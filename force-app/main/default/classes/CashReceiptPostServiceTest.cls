@IsTest
public class CashReceiptPostServiceTest {

    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Cash_Receipt__c testCR1 = testData.cashReceipts.get(1);
            Cash_Receipt__c testCR2 = testData.cashReceipts.get(2);

            List<PostResult> unpostResults = CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{testCR1, testCR2});
            System.assertEquals(2, unpostResults.size());
            System.assertEquals(true, unpostResults[0].isSuccess);
            System.assertEquals(true, unpostResults[1].isSuccess);

            //close first period
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            List<PostResult> postResults = CashReceiptPostService.postCashReceipts(new List<Cash_Receipt__c>{testCR1, testCR2});

            PostResult testCR1PostResult;
            PostResult testCR2PostResult;
            for (PostResult postResult : postResults) {
                if (postResult.id == testCR1.Id) {
                    testCR1PostResult = postResult;
                }
                if (postResult.id == testCR2.Id) {
                    testCR2PostResult = postResult;
                }
            }

            System.assertEquals(true, testCR1PostResult.isSuccess);
            System.assertEquals(false, testCR2PostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, testCR2PostResult.errors.get(0).message);
        }
    }

    @IsTest
    public static void testAccountingPeriodClosedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[2]}
            );
            System.assertEquals(true, results[0].isSuccess);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            results = CashReceiptPostService.postCashReceipts(new List<Cash_Receipt__c>{testData.cashReceipts[2]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }  

    @IsTest
    public static void testAlreadyPostedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            System.assertEquals(
                'Posted',
                [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Status__c
            );

            List<PostResult> results = CashReceiptPostService.postCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[0]}
            );

            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED, results[0].errors[0].statusCode);
        }

    } 

    @IsTest
    public static void testNoControlAccountPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[0]}
            );
            System.assertEquals(true, results[0].isSuccess);

            AccountingSettingsHandler.acctSeedSettings = NULL;
            results = CashReceiptPostService.postCashReceipts(
                new Cash_Receipt__c[]{[
                    SELECT Id, Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testData.cashReceipts[0].Id
                ]}
            );
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_UNAPPLIED_CASH_CONTROL_ACCOUNT_DEFINED, results[0].errors[0].statusCode);
        }

    }
  
    @IsTest
    public static void testPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[0]}
            );
            System.assertEquals(true, results[0].isSuccess);

            results = CashReceiptPostService.postCashReceipts(
                new List<Cash_Receipt__c>{
                    [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id]
                }
            );
            System.assertEquals(true, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testAccountingPeriodClosedUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[2]}
            );
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }

    @IsTest    
    public static void testNotPostedUnpostSucess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[0]}
            );
            System.assertEquals(true, results[0].isSuccess);

            results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{
                    [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id]
                }
            );
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_UNPOSTED, results[0].errors[0].statusCode);
            System.assertEquals(
                testData.cashReceipts[0].Status__c,
                [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Status__c
            );
        }

    }

    @IsTest    
    public static void testBillingCashReceiptsExistUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Applied_Amount__c = 2;
            insert bcr;

            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[0]}
            );
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.BILLING_CASH_RECEIPTS_EXIST, results[0].errors[0].statusCode);
        }

    }

    @IsTest    
    public static void testBankReconciliationClearedUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[0]}
            );
            System.assertEquals(true, results[0].isSuccess);

            testData.cashReceipts[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            testData.cashReceipts[0].Status__c = 'Approved';

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Reconciliation__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            results = CashReceiptPostService.postCashReceipts(
                new List<Cash_Receipt__c>{
                    [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id]
                }
            );
            System.assertEquals(true, results[0].isSuccess);

            results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{
                    [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id]
                }
            );

            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION, results[0].errors[0].statusCode);
        }

    }

    @IsTest    
    public static void testBankDepositClearedUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankDeposits();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{testData.cashReceipts[0]}
            );
            System.assertEquals(true, results[0].isSuccess);

            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            testData.cashReceipts[0].Status__c = 'Approved';

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            results = CashReceiptPostService.postCashReceipts(
                new List<Cash_Receipt__c>{
                    [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id]
                }
            );
            System.assertEquals(true, results[0].isSuccess);

            results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{
                    [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id]
                }
            );
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_DEPOSIT, results[0].errors[0].statusCode);
        }

    }
   
    @IsTest  
    public static void testUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<PostResult> results = CashReceiptPostService.unpostCashReceipts(
                new List<Cash_Receipt__c>{
                    [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id]
                }
            );
            System.assertEquals(true, results[0].isSuccess);
        }

    }

}