@isTest
public with sharing class AutomatedEmailBillingSchedulerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testStartAutomatedEmailBillingScheduler() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);

        System.runAs(testData.users[1]) {
            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Balance Due Only';
            update testData.billingFormats[0];

            Billing__c billToPost = [
                SELECT Id, 
                       Due_Date2__c,
                       Billing_Contact__c,
                       Status__c
                FROM Billing__c 
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due Only' 
                LIMIT 1
            ];

            billToPost.Billing_Contact__c = testData.contacts[0].Id;
            billToPost.Due_Date2__c = System.today() - 1;
            
            update billToPost;

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<SObject>{billToPost});

            String CRON_EXPRESSION = '0 13 * * * ?';
            
            String jobId = AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                CRON_EXPRESSION, 'Automated Email Billing Job', TestDataSuite.salesforceUrl
            );
            Test.stopTest();

            System.assertEquals(
                1, 
                DomainUtils.getCronTriggerByJobName(new Set<String> {'Automated Email Billing Job'}).size()
            );

            System.assertEquals(
                2,
                bills.size()
            );

            for(Billing__c testBilling : bills.values()){
                testBilling.Date__c = system.today() + 1;
            }
            update bills.values();

            Map<Id, Billing__c> updatedBills = DomainUtils.getAutomatedEmailBillings();
            System.assertEquals(
                0,
                updatedBills.size()
            );

        }
    }

    @IsTest
    public static void testAutomatedEmailBillingScheduler_BalanceDueOnly() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);

        System.runAs(testData.users[1]) {
            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Balance Due Only';
            update testData.billingFormats[0];

            list<Billing__c> billsToPost = [
                SELECT Id,
                    Due_Date2__c,
                    Billing_Contact__c,
                    Status__c
                FROM Billing__c
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due Only'
            ];

            for(Billing__c b : billsToPost){
                b.Billing_Contact__c = testData.contacts[0].Id;
            }
            update billsToPost;

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            String CRON_EXPRESSION = '0 13 * * * ?';

            String jobId = AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                CRON_EXPRESSION, 'Automated Email Billing Job', TestDataSuite.salesforceUrl
            );
            Test.stopTest();

            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String> {'Automated Email Billing Job'}).size());
            System.assertEquals(2,bills.size());

            for(Billing__c testBilling : bills.values()){
                testBilling.Date__c = system.today() + 1;
                system.assert(testBilling.Balance__c > 0);
            }
            update bills.values();

            Map<Id, Billing__c> updatedBills = DomainUtils.getAutomatedEmailBillings();
            System.assertEquals(0,updatedBills.size());
        }
    }

    @IsTest
    public static void testAutomatedEmailBillingScheduler_ZeroBalanceOnly() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);

        System.runAs(testData.users[1]) {
            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Zero Balance Only';
            update testData.billingFormats[0];

            list<Billing__c> billsToPost = [
                SELECT Id,
                    Due_Date2__c,
                    Billing_Contact__c,
                    Status__c
                FROM Billing__c
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'Zero Balance Only'
            ];

            for(Billing__c b : billsToPost){
                b.Billing_Contact__c = testData.contacts[0].Id;
            }
            update billsToPost;

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            String CRON_EXPRESSION = '0 13 * * * ?';

            String jobId = AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                CRON_EXPRESSION, 'Automated Email Billing Job', TestDataSuite.salesforceUrl
            );
            Test.stopTest();

            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String> {'Automated Email Billing Job'}).size());
            System.assertEquals(1,bills.size());

            for(Billing__c testBilling : bills.values()){
                testBilling.Date__c = system.today() + 1;
                system.assert(testBilling.Balance__c == 0);
            }
            update bills.values();

            Map<Id, Billing__c> updatedBills = DomainUtils.getAutomatedEmailBillings();
            System.assertEquals(0,updatedBills.size());
        }
    }

    @IsTest
    public static void testAutomatedEmailBillingScheduler_BalanceDueorZeroBalance() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);

        System.runAs(testData.users[1]) {
            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Balance Due or Zero Balance';
            update testData.billingFormats[0];

            list<Billing__c> billings = [
                SELECT Id,
                    Due_Date2__c,
                    Billing_Contact__c,
                    Status__c
                FROM Billing__c
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due or Zero Balance'
            ];

            for(Billing__c b : billings){
                b.Billing_Contact__c = testData.contacts[0].Id;
            }
            update billings;

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            String CRON_EXPRESSION = '0 13 * * * ?';
            String jobId = AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                CRON_EXPRESSION, 'Automated Email Billing Job', TestDataSuite.salesforceUrl
            );
            Test.stopTest();

            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String> {'Automated Email Billing Job'}).size());
            System.assertEquals(3, bills.size());
            
            for(Billing__c testBilling : bills.values()){
                testBilling.Date__c = system.today() + 1;
            }
            update bills.values();
            Map<Id, Billing__c> updatedBills = DomainUtils.getAutomatedEmailBillings();

            System.assertEquals(0,updatedBills.size());
        }
    }

    @IsTest
    public static void testAutomatedEmailBillingScheduler_BalanceDueorCreditMemo() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);

        System.runAs(testData.users[1]) {
            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Balance Due or Credit Memo Balance';
            update testData.billingFormats[0];
            list<Billing__c> billsToPost = [
                SELECT Id,
                    Due_Date2__c,
                    Billing_Contact__c,
                    Status__c
                FROM Billing__c
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due or Credit Memo Balance'
            ];

            for(Billing__c b : billsToPost){
                b.Billing_Contact__c = testData.contacts[0].Id;
            }
            update billsToPost;

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            String CRON_EXPRESSION = '0 13 * * * ?';
            String jobId = AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                CRON_EXPRESSION, 'Automated Email Billing Job', TestDataSuite.salesforceUrl
            );
            Test.stopTest();

            System.assertEquals(1, DomainUtils.getCronTriggerByJobName(new Set<String> {'Automated Email Billing Job'}).size() );
            System.assertEquals(4,bills.size());

            for(Billing__c testBilling : bills.values()){
                testBilling.Date__c = system.today() + 1;
            }
            update bills.values();

            Map<Id, Billing__c> updatedBills = DomainUtils.getAutomatedEmailBillings();
            System.assertEquals(0,updatedBills.size());
        }
    }

    @IsTest
    public static void testAutomatedEmailBillingScheduler_Always() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);

        System.runAs(testData.users[1]) {

            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Balance Due Only';
            update testData.billingFormats[0];

            Billing__c billToPost = [
                SELECT Id, 
                       Due_Date2__c,
                       Billing_Contact__c,
                       Status__c
                FROM Billing__c 
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due Only' 
                LIMIT 1
            ];

            billToPost.Billing_Contact__c = testData.contacts[0].Id;
            billToPost.Due_Date2__c = System.today() - 1;
            
            update billToPost;

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<SObject>{billToPost});

            String CRON_EXPRESSION = '0 13 * * * ?';
            
            String jobId = AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                CRON_EXPRESSION, 'Automated Email Billing Job', TestDataSuite.salesforceUrl
            );
            Test.stopTest();

            System.assertEquals(
                1, 
                DomainUtils.getCronTriggerByJobName(new Set<String> {'Automated Email Billing Job'}).size()
            );

            System.assertEquals(
                2,
                bills.size()
            );

            for(Billing__c testBilling : bills.values()){
                testBilling.Date__c = system.today() + 1;
            }
            update bills.values();

            Map<Id, Billing__c> updatedBills = DomainUtils.getAutomatedEmailBillings();
            System.assertEquals(
                0,
                updatedBills.size()
            );

        }
    }

    @IsTest
    public static void testAutomatedEmailBillingScheduler_NoDelivery() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'No Delivery';
            update testData.billingFormats[0];

            Billing__c billToPost = [
                SELECT Id, 
                       Due_Date2__c,
                       Billing_Contact__c,
                       Status__c
                FROM Billing__c 
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'No Delivery' 
                LIMIT 1
            ];

            billToPost.Billing_Contact__c = testData.contacts[0].Id;
            billToPost.Due_Date2__c = System.today() - 1;
            
            update billToPost;

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<SObject>{billToPost});

            String CRON_EXPRESSION = '0 13 * * * ?';
            
            String jobId = AutomatedEmailBillingScheduler.startAutomatedEmailBillingScheduler(
                CRON_EXPRESSION, 'Automated Email Billing Job', TestDataSuite.salesforceUrl
            );
            Test.stopTest();

            System.assertEquals(
                1, 
                DomainUtils.getCronTriggerByJobName(new Set<String> {'Automated Email Billing Job'}).size()
            );

            System.assertEquals(
                0,
                bills.size()
            );
        }
    }

    @isTest
    public static void testStatementPDFSaveMailBatch() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings(true);
        System.runAs(testData.users[1]) {
            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Balance Due Only';
            update testData.billingFormats[0];

            Billing__c billToPost = [
                SELECT Id,
                       Due_Date2__c,
                       Billing_Contact__c,
                       Status__c
                FROM Billing__c 
                WHERE Billing_Format__r.Automated_Email_Delivery2__c = 'Balance Due Only' 
                LIMIT 1
            ];

            billToPost.Billing_Contact__c = testData.contacts[0].Id;
            billToPost.Due_Date2__c = System.today() - 1;
            
            update billToPost; 

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();

            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<SObject>{billToPost});

            update billToPost; 

            StatementPDFSaveMailBatch pdfStatement = new StatementPDFSaveMailBatch(
                new List<Id>{billToPost.Id}, true, '', AbstractStatementManager.StatementBase.BILLING
            );
            Database.executeBatch(pdfStatement, 100);
            Test.stopTest();

            System.assertEquals(
                'Sent',
                [
                    SELECT PDF_Email_Status__c
                    FROM Billing__c
                    WHERE Id = :billToPost.Id
                ].PDF_Email_Status__c
            );

            System.assertEquals(
                2,
                bills.size()
            );
            
            for(Billing__c testBilling : bills.values()){
                testBilling.Date__c = system.today() + 1;
            }
            update bills.values();

            Map<Id, Billing__c> updatedBills = DomainUtils.getAutomatedEmailBillings();
            System.assertEquals(
                0,
                updatedBills.size()
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Automated Email Billing', ajr.Schedule_Job_Type__c);
            System.assertEquals(1, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }

    }

    @isTest
    public static void testStatementPDFSaveMailBatchCreditMemoType() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.contacts[0].Email = 'testmail@gmail.com';
            update testData.contacts[0];

            testData.billingFormats[0].Automated_Email_Delivery2__c = 'Balance Due Only';
            update testData.billingFormats[0];

            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 25,
                Rate__c = -1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert billingLine;

            Test.stopTest();

            Map<Id, Billing__c> bills = DomainUtils.getAutomatedEmailBillings();
            List<Id> billsKeySet = new List<Id> (bills.keySet());

            System.assertEquals(
                true,
                billsKeySet.isEmpty()
            );

            System.assertEquals(
                0,
                bills.size()
            );
        }

    }

}