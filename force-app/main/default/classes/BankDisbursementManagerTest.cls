@IsTest
public with sharing class BankDisbursementManagerTest {
	
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest 
    public static void testGetCDandJELUnassociatedRecordsForAll(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec1;

            Cash_Disbursement__c cashDisRec2 = testData.cashDisbursements[1];
            cashDisRec2.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec2.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec2;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{cashDisRec1, cashDisRec2});
            
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Debit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine1;

            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','All','','',1000,1000);
            List<BankDisbursementManager.ResultRecordsWrapper> listOfUnassociatedRecs = BankDisbursementManager.getCDandJELRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'UnassociatedRecords');
            
            System.assertEquals(4,listOfUnassociatedRecs.size());
            Test.stopTest();
        } 
    }
    
    @IsTest 
    public static void testGetCDandJELAssociatedRecordsForAll(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            cashDisRec1.Bank_Disbursement__c = bankDisRec.Id;
            update cashDisRec1;
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{cashDisRec1});

            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Debit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine1;
            
            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','All','','',1000,1000);
            List<BankDisbursementManager.ResultRecordsWrapper> listOfUnassociatedRecs = BankDisbursementManager.getCDandJELRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'AssociatedRecords');
            
            System.assertEquals(3,listOfUnassociatedRecs.size());
            Test.stopTest();
        } 
    }
	
    @IsTest 
    public static void testGetCDandJELUnassociatedRecordsForCD(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec1;

            Cash_Disbursement__c cashDisRec2 = testData.cashDisbursements[1];
            cashDisRec2.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec2.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec2;
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{cashDisRec1, cashDisRec2});
			
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Debit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine1;
            
            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','Cash Disbursement','','',1000,1000);
            List<BankDisbursementManager.ResultRecordsWrapper> listOfUnassociatedRecs = BankDisbursementManager.getCDandJELRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'UnassociatedRecords');
            
            System.assertEquals(2,listOfUnassociatedRecs.size());
            Test.stopTest();
        } 
    }
    
    @IsTest 
    public static void testGetCDandJELAssociatedRecordsForCD(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            cashDisRec1.Bank_Disbursement__c = bankDisRec.Id;
            update cashDisRec1;
			
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{cashDisRec1});
            
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Debit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine1;
            
            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','Cash Disbursement','','',1000,1000);
            List<BankDisbursementManager.ResultRecordsWrapper> listOfUnassociatedRecs = BankDisbursementManager.getCDandJELRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'AssociatedRecords');
            
            System.assertEquals(1,listOfUnassociatedRecs.size());
            Test.stopTest();
        } 
    }

    @IsTest 
    public static void testGetCDandJELUnassociatedRecordsForJEL(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec1;

            Cash_Disbursement__c cashDisRec2 = testData.cashDisbursements[1];
            cashDisRec2.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec2.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec2;
			
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Debit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine1;

            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','Journal Entry Line','','',1000,1000);
            List<BankDisbursementManager.ResultRecordsWrapper> listOfUnassociatedRecs = BankDisbursementManager.getCDandJELRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'UnassociatedRecords');
            
            System.assertEquals(2,listOfUnassociatedRecs.size());
            Test.stopTest();
        } 
    }
    
    @IsTest 
    public static void testGetCDandJELAssociatedRecordsForJEL(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            cashDisRec1.Bank_Disbursement__c = bankDisRec.Id;
            update cashDisRec1;
			
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine;
            jEntryLine.Bank_Disbursement__c = bankDisRec.Id;
            update jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Debit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine1;
            jEntryLine1.Bank_Disbursement__c = bankDisRec.Id;
            update jEntryLine1;
            
            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','Journal Entry Line','','',1000,1000);
            List<BankDisbursementManager.ResultRecordsWrapper> listOfUnassociatedRecs = BankDisbursementManager.getCDandJELRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'AssociatedRecords');
            
            System.assertEquals(2,listOfUnassociatedRecs.size());
            Test.stopTest();
        } 
    }
    
    @IsTest 
    public static void testgetTotalCDRecords(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements();
        
        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            cashDisRec1.Bank_Disbursement__c = bankDisRec.Id;
            update cashDisRec1;
            
            Cash_Disbursement__c cashDisRec2 = testData.cashDisbursements[1];
            cashDisRec2.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec2.Ledger__c = testData.ledgers[0].Id;
            cashDisRec2.Bank_Disbursement__c = bankDisRec.Id;
            update cashDisRec2;
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{cashDisRec1, cashDisRec2});
			
            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','Cash Disbursement','','',1000,1000);
            Integer associatedCDs = BankDisbursementManager.getTotalCDRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'AssociatedRecords');
            
            System.assertEquals(2,associatedCDs);
            Test.stopTest();
        } 
    }
    
    @IsTest 
    public static void testgetTotalJELRecords(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createLedgerWithPaymentEnabled()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            bankDisRec.Ledger__c = testData.ledgers[0].Id;
            update bankDisRec;
			
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Debit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine1;
            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.FiltersWrapper filters = new BankDisbursementManager.FiltersWrapper('2024-07-09','2024-08-16','Journal Entry Line','','',1000,1000);
            Integer associatedJELs = BankDisbursementManager.getTotalJELRecords(testData.bankDisbursements[0].Id, JSON.serialize(filters), 'AssociatedRecords');
            
            System.assertEquals(2,associatedJELs);
            Test.stopTest();
        } 
    }
    
    @IsTest 
    public static void testupdateCDorJELrecordsToAssociate(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec1;

            Cash_Disbursement__c cashDisRec2 = testData.cashDisbursements[1];
            cashDisRec2.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec2.Ledger__c = testData.ledgers[0].Id;
            update cashDisRec2;
			
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine;

            BankDisbursementManager.updateCDorJELrecords(new List<Id>{cashDisRec1.Id,cashDisRec2.Id, jEntryLine.Id},testData.bankDisbursements[0].Id, Label.COMMON_UNASSOCIATE);
            
            List<Cash_Disbursement__c> listOfAssociatedCDs = [SELECT Id FROM CASH_DISBURSEMENT__C WHERE Bank_Disbursement__c =: bankDisRec.Id];
            System.assertEquals(2,listOfAssociatedCDs.size());
            
            List<Journal_Entry_Line__c> listOfAssociatedJELs = [SELECT Id FROM Journal_Entry_Line__c WHERE Bank_Disbursement__c =: bankDisRec.Id];
            System.assertEquals(1,listOfAssociatedJELs.size());
            Test.stopTest();
        } 
    }
    
	@IsTest 
    public static void testupdateCDorJELrecordsToUnAssociate(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createLedgerWithPaymentEnabled()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(); 

        System.runAs(testData.users[1]) {
			Test.startTest();
            Bank_Disbursement__c bankDisRec = testData.bankDisbursements[0];
            bankDisRec.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            update bankDisRec;

            Cash_Disbursement__c cashDisRec1 = testData.cashDisbursements[0];
            cashDisRec1.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec1.Ledger__c = testData.ledgers[0].Id;
            cashDisRec1.Bank_Disbursement__c = bankDisRec.Id;
            update cashDisRec1;

            Cash_Disbursement__c cashDisRec2 = testData.cashDisbursements[1];
            cashDisRec2.Disbursement_Date__c = Date.newInstance(2024, 07, 14);
            cashDisRec1.Bank_Account__c = testData.glAccounts[0].Id;
            cashDisRec2.Ledger__c = testData.ledgers[0].Id;
            cashDisRec2.Bank_Disbursement__c = bankDisRec.Id;
            update cashDisRec2;
			
            Journal_Entry__c journalEntryRec = testData.journalEntries[0];
            journalEntryRec.Ledger__c = testData.ledgers[0].Id;
            update journalEntryRec;
            
            Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14),
                Bank_Disbursement__c = bankDisRec.Id
            );
                
            insert jEntryLine;
            
            Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = journalEntryRec.Id,
                Credit__c = 200,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'ref 3',
                Account__c = testData.accounts[0].Id,
                Date__c = Date.newInstance(2024, 07, 14)
            );
                
            insert jEntryLine1;
            
            AbstractPostHandler postHandlerForJE = new JournalEntryPostHandler();
            List<PostResult> results = postHandlerForJE.post(new List<Journal_Entry__c>{journalEntryRec});

            BankDisbursementManager.updateCDorJELrecords(new List<Id>{cashDisRec1.Id,cashDisRec2.Id, jEntryLine.Id},testData.bankDisbursements[0].Id, Label.COMMON_ASSOCIATE);
            
            List<Cash_Disbursement__c> listOfAssociatedCDs = [SELECT Id FROM CASH_DISBURSEMENT__C WHERE Bank_Disbursement__c = NULL];
            System.assertEquals(9,listOfAssociatedCDs.size());
            
            List<Journal_Entry_Line__c> listOfAssociatedJELs = [SELECT Id FROM Journal_Entry_Line__c WHERE Bank_Disbursement__c = NULL];
            System.assertEquals(8,listOfAssociatedJELs.size());
            Test.stopTest();
        } 
    }
}