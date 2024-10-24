@IsTest
public class ExpenseLineActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testExpenseGlAccountIsRequiredOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports();

        System.runAs(testData.users.get(1)) {
            Expense_Line__c testExpenseLine = new Expense_Line__c(
                Date__c = System.today(),
                Expense_Report__c = testData.expenseReports.get(0).Id,
                Project__c = testData.projects.get(0).Id,
                Project_Task__c = testData.projectTasks.get(0).Id,
                Expense_GL_Account__c = NULL,
                Miles__c = 50,
                Amount__c = 0
            );

            DmlException dmlEx;
            try {
                insert testExpenseLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testExpenseGlAccountIsRequiredOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports();

        System.runAs(testData.users.get(1)) {
            Expense_Line__c testExpenseLine = new Expense_Line__c(
                Date__c = System.today(),
                Expense_Report__c = testData.expenseReports.get(0).Id,
                Project__c = testData.projects.get(0).Id,
                Project_Task__c = testData.projectTasks.get(0).Id,
                Expense_GL_Account__c = testData.glAccountsExpense.get(2).Id,
                Miles__c = 50,
                Amount__c = 0
            );

            DmlException dmlEx;
            try {
                insert testExpenseLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            //UPDATE
            testExpenseLine.Expense_GL_Account__c = NULL;
            dmlEx = NULL;
            try {
                update testExpenseLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPopulateCCVendorPayableField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Expense_Line__c> testLines = [SELECT Id, Credit_Card_Vendor_Payable__c FROM Expense_Line__c WHERE Credit_Card_Vendor__c != NULL];
            System.assertEquals(2, testLines.size());
            System.assertEquals(true, testLines.get(0).Credit_Card_Vendor_Payable__c);
            System.assertEquals(true, testLines.get(1).Credit_Card_Vendor_Payable__c);
        }
    }

   @IsTest
    public static void testCalculateMileageExcludeIfNoMilesDefinedExpenseLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Expense_Line__c expLineClone = testData.expenses[0].clone(false,true);
            expLineClone.Miles__c = NULL;
            expLineClone.Expense_GL_Account__c = testData.glAccounts.get(16).Id;
            insert expLineClone;

            System.assertEquals(
                0, [
                    SELECT Amount__c
                    FROM Expense_Line__c
                    WHERE Id = :expLineClone.Id
                ].Amount__c
            );
        }
    }
    
    @IsTest
    public static void testValidateCCVendorField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Line__c testLine = new Expense_Line__c(
                Date__c = System.today(),
                Expense_Report__c = testData.expenseReports.get(0).Id,
                Project__c = testData.projects.get(0).Id,
                Project_Task__c = testData.projectTasks.get(0).Id,
                Expense_GL_Account__c = testData.glAccountsExpense.get(2).Id,
                Miles__c = 50,
                Amount__c = 50,
                Employee_Reimburse__c = true,
                Credit_Card_Vendor__c = testData.accounts[0].Id
            );

            DMLException dmlEx;
            try {
                insert testLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(ExpenseLineActions.EMPLOYEE_CREDIT_CARD_VENDOR_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testValidateMandatoryMileageRate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            testData.glAccountsExpense.get(2).Mileage_Account__c = true;
            testData.glAccountsExpense.get(2).Mileage_Rate__c = 10;

            update testData.glAccountsExpense.get(2);

            Expense_Line__c testLine = new Expense_Line__c(
                Date__c = System.today(),
                Expense_Report__c = testData.expenseReports.get(0).Id,
                Project__c = testData.projects.get(0).Id,
                Project_Task__c = testData.projectTasks.get(0).Id,
                Expense_GL_Account__c = testData.glAccountsExpense.get(2).Id,
                Amount__c = 50,
                Employee_Reimburse__c = true
            );

            DMLException dmlEx;
            try {
                insert testLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(ExpenseLineActions.MILEAGE_RATE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testCalculateMileageSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            System.assertEquals(
                26, [
                    SELECT Amount__c
                    FROM Expense_Line__c
                    WHERE Id = :testData.expenses[0].Id
                ].Amount__c
            );
        }
    }

    @IsTest
    public static void testSetExpenseLinesFromBillingsAndSetTimeCardLineNonBilled() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createBillings()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Integer index = 0;
            while (index < testData.expenses.size()) {
                testData.expenses[index].Billing_Line__c = testData.billingLines[index].Id;
                testData.expenses[index].Billed__c = true;
                index++;
            }
            update testData.expenses;
            ExpenseLineActions.setExpenseLinesFromBillings(new Map<Id,Billing__c>{testData.billings[0].Id => testData.billings[0]});
            System.assertEquals(2, ExpenseLineActions.billExpenseLineIds.size());

            delete testData.billings;
            for (Expense_Line__c el : [SELECT Id, Billed__c FROM Expense_Line__c WHERE Id IN :testData.expenses]) {
                System.assertEquals(false, el.Billed__c);
            }
        }
    }

    @IsTest
    public static void testSetExpenseLinesFromAccountPayablesAndSetExpenseLineUnpaid() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createPayables()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Integer index = 0;
            while (index < testData.expenses.size()) {
                testData.expenses[index].Account_Payable_Line__c = testData.payableLines[index].Id;
                testData.expenses[index].Vendor_Employee_Paid__c = true;
                index++;
            }
            update testData.expenses;

            for (Expense_Line__c el : [SELECT Id, Vendor_Employee_Paid__c
                                        FROM Expense_Line__c
                                        WHERE Id IN :testData.expenses
            ]) {

                System.assertEquals(true, el.Vendor_Employee_Paid__c);
            }

            ExpenseLineActions.setExpenseLinesFromAccountPayables(
                new Map<Id,Account_Payable__c>{
                    testData.payables[0].Id => testData.payables[0]
                }
            );
            System.assertEquals(3, ExpenseLineActions.payableExpenseLineIds.size());

            delete testData.payableLines[0];
            System.assertEquals(
                false, [
                    SELECT Id, Vendor_Employee_Paid__c
                    FROM Expense_Line__c
                    WHERE Id = :testData.expenses[0].Id
                ].Vendor_Employee_Paid__c
            );
            delete testData.payables;

            for (Expense_Line__c el : [SELECT Id, Vendor_Employee_Paid__c
                                        FROM Expense_Line__c
                                        WHERE Id IN :testData.expenses
            ]) {

                System.assertEquals(false, el.Vendor_Employee_Paid__c);
            }
        }
    }


    @isTest
    public static void testExpenseLineIsoCodeSetFromParentInsert_MC() {
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

                List<Expense_Line__c> elList = new List<Expense_Line__c>();

                Expense_Report__c cloneER = testData.expenseReports[0].clone(false,true);
                cloneER.put('CurrencyIsoCode',newCurrencyIsoCode);
                cloneER.Employee__c = testData.users[1].Id;
                insert cloneER;

                cloneER = (Expense_Report__c) Database.query('SELECT Id, CurrencyIsoCode FROM Expense_Report__c WHERE Id = \'' + cloneER.Id + '\' LIMIT 1');

                System.assertEquals(newCurrencyIsoCode,(String) cloneER.get('CurrencyIsoCode'));

                Id expenseReportId;
                Integer counter = 0;
                for (Expense_Line__c el : testData.expenses) {
                    Expense_Line__c cloneEl = el.clone(false);
                    cloneEl.Expense_Report__c = cloneER.Id;
                    cloneEl.Billable__c = true;
                    elList.add(cloneEL);
                }

                insert elList;

                for (Expense_Line__c el : (Expense_Line__c[]) Database.query('SELECT Id, Date__c, CurrencyIsoCode, ' +
                                                    'Expense_Report__r.CurrencyIsoCode ' +
                                                    'FROM Expense_Line__c ' +
                                                    'WHERE Id IN :elList')) {

                    System.assertEquals(newCurrencyIsoCode, (String) el.getSObject('Expense_Report__r').get('CurrencyIsoCode'));
                    System.assertEquals(newCurrencyIsoCode, (String) el.get('CurrencyIsoCode'));
                    System.assertEquals((String) el.getSObject('Expense_Report__r').get('CurrencyIsoCode'), (String) el.get('CurrencyIsoCode'));
                }
            }
        }
        catch (Exception ex) {

        }
    }

    @isTest
    public static void testExpenseLineIsoCodeSetFromParentUpdate_MC() {
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

                List<Expense_Line__c> elList = new List<Expense_Line__c>();

                Expense_Report__c cloneER = testData.expenseReports[0].clone(false,true);
                cloneER.put('CurrencyIsoCode',newCurrencyIsoCode);
                cloneER.Employee__c = testData.users[1].Id;
                insert cloneER;

                cloneER = (Expense_Report__c) Database.query('SELECT Id, CurrencyIsoCode FROM Expense_Report__c WHERE Id = \'' + cloneER.Id + '\' LIMIT 1');

                System.assertEquals(newCurrencyIsoCode,(String) cloneER.get('CurrencyIsoCode'));

                Id expenseReportId;
                Integer counter = 0;
                for (Expense_Line__c el : testData.expenses) {
                    Expense_Line__c cloneEl = el.clone(false);
                    cloneEl.Expense_Report__c = cloneER.Id;
                    cloneEl.Billable__c = true;
                    elList.add(cloneEL);
                }

                insert elList;

                for (Expense_Line__c el : elList) {
                    el.put('CurrencyIsoCode',MultiCurrencyHandler.CORPORATE_CURRENCY);
                }

                update elList;

                for (Expense_Line__c el : (Expense_Line__c[]) Database.query('SELECT Id, Date__c, CurrencyIsoCode, ' +
                                                    'Expense_Report__r.CurrencyIsoCode ' +
                                                    'FROM Expense_Line__c ' +
                                                    'WHERE Id IN :elList')) {

                    System.assertEquals(newCurrencyIsoCode, (String) el.getSObject('Expense_Report__r').get('CurrencyIsoCode'));
                    System.assertEquals(newCurrencyIsoCode, (String) el.get('CurrencyIsoCode'));
                    System.assertEquals((String) el.getSObject('Expense_Report__r').get('CurrencyIsoCode'), (String) el.get('CurrencyIsoCode'));
                }
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testExpenseLineNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Expense_Line__c expenseLine = new Expense_Line__c();
                insert expenseLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

}