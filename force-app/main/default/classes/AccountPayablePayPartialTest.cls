@isTest
private class AccountPayablePayPartialTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testAccountPayablePayPartialIsPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);

            Test.stopTest();

            System.assertEquals(
                true,
                apb.isError
            );

            System.assertEquals(
                PaymentResult.StatusCode.NOT_POSTED,
                apb.paymentResultDispatcher.getPaymentResults().get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testAccountPayablePayPartialIsPaidError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Total__c;
            apb.payPartial();

            controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            apb = new AccountPayablePayPartial(controller);

            Test.stopTest();

            System.assertEquals(true, apb.isError);

            System.assertEquals(
                PaymentResult.StatusCode.ALREADY_PAID,
                apb.paymentResultDispatcher.getPaymentResults().get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testAccountPayablePayPartialAmountMoreThanBalanceError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);
        Test.startTest();
        testData.createCashDisbursementBatches()
            .createCashDisbursements()
            .createAPDisbursements();

        System.runAs(testData.users.get(1)) {
            AccountPayablePayPartial apb = new AccountPayablePayPartial(new ApexPages.StandardController(testData.payables[7]));

            System.assertEquals(true, apb.isError);

            System.assertEquals(
                PaymentResult.StatusCode.ALREADY_PAID,
                apb.paymentResultDispatcher.getPaymentResults().get(0).errors.get(0).statusCode
            );
        }
        Test.stopTest();
    } 

    @isTest
    private static void testAccountPayablePayPartialDiscountAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Discount_Amount__c = 100;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = 1;
            apb.payPartial();

            Test.stopTest();

            System.assertEquals(
                AccountPayablePaymentHandler.DISCOUNTED_AMOUNT_MUST_PAY_IN_FULL_ERROR_MESSAGE,
                ApexPages.getMessages().get(0).getSummary()
            );
        }
    }

    @isTest
    private static void testAccountPayablePayPartialNegativeAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = -100;
            apb.payPartial();

            Test.stopTest();

            System.assertEquals(
                AccountPayablePaymentHandler.NEGATIVE_AMOUNT_ERROR_MESSAGE,
                ApexPages.getMessages().get(0).getSummary()
            );
        }
    }

    @isTest
    private static void testAccountPayablePayPartialNegativeDiscountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.acctPayable.Discount_Amount__c = -10; //error expected
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = 110;
            apb.payPartial();

            Test.stopTest();

            System.assertEquals(
                AccountPayablePaymentHandler.NEGATIVE_DISCOUNT_ERROR_MESSAGE,
                ApexPages.getMessages().get(0).getSummary()
            );
        }
    }
      
    @isTest    
    private static void testAccountPayablePayPartialNoDiscount() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = 25;
            apb.payPartial();

            Test.stopTest();

            AP_Disbursement__c testValidatedAPDisbursement = [
                SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c, Account_Payable__r.Payment_Status__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(3).Id
                LIMIT 1
            ];

            System.assertEquals(
                25,
                testValidatedAPDisbursement.Paid_Amount__c
            );

            System.assertEquals(
                25,
                testValidatedAPDisbursement.Cash_Disbursement__r.Amount__c
            );

            System.assertEquals(
                'Partially Paid',
                testValidatedAPDisbursement.Account_Payable__r.Payment_Status__c
            );
        }
    }
    
    @isTest
    private static void testAccountPayablePayFullWithDiscount() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Discount_Amount__c = 10;
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c;
            apb.payPartial();

            Test.stopTest();

            Account_Payable__c testValidatedAccountPayable = [
                SELECT Id, Net_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
                LIMIT 1
            ];

            AP_Disbursement__c testValidatedAPDisbursement = [
                SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c, Account_Payable__r.Payment_Status__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(3).Id
                LIMIT 1
            ];

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Paid_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Cash_Disbursement__r.Amount__c
            );

            System.assertEquals(
                'Paid',
                testValidatedAPDisbursement.Account_Payable__r.Payment_Status__c
            );
        }
    } 

    @isTest
    private static void testAccountPayablePayFullWithDiscountSetPayPartial() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            //testData.payables.get(3).Discount_Amount__c = 10;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.acctPayable.Discount_Amount__c = 8;
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 8;
            apb.payPartial();

            Test.stopTest();

            Account_Payable__c testValidatedAccountPayable = [
                SELECT Id, Net_Amount__c, Discount_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
                LIMIT 1
            ];

            AP_Disbursement__c testValidatedAPDisbursement = [
                SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c, Account_Payable__r.Payment_Status__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(3).Id
                LIMIT 1
            ];

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Paid_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Cash_Disbursement__r.Amount__c
            );

            System.assertEquals(
                8,
                testValidatedAccountPayable.Discount_Amount__c
            );

            System.assertEquals(
                'Paid',
                testValidatedAPDisbursement.Account_Payable__r.Payment_Status__c
            );
        }
    }   

    @isTest
    private static void testAccountPayablePayFullWithVendorDiscountNullIncluded() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Discount_Days_Due__c = 1;
            testData.accounts.get(0).Discount_Percent__c = 10;
            update testData.accounts.get(0);

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Discount_Amount__c = NULL;
            testData.payables.get(0).Date__c = System.today() + 2;
            testData.payables.get(0).Due_Date__c = System.today() + 2;
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Total__c * .90;
            apb.payPartial();

            Test.stopTest();

            Account_Payable__c testValidatedAccountPayable = [
                SELECT Id, Total__c, Net_Amount__c, Discount_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
                LIMIT 1
            ];

            AP_Disbursement__c testValidatedAPDisbursement = [
                SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c, Account_Payable__r.Payment_Status__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(0).Id
                LIMIT 1
            ];

            System.assertEquals(
                testValidatedAccountPayable.Total__c * .10,
                testValidatedAccountPayable.Discount_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Paid_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Cash_Disbursement__r.Amount__c
            );

            System.assertEquals(
                'Paid',
                testValidatedAPDisbursement.Account_Payable__r.Payment_Status__c
            );
        }
    }

    @isTest
    private static void testAccountPayablePayFullWithVendorDiscountZeroIncluded() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Discount_Days_Due__c = 1;
            testData.accounts.get(0).Discount_Percent__c = 10;
            update testData.accounts.get(0);

            testData.payables.get(0).Status__c = 'Approved';
            testData.payables.get(0).Discount_Amount__c = 0;
            testData.payables.get(0).Date__c = System.today()+2;
            testData.payables.get(0).Due_Date__c = System.today()+2;
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Total__c * .90;
            apb.payPartial();

            Test.stopTest();

            Account_Payable__c testValidatedAccountPayable = [
                SELECT Id, Total__c, Net_Amount__c, Discount_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
                LIMIT 1
            ];

            AP_Disbursement__c testValidatedAPDisbursement = [
                SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c, Account_Payable__r.Payment_Status__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(0).Id
                LIMIT 1
            ];

            System.assertEquals(
                testValidatedAccountPayable.Total__c * .10,
                testValidatedAccountPayable.Discount_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Paid_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Cash_Disbursement__r.Amount__c
            );

            System.assertEquals(
                'Paid',
                testValidatedAPDisbursement.Account_Payable__r.Payment_Status__c
            );
        }
    }  
    
    @isTest
    private static void testAccountPayablePayFullWithVendorDiscountExcluded() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Discount_Days_Due__c = 1;
            testData.accounts.get(0).Discount_Percent__c = 10;
            update testData.accounts.get(0);

            testData.payables.get(0).Discount_Amount__c = 0;
            testData.payables.get(0).Date__c = testData.acctPeriods[0].Start_Date__c;
            testData.payables.get(0).Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(1);
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);
            System.assertEquals(true, result.isSuccess);

            Account_Payable__c testPayable = [
                SELECT Id, Total__c, Vendor__r.Discount_Percent__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ];

            ApexPages.StandardController controller = new ApexPages.StandardController(testPayable);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            Decimal amount = testPayable.Total__c - (testPayable.Total__c * testPayable.Vendor__r.Discount_Percent__c/100);
            apb.uiCashDisbursement.Amount__c = amount;
            apb.payPartial();

            Test.stopTest();

            Account_Payable__c testValidatedAccountPayable = [
                SELECT Id, Net_Amount__c, Discount_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
                LIMIT 1
            ];

            AP_Disbursement__c testValidatedAPDisbursement = [
                SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c, Account_Payable__r.Payment_Status__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(0).Id
                LIMIT 1
            ];

            System.assertEquals(
                16.50,
                testValidatedAccountPayable.Discount_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Paid_Amount__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAPDisbursement.Cash_Disbursement__r.Amount__c
            );

            System.assertEquals(
                'Paid',
                testValidatedAPDisbursement.Account_Payable__r.Payment_Status__c
            );
        }
    } 

    @isTest
    private static void testAccountPayablePayDisbursementPeriodBeforeAPPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Discount_Days_Due__c = 1;
            testData.accounts.get(0).Discount_Percent__c = 10;
            update testData.accounts.get(0);

            testData.payables.get(0).Discount_Amount__c = 0;
            testData.payables.get(0).Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(-2);
            testData.payables.get(0).Due_Date__c = testData.acctPeriods.get(1).Start_Date__c;
            testData.payables.get(0).Accounting_Period__c = testData.acctPeriods.get(1).Id;
            update testData.payables.get(0);

            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);
            System.assertEquals(true, result.isSuccess);

            Account_Payable__c testPayable = [
                SELECT Id, Total__c, Vendor__r.Discount_Percent__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ];

            AccountPayablePayPartial apb = new AccountPayablePayPartial(new ApexPages.StandardController(testPayable));
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            Decimal amount = testPayable.Total__c - (testPayable.Total__c * testPayable.Vendor__r.Discount_Percent__c/100);
            apb.uiCashDisbursement.Amount__c = amount;
            apb.payPartial();

            Test.stopTest();

            System.assertEquals(
                PaymentResult.StatusCode.NON_VALID_ACCOUNTING_PERIOD,
                apb.paymentResultDispatcher.getPaymentResults().get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testAccountPayablePayPartialWithCashFlowCategory() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id defaultCDCategory = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_DISBURSEMENT_CATEGORY)?.GL_Account__c;
            System.assertEquals(
                'Payments to suppliers',
                [SELECT Id, Name FROM GL_Account__c WHERE Id = :defaultCDCategory].Name
            );

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 8;
            apb.uiCashDisbursement.Cash_Flow_Category__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_RECEIPT_CATEGORY)?.GL_Account__c;
            apb.payPartial();

            Test.stopTest();

            List<AP_Disbursement__c> newAPDs = [
                SELECT Id, Cash_Disbursement__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testData.payables.get(3).Id
            ];

            System.assertEquals(
                1, newAPDs.size()
            );

            System.assertEquals(
                'Partially Paid',
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Payment_Status__c
            );

            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_RECEIPT_CATEGORY)?.GL_Account__c,
                [SELECT Cash_Flow_Category__c FROM Cash_Disbursement__c WHERE Id = :newAPDs.get(0).Cash_Disbursement__c LIMIT 1].Cash_Flow_Category__c
            );
        }
    }
      
    @isTest
    private static void testAccountPayablePayPartialSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 8;
            apb.payPartial();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM AP_Disbursement__c WHERE Account_Payable__c = :testData.payables.get(3).Id]
            );

            System.assertEquals(
                'Partially Paid',
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Payment_Status__c
            );

            apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id;
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = 8;
            apb.payPartial();

            Test.stopTest();

            Account_Payable__c testValidatedAccountPayable = [
                SELECT Id, Payment_Status__c, Net_Amount__c, Paid_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
                LIMIT 1
            ];

            System.assertEquals(
                2,
                [SELECT COUNT() FROM AP_Disbursement__c WHERE Account_Payable__c = :testData.payables.get(3).Id]
            );

            System.assertEquals(
                'Paid',
                testValidatedAccountPayable.Payment_Status__c
            );

            System.assertEquals(
                testValidatedAccountPayable.Net_Amount__c,
                testValidatedAccountPayable.Paid_Amount__c
            );
        }
    }

    @isTest
    private static void testAccountPayablePayPartialDefaultGLAVAndGLAccountsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            testData.payables.get(3).Vendor__c = testData.accounts.get(0).Id;
            testData.payables.get(3).Employee__c = null;
            testData.payables.get(3).Payee_Reference__c = 'TEST2435634643646';
            update testData.payables.get(3);

            //setup default GLAV values for the Billing's Customer(Lookup to Account)

            testData.accounts.get(0).GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id;
            update testData.accounts.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Type__c = 'Electronic123';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 1;
            apb.payPartial();

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Type__c = 'Electronic123']
            );

            Ledger__c testDefaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(LedgerHandler.getLedgerId());
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testDefaultLedger.Id);

            for (Cash_Disbursement__c cashDisbursement : [SELECT Id,
                                                                 Bank_Account__c,
                                                                 Debit_GL_Account__c,
                                                                 GL_Account_Variable_1__c,
                                                                 GL_Account_Variable_2__c,
                                                                 GL_Account_Variable_3__c,
                                                                 GL_Account_Variable_4__c
                                                            FROM Cash_Disbursement__c
                                                            WHERE Type__c = 'Electronic123']) {

                System.assertEquals(
                    testDefaultLedger.Default_Bank_Account__c,
                    cashDisbursement.Bank_Account__c
                );

                System.assertEquals(
                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
                    cashDisbursement.Debit_GL_Account__c
                );

                System.assertEquals(
                    testData.accounts.get(0).GL_Account_Variable_1__c,
                    cashDisbursement.GL_Account_Variable_1__c
                );

                System.assertEquals(
                    testData.accounts.get(0).GL_Account_Variable_2__c,
                    cashDisbursement.GL_Account_Variable_2__c
                );

                System.assertEquals(
                    testData.accounts.get(0).GL_Account_Variable_3__c,
                    cashDisbursement.GL_Account_Variable_3__c
                );

                System.assertEquals(
                    testData.accounts.get(0).GL_Account_Variable_4__c,
                    cashDisbursement.GL_Account_Variable_4__c
                );
            }
        }
    }

    @isTest
    private static void testRefreshCheckNumber() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id,
                Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Type__c = 'Check',
                Amount__c = 500,
                Source__c = 'Account Payable',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Employee__c = UserInfo.getUserId(),
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Status__c = 'In Process',
                Reference__c = 'someReference',
                Check_Number__c = 99
            );

            insert testCD;

            Test.startTest();

            Decimal nextCheckNumber = AccountPayablePaymentHandler.refreshCheckNumber((String) testData.glAccounts.get(0).Id);

            Test.stopTest();

            System.assertEquals(100, nextCheckNumber);
        }
    }

    @isTest
    private static void testPayPartialAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Total__c;
            apb.payPartialAndPost();

            Test.stopTest();

            System.assertEquals(false, apb.isError);

            System.assertEquals(
                'Posted',
                [SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :apb.cashDisbursementBatchToInsert.Id].Status__c
            );
        }
    }

    @isTest
    private static void testPay1099FailBlankBox() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Integer Year = Date.today().Year(); 
            
            Accounting_Period__c acctPeriod = new Accounting_Period__c(
                Name = Year + '-01',
                Start_Date__c = Date.newInstance(Year, 1, 1),
                End_Date__c = Date.newInstance(Year, 12, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert acctPeriod;  

            Account acct = testData.accounts[0];
            acct.X1099_Vendor__c = true;
            Id formTypeId = [SELECT Id, Effective_Year__c FROM Form_Type__mdt WHERE Effective_Year__c <= :Year ORDER BY Effective_Year__c DESC LIMIT 1].Id;
            acct.Default_Form_Category_Id__c = [SELECT Id from Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;
            update acct;

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(3)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = Date.today();
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = 5;
            apb.uiCashDisbursement.Form_Category_Id__c = formTypeId;
            apb.uiCashDisbursement.Form_1099_Box__c = '';
            apb.payPartialAndPost();

            Test.stopTest();

            System.assertEquals(false, apb.isError);

            for (ApexPages.Message message: ApexPages.getMessages()) {
                System.assertEquals(AccountPayablePaymentHandler.FORM_CATEGORY_INVALID_ERROR_MESSAGE, message.getSummary());      
            }        
        }
    }

    @isTest
    private static void testPayPartial1099InvalidCategory() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Integer Year = Date.today().Year(); 
            
            Accounting_Period__c acctPeriod = new Accounting_Period__c(
                Name = Year + '-01',
                Start_Date__c = Date.newInstance(Year, 1, 1),
                End_Date__c = Date.newInstance(Year, 12, 31),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert acctPeriod; 

            Account acct = testData.accounts[0];
            acct.X1099_Vendor__c = true;
            Id formTypeId = [SELECT Id, Effective_Year__c FROM Form_Type__mdt WHERE Effective_Year__c = 2001 LIMIT 1].Id;
            acct.Default_Form_Category_Id__c = [SELECT Id from Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;
            update acct;

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(3)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(
                    true,
                    result.isSuccess
                );
            }

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = Date.today();
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = 5;
            apb.uiCashDisbursement.Form_Category_Id__c = formTypeId;
            apb.uiCashDisbursement.Form_1099_Box__c = acct.Default_Form_Category_Id__c;
            apb.payPartialAndPost();

            Test.stopTest();

            System.assertEquals(false, apb.isError);

            for (ApexPages.Message message: ApexPages.getMessages()) {
                System.assertEquals(
                    String.format(AccountPayablePaymentHandler.FORM_TYPE_INVALID_ERROR_MESSAGE, new List<String>{apb.uiCashDisbursement.Disbursement_Date__c.format()}), 
                    message.getSummary());       
            }       
        }
    }

    @IsTest
    private static void testAccountPayablePayFullReverseChargeDiscountFromVendor() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .setHeaderLevelPost()
                .createTaxGroups()
                .setAvaVATSelected();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                //Create Ledger for foreign currency
                Ledger__c theLedger = testData.ledgers.get(0).clone();
                theLedger.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert theLedger;

                //Populate Discount on Account
                Account testAccount = testData.accounts[0];
                testAccount.Discount_Days_Due__c = 30;
                testAccount.Discount_Percent__c = 10;
                update testAccount;

                //Create Payables
                Account_Payable__c payable = new Account_Payable__c(
                    Payee_Reference__c = 'payable1',
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(30),
                    Vendor__c = testAccount.Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = theLedger.Id
                );
                payable.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert payable;

                //Create Payable Lines
                Account_Payable_Line__c line = new Account_Payable_Line__c(
                    Account_Payable__c = payable.Id,
                    Unit_Cost__c = 100,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Tax_Group__c = testData.taxGroups[3].Id
                );
                insert line;

                payable = [
                    SELECT  Id,
                            Reverse_Charge__c,
                            VAT_Line_Count__c,
                            Reverse_Charge_Count__c,
                            Purchase_Tax3__c,
                            Vendor__c,
                            Contact__c,
                            Payment_Status__c
                    FROM Account_Payable__c
                    WHERE Id = :payable.Id
                ];

                System.assertEquals(true, payable.Reverse_Charge__c);
                System.assertEquals(1, payable.VAT_Line_Count__c);
                System.assertEquals(1, payable.Reverse_Charge_Count__c);
                System.assertEquals(20, payable.Purchase_Tax3__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals('Unpaid', payable.Payment_Status__c);

                //Post payable rec
                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{payable});
                System.assertEquals(true, postResults[0].isSuccess);

                Account_Payable__c testPayable = [
                    SELECT Id, Total__c, Vendor__r.Discount_Percent__c, Purchase_Tax3__c
                    FROM Account_Payable__c
                    WHERE Id = :payable.Id
                ];

                ApexPages.StandardController controller = new ApexPages.StandardController(payable);

                AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
                apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
                apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
                apb.uiCashDisbursement.Type__c = 'Electronic';
                apb.payPartial();
                Test.stopTest();

                testPayable = [
                    SELECT Payment_Status__c, Purchase_Tax3__c, Discount_Amount__c, Total__c, Vendor__c
                    FROM Account_Payable__c
                    WHERE Id = :testPayable.Id
                ];
                System.assertEquals('Paid', testPayable.Payment_Status__c);
                System.assertEquals(10, testPayable.Discount_Amount__c);

                Cash_Disbursement__c cd = [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Vendor__c = :testPayable.Vendor__c];
                //Total (100) - Purchase Tax (10) expected
                System.assertEquals(
                    (testPayable.Total__c - testPayable.Discount_Amount__c - testPayable.Purchase_Tax3__c).setScale(2, System.RoundingMode.HALF_UP),
                    cd.Amount__c.setScale(2, System.RoundingMode.HALF_UP)
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @isTest
    private static void testAPDAppliedDateFromCDDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(5);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 8;
            apb.payPartial();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM AP_Disbursement__c WHERE Account_Payable__c = :testData.payables.get(3).Id]
            );

            System.assertEquals(
                'Partially Paid',
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Payment_Status__c
            );

            apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Cash_Disbursement_Batch__c = testData.cashDisbursementBatch.get(0).Id;
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(5);
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = 8;
            apb.payPartial();

            Test.stopTest();

            List<AP_Disbursement__c> results = [SELECT Id, Applied_Date__c FROM AP_Disbursement__c WHERE Account_Payable__c = :testData.payables.get(3).Id];

            System.assertEquals(
                2,
                [SELECT COUNT() FROM AP_Disbursement__c WHERE Account_Payable__c = :testData.payables.get(3).Id]
            );

            for (AP_Disbursement__c res : results) {
                System.assertEquals(testData.acctPeriods.get(1).Start_Date__c.addDays(5), res.Applied_Date__c);
            }
        }
    }

    @isTest
    private static void testAccountPayablePayPartialForPayableAccountingCDSource() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Settings__c accSetting= testData.settings;
            accSetting.Cash_Disbursement_Source__c = 'Payable';
            update accSetting;

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            testData.payables.get(3).Vendor__c = testData.accounts.get(0).Id;
            testData.payables.get(3).Employee__c = null;
            testData.payables.get(3).Payee_Reference__c = 'TEST2435634643646';
            update testData.payables.get(3);

            testData.accounts.get(0).GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id;
            update testData.accounts.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Type__c = 'Electronic123';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 1;
            apb.payPartial();

            Test.stopTest();

            Ledger__c testDefaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(LedgerHandler.getLedgerId());
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testDefaultLedger.Id);

            for (Cash_Disbursement__c cashDisbursement : [SELECT Id,
                                                                 Bank_Account__c,
                                                                 Debit_GL_Account__c
                                                            FROM Cash_Disbursement__c
                                                            WHERE Type__c = 'Electronic123']) {

                System.assertEquals(
                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                    cashDisbursement.Debit_GL_Account__c
                );
            }
        }
    }

    @isTest
    private static void testAccountPayablePayPartialForDebitGLAccountFromUIPage() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Settings__c accSetting= testData.settings;
            accSetting.Cash_Disbursement_Source__c = 'Payable';
            update accSetting;

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            testData.payables.get(3).Vendor__c = testData.accounts.get(0).Id;
            testData.payables.get(3).Employee__c = null;
            testData.payables.get(3).Payee_Reference__c = 'TEST2435634643646';
            update testData.payables.get(3);

            testData.accounts.get(0).GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id;
            update testData.accounts.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Type__c = 'Electronic123';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 1;
            apb.uiCashDisbursement.Debit_GL_Account__c = testData.glAccounts.get(0).Id;
            apb.payPartial();

            Test.stopTest();

            Ledger__c testDefaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(LedgerHandler.getLedgerId());
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testDefaultLedger.Id);

            for (Cash_Disbursement__c cashDisbursement : [SELECT Id,
                                                                 Bank_Account__c,
                                                                 Debit_GL_Account__c
                                                            FROM Cash_Disbursement__c
                                                            WHERE Type__c = 'Electronic123']) {

                System.assertEquals(
                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                    cashDisbursement.Debit_GL_Account__c
                );
            }
        }
    }

     @isTest
    private static void testAccountPayablePayPartialForForCashLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).Accounting_Period__c = testData.acctPeriods.get(0).Id;
            testData.payables.get(3).Vendor__c = testData.accounts.get(0).Id;
            testData.payables.get(3).Employee__c = null;
            testData.payables.get(3).Payee_Reference__c = 'TEST2435634643646';
            testData.payables.get(3).Ledger__c = testData.ledgers.get(3).Id;
            update testData.payables.get(3);

            testData.accounts.get(0).GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_2__c = testData.accountingVariables2.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_3__c = testData.accountingVariables3.get(0).Id;
            testData.accounts.get(0).GL_Account_Variable_4__c = testData.accountingVariables4.get(0).Id;
            update testData.accounts.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);
            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Type__c = 'Electronic123';
            apb.uiCashDisbursement.Amount__c = [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables.get(3).Id].Net_Amount__c - 1;
            apb.uiCashDisbursement.Debit_GL_Account__c = testData.glAccounts.get(0).Id;
            apb.payPartial();

            Test.stopTest();

            Ledger__c testDefaultLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(LedgerHandler.getLedgerId());
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testDefaultLedger.Id);

            for (Cash_Disbursement__c cashDisbursement : [SELECT Id,
                                                                 Bank_Account__c,
                                                                 Debit_GL_Account__c
                                                            FROM Cash_Disbursement__c
                                                            WHERE Type__c = 'Electronic123']) {

                System.assertEquals(
                    defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
                    cashDisbursement.Debit_GL_Account__c
                );
            }
        }
    }

    @isTest
    private static void testAccountPayablePayPartialForOnHoldPayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(3).Status__c = 'Approved';
            testData.payables.get(3).On_Hold__c = true;
            update testData.payables.get(3);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(3)}).get(0);

            System.assertEquals(true, result.isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(3).Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(controller);
            PageReference pageRef = Page.AccountPayablePayPartial;
              pageRef.getParameters().put('id', testData.payables.get(3).Id);
              Test.setCurrentPage(pageRef);

            Test.stopTest();
			System.assertEquals(
                AccountPayablePaymentHandler.ERR_ON_PAYABLE_PAY_PARTIAL_PAGE_WHEN_ON_HOLD_IS_CHECKED,
                ApexPages.getMessages().get(0).getSummary()
            );
        }
    }
}