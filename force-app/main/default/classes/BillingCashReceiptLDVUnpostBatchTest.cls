@IsTest
private class BillingCashReceiptLDVUnpostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testUnpostAllApproved() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true).createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings[0].Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Applied_Amount__c = 450
            );
            insert bcr;
            Database.executeBatch(new BillingCashReceiptLDVUnpostBatch(new Set<Id> {bcr.Id}), 200);
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Unpost', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(1, ajr[0].Processed__c);
            System.assertEquals(1, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }

    @IsTest
    private static void testUnpostById() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings[0].Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Applied_Amount__c = 450
            );
            insert bcr;
            testData.enableLDVMode();
            new PostProcessor().unpost(new List<Id> {bcr.Id});
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Unpost', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(1, ajr[0].Processed__c);
            System.assertEquals(1, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }
}