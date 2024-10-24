@IsTest
public with sharing class AJRLoggerTest {
    
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testConstructorInputs(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            AJRLogger.Config config = null;

            AJRLogger.AJRLoggerException expectedEx;
            try {
                new AJRLogger(config);
            } catch(AJRLogger.AJRLoggerException e) {
                expectedEx = e;
            }
            Assert.isNotNull(expectedEx);

            config = new AJRLogger.Config();
            expectedEx = null;
            try {
                new AJRLogger(config);
            } catch(AJRLogger.AJRLoggerException e) {
                expectedEx = e;
            }
            Assert.isNotNull(expectedEx);
          
            config.jobName = 'Test It';
            expectedEx = null;
            try {
                new AJRLogger(config);
            } catch(AJRLogger.AJRLoggerException e) {
                expectedEx = e;
            }
            Assert.isNotNull(expectedEx);

            config.jobName = null;
            config.reportName = 'Test It Job';
            expectedEx = null;
            try {
                new AJRLogger(config);
            } catch(AJRLogger.AJRLoggerException e) {
                expectedEx = e;
            }
            Assert.isNotNull(expectedEx);
        }
    }

    @IsTest
    static void testLogErrorAndSave(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            AJRLogger logger = getTestLogger();
            logger.logError(testData.paymentProcessors[2].Id,'Test Payment Processor Error 1');
            logger.logError(testData.paymentProcessors[3].Id,'Test Payment Processor Error 2');
            logger.save();

            List<Automated_Job_Results__c> ajrs = [SELECT Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(2, ajrs[0].Processed__c);
            Assert.areEqual(2, ajrs[0].Failed__c);
            Assert.areEqual(0, ajrs[0].Succeeded__c);
            Assert.areEqual(2, [SELECT COUNT() FROM Task]);
        }
    }

    @IsTest
    static void testLogErrorAndSaveDuplicate(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            AJRLogger logger = getTestLogger();
            logger.logError(testData.paymentProcessors[2].Id,'Test Payment Processor Error 1');
            logger.logError(testData.paymentProcessors[2].Id,'Test Payment Processor Error 2');
            logger.save();

            List<Automated_Job_Results__c> ajrs = [SELECT Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(1, ajrs[0].Processed__c);
            Assert.areEqual(1, ajrs[0].Failed__c);
            Assert.areEqual(0, ajrs[0].Succeeded__c);
            Assert.areEqual(1, [SELECT COUNT() FROM Task]);
        }
    }

    @IsTest
    static void testLogErrorAndWriteErrorWithLogSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createBillings();

        System.runAs(testData.users.get(1)) {
            AJRLogger logger = getTestLogger();

            logger.logError(testData.paymentProcessors[1].Id, 'Test Payment Processor Error 1');
            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.save();

            List<Automated_Job_Results__c> ajrs = [SELECT Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];

            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(2, ajrs[0].Processed__c);
            Assert.areEqual(1, ajrs[0].Succeeded__c);
            Assert.areEqual(1, ajrs[0].Failed__c);
            Assert.areEqual(1, [SELECT COUNT() FROM Task]);
        }
    }

    @IsTest
    static void testSaveMultipleTimes(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            AJRLogger logger = getTestLogger();

            String firstError = 'Error One';
            logger.logError(testData.paymentProcessors[2].Id, firstError);
            logger.save();

            String secondError = 'Error Two';
            logger.logError(testData.paymentProcessors[2].Id, secondError);
            logger.save();

            logger.logSuccess(testData.paymentProcessors[3].Id);
            logger.save();

            List<Automated_Job_Results__c> ajrs = [SELECT Id, Processed__c, Succeeded__c, Failed__c, Notes__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(2, ajrs[0].Processed__c);
            Assert.areEqual(1, ajrs[0].Succeeded__c);
            Assert.areEqual(1, ajrs[0].Failed__c);
            Assert.isFalse(String.isBlank(ajrs[0].Notes__c));

            List<Task> tasks = [SELECT Id, WhatId, Description FROM Task];
            Assert.areEqual(1, tasks.size());
            Assert.areEqual(testData.paymentProcessors[2].Id, tasks[0].WhatId);
            Assert.isTrue(tasks[0].Description.contains(firstError));
            Assert.isTrue(tasks[0].Description.contains(secondError));
        }
    }

    @IsTest
    static void testLogSuccessShouldOnlyLogOncePerRecord(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            AJRLogger logger = getTestLogger();

            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.save();

            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.save();

            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.save();

            List<Automated_Job_Results__c> ajrs = [SELECT Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(1, ajrs[0].Processed__c);
            Assert.areEqual(1, ajrs[0].Succeeded__c);
            Assert.areEqual(0, ajrs[0].Failed__c);

            List<Task> tasks = [SELECT Id FROM Task];
            Assert.areEqual(0, tasks.size());
        }
    }

    @IsTest
    static void testSwitchSucceededToFailed(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            AJRLogger logger = getTestLogger();

            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.logError(testData.paymentProcessors[2].Id, 'Error Message');
            logger.save();

            List<Automated_Job_Results__c> ajrs = [SELECT Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(1, ajrs[0].Processed__c);
            Assert.areEqual(0, ajrs[0].Succeeded__c);
            Assert.areEqual(1, ajrs[0].Failed__c);
        }
    }

    @IsTest
    static void testSwitchFailedToSucceededNotAllowed(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            AJRLogger logger = getTestLogger();

            logger.logError(testData.paymentProcessors[2].Id, 'Error Message');
            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.save();

            List<Automated_Job_Results__c> ajrs = [SELECT Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(1, ajrs[0].Processed__c);
            Assert.areEqual(0, ajrs[0].Succeeded__c);
            Assert.areEqual(1, ajrs[0].Failed__c);
        }
    }

    @IsTest
    static void testTrimTaskDescription(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            String message = '';
            for (Integer i=0; i<32005; i++) {
                message += 'x';
            }
            Id processor = testData.paymentProcessors[2].Id;
            
            AJRLogger logger = getTestLogger();

            logger.logError(processor, message);
            logger.save();

            List<Task> tasks = [SELECT Id, Description FROM Task WHERE WhatId = :processor];
            Assert.areEqual(1, tasks.size());
            Assert.areEqual(32000, tasks[0].Description.length());
        }
    }

    public static AJRLogger getTestLogger() {
        AJRLogger.Config config = new AJRLogger.Config();
        config.jobName = 'Test It';
        config.reportName = 'Test It Job';
        return new AJRLogger(config);
    }
}