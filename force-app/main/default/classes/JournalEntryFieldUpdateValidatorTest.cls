@IsTest
private class JournalEntryFieldUpdateValidatorTest {

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
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.journalEntries[0].Journal_Date__c = System.today().addDays(2);
                update testData.journalEntries[0];
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
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.journalEntries[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedFieldStatusField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryFieldUpdateValidator();

            DMLException dmlEx;

            Journal_Entry__c je = [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id LIMIT 1];

            try {
                je.Status__c = 'Posted';
                update je;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidateLockedField() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .createProjects()
                .createProjectTasks()
                .createJournalEntries();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                SourceDocumentUpdateFieldValidator sfu = new JournalEntryFieldUpdateValidator();

                DMLException dmlEx;

                Journal_Entry__c je = [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id LIMIT 1];

                try {
                    je.put('CurrencyIsoCode', newCurrencyIsoCode);
                    update je;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                    dmlEx.getDmlMessage(0));
            }
        }
        catch (Exception ex) {

        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new JournalEntryFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                delete testData.journalEntries[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }
}