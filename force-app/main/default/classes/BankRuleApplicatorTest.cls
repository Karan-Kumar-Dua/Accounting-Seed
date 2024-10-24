@IsTest
private class BankRuleApplicatorTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testInitBankRuleApplicator() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankRules();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BankRuleApplicator brApplicator = BankRuleApplicator.getInstance();
            System.assertEquals(false, brApplicator.cashInRules.isEmpty());
            System.assertEquals(false, brApplicator.cashOutRules.isEmpty());
        }
    }

    @IsTest
    private static void testApplySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashReceipts()
            .createBankTransactions()
            .createBankRules();

        System.runAs(testData.users.get(1)) {

            Bank_Transaction__c bt = DomainUtils.getBankTransactionsById(new Set<Id>{testData.bankTransactions[0].Id})[0];
            bt.Amount__c = 100; //to fit by BR condition
            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            update bt;
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;

            Cash_Receipt__c testCR = testData.cashReceipts[2];
            testCR.Amount__c = 100; //to fit by BR condition
            update testCR;

            BankRuleApplicator brApplicator = BankRuleApplicator.getInstance();

            Test.startTest();
            BDCSourceDocumentsFactory.BDCSourceDocumentUnit unit = brApplicator.apply(bt);

            System.assertEquals('test test test', unit.cashReceipt.getRecord().Description__c);
        }
    }

    @IsTest
    private static void testApplyNoApplicableRules() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankTransactions()
            .createBankRules();

        System.runAs(testData.users.get(1)) {

            Bank_Transaction__c bt = DomainUtils.getBankTransactionsById(new Set<Id>{testData.bankTransactions[0].Id})[0];
            Cash_Receipt__c testCR = testData.cashReceipts[2];

            BankRuleApplicator brApplicator = BankRuleApplicator.getInstance();

            Test.startTest();
            BDCSourceDocumentsFactory.BDCSourceDocumentUnit unit = brApplicator.apply(bt);

            System.assertEquals(NULL, unit);
        }
    }
}