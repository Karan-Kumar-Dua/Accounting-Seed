@IsTest
private class APDisbursementLDVPostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPostAllApproved() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false)
            .disableAutoPostSourceDocuments();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );
            insert testApDisbursement;
            Database.executeBatch(new APDisbursementLDVPostBatch(new Set<Id> {testApDisbursement.Id}), 200);
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Post', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(1, ajr[0].Processed__c);
            System.assertEquals(1, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }

    @IsTest
    private static void testPostById() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false)
            .disableAutoPostSourceDocuments();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.enableLDVMode();
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );
            insert testApDisbursement;
            new PostProcessor().post(new List<Id> {testApDisbursement.Id});
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Post', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(1, ajr[0].Processed__c);
            System.assertEquals(1, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }
}