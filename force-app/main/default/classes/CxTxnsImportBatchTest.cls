@IsTest
public with sharing class CxTxnsImportBatchTest {
   
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testStartFirstRun() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users[1]) {
            // only want to test with one processor
            testData.paymentProcessors[3].Active__c = false;
            update testData.paymentProcessors[3];

            // validate test setup
            Payment_Processor__c processor = [SELECT Id, Last_Sync__c FROM Payment_Processor__c WHERE Id = :testData.paymentProcessors[2].Id];
            Assert.isNull(processor.Last_Sync__c, 'Incorrect test setup. Expected Last_Sync__c to be null in order to simulate first run for processor.');

            CxTxnsImportBatch job = new CxTxnsImportBatch();
            Iterable<Integer> jobScope = job.start(null);

            Integer jobSize = 0;
            Iterator<Integer> itr = jobScope.iterator();
            while (itr.hasNext()) {
                itr.next();
                jobSize++;
            }

            Assert.areEqual(CxTxnsImportBatch.FIRST_SYNC_DAYS, jobSize);
        }
    }

    @IsTest
    static void testStartSubsequentRun() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users[1]) {
            // only want to test with one processor
            testData.paymentProcessors[3].Active__c = false;
            update testData.paymentProcessors[3];

            // set last sync date
            Payment_Processor__c processor = [SELECT Id, Last_Sync__c FROM Payment_Processor__c WHERE Id = :testData.paymentProcessors[2].Id];
            Integer daysSinceLastSync = 2;
            processor.Last_Sync__c = Datetime.now().addDays(-1 * daysSinceLastSync);
            update processor;

            CxTxnsImportBatch job = new CxTxnsImportBatch();
            Iterable<Integer> jobScope = job.start(null);

            Integer jobSize = 0;
            Iterator<Integer> itr = jobScope.iterator();
            while (itr.hasNext()) {
                itr.next();
                jobSize++;
            }

            Assert.areEqual(daysSinceLastSync, jobSize);
            Assert.isTrue(job.syncProgress.containsKey(processor.Id)); 
            Assert.areEqual(processor.Last_Sync__c, job.syncProgress.get(processor.Id));
        }
    }

    @IsTest
    static void testStartOverflowRun() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users[1]) {
            // only want to test with one processor
            testData.paymentProcessors[3].Active__c = false;
            update testData.paymentProcessors[3];

            // set last sync date
            Payment_Processor__c processor = [SELECT Id, Last_Sync__c FROM Payment_Processor__c WHERE Id = :testData.paymentProcessors[2].Id];
            Datetime endDate = Datetime.now();
            processor.Last_Sync__c = endDate.addDays(-5);
            update processor;
            
            Datetime startDate = endDate.addDays(-2);
            Map<Id,Datetime> syncProgress = new Map<Id,Datetime>{ processor.Id => startDate };
            // simulate job finished but not all txns imported. job reschedules itself to pickup from where it stopped
            CxTxnsImportBatch job = new CxTxnsImportBatch(endDate, syncProgress, new Set<Id>(), new CxAJRLogger());
            Iterable<Integer> jobScope = job.start(null);

            Integer jobSize = 0;
            Iterator<Integer> itr = jobScope.iterator();
            while (itr.hasNext()) {
                itr.next();
                jobSize++;
            }

            Assert.areEqual(2, jobSize);
            Assert.isTrue(job.syncProgress.containsKey(processor.Id)); 
            Assert.areEqual(startDate, job.syncProgress.get(processor.Id));
        }
    }

    @IsTest
    static void testExecute() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users[1]) {
            // only want to test with one processor
            testData.paymentProcessors[3].Active__c = false;
            update testData.paymentProcessors[3];

            CxTxnsImportBatch job = new CxTxnsImportBatch();

            // mock importer
            GenericMock mock = new GenericMock();
            mock.registerResponse('import', job.endDate);
            CxTxnsImporter importer = (CxTxnsImporter) Test.createStub(CxTxnsImporter.class, mock);
            CxTxnsImportBatch.mockImporter = importer;

            job.start(null); //  needs to be run for setup
            job.execute(null, new List<Integer>{1}); // inputs don't matter

            Assert.isTrue(job.syncProgress.isEmpty(), 'Expected processing to be complete (items removed from syncProgress when upto date).');
            Assert.areEqual(1, job.processorsCompletedNormally.size(), 'Expected processing completed normally.');
        }
    }

    @IsTest
    static void testExecuteError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users[1]) {
            // only want to test with one processor
            testData.paymentProcessors[3].Active__c = false;
            update testData.paymentProcessors[3];

            // mock importer
            GenericMock mock = new GenericMock();
            mock.registerResponse('import', new CxTxnsImporter.CxTxnsImporterException('test error'));
            CxTxnsImporter importer = (CxTxnsImporter) Test.createStub(CxTxnsImporter.class, mock);
            CxTxnsImportBatch.mockImporter = importer;

            // simulate job finished with errors
            CxTxnsImportBatch job = new CxTxnsImportBatch();
            job.start(null); //  needs to be run for setup
            job.execute(null, new List<Integer>{1}); // inputs don't matter

            Assert.isTrue(job.syncProgress.isEmpty(), 'Expected processing to be complete (items removed from syncProgress on error).');
            Assert.isTrue(job.processorsCompletedNormally.isEmpty(), 'Expected processing completed with errors.');
        }
    }

    @IsTest
    static void testExecuteHasMore() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();
        
        System.runAs(testData.users[1]) {
            // only want to test with one processor
            testData.paymentProcessors[3].Active__c = false;
            update testData.paymentProcessors[3];

            // mock importer
            GenericMock mock = new GenericMock();
            mock.registerResponse('import', Datetime.now().addDays(-1));
            CxTxnsImporter importer = (CxTxnsImporter) Test.createStub(CxTxnsImporter.class, mock);
            CxTxnsImportBatch.mockImporter = importer;

            // simulate job finished with with more outstanding items to process
            CxTxnsImportBatch job = new CxTxnsImportBatch();
            job.start(null); //  needs to be run for setup
            job.execute(null, new List<Integer>{1}); // inputs don't matter

            Assert.isFalse(job.syncProgress.isEmpty(), 'Expected sync not fully complete (syncProgress still has items for processing).');
            Assert.isTrue(job.processorsCompletedNormally.isEmpty(), 'Expected processing not completed.');
        }
    }

    @IsTest
    static void testLastSyncUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            // only want to test with one processor
            testData.paymentProcessors[3].Active__c = false;
            update testData.paymentProcessors[3];

            // set last sync date so batch will only run 1x
            Payment_Processor__c processor = [SELECT Id, Last_Sync__c FROM Payment_Processor__c WHERE Id = :testData.paymentProcessors[2].Id];
            Integer daysSinceLastSync = 1;
            processor.Last_Sync__c = Datetime.now().addDays(-1 * daysSinceLastSync);
            update processor;

            // test subject
            CxTxnsImportBatch job = new CxTxnsImportBatch();

            // mock importer
            GenericMock mock = new GenericMock();
            mock.registerResponse('import', job.endDate);
            CxTxnsImporter importer = (CxTxnsImporter) Test.createStub(CxTxnsImporter.class, mock);
            CxTxnsImportBatch.mockImporter = importer;

            Test.startTest();
            Database.executeBatch(job, 1);
            Test.stopTest();

            Assert.areEqual(job.endDate, [SELECT Last_Sync__c FROM Payment_Processor__c WHERE Id = :processor.Id].Last_Sync__c, 
                'Expected Last_Sync__c to be updated for successfully completed processor.');
        }
    }

}