@IsTest
public with sharing class AutomatedJobsHelperTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSchedule() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String jobName = Label.JOB_RECUR_BILLINGS;
            String startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());

            jobName = Label.JOB_RECUR_PAYABLES;
            startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());

            jobName = Label.JOB_RECUR_JOURNAL_ENTRIES;
            startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());

            jobName = Label.JOB_EMAIL_BILLING;
            startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());

            jobName = Label.JOB_POST;
            startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>{'Billings'});
            System.assertEquals(1, DomainUtils.getCronTriggerByJobNamePrefix(jobName).size());

            jobName = Label.JOB_BANK_DOWNLOAD;
            startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());

            jobName = Label.JOB_RECUR_PERIOD_TASK;
            startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());


        }
    }

    @IsTest
    private static void testSchedule2() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String jobName = Label.JOB_PAYMENT_ACTIVITY;
            String startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());
        }
    }

    @IsTest
    private static void testScheduleNPSP() {
        TestDataSuite testData = TestDataSuite.getInstance().setNPSPEnabled();

        System.runAs(testData.users.get(1)) {
            if (AccountingSettingsHandler.isNPSPEnabled()) {
                String jobName = Label.JOB_NPSP_JOURNAL_ENTRIES;
                String startTime = '10';
                AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
                System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());
            }
        }
    }

    @IsTest
    private static void testGetSchedule() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String jobName = Label.JOB_RECUR_BILLINGS;
            String startTime = '1';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());

            jobName = Label.JOB_RECUR_PAYABLES;
            startTime = '0';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());

            jobName = Label.JOB_POST;
            startTime = '23';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>{'Billings'});

            jobName = Label.JOB_BANK_DOWNLOAD;
            startTime = '22';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());

            List<AutomatedJobsHelper.ScheduledJobWrapper> jobs = AutomatedJobsHelper.getSchedule();

            List<String> jobNames = new List<String>();
            for (AutomatedJobsHelper.ScheduledJobWrapper job : jobs) {
                jobNames.add(job.jobType);
            }
            System.assert(jobNames.contains(Label.JOB_RECUR_BILLINGS));
            System.assert(jobNames.contains(Label.JOB_RECUR_PAYABLES));
            System.assert(jobNames.contains(Label.JOB_BANK_DOWNLOAD));
            System.assert(jobNames.contains(Label.JOB_POST + ': Billings'));
        }
    }

    @IsTest
    private static void testRemove() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String jobName = Label.JOB_RECUR_BILLINGS;
            String startTime = '10';
            AutomatedJobsHelper.schedule(jobName, startTime, new List<String>());
            
            List<CronTrigger> crons = DomainUtils.getCronTriggerByJobName(new Set<String>{jobName});
            System.assertEquals(1, crons.size());

            AutomatedJobsHelper.remove(crons[0].Id);

            System.assertEquals(0, DomainUtils.getCronTriggerByJobName(new Set<String>{jobName}).size());
        }
    }

    @IsTest
    private static void testRun() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String jobName = Label.JOB_BANK_DOWNLOAD;
            String msg = AutomatedJobsHelper.run(jobName, new List<String>());
            System.assertEquals(Label.INF_AUTOMATED_JOBS_SCHEDULED_BANK_DL, msg);
        
            jobName = Label.JOB_PAYMENT_ACTIVITY;
            msg = AutomatedJobsHelper.run(jobName, new List<String>());
            System.assertEquals(Label.INF_PAYMENT_ACTIVITY_JOB_RUNNING, msg);

            jobName = Label.JOB_POST;
            msg = AutomatedJobsHelper.run(jobName, new List<String>{'Billings'});
            System.assertEquals(Label.INF_AUTOMATED_JOBS_SCHEDULED_POST, msg);
        }
    }

    @IsTest
    private static void testRunNPSP() {
        TestDataSuite testData = TestDataSuite.getInstance().setNPSPEnabled();

        System.runAs(testData.users.get(1)) {
            if (AccountingSettingsHandler.isNPSPEnabled()) {
                String jobName = Label.JOB_NPSP_JOURNAL_ENTRIES;
                String msg = AutomatedJobsHelper.run(jobName, new List<String>());
                System.assertEquals(Label.INF_AUTOMATED_JOBS_NPSP, msg);
            }
        }
    }

    @IsTest
    private static void testRunNotFound() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            try {
                String jobName = 'Fake Job';
                AutomatedJobsHelper.run(jobName, new List<String>());
            }
            catch (AutomatedJobsHelper.AutomatedJobsHelperException ex) {
                expectedEx = ex;
            }
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.COMMON_ERR_JOB_NOT_FOUND, expectedEx.getMessage());
        }
    }

    @IsTest
    private static void testRunPostJobRunning() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            AutomatedJobsHelper.run(Label.JOB_POST, new List<String>{'Billings'});
            Exception expectedEx;
            try {
                AutomatedJobsHelper.run(Label.JOB_POST, new List<String>{'Billings'});
            }
            catch (AutomatedJobsHelper.AutomatedJobsHelperException ex) {
                expectedEx = ex;
            }
            System.assertNotEquals(null, expectedEx);
            System.assertEquals(Label.WRN_RUNNING_POSTING_JOB, expectedEx.getMessage());
        }
    }

    @IsTest
    private static void testGetAvailableJobs() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<AutomatedJobsHelper.ScheduledJobDescription> descriptions = AutomatedJobsHelper.getAvailableJobs();
            
            System.assertNotEquals(null, descriptions);

            List<String> expectedJobs = new List<String>{
                Label.JOB_RECUR_BILLINGS,
                Label.JOB_RECUR_PAYABLES,
                Label.JOB_RECUR_JOURNAL_ENTRIES,
                Label.JOB_EMAIL_BILLING,
                Label.JOB_POST,
                Label.JOB_BANK_DOWNLOAD,
                Label.JOB_RECUR_PERIOD_TASK,
                Label.JOB_PAYMENT_ACTIVITY,
                Label.JOB_JOURNAL_ENTRIES,
                Label.JOB_PAYMENT_PROPOSAL
            };

            for (AutomatedJobsHelper.ScheduledJobDescription description : descriptions) {
                System.assert(expectedJobs.contains(description.value));
            }
        }
    }

    @IsTest
    private static void testGetAvailableJobsNPSP() {
        TestDataSuite testData = TestDataSuite.getInstance().setNPSPEnabled();

        System.runAs(testData.users.get(1)) {
            List<AutomatedJobsHelper.ScheduledJobDescription> descriptions = AutomatedJobsHelper.getAvailableJobs();
            
            System.assertNotEquals(null, descriptions);

            List<String> expectedJobs = new List<String>{
                Label.JOB_RECUR_BILLINGS,
                Label.JOB_RECUR_PAYABLES,
                Label.JOB_RECUR_JOURNAL_ENTRIES,
                Label.JOB_EMAIL_BILLING,
                Label.JOB_POST,
                Label.JOB_BANK_DOWNLOAD,
                Label.JOB_RECUR_PERIOD_TASK,
                Label.JOB_PAYMENT_ACTIVITY,
                Label.JOB_NPSP_JOURNAL_ENTRIES,
                Label.JOB_JOURNAL_ENTRIES,
                Label.JOB_PAYMENT_PROPOSAL
            };

            for (AutomatedJobsHelper.ScheduledJobDescription description : descriptions) {
                System.assert(expectedJobs.contains(description.value));
            }
        }
    }

}