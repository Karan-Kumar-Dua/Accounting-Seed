@IsTest
private class FinancialReporterTest {

    @TestSetup
    private static void testDataSetup() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        AccountingPeriodHandler.reset();

        System.runAs(testData.users.get(1)) {
            //Create source documents
            testData.createBillings();

            Test.startTest();
            AccountingPeriodActions.isFirstRun = false;
            for (Accounting_Period__c ap : testData.acctPeriods) {
                ap.Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            }
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            System.assertEquals(7, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.ARCHIVED_STATUS]);

            Date acctDate = Date.newInstance(System.today().year(), System.today().month() - 3, 1);
            List<Accounting_Period__c> newPeriods = new List<Accounting_Period__c>();

            for (Integer i = 0; i < 8; i++) {
                newPeriods.add(
                    new Accounting_Period__c(
                        Name =
                            String.valueOf(acctDate.year()) +
                                '-' +
                                (acctDate.month() > 9
                                    ? String.valueOf(acctDate.month())
                                    : '0' + String.valueOf(acctDate.month())),
                        Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                        End_Date__c = Date.newInstance(
                            acctDate.year(),
                            acctDate.month(),
                            Date.daysInMonth(acctDate.year(), acctDate.month())
                        ),
                        Status__c = AccountingPeriodActions.OPEN_STATUS
                    )
                );

                if (acctDate.month() == 12) {
                    acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
                }
                else {
                    acctDate = acctDate.addMonths(1);
                }
            }
            insert newPeriods;

            System.assertEquals(8, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS LIMIT 100]);

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            List<Accounting_Period__c> closedPeriods = new List<Accounting_Period__c>{
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -3),
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -2),
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -1)
            };

            AccountingPeriodActions.isFirstRun = false;
            for (Accounting_Period__c ap : closedPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update closedPeriods;
            AccountingPeriodActions.isFirstRun = true;

            System.assertEquals(3, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.CLOSED_STATUS LIMIT 100]);
            System.assertEquals(5, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS LIMIT 100]);
        }
    }

    @IsTest
    private static void testDeleteReportsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            System.assert(!testData.financialReportResults.isEmpty());
            Set<Id> toDelete = new Map<Id,Financial_Report_Result__c>(testData.financialReportResults).keySet();

            Test.startTest();
            ServiceResult result = FinancialReporter.deleteReports(toDelete);
            Test.stopTest();

            System.assert(result.isSuccess);
            List<Financial_Report_Result__c> existingFRRs = new List<Financial_Report_Result__c>();
            existingFRRs = [SELECT Id FROM Financial_Report_Result__c WHERE Id IN :toDelete];
            System.assert(existingFRRs.isEmpty());
        }
    }

    @IsTest
    private static void testDeleteReportsNoInput() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            System.assert(!testData.financialReportResults.isEmpty());

            Test.startTest();
            ServiceResult resultNull = FinancialReporter.deleteReports(null);
            ServiceResult resultEmpty = FinancialReporter.deleteReports(new Set<Id>());
            Test.stopTest();

            System.assert(resultNull.isSuccess);
            System.assert(resultEmpty.isSuccess);
            List<Financial_Report_Result__c> existingFRRs = new List<Financial_Report_Result__c>();
            existingFRRs = [SELECT Id FROM Financial_Report_Result__c];
            System.assertEquals(testData.financialReportResults.size(), existingFRRs.size());
        }
    }

    @IsTest
    private static void testDeleteReportsNoAccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(2)) {
            Set<Id> toDelete = new Map<Id,Financial_Report_Result__c>(testData.financialReportResults).keySet();

            Test.startTest();
            ServiceResult result = FinancialReporter.deleteReports(toDelete);
            Test.stopTest();

            System.assert(!result.isSuccess);
        }
    }
    @IsTest
    private static void testRetrieveReportsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            for (Financial_Report_Result__c frr : testData.financialReportResults) {
                frr.Report_Type__c = 'Profit & Loss';
            }
            testData.financialReportResults[0].Report_Type__c = 'Balance Sheet';
            update testData.financialReportResults;

            Test.startTest();
            List<Financial_Report_Result__c> result = FinancialReporter.retrieveReports(FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS);
            Test.stopTest();

            System.assertEquals(testData.financialReportResults.size() - 1, result.size());
            Set<Id> resultIds = new Map<Id,Financial_Report_Result__c>(result).keySet();
            List<Financial_Report_Result__c> frrs = [SELECT Report_Type__c FROM Financial_Report_Result__c WHERE Id IN :resultIds];
            for (Financial_Report_Result__c frr : frrs) {
                System.assertEquals('Profit & Loss', frr.Report_Type__c);
            }
        }
    }

    @IsTest
    private static void testRetrieveReportsCheckLimit() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            FinancialReporter.MAX_RETRIEVE_REPORTS = testData.financialReportResults.size() - 1;
            for (Financial_Report_Result__c frr : testData.financialReportResults) {
                frr.Report_Type__c = 'Profit & Loss';
            }
            update testData.financialReportResults;

            Test.startTest();
            List<Financial_Report_Result__c> result = FinancialReporter.retrieveReports(FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS);
            Test.stopTest();

            System.assertEquals(testData.financialReportResults.size() - 1, result.size());
        }
    }

    @IsTest
    private static void testRetrieveReportsNoAccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(2)) {
            for (Financial_Report_Result__c frr : testData.financialReportResults) {
                frr.Report_Type__c = 'Profit & Loss';
            }
            testData.financialReportResults[0].Report_Type__c = 'Balance Sheet';
            update testData.financialReportResults;

            Test.startTest();
            List<Financial_Report_Result__c> result = FinancialReporter.retrieveReports(FinancialReportOptions.FinancialReportType.PROFIT_AND_LOSS);
            Test.stopTest();

            System.assertEquals(0, result.size());
        }
    }

    @IsTest
    private static void testRetrieveReportsNoInput() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            for (Financial_Report_Result__c frr : testData.financialReportResults) {
                frr.Report_Type__c = 'Profit & Loss';
            }
            testData.financialReportResults[0].Report_Type__c = 'Balance Sheet';
            update testData.financialReportResults;

            Test.startTest();
            List<Financial_Report_Result__c> result = FinancialReporter.retrieveReports(null);
            Test.stopTest();

            System.assertEquals(0, result.size());
        }
    }

    @IsTest
    private static void testRetrieveReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            Id reportId = testData.financialReportResults[0].Id;

            Test.startTest();
            Financial_Report_Result__c result = FinancialReporter.retrieveReport(reportId);
            Test.stopTest();

            System.assertEquals(reportId, result.Id);
        }
    }

    @IsTest
    private static void testRetrieveReportNoAccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(2)) {
            Id reportId = testData.financialReportResults[0].Id;

            Test.startTest();
            Financial_Report_Result__c result = FinancialReporter.retrieveReport(reportId);
            Test.stopTest();

            System.assertEquals(null, result);
        }
    }

    @IsTest
    private static void testRetrieveReportNoInput() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Financial_Report_Result__c result = FinancialReporter.retrieveReport(null);
            Test.stopTest();

            System.assertEquals(null, result);
        }
    }

    @IsTest
    private static void testReportInvocableInvalidReportType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
  
            Test.startTest();
            //Run Profit And Loss financial report
            list<FinancialReporterInvocableOptions> options = new list<FinancialReporterInvocableOptions>();
            FinancialReporterInvocableOptions option = new FinancialReporterInvocableOptions();
            option.reportType = 'INVALID_REPORT_TYPE';
            options.add(option);
            List<FinancialReportResult> FRR = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, FRR[0].isSuccess);
            System.assertEquals(false, FRR[0].errors.isEmpty());

        }
    }

    @IsTest
    private static void testRerunReportInvalidType() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createFinancialReportResults();

        System.runAs(testData.users.get(1)) {
            Id reportId = testData.financialReportResults[0].Id;

            Test.startTest();
            ServiceResult result = FinancialReporter.reRunReport(reportId);
            Test.stopTest();

            System.assertEquals(FinancialReporter.INVALID_REPORT_TYPE_ERROR, result.errors[0].detail);
        }
    }

