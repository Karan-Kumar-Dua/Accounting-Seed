@IsTest
private class ExchangeRateFieldUpdateValidatorTest {
    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventUpdateAction() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();
            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                Test.startTest();
                SourceDocumentUpdateFieldValidator sfu = new ExchangeRateTableFieldUpdateValidator();
                DMLException dmlEx;

                try {
                    testData.exchangeRateTables[0].Next_Exchange_Rate__c = testData.exchangeRateTables[2].Id;
                    update testData.exchangeRateTables[0];
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assertEquals(String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                    dmlEx.getDmlMessage(0));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }
}