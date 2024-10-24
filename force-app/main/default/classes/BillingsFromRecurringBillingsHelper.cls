public with sharing class BillingsFromRecurringBillingsHelper {
    //final strings
    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private final String COMPLETED = TransactionGroupActions.STATUS_COMPLETED;
    private final String FAILED = TransactionGroupActions.STATUS_FAILED;
    private final String PROCESSING = TransactionGroupActions.STATUS_PROCESSING;

    //instance members
    private List<Recurring_Billing_Line__c> recBillingLines;
    private String batchId;
    private Boolean isOpportunityAvailable;
    private Boolean isProductAvailable;
    private Set<Id> recBillingIds;
    private Map<Id,Recurring_Billing__c> recurringBillingsById;
    private Map<Id,Transaction_Group__c> existingTxnGrpByRecBills;
    private Map<Id,Transaction_Group__c> newTxnGrpByRecBills;
    private Map<Id,Integer> linesCountByRecBilling;
    private Map<Id,Integer> processedLinesCountByRecBilling;
    private Set<Id> failedBillingLineRecBillIds;

    AJRLogger logger;
    //contructor
    public BillingsFromRecurringBillingsHelper(List<SObject> recBillingLines,String batchId, AJRLogger logger){
        this.recBillingLines = (List<Recurring_Billing_Line__c>)recBillingLines;
        this.batchId = batchId;
        this.isOpportunityAvailable = Schema.SObjectType.Opportunity.isAccessible();
        this.isProductAvailable = Product2.SObjectType.getDescribe().isAccessible() && Recurring_Billing_Line__c.SObjectType.fields.Product__c.getDescribe().isAccessible();
        this.newTxnGrpByRecBills = new Map<Id,Transaction_Group__c>();
        this.logger = logger;
    }

    /**
     * this method will create and update the source records for recurring billings
     * this will be responsible for creating Billings, Transaction Groups, and Billing Lines
     * this will also be responsible for updating the Transaction Groups with Failed status
     */
    public void createSourceRecords(){
        fetchUniqueRecurringBillings();
        fetchExistingTransactionGroups();
        dropLinesRelatedToFailedTransactionGroups(existingTxnGrpByRecBills);
        fetchRecurringBillingLinesCount();
        calculateLineProcessedByRecurringBillings();
        createBillings();
        dropLinesRelatedToFailedTransactionGroups(newTxnGrpByRecBills);
        createBillingLines();
        updateTransactionGroupsForFailedLines();
        updateTransactionGroupsWithNewLineCountLineProcessed();
        updateRecurringBillings();
    }
    /**
     * fetch and store all the unique Recurring Billings from the current chunk of Recurring Billing Lines
     */
    private void fetchUniqueRecurringBillings(){
        recBillingIds = new Set<Id>();
        for(Recurring_Billing_Line__c recBillLine : recBillingLines){
            recBillingIds.add(recBillLine.Recurring_Billing__c);
        }
    }
    /**
     * store all the line counts by recurring billings
     * this will help us creating the recurring Transaction Groups
     */
    private void fetchRecurringBillingLinesCount(){
        linesCountByRecBilling = new Map<Id,Integer>();
        Map<Id,AggregateResult> results = DomainUtils.getRecurringBillingLinesCountByRecBilling(recBillingIds);

        for(Id recordId : results.keySet()){
            linesCountByRecBilling.put(recordId,Integer.valueOf(results.get(recordId).get('lineCount')));
        }
    }
    /**
     * Fetch existing Transaction Groups to get the previously created details or to update them with latest status
     */
    private void fetchExistingTransactionGroups(){
        if(recBillingIds != null){
            List<Transaction_Group__c> existingTxnGroup = DomainUtils.getTransactionGroupBySourceAndBatchId(recBillingIds,batchId);
            existingTxnGrpByRecBills = new Map<Id,Transaction_Group__c>();
            for(Transaction_Group__c txnGrp : existingTxnGroup){
                existingTxnGrpByRecBills.put(txnGrp.Recurring_Billing__c, txnGrp);
            }
        }
    }

    /**
     * Drop the Recurring Account Payable Lines related to the failed Transaction Groups
     */
    private void dropLinesRelatedToFailedTransactionGroups(Map<Id, Transaction_Group__c> txnGroupByRecBillings){
        if (txnGroupByRecBillings == null || txnGroupByRecBillings.isEmpty()) {
            return;
        }

        List<Recurring_Billing_Line__c> lines = new List<Recurring_Billing_Line__c>();
        for(Recurring_Billing_Line__c line : recBillingLines){
            Transaction_Group__c txnGroup = txnGroupByRecBillings.get(line.Recurring_Billing__c);
            if (txnGroup == null || !FAILED.equalsIgnoreCase(txnGroup.Status__c)) {
                lines.add(line);
            } else {
                recBillingIds.remove(line.Recurring_Billing__c);
            }
        }

        recBillingLines = lines;
    }

    /**
     * Method to calculate the total line processed
     * this will be used in creating the Transaction Groups
     */
    private void calculateLineProcessedByRecurringBillings() {
        processedLinesCountByRecBilling =  new Map<Id,Integer>();

        for(Id recBillId : existingTxnGrpByRecBills.keySet()){
            processedLinesCountByRecBilling.put(recBillId,Integer.valueOf(existingTxnGrpByRecBills.get(recBillId).Lines_Processed__c));
        }

        for(Recurring_Billing_Line__c recBillLine : recBillingLines){
            if(processedLinesCountByRecBilling.containsKey(recBillLine.Recurring_Billing__c)){
                processedLinesCountByRecBilling.put(recBillLine.Recurring_Billing__c,processedLinesCountByRecBilling.get(recBillLine.Recurring_Billing__c) + 1);
            }else{
                processedLinesCountByRecBilling.put(recBillLine.Recurring_Billing__c,1);
            }
        }
    }
    /**
     * Method to create the Billings from the Recurring Billings
     * This will also be creating new Transaction Groups for new Recurring Billings
     */
    private void createBillings(){
        List<Billing__c> newBillings = new List<Billing__c>();
        //fetch  recurring billings
        recurringBillingsById = new Map<Id,Recurring_Billing__c>(DomainUtils.getRecurringBillingsById(recBillingIds,isOpportunityAvailable));
        List<Transaction_Group__c> newTxnGroups = new List<Transaction_Group__c>();
        List<Recurring_Billing__c> recurringBillings = recurringBillingsById.values();
		List<Recurring_Billing__c> nonExistingTxnGrpRecBillings = new List<Recurring_Billing__c>();
        
        for(Recurring_Billing__c recBilling : recurringBillings){
            //indicates we already have a billing for this recurring billing
            if(!existingTxnGrpByRecBills.containsKey(recBilling.Id)){
                nonExistingTxnGrpRecBillings.add(recBilling);
                newBillings.add(getBillingFromRcurringBilling(recBilling));
            }
        }

        if(!newBillings.isEmpty()){
            //save the billings
            List<Database.SaveResult> results = SFDCSecurityUtils.insertProxy(newBillings,false);

            //create either failed or completed Transactions Groups based on billing record success
            for (Integer index = 0; index < results.size(); index++) {
                newTxnGroups.add(getTransactionGroup(nonExistingTxnGrpRecBillings[index].Id,results[index].getId(),results[index].isSuccess()));
                if(results[index].isSuccess()){
                    logger.logSuccess(newBillings[index].Recurring_Billing__c);
                } else {
                    logger.logError(newBillings[index].Recurring_Billing__c, results[index].getErrors()[0].getMessage());
                }
            }

            if(!newTxnGroups.isEmpty()){
                //insert new Transaction Groups
                List<Database.SaveResult> txnSaveResults = SFDCSecurityUtils.insertProxy(newTxnGroups,false);
                Integer recordIndex = 0;
                for(Database.SaveResult result : txnSaveResults){
                    if(result.isSuccess()){
                        newTxnGrpByRecBills.put(newTxnGroups[recordIndex].Recurring_Billing__c,newTxnGroups[recordIndex]);
                    }
                    recordIndex++;
                }
            }
        }
    }
    //return a new instance of Billing originated from a Recurring Billing
    private Billing__c getBillingFromRcurringBilling(Recurring_Billing__c rBill){
        Billing__c bill = new Billing__c();
        bill.Customer__c = rBill.Customer__c;
        bill.Customer__r = rBill.Customer__r;
        bill.Opportunity__c =  isOpportunityAvailable ? rBill.Opportunity__c : NULL;
        bill.Date__c = rBill.Next_Billing_Date__c;
        bill.Recurring_Billing__c = rBill.Id;
        bill.Ledger__c = (rBill.Ledger__c == NULL) ? LedgerHandler.getLegacyDefaultLedgerId() : rBill.Ledger__c;
        bill.Accounting_Period__c = NULL;
        bill.Billing_Contact__c = rBill.Billing_Contact__c;
        bill.PO_Number__c = rBill.PO_Number__c;
        bill.Billing_Comment__c = rBill.Comment__c;

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            bill.put('CurrencyIsoCode', rBill.get('currencyIsoCode'));
        }
        return bill;
    }
    //return a new instance of Transaction Group for provided Recurring Billing and Billing
    private Transaction_Group__c getTransactionGroup(Id recBillingId, Id billingId, Boolean isSuccess){
        Transaction_Group__c result = new Transaction_Group__c();
        result.Line_Count__c = linesCountByRecBilling.containsKey(recBillingId) == true ? linesCountByRecBilling.get(recBillingId) : 0;
        result.Lines_Processed__c = processedLinesCountByRecBilling.containsKey(recBillingId) == true ? processedLinesCountByRecBilling.get(recBillingId) : 0;
        result.Batch_Id__c = batchId; 
        result.Recurring_Billing__c = recBillingId;
        result.Billing__c = billingId;
        result.Status__c = isSuccess == true ? PROCESSING : FAILED;
        result.Ledger__c = recurringBillingsById.get(recBillingId).Ledger__c;
        result.Job_Type__c = BillingFromRecurringBillingBatch.JOB_NAME;
        return result; 
    }
    /**
     * Create Billing Lines from the Recurring Billing Lines 
     * This will also responsible for updateting Transaction Group Record with the failed status if any Billing Line fails
     */
    private void createBillingLines(){
        List<Billing_Line__c> billingLines = new List<Billing_Line__c>();
        failedBillingLineRecBillIds = new Set<Id>();

        //create Billing Line From Recurring Billing Line
        for(Recurring_Billing_Line__c recBill : recBillingLines){
            billingLines.add(getBillingLineFromRecBillingLine(recurringBillingsById.get(recBill.Recurring_Billing__c),recBill));
        }

        if(!billingLines.isEmpty()){
            //create Recurring Billing Lines
            List<Database.SaveResult> billingLineSaveResult = SFDCSecurityUtils.insertProxy(billingLines,false);

            //store failed Billing Lines to update Transaction Group
            Integer recordIndex = 0;
            for(Database.SaveResult result : billingLineSaveResult){
                Id rBillId = recBillingLines[recordIndex].Recurring_Billing__c;
                if (result.isSuccess()) {
                    logger.logSuccess(rBillId);
                } else {
                    failedBillingLineRecBillIds.add(rBillId);
                    logger.logError(rBillId, result.getErrors()[0].getMessage());
                }
                recordIndex++;
            }
        }
    }
    //return an instance of Billing Line originated from a Recurring Billing Line
    private Billing_Line__c getBillingLineFromRecBillingLine(Recurring_Billing__c rBill, Recurring_Billing_Line__c rBillLine) {
        Id billingId = (existingTxnGrpByRecBills != NULL && existingTxnGrpByRecBills.containsKey(rBill.Id)) ? 
                        existingTxnGrpByRecBills.get(rBill.Id).Billing__c : 
                        (newTxnGrpByRecBills != NULL && newTxnGrpByRecBills.containsKey(rBill.Id)) ? 
                        newTxnGrpByRecBills.get(rBill.Id).Billing__c : 
                        NULL;

        //billing Id = null indicates we don't have any Transaction Group for this Recurring Billing means it should fail 
        if(billingId == NULL){
            return new Billing_Line__c();
        }
        Billing_Line__c billLine = new Billing_Line__c();
        billLine.Billing__c = billingId;
        billLine.Recurring_Billing_Line__c = rBillLine.Id;
        billLine.Revenue_GL_Account__c = rBillLine.Revenue_GL_Account__c;
        billLine.Opportunity_Product_Id__c = rBillLine.Opportunity_Product_Id__c;
        billLine.List_Price__c = rBillLine.List_Price__c;
        billLine.Date__c = rBill.Next_Billing_Date__c;
        billLine.Rate__c = rBillLine.Rate__c ?? 0;
        billLine.Hours_Units__c = rBillLine.Quantity__c;
        billLine.Tax_Amount2__c = rBillLine.Tax_Amount__c;
        billLine.Tax_Group__c = rBillLine.Tax_Group__c;
        billLine.Project__c = rBillLine.Project__c;
        billLine.Project_Task__c = rBillLine.Project_Task__c;
        billLine.Comment__c = rBillLine.Comment__c;
        billLine.GL_Account_Variable_1__c = rBillLine.GL_Account_Variable_1__c;
        billLine.GL_Account_Variable_2__c = rBillLine.GL_Account_Variable_2__c;
        billLine.GL_Account_Variable_3__c = rBillLine.GL_Account_Variable_3__c;
        billLine.GL_Account_Variable_4__c = rBillLine.GL_Account_Variable_4__c;
        if (isProductAvailable) {
            billLine.Product__c = rBillLine.Product__c;
            billLine.Product__r = rBillLine.Product__r;
        }
        return billLine;
    }
    /**
     * When there are any failure during creating the Billing Line we've to update the respective Transaction Group
     * If we found the correct Transaction Group Update the Status to Fail
     * else create a new Transaction Group with failed status
     */
    private void updateTransactionGroupsForFailedLines(){
        if(failedBillingLineRecBillIds != null && failedBillingLineRecBillIds.size() != 0){
            List<Transaction_Group__c> groupsToUpdate = new List<Transaction_Group__c>();

            for(Id recBillId : failedBillingLineRecBillIds){
                Transaction_Group__c txnGroup = existingTxnGrpByRecBills.containsKey(recBillId) ? 
                                                existingTxnGrpByRecBills.get(recBillId) : 
                                                newTxnGrpByRecBills.containsKey(recBillId) ? 
                                                newTxnGrpByRecBills.get(recBillId) : NULL;
                if(txnGroup != NULL){
                    //update existing record
                    txnGroup.Status__c = FAILED;
                    groupsToUpdate.add(txnGroup);
                }else{
                    //create new Transaction Group
                    groupsToUpdate.add(getTransactionGroup(recBillId,NULL,false));
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
        updates.addAll(getTransactionGroupUpdates(existingTxnGrpByRecBills));
        updates.addAll(getTransactionGroupUpdates(newTxnGrpByRecBills));

        if(!updates.isEmpty()){
            //update the Transaction Groups
            SFDCSecurityUtils.updateProxy(updates, false);
        }
    }

    private List<Transaction_Group__c> getTransactionGroupUpdates(Map<Id,Transaction_Group__c> txnGroupsByRecBilling) {
        List<Transaction_Group__c> updates = new List<Transaction_Group__c>();
        for(Id recBillId : txnGroupsByRecBilling.keySet()){
            Transaction_Group__c txnGroup = txnGroupsByRecBilling.get(recBillId);
            //check if line count has any reference
            if(linesCountByRecBilling.containsKey(recBillId)){
                txnGroup.Line_Count__c = linesCountByRecBilling.get(recBillId);
            }
            //check if processed line count has any reference
            if(processedLinesCountByRecBilling.containsKey(recBillId)){
                txnGroup.Lines_Processed__c = processedLinesCountByRecBilling.get(recBillId);
            }
            // check if status can be updated to completed
            if (txnGroup.Line_Count__c == txnGroup.Lines_Processed__c && txnGroup.Status__c == PROCESSING) {
                txnGroup.Status__c = COMPLETED;
            }
            updates.add(txnGroup);
        }
        return updates;
    }

    private void updateRecurringBillings(){
        List<Recurring_Billing__c> updates = new List<Recurring_Billing__c>();
        updates.addAll(updateCompletedRecurringBillingSchedules(existingTxnGrpByRecBills));
        updates.addAll(updateCompletedRecurringBillingSchedules(newTxnGrpByRecBills));

        if(!updates.isEmpty()){
            //update the Transaction Groups
            SFDCSecurityUtils.updateProxy(updates, false);
        }
    }

    private List<Recurring_Billing__c> updateCompletedRecurringBillingSchedules(Map<Id,Transaction_Group__c> txnGroupsByRecBilling) {
        List<Recurring_Billing__c> updates = new List<Recurring_Billing__c>();
        for(Id recBillId : txnGroupsByRecBilling.keySet()){
            if (txnGroupsByRecBilling.get(recBillId).Status__c == COMPLETED) {
                Recurring_Billing__c recBill = recurringBillingsById.get(recBillId);
                if (recBill.Status__c == RecurringBillingActions.RECURRING_STATUS_ACTIVE) {
                    recBill.Last_Billing_Date__c = recBill.Next_Billing_Date__c;
                    recBill.Next_Billing_Date__c = FinancialSuiteUtils.getNextRecurringDate(recBill.Next_Billing_Date__c, recBill.Billing_Frequency__c);
                    updates.add(recBill);
                }
            }
        }
        return updates;
    }

}