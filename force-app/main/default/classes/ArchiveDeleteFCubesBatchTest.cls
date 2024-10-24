@IsTest
public class ArchiveDeleteFCubesBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testDeleteFCubesViaBatch() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> acctPeriodList = [
                SELECT Id, Name, Status__c, Start_Date__c, End_Date__c
                FROM Accounting_Period__c
                LIMIT 1
            ];
            List<GL_Account__c> glAccountList = [SELECT Id, Name FROM GL_Account__c LIMIT 1];
            LedgerHandler.reset();
            Ledger__c testLedger = new Ledger__c(Name = 'TestLedger', Type__c = 'Budget');
            insert testLedger;
            List<Financial_Cube__c> fCubes = createFinancialCubes(acctPeriodList[0], glAccountList[0], testLedger);
            insert fCubes;

            ArchiveDeleteFCubesBatch batchInstance = new ArchiveDeleteFCubesBatch(acctPeriodList[0]);
            System.assertEquals(1, fCubes.size());//before batch execution
            Id batchProcessId = Database.executeBatch(batchInstance);
            Test.stopTest();

            Id fCubeId = fCubes[0].Id;
            List<Financial_Cube__c> fCubesAfterBatchExec = [SELECT Id FROM Financial_Cube__c WHERE Id = :fCubeId LIMIT 1];
            System.assertEquals(true, fCubesAfterBatchExec.isEmpty());//because this record should be deleted during batch execution
        }

    }

    private static List<Financial_Cube__c> createFinancialCubes(Accounting_Period__c acctPeriod, GL_Account__c glAccount, Ledger__c aLedger) {
        List<Financial_Cube__c> result = new List<Financial_Cube__c>();

        result.add(
            new Financial_Cube__c(
                Accounting_Period__c = acctPeriod.Id,
                GL_Account__c = glAccount.Id,
                Ledger__c = aLedger.Id,
                Cube_Type__c = 'Period',
                Opening_Balance__c = 0
            )
        );

        return result;
    }

}