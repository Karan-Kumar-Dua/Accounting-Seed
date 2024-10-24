@IsTest
public with sharing class CxAJRLoggerTest {
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }
    @IsTest
    static void testLogErrorAndWriteError(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();
            logger.logError(testData.paymentProcessors[2].Id,'Test Cardknox Processor Error 1');
            logger.logError(testData.paymentProcessors[3].Id,'Test Cardknox Processor Error 2');
            logger.write();

            CxAJRLogger.Config config = logger.getConfig();

            Assert.areNotEqual(null,config.ajr);
            Assert.areEqual(2,config.taskIdsByWhatId.keySet().size());
            Assert.areEqual(1,[SELECT ID,Name FROM Automated_Job_Results__c WHERE Id = :config.ajr].size());
            Assert.areEqual(2,[SELECT ID FROM Task WHERE Id IN :config.taskIdsByWhatId.values()].size());
        }
    }
    @IsTest
    static void testLogErrorAndWriteErrorOnSameProcessor(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();
            logger.logError(testData.paymentProcessors[2].Id,'Test Cardknox Processor Error 1');
            logger.logError(testData.paymentProcessors[2].Id,'Test Cardknox Processor Error 2');
            logger.write();

            CxAJRLogger.Config config = logger.getConfig();

            Assert.areNotEqual(null,config.ajr);
            Assert.areEqual(1,config.taskIdsByWhatId.keySet().size());
            Assert.areEqual(1,[SELECT ID,Name FROM Automated_Job_Results__c WHERE Id = :config.ajr].size());
            Assert.areEqual(1,[SELECT ID FROM Task WHERE Id IN :config.taskIdsByWhatId.values()].size());
        }
    }
    @IsTest
    static void testLogErrorAndWriteErrorWithPPFailure(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createBillings();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();

            try{
                INSERT new Payment_Processor__c();
            }catch(Exception ex){
                logger.logError(testData.paymentProcessors[1].Id,ex.getMessage());
            }
            logger.write();

            CxAJRLogger.Config config = logger.getConfig();

            Assert.areNotEqual(null,config.ajr);
            Assert.areEqual(1,config.taskIdsByWhatId.keySet().size());
            Assert.areEqual(1,[SELECT ID,Name FROM Automated_Job_Results__c WHERE Id = :config.ajr].size());
            Assert.areEqual(1,[SELECT ID FROM Task WHERE Id IN :config.taskIdsByWhatId.values()].size());
        }
    }
    @IsTest
    static void testLogErrorAndWriteErrorWithLogSuccess(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createBillings();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();

            try{
                INSERT new Payment_Processor__c();
            }catch(Exception ex){
                logger.logError(testData.paymentProcessors[1].Id,ex.getMessage());
            }
            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.write();

            CxAJRLogger.Config config = logger.getConfig();

            Assert.areNotEqual(null,config.ajr);
            Assert.areEqual(1,config.taskIdsByWhatId.keySet().size());
            Assert.areEqual(1,[SELECT ID,Name FROM Automated_Job_Results__c WHERE Id = :config.ajr].size());
            Assert.areEqual(1,[SELECT ID FROM Task WHERE Id IN :config.taskIdsByWhatId.values()].size());
            Assert.areEqual(2,[SELECT ID,Processed__c FROM Automated_Job_Results__c WHERE Id = :config.ajr][0].Processed__c);
            Assert.areEqual(1,[SELECT ID,Succeeded__c FROM Automated_Job_Results__c WHERE Id = :config.ajr][0].Succeeded__c);
        }
    }
    @IsTest
    static void testLogErrorAndWriteErrorWithConfig(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createBillings();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();

            try{
                INSERT new Payment_Processor__c();
            }catch(Exception ex){
                logger.logError(testData.paymentProcessors[1].Id,ex.getMessage());
            }
            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.write();

            CxAJRLogger.Config config = logger.getConfig();
            logger = new CxAJRLogger(config);
            
            Assert.areNotEqual(null,config.ajr);
            Assert.areEqual(1,config.taskIdsByWhatId.keySet().size());
            Assert.areEqual(1,[SELECT ID,Name FROM Automated_Job_Results__c WHERE Id = :config.ajr].size());
            Assert.areEqual(1,[SELECT ID FROM Task WHERE Id IN :config.taskIdsByWhatId.values()].size());
            Assert.areEqual(2,[SELECT ID,Processed__c FROM Automated_Job_Results__c WHERE Id = :config.ajr][0].Processed__c);
            Assert.areEqual(1,[SELECT ID,Succeeded__c FROM Automated_Job_Results__c WHERE Id = :config.ajr][0].Succeeded__c);
        }
    }

    @IsTest
    static void testWriteMultipleTimes(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();
            String firstError = 'Error One';
            logger.logError(testData.paymentProcessors[2].Id, firstError);
            logger.write();

            String secondError = 'Error Two';
            logger.logError(testData.paymentProcessors[2].Id, secondError);
            logger.write();

            logger.logSuccess(testData.paymentProcessors[3].Id);
            logger.write();

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
    static void testRestoreFromConfig(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();
            String firstError = 'Error One';
            logger.logError(testData.paymentProcessors[2].Id, firstError);
            logger.write();

            CxAJRLogger.Config config = logger.getConfig();
            logger = new CxAJRLogger(config); // Restore from config

            String secondError = 'Error Two';
            logger.logError(testData.paymentProcessors[2].Id, secondError);
            logger.write();

            List<Automated_Job_Results__c> ajrs = [SELECT Id, Processed__c, Succeeded__c, Failed__c, Notes__c FROM Automated_Job_Results__c];
            Assert.areEqual(1, ajrs.size());
            Assert.areEqual(1, ajrs[0].Processed__c);
            Assert.areEqual(0, ajrs[0].Succeeded__c);
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
    static void testLogSuccessShouldOnlyLogOncePerProcessor(){
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            CxAJRLogger logger = new CxAJRLogger();
            String firstError = 'Error One';
            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.write();

            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.write();

            CxAJRLogger.Config config = logger.getConfig();
            logger = new CxAJRLogger(config); // restore from config

            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.write();

            List<Automated_Job_Results__c> ajrs = [SELECT Id, Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
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
            CxAJRLogger logger = new CxAJRLogger();
            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.logError(testData.paymentProcessors[2].Id, 'Error Message');
            logger.write();

            List<Automated_Job_Results__c> ajrs = [SELECT Id, Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
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
            CxAJRLogger logger = new CxAJRLogger();
            logger.logError(testData.paymentProcessors[2].Id, 'Error Message');
            logger.logSuccess(testData.paymentProcessors[2].Id);
            logger.write();

            List<Automated_Job_Results__c> ajrs = [SELECT Id, Processed__c, Succeeded__c, Failed__c FROM Automated_Job_Results__c];
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
            CxAJRLogger logger = new CxAJRLogger();
            logger.logError(processor, message);
            logger.write();

            List<Task> tasks = [SELECT Id, Description FROM Task WHERE WhatId = :processor];
            Assert.areEqual(1, tasks.size());
            Assert.areEqual(32000, tasks[0].Description.length());
        }
    }
}