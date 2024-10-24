@IsTest
private class CashDisbursementLDVPostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPostAllApproved() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Database.executeBatch(new CashDisbursementLDVPostBatch(), 200);
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Post', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(9, ajr[0].Processed__c);
            System.assertEquals(9, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }

    @IsTest
    private static void testPostById() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(false)
            .enableLDVMode();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            new PostProcessor().post(new List<Id> {testData.cashDisbursements[0].Id, testData.cashDisbursements[1].Id});
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Post', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(2, ajr[0].Processed__c);
            System.assertEquals(2, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }
}