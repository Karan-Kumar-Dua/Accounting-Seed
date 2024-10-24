@IsTest
private class AccountPayableLDVUnpostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testUnpostAllApproved() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Database.executeBatch(new AccountPayableLDVUnpostBatch(), 200);
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Unpost', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(8, ajr[0].Processed__c);
            System.assertEquals(8, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }

    @IsTest
    private static void testUnpostById() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true).enableLDVMode();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            new PostProcessor().unpost(new List<Id> {testData.payables[0].Id, testData.payables[1].Id});
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Unpost', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(2, ajr[0].Processed__c);
            System.assertEquals(2, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }
}