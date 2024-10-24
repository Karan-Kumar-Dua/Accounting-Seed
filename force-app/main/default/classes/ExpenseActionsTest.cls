@IsTest
public class ExpenseActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPreventInsertExpenseReportWithoutLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Report__c testExpReport = testData.expenseReports.get(0).clone();
            testExpReport.Ledger__c = NULL;

            testData.ledgerSettings.Ledger_Id__c = FinancialSuiteUtils.getFakeId(Ledger_Custom_Settings__c.SObjectType);
            update testData.ledgerSettings;

            DMLException dmlEx;
            try {
                insert testExpReport;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventUpdateExpenseReportWithoutLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Report__c testExpReport = testData.expenseReports.get(0);
            testExpReport.Ledger__c = NULL;

            AccountingSettingsActions.isPreventUpdateOverride = true;
            testData.settings.Legacy_Default_Ledger__c = NULL;
            update testData.settings;
            AccountingSettingsActions.isPreventUpdateOverride = false;

            DMLException dmlEx;
            try {
                update testExpReport;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventInsertExpenseReportWithoutEmployee() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Report__c testExpReport = testData.expenseReports.get(0).clone();
            testExpReport.Employee__c = NULL;

            DMLException dmlEx;
            try {
                insert testExpReport;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventUpdateExpenseReportWithoutEmployee() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGLAccountExpenses()
            .createProjects()
            .createProjectTasks()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            Expense_Report__c testExpReport = testData.expenseReports.get(0);
            testExpReport.Employee__c = NULL;

            DMLException dmlEx;
            try {
                update testExpReport;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testExpenseReportNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Expense_Report__c er = new Expense_Report__c();
                insert er;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testExpenseReportNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users[1]) {
                DMLException dmlEx;
                try {
                    Expense_Report__c er = new Expense_Report__c();
                    insert er;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testSetDefaultStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            String defaultStatusER;
            for (Schema.PicklistEntry pe : Expense_Report__c.getSObjectType()
                                                .getDescribe().fields.getMap()
                                                .get(GlobalVariables.PACKAGE_QUALIFIER + 'Status__c')
                                                .getDescribe().getPicklistValues()) {

                if (pe.isDefaultValue()) {
                    defaultStatusER = pe.getValue();
                    break;
                }
            }

            //test when Status == NULL
            Expense_Report__c expenseReport = new Expense_Report__c(
                Name = 'TestER',
                Employee__c = UserInfo.getUserId()
            );
            insert expenseReport;
            System.assertEquals(
                defaultStatusER, [
                    SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :expenseReport.Id
                ].Status__c
            );

            //test when Status was set to some undefined value
            Expense_Report__c expenseReport2 = new Expense_Report__c(
                Name = 'TestER',
                Employee__c = UserInfo.getUserId(),
                Status__c = 'Not Defined Status Value'
            );
            insert expenseReport2;
            System.assertEquals(
                defaultStatusER, [
                    SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :expenseReport2.Id
                ].Status__c
            );

            //test when Status was directly set to one of pre-defined values
            Expense_Report__c expenseReport3 = new Expense_Report__c(
                Name = 'TestER',
                Employee__c = UserInfo.getUserId(),
                Status__c = 'Approved'
            );
            insert expenseReport3;
            System.assertEquals(
                'Approved', [
                    SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :expenseReport3.Id
                ].Status__c
            );

            //test update to one of pre-defined values
            expenseReport.Status__c = 'Approved';
            update expenseReport;
            System.assertEquals(
                'Approved', [
                    SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :expenseReport.Id
                ].Status__c
            );

            //test clear Status on update
            expenseReport2.Status__c = NULL;
            update expenseReport2;
            System.assertEquals(
                defaultStatusER, [
                    SELECT Id, Status__c FROM Expense_Report__c WHERE Id = :expenseReport2.Id
                ].Status__c
            );
        }
    }

    @IsTest
    public static void testPreventUpdateCurrency_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createGLAccountExpenses()
                .createProjects()
                .createProjectTasks()
                .createExpenseReports()
                .createExpenseLines();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Expense_Report__c testExpRep = testData.expenseReports.get(0);
                testExpRep.put('CurrencyIsoCode', newCurrencyIsoCode);

                DmlException dmlEx;
                try {
                    update testExpRep;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(String.format(
                    SObjectActions.UPDATE_ERROR,
                    new List<String>{
                        FinancialSuiteUtils.formatFieldStrings(
                            Expense_Report__c.SObjectType,
                            ExpenseActions.nonUpdateFields
                        )
                    }), dmlEx.getDmlMessage(0));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }
}