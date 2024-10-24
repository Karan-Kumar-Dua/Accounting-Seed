@IsTest
private class JournalEntryLineFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryLineFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.journalEntryLines[0].Units__c = 233;
                update testData.journalEntryLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryLineFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.journalEntryLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidatePreventInsertActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryLineFieldUpdateValidator();
            Journal_Entry_Line__c newJELine = testData.journalEntryLines[0].clone();
            newJELine.Journal_Entry__c = testData.journalEntries[0].Id;

            DMLException dmlEx;

            try {
                insert newJELine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_INSERT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryLineFieldUpdateValidator();

            DMLException dmlEx;

            Journal_Entry_Line__c jel = [SELECT Id, Bank_Reconciliation__c FROM Journal_Entry_Line__c WHERE Id = :testData.journalEntryLines[0].Id LIMIT 1];

            try {
                jel.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
                update jel;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateLockedFieldDependingOfFeatureManagement() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryLineFieldUpdateValidator();
            DMLException dmlEx;
            Journal_Entry_Line__c jel = [
                SELECT
                    Id, Bank_Transaction__c
                FROM Journal_Entry_Line__c
                WHERE Id = :testData.journalEntryLines[0].Id LIMIT 1
            ];
            try {
                jel.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update jel;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}
                ),
                dmlEx.getDmlMessage(0)
            );

            //Enable Force Match Feature to allow update of the Bank Transaction field on JEL record
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Financial_Suite_Key__c = GlobalVariables.FORCE_MATCH_PERMISSION_KEY;
            update settings;

            dmlEx = NULL;
            try {
                jel.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update jel;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            //No DML error expected since we bypass Bank Transaction field's validation via FORCE_MATCH_PERMISSION_KEY
            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                testData.bankTransactions[0].Id,
                [SELECT Bank_Transaction__c FROM Journal_Entry_Line__c WHERE Id = :testData.journalEntryLines[0].Id].Bank_Transaction__c
            );
        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryLineFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                delete testData.journalEntryLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }
    }

}