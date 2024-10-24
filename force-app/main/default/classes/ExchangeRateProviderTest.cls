@IsTest
private class ExchangeRateProviderTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGetTranslatedAmountForPeriodNoTables() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Ledger__c actualLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(testData.ledgers[0].Id);

                Decimal result = ExchangeRateProvider.getExchangeRateForPeriod(
                    testData.acctPeriods[0].Start_Date__c,
                    testData.acctPeriods[0].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );

                System.assertEquals(1, result);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testGetTranslatedAmountForPeriodSuccess() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                testData.exchangeRateTables[0].To_Currency_Code__c = newCurrencyIsoCode;
                update testData.exchangeRateTables[0];

                Ledger__c actualLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(testData.ledgers[0].Id);

                Decimal result = ExchangeRateProvider.getExchangeRateForPeriod(
                    testData.acctPeriods[0].Start_Date__c,
                    testData.acctPeriods[0].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );

                System.assertEquals(0.95, result);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testGetTranslatedAmountForPeriodGetLatestTable() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                testData.exchangeRateTables[0].To_Currency_Code__c = newCurrencyIsoCode;
                update testData.exchangeRateTables[0];

                Ledger__c actualLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(testData.ledgers[0].Id);

                Decimal result = ExchangeRateProvider.getExchangeRateForPeriod(
                    testData.acctPeriods[1].Start_Date__c,
                    testData.acctPeriods[1].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );

                System.assertEquals(0.98, result);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testIsAllExchangeRateTablesValidNoTables() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                List<ExchangeRateProvider.ExchangeRateWrapper> paramsToValidate = new List<ExchangeRateProvider.ExchangeRateWrapper>();

                Ledger__c actualLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(testData.ledgers[0].Id);

                ExchangeRateProvider.ExchangeRateWrapper cert = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[0].Start_Date__c,
                    testData.acctPeriods[0].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );
                paramsToValidate.add(cert);

                ExchangeRateProvider.AllExchangeRateTablesValidationResult validationResult = ExchangeRateProvider.isAllExchangeRateTablesValid(paramsToValidate);
                System.assertEquals(false, validationResult.isValid);
                System.assertEquals(false, validationResult.notValidRateTables.isEmpty());
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testIsAllExchangeRateTablesValidSuccess() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                List<ExchangeRateProvider.ExchangeRateWrapper> paramsToValidate = new List<ExchangeRateProvider.ExchangeRateWrapper>();

                Ledger__c actualLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(testData.ledgers[0].Id);

                ExchangeRateProvider.ExchangeRateWrapper cert = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[0].Start_Date__c,
                    testData.acctPeriods[0].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );
                paramsToValidate.add(cert);

                ExchangeRateProvider.ExchangeRateWrapper cert1 = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[1].Start_Date__c,
                    testData.acctPeriods[1].Start_Date__c.addDays(15),
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );
                paramsToValidate.add(cert1);

                ExchangeRateProvider.ExchangeRateWrapper cert2 = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[1].Start_Date__c.addDays(15),
                    testData.acctPeriods[1].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );
                paramsToValidate.add(cert2);

                ExchangeRateProvider.AllExchangeRateTablesValidationResult validationResult = ExchangeRateProvider.isAllExchangeRateTablesValid(paramsToValidate);
                System.assertEquals(true, validationResult.isValid);
                System.assertEquals(true, validationResult.notValidRateTables.isEmpty());
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testIsAllExchangeRateTablesValidNotAllExist() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                List<ExchangeRateProvider.ExchangeRateWrapper> paramsToValidate = new List<ExchangeRateProvider.ExchangeRateWrapper>();

                Ledger__c actualLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(testData.ledgers[0].Id);

                ExchangeRateProvider.ExchangeRateWrapper cert = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[0].Start_Date__c,
                    testData.acctPeriods[0].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );
                paramsToValidate.add(cert);

                ExchangeRateProvider.ExchangeRateWrapper cert1 = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[1].Start_Date__c,
                    testData.acctPeriods[1].Start_Date__c.addDays(15),
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );
                paramsToValidate.add(cert1);

                ExchangeRateProvider.ExchangeRateWrapper cert2 = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[1].Start_Date__c.addDays(15),
                    testData.acctPeriods[1].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );
                paramsToValidate.add(cert2);

                ExchangeRateProvider.ExchangeRateWrapper cert3 = new ExchangeRateProvider.ExchangeRateWrapper(
                    testData.acctPeriods[2].Start_Date__c,
                    testData.acctPeriods[2].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    'BY',
                    'Monthly Average'
                );
                paramsToValidate.add(cert3);

                ExchangeRateProvider.AllExchangeRateTablesValidationResult validationResult = ExchangeRateProvider.isAllExchangeRateTablesValid(paramsToValidate);
                System.assertEquals(false, validationResult.isValid);
                System.assertEquals(false, validationResult.notValidRateTables.isEmpty());
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testGetTranslatedAmountForPeriodWithNoEndDateSuccess() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                testData.exchangeRateTables[0].To_Currency_Code__c = newCurrencyIsoCode;
                update testData.exchangeRateTables[0];

                Ledger__c actualLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(testData.ledgers[0].Id);

                Decimal result = ExchangeRateProvider.getExchangeRateForPeriod(
                    testData.acctPeriods[0].Start_Date__c,
                    testData.acctPeriods[0].End_Date__c,
                    (String) actualLedger.get('CurrencyIsoCode'),
                    newCurrencyIsoCode,
                    'Monthly Average'
                );

                System.assertEquals(0.95, result);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }
}