//PROFFIT AND LOSS***************************************************************************************************

    @IsTest
    private static void testRunProfitAndLossReportInvocableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            //Run Profit And Loss financial report
            list<FinancialReporterInvocableOptions> options = new list<FinancialReporterInvocableOptions>();
            FinancialReporterInvocableOptions option = new FinancialReporterInvocableOptions();
            option.reportType = 'PROFIT_AND_LOSS';
            options.add(option);
            List<FinancialReportResult> FRR = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(true, FRR[0].isSuccess);
            System.assertEquals(true, FRR[0].errors.isEmpty());
            System.assertNotEquals(NULL, FRR[0].data);
        }
    }

    

    @IsTest
    private static void testRunProfitAndLossReportNoNonZeroRows() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(AbstractFinancialReport.NO_NON_ZERO_ROWS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(true, sr.isSuccess);
            System.assertEquals(true, sr.errors.isEmpty());
            System.assertNotEquals(NULL, sr.data);
        }
    }

    @IsTest
    private static void testRunProfitAndLossReportStartPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;

            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            options.startingAccountingPeriod = NULL;

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.START_PERIOD_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossReportEndPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            options.endingAccountingPeriod = NULL;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.END_PERIOD_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossReportEndBeforeStartPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            options.endingAccountingPeriod = previousPeriod.Id;

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.END_PERIOD_BEFORE_START_PERIOD_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossReportLedgerRequiredError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            options.ledger = NULL;

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.LEDGER_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossReportPeriodIsBeingArchived() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            //set 'Archive In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;

            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossReportPrecedingPeriodIsBeingArchived() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);
            Accounting_Period__c precedingPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(previousPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            //set 'Archive In Progress' status for the preceding period
            AccountingPeriodActions.isFirstRun = false;
            precedingPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            update precedingPeriod;
            AccountingPeriodActions.isFirstRun = false;

            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testReRunProfitAndLossReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

                //Run Profit And Loss financial report
                ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
                ServiceResult sr = FinancialReporter.runReport(options);
                
                System.assertEquals(true, sr.isSuccess);
                System.assertNotEquals(NULL, sr.data);
                
                //rerun the report
                ServiceResult reRunResult = FinancialReporter.reRunReport(sr.data);
            
            Test.stopTest();

            System.assertEquals(true, reRunResult.isSuccess);
            System.assertNotEquals(NULL, reRunResult.data);
            
            List<Financial_Report_Result__c> FRRs = getFinRepResultsForCompare();
            System.assertEquals(2, FRRs.size());
            
            //assert both FRR records are the same
            System.assertEquals(true, FRRs[0] == FRRs[1]);
        }
    }

