@IsTest
private class APDisbursementPostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testAPIPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 10
            );
            insert testApDisbursement;

            List<Transaction__c> transactions = [
                SELECT Id, Amount__c FROM Transaction__c WHERE AP_Disbursement__c = :testApDisbursement.Id
            ];
            System.assertEquals(0, transactions.size());

            List<PostResult> postResults = APDisbursementPostService.postApDisbursements(
                new List<AP_Disbursement__c>{testApDisbursement}
            );
            System.assertEquals(true, postResults[0].isSuccess);

            transactions = [
                SELECT Id, Amount__c FROM Transaction__c WHERE AP_Disbursement__c = :testApDisbursement.Id
            ];
            System.assertEquals(2, transactions.size());

            Transaction__c debitLine;
            Transaction__c creditLine;
            for (Transaction__c trans : transactions) {
                if (trans.Amount__c > 0) {
                    debitLine = trans;
                }
                else if (trans.Amount__c < 0) {
                    creditLine = trans;
                }
            }
            System.assertEquals(10, debitLine.Amount__c);
            System.assertEquals(-10, creditLine.Amount__c);
        }
    }

}