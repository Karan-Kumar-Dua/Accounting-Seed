public with sharing class CashDisbursementApplyAccountPayable {
   //labels
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final Integer MAX_RECORD_COUNT = 2000;
    private static final List<String> sortColumns = new List<String>{
        'Name',
        PACKAGE_QUALIFIER + 'Payee_Reference__c',
        PACKAGE_QUALIFIER + 'Date__c',
        PACKAGE_QUALIFIER + 'Due_Date__c',
        PACKAGE_QUALIFIER + 'Total__c',
        PACKAGE_QUALIFIER + 'Credit_Memo_Applied_Amount__c',
        PACKAGE_QUALIFIER + 'Balance__c'
    };
    private static final List<String> sortOrder = new List<String>{'ASC', 'DESC'};
    public static final String LAST_MODIFIED_ERROR = Label.ERR_CD_LAST_MODIFIED;
    public static final String AMOUNT_LESS_THAN_ZERO_ERROR = Label.ERR_AMOUNT_NOT_POSITIVE_NUMBER;
    public static final String CD_BALANCE_LESS_THAN_ZERO_ERROR = Label.ERR_CD_BALANCE_LESS_THAN_ZERO;
    public static final String ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO_ERROR = Label.ERR_ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO;
    public static final String ACCOUNT_PERIOD_NOT_VALID_ERROR = Label.ERR_AP_APPLIED_GREATER_THAN_AP_PAYABLE;
    public static final String NO_MATCHING_ACCOUNT_PAYABLE_RECORDS_FOUND_ERROR = Label.ERR_CD_NO_MATCHING_ACCOUNT_PAYABLE_RECORDS;
    public static final String VOIDED_CD_ERROR = Label.COMMON_VOIDED_CD_ERROR;

    private Map<Id, AP_Disbursement__c> apIdToAPDisbursement {get; set;}
    private Set<Id> appliedAPIds {get; set;}
    private Decimal balance;
    private Id payeeId;
    private Boolean isLedgerEqualLegacyLedger;
    private Id ledgerId;

    public Boolean IS_MULTI_CURRENCY_ENABLED {get; private set;}
    public String currencyIsoCode {get; private set;}
    private Decimal currencyConversionRate {get; set;}

    public Integer offset {get; set;}
    public Integer recLimit {get; set;}
    public Integer recordSetSize {get; set;}
    public Integer sortFieldIndex {get; set;}
    public Integer sortOrderIndex {get; set;}
    public Decimal appliedAmount {get; set;}

    public ExecutionStatusDispatcher execStatusDispatcher {get; set;}

    public Cash_Disbursement__c cashDisbursement {get; set;}
    private String cashDisbursementId;
    public List<APDisbursementWrapper> wrappedRecords {get; set;}

    //====================================================================================
    //========================= CONSTRUCTOR ============================================
    //====================================================================================
    public CashDisbursementApplyAccountPayable(ApexPages.StandardController stdController) {
        try {
            this.execStatusDispatcher = new ExecutionStatusDispatcher();
            this.IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.cashDisbursementId = stdController.getId();
            this.cashDisbursement = queryCashDisbursement();
            this.cashDisbursement.Ledger__c = this.ledgerId = cashDisbursement.Ledger__c != NULL ?
                    cashDisbursement.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
            this.isLedgerEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(ledgerId);
            this.payeeId = getPayeeId();

            if (IS_MULTI_CURRENCY_ENABLED) {
                this.currencyIsoCode = (String) cashDisbursement.get('CurrencyIsoCode');
                this.currencyConversionRate = cashDisbursement.Currency_Conversion_Rate__c;
            }

            //First step validation
            validateOnLoad();
            if (execStatusDispatcher.getIsErrorState()) {
                return;
            }

            this.apIdToAPDisbursement = queryExistedAPDisbursements();
            this.appliedAPIds = apIdToAPDisbursement.keySet();

            //=================================================================
            // No need to check CRUD and FLS because is is checked in the initialRecordsLoad method 
            // on the exact same record set. Performing CRUD and FLS check here would be redundant.
            //=================================================================
            this.recordSetSize = Database.countQuery(
                'SELECT count() ' +
                'FROM ' + PACKAGE_QUALIFIER + 'Account_Payable__c ' +
                'WHERE ' + PACKAGE_QUALIFIER + 'Type__c = \'Invoice\' ' +
                'AND ((' + PACKAGE_QUALIFIER + 'Balance__c > 0 ' +
                'AND ' + PACKAGE_QUALIFIER + 'Status__c = \'Posted\' ' +
                'AND ((' + PACKAGE_QUALIFIER + 'Vendor__c != NULL AND ' + PACKAGE_QUALIFIER + 'Vendor__c = :payeeId) OR (' + PACKAGE_QUALIFIER + 'Contact__c != NULL AND ' + PACKAGE_QUALIFIER + 'Contact__c = :payeeId) OR (' + PACKAGE_QUALIFIER + 'Employee__c != NULL AND ' + PACKAGE_QUALIFIER + 'Employee__c = :payeeId))) ' +
                ' OR Id IN :appliedAPIds) ' +
                (
                    (IS_MULTI_CURRENCY_ENABLED)
                        ? ' AND CurrencyIsoCode = :currencyIsoCode '
                        : ' '
                ) +
                'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
                (isLedgerEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
                (!isLedgerEqualLegacyLedger ? ') ' : ' ') +
                'LIMIT :MAX_RECORD_COUNT'
            );

            this.offset = offset == NULL ? 0 : offset;
            this.recLimit = recLimit == NULL ? 10 : recLimit;
            this.sortFieldIndex = sortFieldIndex == NULL ? 0 : sortFieldIndex;
            this.sortOrderIndex = sortOrderIndex == NULL ? 1 : sortOrderIndex;

            initialRecordsLoad();
        }
        catch (Exception ex) {
            execStatusDispatcher.isExceptionThrown = true;
            ApexPages.addMessages(ex);
        }

    }
    //========================================================================================

    private Id getPayeeId() {
        Id result;
        if (cashDisbursement.Vendor__c != NULL) {
            result = cashDisbursement.Vendor__c;
        }
        else if (cashDisbursement.Contact__c != NULL) {
            result = cashDisbursement.Contact__c;
        }
        else if (cashDisbursement.Employee__c != NULL) {
            result = cashDisbursement.Employee__c;
        }
        return result;
    }

    private Cash_Disbursement__c queryCashDisbursement() {
        //need Dynamic SOQL because the "CurrencyIsoCode" field will be not visible in non-multi-currency orgs
        //define fields to query
        List<String> fieldsToQuery = new List<String>{
            'Id',
            'Name',
            'Accounting_Period__c',
            'Status__c',
            'Payment_Status__c',
            'Vendor__c',
            'Ledger__c',
            'Payee__c',
            'Contact__c',
            'Employee__c',
            'Amount__c',
            'Applied_Amount__c',
            'Cash_Disbursement_Batch__c',
            'Balance__c',
            'Currency_Conversion_Rate__c',
            'Debit_GL_Account__c',
            'Project__c',
            'Project_Task__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'LastModifiedDate'
        };
        //add MC field
        if (IS_MULTI_CURRENCY_ENABLED) {
            fieldsToQuery.add('CurrencyIsoCode');
        }
        //set query condition
        String queryCondition = 'Id = :cashDisbursementId';
        //Final assembly of SOQL string
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Cash_Disbursement__c.SObjectType,
            queryCondition,
            true,
            true
        );
        //Call DML operation
        List<Cash_Disbursement__c> results = (List<Cash_Disbursement__c>) Database.query(dynamicSOQL);
        return (results.isEmpty()) ? NULL : results[0];
    }

    private String buildAccountPayableSOQLQuery() {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Type__c',
            'Date__c',
            'Due_Date__c',
            'Total__c',
            'Paid_Amount__c',
            'Net_Amount__c',
            'Discount_Amount__c',
            'Balance__c',
            'Ledger__c',
            'Credit_Memo_Applied_Amount__c',
            'Payee_Reference__c',
            'Status__c',
            'Vendor__c',
            'Contact__c',
            'Employee__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Status__c',
            'Accounting_Period__r.Start_Date__c',
            'Proprietary_Payable_Number__c',
            'Purchase_Tax3__c',
            'Reverse_Charge__c'
        };
        //set query condition
        String queryCondition =
            PACKAGE_QUALIFIER + 'Type__c = \'Invoice\' ' +
            'AND ((' + PACKAGE_QUALIFIER + 'Balance__c > 0 ' +
            'AND ' + PACKAGE_QUALIFIER + 'Status__c = \'Posted\' ' +
            'AND ((' + PACKAGE_QUALIFIER + 'Vendor__c != NULL AND ' + PACKAGE_QUALIFIER + 'Vendor__c = :payeeId) OR (' + PACKAGE_QUALIFIER + 'Contact__c != NULL AND ' + PACKAGE_QUALIFIER + 'Contact__c = :payeeId) OR (' + PACKAGE_QUALIFIER + 'Employee__c != NULL AND ' + PACKAGE_QUALIFIER + 'Employee__c = :payeeId))) ' +
                ' OR Id IN :appliedAPIds) ' +
            (
                (IS_MULTI_CURRENCY_ENABLED == true)
                    ? ' AND CurrencyIsoCode = :currencyIsoCode '
                    : ' '
            ) +
            'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
            (isLedgerEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
            (!isLedgerEqualLegacyLedger ? ') ' : ' ') +
            'ORDER BY ' +
                String.escapeSingleQuotes(sortColumns[sortFieldIndex]) +
                ' ' +
                String.escapeSingleQuotes(sortOrder[sortOrderIndex]) +
                ' ' +
            'LIMIT :recLimit OFFSET :offset';

        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return theQuery.toSOQL();
    }

    private String buildExistedAPDisbursementSOQLQuery() {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Account_Payable__c',
            'Cash_Disbursement__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Status__c',
            'Paid_Amount__c'
        };
        //set query condition
        String queryCondition = 'Cash_Disbursement__c = :cashDisbursementId ORDER BY Account_Payable__r.Name DESC';

        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(AP_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return theQuery.toSOQL();
    }

    public void initialRecordsLoad() {
        if (!execStatusDispatcher.getIsErrorState()) {
            if (offset > MAX_RECORD_COUNT) {
                offset = MAX_RECORD_COUNT;
            }

            wrappedRecords = new List<APDisbursementWrapper>();

            execStatusDispatcher.isDirty = false;
            //to fix roll-up summary issue on MC orgs
            appliedAmount = cashDisbursement.Applied_Amount__c.setScale(2, System.RoundingMode.HALF_UP);
            balance = cashDisbursement.Balance__c;

            for (Account_Payable__c acctPayable : (List<Account_Payable__c>) Database.query(buildAccountPayableSOQLQuery())) {
                APDisbursementWrapper apdWrapper;
                if (!apIdToAPDisbursement.containsKey(acctPayable.Id)) {

                    Accounting_Period__c mostRecentPeriod =
                        AccountingPeriodHandler.getInstance().getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(
                        new Set<Id> {
                            cashDisbursement.Accounting_Period__c,
                            acctPayable.Accounting_Period__c
                        },
                        Account_Payable__c.sObjectType
                    );

                    AP_Disbursement__c apd = new AP_Disbursement__c(
                        Cash_Disbursement__c = cashDisbursement.Id,
                        Account_Payable__c = acctPayable.Id,
                        Accounting_Period__c = mostRecentPeriod.Id
                    );

                    //in case if there was not existed AP Disbursement(means this CD was never applied to this Payable before)
                    //user will always have ability to edit the line
                    //so in this case it does not matter the opened/closed state of the Payable's Accounting Period
                    apdWrapper = new APDisbursementWrapper(acctPayable, apd, false);
                }
                else {
                    AP_Disbursement__c apd = apIdToAPDisbursement.get(acctPayable.Id);
                    apdWrapper = new APDisbursementWrapper(
                        acctPayable,
                        apd,
                        (!(AccountingPeriodHandler.getInstance().isConsideredOpen(apd.Accounting_Period__c, AP_Disbursement__c.sObjectType)))
                    );
                    appliedAmount -= apd.Paid_Amount__c != NULL ? apd.Paid_Amount__c : 0;
                    balance += apd.Paid_Amount__c != NULL ? apd.Paid_Amount__c : 0;
                }

                wrappedRecords.add(apdWrapper);
            }

            if (wrappedRecords.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.MESSAGE(
                        ApexPages.SEVERITY.ERROR,
                        String.format(
                            NO_MATCHING_ACCOUNT_PAYABLE_RECORDS_FOUND_ERROR,
                            new List<String>{cashDisbursement.Payee__c}
                        )
                    )
                );
                execStatusDispatcher.noRecordsFound = true;
            }
        }
    }

    private Map<Id, AP_Disbursement__c> queryExistedAPDisbursements() {
        Map<Id, AP_Disbursement__c> resultMap = new Map<Id, AP_Disbursement__c>();
        for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) Database.query(buildExistedAPDisbursementSOQLQuery())) {
            resultMap.put(apd.Account_Payable__c, apd);
        }
        return resultMap;
    }

    public PageReference saveAndRefresh() {
        save();
        execStatusDispatcher.isCompleted = false;
        execStatusDispatcher.isDirty = execStatusDispatcher.getIsErrorState();

        return NULL;
    }

    public PageReference save() {
        Savepoint sp = Database.setSavepoint();
        try {
            validateOnSave();
            if (execStatusDispatcher.getIsErrorState()) {
                return NULL;
            }

            List<AP_Disbursement__c> apDisbursementsForInsert = new List<AP_Disbursement__c>();
            List<AP_Disbursement__c> apDisbursementsForDelete = new List<AP_Disbursement__c>();

            for (APDisbursementWrapper wrappedRecord : wrappedRecords) {
                if (!isBlankNumber(wrappedRecord.apDisbursement.Paid_Amount__c)
                        && (wrappedRecord.apDisbursement.Paid_Amount__c != wrappedRecord.originalAppliedAmount
                                || wrappedRecord.apDisbursement.Accounting_Period__c != wrappedRecord.originalAccountingPeriod)) {

                    //create AP Disbursements to save them in DB later
                    AP_Disbursement__c apd = (wrappedRecord.apDisbursement.clone(false, true));
                    apd.Cash_Disbursement__c = cashDisbursement.Id;
                    apd.Account_Payable__c = wrappedRecord.acctPayable.Id;
                    if (IS_MULTI_CURRENCY_ENABLED) {
                        apd.put('CurrencyIsoCode', currencyIsoCode);
                    }
                    apDisbursementsForInsert.add(apd);

                    if (wrappedRecord.apDisbursement.Id != NULL) {
                        apDisbursementsForDelete.add(wrappedRecord.apDisbursement);
                    }
                }
                else if (isBlankNumber(wrappedRecord.apDisbursement.Paid_Amount__c) && wrappedRecord.apDisbursement.Id != NULL) {
                    apDisbursementsForDelete.add(wrappedRecord.apDisbursement);
                }

            }

            if (!apDisbursementsForDelete.isEmpty()) {
                //Unpost and delete existed APDs
                SFDCSecurityUtils.deleteProxy(apDisbursementsForDelete);
            }

            if (!apDisbursementsForInsert.isEmpty()) {
                //insert and post the new APDs
                SFDCSecurityUtils.insertProxy(apDisbursementsForInsert);
            }

            cashDisbursement = queryCashDisbursement();

            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, Label.COMMON_CHANGES_SAVED));
            execStatusDispatcher.isCompleted = true;
            refreshAndInitRecords();
        }
        catch (Exception ex) {
            execStatusDispatcher.isExceptionThrown = true;
            Database.rollback(sp);
            ApexPages.addMessages(ex);
        }

        return NULL;
    }

    private void validateOnLoad() {
        if (this.cashDisbursement.Payment_Status__c == 'Void') {
            ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, VOIDED_CD_ERROR));
            execStatusDispatcher.isVoided = true;
        }
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(this.cashDisbursement.Ledger__c);
        if (this.cashDisbursement.Debit_GL_Account__c == NULL
            || this.cashDisbursement.Debit_GL_Account__c == defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c) {
            ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, APDisbursementPostHandler.DEBIT_GL_ACCOUNT_VALIDATION_ON_INSERT_ERROR_MESSAGE));
            execStatusDispatcher.isDebitGLAccountError = true;
        }
    }

    private void validateOnSave() {
        //reset Execution Status Dispatcher
        execStatusDispatcher = new ExecutionStatusDispatcher();
        //execute step by step validation before save the records
        checkCashDisbursementModifiedByAnotherUser();

        if (!execStatusDispatcher.getIsErrorState()) {
             validateRequiredValueSet();
        }

        if (!execStatusDispatcher.getIsErrorState()) {
            validateAccountingPeriod();
        }

        if (!execStatusDispatcher.getIsErrorState()) {
            validatePositiveAppliedAmount();
        }

        if (!execStatusDispatcher.getIsErrorState()) {
            validatePositiveAPBalance();
        }

        if (!execStatusDispatcher.getIsErrorState()) {
            validatePositiveCDBalance();
        }
    }

    private void checkCashDisbursementModifiedByAnotherUser() {
        // Accessible and FLS checks performed in class constructor. Redundant to perform same checks here.
        DateTime newLastModified =
            DomainUtils.getCashDisbursementByIdForUpdate(new Set<Id>{cashDisbursement.Id})[0].LastModifiedDate;

        if (newLastModified != cashDisbursement.LastModifiedDate) {
            ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, LAST_MODIFIED_ERROR));
            execStatusDispatcher.isLastModifiedError = true;
        }
    }

    private void validateRequiredValueSet() {
        for (APDisbursementWrapper wrappedRecord : wrappedRecords) {
            if (wrappedRecord.apDisbursement.Paid_Amount__c != NULL && wrappedRecord.apDisbursement.Accounting_Period__c == NULL) {
                wrappedRecord.apDisbursement.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
                execStatusDispatcher.requiredValueIsNotSet = true;
            }
        }
    }

    private void validateAccountingPeriod() {
        Set<Id> acctPeriodIds = new Set<Id>();

        for (APDisbursementWrapper wrappedRecord : wrappedRecords) {
            if (wrappedRecord.apDisbursement.Accounting_Period__c != NULL) {
                acctPeriodIds.add(wrappedRecord.apDisbursement.Accounting_Period__c);
            }
        }

        Map<Id, Accounting_Period__c> periods = new Map<Id, Accounting_Period__c>(
            AccountingPeriodHandler.getInstance().getAccountingPeriodsById(acctPeriodIds)
        );

        for (APDisbursementWrapper wrappedRecord : wrappedRecords) {
            if (wrappedRecord.apDisbursement.Paid_Amount__c != NULL
                    && !wrappedRecord.isPeriodClosed//if the Period was not yet closed on initial page load
                    && (periods.get(wrappedRecord.apDisbursement.Accounting_Period__c).Status__c != AccountingPeriodActions.OPEN_STATUS
                            || periods.get(wrappedRecord.apDisbursement.Accounting_Period__c).Start_Date__c
                                    < wrappedRecord.acctPayable.Accounting_Period__r.Start_Date__c)) {

                wrappedRecord.apDisbursement.Accounting_Period__c.addError(ACCOUNT_PERIOD_NOT_VALID_ERROR);
                execStatusDispatcher.isAccountingPeriodValid = false;
            }
        }
    }

    private void validatePositiveAppliedAmount() {
        for (APDisbursementWrapper wrappedRecord : wrappedRecords) {
            if (wrappedRecord.apDisbursement.Paid_Amount__c != NULL && wrappedRecord.apDisbursement.Paid_Amount__c < 0) {
                wrappedRecord.apDisbursement.Paid_Amount__c.addError(AMOUNT_LESS_THAN_ZERO_ERROR);
                execStatusDispatcher.negativeAmount = true;
            }
        }
    }

    private void validatePositiveAPBalance() {
        for (APDisbursementWrapper wrappedRecord : wrappedRecords) {
            if (wrappedRecord.getBalance() < 0) {
                wrappedRecord.apDisbursement.Paid_Amount__c.addError(ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO_ERROR);
                execStatusDispatcher.negativeAPBalance = true;
            }
        }
    }

    private void validatePositiveCDBalance() {
        Decimal checkBalance = balance;
        for (APDisbursementWrapper wrappedRecord : wrappedRecords) {
            checkBalance -= wrappedRecord.apDisbursement.Paid_Amount__c != NULL ? wrappedRecord.apDisbursement.Paid_Amount__c : 0;
        }
        if (checkBalance.setScale(2, System.RoundingMode.HALF_UP) < 0) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, CD_BALANCE_LESS_THAN_ZERO_ERROR));
            execStatusDispatcher.negativeCDBalance = true;
        }
    }

    private void refreshAppliedState() {
        apIdToAPDisbursement = queryExistedAPDisbursements();
        appliedAPIds = apIdToAPDisbursement.keySet();
    }

    public void refreshAndInitRecords() {
        refreshAppliedState();
        initialRecordsLoad();
    }

    private Boolean isBlankNumber(Decimal sourceDecimal) {
        return sourceDecimal == NULL || sourceDecimal == 0;
    }

    //====================================================================================
    //========================= INNER CLASSES ============================================
    //====================================================================================
    public with sharing class APDisbursementWrapper {

        public Account_Payable__c acctPayable {get; set;}
        public AP_Disbursement__c apDisbursement {get; set;}
        public Decimal originalAppliedAmount {get; set;}
        public Decimal originalTotalAppliedAmount {get; private set;}
        public Decimal paidAmount {get; set;}
        public Decimal creditAmount {get; set;}
        public Id originalAccountingPeriod {get; private set;}
        public Boolean isPeriodClosed {get; private set;}

        public APDisbursementWrapper(Account_Payable__c ap, AP_Disbursement__c apd, Boolean isPeriodClosed) {
            this.acctPayable = ap;
            this.apDisbursement = apd;
            this.isPeriodClosed = isPeriodClosed;
            this.originalAccountingPeriod = this.apDisbursement.Accounting_Period__c;
            this.originalAccountingPeriod = this.apDisbursement.Accounting_Period__c;
            this.originalAppliedAmount = (apDisbursement.Paid_Amount__c != NULL ? apDisbursement.Paid_Amount__c : 0);

            this.paidAmount =
                (acctPayable.Paid_Amount__c).setScale(2, System.RoundingMode.HALF_UP) -
                    (apDisbursement.Paid_Amount__c != NULL ? apDisbursement.Paid_Amount__c : 0);

            this.creditAmount =
                acctPayable.Credit_Memo_Applied_Amount__c != NULL ? acctPayable.Credit_Memo_Applied_Amount__c : 0;

            this.originalTotalAppliedAmount = this.paidAmount + this.creditAmount;
        }

        public Decimal getAppliedAmount() {
            return paidAmount +
                    creditAmount +
                    (apDisbursement.Paid_Amount__c != NULL ? apDisbursement.Paid_Amount__c : 0);
        }

        public Decimal getBalance() {
            return acctPayable.Net_Amount__c.setScale(2, System.RoundingMode.HALF_UP) - getAppliedAmount();
        }

    }
    //======================================================================================
    public with sharing class ExecutionStatusDispatcher {
        public Boolean isExceptionThrown {get; set;}
        public Boolean isLastModifiedError {get; set;}
        public Boolean isDebitGLAccountError {get; set;}
        public Boolean noRecordsFound {get; set;}
        public Boolean isDirty {get; set;}
        public Boolean isCompleted {get; set;}
        public Boolean isPosted {get; set;}
        public Boolean isVoided {get; set;}
        public Boolean isAccountingPeriodValid {get; set;}
        public Boolean requiredValueIsNotSet {get; set;}
        public Boolean negativeAmount {get; set;}
        public Boolean negativeAPBalance {get; set;}
        public Boolean negativeCDBalance {get; set;}
        public Boolean isValidPayee {get; set;}

        private Boolean canShowSaveButton;
        private Boolean canShowHeaderSection;
        private Boolean canShowTableSection;
        private Boolean isErrorState;

        public ExecutionStatusDispatcher() {
            this.isExceptionThrown = false;
            this.isDebitGLAccountError = false;
            this.isLastModifiedError = false;
            this.isDirty = false;
            this.noRecordsFound = false;
            this.isCompleted = false;
            this.isPosted = true;
            this.isVoided = false;
            this.isAccountingPeriodValid = true;
            this.requiredValueIsNotSet = false;
            this.negativeAmount = false;
            this.negativeAPBalance = false;
            this.negativeCDBalance = false;
            this.isValidPayee = true;
        }

        public Boolean getCanShowSaveButton() {
            canShowSaveButton = (!isCompleted && isPosted && isValidPayee && !isVoided && !noRecordsFound && !isLastModifiedError && !isDebitGLAccountError);
            return canShowSaveButton;
        }

        public Boolean getCanShowHeaderSection() {
            canShowHeaderSection = (!noRecordsFound && isPosted && isValidPayee && !isVoided && !isLastModifiedError && !isDebitGLAccountError);
            return canShowHeaderSection;
        }

        public Boolean getCanShowTableSection() {
            canShowTableSection = (!noRecordsFound && isPosted && isValidPayee && !isVoided && !isLastModifiedError && !isDebitGLAccountError);
            return canShowTableSection;
        }

        public Boolean getIsErrorState() {
            isErrorState =  isExceptionThrown
                            || isLastModifiedError
                            || isDebitGLAccountError
                            || noRecordsFound
                            || !isPosted
                            || !isValidPayee
                            || isVoided
                            || !isAccountingPeriodValid
                            || requiredValueIsNotSet
                            || negativeAmount
                            || negativeAPBalance
                            || negativeCDBalance;

            return isErrorState;
        }

        public void setIsErrorState(Boolean value) {
            isErrorState = value;
        }
    }

}