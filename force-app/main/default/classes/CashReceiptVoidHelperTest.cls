@IsTest
public with sharing class CashReceiptVoidHelperTest {
    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    public static void testGetIsCashFlowStatementEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashFlowCategories(false)
                .createCashReceipts()
                .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account customer = testData.accounts.get(1);
            Payment_Processor__c paymentProcessor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
                Account__c = customer.Id, 
                Processor__c = paymentProcessor.Id, 
                External_Id__c = '123'
            );
            insert ppc;

            Payment_Method__c paymentMethod = new Payment_Method__c(
                Customer__c = customer.Id, 
                Payment_Processor__c = paymentProcessor.Id, 
                External_Id__c = '123',
                Last_Four_Digits__c = '4242',
                Payment_Method_Type__c = 'Credit Card',
                Status__c='Active',
                Expiration_Month__c = '12',
                Expiration_Year__c = '2224',
                Type__c = 'Visa',
                Default__c = true
            );
            insert paymentMethod;

            Payment_Activity__c pa = new Payment_Activity__c(
                    Amount__c = 100,
                    Payment_Method__c = paymentMethod.Id,
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Merchant_Reference__c = '1234'
                );
            INSERT pa;

            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Assert.areEqual(false, settings.Enable_Cash_Flow_Statement__c);

            settings.Enable_Cash_Flow_Statement__c = true;
            AccountingSettingsHelper.save(settings);  

            CashReceiptVoidHelper.VoidDetails details = CashReceiptVoidHelper.getVoidDetails();
            Assert.areEqual(true, details.isCashFlowStatementEnabled);
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCRRecordSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                    .createCashReceipts()
                    .createCashFlowCategories(false)
                    .createBillings(false)
                    .createPaymentProcessors();

        System.runAs(testData.users[1]) {

            Test.startTest();
            Payment_Processor__c pp = testData.paymentProcessors[3];

            Cash_Receipt__c cReceipt = testData.cashReceipts[0];

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Bank Account', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Default__c=true, Bank_Account_Type__c='Individual');
            INSERT pm;

            Payment_Activity__c activity = new Payment_Activity__c(
                Amount__c = cReceipt.Amount__c,
                Payment_Method__c = pm.Id,
                Status__c = 'Pending',
                Cash_Receipt__c = cReceipt.Id,
                Merchant_Reference__c = cReceipt.Payment_Reference__c
            );

            INSERT activity;

            cReceipt.Status__c = 'Posted';
            cReceipt.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            cReceipt.Payment_Processor__c = pp.Id;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c
                }
            );
            update cReceipt;     
            
            List<Transaction__c> controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
            ];
           //initially there should be only 2 transactions
            Assert.areEqual(2, controlledTrans.size());
            
            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts[0].Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = testData.cashFlowCategories[0].Id;
            voidData.paymentId = cReceipt.Payment_Reference__c;

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date().addDays(-10);
            testAccountingPeriod.End_Date__c = System.now().date();
            testAccountingPeriod.Status__c = 'Open';
            
            UPDATE testAccountingPeriod;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testAccountingPeriod.Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = cReceipt.Id;
            bcr.Applied_Amount__c = 1;
            bcr.Adjustment_Amount__c = 1;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            INSERT bcr;

            //make sure there is only one bcr record exist
            Assert.areEqual(1,[SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cReceipt.Id].size());

            //the payment activity should be in pending status
            Assert.areEqual(1, [SELECT Id,Status__c FROM Payment_Activity__c WHERE Cash_Receipt__c = :cReceipt.Id AND Status__c = 'Pending'].size());
            
            CashReceiptVoidHelper.voidCashReceipt(cReceipt.Id, JSON.serialize(voidData));

            controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
            ];
            //make sure 2 nex transaction are created
            Assert.areEqual(4, controlledTrans.size());

            Cash_Receipt__c cr = [SELECT Void__c, Void_Date__c, Void_Description__c FROM Cash_Receipt__c WHERE Id = :cReceipt.Id][0];

            // make sure the cash receipt is updated
            Assert.areEqual(true, cr.Void__c);
            Assert.areEqual(System.now().date(), cr.Void_Date__c);
            Assert.areEqual( voidData.description, cr.Void_Description__c);

            //make sure a new bcr is created
            Assert.areEqual(2,[SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cReceipt.Id].size());

            //the payment activity should not be in pending status
            Assert.areEqual(0, [SELECT Id,Status__c FROM Payment_Activity__c WHERE Cash_Receipt__c = :cReceipt.Id AND Status__c = 'Pending'].size());
            //the payment activity should be in Void status
            Assert.areEqual(1, [SELECT Id,Status__c FROM Payment_Activity__c WHERE Cash_Receipt__c = :cReceipt.Id AND Status__c = 'Void'].size());

            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCRRecordError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            List<PostResult> unpostResults = CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testData.cashReceipts.get(1)});
            Assert.areEqual(1, unpostResults.size());
            Assert.areEqual(true, unpostResults[0].isSuccess);

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts[0].Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            try{
                CashReceiptVoidHelper.voidCashReceipt(testData.cashReceipts.get(1).Id, JSON.serialize(voidData));
                Assert.fail('Exception expected.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
            }
            Test.stopTest();
        }
    }
}