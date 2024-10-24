@IsTest
public with sharing class CxSettlerTest {
    
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testCreateJournalEntryWithLinesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.01;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(activity.Amount__c + activity.Fee__c, jes[0].Total_Credits__c);
            Assert.areEqual(activity.Amount__c + activity.Fee__c, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(4, jes[0].Line_Count__c);
            Assert.areEqual(String.format(Label.MERCHANT_DOWNLOAD_JE_NAME, new List<String>{ String.valueOf(deposit.Deposit_Date__c) }), jes[0].Name);
            
            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, activity.Amount__c, activity.Fee__c);

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));

            // bank deposit assertions
            List<Bank_Deposit__c> bds = [SELECT Merchant_Funds_Transfer__c FROM Bank_Deposit__c WHERE Id = :deposit.Id];
            Assert.areEqual(1, bds.size());
            Assert.areEqual(jes[0].Id, bds[0].Merchant_Funds_Transfer__c);
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesNoDuplicates() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.01;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Set<Id> successfulJournalEntryIds = result.successfulJournalEntryIds;
            result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            successfulJournalEntryIds.addAll(result.successfulJournalEntryIds);
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(0, result.succeedRecords); // JE already created
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(successfulJournalEntryIds);

            Assert.areEqual(1, jes.size()); // expect 1 JE created during first run
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(activity.Amount__c + activity.Fee__c, jes[0].Total_Credits__c);
            Assert.areEqual(activity.Amount__c + activity.Fee__c, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(4, jes[0].Line_Count__c);
            
            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, activity.Amount__c, activity.Fee__c);

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];
            // close the period
            period.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            // skip running resource intense close actions
            AccountingPeriodActions.isFirstRun = false;
            update period;
            AccountingPeriodActions.isFirstRun = true;

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.01;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(activity.Amount__c + activity.Fee__c, jes[0].Total_Credits__c);
            Assert.areEqual(activity.Amount__c + activity.Fee__c, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(4, jes[0].Line_Count__c);
            
            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, activity.Amount__c, activity.Fee__c);

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesMultiPayment() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 202.02;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            List<Cash_Receipt__c> receipts = new List<Cash_Receipt__c>{testData.cashReceipts[0], testData.cashReceipts[1]};
           
            receipts[0].Payment_Reference__c = '987654321';
            receipts[0].Payment_Processor__c = processor.Id;
            receipts[0].Account__c = customer.Account__c;
            receipts[0].Amount__c = 101.01;
            receipts[0].Bank_Deposit__c = deposit.Id;
            receipts[0].Ledger__c = deposit.Ledger__c;
            receipts[0].Receipt_Date__c = period.Start_Date__c;
            receipts[0].Accounting_Period__c = period.Id;

            receipts[1].Payment_Reference__c =  '876543219';
            receipts[1].Payment_Processor__c =  receipts[0].Payment_Processor__c;
            receipts[1].Account__c =            receipts[0].Account__c;
            receipts[1].Amount__c =             receipts[0].Amount__c;
            receipts[1].Bank_Deposit__c =       receipts[0].Bank_Deposit__c;
            receipts[1].Ledger__c =             receipts[0].Ledger__c;
            receipts[1].Receipt_Date__c =       receipts[0].Receipt_Date__c;
            receipts[1].Accounting_Period__c =  receipts[0].Accounting_Period__c;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipts;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>{
                getPaymentActivity(paymentMethod, receipts[0], merchantBatchId),
                getPaymentActivity(paymentMethod, receipts[1], merchantBatchId)
            };
            insert activities;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Decimal totalAmount = activities[0].Amount__c + activities[1].Amount__c;
            Decimal totalFee = activities[0].Fee__c + activities[1].Fee__c;
            Decimal total = totalAmount + totalFee;

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(total, jes[0].Total_Credits__c);
            Assert.areEqual(total, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(4, jes[0].Line_Count__c);
            
            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, totalAmount, totalFee);

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesMultiDeposit() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            List<Bank_Deposit__c> deposits = new List<Bank_Deposit__c>{testData.bankDeposits[0], testData.bankDeposits[1]};
            
            deposits[0].Merchant_Batch_Id__c = '1234567890';
            deposits[0].Bank_Account__c = processor.Bank_GL_Account__c;
            deposits[0].Amount__c = 101.01;
            deposits[0].Ledger_Amount__c = deposits[0].Amount__c;
            deposits[0].Ledger__c = testData.ledgers[0].Id;
            deposits[0].Deposit_Date__c = period.Start_Date__c.addDays(1);

            deposits[1].Merchant_Batch_Id__c = '2345678901';
            deposits[1].Bank_Account__c = processor.Bank_GL_Account__c;
            deposits[1].Amount__c = 101.01;
            deposits[1].Ledger_Amount__c = deposits[1].Amount__c;
            deposits[1].Ledger__c = testData.ledgers[0].Id;
            deposits[1].Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposits;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            List<Cash_Receipt__c> receipts = new List<Cash_Receipt__c>{testData.cashReceipts[0], testData.cashReceipts[1]};
           
            receipts[0].Payment_Reference__c = '987654321';
            receipts[0].Payment_Processor__c = processor.Id;
            receipts[0].Account__c = customer.Account__c;
            receipts[0].Amount__c = deposits[0].Amount__c;
            receipts[0].Bank_Deposit__c = deposits[0].Id;
            receipts[0].Ledger__c = deposits[0].Ledger__c;
            receipts[0].Receipt_Date__c = period.Start_Date__c;
            receipts[0].Accounting_Period__c = period.Id;

            receipts[1].Payment_Reference__c = '876543219';
            receipts[1].Payment_Processor__c = processor.Id;
            receipts[1].Account__c = customer.Account__c;
            receipts[1].Amount__c = deposits[1].Amount__c;
            receipts[1].Bank_Deposit__c = deposits[1].Id;
            receipts[1].Ledger__c = deposits[1].Ledger__c;
            receipts[1].Receipt_Date__c = period.Start_Date__c;
            receipts[1].Accounting_Period__c = period.Id;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipts;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>{
                getPaymentActivity(paymentMethod, receipts[0], deposits[0].Merchant_Batch_Id__c),
                getPaymentActivity(paymentMethod, receipts[1], deposits[1].Merchant_Batch_Id__c)
            };
            insert activities;

            List<Bank_Deposit__c> inputDeposits = getBankDeposits(new Set<Id>{deposits[0].Id, deposits[1].Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(inputDeposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(2, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);
            Assert.areEqual(result.succeedRecords, jes.size());
            // maker sure results are ordered as expected
            Assert.areEqual(jes[0].Reference__c, deposits[0].Merchant_Batch_Id__c);
            Assert.areEqual(jes[1].Reference__c, deposits[1].Merchant_Batch_Id__c);

            for (Integer i=0; i<jes.size(); i++) {
                Assert.areEqual(deposits[i].Merchant_Batch_Id__c, jes[i].Reference__c);
                Assert.areEqual(deposits[i].Ledger__c, jes[i].Ledger__c);
                Assert.areEqual(0, jes[i].Out_of_Balance__c);
                Assert.areEqual(activities[i].Amount__c + activities[i].Fee__c, jes[i].Total_Credits__c);
                Assert.areEqual(jes[i].Total_Credits__c, jes[i].Total_Debits__c);
                Assert.areEqual(period.Id, jes[i].Accounting_Period__c);
                Assert.areEqual(4, jes[i].Line_Count__c);

                // JE line assertions
                journalEntryLineAssertions(jes[i], processor, activities[i].Amount__c, activities[i].Fee__c);
            }

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesMultiLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            List<Bank_Deposit__c> deposits = new List<Bank_Deposit__c>{testData.bankDeposits[0], testData.bankDeposits[1]};
            
            deposits[0].Merchant_Batch_Id__c = '1234567890';
            deposits[0].Bank_Account__c = processor.Bank_GL_Account__c;
            deposits[0].Amount__c = 101.01;
            deposits[0].Ledger_Amount__c = deposits[0].Amount__c;
            deposits[0].Ledger__c = testData.ledgers[0].Id;
            deposits[0].Deposit_Date__c = period.Start_Date__c.addDays(1);

            deposits[1].Merchant_Batch_Id__c = '2345678901';
            deposits[1].Bank_Account__c = processor.Bank_GL_Account__c;
            deposits[1].Amount__c = 101.01;
            deposits[1].Ledger_Amount__c = deposits[1].Amount__c;
            deposits[1].Ledger__c = testData.ledgers[2].Id;
            deposits[1].Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposits;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            List<Cash_Receipt__c> receipts = new List<Cash_Receipt__c>{testData.cashReceipts[0], testData.cashReceipts[1]};
           
            receipts[0].Payment_Reference__c = '987654321';
            receipts[0].Payment_Processor__c = processor.Id;
            receipts[0].Account__c = customer.Account__c;
            receipts[0].Amount__c = deposits[0].Amount__c;
            receipts[0].Bank_Deposit__c = deposits[0].Id;
            receipts[0].Ledger__c = deposits[0].Ledger__c;
            receipts[0].Receipt_Date__c = period.Start_Date__c;
            receipts[0].Accounting_Period__c = period.Id;

            receipts[1].Payment_Reference__c = '876543219';
            receipts[1].Payment_Processor__c = processor.Id;
            receipts[1].Account__c = customer.Account__c;
            receipts[1].Amount__c = deposits[1].Amount__c;
            receipts[1].Bank_Deposit__c = deposits[1].Id;
            receipts[1].Ledger__c = deposits[1].Ledger__c;
            receipts[1].Receipt_Date__c = period.Start_Date__c;
            receipts[1].Accounting_Period__c = period.Id;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipts;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>{
                getPaymentActivity(paymentMethod, receipts[0], deposits[0].Merchant_Batch_Id__c),
                getPaymentActivity(paymentMethod, receipts[1], deposits[1].Merchant_Batch_Id__c)
            };
            insert activities;

            List<Bank_Deposit__c> inputDeposits = getBankDeposits(new Set<Id>{deposits[0].Id, deposits[1].Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(inputDeposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(2, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);
            Assert.areEqual(result.succeedRecords, jes.size());
            // maker sure results are ordered as expected
            Assert.areEqual(jes[0].Reference__c, deposits[0].Merchant_Batch_Id__c);
            Assert.areEqual(jes[1].Reference__c, deposits[1].Merchant_Batch_Id__c);

            for (Integer i=0; i<jes.size(); i++) {
                Assert.areEqual(deposits[i].Merchant_Batch_Id__c, jes[i].Reference__c);
                Assert.areEqual(deposits[i].Ledger__c, jes[i].Ledger__c);
                Assert.areEqual(0, jes[i].Out_of_Balance__c);
                Assert.areEqual(activities[i].Amount__c + activities[i].Fee__c, jes[i].Total_Credits__c);
                Assert.areEqual(jes[i].Total_Credits__c, jes[i].Total_Debits__c);
                Assert.areEqual(period.Id, jes[i].Accounting_Period__c);
                Assert.areEqual(4, jes[i].Line_Count__c);

                // JE line assertions
                journalEntryLineAssertions(jes[i], processor, activities[i].Amount__c, activities[i].Fee__c);
            }

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesMultiCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        try {
            testData.enableMultiCurrency();
            MultiCurrencyHandler.isMultiCurrencyEnabled = true;
        } catch (TestDataSuite.TestDataSuiteException e) {
            // MC not enabled for org
            return;
        }

        System.runAs(testData.users.get(1)) {
            // set currency for ledgers
            List<SObject> allCurrencies = Database.query('SELECT IsoCode FROM CurrencyType LIMIT 2');
            if (allCurrencies.size() < 2) {
                // only one currency configured
                return;
            }
            List<Ledger__c> ledgers = new List<Ledger__c>{testData.ledgers[0].clone(false,true,false,false), testData.ledgers[2].clone(false,true,false,false)};
            ledgers[0].put('CurrencyIsoCode', allCurrencies[0].get('IsoCode'));
            ledgers[1].put('CurrencyIsoCode', allCurrencies[1].get('IsoCode'));
            insert ledgers;

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            List<Bank_Deposit__c> deposits = new List<Bank_Deposit__c>{testData.bankDeposits[0], testData.bankDeposits[1]};
            
            deposits[0].Merchant_Batch_Id__c = '1234567890';
            deposits[0].Bank_Account__c = processor.Bank_GL_Account__c;
            deposits[0].Amount__c = 101.01;
            deposits[0].Ledger_Amount__c = deposits[0].Amount__c;
            deposits[0].Ledger__c = ledgers[0].Id;
            deposits[0].Deposit_Date__c = period.Start_Date__c.addDays(1);
            deposits[0].put('CurrencyIsoCode', ledgers[0].get('CurrencyIsoCode'));

            deposits[1].Merchant_Batch_Id__c = '2345678901';
            deposits[1].Bank_Account__c = processor.Bank_GL_Account__c;
            deposits[1].Amount__c = 101.01;
            deposits[1].Ledger_Amount__c = deposits[1].Amount__c;
            deposits[1].Ledger__c = ledgers[1].Id;
            deposits[1].Deposit_Date__c = period.Start_Date__c.addDays(1);
            deposits[1].put('CurrencyIsoCode', ledgers[1].get('CurrencyIsoCode'));

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposits;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            List<Cash_Receipt__c> receipts = new List<Cash_Receipt__c>{testData.cashReceipts[0], testData.cashReceipts[1]};
           
            receipts[0].Payment_Reference__c = '987654321';
            receipts[0].Payment_Processor__c = processor.Id;
            receipts[0].Account__c = customer.Account__c;
            receipts[0].Amount__c = deposits[0].Amount__c;
            receipts[0].Bank_Deposit__c = deposits[0].Id;
            receipts[0].Ledger__c = deposits[0].Ledger__c;
            receipts[0].Receipt_Date__c = period.Start_Date__c;
            receipts[0].Accounting_Period__c = period.Id;
            receipts[0].put('CurrencyIsoCode', deposits[0].get('CurrencyIsoCode'));

            receipts[1].Payment_Reference__c = '876543219';
            receipts[1].Payment_Processor__c = processor.Id;
            receipts[1].Account__c = customer.Account__c;
            receipts[1].Amount__c = deposits[1].Amount__c;
            receipts[1].Bank_Deposit__c = deposits[1].Id;
            receipts[1].Ledger__c = deposits[1].Ledger__c;
            receipts[1].Receipt_Date__c = period.Start_Date__c;
            receipts[1].Accounting_Period__c = period.Id;
            receipts[1].put('CurrencyIsoCode', deposits[1].get('CurrencyIsoCode'));
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipts;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            List<Payment_Activity__c> activities = new List<Payment_Activity__c>{
                getPaymentActivity(paymentMethod, receipts[0], deposits[0].Merchant_Batch_Id__c),
                getPaymentActivity(paymentMethod, receipts[1], deposits[1].Merchant_Batch_Id__c)
            };
            insert activities;

            List<Bank_Deposit__c> inputDeposits = getBankDeposits(new Set<Id>{deposits[0].Id, deposits[1].Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(inputDeposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(2, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);
            Assert.areEqual(result.succeedRecords, jes.size());
            // maker sure results are ordered as expected
            Assert.areEqual(jes[0].Reference__c, deposits[0].Merchant_Batch_Id__c);
            Assert.areEqual(jes[1].Reference__c, deposits[1].Merchant_Batch_Id__c);

            for (Integer i=0; i<jes.size(); i++) {
                Assert.areEqual(deposits[i].Merchant_Batch_Id__c, jes[i].Reference__c);
                Assert.areEqual(deposits[i].Ledger__c, jes[i].Ledger__c);
                Assert.areEqual(0, jes[i].Out_of_Balance__c);
                Assert.areEqual(activities[i].Amount__c + activities[i].Fee__c, jes[i].Total_Credits__c);
                Assert.areEqual(jes[i].Total_Credits__c, jes[i].Total_Debits__c);
                Assert.areEqual(period.Id, jes[i].Accounting_Period__c);
                Assert.areEqual(4, jes[i].Line_Count__c);
                Assert.areEqual(deposits[i].get('CurrencyIsoCode'), ((Journal_Entry__c)database.query('SELECT CurrencyIsoCode FROM Journal_Entry__c WHERE Id = \'' + jes[i].Id + '\' LIMIT 1')).get('CurrencyIsoCode'));

                // JE line assertions
                journalEntryLineAssertions(jes[i], processor, activities[i].Amount__c, activities[i].Fee__c);
            }

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesRounding() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.010101;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(activity.Amount__c.setScale(2,RoundingMode.HALF_UP) + activity.Fee__c.setScale(2,RoundingMode.HALF_UP), jes[0].Total_Credits__c);
            Assert.areEqual(activity.Amount__c.setScale(2,RoundingMode.HALF_UP) + activity.Fee__c.setScale(2,RoundingMode.HALF_UP), jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(4, jes[0].Line_Count__c);
            
            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, activity.Amount__c.setScale(2,RoundingMode.HALF_UP), activity.Fee__c.setScale(2,RoundingMode.HALF_UP));

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesRoundingAndSingleCnvFee() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[3];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.010101;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            receipt.Convenience_Fees_Charged__c=110;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            Decimal expectedAmount = (activity.Amount__c.setScale(2,RoundingMode.HALF_UP) + activity.Fee__c.setScale(2,RoundingMode.HALF_UP) + receipt.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP));
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Credits__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(6, jes[0].Line_Count__c);
            
            Map<Id,Bank_Deposit__c> bankDepositMap = new Map<Id,Bank_Deposit__c>();
            bankDepositMap.put(deposit.Id,deposit);

            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, activity.Amount__c.setScale(2,RoundingMode.HALF_UP), activity.Fee__c.setScale(2,RoundingMode.HALF_UP));
            journalEntryLineCnvFeeAssertions(jes[0], processor,bankDepositMap,deposit.Id, receipt.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP));

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }
    @IsTest
    static void testCreateJournalEntryWithLinesRoundingAndMultipleCnvFee() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[3];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.010101;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            receipt.Convenience_Fees_Charged__c=110;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Cash_Receipt__c receipt2 = testData.cashReceipts[1];
            receipt2.Payment_Reference__c = merchantRefNum;
            receipt2.Payment_Processor__c = processor.Id;
            receipt2.Account__c = customer.Account__c;
            receipt2.Amount__c = deposit.Ledger_Amount__c;
            receipt2.Bank_Deposit__c = deposit.Id;
            receipt2.Ledger__c = deposit.Ledger__c;
            receipt2.Receipt_Date__c = period.Start_Date__c;
            receipt2.Accounting_Period__c = period.Id;
            receipt2.Convenience_Fees_Charged__c=100;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt2;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            Payment_Activity__c activity2 = getPaymentActivity(paymentMethod, receipt2, merchantBatchId);
            insert activity2;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            Decimal expectedAmount = (activity.Amount__c.setScale(2,RoundingMode.HALF_UP) + activity.Fee__c.setScale(2,RoundingMode.HALF_UP) + receipt.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP) + 
                        activity2.Fee__c.setScale(2,RoundingMode.HALF_UP) + receipt2.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP));
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Credits__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(6, jes[0].Line_Count__c);
            
            Map<Id,Bank_Deposit__c> bankDepositMap = new Map<Id,Bank_Deposit__c>();
            bankDepositMap.put(deposit.Id,deposit);

            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, activity.Amount__c.setScale(2,RoundingMode.HALF_UP), activity.Fee__c.setScale(2,RoundingMode.HALF_UP) + activity2.Fee__c.setScale(2,RoundingMode.HALF_UP));
            journalEntryLineCnvFeeAssertions(jes[0], processor,bankDepositMap,deposit.Id, receipt.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP) + receipt2.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP));

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesCnvFeeMissingGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[2];

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Decimal convFees = 2.98;

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.01 + convFees;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            receipt.Convenience_Fees_Charged__c = convFees;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);
            
            Decimal expectedAmount = (activity.Amount__c.setScale(2,RoundingMode.HALF_UP) + activity.Fee__c.setScale(2,RoundingMode.HALF_UP) + receipt.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP));
            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Credits__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(6, jes[0].Line_Count__c);
            // no conv fee lines created because conv fee gl account was not present on the processor
            
            Map<Id,Bank_Deposit__c> bankDepositMap = new Map<Id,Bank_Deposit__c>();
            bankDepositMap.put(deposit.Id,deposit);

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    @IsTest
    static void testCreateJournalEntryWithLinesCnvFeeDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments() // avoid extra processing
            .createPaymentProcessors()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            String merchantBatchId = '1234567890';
            String merchantRefNum = '987654321';

            Payment_Processor__c processor = testData.paymentProcessors[2];
            processor.Convenience_Fees_GL_Account__c = testData.paymentProcessors[3].Convenience_Fees_GL_Account__c;
            update processor;

            Payment_Processor_Customer__c customer = getPaymentProcessorCustomer(testData.accounts[0], processor);

            Accounting_Period__c period = testData.acctPeriods[0];

            Decimal convFees = 2.98;

            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Merchant_Batch_Id__c = merchantBatchId;
            deposit.Bank_Account__c = processor.Bank_GL_Account__c;
            deposit.Amount__c = 101.01 + convFees;
            deposit.Ledger_Amount__c = deposit.Amount__c;
            deposit.Ledger__c = testData.ledgers[0].Id;
            deposit.Deposit_Date__c = period.Start_Date__c.addDays(1);

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});                    
			update deposit;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c});

            Cash_Receipt__c receipt = testData.cashReceipts[0];
            receipt.Payment_Reference__c = merchantRefNum;
            receipt.Payment_Processor__c = processor.Id;
            receipt.Account__c = customer.Account__c;
            receipt.Amount__c = deposit.Ledger_Amount__c;
            receipt.Bank_Deposit__c = deposit.Id;
            receipt.Ledger__c = deposit.Ledger__c;
            receipt.Receipt_Date__c = period.Start_Date__c;
            receipt.Accounting_Period__c = period.Id;
            receipt.Convenience_Fees_Charged__c= convFees;
            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});                    
			update receipt;
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField>{Cash_Receipt__c.Bank_Deposit__c});

            Payment_Method__c paymentMethod = getPaymentMethod(customer, processor);
            insert paymentMethod;

            Payment_Activity__c activity = getPaymentActivity(paymentMethod, receipt, merchantBatchId);
            insert activity;

            List<Bank_Deposit__c> deposits = getBankDeposits(new Set<Id>{deposit.Id});
            
            Test.startTest();
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper result = cx.createJournalEntryWithLines(deposits, new Set<Id>{processor.Id}, new CxAJRLogger());
            Test.stopTest();

            // JE summary assertions
            Assert.areEqual(1, result.succeedRecords);
            Assert.areEqual(result.succeedRecords, result.successfulJournalEntryIds.size());
            Assert.areEqual(0, result.failedRecords);

            Decimal expectedAmount = (activity.Amount__c.setScale(2,RoundingMode.HALF_UP) + activity.Fee__c.setScale(2,RoundingMode.HALF_UP) + receipt.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP));

            // JE individual assertions
            List<Journal_Entry__c> jes = getJournalEntries(result.successfulJournalEntryIds);

            Assert.areEqual(result.succeedRecords, jes.size());
            Assert.areEqual(deposit.Merchant_Batch_Id__c, jes[0].Reference__c);
            Assert.areEqual(deposit.Ledger__c, jes[0].Ledger__c);
            Assert.areEqual(0, jes[0].Out_of_Balance__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Credits__c);
            Assert.areEqual(expectedAmount, jes[0].Total_Debits__c);
            Assert.areEqual(period.Id, jes[0].Accounting_Period__c);
            Assert.areEqual(6, jes[0].Line_Count__c);
            // conv fee lines created because there are existing CRs with conv fees which must be recorded
            
            Map<Id,Bank_Deposit__c> bankDepositMap = new Map<Id,Bank_Deposit__c>();
            bankDepositMap.put(deposit.Id,deposit);

            // JE line assertions
            journalEntryLineAssertions(jes[0], processor, activity.Amount__c.setScale(2,RoundingMode.HALF_UP), activity.Fee__c.setScale(2,RoundingMode.HALF_UP));
            journalEntryLineCnvFeeAssertions(jes[0], processor,bankDepositMap,deposit.Id, receipt.Convenience_Fees_Charged__c.setScale(2,RoundingMode.HALF_UP));

            // payment processor assertions
            Assert.areEqual(1, result.ppLastSyncUpdate.size());
            Assert.isTrue(result.ppLastSyncUpdate.contains(processor.Id));
        }
    }

    private static List<Bank_Deposit__c> getBankDeposits(Set<Id> depositIds) {
        Database.QueryLocator loc = DomainUtils.getQueryLocatorForCxSettlementBatch(depositIds, new Set<String>{'1234'});
        Database.QueryLocatorIterator itr = loc.iterator();
        List<Bank_Deposit__c> deposits = new List<Bank_Deposit__c>();
        Integer breaker = 0; // infinite loop safety
        while (itr.hasNext() && breaker < 100) {
            deposits.add((Bank_Deposit__c)itr.next());
            breaker++;
        }
        return deposits;
    }

    // ordered by reference (corresponds to merchant batch id on CR, Payment Activity, and Bank Deposit)
    private static List<Journal_Entry__c> getJournalEntries(Set<Id> jeIds) {
        return [
            SELECT
                Id,
                Name,
                Total_Credits__c,
                Total_Debits__c,
                Out_of_Balance__c,
                Accounting_Period__c,
                Reference__c,
                Line_Count__c,
                Ledger__c,
                (
                    SELECT
                        Amount__c,
                        Credit__c,
                        Debit__c,
                        GL_Account__c,
                        Ledger_Amount__c,
                        Description__c 
                    FROM Journal_Entry_Lines__r
                )
            FROM Journal_Entry__c
            WHERE Id IN :jeIds
            ORDER BY Reference__c ASC
        ];
    }

    private static Payment_Processor_Customer__c getPaymentProcessorCustomer(Account customer, Payment_Processor__c processor) {
        return new Payment_Processor_Customer__c(
            Account__c = customer.Id, 
            Processor__c = processor.Id, 
            External_Id__c = customer.Id + '' + processor.Id
        );
    }

    private static Payment_Method__c getPaymentMethod(Payment_Processor_Customer__c customer, Payment_Processor__c processor) {
        return new Payment_Method__c(
            Customer__c = customer.Account__c, 
            Payment_Processor__c = processor.Id, 
            External_Id__c = customer.Id + '' + processor.Id,
            Last_Four_Digits__c = '4242',
            Payment_Method_Type__c = 'Credit Card', 
            Status__c = 'Active',
            Expiration_Month__c = '12',
            Expiration_Year__c = '2224',
            Type__c = 'Visa',
            Default__c = true
        );
    }

    private static Payment_Activity__c getPaymentActivity(Payment_Method__c pm, Cash_Receipt__c cr, String merchantBatchId) {
        return new Payment_Activity__c(
            Type__c = PaymentActivityHelper.PAYMENT_TYPE,
            Status__c = PaymentActivityHelper.PENDING_STATUS,
            Amount__c = cr.Amount__c,
            Fee__c = (cr.Amount__c * 0.018).setScale(PaymentActivityActions.currencyAndNumberFields.get(Payment_Activity__c.Fee__c), System.RoundingMode.HALF_UP),
            Payment_Method__c = pm.Id,
            Cash_Receipt__c = cr.Id,
            Merchant_Reference__c = cr.Payment_Reference__c,
            Merchant_Batch_Id__c = merchantBatchId
        );
    }

    private static void journalEntryLineAssertions(Journal_Entry__c je, Payment_Processor__c processor, Decimal amount, Decimal fee) {

        for (Journal_Entry_Line__c jel : je.Journal_Entry_Lines__r) {
            if (jel.GL_Account__c == processor.Bank_GL_Account__c && jel.Debit__c > 0) {
                Assert.areEqual(amount, jel.Amount__c);
                Assert.areEqual(jel.Amount__c, jel.Debit__c);
                Assert.isNull(jel.Credit__c);
                Assert.areEqual(jel.Amount__c, jel.Ledger_Amount__c);
                Assert.areEqual(je.Name + ' (' + (Label.COMMON_DEPOSIT).toLowerCase() + ')', jel.Description__c);
            } else if (jel.GL_Account__c == processor.Merchant_GL_Account__c) {
                Assert.areEqual(amount, jel.Amount__c);
                Assert.isNull(jel.Debit__c);
                Assert.isNull(jel.Description__c);
                Assert.areEqual(jel.Amount__c, jel.Credit__c);
                Assert.areEqual(jel.Amount__c, jel.Ledger_Amount__c);
            } else if (jel.GL_Account__c == processor.Merchant_Fees_GL_Account__c) {
                Assert.areEqual(fee, jel.Amount__c);
                Assert.areEqual(jel.Amount__c, jel.Debit__c);
                Assert.isNull(jel.Credit__c);
                Assert.isNull(jel.Description__c);
                Assert.areEqual(jel.Amount__c, jel.Ledger_Amount__c);
            } else if (jel.GL_Account__c == processor.Bank_GL_Account__c && jel.Credit__c > 0) {
                Assert.areEqual(fee, jel.Amount__c);
                Assert.isNull(jel.Debit__c);
                Assert.areEqual(jel.Amount__c, jel.Credit__c);
                Assert.areEqual(jel.Amount__c, jel.Ledger_Amount__c);
                Assert.areEqual(je.Name + ' (' + Label.COMMON_FEE_WITHDRAWAL + ')' , jel.Description__c);
            }  else if (jel.GL_Account__c == processor.Convenience_Fees_GL_Account__c) {
                Assert.isNull(jel.Debit__c);
                Assert.areEqual(jel.Amount__c, jel.Credit__c);
            }
        }
    }
    private static void journalEntryLineCnvFeeAssertions(Journal_Entry__c je, Payment_Processor__c processor,Map<Id,Bank_Deposit__c> bankDepositMap, String bankDepId,Decimal cnvFee) {
        Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaults = GLAccount.glAccountDefaultsMapByLedgerId(
                                            new Set<Id> (SObjectActions.ledgerIdBySourceId(bankDepositMap.values()).values()));

        for (Journal_Entry_Line__c jel : je.Journal_Entry_Lines__r) {
            if (jel.GL_Account__c == processor.Convenience_Fees_GL_Account__c && jel.Credit__c > 0) {
                Assert.areEqual(cnvFee, jel.Amount__c);
                Assert.isNull(jel.Debit__c);
                Assert.areEqual(jel.Amount__c, jel.Credit__c);
                Assert.areEqual(jel.Amount__c, jel.Ledger_Amount__c);
                Assert.areEqual(Label.INF_CONVENIENCE_FEES_CHARGE_FOR_ALL, jel.Description__c);
            } else if (jel.GL_Account__c == glAccountDefaults.get(bankDepositMap.get(bankDepId).Ledger__c).get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT).GL_Account__c && jel.Debit__c > 0) {
                Assert.areEqual(cnvFee, jel.Amount__c);
                Assert.areEqual(jel.Amount__c, jel.Debit__c);
                Assert.isNull(jel.Credit__c);
                Assert.areEqual(jel.Amount__c, jel.Ledger_Amount__c);
                Assert.areEqual(Label.INF_CONVENIENCE_FEES_CHARGE_FOR_ALL, jel.Description__c);
            }
        }
    }
}