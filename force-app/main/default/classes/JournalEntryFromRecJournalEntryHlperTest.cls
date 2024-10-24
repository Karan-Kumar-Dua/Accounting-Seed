@IsTest
public with sharing class JournalEntryFromRecJournalEntryHlperTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringJEIds = new Set<Id>{ testData.recurringJournalEntries[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringJournalEntryLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Journal_Entry_Line__c> lines = selector.selectLinesByHeaderId(recurringJEIds);

            // create the source records
            String batchId = 'batch_id_123';
            JournalEntryFromRecurJournalEntryHelper helper = new JournalEntryFromRecurJournalEntryHelper(lines, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify the results
            List<Transaction_Group__c> txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Journal_Entry__c, Journal_Entry__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Transaction_Group__c txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Journal_Entry__c);
            Assert.isTrue(recurringJEIds.contains(txnGroup.Recurring_Journal_Entry__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(lines.size(), txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_COMPLETED, txnGroup.Status__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupUpdated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringJEIds = new Set<Id>{ testData.recurringJournalEntries[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringJournalEntryLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Journal_Entry_Line__c> lines = selector.selectLinesByHeaderId(recurringJEIds);
            Assert.areEqual(2, lines.size());

            // create the source records for the first line
            String batchId = 'batch_id_123';
            JournalEntryFromRecurJournalEntryHelper helper = new JournalEntryFromRecurJournalEntryHelper(new List<Recurring_Journal_Entry_Line__c>{lines[0]}, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify first run results
            List<Transaction_Group__c> txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Journal_Entry__c, Journal_Entry__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Transaction_Group__c txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Journal_Entry__c);
            Assert.isTrue(recurringJEIds.contains(txnGroup.Recurring_Journal_Entry__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(1, txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_PROCESSING, txnGroup.Status__c);

            // create the source records for the second line
            helper = new JournalEntryFromRecurJournalEntryHelper(new List<Recurring_Journal_Entry_Line__c>{lines[1]}, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify second run results
            txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Journal_Entry__c, Journal_Entry__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Journal_Entry__c);
            Assert.isTrue(recurringJEIds.contains(txnGroup.Recurring_Journal_Entry__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(lines.size(), txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_COMPLETED, txnGroup.Status__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsRecurringScheduleUpdated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringJEIds = new Set<Id>{ testData.recurringJournalEntries[0].Id };
            
            List<Recurring_Journal_Entry__c> recurBefore = [SELECT Next_Journal_Entry_Date__c FROM Recurring_Journal_Entry__c WHERE Id IN :recurringJEIds];

            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringJournalEntryLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Journal_Entry_Line__c> lines = selector.selectLinesByHeaderId(recurringJEIds);

            // create the source records
            String batchId = 'batch_id_123';
            JournalEntryFromRecurJournalEntryHelper helper = new JournalEntryFromRecurJournalEntryHelper(lines, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify the results
            List<Recurring_Journal_Entry__c> recurAfter = [SELECT Next_Journal_Entry_Date__c, Last_Journal_Entry_Date__c FROM Recurring_Journal_Entry__c WHERE Id IN :recurringJEIds];
            Assert.areEqual(recurBefore[0].Next_Journal_Entry_Date__c.addMonths(1), recurAfter[0].Next_Journal_Entry_Date__c);
            Assert.areEqual(recurBefore[0].Next_Journal_Entry_Date__c, recurAfter[0].Last_Journal_Entry_Date__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsJECreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringJEIds = new Set<Id>{ testData.recurringJournalEntries[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringJournalEntryLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Journal_Entry_Line__c> lines = selector.selectLinesByHeaderId(recurringJEIds);

            // create the source records
            String batchId = 'batch_id_123';
            JournalEntryFromRecurJournalEntryHelper helper = new JournalEntryFromRecurJournalEntryHelper(lines, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify the results
            // get the Journal Entry record
            List<Journal_Entry__c> journalEntries = [
                SELECT 
                    Name,
                    Journal_Date__c,
                    Ledger__c,
                    Recurring_Journal_Entry__c,
                    Auto_Reverse__c,
                    Reference__c,
                    Type__c,
                    Source__c
                FROM Journal_Entry__c 
                WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries[0].Id
            ];
            Assert.isNotNull(journalEntries);
            Assert.areEqual(1, journalEntries.size());
            Journal_Entry__c journalEntry = journalEntries[0];

            // get the recurring journal Entry record
            Recurring_Journal_Entry__c recur = [
                SELECT 
                    Name,
                    Ledger__c,
                    Next_Journal_Entry_Date__c,
                    Auto_Reverse__c,
                    Reference__c,
                    Type__c
                FROM Recurring_Journal_Entry__c 
                WHERE Id = :lines[0].Recurring_Journal_Entry__c
            ];
            
            Assert.areEqual(recur.Name, journalEntry.Name);
            Assert.areEqual(recur.Ledger__c, journalEntry.Ledger__c);
            Assert.areEqual(recur.Auto_Reverse__c, journalEntry.Auto_Reverse__c);
            Assert.areEqual(recur.Reference__c, journalEntry.Reference__c);
            Assert.areEqual(recur.Type__c, journalEntry.Type__c);
            Assert.areEqual(JournalEntryActions.SOURCE_RJE, journalEntry.Source__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsJELinesCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringJEIds = new Set<Id>{ testData.recurringJournalEntries[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringJournalEntryLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Journal_Entry_Line__c> lines = selector.selectLinesByHeaderId(recurringJEIds);

            // create the source records
            String batchId = 'batch_id_123';
            JournalEntryFromRecurJournalEntryHelper helper = new JournalEntryFromRecurJournalEntryHelper(lines, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify the results
            // get the recurring Journal Entry line records
            List<Recurring_Journal_Entry_Line__c> recurLines = [
                SELECT 
                    Id,
                    Cash_Flow_Category__c,
                    GL_Account__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Debit__c,
                    Quantity__c,
                    Reference__c,
                    Credit__c,
                    Account__c,
                    Project__c,
                    Project_Task__c,
                    Contact__c,
                    Employee__c,
                    Description__c
                FROM Recurring_Journal_Entry_Line__c 
                WHERE Recurring_Journal_Entry__c = :lines[0].Recurring_Journal_Entry__c
            ];
            Assert.isNotNull(recurLines);
            Assert.areEqual(2, recurLines.size());
            Map<Id, Recurring_Journal_Entry_Line__c> recurLinesMap = new Map<Id, Recurring_Journal_Entry_Line__c>(recurLines);

            // get the journal Entry line records
            List<Journal_Entry_Line__c> jELines = [
                SELECT 
                    Id,
                    Recurring_Journal_Entry_Line__c,
                    Cash_Flow_Category__c,
                    GL_Account__c,
                    Units__c,
                    Reference__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Credit__c,
                    Debit__c,
                    Account__c,
                    Contact__c,
                    Employee__c,
                    Project__c,
                    Project_Task__c,
                    Description__c
                FROM Journal_Entry_Line__c 
                WHERE Recurring_Journal_Entry_Line__c = :recurLinesMap.keySet()
            ];
            Assert.isNotNull(recurLines);
            Assert.areEqual(2, recurLines.size());

            for (Journal_Entry_Line__c line : jELines) {
                Recurring_Journal_Entry_Line__c recurLine = recurLinesMap.get(line.Recurring_Journal_Entry_Line__c);
                Assert.isNotNull(recurLine);
                Assert.areEqual(recurLine.Cash_Flow_Category__c, line.Cash_Flow_Category__c);
                Assert.areEqual(recurLine.GL_Account__c, line.GL_Account__c);
                Assert.areEqual(recurLine.GL_Account_Variable_1__c, line.GL_Account_Variable_1__c);
                Assert.areEqual(recurLine.GL_Account_Variable_2__c, line.GL_Account_Variable_2__c);
                Assert.areEqual(recurLine.GL_Account_Variable_3__c, line.GL_Account_Variable_3__c);
                Assert.areEqual(recurLine.GL_Account_Variable_4__c, line.GL_Account_Variable_4__c);
                Assert.areEqual(recurLine.Debit__c, line.Debit__c);
                Assert.areEqual(recurLine.Reference__c, line.Reference__c);
                Assert.areEqual(recurLine.Project__c, line.Project__c);
                Assert.areEqual(recurLine.Project_Task__c, line.Project_Task__c);
                Assert.areEqual(recurLine.Quantity__c, line.Units__c);
                Assert.areEqual(recurLine.Credit__c, line.Credit__c);
                Assert.areEqual(recurLine.Account__c, line.Account__c);
                Assert.areEqual(recurLine.Contact__c, line.Contact__c);
                Assert.areEqual(recurLine.Employee__c, line.Employee__c);
                Assert.areEqual(recurLine.Description__c, line.Description__c);
            }
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupFailed() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            // force error
            delete [SELECT Id FROM Accounting_Period__c];

            // get the lines to process
            Set<Id> recurringJEIds = new Set<Id>{ testData.recurringJournalEntries[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringJournalEntryLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Journal_Entry_Line__c> lines = selector.selectLinesByHeaderId(recurringJEIds);

            // create the source records
            String batchId = 'batch_id_123';
            JournalEntryFromRecurJournalEntryHelper helper = new JournalEntryFromRecurJournalEntryHelper(lines, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify the results
            List<Transaction_Group__c> txnGroups = [SELECT Status__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Assert.areEqual(TransactionGroupActions.STATUS_FAILED, txnGroups[0].Status__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsNoDuplicateBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringJEIds = new Set<Id>{ testData.recurringJournalEntries[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringJournalEntryLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Journal_Entry_Line__c> lines = selector.selectLinesByHeaderId(recurringJEIds);
            Assert.areEqual(2, lines.size());

            // create the source records for the first line
            String batchId = 'batch_id_123';
            JournalEntryFromRecurJournalEntryHelper helper = new JournalEntryFromRecurJournalEntryHelper(new List<Recurring_Journal_Entry_Line__c>{lines[0]}, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify first run results
            Integer txnGroupCnt = [SELECT COUNT() FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroupCnt);

            Integer journalEntryCnt = [SELECT COUNT() FROM Journal_Entry__c];
            Assert.areEqual(1, journalEntryCnt);

            Integer lineCnt = [SELECT COUNT() FROM Journal_Entry_Line__c];
            Assert.areEqual(1, lineCnt);

            // create the source records for the second line
            helper = new JournalEntryFromRecurJournalEntryHelper(new List<Recurring_Journal_Entry_Line__c>{lines[1]}, batchId, AJRLoggerTest.getTestLogger());
            helper.createSourceRecords();

            // verify second run results
            txnGroupCnt = [SELECT COUNT() FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroupCnt);

            journalEntryCnt = [SELECT COUNT() FROM Journal_Entry__c];
            Assert.areEqual(1, journalEntryCnt);

            lineCnt = [SELECT COUNT() FROM Journal_Entry_Line__c];
            Assert.areEqual(2, lineCnt);
        }
    }

}