public with sharing class BillingFromExpenseReport {
   
    public static final String NO_SELECTION_ERROR_MESSAGE = Label.ERR_NO_QUALIFYING_RECORDS_SELECTED;
    public static final String NO_ACCOUNTING_RANGE_ERROR = Label.ERR_NO_ACCOUNTING_PERIOD_IN_DATE_RANGE;
    public static final String NO_OPEN_ACCOUNTING_RANGE_ERROR = Label.ERR_NO_OPEN_ACCOUNTING_PERIOD_IN_DATE_RANGE;

    private ApexPages.StandardSetController stdSetController;
    private Map<String, ExpenseReportWrapper> expReportMap;
    private Boolean isNeedToPost;

    public List<Expense_Line__c> expLines {get; set;}
    public List<ExpenseReportWrapper> expReportList {get; set;}
    public Billing__c bill {get; set;}
    public String filterId {get; private set;}
    public Boolean isSuccess {get; private set;}
    public Boolean showData {get; private set;}
    public Boolean showInfo {get; private set;}
    public Map<String, Billing_Rates__c> billingRates;
    public Boolean isMultiCurrencyEnabled {get; private set;}
    @TestVisible
    private Map<String, Billing__c> billings;

    public BillingFromExpenseReport(ApexPages.StandardSetController setController) {
        this.stdSetController = setController;
        bill = new Billing__c();
        filterId = stdSetController.getFilterId().substring(0, 15);
        isSuccess = false;
        isNeedToPost = false;
        showData = true;
        showInfo = false;
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

        try {
            expLines = queryExpenseLines((List<Expense_Report__c>) stdSetController.getSelected());
            init();
            showInfo = true;
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isSuccess = false;
            showData = false;
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
            'Expense_Report__r.Employee__c',
            'Project__c',
            'Project_Task__c',
            'Expense_GL_Account__r.TM_Revenue_Conversion__c',
            'Expense_Report__r.Name',
            'Expense_Report__r.Ledger__c',
            'Invoice_Comment__c',
            'Project__r.Account__c',
            'Project__r.Account__r.Name',
            'Amount__c',
            'Expense_Report__r.Employee__r.Name',
            'Project__r.Name',
            'Project_Task__r.Name',
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
            'AND Billable__c = true ' +
            'AND Project__r.Account__c != NULL ' +
            'AND Billing_Line__c = NULL ' +
            'AND Expense_Report__r.Status__c = \'Approved\' ' +
            'AND Expense_Report__r.Employee__c != NULL ' +
            'AND Expense_Report__r.Ledger__r.Active__c = true';

        SOQLBuilder theQuery = new SOQLBuilder(Expense_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Expense_Line__c>) Database.query(theQuery.toSOQL());
    }

    public with sharing class ExpenseReportWrapper {

        public List<ExpenseLineWrapper> expLineList {get; set;}
        public Account acct {get; set;}
        public String isoCode {get; set;}

        public ExpenseReportWrapper(Expense_Line__c expLine, Account acct, Billing_Rates__c br) {
            expLineList = new List<ExpenseLineWrapper>();
            expLineList.add(new ExpenseLineWrapper(expLine, br));
            this.acct = acct;

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                isoCode = (String) expLine.getSObject(Expense_Line__c.Expense_Report__c).get('CurrencyIsoCode');
            }
        }

        public void addExpenseLine(Expense_Line__c expLine, Billing_Rates__c br) {
            expLineList.add(new ExpenseLineWrapper(expLine, br));
        }

        public Decimal getAmount() {
            Decimal amount = 0;
            for (ExpenseLineWrapper elw : expLineList) {
                amount += elw.expLine.Amount__c + elw.getMarkupAmount();
            }

            return amount;
        }
    }

    public with sharing class ExpenseLineWrapper {
        public Expense_Line__c expLine {get; set;}
        public Billing_Line__c billLine {get; set;}
        public Billing_Rates__c billingRate {get; set;}

        public ExpenseLineWrapper(Expense_Line__c expLine, Billing_Rates__c billingRate) {
            this.expLine = expLine;
            this.billingRate = billingRate;
            billLine = new Billing_Line__c(Revenue_GL_Account__c = expLine.Expense_GL_Account__r.TM_Revenue_Conversion__c);
        }

        public Decimal getMarkupAmount() {
            return expLine.Amount__c * ((billingRate.Expense_Markup__c != NULL ? billingRate.Expense_Markup__c : 0) / 100);
        }
    }

    private void init() {
        expReportMap = new Map<String, ExpenseReportWrapper>();

        setBillingRates();

        for (Expense_Line__c expLine : expLines) {
            expLine.Expense_Report__r.Ledger__c = expLine.Expense_Report__r.Ledger__c != NULL ? expLine.Expense_Report__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        }

        for (Expense_Line__c expLine : expLines) {
            String isoCode = isMultiCurrencyEnabled ? (String) expLine.getSObject(Expense_Line__c.Expense_Report__c).get('CurrencyIsoCode') : '';
            String key = String.valueOf(expLine.Project__r.Account__c) + String.valueOf(expLine.Expense_Report__r.Ledger__c) + isoCode;
            Billing_Rates__c br = new Billing_Rates__c(Expense_Markup__c = 0);

            String projKey = String.valueOf(expLine.Project__c) + String.valueOf(expLine.Expense_Report__r.Employee__c);
            String projTaskKey = String.valueOf(expLine.Project_Task__c) + String.valueOf(expLine.Expense_Report__r.Employee__c);
            
            if (billingRates.containsKey(projTaskKey)
                    && billingRates.get(projTaskKey).Expense_Markup__c != NULL) {

                br = billingRates.get(projTaskKey);
            }
            else if (billingRates.containsKey(projKey)
                        && billingRates.get(projKey).Expense_Markup__c != NULL) {

                br = billingRates.get(projKey);
            }

            if (expReportMap.containsKey(key)) {
                expReportMap.get(key).addExpenseLine(expLine, br);
            }
            else {
                expReportMap.put(key, new ExpenseReportWrapper(expLine, expLine.Project__r.Account__r, br));
            }
        }

        expReportList = expReportMap.values();

        if (expReportList.isEmpty()) {
            showData = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_SELECTION_ERROR_MESSAGE));
        }
        else {
            bill.Billing_Format__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(
                expReportList[0].expLineList[0].expLine.Expense_Report__r.Ledger__c
            ).Default_Billing_Format__c;
        }

    }

    public void setBillingRates() {

        billingRates = new Map<String,Billing_Rates__c>();
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> projectIds = new Set<Id>();
        Set<Id> projectTaskIds = new Set<Id>();

        for (Expense_Line__c expLine : expLines) {
            employeeIds.add(expLine.Expense_Report__r.Employee__c);
            projectIds.add(expLine.Project__c);
            projectTaskIds.add(expLine.Project_Task__c);
        }

        for (Billing_Rates__c rate : queryBillingRates(employeeIds, projectIds, projectTaskIds)) {
            String projKey = String.valueOf(rate.Project__c) + String.valueOf(rate.Employee__c);
            String projTaskKey = String.valueOf(rate.Project_Task__c) + String.valueOf(rate.Employee__c);
            
            if (rate.Project_Task__c != NULL && !billingRates.containsKey(projTaskKey)) {
                billingRates.put(projTaskKey, rate);
                continue;
            }

            if (rate.Project__c != NULL && !billingRates.containsKey(projKey)) {
                billingRates.put(projKey, rate);
            }
        }
    }

    private List<Billing_Rates__c> queryBillingRates(Set<Id> employeeIds, Set<Id> projectIds, Set<Id> projectTaskIds) {
        //=== Build SOQL query with CRUD checks ===
        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Employee__c',
            'Project__c',
            'Project_Task__c',
            'Amount__c',
            'Expense_Markup__c'
        };

        //Add query condition
        String queryCondition =
            'Employee__c IN :employeeIds ' +
            'AND (Project__c IN :projectIds OR Project_Task__c IN :projectTaskIds) ' +
            'ORDER BY CreatedDate DESC';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Rates__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing_Rates__c>) Database.query(theQuery.toSOQL());
    }

    public PageReference createBillingAndPost() {
        isNeedToPost = true;
        createBillings();
        return NULL;
    }

    public PageReference createBillings() {
        isSuccess = false;
        billings = new Map<String, Billing__c>();
        Map<Expense_Line__c, Billing_Line__c> billLinesMap = new Map<Expense_Line__c, Billing_Line__c>();
        List<Expense_Line__c> expLinesList = new List<Expense_Line__c>();

        Savepoint sp = Database.setSavepoint();

        try {
            Accounting_Period__c acctPeriod = new Accounting_Period__c();
            if (isNeedToPost) {
                acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(bill.Date__c, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Billing__c.SObjectType);
            }
            else {
                acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(bill.Date__c);
            }
            if (acctPeriod != NULL) {
                bill.Accounting_Period__c = acctPeriod.Id;
            }
            else {
                bill.Date__c.addError(isNeedToPost ? NO_OPEN_ACCOUNTING_RANGE_ERROR : NO_ACCOUNTING_RANGE_ERROR);
            }
            if (bill.Accounting_Period__c != NULL) {
                for (ExpenseReportWrapper erw :  expReportList) {
                    Id ledgerId = erw.expLineList[0].expLine.Expense_Report__r.Ledger__c;
                    String key = String.valueOf(erw.acct.Id) + String.valueOf(ledgerId) + erw.isoCode;
                    Billing__c theBill = new Billing__c();
                    theBill.Accounting_Period__c = bill.Accounting_Period__c;
                    theBill.Date__c = bill.Date__c;
                    theBill.Billing_Cycle_Start_Date__c = bill.Billing_Cycle_Start_Date__c;
                    theBill.Billing_Cycle_End_Date__c = bill.Billing_Cycle_End_Date__c;
                    theBill.Billing_Format__c = bill.Billing_Format__c;
                    theBill.Customer__c = erw.acct.Id;
                    theBill.Ledger__c = ledgerId;
                    if (isNeedToPost) {
                        theBill.Status__c = 'Approved';
                    }
                    if (isMultiCurrencyEnabled) {
                        theBill.put('CurrencyIsoCode', erw.isoCode);
                    }
                    billings.put(key, theBill);
                }

                //Insert the new Billing record
                SFDCSecurityUtils.insertCheckCRUDAndFLS(billings.values(), new List<String>{
                    'Accounting_Period__c',
                    'Date__c',
                    'Billing_Cycle_Start_Date__c',
                    'Billing_Cycle_End_Date__c',
                    'Customer__c',
                    'Billing_Format__c',
                    'Ledger__c'
                });

                for (ExpenseReportWrapper erw :  expReportList) {
                    Id ledgerId = erw.expLineList[0].expLine.Expense_Report__r.Ledger__c;
                    String key = String.valueOf(erw.acct.Id) + String.valueOf(ledgerId) + erw.isoCode;
                    for (ExpenseLineWrapper elw : erw.expLineList) {
                        elw.billLine.Billing__c = billings.get(key).Id;
                        elw.billLine.Date__c = elw.expLine.Date__c;
                        elw.billLine.Employee__c = elw.expLine.Expense_Report__r.Employee__c;
                        elw.billLine.Rate__c = elw.expLine.Amount__c + elw.getMarkupAmount();
                        elw.billLine.Hours_Units__c = 1;
                        elw.billLine.Project__c = elw.expLine.Project__c;
                        elw.billLine.Project_Task__c = elw.expLine.Project_Task__c;
                        elw.billLine.Comment__c = elw.expLine.Invoice_Comment__c;
                        elw.billLine.GL_Account_Variable_1__c = elw.expLine.GL_Account_Variable_1__c;
                        elw.billLine.GL_Account_Variable_2__c = elw.expLine.GL_Account_Variable_2__c;
                        elw.billLine.GL_Account_Variable_3__c = elw.expLine.GL_Account_Variable_3__c;
                        elw.billLine.GL_Account_Variable_4__c = elw.expLine.GL_Account_Variable_4__c;
                        billLinesMap.put(elw.expLine, elw.billLine);
                    }
                }

                //Insert new Billing Lines
                SFDCSecurityUtils.insertCheckCRUDAndFLS(billLinesMap.values(), new List<String>{
                    'Date__c',
                    'Comment__c',
                    'Employee__c',
                    'Rate__c',
                    'Hours_Units__c',
                    'Project__c',
                    'Project_Task__c',
                    'GL_Account_Variable_1__c',
                    'GL_Account_Variable_2__c',
                    'GL_Account_Variable_3__c',
                    'GL_Account_Variable_4__c'
                });

                for (Expense_Line__c el : billLinesMap.keySet()) {
                    el.Billing_Line__c = billLinesMap.get(el).Id;
                    el.Billed__c = true;
                    expLinesList.add(el);
                }

                SFDCSecurityUtils.updateCheckCRUDAndFLS(expLinesList, new List<String>{'Billing_Line__c', 'Billed__c'});

                if (isNeedToPost) {
                    List<PostResult> results = BillingPostService.postBillings(billings.values());
                    if (!results[0].isSuccess && results[0].errors.size() > 0) {
                        throw new DMLException(results[0].errors[0].message);
                    }
                }

                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, Label.COMMON_BILLINGS_CREATED));
                isSuccess = true;
            }
        }
        catch (SFDCSecurityUtils.SecurityException securityException) {
            resetDataAfterError(sp, billLinesMap);
            ApexPages.addMessages(securityException);
            showData = false;
        }
        catch (Exception ex) {
            resetDataAfterError(sp, billLinesMap);
            ApexPages.addMessages(ex);
            showData = true;
        }

        showInfo = false;

        return NULL;
    }

    private void resetDataAfterError(Savepoint sp, Map<Expense_Line__c, Billing_Line__c> billLinesMap) {
        Database.rollback(sp);

        for (Expense_Line__c el : billLinesMap.keySet()) {
            el.Billing_Line__c = NULL;
            el.Billed__c = false;
        }

        isSuccess = false;
        isNeedToPost = false;
    }

}