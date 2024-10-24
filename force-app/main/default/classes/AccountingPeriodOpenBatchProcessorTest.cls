@IsTest
public class AccountingPeriodOpenBatchProcessorTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testSetFinancialCubesOpeningBalance() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(0, [SELECT count() FROM Financial_Cube__c]);

            // Setup period cube for test data
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = 'Period';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 200;
            fCube.Cube_Type__c = 'Period';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(2, [SELECT count() FROM Financial_Cube__c WHERE Cube_Type__c = 'Period']);

            AccountingPeriodOpenBatchProcessor apb = new AccountingPeriodOpenBatchProcessor(
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods[4]}, 0, AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            apb.setFinancialCubesOpeningBalance([SELECT Id, Opening_Balance__c FROM Financial_Cube__c WHERE Accounting_Period__c = :testData.acctPeriods[1].Id]);

            for (Financial_Cube__c fCubeCheck : [SELECT Id, Opening_Balance__c FROM Financial_Cube__c WHERE Accounting_Period__c = :testData.acctPeriods[1].Id]) {
                System.assertEquals(0, fCubeCheck.Opening_Balance__c);
            }
        }

    }

    @IsTest
    public static void testAccountingPeriodOpenBatchProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users[1]) {
            Test.startTest();

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(0, [SELECT count() FROM Financial_Cube__c]);

            // Setup period cube for test data
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[1].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = 'Period';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[1].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 200;
            fCube.Cube_Type__c = 'Period';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(2, [SELECT count() FROM Financial_Cube__c WHERE Cube_Type__c = 'Period']);

            AccountingPeriodOpenBatchProcessor apb = new AccountingPeriodOpenBatchProcessor(
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods[0]}, 0, AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            Id jobId = Database.executeBatch(apb);
            Test.stopTest();

            System.assertEquals(1, [SELECT count() FROM AsyncApexJob WHERE Id = :jobId AND Status = 'Completed']);
        }

    }

    @IsTest
    public static void testDeleteCYEandRE() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users[1]) {
            Test.startTest();

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(0, [SELECT count() FROM Financial_Cube__c]);

            // Setup period cube for test data
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = 'Period';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Amount__c = 200;
            fCube.Cube_Type__c = 'Current Year Earnings';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[1].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Amount__c = 200;
            fCube.Cube_Type__c = 'Retained Earnings';
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;

            AccountingPeriodOpenBatchProcessor apb = new AccountingPeriodOpenBatchProcessor(
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods[0]}, 0, AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            Id jobId = Database.executeBatch(apb);
            Test.stopTest();

            System.assertEquals(1, [SELECT count() FROM AsyncApexJob WHERE Id = :jobId AND Status = 'Completed']);
            System.assertEquals(1, [SELECT count() FROM Financial_Cube__c WHERE Cube_Type__c = 'Period']);
            System.assertEquals(0, [SELECT count() FROM Financial_Cube__c WHERE Cube_Type__c = 'Current Year Earnings' OR Cube_Type__c = 'Retained Earnings']);
        }

    }

    @IsTest
    public static void testDeleteConsolidationsFCs() {
        TestDataSuite testData = TestDataSuite.getInstance().createConsolidationLedgers();

        System.runAs(testData.users[1]) {
            Test.startTest();

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(0, [SELECT count() FROM Financial_Cube__c]);

            List<Ledger__c> testLedgers = [SELECT Id FROM Ledger__c WHERE Type__c = :LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL];
            System.assertEquals(false, testLedgers.isEmpty());
            // Setup period cube for test data
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testLedgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Amount__c = 100;
            fCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS;
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testLedgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[0].Id;
            fCube.Amount__c = 100;
            fCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS;
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;

            AccountingPeriodOpenBatchProcessor apb = new AccountingPeriodOpenBatchProcessor(
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods[0]}, 0, AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            Id jobId = Database.executeBatch(apb);
            Test.stopTest();

            System.assertEquals(1, [SELECT count() FROM AsyncApexJob WHERE Id = :jobId AND Status = 'Completed']);
            System.assertEquals(0, [SELECT count() FROM Financial_Cube__c WHERE Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS]);
        }

    }

}