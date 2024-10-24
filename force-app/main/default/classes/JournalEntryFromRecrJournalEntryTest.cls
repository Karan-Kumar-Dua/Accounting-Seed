@IsTest
private class JournalEntryFromRecrJournalEntryTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testCreateJournalEntryFromRecrJournalEntryIsInactiveError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Status__c = 'Inactive';
            update testData.recurringJournalEntries.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);

            Test.stopTest();

            System.assertEquals(true, jrj.isInActiveError);
            System.assertEquals(JournalEntryFromRecurringJournalEntry.INACTIVE_ERROR, ApexPages.getMessages()[0].getDetail());
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecrJournalEntryOutOfBalanceError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntryLines.get(0).Debit__c = 10;
            update testData.recurringJournalEntryLines;

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);

            Test.stopTest();

            System.assertEquals(true, jrj.isOutOfBalanceError);
            System.assertEquals(JournalEntryFromRecurringJournalEntry.OUT_OF_BALANCE_ERROR, ApexPages.getMessages()[0].getDetail());
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecrJournalEntryBiWeeklySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Journal_Entry_Frequency__c = 'Bi-weekly';
            update testData.recurringJournalEntries.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
            jrj.createJE();

            Test.stopTest();

            Recurring_Journal_Entry__c validatedTestRecurringJE = [
                SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c
                FROM Recurring_Journal_Entry__c
                WHERE Id = :testData.recurringJournalEntries.get(0).Id
            ];

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c,
                validatedTestRecurringJE.Last_Journal_Entry_Date__c
            );

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c.addDays(14),
                validatedTestRecurringJE.Next_Journal_Entry_Date__c
            );
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecrJournalEntryMonthlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Journal_Entry_Frequency__c = 'Monthly';
            update testData.recurringJournalEntries.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
            jrj.createJE();

            Test.stopTest();

            Recurring_Journal_Entry__c validatedTestRecurringJE = [
                SELECT Id, Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c, Reference__c
                FROM Recurring_Journal_Entry__c
                WHERE Id = :testData.recurringJournalEntries.get(0).Id
            ];

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c,
                validatedTestRecurringJE.Last_Journal_Entry_Date__c
            );

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c.addMonths(1),
                validatedTestRecurringJE.Next_Journal_Entry_Date__c
            );

            //check Journal Entries have fields set from recurring journal entries
            List<Journal_Entry__c> relatedJEntries = [
                SELECT id, Reference__c FROM Journal_Entry__c WHERE Recurring_Journal_Entry__c = :validatedTestRecurringJE.Id
            ];

            System.assert(relatedJEntries.size() > 0);

            for (Journal_Entry__c anEntry : relatedJEntries) {
                System.assertEquals(validatedTestRecurringJE.Reference__c, anEntry.Reference__c);
            }

            //check that recurring journal entry lines have fields set from recurring journal entry lines
            Map<Id, Recurring_Journal_Entry_Line__c> recJourLines = new Map<Id, Recurring_Journal_Entry_Line__c>([
                SELECT Id, Description__c FROM Recurring_Journal_Entry_Line__c
            ]);

            List<Journal_Entry_Line__c> relatedJourEntryLines = [
                SELECT id, Description__c, Recurring_Journal_Entry_Line__c  
                FROM Journal_Entry_Line__c 
                WHERE Recurring_Journal_Entry_Line__c IN :recJourLines.keySet()
            ];

            System.assert(relatedJourEntryLines.size() > 0);

            for (Journal_Entry_Line__c anEntry : relatedJourEntryLines) {
                System.assertEquals(recJourLines.get(anEntry.Recurring_Journal_Entry_Line__c).Description__c, anEntry.Description__c);
            }
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecurringJournalEntryQuarterlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Journal_Entry_Frequency__c = 'Quarterly';
            update testData.recurringJournalEntries.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
            jrj.createJE();

            Test.stopTest();

            Recurring_Journal_Entry__c validatedTestRecurringJE = [
                SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c
                FROM Recurring_Journal_Entry__c
                WHERE Id = :testData.recurringJournalEntries.get(0).Id
            ];

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c,
                validatedTestRecurringJE.Last_Journal_Entry_Date__c
            );

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c.addMonths(3),
                validatedTestRecurringJE.Next_Journal_Entry_Date__c
            );
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecrJournalEntrySemiAnnualSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Journal_Entry_Frequency__c = 'Semi-annual';
            update testData.recurringJournalEntries.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
            jrj.createJE();

            Test.stopTest();

            Recurring_Journal_Entry__c validatedTestRecurringJE = [
                SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c
                FROM Recurring_Journal_Entry__c
                WHERE Id = :testData.recurringJournalEntries.get(0).Id
            ];

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c,
                validatedTestRecurringJE.Last_Journal_Entry_Date__c
            );

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c.addMonths(6),
                validatedTestRecurringJE.Next_Journal_Entry_Date__c
            );
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecurringJournalEntryAnnualSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Journal_Entry_Frequency__c = 'Annual';
            update testData.recurringJournalEntries.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
            jrj.createJE();

            Test.stopTest();

            Recurring_Journal_Entry__c validatedTestRecurringJE = [
                SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c
                FROM Recurring_Journal_Entry__c
                WHERE Id = :testData.recurringJournalEntries.get(0).Id
            ];

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c,
                validatedTestRecurringJE.Last_Journal_Entry_Date__c
            );

            System.assertEquals(
                testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c.addMonths(12),
                validatedTestRecurringJE.Next_Journal_Entry_Date__c
            );
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecurringJournalEntryIsSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Status__c = 'Inactive';
            testData.recurringJournalEntryLines.get(2).Debit__c = 200;
            update testData.recurringJournalEntries;
            update testData.recurringJournalEntryLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringJournalEntries);
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(setController);

            Test.stopTest();

            System.assertEquals(true, jrj.isNoSelectionError);
        }
    }

    @isTest
    private static void testCreateJournalEntriesFromRecrJournalEntrySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringJournalEntries);
            setController.setSelected(setController.getRecords());

            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(setController);
            jrj.createJE();

            Test.stopTest();

            System.assertEquals(false, jrj.isNoSelectionError);
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecrJournalEntryTestGetNextJEDateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringJournalEntries);
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(setController);

            Test.stopTest();

            System.assertEquals(29, jrj.getNextSourceDate(Date.newInstance(2012, 1, 31), 1).day());
            System.assertEquals(31, jrj.getNextSourceDate(Date.newInstance(2012, 2, 28), 1).day());
            System.assertEquals(31, jrj.getNextSourceDate(Date.newInstance(2012, 6, 30), 1).day());
            System.assertEquals(
                Date.newInstance(2012, 6, 15).addMonths(1).day(),
                jrj.getNextSourceDate(Date.newInstance(2012, 6, 15), 1).day()
            );
        }
    }

    @isTest
    private static void testCreateJournalEntryAndPostFromRecrJournalEntrySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringJournalEntries);
            setController.setSelected(setController.getRecords());

            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(setController);
            jrj.createJEAndPost();

            System.assertEquals(false, jrj.isNoSelectionError);
            Test.stopTest();
            List<Journal_Entry__c> journalEntries = [
                SELECT Id, Status__c
                FROM Journal_Entry__c
                WHERE Recurring_Journal_Entry__c IN :testData.recurringJournalEntries
            ];

            for (Journal_Entry__c je : journalEntries) {
                System.assertEquals(
                    'Posted',
                    je.Status__c
                );

                System.assertEquals(
                    String.format(AbstractSourceFromRecurring.CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE, new List<String>{Label.COMMON_SMALL_JOURNAL_ENTRIES}),
                    ApexPages.getMessages().get(0).getDetail()
                );
            }
        }
    }

    @isTest
    private static void testCreateAndPostLineWithProjectOnly() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createProjects();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            //Create Recurring JEL with Project but without Project Task
            List<Recurring_Journal_Entry_Line__c> recurringJournalEntryLines = new List<Recurring_Journal_Entry_Line__c>();
            recurringJournalEntryLines.add(
                new Recurring_Journal_Entry_Line__c(
                    Recurring_Journal_Entry__c = testData.recurringJournalEntries.get(0).Id,
                    Quantity__c = 2,
                    Debit__c = 300,
                    GL_Account__c = testData.glAccounts.get(16).Id,
                    Project__c = testData.projects[0].Id
                )
            );

            recurringJournalEntryLines.add(
                new Recurring_Journal_Entry_Line__c(
                    Recurring_Journal_Entry__c = testData.recurringJournalEntries.get(0).Id,
                    Quantity__c = 3,
                    Credit__c = 300,
                    GL_Account__c = testData.glAccounts.get(16).Id,
                    Project__c = testData.projects[0].Id
                )
            );
            insert recurringJournalEntryLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringJournalEntries);
            setController.setSelected(setController.getRecords());

            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(setController);
            jrj.createJEAndPost();

            System.assertEquals(false, jrj.isNoSelectionError);
            Test.stopTest();
            List<Journal_Entry__c> journalEntries = [
                SELECT Id, Status__c, (SELECT Id, Project__c, Project_Task__c FROM Journal_Entry_Lines__r)
                FROM Journal_Entry__c
                WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries.get(0).Id
            ];

            for (Journal_Entry__c je : journalEntries) {
                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, je.Status__c);
                for (Journal_Entry_Line__c jel : je.Journal_Entry_Lines__r) {
                    System.assertNotEquals(NULL, jel.Project__c);
                    System.assertEquals(NULL, jel.Project_Task__c);
                }

                System.assertEquals(
                    String.format(AbstractSourceFromRecurring.CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE, new List<String>{Label.COMMON_SMALL_JOURNAL_ENTRIES}),
                    ApexPages.getMessages().get(0).getDetail()
                );
            }
        }
    }

    @isTest
    private static void testCreateMultipleJournalEntryFromRecrJournalEntryMonthlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringJournalEntries.get(0).Journal_Entry_Frequency__c = 'Monthly';
            update testData.recurringJournalEntries.get(0);

            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(testData.recurringJournalEntries);
            jrj.createJE();

            Test.stopTest();

            System.assertEquals(
                Date.newInstance(1991, 12, 31), [
                    SELECT Last_Journal_Entry_Date__c
                    FROM Recurring_Journal_Entry__c
                    WHERE Id = :testData.recurringJournalEntries[0].Id
                ].Last_Journal_Entry_Date__c
            );
            System.assertEquals(
                testData.recurringJournalEntries[0].Next_Journal_Entry_Date__c.addMonths(1), [
                    SELECT Next_Journal_Entry_Date__c
                    FROM Recurring_Journal_Entry__c
                    WHERE Id = :testData.recurringJournalEntries[0].Id
                ].Next_Journal_Entry_Date__c
            );
            System.assertEquals(
                Date.newInstance(1992, 1, 31), [
                    SELECT Last_Journal_Entry_Date__c
                    FROM Recurring_Journal_Entry__c
                    WHERE Id = :testData.recurringJournalEntries[1].Id
                ].Last_Journal_Entry_Date__c
            );
            System.assertEquals(
                testData.recurringJournalEntries[1].Next_Journal_Entry_Date__c.addMonths(1), [
                    SELECT Next_Journal_Entry_Date__c
                    FROM Recurring_Journal_Entry__c
                    WHERE Id = :testData.recurringJournalEntries[1].Id
                ].Next_Journal_Entry_Date__c
            );
            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Journal_Entry__c
                    WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries[0].Id
                ]
            );
            System.assertEquals(
                4, [
                    SELECT count()
                    FROM Journal_Entry_Line__c
                    WHERE Recurring_Journal_Entry_Line__c IN :testData.recurringJournalEntryLines
                ]
            );
        }
    }

    @isTest
    private static void testCreateJournalEntryFromRecrJournalEntryIsDmlLimitError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            List<Recurring_Journal_Entry__c> rje = new List<Recurring_Journal_Entry__c>();
            for (Integer i = 0; i < 2000; i++) {
                rje.add(testData.recurringJournalEntries.get(0).clone());
            }

            insert rje;

            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(rje);

            Test.stopTest();

            System.assertEquals(true, jrj.isDmlLimitError);
        }
    }

    @IsTest
    public static void testCreateAccountPayableFromRecrAccountPayablePlatformUserSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(0)) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User'];
            User testPlatformUser = new User(
                Alias = 'pltfUsr',
                Email = 'platformuser@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'platformUser.recbill@testorg.com'
            );
            insert testPlatformUser;

            TestDataSuite.assignAdminPermissionSet(testPlatformUser.Id);

            System.runAs(testPlatformUser) {

                Test.startTest();
                testData.disableLDVMode();

                testData.recurringJournalEntries.get(0).Journal_Entry_Frequency__c = 'Monthly';
                update testData.recurringJournalEntries.get(0);

                ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringJournalEntries.get(0));
                JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
                jrj.createJE();

                Test.stopTest();

                Recurring_Journal_Entry__c validatedTestRecurringJE = [
                    SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c
                    FROM Recurring_Journal_Entry__c
                    WHERE Id = :testData.recurringJournalEntries.get(0).Id
                ];

                System.assertEquals(
                    testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c,
                    validatedTestRecurringJE.Last_Journal_Entry_Date__c
                );

                System.assertEquals(
                    testData.recurringJournalEntries.get(0).Next_Journal_Entry_Date__c.addMonths(1),
                    validatedTestRecurringJE.Next_Journal_Entry_Date__c
                );
            }
        }

    }

    @IsTest
    private static void testCreateJELDOWithoutUpdates() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Recurring_Journal_Entry__c selectedRecurringJournal = [SELECT Id, Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c FROM Recurring_Journal_Entry__c WHERE Id = : testData.recurringJournalEntries[0].Id];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(selectedRecurringJournal);
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
            jrj.createJE();

            // the recurring JE should not have been updated - it should be updated later in the async job
            Recurring_Journal_Entry__c rJournal = [SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c FROM Recurring_Journal_Entry__c WHERE Id = :selectedRecurringJournal.Id];
            Assert.areEqual(selectedRecurringJournal.Last_Journal_Entry_Date__c, rJournal.Last_Journal_Entry_Date__c);
            Assert.areEqual(selectedRecurringJournal.Next_Journal_Entry_Date__c, rJournal.Next_Journal_Entry_Date__c);
            
            // a JE should not have been created - it should be created later in the async job
            Integer journals = [SELECT COUNT() FROM Journal_Entry__c];
            Assert.areEqual(0, journals);
            
            // JE lines should not have been created - they should be created later in the async job
            Integer lines = [SELECT COUNT() FROM Journal_Entry_Line__c];
            Assert.areEqual(0, lines);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testCreateJELDOWithUpdates() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            Recurring_Journal_Entry__c selectedRecurringJournal = [SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c FROM Recurring_Journal_Entry__c WHERE Id = : testData.recurringJournalEntries[0].Id];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(selectedRecurringJournal);
            JournalEntryFromRecurringJournalEntry jrj = new JournalEntryFromRecurringJournalEntry(controller);
            
            // edit header record to simulate field updates from UI
            Journal_Entry__c obj = (Journal_Entry__c) jrj.objList[0].obj;
            obj.Journal_Date__c = obj.Journal_Date__c.addDays(1);
            obj.Name = obj.Name + ' - updated';
            
            jrj.createJE();

            // the recurring JE should not have been updated - it should be updated later in the async job
            Recurring_Journal_Entry__c rJournal = [SELECT Last_Journal_Entry_Date__c, Next_Journal_Entry_Date__c FROM Recurring_Journal_Entry__c WHERE Id = :selectedRecurringJournal.Id];
            Assert.areEqual(selectedRecurringJournal.Last_Journal_Entry_Date__c, rJournal.Last_Journal_Entry_Date__c);
            Assert.areEqual(selectedRecurringJournal.Next_Journal_Entry_Date__c, rJournal.Next_Journal_Entry_Date__c);
            
            // a JE should have been created
            List<Journal_Entry__c> journals = [SELECT Id, Total_Credits__c, Total_Debits__c FROM Journal_Entry__c];
            Assert.areEqual(1, journals.size());
            Assert.areEqual(0, journals[0].Total_Credits__c);
            Assert.areEqual(0, journals[0].Total_Debits__c);
            
            // JE lines should not have been created - they should be created later in the async job
            Integer lines = [SELECT COUNT() FROM Journal_Entry_Line__c];
            Assert.areEqual(0, lines);

            // transaction group should have been created to be picked up by async job
            List<Transaction_Group__c> txnGroups = [SELECT Journal_Entry__c, Recurring_Journal_Entry__c FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroups.size());
            Assert.areEqual(journals[0].Id, txnGroups[0].Journal_Entry__c);
            Assert.areEqual(selectedRecurringJournal.Id, txnGroups[0].Recurring_Journal_Entry__c);

            Test.stopTest();
        }
    }

}