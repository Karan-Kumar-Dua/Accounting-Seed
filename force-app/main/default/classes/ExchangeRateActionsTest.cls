@IsTest
private class ExchangeRateActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testSetDefaultField() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                Exchange_Rate__c newTable = new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = testData.acctPeriods[2].Start_Date__c,
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id),
                    To_Currency_Code__c = newCurrencyIsoCode,
                    Exchange_Rate__c = 0.8,
                    Next_Exchange_Rate__c = testData.exchangeRateTables[0].Id
                );

                insert newTable;

                System.assertEquals(
                    null,
                    [SELECT Id, Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :newTable.Id][0].Next_Exchange_Rate__c
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testNewTableErrorMessage() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                Exchange_Rate__c newTable = new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = testData.acctPeriods[0].Start_Date__c,
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id),
                    To_Currency_Code__c = newCurrencyIsoCode,
                    Exchange_Rate__c = 0.8
                );

                DMLException dmlEx;

                try {
                    insert newTable;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assertEquals(ExchangeRateActions.SAME_TABLE_ERROR, dmlEx.getDmlMessage(0));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testInsertNewTable() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                Exchange_Rate__c lastExisted =
                [SELECT Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :testData.exchangeRateTables[2].Id];

                System.assertEquals(null, lastExisted.Next_Exchange_Rate__c);

                Exchange_Rate__c newTable = new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = testData.acctPeriods[2].Start_Date__c,
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id),
                    To_Currency_Code__c = newCurrencyIsoCode,
                    Exchange_Rate__c = 0.8
                );

                insert newTable;

                lastExisted = [SELECT Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :testData.exchangeRateTables[2].Id];

                System.assertEquals(newTable.Id, lastExisted.Next_Exchange_Rate__c);

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testInsertNewTableList() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                Exchange_Rate__c lastExisted =
                [SELECT Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :testData.exchangeRateTables[2].Id];

                System.assertEquals(null, lastExisted.Next_Exchange_Rate__c);

                List<Exchange_Rate__c> rateTableList = new List<Exchange_Rate__c>();

                Exchange_Rate__c newTable1 = new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = testData.acctPeriods[2].Start_Date__c,
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id),
                    To_Currency_Code__c = newCurrencyIsoCode,
                    Exchange_Rate__c = 0.8
                );
                rateTableList.add(newTable1);

                Exchange_Rate__c newTable2 = new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = testData.acctPeriods[3].Start_Date__c,
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id),
                    To_Currency_Code__c = newCurrencyIsoCode,
                    Exchange_Rate__c = 0.8
                );
                rateTableList.add(newTable2);

                insert rateTableList;

                lastExisted = [SELECT Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :testData.exchangeRateTables[2].Id];
                Exchange_Rate__c newTable1Existed =
                [SELECT Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :newTable1.Id];
                Exchange_Rate__c newTable2Existed =
                [SELECT Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :newTable2.Id];

                System.assertEquals(newTable1.Id, lastExisted.Next_Exchange_Rate__c);
                System.assertEquals(newTable2.Id, newTable1Existed.Next_Exchange_Rate__c);
                System.assertEquals(null, newTable2Existed.Next_Exchange_Rate__c);

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testDeleteMiddleTable() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                delete testData.exchangeRateTables[1];

                System.assertEquals(
                    testData.exchangeRateTables[2].Id, [
                        SELECT Id, Next_Exchange_Rate__c
                        FROM Exchange_Rate__c
                        WHERE Id = :testData.exchangeRateTables[0].Id
                    ].Next_Exchange_Rate__c
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testInsertNewTableForPriorPeriod() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createExchangeRates();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                Exchange_Rate__c firstExisted = testData.exchangeRateTables[0];

                Exchange_Rate__c newTable = new Exchange_Rate__c(
                    Rate_Type__c = 'Monthly Average',
                    Effective_From__c = firstExisted.Effective_From__c.addDays(-10),
                    From_Currency_Code__c = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id),
                    To_Currency_Code__c = newCurrencyIsoCode,
                    Exchange_Rate__c = 0.8
                );
                insert newTable;

                newTable = [SELECT Next_Exchange_Rate__c FROM Exchange_Rate__c WHERE Id = :newTable.Id];
                System.assertEquals(firstExisted.Id, newTable.Next_Exchange_Rate__c);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    //code coverage is required for triggers, and when multi-currency is not enabled this entire test class will get skipped, resulting in 0% trigger code coverage
    public static void testForceTriggerCoverage() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Exchange_Rate__c cert = new Exchange_Rate__c();
            cert.effective_from__c = date.parse('1/1/2022');
            cert.exchange_rate__c = 0.00;
            cert.from_currency_code__c = 'USD';
            cert.to_currency_code__c = 'USD';
            cert.rate_type__c = 'Current';
            insert cert;

            system.assertEquals(
                1,
                [SELECT Id FROM Exchange_Rate__c].size()
            );

            cert.exchange_rate__c = 0.10;
            update cert;
            system.assertEquals(
                0.10,
                [SELECT Id, Exchange_Rate__c FROM Exchange_Rate__c].Exchange_Rate__c
            );
            delete cert;
            Test.stopTest();
            system.assertEquals(
                0,
                [SELECT Id FROM Exchange_Rate__c].size()
            );
        }
    }

}