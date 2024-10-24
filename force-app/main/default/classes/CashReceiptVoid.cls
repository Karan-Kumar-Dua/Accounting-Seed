public with sharing class CashReceiptVoid {
    // private instance members
    private String crId;
    private Cash_Receipt__c cashReceipt;
    private CashReceiptVoidHelper.VoidData crVoidData;
    private Accounting_Settings__c main;
    private Payment_Activity__c activity;
    private Boolean isCashFlowStatementEnabled;
    private AccountingPeriodHandler handler;
    private Id bankDepositId;

    //private final strings
    private final Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    private static final Integer BATCH_SIZE = 1;
    private static final String POSTED_ERROR_MESSAGE = Label.ERR_THE_CR_MUST_BE_POSTED;
    private static final String VOIDED_ERROR_MESSAGE = Label.ERR_THE_CR_WAS_ALREADY_VOIDED;
    private static final String ASSOCIATED_WITH_BANK_TRANSACTION_ERROR_MESSAGE = Label.ERR_THE_CR_IS_NOT_LINKED_TO_BANK_RECONCILIATION;
    private static final String NO_PERIOD_ERROR_MESSAGE = Label.ERR_NO_PERIOD_FOR_SELECTED_VOID_RECEIPT_DATE;
    private static final String TOO_EARLY_VOIDED_DATE = Label.ERR_THE_VOID_DATE_CAN_NOT_EARLIER_THAN_RECEIPT_DATE;
    private static final String CASH_FLOW_ERROR = Label.ERR_CASH_FLOW_CATEGORY_MUST_SPECIFIED_WHEN_CFS_ENABLED;
    private static final String STATUS_POSTED = Label.COMMON_POSTED;
    private static final String NO_RECORD_FOUND = Label.ERR_NO_RECORD_FOUND;
    private static final String COMMON_VOID = Label.COMMON_VOID;
    private static final String CASH_RECEIPT_VOID_FAILED_BANK_DEPOSIT_IS_CLEARED = Label.ERR_CASH_RECEIPT_VOID_FAILED_BANK_DEPOSIT_IS_CLEARED;
    private static final Integer MAX_BCR_PROCESS_LIMIT = 200;
    private static final String STATUS_OPEN = 'Open';

    //contructor
    public CashReceiptVoid(Id crId, CashReceiptVoidHelper.VoidData crVoidData){
        this.crId = crId;
        this.crVoidData = crVoidData;
        this.main = AccountingSettingsHandler.getAccountingSettings();
        this.isCashFlowStatementEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
        this.handler = AccountingPeriodHandler.getInstance();
    }

    //exception class to handle only void exceptions
    public with sharing class CashReceiptVoidException extends Exception{} 

    public with sharing class ValidationResult {
        public Boolean ok;
        public String error;
        public ValidationResult(Boolean ok, String error){
            this.ok = ok;
            this.error = error;
        }
    }

    //contructor
    public CashReceiptVoid(){
        this.main = AccountingSettingsHandler.getAccountingSettings();
        this.isCashFlowStatementEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
        this.handler = AccountingPeriodHandler.getInstance();
    } 


     /**
     * Only performs the void internally in salesforce. The payments will not be
     * voided in the external system (ie. Cardknox, Stripe, etc.).
     */
    public void asyncVoidCashReceiptInternally(List<CashReceiptVoidHelper.VoidData> voidDataList) {
        Map<Id,CashReceiptVoidHelper.VoidData> voidDataMap = new Map<Id,CashReceiptVoidHelper.VoidData>();

        //prepare map of cr id and it's void data
        for(CashReceiptVoidHelper.VoidData voidData : voidDataList){
            voidDataMap.put(voidData.cashReceiptId, voidData);
        }

        //execute the batch
        if(!voidDataMap.isEmpty()){
            Database.executeBatch(new CashReceiptVoidBCRBatch(voidDataMap,VoidExternalTransactionBatch.getLogger()));
        }
    }

    /**
     * This will be responsible to fetch, update, validate and create compensating trnsactions for the CR
     */
    public void voidCashReceipt(CashReceiptVoidHelper.VoidData crVoidData){
        initializeVoidData(crVoidData);
        fetchCashReceipts();
        validateCashReceipt(cashReceipt);
        Boolean isBatchRunning = processBCRAsynchronouslyIfCrossesMaxLimit();
        if(!isBatchRunning){
            fetchPaymentActivity();
            voidTransactionInExternalSystem();
            Savepoint sp = Database.setSavepoint();
            try {
                updateCashReceipt(); // this must be run first because llp posting logic depends on CR being updated
                createCompensatingBCR();
                createCompensatingTransactions();
                updatePaymentActivity();
                updateBankDeposit();
            }catch (DmlException dmlExp) {
                Database.rollback(sp);
                throw new CashReceiptVoidException(dmlExp.getDmlMessage(0));
            }catch (Exception e) {
                Database.rollback(sp);
                throw new CashReceiptVoidException(e.getMessage());
            }
            Database.releaseSavepoint(sp);
        }
    }
    public CashReceiptVoid initializeVoidData(CashReceiptVoidHelper.VoidData crVoidData){
        this.crVoidData = crVoidData;
        this.crId = crVoidData.cashReceiptId;
        return this;
    }
    /**
     * Check all the required validations criteria and throw errors accordingly
     */
    public Boolean validateCashReceipt(Cash_Receipt__c cReceipt){
        //validations
        if(cReceipt == null){
            throw new CashReceiptVoidException(NO_RECORD_FOUND);
        }else if(cReceipt.Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED){
            throw new CashReceiptVoidException(POSTED_ERROR_MESSAGE);
        }else if(cReceipt.Void__c == true){
            throw new CashReceiptVoidException(VOIDED_ERROR_MESSAGE);
        }else if(cReceipt.Bank_Reconciliation__c != null){
            throw new CashReceiptVoidException(ASSOCIATED_WITH_BANK_TRANSACTION_ERROR_MESSAGE);
        }else if(handler.getAccountingPeriodByDateAndStatus(crVoidData.voidReceiptDate,STATUS_OPEN) == null || 
            handler.isConsideredOpen(handler.getAccountingPeriodByDate(crVoidData.voidReceiptDate)?.Id, Cash_Receipt__c.sObjectType) == false){
            throw new CashReceiptVoidException(NO_PERIOD_ERROR_MESSAGE);
        }else if(crVoidData.voidReceiptDate < cReceipt.Receipt_Date__c){
            throw new CashReceiptVoidException(TOO_EARLY_VOIDED_DATE);
        }else if(isCashFlowStatementEnabled && cReceipt.Cash_Flow_Category__c == null && String.isEmpty(crVoidData.cashFlowCategory)){
            throw new CashReceiptVoidException(CASH_FLOW_ERROR);
        }else if(cReceipt.Bank_Deposit__c != null && cReceipt.Bank_Deposit__r.Bank_Reconciliation__c != null){
            throw new CashReceiptVoidException(CASH_RECEIPT_VOID_FAILED_BANK_DEPOSIT_IS_CLEARED);
        }
        return true;
    }

    /**
     * Check if criteria to void are met.
     */
    public static ValidationResult validateCashReceipt(Cash_Receipt__c cr, CashReceiptVoidHelper.VoidData voidData){
        if(cr == null){
            return new ValidationResult(false, NO_RECORD_FOUND);
        }else if(cr.Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED){
            return new ValidationResult(false, POSTED_ERROR_MESSAGE);
        }else if(cr.Void__c == true){
            return new ValidationResult(false, VOIDED_ERROR_MESSAGE);
        }else if(cr.Bank_Reconciliation__c != null){
            return new ValidationResult(false, ASSOCIATED_WITH_BANK_TRANSACTION_ERROR_MESSAGE);
        }else if(AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(voidData.voidReceiptDate) == null){
            return new ValidationResult(false, NO_PERIOD_ERROR_MESSAGE);
        }else if(voidData.voidReceiptDate < cr.Receipt_Date__c){
            return new ValidationResult(false, TOO_EARLY_VOIDED_DATE);
        }else if(AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c && cr.Cash_Flow_Category__c == null && String.isEmpty(voidData.cashFlowCategory)){
            return new ValidationResult(false, CASH_FLOW_ERROR);
        }
        return new ValidationResult(true, null);
    }

    /**
     * Check if criteria to void are met. This variation uses reference fields to access the 
     * Cash Receipt data, so make sure to add them to your query. 
     */
    public static ValidationResult validateCashReceipt(Billing_Cash_Receipt__c bcr, CashReceiptVoidHelper.VoidData voidData){
        Cash_Receipt__c cr = bcr.Cash_Receipt__c == null ? null : new Cash_Receipt__c(
            Status__c = bcr.Cash_Receipt__r.Status__c,
            Void__c = bcr.Cash_Receipt__r.Void__c,
            Bank_Reconciliation__c = bcr.Cash_Receipt__r.Bank_Reconciliation__c,
            Receipt_Date__c = bcr.Cash_Receipt__r.Receipt_Date__c,
            Cash_Flow_Category__c = bcr.Cash_Receipt__r.Cash_Flow_Category__c
        );

        return validateCashReceipt(cr, voidData);
    }

    /**
     * prcess bcr asyncronously if the total bcrs attached to a cr crosses the max bcr limit
     * return true or false
     * True represent batch is running 
     * False represent records can be processed syyncronously
     */
    private Boolean processBCRAsynchronouslyIfCrossesMaxLimit(){
        if(cashReceipt.Number_of_Billing_Cash_Receipts__c > MAX_BCR_PROCESS_LIMIT){
            Database.executeBatch(new VoidExternalTransactionBatch(new Map<Id,CashReceiptVoidHelper.VoidData> {
                crVoidData.cashReceiptId => crVoidData
            }),BATCH_SIZE);
            return true;
        }
        return false;
    }
    /**
     * If the payment is found in the cardknox void it
     */
    public void voidTransactionInExternalSystem(){  
        // 1. no activity means the payment is not related to any payment in an external system
        // 2. voids are not currently supported by our stripe integration
        if(activity == null || activity.Payment_Method__r.Payment_Processor__r.Type__c == PaymentProcessorActions.STRIPE_TYPE){
            return;
        }

        //create instance of payment gateway
        PaymentGateway gtwy = new PaymentGateway();
        
        if(!Test.isRunningTest()){
            //use void transaction method of payment gateway to void the transaction
            gtwy.voidTransaction(activity);
        }
    }
    /**
     * Create the compensating Billing Cash Receipts for the CR
     */
    private void createCompensatingBCR(){
        List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

        //fetch existing BCR
        for(Billing_Cash_Receipt__c bcr : fetchCashReceiptsBCRs()){
            billingCashReceipts.add(createCounterBCR(bcr));
        }
        if(!billingCashReceipts.isEmpty()){
            //insert the counter BCR
            SFDCSecurityUtils.insertProxy(billingCashReceipts);
        }
    }
    //Billing Cash Receipt creation helper method
    public Billing_Cash_Receipt__c createCounterBCR(Billing_Cash_Receipt__c sourceBcr){
        Billing_Cash_Receipt__c counterBcr = new Billing_Cash_Receipt__c();
        Accounting_Period__c acctPeriod = handler.getAccountingPeriodByDate(crVoidData.voidReceiptDate);

        //populate the counter fields
        counterBcr.Cash_Receipt__c = crVoidData.cashReceiptId;
        counterBcr.Accounting_Period__c = acctPeriod != null ? acctPeriod.Id : null;
        counterBcr.Adjustment_Amount__c = sourceBcr.Adjustment_Amount__c != null ? sourceBcr.Adjustment_Amount__c * -1 : null;
        counterBcr.Adjustment_GL_Account__c = sourceBcr.Adjustment_GL_Account__c;
        counterBcr.Applied_Amount__c = sourceBcr.Applied_Amount__c != null ? sourceBcr.Applied_Amount__c * -1 : null;
        counterBcr.Billing__c = sourceBcr.Billing__c;

        //check for multicurrency
        if(isMultiCurrencyEnabled){
            counterBcr.put('CurrencyIsoCode', sourceBcr.get('CurrencyIsoCode'));
        }
        return counterBcr;
    }
    /**
     * Create compensating transactions for the cash receipts
     */
    private void createCompensatingTransactions(){
        //create new Transactions that counter the existed Transactions for the Cash Receipt
        List<Transaction__c> transactions = new List<Transaction__c>();

        //fetch existing transactions and create counter transactions
        for (Transaction__c trans : queryTransactions()) {
            transactions.add(createCounterTransaction(cashReceipt,trans));
        }
        //validate and create counter transactions
        if(!transactions.isEmpty()){
            CubeBuilder.isEnabledCashFlowStatement = isCashFlowStatementEnabled;
            TransactionActions.createTransactions(transactions);
            CubeBuilder.isEnabledCashFlowStatement = false;
            TriggerObserver.reset();
        }
    }
    //Transaction creation helper method 
    public Transaction__c createCounterTransaction(Cash_Receipt__c receipt, Transaction__c sourceTransaction) {
        Accounting_Period__c acctPeriod = handler.getAccountingPeriodByDate(crVoidData.voidReceiptDate);

        Transaction__c counterTransaction = new Transaction__c();
        //Populate Source Document related fields
        counterTransaction.Cash_Receipt__c = crVoidData.cashReceiptId;
        counterTransaction.Accounting_Period__c = acctPeriod != null ? acctPeriod.Id : null;
        counterTransaction.Date__c = crVoidData.voidReceiptDate;

        //Populate Common fields
        counterTransaction.Ledger__c = sourceTransaction.Ledger__c != NULL ? sourceTransaction.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        counterTransaction.GL_Account__c = sourceTransaction.GL_Account__c;
        counterTransaction.Account__c = sourceTransaction.Account__c;
        counterTransaction.Employee__c = sourceTransaction.Employee__c;
        counterTransaction.Contact__c = sourceTransaction.Contact__c;
        counterTransaction.GL_Account_Variable_1__c = sourceTransaction.GL_Account_Variable_1__c;
        counterTransaction.GL_Account_Variable_2__c = sourceTransaction.GL_Account_Variable_2__c;
        counterTransaction.GL_Account_Variable_3__c = sourceTransaction.GL_Account_Variable_3__c;
        counterTransaction.GL_Account_Variable_4__c = sourceTransaction.GL_Account_Variable_4__c;
        counterTransaction.Project__c = sourceTransaction.Project__c;
        counterTransaction.Project_Task__c = sourceTransaction.Project_Task__c;
        counterTransaction.Cash_Flow_Category__c = receipt.Cash_Flow_Category__c != null ? receipt.Cash_Flow_Category__c : crVoidData.cashFlowCategory;
        counterTransaction.Amount__c = sourceTransaction.Amount__c * -1;

        return counterTransaction;
    }
    /**
     * Once the cash receipt is validated, comapensating records have been created then, update void details on the CR
     */
    private void updateCashReceipt(){
        cashReceipt.Void__c = true;
        cashReceipt.Void_Date__c = crVoidData.voidReceiptDate;
        cashReceipt.Void_Description__c = crVoidData.description;
        cashReceipt.Cash_Flow_Category__c = cashReceipt.Cash_Flow_Category__c == null ? crVoidData.cashFlowCategory : cashReceipt.Cash_Flow_Category__c;
        if(cashReceipt.Bank_Deposit__c != null){
            bankDepositId = cashReceipt.Bank_Deposit__c;
            cashReceipt.Bank_Deposit__c = null;
        }

        //unlock cash flow category field
        TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Void__c,
                    Cash_Receipt__c.Void_Date__c,
                    Cash_Receipt__c.Void_Description__c
            }
        );

        //update the cr
        SFDCSecurityUtils.updateCheckCRUDAndFLS(cashReceipt, new List<String>{
            'Void__c',
            'Void_Date__c',
            'Void_Description__c',
            'Cash_Flow_Category__c'
        });
    }
    /**
     * once the cash receipt has been voided now we can update the payment activity to void 
     */
    private void updatePaymentActivity(){
        // check if anything to update
        if (activity == null) {
            return;
        }

        //update activity status to void
        activity.Status__c = COMMON_VOID;

        //update the activity
        SFDCSecurityUtils.updateCheckCRUDAndFLS(activity, new List<String>{
            'Status__c'
        });
    }
    /**
     * once the cash receipt has been voided now we can update the bank deposits amount 
     */
    private void updateBankDeposit(){
        if(bankDepositId == null){
            return;
        }
        BankDepositHandler handler = new BankDepositHandler(bankDepositId);
        handler.calculateTotalAmount();
    }
    /**
     * Query the cash receipt enforcing the crud fls check
     */
    private void fetchCashReceipts(){
        List<String> queryFields = new List<String>{
            'Id',
            'Receipt_Date__c',
            'Account__c',
            'Account__r.Name',
            'Check_Number__c',
            'Amount__c',
            'Cash_Flow_Category__c',
            'Cash_Flow_Category__r.Name',
            'Status__c',
            'Void__c',
            'Bank_Reconciliation__c',
            'Ledger__c',
            'Number_of_Billing_Cash_Receipts__c',
            'Payment_Processor__c',
            'Payment_Processor__r.Type__c',
            'Bank_Deposit__c',
            'Bank_Deposit__r.Bank_Reconciliation__c'
        };
        String queryCondition = 'Id = :crId';
        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //query cash receipts
        List<Cash_Receipt__c> cashReceipts = (List<Cash_Receipt__c>)Database.query(theQuery.toSOQL());

        //take the first record
        if(!cashReceipts.isEmpty()){
            cashReceipt = cashReceipts[0];
        }
    }
    /**
     * Query the transactions enforcing the crud fls check
     */
    private List<Transaction__c> queryTransactions() {
        //Prepare SOQL Query to query Transactions with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Cash_Receipt__c',
            'Date__c',
            'Amount__c',
            'Accounting_Period__c',
            'GL_Account__c',
            'Project__c',
            'Project_Task__c',
            'Account__c',
            'Employee__c',
            'Contact__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Cash_Flow_Category__c',
            'Ledger__c'
        };

        String queryCondition = 'Cash_Receipt__c = :crId';

        SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Transaction__c>) Database.query(theQuery.toSOQL());
    }
    /**
     * Query the billing cash receipt enforcing the crud fls check
     */
    private List<Billing_Cash_Receipt__c> fetchCashReceiptsBCRs(){
        //Prepare SOQL Query to query Billing Cash Receipts with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Cash_Receipt__c',
            'Accounting_Period__c',
            'Adjustment_Amount__c',
            'Adjustment_GL_Account__c',
            'Applied_Amount__c',
            'Billing__c',
            'Ledger__c'
        };
        if(isMultiCurrencyEnabled){
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Cash_Receipt__c = :crId';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Cash_Receipt__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing_Cash_Receipt__c>) Database.query(theQuery.toSOQL());
    }
    /**
     * Query the Payment activity
     */
    public CashReceiptVoid fetchPaymentActivity(){
        String paymentId = crVoidData.paymentId;
        //fields to query
        List<String> queryFields = new List<String>{
            'Name',
            'Merchant_Reference__c',
            'Cash_Receipt__c',
            'Cash_Receipt__r.Payment_Processor__c',
            'Payment_Method__c',
            'Payment_Method__r.Payment_Method_Type__c',
            'Payment_Method_Type__c',
            'Payment_Method__r.Payment_Processor__r.Type__c'
        };
        //condition
        String queryCondition = 'Cash_Receipt__c =:crId';

        //dynamic query
        SOQLBuilder theQuery = new SOQLBuilder(Payment_Activity__c.sObjectType);
        theQuery
            .assertIsAccessible()
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //query records
        List<Payment_Activity__c> results = Database.query(theQuery.toSOQL());

        if(results.size() > 0){
            activity = results[0];
        }
        return this;
    }
}