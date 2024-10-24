@IsTest
public with sharing class VoidTransactionUpdateCRsBatchTest {
    
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testUpdatePaymentActivityStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enableAutoPostSourceDocuments()
            .createPaymentProcessors()
            .createCashReceipts();
        
        System.runAs(testData.users.get(1)) {
            Payment_Method__c pm = new Payment_Method__c(
                Type__c = 'Visa',
                Status__c = 'Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2099',
                Last_Four_Digits__c = '4444',
                External_Id__c = 'stripe-card-1',
                Customer__c = testData.accounts[0].Id,
                Default__c = true,
                Payment_Processor__c = testData.paymentProcessors[0].Id
            );
            insert pm;

            Cash_Receipt__c cr1 = testData.cashReceipts[0];
            Cash_Receipt__c cr2 = testData.cashReceipts[1];

            Payment_Activity__c pa1 = new Payment_Activity__c(
                Cash_Receipt__c = cr1.Id,
                Status__c = PaymentActivityHelper.ERROR_STATUS,
                Amount__c = 1000,
                Payment_Method__c = pm.Id
            );
            Payment_Activity__c pa2 = new Payment_Activity__c(
                Cash_Receipt__c = cr2.Id,
                Status__c = PaymentActivityHelper.PENDING_STATUS,
                Amount__c = 1000,
                Payment_Method__c = pm.Id
            );
            insert new List<Payment_Activity__c>{pa1, pa2};
            
            Test.startTest();
            CashReceiptVoidHelper.VoidData voidData1 = new CashReceiptVoidHelper.VoidData();
            voidData1.cashReceiptId = cr1.Id;
            voidData1.voidReceiptDate = cr1.Receipt_Date__c.addDays(1);
            voidData1.paymentId = pa1.Id;
            CashReceiptVoidHelper.VoidData voidData2 = new CashReceiptVoidHelper.VoidData();
            voidData2.cashReceiptId = cr2.Id;
            voidData2.voidReceiptDate = cr2.Receipt_Date__c.addDays(1);
            voidData2.paymentId = pa2.Id;
            Map<Id,CashReceiptVoidHelper.VoidData> crWithVoidData = new Map<Id,CashReceiptVoidHelper.VoidData>{cr1.Id => voidData1, cr2.Id => voidData2};
            Set<Id> failedCrIds = new Set<Id>();
            Map<Id,Set<Id>> bcrsWithCrId = new Map<Id,Set<Id>>{cr1.Id => new Set<Id>(), cr2.Id => new Set<Id>()};
            VoidTransactionUpdateCashReceiptsBatch job = new VoidTransactionUpdateCashReceiptsBatch(crWithVoidData, failedCrIds, bcrsWithCrId, VoidExternalTransactionBatch.getLogger());
            Database.executeBatch(job);
            Test.stopTest();

            Assert.areEqual(PaymentActivityHelper.ERROR_STATUS, [SELECT Status__c FROM Payment_Activity__c WHERE Id = :pa1.Id].Status__c);
            Assert.areEqual(PaymentActivityHelper.VOID_STATUS, [SELECT Status__c FROM Payment_Activity__c WHERE Id = :pa2.Id].Status__c);
        }
    }

}