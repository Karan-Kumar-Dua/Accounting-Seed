@IsTest
private class APDisbursementVoidBatchTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testDeleteCashDisbursementVoidUpdateAPStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables(false)
                .createCashDisbursementBatches();

        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Account_Payable__c testAccountPayable = testData.payables[5];

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = testData.cashDisbursements[6];
            testCD.Disbursement_Date__c = System.today();
            testCD.Accounting_Period__c = currentPeriod.Id;
            update testCD;

            List<AP_Disbursement__c> newAPDs = new List<AP_Disbursement__c>();
            CashDisbursementVoid.SYNC_RECORDS_LIMIT = 190;
            for (Integer index = 0; index < CashDisbursementVoid.SYNC_RECORDS_LIMIT + 1; index++) {
                newAPDs.add(new AP_Disbursement__c(
                        Status__c = '',
                        Account_Payable__c = testAccountPayable.Id,
                        Paid_Amount__c = 0.1,
                        Accounting_Period__c = currentPeriod.Id,
                        Applied_Date__c = System.today(),
                        Cash_Disbursement__c = testCD.Id
                ));
            }
            insert newAPDs;
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__r.Status__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.voidCashDisbursement();
            Test.stopTest();

            System.assertEquals(
                'Unpaid', [
                    SELECT Payment_Status__c
                    FROM Account_Payable__c
                    WHERE Id = :testAccountPayable.Id
                ].Payment_Status__c
            );
        }
    }
}