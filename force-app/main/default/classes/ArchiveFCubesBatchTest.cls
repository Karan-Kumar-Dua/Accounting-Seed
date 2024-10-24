@IsTest
public class ArchiveFCubesBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testArchiveFCubesPositiveScenario() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> acctPeriodList = [
                SELECT Id, Name, Status__c, Start_Date__c, End_Date__c
                FROM Accounting_Period__c
                LIMIT 1
            ];
            System.assertEquals(false, acctPeriodList.isEmpty());
            Accounting_Period__c acctPeriod = acctPeriodList[0];

            ArchiveFCubesBatch batchInstance = new ArchiveFCubesBatch(acctPeriod);
            Id batchProcessId = Database.executeBatch(batchInstance);
            Test.stopTest();

            for (Financial_Cube__c fCube : [SELECT Id, Amount__c, Transaction_Amount__c, Archived_Amount__c
                                            FROM Financial_Cube__c
                                            WHERE Cube_Type__c = 'Period'
                                            AND Accounting_Period__c = :acctPeriod.Id LIMIT 10]) {

                if (fCube.Transaction_Amount__c == 300) {
                    System.assertEquals(300, fCube.Amount__c);
                }

                if (fCube.Transaction_Amount__c == -900) {
                    System.assertEquals(-900, fCube.Amount__c);
                }

                if (fCube.Transaction_Amount__c == 600) {
                    System.assertEquals(600, fCube.Amount__c);
                }
            }
        }

    }

    @IsTest
    public static void testArchiveFCubesSecondRunPositiveScenario() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> acctPeriodList = [
                SELECT Id, Name, Status__c, Start_Date__c, End_Date__c
                FROM Accounting_Period__c
                LIMIT 1
            ];
            System.assertEquals(false, acctPeriodList.isEmpty());
            Accounting_Period__c acctPeriod = acctPeriodList[0];

            List<Financial_Cube__c> fCubes = [
                SELECT Id, Amount__c, Transaction_Amount__c, Archived_Amount__c
                FROM Financial_Cube__c
                WHERE Cube_Type__c = 'Period'
                AND Accounting_Period__c = :acctPeriod.Id
                LIMIT 10
            ];

            ArchiveFCubesBatch batchInstance = new ArchiveFCubesBatch(acctPeriod);
            //simulate first run of batch job
            batchInstance.execute(NULL, fCubes);
            //then start actual batch execution
            Id batchProcessId = Database.executeBatch(batchInstance);
            Test.stopTest();

            for (Financial_Cube__c fCube : [SELECT Id, Amount__c, Transaction_Amount__c, Archived_Amount__c
                                            FROM Financial_Cube__c
                                            WHERE Cube_Type__c = 'Period'
                                            AND Accounting_Period__c = :acctPeriod.Id LIMIT 10]) {

                if (fCube.Transaction_Amount__c == 300) {
                    System.assertEquals(300, fCube.Amount__c);
                    System.assertEquals(300, fCube.Archived_Amount__c);
                }

                if (fCube.Transaction_Amount__c == -900) {
                    System.assertEquals(-900, fCube.Amount__c);
                    System.assertEquals(-900, fCube.Archived_Amount__c);
                }

                if (fCube.Transaction_Amount__c == 600) {
                    System.assertEquals(600, fCube.Amount__c);
                    System.assertEquals(600, fCube.Archived_Amount__c);
                }
            }
        }

    }

}