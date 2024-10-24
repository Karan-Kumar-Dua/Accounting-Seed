@IsTest
private class RecJournalEntrySchedulableBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateBatchJEFromRecurringJESuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry().createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.recurringJournalEntries[0].Journal_Entry_Frequency__c = 'Monthly';
            update testData.recurringJournalEntries[0];

            if (DomainUtils.getCronTriggerByJobName(new Set<String> {'Recurring Journal Entry Job'}).size() != 0) {
                return;
            }

            RecurringJournalEntrySchedulableBatch.startRecurringJournalEntrySchedulableBatch(NULL, 'Recurring Journal Entry Job');
            Test.stopTest();
            System.assertEquals(
                Date.newinstance(1991, 12, 31), [
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
                Date.newinstance(1992, 01, 31), [
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
                2, [
                SELECT count()
                FROM Journal_Entry__c
                WHERE Recurring_Journal_Entry__c IN :testData.recurringJournalEntries
            ]
            );
            System.assertEquals(
                4, [
                SELECT count()
                FROM Journal_Entry_Line__c
                WHERE Recurring_Journal_Entry_Line__c IN :testData.recurringJournalEntryLines
            ]
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Journal Entry', ajr.Schedule_Job_Type__c);
            System.assertEquals(2, ajr.Processed__c);
            System.assertEquals(2, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    public static void testCreateBatchPayableNextDateMoreToday() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry().createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            for (Recurring_Journal_Entry__c rPay : testData.recurringJournalEntries) {
                rPay.Next_Journal_Entry_Date__c = System.today().addDays(2);
            }
            update testData.recurringJournalEntries;

            RecurringJournalEntrySchedulableBatch.startRecurringJournalEntrySchedulableBatch(NULL,'Recurring Journal Entry Job');
            Test.stopTest();
            System.assertEquals(
                0, [
                SELECT count()
                FROM Journal_Entry__c
                WHERE Recurring_Journal_Entry__c IN :testData.recurringJournalEntries
            ]
            );
            System.assertEquals(
                0, [
                SELECT count()
                FROM Journal_Entry_Line__c
                WHERE Recurring_Journal_Entry_Line__c IN :testData.recurringJournalEntryLines
            ]
            );
        }
    }

    @IsTest
    public static void testCreateBatchExcludeScheduledJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry().createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            for (Recurring_Journal_Entry__c rPay : testData.recurringJournalEntries) {
                rPay.Exclude_From_Automation__c = true;
            }
            update testData.recurringJournalEntries;

            RecurringJournalEntrySchedulableBatch.startRecurringJournalEntrySchedulableBatch(NULL, 'Recurring Journal Entry Job');
            Test.stopTest();
            System.assertEquals(
                0, [
                SELECT count()
                FROM Journal_Entry__c
                WHERE Recurring_Journal_Entry__c IN :testData.recurringJournalEntries
            ]
            );
            System.assertEquals(
                0, [
                SELECT count()
                FROM Journal_Entry_Line__c
                WHERE Recurring_Journal_Entry_Line__c IN :testData.recurringJournalEntryLines
            ]
            );
        }
    }

    @IsTest
    public static void testCreateBatchSchedulerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Recurring_Journal_Entry__c testRecurringJournalEntry = new Recurring_Journal_Entry__c(
                Name = 'Test Journal Entry 1',
                Next_Journal_Entry_Date__c = Date.newInstance(1991, 12, 31),
                Journal_Entry_Frequency__c = 'Monthly',
                Status__c = 'Active'
            );
            insert testRecurringJournalEntry;

            Recurring_Journal_Entry_Line__c testRecurringJournalEntryLine = new Recurring_Journal_Entry_Line__c(
                Recurring_Journal_Entry__c = testRecurringJournalEntry.Id,
                Quantity__c = 2,
                Debit__c = 300,
                GL_Account__c = testData.glAccounts.get(16).Id
            );
            insert testRecurringJournalEntryLine;

            RecurringJournalEntrySchedulableBatch.startRecurringJournalEntrySchedulableBatch('0 0 0 * * ? *', 'Recurring Journal Entry Job');

            CronTrigger ct = [SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, TimesTriggered FROM CronTrigger WHERE CronJobDetail.Name = 'Recurring Journal Entry Job'];

            System.assertNotEquals(NULL, ct);
            System.assertEquals(0, ct.TimesTriggered);

            Test.stopTest();

            AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE ApexClass.Name = 'RecurringJournalEntrySchedulableBatch' AND JobType = 'BatchApex'];
            System.assertNotEquals(NULL, job);

        }
    }

    @IsTest
    public static void testCreateBatchSchedulerPartialSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true).createRecurringJournalEntry().createRecurringJournalEntryLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //set Bank GL Account on Recurring JE Line to prevent JE Line creation
            Recurring_Journal_Entry_Line__c badLine = testData.recurringJournalEntryLines[0].clone(false, true, false, false);
            badLine.GL_Account__c = testData.cashFlowCategories[0].Id;

            RecurringJournalEntryLineActions.bypassGLAccountValidation = true;
            insert badLine;
            RecurringJournalEntryLineActions.bypassGLAccountValidation = false;
            delete testData.recurringJournalEntryLines[0];

            RecurringJournalEntrySchedulableBatch.startRecurringJournalEntrySchedulableBatch(NULL, 'Recurring Journal Entry Job');

            Test.stopTest();

            AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE ApexClass.Name = 'RecurringJournalEntrySchedulableBatch' AND JobType = 'BatchApex'];
            System.assertNotEquals(NULL, job);

            System.assertEquals(0, [SELECT count() FROM Journal_Entry__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries[0].Id]);
            System.assertEquals(1, [SELECT count() FROM Journal_Entry__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries[1].Id]);

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Journal Entry', ajr.Schedule_Job_Type__c);
            System.assertEquals(2, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(1, ajr.Failed__c);
        }
    }

}