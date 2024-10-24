@isTest
public class RecurringBillingActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testRequiredFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            Recurring_Billing__c rBill = testData.recurringBillings[0].clone(false, true);
            rBill.Billing_Frequency__c = NULL;

            try {
                insert rBill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals('REQUIRED_FIELD_MISSING', dmlEx.getDmlStatusCode(0));

            dmlEx = NULL;
            rBill = testData.recurringBillings[0].clone(false, true);
            rBill.Status__c = NULL;

            try {
                insert rBill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDMLMessage(0));
        }

    }
    
    @isTest
    public static void testRequiredFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.recurringBillings[0].Billing_Frequency__c = NULL;

            DMLException dmlEx;
            try {
                update testData.recurringBillings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals('REQUIRED_FIELD_MISSING', dmlEx.getDmlStatusCode(0));

            testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
            testData.recurringBillings[0].Status__c = NULL;

            dmlEx = NULL;
            try {
                update testData.recurringBillings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @isTest    
    public static void testPreventInsertMaxLineCountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Recurring_Billing_Line__c> lineList = new List<Recurring_Billing_Line__c>();
            for (Integer i = 0; i < RecurringBillingActions.MAX_LINE_COUNT; i++) {
                lineList.add(testData.recurringBillingLines[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                insert lineList;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SObjectActions.MAX_LINE_ERROR, new List<String> {String.valueOf(RecurringBillingActions.MAX_LINE_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @isTest    
    public static void testPreventInsertMaxLineCountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Recurring_Billing_Line__c> lineList = new List<Recurring_Billing_Line__c>();
            for (Integer i = 0; i < RecurringBillingActions.MAX_LINE_COUNT - 100; i++) {
                lineList.add(testData.recurringBillingLines[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                insert lineList;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }

    @IsTest
    public static void testRecurringBillingNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Recurring_Billing__c rb = new Recurring_Billing__c();

                try {
                    insert rb;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testRecurringBillingNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Recurring_Billing__c rb = new Recurring_Billing__c();
                insert rb;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testRequireRevenueGLAccountInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        List<GL_Account_Default__c> defaults = [
                SELECT Id
                FROM GL_Account_Default__c
                WHERE GL_Account_Specification__c =: GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT
        ];
        delete defaults;
        testData.createRecurringBilling()
                .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Recurring_Billing_Line__c recurringBL = testData.recurringBillingLines[0].clone(false, true);
            recurringBL.Product__c = NULL;
            recurringBL.Revenue_GL_Account__c = NULL;

            DMLException dmlEx;
            try {
                insert recurringBL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testRequireRevenueGLAccountUpdatetError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringBilling()
                .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            delete testData.settings;
            AccountingSettingsHandler.acctSeedSettings = NULL;

            testData.recurringBillingLines[0].Product__c = NULL;
            testData.recurringBillingLines[0].Revenue_GL_Account__c = NULL;

            DMLException dmlEx;
            try {
                update testData.recurringBillingLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testsetStatusInactiveEndDateExceeded() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringBilling()
                .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
           
            Test.startTest();
            testData.recurringBillings[0].End_Date__c = Date.today();
            testData.recurringBillings[0].Next_Billing_Date__c = Date.today().addMonths(1);

            testData.recurringBillings[1].End_Date__c = Date.today().addMonths(1);
            testData.recurringBillings[1].Next_Billing_Date__c = Date.today();
            update testData.recurringBillings;

            List<Recurring_Billing__c> rBills = [SELECT Id, Status__c FROM Recurring_Billing__c WHERE Id = :testData.recurringBillings[0].Id OR Id = :testData.recurringBillings[1].Id];

            for(Recurring_Billing__c rBill : rBills){
                if(rBill.Id == testData.recurringBillings[0].Id ){
                    System.assertEquals(RecurringBillingActions.RECURRING_STATUS_INACTIVE, rBill.Status__c);
                } else if(rBill.Id == testData.recurringBillings[1].Id){
                    System.assertEquals(RecurringBillingActions.RECURRING_STATUS_ACTIVE, rBill.Status__c);
                }

            }
            
        }

    }

}