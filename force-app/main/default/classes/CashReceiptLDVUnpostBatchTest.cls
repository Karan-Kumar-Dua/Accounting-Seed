@IsTest
private class CashReceiptLDVUnpostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testUnpostAllApproved() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Database.executeBatch(new CashReceiptLDVUnpostBatch(), 200);
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Unpost', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(3, ajr[0].Processed__c);
            System.assertEquals(3, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }

    @IsTest
    private static void testUnpostById() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .enableLDVMode();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            new PostProcessor().unpost(new List<Id> {testData.cashReceipts[0].Id, testData.cashReceipts[1].Id});
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