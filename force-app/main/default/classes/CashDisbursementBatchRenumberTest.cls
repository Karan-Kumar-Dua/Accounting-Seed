@IsTest
private class CashDisbursementBatchRenumberTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testCashDisbursementBatchRenumber() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.cashDisbursementBatch[0].Starting_Check_Number__c = 2;
            update testData.cashDisbursementBatch[0];

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.cashDisbursementBatch[0]);
            CashDisbursementBatchRenumber controller = new CashDisbursementBatchRenumber(stdController);
            controller.renumberChecks();

            System.assertEquals(
                2, [
                    SELECT Check_Number__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[0].Id
                ].Check_Number__c
            );
            System.assertEquals(
                3, [
                    SELECT Check_Number__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[1].Id
                ].Check_Number__c
            );
            System.assertEquals(
                4, [
                    SELECT Check_Number__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[2].Id
                ].Check_Number__c
            );
        }

    }

    @IsTest
    private static void testPostedCDError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[0];

            List<Cash_Disbursement__c> testCDs = new List<Cash_Disbursement__c>{
                testData.cashDisbursements[0],
                testData.cashDisbursements[1],
                testData.cashDisbursements[2]
            };
            //Post all CDs related to given CDB
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(testCDs);
            System.assertEquals(true, postResults[0].isSuccess);

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCDB);
            CashDisbursementBatchRenumber controller = new CashDisbursementBatchRenumber(stdController);

            System.assertEquals(false, controller.isValidationPassed);
            System.assertEquals(CashDisbursementBatchRenumber.POSTED_CD_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    private static void testNoStartingNumberError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[0];
            testCDB.Starting_Check_Number__c = NULL;
            update testCDB;

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCDB);
            CashDisbursementBatchRenumber controller = new CashDisbursementBatchRenumber(stdController);

            System.assertEquals(false, controller.isValidationPassed);
            System.assertEquals(CashDisbursementBatchRenumber.NO_STARTING_NUMBER_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

}