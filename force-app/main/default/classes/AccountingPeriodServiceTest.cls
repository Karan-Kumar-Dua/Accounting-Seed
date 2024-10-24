@IsTest
public class AccountingPeriodServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testSetStatusAuthorizationError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String authKey = 'grumpy';

            Exception ex;
            try {
                AccountingPeriodService.setStatus(new List<Accounting_Period__c>{testData.acctPeriods[0]}, 'Archived', authKey);
            }
            catch (AccountingPeriodService.ServiceAuthorizationException tex) {
                ex = tex;
            }

            System.assertEquals(AccountingPeriodService.AUTHORIZATION_ERROR, ex.getMessage());
        }

    }

    @IsTest
    public static void testSetStatusSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
            AccountingPeriodService.setStatus(new List<Accounting_Period__c>{testData.acctPeriods[0]}, 'Archived', authKey);

            System.assertEquals(
                'Archived',[
                    SELECT Id, Status__c
                    FROM Accounting_Period__c
                    WHERE Id = :testData.acctPeriods[0].Id
                ].Status__c
            );
        }

    }

}