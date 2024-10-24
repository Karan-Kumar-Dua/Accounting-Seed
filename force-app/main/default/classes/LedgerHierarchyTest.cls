@isTest
public with sharing class LedgerHierarchyTest {
    
    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testRetrieveAll() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<LedgerHierarchyModel> models = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING);
            Test.stopTest();

            System.assertEquals(2, models.size());
            for (LedgerHierarchyModel model : models) {
                System.assertEquals(2, model.children.size());
            }
        }
    }

    @isTest
    private static void testRetrieveSubGraph() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Id ledgerHierarchyId = testData.ledgerHierarchies[0].Id;

            Test.startTest();
            LedgerHierarchyModel model = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, ledgerHierarchyId);
            Test.stopTest();

            Set<Id> childIds = new Map<Id, Ledger_Hierarchy__c>([
                SELECT Id 
                FROM Ledger_Hierarchy__c 
                WHERE Parent_Ledger_Hierarchy__c = :ledgerHierarchyId
            ]).keySet();

            System.assertEquals(2, model.children.size());
            for (LedgerHierarchyModel child : model.children) {
                System.assertEquals(0, child.children.size());
                System.assert(childIds.contains(child.value.Id));
            }
        }
    }

    @isTest
    private static void testRetrieveLeaf() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Id ledgerHierarchyId = testData.ledgerHierarchies[2].Id;

            Test.startTest();
            LedgerHierarchyModel model = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, ledgerHierarchyId);
            Test.stopTest();

            System.assertEquals(0, model.children.size());
            System.assertEquals(ledgerHierarchyId, model.value.Id);
        }
    }

    @isTest
    private static void testRetrieveFlat() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> hierarchies = LedgerHierarchy.retrieveFlat(APIOptions.SharingContext.WITHOUT_SHARING);
            Test.stopTest();

            System.assertEquals(6, hierarchies.size());
        }
    }


    @isTest
    private static void testConsolidationValidationSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            Id ledgerHierarchyId = testData.ledgerHierarchies[0].Id;
            ServiceResult sr = LedgerHierarchy.consolidate(ledgerHierarchyId, true, testData.acctPeriods[0].Id);
            Test.stopTest();  
            
            System.assertEquals(true, sr.isSuccess);
        }

    }

    @isTest
    private static void testConsolidationValidationCurrentAPOpen(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id ledgerHierarchyId = testData.ledgerHierarchies[0].Id;
            ServiceResult sr = LedgerHierarchy.consolidate(ledgerHierarchyId, true, testData.acctPeriods[0].Id);
            Test.stopTest();  
            System.assertEquals(
                String.format(LedgerHierarchy.CURRENT_PERIOD_NOT_CLOSED, new List<String>{testData.acctPeriods[0].Name}),
                sr.errors[0].detail
            );
        }
    }

   
    @isTest
    private static void testConsolidationValidationAPCloseInProgress(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        AccountingPeriodActions.isFirstRun = false;
        testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
        update testData.acctPeriods[0];

        AccountingPeriodActions.isFirstRun = false;
        testData.acctPeriods[5].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
        update testData.acctPeriods[5];

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id ledgerHierarchyId = testData.ledgerHierarchies[0].Id;
            ServiceResult sr = LedgerHierarchy.consolidate(ledgerHierarchyId, true, testData.acctPeriods[0].Id);
            Test.stopTest();  
            
            System.assertEquals(LedgerHierarchy.ACCOUNTING_PERIOD_JOB_RUNNING, sr.errors[0].detail);
        }

    }

    @isTest
    private static void testConsolidationValidationAPOpenInProgress(){
        TestDataSuite testData = TestDataSuite.getInstance()
        .createConsolidationLedgers()
        .createLedgerHierarchies();
        AccountingPeriodActions.isFirstRun = false;
        testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
        update testData.acctPeriods[0];

        AccountingPeriodActions.isFirstRun = false;
        testData.acctPeriods[5].Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
        update testData.acctPeriods[5];

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id ledgerHierarchyId = testData.ledgerHierarchies[0].Id;
            ServiceResult sr = LedgerHierarchy.consolidate(ledgerHierarchyId, true, testData.acctPeriods[0].Id);
            Test.stopTest();  
            
            System.assertEquals(LedgerHierarchy.ACCOUNTING_PERIOD_JOB_RUNNING, sr.errors[0].detail);
        }

    }
    

    @isTest
    private static void testConsolidationValidationAPArchiveInProgress(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        AccountingPeriodActions.isFirstRun = false;
        testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
        update testData.acctPeriods[0];

        AccountingPeriodActions.isFirstRun = false;
        testData.acctPeriods[5].Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
        update testData.acctPeriods[5];

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id ledgerHierarchyId = testData.ledgerHierarchies[0].Id;
            ServiceResult sr = LedgerHierarchy.consolidate(ledgerHierarchyId, true, testData.acctPeriods[0].Id);
            Test.stopTest();  
            System.assertEquals(LedgerHierarchy.ACCOUNTING_PERIOD_JOB_RUNNING, sr.errors[0].detail);
        }
    }

    @isTest
    private static void testConsolidationValidationConsolidationBatchInProgress(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            Test.startTest();
            Id ledgerHierarchyId = testData.ledgerHierarchies[0].Id;
            LedgerHierarchyModel model = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, ledgerHierarchyId);
            Database.executeBatch(new ConsolidationRoutineBatch(model, AccountingPeriodHandler.getInstance().getFirstOpenedPeriod().Id, true));
            ServiceResult sr = LedgerHierarchy.consolidate(ledgerHierarchyId, true, testData.acctPeriods[0].Id);
            Test.stopTest();  
            
            System.assertEquals(LedgerHierarchy.CONSOLIDATION_JOB_RUNNING, sr.errors[0].detail);
        }

    }

}