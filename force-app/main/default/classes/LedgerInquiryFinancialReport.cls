public with sharing class LedgerInquiryFinancialReport extends AbstractLWCHelper {

    private static final Integer LEDGER_ACCOUNT_INQUIRY_REPORT_LINE_LIMIT = 5000;
    public static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    @TestVisible
    private static final String NO_POSTED_RECORDS = Label.ERR_NO_POSTED_RECORDS;

    public static LedgerInquiryResponse runReport(FinancialReportOptions aReportOptions) {
        LedgerInquiryFinancialReportOptions reportOptions = (LedgerInquiryFinancialReportOptions) aReportOptions;
        LedgerInquiryResponse ledgerInquiryResponse = new LedgerInquiryResponse();
        
        FinancialReporter ledgerInquiryFinancialReporter = new FinancialReporter(aReportOptions);
        ServiceResult validationServiceResult = ledgerInquiryFinancialReporter.validateLedgerInquiryReportOptions();
        if (validationServiceResult.isSuccess) {
            ledgerInquiryResponse = queryTransactionsByLedgerInquiryRequest(reportOptions);
        }
        ledgerInquiryResponse.saveResponse = new AbstractLWCHelper.SaveResponse(validationServiceResult);

        if (validationServiceResult.isSuccess && ledgerInquiryResponse.lines.isEmpty()) {
            ledgerInquiryResponse.saveResponse.isSuccess = false;
            ledgerInquiryResponse.saveResponse.errors.add(new ResponseError(new ServiceResult.Error(NO_POSTED_RECORDS)));
        }

        return ledgerInquiryResponse;
    }

    public static LedgerInquiryResponse queryTransactionsByLedgerInquiryRequest(LedgerInquiryFinancialReportOptions reportOptions) {
        SaveResponse saveResponse = new SaveResponse();
        LedgerInquiryResponse result;
        try {
            List<Accounting_Period__c> accountingPeriods =
                AccountingPeriodHandler.getInstance().getAccountingPeriodsFromRange(
                    (Id) reportOptions.startingAccountingPeriod, (Id) reportOptions.endingAccountingPeriod
                );

            Accounting_Period__c firstPeriodInRange =
                AccountingPeriodHandler.getInstance().getAccountingPeriodById((Id)reportOptions.startingAccountingPeriod);
            Accounting_Period__c lastPeriodInRange =
                AccountingPeriodHandler.getInstance().getAccountingPeriodById((Id)reportOptions.endingAccountingPeriod);

            Set<Id> accountingPeriodIds = new Set<Id>{(Id) reportOptions.startingAccountingPeriod, (Id) reportOptions.endingAccountingPeriod};

            List<FinancialReportTransactionDetail.TransactionWrapper> wrappedTransactions =
                new List<FinancialReportTransactionDetail.TransactionWrapper>();

            Decimal reportAmount = 0;
            Set<String> populatedFields;
            Boolean isERPEnabled = AccountingSettingsHandler.isERPEnabled();
            //Init SObjectAccessDecision provider
            SOQLBuilder accessValidator = new SOQLBuilder(Transaction__c.SObjectType);
            //Set Access Level
            accessValidator.setStripInaccessible(AccessType.READABLE);
            //Loop through all Transactions queried by given conditions
            //We use SOQL-for-Loop approach to avoid the limit on heap size
            for (List<Transaction__c> transactionsBatch : Database.query(getTransactions(reportOptions, accountingPeriods))) {
                //Validate CRUD & FLS access for each batch of Transaction records (size is up to 200) and strip inaccessible fields
                for (Transaction__c trans : (List<Transaction__c>) accessValidator.getAccessDecisionResult(transactionsBatch)) {
                    //Get Populated Fields as Map only once to reduce Apex CPU time usage
                    if (populatedFields == null) {
                        populatedFields = trans.getPopulatedFieldsAsMap().keySet();
                    }
                    //Wrap each Transaction record
                    wrappedTransactions.add(new FinancialReportTransactionDetail.TransactionWrapper(trans, populatedFields, isERPEnabled));
                    //Aggregate total amount for the whole report
                    reportAmount += (trans.isSet(Transaction__c.Amount__c) ? trans.Amount__c : 0);
                }
            }

            //only allowed maximum of wrapped transactions will be send to UI
            Boolean isMoreThenLimit = false;
            if (wrappedTransactions.size() > LEDGER_ACCOUNT_INQUIRY_REPORT_LINE_LIMIT) {
                isMoreThenLimit = true;
                wrappedTransactions.remove(wrappedTransactions.size() - 1);//remove last element from the list
            }

            BalanceBuilder balBuilder = initializeBalanceBuilder(reportOptions.ledger, accountingPeriodIds, reportOptions.glAccount);
            Decimal openingBalance = 0;
            Decimal currentBalance = 0;
            openingBalance = calculateOpeningBalance(
                balBuilder,
                firstPeriodInRange.Name,
                reportOptions.ledger,
                reportOptions.glAccount,
                reportOptions.glVariable1,
                reportOptions.glVariable2,
                reportOptions.glVariable3,
                reportOptions.glVariable4
            );

            currentBalance = calculateYTDBalance(
                balBuilder,
                lastPeriodInRange.Name,
                reportOptions.ledger,
                reportOptions.glAccount,
                reportOptions.glVariable1,
                reportOptions.glVariable2,
                reportOptions.glVariable3,
                reportOptions.glVariable4
            );

            result = new LedgerInquiryResponse(wrappedTransactions, openingBalance, currentBalance, reportAmount, isMoreThenLimit);
            saveResponse.isSuccess = true;
            result.saveResponse = saveResponse;
            result.ledgerCurrency =
                (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED)
                    ? getLedgerCurrency(reportOptions.ledger)
                    : AbstractLWCHelper.CORPORATE_CURRENCY;
            result.hideCurrentBalance = hideCurrentBalance(reportOptions);
            result.hideOpeningBalance = hideOpeningBalance(reportOptions);

            if (reportOptions.aggregatedBy != 'none' && !result.lines.isEmpty()) {
                result = applyAggregateBy(result, reportOptions);
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    private static String getTransactions(LedgerInquiryFinancialReportOptions reportOptions, List<Accounting_Period__c> accountingPeriods) {
        //build SOQL query to get transaction records
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
            'Account_Payable__c',
            'Account_Payable__r.Name',
            'Account_Payable_Line__c',
            'Account_Payable_Line__r.Name',
            'AP_Disbursement__c',
            'AP_Disbursement__r.Name',
            'Billing__c',
            'Billing__r.Name',
            'Billing_Line__c',
            'Billing_Line__r.Name',
            'Billing_Cash_Receipt__c',
            'Billing_Cash_Receipt__r.Name',
            'Cash_Disbursement__c',
            'Cash_Disbursement__r.Name',
            'Cash_Receipt__c',
            'Cash_Receipt__r.Name',
            'Journal_Entry_Line__c',
            'Journal_Entry_Line__r.Name',
            'Time_Card_Day__c',
            'Time_Card_Day__r.Name',
            'Scheduled_Revenue_Expense__c',
            'Scheduled_Revenue_Expense__r.Name'
        };

        if (AccountingSettingsHandler.isERPEnabled()) {
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

        List<String> periodCondition = new List<String>();
        for (Accounting_Period__c ap : accountingPeriods) {
            periodCondition.add('\'' + ap.Id + '\'');
        }

        String queryCondition =
            'Accounting_Period__c IN (' + String.join(periodCondition, ',') + ') ' +
                (!String.isBlank(reportOptions.glAccount)
                    ? 'AND GL_Account__c = \'' + String.escapeSingleQuotes(reportOptions.glAccount) + '\' ' : '') +
                (!String.isBlank(reportOptions.glVariable1)
                    ? 'AND GL_Account_Variable_1__c = \'' + String.escapeSingleQuotes(reportOptions.glVariable1) + '\' ' : '') +
                (!String.isBlank(reportOptions.glVariable2)
                    ? 'AND GL_Account_Variable_2__c = \'' + String.escapeSingleQuotes(reportOptions.glVariable2) + '\' ' : '') +
                (!String.isBlank(reportOptions.glVariable3)
                    ? 'AND GL_Account_Variable_3__c = \'' + String.escapeSingleQuotes(reportOptions.glVariable3) + '\' ' : '') +
                (!String.isBlank(reportOptions.glVariable4)
                    ? 'AND GL_Account_Variable_4__c = \'' + String.escapeSingleQuotes(reportOptions.glVariable4) + '\' ' : '') +
                (!String.isBlank(reportOptions.project)
                    ? 'AND Project__c = \'' + String.escapeSingleQuotes(reportOptions.project) + '\' ' : '') +
                (!String.isBlank(reportOptions.projectTask)
                    ? 'AND Project_Task__c = \'' + String.escapeSingleQuotes(reportOptions.projectTask) + '\' ' : '') +
                (!String.isBlank(reportOptions.product)
                    ? 'AND Product__c = \'' + String.escapeSingleQuotes(reportOptions.product) + '\' ' : '') +
                (!String.isBlank(reportOptions.account)
                    ? 'AND Account__c = \'' + String.escapeSingleQuotes(reportOptions.account) + '\' ' : '') +
                (LedgerHandler.isLedgerEqualLegacyLedger(reportOptions.ledger)
                    ? 'AND (Ledger__c = \'' + String.escapeSingleQuotes(reportOptions.ledger) + '\' OR Ledger__c = NULL)'
                    : 'AND Ledger__c = \'' + String.escapeSingleQuotes(reportOptions.ledger) + '\'');

        queryCondition += getSourceCondition(reportOptions);

        SOQLBuilder.Ordering ordering =
            new SOQLBuilder.Ordering('Transaction__c', 'Date__c', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
        theQuery
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering)
            .setLimit(LEDGER_ACCOUNT_INQUIRY_REPORT_LINE_LIMIT + 1);

        return theQuery.toSOQL();
    }

    private static String getSourceCondition(LedgerInquiryFinancialReportOptions reportOptions) {
        Boolean isERPEnabled = AccountingSettingsHandler.isERPEnabled();
        String queryCondition = ' AND (';

        if (reportOptions.source.contains('amortizationEntry') || reportOptions.source.contains('all')) {
            queryCondition += ' Scheduled_Revenue_Expense__c != NULL OR';
        }
        if (reportOptions.source.contains('apd') || reportOptions.source.contains('all')) {
            queryCondition += ' AP_Disbursement__c != NULL OR';
        }
        if (reportOptions.source.contains('billing') || reportOptions.source.contains('all')) {
            queryCondition += ' Billing__c != NULL OR';
        }
        if (reportOptions.source.contains('billingLine') || reportOptions.source.contains('all')) {
            queryCondition += ' Billing_Line__c != NULL OR';
        }
        if (reportOptions.source.contains('bcr') || reportOptions.source.contains('all')) {
            queryCondition += ' Billing_Cash_Receipt__c != NULL OR';
        }
        if (reportOptions.source.contains('cd') || reportOptions.source.contains('all')) {
            queryCondition += ' Cash_Disbursement__c != NULL OR';
        }
        if (reportOptions.source.contains('cr') || reportOptions.source.contains('all')) {
            queryCondition += ' Cash_Receipt__c != NULL OR';
        }
        if (reportOptions.source.contains('jel') || reportOptions.source.contains('all')) {
            queryCondition += ' Journal_Entry_Line__c != NULL OR';
        }
        if (reportOptions.source.contains('payable') || reportOptions.source.contains('all')) {
            queryCondition += ' Account_Payable__c != NULL OR';
        }
        if (reportOptions.source.contains('payableLine') || reportOptions.source.contains('all')) {
            queryCondition += ' Account_Payable_Line__c != NULL OR';
        }
        if (reportOptions.source.contains('timeCardDay') || reportOptions.source.contains('all')) {
            queryCondition += ' Time_Card_Day__c != NULL OR';
        }
        if (reportOptions.source.contains('iim') || (isERPEnabled && reportOptions.source.contains('all'))) {
            queryCondition += ' ' + ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c != NULL OR';
        }
        if (reportOptions.source.contains('mim') || (isERPEnabled && reportOptions.source.contains('all'))) {
            queryCondition += ' ' + ERP_PACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c != NULL OR';
        }
        if (reportOptions.source.contains('oim') || (isERPEnabled && reportOptions.source.contains('all'))) {
            queryCondition += ' ' + ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c != NULL OR';
        }
        if (reportOptions.source.contains('poim') || (isERPEnabled && reportOptions.source.contains('all'))) {
            queryCondition += ' ' + ERP_PACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c != NULL OR';
        }
        if (reportOptions.source.contains('soim') || (isERPEnabled && reportOptions.source.contains('all'))) {
            queryCondition += ' ' + ERP_PACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c != NULL OR';
        }

        queryCondition = queryCondition.endsWith('OR') ? queryCondition.removeEnd('OR') : queryCondition;
        queryCondition += ')';

        return reportOptions.source.isEmpty() ? '' : queryCondition;
    }

    //TODO: investigate the reason to have separate methods for hide/show Opening Balance and YTD Balance (current)
    //Maybe it will be enough to have only one common method for it and only one LWC property as well
    private static Boolean hideOpeningBalance(LedgerInquiryFinancialReportOptions reportOptions) {
        return hideCurrentBalance(reportOptions);
    }

    private static Boolean hideCurrentBalance(LedgerInquiryFinancialReportOptions reportOptions) {
        return reportOptions.glAccount == NULL || isFiltered(reportOptions);
    }

    private static Boolean isFiltered(LedgerInquiryFinancialReportOptions reportOptions) {
        return reportOptions.project != NULL
            || reportOptions.projectTask != NULL
            || reportOptions.account != NULL
            || reportOptions.product != NULL;
    }

    private static String getLedgerCurrency(Id ledgerId) {
        return LedgerHandler.getLedgerCurrency(ledgerId);
    }

    private static BalanceBuilder initializeBalanceBuilder(String ledgerId, Set<Id> periodIds, String glAccountId) {
        BalanceBuilder result = new BalanceBuilder(true);
        Set<Id> glAccountIds = new Set<Id>{(Id) glAccountId};
        Set<Id> ledgerIds = (LedgerHandler.isLedgerEqualLegacyLedger(ledgerId))
                                ? new Set<Id>{(Id) ledgerId, NULL}
                                : new Set<Id>{(Id) ledgerId};

        for (Financial_Cube__c fCube : DomainUtils.getFinancialCubesForReporting(periodIds, glAccountIds, ledgerIds)) {
            result.addCube(fCube);
        }

        return result;
    }

    private static Decimal calculateYTDBalance( BalanceBuilder builder,
                                                String periodName,
                                                String ledgerId,
                                                String glAccountId,
                                                String av1,
                                                String av2,
                                                String av3,
                                                String av4) {

        Decimal result = 0;
        result =  builder.getYTDBalance(periodName, ledgerId, glAccountId, av1, av2, av3, av4);
        return result;
    }

    private static Decimal calculateOpeningBalance( BalanceBuilder builder,
                                                    String periodName,
                                                    String ledgerId,
                                                    String glAccountId,
                                                    String av1,
                                                    String av2,
                                                    String av3,
                                                    String av4) {

        Decimal result = 0;
        result =  builder.getOpeningBalance(periodName, ledgerId, glAccountId, av1, av2, av3, av4);
        return result;
    }

    public with sharing class LedgerInquiryResponse {
        @AuraEnabled
        public Decimal openingBalance {get; set;}
        @AuraEnabled
        public Decimal currentBalance {get; set;}
        @AuraEnabled
        public Decimal reportAmount {get; set;}
        @AuraEnabled
        public Integer recordCount {get; set;}
        @AuraEnabled
        public Boolean limitedOutput {get; set;}
        @AuraEnabled
        public String ledgerCurrency {get; set;}
        @AuraEnabled
        public Boolean hideOpeningBalance {get; set;}
        @AuraEnabled
        public Boolean hideCurrentBalance {get; set;}
        @AuraEnabled
        public AbstractLWCHelper.SaveResponse saveResponse  {get;set;}
        @AuraEnabled
        public List<FinancialReportTransactionDetail.TransactionWrapper> lines {get; set;}

        public LedgerInquiryResponse() {
            this.hideOpeningBalance = false;
            this.hideCurrentBalance = false;
        }

        public LedgerInquiryResponse(   List<FinancialReportTransactionDetail.TransactionWrapper> recs,
                                        Decimal openingBalance,
                                        Decimal currentBalance,
                                        Decimal reportAmount,
                                        Boolean limitedOutput) {

            this.lines = recs;
            this.openingBalance = openingBalance;
            this.currentBalance = currentBalance;
            this.recordCount = recs.size();
            this.reportAmount = reportAmount;
            this.limitedOutput = limitedOutput;
            this.hideOpeningBalance = false;
            this.hideCurrentBalance = false;
        }
    }

    // ====================== Aggregate By functions ==============================

    private static LedgerInquiryResponse applyAggregateBy(LedgerInquiryResponse response, LedgerInquiryFinancialReportOptions reportOptions) {
        Map<Id, Decimal> recordAmountById = new Map<Id, Decimal>();
        Map<Id, FinancialReportTransactionDetail.ActiveSource> recordAmountByName = new Map<Id, FinancialReportTransactionDetail.ActiveSource>();

        for (FinancialReportTransactionDetail.TransactionWrapper line : response.lines) {
            switch on reportOptions.aggregatedBy {
                when 'accounts' {
                    calculateAggregatedAmount(line.account, recordAmountById, recordAmountByName, line.amount);
                }
                when 'period' {
                    calculateAggregatedAmount(line.accountingPeriod, recordAmountById, recordAmountByName, line.amount);
                }
                when 'product' {
                    calculateAggregatedAmount(line.product, recordAmountById, recordAmountByName, line.amount);
                }
                when 'project' {
                    calculateAggregatedAmount(line.project, recordAmountById, recordAmountByName, line.amount);
                }
                when 'projectTask' {
                    calculateAggregatedAmount(line.projectTask, recordAmountById, recordAmountByName, line.amount);
                }
                when 'source' {
                    calculateAggregatedAmount(line.source, recordAmountById, recordAmountByName, line.amount);
                }
                when 'glAccount' {
                    calculateAggregatedAmount(line.glAccount, recordAmountById, recordAmountByName, line.amount);
                }
                when 'glav1' {
                    calculateAggregatedAmount(line.glav1, recordAmountById, recordAmountByName, line.amount);
                }
                when 'glav2' {
                    calculateAggregatedAmount(line.glav2, recordAmountById, recordAmountByName, line.amount);
                }
                when 'glav3' {
                    calculateAggregatedAmount(line.glav3, recordAmountById, recordAmountByName, line.amount);
                }
                when 'glav4' {
                    calculateAggregatedAmount(line.glav4, recordAmountById, recordAmountByName, line.amount);
                }
            }
        }
        response.lines = getResultLines(recordAmountById, reportOptions.aggregatedBy, recordAmountByName);

        return response;
    }

    private static void calculateAggregatedAmount(
        FinancialReportTransactionDetail.ActiveSource source,
        Map<Id, Decimal> recordAmountById,
        Map<Id, FinancialReportTransactionDetail.ActiveSource> recordAmountByName,
        Decimal amount) {

        if (String.isNotBlank(source.id) && recordAmountById.keySet().contains(source.id)) {
            recordAmountById.put(source.id, recordAmountById.get(source.id) + amount);
        }
        else if (String.isNotBlank(source.id) && !recordAmountById.keySet().contains(source.id)) {
            recordAmountById.put(source.id, amount);
            recordAmountByName.put(source.id, source);
        }
    }

    private static List<FinancialReportTransactionDetail.TransactionWrapper> getResultLines(
        Map<Id, Decimal> recordAmountById,
        String source,
        Map<Id, FinancialReportTransactionDetail.ActiveSource> recordAmountByName) {

        List<FinancialReportTransactionDetail.TransactionWrapper> result = new List<FinancialReportTransactionDetail.TransactionWrapper>();

        for (Id lineId : recordAmountById.keySet()) {
            FinancialReportTransactionDetail.TransactionWrapper newLine = new FinancialReportTransactionDetail.TransactionWrapper();
            FinancialReportTransactionDetail.ActiveSource newActSource = new FinancialReportTransactionDetail.ActiveSource(
                lineId,
                recordAmountByName.get(lineId).name,
                NULL
            );

            switch on source {
                when 'accounts' {
                    newLine.account = newActSource;
                }
                when 'period' {
                    newLine.accountingPeriod = newActSource;
                }
                when 'product' {
                    newLine.product = newActSource;
                }
                when 'project' {
                    newLine.project = newActSource;
                }
                when 'projectTask' {
                    newLine.projectTask = newActSource;
                }
                when 'source' {
                    newLine.source = newActSource;
                }
                when 'glAccount' {
                    newLine.glAccount = newActSource;
                }
                when 'glav1' {
                    newLine.glav1 = newActSource;
                }
                when 'glav2' {
                    newLine.glav2 = newActSource;
                }
                when 'glav3' {
                    newLine.glav3 = newActSource;
                }
                when 'glav4' {
                    newLine.glav4 = newActSource;
                }
            }
            newLine.amount = recordAmountById.get(lineId);
            result.add(newLine);
        }

        return result;
    }

}