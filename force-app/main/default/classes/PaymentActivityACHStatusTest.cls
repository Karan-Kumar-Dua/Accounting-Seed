@IsTest
private class PaymentActivityACHStatusTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testCountPendingPayments() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Integer countPA = PaymentActivityACHStatus.countPendingPayments();
            System.assertEquals(0, countPA);
        }
    }

    @IsTest
    private static void testStartStatusProcessing() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Boolean result = PaymentActivityACHStatus.startStatusProcessing();
            System.assertEquals(true, result);
        }
    }
}