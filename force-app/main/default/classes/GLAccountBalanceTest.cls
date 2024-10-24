@IsTest
public with sharing class GLAccountBalanceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testCalculateWithPreviousClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createAccountingVariables()
        .createCashReceipts()
        .createCashDisbursementBatches()
        .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Decimal expectedBalance = 0;

            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = Date.today();
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 200.10,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(9),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -200.35,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(5),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id
            );
            expectedBalance += tx2.Amount__c;

            Transaction__c tx3 = new Transaction__c(
                Amount__c = 500.75,
                Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[1].Id
            );
            expectedBalance += tx3.Amount__c;

            Transaction__c tx4 = new Transaction__c(
                Amount__c = -400.25,
                Date__c = testData.acctPeriods[1].Start_Date__c.addDays(7),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[1].Id
            );
            expectedBalance += tx4.Amount__c;

            Transaction__c tx5 = new Transaction__c(
                Amount__c = 10.00,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[1].Id
            );
            expectedBalance += tx5.Amount__c;

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2, tx3, tx4, tx5 });

            // close period
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();

            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testCalculateWithDateInPreviousClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createAccountingVariables()
        .createCashReceipts()
        .createCashDisbursementBatches()
        .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Decimal expectedBalance = 0;

            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = Date.today();
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 200.10,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(9),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = 500.75,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[1].Id
            );
            expectedBalance += tx2.Amount__c;

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            // close period
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();

            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testCalculateWithDateAfterClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createAccountingVariables()
        .createCashReceipts()
        .createCashDisbursementBatches()
        .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Decimal expectedBalance = 0;

            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = Date.today();
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 200.10,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(9),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = 500.75,
                Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[1].Id
            );
            expectedBalance += tx2.Amount__c;

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            // close period
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();

            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testCalculateWithPreviousArchivedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Decimal expectedBalance = 0;

            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = Date.today();
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 200.10,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(9),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -200.35,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(5),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id
            );
            expectedBalance += tx2.Amount__c;

            Transaction__c tx3 = new Transaction__c(
                Amount__c = 500.75,
                Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[1].Id
            );
            expectedBalance += tx3.Amount__c;

            Transaction__c tx4 = new Transaction__c(
                Amount__c = -400.25,
                Date__c = testData.acctPeriods[1].Start_Date__c.addDays(7),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[1].Id
            );
            expectedBalance += tx4.Amount__c;

            Transaction__c tx5 = new Transaction__c(
                Amount__c = 10.00,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[1].Id
            );
            expectedBalance += tx5.Amount__c;

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2, tx3, tx4, tx5 });

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            AccountingPeriodActions.isPreventUpdateOverride = true;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isPreventUpdateOverride = false;

            Test.startTest();

            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testCalculateWithNoPreviousClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Decimal expectedBalance = 0;

            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = Date.today();
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 500.75,
                Date__c = testData.acctPeriods[1].Start_Date__c,    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -400.25,
                Date__c = testData.acctPeriods[1].Start_Date__c,    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id
            );
            expectedBalance += tx2.Amount__c;

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            Test.startTest();

            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testCalculateWithArchivedTxs() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createAccountingVariables()
        .createCashReceipts()
        .createCashDisbursementBatches()
        .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = testData.acctPeriods[0].End_Date__c.addDays(-1);
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 200.10,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(9),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -200.35,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(5),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id
            );

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            AccountingPeriodActions.isPreventUpdateOverride = true;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isPreventUpdateOverride = false;

            Test.startTest();
            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(0, payload.balance);
        }
    }

    @IsTest
    private static void testCalculatetWithInquiryDateEqualPreviousClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createAccountingVariables()
        .createCashReceipts()
        .createCashDisbursementBatches()
        .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Decimal expectedBalance = 0;

            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = testData.acctPeriods[0].End_Date__c;
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 200.10,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(9),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -200.35,
                Date__c = testData.acctPeriods[0].Start_Date__c.addDays(5),    
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id
            );
            expectedBalance += tx2.Amount__c;

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            // close period
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();

            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testCalculatetWithTxsAfterInquiryDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createAccountingVariables()
        .createCashReceipts()
        .createCashDisbursementBatches()
        .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Decimal expectedBalance = 0;

            GLAccountBalanceOption opts = new GLAccountBalanceOption();
            opts.inquiryDate = testData.acctPeriods[0].End_Date__c;
            opts.requestId = 'my_request';
            opts.ledgerId = testData.ledgers[0].Id;
            opts.glAccountId = testData.glAccounts[0].Id;
            opts.glVariable1Id = testData.accountingVariables1[0].Id;
            opts.glVariable2Id = testData.accountingVariables2[0].Id;
            opts.glVariable3Id = testData.accountingVariables3[0].Id;
            opts.glVariable4Id = testData.accountingVariables4[0].Id;

            // after inquiry date
            Transaction__c tx1 = new Transaction__c(
                Amount__c = 500.75,
                Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id
            );

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -400.25,
                Date__c = testData.acctPeriods[1].Start_Date__c.addDays(7),    
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id
            );

            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            Test.startTest();

            GLAccountBalance balance = new GLAccountBalance(opts);
            balance.calculate();
            
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

}