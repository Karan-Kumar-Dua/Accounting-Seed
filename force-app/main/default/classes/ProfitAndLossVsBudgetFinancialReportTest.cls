@IsTest
private class ProfitAndLossVsBudgetFinancialReportTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            //Create and post Billing records for closed accounting periods
            List<Billing__c> testBillings = new List<Billing__c>{
                createBilling(
                    testData.accounts.get(0),
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -3)
                ),
                createBilling(
                    testData.accounts.get(0),
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -2)
                ),
                createBilling(
                    testData.accounts.get(0),
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -1)
                )
            };
            List<PostResult> postResults = new BillingPostHandler().post(testBillings);
            System.assertEquals(3, postResults.size());
            System.assertEquals(true, postResults[0].isSuccess);
            System.assertEquals(true, postResults[1].isSuccess);
            System.assertEquals(true, postResults[2].isSuccess);

            testData.closePreviousAccountingPeriodsBasedOnCurrentDate();
        }
    }

    private static Billing__c createBilling(Account customer, Accounting_Period__c acctPeriod) {
        Billing__c billing = new Billing__c(
            Billing_Cycle_Start_Date__c = acctPeriod.Start_Date__c,
            Billing_Cycle_End_Date__c = acctPeriod.End_Date__c,
            Date__c = acctPeriod.Start_Date__c,
            Customer__c = customer.Id,
            Accounting_Period__c = acctPeriod.Id,
            Due_Date2__c = acctPeriod.Start_Date__c.addDays(30)
        );
        insert billing;

        Billing_Line__c billingLine = new Billing_Line__c(
            Billing__c = billing.Id,
            Date__c = acctPeriod.Start_Date__c,
            Hours_Units__c = 1,
            Rate__c = 100
        );
        insert billingLine;

        return billing;
    }


    @IsTest
    private static void testProfitAndLossVsBudgetFinancialCreateReportDefinition() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c testBilling = createBilling(testData.accounts.get(0), currentPeriod);
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, postResults.get(0).isSuccess);

            ProfitAndLossVsBudgetFinReptOptions reportOptions = new ProfitAndLossVsBudgetFinReptOptions();
            reportOptions.includeSubType1 = false;
            reportOptions.suppressZeroAmountRows = false;

            ProfitAndLossVsBudgetFinancialReport pnlVsBudgetReportClassInstance = new ProfitAndLossVsBudgetFinancialReport();
            FinancialReportWrapper frw = pnlVsBudgetReportClassInstance.runReport(reportOptions);

            System.assertEquals(29, frw.rowList.size());
            System.assertEquals(26, frw.colList.size());

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
    private static void testProfitAndLossVsBudgetFinancialCreateReportDefinitionSubType() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c testBilling = createBilling(testData.accounts.get(0), currentPeriod);
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, postResults.get(0).isSuccess);

            ProfitAndLossVsBudgetFinReptOptions reportOptions = new ProfitAndLossVsBudgetFinReptOptions();
            reportOptions.suppressZeroAmountRows = false;
            reportOptions.includeSubType1 = true;
            reportOptions.includeSubType2 = true;

            ProfitAndLossVsBudgetFinancialReport pnlVsBudgetReportClassInstance = new ProfitAndLossVsBudgetFinancialReport();
            FinancialReportWrapper frw = pnlVsBudgetReportClassInstance.runReport(reportOptions);

            System.assertEquals(81, frw.rowList.size());
            System.assertEquals(26, frw.colList.size());

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
    private static void testProfitAndLossVsBudgetFinancialCreateReportDefinitionShowAllPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c testBilling = createBilling(testData.accounts.get(0), currentPeriod);
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, postResults.get(0).isSuccess);

            ProfitAndLossVsBudgetFinReptOptions reportOptions = new ProfitAndLossVsBudgetFinReptOptions();
            reportOptions.includeSubType1 = false;
            reportOptions.suppressZeroAmountRows = false;
            reportOptions.showAllPeriods = true;

            ProfitAndLossVsBudgetFinancialReport pnlVsBudgetReportClassInstance = new ProfitAndLossVsBudgetFinancialReport();
            FinancialReportWrapper frw = pnlVsBudgetReportClassInstance.runReport(reportOptions);

            List<GL_Account__c> glAccounts = [
                SELECT Id, Name
                FROM GL_Account__c
                WHERE Type__c = :GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
                OR Type__c = :GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE
            ];
            System.assertEquals(glAccounts.size() + 13, frw.rowList.size());
            System.assertEquals(26, frw.colList.size());
        }
    }

    @IsTest
    private static void testProfitAndLossVsBudgetFinancialCreateReportDefinitionReportNoNonZeroRowsException() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            ProfitAndLossVsBudgetFinReptOptions reportOptions = new ProfitAndLossVsBudgetFinReptOptions();
            reportOptions.startingAccountingPeriod = currentPeriod.Id;
            reportOptions.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod).Id;
            reportOptions.suppressZeroAmountRows = true;

            Exception dmlEx;
            try {
                ProfitAndLossVsBudgetFinancialReport pnlVsBudgetReportClassInstance = new ProfitAndLossVsBudgetFinancialReport();
                pnlVsBudgetReportClassInstance.runReport(reportOptions);
            } catch (Exception ex) {
                dmlEx = ex;
            }

            System.assertEquals(AbstractFinancialReport.NO_NON_ZERO_ROWS_ERROR, dmlEx.getMessage());
        }
    }

    @IsTest
    private static void testProfitAndLossVsBudgetFinancialCreateReportDefinitionReportTooManyRowsException() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            ProfitAndLossVsBudgetFinReptOptions reportOptions = new ProfitAndLossVsBudgetFinReptOptions();
            reportOptions.startingAccountingPeriod = currentPeriod.Id;
            reportOptions.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod).Id;
            reportOptions.suppressZeroAmountRows = false;

            List<GL_Account__c> glAccountList = new List<GL_Account__c>();
            for (Integer i = 0; i < 250; i++) {
                glAccountList.add(testData.glAccounts[11].clone(false));
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
                AbstractFinancialReport.REPORT_CELL_LIMIT = 200;
                ProfitAndLossVsBudgetFinancialReport pnlVsBudgetReportClassInstance = new ProfitAndLossVsBudgetFinancialReport();
                pnlVsBudgetReportClassInstance.runReport(reportOptions);
            } catch (Exception ex) {
                dmlEx = ex;
            }

            System.assertEquals(AbstractFinancialReport.TOO_MANY_ROWS_ERROR, dmlEx.getMessage());
        }
    }

    @IsTest
    private static void testProfitAndLossVsBudgetFinancialCreateReportDefinitionReportImplicitSuppressZero() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createGLAccountExpenses();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            ProfitAndLossVsBudgetFinReptOptions reportOptions = new ProfitAndLossVsBudgetFinReptOptions();
            reportOptions.startingAccountingPeriod = currentPeriod.Id;
            reportOptions.endingAccountingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriod).Id;
            reportOptions.suppressZeroAmountRows = false;

            List<GL_Account__c> glAccountList = new List<GL_Account__c>();
            for (Integer i = 0; i < 250; i++) {
                glAccountList.add(testData.glAccounts[11].clone(false));
            }
            insert glAccountList;

            Exception dmlEx;
            try {
                AbstractFinancialReport.REPORT_CELL_LIMIT = 200;
                ProfitAndLossVsBudgetFinancialReport pnlVsBudgetReportClassInstance = new ProfitAndLossVsBudgetFinancialReport();
                pnlVsBudgetReportClassInstance.runReport(reportOptions);
            } catch (Exception ex) {
                dmlEx = ex;
            }

            System.assert(reportOptions.suppressZeroAmountRows, true);
        }
    }

}