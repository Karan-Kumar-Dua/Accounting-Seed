@IsTest
public class CashReceiptPostTest {

    @TestSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCashReceiptBatchPost() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts
            ]);
            setController.setSelected(setController.getRecords());
            CashReceiptPost crp = new CashReceiptPost(setController);
            crp.unpost();
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c IN :testData.cashReceipts]);

            setController = new ApexPages.StandardSetController([
                SELECT Id FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts
            ]);
            setController.setSelected(setController.getRecords());
            crp = new CashReceiptPost(setController);
            crp.post();
            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c IN :testData.cashReceipts]);
        }
    }

    @IsTest
    public static void testCashReceiptPostPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Need to unpost to start test as cash receipts are auto posted when created
            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Accounting_Period__r.Status__c, Status__c, Number_of_Billing_Cash_Receipts__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ]);
            CashReceiptPost crp = new CashReceiptPost(controller);
            crp.unpost();
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testData.cashReceipts[0].Id]);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[1];

            controller = new ApexPages.StandardController([
                SELECT Id, Accounting_Period__r.Status__c, Status__c, Number_of_Billing_Cash_Receipts__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ]);
            crp = new CashReceiptPost(controller);
            crp.post();
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testCashReceiptBatchPostNoSelectionClosedPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c testCR = testData.cashReceipts[0];
            //Unpost Cash Receipt
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> results = postHandler.unpost(new List<Cash_Receipt__c>{testCR});

            System.assertEquals(true, results[0].isSuccess);
            //Check unpost functionality
            System.assertEquals(
                'Approved', [
                    SELECT Status__c
                    FROM Cash_Receipt__c
                    WHERE Id = :testCR.Id
                ].Status__c
            );

            //now close Accounting Period and try to post these records
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update new List<Accounting_Period__c>{testData.acctPeriods[0], testData.acctPeriods[1]};

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Cash_Receipt__c>{testCR}
            );
            setController.setSelected(setController.getRecords());
            CashReceiptPost controller = new CashReceiptPost(setController);
            controller.validateBeforePost();

            System.assertEquals(1, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testCR.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(
                String.valueOf(testData.acctPeriods[1].Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }

    @IsTest
    public static void testCashReceiptUnpost() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Accounting_Period__r.Status__c, Status__c, Number_of_Billing_Cash_Receipts__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ]);

            CashReceiptPost crp = new CashReceiptPost(controller);
            crp.unpost();
            System.assertEquals('Approved', [SELECT Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Cash_Receipt__c = :testData.cashReceipts[0].Id]);
        }

    }

    @IsTest
    public static void testCashReceiptUnpostBankDepositError() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankDeposits();

        System.runAs(testData.users[1]) {
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            testData.cashReceipts[0].Status__c = 'Posted';

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Id, Accounting_Period__r.Status__c, Status__c, Number_of_Billing_Cash_Receipts__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ]);

            CashReceiptPost crp = new CashReceiptPost(controller);
            crp.unpost();
            System.assertEquals(CashReceiptPostHandler.UNPOST_DEPOSIT_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testCashReceiptBatchNoRecordsSelected() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ]);

            CashReceiptPost crp = new CashReceiptPost(setController);
            crp.post();
            System.assertEquals(AbstractPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
            crp.unpost();
            System.assertEquals(CashReceiptPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE, ApexPages.getMessages()[1].getSummary());
        }

    }

}