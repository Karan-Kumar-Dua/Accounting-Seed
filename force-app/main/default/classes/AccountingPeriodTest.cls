@IsTest
public class AccountingPeriodTest {

    public static List<SObjectType> arSubLedgerTypes = new List<SObjectType>(AccountingPeriod.arSubLedgerTypes);
    public static List<SObjectType> apSubLedgerTypes = new List<SObjectType>(AccountingPeriod.apSubLedgerTypes);

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testIsPeriodOpenForAP() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.OPEN_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;
            
            System.assertEquals(false, AccountingPeriod.isPeriodOpen(testData.acctPeriods[0],apSubLedgerTypes[0]));
            System.assertEquals(true, AccountingPeriod.isPeriodOpen(testData.acctPeriods[1],apSubLedgerTypes[0]));
        }
    }

    @IsTest
    static void testIsPeriodOpenForAR() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.OPEN_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;
            
            System.assertEquals(false, AccountingPeriod.isPeriodOpen(testData.acctPeriods[0],arSubLedgerTypes[0]));
            System.assertEquals(true, AccountingPeriod.isPeriodOpen(testData.acctPeriods[1],arSubLedgerTypes[0]));
        }
    }

    @IsTest
    static void testisPeriodClosedForAP() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.OPEN_STATUS;
            testData.acctPeriods[2].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;
            
            System.assertEquals(true, AccountingPeriod.isPeriodClosed(testData.acctPeriods[0],apSubLedgerTypes[0]));
            System.assertEquals(false, AccountingPeriod.isPeriodClosed(testData.acctPeriods[1],apSubLedgerTypes[1]));
            System.assertEquals(true, AccountingPeriod.isPeriodClosed(testData.acctPeriods[2],apSubLedgerTypes[2]));
        }
    }

    @IsTest
    static void testisPeriodClosedForAR() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.OPEN_STATUS;
            testData.acctPeriods[2].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;
            
            System.assertEquals(true, AccountingPeriod.isPeriodClosed(testData.acctPeriods[0],arSubLedgerTypes[0]));
            System.assertEquals(false, AccountingPeriod.isPeriodClosed(testData.acctPeriods[1],arSubLedgerTypes[1]));
            System.assertEquals(true, AccountingPeriod.isPeriodClosed(testData.acctPeriods[2],arSubLedgerTypes[2]));
        }
    }
}