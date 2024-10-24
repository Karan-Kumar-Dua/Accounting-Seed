@IsTest
public with sharing class LedgerHierarchyHandlerTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetAllHierarchiesWithSharing() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            LedgerHierarchyHandler handler = LedgerHierarchyHandler.getInstanceWithSharing();
            Test.stopTest();

            Integer countActual = handler.getAllHierarchies().size();
            Integer countExpected = [SELECT count() FROM Ledger_Hierarchy__c];
            System.assertEquals(countExpected, countActual);
        }
    }

    @IsTest
    static void testGetAllHierarchiesWithoutSharing() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            LedgerHierarchyHandler handler = LedgerHierarchyHandler.getInstanceWithoutSharing();
            Integer countActual = handler.getAllHierarchies().size();
            Test.stopTest();

            Integer countExpected = [SELECT count() FROM Ledger_Hierarchy__c];
            System.assertEquals(countExpected, countActual);
        }
    }

    @IsTest
    static void testGetHierarchiesByRootId() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Id rootNodeId = testData.ledgerHierarchies[0].Id;

            Test.startTest();
            LedgerHierarchyHandler handler = LedgerHierarchyHandler.getInstanceWithSharing();
            Integer countActual = handler.getHierarchiesByRootId(rootNodeId).size();
            Test.stopTest();

            Integer countExpected = [
                SELECT count()
                FROM Ledger_Hierarchy__c
                WHERE Id = :rootNodeId
                    OR Root_Node_ID__c = :rootNodeId
            ];
            System.assertEquals(countExpected, countActual);
        }
    }

    @IsTest
    static void testGetHierarchiesByIds() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Set<Id> hierarchyIds = new Set<Id>{ 
                testData.ledgerHierarchies[0].Id, 
                testData.ledgerHierarchies[3].Id 
            };

            Test.startTest();
            LedgerHierarchyHandler handler = LedgerHierarchyHandler.getInstanceWithSharing();
            Integer countActual = handler.getHierarchiesByIds(hierarchyIds).size();
            Test.stopTest();

            Integer countExpected = [
                SELECT count() 
                FROM Ledger_Hierarchy__c 
                WHERE Id IN :hierarchyIds 
            ];
            System.assertEquals(countExpected, countActual);
        }
    }

    @IsTest
    static void testGetHierarchiesByLedgerIds() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Set<Id> ledgerIds = new Set<Id>{ 
                testData.ledgerHierarchies[0].Ledger__c, 
                testData.ledgerHierarchies[3].Ledger__c 
            };

            Test.startTest();
            LedgerHierarchyHandler handler = LedgerHierarchyHandler.getInstanceWithSharing();
            Integer countActual = handler.getHierarchiesByLedgerIds(ledgerIds).size();
            Test.stopTest();

            Integer countExpected = [
                SELECT count() 
                FROM Ledger_Hierarchy__c 
                WHERE Ledger__c IN :ledgerIds 
            ];
            System.assertEquals(countExpected, countActual);
        }
    }

    @IsTest
    static void testReset() {
        TestDataSuite testData = TestDataSuite.getInstance();
            
        LedgerHierarchyHandler handler;
        System.runAs(testData.users.get(1)) {
            handler = LedgerHierarchyHandler.getInstanceWithoutSharing();
        }

        testData.createConsolidationLedgers().createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            System.assertEquals(0, handler.getAllHierarchies().size());
            Test.startTest();
            LedgerHierarchyHandler.reset();
            handler = LedgerHierarchyHandler.getInstanceWithoutSharing();
            Test.stopTest();
            System.assert(handler.getAllHierarchies().size() > 0);
        }
    }

}