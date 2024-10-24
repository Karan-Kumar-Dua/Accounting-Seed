@IsTest
public class CashDisbursementWrapperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCashDisbursementWrapperSort() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createPayables();

        System.runAs(testData.users[1]) {
            List<CashDisbursementWrapper> cdwList = new List<CashDisbursementWrapper>();

            cdwList.add(
                new CashDisbursementWrapper(
                    testData.cashDisbursements[1],
                    testData.contacts[0].Name,
                    0,
                    0,
                    0,
                    0,
                    new List<Account_Payable__c>{testData.payables[1]}
                )
            );

            cdwList.add(
                new CashDisbursementWrapper(
                    testData.cashDisbursements[0],
                    testData.accounts[0].Name,
                    0,
                    0,
                    0,
                    0,
                    new List<Account_Payable__c>{testData.payables[0]}
                )
            );

            cdwList.sort();

            System.assertEquals(cdwList[0].payee, testData.accounts[0].Name);
            System.assertEquals(cdwList[1].payee, testData.contacts[0].Name);
        }
    }

}