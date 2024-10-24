@IsTest
public class JournalEntryPostServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE1 = testData.journalEntries[0];
            Journal_Entry__c testJE2 = testData.journalEntries[1];

            testJE2.Status__c = 'In Process';
            update testJE2;

            List<PostResult> postResults = JournalEntryPostService.postJournalEntries(new List<Journal_Entry__c>{testJE1, testJE2});
            System.assertEquals(2, postResults.size());

            PostResult testJE1PostResult;
            PostResult testJE2PostResult;
            for (PostResult postResult : postResults) {
                if (postResult.id == testJE1.Id) {
                    testJE1PostResult = postResult;
                }
                if (postResult.id == testJE2.Id) {
                    testJE2PostResult = postResult;
                }
            }

            System.assertEquals(true, testJE1PostResult.isSuccess);
            System.assertEquals(false, testJE2PostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.NOT_APPROVED_ERROR_MESSAGE, testJE2PostResult.errors.get(0).message);
        }

    }

    @IsTest
    public static void testUnPostPartial() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Journal_Entry__c testJE1 = testData.journalEntries[0];
            Journal_Entry__c testJE2 = testData.journalEntries[1];

            testJE2.Status__c = 'In Process';
            update testJE2;

            List<PostResult> postResults = JournalEntryPostService.postJournalEntries(new List<Journal_Entry__c>{testJE1, testJE2});
            List<PostResult> unpostResults = JournalEntryPostService.unpostJournalEntries(new List<Journal_Entry__c>{testJE1, testJE2});

            PostResult testJE1UnPostResult;
            PostResult testJE2UnPostResult;
            for (PostResult postResult : unpostResults) {
                if (postResult.id == testJE1.Id) {
                    testJE1UnPostResult = postResult;
                }
                if (postResult.id == testJE2.Id) {
                    testJE2UnPostResult = postResult;
                }
            }

            System.assertEquals(true, testJE1UnPostResult.isSuccess);
            System.assertEquals(false, testJE2UnPostResult.isSuccess);
            System.assertEquals(AbstractPostHandler.UNPOSTED_ERROR_MESSAGE, testJE2UnPostResult.errors.get(0).message);
        }

    }

    @IsTest
    public static void testNoJournalEntryLinesPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            delete testData.journalEntryLines;

            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_LINES, results[0].errors[0].statusCode);
        }

    }
    
    @IsTest
    public static void testAccountingPeriodClosedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }  
    
    @IsTest
    public static void testAlreadyPostedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(true, results[0].isSuccess);

            results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED, results[0].errors[0].statusCode);
        }

    }
     
    @IsTest   
    public static void testStatusNotApprovedPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        Journal_Entry__c journalEntry = testData.journalEntries[0];
        journalEntry.Status__c = 'In Process';
        update journalEntry;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{journalEntry});
            Test.stopTest();
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.STATUS_NOT_APPROVED, results[0].errors[0].statusCode);
        }

    }   
    
    @IsTest
    public static void testCreditsNotEqualDebitsPostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntryLines[0].Credit__c = 1200;
            update testData.journalEntryLines[0];

            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CREDITS_DEBITS_NOT_EQUAL, results[0].errors[0].statusCode);
        }

    } 

    @IsTest
    public static void testCreditsNotEqualDebitsPostLargeScaleSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Credit__c = 100.456346346436436464,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testData.journalEntries[0].Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Debit__c = 100.456346346436436463,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10
                )
            );
            insert journalEntryLines;

            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(true, results[0].isSuccess);
        }

    } 
        
    @IsTest
    public static void testPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(true, results[0].isSuccess);
        }

    }
    
    @IsTest
    public static void testAccountingPeriodClosedUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            results = JournalEntryPostService.unpostJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, results[0].errors[0].statusCode);
        }

    }
    
    @IsTest
    public static void testNotPostedUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results =
                JournalEntryPostService.unpostJournalEntries(new List<Journal_Entry__c>{testData.journalEntries[0]});

            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_UNPOSTED, results[0].errors[0].statusCode);
            System.assertEquals(
                testData.journalEntries[0].Status__c,
                [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Status__c
            );
        }

    }
    
    @IsTest
    public static void testClearedBankReconciliationUnpostError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntryLines[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Reconciliation__c);
            update testData.journalEntryLines[0];
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Reconciliation__c);

            List<PostResult> results = JournalEntryPostService.postJournalEntries(new List<Journal_Entry__c>{testData.journalEntries[0]});
            System.assertEquals(true, results[0].isSuccess);

            results = JournalEntryPostService.unpostJournalEntries(new List<Journal_Entry__c>{testData.journalEntries[0]});
            System.assertEquals(false, results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION, results[0].errors[0].statusCode);
        }

    }

    @IsTest
    public static void testJournalEntryUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<PostResult> results = JournalEntryPostService.postJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(true, results[0].isSuccess);
            results = JournalEntryPostService.unpostJournalEntries(new Journal_Entry__c[]{testData.journalEntries[0]});
            System.assertEquals(true, results[0].isSuccess);
        }

    }

}