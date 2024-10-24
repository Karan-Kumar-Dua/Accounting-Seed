@IsTest
public with sharing class BillingLDVCloneBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBillingLDVClone() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Set<Id> sourceIds = new Set<Id>{testData.billings[0].Id};
            BillingLDVCloneBatch batchInstance = new BillingLDVCloneBatch (
                sourceIds,
                testData.acctPeriods[1].Id,
                Date.today(),
                null,
                false
            );
            Database.executeBatch(batchInstance);

            Test.stopTest();

            System.assertNotEquals(true, [SELECT Id FROM Billing__c WHERE Date__c =: Date.today()].isEmpty());
            System.assertNotEquals(true, [SELECT Id FROM Billing_Line__c WHERE Date__c =: Date.today()].isEmpty());
            System.assertEquals(1, [SELECT Id FROM Billing__c WHERE Date__c =: Date.today()].size());
            System.assertEquals(2, [SELECT Id FROM Billing_Line__c WHERE Date__c =: Date.today()].size());
        }
    }

    @IsTest
    static void testBillingLDVCloneAsCreditMemo() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Set<Id> sourceIds = new Set<Id>{testData.billings[0].Id};
            BillingLDVCloneBatch batchInstance = new BillingLDVCloneBatch (
                sourceIds,
                testData.acctPeriods[1].Id,
                Date.today(),
                null,
                true
            );
            Database.executeBatch(batchInstance);

            Test.stopTest();

            System.assertEquals(-1 * testData.billingLines[0].Rate__c, [SELECT Id, Rate__c FROM Billing_Line__c WHERE Date__c =: Date.today()][0].Rate__c);

        }
    }
}