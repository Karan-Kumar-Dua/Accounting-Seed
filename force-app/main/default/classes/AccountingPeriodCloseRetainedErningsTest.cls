@IsTest
public with sharing class AccountingPeriodCloseRetainedErningsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }


    @IsTest
    private static void testCalculateRetainedEarningsNextPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
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

            Financial_Cube__c testRetEarningsCube = new Financial_Cube__c(
                Ledger__c = testData.ledgers.get(0).Id,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Year__c = testData.acctPeriods.get(0).Start_Date__c.year(),
                GL_Account__c = testData.glAccounts.get(0).Id,
                Opening_Balance__c = 100,
                Cube_Type__c = 'Retained Earnings'
            );
            FinancialCubeActions.isPreventOverride = true;
            insert testRetEarningsCube;
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(1, [SELECT count() FROM Financial_Cube__c WHERE Cube_Type__c = 'Retained Earnings' AND Accounting_Period__c = :testData.acctPeriods[0].Id]);

            AccountingPeriodOpenCloseOptions periodInfoContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods[0]},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            Test.startTest();
            Database.executeBatch(new AccountingPeriodCloseRetainedEarnings(periodInfoContainer));
            Test.stopTest();

            List<Financial_Cube__c> testRetEarningsCubes = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE Cube_Type__c = 'Retained Earnings'
                AND Accounting_Period__c = :testData.acctPeriods[1].Id
            ];
            System.assertEquals(1, testRetEarningsCubes.size());
            System.assertEquals(100, testRetEarningsCubes[0].Opening_Balance__c);
        }
    }

}