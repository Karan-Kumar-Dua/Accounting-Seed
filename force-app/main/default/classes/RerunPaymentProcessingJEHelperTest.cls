@IsTest
public with sharing class RerunPaymentProcessingJEHelperTest {
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testRunBatchJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            List<Payment_Activity__c> activities = new List<Payment_Activity__c>();

            Payment_Processor__c pp = testData.paymentProcessors[2];
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;
                       
            Accounting_Period__c  period = new Accounting_Period__c(
                Name = '2023-01',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2023, 1, 31),
                Status__c = 'Open'
            );
            
            INSERT period;

            Bank_Deposit__c bankDeposit = new Bank_Deposit__c(
                Deposit_Date__c = Date.newInstance(2023, 1, 2),
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1',
                Merchant_Batch_Id__c = '1234'
            );

            INSERT bankDeposit;

            cashReceipts.add(new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = Date.newInstance(2023, 1, 1),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '1234',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Payment_Processor__c = pp.Id,
                        Bank_Deposit__c = bankDeposit.Id
                    ));

            cashReceipts.add(new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 40,
                Status__c = 'Approved',
                Receipt_Date__c = Date.newInstance(2023, 1, 1),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '4567',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Payment_Processor__c = pp.Id,
                Bank_Deposit__c = bankDeposit.Id
            ));
            INSERT cashReceipts;
            
            TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Bank_Deposit__c, Cash_Receipt__c.Status__c});
                    
            
			cashReceipts[0].Bank_Deposit__c = bankDeposit.Id;
            cashReceipts[1].Bank_Deposit__c = bankDeposit.Id;
            
            UPDATE cashReceipts;
            
            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[0].Id, Fee__c = 10));

            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[1].Id, Fee__c = 23));

            INSERT activities;

			List<Payment_Activity__C> ac = [SELECT Id, Cash_Receipt__r.Bank_Deposit__c, Cash_Receipt__r.Payment_Processor__r.Type__c  FROM PAYMENT_ACTIVITY__c];

            Test.startTest();
            RerunPaymentProcessingJEHelper.runBatchJob();
            Test.stopTest();
            Assert.areEqual(0,[SELECT Id FROM Journal_Entry__c].size());
            Assert.areEqual(0,[SELECT Id FROM Journal_Entry_Line__c].size());
        }
    }
}