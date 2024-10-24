@isTest
private class CashReceiptVoidTest {
    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    public static void testVoidCRPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            List<PostResult> unpostResults = CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testData.cashReceipts.get(1)});
            Assert.areEqual(1, unpostResults.size());
            Assert.areEqual(true, unpostResults[0].isSuccess);

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts.get(1).Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            try{
                new CashReceiptVoid().voidCashReceipt(voidData);
                Assert.fail(Label.ERR_THE_CR_MUST_BE_POSTED + ' Exception expected, but was not thrown.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
                Assert.areEqual(Label.ERR_THE_CR_MUST_BE_POSTED, e.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCRVoidedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            List<PostResult> unpostResults = CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testData.cashReceipts.get(1)});
            Assert.areEqual(1, unpostResults.size());
            Assert.areEqual(true, unpostResults[0].isSuccess);

            Cash_Receipt__c cr = testData.cashReceipts.get(1);
            cr.Void__c = true;
            
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Void__c
                }
            );


            UPDATE cr;

            List<PostResult> postResults = CashReceiptPostService.postCashReceipts(new List<Cash_Receipt__c>{testData.cashReceipts.get(1)});
            Assert.areEqual(1, postResults.size());
            Assert.areEqual(false, postResults[0].isSuccess);

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts.get(1).Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            try{
                new CashReceiptVoid().voidCashReceipt(voidData);
                Assert.fail(Label.ERR_THE_CR_WAS_ALREADY_VOIDED + ' Exception expected, but was not thrown.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
                Assert.areEqual(Label.ERR_THE_CR_MUST_BE_POSTED, e.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCRBankReconError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                                .createCashReceipts()
                                .createBankReconciliations()
                                .createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            List<PostResult> unpostResults = CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testData.cashReceipts.get(1)});
            Assert.areEqual(1, unpostResults.size());
            Assert.areEqual(true, unpostResults[0].isSuccess);

            testData.cashReceipts[1].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            testData.cashReceipts[1].Status__c = 'Posted';
            testData.cashReceipts[1].Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Reconciliation__c,
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c
                }
            );
            update testData.cashReceipts[1]; 

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts.get(1).Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            try{
                new CashReceiptVoid().voidCashReceipt(voidData);
                Assert.fail(Label.ERR_THE_CR_IS_NOT_LINKED_TO_BANK_RECONCILIATION + ' Exception expected, but was not thrown.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
                Assert.areEqual(Label.ERR_THE_CR_IS_NOT_LINKED_TO_BANK_RECONCILIATION, e.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCRNoAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                        .createCashReceipts()
                        .createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.cashReceipts[1].Status__c = 'Posted';
            testData.cashReceipts[1].Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c
                }
            );
            update testData.cashReceipts[1]; 

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts.get(1).Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            try{
                new CashReceiptVoid().voidCashReceipt(voidData);
                Assert.fail(Label.ERR_NO_PERIOD_FOR_SELECTED_VOID_RECEIPT_DATE + ' Exception expected, but was not thrown.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
                Assert.areEqual(Label.ERR_NO_PERIOD_FOR_SELECTED_VOID_RECEIPT_DATE, e.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCREarlierVoidDateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                        .createCashReceipts()
                        .createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.cashReceipts[1].Status__c = 'Posted';
            testData.cashReceipts[1].Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            testData.cashReceipts[1].Receipt_Date__c = System.today();

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Receipt_Date__c
                }
            );
            update testData.cashReceipts[1]; 

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts.get(1).Id;
            voidData.voidReceiptDate = System.today().addDays(-2);
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date().addDays(-10);
            testAccountingPeriod.End_Date__c = System.now().date();
            
            UPDATE testAccountingPeriod;

            try{
                new CashReceiptVoid().voidCashReceipt(voidData);
                Assert.fail(Label.ERR_THE_VOID_DATE_CAN_NOT_EARLIER_THAN_RECEIPT_DATE + ' Exception expected, but was not thrown.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
                Assert.areEqual(Label.ERR_THE_VOID_DATE_CAN_NOT_EARLIER_THAN_RECEIPT_DATE, e.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCRCashFlowCategoryError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                        .createCashReceipts()
                        .createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            Accounting_Settings__c settings = AccountingSettingsHelper.getSettings();
            Assert.areEqual(false, settings.Enable_Cash_Flow_Statement__c);

            settings.Enable_Cash_Flow_Statement__c = true;
            AccountingSettingsHelper.save(settings);  
            
            testData.cashReceipts[1].Status__c = 'Posted';
            testData.cashReceipts[1].Receipt_Date__c = System.today();

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Receipt_Date__c
                }
            );
            update testData.cashReceipts[1]; 

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts.get(1).Id;
            voidData.voidReceiptDate = System.today().addDays(1);
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date().addDays(-10);
            testAccountingPeriod.End_Date__c = System.now().date().addDays(5);
            
            UPDATE testAccountingPeriod;

            try{
                new CashReceiptVoid().voidCashReceipt(voidData);
                Assert.fail(Label.ERR_CASH_FLOW_CATEGORY_MUST_SPECIFIED_WHEN_CFS_ENABLED + ' Exception expected, but was not thrown.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
                Assert.areEqual(Label.ERR_CASH_FLOW_CATEGORY_MUST_SPECIFIED_WHEN_CFS_ENABLED, e.getMessage());
            }
            Test.stopTest();
        }
    }
    @IsTest
    public static void testVoidCRRecordNoPaymentActivity() {
        TestDataSuite testData = TestDataSuite.getInstance()
                    .createCashReceipts()
                    .createBankDeposits()
                    .createCashFlowCategories(false)
                    .createBillings(false)
                    .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Cash_Receipt__c cReceipt = testData.cashReceipts[0];
            cReceipt.Status__c = 'Posted';
            cReceipt.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Payment_Processor__c
                }
            );
            update cReceipt;     
            
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date();
            testAccountingPeriod.End_Date__c = System.now().date();
            
            UPDATE testAccountingPeriod;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testAccountingPeriod.Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = cReceipt.Id;
            bcr.Applied_Amount__c = 1;
            bcr.Adjustment_Amount__c = 1;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            INSERT bcr;

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = cReceipt.Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = testData.cashFlowCategories[0].Id;
            voidData.paymentId = cReceipt.Payment_Reference__c;


            List<Transaction__c> controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
            ];

            //initially there should be only 2 transactions
            Assert.areEqual(2, controlledTrans.size());
            //make sure there is only one bcr record exist
            Assert.areEqual(1,[SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cReceipt.Id].size());

            //no payment activity is expected
            Assert.areEqual(0, [SELECT Id,Status__c FROM Payment_Activity__c WHERE Cash_Receipt__c = :cReceipt.Id AND Status__c = 'Pending'].size());
            
            new CashReceiptVoid().voidCashReceipt(voidData);
            Assert.isTrue([SELECT Void__c FROM Cash_Receipt__c WHERE Id = :cReceipt.Id].Void__c);
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
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Payment_Processor__c
                }
            );
            update cReceipt;     
            
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date();
            testAccountingPeriod.End_Date__c = System.now().date();
            
            UPDATE testAccountingPeriod;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testAccountingPeriod.Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = cReceipt.Id;
            bcr.Applied_Amount__c = 1;
            bcr.Adjustment_Amount__c = 1;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            INSERT bcr;

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = cReceipt.Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = testData.cashFlowCategories[0].Id;
            voidData.paymentId = cReceipt.Payment_Reference__c;


            List<Transaction__c> controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
            ];

            //initially there should be only 2 transactions
            Assert.areEqual(2, controlledTrans.size());
            //make sure there is only one bcr record exist
            Assert.areEqual(1,[SELECT Id FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :cReceipt.Id].size());

            //the payment activity should be in pending status
            Assert.areEqual(1, [SELECT Id,Status__c FROM Payment_Activity__c WHERE Cash_Receipt__c = :cReceipt.Id AND Status__c = 'Pending'].size());
            
            new CashReceiptVoid().voidCashReceipt(voidData);

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
    public static void testVoidCRBankDepositError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                        .createCashReceipts()
                        .createBankDeposits()
                        .createBankReconciliations()
                        .createCashFlowCategories(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            Bank_Deposit__c bd = testData.bankDeposits[0].clone(false,true);
            insert bd;

            bd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            bd.Amount__c = 100;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Bank_Deposit__c.Bank_Reconciliation__c,
                    Bank_Deposit__c.Amount__c
                }
            );
            update bd;

            TriggerObserver.reset();

            Cash_Receipt__c cReceipt = testData.cashReceipts[0];
            cReceipt.Status__c = 'Posted';
            cReceipt.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            cReceipt.Bank_Deposit__c = bd.Id;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Payment_Processor__c,
                    Cash_Receipt__c.Bank_Deposit__c
                }
            );
            update cReceipt;     
            
            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = cReceipt.Id;
            voidData.voidReceiptDate = System.today().addDays(1);
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = '';

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date().addDays(-10);
            testAccountingPeriod.End_Date__c = System.now().date().addDays(5);
            
            UPDATE testAccountingPeriod;

            try{
                new CashReceiptVoid().voidCashReceipt(voidData);
                Assert.fail(Label.ERR_CASH_RECEIPT_VOID_FAILED_BANK_DEPOSIT_IS_CLEARED + ' Exception expected, but was not thrown.');
            }catch(Exception e){
                Assert.areEqual(false, String.isBlank(e.getMessage()));
                Assert.areEqual(Label.ERR_CASH_RECEIPT_VOID_FAILED_BANK_DEPOSIT_IS_CLEARED, e.getMessage());
            }
            Test.stopTest();
        }
    }
}