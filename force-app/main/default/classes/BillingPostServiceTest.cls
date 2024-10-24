@IsTest
public class BillingPostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling1 = testData.billings.get(0);
            Billing__c testBilling2 = testData.billings.get(1);

            testBilling1.Status__c = 'In Process';
            update testBilling1;

            List<PostResult> postResults = BillingPostService.postBillings(new List<Billing__c>{testBilling1, testBilling2});
            System.assertEquals(2, postResults.size());

            PostResult testBilling1PostResult;
            PostResult testBilling2PostResult;
            for (PostResult postResult : postResults) {
                if (postResult.id == testBilling1.Id) {
                    testBilling1PostResult = postResult;
                }
                if (postResult.id == testBilling2.Id) {
                    testBilling2PostResult = postResult;
                }
            }

            System.assertEquals(false, testBilling1PostResult.isSuccess);
            System.assertEquals(true, testBilling2PostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.NOT_APPROVED_ERROR_MESSAGE, testBilling1PostResult.errors.get(0).message);
        }
    }

    @IsTest
    public static void testUnPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling1 = testData.billings.get(0);
            Billing__c testBilling2 = testData.billings.get(1);

            testBilling1.Status__c = 'In Process';
            update testBilling1;

            List<PostResult> postResults = BillingPostService.postBillings(new List<Billing__c>{testBilling1, testBilling2});
            System.assertEquals(2, postResults.size());

            List<PostResult> unpostResults = BillingPostService.unpostBillings(
                new List<Billing__c>{testBilling1, testBilling2}
            );
            System.assertEquals(2, unpostResults.size());

            PostResult testBilling1UnPostResult;
            PostResult testBilling2UnPostResult;
            for (PostResult postResult : unpostResults) {
                if (postResult.id == testBilling1.Id) {
                    testBilling1UnPostResult = postResult;
                }
                if (postResult.id == testBilling2.Id) {
                    testBilling2UnPostResult = postResult;
                }
            }

            System.assertEquals(false, testBilling1UnPostResult.isSuccess);
            System.assertEquals(true, testBilling2UnPostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.UNPOSTED_ERROR_MESSAGE, testBilling1UnPostResult.errors.get(0).message);
        }

    }

    @IsTest
    public static void testNoBillingLinesPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            delete testData.billingLines;

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(false,results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_LINES, results[0].errors[0].statusCode);
        }

    }
    
    @IsTest
    public static void testAccountingPeriodClosedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.billings[0];
            update testData.acctPeriods[0];

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(false,results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }  
     
    @IsTest
    public static void testAlreadyPostedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(true,results[0].isSuccess);

            results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(false,results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED, results[0].errors[0].statusCode);
        }

    }
    
    @IsTest
    public static void testStatusNotApprovedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        Billing__c billing = testData.billings[0];
        billing.Status__c = 'In Process';
        update billing;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{billing});
            Test.stopTest();
            System.assertEquals(false,results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.STATUS_NOT_APPROVED, results[0].errors[0].statusCode);
        }

    }   
    
    @IsTest
    public static void testStatusNoControlARPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            List<PostResult> results = BillingPostService.postBillings(new List<Billing__c>{testData.billings[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_CONTROL_AR_ACCOUNT_DEFINED, results[0].errors[0].statusCode);
        }

    } 
    
    @IsTest
    public static void testPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(true,results[0].isSuccess);
        }

    }  
    
    @IsTest
    public static void testAccountingPeriodClosedUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            results = BillingPostService.unpostBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(false,results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }
    
    @IsTest
    public static void testNotPostedUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results = BillingPostService.unpostBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_UNPOSTED, results[0].errors[0].statusCode);
            System.assertEquals(
                testData.billings[0].Status__c,
                [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c
            );
        }

    }

    @IsTest
    public static void testBillingCashReceiptsExistUnpost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(true,results[0].isSuccess);

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;

            insert bcr;

            results = BillingPostService.unpostBillings(new Billing__c[]{testData.billings[0]});

            System.assertEquals(true, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testBillingInvoiceCreditMemosExistUnpost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            testData.billings[3].Status__c = 'Approved';
            update testData.billings[3];

            System.assertEquals('Approved',[Select Id, Status__c From Billing__c Where Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Approved',[Select Id, Status__c From Billing__c Where Id = :testData.billings[3].Id].Status__c);

            System.assertEquals(AccountingPeriodActions.OPEN_STATUS,[Select Id, Accounting_Period__r.Status__c From Billing__c Where Id = :testData.billings[0].Id].Accounting_Period__r.Status__c);
            System.assertEquals(AccountingPeriodActions.OPEN_STATUS,[Select Id, Accounting_Period__r.Status__c From Billing__c Where Id = :testData.billings[3].Id].Accounting_Period__r.Status__c);

            System.assertNotEquals(0,[Select count() From Billing_Line__c Where Billing__c = :testData.billings[0].Id]);
            System.assertNotEquals(0,[Select count() From Billing_Line__c Where Billing__c = :testData.billings[3].Id]);

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0],testData.billings[3]});
            System.assertEquals(true,results[0].isSuccess);
            System.assertEquals(true,results[1].isSuccess);

            System.assertEquals('Posted',[Select Id, Status__c From Billing__c Where Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Posted',[Select Id, Status__c From Billing__c Where Id = :testData.billings[3].Id].Status__c);

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            // Test unpost billing credit memo
            results = BillingPostService.unpostBillings(new Billing__c[]{testData.billings[0]});

            System.assertEquals(true, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testBillingCreditMemoCreditMemosExistUnpost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            testData.billings[3].Status__c = 'Approved';
            update testData.billings[3];

            System.assertEquals('Approved',[Select Id, Status__c From Billing__c Where Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Approved',[Select Id, Status__c From Billing__c Where Id = :testData.billings[3].Id].Status__c);

            System.assertEquals(AccountingPeriodActions.OPEN_STATUS,[Select Id, Accounting_Period__r.Status__c From Billing__c Where Id = :testData.billings[0].Id].Accounting_Period__r.Status__c);
            System.assertEquals(AccountingPeriodActions.OPEN_STATUS,[Select Id, Accounting_Period__r.Status__c From Billing__c Where Id = :testData.billings[3].Id].Accounting_Period__r.Status__c);

            System.assertNotEquals(0,[Select count() From Billing_Line__c Where Billing__c = :testData.billings[0].Id]);
            System.assertNotEquals(0,[Select count() From Billing_Line__c Where Billing__c = :testData.billings[3].Id]);

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0],testData.billings[3]});
            System.assertEquals(true,results[0].isSuccess);
            System.assertEquals(true,results[1].isSuccess);

            System.assertEquals('Posted',[Select Id, Status__c From Billing__c Where Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Posted',[Select Id, Status__c From Billing__c Where Id = :testData.billings[3].Id].Status__c);

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            // Test unpost billing credit memo
            results = BillingPostService.unpostBillings(new Billing__c[]{testData.billings[3]});

            System.assertEquals(true, results[0].isSuccess);
        }

    }
    
    @IsTest 
    public static void testBillingUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            List<PostResult> results = BillingPostService.postBillings(new Billing__c[]{testData.billings[0]});
            System.assertEquals(true,results[0].isSuccess);

            results = BillingPostService.unpostBillings(new Billing__c[]{testData.billings[0]});

            System.assertEquals(true,results[0].isSuccess);
        }

    }

    @IsTest
    public static void testPostSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBillings();

            System.runAs(testData.users.get(1)) {
                Billing__c testBilling = testData.billings[0];
                testBilling.Status__c = 'Approved';

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrency)) {
                    return;
                }

                testBilling.put('CurrencyIsoCode', newCurrency);

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update testData.billings[0];
                TriggerObserver.reset();

                List<PostResult> results = BillingPostService.postBillings(new List<Billing__c>{testData.billings[0]});

                System.assertEquals(
                    newCurrency, [
                        SELECT Foreign_Currency__c
                        FROM Transaction__c
                        WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    ][0].Foreign_Currency__c
                );
                System.assertEquals(true, results[0].isSuccess);
            }
        }
        catch (Exception ex) {

        }
    }
}