@IsTest
private class LedgerHierarchyActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testTransactionalTypeMatchingChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert consolidationLedgerHierarchies;

            DMLException dmlEx;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Budget ledger',
                    Ledger__c = testData.ledgers[1].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id
                );
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(LedgerHierarchyActions.ONLY_LEDGER_WITH_CORRECT_TYPE_ERROR,
                    new List<String>{
                        LedgerHierarchyActions.TRANSACTIONAL_TEMPLATE
                    }),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    static void testBudgetTypeMatchingChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Budget ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert consolidationLedgerHierarchies;

            DMLException dmlEx;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id
                );
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(LedgerHierarchyActions.ONLY_LEDGER_WITH_CORRECT_TYPE_ERROR,
                    new List<String>{
                        LedgerHierarchyActions.BUDGET_TEMPLATE
                    }),
                dmlEx.getDmlMessage(0)
            );
            Test.stopTest();
        }
    }

    @IsTest
    static void testConsolidationLedgerUniquenessChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        Ledger__c consolidationLedger = null;
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedger = ledger;
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            insert new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = consolidationLedger.Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            );

            DMLException dmlEx;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Duplicate ledger',
                    Ledger__c = consolidationLedger.Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(LedgerHierarchyActions.CONSOLIDATION_LEDGER_ASSOCIATION_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    static void testLedgerUniquenessInHierarchyChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert consolidationLedgerHierarchies;

            Ledger_Hierarchy__c ledgerHierarchyForFirstHierarchy = new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = testData.ledgers[0].Id,
                Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            );
            insert ledgerHierarchyForFirstHierarchy;


            DMLException dmlEx;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(LedgerHierarchyActions.LEDGER_EXIST_IN_HIERARCHY_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    static void testConsolidationRoutineChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger 1',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c,
                    Hierarchy_Status__c = LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS
                )
            };
            insert consolidationLedgerHierarchies;

            DMLException dmlEx1;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            }
            catch (DMLException ex) {
                dmlEx1 = ex;
            }

            System.assertEquals(LedgerHierarchyActions.INSERT_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR, dmlEx1.getDmlMessage(0));

            DMLException dmlEx2;
            try {
                delete consolidationLedgerHierarchies;
            }
            catch (DMLException ex) {
                dmlEx2 = ex;
            }

            System.assertEquals(LedgerHierarchyActions.DELETE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR, dmlEx2.getDmlMessage(0));

            DMLException dmlEx3;
            try {
                update consolidationLedgerHierarchies;
            }
            catch (DMLException ex) {
                dmlEx3 = ex;
            }

            System.assertEquals(LedgerHierarchyActions.UPDATE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR, dmlEx3.getDmlMessage(0));

            Test.stopTest();
        }

    }


    @IsTest
    static void testConsolidationRoutineCheckingBypass() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger 1',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c,
                    Hierarchy_Status__c = LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS
                )
            };
            insert consolidationLedgerHierarchies;

            LedgerHierarchyActions.bypassConsolidationRoutineValidation = true;
            insert new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = testData.ledgers[0].Id,
                Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            );

            List<Ledger_Hierarchy__c> insertedLH = [SELECT Id FROM Ledger_Hierarchy__c WHERE Name = 'Actual ledger'];
            System.assertEquals(1, insertedLH.size());

            DMLException dmlEx2;
            try {
                LedgerHierarchyActions.bypassConsolidationRoutineValidation = true;
                delete consolidationLedgerHierarchies;
            }
            catch (DMLException ex) {
                dmlEx2 = ex;
            }
            System.assertNotEquals(LedgerHierarchyActions.DELETE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR, dmlEx2.getDmlMessage(0));

            LedgerHierarchyActions.bypassConsolidationRoutineValidation = true;
            consolidationLedgerHierarchies[0].Name = 'Updated Name';
            update consolidationLedgerHierarchies;

            List<Ledger_Hierarchy__c> updatedLH = [SELECT Id FROM Ledger_Hierarchy__c WHERE Name = 'Updated Name'];
            System.assertEquals(1, updatedLH.size());

            Test.stopTest();
        }

    }

    @IsTest
    static void testClosedConsolidationFinancialCubeChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (LedgerHandler.isConsolidationLedger(ledger.Type__c)) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Ledger_Hierarchy__c firstConsolidationLedgerHierarchy = new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = consolidationLedgers[0].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            );
            insert firstConsolidationLedgerHierarchy;
            Ledger_Hierarchy__c secondConsolidationLedgerHierarchy = new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = consolidationLedgers[2].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c,
                Parent_Ledger_Hierarchy__c = firstConsolidationLedgerHierarchy.Id
            );
            insert secondConsolidationLedgerHierarchy;

            Ledger_Hierarchy__c tryRemoveLedgerHierarchy = new Ledger_Hierarchy__c(
                Name = 'Budget ledger',
                Ledger__c = testData.ledgers[2].Id,
                Parent_Ledger_Hierarchy__c = secondConsolidationLedgerHierarchy.Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            );
            insert tryRemoveLedgerHierarchy;

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testAccountingPeriod.Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = null,
                    Ledger__c = consolidationLedgers[2].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx1;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Parent_Ledger_Hierarchy__c = secondConsolidationLedgerHierarchy.Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            }
            catch (DMLException ex) {
                dmlEx1 = ex;
            }
            System.assertEquals(LedgerHierarchyActions.ASSOCIATED_CONSOLIDATION_FINANCIAL_CUBES_ERROR, dmlEx1.getDmlMessage(0));

            DMLException dmlEx2;
            try {
                delete tryRemoveLedgerHierarchy;
            }
            catch (DMLException ex) {
                dmlEx2 = ex;
            }

            System.assertEquals(LedgerHierarchyActions.ASSOCIATED_CONSOLIDATION_FINANCIAL_CUBES_ERROR, dmlEx2.getDmlMessage(0));
            Test.stopTest();
        }

    }

    @IsTest
    static void testClosedConsolidationFinancialCubeCheckingSingleRemoving() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Ledger_Hierarchy__c firstConsolidationLedgerHierarchy = new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = consolidationLedgers[0].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            );
            insert firstConsolidationLedgerHierarchy;

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testAccountingPeriod.Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = null,
                    Ledger__c = consolidationLedgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                )

            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete firstConsolidationLedgerHierarchy;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(LedgerHierarchyActions.ASSOCIATED_CONSOLIDATION_FINANCIAL_CUBES_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }

    }

    @IsTest
    static void testCLedgerWithChildrenChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (LedgerHandler.isConsolidationLedger(ledger)) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert consolidationLedgerHierarchies;
            insert new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = consolidationLedgers[2].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c,
                Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id
            );

            DMLException dmlEx;
            try {
                delete consolidationLedgerHierarchies[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(LedgerHierarchyActions.PREVENT_REMOVE_CL_WITH_CHILD_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    static void testEliminationHierarchyCreating() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = consolidationLedgers[0].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            )};
            insert consolidationLedgerHierarchies;

            List<Ledger_Hierarchy__c> eliminationLedgerHierarchies = [
                SELECT Id FROM Ledger_Hierarchy__c WHERE Ledger__r.Consolidation_Ledger_ID__c =: consolidationLedgers[0].Id
            ];

            System.assert(!eliminationLedgerHierarchies.isEmpty());
            Test.stopTest();
        }
    }

    @IsTest
    static void testEliminationHierarchyRemoving() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{new Ledger_Hierarchy__c(
                Name = 'Actual ledger',
                Ledger__c = consolidationLedgers[0].Id,
                Last_Period__c = testData.acctPeriods.get(0).Id,
                Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
            )};
            insert consolidationLedgerHierarchies;

            System.assert(![SELECT Id FROM Ledger_Hierarchy__c WHERE Ledger__r.Consolidation_Ledger_ID__c =: consolidationLedgers[0].Id].isEmpty());
            delete consolidationLedgerHierarchies;
            System.assert([SELECT Id FROM Ledger_Hierarchy__c WHERE Ledger__r.Consolidation_Ledger_ID__c =: consolidationLedgers[0].Id].isEmpty());

            Test.stopTest();
        }

    }

    @IsTest
    static void testHappyPathOfHierarchy() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (LedgerHandler.isConsolidationLedger(ledger.Type__c)) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                ),
                new Ledger_Hierarchy__c(
                    Name = 'Budget ledger',
                    Ledger__c = consolidationLedgers[1].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert consolidationLedgerHierarchies;

            List<Ledger_Hierarchy__c> secondLevelLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                ),
                new Ledger_Hierarchy__c(
                    Name = 'Budget ledger',
                    Ledger__c = testData.ledgers[1].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[1].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert secondLevelLedgerHierarchies;

            System.assert([
                SELECT Id, Root_Node_ID__c
                FROM Ledger_Hierarchy__c
                WHERE Id =: secondLevelLedgerHierarchies[0].Id
            ].Root_Node_ID__c == consolidationLedgerHierarchies[0].Id);
            Test.stopTest();
        }
    }

    @IsTest
    static void testSortOrderOfHierarchy() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (LedgerHandler.isConsolidationLedger(ledger.Type__c)) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                ),
                new Ledger_Hierarchy__c(
                    Name = 'Budget ledger',
                    Ledger__c = consolidationLedgers[1].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert consolidationLedgerHierarchies;

            List<Ledger_Hierarchy__c> secondLevelLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                ),
                new Ledger_Hierarchy__c(
                    Name = 'Budget ledger',
                    Ledger__c = testData.ledgers[1].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchies[1].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert secondLevelLedgerHierarchies;

            List<Ledger_Hierarchy__c> consolidationHierarchies = [
                SELECT Id, Sort_Order__c
                FROM Ledger_Hierarchy__c
                WHERE Id IN :consolidationLedgerHierarchies
                ORDER BY Sort_Order__c ASC
            ];

            List<Ledger_Hierarchy__c> secondLevelHierarchiesFirst = [
                SELECT Id, Sort_Order__c
                FROM Ledger_Hierarchy__c
                WHERE Parent_Ledger_Hierarchy__c = :consolidationLedgerHierarchies[0].Id
                ORDER BY Sort_Order__c ASC
            ];

            List<Ledger_Hierarchy__c> secondLevelHierarchiesSecond = [
                SELECT Id, Sort_Order__c
                FROM Ledger_Hierarchy__c
                WHERE Parent_Ledger_Hierarchy__c = :consolidationLedgerHierarchies[1].Id
                ORDER BY Sort_Order__c ASC
            ];

            System.assertEquals(1, consolidationHierarchies[0].Sort_Order__c);
            System.assertEquals(2, consolidationHierarchies[1].Sort_Order__c);
            System.assertEquals(1, secondLevelHierarchiesFirst[0].Sort_Order__c);
            System.assertEquals(2, secondLevelHierarchiesFirst[1].Sort_Order__c);
            System.assertEquals(1, secondLevelHierarchiesSecond[0].Sort_Order__c);
            System.assertEquals(2, secondLevelHierarchiesSecond[1].Sort_Order__c);

        }
    }

    @IsTest
    static void testSortOrderOfHierarchyAddNewConsolidation() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (LedgerHandler.isConsolidationLedger(ledger)) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Ledger_Hierarchy__c consolidationLedgerHierarchyFirst =
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            insert consolidationLedgerHierarchyFirst;

            Ledger_Hierarchy__c consolidationHierarchyFirst = [
                SELECT Id, Sort_Order__c
                FROM Ledger_Hierarchy__c
                WHERE Id = :consolidationLedgerHierarchyFirst.Id
                LIMIT 1
            ];
            System.assertEquals(1, consolidationHierarchyFirst.Sort_Order__c);

            Ledger_Hierarchy__c consolidationLedgerHierarchySecond =
                new Ledger_Hierarchy__c(
                    Name = 'Budget ledger',
                    Ledger__c = consolidationLedgers[1].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            insert consolidationLedgerHierarchySecond;

            Ledger_Hierarchy__c consolidationHierarchySecond = [
                SELECT Id, Sort_Order__c
                FROM Ledger_Hierarchy__c
                WHERE Id = :consolidationLedgerHierarchySecond.Id
                LIMIT 1
            ];
            System.assertEquals(2, consolidationHierarchySecond.Sort_Order__c);
        }
    }

    @IsTest
    static void testSortOrderOfHierarchyAddNewTransactional() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Ledger_Hierarchy__c consolidationLedgerHierarchy =
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );

            insert consolidationLedgerHierarchy;


            List<Ledger_Hierarchy__c> secondLevelLedgerHierarchiesFirst = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchy.Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert secondLevelLedgerHierarchiesFirst;

            List<Ledger_Hierarchy__c> secondLevelLedgerHierarchiesSecond = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[2].Id,
                    Parent_Ledger_Hierarchy__c = consolidationLedgerHierarchy.Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                )
            };
            insert secondLevelLedgerHierarchiesSecond;

            List<Ledger_Hierarchy__c> secondLevelHierarchies = [
                SELECT Id, Sort_Order__c
                FROM Ledger_Hierarchy__c
                WHERE Parent_Ledger_Hierarchy__c = :consolidationLedgerHierarchy.Id
                ORDER BY Sort_Order__c ASC
            ];

            System.assertEquals(1, secondLevelHierarchies[0].Sort_Order__c);
            System.assertEquals(2, secondLevelHierarchies[1].Sort_Order__c);
            System.assertEquals(3, secondLevelHierarchies[2].Sort_Order__c);
        }
    }

    @IsTest
    static void testUpdateNameToBlankOrNull() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            Test.startTest();
            List<Ledger_Hierarchy__c> hierarchies = new List<Ledger_Hierarchy__c>();
            try{
                Ledger_Hierarchy__c hierarchyNull = testData.ledgerHierarchies[0];
                hierarchyNull.Name = null;
                hierarchies.add(hierarchyNull);

                Ledger_Hierarchy__c hierarchyBlank = testData.ledgerHierarchies[1];
                hierarchyBlank.Name = '';
                hierarchies.add(hierarchyBlank);

                update hierarchies;
            }
            catch (DmlException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(2, expectedEx.getNumDml());
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, expectedEx.getDmlMessage(0));
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, expectedEx.getDmlMessage(1));
        }
    }

    @IsTest
    static void testParentTypeMatchingChecking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DMLException dmlEx;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Actual ledger',
                    Ledger__c = testData.ledgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(LedgerHierarchyActions.CHOOSE_LEDGER_WITH_CORRECT_TYPE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventAddEliminationManually() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Ledger__c eLedger = [SELECT Id FROM Ledger__c WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL LIMIT 1];
            DMLException dmlEx;
            try {
                insert new Ledger_Hierarchy__c(
                    Name = 'Test Elimination',
                    Ledger__c = eLedger.Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c
                );
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(LedgerHierarchyActions.MANUAL_ELIMINATION_HIERARCHY_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testConsolidationRoutineAllowSetStatusFromInProgressToBlank() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        List<Ledger__c> consolidationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedgers.add(ledger);
            }
        }

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Ledger_Hierarchy__c> consolidationLedgerHierarchies = new List<Ledger_Hierarchy__c>{
                new Ledger_Hierarchy__c(
                    Name = 'Actual ledger 1',
                    Ledger__c = consolidationLedgers[0].Id,
                    Last_Period__c = testData.acctPeriods.get(0).Id,
                    Last_Run__c = testData.acctPeriods.get(0).Start_Date__c,
                    Hierarchy_Status__c = LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS
                )
            };
            insert consolidationLedgerHierarchies;

            Ledger_Hierarchy__c ledgerHierarchy = [SELECT Hierarchy_Status__c FROM Ledger_Hierarchy__c WHERE Id = :consolidationLedgerHierarchies[0].Id];

            ledgerHierarchy.Hierarchy_Status__c = LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_ERROR;

            DMLException dmlEx;
            try {
                update ledgerHierarchy;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(LedgerHierarchyActions.UPDATE_CONSOLIDATION_ROUTINE_IS_IS_PROGRESS_ERROR, dmlEx.getDmlMessage(0));

            ledgerHierarchy.Hierarchy_Status__c = '';

            DMLException dmlEx2;
            try {
                update ledgerHierarchy;
            }
            catch (DMLException ex) {
                dmlEx2 = ex;
            }

            System.assertEquals(null, dmlEx2);

            Test.stopTest();
        }

    }
}