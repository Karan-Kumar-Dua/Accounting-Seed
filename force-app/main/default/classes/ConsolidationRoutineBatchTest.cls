@IsTest
private with sharing class ConsolidationRoutineBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            testData.closePreviousAccountingPeriodsBasedOnCurrentDate();
        }
    }

    @IsTest
    static void testRunConsolidationForParent() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Ledger__c consolidationLedger = [SELECT Id FROM Ledger__c WHERE Name = 'Consolidation ledger3'];
            Ledger__c transactionLedger1 = testData.ledgers.get(0);
            Ledger__c transactionLedger2 = testData.ledgers.get(2);
            //Query consolidationLedger hierarchy
            Ledger_Hierarchy__c consolidationHierarchy = testData.ledgerHierarchies.get(0);
            //add transactionLedger2 to the consolidationLedger hierarchy
            Ledger_Hierarchy__c transactionalHierarchy2 = new Ledger_Hierarchy__c(
                Name = 'Transactional Ledger 2',
                Ledger__c = transactionLedger2.Id,
                Parent_Ledger_Hierarchy__c = consolidationHierarchy.Id
            );
            insert transactionalHierarchy2;

            //Create CRs for each of transactional ledgers added into hierarchy
            List<Cash_Receipt__c> newCashReceipts = new List<Cash_Receipt__c>();
            Cash_Receipt__c testCR1 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 400,
                Payment_Reference__c = '0000000432',
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Receipt_Date__c = currentPeriod.Start_Date__c,
                Accounting_Period__c = currentPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Ledger__c = transactionLedger1.Id
            );
            newCashReceipts.add(testCR1);

            Cash_Receipt__c testCR2 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 400,
                Payment_Reference__c = '0000000433',
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Receipt_Date__c = currentPeriod.Start_Date__c,
                Accounting_Period__c = currentPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Ledger__c = transactionLedger2.Id
            );
            newCashReceipts.add(testCR2);
            insert newCashReceipts;

            List<Financial_Cube__c> periodFinancialCubes = [
                SELECT Id
                FROM Financial_Cube__c
                WHERE (Ledger__c = :transactionLedger1.Id OR Ledger__c = :transactionLedger2.Id)
                AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                AND Accounting_Period__c = :currentPeriod.Id
            ];

            AccountingPeriodActions.isFirstRun = false;
            currentPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update currentPeriod;
            AccountingPeriodActions.isFirstRun = true;

            LedgerHierarchy.consolidate(consolidationHierarchy.Id, false, currentPeriod.Id);
            Test.stopTest();

            List<Financial_Cube__c> consolidationFinancialCubes = [
                SELECT Id, Amount__c
                FROM Financial_Cube__c
                WHERE Ledger__c = :consolidationLedger.Id
                AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                AND Accounting_Period__c = :currentPeriod.Id
            ];
            System.assertEquals(false, consolidationFinancialCubes.isEmpty());
            System.assertEquals(periodFinancialCubes.size() / 2, consolidationFinancialCubes.size());
        }

    }

    @IsTest
    static void testRunConsolidationForParentWithChildren() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Ledger__c consolidationLedger = [SELECT Id FROM Ledger__c WHERE Name = 'Consolidation ledger1'];
            Ledger__c transactionLedger1 = testData.ledgers.get(0);
            Ledger__c transactionLedger2 = testData.ledgers.get(2);
            //Query consolidationLedger hierarchy
            Ledger_Hierarchy__c consolidationHierarchy = testData.ledgerHierarchies.get(0);
            //add transactionLedger2 to the consolidationLedger hierarchy
            Ledger_Hierarchy__c transactionalHierarchy2 = new Ledger_Hierarchy__c(
                Name = 'Transactional Ledger 2',
                Ledger__c = transactionLedger2.Id,
                Parent_Ledger_Hierarchy__c = consolidationHierarchy.Id
            );
            insert transactionalHierarchy2;
            //Create second consolidation ledger hierarchy as child of the first one
            Ledger__c consolidationLedgerExt = new Ledger__c(
                Name = 'Consolidation ledger ext',
                Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
                Default_Bank_Account__c = testData.glAccounts[0].Id,
                Default_Billing_Format__c = testData.billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
            );
            insert consolidationLedgerExt;
            //add consolidationLedgerExt to the consolidationLedger hierarchy
            Ledger_Hierarchy__c consolidationHierarchyExt = new Ledger_Hierarchy__c(
                Name = 'Consolidation Ledger EXT',
                Ledger__c = consolidationLedgerExt.Id,
                Parent_Ledger_Hierarchy__c = consolidationHierarchy.Id
            );
            insert consolidationHierarchyExt;

            LedgerHierarchyModel mainModel = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, consolidationHierarchy.Id);
            ConsolidationRoutineBatch batchInstance = new ConsolidationRoutineBatch(mainModel, currentPeriod.Id, true);

            System.assertEquals(batchInstance.mainConsolidationLedgerId, consolidationLedgerExt.Id);
        }

    }

    @IsTest
    static void testRunConsolidationCreatesAJR() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Id currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today()).Id;
            Id hierarchyId = testData.ledgerHierarchies[0].Id;

            Test.startTest();
            LedgerHierarchyModel mainModel = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, hierarchyId);
            ConsolidationRoutineBatch batchInstance = new ConsolidationRoutineBatch(mainModel, currentPeriod, true);
            Database.executeBatch(batchInstance);
            Test.stopTest();

            List<Automated_Job_Results__c> ajrs = new List<Automated_Job_Results__c>();
            ajrs = [
                SELECT Failed__c, Processed__c, Schedule_Job_Type__c, Succeeded__c
                FROM Automated_Job_Results__c
            ];

            System.assertNotEquals(null, ajrs);
            System.assertEquals(1, ajrs.size());

            Automated_Job_Results__c ajr = ajrs[0];
            System.assertEquals(AutomatedJobResultsHandler.jobsName.get(ConsolidationRoutineBatch.JOB_NAME), ajr.Schedule_Job_Type__c);
            System.assertEquals(1, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testRunConsolidationErrorCreatesAJR() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Id currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today()).Id;
            Id hierarchyId = testData.ledgerHierarchies[0].Id;

            Test.startTest();
            LedgerHierarchyModel mainModel = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, hierarchyId);
            ConsolidationRoutineBatch batchInstance = new ConsolidationRoutineBatch(mainModel, currentPeriod, true);
            Database.executeBatch(batchInstance);
            Test.stopTest();

            List<Automated_Job_Results__c> ajrs = new List<Automated_Job_Results__c>();
            ajrs = [
                SELECT Failed__c, Processed__c, Schedule_Job_Type__c, Succeeded__c
                FROM Automated_Job_Results__c
            ];

            System.assertNotEquals(null, ajrs);
            System.assertEquals(1, ajrs.size());

            Automated_Job_Results__c ajr = ajrs[0];
            System.assertEquals(AutomatedJobResultsHandler.jobsName.get(ConsolidationRoutineBatch.JOB_NAME), ajr.Schedule_Job_Type__c);
            System.assertEquals(1, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    static void testRunConsolidationErrorCreatesActivity() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Id currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today()).Id;
            Id hierarchyId = testData.ledgerHierarchies[0].Id;

            Test.startTest();
            LedgerHierarchyModel mainModel = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, hierarchyId);
            ConsolidationRoutineBatch batchInstance = new ConsolidationRoutineBatch(mainModel, currentPeriod, true);
            batchInstance.isError = true;
            Database.executeBatch(batchInstance);
            Test.stopTest();

            List<Task> activities = new List<Task>();
            activities = [
                SELECT
                    ActivityDate,
                    Description,
                    OwnerId,
                    Priority,
                    Status,
                    Subject,
                    WhatId
                FROM Task
            ];

            System.assertNotEquals(null, activities);
            System.assertEquals(1, activities.size());

            Task activity = activities[0];
            System.assertEquals(Date.today(), activity.ActivityDate);
            System.assertEquals(UserInfo.getUserId(), activity.OwnerId);
            System.assertEquals(ConsolidationRoutineBatch.ACTIVITY_PRIORITY, activity.Priority);
            System.assertEquals(ConsolidationRoutineBatch.ACTIVITY_STATUS, activity.Status);
            System.assertEquals(ConsolidationRoutineBatch.ACTIVITY_SUBJECT, activity.Subject);
            System.assertEquals(hierarchyId, activity.WhatId);
        }
    }

    public class FinancialCubesConsolidatorMock implements System.StubProvider {
        public String exceptionMsg = 'exception test';

        public Object handleMethodCall(
            Object stubbedObject,
            String stubbedMethodName,
            Type returnType,
            List<Type> listOfParamTypes,
            List<String> listOfParamNames,
            List<Object> listOfArgs) {

            if (stubbedMethodName.equalsIgnoreCase('getConsolidationCubes')) {
                DmlException ex = new DmlException();
                ex.setMessage(exceptionMsg);
                throw ex;
            }
            return null;
        }
    }


    @IsTest
    static void testRunConsolidationSuccessUpdatesHierarchyParentStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createConsolidationLedgers()
        .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Id currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today()).Id;
            Id hierarchyId = testData.ledgerHierarchies[0].Id;

            Test.startTest();
            LedgerHierarchyModel mainModel = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, hierarchyId);
            ConsolidationRoutineBatch batchInstance = new ConsolidationRoutineBatch(mainModel, currentPeriod, false);
            Database.executeBatch(batchInstance);
            Test.stopTest();

            Ledger_Hierarchy__c lH = [
                SELECT Hierarchy_Status__c
                FROM Ledger_Hierarchy__c
                WHERE Id = :hierarchyId
            ];

            System.assertEquals(LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_COMPLETE, lH.Hierarchy_Status__c );

        }
    }

    @IsTest
    static void testRunConsolidationErrorUpdatesHierarchyParentStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createConsolidationLedgers()
        .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Id currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today()).Id;
            Id hierarchyId = testData.ledgerHierarchies[0].Id;

            Test.startTest();
            LedgerHierarchyModel mainModel = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, hierarchyId);
            ConsolidationRoutineBatch batchInstance = new ConsolidationRoutineBatch(mainModel, currentPeriod, true);
            batchInstance.isError = true;
            Database.executeBatch(batchInstance);
            Test.stopTest();

            Ledger_Hierarchy__c lH = [
                SELECT Hierarchy_Status__c
                FROM Ledger_Hierarchy__c
                WHERE Id = :hierarchyId
            ];

            System.assertEquals(lH.Hierarchy_Status__c, LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_ERROR);
        }
    }


    @IsTest
    static void testRunConsolidationErrorUpdatesHierarchyChildStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        Test.startTest();
         //Query consolidationLedger hierarchy
         Ledger_Hierarchy__c consolidationHierarchy = testData.ledgerHierarchies.get(0);
         //Create second consolidation ledger hierarchy as child of the first one
         Ledger__c consolidationLedgerExt = new Ledger__c(
            Name = 'Consolidation ledger ext',
            Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
            Default_Bank_Account__c = testData.glAccounts[0].Id,
            Default_Billing_Format__c = testData.billingFormats[0].Id,
            Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
            Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
        );
        insert consolidationLedgerExt;
        //add consolidationLedgerExt to the consolidationLedger hierarchy
        Ledger_Hierarchy__c consolidationHierarchyExt = new Ledger_Hierarchy__c(
            Name = 'Consolidation Ledger EXT',
            Ledger__c = consolidationLedgerExt.Id,
            Parent_Ledger_Hierarchy__c = consolidationHierarchy.Id
        );
        insert consolidationHierarchyExt;

        Id currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today()).Id;
        Id hierarchyId = testData.ledgerHierarchies[0].Id;

        System.runAs(testData.users[1]) {
            
            LedgerHierarchyModel mainModel = LedgerHierarchy.retrieve(APIOptions.SharingContext.WITHOUT_SHARING, hierarchyId);
            ConsolidationRoutineBatch batchInstance = new ConsolidationRoutineBatch(mainModel, currentPeriod, true);
            batchInstance.isError = true;
            Database.executeBatch(batchInstance);
            Test.stopTest();

            consolidationHierarchy = [SELECT Id, Hierarchy_Status__c FROM Ledger_Hierarchy__c WHERE Name = 'Transactional Hierarchy'];
            System.assertEquals(LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_NOT_RUN, consolidationHierarchy.Hierarchy_Status__c);
            consolidationHierarchyExt = [SELECT Id, Hierarchy_Status__c FROM Ledger_Hierarchy__c WHERE Name = 'Consolidation Ledger EXT'];
            System.assertEquals(LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_ERROR, consolidationHierarchyExt.Hierarchy_Status__c);
        }
    }

}