@IsTest
private class BalanceSheetFinancialReportTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
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
    private static void testUncategorizedSectionsInAllTypes()  {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<GL_Account__c> liabilitiesGlAccounts = [
                SELECT Sub_Type_1__c, Sub_Type_2__c
                FROM GL_Account__c
                WHERE Sub_Type_1__c = :GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_LIABILITIES
            ];

            for (GL_Account__c item : liabilitiesGlAccounts) {
                item.Sub_Type_2__c = NULL;
            }
            update liabilitiesGlAccounts;

            GL_Account__c newAccountAsset = new GL_Account__c(
                Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_ASSETS,
                Sub_Type_2__c = NULL
            );
            insert newAccountAsset;

            GL_Account__c newAccountLiabilities = new GL_Account__c(
                Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_LIABILITIES,
                Sub_Type_2__c = NULL
            );
            insert newAccountLiabilities;

            GL_Account__c newAccountOwnersEquity = new GL_Account__c(
                Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY,
                Sub_Type_2__c = NULL
            );
            insert newAccountOwnersEquity;

            BalanceSheetFinancialReportOptions reportOptions = new BalanceSheetFinancialReportOptions();
            reportOptions.suppressZeroAmountRows = false;
            reportOptions.includeSubType2 = true;

            BalanceSheetFinancialReport bsf = new BalanceSheetFinancialReport();
            FinancialReportWrapper frw = bsf.runReport(reportOptions);

            Integer numberOfUncategorizedRows = 0;
            for (Financial_Report_Row__c item : frw.rowList) {
                if (item.Row_Label__c == 'Total Uncategorized') {
                    numberOfUncategorizedRows++;
                }
            }

            System.assertEquals(65, frw.rowList.size());
            System.assertEquals(3, numberOfUncategorizedRows);
        }

    }

    @IsTest
    private static void testBalanceSheetCreateReportDefinitionExcludeSubType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BalanceSheetFinancialReportOptions reportOptions = new BalanceSheetFinancialReportOptions();
            reportOptions.suppressZeroAmountRows = false;
            reportOptions.includeSubType2 = false;
            BalanceSheetFinancialReport bsf = new BalanceSheetFinancialReport();
            FinancialReportWrapper frw = bsf.runReport(reportOptions);
            System.assertEquals(34, frw.rowList.size());
            System.assertEquals(11, frw.colList.size());

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
    private static void testBalanceSheetCreateReportDefinitionIncludeSubType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BalanceSheetFinancialReportOptions reportOptions = new BalanceSheetFinancialReportOptions();
            reportOptions.suppressZeroAmountRows = false;
            BalanceSheetFinancialReport bsf = new BalanceSheetFinancialReport();
            FinancialReportWrapper frw = bsf.runReport(reportOptions);

            System.assertEquals(54, frw.rowList.size());
            System.assertEquals(11, frw.colList.size());

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
    private static void testBalanceSheetCreateReportDefinitionNoNonZeroRowsException() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            FinancialReportOptions reportOptions = new BalanceSheetFinancialReportOptions();
            reportOptions.startingAccountingPeriod = currentPeriod.Id;
            reportOptions.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod).Id;
            reportOptions.suppressZeroAmountRows = true;

            Exception dmlEx;
            try {
                BalanceSheetFinancialReport bsf = new BalanceSheetFinancialReport();
                bsf.runReport(reportOptions);
            } catch (Exception ex) {
                dmlEx = ex;
            }

            System.assertEquals(AbstractFinancialReport.NO_NON_ZERO_ROWS_ERROR, dmlEx.getMessage());
        }
    }

    @IsTest
    private static void testBalanceSheetCreateReportDefinitionReportTooManyRowsException() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            FinancialReportOptions reportOptions = new BalanceSheetFinancialReportOptions();
            reportOptions.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod).Id;
            reportOptions.suppressZeroAmountRows = false;

            List<GL_Account__c> glAccountList = new List<GL_Account__c>();
            for (Integer i = 0; i < 250; i++) {
                glAccountList.add(testData.glAccounts[1].clone(false));
            }
            insert glAccountList;

            List<Journal_Entry__c> jeList = new List<Journal_Entry__c>();
            jeList.add(testData.journalEntries[0].clone(false));
            jeList[0].Accounting_Period__c = currentPeriod.Id;
            insert jeList;

            List<Journal_Entry_Line__c> jelList = new List<Journal_Entry_Line__c>();
            for (Integer i = 0; i < 250; i++) {
                Journal_Entry_Line__c jel = new Journal_Entry_Line__c(
                    Journal_Entry__c = jeList[0].Id,
                    GL_Account__c = glAccountList[i].Id
                );

                if (Math.mod(i, 2) == 0) {
                    jel.Credit__c = 1;
                } else {
                    jel.Debit__c = 1;
                }

                jelList.add(jel);
            }
            insert jelList;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(jeList);
            System.assertEquals(true, postResults.get(0).isSuccess);

            Exception dmlEx;
            try {
                AbstractFinancialReport.REPORT_CELL_LIMIT = 1000;
                BalanceSheetFinancialReport bsReportClassInstance = new BalanceSheetFinancialReport();
                bsReportClassInstance.runReport(reportOptions);
            } catch (Exception ex) {
                dmlEx = ex;
            }

            System.assertEquals(AbstractFinancialReport.TOO_MANY_ROWS_ERROR, dmlEx.getMessage());
        }

    }

    @IsTest
    private static void testProfitAndLossFinancialCreateReportDefinitionReportImplicitSuppressZero() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            FinancialReportOptions reportOptions = new BalanceSheetFinancialReportOptions();
            reportOptions.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod).Id;
            reportOptions.suppressZeroAmountRows = false;

            List<GL_Account__c> glAccountList = new List<GL_Account__c>();
            for (Integer i = 0; i < 250; i++) {
                glAccountList.add(testData.glAccounts[1].clone(false));
            }
            insert glAccountList;

            Exception dmlEx;
            try {
                AbstractFinancialReport.REPORT_CELL_LIMIT = 1000;
                BalanceSheetFinancialReport bsReportClassInstance = new BalanceSheetFinancialReport();
                bsReportClassInstance.runReport(reportOptions);
            } catch (Exception ex) {
                dmlEx = ex;
            }

            System.assertEquals(reportOptions.suppressZeroAmountRows, true);
        }
    }

}