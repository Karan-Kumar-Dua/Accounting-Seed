public with sharing class CxSettler {

    public SettlerWrapper createJournalEntryWithLines(List<Bank_Deposit__c> scope, Set<Id> ppIds, CxAJRLogger logger){
        Map<Id, Bank_Deposit__c> bankDepositMap = new Map<Id, Bank_Deposit__c>(scope); 
        Map<Id, Decimal> bankDepWithFee = new Map<Id, Decimal>();
        Map<Id, Decimal> bankDepWithAmt = new Map<Id, Decimal>();
        Map<Id, Decimal> bankDepWithConvFee = new Map<Id,Decimal>();
        Set<String> batchIds = new Set<String>();
        Set<Id> jESuccessIds = new Set<Id>();
        Integer currentExecutionFailed = 0;
        
        for(Bank_Deposit__c bankDep : scope){
            //Used to store all Merchant Batch Ids for Existing Bank Deposits
            batchIds.add(bankDep.Merchant_Batch_Id__c);
            bankDepWithAmt.put(bankDep.Id, bankDep.Ledger_Amount__c);
        }

        List<AggregateResult> activityAggregate = DomainUtils.getPaymentProcessingFeesByBankDeposit(bankDepositMap.keyset());

        for(AggregateResult ar : activityAggregate){
            bankDepWithFee.put((Id)ar.get('bankDep'), (Decimal)ar.get('feeSum'));
            bankDepWithConvFee.put((Id)ar.get('bankDep'), (Decimal)ar.get('convenienceFee'));
        }
        // parallel lists
        Map<Id, Journal_Entry__c> depositJournalEntry = new Map<Id, Journal_Entry__c>();
        List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();
        // for updating existing journal Entry Lines
        Map<Id, Journal_Entry__c> depositExistJournalEntry = new Map<Id, Journal_Entry__c>();
        Map<String, Journal_Entry__c> batchIdJournalEntry = new Map<String, Journal_Entry__c>();

        // Get existing Journal Entries having the similar Merchant Batch Id.
        List<Journal_Entry__c> journalEntries = DomainUtils.getJournalEntryByReference(batchIds);
        //clearing the batchIds to store the existing JE batchIds.
        batchIds.clear();
        
        for(Journal_Entry__c jEntry: journalEntries){
            batchIds.add(jEntry.Reference__c + String.valueOf(jEntry.Ledger__c));
            batchIdJournalEntry.put(jEntry.Reference__c + String.valueOf(jEntry.Ledger__c), jEntry);
        }

        List<Id> pymtprocessorIds = new List<Id>();
        Map<Id, Id> jeIdWithPPId = new Map<Id, Id>();

        for(Bank_Deposit__c bD : scope){
            //Creating JournalEntry if not exist already
            if(!batchIds.contains(bD.Merchant_Batch_Id__c + bD.Ledger__c)){
                pymtprocessorIds.add(bD.Cash_Receipts__r[0]?.Payment_Processor__c);
                depositJournalEntry.put(bD.Id, createJournalEntry(bD));
            }else{
                jeIdWithPPId.put(batchIdJournalEntry.get(bD.Merchant_Batch_Id__c + bD.Ledger__c).Id, bD.Cash_Receipts__r[0]?.Payment_Processor__c);
                depositExistJournalEntry.put(bD.Id, batchIdJournalEntry.get(bD.Merchant_Batch_Id__c + bD.Ledger__c));
            }
        }

        //Insert JournalEntry Records
        Database.SaveResult[] saveJEList = SfdcSecurityUtils.insertProxy(depositJournalEntry.values(), false);
        List<ResultWrapper> failedJEInsertResults = new List<ResultWrapper>();
        Set<Id> ppIdsToRemove = new Set<Id>();
        Set<Id> journalEntriesToDelete = new Set<Id>();
        //Used to append more than one Error messages in existing Wrapper instance for further JE and its related JEL operation.
        Map<Id, ResultWrapper> jEWithWrapper = new Map<Id, ResultWrapper>();
        //gl account defaults for the bank deposits
        Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaults = GLAccount.glAccountDefaultsMapByLedgerId(
                                            new Set<Id> (SObjectActions.ledgerIdBySourceId(bankDepositMap.values()).values())
                                        );
        // Iterate through saveResultList based on isSuccess capture the failed records
        for (Integer i = 0; i < saveJEList.size(); i++) {
            if (saveJEList[i].isSuccess()) {
                logger.logSuccess(pymtprocessorIds[i]);
                jESuccessIds.add(saveJEList[i].getId());
                jeIdWithPPId.put(saveJEList[i].getId(), pymtprocessorIds[i]);
            }
            else {
                logger.logError(pymtprocessorIds[i], saveJEList[i].getErrors()[0].getMessage());
                //currentExecutionFailed++;
                //failedJEInsertResults.add(new ResultWrapper(saveJEList[i], pymtprocessorIds[i]));
            }
        }
        // for Insert Journal Entry Lines
        for(Id bankDepId : depositJournalEntry.keySet()){
            if(depositJournalEntry.containsKey(bankDepId) && depositJournalEntry.get(bankDepId).Id != null){
                //Creating JournalEntryLine 1
                journalEntryLines.add( new Journal_Entry_Line__c(
                        Journal_Entry__c = depositJournalEntry.get(bankDepId).Id,
                        GL_Account__c = bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Merchant_GL_Account__c,
                        Credit__c = bankDepWithAmt.get(bankDepId)
                ));

                //Creating JournalEntryLine 2
                journalEntryLines.add( new Journal_Entry_Line__c(
                        Journal_Entry__c = depositJournalEntry.get(bankDepId).Id,
                        GL_Account__c = bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Bank_GL_Account__c,
                        Debit__c = bankDepWithAmt.get(bankDepId),
                        Description__c = depositJournalEntry.get(bankDepId).Name + ' (' + (Label.COMMON_DEPOSIT).toLowerCase() + ')'
                ));

                //Creating JournalEntryLine 3
                journalEntryLines.add( new Journal_Entry_Line__c(
                        Journal_Entry__c = depositJournalEntry.get(bankDepId).Id,
                        GL_Account__c = bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Bank_GL_Account__c,
                        Credit__c = bankDepWithFee.get(bankDepId),
                        Description__c = depositJournalEntry.get(bankDepId).Name + ' (' + Label.COMMON_FEE_WITHDRAWAL + ')'
                ));

                //Creating JournalEntryLine 4
                journalEntryLines.add( new Journal_Entry_Line__c(
                        Journal_Entry__c = depositJournalEntry.get(bankDepId).Id,
                        GL_Account__c = bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Merchant_Fees_GL_Account__c,
                        Debit__c = bankDepWithFee.get(bankDepId)
                ));
            }
            if(!bankDepWithConvFee.isEmpty() && bankDepWithConvFee.get(bankDepId) != null && bankDepWithConvFee.get(bankDepId) > 0 
                && (
                    (bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Convenience_Fees_GL_Account__c != null) ||
                    (bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Merchant_Fees_GL_Account__c != null)
                    )
                ){
                //create debit journal entry line on unapplied AR General ledger Account
                journalEntryLines.add( new Journal_Entry_Line__c(
                        Journal_Entry__c = depositJournalEntry.get(bankDepId).Id,
                        GL_Account__c = glAccountDefaults.get(bankDepositMap.get(bankDepId).Ledger__c).get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT).GL_Account__c,
                        Debit__c = bankDepWithConvFee.get(bankDepId),
                        Description__c=Label.INF_CONVENIENCE_FEES_CHARGE_FOR_ALL
                ));
                //create credit journal entry line on PP convenience fee gl account
                journalEntryLines.add( new Journal_Entry_Line__c(
                        Journal_Entry__c = depositJournalEntry.get(bankDepId).Id,
                        GL_Account__c = (bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Convenience_Fees_GL_Account__c) != null ? (bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Convenience_Fees_GL_Account__c) : (bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Merchant_Fees_GL_Account__c),
                        Credit__c = bankDepWithConvFee.get(bankDepId),
                        Description__c=Label.INF_CONVENIENCE_FEES_CHARGE_FOR_ALL
                ));
            }
        }
        //for Update Journal Entry Lines
        for(Id bankDepId : depositExistJournalEntry.keySet()){
            for(Journal_Entry_Line__c jEL : depositExistJournalEntry.get(bankDepId).Journal_Entry_Lines__r){
                if(jEL.GL_Account__c == bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Merchant_Fees_GL_Account__c && jEl.Credit__c == null){
                    jEL.Debit__c = bankDepWithFee.get(bankDepId);
                }else if(jEL.GL_Account__c == bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Bank_GL_Account__c && jEL.Credit__c == null){
                    jEL.Debit__c = bankDepWithAmt.get(bankDepId);
                }else if(jEL.GL_Account__c == bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Bank_GL_Account__c && jEL.Debit__c == null){
                    jEL.Credit__c = bankDepWithFee.get(bankDepId);
                }else if(jEL.GL_Account__c == bankDepositMap.get(bankDepId).Cash_Receipts__r?.Payment_Processor__r?.Merchant_GL_Account__c && jEL.Debit__c == null){
                    jEL.Credit__c = bankDepWithAmt.get(bankDepId);
                }
                journalEntryLines.add(jEL);
            }
        }
        // Upsert JournalEntryLines
        Database.UpsertResult[] upsertJELResults = SfdcSecurityUtils.upsertProxy(journalEntryLines, false);
        for (Integer i = 0; i < upsertJELResults.size(); i++) {
            if (!upsertJELResults[i].isSuccess()) {
                jESuccessIds.remove(journalEntryLines[i].Journal_Entry__c);
                logger.logError(jeIdWithPPId.get(journalEntryLines[i].Journal_Entry__c), upsertJELResults[i].getErrors()[0].getMessage());
                journalEntriesToDelete.add(journalEntryLines[i].Journal_Entry__c);
               
                // deleting the ppId if any of JEL get failed, to not sync its payment processor last sync field.
                ppIdsToRemove.add(jeIdWithPPId.get(journalEntryLines[i].Journal_Entry__c)); 

            }else{
                // Used to check if all JEL has been upserted properly, to update its related Payment Processor Last Sync.
                ppIds.add(jeIdWithPPId.get(journalEntryLines[i].Journal_Entry__c));
            }
        } 

        ppIds.removeAll(ppIdsToRemove);

        //prepare List of Journal Entry to Delete because of failure child JEL's.
        if(!journalEntriesToDelete.isEmpty()){
            List<Journal_Entry__c> deleteJEs = prepJournalEntryToDelete(journalEntriesToDelete);
            Database.DeleteResult[] deleteJEResults = SfdcSecurityUtils.deleteProxyDatabase(deleteJEs, false);
            for (Integer i = 0; i < deleteJEResults.size(); i++) {
                if (!deleteJEResults[i].isSuccess()) {
                    logger.logError(jeIdWithPPId.get(journalEntryLines[i].Journal_Entry__c), deleteJEResults[i].getErrors()[0].getMessage());
                    }               
                }
            }

        // Link deposits to their respective JEs
        Journal_Entry__c je;
        List<Bank_Deposit__c> depositUpdates = new List<Bank_Deposit__c>();
        for (Bank_Deposit__c deposit : scope) {
            // find JE associated with the deposit
            if (depositJournalEntry.containsKey(deposit.Id)) {
                je = depositJournalEntry.get(deposit.Id);
            } else if (depositExistJournalEntry.containsKey(deposit.Id)) {
                je = depositExistJournalEntry.get(deposit.Id);
            } else {
                continue;
            }
            
            // if the JE was successfully created/updated, update the deposit with the JE ID
            if (jESuccessIds.contains(je.Id)) {
                deposit.Merchant_Funds_Transfer__c = je.Id;
                depositUpdates.add(deposit);
            }
        }

        // save the updated deposits
        SfdcSecurityUtils.updateProxy(depositUpdates, false);
        

        SettlerWrapper jEWrapper = new SettlerWrapper();
        jEWrapper.succeedRecords = jESuccessIds.size();
        jEWrapper.successfulJournalEntryIds = jESuccessIds;
        jEWrapper.failedRecords = currentExecutionFailed;
        jEWrapper.resultWrapperList = failedJEInsertResults;
        jEWrapper.ppLastSyncUpdate = ppIds;

        return jEWrapper;
    }

    // Method to create Journal Entry.
    private Journal_Entry__c createJournalEntry(Bank_Deposit__c bD){
        Journal_Entry__c je = new Journal_Entry__c(
            Name = String.format(Label.MERCHANT_DOWNLOAD_JE_NAME, new List<String>{ String.valueOf(bD.Deposit_Date__c) }),
            Reference__c = bD.Merchant_Batch_Id__c,
            Journal_Date__c = bD.Deposit_Date__c,
            Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
            Ledger__c = bD.Ledger__c
        );
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            je.put('CurrencyIsoCode', bD.get('CurrencyIsoCode'));
        }
        return je;
    }

    // Method to delete Journal Entry.
    private List<Journal_Entry__c> prepJournalEntryToDelete(Set<Id> deleteJEIds){
        List<Journal_Entry__c> jEList = new List<Journal_Entry__c>();
        for(Id journalEntryId : deleteJEIds){
            jEList.add(new Journal_Entry__c (Id = journalEntryId));
        }
        return jEList;
    }

    public with sharing class ResultWrapper {
        public Boolean isSuccess;
        public Id recordId;
        public String errorMsg;

        public ResultWrapper(Database.UpsertResult dr, Id pymtProcessorId) {
            this.isSuccess = dr.isSuccess();
            this.recordId = pymtProcessorId;
            this.errorMsg = !dr.isSuccess() ? dr.getErrors()[0].getStatusCode() + ': ' + dr.getErrors()[0].getMessage() : '';
        }

        public ResultWrapper(Database.SaveResult sr, Id pymtProcessorId) {
            this.isSuccess = sr.isSuccess();
            this.recordId = pymtProcessorId;
            this.errorMsg = !sr.isSuccess() ? sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage() : '';
        }
    }

    public with sharing class SettlerWrapper {
        public List<ResultWrapper> resultWrapperList;
        public Integer succeedRecords;
        public Integer failedRecords;
        public Set<Id> ppLastSyncUpdate;
        public Set<Id> successfulJournalEntryIds;
    }

}