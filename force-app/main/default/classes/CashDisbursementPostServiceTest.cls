@IsTest
public class CashDisbursementPostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD1 = testData.cashDisbursements.get(0);
            Cash_Disbursement__c testCD2 = testData.cashDisbursements.get(1);

            testCD2.Payment_Status__c = 'Void';
            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Payment_Status__c);
            update testCD2;

            List<PostResult> postResults = CashDisbursementPostService.postCashDisbursements(new List<Cash_Disbursement__c>{testCD1, testCD2});
            System.assertEquals(2, postResults.size());

            PostResult testCD1PostResult;
            PostResult testCD2PostResult;
            for (PostResult postResult : postResults) {
                if (postResult.id == testCD1.Id) {
                    testCD1PostResult = postResult;
                }
                if (postResult.id == testCD2.Id) {
                    testCD2PostResult = postResult;
                }
            }

            System.assertEquals(true, testCD1PostResult.isSuccess);
            System.assertEquals(false, testCD2PostResult.isSuccess);
            System.assertEquals(CashDisbursementPostHandler.POSTED_VOID_ERROR_MESSAGE, testCD2PostResult.errors.get(0).message);
        }
    }

    @IsTest
    private static void testUnPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD1 = testData.cashDisbursements.get(0);
            Cash_Disbursement__c testCD2 = testData.cashDisbursements.get(1);

            testCD2.Payment_Status__c = 'Void';
            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Payment_Status__c);
            update testCD2;

            List<PostResult> postResults = CashDisbursementPostService.postCashDisbursements(new List<Cash_Disbursement__c>{testCD1, testCD2});
            List<PostResult> unpostResults = CashDisbursementPostService.unpostCashDisbursements(new List<Cash_Disbursement__c>{testCD1, testCD2});
            System.assertEquals(2, unpostResults.size());

            PostResult testCD1UnPostResult;
            PostResult testCD2UnPostResult;
            for (PostResult postResult : unpostResults) {
                if (postResult.id == testCD1.Id) {
                    testCD1UnPostResult = postResult;
                }
                if (postResult.id == testCD2.Id) {
                    testCD2UnPostResult = postResult;
                }
            }

            System.assertEquals(true, testCD1UnPostResult.isSuccess);
            System.assertEquals(false, testCD2UnPostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.UNPOSTED_ERROR_MESSAGE, testCD2UnPostResult.errors.get(0).message);
        }
    }

    @IsTest
    public static void testCashDisbursementPostServicePostClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //all test Cash Disbursement records belong to Accounting Period "1991-10" which is first in list of created periods
            //let's try to close this Accounting Period to reproduce currently tested error
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAcctPeriod;
            Test.stopTest();
            //Let's make it sure
            System.assertEquals(AccountingPeriodActions.CLOSED_STATUS, [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAcctPeriod.Id].Status__c);
            //Try to post all cash disbursements
            List<PostResult> results = CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);

            System.assertEquals(testData.cashDisbursements.size(), results.size());
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    public static void testCashDisbursementPostServicePostAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Try to post all cash disbursements
            CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);
            //Let's make sure that we dont have non-posted records anymore
            List<Cash_Disbursement__c> unpostedCDs = [
                    SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'In Process'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            //And now we will try to post records which are already posted and ...
            List<PostResult> results = CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);
            //Getting expected error message
            System.assertEquals(AbstractPostHandler.POSTED_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    public static void testCashDisbursementPostServicePostVoidedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Set Payment Status as "Void" for every Cash Disbursement
            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                cd.Payment_Status__c = 'Void';
            }
            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Payment_Status__c);
            update testData.cashDisbursements;

            System.assertEquals('Void', testData.cashDisbursements[0].Payment_Status__c);
            //And now we will try to post records which have "Void" Payment Status and ...
            List<PostResult> results = CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);
            //Getting expected error message
            System.assertEquals(CashDisbursementPostHandler.POSTED_VOID_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    public static void testCashDisbursementPostServicePostAPControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            List<PostResult> results = CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);

            List<Cash_Disbursement__c> postedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];
            System.assertEquals(CashDisbursementPostHandler.NO_CONTROL_ACCOUNT_MESSAGE, results[0].errors[0].message);
        }
    }

    @IsTest
    public static void testCashDisbursementPostServiceAPAmountNotEqualCDAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches();

        Test.startTest();
        testData.createCashDisbursements();
        testData.createApDisbursements();

        System.runAs(testData.users.get(1)) {
            Cash_Disbursement__c cd = [
                SELECT
                    Id,
                    Amount__c,
                    Source__c,
                    (
                        SELECT
                            Id,
                            Paid_Amount__c
                        FROM Account_Payable_Cash_Disbursements__r
                    )
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[0].Id
            ];
            cd.Amount__c = cd.Amount__c + 3425;
            CashDisbursementPostHandler cdh = new CashDisbursementPostHandler();
            cdh.sourceRecords = new Cash_Disbursement__c[]{cd};
            cdh.validatePaidAmountSumEqualsCashDisbursementAmount(false);

            System.assertEquals(CashDisbursementPostHandler.PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_ERROR_MESSAGE, cdh.dispatcher.getPostResults()[0].errors[0].message);
        }
    }

    @IsTest
    public static void tesCashDisbursementPostServicePostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);

            List<Cash_Disbursement__c> postedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(false, postedCDs.isEmpty());

            List<PostResult> results = CashDisbursementPostService.unpostCashDisbursements(testData.cashDisbursements);

            List<Cash_Disbursement__c> unPostedViaServiceCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unPostedViaServiceCDs.isEmpty());
        }

    }

    @IsTest
    public static void testCashDisbursementPostServiceUnpostClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Post all cash disbursements
            CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);
            //all test Cash Disbursement records belong to Accounting Period "1991-10" which is first in list of created periods
            //let's try to close this Accounting Period to reproduce currently tested error
            Accounting_Period__c testAcctPeriod = testData.acctPeriods[0];
            testAcctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAcctPeriod;
            Test.stopTest();
            //Let's make it sure
            System.assertEquals(AccountingPeriodActions.CLOSED_STATUS, [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAcctPeriod.Id].Status__c);
            //Now let's try to Unpost these records
            List<PostResult> results = CashDisbursementPostService.unpostCashDisbursements(testData.cashDisbursements);
            //Check for expected error
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, results[0].errors[0].message);
        }

    }

    @IsTest
    public static void testCashDisbursementPostServiceUnpostClearedBankRecError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0];
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, postResults[0].isSuccess);

            testCD = [SELECT Id, Bank_Reconciliation__c, Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id LIMIT 1];
            System.assertEquals('Posted', testCD.Status__c);

            testCD.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
            update testCD;

            testCD = [SELECT Id, Bank_Reconciliation__c, Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id LIMIT 1];
            System.assertEquals(testData.bankReconciliations[0].Id, testCD.Bank_Reconciliation__c);

            List<PostResult> results = CashDisbursementPostService.unpostCashDisbursements(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void tesCashDisbursementPostServiceUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            List<Cash_Disbursement__c> unpostedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unpostedCDs.isEmpty());

            CashDisbursementPostService.postCashDisbursements(testData.cashDisbursements);

            List<Cash_Disbursement__c> postedCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(false, postedCDs.isEmpty());

            List<PostResult> results = CashDisbursementPostService.unpostCashDisbursements(testData.cashDisbursements);

            List<Cash_Disbursement__c> unPostedViaServiceCDs = [
                SELECT Id FROM Cash_Disbursement__c WHERE Status__c = 'Posted'
            ];

            System.assertEquals(true, unPostedViaServiceCDs.isEmpty());
        }

    }
}