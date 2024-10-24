public with sharing virtual class AccountPayablePaymentHandler {

    public class AccountPayablePaymentException extends Exception {}

    public static final String NOT_POSTED_ERROR_MESSAGE = Label.ERR_NOT_POSTED_BEFORE_PAY;
    public static final String NON_VALID_TYPE_ERROR_MESSAGE = Label.ERR_PAYABLE_NOT_VALID_TYPE;
    public static final String ALREADY_PAID_ERROR_MESSAGE = Label.ERR_ALREADY_PAID;
    public static final String FULL_BALANCE_PAID_ERROR_MESSAGE = Label.ERR_FULL_BALANCE_ALREADY_PAID;
    public static final String NO_QUALIFIED_RECORDS_SELECTED_ERROR_MESSAGE = Label.ERR_NO_QUALIFYING_RECORDS_SELECTED;
    public static final String NOT_SAME_CURRENCY_ERROR_MESSAGE = Label.ERR_NOT_SAME_CURRENCY_FOR_PAYABLE_RECORD;
    public static final String NO_SELECTED_CASH_DISBURSEMENT_ERROR_MESSAGE = Label.ERR_NO_SELECTED_CASH_DISBURSEMENT;
    public static final String NEGATIVE_AMOUNT_ERROR_MESSAGE = Label.ERR_NEGATIVE_AMOUNT;
    public static final String NEGATIVE_DISCOUNT_ERROR_MESSAGE = Label.ERR_NEGATIVE_DISCOUNT_PAYMENT;
    public static final String AMOUNT_MORE_THAN_BALANCE_ERROR_MESSAGE = Label.ERR_AMOUNT_MORE_THAN_BALANCE;
    public static final String DISCOUNTED_AMOUNT_MUST_PAY_IN_FULL_ERROR_MESSAGE = Label.ERR_DISCOUNTED_AMOUNT_MUST_PAY_IN_FULL;
    public static final String FORM_TYPE_INVALID_ERROR_MESSAGE = Label.ERR_1099_FORM_TYPE_INVALID;
    public static final String FORM_CATEGORY_INVALID_ERROR_MESSAGE = Label.ERR_FORM_CATEGORY_INVALID_CASH_DISBURSEMENT;
    public static final String NO_ACCOUNTING_RANGE_ERROR = Label.ERR_NO_ACCOUNTING_PERIOD_IN_DATE_RANGE;
    public static final String CLOSED_PERIOD_ERROR = Label.ERR_CLOSED_ACCOUNTING_PERIOD;
    public static final String NOT_SAME_LEDGER_ERROR_MESSAGE = Label.ERR_NOT_SAME_LEDGER_CASH_DISBURSEMENT;
    public static final String CD_DEFAULT_STATUS_APPROVED = Label.WRN_CD_DEFAULT_STATUS_APPROVED;
    public static final String CD_DEFAULT_STATUS_APPROVED_BATCH = Label.WRN_CD_DEFAULT_STATUS_APPROVED_BATCH;
    public static final String ERR_ON_PAYABLE_PAY_BATCH_PAGE_WHEN_ON_HOLD_IS_CHECKED = Label.ERR_ON_PAYABLE_PAY_BATCH_PAGE_WHEN_ON_HOLD_IS_CHECKED;
    public static final String ERR_ON_PAYABLE_PAY_PARTIAL_PAGE_WHEN_ON_HOLD_IS_CHECKED = Label.ERR_ON_PAYABLE_PAY_PARTIAL_PAGE_WHEN_ON_HOLD_IS_CHECKED;
    public static final String CD_SOURCE_MANUAL = 'Manual';
    public static final String CD_SOURCE_PAYABLE = 'Payable';
    public static final String LEDGER_ACCOUNTING_METHOD_ACCRUAL_AND_CASH = 'Accrual and Cash';
    public static final String LEDGER_ACCOUNTING_METHOD_CASH = 'Cash';
    public static final String LEDGER_ACCOUNTING_METHOD_ACCRUAL = 'Accrual';

    public enum PayeeType {
        VENDOR,
        CONTACT,
        EMPLOYEE
    }

    public Cash_Disbursement__c uiCashDisbursement {get; set;}
    public Cash_Disbursement_Batch__c uiCashDisbursementBatch {get; set;}
    public List<CashDisbursementWrapper> wrappedCDs {get; set;}
    public String currencyIsoCode {get; private set;}
    public Boolean isMultiCurrencyEnabled {get; set;}
    public Boolean isVendorDiscountWarning {get; set;}
    public Boolean isCashFlowStatementEnabled {get; set;}      
    public Boolean areAnyPayees1099 {get; set;}  
    public PaymentResultDispatcher paymentResultDispatcher = new PaymentResultDispatcher();
    public List<SelectOption> form1099Types;  
    public Map<Id, List<SelectOption>> form1099Boxes; 
    public Boolean is1099Vendor {get; set;}
    public Boolean isDefaultCDApproved {get; set;}  
    public Boolean isShowDebitGLAccountField {get; set;}

    protected Accounting_Settings__c main;
    @TestVisible
    protected Cash_Disbursement_Batch__c cashDisbursementBatchToInsert {get; set;}
    protected List<Cash_Disbursement__c> cashDisbursementsToInsert {get; set;}
    @TestVisible
    protected List<Account_Payable__c> accountPayables {get; set;}
    protected Map<Id, List<Account_Payable__c>> paymentsToVendorAsPayee;
    protected Map<Id, List<Account_Payable__c>> paymentsToContactAsPayee;
    protected Map<Id, List<Account_Payable__c>> paymentsToEmployeeAsPayee;
    private Boolean aggregateByPayee;
   
    protected Boolean batchProcessing;
    protected List<PaymentResult> results;     
    private List<PaymentResult> badResults;
    protected List<PostResult> postResults;
    private List<PostResult> badPostResults;
    private List<SelectOption> gLAccounts;    
    private Id defaultBankId;
    private Map<Id, Account> personAccounts = new Map<Id, Account>();
    
    protected Accounting_Settings__c getAccountingSettings() {
        if (main == NULL) {
            main = AccountingSettingsHandler.getAccountingSettings();
        }
        return main;
    }

    public pageReference updateBoxes() {
        String selectedFormTypeId;        
        for (CashDisbursementWrapper cd : wrappedCDs) {
            selectedFormTypeId = cd.CashDisbursement.Form_Category_Id__c;
            if (String.isEmpty(selectedFormTypeId)) {
                cd.CashDisbursement.Form_1099_Box__c = NULL;
            }
            cd.formCategories = getForm1099BoxOptions(selectedFormTypeId);
        }
        return null;
    }    

    public List<SelectOption> getGLAccounts() {
        if (glAccounts == NULL) {
            glAccounts = new List<SelectOption>();
            for (GL_Account__c glAccount : DomainUtils.getBankGlAccounts()) {
                                glAccounts.add(new SelectOption(glAccount.Id, glAccount.Name));
            }
            if (glAccounts.isEmpty()) {
                glAccounts.add(new SelectOption('', '--'+ Label.COMMON_NONE + '--'));
            }
        }
        return glAccounts;
    }

    public List<SelectOption> getForm1099Types() {
        if (form1099Types == NULL) {
            form1099Types = new List<SelectOption>();
            form1099Types.add(new SelectOption('', '--'+ Label.COMMON_NONE + '--'));
            for (Form_Type__mdt formType : X1099InfoHelper.getFormTypes(uiCashDisbursement.Disbursement_Date__c.Year())) {
                form1099Types.add(new SelectOption(formType.Id, formType.Label));
            }
        }
        return form1099Types;
    }

    public List<SelectOption> getForm1099Boxes() {
        if (String.isEmpty(uiCashDisbursement.Form_Category_Id__c)) {
            uiCashDisbursement.Form_1099_Box__c = '';
        }
        return getForm1099BoxOptions();
    }

    private void reconcile1099Info() {
        Set<String> formTypeIdAndDates = new Set<String>();
        List<String> badFormTypeIdAndDates = new List<String>();
        for (CashDisbursementWrapper cdw : wrappedCDs) {
            if (cdw.cashDisbursement.Form_Category_Id__c != NULL) {
                formTypeIdAndDates.add(cdw.cashDisbursement.Form_Category_Id__c + ':' + cdw.cashDisbursement.Disbursement_Date__c);                
            }
        }

        for (String formTypeIdAndDate : formTypeIdAndDates) {
            String[] values = formTypeIdAndDate.split(':');
            if (!X1099InfoHelper.validateFormTypeForDistributionDate(values[0], Date.valueOf(values[1]))) {
                badFormTypeIdAndDates.add(formTypeIdAndDate);
            }
        }

        for (CashDisbursementWrapper cdw : wrappedCDs) {
            String formTypeId = cdw.cashDisbursement.Form_Category_Id__c;
            String formTypeIdAndDate = formTypeId + ':' + cdw.cashDisbursement.Disbursement_Date__c;
            if (!String.isEmpty(formTypeIdAndDate) && badFormTypeIdAndDates.contains(formTypeIdAndDate)) {
                cdw.cashDisbursement.Form_1099_Box__c = NULL;
                cdw.cashDisbursement.Form_Category_Id__c = NULL;
            }
        }
    }

    private List<SelectOption> getForm1099BoxOptions(String formTypeId) {
        if (form1099Boxes == NULL) {
            form1099Boxes = X1099InfoHelper.getFormCategoryOptionsByFormTypeId();
        }        
        if (!String.isEmpty(formTypeId)) {
            return form1099Boxes.get(formTypeId);
        }
        return form1099Boxes.get(NULL);
    }

    private List<SelectOption> getForm1099BoxOptions() {
        return getForm1099BoxOptions(uiCashDisbursement.Form_Category_Id__c);
    }

    private void queryAccountPayables(Set<Id> apIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'Payee__c',
            'Total__c',
            'Payment_Status__c',
            'Discount_Amount__c',
            'Balance__c',
            'Status__c',
            'Vendor__c',
            'Contact__c',
            'Contact__r.Name',
            'Contact__r.Default_Form_Category_Id__c',
            'Contact__r.X1099_Vendor__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Start_Date__c',
            'Employee__c',
            'Employee__r.Name',
            'Paid_Amount__c',
            'Date__c',
            'Type__c',
            'Ledger__c',
            'Net_Amount__c',
            'Vendor__r.Name',
            'Vendor__r.Discount_Days_Due__c',
            'Vendor__r.Discount_Percent__c',
            'Vendor__r.GL_Account_Variable_1__c',
            'Vendor__r.GL_Account_Variable_2__c',
            'Vendor__r.GL_Account_Variable_3__c',
            'Vendor__r.GL_Account_Variable_4__c',
            'Vendor__r.Default_Form_Category_Id__c',
            'Vendor__r.X1099_Vendor__c',
            'Credit_Memo_Applied_Amount__c',
            'Currency_Conversion_Rate__c',
            'Purchase_Tax3__c',
            'Reverse_Charge__c',
            'Ledger__r.Accounting_Method__c',
            'On_Hold__c'
        };

        if (GlobalVariables.isPersonAccountEnabled) {
            queryFields.add('Contact__r.IsPersonAccount');
            queryFields.add('Contact__r.AccountId');
        }

        String queryCondition = 'Id IN :apIds';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable_Cash_Disbursements__r')
            .setLimit(1);

        accountPayables = (List<Account_Payable__c>) Database.query(theQuery.toSOQL());
    }


    protected Account_Payable__c queryAccountPayable(String accountPayableId) {
        queryAccountPayables(new Set<Id>{accountPayableId});
        return !accountPayables.isEmpty() ? accountPayables[0] : NULL;
    }

    protected List<Account_Payable__c> queryAccountPayables(List<Account_Payable__c> selectedAccountPayables) {
        Map<Id, Account_Payable__c> apMap = new Map<Id, Account_Payable__c>(selectedAccountPayables);
        queryAccountPayables(apMap.keySet());
        return accountPayables;
    }

    //Validation methods ==============
    //=================================
    protected void validatePosted() {
        List<Account_Payable__c> validRecords = new List<Account_Payable__c>();
        for (Account_Payable__c accountPayable : accountPayables) {
            if (accountPayable.Status__c != 'Posted') {
                paymentResultDispatcher.addPaymentErrorResult(
                    accountPayable.Id,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.NOT_POSTED,
                        NOT_POSTED_ERROR_MESSAGE
                    )
                );
            }
            else {
                validRecords.add(accountPayable);
            }
        }

        accountPayables = validRecords;
    }

    protected void validateIsInvoice() {
        List<Account_Payable__c> validRecords = new List<Account_Payable__c>();
        for (Account_Payable__c accountPayable : accountPayables) {
            if (accountPayable.Type__c != 'Invoice') {
                paymentResultDispatcher.addPaymentErrorResult(
                    accountPayable.Id,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.NON_VALID_TYPE,
                        NON_VALID_TYPE_ERROR_MESSAGE
                    )
                );
            }
            else {
                validRecords.add(accountPayable);
            }
        }

        accountPayables = validRecords;
    }

    protected void validateNotPaid() {
        List<Account_Payable__c> validRecords = new List<Account_Payable__c>();
        for (Account_Payable__c accountPayable : accountPayables) {
            if (accountPayable.Payment_Status__c == 'Paid') {
                paymentResultDispatcher.addPaymentErrorResult(
                    accountPayable.Id,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.ALREADY_PAID,
                        ALREADY_PAID_ERROR_MESSAGE
                    )
                );
            }
            else {
                validRecords.add(accountPayable);
            }
        }

        accountPayables = validRecords;
    }

    protected void validateBalance() {
        List<Account_Payable__c> validRecords = new List<Account_Payable__c>();
        for (Account_Payable__c accountPayable : accountPayables) {
            if (accountPayable.Balance__c.setScale(2) <= 0) {
                paymentResultDispatcher.addPaymentErrorResult(
                    accountPayable.Id,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.ALREADY_PAID,
                        FULL_BALANCE_PAID_ERROR_MESSAGE
                    )
                );
            }
            else {
                validRecords.add(accountPayable);
            }
        }

        accountPayables = validRecords;
    }

    private void validateOnHoldPayables(){
        List<Account_Payable__c> validRecords = new List<Account_Payable__c>();
        for (Account_Payable__c accountPayable : accountPayables) {
            if (accountPayable.On_Hold__c == false) {
                validRecords.add(accountPayable);
            }
        }

        if(batchProcessing && accountPayables.size() > 0 &&  validRecords.size() == 0){
            paymentResultDispatcher.addPaymentErrorResult(
                paymentResultDispatcher.BLOCKER_ERROR_KEY,
                new PaymentResult.PaymentResultError(
                    PaymentResult.StatusCode.ON_HOLD_PAYABLE,
                    ERR_ON_PAYABLE_PAY_BATCH_PAGE_WHEN_ON_HOLD_IS_CHECKED
                )
            );
        }else if(batchProcessing && validRecords.size() > 0 && (validRecords.size() != accountPayables.size())){
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.INFO,
                    ERR_ON_PAYABLE_PAY_BATCH_PAGE_WHEN_ON_HOLD_IS_CHECKED
                )
            );
        }else if(batchProcessing == false && validRecords.size() == 0){
            paymentResultDispatcher.addPaymentErrorResult(
                paymentResultDispatcher.BLOCKER_ERROR_KEY,
                new PaymentResult.PaymentResultError(
                    PaymentResult.StatusCode.ON_HOLD_PAYABLE,
                    ERR_ON_PAYABLE_PAY_PARTIAL_PAGE_WHEN_ON_HOLD_IS_CHECKED
                )
            );
        }
        accountPayables = validRecords;
    }

    protected Boolean validate1099Type() {
        String formTypeId = uiCashDisbursement.Form_Category_Id__c;
        if(!String.isEmpty(formTypeId) && !X1099InfoHelper.validateFormTypeForDistributionDate(
                                                            formTypeId, 
                                                            uiCashDisbursement.Disbursement_Date__c)) {
            for (CashDisbursementWrapper cdw : wrappedCds) {
                cdw.cashDisbursement.addError(
                                        String.format(FORM_TYPE_INVALID_ERROR_MESSAGE, new List<String>{uiCashDisbursement.Disbursement_Date__c.format()}));
                paymentResultDispatcher.addPaymentErrorResult(
                    PaymentResultDispatcher.BLOCKER_ERROR_KEY,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.SYSTEM_EXCEPTION,
                        String.format(FORM_TYPE_INVALID_ERROR_MESSAGE, new List<String>{uiCashDisbursement.Disbursement_Date__c.format()})
                    )
                );
            }
            return false;                            
        }
        if (!String.isEmpty(formTypeId) && String.isEmpty(uiCashDisbursement.Form_1099_Box__c)) {
            for (CashDisbursementWrapper cdw : wrappedCds) {
                cdw.cashDisbursement.addError(FORM_CATEGORY_INVALID_ERROR_MESSAGE);
                paymentResultDispatcher.addPaymentErrorResult(
                    PaymentResultDispatcher.BLOCKER_ERROR_KEY,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.SYSTEM_EXCEPTION,
                        FORM_CATEGORY_INVALID_ERROR_MESSAGE
                    )
                );
            }   
            return false;                         
        }
        return true;
    }

    protected Boolean validate1099TypeBatch() {
        Boolean allValid = true;
        Set<String> formTypeIdAndDates = new Set<String>();
        List<String> badFormTypeIdAndDates = new List<String>();
        for (CashDisbursementWrapper cdw : wrappedCds) {
            if (cdw.isSelected && cdw.cashDisbursement.Form_Category_Id__c != NULL) {
                formTypeIdAndDates.add(cdw.cashDisbursement.Form_Category_Id__c + ':' + cdw.cashDisbursement.Disbursement_Date__c);                
            }
        }

        for (String formTypeIdAndDate : formTypeIdAndDates) {
            String[] values = formTypeIdAndDate.split(':');
            if (!X1099InfoHelper.validateFormTypeForDistributionDate(values[0], Date.valueOf(values[1]))) {
                badFormTypeIdAndDates.add(formTypeIdAndDate);
            }
        }

        for (CashDisbursementWrapper cdw : wrappedCds) {
            String formTypeId = cdw.cashDisbursement.Form_Category_Id__c;
            String formTypeIdAndDate = formTypeId + ':' + cdw.cashDisbursement.Disbursement_Date__c;
            if (!String.isEmpty(formTypeIdAndDate) && badFormTypeIdAndDates.contains(formTypeIdAndDate)) {
                cdw.cashDisbursement.addError(String.format(FORM_TYPE_INVALID_ERROR_MESSAGE, new List<String>{cdw.cashDisbursement.Disbursement_Date__c.format()}));
                paymentResultDispatcher.addPaymentErrorResult(
                    PaymentResultDispatcher.BLOCKER_ERROR_KEY,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.SYSTEM_EXCEPTION,
                        String.format(FORM_TYPE_INVALID_ERROR_MESSAGE, new List<String>{cdw.cashDisbursement.Disbursement_Date__c.format()})
                    )
                );             
                allValid = false;   
            }
    
            if (!String.isEmpty(formTypeId) && String.isEmpty(cdw.cashDisbursement.Form_1099_Box__c)) {
                cdw.cashDisbursement.addError(FORM_CATEGORY_INVALID_ERROR_MESSAGE);
                paymentResultDispatcher.addPaymentErrorResult(
                    PaymentResultDispatcher.BLOCKER_ERROR_KEY,
                    new PaymentResult.PaymentResultError(
                        PaymentResult.StatusCode.SYSTEM_EXCEPTION,
                        FORM_CATEGORY_INVALID_ERROR_MESSAGE
                    )
                );
                allValid = false;
            }   
        }
        return allValid;
    }

    protected void validateCashDisbursementsAccountingPeriod() {
        for (CashDisbursementWrapper cdw : wrappedCDs) {
            if (cdw.isSelected) {
                Accounting_Period__c thisAccountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(
                    cdw.cashDisbursement.Accounting_Period__c
                );

                if (!AccountingPeriodHandler.getInstance().isConsideredOpen(thisAccountingPeriod.Id, Cash_Disbursement__c.sObjectType)) {
                    cdw.cashDisbursement.Disbursement_Date__c.addError(
                        CLOSED_PERIOD_ERROR
                    );
                    paymentResultDispatcher.addPaymentErrorResult(
                        PaymentResultDispatcher.BLOCKER_ERROR_KEY,
                        new PaymentResult.PaymentResultError(
                            PaymentResult.StatusCode.NON_VALID_ACCOUNTING_PERIOD,
                            CLOSED_PERIOD_ERROR
                        )
                    );
                }
                else if (thisAccountingPeriod.Name < cdw.getMostRecentAccountingPeriod().Name) {
                    cdw.cashDisbursement.Disbursement_Date__c.addError(
                        Label.ERR_PERIOD_MUST_BE_ON_OR_AFTER + ' ' + cdw.getMostRecentAccountingPeriod().Name
                    );
                    paymentResultDispatcher.addPaymentErrorResult(
                        PaymentResultDispatcher.BLOCKER_ERROR_KEY,
                        new PaymentResult.PaymentResultError(
                            PaymentResult.StatusCode.NON_VALID_ACCOUNTING_PERIOD,
                            Label.ERR_PERIOD_MUST_BE_ON_OR_AFTER + ' ' + cdw.getMostRecentAccountingPeriod().Name
                        )
                    );
                }
            }
        }
    }

    protected Boolean validateAllPayablesHaveSameCurrency() {
        Boolean result = true;
        if (isMultiCurrencyEnabled) {
            Set<String> currencyIsoCodes = new Set<String>();
            //=======================================================================================================
            // CRUD for the Account_Payable__c object already has been checked at this point. No need to check again.
            // CurrencyIsoCode field is always visible
            //=======================================================================================================
            for (SObject accountPayable : Database.query('SELECT CurrencyIsoCode FROM Account_Payable__c WHERE Id IN :accountPayables')) {
                currencyIsoCode = (String) accountPayable.get('CurrencyIsoCode');
                currencyIsoCodes.add( (String) accountPayable.get('CurrencyIsoCode') );
            }

            if (currencyIsoCodes.size() > 1) {
                result = false;
            }
        }

        if (!result) {
            paymentResultDispatcher.addPaymentErrorResult(
                paymentResultDispatcher.BLOCKER_ERROR_KEY,
                new PaymentResult.PaymentResultError(
                    PaymentResult.StatusCode.NOT_SAME_CURRENCY,
                    NOT_SAME_CURRENCY_ERROR_MESSAGE
                )
            );
        }

        return result;
    }

    protected void validateNoQualifyingRecords() {
        if (accountPayables.isEmpty()) {
            paymentResultDispatcher.addPaymentErrorResult(
                paymentResultDispatcher.BLOCKER_ERROR_KEY,
                new PaymentResult.PaymentResultError(
                    PaymentResult.StatusCode.NO_QUALIFYING_RECORDS,
                    NO_QUALIFIED_RECORDS_SELECTED_ERROR_MESSAGE
                )
            );
        }
    }

    protected void validateAllPayablesHaveSameLedger() {
        Set<Id> ledgerIds = new Set<Id>();
        for (Account_Payable__c accountPayable : accountPayables) {
            if (accountPayable.Ledger__c == NULL) {
                accountPayable.Ledger__c = LedgerHandler.getLegacyDefaultLedgerId();
            }
            ledgerIds.add(accountPayable.Ledger__c);
        }
        if (ledgerIds.size() > 1) {
            paymentResultDispatcher.addPaymentErrorResult(
                paymentResultDispatcher.BLOCKER_ERROR_KEY,
                new PaymentResult.PaymentResultError(
                    PaymentResult.StatusCode.NOT_SAME_LEDGER,
                    NOT_SAME_LEDGER_ERROR_MESSAGE
                )
            );
        }
    }

    protected void processSystemExceptions(Exception ex) {
        paymentResultDispatcher.addPaymentErrorResult(
            paymentResultDispatcher.BLOCKER_ERROR_KEY,
            new PaymentResult.PaymentResultError(
                PaymentResult.StatusCode.SYSTEM_EXCEPTION,
                ex.getMessage()
            )
        );
    }

    protected void processDmlExceptions(DmlException dmlEx) {
        paymentResultDispatcher.addPaymentErrorResult(
            paymentResultDispatcher.BLOCKER_ERROR_KEY,
            new PaymentResult.PaymentResultError(
                PaymentResult.StatusCode.SYSTEM_EXCEPTION,
                dmlEx.getDmlMessage(0)
            )
        );
    }

    public void validateCashDisbusementStatusApproved(){
        Schema.DescribeFieldResult F = Cash_Disbursement__c.Status__c.getDescribe();
        List <Schema.PicklistEntry> pickVals = F.getPicklistValues();        
        for (Schema.PicklistEntry pv: pickVals) {
            if (pv.isDefaultValue() && pv.getValue() != AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED) {
                if (ApexPages.getMessages().isEmpty()) {
                    if (batchProcessing) {
                        ApexPages.addMessage(
                            new ApexPages.Message(
                                ApexPages.SEVERITY.WARNING,
                                CD_DEFAULT_STATUS_APPROVED_BATCH
                            )
                        );
                    } else {
                        ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.SEVERITY.WARNING,
                            CD_DEFAULT_STATUS_APPROVED
                        )
                    );
                    }
                }
                isDefaultCDApproved = false;
                return;
            }         
        }
        isDefaultCDApproved = true;
    }

    //=======================================================
    //=========== COMMON BUSINESS LOGIC METHODS ============
    //=======================================================
    @TestVisible
    protected List<PaymentResult> init(List<Account_Payable__c> payables, Boolean isBatchProcessing, Boolean isAggregateByPayee) {
        batchProcessing = (isBatchProcessing != NULL) ? isBatchProcessing : true;
        aggregateByPayee = (isAggregateByPayee != NULL) ? isAggregateByPayee : true;
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        isCashFlowStatementEnabled = getAccountingSettings().Enable_Cash_Flow_Statement__c;
        
        try {
            queryAccountPayables(payables);
            validatePosted();
            validateOnHoldPayables();
            validateIsInvoice();
            validateNotPaid();
            validateBalance();
            validateNoQualifyingRecords();
            validateAllPayablesHaveSameLedger();
            validateCashDisbusementStatusApproved();
            if (isMultiCurrencyEnabled && !accountPayables.isEmpty()) {
                validateAllPayablesHaveSameCurrency();
            }
            //check validation results ...
            if (paymentResultDispatcher.isGeneralErrorExists()) {
                throw new AccountPayablePaymentException(paymentResultDispatcher.getGeneralErrorResult().errors[0].message);
            }
            else {//and proceed further
                defaultBankId = LedgerHandler.getInstanceWithoutSharing().getLedgerById(accountPayables[0].Ledger__c).Default_Bank_Account__c;
                splitPaymentsByPayee();
                wrapCashDisbursements();
                initUiCashDisbursementBatch();
                initUiCashDisbursement();
                setInitialCurrencyAndCurrencyConversionRate();
                processPaymentResult(accountPayables);
            }
        }
        catch (Exception ex) {
            processSystemExceptions(ex);
        }
        return paymentResultDispatcher.getPaymentResults();
    }

    @TestVisible
    protected Cash_Disbursement_Batch__c provideCashDisbursementBatch() {
        Cash_Disbursement_Batch__c result = new Cash_Disbursement_Batch__c();
        try {
            if (uiCashDisbursement.Cash_Disbursement_Batch__c == NULL) {
                result.Name = uiCashDisbursementBatch.Name;
                result.Starting_Check_Number__c =
                    (uiCashDisbursement.Type__c == 'Check') ? uiCashDisbursementBatch.Starting_Check_Number__c : NULL;

                if (isMultiCurrencyEnabled) {
                    result.put('CurrencyIsoCode', currencyIsoCode);
                }

                SFDCSecurityUtils.insertCheckCRUDAndFLS(result, new List<String>{
                    'Starting_Check_Number__c'
                });
            }
            else {
                result.Id = uiCashDisbursement.Cash_Disbursement_Batch__c;

                if (isMultiCurrencyEnabled) {
                    //read access to the Cash Disbursement Batch record is controlled by UI
                    //so we just can do inline SOQL query - no need to check read access again
                    String query = 'SELECT Id, CurrencyIsoCode FROM Cash_Disbursement_Batch__c WHERE Id = \'' + result.Id + '\'';
                    result = (Cash_Disbursement_Batch__c) Database.query(query);
                    if (result.get('CurrencyIsoCode') != currencyIsoCode) {
                        throw new AccountPayablePaymentException(CashDisbursementActions.NOT_EQUAL_CURRENCY_ERROR);
                    }
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    @TestVisible
    protected List<PaymentResult> pay(Boolean isNeedToPost) {
        paymentResultDispatcher.clearResultsMap();
                SavePoint sp = Database.setSavepoint();
        try {
            cashDisbursementsToInsert = new List<Cash_Disbursement__c>();
            getSelectedCashDisbursements();
            if (cashDisbursementsToInsert.isEmpty()) {
                return paymentResultDispatcher.getPaymentResults();
            }
            validateCashDisbursementsAccountingPeriod();
            if (paymentResultDispatcher.isGeneralErrorExists()) {
                return paymentResultDispatcher.getPaymentResults();
            }
        
            Map<Id, Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesMap();

            Integer checkNum =
                (uiCashDisbursementBatch.Starting_Check_Number__c == NULL)
                    ? 0
                    : uiCashDisbursementBatch.Starting_Check_Number__c.intValue();

            cashDisbursementBatchToInsert = provideCashDisbursementBatch();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(accountPayables[0].Ledger__c);
            
            for (Cash_Disbursement__c cDisburse : cashDisbursementsToInsert) {
               cDisburse.Cash_Disbursement_Batch__c = cashDisbursementBatchToInsert.Id;
               cDisburse.Bank_Account__c = uiCashDisbursement.Bank_Account__c;

               //Set Cash Ledger source = Manual and default the Debit GL Account if null
               if ((accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_CASH
                    || accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL_AND_CASH)
                    ){
                    cDisburse.Source__c = CD_SOURCE_MANUAL;  
                    cDisburse.Debit_GL_Account__c = (uiCashDisbursement.Debit_GL_Account__c != NULL)? uiCashDisbursement.Debit_GL_Account__c : 
                                                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
                } else if ( accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL ){
                    
                    if(main.Cash_Disbursement_Source__c == CD_SOURCE_PAYABLE){
                    cDisburse.Source__c = CD_SOURCE_PAYABLE; 
                    cDisburse.Debit_GL_Account__c = (uiCashDisbursement.Debit_GL_Account__c != NULL)? uiCashDisbursement.Debit_GL_Account__c : 
                                                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
                    }else if(main.Cash_Disbursement_Source__c == CD_SOURCE_MANUAL){
                        cDisburse.Source__c = CD_SOURCE_MANUAL; 
                        cDisburse.Debit_GL_Account__c = (uiCashDisbursement.Debit_GL_Account__c != NULL)? uiCashDisbursement.Debit_GL_Account__c : 
                                                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
                    }
                }

                cDisburse.Type__c = uiCashDisbursement.Type__c;
                cDisburse.Check_Number__c = (uiCashDisbursement.Type__c == 'Check') ? checkNum : NULL;
               
                if (!batchProcessing) {
                    cDisburse.Reference__c = uiCashDisbursement.Reference__c;
                }
                String form1099Box;
                cDisburse.Form_Category_Id__c = uiCashDisbursement.Form_1099_Box__c != NULL ?
                                                    uiCashDisbursement.Form_1099_Box__c : 
                                                    cDisburse.Form_1099_Box__c;

                if (!String.isEmpty(cDisburse.Form_Category_Id__c)) {
                    Form_Category__mdt formCategory = formCategories.get(cDisburse.Form_Category_Id__c);
                    form1099Box = formCategory.Form_Type__r.Label + ' - ' + formCategory.Label;                    
                }
                cDisburse.Form_1099_Box__c = form1099Box;
                checkNum++;
            }

            CashDisbursementActions.isSourcedFromPayables = (!cashDisbursementsToInsert.isEmpty() && cashDisbursementsToInsert[0].Source__c == CD_SOURCE_MANUAL)?false:true;
            SFDCSecurityUtils.insertCheckCRUDAndFLS(cashDisbursementsToInsert, new List<String>{
                'Cash_Disbursement_Batch__c',
                'Bank_Account__c',
                'Debit_GL_Account__c',
                'Type__c',
                'Source__c',
                'Check_Number__c'
            });

            CashDisbursementActions.isSourcedFromPayables = false;
            List<AP_Disbursement__c> payDisbursements = new List<AP_Disbursement__c>();
            List<Account_Payable__c> updatePayments = new List<Account_Payable__c>();

            // loop through payment records and create ap disbursements and update payment status to paid
            for (CashDisbursementWrapper cdw : wrappedCDs) {
                if (cdw.isSelected) {
                    for (Account_Payable__c payment : cdw.payments) {
                        AP_Disbursement__c paymentDisburse = new AP_Disbursement__c();
                        paymentDisburse.Cash_Disbursement__c = cdw.cashDisbursement.Id;
                        paymentDisburse.Account_Payable__c = payment.Id;
                        paymentDisburse.Accounting_Period__c = cdw.cashDisbursement.Accounting_Period__c;
                        paymentDisburse.Applied_Date__c = cdw.cashDisbursement.Disbursement_Date__c;
                        if (batchProcessing) {//in batch context - only full payment is available
                            paymentDisburse.Paid_Amount__c =
                                payment.Total__c
                                    - ((payment.Discount_Amount__c != NULL) ? payment.Discount_Amount__c : 0)
                                    - ((payment.Reverse_Charge__c && payment.Purchase_Tax3__c != NULL) ? payment.Purchase_Tax3__c : 0)
                                    - payment.Paid_Amount__c
                                    - ((payment.Credit_Memo_Applied_Amount__c != NULL) ? payment.Credit_Memo_Applied_Amount__c : 0);
                        }
                        else {//in single record payment - any valid Amount is available for payment
                            paymentDisburse.Paid_Amount__c = uiCashDisbursement.Amount__c;
                        }

                        if (isMultiCurrencyEnabled) {
                            paymentDisburse.put('CurrencyIsoCode', currencyIsoCode);
                        }
                        payDisbursements.add(paymentDisburse);    
                        updatePayments.add(payment);
                    }
                }
            }

            TriggerObserver.getInstance().unlockField(Account_Payable__c.Discount_Amount__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updatePayments, new List<String>{'Payment_Status__c', 'Ledger__c', 'Discount_Amount__c'});
            TriggerObserver.purgeUnlockedFields(Account_Payable__c.Discount_Amount__c);

            CashDisbursementActions.isBatchPay = true;
            SFDCSecurityUtils.insertCheckCRUDAndFLS(payDisbursements, new List<String>{
                'Cash_Disbursement__c',
                'Account_Payable__c',
                'Paid_Amount__c'
            });

            processPaymentResult(updatePayments);

            if (isNeedToPost) {
                //post procedure will be completed in Sync or Async context
                //depending on Payment context (Single or Batch)
                postCashDisbursements();
            }

            return paymentResultDispatcher.getPaymentResults();
        }
        catch (DmlException dmlEx) {
            Database.rollback(sp);
            processDmlExceptions(dmlEx);
            return paymentResultDispatcher.getPaymentResults();
        }
        catch (Exception ex) {
            Database.rollback(sp);
            processSystemExceptions(ex);
            return paymentResultDispatcher.getPaymentResults();
        }
    }

    private void postCashDisbursements() {
        if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            new PostProcessor().post(new List<Id>(new Map<Id, SObject>(cashDisbursementsToInsert).keySet()));
        } else if (!FeatureManagementHandler.isLargeDataVolumeModeEnabled() && batchProcessing) {
            asyncPostCashDisbursements((List<String>) new List<Id>(new Map<Id, SObject>(cashDisbursementsToInsert).keySet()));
        } else {
            postCashDisbursements((List<String>) new List<Id>(new Map<Id, SObject>(cashDisbursementsToInsert).keySet()));
        }
    }

    private void postCashDisbursements(List<String> cdIds) {
        AbstractPostHandler postHandler = new CashDisbursementPostHandler();
        postResults = postHandler.post(cdIds);
        if (!processPostResultsAfterPost()) {
            String errorMessage = postResults[0].errors[0].message;
            if(errorMessage == Label.INF_STATUS_NOT_APPROVED_HELP_TEXT){
                errorMessage = Label.WRN_CD_DEFAULT_STATUS_APPROVED;
            }
            throw new AccountPayablePaymentException(errorMessage);
        }
    }

    @Future
    private static void asyncPostCashDisbursements(List<String> cdIds) {
        List<PostResult> results = new PostProcessor().post((List<Id>)cdIds);
        createAJRRecords(results);
    }
    private static void createAJRRecords(List<PostResult> results){
        String jobName = 'Async Post or Unpost Job';
        String reportName = 'Async Post or Unpost Job' + Cash_Disbursement__c.getSObjectType().getDescribe().getLabelPlural();
        //varibale will hold the counts
        Integer processedRecords = results.size(),failedRecords = 0;
        //all falied post results
        List<PostResult> failedResults = new List<PostResult>();

        //iterate to create AJR and tasks for relative records
        for(PostResult result : results){
            if(!result.isSuccess){
                failedResults.add(result);
                failedRecords+=1;
            }
        }
        //create AJr record
        AutomatedJobResultsHandler.setJobType(jobName);
        AutomatedJobResultsHandler.setProcessed(processedRecords);
        AutomatedJobResultsHandler.setSucceeded((processedRecords - failedRecords));
        AutomatedJobResultsHandler.setFailed(failedRecords);
        AutomatedJobResultsHandler.setError(AutomatedJobResultsHandler.getReportLink(reportName));
        AutomatedJobResultsHandler.saveAutomatedJobResults();

        //log activities if failed
        if(!failedResults.isEmpty()){
            logOnActivity(failedResults);
        }
    }
    private static void logOnActivity(List<PostResult> failedResults) {
        List<Task> tasks = new List<Task>();
        //create tasks for all failed CDs and set them in open status
        for (PostResult postResult : failedResults) {
            tasks.add(
                FinancialSuiteUtils.setTask(
                    postResult.id,
                    'Open',
                    NULL,
                    Label.COMMON_ERR_CANNOT_POST_RECORD,
                    postResult.errors.get(0).message,
                    NULL
                )
            );
        }

        if (!tasks.isEmpty()) {
            SFDCSecurityUtils.insertProxy(tasks);
        }
    }

    private void initUiCashDisbursement() {
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(accountPayables[0].Ledger__c);
        uiCashDisbursement = new Cash_Disbursement__c();
        uiCashDisbursement.Type__c = CashDisbursementActions.getDefaultTypePicklistValue();
        uiCashDisbursement.Bank_Account__c = defaultBankId;
        uiCashDisbursement.Ledger__c = accountPayables[0].Ledger__c;
        uiCashDisbursement.Cash_Flow_Category__c = (isCashFlowStatementEnabled) ?
            defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_DISBURSEMENT_CATEGORY)?.GL_Account__c
            : NULL;
        uiCashDisbursement.Disbursement_Date__c = accountPayables[0].Accounting_Period__r.Start_Date__c > Date.today() ?
                accountPayables[0].Accounting_Period__r.Start_Date__c : Date.today();
        if (isMultiCurrencyEnabled) {
            uiCashDisbursement.put('CurrencyIsoCode', currencyIsoCode);
        }   

        if (accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_CASH
            || accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL_AND_CASH) {
            uiCashDisbursement.Source__c = CD_SOURCE_MANUAL;
        } else if (accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL && main.Cash_Disbursement_Source__c == CD_SOURCE_PAYABLE)
        {
            uiCashDisbursement.Source__c = CD_SOURCE_PAYABLE;
        }
        else if (accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL && main.Cash_Disbursement_Source__c == CD_SOURCE_MANUAL) {
            uiCashDisbursement.Source__c = CD_SOURCE_MANUAL;
        }

        //Default Debit GL Account for Cash and Accrual Ledgers
        if (accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_CASH) {
            uiCashDisbursement.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
        } else if ((accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL_AND_CASH
                || accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL )) {
            if (main.Cash_Disbursement_Source__c == CD_SOURCE_PAYABLE) {
                uiCashDisbursement.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            } else if (main.Cash_Disbursement_Source__c == CD_SOURCE_MANUAL) {
                uiCashDisbursement.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
            }
        }

        String formBoxId;
        String formTypeId;
        if (accountPayables[0].Vendor__c != NULL && accountPayables[0].Vendor__r.X1099_Vendor__c == true) {            
            is1099Vendor = true;
            formBoxId = accountPayables[0].Vendor__r.Default_Form_Category_Id__c;
            formTypeId = !String.isEmpty(formBoxId) ? 
                            X1099InfoHelper.getFormCategoryById(formBoxId).Form_Type__r.Id :
                            NULL;
        } else if (GlobalVariables.isPersonAccountEnabled
            && accountPayables[0].Contact__c != NULL
            && accountPayables[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('IsPersonAccount') == true) {
            List<Account> personAccounts = DomainUtils.getAccountsById(new Set<Id> {(Id) accountPayables[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('AccountId')});
            if (personAccounts[0].X1099_Vendor__c == true) {
                is1099Vendor = true;
                formBoxId = personAccounts[0].Default_Form_Category_Id__c;
                formTypeId = !String.isEmpty(formBoxId) ?
                    X1099InfoHelper.getFormCategoryById(formBoxId).Form_Type__r.Id :
                    NULL;
            }
        } else if (accountPayables[0].Contact__c != NULL && accountPayables[0].Contact__r.X1099_Vendor__c == true) {
            is1099Vendor = true;
            formBoxId = accountPayables[0].Contact__r.Default_Form_Category_Id__c;
            formTypeId = !String.isEmpty(formBoxId) ?
                            X1099InfoHelper.getFormCategoryById(formBoxId).Form_Type__r.Id :
                            NULL;
        }
        if (X1099InfoHelper.validateFormTypeForDistributionDate(formTypeId, uiCashDisbursement.Disbursement_Date__c)) {
            uiCashDisbursement.Form_1099_Box__c = formBoxId;
            uiCashDisbursement.Form_Category_Id__c = formTypeId;
        }
        
        if (!batchProcessing) {

            uiCashDisbursement.Amount__c =
                isVendorDiscountWarning
                    ? accountPayables[0].Balance__c
                        - (accountPayables[0].Discount_Amount__c != NULL ? accountPayables[0].Discount_Amount__c : 0)
                    : accountPayables[0].Balance__c;

            uiCashDisbursement.GL_Account_Variable_1__c = accountPayables[0].Vendor__r.GL_Account_Variable_1__c;
            uiCashDisbursement.GL_Account_Variable_2__c = accountPayables[0].Vendor__r.GL_Account_Variable_2__c;
            uiCashDisbursement.GL_Account_Variable_3__c = accountPayables[0].Vendor__r.GL_Account_Variable_3__c;
            uiCashDisbursement.GL_Account_Variable_4__c = accountPayables[0].Vendor__r.GL_Account_Variable_4__c;

        }

        if((accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL || accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_CASH) && uiCashDisbursement.Source__c == CD_SOURCE_MANUAL){
                isShowDebitGLAccountField = true;
            }
        else if((uiCashDisbursement.Source__c == CD_SOURCE_MANUAL && accountPayables[0].Ledger__r.Accounting_Method__c == LEDGER_ACCOUNTING_METHOD_ACCRUAL_AND_CASH) || uiCashDisbursement.Source__c == CD_SOURCE_PAYABLE ){
            isShowDebitGLAccountField = false;
        }
    }

    private void initUiCashDisbursementBatch() {
        uiCashDisbursementBatch = new Cash_Disbursement_Batch__c();
        uiCashDisbursementBatch.Name =
            (batchProcessing) ? System.now().format() : accountPayables[0].Payee__c + ' ' + System.now().format();
        uiCashDisbursementBatch.Starting_Check_Number__c =
            AccountPayablePaymentHandler.refreshCheckNumber(defaultBankId);
    }

    protected void getSelectedCashDisbursements() {
        for (CashDisbursementWrapper cdw : wrappedCDs) {
            if (cdw.isSelected) {
                cdw.cashDisbursement.Accounting_Period__c =
                    AccountingPeriodHandler.getInstance()
                        .getAccountingPeriodByDate(cdw.cashDisbursement.Disbursement_Date__c).Id;
                cdw.cashDisbursement.Id = null;
                cashDisbursementsToInsert.add(cdw.cashDisbursement);
            }
        }

        if (cashDisbursementsToInsert.isEmpty()) {
            paymentResultDispatcher.addPaymentErrorResult(
                paymentResultDispatcher.BLOCKER_ERROR_KEY,
                new PaymentResult.PaymentResultError(
                    PaymentResult.StatusCode.NO_QUALIFYING_RECORDS,
                    NO_SELECTED_CASH_DISBURSEMENT_ERROR_MESSAGE
                )
            );
        }
    }

    protected void wrapCashDisbursements() {
        wrappedCDs = new List<CashDisbursementWrapper>();

        if (!paymentsToVendorAsPayee.isEmpty()) {
            wrappedCDs.addAll(
                processPayables(
                    paymentsToVendorAsPayee,
                    AccountPayablePaymentHandler.PayeeType.VENDOR
                )
            );
        }

        if (!paymentsToContactAsPayee.isEmpty()) {
            if (GlobalVariables.isPersonAccountEnabled) {
                setPersonAccountMap();
            }
            wrappedCDs.addAll(
                processPayables(
                    paymentsToContactAsPayee,
                    AccountPayablePaymentHandler.PayeeType.CONTACT
                )
            );
        }

        if (!paymentsToEmployeeAsPayee.isEmpty()) {
            wrappedCDs.addAll(
                processPayables(
                    paymentsToEmployeeAsPayee,
                    AccountPayablePaymentHandler.PayeeType.EMPLOYEE
                )
            );
        }

        if (wrappedCDs.isEmpty()) {
            paymentResultDispatcher.addPaymentErrorResult(
                paymentResultDispatcher.BLOCKER_ERROR_KEY,
                new PaymentResult.PaymentResultError(
                    PaymentResult.StatusCode.NO_QUALIFYING_RECORDS,
                    NO_QUALIFIED_RECORDS_SELECTED_ERROR_MESSAGE
                )
            );
        }
        else {
            this.areAnyPayees1099 = false;
            for (CashDisbursementWrapper wrapper : wrappedCDs) {
                if (wrapper.isPersonAccountPayee) {
                    wrapper.is1099Vendor = personAccounts.get(wrapper.getPersonAccountId()).X1099_Vendor__c;
                }
                if (wrapper.is1099Vendor) {
                    this.areAnyPayees1099 = true;
                }
            }
            wrappedCDs.sort();
        }        
        reconcile1099Info();
        updateBoxes();

    }

    private void setPersonAccountMap() {
        for (Id contact : paymentsToContactAsPayee.keySet()) {
            if (paymentsToContactAsPayee.get(contact)[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('IsPersonAccount') == true) {
                personAccounts.put((Id) paymentsToContactAsPayee.get(contact)[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('AccountId'), null);
            }
        }
        if (!personAccounts.keySet().isEmpty()) {
            personAccounts = new Map<Id, Account> (DomainUtils.getAccountsById(personAccounts.keySet()));
        }
    }

    protected void setInitialCurrencyAndCurrencyConversionRate() {

        if (isMultiCurrencyEnabled) {

            //extract all Cash Disbursements from wrapped records
            List<SObject> cdSObjects = new List<SObject>();
            for (CashDisbursementWrapper eachWrappedCD : wrappedCDs) {
                eachWrappedCD.cashDisbursement.put('CurrencyIsoCode', currencyIsoCode);
                cdSObjects.add(eachWrappedCD.cashDisbursement);
            }

            MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(
                NULL,
                cdSObjects,
                'Disbursement_Date__c'
            );

            if (!batchProcessing) {
                uiCashDisbursement.Currency_Conversion_Rate__c = wrappedCDs[0].cashDisbursement.Currency_Conversion_Rate__c;
            }
        }

    }

    private Id getPayeeId(Account_Payable__c payable, AccountPayablePaymentHandler.PayeeType payeeType) {
        Id payeeId = payable.Vendor__c;//Vendor by default
        if (payeeType == AccountPayablePaymentHandler.PayeeType.CONTACT) {
            payeeId = payable.Contact__c;
        }
        else if (payeeType == AccountPayablePaymentHandler.PayeeType.EMPLOYEE) {
            payeeId = payable.Employee__c;
        }
        return payeeId;
    }

    private String getPayeeName(Account_Payable__c payable, AccountPayablePaymentHandler.PayeeType payeeType) {
        String payeeName = payable.Vendor__r.Name;//Vendor by default
        if (payeeType == AccountPayablePaymentHandler.PayeeType.CONTACT) {
            payeeName = payable.Contact__r.Name;
        }
        else if (payeeType == AccountPayablePaymentHandler.PayeeType.EMPLOYEE) {
            payeeName = payable.Employee__r.Name;
        }
        return payeeName;
    }

    protected void splitPaymentsByPayee() {
        paymentsToVendorAsPayee = new Map<Id, List<Account_Payable__c>>();
        paymentsToContactAsPayee = new Map<Id, List<Account_Payable__c>>();
        paymentsToEmployeeAsPayee = new Map<Id, List<Account_Payable__c>>();

        // Loop through account payable records and aggregate by payment payee
        for (Account_Payable__c payment : accountPayables) {
            Id paymentId;

            if (payment.Contact__c != NULL) {
                paymentId = aggregateByPayee ? payment.Contact__c : payment.Id;
                if (paymentsToContactAsPayee.containsKey(paymentId)) {
                    paymentsToContactAsPayee.get(paymentId).add(payment);
                }
                else {
                    paymentsToContactAsPayee.put(paymentId, new List<Account_Payable__c>{payment});
                }
            }
            else if (payment.Vendor__c != NULL) {
                paymentId = aggregateByPayee ? payment.Vendor__c : payment.Id;
                if (paymentsToVendorAsPayee.containsKey(paymentId)) {
                    paymentsToVendorAsPayee.get(paymentId).add(payment);
                }
                else {
                    paymentsToVendorAsPayee.put(paymentId, new List<Account_Payable__c>{payment});
                }
            }
            else if (payment.Employee__c != NULL) {
                paymentId = aggregateByPayee ? payment.Employee__c : payment.Id;
                if (paymentsToEmployeeAsPayee.containsKey(paymentId)) {
                    paymentsToEmployeeAsPayee.get(paymentId).add(payment);
                }
                else {
                    paymentsToEmployeeAsPayee.put(paymentId, new List<Account_Payable__c>{payment});
                }
            }
        }
    }

    private List<CashDisbursementWrapper> processPayables(  Map<Id, List<Account_Payable__c>> payablesByPayeeMap,
                                                            AccountPayablePaymentHandler.PayeeType payeeType) {

        List<CashDisbursementWrapper> result = new List<CashDisbursementWrapper>();
        Map<Id, Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesMap();
        for (List<Account_Payable__c> payments : payablesByPayeeMap.values()) {
            Decimal sum = 0;
            Decimal discountAmountSum = 0;
            Decimal taxAmountSum = 0;
            Decimal creditMemoAmountSum = 0;
            Decimal paidAmountSum = 0;
            Id payeeId;
            String payeeName;
            Date disbursementDate = Date.today();

            for (Account_Payable__c payment : payments) {

                Decimal discountAmount = 0;
                Decimal taxAmount = (payment.Reverse_Charge__c && payment.Purchase_Tax3__c != NULL) ? payment.Purchase_Tax3__c : 0;
                Decimal creditMemoAmount = (payment.Credit_Memo_Applied_Amount__c != NULL) ? payment.Credit_Memo_Applied_Amount__c : 0;

                // This if block to ensure discount amount populated field always takes precedence over
                // calculating from vendor account
                if (payeeType == AccountPayablePaymentHandler.PayeeType.VENDOR) {
                    if (payment.Discount_Amount__c != NULL && payment.Discount_Amount__c != 0 && (creditMemoAmount == 0 || payment.Paid_Amount__c == 0)) {
                        discountAmount = payment.Discount_Amount__c;
                    }                   
                    else if (isVendorDiscountApplicable(payment)) {
                        //Reverse-Charge Tax must be excluded from Total before use it as base amount for discount calculation
                        Decimal discountBase = payment.Total__c - taxAmount;
                        
                        //back the credit memo applied amount out of the total before calculating the discount
                        discountBase -= payment.Credit_Memo_Applied_Amount__c > 0 ? payment.Credit_Memo_Applied_Amount__c : 0;

                        payment.Discount_Amount__c =
                            (discountBase * (payment.Vendor__r.Discount_Percent__c / 100))
                                .setScale(2, System.RoundingMode.HALF_UP);
                        discountAmount = payment.Discount_Amount__c;
                        isVendorDiscountWarning = true;
                    }
                }
                else {//If Payee is Contact or Employee(User)
                    discountAmount = (payment.Discount_Amount__c != NULL && (creditMemoAmount == 0 || payment.Paid_Amount__c == 0)) ? payment.Discount_Amount__c : 0;
                }

                discountAmountSum += discountAmount;
                taxAmountSum += taxAmount;
                creditMemoAmountSum += creditMemoAmount;
                paidAmountSum += ((payment.Paid_Amount__c != NULL) ? payment.Paid_Amount__c : 0);
                sum += payment.Total__c - payment.Paid_Amount__c - discountAmount - taxAmount - creditMemoAmount;
                payeeId = getPayeeId(payment, payeeType);
                payeeName = getPayeeName(payment, payeeType);
                disbursementDate = payment.Accounting_Period__r.Start_Date__c > disbursementDate ? payment.Accounting_Period__r.Start_Date__c : disbursementDate;
            }
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(payments[0].Ledger__c);
            Cash_Disbursement__c cDisburse = new Cash_Disbursement__c();
            cDisburse.Amount__c = sum;
            cDisburse.Source__c = 'Payable';
            cDisburse.Payment_Status__c = 'Paid';
            cDisburse.Disbursement_Date__c = disbursementDate;
            cDisburse.Ledger__c = payments[0].Ledger__c;
            cDisburse.Cash_Flow_Category__c = (isCashFlowStatementEnabled) ?
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_DISBURSEMENT_CATEGORY)?.GL_Account__c : NULL;

            if (payeeType == AccountPayablePaymentHandler.PayeeType.VENDOR) {
                cDisburse.Vendor__c = payeeId;
                cDisburse.GL_Account_Variable_1__c =
                        payments[0].Vendor__r.GL_Account_Variable_1__c;
                cDisburse.GL_Account_Variable_2__c =
                        payments[0].Vendor__r.GL_Account_Variable_2__c;
                cDisburse.GL_Account_Variable_3__c =
                        payments[0].Vendor__r.GL_Account_Variable_3__c;
                cDisburse.GL_Account_Variable_4__c =
                        payments[0].Vendor__r.GL_Account_Variable_4__c;
                if (payments[0].Vendor__r.X1099_Vendor__c) {
                    String formBoxId = payments[0].Vendor__r.Default_Form_Category_Id__c;
                    String formTypeId = !String.isEmpty(formBoxId) ? 
                            formCategories.get(formBoxId).Form_Type__r.Id :
                            NULL;
                    cDisburse.Form_Category_Id__c = formTypeId;
                    cDisburse.Form_1099_Box__c = formBoxId;
                }
            }
            if (payeeType == AccountPayablePaymentHandler.PayeeType.CONTACT) {
                cDisburse.Contact__c = payeeId;
                Boolean isX1099Vendor = payments[0].Contact__r.X1099_Vendor__c;
                Id personAccountId;

                if (GlobalVariables.isPersonAccountEnabled && payments[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('IsPersonAccount') == true) {
                    personAccountId = (Id) payments[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('AccountId');
                    isX1099Vendor = personAccounts.get(personAccountId).X1099_Vendor__c;
                }

                if (isX1099Vendor) {
                    String formBoxId = personAccountId != null ? personAccounts.get(personAccountId).Default_Form_Category_Id__c : payments[0].Contact__r.Default_Form_Category_Id__c;
                    String formTypeId = !String.isEmpty(formBoxId) ? 
                            formCategories.get(formBoxId).Form_Type__r.Id :
                            NULL;
                    cDisburse.Form_Category_Id__c = formTypeId;
                    cDisburse.Form_1099_Box__c = formBoxId;
                }
            }
            if (payeeType == AccountPayablePaymentHandler.PayeeType.EMPLOYEE) {
                cDisburse.Employee__c = payeeId;
            }

            if (sum >= 0) {
                result.add(
                    new CashDisbursementWrapper(
                        cDisburse,
                        payeeName,
                        discountAmountSum,
                        taxAmountSum,
                        creditMemoAmountSum,
                        paidAmountSum,
                        payments
                    )
                );
            }
        }

        return result;
    }

    @TestVisible
    private Boolean isVendorDiscountApplicable(Account_Payable__c payable) {
        Boolean result = false;
        Date todayDate = (Test.isRunningTest()) ? payable.Date__c : Date.today();
        if (payable.Vendor__r.Discount_Days_Due__c != NULL
                && payable.Vendor__r.Discount_Percent__c != NULL
                && payable.Vendor__r.Discount_Percent__c != 0
                && payable.Type__c == 'Invoice'
                && payable.Date__c.daysBetween(todayDate) <= payable.Vendor__r.Discount_Days_Due__c
                && payable.Paid_Amount__c == 0) {

            result = true;
        }
        return result;
    }
    //=======================================================
    //=========== ERRORS PROCESSING =========================
    protected Boolean processPaymentResults() {
        badResults = new List<PaymentResult>();

        for (PaymentResult result : results) {
            if (!result.isSuccess) {
                badResults.add(result);
            }
        }

        if (!badResults.isEmpty()) {
            if (batchProcessing) {
                //in case of batch payment - only general errors will block the process
                if (paymentResultDispatcher.isGeneralErrorExists()) {
                    if (ApexPages.getMessages().isEmpty()) {
                        ApexPages.addMessage(
                            new ApexPages.Message(
                                ApexPages.SEVERITY.ERROR,
                                paymentResultDispatcher.getGeneralErrorResult().errors[0].message
                            )
                        );
                    }
                    return false;
                }
                else {
                    return true;
                }
            }
            else {//in case of single record payment - any error is blocker
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        badResults[0].errors[0].message
                    )
                );
                return false;
            }
        }
        else {
            return true;
        }
    }

    protected Boolean processPostResultsAfterPost() {
        badPostResults = new List<PostResult>();

        for (PostResult result : postResults) {
            if (!result.isSuccess) {
                badPostResults.add(result);
            }
        }

        if (!badPostResults.isEmpty()) {
            String errorMessage = badPostResults[0].errors[0].message;
            if(errorMessage == Label.INF_STATUS_NOT_APPROVED_HELP_TEXT){
                errorMessage = Label.WRN_CD_DEFAULT_STATUS_APPROVED;
            }
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    errorMessage
                )
            );
            return false;
        }
        else {
            return true;
        }
    }

    protected void processPaymentResult(List<Account_Payable__c> paidPayables) {
        for (Account_Payable__c payable : paidPayables) {
            paymentResultDispatcher.addPaymentResult(payable.Id, new PaymentResult(true, payable.Id, NULL));
        }
    }

    //=========== JS Remote methods ================================
    @RemoteAction
    public static String refreshCashDisbursementBatchName(String cdbId) {
        String result = '';
        List<String> queryFields = new List<String>{'Id', 'Name'};
        String queryCondition = 'Id = :cdbId';

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement_Batch__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        List<Cash_Disbursement_Batch__c> cdbs = (List<Cash_Disbursement_Batch__c>) Database.query(theQuery.toSOQL());
        if (!cdbs.isEmpty()) {
            result = cdbs[0].Name;
        }
        return result;
    }

    @RemoteAction
    public static Decimal refreshCheckNumber(String bankAccountId) {
        return CheckUtils.getNextCheckNumber(bankAccountId);
    }

    @RemoteAction
    public static Decimal queryCurrencyConversionRate(String recordDateString, String currencyIsoCode, String ledgerId) {
        Decimal result;
        Date recordDate = Date.parse(recordDateString);
        //===================================================================================
        // Do NOT check user access to DatedConversionRate. This is a system managed resource.
        //===================================================================================
        Cash_Disbursement__c proxyRecord = new Cash_Disbursement__c(
            Ledger__c = ledgerId,
            Disbursement_Date__c = recordDate
        );
        proxyRecord.put('CurrencyIsoCode', currencyIsoCode);

        MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(
            NULL,
            new List<Sobject> {proxyRecord},
            'Disbursement_Date__c'
        );

        result = proxyRecord.Currency_Conversion_Rate__c;
        return result;
    }

}