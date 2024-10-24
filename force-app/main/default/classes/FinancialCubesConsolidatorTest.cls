@IsTest
public with sharing class FinancialCubesConsolidatorTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testOutputCubesHavePopulatedFields() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Id ledger = [SELECT Id FROM Ledger__c WHERE Name = 'Consolidation ledger1'].Id;
            Id period = testData.acctPeriods[0].Id;

            Financial_Cube__c cube = new Financial_Cube__c(
                Ledger__c = testData.ledgers[0].Id,
                Accounting_Period__c = period,
                GL_Account__c = testData.glAccounts[0].Id,
                GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                GL_Account_Variable_3__c = testData.accountingVariables3[0].Id,
                GL_Account_Variable_4__c = testData.accountingVariables4[0].Id,
                Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
                Amount__c = 1111.11,
                Opening_Balance__c = 2222.22
            );
            FinancialCubeActions.isPreventOverride = true;
            insert cube;
            FinancialCubeActions.isPreventOverride = false;

            cube = [
                SELECT Id,
                    Name,
                    GL_Account__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Opening_Balance__c,
                    Current_Period__c,
                    Amount__c,
                    Ledger__c,
                    Ledger__r.Accounting_Method__c
                FROM Financial_Cube__c
                WHERE Id = :cube.Id
            ];
            
            Test.startTest();
            FinancialCubesConsolidator consolidator = new FinancialCubesConsolidator(ledger, period);
            consolidator.addCube(cube);
            List<Financial_Cube__c> results = consolidator.getConsolidationCubes();
            Test.stopTest();

            System.assertEquals(1, results.size());
            System.assertEquals(ledger, results[0].Ledger__c);
            System.assertEquals(period, results[0].Accounting_Period__c);
            System.assertEquals(cube.GL_Account__c, results[0].GL_Account__c);
            System.assertEquals(cube.GL_Account_Variable_1__c, results[0].GL_Account_Variable_1__c);
            System.assertEquals(cube.GL_Account_Variable_2__c, results[0].GL_Account_Variable_2__c);
            System.assertEquals(cube.GL_Account_Variable_3__c, results[0].GL_Account_Variable_3__c);
            System.assertEquals(cube.GL_Account_Variable_4__c, results[0].GL_Account_Variable_4__c);
            System.assertEquals(cube.Amount__c, results[0].Amount__c);
            System.assertEquals(cube.Opening_Balance__c, results[0].Opening_Balance__c);
            System.assertEquals(FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS, results[0].Cube_Type__c);
        }
    }

    @IsTest
    static void testOutputCubesHaveCorrectTotals() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Id ledger = [SELECT Id FROM Ledger__c WHERE Name = 'Consolidation ledger1'].Id;
            Id period = testData.acctPeriods[0].Id;

            List<Financial_Cube__c> cubes = new List<Financial_Cube__c>{
                new Financial_Cube__c (
                    Ledger__c = testData.ledgers[0].Id,
                    Accounting_Period__c = period,
                    GL_Account__c = testData.glAccounts[0].Id,
                    GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                    GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                    GL_Account_Variable_4__c = testData.accountingVariables4[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
                    Amount__c = 1000.01,
                    Opening_Balance__c = 1000.01
                ),
                new Financial_Cube__c (
                    Ledger__c = testData.ledgers[2].Id,
                    Accounting_Period__c = period,
                    GL_Account__c = testData.glAccounts[0].Id,
                    GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                    GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                    GL_Account_Variable_4__c = testData.accountingVariables4[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
                    Amount__c = 2000.01,
                    Opening_Balance__c = 2000.01
                ),
                new Financial_Cube__c (
                    Ledger__c = testData.ledgers[0].Id,
                    Accounting_Period__c = period,
                    GL_Account__c = testData.glAccounts[0].Id,
                    GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                    GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                    GL_Account_Variable_3__c = testData.accountingVariables3[0].Id,
                    GL_Account_Variable_4__c = testData.accountingVariables4[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
                    Amount__c = 3000.01,
                    Opening_Balance__c = 3000.01
                ),
                new Financial_Cube__c (
                    Ledger__c = testData.ledgers[0].Id,
                    Accounting_Period__c = period,
                    GL_Account__c = testData.glAccounts[0].Id,
                    GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
                    GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
                    GL_Account_Variable_3__c = testData.accountingVariables3[1].Id,
                    GL_Account_Variable_4__c = testData.accountingVariables4[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
                    Amount__c = 4000.01,
                    Opening_Balance__c = 4000.01
                )
            };
            FinancialCubeActions.isPreventOverride = true;
            insert cubes;
            FinancialCubeActions.isPreventOverride = false;

            Id[] cubeIds = new Id[]{ cubes[0].Id, cubes[1].Id, cubes[2].Id, cubes[3].Id };

            cubes = [
                SELECT Id,
                    Name,
                    GL_Account__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Opening_Balance__c,
                    Current_Period__c,
                    Amount__c,
                    Ledger__c,
                    Ledger__r.Accounting_Method__c
                FROM Financial_Cube__c
                WHERE Id = :cubeIds
            ];
            
            Test.startTest();
            FinancialCubesConsolidator consolidator = new FinancialCubesConsolidator(ledger, period);
            for (Financial_Cube__c cube : cubes) {
                consolidator.addCube(cube);
            }
            List<Financial_Cube__c> results = consolidator.getConsolidationCubes();
            Test.stopTest();

            System.assertEquals(3, results.size());
            for (Financial_Cube__c result : results) {
                if (result.GL_Account_Variable_1__c == cubes[0].GL_Account_Variable_1__c
                        && result.GL_Account_Variable_2__c == cubes[0].GL_Account_Variable_2__c
                        && result.GL_Account_Variable_3__c == cubes[0].GL_Account_Variable_3__c
                        && result.GL_Account_Variable_4__c == cubes[0].GL_Account_Variable_4__c) {
                    System.assertEquals(cubes[0].Opening_Balance__c + cubes[1].Opening_Balance__c, result.Opening_Balance__c);
                    System.assertEquals(cubes[0].Amount__c + cubes[1].Amount__c, result.Amount__c);
                }
                else if (result.GL_Account_Variable_1__c == cubes[2].GL_Account_Variable_1__c
                        && result.GL_Account_Variable_2__c == cubes[2].GL_Account_Variable_2__c
                        && result.GL_Account_Variable_3__c == cubes[2].GL_Account_Variable_3__c
                        && result.GL_Account_Variable_4__c == cubes[2].GL_Account_Variable_4__c) {
                    System.assertEquals(cubes[2].Opening_Balance__c, result.Opening_Balance__c);
                    System.assertEquals(cubes[2].Amount__c, result.Amount__c);
                }
                else if (result.GL_Account_Variable_1__c == cubes[3].GL_Account_Variable_1__c
                        && result.GL_Account_Variable_2__c == cubes[3].GL_Account_Variable_2__c
                        && result.GL_Account_Variable_3__c == cubes[3].GL_Account_Variable_3__c
                        && result.GL_Account_Variable_4__c == cubes[3].GL_Account_Variable_4__c) {
                    System.assertEquals(cubes[3].Opening_Balance__c, result.Opening_Balance__c);
                    System.assertEquals(cubes[3].Amount__c, result.Amount__c);
                }
                else {
                    System.assert(false, 'Unexpected output consolidation financial cube.');
                }
            }
        }
    }

}