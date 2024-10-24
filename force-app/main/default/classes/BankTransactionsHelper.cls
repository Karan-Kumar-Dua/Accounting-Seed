public with sharing class BankTransactionsHelper {
    
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String BT_ADDED_STATUS = 'Added';
    public static final String BT_MATCHED_STATUS = 'Matched';
    public static final String BT_UNMATCHED_STATUS = 'Unmatched';
    public static final String BT_REMOVED_STATUS = 'Removed';
    public static final String BT_IN_PROCESS_STATUS = 'In Process';
    public static final String SOURCE_FINANCIAL_FILE_IMPORT = 'Financial File Import';

    public static final String PROVIDER_STATUS_USER_INPUT_REQUIRED = 'USER_INPUT_REQUIRED';
    public static final String USER_INPUT_REQUIRED_ERROR_MSG = Label.COMMON_USER_AUTHENTICATION_REQ;
    
    public static final String PROVIDER_STATUS_FAILED = 'FAILED';
    public static final String FAILED_ERROR_MSG = Label.ERR_FIA_FAILED;

    public static final String NO_ACTION_REQUIRED_MSG = Label.COMMON_CONN_SUCCESS_NO_ACTION_REQUIRED_MSG;

    private static final Integer MAX_STRING_LENGTH = 255;

    //==============================================================================
    //========== Methods to process downloaded Bank Transactions ===================
    //==============================================================================
    
    public static void processDownloadedBankTransactions(
        List<BDCTransaction> transactionModels,
        Map<String, BDCCategory> categoryById,
        String source
    ) {

        System.Savepoint sp = Database.setSavepoint();
        try {
            //Save downloaded transactions in DB
            List<Bank_Transaction__c> bankTransactions = createBankTransactions(transactionModels, categoryById, source);
            //Execute Matcher class to find applicable source documents for Automated Match and/or Automated Add
            processAutomatedMatchAndAddSync(bankTransactions);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    public static void processAutomatedMatchAndAddSync(List<Bank_Transaction__c> bankTransactions) {
        try {
            if (!bankTransactions.isEmpty() &&
                    (AccountingSettingsHandler.isGlobalAutomatedMatchEnabled()
                        || AccountingSettingsHandler.isGlobalAutomatedAddEnabled())) {

                Set<Id> bankTransactionIds = new Map<Id, Bank_Transaction__c>(bankTransactions).keySet();
                Map<Id, SObject> applicableToMatch = new Map<Id, SObject>();
                List<Bank_Transaction__c> applicableToAdd = new List<Bank_Transaction__c>();
                BankTransactionsMatcher matcher = new BankTransactionsMatcher(
                    bankTransactionIds,
                    BankTransactionsMatcher.ExecutionContext.APEX_JOB
                );
                matcher.searchMatchingRecords();
                for (Bank_Transaction__c bt : bankTransactions) {
                    if (matcher.hasMatchingRecords(bt.Id)
                            && matcher.getMatchingRecords(bt.Id).size() == 1
                            && matcher.getBankTransactionsByMatchingRecord(matcher.getMatchingRecords(bt.Id).get(0).Id).size() == 1) {

                        applicableToMatch.put(bt.Id, matcher.getMatchingRecords(bt.Id).get(0));
                    }
                    else if (!matcher.hasMatchingRecords(bt.Id)) {
                        applicableToAdd.add(bt);
                    }
                }

                //Execute Automated Match if only one possible Source record match exists for the Bank Transaction
                if (AccountingSettingsHandler.isGlobalAutomatedMatchEnabled() && !applicableToMatch.isEmpty()) {
                    List<ServiceResult> acceptResults = acceptMatchingRecord(applicableToMatch, new Map<Id, Bank_Transaction__c>(bankTransactions));
                    updateBankTransactionsStatus(acceptResults, BT_MATCHED_STATUS);
                }
                //Execute Automated Add if there are Bank Transactions without any possible matching records
                if (AccountingSettingsHandler.isGlobalAutomatedAddEnabled() && !applicableToAdd.isEmpty()) {
                    List<ServiceResult> addResults = autoAddRecords(applicableToAdd);
                    updateBankTransactionsStatus(addResults, BT_ADDED_STATUS);
                }
                //Set final Status for BTs not applicable for Automated Match/Add
                updateBankTransactionsStatus(DomainUtils.getPendingBankTransactionsById(bankTransactionIds), BT_UNMATCHED_STATUS);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static void processAutomatedMatchAndAddAsync(List<Bank_Transaction__c> bankTransactions) {
        if (!bankTransactions.isEmpty() &&
                (AccountingSettingsHandler.isGlobalAutomatedMatchEnabled()
                    || AccountingSettingsHandler.isGlobalAutomatedAddEnabled())) {

            BankTransactionsAutomatedMatchBatch automatedMatchBatchInstance =
                new BankTransactionsAutomatedMatchBatch(bankTransactions);
            Database.executeBatch(automatedMatchBatchInstance, ImportFileWizardHelper.TRANSACTIONS_PAGE_SIZE);
        }
    }

    public static List<ServiceResult> acceptMatchingRecord(Map<Id, SObject> btIdToSourceDocRecord, Map<Id, Bank_Transaction__c> allBTs) {
        List<ServiceResult> results = new List<ServiceResult>();
        try {
            for (Id btId : btIdToSourceDocRecord.keySet()) {
                SObject sourceDoc = btIdToSourceDocRecord.get(btId);
                sourceDoc.put('Bank_Transaction__c', btId);
                sourceDoc.put('Cleared_Date__c', allBTs.get(btId).Date__c);
                String descriptionTargetFieldApiName =
                    (sourceDoc.Id.getSobjectType() == Bank_Deposit__c.SObjectType)
                        ? 'Deposit_Reference__c' : 'Description__c';
                //Carry Description over from BT to CR, CD, JEL and BD
                if (String.isBlank((String) sourceDoc.get(descriptionTargetFieldApiName))) {
                    sourceDoc.put(descriptionTargetFieldApiName, allBTs.get(btId).Description__c);
                }
            }

            List<SObject> sourceDocsToUpdate = btIdToSourceDocRecord.values();
            // sort by SObject type avoids chunking error
            sourceDocsToUpdate.sort();
            Set<SObjectField> fieldsToUnlock = new Set<SObjectField>{
                Cash_Receipt__c.Bank_Transaction__c,
                Cash_Disbursement__c.Bank_Transaction__c,
                Journal_Entry_Line__c.Bank_Transaction__c,
                Bank_Deposit__c.Bank_Transaction__c
            };
            TriggerObserver.getInstance().unlockFields(fieldsToUnlock);
            List<Database.SaveResult> updateResults = SFDCSecurityUtils.updateProxy(sourceDocsToUpdate, false);
            TriggerObserver.purgeUnlockedFields(fieldsToUnlock);

            for (Integer i = 0; i < sourceDocsToUpdate.size(); i++) {
                Database.SaveResult updateResult = updateResults.get(i);
                Id bankTransactionId = (String) sourceDocsToUpdate.get(i).get('Bank_Transaction__c');
                if (updateResult.isSuccess()) {
                    results.add(new ServiceResult(bankTransactionId, true));
                }
                else {
                    Database.Error err = updateResult.getErrors()[0];
                    results.add(new ServiceResult(bankTransactionId, err.statusCode.name(), err.message));
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return results;
    }

    public static void updateBankTransactionsStatus(List<ServiceResult> btServiceResults, String status) {
        try {
            Set<Id> btIds = new Set<Id>();
            for (ServiceResult sr : btServiceResults) {
                if (sr.isSuccess) {
                    btIds.add(sr.data);
                }
            }
            updateBankTransactionsStatus(btIds, status);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static void updateBankTransactionsStatus(Set<Id> btIds, String status) {
        try {
            if (!btIds.isEmpty()) {
                List<Bank_Transaction__c> bts = DomainUtils.getBankTransactionsById(btIds);
                updateBankTransactionsStatus(bts, status);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static void updateBankTransactionsStatus(List<Bank_Transaction__c> bts, String status) {
        try {
            for (Bank_Transaction__c bt : bts) {
                bt.Status__c = status;
            }
            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            SFDCSecurityUtils.updateProxy(bts);
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static List<ServiceResult> autoAddRecords(List<Bank_Transaction__c> bankTransactions) {
        List<ServiceResult> results = new List<ServiceResult>();
        Savepoint sp = Database.setSavepoint();
        try {
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(bankTransactions);
            results.addAll(sdFactory.insertSourceDocuments());
        }
        catch (Exception ex) {
            Database.rollback(sp);
            results.add(new ServiceResult(NULL, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())}));
        }
        return results;
    }

    public static List<Bank_Transaction__c> createBankTransactions(
        List<BDCTransaction> transactionModels,
        Map<String, BDCCategory> categoryById,
        String source
    ) {

        List<Bank_Transaction__c> bankTransactionsToInsert = new List<Bank_Transaction__c>();
        try {
            //Build GLAM map to populate GLAM lookup field on BT
            Map<String, GL_Account_Mapping__c> externalIdToGLAM = new Map<String, GL_Account_Mapping__c>();
            for (BDCTransaction transactionModel : transactionModels) {
                externalIdToGLAM.put(transactionModel.accountId, NULL);
            }
            for (GL_Account_Mapping__c glam : DomainUtils.getGLAccountMappingsByExternalIds(externalIdToGLAM.keySet())) {
                externalIdToGLAM.put(glam.External_Id__c, glam);
            }
            //Create new BTs
            Map<String, Bank_Transaction__c> newBankTransactionByKey = mapBankTransactions(
                transactionModels, externalIdToGLAM, categoryById, source
            );
            //Query existed BTs to avoid duplications
            Map<String, Bank_Transaction__c> existedBankTransactionByKey = new Map<String, Bank_Transaction__c>();
            for (Bank_Transaction__c existedBT : DomainUtils.getBankTransactionsByKey(newBankTransactionByKey.keySet())) {
                existedBankTransactionByKey.put(existedBT.Key__c, existedBT);
            }
            //Filter already existed BTs out
            for (String btKey : newBankTransactionByKey.keySet()) {
                if (!existedBankTransactionByKey.containsKey(btKey)) {
                    bankTransactionsToInsert.add(newBankTransactionByKey.get(btKey));
                }
            }
            SFDCSecurityUtils.insertProxy(bankTransactionsToInsert);
        }
        catch (Exception ex) {
            throw ex;
        }
        return bankTransactionsToInsert;
    }

    public static void updateGLAM(List<BDCAccount> accountModels, List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities) {
        try {
            //Map all account models by external id
            Map<String, BDCAccount> acctModelByExtId = new Map<String, BDCAccount>();
            Map<String, BDCFinancialInstitutionIdentity> providerAcctModelByExtId = new Map<String, BDCFinancialInstitutionIdentity>();
            for (BDCAccount acctModel : accountModels) {
                if (acctModel != NULL && String.isNotBlank(acctModel.id)) {
                    acctModelByExtId.put(acctModel.id, acctModel);
                }
            }
            for (BDCFinancialInstitutionIdentity finInstIdentity : financialInstitutionIdentities) {
                if (finInstIdentity != NULL && String.isNotBlank(finInstIdentity.id)) {
                    providerAcctModelByExtId.put(finInstIdentity.id, finInstIdentity);
                }
            }
            //Query existed GLAMs by External Id and update them using data received from external source
            List<GL_Account_Mapping__c> glamsToUpdate = new List<GL_Account_Mapping__c>();            
            for (GL_Account_Mapping__c glam : DomainUtils.getGLAccountMappingsByExternalIdsAndFIAIds(acctModelByExtId.keySet(), providerAcctModelByExtId.keySet())) {
                BDCFinancialInstitutionIdentity finInstIdentity = providerAcctModelByExtId.get(glam.Financial_Institution_Id__c);                
                BDCAccount acctModel = acctModelByExtId.get(glam.External_Id__c);
                glam.FIA_Status__c = NO_ACTION_REQUIRED_MSG;
                
                //next, check the provider account status to make sure there's not a credential issue  
                if (finInstIdentity != NULL) {
                    glam.FIA_Status__c = finInstIdentity.status == PROVIDER_STATUS_USER_INPUT_REQUIRED
                    ? USER_INPUT_REQUIRED_ERROR_MSG
                    : finInstIdentity.status == PROVIDER_STATUS_FAILED
                        ? FAILED_ERROR_MSG
                        : glam.FIA_Status__c;
                }  
                
                if (acctModel != NULL) {
                    glam.Last_Refreshed__c = acctModel.lastUpdated;
                    glam.Available_Balance__c = acctModel.availableBalance;
                    glam.Current_Balance__c = acctModel.currentBalance;
                }
                glamsToUpdate.add(glam);
            }
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
            SFDCSecurityUtils.updateProxy(glamsToUpdate);
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static void logOnActivity(List<String> externalIds, String errorMsg) {
        try {
            List<Task> activities = new List<Task>();
            for (GL_Account_Mapping__c glam : DomainUtils.getGLAccountMappingsByExternalIds(new Set<String>(externalIds))) {
                activities.add(
                    FinancialSuiteUtils.setTask(
                        glam.Id, Label.ERR_DOWNLOADING_BANK_TRANSACTIONS, errorMsg
                    )
                );
            }
            SFDCSecurityUtils.insertProxy(activities);
        }
        catch (Exception ex) {
            //If we unable to create a Task for a GLAM record - just skip it
            throw ex;
        }
    }

    @TestVisible
    private static Date getInitialStartDateThreshold(Date initialStartDate) {
        Date result;
        if (initialStartDate != null) {
            result = initialStartDate.addDays(- BDCService.REFRESH_OFFSET);
        }
        else {
            result =
                Date.today()
                    .addDays(- (BDCService.DEFAULT_START_DATE_OFFSET_IN_DAYS + BDCService.REFRESH_OFFSET));
        }
        return result;
    }

    @TestVisible
    private static Map<String, Bank_Transaction__c> mapBankTransactions(
        List<BDCTransaction> transactionModels, 
        Map<String, GL_Account_Mapping__c> accountIdToGLAM, 
        Map<String, BDCCategory> categoryById,
        String source
    ) {
        Map<String, Bank_Transaction__c> bankTransactionByKey = new Map<String, Bank_Transaction__c>();
        if (categoryById == NULL) {
            categoryById = new Map<String, BDCCategory>();
        }
        
        for (BDCTransaction transactionModel : transactionModels) {
            if (source == BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT || transactionModel.transactionDate >= getInitialStartDateThreshold(accountIdToGLAM.get(transactionModel.accountId).Initial_Start_Date__c)) {
                Bank_Transaction__c bt = new Bank_Transaction__c();
                bt.Bank_Transaction_Id__c = transactionModel.id;
                bt.Account_Id__c = transactionModel.accountId;
                bt.Amount__c = transactionModel.amount;
                if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                    bt.put('CurrencyIsoCode', transactionModel.currencyIsoCode);
                }
                bt.Base_Type__c = transactionModel.baseType;
                bt.Check_Number__c = FinancialSuiteUtils.trunc(transactionModel.checkNumber, 50);
                bt.Container__c = transactionModel.container;
                bt.Date__c = transactionModel.transactionDate;
                bt.Transaction_Date__c = transactionModel.transactionDate;
                bt.Post_Date__c = transactionModel.postDate; 
                bt.Description__c = (transactionModel.description != NULL) ? FinancialSuiteUtils.trunc(transactionModel.description, MAX_STRING_LENGTH) : NULL;
                bt.Category_Type2__c = FinancialSuiteUtils.trunc(transactionModel.categoryType, MAX_STRING_LENGTH);
                bt.Memo__c = FinancialSuiteUtils.trunc(transactionModel.memo, MAX_STRING_LENGTH);
                bt.Merchant_Name__c = (transactionModel.merchantName != NULL) ? FinancialSuiteUtils.trunc(transactionModel.merchantName, MAX_STRING_LENGTH) : NULL;
                bt.Running_Balance__c = (transactionModel.runningBalance != NULL) ? transactionModel.runningBalance : NULL;
                bt.Source__c = source;
                bt.Type__c = FinancialSuiteUtils.trunc(transactionModel.type, MAX_STRING_LENGTH);
                bt.Key__c = transactionModel.container + transactionModel.id;
                bt.GL_Account_Mapping__c = accountIdToGLAM.get(transactionModel.accountId).Id;

                bt.Status__c =
                    AccountingSettingsHandler.isGlobalAutomatedMatchEnabled()
                        || AccountingSettingsHandler.isGlobalAutomatedAddEnabled() ? BT_IN_PROCESS_STATUS : BT_UNMATCHED_STATUS;
                
                //CATEGORY LEVEL 1
                bt.High_Level_Category_Id__c = FinancialSuiteUtils.trunc(transactionModel.categoryLevel1Id, 50);
                if (String.isNotEmpty(transactionModel.categoryLevel1Id)) {
                    try {
                        bt.High_Level_Category__c = FinancialSuiteUtils.trunc(
                            categoryById.get(transactionModel.categoryLevel1Id).name,
                            MAX_STRING_LENGTH
                        );
                    } catch (System.TypeException ex) {
                        throw ex;
                    }
                }

                //CATEGORY LEVEL 2
                bt.Category_ID__c = FinancialSuiteUtils.trunc(transactionModel.categoryLevel2Id, 50);
                if (String.isNotEmpty(transactionModel.categoryLevel2Id)) {
                    try {
                        bt.Category__c = FinancialSuiteUtils.trunc(
                            categoryById.get(transactionModel.categoryLevel2Id).name,
                            MAX_STRING_LENGTH
                        );
                    } catch (System.TypeException ex) {
                        throw ex;
                    }
                }

                //CATEGORY LEVEL 3
                bt.Detail_Category_Id__c = FinancialSuiteUtils.trunc(transactionModel.categoryLevel3Id, 50);
                if (String.isNotEmpty(transactionModel.categoryLevel3Id)) {
                    try {
                        bt.Detail_Category__c = FinancialSuiteUtils.trunc(
                            categoryById.get(transactionModel.categoryLevel3Id).name,
                            MAX_STRING_LENGTH
                        );
                    } catch (System.TypeException ex) {
                        throw ex;
                    }
                }
                
                bt.Merchant_Category__c = (transactionModel.merchantCategory != NULL) ? FinancialSuiteUtils.trunc(transactionModel.merchantCategory, MAX_STRING_LENGTH) : NULL;
                bt.Merchant_Id__c = (transactionModel.merchantId != NULL) ? FinancialSuiteUtils.trunc(transactionModel.merchantId, 50) : NULL;   
                bt.Merchant_Type2__c = (transactionModel.merchantType != NULL) ? FinancialSuiteUtils.trunc(transactionModel.merchantType, MAX_STRING_LENGTH) : NULL;
                bt.Parent_Category_Id__c = (transactionModel.categoryCustomId != NULL) ? FinancialSuiteUtils.trunc(transactionModel.categoryCustomId, 50) : NULL; 
                bt.Simple_Description__c = (transactionModel.shortDescription != NULL) ? FinancialSuiteUtils.trunc(transactionModel.shortDescription, MAX_STRING_LENGTH) : NULL;

                bankTransactionByKey.put(bt.Key__c, bt);
            }
        }
        return bankTransactionByKey;
        
    }
    


}