//PROFFIT AND LOSS Vs BUDGET***************************************************************************************************

    @IsTest
    private static void testRunProfitAndLossVsBudgetReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss VS Budget financial report
            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess);
            System.assertEquals(true, sr.errors.isEmpty());
            System.assertNotEquals(NULL, sr.data);
        }
    }

    @IsTest
    private static void testRunProfitAndLossVsBudgetInvocableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss VS Budget financial report
            list<FinancialReporterInvocableOptions> options = new list<FinancialReporterInvocableOptions>();
            FinancialReporterInvocableOptions option = new FinancialReporterInvocableOptions();
            option.reportType = 'PROFIT_AND_LOSS_VS_BUDGET';
            options.add(option);
            List<FinancialReportResult> FRR = FinancialReporter.runReport(options);

            Test.stopTest();
            System.assertEquals(true, FRR[0].isSuccess);
            System.assertEquals(true, FRR[0].errors.isEmpty());
            System.assertNotEquals(NULL, FRR[0].data);
        }
    }

    @IsTest
    private static void testRunProfitAndLossVsBudgetReportBudgetLedgerRequiredError() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss financial report
            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            options.budgetLedger = NULL;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.BUDGET_LEDGER_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossVsBudgetReportPeriodIsBeingArchived() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            //set 'Archive In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //Run Profit And Loss VS Budget financial report
            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR, sr.errors[0].detail);
            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testRunProfitAndLossVsBudgetReportTransLedgerTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss financial report
            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            options.ledger = testData.ledgers[1].Id;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.LEDGER_TYPE_TRANSACTIONAL_ERROR, sr.errors[0].detail);
        }
    }
    @IsTest
    private static void testRunProfitAndLossVsBudgetReportBudgetLedgerTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss financial report
            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            options.budgetLedger = testData.ledgers[0].Id;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.BUDGET_LEDGER_TYPE_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunProfitAndLossVsBudgetReportNoNonZeroRows() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(AbstractFinancialReport.NO_NON_ZERO_ROWS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testReRunProfitAndLossVsBudgetReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

                //Run Profit And Loss VS Budget financial report
                ProfitAndLossVsBudgetFinReptOptions options = new ProfitAndLossVsBudgetFinReptOptions();
                ServiceResult sr = FinancialReporter.runReport(options);
        

                System.assertEquals(true, sr.isSuccess);
                System.assertEquals(true, sr.errors.isEmpty());
                System.assertNotEquals(NULL, sr.data);

                 ServiceResult reRunResult = FinancialReporter.reRunReport(sr.data);
           
            Test.stopTest();
 
            System.assertEquals(true, reRunResult.isSuccess);
            System.assertNotEquals(NULL, reRunResult.data);
            
            List<Financial_Report_Result__c> FRRs = getFinRepResultsForCompare();
            System.assertEquals(2, FRRs.size());
            
            //assert both FRR records are the same
            System.assertEquals(true, FRRs[0] == FRRs[1]);
        }
    }

    //BALANCE SHEET***************************************************************************************************
    @IsTest
    private static void testRunBalanceSheetReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);

            Test.startTest();
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.endingAccountingPeriod = currentPeriod.id;
            options.includeSubType2 = false;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess);
            System.assertEquals(true, sr.errors.isEmpty());
            System.assertNotEquals(NULL, sr.data);
        }
    }

    @IsTest
    private static void testRunBalanceSheetInvocableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);

            Test.startTest();
            list<FinancialReporterInvocableOptions> options = new list<FinancialReporterInvocableOptions>();
            FinancialReporterInvocableOptions option = new FinancialReporterInvocableOptions();
            option.reportType = 'BALANCE_SHEET';
            option.startingAccountingPeriod = currentPeriod.id;
            option.endingAccountingPeriod = currentPeriod.id;
            option.includeSubType2 = false;
            option.suppressZeroAmountRows = false;
            options.add(option);
            List<FinancialReportResult> FRR = FinancialReporter.runReport(options);

            Test.stopTest();
            System.assertEquals(true, FRR[0].isSuccess);
            System.assertEquals(true, FRR[0].errors.isEmpty());
            System.assertNotEquals(NULL, FRR[0].data);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportLedgerTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);

            Test.startTest();
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.endingAccountingPeriod = nextPeriod.id;
            options.includeSubType2 = false;
            options.ledger = testData.ledgers[1].Id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.LEDGER_TYPE_TRANSACTIONAL_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportLedgerNullError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);

            Test.startTest();
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.endingAccountingPeriod = nextPeriod.id;
            options.includeSubType2 = false;
            options.ledger = null;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.LEDGER_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportNoNonZeroRows() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            Test.startTest();
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            options.endingAccountingPeriod = currentPeriod.Id;
            options.includeSubType2 = false;
            options.suppressZeroAmountRows = true;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(AbstractFinancialReport.NO_NON_ZERO_ROWS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportStartPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            Test.startTest();
            //Run Profit And Loss financial report
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod = null;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.START_PERIOD_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportEndPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            Test.startTest();
            //Run Profit And Loss financial report
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.endingAccountingPeriod = null;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.END_PERIOD_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportEndBeforeStartPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            Test.startTest();
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.endingAccountingPeriod = previousPeriod.id;
            options.includeSubType2 = false;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.END_PERIOD_BEFORE_START_PERIOD_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportPeriodRangeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);

            Test.startTest();
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getAllAccountingPeriods()[0].id ;
            options.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getAllAccountingPeriods()[12].id ;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.ACCOUNTING_PERIOD_RANGE_LIMIT_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunBalanceSheetReportStartPeriodStatusError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
        Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);


        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            options.startingAccountingPeriod =  testData.acctPeriods[12].id;
            options.endingAccountingPeriod = testData.acctPeriods[13].id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.START_PERIOD_STATUS_ERROR, sr.errors[0].detail);
        }
    }
    @IsTest
    private static void testBalanceSheetReportPeriodIsBeingArchived() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Archive In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Balance Sheet financial report
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testBalanceSheetReportPrecedingPeriodIsBeingArchived() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);
            Accounting_Period__c precedingPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(previousPeriod);

            //set 'Archive In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            precedingPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            update precedingPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Balance Sheet financial report
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testBalanceSheetReportPeriodIsBeingClosed() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Close In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Balance Sheet financial report
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            Boolean found = false;
            for (ServiceResult.Error err : sr.errors) {
                if (err.detail == FinancialReporter.PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR) {
                    found = true;
                    break;
                }
            }
            System.assert(found);
        }
    }

    @IsTest
    private static void testBalanceSheetReportPeriodIsBeingOpened() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Open In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Balance Sheet financial report
            BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testReRunBalanceSheetReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);

            Test.startTest();
                BalanceSheetFinancialReportOptions options = new BalanceSheetFinancialReportOptions();
                options.startingAccountingPeriod = currentPeriod.id;
                options.endingAccountingPeriod = currentPeriod.id;
                options.includeSubType2 = false;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);
            
                System.assertEquals(true, sr.isSuccess);
                System.assertEquals(true, sr.errors.isEmpty());
                System.assertNotEquals(NULL, sr.data);

                ServiceResult reRunResult = FinancialReporter.reRunReport(sr.data);
         
            Test.stopTest();

          System.assertEquals(true, reRunResult.isSuccess);
          System.assertNotEquals(NULL, reRunResult.data);
          
          List<Financial_Report_Result__c> FRRs = getFinRepResultsForCompare();
          System.assertEquals(2, FRRs.size());
          
          //assert both FRR records are the same
          System.assertEquals(true, FRRs[0] == FRRs[1]);
        }
    }

