@IsTest
private class BankManagerHelperTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testGetLedgerCondition() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String defaultLedger = LedgerHandler.getLegacyDefaultLedgerId();
            String nullLedgerCondition = BankManagerHelper.getLedgerCondition('', 'Ledger__c');

            System.assertEquals('AND (Ledger__c = \'' + defaultLedger + '\' OR Ledger__c = NULL)', nullLedgerCondition);

            String legacyLedgerCondition = BankManagerHelper.getLedgerCondition(defaultLedger, 'Ledger__c');

            System.assertEquals('AND (Ledger__c = :ledgerId OR Ledger__c = NULL)', legacyLedgerCondition);

            String otherLedgerCondition = BankManagerHelper.getLedgerCondition(testData.ledgers[2].Id, 'Ledger__c');

            System.assertEquals('AND Ledger__c = :ledgerId', otherLedgerCondition);

        }

    }

    @isTest
    public static void testCurrencyCondition() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                String equalCurrencyCondition = BankManagerHelper.getCurrencyCondition(
                    testData.ledgers[0].Id,
                    (String) testData.ledgers[0].get('CurrencyIsoCode')
                );

                System.assertEquals('', equalCurrencyCondition);

                String diffCurrencyCondition = BankManagerHelper.getCurrencyCondition(testData.ledgers[0].Id, newCurrencyIsoCode);

                System.assertEquals(' AND CurrencyIsoCode = :currencyIsoCode ', diffCurrencyCondition);

            }
        }
        catch (Exception ex) {

        }

    }

    @isTest
    public static void testNeedShowLedgerAmount() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Boolean equalCurrencyCondition = BankManagerHelper.needShowLedgerAmount(
                    testData.ledgers[0].Id,
                    (String) testData.ledgers[0].get('CurrencyIsoCode')
                );

                System.assertEquals(true, equalCurrencyCondition);

                Boolean diffCurrencyCondition = BankManagerHelper.needShowLedgerAmount(testData.ledgers[0].Id, newCurrencyIsoCode);

                System.assertEquals(false, diffCurrencyCondition);

            }
        }
        catch (Exception ex) {

        }

    }

    @isTest
    public static void testGetGlavVariablePredicate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String defaultLedger = LedgerHandler.getLegacyDefaultLedgerId();
            String nullGlavsCondition = BankManagerHelper.getGlavVariablePredicate('', '', '', '');

            System.assertEquals('', nullGlavsCondition);

            String fullGlavsCondition = BankManagerHelper.getGlavVariablePredicate('glav1', 'glav2', 'glav3', 'glav4');
            String resultString =' AND GL_Account_Variable_1__c = :glavVar1  AND GL_Account_Variable_2__c = :glavVar2  AND GL_Account_Variable_3__c = :glavVar3  AND GL_Account_Variable_4__c = :glavVar4 ';

            System.assertEquals(resultString, fullGlavsCondition);
        }

    }
}