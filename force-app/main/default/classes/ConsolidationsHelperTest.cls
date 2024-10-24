@IsTest
private class ConsolidationsHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            testData.closePreviousAccountingPeriodsBasedOnCurrentDate();

            buildTestLedgerHierarchiesTree();
        }
    }

    /*
    * Create Ledger Hierarchy Tree:
    * -> Activision (HT: Transactional LT: Consolidations-Transactional)
    *   - Activision - EL
    *   - Infinity Ward
    *   - Raven Software
    *   - Treyarch
    *   -> Blizzard (HT: Transactional LT: Consolidations-Transactional)
    *       - Blizzard - EL
    *       - CentreSoft Limited
    */

    private static void buildTestLedgerHierarchiesTree() {
        TestDataSuite testData = TestDataSuite.getInstance();

        Map<String, String> ledgerNameToType = new Map<String, String>{
            'Activision' => LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
            'Activision - EL' => LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL,
            'Infinity Ward' => LedgerActions.LEDGER_TYPE_TRANSACTIONAL,
            'Raven Software' => LedgerActions.LEDGER_TYPE_TRANSACTIONAL,
            'Treyarch' => LedgerActions.LEDGER_TYPE_TRANSACTIONAL,
            'Blizzard' => LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
            'Blizzard - EL' => LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL,
            'CentreSoft Limited' => LedgerActions.LEDGER_TYPE_TRANSACTIONAL
        };

        System.runAs(testData.users.get(1)) {
            //Create Ledgers
            List<Ledger__c> ledgersToInsert = new List<Ledger__c>();
            for (String ledgerName : ledgerNameToType.keySet()) {
                String ledgerType = ledgerNameToType.get(ledgerName);
                //Create only Consolidation and Transactional ledgers
                if (ledgerType != LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL) {
                    ledgersToInsert.add(
                        new Ledger__c(
                            Name = ledgerName,
                            Type__c = ledgerType,
                            Default_Bank_Account__c = testData.glAccounts[0].Id,
                            Default_Billing_Format__c = testData.billingFormats[0].Id,
                            Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                            Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                        )
                    );
                }
            }

            DmlException dmlEx;
            try {
                insert ledgersToInsert;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
            List<Ledger__c> allNewLedgers = [
                SELECT Id, Name, Type__c
                FROM Ledger__c
                WHERE Name IN :ledgerNameToType.keySet()
            ];
            System.assertEquals(ledgerNameToType.keySet().size(), allNewLedgers.size());

            Map<String, Ledger__c> ledgerNameToLedgerRecord = new Map<String, Ledger__c>();
            for (Ledger__c newLedger : allNewLedgers) {
                ledgerNameToLedgerRecord.put(newLedger.Name, newLedger);
            }

            //Create Ledger Hierarchies
            //Add root node - [Activision CL]
            Ledger_Hierarchy__c activisionLH = new Ledger_Hierarchy__c(
                Name = ledgerNameToLedgerRecord.get('Activision').Name,
                Ledger__c = ledgerNameToLedgerRecord.get('Activision').Id
            );
            insert activisionLH;
            //check [Activision - EL] ledger is added into the Activision root node
            Ledger_Hierarchy__c activisionEliminationLH = [
                SELECT Id
                FROM Ledger_Hierarchy__c
                WHERE Parent_Ledger_Hierarchy__c = :activisionLH.Id
                AND Name = 'Activision - EL'
            ];
            System.assertNotEquals(null, activisionEliminationLH);

            Ledger_Hierarchy__c infinityWardLH = new Ledger_Hierarchy__c(
                Name = ledgerNameToLedgerRecord.get('Infinity Ward').Name,
                Ledger__c = ledgerNameToLedgerRecord.get('Infinity Ward').Id,
                Parent_Ledger_Hierarchy__c = activisionLH.Id
            );
            insert infinityWardLH;

            Ledger_Hierarchy__c ravenSoftwareLH = new Ledger_Hierarchy__c(
                Name = ledgerNameToLedgerRecord.get('Raven Software').Name,
                Ledger__c = ledgerNameToLedgerRecord.get('Raven Software').Id,
                Parent_Ledger_Hierarchy__c = activisionLH.Id
            );
            insert ravenSoftwareLH;

            Ledger_Hierarchy__c treyarchLH = new Ledger_Hierarchy__c(
                Name = ledgerNameToLedgerRecord.get('Treyarch').Name,
                Ledger__c = ledgerNameToLedgerRecord.get('Treyarch').Id,
                Parent_Ledger_Hierarchy__c = activisionLH.Id
            );
            insert treyarchLH;

            Ledger_Hierarchy__c blizzardLH = new Ledger_Hierarchy__c(
                Name = ledgerNameToLedgerRecord.get('Blizzard').Name,
                Ledger__c = ledgerNameToLedgerRecord.get('Blizzard').Id,
                Parent_Ledger_Hierarchy__c = activisionLH.Id
            );
            insert blizzardLH;
            //check [Blizzard - EL] ledger is added into the Blizzard node
            Ledger_Hierarchy__c blizzardEliminationLH = [
                SELECT Id
                FROM Ledger_Hierarchy__c
                WHERE Parent_Ledger_Hierarchy__c = :blizzardLH.Id
                AND Name = 'Blizzard - EL'
            ];
            System.assertNotEquals(null, blizzardEliminationLH);

            Ledger_Hierarchy__c centreSoftLH = new Ledger_Hierarchy__c(
                Name = ledgerNameToLedgerRecord.get('CentreSoft Limited').Name,
                Ledger__c = ledgerNameToLedgerRecord.get('CentreSoft Limited').Id,
                Parent_Ledger_Hierarchy__c = blizzardLH.Id
            );
            insert centreSoftLH;
        }

    }

    @IsTest
    static void testGetSetupConsolidations() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Map<String, Object> result = ConsolidationsHelper.getLedgerHierarchyRecords();

            Integer expected = [SELECT Id FROM Ledger_Hierarchy__c].size();
            System.assertEquals(expected, ((List<Object>)result.get('rows')).size());
        }

    }

    @IsTest
    static void testRunConsolidationForParent() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Ledger_Hierarchy__c parentLedgerHierarchy = [
                SELECT Id
                FROM Ledger_Hierarchy__c
                WHERE Name = 'Activision'
            ];

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();
            AbstractLWCHelper.SaveResponse sr = ConsolidationsHelper.runConsolidation(parentLedgerHierarchy.Id, testAccountingPeriod.Id, false);
            System.assertEquals(true, sr.isSuccess);

            parentLedgerHierarchy = [
                SELECT Id, Hierarchy_Status__c
                FROM Ledger_Hierarchy__c
                WHERE Name = 'Activision'
            ];
            System.assertEquals(LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS, parentLedgerHierarchy.Hierarchy_Status__c);

            Ledger_Hierarchy__c childConsolidationNode = [
                SELECT Id, Hierarchy_Status__c
                FROM Ledger_Hierarchy__c
                WHERE Name = 'Blizzard'
            ];
            System.assertEquals(null, childConsolidationNode.Hierarchy_Status__c);
        }
    }

    @IsTest
    static void testRunConsolidationForParentWithChildren() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Ledger_Hierarchy__c parentLedgerHierarchy = [
                SELECT Id
                FROM Ledger_Hierarchy__c
                WHERE Name = 'Activision'
            ];

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();
            AbstractLWCHelper.SaveResponse sr = ConsolidationsHelper.runConsolidation(parentLedgerHierarchy.Id, testAccountingPeriod.Id, true);
            System.assertEquals(true, sr.isSuccess);

            parentLedgerHierarchy = [
                SELECT Id, Hierarchy_Status__c
                FROM Ledger_Hierarchy__c
                WHERE Name = 'Activision'
            ];
            System.assertEquals(LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS, parentLedgerHierarchy.Hierarchy_Status__c);

            Ledger_Hierarchy__c childConsolidationNode = [
                SELECT Id, Hierarchy_Status__c
                FROM Ledger_Hierarchy__c
                WHERE Name = 'Blizzard'
            ];
            System.assertEquals(LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS, childConsolidationNode.Hierarchy_Status__c);
        }
    }

    @IsTest
    static void testCreateDefaultForConsolidations() {
        TestDataSuite testData = TestDataSuite.getInstance().createConsolidationLedgers();

        System.runAs(testData.users[1]) {

            Id consLedgerId = [SELECT Id, Name FROM Ledger__c WHERE Name = :'Consolidation ledger1' LIMIT 1].Id;
            List<GL_Account_Default__c> consDefs =
            [SELECT Id, GL_Account__c, GL_Account__r.Name, GL_Account_Specification__c, Ledger__c, Ledger__r.Name FROM GL_Account_Default__c WHERE Ledger__c = :consLedgerId];

            List<GL_Account_Default__c> eliminationDefs =
            [SELECT Id, GL_Account__c, GL_Account__r.Name, GL_Account_Specification__c, Ledger__c, Ledger__r.Consolidation_Ledger_ID__c FROM GL_Account_Default__c WHERE Ledger__r.Consolidation_Ledger_ID__c = :consLedgerId];

            System.assert(consDefs.isEmpty());
            System.assert(eliminationDefs.isEmpty());


            Map<String, Object> values = new Map<String, Object> {
                'ledgerId' => consLedgerId,
                'recordId' => null,
                'notes' => 'test notes',
                GLAccountDefaultsHandler.CTA_GL_ACCOUNT => testData.glAccounts[7].Id,
                GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT => testData.glAccounts[9].Id,
                GLAccountDefaultsHandler.RETAINED_EARNINGS_GL_ACCOUNT => testData.glAccounts[8].Id
            };

            Map<String, Object> saveResult = ConsolidationsHelper.saveRecord(values, new List<String>());

            List<GL_Account_Default__c> consDefsAfter =
            [SELECT Id, Ledger__c FROM GL_Account_Default__c WHERE Ledger__c = :consLedgerId];

            List<GL_Account_Default__c> eliminationDefsAfter =
            [SELECT Id, Ledger__c, Ledger__r.Consolidation_Ledger_ID__c FROM GL_Account_Default__c WHERE Ledger__r.Consolidation_Ledger_ID__c = :consLedgerId];

            System.assertEquals(3, consDefsAfter.size());
            System.assertEquals(3, eliminationDefsAfter.size());
        }

    }

}