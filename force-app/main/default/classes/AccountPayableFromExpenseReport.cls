public with sharing class AccountPayableFromExpenseReport {
    
    public static final String NO_SELECTION_ERROR_MESSAGE = Label.ERR_NO_QUALIFYING_RECORDS_SELECTED;
    public static final String NO_ACCOUNTING_RANGE_ERROR = Label.ERR_NO_ACCOUNTING_PERIOD_IN_DATE_RANGE;
    public static final String NO_OPEN_ACCOUNTING_RANGE_ERROR = Label.ERR_NO_OPEN_ACCOUNTING_PERIOD_IN_DATE_RANGE;

    private ApexPages.StandardSetController stdSetController;
    private Map<String, ExpenseReportWrapper> expReportMap;
    private Accounting_Settings__c main;
    private Boolean isNeedToPost;

    public List<Expense_Line__c> expLines {get; set;}
    public List<ExpenseReportWrapper> expReportList {get; set;}
    public Account_Payable__c acctPayable {get; set;}
    public String filterId {get; private set;}
    public Boolean isSuccess {get; private set;}
    public Boolean isError {get; private set;}
    public Boolean showInfo {get; private set;}
    public Boolean isMultiCurrencyEnabled {get; private set;}
    @TestVisible
    private Map<String, Account_Payable__c> acctPayables;
        
    public AccountPayableFromExpenseReport(ApexPages.StandardSetController setController) {
        this.stdSetController = setController;
        acctPayable = new Account_Payable__c();
        acctPayable.Due_Date__c = System.today() + 30;
        filterId = stdSetController.getFilterId().substring(0, 15);
        isSuccess = false;
        isError = false;
        isNeedToPost = false;
        showInfo = false;
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

        try {
            expLines = queryExpenseLines((List<Expense_Report__c>) setController.getSelected());
            init();
            showInfo = true;
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isSuccess = false;
            isError = true;
        }
    }

    public String getListViewId() {
        return stdSetController.getFilterId();
    }

    public String getSObjectApiName() {
        return Expense_Report__c.SObjectType.getDescribe().getName();
    }

    private List<Expense_Line__c> queryExpenseLines(List<Expense_Report__c> selectedExpenseReports) {
        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Date__c',
            'Expense_Report__r.Name',
            'Expense_Report__r.Ledger__c',
            'Expense_Report__r.Ledger__r.Name',
            'Project__c',
            'Project_Task__c',
            'Project__r.Account__c',
            'Project__r.Account__r.Name',
            'Amount__c',
            'Credit_Card_Vendor__c',
            'Credit_Card_Vendor__r.Name',
            'Project__r.Name',
            'Project_Task__r.Name',
            'Expense_GL_Account__c',
            'Expense_Report__r.Employee__r.Name',
            'Expense_Report__r.Employee__c',
            'Internal_Comment__c',
            'Invoice_Comment__c',
            'Employee_Reimburse__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };

        if (isMultiCurrencyEnabled) {
            queryFields.add('Expense_Report__r.CurrencyIsoCode');
        }

        //Add main query condition
        String queryCondition =
            'Expense_Report__c IN :selectedExpenseReports ' +
            'AND Account_Payable_Line__c = NULL ' +
            'AND Expense_Report__r.Status__c = \'Approved\' ' +
            'AND Expense_Report__r.Employee__c != NULL ' +
            'AND (Employee_Reimburse__c = true OR Credit_Card_Vendor__c != NULL) ' +
            'AND Expense_Report__r.Ledger__r.Active__c = true';

        SOQLBuilder theQuery = new SOQLBuilder(Expense_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Expense_Line__c>) Database.query(theQuery.toSOQL());
    }


    private void init() {
        expReportMap = new Map<String, ExpenseReportWrapper>();
        for (Expense_Line__c expLine : expLines) {
            expLine.Expense_Report__r.Ledger__c = expLine.Expense_Report__r.Ledger__c != NULL ? expLine.Expense_Report__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        }

        for (Expense_Line__c expLine : expLines) {
            String ledger = String.valueOf(expLine.Expense_Report__r.Ledger__c);
            String isoCode = isMultiCurrencyEnabled ? (String) expLine.getSObject(Expense_Line__c.Expense_Report__c).get('CurrencyIsoCode') : '';
            String ccVendorKey = expLine.Credit_Card_Vendor__c + ledger + isoCode;
            String empKey = expLine.Expense_Report__r.Employee__c + ledger + isoCode;

            if (expLine.Credit_Card_Vendor__c != NULL && expReportMap.containsKey(ccVendorKey)) {
                expReportMap.get(ccVendorKey).expLineList.add(expLine);
            }
            else if (expLine.Credit_Card_Vendor__c != NULL) {
                expReportMap.put(ccVendorKey, new ExpenseReportWrapper(expLine, expLine.Credit_Card_Vendor__r, isoCode));
            }
            
            if (expLine.Expense_Report__r.Employee__c != NULL && expLine.Employee_Reimburse__c && expReportMap.containsKey(empKey)) {
                expReportMap.get(empKey).expLineList.add(expLine);
            }
            else if (expLine.Expense_Report__r.Employee__c != NULL && expLine.Employee_Reimburse__c) {
                expReportMap.put(empKey, new ExpenseReportWrapper(expLine, expLine.Expense_Report__r.Employee__r, isoCode));
            }
        }
        
        expReportList = expReportMap.values();

        if (expReportList.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_SELECTION_ERROR_MESSAGE));
            isError = true;
        }
    }

    public PageReference createAccountsPayableAndPost() {
        isNeedToPost = true;
        createAccountsPayable();
        return NULL;
    }
    
    public PageReference createAccountsPayable() {
        isError = false;
        acctPayables = new Map<String, Account_Payable__c>();
        Map<Expense_Line__c, Account_Payable_Line__c> acctPayablesMap = new Map<Expense_Line__c, Account_Payable_Line__c>();
        List<Expense_Line__c> expLinesList = new List<Expense_Line__c>();

        Savepoint sp = Database.setSavepoint();
        
        try {
            Accounting_Period__c acctPeriod = new Accounting_Period__c();
            if (isNeedToPost) {
                acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(acctPayable.Date__c, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Account_Payable__c.SObjectType);
            }
            else {
                acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(acctPayable.Date__c);
            }
            if (acctPeriod != NULL) {
                acctPayable.Accounting_Period__c = acctPeriod.Id;
            }
            else {
                acctPayable.Date__c.addError(isNeedToPost ? NO_OPEN_ACCOUNTING_RANGE_ERROR : NO_ACCOUNTING_RANGE_ERROR);
            }
            if (acctPayable.Accounting_Period__c != NULL) {
                for (ExpenseReportWrapper erw :  expReportList) {
                    Id ledgerId = erw.expLineList[0].Expense_Report__r.Ledger__c;
                    Account_Payable__c ap = new Account_Payable__c();
                    ap.Accounting_Period__c = acctPayable.Accounting_Period__c;
                    ap.Date__c = (acctPayable.Date__c == NULL ? System.today() : acctPayable.Date__c);
                    ap.Due_Date__c = (acctPayable.Due_Date__c == NULL ? System.today() + 30 : acctPayable.Due_Date__c);
                    ap.Status__c = 'Approved';
                    ap.Payee_Reference__c = erw.acctPayable.Payee_Reference__c;
                    ap.Ledger__c = ledgerId;

                    if (erw.acct != NULL) {
                        String key = String.valueOf(erw.acct.Id) + String.valueOf(ledgerId) + erw.isoCode;
                        ap.Vendor__c = erw.acct.Id;
                        acctPayables.put(key, ap);
                    }
                    else {
                        String key = String.valueOf(erw.employee.Id) + String.valueOf(ledgerId) + erw.isoCode;
                        ap.Employee__c = erw.employee.Id;
                        acctPayables.put(key, ap);
                    }

                    if (isMultiCurrencyEnabled) {
                        ap.put('CurrencyIsoCode',erw.isoCode);
                    }
                }

                //Insert the new Account Payable
                SFDCSecurityUtils.insertCheckCRUDAndFLS(acctPayables.values(), new List<String>{
                        'Accounting_Period__c',
                        'Date__c',
                        'Due_Date__c',
                        'Status__c',
                        'Payee_Reference__c',
                        'Ledger__c'
                });

                for (ExpenseReportWrapper erw :  expReportList) {
                    Id ledgerId = erw.expLineList[0].Expense_Report__r.Ledger__c;
                    for (Expense_Line__c expLine : erw.expLineList) {
                        Account_Payable_Line__c apLine = new Account_Payable_Line__c();
                        if (erw.acct != null) {
                            String key = String.valueOf(erw.acct.Id) + String.valueOf(ledgerId) + erw.isoCode;
                            apLine.Account_Payable__c = acctPayables.get(key).Id;
                        }
                        else {
                            String key = String.valueOf(erw.employee.Id) + String.valueOf(ledgerId) + erw.isoCode;
                            apLine.Account_Payable__c = acctPayables.get(key).Id;
                        }
                        apLine.Date__c = expLine.Date__c;
                        apLine.Expense_GL_Account__c = expLine.Expense_GL_Account__c;

                        if (expLine.Amount__c != null && expLine.Amount__c >= 0) {
                            apLine.Quantity__c = 1;
                        }
                        else if (expLine.Amount__c != null && expLine.Amount__c < 0) {
                            apLine.Quantity__c = -1;
                        }

                        apLine.Amount__c = expLine.Amount__c;
                        apLine.Internal_Comment__c = expLine.Internal_Comment__c;
                        apLine.Invoice_Comment__c = expLine.Invoice_Comment__c;
                        apLine.Project__c = expLine.Project__c;
                        apLine.Project_Task__c = expLine.Project_Task__c;
                        apLine.GL_Account_Variable_1__c = expLine.GL_Account_Variable_1__c;
                        apLine.GL_Account_Variable_2__c = expLine.GL_Account_Variable_2__c;
                        apLine.GL_Account_Variable_3__c = expLine.GL_Account_Variable_3__c;
                        apLine.GL_Account_Variable_4__c = expLine.GL_Account_Variable_4__c;
                        acctPayablesMap.put(expLine, apLine);
                    }
                }

                //Insert AP lines
                SFDCSecurityUtils.insertCheckCRUDAndFLS(acctPayablesMap.values(), new List<String>{
                    'Date__c',
                    'Expense_GL_Account__c',
                    'Quantity__c',
                    'Amount__c',
                    'Internal_Comment__c',
                    'Invoice_Comment__c',
                    'Project__c',
                    'Project_Task__c',
                    'GL_Account_Variable_1__c',
                    'GL_Account_Variable_2__c',
                    'GL_Account_Variable_3__c',
                    'GL_Account_Variable_4__c'
                });

                for (Expense_Line__c el : acctPayablesMap.keySet()) {
                    el.Account_Payable_Line__c = acctPayablesMap.get(el).Id;
                    el.Vendor_Employee_Paid__c = true;
                    expLinesList.add(el);
                }

                SFDCSecurityUtils.updateProxy(expLinesList);

                if (isNeedToPost) {
                    List<PostResult> results = AccountPayablePostService.postAccountPayables(acctPayables.values());
                    if (!results[0].isSuccess && results[0].errors.size() > 0) {
                        throw new DMLException(results[0].errors[0].message);
                    }
                }

                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, Label.INF_PAYABLES_CREATED));
                isSuccess = true;
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            for (Expense_Line__c el : acctPayablesMap.keySet()) {
                el.Account_Payable_Line__c = NULL;
                el.Vendor_Employee_Paid__c = false;
                if (el.Credit_Card_Vendor__c != NULL)
                    el.Credit_Card_Vendor_Payable__c = false;
            }
            isNeedToPost = false;
            isError = true;
            ApexPages.addMessages(ex);
            isSuccess = false;
        }

        showInfo = false;
        return NULL;
    }

    public with sharing class ExpenseReportWrapper {
        public List<Expense_Line__c> expLineList {get; set;}
        public Account acct {get; set;}
        public User employee {get; set;}
        public Account_Payable__c acctPayable {get; set;}
        public String isoCode {get; set;}

        public ExpenseReportWrapper(Expense_Line__c expLine, Account acct, String isoCode) {
            ExpenseReportWrapper(expLine);
            this.acct = acct;
            this.isoCode = isoCode;
        }

        public ExpenseReportWrapper(Expense_Line__c expLine, User employee, String isoCode) {
            ExpenseReportWrapper(expLine);
            this.employee = employee;
            this.isoCode = isoCode;
        }

        private void ExpenseReportWrapper(Expense_Line__c expLine) {
            expLineList = new List<Expense_Line__c>{expLine};
            setPayReference();
        }

        public Decimal getAmount() {
            Decimal amount = 0;
            for (Expense_Line__c expLine : expLineList) {
                amount += expLine.Amount__c;
            }
            return amount;
        }

        public String getPayee() {
            return acct != NULL ? acct.Name : employee.Name;
        }

        public void setPayReference() {
            acctPayable = new Account_Payable__c();
            acctPayable.Payee_Reference__c = 'Expenses ' +
                (expLineList[0].Expense_Report__r.Ledger__r.Name != NULL ? expLineList[0].Expense_Report__r.Ledger__r.Name : '')
                + ' ' + System.now().format() + ' ' + Integer.valueof((Math.random() * 100));
        }
    }

}