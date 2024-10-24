@IsTest
private class BillingCashReceiptPostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testAPIPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            List<PostResult> postResults = BillingCashReceiptPostService.postBillingCashReceipts(billingCashReceipts);
            System.assertEquals(true, postResults[0].isSuccess);
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

    @IsTest
    public static void testRefundBCRNoPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            List<PostResult> postResults = BillingCashReceiptPostService.postBillingCashReceipts(
                new List<Billing_Cash_Receipt__c>{billingCashReceipts[0]}
            );
            System.assertEquals(BillingCashReceiptPostHandler.REFUND_STATUS_CANNOT_BE_POSTED, postResults[0].errors[0].message);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

    @IsTest
    public static void testAPIPostingMixedStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 1,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND
                )
            );
            insert billingCashReceipts;
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);

            List<PostResult> postResults = BillingCashReceiptPostService.postBillingCashReceipts(billingCashReceipts);
            System.assertEquals(false, postResults[1].isSuccess);
            System.assertEquals(BillingCashReceiptPostHandler.REFUND_STATUS_CANNOT_BE_POSTED, postResults[1].errors[0].message);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[1].Id]);
            
            System.assertEquals(true, postResults[0].isSuccess);
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :billingCashReceipts[0].Id]);
        }
    }

}