@IsTest
public class RecurringAccountPayableActionTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testRecurringAccountPayableNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Recurring_Account_Payable__c rp = new Recurring_Account_Payable__c();
                insert rp;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));

        }
    }

    @IsTest
    public static void testRecurringAccountPayableWithVendorAndContact() {
        TestDataSuite testData = TestDataSuite.getInstance();
        TestDataSuite.createTestUser();
        testData.createRecurringAccountPayables();
        testData.createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;

            Recurring_Account_Payable__c rap = [SELECT Id FROM Recurring_Account_Payable__c LIMIT 1];
            rap.Employee__c = [SELECT Id FROM User LIMIT 1].Id;
            try {
                update rap;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx.getDmlMessage(0).contains(RecurringAccountPayableAction.MULTIPLE_PAYEEE_ERROR));

        }
    }

    @IsTest
    public static void testRecurringAccountPayableNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;
                try {
                    Recurring_Account_Payable__c rp = new Recurring_Account_Payable__c();
                    insert rp;
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
    public static void testStatusInactiveEndDateExceeded() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {

            Test.startTest();
            testData.recurringPayables[0].End_Date__c = Date.today();
            testData.recurringPayables[0].Next_Account_Payable_Date__c = Date.today().addMonths(1);

            testData.recurringPayables[1].End_Date__c = Date.today().addMonths(1);
            testData.recurringPayables[1].Next_Account_Payable_Date__c = Date.today();
            update testData.recurringPayables;

            List<Recurring_Account_Payable__c> recurringAccountPayables = [
                    SELECT Id, Status__c
                    FROM Recurring_Account_Payable__c
                    WHERE Id = :testData.recurringPayables[0].Id OR Id = :testData.recurringPayables[1].Id
            ];

            for(Recurring_Account_Payable__c recurringAccountPayable : recurringAccountPayables){
                if(recurringAccountPayable.Id == testData.recurringPayables[0].Id ){
                    System.assertEquals(RecurringBillingActions.RECURRING_STATUS_INACTIVE, recurringAccountPayable.Status__c);
                } else if(recurringAccountPayable.Id == testData.recurringPayables[1].Id){
                    System.assertEquals(RecurringBillingActions.RECURRING_STATUS_ACTIVE, recurringAccountPayable.Status__c);
                }

            }
            Test.stopTest();
        }
    }

}