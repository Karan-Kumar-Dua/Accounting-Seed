@isTest
private class CashDisbursementBRemittanceComponentTest {

    private static List<RemittanceWrapper> createRemittances(TestDataSuite testData, Integer countRemittances) {
        List<RemittanceWrapper> result = new List<RemittanceWrapper>();
        Account_Payable__c ap = testData.payables.get(0);
        for (Integer i = 0; i < countRemittances; i++) {
            result.add(new RemittanceWrapper(ap, i * 20));
        }
        return result;
    }

    private static CashDisbursementWrapper createCashDisbursement(TestDataSuite testData, Integer countRemittances) {
        CashDisbursementWrapper result = new CashDisbursementWrapper(
            testData.cashDisbursements.get(0),
            createRemittances(testData, countRemittances),
            false
        );
        return result;
    }

    private static List<CashDisbursementWrapper> createCashDisbursements(TestDataSuite testData,
                                                                        Integer countDisbursements,
                                                                        Integer countRemittances) {

        List<CashDisbursementWrapper> result = new List<CashDisbursementWrapper>();
        for (Integer i = 0; i < countDisbursements; i++) {
            result.add(createCashDisbursement(testData, countRemittances));
        }
        return result;
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testNullDisbursements() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            CashDisbursementBatchRemittanceComponent cmp = new CashDisbursementBatchRemittanceComponent();

            Test.startTest();
            System.assertNotEquals(NULL, cmp.cCashDisbursements);
            System.assertNotEquals(NULL, cmp.offsetsByCashDisbursement);
            System.assertEquals(0, cmp.cCashDisbursements.size());
            System.assertEquals(0, cmp.offsetsByCashDisbursement.size());
            Test.stopTest();
        }

    }

    @IsTest
    private static void testOneDisbursements() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            CashDisbursementWrapper cdw = createCashDisbursements(testData, 1, 0).get(0);
            CashDisbursementBatchRemittanceComponent cmp = new CashDisbursementBatchRemittanceComponent();
            cmp.cCashDisbursement = cdw;
            cmp.cShowRemittances = true;
            cmp.cLimitRemittances = 10;
            cmp.cPerPageRemittances = 5;

            Test.startTest();
            System.assertNotEquals(NULL, cmp.cCashDisbursements);
            System.assertNotEquals(NULL, cmp.offsetsByCashDisbursement);
            System.assertEquals(1, cmp.cCashDisbursements.size());
            System.assertEquals(1, cmp.offsetsByCashDisbursement.size());
            Test.stopTest();
        }

    }

    @IsTest
    private static void testFewDisbursements() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            List<CashDisbursementWrapper> cdws = createCashDisbursements(testData, 10, 20);
            CashDisbursementBatchRemittanceComponent cmp = new CashDisbursementBatchRemittanceComponent();
            cmp.cCashDisbursements = cdws;
            cmp.cShowRemittances = true;
            cmp.cLimitRemittances = 10;
            cmp.cPerPageRemittances = 5;

            Test.startTest();
            System.assertNotEquals(NULL, cmp.cCashDisbursements);
            System.assertNotEquals(NULL, cmp.offsetsByCashDisbursement);
            System.assertEquals(cdws.size(), cmp.cCashDisbursements.size());

            //Because we inserted Cash Disbursement wrappers with the same Id
            System.assertEquals(1, cmp.offsetsByCashDisbursement.size());

            System.assertEquals(
                cdws.get(0).remittances.size(),
                cmp.cCashDisbursements.get(0).remittances.size()
            );
            Integer totalRemittances = cdws.get(0).remittances.size();
            Integer limitRemittances = (cmp.cLimitRemittances < totalRemittances) ? cmp.cLimitRemittances : totalRemittances;
            System.assertEquals(
                Math.ceil(limitRemittances / cmp.cPerPageRemittances),
                cmp.offsetsByCashDisbursement.get(cdws.get(0).cashDisbursement.Id).size()
            );
            Test.stopTest();
        }
    }

}