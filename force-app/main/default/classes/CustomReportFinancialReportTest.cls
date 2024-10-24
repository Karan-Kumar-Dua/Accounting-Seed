@IsTest
private class CustomReportFinancialReportTest {

    @TestSetup
    public static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        AccountingPeriodHandler.reset();

        System.runAs(testData.users.get(1)) {
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
    private static void testRunCustomReport() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportRows()
            .createReportColumns();

        System.runAs(testData.users.get(1)) {

            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Accounting_Period__c previousPeriod = AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(currentPeriod);

            Financial_Report_Definition__c reportDef = [
                SELECT
                    Id, Name,
                    (SELECT
                        Id, GL_Account_Reporting_Group__c, Type__c, GL_Account__c,
                        GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
                        FROM Financial_Report_Rows__r),
                    (SELECT
                        Id, Ledger__c, Offset__c, Header_2__c
                        FROM Financial_Report_Columns__r)
                FROM Financial_Report_Definition__c
                WHERE Id = :testData.reportDefs[0].Id
            ];

            CustomFinancialReportOptions reportOptions = new CustomFinancialReportOptions(reportDef.Id);
            reportOptions.startingAccountingPeriod = previousPeriod.Id;
            reportOptions.suppressZeroAmountRows = false;
            reportOptions.subtitle = 'Test Subtitle';

            AbstractFinancialReport afr = new CustomReportFinancialReport();
            FinancialReportWrapper frw = afr.runReport(reportOptions);

            System.assertNotEquals(true, frw.rowList.isEmpty());
            System.assertNotEquals(true, frw.colList.isEmpty());
            System.assertEquals(NULL, frw.getGLVariable1Id());
            System.assertEquals(NULL, frw.getGLVariable2Id());
            System.assertEquals(NULL, frw.getGLVariable3Id());
            System.assertEquals(NULL, frw.getGLVariable4Id());
            System.assertEquals(testData.ledgers.get(1).Id, frw.getLedgerId());
            System.assertEquals(NULL, frw.getBudgetLedgerId());
            System.assertEquals('Test Subtitle', frw.reportDefinition.Subtitle__c);
        }
    }

}