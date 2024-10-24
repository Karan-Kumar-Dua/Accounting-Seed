@IsTest
private class LedgerHierarchyFieldUpdateValidatorTest {
    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance()                
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new LedgerHierarchyFieldUpdateValidator();
            DMLException dmlEx;

            try {
                testData.ledgerHierarchies[0].Root_Node_ID__c = testData.ledgerHierarchies[0].Id;
                update testData.ledgerHierarchies[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                    dmlEx.getDmlMessage(0));
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
            SourceDocumentUpdateFieldValidator sfu = new LedgerHierarchyFieldUpdateValidator();
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
                LedgerHierarchyActions.bypassConsolidationRoutineValidation = true;
                update ledgerHierarchy;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                dmlEx.getDmlMessage(0));

            ledgerHierarchy.Hierarchy_Status__c = '';

            DMLException dmlEx2;
            try {
                LedgerHierarchyActions.bypassConsolidationRoutineValidation = true;
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