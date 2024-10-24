@IsTest
private class CashDisbursementBatchActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPreventDeleteAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testData.cashDisbursements[0]});
            System.assertEquals(true, postResults[0].isSuccess);

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Status__c, Accounting_Period__r.Status__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[0].Id
                ].Status__c
            );

            DMLException dmlEx;
            try {
                delete testData.cashDisbursementBatch[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(CashDisbursementBatchActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventInsertMaxLineCountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Cash_Disbursement__c> lineList = new List<Cash_Disbursement__c>();
            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT; i++) {
                lineList.add(testData.cashDisbursements[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                CashDisbursementActions.isBypassGLAccountValidations = true;
                insert lineList;
                CashDisbursementActions.isBypassGLAccountValidations = false;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SObjectActions.MAX_LINE_ERROR, new List<String> {String.valueOf(SObjectActions.MAX_LINE_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
            Test.stopTest();
        }

    }

    @IsTest
    private static void testPreventInsertMaxLineCountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Cash_Disbursement__c> lineList = new List<Cash_Disbursement__c>();
            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT - 100; i++) {
                lineList.add(testData.cashDisbursements[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                CashDisbursementActions.isBypassGLAccountValidations = true;
                insert lineList;
                CashDisbursementActions.isBypassGLAccountValidations = false;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPreventUpdateCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users[1]) {
                Test.startTest();
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }
                //update currency on the existed CDB with related CD
                Cash_Disbursement_Batch__c testCashDisbursementBatch = testData.cashDisbursementBatch[0];

                DMLException dmlEx;
                try {
                    testCashDisbursementBatch.put('CurrencyIsoCode', newCurrency);
                    update testCashDisbursementBatch;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(CashDisbursementBatchActions.UPDATE_CURRENCY_ERROR, dmlEx.getDmlMessage(0));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    private static void testCashDisbursementBatchNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Cash_Disbursement_Batch__c cdb = new Cash_Disbursement_Batch__c();
                insert cdb;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            if (dmlEx != NULL) {
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
    }

    @IsTest
    private static void testCashDisbursementBatchNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users[1]) {
                DMLException dmlEx;

                Cash_Disbursement_Batch__c cdb = new Cash_Disbursement_Batch__c();

                try {
                    insert cdb;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                if (dmlEx != NULL) {
                    System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
                }
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    private static void testDeleteCashDisbursementBatchAndUpdateBTs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            testData.bankTransactions[0].Status__c = BankTransactionsHelper.BT_ADDED_STATUS;
            testData.cashDisbursements[0].Bank_Transaction__c = testData.bankTransactions[0].Id;

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Transaction__c);
            update testData.cashDisbursements[0];
            TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Bank_Transaction__c);

            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            update testData.bankTransactions[0];
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;

            System.assertEquals(
                BankTransactionsHelper.BT_ADDED_STATUS,
                [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testData.bankTransactions[0].Id].Status__c
            );

            delete testData.cashDisbursementBatch[0];

            System.assertEquals(
                BankTransactionsHelper.BT_UNMATCHED_STATUS,
                [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testData.bankTransactions[0].Id].Status__c
            );
        }
    }

}