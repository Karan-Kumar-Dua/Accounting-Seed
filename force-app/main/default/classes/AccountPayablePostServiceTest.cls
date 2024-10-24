@IsTest
public class AccountPayablePostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Account_Payable__c testPayable1 = testData.payables.get(0);
            Account_Payable__c testPayable2 = testData.payables.get(1);

            testPayable1.Status__c = 'In Process';
            update testPayable1;

            List<PostResult> postResults = AccountPayablePostService.postAccountPayables(
                new List<Account_Payable__c>{testPayable1, testPayable2}
            );
            System.assertEquals(2, postResults.size());

            PostResult testPayable1PostResult;
            PostResult testPayable2PostResult;
            for (PostResult postResult : postResults) {
                if (postResult.id == testPayable1.Id) {
                    testPayable1PostResult = postResult;
                }
                if (postResult.id == testPayable2.Id) {
                    testPayable2PostResult = postResult;
                }
            }

            System.assertEquals(false, testPayable1PostResult.isSuccess);
            System.assertEquals(true, testPayable2PostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.NOT_APPROVED_ERROR_MESSAGE, testPayable1PostResult.errors.get(0).message);
        }

    }

    @IsTest
    public static void testUnPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Account_Payable__c testPayable1 = testData.payables.get(0);
            Account_Payable__c testPayable2 = testData.payables.get(1);

            testPayable1.Status__c = 'In Process';
            update testPayable1;

            List<PostResult> postResults = AccountPayablePostService.postAccountPayables(
                new List<Account_Payable__c>{testPayable1, testPayable2}
            );

            List<PostResult> unpostResults = AccountPayablePostService.unpostAccountPayables(
                new List<Account_Payable__c>{testPayable1, testPayable2}
            );

            System.assertEquals(2, unpostResults.size());

            PostResult testPayable1UnPostResult;
            PostResult testPayable2UnPostResult;
            for (PostResult postResult : unpostResults) {
                if (postResult.id == testPayable1.Id) {
                    testPayable1UnPostResult = postResult;
                }
                if (postResult.id == testPayable2.Id) {
                    testPayable2UnPostResult = postResult;
                }
            }

            System.assertEquals(false, testPayable1UnPostResult.isSuccess);
            System.assertEquals(true, testPayable2UnPostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.UNPOSTED_ERROR_MESSAGE, testPayable1UnPostResult.errors.get(0).message);
        }

    }

    @IsTest
    public static void testPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            update testData.payables[0];

            List<PostResult> results = AccountPayablePostService.postAccountPayables(
                new List<Account_Payable__c>{testData.payables[0]}
            );
            System.assertEquals(true, results[0].isSuccess);
        }

    }

    @IsTest
    public static void testUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[3].Status__c = 'Approved';
            update testData.payables[3];

            List<PostResult> results = AccountPayablePostService.postAccountPayables(
                new List<Account_Payable__c>{testData.payables[3]}
            );
            System.assertEquals(true, results[0].isSuccess);

            results = AccountPayablePostService.unpostAccountPayables(
                new List<Account_Payable__c>{testData.payables[3]}
            );
            System.assertEquals(true, results[0].isSuccess);
        }
    }

    @IsTest
    public static void testStatusNoControlAPPostError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            testData.payables[0].Status__c = 'Approved';
            update testData.payables[0];

            List<PostResult> results = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testPostSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables();

            System.runAs(testData.users[1]) {
                Test.startTest();

                AccountingSettingsHandler.acctSeedSettings = NULL;
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }
                Account_Payable__c testAcctPayable = testData.payables[0];
                testAcctPayable.Status__c = 'Approved';
                testAcctPayable.put('CurrencyIsoCode', newCurrency);
                update testAcctPayable;

                //Check if currency Conversion Rate was set properly
                testAcctPayable = [
                    SELECT Id, Currency_Conversion_Rate__c
                    FROM Account_Payable__c
                    WHERE Id = :testAcctPayable.Id LIMIT 1
                ];
                System.assertEquals(false, testAcctPayable.Currency_Conversion_Rate__c == NULL);

                List<PostResult> results = AccountPayablePostService.postAccountPayables(
                    new List<Account_Payable__c>{testAcctPayable}
                );
                System.assertEquals(true, results[0].isSuccess);
            }
        }
        catch (Exception ex) {

        }

    }

}