@isTest
public with sharing class CashReceiptVoidBCRBatchTest {
    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    public static void testCRVoidBCRBatchSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                    .createCashReceipts()
                    .createCashFlowCategories(false)
                    .createBillings(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Deposit__c bd = new Bank_Deposit__c(
                    Deposit_Date__c = System.today(),
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Deposit_Reference__c = 'the reference 1'
                );
            INSERT bd;

            Cash_Receipt__c cReceipt = testData.cashReceipts[0];
            cReceipt.Status__c = 'Posted';
            cReceipt.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            cReceipt.Bank_Deposit__c = bd.Id;
            
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Bank_Deposit__c
                }
            );
            UPDATE cReceipt;     
                
            Assert.areNotEqual(null,cReceipt.Bank_Deposit__c);

            List<Transaction__c> controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
            ];
           //initially there should be only 2 transactions
            Assert.areEqual(2, controlledTrans.size());

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = cReceipt.Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = testData.cashFlowCategories[0].Id;
            voidData.paymentId = cReceipt.Payment_Reference__c;

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date();
            testAccountingPeriod.End_Date__c = System.now().date();
            
            UPDATE testAccountingPeriod;

            createBulkBCR(testAccountingPeriod,testData);
            
            //make sure there are 200 bcr created 
            Assert.areEqual(200,[SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cReceipt.Id].size());

            Database.executeBatch(new CashReceiptVoidBCRBatch(new Map<Id,CashReceiptVoidHelper.VoidData> {
                testData.cashReceipts.get(0).Id => voidData
            },VoidExternalTransactionBatch.getLogger()));
            Test.stopTest();

            //make sure new bcr are created
            Assert.areEqual(400,[SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cReceipt.Id].size());

            controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
                ];

            //make sure 2 new transaction are created
            Assert.areEqual(4, controlledTrans.size());
            
            Cash_Receipt__c cr = [SELECT Void__c, Void_Date__c,Bank_Deposit__c, Void_Description__c FROM Cash_Receipt__c WHERE Id = :cReceipt.Id][0];
            
            // make sure the cash receipt is updated
            Assert.areEqual(true, cr.Void__c);
            Assert.areEqual(System.now().date(), cr.Void_Date__c);
            Assert.areEqual( voidData.description, cr.Void_Description__c);
            Assert.areEqual(null, cr.Bank_Deposit__c);
        }
    } 
    @IsTest
    public static void testCRVoidBCRBatchSuccessWithNoBCR() {
        TestDataSuite testData = TestDataSuite.getInstance()
                    .createCashReceipts()
                    .createBankDeposits()
                    .createCashFlowCategories(false)
                    .createBillings(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c cReceipt = testData.cashReceipts[0];
            cReceipt.Status__c = 'Posted';
            cReceipt.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;

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
            voidData.cashReceiptId = cReceipt.Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = testData.cashFlowCategories[0].Id;
            voidData.paymentId = cReceipt.Payment_Reference__c;


            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date();
            testAccountingPeriod.End_Date__c = System.now().date();
            
            UPDATE testAccountingPeriod;
            
            //make sure there are no bcr
            Assert.areEqual(0,[SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cReceipt.Id].size());

            
            Database.executeBatch(new CashReceiptVoidBCRBatch(new Map<Id,CashReceiptVoidHelper.VoidData> {
                testData.cashReceipts.get(0).Id => voidData
            },VoidExternalTransactionBatch.getLogger()));
            Test.stopTest();
            
            controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
            ];
            
            //make sure still 2 new transaction are created
            Assert.areEqual(4, controlledTrans.size());
            
            Cash_Receipt__c cr = [SELECT Void__c, Void_Date__c,Bank_Deposit__c, Void_Description__c FROM Cash_Receipt__c WHERE Id = :cReceipt.Id][0];
            
            
            // make sure still the cash receipt is updated
            Assert.areEqual(true, cr.Void__c);
            Assert.areEqual(System.now().date(), cr.Void_Date__c);
            Assert.areEqual( voidData.description, cr.Void_Description__c);  
            
            //make sure AJR Record is created 
            List<Automated_Job_Results__c> results = [SELECT Id,Schedule_Job_Type__c,Failed__c,Notes__c,Processed__c,Succeeded__c
                FROM Automated_Job_Results__c WHERE Schedule_Job_Type__c = 'Cash Receipt Void'];
            Assert.areEqual(1, results.size());
            Assert.areEqual(1, results[0].Succeeded__c);
            Assert.areEqual(1, results[0].Processed__c);
            Assert.areEqual(0, results[0].Failed__c);
        }
    } 
    private static void createBulkBCR(Accounting_Period__c testAccountingPeriod,TestDataSuite testData){
        List<Billing_Cash_Receipt__c> bcrs = new List<Billing_Cash_Receipt__c>();
        for(Integer i = 0;i< 200 ;i++){
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testAccountingPeriod.Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 0;
            bcr.Adjustment_Amount__c = 0;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            bcrs.add(bcr);
        }
        INSERT bcrs;
    } 
}