@IsTest
public with sharing class GLAccountBalanceBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testExecuteWithNoRecords() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createAccountingVariables();

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
            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Decimal startBalance = 0;

            GLAccountBalanceBatch reducer = new GLAccountBalanceBatch(opts, startDate, startBalance);

            Test.startTest();
            Database.executeBatch(reducer, 2000);
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testExecuteWithRecordsInRange() {
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
            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Decimal startBalance = 0;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 100.17,
                Date__c = Date.today().addDays(-5),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -80.13,
                Date__c = Date.today().addDays(-3),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id
            );
            expectedBalance += tx2.Amount__c;
            
            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            GLAccountBalanceBatch reducer = new GLAccountBalanceBatch(opts, startDate, startBalance);

            Test.startTest();
            Database.executeBatch(reducer, 2000);
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testExecuteDateRangeBound() {
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
            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Decimal startBalance = 0;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 100.17,
                Date__c = Date.today(),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -80.13,
                Date__c = Date.today().addDays(-10),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id
            );
            expectedBalance += tx2.Amount__c;
            
            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2 });

            GLAccountBalanceBatch reducer = new GLAccountBalanceBatch(opts, startDate, startBalance);

            Test.startTest();
            Database.executeBatch(reducer, 2000);
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testExecuteWithRecordsOutRange() {
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
            Date startDate = testData.acctPeriods[1].Start_Date__c;
            Decimal startBalance = 0;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 100.17,
                Date__c = Date.today().addDays(-5),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id
            );
            expectedBalance += tx1.Amount__c;

            Transaction__c tx2 = new Transaction__c(
                Amount__c = -80.13,
                Date__c = Date.today().addDays(-11),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id
            );

            Transaction__c tx3 = new Transaction__c(
                Amount__c = -120.73,
                Date__c = Date.today().addDays(1),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[1].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id,
                GL_Account_Variable_4__c = opts.glVariable4Id
            );
            
            TransactionActions.createTransactions(new Transaction__c[] { tx1, tx2, tx3 });

            GLAccountBalanceBatch reducer = new GLAccountBalanceBatch(opts, startDate, startBalance);

            Test.startTest();
            Database.executeBatch(reducer, 2000);
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

    @IsTest
    private static void testExecuteWithRecordsNoMatch() {
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
            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Decimal startBalance = 0;

            Transaction__c tx1 = new Transaction__c(
                Amount__c = 100.17,
                Date__c = Date.today().addDays(-5),    
                Cash_Receipt__c = testData.cashReceipts[0].Id, 
                Accounting_Period__c = testData.acctPeriods[0].Id,   
                Ledger__c = opts.ledgerId,
                GL_Account__c = opts.glAccountId,
                Account__c = testData.cashReceipts[0].Account__c,
                GL_Account_Variable_1__c = opts.glVariable1Id,
                GL_Account_Variable_2__c = opts.glVariable2Id,
                GL_Account_Variable_3__c = opts.glVariable3Id
            );
            
            TransactionActions.createTransactions(new Transaction__c[] { tx1 });

            GLAccountBalanceBatch reducer = new GLAccountBalanceBatch(opts, startDate, startBalance);

            Test.startTest();
            Database.executeBatch(reducer, 2000);
            Test.stopTest();

            System.assertNotEquals(null, EventBusTestUtils.getPublishedEvents());
            System.assertEquals(1, EventBusTestUtils.getPublishedEvents().size());
            AS_Immediate_Event__e event = (AS_Immediate_Event__e) EventBusTestUtils.getPublishedEvents()[0];
            GLAccountBalance.Balance payload = (GLAccountBalance.Balance) JSON.deserialize(event.Payload__c, GLAccountBalance.Balance.class);
            System.assertEquals(expectedBalance, payload.balance);
        }
    }

}