//TRIAL BALANCE***************************************************************************************************
    @IsTest
    private static void testRunTrialBalanceReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess);
            System.assertEquals(true, sr.errors.isEmpty());
            System.assertNotEquals(NULL, sr.data);
        }
    }

    @IsTest
    private static void testRunTrialBalanceInvocableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            list<FinancialReporterInvocableOptions> options = new list<FinancialReporterInvocableOptions>();
            FinancialReporterInvocableOptions option = new FinancialReporterInvocableOptions();
            option.reportType = 'TRIAL_BALANCE';
            option.startingAccountingPeriod = currentPeriod.id;
            option.suppressZeroAmountRows = false;
            option.suppressOpeningBalanceAndPeriodColumns = false;
            options.add(option);
            List<FinancialReportResult> FRR = FinancialReporter.runReport(options);

            Test.stopTest();
            System.assertEquals(true, FRR[0].isSuccess);
            System.assertEquals(true, FRR[0].errors.isEmpty());
            System.assertNotEquals(NULL, FRR[0].data);

        }
    }

    @IsTest
    private static void testRunTrialBalanceReportLedgerTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            Test.startTest();
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.includeSubType2 = false;
            options.ledger = testData.ledgers[1].Id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.LEDGER_TYPE_TRANSACTIONAL_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunTrialBalanceReportLedgerNullError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            Test.startTest();
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.includeSubType2 = false;
            options.ledger = null;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.LEDGER_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunTrialBalanceReportAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            Test.startTest();
            //Run Profit And Loss financial report
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = null;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunTrialBalanceReportAccountingPeriodStatusError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c acctPeriod = testData.acctPeriods[12];

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = acctPeriod.Id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testTrialReportPeriodIsBeingArchived() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Archive In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Trial Balance financial report
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = previousPeriod.Id;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testTrialReportPeriodIsBeingClosed() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Close In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Trial Balance financial report
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = previousPeriod.Id;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testTrialReportPrecedingPeriodIsBeingClosed() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Close In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Trial Balance financial report
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = previousPeriod.Id;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testTrialReportPeriodIsBeingOpened() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Open In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Trial Balance financial report
            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            options.startingAccountingPeriod = previousPeriod.Id;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testReRunTrialBalanceReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
                Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

                TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
                options.startingAccountingPeriod = currentPeriod.id;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);
        
                System.assertEquals(true, sr.isSuccess);
                System.assertEquals(true, sr.errors.isEmpty());
                System.assertNotEquals(NULL, sr.data);

                ServiceResult reRunResult = FinancialReporter.reRunReport(sr.data);
         
          Test.stopTest();

          System.assertEquals(true, reRunResult.isSuccess);
          System.assertNotEquals(NULL, reRunResult.data);
          
          List<Financial_Report_Result__c> FRRs = getFinRepResultsForCompare();
          System.assertEquals(2, FRRs.size());
          
          //assert both FRR records are the same
          System.assertEquals(true, FRRs[0] == FRRs[1]);
           
           
        }
    }

