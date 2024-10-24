@IsTest
public class AccountPayableFromExpenseReportTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testExpenseNoSelection() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createExpenseReports();

        System.runAs(testData.users[1]) {
            for (Expense_Report__c er : testData.expenseReports) {
                er.Status__c = 'In Process';
            }

            update testData.expenseReports;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                testData.expenseReports
            );
            setController.setSelected(setController.getRecords());
            AccountPayableFromExpenseReport bfer = new AccountPayableFromExpenseReport(setController);

            System.assertEquals(
                AccountPayableFromExpenseReport.NO_SELECTION_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getDetail()
            );
        }

    }
    
    @IsTest
    public static void testCreateAccountsPayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Integer eCount = 0;

            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
                el.Internal_Comment__c = 'Test Internal ' + eCount;
                el.Invoice_Comment__c = 'Test Invoice ' + eCount;
                eCount++;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                testData.expenseReports
            );
            setController.setSelected(setController.getRecords());
            AccountPayableFromExpenseReport bfer = new AccountPayableFromExpenseReport(setController);
            bfer.acctPayable.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.acctPayable.Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.createAccountsPayable();

            System.assertEquals(true, bfer.isSuccess);

            for (Expense_Line__c el : [SELECT   Id,
                                                Date__c,
                                                Vendor_Employee_Paid__c,
                                                Invoice_Comment__c,
                                                Internal_Comment__c,
                                                Account_Payable_Line__c,
                                                Account_Payable_Line__r.Date__c,
                                                Account_Payable_Line__r.Invoice_Comment__c,
                                                Account_Payable_Line__r.Internal_Comment__c
                                        FROM Expense_Line__c
                                        WHERE Id IN :testData.expenses
            ]) {

                System.assertEquals(true, el.Vendor_Employee_Paid__c);
                System.assertNotEquals(NULL, el.Account_Payable_Line__c);
                System.assertEquals(el.Invoice_Comment__c, el.Account_Payable_Line__r.Invoice_Comment__c);
                System.assertEquals(el.Internal_Comment__c, el.Account_Payable_Line__r.Internal_Comment__c);
            }
        }

    }

    @IsTest
    public static void testCreateAccountsPayableAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Integer eCount = 0;

            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
                el.Internal_Comment__c = 'Test Internal ' + eCount;
                el.Invoice_Comment__c = 'Test Invoice ' + eCount;
                eCount++;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            AccountPayableFromExpenseReport bfer = new AccountPayableFromExpenseReport(setController);
            bfer.acctPayable.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.acctPayable.Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.createAccountsPayableAndPost();

            System.assertEquals(true, bfer.isSuccess);

            for (Expense_Line__c el : [SELECT   Id,
                                                Date__c,
                                                Vendor_Employee_Paid__c,
                                                Invoice_Comment__c,
                                                Internal_Comment__c,
                                                Account_Payable_Line__c,
                                                Account_Payable_Line__r.Date__c,
                                                Account_Payable_Line__r.Invoice_Comment__c,
                                                Account_Payable_Line__r.Internal_Comment__c,
                                                Account_Payable_Line__r.Account_Payable__r.Status__c
                                        FROM Expense_Line__c
                                        WHERE Id IN :testData.expenses
            ]) {

                System.assertEquals(true, el.Vendor_Employee_Paid__c);
                System.assertNotEquals(NULL, el.Account_Payable_Line__c);
                System.assertEquals(el.Invoice_Comment__c, el.Account_Payable_Line__r.Invoice_Comment__c);
                System.assertEquals(el.Internal_Comment__c, el.Account_Payable_Line__r.Internal_Comment__c);
                System.assertEquals('Posted', el.Account_Payable_Line__r.Account_Payable__r.Status__c);
            }
        }

    }

    @IsTest
    public static void testCreateAccountsPayableWithDiffLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.expenseReports[1].Ledger__c = testData.ledgers[2].Id;
            update testData.expenseReports[1];

            Integer eCount = 0;

            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
                el.Internal_Comment__c = 'Test Internal ' + eCount;
                el.Invoice_Comment__c = 'Test Invoice ' + eCount;
                eCount++;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            AccountPayableFromExpenseReport bfer = new AccountPayableFromExpenseReport(setController);
            bfer.acctPayable.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.acctPayable.Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);

            System.assertEquals(3, bfer.expReportList.size());

            bfer.createAccountsPayable();

            System.assertEquals(true, bfer.isSuccess);
        }

    }
    @isTest
    public static void testCreatePayableFromExpenseReport_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProjects()
                .createProjectTasks()
                .createGLAccountExpenses()
                .createExpenseReports()
                .createExpenseLines();

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
                expLine.Employee_Reimburse__c = true;
                expLineList.add(expLine);

                expLine = testData.expenses[1].clone(false,true);
                expLine.Expense_Report__c = expReport.Id;
                expLine.Employee_Reimburse__c = true;
                expLineList.add(expLine);
                insert expLineList;

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(new Expense_Report__c[]{expReport});
                setController.setSelected(setController.getRecords());
                setController.setSelected(setController.getRecords());
                AccountPayableFromExpenseReport bfer = new AccountPayableFromExpenseReport(setController);
                bfer.acctPayable.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
                bfer.acctPayable.Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);

                System.assertEquals(1, bfer.expReportList.size());
                bfer.createAccountsPayable();

                System.assertEquals(true, bfer.isSuccess);
                Id apId = bfer.acctPayables.values()[0].Id;

                Account_Payable__c ap = (Account_Payable__c) Database.query('SELECT Id, CurrencyIsoCode FROM Account_Payable__c WHERE Id = :apId LIMIT 1');
                System.assertEquals(newCurrencyIsoCode, (String)ap.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testCreateSoftAPCloseAccountsPayableAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest(); 

            List<Accounting_Period__c> acctPeriods = [Select id, Close_AP__c, Start_Date__c From Accounting_Period__c 
                                                    WHERE Start_Date__c =: Date.newInstance(1991, 10, 1)];
            acctPeriods[0].Close_AP__c = true;
            UPDATE acctPeriods[0]; 

            Integer eCount = 0;
          
            for (Expense_Line__c el : testData.expenses) {
                el.Billable__c = true;
                el.Internal_Comment__c = 'Test Internal ' + eCount;
                el.Invoice_Comment__c = 'Test Invoice ' + eCount;
                eCount++;
            }

            update testData.expenses;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.expenseReports);
            setController.setSelected(setController.getRecords());
            AccountPayableFromExpenseReport bfer = new AccountPayableFromExpenseReport(setController);
            bfer.acctPayable.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.acctPayable.Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bfer.createAccountsPayableAndPost();

            System.assertEquals(false, bfer.isSuccess);
            System.assertEquals(NULL, bfer.acctPayable.Accounting_Period__c);
        }

    }
}