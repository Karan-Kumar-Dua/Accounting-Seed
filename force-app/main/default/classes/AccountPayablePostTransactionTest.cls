@IsTest
public class AccountPayablePostTransactionTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPayablePostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.payables[0].Status__c = 'Approved';
            update testData.payables[0];

            // Test post functionality
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id FROM Account_Payable__c WHERE Id = :testData.payables[0].Id
            ]);
            setController.setSelected(setController.getRecords());

            AccountPayablePostTransaction pt = new AccountPayablePostTransaction(setController);
            pt.post();

            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables[0].Id]);
            System.assertEquals('Posted', [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Status__c);
            System.assertEquals(0, [SELECT sum(Amount__c) sum FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables[0].Id GROUP BY Account_Payable_Line__r.Account_Payable__c][0].get('sum'));

            setController = new ApexPages.StandardSetController([SELECT Id FROM Account_Payable__c WHERE Id IN :testData.payables]);
            setController.setSelected(setController.getRecords());
            pt = new AccountPayablePostTransaction(setController);
            // Test unpost functionality
            pt.unpost();

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables[0].Id]);
            System.assertEquals('Approved', [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Status__c);
        }

    }

    @IsTest
    public static void testPayableUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>{
                testData.payables[0],
                testData.payables[1]
            };
            //Test unpost functionality
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(accountPayables);
            setController.setSelected(setController.getRecords());
            AccountPayablePostTransaction controller = new AccountPayablePostTransaction(setController);
            controller.validateBeforeUnpost();

            System.assertEquals(NULL, controller.errorStatisticsLines);
            System.assertEquals(true, controller.showActionButton);

            controller.unpost();

            System.assertEquals(
                'Approved',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Status__c
            );
            System.assertEquals(
                'Approved',
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables[1].Id].Status__c
            );
        }

    }

    @IsTest
    public static void testPayableUnpostNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            // Test post functionality
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);
            AccountPayablePostTransaction pt = new AccountPayablePostTransaction(setController);
            // Test unpost functionality
            pt.unpost();

            System.assertEquals(AccountPayablePostHandler.NO_SELECTION_UNPOST_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testAccountPayablePostBatchNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Account_Payable__c testPayable = testData.payables[0];
            testPayable.Status__c = 'In Process';
            update testPayable;

            Test.startTest();  
            // Test post functionality
            ApexPages.StandardSetController setController =
                new ApexPages.StandardSetController(new List<Account_Payable__c>{testPayable});
            setController.setSelected(setController.getRecords());
            AccountPayablePostTransaction controller = new AccountPayablePostTransaction(setController);

            controller.validateBeforePost();
            Test.stopTest();

            System.assertEquals(1, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testPayable.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(
                String.valueOf(testPayable.Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.STATUS_NOT_APPROVED.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }


    //=============================================================================
    //===== Group of test methods related to the Multi Currency functionality =====
    //=============================================================================

    @IsTest
    public static void testPayablePostSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables();

            System.runAs(testData.users[1]) {
                Account_Payable__c testAcctPayable = testData.payables[0];
                testAcctPayable.Status__c = 'Approved';

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrency)) {
                    return;
                }

                testAcctPayable.put('CurrencyIsoCode', newCurrency);
                testAcctPayable.Currency_Conversion_Rate__c = 0.90;//1 USD = 0.9 EUR
                update testAcctPayable;

                //Check if currency Conversion Rate was set properly
                testAcctPayable = [SELECT Id, Currency_Conversion_Rate__c FROM Account_Payable__c WHERE Id = :testAcctPayable.Id LIMIT 1];
                System.assertEquals(false, testAcctPayable.Currency_Conversion_Rate__c == NULL);


                // Test post functionality
                ApexPages.StandardController controller = new ApexPages.StandardController(testAcctPayable);
                AccountPayablePostTransaction pt = new AccountPayablePostTransaction(controller);
                pt.post();

                //check results
                List<Transaction__c> newTransactions = [
                    SELECT  Id,
                            Foreign_Amount__c,
                            Foreign_Currency__c,
                            Currency_Conversion_Rate__c,
                            Amount__c
                    FROM Transaction__c
                    WHERE Account_Payable_Line__r.Account_Payable__c = :testAcctPayable.Id
                    AND Foreign_Amount__c != NULL
                    AND Foreign_Currency__c != NULL
                    AND Currency_Conversion_Rate__c != NULL
                ];
                System.assertEquals(6, newTransactions.size());
                System.assertEquals('Posted', [SELECT Status__c FROM Account_Payable__c WHERE Id = :testAcctPayable.Id].Status__c);
                System.assertEquals(
                    0, [
                        SELECT sum(Foreign_Amount__c) sum
                        FROM Transaction__c
                        WHERE Account_Payable_Line__r.Account_Payable__c = :testAcctPayable.Id
                        GROUP BY Account_Payable_Line__r.Account_Payable__c
                    ][0].get('sum')
                );
                System.assertEquals(
                    newCurrency, [
                        SELECT Foreign_Currency__c
                        FROM Transaction__c
                        WHERE Account_Payable_Line__r.Account_Payable__c = :testAcctPayable.Id
                    ][0].Foreign_Currency__c
                );
            }
        }
        catch (Exception ex) {

        }

    }

}