public with sharing class BillingFromTimeCard {
   
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String NO_SELECTION_ERROR_MESSAGE = Label.ERR_NO_QUALIFYING_RECORDS_SELECTED;
    public static final String NO_ACCOUNTING_RANGE_ERROR = Label.ERR_NO_ACCOUNTING_PERIOD_IN_DATE_RANGE;
    public static final String NO_OPEN_ACCOUNTING_RANGE_ERROR = Label.ERR_NO_OPEN_ACCOUNTING_PERIOD_IN_DATE_RANGE;

    private ApexPages.StandardSetController stdSetController;
    private List<Time_Card_Line__c> timeCardLines;
    private Map<String, TimeCardWrapper> timeCardMap;
    @TestVisible
    private Map<String, Billing_Rates__c> billingRates;
    private Boolean isNeedToPost;

    public List<TimeCardWrapper> timeCardWrapperList {get; set;}
    public Billing__c bill {get; set;}
    public String filterId {get; private set;}
    public Boolean isSuccess {get; private set;}
    public Boolean showInfo {get; private set;}
    public Boolean showData {get; private set;}
    public Boolean isMultiCurrencyEnabled {get; private set;}
    public Map<Id, Ledger__c> ledgerMap {get; set;}

    public BillingFromTimeCard(ApexPages.StandardSetController setController) {
        this.stdSetController = setController;
        bill = new Billing__c();
        filterId = stdSetController.getFilterId().substring(0, 15);
        isSuccess = false;
        isNeedToPost = false;
        showInfo = false;
        showData = true;
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        ledgerMap = new Map<Id, Ledger__c>(LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers());
        try {
            timeCardLines = queryTimeCardLines((List<Time_Card__c>) stdSetController.getSelected());
            init();
            showInfo = true;
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isSuccess   = false;
            showData    = false;
        }
    }

    public String getListViewId() {
        return stdSetController.getFilterId();
    }

    public String getSObjectApiName() {
        return Time_Card__c.SObjectType.getDescribe().getName();
    }

    private List<Time_Card_Line__c> queryTimeCardLines(List<Time_Card__c> selectedTimeCards) {
        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Project__c',
            'Project__r.Account__c',
            'Project__r.Account__r.Name',
            'Project_Task__r.Labor_GL_Account__r.TM_Revenue_Conversion__c',
            'Project_Task__c',
            'Total_Hours__c',
            'Billable__c',
            'Overtime__c',
            'Time_Card__r.Employee__r.Name',
            'Time_Card__r.Employee__c',
            'Time_Card__r.Employee__r.Default_Billing_Rate__c',
            'Time_Card__r.Time_Card_Period__r.Name',
            'Time_Card__r.Ledger__c',
            'Project__r.Name',
            'Project_Task__r.Name',
            'Project_Task__r.GL_Account_Variable_1__c',
            'Project_Task__r.GL_Account_Variable_2__c',
            'Project_Task__r.GL_Account_Variable_3__c',
            'Project_Task__r.GL_Account_Variable_4__c',
            'Time_Card_Variable_1__c',
            'Time_Card_Variable_2__c'
        };

        //Add main query condition
        String queryCondition =
            'Time_Card__c = :selectedTimeCards ' +
            'AND Billable__c = true ' +
            'AND Project__r.Account__c != NULL ' +
            'AND Time_Card__r.Status__c = \'Posted\' ' +
            'AND Billed__c = false ORDER BY Project__r.Account__r.Name ASC';

        //Add subquery
        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Time_Card_Days__r';
        List<String> subQueryFields = new List<String>{
            'Id',
            'Hours__c',
            'Date__c',
            'Invoice_Comment__c'
        };
        String subQueryCondition = 'Billing_Line__c = NULL';


        SOQLBuilder theQuery = new SOQLBuilder(Time_Card_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, true)
            .setEnforceFLS(true)
            .selectFields(subQueryFields)
            .setCondition(subQueryCondition);

        return (List<Time_Card_Line__c>) Database.query(theQuery.toSOQL());
    }
    
    public void init() {
        timeCardMap = new Map<String, TimeCardWrapper>();

        getBillingRates();
        for (Time_Card_Line__c tcl : timeCardLines) {
            tcl.Time_Card__r.Ledger__c = tcl.Time_Card__r.Ledger__c != NULL ? tcl.Time_Card__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        }

        for (Time_Card_Line__c tcl : timeCardLines) {
            Billing_Rates__c br = new Billing_Rates__c(Amount__c = 0);
            String key = String.valueOf(tcl.Project__r.Account__c) + String.valueOf(tcl.Time_Card__r.Ledger__c);

            if (billingRates.containsKey(String.valueOf(tcl.Project_Task__c) + String.valueOf(tcl.Time_Card__r.Employee__c))) {
                br = billingRates.get(String.valueOf(tcl.Project_Task__c) + String.valueOf(tcl.Time_Card__r.Employee__c));
            }
            else if (billingRates.containsKey(String.valueOf(tcl.Project__c) + String.valueOf(tcl.Time_Card__r.Employee__c))) {
                br = billingRates.get(String.valueOf(tcl.Project__c) + String.valueOf(tcl.Time_Card__r.Employee__c));
            }
    
            if (timeCardMap.containsKey(key)) {
                timeCardMap.get(key).addTimeCardLine(tcl, br);
            }
            else {
                timeCardMap.put(key, new TimeCardWrapper(tcl, tcl.Project__r.Account__r, br));
            }
        }
        
        timeCardWrapperList = timeCardMap.values();
        
        if (timeCardWrapperList.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_SELECTION_ERROR_MESSAGE));
            showData = false;
        }
        else {
            bill.Billing_Format__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(
                timeCardWrapperList[0].timeCardLineList[0].tcLine.Time_Card__r.Ledger__c
            ).Default_Billing_Format__c;
        }
    }
    
    public with sharing class TimeCardWrapper {
        
        public List<TimeCardLineWrapper> timeCardLineList {get; set;}
        public Account acct {get; set;}

        public TimeCardWrapper(Time_Card_Line__c tcl, Account acct, Billing_Rates__c br) {
            timeCardLineList = new List<TimeCardLineWrapper>();
            timeCardLineList.add(new TimeCardLineWrapper(tcl, br));
            this.acct = acct;
        }
                
        public void addTimeCardLine(Time_Card_Line__c tcl, Billing_Rates__c br) {
            timeCardLineList.add(new TimeCardLineWrapper(tcl, br));
        }
        
        public Decimal getAmount() {
            Decimal amount = 0;
            for (TimeCardLineWrapper tclw : timeCardLineList) {
                amount +=
                    tclw.tcLine.Total_Hours__c *
                        (
                            (tclw.tcLine.Overtime__c && tclw.billingRate.Overtime_Labor_Billing_Rate__c > 0)
                                ? tclw.billingRate.Overtime_Labor_Billing_Rate__c
                                : tclw.billingRate.Amount__c
                        );
            }
            
            return amount;
        }
        
    }
    

    public with sharing class TimeCardLineWrapper {
        public Time_Card_Line__c tcLine {get; set;}
        public Billing_Rates__c billingRate {get; set;}
        public Billing_Line__c glAccountBillLine {get; set;}
        
        public TimeCardLineWrapper(Time_Card_Line__c tcLine, Billing_Rates__c billingRate) {
            this.tcLine = tcLine;
            this.billingRate = billingRate;
            this.glAccountBillLine = new Billing_Line__c(Revenue_GL_Account__c = tcLine.Project_Task__r.Labor_GL_Account__r.TM_Revenue_Conversion__c);
        }
        
        public Decimal getAmount() {
            Decimal amount = 0;
            amount += tcLine.Total_Hours__c * getBillingRateAmount();
            return amount;
        }
        
        public Decimal getBillingRateAmount() {
            Decimal billRateAmount = 0;

            if (tcLine.Overtime__c && billingRate.Overtime_Labor_Billing_Rate__c > 0) {
                billRateAmount = billingRate.Overtime_Labor_Billing_Rate__c;
            }
            else if (billingRate.Amount__c != 0) {
                billRateAmount = billingRate.Amount__c;
            }
            else if (tcLine.Time_Card__r.Employee__r.Default_Billing_Rate__c != NULL) {
                billRateAmount = tcLine.Time_Card__r.Employee__r.Default_Billing_Rate__c;
            }
            
            return billRateAmount;
        }
    }

    private void getBillingRates() {

        billingRates = new Map<String, Billing_Rates__c>();
        Set<Id> employeeIds = new Set<Id>();
        Set<Id> projectIds = new Set<Id>();
        Set<Id> projectTaskIds = new Set<Id>();
        
        for (Time_Card_Line__c tcl : timeCardLines) {
            employeeIds.add(tcl.Time_Card__r.Employee__c);
            projectIds.add(tcl.Project__c);     
            projectTaskIds.add(tcl.Project_Task__c);    
        }

        for (Billing_Rates__c rate : queryBillingRates(employeeIds, projectIds, projectTaskIds)) {

            if (rate.Project_Task__c != NULL && !billingRates.containsKey(String.valueOf(rate.Project_Task__c) + String.valueOf(rate.Employee__c))) {
                billingRates.put(String.valueOf(rate.Project_Task__c) + String.valueOf(rate.Employee__c), rate);
                continue;
            }
             
            if (rate.Project__c != NULL && rate.Project_Task__c == NULL && !billingRates.containsKey(String.valueOf(rate.Project__c) + String.valueOf(rate.Employee__c))) {
                billingRates.put(String.valueOf(rate.Project__c) + String.valueOf(rate.Employee__c), rate);
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
            'Overtime_Labor_Billing_Rate__c'
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
        Map<String, Billing__c> billings =  new Map<String, Billing__c>();
        Map<Time_Card_Day__c, Billing_Line__c> billLinesMap = new Map<Time_Card_Day__c, Billing_Line__c>();
        List<Time_Card_Line__c> tcLineList = new List<Time_Card_Line__c>();
        List<Time_Card_Day__c> tcDayList = new List<Time_Card_Day__c>();
        
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
                for (TimeCardWrapper tcw : timeCardWrapperList) {
                    Id ledgerId = tcw.timeCardLineList[0].tcLine.Time_Card__r.Ledger__c;
                    String key = String.valueOf(tcw.acct.Id) + String.valueOf(ledgerId);
                    Billing__c theBill = new Billing__c();
                    theBill.Accounting_Period__c = bill.Accounting_Period__c;
                    theBill.Date__c = bill.Date__c;
                    theBill.Billing_Cycle_Start_Date__c = bill.Billing_Cycle_Start_Date__c;
                    theBill.Billing_Cycle_End_Date__c = bill.Billing_Cycle_End_Date__c;
                    theBill.Customer__c = tcw.acct.Id;
                    theBill.Billing_Format__c = bill.Billing_Format__c;
                    theBill.Ledger__c = ledgerId;
                    if (isNeedToPost) {
                        theBill.Status__c = 'Approved';
                    }
                    if (isNeedToPost && AbstractTaxService.isLedgerTaxSettingsEmpty(theBill)) {
                        throw new AvaTaxService.AvaTaxException(TaxService.getNoTaxSettingErrorMessage(false));
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

                for (TimeCardWrapper tcw : timeCardWrapperList) {
                    String key = String.valueOf(tcw.acct.Id) + String.valueOf(tcw.timeCardLineList[0].tcLine.Time_Card__r.Ledger__c);
                    for (TimeCardLineWrapper tclw : tcw.timeCardLineList) {
                        for (Time_Card_Day__c tcd : tclw.tcLine.Time_Card_Days__r) {
                            Billing_Line__c billLine = new Billing_Line__c();
                            billLine.Revenue_GL_Account__c = tclw.glAccountBillLine.Revenue_GL_Account__c;
                            billLine.Billing__c = billings.get(key).Id;
                            billLine.Date__c = tcd.Date__c;
                            billLine.Comment__c = tcd.Invoice_Comment__c;
                            billLine.Employee__c = tclw.tcLine.Time_Card__r.Employee__c;
                            billLine.Rate__c = tclw.getBillingRateAmount();
                            billLine.Hours_Units__c = tcd.Hours__c;
                            billLine.Project__c = tclw.tcLine.Project__c;
                            billLine.Project_Task__c = tclw.tcLine.Project_Task__c;
                            billLine.GL_Account_Variable_1__c = tclw.tcLine.Project_Task__r.GL_Account_Variable_1__c;
                            billLine.GL_Account_Variable_2__c = tclw.tcLine.Project_Task__r.GL_Account_Variable_2__c;
                            billLine.GL_Account_Variable_3__c = tclw.tcLine.Project_Task__r.GL_Account_Variable_3__c;
                            billLine.GL_Account_Variable_4__c = tclw.tcLine.Project_Task__r.GL_Account_Variable_4__c;
                            billLine.Time_Card_Variable_1__c = tclw.tcLine.Time_Card_Variable_1__c;
                            billLine.Time_Card_Variable_2__c = tclw.tcLine.Time_Card_Variable_2__c;
                            billLinesMap.put(tcd, billLine);
                        }
                    }
                }

                //Insert new Billing Lines
                SFDCSecurityUtils.insertCheckCRUDAndFLS(billLinesMap.values(), new List<String>{
                    'Revenue_GL_Account__c',
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
                    'GL_Account_Variable_4__c',
                    'Time_Card_Variable_1__c',
                    'Time_Card_Variable_2__c'
                });

                for (TimeCardWrapper tcw : timeCardWrapperList) {
                    for (TimeCardLineWrapper tclw : tcw.timeCardLineList) {
                        for (Time_Card_Day__c tcd : tclw.tcLine.Time_Card_Days__r) {
                            tcd.Billing_Line__c = billLinesMap.get(tcd).Id;
                            tcDayList.add(tcd);
                        }
                        tclw.tcLine.Billed__c = true;
                        tcLineList.add(tclw.tcLine);
                    }
                }

                SFDCSecurityUtils.updateCheckCRUDAndFLS(tcLineList, new List<String>{'Billed__c'});
                SFDCSecurityUtils.updateCheckCRUDAndFLS(tcDayList, new List<String>{'Billing_Line__c'});

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
            resetDataAfterError(sp);
            ApexPages.addMessages(securityException);
            showData = false;
        }
        catch (Exception ex) {
            resetDataAfterError(sp);
            ApexPages.addMessages(ex);
            showData = true;
        }

        showInfo = false;

        return NULL;
    }

    private void resetDataAfterError(Savepoint sp) {
        Database.rollback(sp);

        for (TimeCardWrapper tcw : timeCardWrapperList) {
            for (TimeCardLineWrapper tclw : tcw.timeCardLineList) {
                for (Time_Card_Day__c tcd : tclw.tcLine.Time_Card_Days__r) {
                    tcd.Billing_Line__c = NULL;
                }
                tclw.tcLine.Billed__c = false;
            }
        }
        isSuccess       = false;
        isNeedToPost    = false;
    }

}