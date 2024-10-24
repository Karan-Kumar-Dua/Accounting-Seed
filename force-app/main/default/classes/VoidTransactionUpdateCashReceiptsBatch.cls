public with sharing class VoidTransactionUpdateCashReceiptsBatch implements Database.Batchable<sObject>, Database.Stateful {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    //void data with related cash receipts
    private Map<Id,CashReceiptVoidHelper.VoidData> crWithVoidData;
    //an instance of accouting setting 
    private Accounting_Settings__c main;
    //processed bcrs with their cash receipts
    private Map<Id,Set<Id>> bcrsWithCrId;
    //failed cash receipt ids
    private Set<Id> failedCrIds;
    private String query;
    private AJRLogger logger; 

    public VoidTransactionUpdateCashReceiptsBatch(
            Map<Id,CashReceiptVoidHelper.VoidData> crWithVoidData, 
            Set<Id> failedCrIds,
            Map<Id,Set<Id>> bcrsWithCrId,
            AJRLogger logger) {
        this.crWithVoidData = crWithVoidData;
        this.failedCrIds = failedCrIds;
        this.bcrsWithCrId = bcrsWithCrId;
        this.main = AccountingSettingsHandler.getAccountingSettings();
        this.logger = logger;
        //prepare query to get child Transactions
        this.query = 'SELECT Id, ' +
                            PACKAGE_QUALIFIER + 'Void__c, ' +
                            PACKAGE_QUALIFIER + 'Void_Date__c, ' +
                            PACKAGE_QUALIFIER + 'Void_Description__c, ' +
                            PACKAGE_QUALIFIER + 'Cash_Flow_Category__c, ' +
                            PACKAGE_QUALIFIER + 'Bank_Reconciliation__c, ' +
                            PACKAGE_QUALIFIER + 'Receipt_Date__c, ' +
                            PACKAGE_QUALIFIER + 'Status__c, ' +
                            PACKAGE_QUALIFIER + 'Ledger__c, ' +
                            PACKAGE_QUALIFIER + 'Bank_Deposit__c, ' +
                            PACKAGE_QUALIFIER + 'Bank_Deposit__r.'+ PACKAGE_QUALIFIER + 'Bank_Reconciliation__c, ' +
                            '(SELECT Id, ' +
                                    PACKAGE_QUALIFIER + 'GL_Account__c, ' +
                                    PACKAGE_QUALIFIER + 'Account__c, ' +
                                    PACKAGE_QUALIFIER + 'Employee__c, ' +
                                    PACKAGE_QUALIFIER + 'Contact__c, ' +
                                    PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c, ' +
                                    PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c, ' +
                                    PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c, ' +
                                    PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c, ' +
                                    PACKAGE_QUALIFIER + 'Project__c, ' +
                                    PACKAGE_QUALIFIER + 'Project_Task__c, ' +
                                    PACKAGE_QUALIFIER + 'Cash_Receipt__c, ' +
                                    PACKAGE_QUALIFIER + 'Cash_Receipt__r.' +PACKAGE_QUALIFIER+ 'Ledger__c, ' +
                                    PACKAGE_QUALIFIER + 'Amount__c, ' +
                                    PACKAGE_QUALIFIER + 'Ledger__c ' +
                                'FROM ' + PACKAGE_QUALIFIER + 'Transactions__r '+
                            '), '+
                            '(SELECT Id, ' +
                                    PACKAGE_QUALIFIER + 'Status__c ' +
                                'FROM ' + PACKAGE_QUALIFIER + 'Payment_Activities__r '+
                                'WHERE ' + PACKAGE_QUALIFIER + 'Status__c != \'' + PaymentActivityHelper.ERROR_STATUS + '\' '+
                            ') '+
                    'FROM ' + PACKAGE_QUALIFIER + 'Cash_Receipt__c ' +
                    'WHERE Id IN  :genericIdSet';
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query, crWithVoidData.keySet());
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        //set a save point to get the rollback done in case of failure
        Savepoint sp = Database.setSavepoint();
        try{
            List<Transaction__c> counterTransactions = new List<Transaction__c>();
            List<Payment_Activity__c> paymentActivities = new List<Payment_Activity__c>();
            Set<Id> bankDepositIds = new Set<Id>();

            // loop through the cash receipts to update the void details and get the counter transactions
            for(Cash_Receipt__c cashReceipt : (List<Cash_Receipt__c>) scope){
                CashReceiptVoid.ValidationResult validationResult = CashReceiptVoid.validateCashReceipt(cashReceipt, crWithVoidData.get(cashReceipt.Id));
                if(validationResult.ok && cashReceipt.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED){
                    if(cashReceipt.Transactions__r != null && !cashReceipt.Transactions__r.isEmpty()){
                        //use public property of CashReceiptVoid class to get counter transactions
                        counterTransactions.addAll(getCounterTransactions(cashReceipt,cashReceipt.Transactions__r));
                    }
                    if(cashReceipt.Payment_Activities__r != null && !cashReceipt.Payment_Activities__r.isEmpty()){
                        //collect all the payment activity
                        paymentActivities.addAll(cashReceipt.Payment_Activities__r);
                    }
                    cashReceipt.Void__c = true;
                    cashReceipt.Void_Date__c = crWithVoidData.get(cashReceipt.Id).voidReceiptDate;
                    cashReceipt.Void_Description__c = crWithVoidData.get(cashReceipt.Id).description;
                    cashReceipt.Cash_Flow_Category__c = cashReceipt.Cash_Flow_Category__c == null ? crWithVoidData.get(cashReceipt.Id).cashFlowCategory : cashReceipt.Cash_Flow_Category__c;
                    if(cashReceipt.Bank_Deposit__c != null){
                        bankDepositIds.add(cashReceipt.Bank_Deposit__c);
                        cashReceipt.Bank_Deposit__c = null;
                    }
                } else if (!validationResult.ok) {
                    // the cr is not valid and additional cleanup may be needed
                    failedCrIds.add(cashReceipt.Id);
                    logger.logError(cashReceipt.Id, validationResult.error);
                }   
            }

            //do required chhecks and create the counter transactions
            if(!counterTransactions.isEmpty()){
                CubeBuilder.isEnabledCashFlowStatement = main.Enable_Cash_Flow_Statement__c;
                TransactionActions.createTransactions(counterTransactions);
                CubeBuilder.isEnabledCashFlowStatement = false;
                TriggerObserver.reset();
            }

            //unlock cash flow category field
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Void__c,
                    Cash_Receipt__c.Void_Date__c
                }
            );

            //update the cash receipts
            SFDCSecurityUtils.updateCheckCRUDAndFLS(scope, new List<String> {
                PACKAGE_QUALIFIER + 'Void__c', 
                PACKAGE_QUALIFIER + 'Void_Date__c',
                PACKAGE_QUALIFIER + 'Void_Description__c',
                PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
                PACKAGE_QUALIFIER + 'Bank_Deposit__c'
            });


            //update bank deposits total amount
            if(!bankDepositIds.isEmpty() && bankDepositIds.size() > 0){
                for(Id bankDepositId : bankDepositIds){
                    BankDepositHandler handler = new BankDepositHandler(bankDepositId);
                    handler.calculateTotalAmount();
                }
            }
            //update payment activities
            if(!paymentActivities.isEmpty()){
                //update the status to void
                for(Payment_Activity__c activity : paymentActivities){
                    if (activity.Status__c != PaymentActivityHelper.ERROR_STATUS) {
                        activity.Status__c = PaymentActivityHelper.VOID_STATUS;
                    }
                }
                //update the Payment activity
                SFDCSecurityUtils.updateCheckCRUDAndFLS(paymentActivities, new List<String>{
                    'Status__c'
                });
            }
            logger.logSuccess(scope[0].Id);

        }catch(Exception e){
            //if fails put them into the failed cr ids to further clean the records
            for(Cash_Receipt__c cashReceipt : (List<Cash_Receipt__c>) scope){
                failedCrIds.add(cashReceipt.Id);
                logger.logError(cashReceipt.Id, e.getMessage());
            }
            //rollback the transaction
            Database.rollback(sp);
        }
    }
    private List<Transaction__c> getCounterTransactions(Cash_Receipt__c cashReceipt, List<Transaction__c> source){
        List<Transaction__c> counterTransactions = new List<Transaction__c>();
        //get the counter transactions
        for(Transaction__c txn : source){
            counterTransactions.add(new CashReceiptVoid().initializeVoidData(crWithVoidData.get(cashReceipt.Id)).createCounterTransaction(cashReceipt,txn));
        }
        return counterTransactions;
    }
    public void finish (Database.BatchableContext BC) {
        logger.save();
        Set<Id> bcrToDelete = new Set<Id>();
        
        if(bcrsWithCrId != null && !bcrsWithCrId.isEmpty()){
            //filter bcrs to delete them in the next batch
            for(Id crId : failedCrIds){
                bcrToDelete.addAll(bcrsWithCrId.get(crId));
            }
        }
        
        if(!bcrToDelete.isEmpty() && bcrToDelete.size() != 0){
            //run next clean up batch
            Database.executeBatch(new FailedBCRCleanupBatch(bcrToDelete));
        }
    }
}