public with sharing class JournalEntryFromRecurJournalEntryHelper {
    //final strings
    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private final String COMPLETED = TransactionGroupActions.STATUS_COMPLETED;
    private final String FAILED = TransactionGroupActions.STATUS_FAILED;
    private final String PROCESSING = TransactionGroupActions.STATUS_PROCESSING;

    //instance members
    private List<Recurring_Journal_Entry_Line__c> recurringJELines;
    private String batchId;
    private Boolean isProductAvailable;
    private Set<Id> recurringJEIds;
    private Map<Id,Recurring_Journal_Entry__c> recurringJEById;
    private Map<Id,Transaction_Group__c> existingTxnGrpByRecJE;
    private Map<Id,Transaction_Group__c> newTxnGrpByRecJE;
    private Map<Id,Integer> linesCountByRecJE;
    private Map<Id,Integer> processedLinesCountByRecJE;
    private Set<Id> failedJELineRecJEIds;
    private AJRLogger logger;

    //contructor
    public JournalEntryFromRecurJournalEntryHelper(List<SObject> recurringJELines,String batchId, AJRLogger logger){
        this.recurringJELines = (List<Recurring_Journal_Entry_Line__c>)recurringJELines;
        this.batchId = batchId;
        this.logger = logger;
        this.isProductAvailable = Product2.SObjectType.getDescribe().isAccessible() && Recurring_Journal_Entry_Line__c.SObjectType.fields.Product__c.getDescribe().isAccessible();
        this.newTxnGrpByRecJE = new Map<Id,Transaction_Group__c>();
    }

    /**
     * this method will create and update the source records for recurring Journal Entry
     * this will be responsible for creating Journal Entry, Transaction Groups, and Journal Entry Lines
     * this will also be responsible for updating the Transaction Groups with Failed status
     */
    public void createSourceRecords(){
        fetchUniqueRecurringJEs();
        fetchExistingTransactionGroups();
        dropLinesRelatedToFailedTransactionGroups(existingTxnGrpByRecJE);
        fetchRecurringJELinesCount();
        calculateLineProcessedByRecurringJE();
        createJournalEntries();
        dropLinesRelatedToFailedTransactionGroups(newTxnGrpByRecJE);
        createJournalEntryLines();
        updateTransactionGroupsForFailedLines();
        updateTransactionGroupsWithNewLineCountLineProcessed();
        updateRecurringJournalEntries();
    }
    /**
     * fetch and store all the unique Recurring Journal Entry from the current chunk of Recurring Journal Entry Lines
     */
    private void fetchUniqueRecurringJEs(){
        recurringJEIds = new Set<Id>();
        for(Recurring_Journal_Entry_Line__c rJELine : recurringJELines){
            recurringJEIds.add(rJELine.Recurring_Journal_Entry__c);
        }
    }
    /**
     * store all the line counts by recurring Journal Entry
     * this will help us creating the recurring Transaction Groups
     */
    private void fetchRecurringJELinesCount(){
        linesCountByRecJE = new Map<Id,Integer>();
        Map<Id,AggregateResult> results = DomainUtils.getRecurringJournalEntryLinesCountByRecJE(recurringJEIds);

        for(Id recordId : results.keySet()){
            linesCountByRecJE.put(recordId,Integer.valueOf(results.get(recordId).get('lineCount')));
        }
    }
    /**
     * Fetch existing Transaction Groups to get the previously created details or to update them with latest status
     */
    private void fetchExistingTransactionGroups(){
        if(recurringJEIds != null){
            List<Transaction_Group__c> existingTxnGroup = DomainUtils.getTransactionGroupBySourceAndBatchId(recurringJEIds,batchId);
            existingTxnGrpByRecJE = new Map<Id,Transaction_Group__c>();
            for(Transaction_Group__c txnGrp : existingTxnGroup){
                existingTxnGrpByRecJE.put(txnGrp.Recurring_Journal_Entry__c, txnGrp);
            }
        }
    }

    /**
     * Drop the Recurring Account Payable Lines related to the failed Transaction Groups
     */
    private void dropLinesRelatedToFailedTransactionGroups(Map<Id, Transaction_Group__c> txnGroupByRecJEs){
        if (txnGroupByRecJEs == null || txnGroupByRecJEs.isEmpty()) {
            return;
        }

        List<Recurring_Journal_Entry_Line__c> lines = new List<Recurring_Journal_Entry_Line__c>();
        for(Recurring_Journal_Entry_Line__c line : recurringJELines){
            Transaction_Group__c txnGroup = txnGroupByRecJEs.get(line.Recurring_Journal_Entry__c);
            if (txnGroup == null || !FAILED.equalsIgnoreCase(txnGroup.Status__c)) {
                lines.add(line);
            } else {
                recurringJEIds.remove(line.Recurring_Journal_Entry__c);
            }
        }

        recurringJELines = lines;
    }

    /**
     * Method to calculate the total line processed
     * this will be used in creating the Transaction Groups
     */
    private void calculateLineProcessedByRecurringJE() {
        processedLinesCountByRecJE =  new Map<Id,Integer>();

        for(Id recJEId : existingTxnGrpByRecJE.keySet()){
            processedLinesCountByRecJE.put(recJEId,Integer.valueOf(existingTxnGrpByRecJE.get(recJEId).Lines_Processed__c));
        }

        for(Recurring_Journal_Entry_Line__c rJELine : recurringJELines){
            if(processedLinesCountByRecJE.containsKey(rJELine.Recurring_Journal_Entry__c)){
                processedLinesCountByRecJE.put(rJELine.Recurring_Journal_Entry__c,processedLinesCountByRecJE.get(rJELine.Recurring_Journal_Entry__c) + 1);
            }else{
                processedLinesCountByRecJE.put(rJELine.Recurring_Journal_Entry__c,1);
            }
        }
    }
    /**
     * Method to create the Journal Entry from the Recurring Journal Entry
     * This will also be creating new Transaction Groups for new Recurring Journal Entry
     */
    private void createJournalEntries(){
        List<Journal_Entry__c> newJE = new List<Journal_Entry__c>();
        //fetch  recurring Journal Entry
        recurringJEById = new Map<Id,Recurring_Journal_Entry__c>(DomainUtils.getRecurringJEById(recurringJEIds));
        List<Transaction_Group__c> newTxnGroups = new List<Transaction_Group__c>();
        List<Recurring_Journal_Entry__c> recurringJRs = recurringJEById.values();
        List<Recurring_Journal_Entry__c> nonExistingTxnGrpRecJEs = new List<Recurring_Journal_Entry__c>();
        
        for(Recurring_Journal_Entry__c recJE : recurringJRs){
            //indicates we already have a Journal Entry for this recurring Journal Entry
            if(!existingTxnGrpByRecJE.containsKey(recJE.Id)){
                nonExistingTxnGrpRecJEs.add(recJE);
                newJE.add(getJournalEntryFromRecJE(recJE));
            }
        }

        if(!newJE.isEmpty()){
            //save the Journal Entry
            List<Database.SaveResult> results = SFDCSecurityUtils.insertProxy(newJE,false);

            //create either failed or completed Transactions Groups based on Journal Entry record success
            for (Integer index = 0; index < results.size(); index++) {
                newTxnGroups.add(getTransactionGroup(nonExistingTxnGrpRecJEs[index].Id,results[index].getId(),results[index].isSuccess()));
                if(results[index].isSuccess()){
                    logger.logSuccess(newJE[index].Recurring_Journal_Entry__c);
                } else {
                    logger.logError(newJE[index].Recurring_Journal_Entry__c, results[index].getErrors()[0].getMessage());
                }
            }

            if(!newTxnGroups.isEmpty()){
                //insert new Transaction Groups
                List<Database.SaveResult> txnSaveResults = SFDCSecurityUtils.insertProxy(newTxnGroups,false);
                Integer recordIndex = 0;
                for(Database.SaveResult result : txnSaveResults){
                    if(result.isSuccess()){
                        newTxnGrpByRecJE.put(newTxnGroups[recordIndex].Recurring_Journal_Entry__c,newTxnGroups[recordIndex]);
                    }
                    recordIndex++;
                }
            }
        }
    }
    //return a new instance of Journal Entry originated from a Recurring Journal Entry
    private Journal_Entry__c getJournalEntryFromRecJE(Recurring_Journal_Entry__c recurringJE){
        Journal_Entry__c jE = new Journal_Entry__c();
        jE.Name = recurringJE.Name;
        jE.Journal_Date__c = recurringJE.Next_Journal_Entry_Date__c;
        jE.Recurring_Journal_Entry__c = recurringJE.Id;
        jE.Auto_Reverse__c = recurringJE.Auto_Reverse__c;
        jE.Ledger__c = recurringJE.Ledger__c;
        jE.Reference__c = recurringJE.Reference__c;
        jE.Type__c = recurringJE.Type__c;
        jE.Source__c = JournalEntryActions.SOURCE_RJE;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            jE.put('CurrencyIsoCode', recurringJE.get('CurrencyIsoCode'));
        }
        return jE;
    }
    //return a new instance of Transaction Group for provided Recurring Journal Entry and Journal Entry
    private Transaction_Group__c getTransactionGroup(Id recurringJEId, Id jEId, Boolean isSuccess){
        Transaction_Group__c result = new Transaction_Group__c();
        result.Line_Count__c = linesCountByRecJE.containsKey(recurringJEId) == true ? linesCountByRecJE.get(recurringJEId) : 0;
        result.Lines_Processed__c = processedLinesCountByRecJE.containsKey(recurringJEId) == true ? processedLinesCountByRecJE.get(recurringJEId) : 0;
        result.Batch_Id__c = batchId; 
        result.Recurring_Journal_Entry__c = recurringJEId;
        result.Journal_Entry__c = jEId;
        result.Status__c = isSuccess == true ? PROCESSING : FAILED;
        result.Ledger__c = recurringJEById.get(recurringJEId).Ledger__c;
        result.Job_Type__c = JEFromRecurringJEBatch.JOB_NAME;
        return result; 
    }
    /**
     * Create Journal Entry Lines from the Recurring Journal Entry Lines 
     * This will also responsible for updateting Transaction Group Record with the failed status if any Journal Entry Line fails
     */
    private void createJournalEntryLines(){
        List<Journal_Entry_Line__c> jELines = new List<Journal_Entry_Line__c>();
        failedJELineRecJEIds = new Set<Id>();

        //create Journal Entry Line From Recurring Journal Entry Line
        for(Recurring_Journal_Entry_Line__c recJELine : recurringJELines){
            jELines.add(getJournalEntryLineFromRecurringJELine(recurringJEById.get(recJELine.Recurring_Journal_Entry__c),recJELine));
        }

        if(!jELines.isEmpty()){
            //create Recurring Journal Entry Lines
            List<Database.SaveResult> jELinesSaveResult = SFDCSecurityUtils.insertProxy(jELines,false);

            //store failed Journal Entry Lines to update Transaction Group
            Integer recordIndex = 0;
            for(Database.SaveResult result : jELinesSaveResult){
                Id rJEId = recurringJELines[recordIndex].Recurring_Journal_Entry__c;
                if (result.isSuccess()) {
                    logger.logSuccess(rJEId);
                } else {
                    failedJELineRecJEIds.add(rJEId);
                    logger.logError(rJEId, result.getErrors()[0].getMessage());
                }
                recordIndex++;
            }
        }
    }
    //return an instance of Journal Entry Line originated from a Recurring Journal Entry Line
    private Journal_Entry_Line__c getJournalEntryLineFromRecurringJELine(Recurring_Journal_Entry__c recurringJE, Recurring_Journal_Entry_Line__c recurringJELine) {
        Id journalEntryId = (existingTxnGrpByRecJE != NULL && existingTxnGrpByRecJE.containsKey(recurringJE.Id)) ? 
                        existingTxnGrpByRecJE.get(recurringJE.Id).Journal_Entry__c : 
                        (newTxnGrpByRecJE != NULL && newTxnGrpByRecJE.containsKey(recurringJE.Id)) ? 
                        newTxnGrpByRecJE.get(recurringJE.Id).Journal_Entry__c : 
                        NULL;

        //journalEntryId Id = null indicates we don't have any Transaction Group for this Recurring Journal Entry means it should fail 
        if(journalEntryId == NULL){
            return new Journal_Entry_Line__c();
        }
        Journal_Entry_Line__c jELine = new Journal_Entry_Line__c();
        jELine.Journal_Entry__c = journalEntryId;
        jELine.Recurring_Journal_Entry_Line__c = recurringJELine.Id;
        jELine.Cash_Flow_Category__c = recurringJELine.Cash_Flow_Category__c;
        jELine.GL_Account__c = recurringJELine.GL_Account__c;
        jELine.Units__c = recurringJELine.Quantity__c;
        jELine.Project__c = recurringJELine.Project__c;
        jELine.Project_Task__c = recurringJELine.Project_Task__c;
        jELine.Reference__c = recurringJELine.Reference__c;
        jELine.GL_Account_Variable_1__c = recurringJELine.GL_Account_Variable_1__c;
        jELine.GL_Account_Variable_2__c = recurringJELine.GL_Account_Variable_2__c;
        jELine.GL_Account_Variable_3__c = recurringJELine.GL_Account_Variable_3__c;
        jELine.GL_Account_Variable_4__c = recurringJELine.GL_Account_Variable_4__c;
        jELine.Credit__c = recurringJELine.Credit__c;
        jELine.Debit__c = recurringJELine.Debit__c;
        jELine.Account__c = recurringJELine.Account__c;
        jELine.Contact__c = recurringJELine.Contact__c;
        jELine.Employee__c = recurringJELine.Employee__c;
        jELine.Description__c = recurringJELine.Description__c;
        if (isProductAvailable) {
            jELine.Product__c = recurringJELine.Product__c;
        }
        return jELine;
    }
    /**
     * When there are any failure during creating the Journal Entry Line we've to update the respective Transaction Group
     * If we found the correct Transaction Group Update the Status to Fail
     * else create a new Transaction Group with failed status
     */
    private void updateTransactionGroupsForFailedLines(){
        if(failedJELineRecJEIds != null && failedJELineRecJEIds.size() != 0){
            List<Transaction_Group__c> groupsToUpdate = new List<Transaction_Group__c>();

            for(Id recJEId : failedJELineRecJEIds){
                Transaction_Group__c txnGroup = existingTxnGrpByRecJE.containsKey(recJEId) ? 
                                                existingTxnGrpByRecJE.get(recJEId) : 
                                                newTxnGrpByRecJE.containsKey(recJEId) ? 
                                                newTxnGrpByRecJE.get(recJEId) : NULL;
                if(txnGroup != NULL){
                    //update existing record
                    txnGroup.Status__c = FAILED;
                    groupsToUpdate.add(txnGroup);
                }else{
                    //create new Transaction Group
                    groupsToUpdate.add(getTransactionGroup(recJEId,NULL,false));
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
        updates.addAll(getTransactionGroupUpdates(existingTxnGrpByRecJE));
        updates.addAll(getTransactionGroupUpdates(newTxnGrpByRecJE));

        if(!updates.isEmpty()){
            //update the Transaction Groups
            SFDCSecurityUtils.updateProxy(updates, false);
        }
    }
    private List<Transaction_Group__c> getTransactionGroupUpdates(Map<Id,Transaction_Group__c> txnGroupsByRecJE) {
        List<Transaction_Group__c> updates = new List<Transaction_Group__c>();
        for(Id recJEId : txnGroupsByRecJE.keySet()){
            Transaction_Group__c txnGroup = txnGroupsByRecJE.get(recJEId);
            //check if line count has any reference
            if(linesCountByRecJE.containsKey(recJEId)){
                txnGroup.Line_Count__c = linesCountByRecJE.get(recJEId);
            }
            //check if processed line count has any reference
            if(processedLinesCountByRecJE.containsKey(recJEId)){
                txnGroup.Lines_Processed__c = processedLinesCountByRecJE.get(recJEId);
            }
            // check if status can be updated to completed
            if (txnGroup.Line_Count__c == txnGroup.Lines_Processed__c && txnGroup.Status__c == PROCESSING) {
                txnGroup.Status__c = COMPLETED;
            }
            updates.add(txnGroup);
        }
        return updates;
    }
    private void updateRecurringJournalEntries(){
        List<Recurring_Journal_Entry__c> updates = new List<Recurring_Journal_Entry__c>();
        updates.addAll(updateCompletedRecurringJESchedules(existingTxnGrpByRecJE));
        updates.addAll(updateCompletedRecurringJESchedules(newTxnGrpByRecJE));

        if(!updates.isEmpty()){
            //update the Transaction Groups
            SFDCSecurityUtils.updateProxy(updates, false);
        }
    }
    private List<Recurring_Journal_Entry__c> updateCompletedRecurringJESchedules(Map<Id,Transaction_Group__c> txnGroupsByRecJE) {
        List<Recurring_Journal_Entry__c> updates = new List<Recurring_Journal_Entry__c>();
        for(Id recJEId : txnGroupsByRecJE.keySet()){
            if (txnGroupsByRecJE.get(recJEId).Status__c == COMPLETED) {
                Recurring_Journal_Entry__c recJE = recurringJEById.get(recJEId);
                if (recJE.Status__c == RecurringJournalEntryActions.RECURRING_STATUS_ACTIVE) {
                    recJE.Last_Journal_Entry_Date__c = recJE.Next_Journal_Entry_Date__c;
                    recJE.Next_Journal_Entry_Date__c = FinancialSuiteUtils.getNextRecurringDate(recJE.Next_Journal_Entry_Date__c, recJE.Journal_Entry_Frequency__c);
                    updates.add(recJE);
                }
            }
        }
        return updates;
    }
}