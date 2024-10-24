@IsTest
public class JournalEntryDeepCloneTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testJournalEntryDeepCloneNoAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users[1]) {
            JournalEntryDeepClone jed = new JournalEntryDeepClone(new ApexPages.standardController(testData.journalEntries[0]));
            jed.tempJournalEntry.Journal_Date__c = Date.newInstance(1970, 3, 13);
            jed.cloneJournalEntry();

            System.assertEquals(
                    String.format(JournalEntryDeepClone.NO_OPEN_PERIOD_ERROR_MESSAGE, new List<String>{(jed.tempJournalEntry.Journal_Date__c).format()}),
                    ApexPages.getMessages()[0].getDetail()
            );
        }
    }

    @IsTest
    public static void testJournalEntryDeepCloneSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            JournalEntryDeepClone jed = new JournalEntryDeepClone(new ApexPages.standardController(testData.journalEntries[0]));
            jed.tempJournalEntry.Journal_Date__c = testData.acctPeriods[0].Start_Date__c;
            jed.cloneJournalEntry();

            System.assertEquals(1, [SELECT count() FROM Journal_Entry__c WHERE Id = :jed.journalEntry.Id]);

            System.assertEquals(
                [SELECT Total_Credits__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Total_Credits__c,
                [SELECT Total_Credits__c FROM Journal_Entry__c WHERE Id = :jed.journalEntry.Id].Total_Credits__c
            );

            System.assertEquals(
                [SELECT Total_Debits__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Total_Debits__c,
                [SELECT Total_Debits__c FROM Journal_Entry__c WHERE Id = :jed.journalEntry.Id].Total_Debits__c
            );
        }
    }

    @IsTest
    public static void testJournalEntryReverseDeepCloneSucess() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            JournalEntryDeepClone jed = new JournalEntryDeepClone(new ApexPages.standardController(testData.journalEntries[0]));
            jed.tempJournalEntry.Journal_Date__c = testData.acctPeriods[0].Start_Date__c;
            jed.reverseCloneJournalEntry();

            System.assertEquals(1, [SELECT count() FROM Journal_Entry__c WHERE Id = :jed.journalEntry.Id]);

            System.assertEquals(
                [SELECT Total_Debits__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Total_Debits__c,
                [SELECT Total_Credits__c FROM Journal_Entry__c WHERE Id = :jed.journalEntry.Id].Total_Credits__c
            );

            System.assertEquals(
                [SELECT Total_Credits__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Total_Credits__c,
                [SELECT Total_Debits__c FROM Journal_Entry__c WHERE Id = :jed.journalEntry.Id].Total_Debits__c
            );
        }
    }
}