public with sharing class AccountPayableFromRecrAccPayableHelper {
    //final strings
    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private final String COMPLETED = TransactionGroupActions.STATUS_COMPLETED;
    private final String FAILED = TransactionGroupActions.STATUS_FAILED;
    private final String PROCESSING = TransactionGroupActions.STATUS_PROCESSING;

    //instance members
    private List<Recurring_Account_Payable_Line__c> recAccPayableLines;
    private String batchId;
    private Boolean isProductAvailable;
    private Set<Id> recAccPayableIds;
    private Map<Id,Recurring_Account_Payable__c> recurringAccPayablesById;
    private Map<Id,Transaction_Group__c> existingTxnGrpByRecAccPayable;
    private Map<Id,Transaction_Group__c> newTxnGrpByRecAccPayable;
    private Map<Id,Integer> linesCountByRecAccPayable;
    private Map<Id,Integer> processedLinesCountByRecAccPayable;
    private Set<Id> failedAccPayableLineRecAccPayableIds;
    private AJRLogger logger;

    //contructor
    public AccountPayableFromRecrAccPayableHelper(List<SObject> recAccPayableLines,String batchId, AJRLogger logger){
        this.recAccPayableLines = (List<Recurring_Account_Payable_Line__c>)recAccPayableLines;
        this.batchId = batchId;
        this.logger = logger;
        this.isProductAvailable = Product2.SObjectType.getDescribe().isAccessible() && Recurring_Account_Payable_Line__c.SObjectType.fields.Product__c.getDescribe().isAccessible();
        this.newTxnGrpByRecAccPayable = new Map<Id,Transaction_Group__c>();
    }

    /**
     * this method will create and update the source records for recurring Account Payable
     * this will be responsible for creating Account Payable, Transaction Groups, and Account Payable Line
     * this will also be responsible for updating the Transaction Groups with Failed status
     */
    public void createSourceRecords(){
        fetchUniqueRecAccPayables();
        fetchExistingTransactionGroups();
        dropLinesRelatedToFailedTransactionGroups(existingTxnGrpByRecAccPayable);
        fetchRecAccPayableLinesCount();
        calculateLineProcessedByRecAccPayable();
        fetchRecurringAccountPayables();
        createAccountPayables();
        dropLinesRelatedToFailedTransactionGroups(newTxnGrpByRecAccPayable);
        createAccountPayableLines();
        updateTransactionGroupsForFailedLines();
        updateTransactionGroupsWithNewLineCountLineProcessed();
        updateRecurringAccountPayables();
    }
    /**
     * fetch and store all the unique Recurring Account Payable from the current chunk of Recurring Account Payable Lines
     */
    private void fetchUniqueRecAccPayables(){
        recAccPayableIds = new Set<Id>();
        for(Recurring_Account_Payable_Line__c recAccPayableLine : recAccPayableLines){
            recAccPayableIds.add(recAccPayableLine.Recurring_Account_Payable__c);
        }
    }
    /**
     * store all the line counts by recurring Account Payable
     * this will help us creating the recurring Transaction Groups
     */
    private void fetchRecAccPayableLinesCount(){
        linesCountByRecAccPayable = new Map<Id,Integer>();
        Map<Id,AggregateResult> results = DomainUtils.getRecAccPayablelinesCountByRecAccPayable(recAccPayableIds);

        for(Id recordId : results.keySet()){
            linesCountByRecAccPayable.put(recordId,Integer.valueOf(results.get(recordId).get('lineCount')));
        }
    }
    /**
     * Fetch existing Transaction Groups to get the previously created details or to update them with latest status
     */
    private void fetchExistingTransactionGroups(){
        if(recAccPayableIds != null){
            List<Transaction_Group__c> existingTxnGroup = DomainUtils.getTransactionGroupBySourceAndBatchId(recAccPayableIds,batchId);
            existingTxnGrpByRecAccPayable = new Map<Id,Transaction_Group__c>();
            for(Transaction_Group__c txnGrp : existingTxnGroup){
                existingTxnGrpByRecAccPayable.put(txnGrp.Recurring_Account_Payable__c, txnGrp);
            }
        }
    }

    /**
     * Drop the Recurring Account Payable Lines related to the failed Transaction Groups
     */
    private void dropLinesRelatedToFailedTransactionGroups(Map<Id, Transaction_Group__c> txnGroupByRecPayables){
        if (txnGroupByRecPayables == null || txnGroupByRecPayables.isEmpty()) {
            return;
        }

        List<Recurring_Account_Payable_Line__c> lines = new List<Recurring_Account_Payable_Line__c>();
        for(Recurring_Account_Payable_Line__c line : recAccPayableLines){
            Transaction_Group__c txnGroup = txnGroupByRecPayables.get(line.Recurring_Account_Payable__c);
            if (txnGroup == null || !FAILED.equalsIgnoreCase(txnGroup.Status__c)) {
                lines.add(line);
            } else {
                recAccPayableIds.remove(line.Recurring_Account_Payable__c);
            }
        }

        recAccPayableLines = lines;
    }

    /**
     * Method to calculate the total line processed
     * this will be used in creating the Transaction Groups
     */
    private void calculateLineProcessedByRecAccPayable() {
        processedLinesCountByRecAccPayable =  new Map<Id,Integer>();

        for(Id recAccPayableId : existingTxnGrpByRecAccPayable.keySet()){
            processedLinesCountByRecAccPayable.put(recAccPayableId,Integer.valueOf(existingTxnGrpByRecAccPayable.get(recAccPayableId).Lines_Processed__c));
        }

        for(Recurring_Account_Payable_Line__c recAccPayableLine : recAccPayableLines){
            if(processedLinesCountByRecAccPayable.containsKey(recAccPayableLine.Recurring_Account_Payable__c)){
                processedLinesCountByRecAccPayable.put(recAccPayableLine.Recurring_Account_Payable__c,processedLinesCountByRecAccPayable.get(recAccPayableLine.Recurring_Account_Payable__c) + 1);
            }else{
                processedLinesCountByRecAccPayable.put(recAccPayableLine.Recurring_Account_Payable__c,1);
            }
        }
    }
    /**
     * Fetch Recurring Account Payable to use them further in either calculation or record creation 
     */
    private void fetchRecurringAccountPayables(){
        recurringAccPayablesById = new Map<Id,Recurring_Account_Payable__c>(DomainUtils.getRecurringAccountPayableByIds(recAccPayableIds));
    }
    /**
     * Method to create the Account Payable from the Recurring Account Payables
     * This will also be creating new Transaction Groups for new Recurring Account Payables
     */
    private void createAccountPayables(){
        List<Account_Payable__c> newAccountPayables = new List<Account_Payable__c>();
        //fetch  recurring Account Payables
        List<Transaction_Group__c> newTxnGroups = new List<Transaction_Group__c>();
        List<Recurring_Account_Payable__c> recurringAccPayables = recurringAccPayablesById.values();
		List<Recurring_Account_Payable__c> nonExistingTxnGrpRecAccPayables = new List<Recurring_Account_Payable__c>();
        
        for(Recurring_Account_Payable__c recAccPayable : recurringAccPayables){
            //indicates we already have a Account Payable for this recurring Account Payable
            if(!existingTxnGrpByRecAccPayable.containsKey(recAccPayable.Id)){
                nonExistingTxnGrpRecAccPayables.add(recAccPayable);
                newAccountPayables.add(getPayableFromRecPayable(recAccPayable));
            }
        }

        if(!newAccountPayables.isEmpty()){
            //save the Account Payable
            List<Database.SaveResult> results = SFDCSecurityUtils.insertProxy(newAccountPayables,false);

            //create either failed or completed Transactions Groups based on Account Payable record success
            for (Integer index = 0; index < results.size(); index++) {
                newTxnGroups.add(getTransactionGroup(nonExistingTxnGrpRecAccPayables[index].Id,results[index].getId(),results[index].isSuccess()));
                if (results[index].isSuccess()) {
                    logger.logSuccess(newAccountPayables[index].Recurring_Account_Payable__c);
                } else {
                    logger.logError(newAccountPayables[index].Recurring_Account_Payable__c, results[index].getErrors()[0].getMessage());
                }
            }

            if(!newTxnGroups.isEmpty()){
                //insert new Transaction Groups
                List<Database.SaveResult> txnSaveResults = SFDCSecurityUtils.insertProxy(newTxnGroups,false);
                Integer recordIndex = 0;
                for(Database.SaveResult result : txnSaveResults){
                    if(result.isSuccess()){
                        newTxnGrpByRecAccPayable.put(newTxnGroups[recordIndex].Recurring_Account_Payable__c,newTxnGroups[recordIndex]);
                    }
                    recordIndex++;
                }
            }
        }
    }
    //return a new instance of Account Payable originated from a Recurring Account Payable
    private Account_Payable__c getPayableFromRecPayable(Recurring_Account_Payable__c rPayable) {
        Account_Payable__c payable = new Account_Payable__c();
        payable.Date__c = rPayable.Next_Account_Payable_Date__c;
        payable.Payee_Reference__c = rPayable.Name + ' ' + System.now().formatLong();
        payable.Vendor__c = rPayable.Vendor__c;
        payable.Contact__c = rPayable.Contact__c;
        payable.Employee__c = rPayable.Employee__c;
        payable.Recurring_Account_Payable__c = rPayable.Id;
        payable.Ledger__c = (rPayable.Ledger__c == NULL) ? LedgerHandler.getLegacyDefaultLedgerId() : rPayable.Ledger__c;

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            payable.put('CurrencyIsoCode', rPayable.get('currencyIsoCode'));
        }
        return payable;
    }
    //return a new instance of Transaction Group for provided Recurring Account Payable and Account Payable
    private Transaction_Group__c getTransactionGroup(Id recAccPayableId, Id accPayableId, Boolean isSuccess){
        Transaction_Group__c result = new Transaction_Group__c();
        result.Line_Count__c = linesCountByRecAccPayable.containsKey(recAccPayableId) == true ? linesCountByRecAccPayable.get(recAccPayableId) : 0;
        result.Lines_Processed__c = processedLinesCountByRecAccPayable.containsKey(recAccPayableId) == true ? processedLinesCountByRecAccPayable.get(recAccPayableId) : 0;
        result.Batch_Id__c = batchId;
        result.Recurring_Account_Payable__c = recAccPayableId;
        result.Account_Payable__c = accPayableId;
        result.Status__c = isSuccess == true ? PROCESSING : FAILED;
        result.Ledger__c = recurringAccPayablesById.get(recAccPayableId).Ledger__c;
        result.Job_Type__c = PayableFromRecurringPayableBatch.JOB_NAME;
        return result; 
    }
    /**
     * Create Account Payable Lines from the Recurring Account Payable Lines 
     * This will also responsible for updateting Transaction Group Record with the failed status if any Account Payable Line fails
     */
    private void createAccountPayableLines(){
        List<Account_Payable_Line__c> accPayableLines = new List<Account_Payable_Line__c>();
        failedAccPayableLineRecAccPayableIds = new Set<Id>();

        //create Account Payable Line From Recurring Account Payable Line
        for(Recurring_Account_Payable_Line__c recAccPayableLine : recAccPayableLines){
            accPayableLines.add(getPayableLineFromRecPayableLine(recurringAccPayablesById.get(recAccPayableLine.Recurring_Account_Payable__c),recAccPayableLine));
        }

        if(!accPayableLines.isEmpty()){
            //create Recurring Account Payable Lines
            List<Database.SaveResult> accPayableLinesaveResult = SFDCSecurityUtils.insertProxy(accPayableLines,false);

            //store failed Account Payable Lines to update Transaction Group
            Integer recordIndex = 0;
            for(Database.SaveResult result : accPayableLinesaveResult){
                Id rPayId = recAccPayableLines[recordIndex].Recurring_Account_Payable__c;
                if(result.isSuccess()){
                    logger.logSuccess(rPayId);
                } else {
                    failedAccPayableLineRecAccPayableIds.add(rPayId);
                    logger.logError(rPayId, result.getErrors()[0].getMessage());
                }
                recordIndex++;
            }
        }
    }
    //return an instance of Account Payable Line originated from a Recurring Account Payable Line
    private Account_Payable_Line__c getPayableLineFromRecPayableLine(Recurring_Account_Payable__c recAccountPayable, Recurring_Account_Payable_Line__c rPayableLine) {
        Id accPayableId = (existingTxnGrpByRecAccPayable != NULL && existingTxnGrpByRecAccPayable.containsKey(recAccountPayable.Id)) ? 
                        existingTxnGrpByRecAccPayable.get(recAccountPayable.Id).Account_Payable__c : 
                        (newTxnGrpByRecAccPayable != NULL && newTxnGrpByRecAccPayable.containsKey(recAccountPayable.Id)) ? 
                        newTxnGrpByRecAccPayable.get(recAccountPayable.Id).Account_Payable__c : 
                        NULL;

        //accPayable Id = null indicates we don't have any Transaction Group for this Recurring Account payable means it should fail 
        if(accPayableId == NULL){
            return new Account_Payable_Line__c();
        }
        Account_Payable_Line__c payableLine = new Account_Payable_Line__c();
        payableLine.Account_Payable__c = accPayableId;
        payableLine.Recurring_Account_Payable_Line__c = rPayableLine.Id;
        payableLine.Expense_GL_Account__c = rPayableLine.Expense_GL_Account__c;
        payableLine.Quantity__c = rPayableLine.Quantity__c != NULL ? rPayableLine.Quantity__c : 1;
        payableLine.Date__c = recAccountPayable.Next_Account_Payable_Date__c;
        payableLine.Project__c = rPayableLine.Project__c;
        payableLine.Project_Task__c = rPayableLine.Project_Task__c;
        payableLine.Tax_Group__c = rPayableLine.Tax_Group__c;
        payableLine.Tax_Amount__c = rPayableLine.Tax_Amount__c;
        payableLine.Unit_Cost__c = rPayableLine.Unit_Cost__c != NULL ? rPayableLine.Unit_Cost__c : rPayableLine.Amount2__c;
        payableLine.GL_Account_Variable_1__c = rPayableLine.GL_Account_Variable_1__c;
        payableLine.GL_Account_Variable_2__c = rPayableLine.GL_Account_Variable_2__c;
        payableLine.GL_Account_Variable_3__c = rPayableLine.GL_Account_Variable_3__c;
        payableLine.GL_Account_Variable_4__c = rPayableLine.GL_Account_Variable_4__c;
        payableLine.Internal_Comment__c = rPayableLine.Internal_Comment__c;
        if (isProductAvailable) {
            payableLine.Product__c = rPayableLine.Product__c;
        }
        return payableLine;
    }
    /**
     * When there are any failure during creating the Account Payable Line we've to update the respective Transaction Group
     * If we found the correct Transaction Group Update the Status to Fail
     * else create a new Transaction Group with failed status
     */
    private void updateTransactionGroupsForFailedLines(){
        if(failedAccPayableLineRecAccPayableIds != null && failedAccPayableLineRecAccPayableIds.size() != 0){
            List<Transaction_Group__c> groupsToUpdate = new List<Transaction_Group__c>();

            for(Id recAccPayableId : failedAccPayableLineRecAccPayableIds){
                Transaction_Group__c txnGroup = existingTxnGrpByRecAccPayable.containsKey(recAccPayableId) ? 
                                                existingTxnGrpByRecAccPayable.get(recAccPayableId) : 
                                                newTxnGrpByRecAccPayable.containsKey(recAccPayableId) ? 
                                                newTxnGrpByRecAccPayable.get(recAccPayableId) : NULL;
                if(txnGroup != NULL){
                    //update existing record
                    txnGroup.Status__c = FAILED;
                    groupsToUpdate.add(txnGroup);
                }else{
                    //create new Transaction Group
                    groupsToUpdate.add(getTransactionGroup(recAccPayableId,NULL,false));
                }
            }

            if(!groupsToUpdate.isEmpty()){
                SFDCSecurityUtils.upsertProxy(groupsToUpdate, false);              
            }
        }
    }
     /**
     * Update the Existing Transaction Groups with their latest Line Count and Latest Line Processed Values
     */
    private void updateTransactionGroupsWithNewLineCountLineProcessed(){
        List<Transaction_Group__c> updates = new List<Transaction_Group__c>();
        updates.addAll(getTransactionGroupUpdates(existingTxnGrpByRecAccPayable));
        updates.addAll(getTransactionGroupUpdates(newTxnGrpByRecAccPayable));

        if(!updates.isEmpty()){
            //update the Transaction Groups
            SFDCSecurityUtils.updateProxy(updates, false);
        }
    }
    private List<Transaction_Group__c> getTransactionGroupUpdates(Map<Id,Transaction_Group__c> txnGroupsByRecAccPayable) {
        List<Transaction_Group__c> updates = new List<Transaction_Group__c>();
        for(Id recAccPayableId : txnGroupsByRecAccPayable.keySet()){
            Transaction_Group__c txnGroup = txnGroupsByRecAccPayable.get(recAccPayableId);
            //check if line count has any reference
            if(linesCountByRecAccPayable.containsKey(recAccPayableId)){
                txnGroup.Line_Count__c = linesCountByRecAccPayable.get(recAccPayableId);
            }
            if(processedLinesCountByRecAccPayable.containsKey(recAccPayableId)){
                txnGroup.Lines_Processed__c = processedLinesCountByRecAccPayable.get(recAccPayableId);
            }
            // check if status can be updated to completed
            if (txnGroup.Line_Count__c == txnGroup.Lines_Processed__c && txnGroup.Status__c == PROCESSING) {
                txnGroup.Status__c = COMPLETED;
            }
            updates.add(txnGroup);
        }
        return updates;
    }
    private void updateRecurringAccountPayables(){
        List<Recurring_Account_Payable__c> updates = new List<Recurring_Account_Payable__c>();
        updates.addAll(updateCompletedRecurringAccPayableSchedules(existingTxnGrpByRecAccPayable));
        updates.addAll(updateCompletedRecurringAccPayableSchedules(newTxnGrpByRecAccPayable));

        if(!updates.isEmpty()){
            //update the Transaction Groups
            SFDCSecurityUtils.updateProxy(updates, false);
        }
    }
    private List<Recurring_Account_Payable__c> updateCompletedRecurringAccPayableSchedules(Map<Id,Transaction_Group__c> txnGroupsByRecAccPayables) {
        List<Recurring_Account_Payable__c> updates = new List<Recurring_Account_Payable__c>();
        for(Id recAccPayableId : txnGroupsByRecAccPayables.keySet()){
            if (txnGroupsByRecAccPayables.get(recAccPayableId).Status__c == COMPLETED) {
                Recurring_Account_Payable__c recAccPayable = recurringAccPayablesById.get(recAccPayableId);
                if (recAccPayable.Status__c == RecurringAccountPayableAction.RECURRING_STATUS_ACTIVE) {
                    recAccPayable.Last_Account_Payable_Date__c = recAccPayable.Next_Account_Payable_Date__c;
                    recAccPayable.Next_Account_Payable_Date__c = FinancialSuiteUtils.getNextRecurringDate(recAccPayable.Next_Account_Payable_Date__c, recAccPayable.Account_Payable_Frequency__c);
                    updates.add(recAccPayable);
                }
            }
        }
        return updates;
    }
}