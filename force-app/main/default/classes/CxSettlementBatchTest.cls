@IsTest
public with sharing class CxSettlementBatchTest {
    
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testCxSettlementBatchSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            List<Payment_Activity__c> activities = new List<Payment_Activity__c>();

            Payment_Processor__c pp = testData.paymentProcessors[2];
            pp.last_sync__c = DateTime.newInstance(2020, 4, 20);
            UPDATE pp;
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;
                       
            Accounting_Period__c  period = new Accounting_Period__c(
                Name = '2023-01',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2023, 1, 31),
                Status__c = 'Open'
            );
            
            INSERT period;

            Bank_Deposit__c bankDeposit = new Bank_Deposit__c(
                Deposit_Date__c = Date.newInstance(2023, 1, 2),
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1',
                Ledger_Amount__c = 4,
                Merchant_Batch_Id__c = '1234'
            );

            INSERT bankDeposit;

            cashReceipts.add(new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = Date.newInstance(2023, 1, 1),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '1234',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Payment_Processor__c = pp.Id,
                        Bank_Deposit__c = bankDeposit.Id
                    ));

            cashReceipts.add(new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 40,
                Status__c = 'Approved',
                Receipt_Date__c = Date.newInstance(2023, 1, 1),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '4567',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Payment_Processor__c = pp.Id,
                Bank_Deposit__c = bankDeposit.Id
            ));
            INSERT cashReceipts;
            
            TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Bank_Deposit__c, Cash_Receipt__c.Status__c});
                    
            
			cashReceipts[0].Bank_Deposit__c = bankDeposit.Id;
            cashReceipts[1].Bank_Deposit__c = bankDeposit.Id;
            
            UPDATE cashReceipts;
            
            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[0].Id, Fee__c = 10));

            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[1].Id, Fee__c = 23));

            INSERT activities;

			List<Payment_Activity__C> ac = [SELECT Id, Cash_Receipt__r.Bank_Deposit__c, Cash_Receipt__r.Payment_Processor__r.Type__c  FROM PAYMENT_ACTIVITY__c];
            Map<Id, Bank_Deposit__c> bdsMap = new Map<Id, Bank_Deposit__c>([SELECT Id FROM Bank_Deposit__c]);
            CxTxnsUpdater.ProcessedBankDeposits processedBds = new CxTxnsUpdater.ProcessedBankDeposits();
            processedBds.successfulBDIds = bdsMap.keySet();
            processedBDs.failedBDIds = new Set<Id>();
            processedBDs.processedPPIds = new Set<Id>();
            processedBDs.failedBdProcessorIds = new Set<Id>();
            processedBDs.failedMerchantBatchId = new Set<String>();

            Test.startTest();
            Database.executeBatch(new CxSettlementBatch(processedBds, Datetime.now(), new CxAJRLogger()), 200);
            Test.stopTest();

            Assert.areEqual(1,[SELECT Id FROM Journal_Entry__c].size());
            Assert.areEqual(4,[SELECT Id FROM Journal_Entry_Line__c].size());
            Assert.areEqual('1234',[SELECT Id, Reference__c FROM Journal_Entry__c][0].Reference__c);
        }
    }

    @IsTest
    static void testCxSettlementBatchExistingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createProjects()
        .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            List<Payment_Activity__c> activities = new List<Payment_Activity__c>();

            Payment_Processor__c pp = testData.paymentProcessors[2];
            pp.last_sync__c = DateTime.newInstance(2020, 4, 20);
            UPDATE pp;
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;
                       
            Accounting_Period__c  period = new Accounting_Period__c(
                Name = '2023-01',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2023, 1, 31),
                Status__c = 'Open'
            );
            
            INSERT period;

            Bank_Deposit__c bankDeposit = new Bank_Deposit__c(
                Deposit_Date__c = Date.newInstance(2023, 1, 2),
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1',
                Ledger_Amount__c = 4,
                Merchant_Batch_Id__c = '1234'
            );

            INSERT bankDeposit;

            cashReceipts.add(new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = Date.newInstance(2023, 1, 1),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '1234',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Payment_Processor__c = pp.Id,
                        Bank_Deposit__c = bankDeposit.Id
                    ));

            cashReceipts.add(new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 40,
                Status__c = 'Approved',
                Receipt_Date__c = Date.newInstance(2023, 1, 1),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '4567',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Payment_Processor__c = pp.Id,
                Bank_Deposit__c = bankDeposit.Id
            ));
            INSERT cashReceipts;
            
            TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Bank_Deposit__c, Cash_Receipt__c.Status__c});
                    
            
			cashReceipts[0].Bank_Deposit__c = bankDeposit.Id;
            cashReceipts[1].Bank_Deposit__c = bankDeposit.Id;
            
            UPDATE cashReceipts;
            
            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[0].Id, Fee__c = 10));

            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[1].Id, Fee__c = 23));

            INSERT activities;

			List<Payment_Activity__C> ac = [SELECT Id, Cash_Receipt__r.Bank_Deposit__c, Cash_Receipt__r.Payment_Processor__r.Type__c  FROM PAYMENT_ACTIVITY__c];
            Map<Id, Bank_Deposit__c> bdsMap = new Map<Id, Bank_Deposit__c>([SELECT Id FROM Bank_Deposit__c]);

            CxTxnsUpdater.ProcessedBankDeposits processedBds = new CxTxnsUpdater.ProcessedBankDeposits();
            processedBds.successfulBDIds = bdsMap.keySet();
            processedBDs.failedBDIds = new Set<Id>();
            processedBDs.processedPPIds = new Set<Id>();
            processedBDs.failedBdProcessorIds = new Set<Id>();
            processedBDs.failedMerchantBatchId = new Set<String>();

            Test.startTest();
            Database.executeBatch(new CxSettlementBatch(processedBds, Datetime.now(), new CxAJRLogger()), 200);
            Test.stopTest();

            Assert.areEqual(1,[SELECT Id FROM Journal_Entry__c].size());
            Assert.areEqual(4,[SELECT Id FROM Journal_Entry_Line__c].size());
            Assert.areEqual('1234',[SELECT Id, Reference__c FROM Journal_Entry__c][0].Reference__c);
        }
    }

    @IsTest
    static void testCxSettlementBatchExistingJELUpdates() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().createProjects()
        .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            List<Payment_Activity__c> activities = new List<Payment_Activity__c>();

            Payment_Processor__c pp = testData.paymentProcessors[2];
            pp.last_sync__c = DateTime.newInstance(2020, 4, 20);
            UPDATE pp;
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;
                       
            Accounting_Period__c  period = new Accounting_Period__c(
                Name = '2023-01',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2023, 1, 31),
                Status__c = 'Open'
            );
            
            INSERT period;

            Bank_Deposit__c bankDeposit = new Bank_Deposit__c(
                Deposit_Date__c = Date.newInstance(2023, 1, 2),
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1',
                Merchant_Batch_Id__c = '1234',
                Ledger_Amount__c = 4
            );

            INSERT bankDeposit;

            cashReceipts.add(new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = Date.newInstance(2023, 1, 1),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '1234',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Payment_Processor__c = pp.Id,
                        Bank_Deposit__c = bankDeposit.Id
                    ));

            cashReceipts.add(new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 40,
                Status__c = 'Approved',
                Receipt_Date__c = Date.newInstance(2023, 1, 1),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '4567',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Payment_Processor__c = pp.Id,
                Bank_Deposit__c = bankDeposit.Id
            ));
            INSERT cashReceipts;
            
            TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Bank_Deposit__c, Cash_Receipt__c.Status__c});
                    
            
			cashReceipts[0].Bank_Deposit__c = bankDeposit.Id;
            cashReceipts[1].Bank_Deposit__c = bankDeposit.Id;
            
            UPDATE cashReceipts;
            
            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[0].Id, Fee__c = 10));

            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[1].Id, Fee__c = 23));

            INSERT activities;

			List<Payment_Activity__C> ac = [SELECT Id, Cash_Receipt__r.Bank_Deposit__c, Cash_Receipt__r.Payment_Processor__r.Type__c  FROM PAYMENT_ACTIVITY__c];
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = testData.acctPeriods.get(0).Id,
                    Journal_Date__c = System.today(),
                    Status__c = 'Approved',
                    Reference__c = '1234'
                )
            );
            INSERT journalEntries;
            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Credit__c = 100,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10,
                    Reference__c = 'the reference 1',
                    Description__c = 'the description 1'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Debit__c = 100,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10,
                    Reference__c = 'the reference 2',
                    Description__c = 'the description 2'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Credit__c = 100,
                    GL_Account__c = pp.Merchant_GL_Account__c,
                    Units__c = 10,
                    Reference__c = 'the reference 2',
                    Description__c = 'the description 2'
                )
            );

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Debit__c = 100,
                    GL_Account__c = pp.Merchant_GL_Account__c,
                    Units__c = 10,
                    Reference__c = 'the reference 2',
                    Description__c = 'the description 2'
                )
            );

            INSERT journalEntryLines;

            CxTxnsUpdater.ProcessedBankDeposits processedBds = new CxTxnsUpdater.ProcessedBankDeposits();
            processedBds.successfulBDIds = new Set<Id>{bankDeposit.Id};
            processedBDs.failedBDIds = new Set<Id>();
            processedBDs.processedPPIds = new Set<Id>();
            processedBDs.failedBdProcessorIds = new Set<Id>();
            processedBDs.failedMerchantBatchId = new Set<String>();

            Test.startTest();
            Database.executeBatch(new CxSettlementBatch(processedBds, Datetime.now(), new CxAJRLogger()), 200);
            Test.stopTest();

            //make sure the existing JE has been updated and no new JE is created 
            Assert.areEqual(1,[SELECT Id FROM Journal_Entry__c].size());
            //make sure the existing JEL has been updated and no new JEL are created 
            Assert.areEqual(4,[SELECT Id FROM Journal_Entry_Line__c].size());
            Assert.areNotEqual(journalEntryLines[0].Credit__c, [SELECT Id, Credit__c FROM Journal_Entry_Line__c WHERE Id =:journalEntryLines[0].Id][0].Credit__c);
            Assert.areNotEqual(journalEntryLines[1].Debit__c, [SELECT Id, Debit__c FROM Journal_Entry_Line__c WHERE Id =:journalEntryLines[1].Id][0].Debit__c);
            Assert.areNotEqual(journalEntryLines[2].Credit__c, [SELECT Id, Credit__c FROM Journal_Entry_Line__c WHERE Id =:journalEntryLines[2].Id][0].Credit__c);
        }
    } 
    @IsTest
    static void testCxSettlementBatchFailDueToPAFail() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            List<Payment_Activity__c> activities = new List<Payment_Activity__c>();

            Payment_Processor__c pp = testData.paymentProcessors[2];
            pp.last_sync__c = DateTime.newInstance(2020, 4, 20);
            UPDATE pp;
            Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(Account__c = testData.accounts.get(1).Id, Processor__c = pp.Id, External_Id__c='123');
            INSERT ppc;

            Payment_Method__c pm = new Payment_Method__c(Customer__c = testData.accounts.get(1).Id, Payment_Processor__c = pp.Id, External_Id__c='123',
                                    Last_Four_Digits__c = '4242',Payment_Method_Type__c='Credit Card', Status__c='Active',
                                    Expiration_Month__c='12',Expiration_Year__c='2224',Type__c ='Visa',Default__c=true);
            INSERT pm;
                       
            Accounting_Period__c  period = new Accounting_Period__c(
                Name = '2023-01',
                Start_Date__c = Date.newInstance(2023, 1, 1),
                End_Date__c = Date.newInstance(2023, 1, 31),
                Status__c = 'Open'
            );
            
            INSERT period;

            Bank_Deposit__c bankDeposit = new Bank_Deposit__c(
                Deposit_Date__c = Date.newInstance(2023, 1, 2),
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1',
                Ledger_Amount__c = 4,
                Merchant_Batch_Id__c = '1234'
            );

            INSERT bankDeposit;

            cashReceipts.add(new Cash_Receipt__c(
                        Account__c = testData.accounts.get(1).Id,
                        Amount__c = 400,
                        Status__c = 'Approved',
                        Receipt_Date__c = Date.newInstance(2023, 1, 1),
                        Purpose__c = 'Customer Receipt',
                        Payment_Reference__c = '1234',
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Payment_Processor__c = pp.Id,
                        Bank_Deposit__c = bankDeposit.Id
                    ));

            cashReceipts.add(new Cash_Receipt__c(
                Account__c = testData.accounts.get(1).Id,
                Amount__c = 40,
                Status__c = 'Approved',
                Receipt_Date__c = Date.newInstance(2023, 1, 1),
                Purpose__c = 'Customer Receipt',
                Payment_Reference__c = '4567',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Payment_Processor__c = pp.Id,
                Bank_Deposit__c = bankDeposit.Id
            ));
            INSERT cashReceipts;
            
            TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Bank_Deposit__c, Cash_Receipt__c.Status__c});
                    
            
			cashReceipts[0].Bank_Deposit__c = bankDeposit.Id;
            cashReceipts[1].Bank_Deposit__c = bankDeposit.Id;
            
            UPDATE cashReceipts;
            
            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[0].Id, Fee__c = 10));

            activities.add(new Payment_Activity__c(Type__c='Payment',Status__c='Pending',Amount__c=1,
                                Payment_Method__c = pm.Id,Cash_Receipt__c = cashReceipts[1].Id, Fee__c = 23));

            INSERT activities;

			List<Payment_Activity__C> ac = [SELECT Id, Cash_Receipt__r.Bank_Deposit__c, Cash_Receipt__r.Payment_Processor__r.Type__c  FROM PAYMENT_ACTIVITY__c];
            Map<Id, Bank_Deposit__c> bdsMap = new Map<Id, Bank_Deposit__c>([SELECT Id FROM Bank_Deposit__c]);
            CxTxnsUpdater.ProcessedBankDeposits processedBds = new CxTxnsUpdater.ProcessedBankDeposits();
            processedBds.successfulBDIds = bdsMap.keySet();
            processedBDs.failedBDIds = new Set<Id>();
            processedBDs.processedPPIds = new Set<Id>();
            processedBDs.failedBdProcessorIds = new Set<Id>();
            processedBDs.failedMerchantBatchId = new Set<String>{'1234'};

            Test.startTest();
            Database.executeBatch(new CxSettlementBatch(processedBds, Datetime.now(), new CxAJRLogger()), 200);
            Test.stopTest();

            Assert.areEqual(0,[SELECT Id FROM Journal_Entry__c].size());
            Assert.areEqual(0,[SELECT Id FROM Journal_Entry_Line__c].size());
        }
    }   
}