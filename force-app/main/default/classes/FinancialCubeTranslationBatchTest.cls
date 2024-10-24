@IsTest
private class FinancialCubeTranslationBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testNoCTAAccountError() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
                System.assert(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CTA_GL_ACCOUNT)?.GL_Account__c == null);
                Test.startTest();
                Database.executeBatch(
                    new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode));
                Test.stopTest();

                List<Financial_Cube__c> result = [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true];

                System.assert(result.isEmpty());
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCreateTranslationCubeNoGlAccountRateType() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                        GL_Account__c = testData.glAccounts[7].Id,
                        Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;
                GLAccountDefaultsHandler.instance = null;

                Test.startTest();
                Database.executeBatch(
                    new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode));
                Test.stopTest();

                List<Financial_Cube__c> result = [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true];

                System.assert(result.isEmpty());

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCreateTranslationCubeSuccess() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                        GL_Account__c = testData.glAccounts[7].Id,
                        Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;
                GLAccountDefaultsHandler.instance = null;

                testData.glAccounts[2].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[2];

                testData.glAccounts[10].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[10];

                List<Financial_Cube__c> existed = [SELECT Id, GL_Account__c FROM Financial_Cube__c];

                System.assert(!existed.isEmpty());

                Test.startTest();
                Database.executeBatch(
                    new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode));
                Test.stopTest();

                List<Financial_Cube__c> result = [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true];

                System.assert(!result.isEmpty());
                System.assertEquals(existed.size(), result.size());


            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCreateTranslationCubePartExpenseTableExist() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings(true)
                .createCashDisbursementBatches();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                testData.createCashDisbursements(true);
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                        GL_Account__c = testData.glAccounts[7].Id,
                        Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;
                GLAccountDefaultsHandler.instance = null;

                testData.glAccounts[10].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[10];
                testData.glAccounts[23].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[23];
                testData.glAccounts[4].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[4];

                List<Financial_Cube__c> existed = [SELECT Id, GL_Account__c FROM Financial_Cube__c];

                System.assert(!existed.isEmpty());

                Database.executeBatch(
                    new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode));
                Test.stopTest();

                List<Financial_Cube__c> result = [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true];

                System.assertNotEquals(existed.size() + 1, result.size());

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testValidateTranslationCubeRateSuccess() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                        GL_Account__c = testData.glAccounts[7].Id,
                        Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;
                GLAccountDefaultsHandler.instance = null;

                testData.glAccounts[2].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[2];

                testData.glAccounts[10].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[10];

                List<Financial_Cube__c> existed = [SELECT Id, GL_Account__c FROM Financial_Cube__c];

                System.assert(!existed.isEmpty());

                Test.startTest();
                Database.executeBatch(
                    new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode));
                Test.stopTest();

                List<Financial_Cube__c> result = [SELECT Id, Translated_Rate__c, GL_Account__c FROM Financial_Cube__c WHERE IsTranslatedCube__c = true];

                System.assert(!result.isEmpty());
                System.assertEquals(existed.size(), result.size());

                for (Financial_Cube__c fc : result) {
                    if (fc.GL_Account__c != testData.glAccounts[7].Id) {
                        System.assertEquals(testData.exchangeRateTables[0].Exchange_Rate__c, fc.Translated_Rate__c);
                    }
                }

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testValidateTranslationCubeRateCreateCTASuccess() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                        GL_Account__c = testData.glAccounts[7].Id,
                        Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;
                GLAccountDefaultsHandler.instance = null;

                testData.glAccounts[2].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[2];

                testData.glAccounts[10].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[10];

                List<Financial_Cube__c> existed = [SELECT Id, GL_Account__c FROM Financial_Cube__c];

                FinancialCubeActions.isPreventOverride = true;
                delete existed[0];
                FinancialCubeActions.isPreventOverride = false;

                System.assert(!existed.isEmpty());

                Test.startTest();
                Database.executeBatch(
                    new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode));
                Test.stopTest();

                List<Financial_Cube__c> result = [SELECT Id, Translated_Rate__c, GL_Account__c FROM Financial_Cube__c WHERE IsTranslatedCube__c = true];

                System.assert(!result.isEmpty());
                System.assertEquals(existed.size(), result.size());

                Boolean isCTAExist = false;
                for (Financial_Cube__c fc : result) {
                    if (fc.GL_Account__c != testData.glAccounts[7].Id) {
                        System.assertEquals(testData.exchangeRateTables[0].Exchange_Rate__c, fc.Translated_Rate__c);
                    }
                    else {
                        isCTAExist = true;
                    }
                }

                System.assert(isCTAExist);

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testSkipExchangeRateValidationForCYE() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }

                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
                Financial_Cube__c testCurrentPeriodEarningsCube = new Financial_Cube__c(
                    Ledger__c = testData.ledgers.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id,
                    Year__c = testData.acctPeriods.get(0).Start_Date__c.year(),
                    GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT)?.GL_Account__c,
                    Opening_Balance__c = 200,
                    Cube_Type__c = 'Current Year Earnings'
                );
                FinancialCubeActions.isPreventOverride = true;
                insert testCurrentPeriodEarningsCube;
                FinancialCubeActions.isPreventOverride = false;

                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                    GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                    GL_Account__c = testData.glAccounts[7].Id,
                    Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;
                GLAccountDefaultsHandler.instance = null;

                testData.glAccounts[2].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[2];

                testData.glAccounts[10].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[10];

                List<Financial_Cube__c> existed = [SELECT Id, GL_Account__c FROM Financial_Cube__c];

                FinancialCubeActions.isPreventOverride = true;
                delete existed[0];
                FinancialCubeActions.isPreventOverride = false;

                System.assert(!existed.isEmpty());

                GL_Account__c cyeAccount = [SELECT Id, Rate_Type__c FROM GL_Account__c WHERE Id = :(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT).GL_Account__c) LIMIT 1];
                System.assertEquals(null, cyeAccount.Rate_Type__c);

                Test.startTest();
                Database.executeBatch(
                    new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode));
                Test.stopTest();

                List<Financial_Cube__c> result = [SELECT Id, Translated_Rate__c, GL_Account__c, GL_Account__r.Name FROM Financial_Cube__c WHERE IsTranslatedCube__c = true];

                System.assert(!result.isEmpty());
                System.assertEquals(existed.size(), result.size());

                Boolean isCYEExist = false;
                Boolean isCTAExist = false;
                for (Financial_Cube__c fc : result) {
                    if (fc.GL_Account__c != testData.glAccounts[9].Id && fc.GL_Account__c != testData.glAccounts[7].Id) {
                        System.assertEquals(testData.exchangeRateTables[0].Exchange_Rate__c, fc.Translated_Rate__c);
                    }
                    else if (fc.GL_Account__c != testData.glAccounts[9].Id) {
                        isCYEExist = true;
                        System.assertEquals(null, fc.Translated_Rate__c);
                    }
                    else if (fc.GL_Account__c != testData.glAccounts[7].Id) {
                        isCTAExist = true;
                        System.assertEquals(1, fc.Translated_Rate__c);
                    }
                }

                System.assert(isCYEExist);
                System.assert(isCTAExist);

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }
}