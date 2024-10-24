@IsTest
public with sharing class PrintCheckRefundTest {
    
    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPrintCheckRefund() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {

            PrintCheckRefund ctrl = new PrintCheckRefund();
            ctrl.recordId = testData.cashReceipts[0].Id;

            System.assertNotEquals(null, ctrl.check);
            System.assertNotEquals(null, ctrl.check.cashReceipt);
            System.assertEquals(testData.cashReceipts[0].Id, ctrl.check.cashReceipt.Id);

        }
    } 

    @IsTest
    public static void testPrintCheckRefundAddressAPIDefault() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account acct = new Account(
                Name = 'Test Account With Billing Address',
                Alternate_Payee_Name__c = 'TAWBA',
                BillingStreet = 'Some Street',
                BillingCity = 'Some City',
                BillingState = 'Some State',
                BillingPostalCode = '99666',
                BillingCountry = 'Some Country'
            );
            insert acct;

            Billing__c testBilling = testData.billings[2];
            testBilling.Customer__c = acct.Id;
            update testBilling;
            
            CreditsAndRefundsOptions credRefundOpts = new CreditsAndRefundsOptions(testData.billings[2].Id);
            credRefundOpts.refundDate = credRefundOpts.sourceRecordDate;
            credRefundOpts.bankAccount = testData.glAccounts[0].Id;
            ServiceResult result = CreditsAndRefunds.createAndApplyRefundCashReceipt(credRefundOpts);

            System.assertEquals(true, result.isSuccess);

            PrintCheckRefund ctrl = new PrintCheckRefund();
            ctrl.recordId = result.data;

            System.assertNotEquals(null, ctrl.check);
            System.assertNotEquals(null, ctrl.check.cashReceipt);
            System.assertEquals(result.data, ctrl.check.cashReceipt.Id);
            System.assertEquals(acct.Alternate_Payee_Name__c, ctrl.check.payeeName);
            System.assertEquals(
                acct.BillingCity + ' ' + acct.BillingState + ' ' + acct.BillingPostalCode,
                ctrl.check.payeeCityStateZip
            );
            Test.stopTest();
        }
    } 

    @IsTest    
    public static void testPrintCheckRefundGetMethods() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            PrintCheckRefund ctrl = new PrintCheckRefund();
            System.assertEquals(PrintchecksComponent.DATE_TOP_POSITION, ctrl.getDateTopOffset());
            System.assertEquals(PrintchecksComponent.DATE_RIGHT_POSITION, ctrl.getDateRightOffset());

            System.assertEquals(PrintchecksComponent.AMOUNT_TOP_POSITION, ctrl.getAmountTopOffset());
            System.assertEquals(PrintchecksComponent.AMOUNT_RIGHT_POSITION, ctrl.getAmountRightOffset());

            System.assertEquals(PrintchecksComponent.AMOUNT_WORDS_TOP_POSITION, ctrl.getAmountWordsTopOffset());
            System.assertEquals(PrintchecksComponent.AMOUNT_WORDS_LEFT_POSITION, ctrl.getAmountWordsLeftOffset());

            System.assertEquals(PrintchecksComponent.PAYEE_TOP_POSITION, ctrl.getPayeeTopOffset());
            System.assertEquals(PrintchecksComponent.PAYEE_LEFT_POSITION, ctrl.getPayeeLeftOffset());

            System.assertEquals(PrintchecksComponent.PAYEE_ADDRESS_TOP_POSITION, ctrl.getPayeeAddressTopOffset());
            System.assertEquals(PrintchecksComponent.PAYEE_ADDRESS_LEFT_POSITION, ctrl.getPayeeAddressLeftOffset());

            System.assertEquals(PrintchecksComponent.MEMO_TOP_POSITION, ctrl.getMemoTopOffset());
            System.assertEquals(PrintchecksComponent.MEMO_LEFT_POSITION, ctrl.getMemoLeftOffset());
        }

    }
}