@IsTest
public class SOQLAccessDecisionUtilTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGetRecordsCheckCRUDAndFlsWithoutAccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[2]) {
            List<Billing__c> result = [SELECT Id, Name, Status__c, Balance__c FROM Billing__c];
            SOQLAccessDecisionUtil dec = new SOQLAccessDecisionUtil(result, AccessType.READABLE);
            System.assertEquals(new List<SObject>(), dec.getRecords());
            System.assert(dec.isAccessDecisionCRUDException());
        }
    }

    @IsTest
    public static void testGetRecordsCheckCRUDAndFlsWithAccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        TestDataSuite.assignAdminPermissionSet(testData.users[2].Id, false);
        System.runAs(testData.users[2]) {
            List<Billing__c> result = [SELECT Id, Name, Status__c, Balance__c FROM Billing__c];
            SOQLAccessDecisionUtil dec = new SOQLAccessDecisionUtil(result, AccessType.READABLE);
            System.assertEquals(result, dec.getRecords());
        }
    }

    @IsTest
    public static void testGetRecordsCheckFlsWithoutAccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[2]) {
            List<Billing__c> result = [SELECT Id, Name, Status__c, Balance__c FROM Billing__c];
            SOQLAccessDecisionUtil dec = new SOQLAccessDecisionUtil(result, AccessType.READABLE, false);
            List<Billing__c> expectedResult = [SELECT Id FROM Billing__c];
            Map<String, Set<String>> removed = new Map<String, Set<String>> {
                'AcctSeed__Billing__c' => new Set<String> {'AcctSeed__Balance__c', 'AcctSeed__Status__c', 'Name'}
            };

            System.assertEquals(expectedResult, dec.getRecords());
            System.assertEquals(removed, dec.getRemovedFields());
        }
    }

    @IsTest
    public static void testGetRecordsCheckFlsEditAccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        TestDataSuite.assignAdminPermissionSet(testData.users[2].Id, false);
        System.runAs(testData.users[2]) {
            List<Billing__c> result = [SELECT Id, Name, Status__c, Balance__c FROM Billing__c];
            SOQLAccessDecisionUtil dec = new SOQLAccessDecisionUtil(result, AccessType.CREATABLE, false);

            List<Billing__c> expectedResult = [SELECT Id, Status__c FROM Billing__c];
            Map<String, Set<String>> removed = new Map<String, Set<String>> {
                'AcctSeed__Billing__c' => new Set<String> {'AcctSeed__Balance__c', 'Name'}
            };

            System.assertEquals(expectedResult, dec.getRecords());
            System.assertEquals(removed, dec.getRemovedFields());
        }
    }

}