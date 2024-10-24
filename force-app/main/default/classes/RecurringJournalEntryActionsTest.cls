@IsTest
private class RecurringJournalEntryActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testRecurringJournalEntryNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Recurring_Journal_Entry__c testRJE = new Recurring_Journal_Entry__c();
                insert testRJE;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testRecurringJournalEntryLineNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Recurring_Journal_Entry_Line__c testRJEL = new Recurring_Journal_Entry_Line__c();
                insert testRJEL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testStatusInactiveEndDateExceeded() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringJournalEntry()
                .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {

            Test.startTest();
            testData.recurringJournalEntries[0].End_Date__c = Date.today();
            testData.recurringJournalEntries[0].Next_Journal_Entry_Date__c = Date.today().addMonths(1);

            testData.recurringJournalEntries[1].End_Date__c = Date.today().addMonths(1);
            testData.recurringJournalEntries[1].Next_Journal_Entry_Date__c = Date.today();
            update testData.recurringJournalEntries;

            List<Recurring_Journal_Entry__c> recurringJournalEntries = [
                    SELECT Id, Status__c
                    FROM Recurring_Journal_Entry__c
                    WHERE Id = :testData.recurringJournalEntries[0].Id OR Id = :testData.recurringJournalEntries[1].Id
            ];

            for(Recurring_Journal_Entry__c recurringJournalEntry : recurringJournalEntries){
                if(recurringJournalEntry.Id == testData.recurringJournalEntries[0].Id ){
                    System.assertEquals(RecurringBillingActions.RECURRING_STATUS_INACTIVE, recurringJournalEntry.Status__c);
                } else if(recurringJournalEntry.Id == testData.recurringJournalEntries[1].Id){
                    System.assertEquals(RecurringBillingActions.RECURRING_STATUS_ACTIVE, recurringJournalEntry.Status__c);
                }

            }
            Test.stopTest();
        }
    }

}