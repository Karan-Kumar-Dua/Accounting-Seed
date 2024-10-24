@IsTest
private class CashFlowStatementReportTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createCashFlowCategories(true);
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            //Create and post Cash Receipt records for closed accounting periods
            createCashReceipt(
                testData.accounts.get(0),
                testData.glAccounts.get(0),
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -3)
            );
            createCashReceipt(
                testData.accounts.get(0),
                testData.glAccounts.get(0),
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -2)
            );
            createCashReceipt(
                testData.accounts.get(0),
                testData.glAccounts.get(0),
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -1)
            );

            testData.closePreviousAccountingPeriodsBasedOnCurrentDate();
        }
    }

    private static Cash_Receipt__c createCashReceipt(Account acct, GL_Account__c bankGlAccount, Accounting_Period__c acctPeriod) {
        Cash_Receipt__c cr = new Cash_Receipt__c(
            Account__c = acct.Id,
            Amount__c = 500,
            Payment_Reference__c = '0000000123',
            Receipt_Date__c = acctPeriod.Start_Date__c,
            Accounting_Period__c = acctPeriod.Id,
            Purpose__c = 'Customer Receipt',
            Bank_Account__c = bankGlAccount.Id
        );
        insert cr;
        return cr;
    }

    @IsTest
    private static void testCashFlowStatementCreateReportDefinitionCurrentPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            CashFlowFinancialReportOptions reportOptions = new CashFlowFinancialReportOptions();
            CashFlowStatementReport cfsr = new CashFlowStatementReport();
            FinancialReportWrapper frw = cfsr.runReport(reportOptions);

            System.assertEquals(29, frw.rowList.size());//15 CF Category rows + 14 other static rows
            System.assertEquals(reportOptions.getListOfPeriodNames().size(), frw.colList.size());
            Test.stopTest();

            List<Financial_Report_Result_Value__c> cells = [
                SELECT Id
                FROM Financial_Report_Result_Value__c
                WHERE Financial_Report_Result__c = :frw.reportResult.Id
            ];

            System.assertNotEquals(true, cells.isEmpty());
        }

    }

    @IsTest
    private static void testCashFlowStatementCreateReportDefinitionShowAllPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            CashFlowFinancialReportOptions reportOptions = new CashFlowFinancialReportOptions();
            reportOptions.showAllPeriods = true;
            CashFlowStatementReport cfsr = new CashFlowStatementReport();
            FinancialReportWrapper frw = cfsr.runReport(reportOptions);

            System.assertEquals(29, frw.rowList.size());//15 CF Category rows + 14 other static rows
            System.assertEquals(reportOptions.getListOfPeriodNames().size(), frw.colList.size());
            Test.stopTest();

            List<Financial_Report_Result_Value__c> cells = [
                SELECT Id
                FROM Financial_Report_Result_Value__c
                WHERE Financial_Report_Result__c = :frw.reportResult.Id
            ];

            System.assertNotEquals(true, cells.isEmpty());
        }

    }

}