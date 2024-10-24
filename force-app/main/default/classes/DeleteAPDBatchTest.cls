@IsTest
private class DeleteAPDBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testDeleteAPDAndCDJob() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();

        System.runAs(testData.users[1]) {
            Id cdId = testData.cashDisbursements[0].Id;
            //Check total AP Disbursement Records
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());

            Set<Id> apdIds = new Map<Id, AP_Disbursement__c> ([SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId]).keySet();
            Database.executeBatch(new DeleteAPDBatch(apdIds, [SELECT Id,Status__c FROM Cash_Disbursement__c WHERE Id = :cdId][0]), 100);
            Test.stopTest();

            System.assertEquals(0, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :cdId].size());
            System.assertEquals(0, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());
        }
    }

    @IsTest
    private static void testDeleteOnlyAPDJob() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();
        System.runAs(testData.users[1]) {
            Id cdId = testData.cashDisbursements[0].Id;
            //Check total AP Disbursement Records
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());

            Set<Id> apdIds = new Map<Id, AP_Disbursement__c> ([SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId]).keySet();
            Database.executeBatch(new DeleteAPDBatch(apdIds, null), 100);
            Test.stopTest();

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :cdId].size());
            System.assertEquals(0, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());
        }
    }
}