//CASH FLOW***************************************************************************************************
    @IsTest
    private static void testRunCashFlowReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Test.startTest();
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(true, sr.isSuccess);
            System.assertEquals(true, sr.errors.isEmpty());
            System.assertNotEquals(NULL, sr.data);
        }
    }

    @IsTest
    private static void testRunCashFlowInvocableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            list<FinancialReporterInvocableOptions> options = new list<FinancialReporterInvocableOptions>();
            FinancialReporterInvocableOptions option = new FinancialReporterInvocableOptions();
            option.reportType = 'CASH_FLOW';
            option.startingAccountingPeriod = currentPeriod.id;
            option.suppressZeroAmountRows = false;
            options.add(option);
            List<FinancialReportResult> FRR = FinancialReporter.runReport(options);

            Test.stopTest();
            System.assertEquals(true, FRR[0].isSuccess);
            System.assertEquals(true, FRR[0].errors.isEmpty());
            System.assertNotEquals(NULL, FRR[0].data);
        }
    }

    @IsTest
    private static void testRunCashFlowReportLedgerTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

            System.runAs(testData.users.get(1)) {
                Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
                Test.startTest();
                CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
                options.startingAccountingPeriod = currentPeriod.id;
                options.includeSubType2 = false;
                options.ledger = testData.ledgers[1].Id;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);
                Test.stopTest();
                System.assertEquals(false, sr.isSuccess);
                System.assertEquals(false, sr.errors.isEmpty());
                System.assertEquals(FinancialReporter.LEDGER_TYPE_TRANSACTIONAL_ERROR, sr.errors[0].detail);
            }
    }

    @IsTest
    private static void testRunCashFlowReportLedgerNullError() {
        TestDataSuite testData = TestDataSuite.getInstance();

            System.runAs(testData.users.get(1)) {
                Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
                Test.startTest();
                CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
                options.startingAccountingPeriod = currentPeriod.id;
                options.includeSubType2 = false;
                options.ledger = null;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);
                Test.stopTest();
                System.assertEquals(false, sr.isSuccess);
                System.assertEquals(false, sr.errors.isEmpty());
                System.assertEquals(FinancialReporter.LEDGER_REQUIRED_ERROR, sr.errors[0].detail);
            }
    }

    @IsTest
    private static void testRunCashFlowReportAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                //Run Profit And Loss financial report
                CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
                options.startingAccountingPeriod = null;
                ServiceResult sr = FinancialReporter.runReport(options);
                Test.stopTest();
                System.assertEquals(false, sr.isSuccess);
                System.assertNotEquals(true, sr.errors.isEmpty());
                System.assertEquals(FinancialReporter.PERIOD_REQUIRED_ERROR, sr.errors[0].detail);
            }
    }

    @IsTest
    private static void testRunCashFlowReportAccountingPeriodStatusError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c acctPeriod = testData.acctPeriods[12];

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
                options.startingAccountingPeriod = acctPeriod.id;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);
                Test.stopTest();
                System.assertEquals(false, sr.isSuccess);
                System.assertEquals(false, sr.errors.isEmpty());
                System.assertEquals(FinancialReporter.PERIOD_STATUS_ERROR, sr.errors[0].detail);
            }
    }

    @IsTest
    private static void testCashFlowReportPeriodIsBeingArchived() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Archive In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Cash Flow Statement financial report
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_ARCHIVE_IN_PROGRESS_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testCashFlowReportPeriodIsBeingClosed() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Close In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Cash Flow Statement financial report
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            Boolean found = false;
            for (ServiceResult.Error err : sr.errors) {
                if (err.detail == FinancialReporter.PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR) {
                    found = true;
                    break;
                }
            }
            System.assert(found);
        }
    }

    @IsTest
    private static void testCashFlowReportPeriodIsBeingOpened() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //set 'Open In Progress' status for previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            Test.startTest();
            //Run Cash Flow Statement financial report
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_IS_IN_OPEN_OR_CLOSED_INTERIM_STATUSES_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunCashFlowReportWithCRMissingCFCategory() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createCashFlowCategories(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            
            Cash_Receipt__c cr = testData.cashReceipts[0];
            cr.Accounting_Period__c = currentPeriod.Id;
            update cr;
            CashReceiptPostService.postCashReceipts(new List<Cash_Receipt__c>{ cr });

            testData.settings.Enable_Cash_Flow_Statement__c = true;
            update testData.settings;
            AccountingSettingsHandler.resetAccountingSettings();
            
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assert(!sr.isSuccess);
            Boolean foundExpectedError =false;
            for (ServiceResult.Error err : sr.errors) {
                if (err.detail == FinancialReporter.CASH_FLOW_UNCATEGORIZED_RECORDS_ERROR) {
                    foundExpectedError = true;
                    break;
                }
            }
            System.assert(foundExpectedError);
        }
    }

    @IsTest
    private static void testRunCashFlowReportWithCDMissingCFCategory() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createCashFlowCategories(false);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            
            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Accounting_Period__c = currentPeriod.Id;
            update cd;
            CashDisbursementPostService.postCashDisbursements(new List<Cash_Disbursement__c>{ cd });

            testData.settings.Enable_Cash_Flow_Statement__c = true;
            update testData.settings;
            AccountingSettingsHandler.resetAccountingSettings();
            
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assert(!sr.isSuccess);
            Boolean foundExpectedError =false;
            for (ServiceResult.Error err : sr.errors) {
                if (err.detail == FinancialReporter.CASH_FLOW_UNCATEGORIZED_RECORDS_ERROR) {
                    foundExpectedError = true;
                    break;
                }
            }
            System.assert(foundExpectedError);
        }
    }

    @IsTest
    private static void testRunCashFlowReportWithJEMissingCFCategory() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createCashFlowCategories(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            
            Journal_Entry__c je = testData.journalEntries[0];
            je.Accounting_Period__c = currentPeriod.Id;
            update je;
            JournalEntryPostService.postJournalEntries(new List<Journal_Entry__c>{ je });

            testData.settings.Enable_Cash_Flow_Statement__c = true;
            update testData.settings;
            AccountingSettingsHandler.resetAccountingSettings();
            
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;

            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assert(!sr.isSuccess);
            Boolean foundExpectedError =false;
            for (ServiceResult.Error err : sr.errors) {
                if (err.detail == FinancialReporter.CASH_FLOW_UNCATEGORIZED_RECORDS_ERROR) {
                    foundExpectedError = true;
                    break;
                }
            }
            System.assert(foundExpectedError);
        }
    }

    @IsTest
    private static void testReRunCashFlowReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Test.startTest();
            CashFlowFinancialReportOptions options = new CashFlowFinancialReportOptions();
                options.startingAccountingPeriod = currentPeriod.id;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);
            
                System.assertEquals(true, sr.isSuccess);
                System.assertEquals(true, sr.errors.isEmpty());
                System.assertNotEquals(NULL, sr.data);
                ServiceResult reRunResult = FinancialReporter.reRunReport(sr.data);
         
            Test.stopTest();

            System.assertEquals(true, reRunResult.isSuccess);
            System.assertNotEquals(NULL, reRunResult.data);
            
            List<Financial_Report_Result__c> FRRs = getFinRepResultsForCompare();
            System.assertEquals(2, FRRs.size());
            
            //assert both FRR records are the same
            System.assertEquals(true, FRRs[0] == FRRs[1]);  
        }
    }

    //LEDGER INQUIRY***************************************************************************************************
    @IsTest
    private static void testRunLedgerInquiryReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = currentPeriod.Start_Date__c,
                Billing_Cycle_End_Date__c = currentPeriod.End_Date__c + 3,
                Date__c = currentPeriod.Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = currentPeriod.End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempBilling;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = currentPeriod.Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert tempBillingLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c> {tempBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(true, response.saveResponse.isSuccess);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportWithNoAccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c currentPeriod;
        Test.startTest();
        System.runAs(testData.users.get(1)) {
            currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = currentPeriod.Start_Date__c,
                Billing_Cycle_End_Date__c = currentPeriod.End_Date__c + 3,
                Date__c = currentPeriod.Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = currentPeriod.End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempBilling;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = currentPeriod.Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert tempBillingLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c> {tempBilling});
            System.assertEquals(true, postResults[0].isSuccess);
        }

        System.runAs(testData.users.get(2)) {
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(0, response.lines.size());
        }
        Test.stopTest();
    }

    @IsTest
    private static void testRunLedgerInquiryReportNoTransactions() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Test.startTest();
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(LedgerInquiryFinancialReport.NO_POSTED_RECORDS, response.saveResponse.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportStartPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = null;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(FinancialReporter.START_PERIOD_REQUIRED_ERROR, response.saveResponse.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportEndPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.endingAccountingPeriod = null;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(FinancialReporter.END_PERIOD_REQUIRED_ERROR, response.saveResponse.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportEndBeforeStartPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            Test.startTest();
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.id;
            options.endingAccountingPeriod = previousPeriod.id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(FinancialReporter.END_PERIOD_BEFORE_START_PERIOD_ERROR, response.saveResponse.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportPeriodRangeError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);
            Test.startTest();
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getAllAccountingPeriods()[0].Id ;
            options.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getAllAccountingPeriods()[12].Id ;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(FinancialReporter.ACCOUNTING_PERIOD_RANGE_LIMIT_ERROR, response.saveResponse.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportStartPeriodStatusError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
        Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod =  testData.acctPeriods[12].Id;
            options.endingAccountingPeriod = testData.acctPeriods[13].Id;
            options.suppressZeroAmountRows = false;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(FinancialReporter.START_PERIOD_STATUS_ERROR, response.saveResponse.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportCashFlowGLAError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createCashFlowCategories(true);
        
        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod);
            Test.startTest();
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = AccountingPeriodHandler.getInstance().getAllAccountingPeriods()[0].Id;
            options.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getAllAccountingPeriods()[12].Id;
            options.glAccount = testData.cashFlowCategories[1].id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();
            System.assertEquals(false, response.saveResponse.isSuccess);
            System.assertEquals(FinancialReporter.CASH_FLOW_ACCOUNT_TYPE_ERROR, response.saveResponse.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportSelectSource() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = currentPeriod.Start_Date__c,
                Billing_Cycle_End_Date__c = currentPeriod.End_Date__c + 3,
                Date__c = currentPeriod.Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = currentPeriod.End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempBilling;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = currentPeriod.Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert tempBillingLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c> {tempBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            Account_Payable__c tempPayable = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdh',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = currentPeriod.Start_Date__c,
                Due_Date__c = currentPeriod.End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempPayable;

            Account_Payable_Line__c tempApLine = new Account_Payable_Line__c(
                Account_Payable__c = tempPayable.Id,
                Amount__c = 45,
                Date__c = currentPeriod.Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert tempApLine;

            AbstractPostHandler postHandlerPay = new AccountPayablePostHandler();
            List<PostResult> postResultsPay = postHandlerPay.post(new List<Account_Payable__c> {tempPayable});
            System.assertEquals(true, postResultsPay[0].isSuccess);

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            System.assertEquals(4, response.lines.size());

            LedgerInquiryFinancialReportOptions optionsNew = new LedgerInquiryFinancialReportOptions();
            optionsNew.startingAccountingPeriod = currentPeriod.Id;
            optionsNew.source = new List<String> {'billing'};
            LedgerInquiryFinancialReport.LedgerInquiryResponse responseNew = LedgerInquiryFinancialReport.runReport(optionsNew);
            Test.stopTest();

            System.assertEquals(2, responseNew.lines.size());
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportSelectSourceLLP() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = currentPeriod.Start_Date__c,
                Billing_Cycle_End_Date__c = currentPeriod.End_Date__c + 3,
                Date__c = currentPeriod.Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = currentPeriod.End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempBilling;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = currentPeriod.Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert tempBillingLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c> {tempBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            Account_Payable__c tempPayable = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdh',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = currentPeriod.Start_Date__c,
                Due_Date__c = currentPeriod.End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempPayable;

            Account_Payable_Line__c tempApLine = new Account_Payable_Line__c(
                Account_Payable__c = tempPayable.Id,
                Amount__c = 45,
                Date__c = currentPeriod.Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert tempApLine;

            AbstractPostHandler postHandlerPay = new AccountPayablePostHandler();
            List<PostResult> postResultsPay = postHandlerPay.post(new List<Account_Payable__c> {tempPayable});
            System.assertEquals(true, postResultsPay[0].isSuccess);

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            System.assertEquals(4, response.lines.size());

            LedgerInquiryFinancialReportOptions optionsNew = new LedgerInquiryFinancialReportOptions();
            optionsNew.startingAccountingPeriod = currentPeriod.Id;
            optionsNew.source = new List<String> {'billingLine', 'payableLine'};
            LedgerInquiryFinancialReport.LedgerInquiryResponse responseNew = LedgerInquiryFinancialReport.runReport(optionsNew);
            Test.stopTest();

            System.assertEquals(4, responseNew.lines.size());
        }
    }

    @IsTest
    private static void testRunLedgerInquiryReportSelectAggregateBy() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = currentPeriod.Start_Date__c,
                Billing_Cycle_End_Date__c = currentPeriod.End_Date__c + 3,
                Date__c = currentPeriod.Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = currentPeriod.End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempBilling;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = currentPeriod.Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert tempBillingLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c> {tempBilling});
            System.assertEquals(true, postResults[0].isSuccess);


            Account_Payable__c tempPayable = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdh',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = currentPeriod.Start_Date__c,
                Due_Date__c = currentPeriod.End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempPayable;

            Account_Payable_Line__c tempApLine = new Account_Payable_Line__c(
                Account_Payable__c = tempPayable.Id,
                Amount__c = 45,
                Date__c = currentPeriod.Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert tempApLine;

            AbstractPostHandler postHandlerPay = new AccountPayablePostHandler();
            List<PostResult> postResultsPay = postHandlerPay.post(new List<Account_Payable__c> {tempPayable});
            System.assertEquals(true, postResultsPay[0].isSuccess);

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = currentPeriod.Id;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            System.assertEquals(4, response.lines.size());

            LedgerInquiryFinancialReportOptions optionsNew = new LedgerInquiryFinancialReportOptions();
            optionsNew.startingAccountingPeriod = currentPeriod.Id;
            optionsNew.aggregatedBy = 'accounts';
            LedgerInquiryFinancialReport.LedgerInquiryResponse responseNew = LedgerInquiryFinancialReport.runReport(optionsNew);
            Test.stopTest();

            System.assertEquals(1, responseNew.lines.size());
            System.assertEquals(0, responseNew.lines[0].amount);
        }
    }

    //CUSTOM REPORTS***************************************************************************************************
    @IsTest
    private static void testRunCustomReportReportInvocableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createReportDefinitions();
       

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Financial_Report_Definition__c repDef = [SELECT Id, Name FROM Financial_Report_Definition__c LIMIT 1];
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            list<FinancialReporterInvocableOptions> options = new list<FinancialReporterInvocableOptions>();
            FinancialReporterInvocableOptions option = new FinancialReporterInvocableOptions();
            option.reportType = 'CUSTOM';
            option.financialReportDefinitionId = repDef.Id;
            option.startingAccountingPeriod = currentPeriod.Id;
            option.suppressZeroAmountRows = false;
            options.add(option);
            List<FinancialReportResult> FRR = FinancialReporter.runReport(options);
            Test.stopTest();
            System.assertEquals(true, FRR[0].isSuccess);
            System.assertEquals(true, FRR[0].errors.isEmpty());
            System.assertNotEquals(NULL, FRR[0].data);
        }
    }
     @IsTest
    private static void testRunCustomReportReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createReportDefinitions();
       

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Financial_Report_Definition__c repDef = [SELECT Id, Name FROM Financial_Report_Definition__c LIMIT 1];
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            CustomFinancialReportOptions options = new CustomFinancialReportOptions(repDef.Id);
            options.startingAccountingPeriod = currentPeriod.Id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess);
            System.assertEquals(true, sr.errors.isEmpty());
            System.assertNotEquals(NULL, sr.data);
        }
    }

    @IsTest
    private static void testRunCustomReportReportDefinitionError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            Test.startTest();
            CustomFinancialReportOptions options = new CustomFinancialReportOptions(null);
            options.startingAccountingPeriod = currentPeriod.id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.CUSTOM_REPORT_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunCustomReportAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createReportDefinitions();
       
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Financial_Report_Definition__c repDef = [SELECT Id, Name FROM Financial_Report_Definition__c LIMIT 1];
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            CustomFinancialReportOptions options = new CustomFinancialReportOptions(repDef.Id);
            options.startingAccountingPeriod = NULL;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertNotEquals(true, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_REQUIRED_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testRunCustomReportAccountingPeriodWithOnlyExpenseOrRev() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createReportDefinitions();
        Accounting_Period__c acctPeriod = testData.acctPeriods[12];

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                Financial_Report_Definition__c repDef = [SELECT Id, Name FROM Financial_Report_Definition__c LIMIT 1];
                CustomFinancialReportOptions options = new CustomFinancialReportOptions(repDef.Id);
                options.startingAccountingPeriod = acctPeriod.Id;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);
                Test.stopTest();

                System.assertEquals(true, sr.isSuccess);
                System.assertEquals(true, sr.errors.isEmpty());
            }
    }

    @IsTest
    private static void testRunCustomReportAccountingPeriodStatusError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportRows();
        Accounting_Period__c acctPeriod = testData.acctPeriods[12];

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Financial_Report_Definition__c repDef = [SELECT Id, Name FROM Financial_Report_Definition__c LIMIT 1];
            CustomFinancialReportOptions options = new CustomFinancialReportOptions(repDef.Id);
            options.startingAccountingPeriod = acctPeriod.Id;
            options.suppressZeroAmountRows = false;
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(false, sr.errors.isEmpty());
            System.assertEquals(FinancialReporter.PERIOD_STATUS_ERROR, sr.errors[0].detail);
        }
    }

    @IsTest
    private static void testReRunCustomReportReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createReportDefinitions();
       

        System.runAs(testData.users.get(1)) {
            Test.startTest();
                Financial_Report_Definition__c repDef = [SELECT Id, Name FROM Financial_Report_Definition__c LIMIT 1];
                Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

                CustomFinancialReportOptions options = new CustomFinancialReportOptions(repDef.Id);
                options.startingAccountingPeriod = currentPeriod.Id;
                options.suppressZeroAmountRows = false;
                ServiceResult sr = FinancialReporter.runReport(options);

                System.assertEquals(true, sr.isSuccess);
                System.assertEquals(true, sr.errors.isEmpty());
                System.assertNotEquals(NULL, sr.data);
                ServiceResult reRunResult = FinancialReporter.reRunReport(sr.data);
         
            Test.stopTest();
      
            System.assertEquals(true, reRunResult.isSuccess);
            System.assertNotEquals(NULL, reRunResult.data);
            
            List<Financial_Report_Result__c> FRRs = getFinRepResultsForCompare();
            System.assertEquals(2, FRRs.size());
            
            //assert both FRR records are the same
            System.assertEquals(true, FRRs[0] == FRRs[1]);
                 
                 
        }
    }

    // Report Viewer Helper ===========================================================================

    @IsTest
    private static void testGetFinancialReportResultsById() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);
            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            FinancialReportWrapper result = FinancialReporterHelper.getFinancialReportResultsById(sr.data);

            System.assertEquals(false, result.rowList.isEmpty());
            System.assertEquals(false, result.colList.isEmpty());
            System.assertEquals(false, result.reportvalues.isEmpty());
            System.assertEquals(false, result.reportPeriodsByOffset.isEmpty());
            System.assertNotEquals(NULL, result.reportDefinition);
        }
    }

    @IsTest
    private static void testUpdateReportSubtitle() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            //Run Profit And Loss financial report
            ProfitAndLossFinancialReportOptions options = new ProfitAndLossFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            FinancialReportWrapper result = FinancialReporterHelper.getFinancialReportResultsById(sr.data);
            System.assertEquals(NULL, result.reportDefinition.Subtitle__c);

            AbstractLWCHelper.SaveResponse response = FinancialReporterHelper.updateReportSubtitle(sr.data, 'Test Subtitle');
            System.assert(response.isSuccess);

            FinancialReportWrapper newResult = FinancialReporterHelper.getFinancialReportResultsById(sr.data);

            System.assertEquals('Test Subtitle', newResult.reportDefinition.Subtitle__c);
        }
    }

    @IsTest
    private static void testForceSetIncludeSubtype1WhenIncludeSubtype2IsTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            FinancialReportOptions reportOptions = new ProfitAndLossFinancialReportOptions();
            reportOptions.includeSubType1 = false;
            reportOptions.includeSubType2 = true;

            Test.startTest();
            FinancialReporter.runReport(reportOptions);
            System.assertEquals(true, reportOptions.includeSubType1);
        }
    }

    @IsTest
    private static void testCloneAsCustom() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod =
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod =
                    AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            //open previous period
            AccountingPeriodActions.isFirstRun = false;
            previousPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update previousPeriod;
            AccountingPeriodActions.isFirstRun = false;
            //update source docs
            Billing__c testBilling = [SELECT  Id FROM Billing__c ORDER BY Date__c LIMIT 1];
            testBilling.Billing_Cycle_Start_Date__c = previousPeriod.Start_Date__c;
            testBilling.Billing_Cycle_End_Date__c = previousPeriod.End_Date__c + 3;
            testBilling.Date__c = previousPeriod.Start_Date__c;
            testBilling.Accounting_Period__c = previousPeriod.Id;
            update testBilling;
            //Post source docs
            Test.startTest();
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> results = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, results[0].isSuccess);

            TrialBalanceFinancialReportOptions options = new TrialBalanceFinancialReportOptions();
            ServiceResult sr = FinancialReporter.runReport(options);
            Test.stopTest();

            Map<String, Object> result = FinancialReporterHelper.cloneAsCustom(new Map<String, String>{
                    'name' => 'test',
                    'description' => 'test',
                    'reportId' => sr.data
            });

            System.assert(result != null && String.isNotBlank((String)result.get('definitionId')));
        }
    }

    private static List<Financial_Report_Result__c> getFinRepResultsForCompare(){
        List<Financial_Report_Result__c> FRRs = [SELECT Ledger__c,
        Budget_Ledger__c,
        Accounting_Period__c,
        End_Accounting_Period__c,
        GL_Account_Variable_1__c,
        GL_Account_Variable_2__c,
        GL_Account_Variable_3__c,
        GL_Account_Variable_4__c,
        Financial_Report_Definition__c,
        Suppress_Opening_Balance_and_Period__c,
        Include_Sub_Type_1__c,
        Include_Sub_Type_2__c,
        Rounding__c,
        Subtitle__c,
        Suppress_Zero_Amount_Rows__c,
        Report_Type__c,
        Show_All_Periods__c FROM Financial_Report_Result__c ];

        //nullify Ids becuase they will always be different
        FRRs[0].Id = null;
        FRRs[1].Id = null;

        return FRRs;
    }
}