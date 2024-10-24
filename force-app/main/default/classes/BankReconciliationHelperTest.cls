@IsTest
private class BankReconciliationHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetUnclearedItems() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            List<SObject> bw = BankReconciliationHelper.getAllRecords(bankRec.Id);

            Integer totalResult = testData.cashReceipts.size() + testData.cashDisbursements.size() + testData.journalEntryLines.size() + testData.bankDeposits.size();

            System.assertEquals(totalResult, bw.size());
        }
    }

    @IsTest
    static void testRunAutoClearJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.End_Date__c = System.today().addDays(30);     
            TriggerObserver.getInstance().unlockField(Bank_Reconciliation2__c.End_Date__c);       
            update bankRec;
            TriggerObserver.reset();

            testData.cashDisbursements[6].Cleared_Date__c = System.today().addDays(5); 
            List<Cash_Disbursement__C> cds = new List<Cash_Disbursement__c> {testData.cashDisbursements[6]};

            update cds;
            
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(cds);
            System.assertEquals(true, postResults[0].isSuccess);
            EventBusTestUtils.deliverAllEvents();
            
            Test.startTest();
            AbstractLWCHelper.SaveResponse sr = BankReconciliationHelper.runAutoClearJob(bankRec.Id);
            System.assert(sr.isSuccess);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();    
            

            Cash_Disbursement__c cd = [SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :cds[0].Id LIMIT 1];
            System.assertEquals(bankRec.Id, cd.Bank_Reconciliation__c);                        

        }
    }

    @IsTest
    static void testClearItems() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            Test.startTest();
            List<Id> sourceIds = new List<Id>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                sourceIds.add(cr.Id);
            }
            AbstractLWCHelper.SaveResponse sr = BankReconciliationHelper.clearItems(bankRec.Id, sourceIds);

            System.assert(sr.isSuccess);

            for (Cash_Receipt__c cr : [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :sourceIds]) {
                System.assertEquals(bankRec.Id, cr.Bank_Reconciliation__c);
            }

        }
    }

    @IsTest
    static void testUnclearItems() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            Test.startTest();
            List<Id> sourceIds = new List<Id>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                sourceIds.add(cr.Id);
            }
            AbstractLWCHelper.SaveResponse sr = BankReconciliationHelper.clearItems(bankRec.Id, sourceIds);

            System.assert(sr.isSuccess);

            for (Cash_Receipt__c cr : [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :sourceIds]) {
                System.assertEquals(bankRec.Id, cr.Bank_Reconciliation__c);
            }

            AbstractLWCHelper.SaveResponse sr2 = BankReconciliationHelper.unclearItems(bankRec.Id, sourceIds);

            System.assert(sr2.isSuccess);

            for (Cash_Receipt__c cr : [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :sourceIds]) {
                System.assertEquals(NULL, cr.Bank_Reconciliation__c);
            }

        }
    }

    @IsTest
    static void testCreateBankReconciliationReportsFuture() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            Test.startTest();
            List<Id> sourceIds = new List<Id>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                sourceIds.add(cr.Id);
            }
            AbstractLWCHelper.SaveResponse sr = BankReconciliationHelper.clearItems(bankRec.Id, sourceIds);

            System.assert(sr.isSuccess);

            BankReconciliationHelper.createBankReconciliationPDFReport(bankRec.Id);
            Test.stopTest();

            List<ContentVersion> res = DomainUtils.getFilesByLinkedEntityId(bankRec.Id);
            System.assert(!res.isEmpty());
        }
    }

    @IsTest
    static void testCreateBankReconciliationCSVFile() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            Test.startTest();
            List<Id> sourceIds = new List<Id>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                sourceIds.add(cr.Id);
            }
            AbstractLWCHelper.SaveResponse sr = BankReconciliationHelper.clearItems(bankRec.Id, sourceIds);

            System.assert(sr.isSuccess);

            BankReconciliationHelper.createBankReconciliationCSVFile(bankRec.Id);
            Test.stopTest();

            List<ContentVersion> res = DomainUtils.getFilesByLinkedEntityId(bankRec.Id);
            System.assert(!res.isEmpty());
        }
    }

    @IsTest
    static void testGetRecordCount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            Test.startTest();
            Integer recordCount = BankReconciliationHelper.getRecordCount(bankRec.Id);
            Test.stopTest();

            Integer recordCountExpected = [SELECT COUNT() FROM Cash_Receipt__c];
            System.assertEquals(recordCountExpected, recordCount);
        }
    }

    @IsTest
    static void testGetPrevNextLastBankRecs() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashReceipts()
                .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            Test.startTest();
            Map<String, Bank_Reconciliation2__c> prevNextLastBankRecs = BankReconciliationHelper.getPrevNextLastBankRecs(testData.bankReconciliations[0].Id);
            Test.stopTest();

            System.assertEquals(testData.bankReconciliations[0].Id, prevNextLastBankRecs.get('previousBankRec').Id);
            System.assertEquals(testData.bankReconciliations[1].Id, prevNextLastBankRecs.get('nextBankRec').Id);
            System.assertEquals(bankRec.Id, prevNextLastBankRecs.get('lastBankRec').Id);
        }
    }

}