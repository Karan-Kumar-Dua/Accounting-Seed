public with sharing class FinancialReportTransactionDetail {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;

    public String glAccountId               { get; set; }
    public String acctPeriodId              { get; set; }
    public Accounting_Period__c acctPeriod  { get; set; }
    public String glavVariable1             { get; set; }
    public String glavVariable2             { get; set; }
    public String glavVariable3             { get; set; }
    public String glavVariable4             { get; set; }
    public Transaction__c theTransaction    { get; set; }
    public Boolean isMultiCurrencyEnabled   { get; set; }
    public Boolean isCashFlowGlAccount      { get; set; }
    public String ledgerId                  { get; set; }
    public String ledgerCurrency            { get; set; }
    public Boolean isERPEnabled = AccountingSettingsHandler.isERPEnabled();
    private Boolean isLedgerEqualLegacyLedger;
    private static final Integer RECORD_DISPLAY_LIMIT = 4000;
    private static final String RECORD_LIMIT_ERROR_MESSAGE = Label.ERR_RECORD_LIMIT;

    public FinancialReportTransactionDetail() {
        try {
            this.glAccountId = ApexPages.currentPage().getParameters().get('glAccountId');
            this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.isCashFlowGlAccount = (getGLAccountType(this.glAccountId) == 'Cash Flow') ? true : false;
            this.acctPeriodId = ApexPages.currentPage().getParameters().get('acctPeriodId');
            this.glavVariable1 = ApexPages.currentPage().getParameters().get('glav1');
            this.glavVariable2 = ApexPages.currentPage().getParameters().get('glav2');
            this.glavVariable3 = ApexPages.currentPage().getParameters().get('glav3');
            this.glavVariable4 = ApexPages.currentPage().getParameters().get('glav4');
            this.ledgerId = ApexPages.currentPage().getParameters().get('ledgerId');
            this.acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(this.acctPeriodId);
            this.theTransaction = new Transaction__c();
            theTransaction.Ledger__c = ledgerId;
            isLedgerEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(ledgerId);
            ledgerCurrency =
                isMultiCurrencyEnabled
                    ? (String) LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId).get('CurrencyIsoCode')
                    : MultiCurrencyHandler.CORPORATE_CURRENCY;
            populateStaticFields();

            List<TransactionWrapper> transWrapperList = getTransactions(
                glAccountId,
                acctPeriodId,
                ledgerId,
                glavVariable1,
                glavVariable2,
                glavVariable3,
                glavVariable4,
                isERPEnabled
            );

            if (transWrapperList.size() >= RECORD_DISPLAY_LIMIT) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.WARNING,
                        String.format(RECORD_LIMIT_ERROR_MESSAGE, new List<String>{String.valueOf(RECORD_DISPLAY_LIMIT)})
                    )
                );
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    private static String getGLAccountType(String glAcctId) {
        //==================================================================================================
        // This query serves to check type of current GL Account only
        // CRUD and FLS are handled and checked by VF page
        //==================================================================================================
        String result;
        try {
            List<GL_Account__c> glAccounts = DomainUtils.getGlAccountsById(new Set<Id>{glAcctId});
            if (!glAccounts.isEmpty()) {
                result = glAccounts[0].Type__c;
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private void populateStaticFields() {
        //from there we have two possible flow
        //1. Query among regular existed Transactions (Transaction__c) records
        //2. Query among Archived Transactions (Transaction_Archive__b)
        if (acctPeriod.Status__c == AccountingPeriodActions.ARCHIVED_STATUS) {//2
            populateStaticFieldsFromArchive();
        }
        else {//1
            populateStaticFieldsFromTransactions();
        }
    }

    private void populateStaticFieldsFromTransactions() {
        List<Transaction__c> transactions =
            queryTransactionsByGLAccountAndAccountingPeriod(glAccountId, acctPeriod.Id);

        if (!transactions.isEmpty()) {
            theTransaction.GL_Account__c = transactions[0].GL_Account__c;
            if (isCashFlowGlAccount) {
                theTransaction.Cash_Flow_Category__c = transactions[0].Cash_Flow_Category__c;
            }
            theTransaction.Accounting_Period__c = transactions[0].Accounting_Period__c;
            //==================================================================================================
            // CRUD and FLS are handled and checked in the queryTransactionsByGLAccountAndAccountingPeriod
            // Performing CRUD and FLS would be a redundant check for aggregate query
            //==================================================================================================
            String dynamicQueryString =
                'SELECT SUM(' + PACKAGE_QUALIFIER + 'Amount__c) totalAmount ' +
                'FROM ' + PACKAGE_QUALIFIER + 'Transaction__c ' +
                'WHERE ' +
                    (
                        (isCashFlowGlAccount)
                            ? PACKAGE_QUALIFIER + 'Cash_Flow_Category__c = :glAccountId ' +
                              'AND ' + PACKAGE_QUALIFIER + 'GL_Account__r.' + PACKAGE_QUALIFIER + 'Bank__c = true '
                            : PACKAGE_QUALIFIER + 'GL_Account__c = :glAccountId '
                    ) +
                'AND ' + PACKAGE_QUALIFIER + 'Accounting_Period__c = :acctPeriodId ' +
                (!String.isBlank(glavVariable1)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c = :glavVariable1 ' : '') +
                (!String.isBlank(glavVariable2)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c = :glavVariable2 ' : '') +
                (!String.isBlank(glavVariable3)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c = :glavVariable3 ' : '') +
                (!String.isBlank(glavVariable4)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c = :glavVariable4 ' : '') +
                'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
                (isLedgerEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
                (!isLedgerEqualLegacyLedger ? ') ' : '') +
                'GROUP BY ' + PACKAGE_QUALIFIER + 'GL_Account__c';

            Decimal conversionRate = 1;
            if (isMultiCurrencyEnabled) {
                conversionRate = MultiCurrencyHandler.getConversionRateByCurrencyCode(ledgerCurrency);
            }
            List<AggregateResult> groupedResults = Database.query(dynamicQueryString);
            Decimal totalAmount = 0;
            for (AggregateResult result : groupedResults) {
                totalAmount += (Decimal) result.get('totalAmount') * conversionRate;
            }
            theTransaction.Amount__c = totalAmount;
        }

    }

    private void populateStaticFieldsFromArchive() {
        //we cant query archived Transactions directly so we will query Financial Cube first
        List<String> queryFields = new List<String>{
            'Id',
            'GL_Account__c',
            'Accounting_Period__c',
            'Amount__c'
        };

        String cubeType = (isCashFlowGlAccount) ? 'Cash Flow' : 'Period';

        String queryCondition =
                PACKAGE_QUALIFIER + 'Accounting_Period__c = :acctPeriodId ' +
                'AND GL_Account__c = :glAccountId ' +
                'AND ' + PACKAGE_QUALIFIER + 'Cube_Type__c = :cubeType ' +
                    (!String.isBlank(glavVariable1)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c = :glavVariable1 ' : '') +
                (!String.isBlank(glavVariable2)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c = :glavVariable2 ' : '') +
                (!String.isBlank(glavVariable3)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c = :glavVariable3 ' : '') +
                (!String.isBlank(glavVariable4)
                    ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c = :glavVariable4 ' : '') +
                'AND ' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId';

        SOQLBuilder theQuery = new SOQLBuilder(Financial_Cube__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(50000);

        List<Financial_Cube__c> fCubes = (List<Financial_Cube__c>) Database.query(theQuery.toSOQL());

        if (!fCubes.isEmpty()) {
            theTransaction.GL_Account__c = fCubes[0].GL_Account__c;
            if (isCashFlowGlAccount) {
                theTransaction.Cash_Flow_Category__c = fCubes[0].GL_Account__c;
            }
            theTransaction.Accounting_Period__c = fCubes[0].Accounting_Period__c;
        }

        Decimal totalAmount = 0;
        for (Financial_Cube__c fCube : fCubes) {
            totalAmount += fCube.Amount__c;
        }

        theTransaction.Amount__c = totalAmount;
    }

    private List<Transaction__c> queryTransactionsByGLAccountAndAccountingPeriod(String glAccountId, Id theAccountingPeriodId) {

        List<String> queryFields = new List<String>{
            'Id',
            'GL_Account__c',
            'Accounting_Period__c'
        };

        if (isCashFlowGlAccount) {
            queryFields.add('Cash_Flow_Category__c');
        }

        String queryCondition =
            (
                (isCashFlowGlAccount)
                    ? 'Cash_Flow_Category__c = :glAccountId AND GL_Account__r.Bank__c = true '
                    : 'GL_Account__c = :glAccountId '
            ) +
            'AND Accounting_Period__c = :theAccountingPeriodId ' +
            'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
            (isLedgerEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
            (!isLedgerEqualLegacyLedger ? ') ' : ' ');

        SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(1);

        return (List<Transaction__c>) Database.query(theQuery.toSOQL());
    }

    public Boolean getIsERPEnabled() {
        return isERPEnabled;
    }

    @RemoteAction @ReadOnly
    public static List<TransactionWrapper> getTransactions( String glAccountId,
                                                            String acctPeriodId,
                                                            String ledgerId,
                                                            String glavVariable1,
                                                            String glavVariable2,
                                                            String glavVariable3,
                                                            String glavVariable4,
                                                            Boolean isERPEnabled ) {


        List<FinancialReportTransactionDetail.TransactionWrapper> transList = new List<FinancialReportTransactionDetail.TransactionWrapper>();

        try {
            Boolean isCashFlowGlAccount =
                (FinancialReportTransactionDetail.getGLAccountType(glAccountId) == 'Cash Flow') ? true : false;

            Accounting_Period__c theAccountingPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(acctPeriodId);

            String accountingPeriodId = theAccountingPeriod.Id;

            if (theAccountingPeriod.Status__c == AccountingPeriodActions.ARCHIVED_STATUS) {
                transList = FinancialReportTransactionDetail.getTransactionsFromArchive(
                    glAccountId,
                    accountingPeriodId,
                    ledgerId,
                    glavVariable1,
                    glavVariable2,
                    glavVariable3,
                    glavVariable4,
                    isCashFlowGlAccount,
                    isERPEnabled
                );
            }
            else {
                transList = FinancialReportTransactionDetail.getTransactionsRegular(
                    glAccountId,
                    accountingPeriodId,
                    ledgerId,
                    glavVariable1,
                    glavVariable2,
                    glavVariable3,
                    glavVariable4,
                    isCashFlowGlAccount,
                    isERPEnabled
                );
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return transList;
    }

    private static List<TransactionWrapper> getTransactionsFromArchive( String glAccountId,
                                                                        String acctPeriodId,
                                                                        String ledgerId,
                                                                        String glavVariable1,
                                                                        String glavVariable2,
                                                                        String glavVariable3,
                                                                        String glavVariable4,
                                                                        Boolean isCashFlowGlAccount,
                                                                        Boolean isERPEnabled) {

        List<FinancialReportTransactionDetail.TransactionWrapper> transList =
            new List<FinancialReportTransactionDetail.TransactionWrapper>();

        try {
            String cubeType = (isCashFlowGlAccount) ? 'Cash Flow' : 'Period';

            List<String> queryFields = new List<String>{
                PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_1__r.Name',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_2__r.Name',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_3__r.Name',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c',
                PACKAGE_QUALIFIER + 'GL_Account_Variable_4__r.Name'
            };

            String queryCondition =
                PACKAGE_QUALIFIER + 'Accounting_Period__c = :acctPeriodId ' +
                    'AND GL_Account__c = :glAccountId ' +
                    'AND ' + PACKAGE_QUALIFIER + 'Cube_Type__c = :cubeType ' +
                    (!String.isBlank(glavVariable1)
                        ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c = :glavVariable1 ' : '') +
                    (!String.isBlank(glavVariable2)
                        ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c = :glavVariable2 ' : '') +
                    (!String.isBlank(glavVariable3)
                        ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c = :glavVariable3 ' : '') +
                    (!String.isBlank(glavVariable4)
                        ? ' AND ' + PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c = :glavVariable4 ' : '') +
                    'AND ' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId';

            SOQLBuilder theQuery = new SOQLBuilder(Financial_Cube__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(10000);

            Map<Id, Financial_Cube__c> fCubeMap = new Map<Id, Financial_Cube__c>(
                (List<Financial_Cube__c>) Database.query(theQuery.toSOQL())
            );

            //get GLAVs from Financial Cubes <Id, Name>
            Map<Id, String> glavsMap = new Map<Id, String>();
            for (Financial_Cube__c fCube : fCubeMap.values()) {
                if (fCube.GL_Account_Variable_1__c != NULL) {
                    glavsMap.put(fCube.GL_Account_Variable_1__c, fCube.GL_Account_Variable_1__r.Name);
                }
                if (fCube.GL_Account_Variable_2__c != NULL) {
                    glavsMap.put(fCube.GL_Account_Variable_2__c, fCube.GL_Account_Variable_2__r.Name);
                }
                if (fCube.GL_Account_Variable_3__c != NULL) {
                    glavsMap.put(fCube.GL_Account_Variable_3__c, fCube.GL_Account_Variable_3__r.Name);
                }
                if (fCube.GL_Account_Variable_4__c != NULL) {
                    glavsMap.put(fCube.GL_Account_Variable_4__c, fCube.GL_Account_Variable_4__r.Name);
                }
            }

            //then we can query archived records by FC Ids
            for (Transaction_Archive__b archivedTransaction : DomainUtils.queryArchivedTransactionsByFinancialCubes(fCubeMap.keySet())) {
                transList.add(new FinancialReportTransactionDetail.TransactionWrapper(archivedTransaction, glavsMap, isERPEnabled));
            }

        }
        catch (Exception ex) {
            throw ex;
        }

        return transList;
    }

    private static List<TransactionWrapper> getTransactionsRegular( String glAccountId,
                                                                    String acctPeriodId,
                                                                    String ledgerId,
                                                                    String glavVariable1,
                                                                    String glavVariable2,
                                                                    String glavVariable3,
                                                                    String glavVariable4,
                                                                    Boolean isCashFlowGlAccount,
                                                                    Boolean isERPEnabled ) {

        List<FinancialReportTransactionDetail.TransactionWrapper> transList =
            new List<FinancialReportTransactionDetail.TransactionWrapper>();
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Account__c',
                'Account__r.Name',
                'Date__c',
                'GL_Account__c',
                'GL_Account__r.Name',
                'Accounting_Period__c',
                'Accounting_Period__r.Name',
                'Project__c',
                'Project__r.Name',
                'Project_Task__c',
                'Project_Task__r.Name',
                'Product__c',
                'Product__r.Name',
                'Report_Amount__c',
                'Amount__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_1__r.Name',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_2__r.Name',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_3__r.Name',
                'GL_Account_Variable_4__c',
                'GL_Account_Variable_4__r.Name',
                'Account_Payable__r.Name',
                'Account_Payable_Line__r.Name',
                'AP_Disbursement__r.Name',
                'Billing__r.Name',
                'Billing_Line__r.Name',
                'Billing_Cash_Receipt__r.Name',
                'Cash_Disbursement__r.Name',
                'Cash_Receipt__r.Name',
                'Journal_Entry_Line__r.Name',
                'Time_Card_Day__r.Name',
                'Scheduled_Revenue_Expense__r.Name'
            };

            if (isERPEnabled) {
                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c');
                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__r.Name');

                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c');
                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__r.Name');

                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c');
                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__r.Name');

                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c');
                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__r.Name');

                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c');
                queryFields.add(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__r.Name');
            }

            String queryCondition =
                (
                    (isCashFlowGlAccount)
                        ? 'Cash_Flow_Category__c = :glAccountId AND GL_Account__r.Bank__c = true '
                        : 'GL_Account__c = :glAccountId '
                ) +
                'AND Accounting_Period__c = :acctPeriodId ' +
                (!String.isBlank(glavVariable1) ? ' AND GL_Account_Variable_1__c = :glavVariable1 ' : '') +
                (!String.isBlank(glavVariable2) ? ' AND GL_Account_Variable_2__c = :glavVariable2 ' : '') +
                (!String.isBlank(glavVariable3) ? ' AND GL_Account_Variable_3__c = :glavVariable3 ' : '') +
                (!String.isBlank(glavVariable4) ? ' AND GL_Account_Variable_4__c = :glavVariable4 ' : '') +
                'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
                (LedgerHandler.isLedgerEqualLegacyLedger(ledgerId) ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
                (!LedgerHandler.isLedgerEqualLegacyLedger(ledgerId) ? ') ' : ' ');
            SOQLBuilder.Ordering ordering =
                new SOQLBuilder.Ordering('Transaction__c', 'Date__c', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .setLimit(RECORD_DISPLAY_LIMIT);

            Set<String> populatedFields;
            for (Transaction__c trans : (List<Transaction__c>) Database.query(theQuery.toSOQL())) {
                populatedFields = trans.getPopulatedFieldsAsMap().keySet();
                transList.add(new FinancialReportTransactionDetail.TransactionWrapper(trans, populatedFields, isERPEnabled));
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return transList;
    }

    //Inner class used for display record as hyperlink in HTML table
    //Contains access info as well
    public with sharing class ActiveSource {
        @AuraEnabled
        public String name {get; set;}
        @AuraEnabled
        public String id {get; set;}
        @AuraEnabled
        public Boolean isAccessible {get; set;}

        public ActiveSource(Id id, String name, Boolean isAccessible) {
            this.id = (id == NULL) ? '' : (String) id;
            this.name = (name == NULL) ? '' : name;
            this.isAccessible = (isAccessible == NULL) ? true : isAccessible;
        }

    }

    public with sharing class TransactionWrapper {

        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource id {get; set;}
        @AuraEnabled
        public String transactionDate {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource accountingPeriod {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource glAccount {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource account {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource source {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource project {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource projectTask {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource product {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource glav1 {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource glav2 {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource glav3 {get; set;}
        @AuraEnabled
        public FinancialReportTransactionDetail.ActiveSource glav4 {get; set;}
        @AuraEnabled
        public Decimal amount {get; set;}

        private Boolean isERPEnabled;
        private Set<String> populatedFields;

        public TransactionWrapper() {}

        public TransactionWrapper(Transaction_Archive__b archivedTrans, Map<Id, String> glavsMap, Boolean isERPEnabled) {
            this.isERPEnabled = isERPEnabled;
            this.id = new FinancialReportTransactionDetail.ActiveSource(NULL, 'Archived', true);
            this.transactionDate = archivedTrans.Date__c.date().format();
            this.account = new FinancialReportTransactionDetail.ActiveSource(
                archivedTrans.Account__c,
                archivedTrans.Account__r.Name,
                true
            );
            this.source = new FinancialReportTransactionDetail.ActiveSource(
                getSourceIdForArchived(archivedTrans),
                archivedTrans.Source_Name__c,
                !AccountingPeriodHandler.getInstance().getAccountingPeriodById(archivedTrans.Accounting_Period__c).Source_Docs_Deleted__c
            );
            this.project = new FinancialReportTransactionDetail.ActiveSource(
                archivedTrans.Project__c,
                archivedTrans.Project__r.Name,
                true
            );
            this.projectTask = new FinancialReportTransactionDetail.ActiveSource(
                archivedTrans.Project_Task__c,
                archivedTrans.Project_Task__r.Name,
                true
            );
            this.product = new FinancialReportTransactionDetail.ActiveSource(
                archivedTrans.Product__c,
                archivedTrans.Product__r.Name,
                true
            );
            this.glav1 =
                new FinancialReportTransactionDetail.ActiveSource(
                    archivedTrans.GL_Account_Variable_1__c,
                    glavsMap.get(archivedTrans.GL_Account_Variable_1__c),
                    true
                );
            this.glav2 =
                new FinancialReportTransactionDetail.ActiveSource(
                    archivedTrans.GL_Account_Variable_2__c,
                    glavsMap.get(archivedTrans.GL_Account_Variable_2__c),
                    true
                );
            this.glav3 =
                new FinancialReportTransactionDetail.ActiveSource(
                    archivedTrans.GL_Account_Variable_3__c,
                    glavsMap.get(archivedTrans.GL_Account_Variable_3__c),
                    true
                );
            this.glav4 =
                new FinancialReportTransactionDetail.ActiveSource(
                    archivedTrans.GL_Account_Variable_4__c,
                    glavsMap.get(archivedTrans.GL_Account_Variable_4__c),
                    true
                );
            this.amount = archivedTrans.Amount__c;
        }

        public TransactionWrapper(Transaction__c trans, Set<String> populatedFields, Boolean isERPEnabled) {
            this.isERPEnabled = isERPEnabled;
            this.populatedFields = populatedFields;

            this.id = new FinancialReportTransactionDetail.ActiveSource(trans.Id, trans.Name, true);
            this.transactionDate = trans.Date__c.format();
            //We validate the availability of __c fields b/c __r fields may be not removed by Security.stripInaccessible method
            //For example:
            // populatedFields map does not contains
            // Account_Payable__c field
            // BUT contains
            // Account_Payable__r field
            this.accountingPeriod = new FinancialReportTransactionDetail.ActiveSource(
                trans.isSet(Transaction__c.Accounting_Period__c) ? trans.Accounting_Period__c : NULL,
                populatedFields.contains(PACKAGE_QUALIFIER + 'Accounting_Period__c') ? trans.Accounting_Period__r.Name : NULL,
                true
            );
            this.glAccount = new FinancialReportTransactionDetail.ActiveSource(
                trans.isSet(Transaction__c.GL_Account__c) ? trans.GL_Account__c : NULL,
                populatedFields.contains(PACKAGE_QUALIFIER + 'GL_Account__c') ? trans.GL_Account__r.Name : NULL,
                true
            );
            this.account = new FinancialReportTransactionDetail.ActiveSource(
                trans.isSet(Transaction__c.Account__c) ? trans.Account__c : NULL,
                populatedFields.contains(PACKAGE_QUALIFIER + 'Account__c') ? trans.Account__r.Name : NULL,
                true
            );
            this.source = new FinancialReportTransactionDetail.ActiveSource(
                getSourceId(trans),
                getSourceName(trans),
                true
            );
            this.project = new FinancialReportTransactionDetail.ActiveSource(
                trans.isSet(Transaction__c.Project__c) ? trans.Project__c : NULL,
                populatedFields.contains(PACKAGE_QUALIFIER + 'Project__c') ? trans.Project__r.Name : NULL,
                true
            );
            this.projectTask = new FinancialReportTransactionDetail.ActiveSource(
                trans.isSet(Transaction__c.Project_Task__c) ? trans.Project_Task__c : NULL,
                populatedFields.contains(PACKAGE_QUALIFIER + 'Project_Task__c') ? trans.Project_Task__r.Name : NULL,
                true
            );
            this.product = new FinancialReportTransactionDetail.ActiveSource(
                trans.isSet(Transaction__c.Product__c) ? trans.Product__c : NULL,
                populatedFields.contains(PACKAGE_QUALIFIER + 'Product__c') ? trans.Product__r.Name : NULL,
                true
            );
            this.glav1 =
                new FinancialReportTransactionDetail.ActiveSource(
                    trans.isSet(Transaction__c.GL_Account_Variable_1__c) ? trans.GL_Account_Variable_1__c : NULL,
                    populatedFields.contains(PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c') ? trans.GL_Account_Variable_1__r.Name : NULL,
                    true
                );
            this.glav2 =
                new FinancialReportTransactionDetail.ActiveSource(
                    trans.isSet(Transaction__c.GL_Account_Variable_2__c) ? trans.GL_Account_Variable_2__c : NULL,
                    populatedFields.contains(PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c') ? trans.GL_Account_Variable_2__r.Name : NULL,
                    true
                );
            this.glav3 =
                new FinancialReportTransactionDetail.ActiveSource(
                    trans.isSet(Transaction__c.GL_Account_Variable_3__c) ? trans.GL_Account_Variable_3__c : NULL,
                    populatedFields.contains(PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c') ? trans.GL_Account_Variable_3__r.Name : NULL,
                    true
                );
            this.glav4 =
                new FinancialReportTransactionDetail.ActiveSource(
                    trans.isSet(Transaction__c.GL_Account_Variable_4__c) ? trans.GL_Account_Variable_4__c : NULL,
                    populatedFields.contains(PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c') ? trans.GL_Account_Variable_4__r.Name : NULL,
                    true
                );
            this.amount = trans.isSet(Transaction__c.Amount__c) ? trans.Amount__c : 0;
        }

        private String getSourceName(Transaction__c trans) {
            String source;
            if (populatedFields.contains(PACKAGE_QUALIFIER + 'Account_Payable__c') && trans.Account_Payable__r != null) {
                source = trans.Account_Payable__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Account_Payable_Line__c') && trans.Account_Payable_Line__r != null) {
                source = trans.Account_Payable_Line__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'AP_Disbursement__c') && trans.AP_Disbursement__r != null) {
                source = trans.AP_Disbursement__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Billing__c') && trans.Billing__r != null) {
                source = trans.Billing__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Billing_Line__c') && trans.Billing_Line__r != null) {
                source = trans.Billing_Line__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__c') && trans.Billing_Cash_Receipt__r != null) {
                source = trans.Billing_Cash_Receipt__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Cash_Disbursement__c') && trans.Cash_Disbursement__r != null) {
                source = trans.Cash_Disbursement__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Cash_Receipt__c') && trans.Cash_Receipt__r != null) {
                source = trans.Cash_Receipt__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Journal_Entry_Line__c') && trans.Journal_Entry_Line__r != null) {
                source = trans.Journal_Entry_Line__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Time_Card_Day__c') && trans.Time_Card_Day__r != null) {
                source = trans.Time_Card_Day__r.Name;
            }
            else if (populatedFields.contains(PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c') && trans.Scheduled_Revenue_Expense__r != null) {
                source = trans.Scheduled_Revenue_Expense__r.Name;
            }
            else if (isERPEnabled
                        && populatedFields.contains(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c')
                        && trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__r') != NULL) {

                source = String.valueOf(trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__r').get('Name'));
            }
            else if (isERPEnabled
                        && populatedFields.contains(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c')
                        && trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__r') != NULL) {

                source = String.valueOf(trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__r').get('Name'));
            }
            else if (isERPEnabled
                        && populatedFields.contains(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c')
                        && trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__r') != NULL) {

                source = String.valueOf(trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__r').get('Name'));
            }
            else if (isERPEnabled
                        && populatedFields.contains(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c')
                        && trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__r') != NULL) {

                source = String.valueOf(trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__r').get('Name'));
            }
            else if (isERPEnabled
                && populatedFields.contains(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c')
                && trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__r') != NULL) {

                source = String.valueOf(trans.getSObject(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__r').get('Name'));
            }
            return source;
        }

        private String getSourceId(Transaction__c trans) {
            String source;

            if (trans.isSet(Transaction__c.Account_Payable__c) && trans.Account_Payable__c != null) {
                source = trans.Account_Payable__c;
            }
            else if (trans.isSet(Transaction__c.Account_Payable_Line__c) && trans.Account_Payable_Line__c != null) {
                source = trans.Account_Payable_Line__c;
            }
            else if (trans.isSet(Transaction__c.AP_Disbursement__c) && trans.AP_Disbursement__c != null) {
                source = trans.AP_Disbursement__c;
            }
            else if (trans.isSet(Transaction__c.Billing__c) && trans.Billing__c != null) {
                source = trans.Billing__c;
            }
            else if (trans.isSet(Transaction__c.Billing_Line__c) && trans.Billing_Line__c != null) {
                source = trans.Billing_Line__c;
            }
            else if (trans.isSet(Transaction__c.Billing_Cash_Receipt__c) && trans.Billing_Cash_Receipt__c != null) {
                source = trans.Billing_Cash_Receipt__c;
            }
            else if (trans.isSet(Transaction__c.Cash_Disbursement__c) && trans.Cash_Disbursement__c != null) {
                source = trans.Cash_Disbursement__c;
            }
            else if (trans.isSet(Transaction__c.Cash_Receipt__c) && trans.Cash_Receipt__c != null) {
                source = trans.Cash_Receipt__c;
            }
            else if (trans.isSet(Transaction__c.Journal_Entry_Line__c) && trans.Journal_Entry_Line__c != null) {
                source = trans.Journal_Entry_Line__c;
            }
            else if (trans.isSet(Transaction__c.Time_Card_Day__c) && trans.Time_Card_Day__c != null) {
                source = trans.Time_Card_Day__c;
            }
            else if (trans.isSet(Transaction__c.Scheduled_Revenue_Expense__c) && trans.Scheduled_Revenue_Expense__c != null) {
                source = trans.Scheduled_Revenue_Expense__c;
            }
            else if (isERPEnabled
                        && trans.isSet(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c')
                        && trans.get(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c') != NULL) {

                source = String.valueOf(trans.get(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c'));
            }
            else if (isERPEnabled
                        && trans.isSet(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c')
                        && trans.get(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c') != NULL) {

                source = String.valueOf(trans.get(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c'));
            }
            else if (isERPEnabled
                        && trans.isSet(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c')
                        && trans.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c') != NULL) {

                source = String.valueOf(trans.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c'));
            }
            else if (isERPEnabled
                        && trans.isSet(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c')
                        && trans.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c') != NULL) {

                source = String.valueOf(trans.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c'));
            }
            else if (isERPEnabled
                        && trans.isSet(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c')
                        && trans.get(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c') != NULL) {

                source = String.valueOf(trans.get(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c'));
            }
            return source;
        }

        private String getSourceIdForArchived(Transaction_Archive__b archivedTrans) {
            String source;

            if (archivedTrans.Payable__c != NULL) {
                source = archivedTrans.Payable__c;
            }
            else if (archivedTrans.Payable_Line__c != NULL) {
                source = archivedTrans.Payable_Line__c;
            }
            else if (archivedTrans.AP_Disbursement__c != NULL) {
                source = archivedTrans.AP_Disbursement__c;
            }
            else if (archivedTrans.Billing__c != NULL) {
                source = archivedTrans.Billing__c;
            }
            else if (archivedTrans.Billing_Line__c != NULL) {
                source = archivedTrans.Billing_Line__c;
            }
            else if (archivedTrans.Billing_Cash_Receipt__c != NULL) {
                source = archivedTrans.Billing_Cash_Receipt__c;
            }
            else if (archivedTrans.Cash_Disbursement__c != NULL) {
                source = archivedTrans.Cash_Disbursement__c;
            }
            else if (archivedTrans.Cash_Receipt__c != NULL) {
                source = archivedTrans.Cash_Receipt__c;
            }
            else if (archivedTrans.Journal_Entry_Line__c != NULL) {
                source = archivedTrans.Journal_Entry_Line__c;
            }
            else if (archivedTrans.Time_Card_Day__c != NULL) {
                source = archivedTrans.Time_Card_Day__c;
            }
            else if (archivedTrans.Amortization_Entry__c != NULL) {
                source = archivedTrans.Amortization_Entry__c;
            }
            else if (isERPEnabled && archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c') != NULL) {
                source = String.valueOf(archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c'));
            }
            else if (isERPEnabled && archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c') != NULL) {
                source = String.valueOf(archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c'));
            }
            else if (isERPEnabled && archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c') != NULL) {
                source = String.valueOf(archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c'));
            }
            else if (isERPEnabled && archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c') != NULL) {
                source = String.valueOf(archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c'));
            }
            else if (isERPEnabled && archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c') != NULL) {
                source = String.valueOf(archivedTrans.get(ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c'));
            }
            return source;
        }

    }

}