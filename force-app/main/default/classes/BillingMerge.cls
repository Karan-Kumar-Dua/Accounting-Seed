public with sharing class BillingMerge {
   
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String NO_QUALIFIED_RECORDS = Label.ERR_NO_QUALIFIED_RECORDS_MERGE;
    @TestVisible
    private static final String MULTI_CURRENCY_ERROR = Label.ERR_BILLING_MERGE_MULTI_CURRENCY;
    @TestVisible
    private static final String MULTI_LEDGER_ERROR = Label.ERR_BILLING_MERGE_MULTI_LEDGER;
    private static final String NO_LINES_ERROR = Label.ERR_BILLING_MERGE_NO_LINES;
    private static final String POSTED_BILLING_ERROR = Label.ERR_POSTED_BILLINGs_MERGE;
    @TestVisible
    private static final String AE_EXIST_ERROR = Label.ERR_BILLINGs_AE_EXIST_MERGE;
    @TestVisible
    private static final String MIXED_TYPE_ERROR = Label.ERR_CREDIT_MEMO_INVOICE_MERGE;
    private static final String SUCCESS_CONFIRMATION_MESSAGE = Label.INF_SUCCESS_BILLING_CREATION;

    private final ApexPages.StandardSetController stdSetController;

    private Accounting_Settings__c main;    
    private Accounting_Period__c acctPeriod;
    private Map<Id, Billing__c> deleteBillings;
    private List<Billing__c> selectedBillings;
    public List<BillingMergeWrapper> billingMergeWrapperList {get; private set;}
    public Boolean isValidationError {get; private set;}
    public Boolean isMergerProcessed {get; private set;}

    //several properties used if SF multi currency feature is enabled in the Org
    public Boolean isMultiCurrencyEnabled {get; set;}
    public String currencyIsoCode {get; set;}
    //==========================================================================

    public BillingMerge(ApexPages.StandardSetController setController) {
        try {
            this.stdSetController = setController;
            this.selectedBillings = (List<Billing__c>) stdSetController.getSelected();
            this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.isValidationError = false;
            this.isMergerProcessed = false;

            if (validateSelectedBillings()) {
                initBillingWrapper();
            }
            else {
                this.isValidationError = true;
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }
    
    public with sharing class BillingMergeWrapper {
        public List<Billing_Line__c> billLines {get; set;}
        public Billing__c bill {get; set;}
        public String customer {get; set;}

        public BillingMergeWrapper(Billing__c bill, List<Billing_Line__c> billLines, String customer) {
            this.billLines = billLines;
            this.bill = bill;
            this.customer = customer;
        }

        public Decimal getSum() {
            Decimal sum = 0;
            for (Billing_Line__c billLine : billLines) {
                sum += billLine.Total__c;
            }

            return sum;
        }

        public Integer getCount() {
            return billLines.size();
        }
    }

    public String getListViewId() {
        return stdSetController.getFilterId();
    }

    public String getSObjectApiName() {
        return Billing__c.SObjectType.getDescribe().getName();
    }

    private Boolean validateSelectedBillings() {
        Boolean isValid = true;
        //Prepare secured SOQL query...
        List<String> queryFields = new List<String>{
            'Id',
            'Type__c',
            'Customer__c',
            'Status__c',
            'Ledger__c'
        };
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id IN :selectedBillings';
        String subQueryBillingLines = PACKAGE_QUALIFIER + 'Project_Billing_Lines__r';
        String subQueryAmortizationEntries = PACKAGE_QUALIFIER + 'Scheduled_Revenues__r';
        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryBillingLines, false)
            .setEnforceFLS(false)
            .setLimit(1);
        theQuery
            .subselectQuery(subQueryAmortizationEntries, false)
            .setEnforceFLS(false);


        //And use it
        List<Billing__c> bills = (List<Billing__c>) Database.query(theQuery.toSOQL());

        if (bills.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_QUALIFIED_RECORDS));
            isValid = false;
        }
        else {
            if (isMultiCurrencyEnabled) {
                currencyIsoCode = (String) bills[0].get('CurrencyIsoCode');

                Set<String> currencyIsoCodes = new Set<String>();

                for (Billing__c bill : bills) {
                    currencyIsoCodes.add((String) bill.get('CurrencyIsoCode'));
                }

                if (currencyIsoCodes.size() > 1) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, MULTI_CURRENCY_ERROR));
                    isValid = false;
                }
            }

            Map<Id, List<Billing__c>> customerToBillings = new Map<Id, List<Billing__c>>();
            Integer numberOfPostedBillings = 0;
            Integer numberOfBillingsWithoutLines = 0;
            Integer numberOfBillingsWithAE = 0;

            for (Billing__c bill : bills) {
                if (customerToBillings.containsKey(bill.Customer__c)) {
                    customerToBillings.get(bill.Customer__c).add(bill);
                }
                else {
                    customerToBillings.put(bill.Customer__c, new List<Billing__c>{bill});
                }

                if (bill.Status__c == 'Posted') {
                    numberOfPostedBillings++;
                }

                if (bill.Project_Billing_Lines__r.isEmpty()) {
                    numberOfBillingsWithoutLines++;
                }
                if (!bill.Scheduled_Revenues__r.isEmpty()) {
                    numberOfBillingsWithAE++;
                }
            }

            if (numberOfPostedBillings > 0) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, POSTED_BILLING_ERROR));
                isValid = false;
            }

            if (numberOfBillingsWithoutLines > 0) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_LINES_ERROR));
                isValid = false;
            }

            if (numberOfBillingsWithAE > 0) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, AE_EXIST_ERROR));
                isValid = false;
            }

            for (Id customerId : customerToBillings.keySet()) {
                Set<String> types = new Set<String>();
                Set<String> ledgers = new Set<String>();
                for (Billing__c bill : customerToBillings.get(customerId)) {
                    types.add(bill.Type__c);
                    ledgers.add(bill.Ledger__c);
                }

                if (types.size() > 1) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, MIXED_TYPE_ERROR));
                    isValid = false;
                    break;
                }

                if (ledgers.size() > 1) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, MULTI_LEDGER_ERROR));
                    isValid = false;
                    break;
                }
            }

        }

        return isValid;
    }

    public void initBillingWrapper() {
        billingMergeWrapperList = new List<BillingMergeWrapper>();

        acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(System.today(), new Set<String>{AccountingPeriodActions.OPEN_STATUS},Billing__c.SObjectType);
        if (acctPeriod == NULL) {
            acctPeriod = new Accounting_Period__c();
        }

        deleteBillings = new Map<Id, Billing__c>();

        //Prepare SOQL Query to query Billing Lines with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Billing__c',
            'Name',
            'Date__c',
            'Billing__r.Name',
            'Billing__r.Ledger__c',
            'Revenue_GL_Account__r.Name',
            'Total__c',
            'Billing__r.Customer__r.Name',
            'Project__r.Name',
            'Project_Task__r.Name',
            'Product__r.Name'
        };

        String queryCondition =
            'Billing__c IN :selectedBillings ' +
            'AND Billing__r.Status__c != \'Posted\' ' +
            'ORDER BY Billing__r.Customer__r.Name ASC, Billing__r.Name ASC, Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        Map<String, List<Billing_Line__c>> customerLedgerMap = new Map<String, List<Billing_Line__c>>();

        for (Billing_Line__c billLine : (List<Billing_Line__c>) Database.query(theQuery.toSOQL())) {

            Id ledgerId =
                (billLine.Billing__r.Ledger__c == NULL)
                    ? LedgerHandler.getLegacyDefaultLedgerId()
                    : billLine.Billing__r.Ledger__c;
            String key = String.valueOf(billLine.Billing__r.Customer__r.Id) + String.valueOf(ledgerId);

            if (customerLedgerMap.containsKey(key)) {
                customerLedgerMap.get(key).add(billLine);
            } else {
                customerLedgerMap.put(key, new List<Billing_Line__c> {billLine});
            }
            deleteBillings.put(billLine.Billing__r.Id, billLine.Billing__r);
        }

        for (String key : customerLedgerMap.keySet()) {
            Id ledgerId =
                (customerLedgerMap.get(key)[0].Billing__r.Ledger__c == NULL)
                    ? LedgerHandler.getLegacyDefaultLedgerId()
                    : customerLedgerMap.get(key)[0].Billing__r.Ledger__c;

            Billing__c bill = getNewBilling();
            bill.Accounting_Period__c = acctPeriod.Id;
            bill.Customer__c = customerLedgerMap.get(key)[0].Billing__r.Customer__r.Id;
            bill.Ledger__c = ledgerId;
            billingMergeWrapperList.add(
                new BillingMergeWrapper(
                    bill,
                    customerLedgerMap.get(key),
                    customerLedgerMap.get(key)[0].Billing__r.Customer__r.Name
                )
            );
        }

    }

    private Billing__c getNewBilling() {
        Billing__c result = new Billing__c();
        if (isMultiCurrencyEnabled) {
            result.put('CurrencyIsoCode', this.currencyIsoCode);
        }
        return result;
    }

    public PageReference mergeBillings() {
        Savepoint sp = Database.setSavepoint();
        try {
            List<Billing__c> billings = new List<Billing__c>();
            List<Billing_Line__c> billLines = new List<Billing_Line__c>();
            for (BillingMergeWrapper bmw : billingMergeWrapperList) {
                billings.add(bmw.bill);
            }

            SFDCSecurityUtils.upsertProxy(billings);

            for (BillingMergeWrapper bmw : billingMergeWrapperList) {
                for (Billing_Line__c billLine : bmw.billLines) {
                    billLine.Billing__c = bmw.bill.Id;
                    billLines.add(billLine);
                }
            } 
            
            SFDCSecurityUtils.updateProxy(billLines);
            
            SFDCSecurityUtils.deleteProxy(deleteBillings.values());
            
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, SUCCESS_CONFIRMATION_MESSAGE));
            isMergerProcessed = true;
        }
        catch (Exception ex) {
            Database.rollback(sp);
            ApexPages.addMessages(ex);
            isValidationError = true;
        }

        return NULL;
    }

}