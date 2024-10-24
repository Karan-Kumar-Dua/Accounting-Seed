public with sharing class CashDisbursementVoid {

    @TestVisible
    private static Integer SYNC_RECORDS_LIMIT = 400;
   
    public Boolean isProcessed {get; private set;}
    public Boolean isError {get; private set;}
    public Boolean isASPay {get; private set;}
    public Boolean isCardVoidedSuccess {get; private set;}
    public Cash_Disbursement__c cashDisbursement {get;set;}
    public Cash_Disbursement__c cashDisbursementVoid {get; set;}
    private Accounting_Settings__c main;

    public static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    public static final String TYPE_VIRTUAL_CARD = 'Virtual Card';
    public static final String TYPE_ACH = 'ACH';
    public static final String AS_PAY_TYPE = 'AS Pay';
    public static final List<String> ASPAY_VOID_STATUSES_TO_CHECK = new List<String>{'canceled', 'cancelled', 'publish_cancelled', 'reconcile_declined', 'reconcile_cancelled'};

    public static final String POSTED_ERROR_MESSAGE = Label.ERR_CD_STATUS_POSTED_TO_VOID;
    public static final String VOIDED_ERROR_MESSAGE = Label.ERR_CD_ALREADY_VOIDED;
    public static final String CLEARED_ERROR_MESSAGE = Label.ERR_CD_CLEARED_BANK_RECONCILIATION;
    public static final String ASSOCIATED_WITH_BANK_TRANSACTION_ERROR_MESSAGE = Label.ERR_CD_ASSOCIATED_BANK_TRANSACTION;
    public static final String NO_CONTROL_ACCOUNT_MESSAGE = Label.ERR_CD_NO_CONTROL_ACOUNT;
    public static final String CLOSED_PERIOD_ERROR = Label.ERR_AP_SELECTED_CLOSED;
    public static final String TOO_EARLY_VOIDED_DATE = Label.ERR_AP_VOID_DATE_LESS_START_DATE;
    public static final String NOT_SOURCED_FROM_AP = Label.ERR_CD_NOT_SOURCED_FROM_AP;
    public static final String CASH_FLOW_ERROR = Label.ERR_CASH_FLOW_CATEGORY;
    public static final String NO_PERIOD_ERROR_MESSAGE = Label.ERR_NO_PERIOD_FOR_SELECTED_DATE;
    public static final String ERR_BLOCK_RETURN_FUNDS = Label.ERR_BLOCK_RETURN_FUNDS;

    public CashDisbursementVoid(ApexPages.StandardController controller) {
        try {
            isProcessed = false;
            isError = false;
            try {
                main = AccountingSettingsHandler.getAccountingSettings();
            }
            catch (QueryException ex) {

            }

            cashDisbursement = queryCashDisbursement((Id) controller.getId());
            
            isASPay = cashDisbursement.Type__c == AS_PAY_TYPE ? true : false;

            Map<String, GL_Account_Default__c> defaults = GLAccount.glAccountDefaultsMapByLedgerId(cashDisbursement.Ledger__c);

            cashDisbursementVoid = new Cash_Disbursement__c(
                Accounting_Period__c = cashDisbursement.Accounting_Period__c,
                Disbursement_Date__c = Date.today(),
                Cash_Flow_Category__c = cashDisbursement.Cash_Flow_Category__c
            );

            if (getIsCashFlowStatementEnabled()) {
                cashDisbursementVoid.Cash_Flow_Category__c = cashDisbursement.Cash_Flow_Category__c;
            }

            if (cashDisbursement.Payment_Status__c == 'Void' || cashDisbursement.Status__c == 'Void') {
                isError = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, VOIDED_ERROR_MESSAGE));
            }

            if (cashDisbursement.Status__c != 'Posted' && cashDisbursement.Status__c != 'Void') {
                isError = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, POSTED_ERROR_MESSAGE));
            }

            if (!defaults.containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT) || cashDisbursement.Debit_GL_Account__c == NULL) {
                isError = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_CONTROL_ACCOUNT_MESSAGE));
            }

            if (cashDisbursement.Bank_Reconciliation__c != NULL) {
                isError = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, CLEARED_ERROR_MESSAGE));
            }

            if (cashDisbursement.Bank_Transaction__c != NULL) {
                isError = true;
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    String.format(ASSOCIATED_WITH_BANK_TRANSACTION_ERROR_MESSAGE, new List<String>{cashDisbursement.Bank_Transaction__r.Name})
                ));
            }

            if(cashDisbursement.Type__c == AS_PAY_TYPE){
                if(cashDisbursement.Payment_Method__r.Status__c == 'Blocked'){
                    isCardVoidedSuccess = true;
                }
                //add error for virtual card if the CD is in one of the followinbg statuses where the PM would not have been created yet
                if((ASPAY_VOID_STATUSES_TO_CHECK.contains(cashDisbursement.Payment_Service_Status__c?.toLowerCase())
                        || cashDisbursement.Payment_Service_Status__c?.toLowerCase() == 'pending')
                        && cashDisbursement.AS_Pay_Type__c == TYPE_VIRTUAL_CARD){
                    cashDisbursementVoid.addError(Label.ERR_CD_VCARD_VOID);
                    isError = true;
                //add error for virtual card that is zero balance, they can not be voided in edenred
                }else if(cashDisbursement.AS_Pay_Type__c == TYPE_VIRTUAL_CARD
                        && cashDisbursement.Payment_Method__r.Current_Balance__c > 0
                        && cashDisbursement.Payment_Method__r.Available_Balance__c == 0) {
                    isError = true;
                    cashDisbursementVoid.addError(Label.ERR_CD_CARD_VOID);
                //add error for ACH when status is not one of the defined ones meaning the payment has already been sent
                }else if(cashDisbursement.AS_Pay_Type__c == TYPE_ACH
                        && !ASPAY_VOID_STATUSES_TO_CHECK.contains(cashDisbursement.Payment_Service_Status__c?.toLowerCase())){
                    isError = true;
                    cashDisbursementVoid.addError(Label.ERR_CD_ACH_VOID);
                }
            }
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
        }

    }

    public static Cash_Disbursement__c queryCashDisbursement(Id cdId) {
        //Prepare SOQL Query to query Cash Disbursements with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Status__c',
            'Payment_Status__c',
            'Amount__c',
            'Disbursement_Date__c',
            'Bank_Account__c',
            'Debit_GL_Account__c',
            'Vendor__c',
            'Accounting_Period__c',
            'Bank_Reconciliation__c',
            'Cash_Flow_Category__c',
            'Ledger__c',
            'Bank_Transaction__c',
            'Bank_Transaction__r.Name',
            'AS_Pay_Type__c',
            'Type__c',
            'Payment_Method__c',
            'Payment_Method__r.Type__c',
            'Payment_Service_Status__c',
            'Payment_Method__r.Payment_Method_Type__c',
            'Payment_Method__r.Status__c',
            'Payment_Method__r.Current_Balance__c',
            'Payment_Method__r.Available_Balance__c',
            'Bank_Disbursement__c'
        };

        String queryCondition = 'Id = :cdId FOR UPDATE';

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        //============================================================================
        return (Cash_Disbursement__c) Database.query(theQuery.toSOQL());
    }

    public Boolean getIsCashFlowCategoryPopulated() {
        return cashDisbursement.Cash_Flow_Category__c != NULL;
    }

    public Boolean getIsCashFlowStatementEnabled() {
        return main.Enable_Cash_Flow_Statement__c;
    }

    public PageReference blockCardReturnFunds(){
        cashDisbursement = queryCashDisbursement(cashDisbursement.Id);
        if(cashDisbursement.Type__c == AS_PAY_TYPE){
            //add error for virtual card if the CD is in one of the followinbg statuses where the PM would not have been created yet
            if((ASPAY_VOID_STATUSES_TO_CHECK.contains(cashDisbursement.Payment_Service_Status__c?.toLowerCase())
                    || cashDisbursement.Payment_Service_Status__c?.toLowerCase() == 'pending')
                    && cashDisbursement.AS_Pay_Type__c == TYPE_VIRTUAL_CARD){
                cashDisbursementVoid.addError(Label.ERR_CD_VCARD_VOID);
            //add error for virtual card that is zero balance, they can not be voided in edenred
            }else if(cashDisbursement.AS_Pay_Type__c == TYPE_VIRTUAL_CARD
                    && cashDisbursement.Payment_Method__r.Current_Balance__c > 0
                    && cashDisbursement.Payment_Method__r.Available_Balance__c == 0) {
                cashDisbursementVoid.addError(Label.ERR_CD_CARD_VOID);
            //add error for ACH when status is not one of the defined ones meaning the payment has already been sent
            }else if(cashDisbursement.AS_Pay_Type__c == TYPE_ACH
                    && !ASPAY_VOID_STATUSES_TO_CHECK.contains(cashDisbursement.Payment_Service_Status__c?.toLowerCase())){
                cashDisbursementVoid.addError(Label.ERR_CD_ACH_VOID);
            }else if(cashDisbursement.AS_Pay_Type__c == TYPE_VIRTUAL_CARD){
                VirtualCardService v = new VirtualCardService();
                Map<Id, HttpResponse> mResp = v.blockAndReturnFunds(new List<Id>{cashDisbursement.Payment_Method__c});
                HttpResponse resp = mResp.get(cashDisbursement.Payment_Method__c);
                if(resp.getStatusCode() != 200 && resp.getStatusCode() != 201){
                    isError = true;
                    VirtualCardBlockReturnResult r = VirtualCardBlockReturnResult.parse(resp.getBody());
                    cashDisbursementVoid.addError(ERR_BLOCK_RETURN_FUNDS + ': ' + r.result.description.error);
                }else{
                    isCardVoidedSuccess = true;
                }
            }
        }
        
        return null;
    }

    public PageReference voidCashDisbursement() {

        if (isError) {
            return NULL;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            cashDisbursement = queryCashDisbursement(cashDisbursement.Id);

            Accounting_Period__c acctPeriod = new Accounting_Period__c();
            isError = false;

            try {
                if (main.Enable_Cash_Flow_Statement__c && cashDisbursement.Cash_Flow_Category__c == NULL) {
                    GL_Account__c cashFlow = DomainUtils.getGlAccountsById(new Set<Id>{cashDisbursementVoid.Cash_Flow_Category__c})[0];
                    if (cashFlow != NULL && cashFlow.Type__c != 'Cash Flow') {
                        cashDisbursementVoid.addError(CASH_FLOW_ERROR);
                        return NULL;
                    }
                }

                acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(cashDisbursementVoid.Disbursement_Date__c);
                if (acctPeriod == NULL) {
                    cashDisbursementVoid.addError(NO_PERIOD_ERROR_MESSAGE);
                    return NULL;
                }

                if (AccountingPeriod.isPeriodClosed(acctPeriod,Cash_Disbursement__c.sObjectType)) {
                    cashDisbursementVoid.addError(CLOSED_PERIOD_ERROR);
                    return NULL;
                }

                Accounting_Period__c cashDispAccountingPeriod =
                    AccountingPeriodHandler.getInstance().getAccountingPeriodById(cashDisbursement.Accounting_Period__c);

                if (cashDispAccountingPeriod != NULL && cashDisbursementVoid.Disbursement_Date__c < cashDispAccountingPeriod.Start_Date__c) {
                    cashDisbursementVoid.addError(String.format(TOO_EARLY_VOIDED_DATE, new List<String>{cashDispAccountingPeriod.Start_Date__c.format()}));
                    return NULL;
                }

                cashDisbursementVoid.Accounting_Period__c = acctPeriod.Id;
            }
            catch (Exception ex) {
                ApexPages.addMessages(ex);
                return NULL;
            }

            List<AP_Disbursement__c> apDisbursements = fetchAPDisbursements(cashDisbursement.Id);
            if (apDisbursements.size() <= SYNC_RECORDS_LIMIT) {
                OppositeAPDsWrapper wrapper = prepareOppositeAPDs(apDisbursements, cashDisbursementVoid.Accounting_Period__c);

                cashDisbursement.Payment_Status__c = CashDisbursementActions.STATUS_VOID;
                cashDisbursement.Void_Description__c = cashDisbursementVoid.Void_Description__c;
                cashDisbursement.Void_Date__c = cashDisbursementVoid.Disbursement_Date__c;
                cashDisbursement.Bank_Disbursement__c = NULL;

                Set<Schema.SObjectField> fieldsToUnlock = new Set<SObjectField> {
                        Cash_Disbursement__c.Payment_Status__c,
                        Cash_Disbursement__c.Void_Date__c,
                        Account_Payable__c.Closed_Accounting_Period__c
                };

                TriggerObserver.getInstance().unlockFields(fieldsToUnlock);

                SFDCSecurityUtils.updateCheckCRUDAndFLS(cashDisbursement, new List<String>{
                        'Payment_Status__c',
                        'Void_Date__c',
                        'Void_Description__c',
                        'Bank_Disbursement__c'
                });

                //insert opposite APDs
                MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext = true;
                APDisbursementActions.isPreventInsertOverride = true;
                SFDCSecurityUtils.insertCheckCRUDAndFLS(wrapper.apDisbIdsByNewAPDisbursements.values(), new List<String>{
                        'Paid_Amount__c'
                });
                APDisbursementActions.isPreventInsertOverride = false;
                SFDCSecurityUtils.updateCheckCRUDAndFLS(wrapper.accountPayableRecsByIds.values(), new List<String>{
                        'Closed_Accounting_Period__c',
                        'Payment_Status__c'
                });

                MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext = false;

                //create new Transactions that counter the existed Transactions for the Cash Disbursement and related AP Disbursements
                List<Transaction__c> transactions = new List<Transaction__c>();
                for (Transaction__c trans : queryTransactions(cashDisbursement.Id)) {
                    transactions.add(createCounterTransaction(trans, cashDisbursement, cashDisbursementVoid));
                }

                CubeBuilder.isEnabledCashFlowStatement = main.Enable_Cash_Flow_Statement__c;
                TransactionActions.createTransactions(transactions);
                CubeBuilder.isEnabledCashFlowStatement = false;
                isProcessed = true;
                TriggerObserver.reset();
            } else {
                ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.CONFIRM,
                        Label.CASH_DISBURSEMENT_VOIDED_IN_BACKGROUND
                ));
                isProcessed = true;
                Database.executeBatch(new APDisbursementVoidBatch(cashDisbursement, cashDisbursementVoid));
                return null;
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            ApexPages.addMessages(ex);
            isError = true;
            isProcessed = false;
            TriggerObserver.reset();
            return NULL;
        }

        return new PageReference('/' + cashDisbursement.Id);
    }

    public static OppositeAPDsWrapper prepareOppositeAPDs(List<AP_Disbursement__c> apDisbursements, Id accountingPeriodId) {
        Map<Id, AP_Disbursement__c> apDisbIdsByNewAPDisbursements = new Map<Id, AP_Disbursement__c>();
        Map<Id, Account_Payable__c> accountPayableRecsByIds = new Map<Id, Account_Payable__c>();
        Set<String> paidStatuses = new Set<String>{AccountPayableActions.PAYMENT_STATUS_PAID, AccountPayableActions.PAYMENT_STATUS_PARTIALLY_PAID};
        for (AP_Disbursement__c apdRec : apDisbursements) {
            Double paidAmount = apdRec.Paid_Amount__c == NULL ? 0 : apdRec.Paid_Amount__c;
            Double diffPaidAmount = apdRec.Account_Payable__r.Paid_Amount__c - paidAmount;

            String paymentStatus = apdRec.Account_Payable__r.Payment_Status__c;
            if (paymentStatus == AccountPayableActions.PAYMENT_STATUS_PAID && diffPaidAmount > 0) {
                paymentStatus = AccountPayableActions.PAYMENT_STATUS_PARTIALLY_PAID;
            } else if (paidStatuses.contains(paymentStatus) && diffPaidAmount == 0) {
                paymentStatus = AccountPayableActions.PAYMENT_STATUS_UNPAID;
            }
            accountPayableRecsByIds.put(apdRec.Account_Payable__c, new Account_Payable__c(
                    Id = apdRec.Account_Payable__c,
                    Payment_Status__c = paymentStatus,
                    Closed_Accounting_Period__c = null
            ));

            AP_Disbursement__c newAPDisbursement = new AP_Disbursement__c();
            //new APdRec Disbursement must have the same Currency as original record
            if (IS_MULTI_CURRENCY_ENABLED) {
                newAPDisbursement.put('CurrencyIsoCode', apdRec.get('CurrencyIsoCode'));
            }
            newAPDisbursement.Cash_Disbursement__c = apdRec.Cash_Disbursement__c;
            newAPDisbursement.Account_Payable__c = apdRec.Account_Payable__c;
            newAPDisbursement.Accounting_Period__c = accountingPeriodId;
            newAPDisbursement.Paid_Amount__c = (paidAmount * -1);
            apDisbIdsByNewAPDisbursements.put(apdRec.Id, newAPDisbursement);
        }

        return new OppositeAPDsWrapper(apDisbIdsByNewAPDisbursements, accountPayableRecsByIds);
    }

    public class OppositeAPDsWrapper {
        public Map<Id, AP_Disbursement__c> apDisbIdsByNewAPDisbursements;
        public Map<Id, Account_Payable__c> accountPayableRecsByIds;

        public OppositeAPDsWrapper(Map<Id, AP_Disbursement__c> apDisbIdsByNewAPDisbursements, Map<Id, Account_Payable__c> accountPayableRecsByIds) {
            this.apDisbIdsByNewAPDisbursements = apDisbIdsByNewAPDisbursements;
            this.accountPayableRecsByIds = accountPayableRecsByIds;
        }
    }

    public static List<AP_Disbursement__c> fetchAPDisbursements(Id cashDisbursementId) {
        List<String> queryFields = new List<String>{
                'Id',
                'Account_Payable__r.Payment_Status__c',
                'Account_Payable__r.Paid_Amount__c',
                'Paid_Amount__c',
                'Account_Payable__r.Discount_Amount__c',
                'Cash_Disbursement__c',
                'Account_Payable__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = String.join(new List<String>{
                'Cash_Disbursement__c = :cashDisbursementId',
                '(Account_Payable__r.Payment_Status__c = \'Paid\' OR Account_Payable__r.Payment_Status__c = \'Partially Paid\')'
        }, ' AND ');

        SOQLBuilder theQuery = new SOQLBuilder(AP_Disbursement__c.SObjectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<AP_Disbursement__c>) Database.query(theQuery.toSOQL());
    }

    public static Transaction__c createCounterTransaction(Transaction__c sourceTransaction, Cash_Disbursement__c cashDisbursement, Cash_Disbursement__c cashDisbursementVoid) {
        Transaction__c counterTransaction = new Transaction__c();
        //Populate Source Document related fields
        counterTransaction.Cash_Disbursement__c = cashDisbursement.Id;
        counterTransaction.Accounting_Period__c = cashDisbursementVoid.Accounting_Period__c;
        counterTransaction.Date__c = cashDisbursementVoid.Disbursement_Date__c;

        //Populate Common fields
        counterTransaction.Ledger__c = sourceTransaction.Ledger__c;
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
        counterTransaction.Cash_Flow_Category__c = cashDisbursementVoid.Cash_Flow_Category__c;
        counterTransaction.Amount__c = sourceTransaction.Amount__c * -1;

        return counterTransaction;
    }

    public static List<Transaction__c> queryTransactions(String cdId) {
        //Prepare SOQL Query to query Transactions with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Cash_Disbursement__c',
            'Date__c',
            'Amount__c',
            'Accounting_Period__c',
            'GL_Account__c',
            'Project__c',
            'Project_Task__c',
            'Account__c',
            'Employee__c',
            'Contact__c',
            'Ledger__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Cash_Flow_Category__c'
        };

        String queryCondition = 'Cash_Disbursement__c = :cdId';

        SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        //=====================================================================
        return (List<Transaction__c>) Database.query(theQuery.toSOQL());
    }
}