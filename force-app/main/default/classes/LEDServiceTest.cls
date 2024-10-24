@IsTest
private class LEDServiceTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    static void testBehavior() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            System.assert(LEDService.sendData() != null);
            Test.stopTest();
        }
    }
}