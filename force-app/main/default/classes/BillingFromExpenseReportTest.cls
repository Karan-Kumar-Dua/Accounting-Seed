@isTest
public class BillingFromExpenseReportTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testExpenseReportNoSelection() {
        TestDataSuite testData = TestDataSuite.getInstance().createExpenseReports();

        System.runAs(testData.users[1]) {
            for (Expense_Report__c er : testData.expenseReports) {
                er.Status__c = 'In Process';
            }

            update testData.expenseReports;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);

            System.assertEquals(BillingFromExpenseReport.NO_SELECTION_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }

    }

    @IsTest
    public static void testHandleDmlAndSecurityErrorOnBillingCreation() {

        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createExpenseReports()
            .createExpenseLines()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());

            BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);
            bfer.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bfer.bill.Billing_Cycle_Start_Date__c = bfer.bill.Date__c;
            bfer.bill.Billing_Cycle_End_Date__c = bfer.bill.Date__c + 30;

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            for (BillingFromExpenseReport.ExpenseReportWrapper item : bfer.expReportList) {
                for (BillingFromExpenseReport.ExpenseLineWrapper line : item.expLineList) {
                    line.billLine.Revenue_GL_Account__c = defaultsBySpecDevNames?.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
                }
            }

            DmlException dmlEx;
            try {
                bfer.createBillings();
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);//Dml Exception will be handled by page controller
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, ApexPages.getMessages()[0].getSummary());
        }
    }
    
    @isTest
    public static void testSetBillingRates() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createExpenseReports()
            .createExpenseLines()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);

            System.assertEquals(
                true,
                bfer.billingRates.containsKey(
                    String.valueOf(testData.expenses[0].Project_Task__c) + String.valueOf(UserInfo.getUserId())
                )
            );

            testData.billingRates[0].Project_Task__c = NULL;
            update testData.billingRates;

            setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            bfer = new BillingFromExpenseReport(setController);

            System.assertEquals(
                true,
                bfer.billingRates.containsKey(
                    String.valueOf(testData.expenses[0].Project__c) + String.valueOf(UserInfo.getUserId())
                )
            );
        }

    }

    @isTest
    public static void testCreateBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createExpenseReports()
            .createExpenseLines()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);
            bfer.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bfer.bill.Billing_Cycle_Start_Date__c = bfer.bill.Date__c;
            bfer.bill.Billing_Cycle_End_Date__c = bfer.bill.Date__c + 30;
            bfer.createBillings();

            System.assertEquals(true, bfer.isSuccess);

            for (Expense_Line__c el : [SELECT   Id,
                                                Date__c,
                                                Billed__c,
                                                Billing_Line__c,
                                                Billing_Line__r.Date__c
                                        FROM Expense_Line__c
                                        WHERE Id IN :testData.expenses
            ]) {

                System.assertEquals(true, el.Billed__c);
                System.assertNotEquals(NULL, el.Billing_Line__c);
                System.assertEquals(el.Date__c, el.Billing_Line__r.Date__c);
            }
        }

    }

    @isTest
    public static void testCreateBillingsAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createExpenseReports()
            .createExpenseLines()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);
            bfer.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bfer.bill.Billing_Cycle_Start_Date__c = bfer.bill.Date__c;
            bfer.bill.Billing_Cycle_End_Date__c = bfer.bill.Date__c + 30;
            bfer.createBillingAndPost();

            System.assertEquals(true, bfer.isSuccess);

            for (Expense_Line__c el : [SELECT   Id,
                                                Date__c,
                                                Billed__c,
                                                Billing_Line__c,
                                                Billing_Line__r.Billing__r.Status__c
                                        FROM Expense_Line__c
                                        WHERE Id IN :testData.expenses
            ]) {

                System.assertEquals(true, el.Billed__c);
                System.assertEquals('Posted', el.Billing_Line__r.Billing__r.Status__c);
            }
        }

    }

    @isTest
    public static void testCreateBillingsWithDiffLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createExpenseReports()
            .createExpenseLines()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.expenseReports[1].Ledger__c = testData.ledgers[2].Id;
            update testData.expenseReports[1];

            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);
            bfer.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bfer.bill.Billing_Cycle_Start_Date__c = bfer.bill.Date__c;
            bfer.bill.Billing_Cycle_End_Date__c = bfer.bill.Date__c + 30;

            System.assertEquals(2, bfer.expReportList.size());
            bfer.createBillings();

            System.assertEquals(true, bfer.isSuccess);
        }

    }

    @isTest
    public static void testCreateBillingsFromExpenseReport_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProjects()
                .createProjectTasks()
                .createGLAccountExpenses()
                .createExpenseReports()
                .createExpenseLines()
                .createBillingRates();

            System.runAs(testData.users[1]) {
                Test.startTest();

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Expense_Report__c expReport = testData.expenseReports[0].clone(false,true);
                expReport.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert expReport;

                List<Expense_Line__c> expLineList = new List<Expense_Line__c>();
                Expense_Line__c expLine = testData.expenses[0].clone(false,true);
                expLine.Expense_Report__c = expReport.Id;
                expLine.Billable__c = true;
                expLineList.add(expLine);

                expLine = testData.expenses[1].clone(false,true);
                expLine.Expense_Report__c = expReport.Id;
                expLine.Billable__c = true;
                expLineList.add(expLine);
                insert expLineList;

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(new Expense_Report__c[]{expReport});
                setController.setSelected(setController.getRecords());
                BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);
                bfer.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
                bfer.bill.Billing_Format__c = testData.billingFormats[0].Id;
                bfer.bill.Billing_Cycle_Start_Date__c = bfer.bill.Date__c;
                bfer.bill.Billing_Cycle_End_Date__c = bfer.bill.Date__c + 30;

                System.assertEquals(1, bfer.expReportList.size());
                bfer.createBillings();

                System.assertEquals(true, bfer.isSuccess);
                Id billId = bfer.billings.values()[0].Id;

                Billing__c bill = (Billing__c) Database.query('SELECT Id, CurrencyIsoCode FROM Billing__c WHERE Id = :billId LIMIT 1');
                System.assertEquals(newCurrencyIsoCode, (String)bill.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @isTest
    public static void testCreateSoftARCloseBillingsFromExpenseReport() {
            TestDataSuite testData = TestDataSuite.getInstance()
                .createProjects()
                .createProjectTasks()
                .createGLAccountExpenses()
                .createExpenseReports()
                .createExpenseLines()
                .createBillingRates();

            System.runAs(testData.users[1]) {
                Test.startTest();

                List<Expense_Line__c> expLineList = new List<Expense_Line__c>();
                Expense_Line__c expLine = testData.expenses[0].clone(false,true);
                expLine.Expense_Report__c = testData.expenseReports[0].Id;
                expLine.Billable__c = true;
                expLineList.add(expLine);

                expLine = testData.expenses[1].clone(false,true);
                expLine.Expense_Report__c = testData.expenseReports[0].Id;
                expLine.Billable__c = true;
                expLineList.add(expLine);
                insert expLineList;

                List<Accounting_Period__c> acctPeriods = [Select id, Close_AR__c, Start_Date__c From Accounting_Period__c 
                                                    WHERE Start_Date__c =: Date.newInstance(1991, 10, 1)];
                acctPeriods[0].Close_AR__c = true;
                UPDATE acctPeriods[0]; 

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(new List<Expense_Report__c>{testData.expenseReports[0]});
                setController.setSelected(setController.getRecords());
                BillingFromExpenseReport bfer = new BillingFromExpenseReport(setController);
                bfer.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
                bfer.bill.Billing_Format__c = testData.billingFormats[0].Id;
                bfer.bill.Billing_Cycle_Start_Date__c = bfer.bill.Date__c;
                bfer.bill.Billing_Cycle_End_Date__c = bfer.bill.Date__c + 30;

                System.assertEquals(1, bfer.expReportList.size());
                bfer.createBillingAndPost();

                System.assertEquals(FALSE, bfer.isSuccess);
                System.assertEquals(NULL, bfer.bill.Accounting_Period__c);
            }
    }
}