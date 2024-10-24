@IsTest
public with sharing class AccountingHomeHelperTest {
 
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetPackageVersion() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(new Version(2,0)){
            System.runAs(testData.users[1]) {
                String v = AccountingHomeHelper.getPackageVersion();
                System.assertEquals('2.0', v);
            }
        }
    }

    @IsTest
    private static void testGetCurrentPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Date today = Date.today();
            Accounting_Period__c p = new Accounting_Period__c(
                Name = today.year() + '-' + String.valueOf(today.month()).leftPad(2,'0'),
                Start_Date__c = today.toStartOfMonth(),
                End_Date__c = today.addMonths(1).addDays(-1)
            );
            insert p;
            String periodName = AccountingHomeHelper.getCurrentPeriod();
            System.assertEquals(p.Name, periodName);
        }
    }

    @IsTest
    private static void testGetCurrentPeriodNoneExist() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            String periodName = AccountingHomeHelper.getCurrentPeriod();
            System.assertEquals(null, periodName);
        }
    }

    @IsTest
    private static void testGetLastClosedPeriodNoneExist() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            AccountingHomeHelper.LastClosedPeriodInfo info = AccountingHomeHelper.getLastClosedPeriod();
            System.assertEquals(null, info);
        }
    }

    @IsTest
    private static void testGetLastClosedPeriodCurrent() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Date today = Date.today();
            Accounting_Period__c lastExistingPeriod = [SELECT Name, End_Date__c FROM Accounting_Period__c ORDER BY End_Date__c DESC LIMIT 1];
            
            Accounting_Period__c p = new Accounting_Period__c(
                Name = today.year() + '-' + String.valueOf(today.month()).leftPad(2,'0'),
                Start_Date__c = lastExistingPeriod.End_Date__c.addDays(1),
                End_Date__c = today.addMonths(1).toStartOfMonth().addDays(-1)
            );
            insert p;

            List<Accounting_Period__c> closePeriods = new List<Accounting_Period__c>();
            for (Accounting_Period__c oldPeriod : [
                    SELECT Id, Status__c 
                    FROM Accounting_Period__c 
                    WHERE End_Date__c < :today]) {
                oldPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                closePeriods.add(oldPeriod);
            }
            AccountingPeriodActions.isFirstRun = false;
            update closePeriods;

            Test.startTest();
            AccountingHomeHelper.LastClosedPeriodInfo info = AccountingHomeHelper.getLastClosedPeriod();
            System.assertNotEquals(null, info);
            System.assertEquals(lastExistingPeriod.Name, info.period);
            System.assertEquals(true, info.isCurrent);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetLastClosedPeriodNonCurrent() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Date today = Date.today();
            Accounting_Period__c lastExistingPeriod = [SELECT Name, End_Date__c, Start_Date__c FROM Accounting_Period__c ORDER BY End_Date__c DESC LIMIT 1];
            
            Accounting_Period__c p = new Accounting_Period__c(
                Name = today.year() + '-' + String.valueOf(today.month()).leftPad(2,'0'),
                Start_Date__c = lastExistingPeriod.End_Date__c.addDays(1),
                End_Date__c = today.addMonths(1).toStartOfMonth().addDays(-1)
            );
            insert p;

            List<Accounting_Period__c> closePeriods = new List<Accounting_Period__c>();
            for (Accounting_Period__c oldPeriod : [
                    SELECT Id, Status__c 
                    FROM Accounting_Period__c 
                    WHERE End_Date__c < :lastExistingPeriod.Start_Date__c]) {
                oldPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                closePeriods.add(oldPeriod);
            }
            AccountingPeriodActions.isFirstRun = false;
            update closePeriods;

            Test.startTest();
            AccountingHomeHelper.LastClosedPeriodInfo info = AccountingHomeHelper.getLastClosedPeriod();
            System.assertNotEquals(null, info);
            System.assertEquals([
                    SELECT Name 
                    FROM Accounting_Period__c 
                    WHERE End_Date__c = :lastExistingPeriod.Start_Date__c.addDays(-1)
                    LIMIT 1
                ].Name, info.period);
            System.assertEquals(false, info.isCurrent);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testRetrieveAHConfigurations() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Map<String, Object> ahConfigurations = AccountingHomeHelper.retrieveAHConfigurations(new List<String>{
                    'Billing__c'
            });
            System.assert(ahConfigurations.get('sobjectDetails') != null);
            System.assert(ahConfigurations.get('templateParts') != null);
        }
    }

}