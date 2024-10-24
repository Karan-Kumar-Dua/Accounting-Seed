@IsTest
private class AccountingPeriodOpenCubesDeletionTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBehavior() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createExchangeRates()
                .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                        GL_Account__c = testData.glAccounts[7].Id,
                        Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;

                testData.glAccounts[10].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[10];

                System.assertEquals(false, [SELECT Id, GL_Account__c FROM Financial_Cube__c].isEmpty());

                AccountingPeriodActions.isFirstRun = false;
                testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testData.acctPeriods[0];
                AccountingPeriodActions.isFirstRun = true;

                FinancialCubeTranslationBatch translationBatch =
                    new FinancialCubeTranslationBatch(
                        new Set<Id>{testData.ledgers[0].Id},
                        testData.acctPeriods[0].Id,
                        newCurrencyIsoCode
                    );
                Database.QueryLocatorIterator queryLocatorIterator = translationBatch.start(null).iterator();
                List<Financial_Cube__c> scope = new List<Financial_Cube__c>();
                while (queryLocatorIterator.hasNext()) {
                    scope.add((Financial_Cube__c) queryLocatorIterator.next());
                }

                translationBatch.execute(null, scope);
                translationBatch.finish(null);

                System.assertEquals(false, [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true].isEmpty());

                Test.startTest();
                testData.acctPeriods[0].Status__c = AccountingPeriodActions.OPEN_STATUS;
                update testData.acctPeriods[0];
                Test.stopTest();

                System.assertEquals(true, [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true].isEmpty());
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

}