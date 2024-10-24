@IsTest
private class AutomatedJobResultsHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testCreateAutomatedJobResultsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            AutomatedJobResultsHandler.setJobType('Recurring Billing Job');
            AutomatedJobResultsHandler.setProcessed(10);
            AutomatedJobResultsHandler.setSucceeded(8);
            AutomatedJobResultsHandler.setFailed(2);
            AutomatedJobResultsHandler.setError(AutomatedJobResultsHandler.getReportLink('Recurring Billing Job'));
            AutomatedJobResultsHandler.saveAutomatedJobResults();

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c, Notes__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Billing', ajr.Schedule_Job_Type__c);
            System.assertEquals(10, ajr.Processed__c);
            System.assertEquals(8, ajr.Succeeded__c);
            System.assertEquals(2, ajr.Failed__c);
            System.assertNotEquals('', ajr.Notes__c);
        }
    }

    @IsTest
    static void testAutomatedJobResultsFailedWrongJobType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            AutomatedJobResultsHandler.setJobType('Test Job');
            AutomatedJobResultsHandler.setProcessed(10);
            AutomatedJobResultsHandler.setSucceeded(8);
            AutomatedJobResultsHandler.setFailed(2);
            AutomatedJobResultsHandler.setError(AutomatedJobResultsHandler.getReportLink('Test Job'));
            AutomatedJobResultsHandler.saveAutomatedJobResults();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c, Notes__c FROM Automated_Job_Results__c];

            System.assert(ajr.isEmpty());
        }
    }

    @IsTest
    static void testAutomatedJobResultsFailedEmptyRequiredFields() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            AutomatedJobResultsHandler.saveAutomatedJobResults();

            List<Automated_Job_Results__c> ajr = [SELECT Id FROM Automated_Job_Results__c];
            System.assert(ajr.isEmpty());

            AutomatedJobResultsHandler.setJobType('Recurring Billing Job');
            AutomatedJobResultsHandler.saveAutomatedJobResults();

            ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c, Notes__c FROM Automated_Job_Results__c];

            System.assertEquals(0, ajr[0].Processed__c);
            System.assertEquals(0, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
            System.assertNotEquals('', ajr[0].Notes__c);
        }
    }

    @IsTest
    private static void testAutomatedJobResultsBatchPostNotes() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users[1]) {
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [SELECT Status__c FROM Billing__c][0].Status__c
            );

            Test.startTest();
            List<String> schdPostTypes = new List<String>{'Billings'};
            //Run batch job to post Billings with "Approved" Posting Status
            Database.executeBatch(new BillingPostBatch(new SourceRecordPostBatchChainController(schdPostTypes), null));
            Test.stopTest();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c][0].Status__c
            );
            Automated_Job_Results__c ajr = [
                SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c, Notes__c
                FROM Automated_Job_Results__c
            ];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(5, ajr.Processed__c);
            System.assertEquals(5, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
            System.assert(ajr.Notes__c.contains(Label.INF_NO_OF_BILLINGS_PROCESSED + ': 5'));
            System.assert(ajr.Notes__c.contains(Label.INF_NO_OF_BILLINGS_POSTED_SUCCESSFULLY + ': 5'));
            System.assert(ajr.Notes__c.contains(Label.INF_NO_OF_BILLINGS_FAILED + ': 0'));
            System.assert(ajr.Notes__c.contains(URL.getOrgDomainUrl().toExternalForm()));
        }
    }

    @IsTest
    static void testAutomatedJobResultsReportLink() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            String testLink = URL.getOrgDomainUrl().toExternalForm() + '/00000000000xxxxAAA';
            System.assertEquals(testLink, AutomatedJobResultsHandler.getReportLink('test report job'));
        }
    }
}