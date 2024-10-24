public with sharing class AccountPayableApplyCreditMemo {

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

    private Map<Id, AP_Credit_Memo__c> creditMemoMap {get; set;}
    private Set<Id> appliedAPIds {get; set;}

    private Accounting_Period__c period;
    private Decimal balance;
    private Id vendorId;
    private Id contactId;
    private Id employeeId;
    private AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();

    public static final String AMOUNT_LESS_THAN_ZERO_ERROR = Label.ERR_AMOUNT_NOT_POSITIVE_NUMBER;
    public static final String TOTAL_APPLIED_LESS_THAN_ZERO_ERROR = Label.ERR_TOTAL_APPLIED_LESS_THAN_ZERO;
    public static final String CM_BALANCE_LESS_THAN_ZERO_ERROR = Label.ERR_CM_BALANCE_LESS_THAN_ZERO;
    public static final String LAST_MODIFIED_ERROR = Label.ERR_CREDIT_MEMO_MODIFIED;
    public static final String ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO_ERROR = Label.ERR_ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO;
    public static final String PERIOD_ERROR = Label.ERR_CM_BEFORE_AP;

    public Boolean IS_MULTI_CURRENCY_ENABLED {get; private set;}
    public String currencyIsoCode {get; private set;}
    public Boolean isLedgerCurrency {get; private set;}
    private Decimal currencyConversionRate {get; set;}
    private Boolean isLedgerEqualLegacyLedger;
    private Id ledgerId;

    public Account_Payable__c creditMemo {get; private set;}
    public List<CreditMemoLineWrapper> creditMemoLineWrapperList {get; set;}
    public Boolean isCompleted {get; private set;}
    public Boolean isDirty {get; set;}
    public Boolean isError {get; set;}
    public Boolean isInitError {get; set;}
    public Boolean isLastModifiedError {get; private set;}
    public Integer offset {get; set;}
    public Integer recLimit {get; set;}
    public Integer recordSetSize {get; set;}
    public Integer sortFieldIndex {get; set;}
    public Integer sortOrderIndex {get; set;}
    public Decimal appliedAmount {get; set;}


    public with sharing class CreditMemoLineWrapper {
        public AP_Credit_Memo__c acmLine {get; set;}
        public Account_Payable__c acctPayable {get; set;}
        public Decimal paidAmount {get; set;}
        public Decimal creditAmount {get; set;}
        public Decimal originalAppliedAmount {get; set;}
        public String originalAccountingPeriod {get; set;}
        public Integer lineNum {get; set;}
        public Boolean isPeriodClosed {get; set;}
        public Decimal originalTotalAppliedAmount {get; private set;}

        public CreditMemoLineWrapper(Account_Payable__c acctPayable, AP_Credit_Memo__c acmLine, Boolean isPeriodClosed) {
            this.acmLine = acmLine;
            this.acctPayable = acctPayable;
            this.isPeriodClosed = isPeriodClosed;
            paidAmount = (acctPayable.Paid_Amount__c).setScale(2, System.RoundingMode.HALF_UP) - (acmLine.Amount__c != NULL ? acmLine.Amount__c : 0);
            creditAmount = acctPayable.Credit_Memo_Applied_Amount__c != NULL ? acctPayable.Credit_Memo_Applied_Amount__c.setScale(2, System.RoundingMode.HALF_UP) : 0;
            originalAppliedAmount = (acmLine.Amount__c != NULL ? acmLine.Amount__c : 0);
            originalAccountingPeriod = acmLine.Accounting_Period__c;
            originalTotalAppliedAmount = paidAmount + creditAmount;
        }

        public Decimal getBalance() {
            return acctPayable.Net_Amount__c.setScale(2, System.RoundingMode.HALF_UP) - getAppliedAmount();
        }

        public Decimal getAppliedAmount() {
            return paidAmount + creditAmount + (acmLine.Amount__c != NULL ? acmLine.Amount__c : 0);
        }

    }

    public AccountPayableApplyCreditMemo(ApexPages.StandardController controller) {
        try {
            this.IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.isLedgerCurrency = true;

            Id creditMemoId = controller.getId();
            //need Dynamic SOQL because the "CurrencyIsoCode" field will be not visible in non-multi-currency orgs
            creditMemo = queryThisAccountPayable(creditMemoId);

            this.vendorId = creditMemo.Vendor__c;
            this.contactId = creditMemo.Contact__c;
            this.employeeId = creditMemo.Employee__c;

            ledgerId = creditMemo.Ledger__c != NULL ? creditMemo.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
            isLedgerEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(ledgerId);
            creditMemo.Ledger__c = ledgerId;

            if (IS_MULTI_CURRENCY_ENABLED) {
                this.currencyIsoCode = (String) creditMemo.get('CurrencyIsoCode');
                this.currencyConversionRate = creditMemo.Currency_Conversion_Rate__c;
                this.isLedgerCurrency = LedgerHandler.isLedgerCurrency(this.currencyIsoCode, ledgerId);
            }

            creditMemoMap = queryExistedApCreditMemosById(creditMemoId);
            appliedAPIds = creditMemoMap.keySet();

            recordSetSize = Database.countQuery(
                'SELECT count() ' +
                'FROM ' + PACKAGE_QUALIFIER + 'Account_Payable__c ' +
                ' WHERE ' + PACKAGE_QUALIFIER + 'Type__c = \'Invoice\' ' +
                'AND ((' + PACKAGE_QUALIFIER + 'Balance__c > 0 ' +
                'AND ' + PACKAGE_QUALIFIER + 'Status__c = \'Posted\' ' +
                'AND (' +
                '(' + PACKAGE_QUALIFIER + 'Vendor__c != NULL AND ' + PACKAGE_QUALIFIER + 'Vendor__c = :vendorId) ' +
                'OR ' +
                '(' + PACKAGE_QUALIFIER + 'Contact__c != NULL AND ' + PACKAGE_QUALIFIER + 'Contact__c = :contactId) ' +
                'OR ' +
                '(' + PACKAGE_QUALIFIER + 'Employee__c != NULL AND ' + PACKAGE_QUALIFIER + 'Employee__c = :employeeId) ' +
                ')) ' +
                ' OR Id IN :appliedAPIds) ' +
                ((IS_MULTI_CURRENCY_ENABLED) ? ' AND CurrencyIsoCode = :currencyIsoCode AND ' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c = :currencyConversionRate ' : ' ') +
                'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
                (isLedgerEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
                (!isLedgerEqualLegacyLedger ? ') ' : ' ') +
                'LIMIT :MAX_RECORD_COUNT'
            );

            isCompleted = false;
            isDirty = false;
            isError = false;
            isInitError = false;
            isLastModifiedError = false;
            offset = offset == NULL ? 0 : offset;
            recLimit = recLimit == NULL ? 10 : recLimit;
            sortFieldIndex = sortFieldIndex == NULL ? 0 : sortFieldIndex;
            sortOrderIndex = sortOrderIndex == NULL ? 1 : sortOrderIndex;
            initInvoices();
        }
        catch (Exception ex) {
            isInitError = true;
            ApexPages.addMessages(ex);
        }
    }

    private Account_Payable__c queryThisAccountPayable(String creditMemoId) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Vendor__c',
            'Contact__c',
            'Employee__c',
            'Payee__c',
            'Total__c',
            'Net_Amount__c',
            'Credit_Memo_Applied_Amount__c',
            'Balance__c',
            'Currency_Conversion_Rate__c',
            'LastModifiedDate',
            'Ledger__c',
            'Accounting_Period__c'
        };
        //add MC field
        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }
        //set query condition
        String queryCondition = 'Id = :creditMemoId';
        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //Call DML operation
        List<Account_Payable__c> results = (List<Account_Payable__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }

    private Map<Id, AP_Credit_Memo__c> queryExistedApCreditMemosById(String apcmId) {
        Map<Id, AP_Credit_Memo__c> resultMap = new Map<Id, AP_Credit_Memo__c>();
        if (!String.isBlank(apcmId)) {
            //define fields to query
            List<String> queryFields = new List<String>{
                'Id',
                'Amount__c',
                'Account_Payable_Invoice__c',
                'Account_Payable_Invoice__r.Type__c',
                'Account_Payable_Invoice__r.Date__c',
                'Account_Payable_Invoice__r.Name',
                'Account_Payable_Invoice__r.Total__c',
                'Account_Payable_Invoice__r.Net_Amount__c',
                'Account_Payable_Invoice__r.Paid_Amount__c',
                'Account_Payable_Invoice__r.Balance__c',
                'Account_Payable_Invoice__r.Payee_Reference__c',
                'Account_Payable_Invoice__r.Credit_Memo_Applied_Amount__c',
                'Account_Payable_Invoice__r.Ledger__c',
                'Accounting_Period__c',
                'Accounting_Period__r.Status__c'
            };
            //set query condition
            String queryCondition = 'Account_Payable_Credit_Memo__c = :apcmId ORDER BY Account_Payable_Invoice__r.Name DESC';

            SOQLBuilder theQuery = new SOQLBuilder(AP_Credit_Memo__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            for (AP_Credit_Memo__c acmLine : (List<AP_Credit_Memo__c>) Database.query(theQuery.toSOQL())) {
                acmLine.Amount__c = acmLine.Amount__c * -1;
                resultMap.put(acmLine.Account_Payable_Invoice__c, acmLine);
            }
        }
        return resultMap;
    }

    private void refreshAppliedState() {
        creditMemoMap = queryExistedApCreditMemosById((String) creditMemo.Id);
        appliedAPIds = creditMemoMap.keySet();
    }

    public void refreshAndInitInvoices() {
        refreshAppliedState();
        initInvoices();
    }

    public void initInvoices() {
        if (!isError) {
            if (offset > MAX_RECORD_COUNT) {
                offset = MAX_RECORD_COUNT;
            }

            creditMemoLineWrapperList = new List<CreditMemoLineWrapper>();

            isDirty = false;
            appliedAmount = creditMemo.Credit_Memo_Applied_Amount__c * -1;
            balance = creditMemo.Balance__c * -1;

            //define fields to query
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Type__c',
                'Proprietary_Payable_Number__c',
                'Date__c',
                'Due_Date__c',
                'Total__c',
                'Paid_Amount__c',
                'Discount_Amount__c',
                'Net_Amount__c',
                'Balance__c',
                'Contact__c',
                'Employee__c',
                'Credit_Memo_Applied_Amount__c',
                'Payee_Reference__c',
                'Accounting_Period__c',
                'Purchase_Tax3__c',
                'Reverse_Charge__c'
            };
            //set query condition
            String queryCondition =
                PACKAGE_QUALIFIER + 'Type__c = \'Invoice\' ' +
                'AND ((' + PACKAGE_QUALIFIER + 'Balance__c > 0 ' +
                'AND ' + PACKAGE_QUALIFIER + 'Status__c = \'Posted\' ' +
                'AND (' +
                        '(' + PACKAGE_QUALIFIER + 'Vendor__c != NULL AND ' + PACKAGE_QUALIFIER + 'Vendor__c = :vendorId) ' +
                        'OR ' +
                        '(' + PACKAGE_QUALIFIER + 'Contact__c != NULL AND ' + PACKAGE_QUALIFIER + 'Contact__c = :contactId) ' +
                        'OR ' +
                        '(' + PACKAGE_QUALIFIER + 'Employee__c != NULL AND ' + PACKAGE_QUALIFIER + 'Employee__c = :employeeId) ' +
                ')) ' +
                    ' OR Id IN :appliedAPIds) ' +
                //Multi Currency part of query with legacy records support ============================================
                (
                    (IS_MULTI_CURRENCY_ENABLED == true)
                        ?
                            ' AND CurrencyIsoCode = :currencyIsoCode ' +
                            (
                                (this.currencyConversionRate != NULL)
                                    ?
                                        ' AND ' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c = :currencyConversionRate '
                                    ://means that is legacy Credit Memo record and should be considered as a record with Base Currency and CCR = 1
                                        ' AND (' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c = :currencyConversionRate OR ' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c = 1) '
                            )
                        :
                            ' '
                ) +
                'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
                (isLedgerEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
                (!isLedgerEqualLegacyLedger ? ') ' : ' ') +
                //=====================================================================================================
                'ORDER BY ' + String.escapeSingleQuotes(sortColumns[sortFieldIndex]) + ' ' + String.escapeSingleQuotes(sortOrder[sortOrderIndex]) + ' LIMIT :recLimit OFFSET :offset';

            SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            for (Account_Payable__c acctPayable : (List<Account_Payable__c>) Database.query(theQuery.toSOQL())) {
                CreditMemoLineWrapper clw;

                Accounting_Period__c periodForNewline = acctPeriodHandler.getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(
                                new Set<Id> {
                                        acctPayable.Accounting_Period__c,
                                        creditMemo.Accounting_Period__c
                                },
                                Account_Payable__c.sObjectType
                        );

                if (!creditMemoMap.containsKey(acctPayable.Id)) {
                    AP_Credit_Memo__c acmLine = new AP_Credit_Memo__c(Account_Payable_Credit_Memo__c = creditMemo.Id, Account_Payable_Invoice__c = acctPayable.Id);
                    acmLine.Accounting_Period__c = periodForNewline != NULL && periodForNewline.Id != NULL ? periodForNewline.Id : NULL;
                    clw = new CreditMemoLineWrapper(acctPayable, acmLine, (!AccountingPeriod.isPeriodOpen(periodForNewline, AP_Credit_Memo__c.sObjectType)));
                }
                else {
                    AP_Credit_Memo__c acmLine = creditMemoMap.get(acctPayable.Id);
                    clw = new CreditMemoLineWrapper(acctPayable, acmLine, (!AccountingPeriodHandler.getinstance().isConsideredOpen(acmLine.Accounting_Period__c, AP_Credit_Memo__c.sObjectType)));
                    appliedAmount -= acmLine.Amount__c != NULL ? acmLine.Amount__c : 0;
                    balance += acmLine.Amount__c != NULL ? acmLine.Amount__c : 0;
                }

                creditMemoLineWrapperList.add(clw);
            }
        }
    }

    public Boolean validate() {
        isError = false;
        DateTime newLastModified =
            DomainUtils.getAccountPayablesByIdForUpdate(new Set<Id>{creditMemo.Id})[0].LastModifiedDate;

        if (newLastModified != creditMemo.LastModifiedDate) {
            isError = true;
            isLastModifiedError = true;
            ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, LAST_MODIFIED_ERROR));
            return !isError;
        }

        Decimal checkBalance = balance;

        for (CreditMemoLineWrapper cml : creditMemoLineWrapperList) {
            checkBalance -= cml.acmLine.Amount__c != NULL ? cml.acmLine.Amount__c : 0;

            if (cml.acmLine.Amount__c != NULL && acctPeriodHandler.compareAccountingPeriods(cml.acmLine.Accounting_Period__c, cml.originalAccountingPeriod) < 0) {
                cml.acmLine.Accounting_Period__c.addError(
                    String.format(
                        PERIOD_ERROR,
                        new List<String> {acctPeriodHandler.getAccountingPeriodById(cml.originalAccountingPeriod).Name})
                );
                isError = true;
            }

            if (cml.acmLine.Amount__c != NULL && cml.acmLine.Accounting_Period__c == NULL) {
                cml.acmLine.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
                isError = true;
            }

            if (cml.acmLine.Amount__c != NULL && cml.acmLine.Amount__c < 0) {
                cml.acmLine.Amount__c.addError(AMOUNT_LESS_THAN_ZERO_ERROR);
                isError = true;
            }

            if (cml.getBalance() < 0) {
                cml.acmLine.Amount__c.addError(ACCOUNT_PAYABLE_BALANCE_LESS_THAN_ZERO_ERROR);
                isError = true;
            }

        }

        if (checkBalance.setScale(2, System.RoundingMode.HALF_UP) < 0) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, CM_BALANCE_LESS_THAN_ZERO_ERROR));
            isError = true;
        }

        return !isError;
    }

    public PageReference saveAndRefresh() {
        save();
        isCompleted = false;
        isDirty = isError;

        return NULL;
    }

    public PageReference save() {

        if (!validate()) {
            return NULL;
        }

        isError = true;
        Savepoint sp = Database.setSavepoint();

        try {
            List<AP_Credit_Memo__c> insertAcmLines = new List<AP_Credit_Memo__c>();
            List<AP_Credit_Memo__c> deleteAcmLines = new List<AP_Credit_Memo__c>();

            for (CreditMemoLineWrapper cml : creditMemoLineWrapperList) {

                if (cml.acmLine.Amount__c != NULL
                        && cml.acmLine.Amount__c != 0
                        && (cml.acmLine.Amount__c != cml.originalAppliedAmount
                                || cml.acmLine.Accounting_Period__c != cml.originalAccountingPeriod)) {

                    AP_Credit_Memo__c acm = (cml.acmLine.clone(false, true));
                    acm.Amount__c = acm.Amount__c * -1;
                    acm.Account_Payable_Credit_Memo__c = creditMemo.Id;
                    acm.Account_Payable_Invoice__c = cml.acctPayable.Id;
                    insertAcmLines.add(acm);

                    if (cml.acmLine.Id != NULL)
                        deleteAcmLines.add(cml.acmLine);
                }
                else if ((cml.acmLine.Amount__c == NULL || cml.acmLine.Amount__c == 0) && cml.acmLine.Id != NULL) {
                    deleteAcmLines.add(cml.acmLine);
                }

            }

            SFDCSecurityUtils.deleteProxy(deleteAcmLines);

            SFDCSecurityUtils.insertCheckCRUDAndFLS(insertAcmLines, new List<String>{
                'Amount__c',
                'Account_Payable_Credit_Memo__c',
                'Account_Payable_Invoice__c'
            });

            creditMemo = queryThisAccountPayable((String) creditMemo.Id);

            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, Label.COMMON_CHANGES_SAVED));
            isCompleted = true;
            isError = false;

            refreshAndInitInvoices();
        }
        catch (Exception ex) {
            Database.rollback(sp);
            ApexPages.addMessages(ex);
        }

        return NULL;
    }

}