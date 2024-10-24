@IsTest
public with sharing class FinancialReporterHelperTest {

    private static List<Accounting_Period__c> createCurrentPeriods() {
        //Close all existed periods
        List<Accounting_Period__c> oldPeriods = AccountingPeriodHandler.getInstance().getAllAccountingPeriods();
        AccountingPeriodActions.isFirstRun = false;
        for (Accounting_Period__c ap : oldPeriods) {
            ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
        }
        update oldPeriods;
        AccountingPeriodActions.isFirstRun = true;
        //Create new periods [-+ 12 months of today]
        List<Accounting_Period__c> periods = new List<Accounting_Period__c>();
        Date start = Date.today().addMonths(-12);

        for (Integer i = 0; i < 24; i++) {
            Date next = start.addMonths(i).toStartOfMonth();
            String m = String.valueOf(next.month());
            if (m.length() < 2) {
                m = '0' + m;
            }
            periods.add(
                new Accounting_Period__c(
                    Name = next.year() + '-' + m,
                    Start_Date__c = next.toStartOfMonth(),
                    End_Date__c = next.addMonths(1).toStartOfMonth().addDays(-1),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            );
        }

        return periods;
    }

    @IsTest
    private static void testFetchRateTableCurrencies() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Map<String, Object>> result = FinancialReporterHelper.fetchRateTableCurrencies();
            Test.stopTest();

            System.assert(!result.isEmpty());
        }
    }

    @IsTest
    private static void testGetProfitLossDefaultsLedger() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ProfitAndLossFinancialReportOptions opts = FinancialReporterHelper.getProfitLossDefaults();
            Test.stopTest();

            Id expectedLedger = testData.ledgers[0].Id;
            System.assertEquals(expectedLedger, opts.ledger);
        }
    }

    @IsTest
    private static void testGetProfitLossDefaultsPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c[] periods = createCurrentPeriods(); 
            insert periods;

            Test.startTest();
            ProfitAndLossFinancialReportOptions opts = FinancialReporterHelper.getProfitLossDefaults();
            Test.stopTest();

            System.assertEquals(periods[1].Id, opts.startingAccountingPeriod);
            System.assertEquals(periods[12].Id, opts.endingAccountingPeriod);
        }
    }

    @IsTest
    private static void testGetFinancialReportResults() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            testData.financialReportResults[0].Report_Type__c = 'Profit & Loss';
            update testData.financialReportResults[0];

            List<Financial_Report_Result__c> opts = FinancialReporterHelper.getFinancialReportResults('profitLoss');
            System.assertEquals(1, opts.size());
        }
    }

    @IsTest
    private static void testDeleteFinancialReportResults() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            testData.financialReportResults[0].Report_Type__c = 'Profit & Loss';
            update testData.financialReportResults[0];

            FinancialReporterHelper.deleteFinancialReportResults(new List<Id> {testData.financialReportResults[0].Id});

            List<Financial_Report_Result__c> opts = FinancialReporterHelper.getFinancialReportResults('profitLoss');
            System.assertEquals(0, opts.size());
        }
    }

    @IsTest
    private static void testGetTrialBalanceDefaultPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();

            TrialBalanceFinancialReportOptions opts = FinancialReporterHelper.getTrialBalanceDefaults();
            System.assertEquals(testData.acctPeriods[1].Id, opts.startingAccountingPeriod);
        }
    }

    @IsTest
    private static void testGetBalanceSheetDefaultsLedger() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BalanceSheetFinancialReportOptions opts = FinancialReporterHelper.getBalanceSheetDefaults();
            Test.stopTest();

            Id expectedLedger = testData.ledgers[0].Id;
            System.assertEquals(expectedLedger, opts.ledger);
        }
    }

    @IsTest
    private static void testGetBalanceSheetDefaultsPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();

            BalanceSheetFinancialReportOptions opts = FinancialReporterHelper.getBalanceSheetDefaults();
            
            System.assertEquals(testData.acctPeriods[0].Id, opts.startingAccountingPeriod);
            System.assertEquals(testData.acctPeriods[1].Id, opts.endingAccountingPeriod);
        }
    }

    @IsTest
    private static void testGetCustomReportDefaultsPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings(true);
        testData.createReportDefinitions();
        

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();
            Financial_Report_Definition__c repDef = [select id, name from Financial_Report_Definition__c limit 1];
            CustomFinancialReportOptions options = new CustomFinancialReportOptions(repDef.id);
            System.assertEquals(testData.acctPeriods[0].Id, options.startingAccountingPeriod);
        }
    }

    @IsTest
    private static void testGetLedgerInquiryDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            List<Accounting_Period__c> periods = createCurrentPeriods();
            insert periods;

            Test.startTest();
            AccountingPeriodHandler apHandler = AccountingPeriodHandler.getInstance();
            Accounting_Period__c currentPeriod = apHandler.getAccountingPeriodByDate(Date.today());
            List<Accounting_Period__c> periodsToClose = new List<Accounting_Period__c>();
            periodsToClose.add(apHandler.getAccountingPeriodByOffset(currentPeriod.Id, -12));
            periodsToClose.add(apHandler.getAccountingPeriodByOffset(currentPeriod.Id, -11));
            periodsToClose.add(apHandler.getAccountingPeriodByOffset(currentPeriod.Id, -10));
            periodsToClose.add(apHandler.getAccountingPeriodByOffset(currentPeriod.Id, -9));
            periodsToClose.add(apHandler.getAccountingPeriodByOffset(currentPeriod.Id, -8));

            AccountingPeriodActions.isFirstRun = false;
            for (Accounting_Period__c ap : periodsToClose) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update periodsToClose;
            AccountingPeriodActions.isFirstRun = true;
            Test.stopTest();

            apHandler = AccountingPeriodHandler.getInstance();
            LedgerInquiryFinancialReportOptions reportOptions = FinancialReporterHelper.getLedgerInquiryDefaults();
            //First open period
            System.assertEquals(
                reportOptions.endingAccountingPeriod,
                apHandler.getAccountingPeriodByOffset(currentPeriod.Id, -7).Id
            );
            //-11 periods from current
            System.assertEquals(
                reportOptions.startingAccountingPeriod,
                apHandler.getAccountingPeriodByOffset(reportOptions.endingAccountingPeriod, -11).Id
            );
        }
    }

    @IsTest
    private static void testRunProfitLossSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ProfitAndLossFinancialReportOptions opts = FinancialReporterHelper.getProfitLossDefaults();
            opts.startingAccountingPeriod = testData.acctPeriods[0].Id;
            opts.endingAccountingPeriod = testData.acctPeriods[3].Id;
            AbstractLWCHelper.SaveResponse result = FinancialReporterHelper.runProfitLoss(JSON.serialize(opts));

            System.assert(result.isSuccess);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testRunProfitLossBudgetSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ProfitAndLossVsBudgetFinReptOptions opts = FinancialReporterHelper.getProfitLossVsBudgetDefaults();
            opts.startingAccountingPeriod = testData.acctPeriods[0].Id;
            opts.endingAccountingPeriod = testData.acctPeriods[3].Id;
            AbstractLWCHelper.SaveResponse result = FinancialReporterHelper.runProfitLossVsBudget(JSON.serialize(opts));

            System.assert(result.isSuccess);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testRunBalanceSheetSuccess() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings(true);

        System.runAs(testData.users.get(1)) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();
            BalanceSheetFinancialReportOptions opts = FinancialReporterHelper.getBalanceSheetDefaults();
            opts.startingAccountingPeriod = testData.acctPeriods[0].Id;
            opts.endingAccountingPeriod = testData.acctPeriods[0].Id;
            AbstractLWCHelper.SaveResponse result = FinancialReporterHelper.runBalanceSheet(JSON.serialize(opts));

            System.assert(result.isSuccess);
        }
    }

    @IsTest
    private static void testRunTrialBalanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings(true);

        System.runAs(testData.users.get(1)) {
            TrialBalanceFinancialReportOptions opts = FinancialReporterHelper.getTrialBalanceDefaults();
            opts.startingAccountingPeriod = testData.acctPeriods[0].Id;
            opts.endingAccountingPeriod = testData.acctPeriods[0].Id;
            AbstractLWCHelper.SaveResponse result = FinancialReporterHelper.runTrialBalance(JSON.serialize(opts));

            System.assert(result.isSuccess);
        }
    }

    @IsTest
    private static void testRunCashFlowSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CashFlowFinancialReportOptions opts = FinancialReporterHelper.getCashFlowDefaults();
            opts.startingAccountingPeriod = testData.acctPeriods[0].Id;
            opts.endingAccountingPeriod = testData.acctPeriods[0].Id;
            AbstractLWCHelper.SaveResponse result = FinancialReporterHelper.runCashFlow(JSON.serialize(opts));

            System.assert(result.isSuccess);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testRunCustomReportSuccess() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance(true).createBillings(true);
        testData.createReportDefinitions();

        System.runAs(testData.users.get(1)) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();
            Financial_Report_Definition__c repDef = [select id, name from Financial_Report_Definition__c limit 1];
            CustomFinancialReportOptions options = new CustomFinancialReportOptions(repDef.id);
            AbstractLWCHelper.SaveResponse result = FinancialReporterHelper.runCustomReport(JSON.serialize(options));

            System.assert(result.isSuccess);
        }
    }

}