@isTest
private class AccountPayableDeepCloneTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testAccountPayableDeepClone() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id][0]);
            AccountPayableDeepClone ext = new AccountPayableDeepClone(con);
            ext.tempPayable.Date__c = testData.acctPeriods[0].Start_Date__c;
            PageReference pagerefr = ext.cloneWithlines();

            Test.stopTest();

            System.assertEquals(
                [SELECT COUNT() FROM Account_Payable_Line__c WHERE Account_Payable__c = :testData.payables.get(0).Id],
                ext.newAPLines.size()
            );
        }
    }

    @isTest
    private static void testAccountPayableDeepCloneSetDueDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c newPayable = testData.payables.get(0).clone();
            newPayable.Vendor__c = NULL;
            newPayable.Contact__c = testData.contacts[0].Id;
            newPayable.Due_Date__c = newPayable.Date__c.addDays(10);

            insert newPayable;

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name FROM Account_Payable__c WHERE Id = :newPayable.Id][0]);
            AccountPayableDeepClone ext = new AccountPayableDeepClone(con);

            System.assertEquals(System.today(), ext.tempPayable.Date__c);

            ext.tempPayable.Date__c = testData.acctPeriods[0].Start_Date__c;
            PageReference pagerefr = ext.cloneWithlines();

            Test.stopTest();
            String exName = [SELECT Id, Name FROM Account_Payable__c WHERE Id = :newPayable.Id].Name;

            System.assertEquals(
                1,
                [SELECT Due_Date__c FROM Account_Payable__c WHERE Payee_Reference__c LIKE :('%' + exName + '%')].size()
            );
        }
    }

    public static testMethod void testCloneAsCreditMemoDefault() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().setCreditMemoDefaultAmount();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name FROM Account_Payable__c WHERE Id = :testData.payables[4].Id][0]);
            AccountPayableDeepClone ext = new AccountPayableDeepClone(con);
            ext.tempPayable.Date__c = testData.acctPeriods[0].Start_Date__c;
            ext.makeCreditMemo = true;
            ext.cloneWithLines();
            Account_Payable_Line__c result = [SELECT Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :ext.cloneAcctPayable.Id][0];
            System.assertEquals('Credit Memo', [SELECT Type__c FROM Account_Payable__c WHERE Id = :ext.cloneAcctPayable.Id].Type__c);
            System.assert(result.Unit_Cost__c < 0);
            System.assert(result.Quantity__c > 0);
        }
    }

    public static testMethod void testCloneAsCreditMemoQuantity() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().setCreditMemoDefaultQuantity();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id][0]);
            AccountPayableDeepClone ext = new AccountPayableDeepClone(con);
            ext.tempPayable.Date__c = testData.acctPeriods[0].Start_Date__c;
            ext.makeCreditMemo = true;
            ext.cloneWithLines();
            Account_Payable_Line__c result = [SELECT Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :ext.cloneAcctPayable.Id][0];
            System.assertEquals('Credit Memo', [SELECT Type__c FROM Account_Payable__c WHERE Id = :ext.cloneAcctPayable.Id].Type__c);
            System.assert(result.Unit_Cost__c > 0);
            System.assert(result.Quantity__c < 0);
        }
    }

    public static testMethod void testCreditMemoClone() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id][0]);
            Account_Payable_Line__c apl = new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = -1000,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert  apl;

            AccountPayableDeepClone ext = new AccountPayableDeepClone(con);
            ext.tempPayable.Date__c = testData.acctPeriods[0].Start_Date__c;
            ext.cloneWithLines();
            System.assertEquals('Credit Memo', [SELECT Type__c FROM Account_Payable__c WHERE Id = :ext.cloneAcctPayable.Id].Type__c);
            Test.stopTest();
        }
    }

    public static testMethod void testSoftAPClosePayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        
        Account_Payable_Line__c apl = new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = -1000,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert  apl;
        
        List<Accounting_Period__c> acctPeriods = [Select id, Close_AR__c, Close_AP__c, Start_Date__c From Accounting_Period__c 
                                                  WHERE Start_Date__c =: Date.newInstance(1991, 10, 1)];
        acctPeriods[0].Close_AP__c = true;
        acctPeriods[0].Close_AR__c = true;
        UPDATE acctPeriods[0]; 

        System.runAs(testData.users[1]) {
            Test.startTest();
                ApexPages.StandardController con = new ApexPages.StandardController(testData.payables[0]);
                AccountPayableDeepClone ext = new AccountPayableDeepClone(con);
                ext.tempPayable.Date__c = Date.newInstance(1991, 10, 1);
                PageReference pg = ext.cloneWithLines();

                System.assertEquals(TRUE, pg == NULL);
                System.assertEquals(TRUE, ext.isError); 
            Test.stopTest();
        }
    }

    public static testMethod void testSoftAPOpenPayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        
        Account_Payable_Line__c apl = new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = -1000,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert  apl;
        
        List<Accounting_Period__c> acctPeriods = [Select id, Close_AR__c, Close_AP__c, Start_Date__c From Accounting_Period__c 
                                                  WHERE Start_Date__c =: Date.newInstance(1991, 10, 1)];
        acctPeriods[0].Close_AR__c = true;
        UPDATE acctPeriods[0]; 

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id][0]);
            AccountPayableDeepClone ext = new AccountPayableDeepClone(con);
            ext.tempPayable.Date__c = testData.acctPeriods[0].Start_Date__c;
            PageReference pg = ext.cloneWithLines();

            System.assertEquals(TRUE, pg != NULL);
            System.assertEquals(ext.tempPayable.Date__c, ext.cloneAcctPayable.Date__c); 

            System.assertEquals(ext.tempPayable.Date__c, ext.newAPLines[0].Date__c); 
            System.assertEquals(ext.cloneAcctPayable.Id, ext.newAPLines[0].Account_Payable__c);
            Test.stopTest();
        }
    }
    @isTest
    private static void testAccountPayableDeepCloneAllFields() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id][0]);
            AccountPayableDeepClone ext = new AccountPayableDeepClone(con);
            ext.tempPayable.Date__c = testData.acctPeriods[0].Start_Date__c;
            PageReference pagerefr = ext.cloneWithlines();

            Test.stopTest();

            Assert.areEqual(ext.cloneAcctPayable.Status__c, testData.payables.get(0).Status__c);
            Assert.areEqual(ext.cloneAcctPayable.Payment_Status__c, testData.payables.get(0).Payment_Status__c);
            Assert.areEqual(ext.cloneAcctPayable.Vendor__c, testData.payables.get(0).Vendor__c);
            Assert.areEqual(ext.cloneAcctPayable.Ledger__c, testData.payables.get(0).Ledger__c);
            
            Assert.areEqual(3, ext.newAPLines.size());
            Assert.areEqual(45, ext.newAPLines[0].Amount__c);
        }
    }

    /**
     * Clone lines w/
     *      Quantity: Y 
     *      Unit Cost: Y
     *      Total: Y
     */
    @IsTest
    private static void testCloneWithLinesQuantityCostTotal() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            
            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            // fields to clone
            cloner.apLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c, clonedLine.Unit_Cost__c);
            Assert.areEqual(line.Quantity__c, clonedLine.Quantity__c);
            Assert.areEqual(line.Amount__c, clonedLine.Amount__c);

            Test.stopTest();

        }
    }

    /**
     * Clone lines w/
     *      Quantity: Y 
     *      Unit Cost: Y
     *      Total: N
     */
    @IsTest
    private static void testCloneWithLinesQuantityCost() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;

            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            cloner.apLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c, clonedLine.Unit_Cost__c);
            Assert.areEqual(line.Quantity__c, clonedLine.Quantity__c);
            Assert.areEqual(line.Amount__c, clonedLine.Amount__c);

            Test.stopTest();

        }
    }

    /**
     * Clone lines w/
     *      Quantity: Y 
     *      Unit Cost: N 
     *      Total: Y
     */
    @IsTest
    private static void testCloneWithLinesQuantityTotal() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;

            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            cloner.apLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c, clonedLine.Unit_Cost__c);
            Assert.areEqual(line.Quantity__c, clonedLine.Quantity__c);
            Assert.areEqual(line.Amount__c, clonedLine.Amount__c);

            Test.stopTest();

        }
    }

    /**
     * Clone lines w/
     *      Quantity: Y 
     *      Unit Cost: N 
     *      Total: N
     */
    @IsTest
    private static void testCloneWithLinesQuantity() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;

            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            cloner.apLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(0, clonedLine.Unit_Cost__c);
            Assert.areEqual(line.Quantity__c, clonedLine.Quantity__c);
            Assert.areEqual(clonedLine.Unit_Cost__c * clonedLine.Quantity__c, clonedLine.Amount__c);

            Test.stopTest();

        }
    }

    /**
     * Clone lines w/
     *      Quantity: N 
     *      Unit Cost: Y
     *      Total: Y
     */
    @IsTest
    private static void testCloneWithLinesCostTotal() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;

            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            cloner.apLineFields = new Set<String>{ ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c, clonedLine.Unit_Cost__c);
            Assert.areEqual(1, clonedLine.Quantity__c);
            Assert.areEqual(clonedLine.Unit_Cost__c * clonedLine.Quantity__c, clonedLine.Amount__c);

            Test.stopTest();

        }
    }

    /**
     * Clone lines w/
     *      Quantity: N 
     *      Unit Cost: Y
     *      Total: N
     */
    @IsTest
    private static void testCloneWithLinesCost() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;

            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            cloner.apLineFields = new Set<String>{ ns + 'Unit_Cost__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Unit_Cost__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c, clonedLine.Unit_Cost__c);
            Assert.areEqual(1, clonedLine.Quantity__c);
            Assert.areEqual(clonedLine.Quantity__c * clonedLine.Unit_Cost__c, clonedLine.Amount__c);

            Test.stopTest();
        }
    }

    /**
     * Clone lines w/
     *      Quantity: N 
     *      Unit Cost: N
     *      Total: Y
     */
    @IsTest
    private static void testCloneWithLinesTotal() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;

            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            cloner.apLineFields = new Set<String>{ ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Amount__c, clonedLine.Unit_Cost__c);
            Assert.areEqual(1, clonedLine.Quantity__c);
            Assert.areEqual(line.Amount__c, clonedLine.Amount__c);

            Test.stopTest();

        }
    }

    /**
     * Clone Line w/
     *      Quantity: N 
     *      Unit Cost: N
     *      Total: N
     */
    @IsTest
    private static void testCloneWithLines() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;

            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            cloner.apLineFields = new Set<String>{ ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(0, clonedLine.Unit_Cost__c);
            Assert.areEqual(1, clonedLine.Quantity__c);
            Assert.areEqual(clonedLine.Quantity__c * clonedLine.Unit_Cost__c, clonedLine.Amount__c);

            Test.stopTest();

        }
    }

    /**
     * Clone lines w/ tax
     */
    @IsTest
    private static void testCloneWithLinesTax() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createTaxGroups()
            .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Test.startTest();

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id,
                Tax_Group__c = testData.taxGroups[3].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c, Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.isTrue(line.Tax_Amount__c > 0);
            Assert.areEqual((line.Unit_Cost__c * line.Quantity__c) + line.Tax_Amount__c, line.Amount__c);

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            
            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.theNewPayableId = null;
            // fields to clone
            cloner.apLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Tax_Group__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Tax_Group__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c, Tax_Amount__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c, clonedLine.Unit_Cost__c);
            Assert.areEqual(line.Quantity__c, clonedLine.Quantity__c);
            Assert.areEqual(line.Amount__c, clonedLine.Amount__c);
            Assert.areEqual(line.Tax_Amount__c, clonedLine.Tax_Amount__c);

            Test.stopTest();

        }
    }

     /**
     * Clone lines w/ as credit memo
     */
    @IsTest
    private static void testCloneWithLinesCreditMemo() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            
            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.makeCreditMemo = true;
            cloner.theNewPayableId = null;
            // fields to clone
            cloner.apLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Quantity__c', ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c * -1, clonedLine.Unit_Cost__c);
            Assert.areEqual(line.Quantity__c, clonedLine.Quantity__c);
            Assert.areEqual(line.Amount__c * -1, clonedLine.Amount__c);

            Test.stopTest();
        }
    }

     /**
     * Clone lines w/ as credit memo
     */
    @IsTest
    private static void testCloneWithLinesCreditMemoWithoutQuantity() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // create a current period
            Date today = Date.today();
            Integer year = today.year();
            Integer month = today.month();
            insert new Accounting_Period__c(
                    Name = String.valueOf(year) + '-' + (month > 9 ? String.valueOf(month) : '0' + String.valueOf(month)),
                    Start_Date__c = Date.newInstance(year, month, 1),
                    End_Date__c = Date.newInstance(year, month, Date.daysInMonth(year, month)),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            Account_Payable__c payable = new Account_Payable__c(
                Payee_Reference__c = '0',
                Status__c = 'Approved',
                Payment_Status__c = 'Unpaid',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert payable;

            Decimal cost = 25;
            Decimal quantity = 4;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = payable.Id,
                Unit_Cost__c = cost,
                Quantity__c = quantity,
                Date__c = payable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert line;

            line = [SELECT  Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];

            Assert.areEqual(cost, line.Unit_Cost__c);
            Assert.areEqual(quantity, line.Quantity__c); 
            Assert.areEqual(line.Unit_Cost__c * line.Quantity__c, line.Amount__c);
        
            Test.startTest();

            ApexPages.StandardController con = new ApexPages.StandardController([SELECT Id, Name, Date__c FROM Account_Payable__c WHERE Id = :payable.Id][0]);
            String ns = GlobalVariables.PACKAGE_QUALIFIER;
            
            AccountPayableDeepClone cloner = new AccountPayableDeepClone(con);
            cloner.makeCreditMemo = true;
            cloner.theNewPayableId = null;
            // fields to clone
            cloner.apLineFields = new Set<String>{ ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.tempApLineFields = new Set<String>{ ns + 'Unit_Cost__c', ns + 'Amount__c', ns + 'Expense_GL_Account__c' };
            cloner.cloneWithlines();
            Assert.isNotNull(cloner.theNewPayableId);
            List<Account_Payable_Line__c> clonedLines = [SELECT Amount__c, Quantity__c, Unit_Cost__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :cloner.theNewPayableId];
            Assert.isFalse(clonedLines.isEmpty());
            Account_Payable_Line__c clonedLine = clonedLines[0];
            Assert.areEqual(line.Unit_Cost__c * -1, clonedLine.Unit_Cost__c);
            Assert.areEqual(1, clonedLine.Quantity__c);
            Assert.areEqual(clonedLine.Unit_Cost__c * clonedLine.Quantity__c, clonedLine.Amount__c);

            Test.stopTest();
        }
    }
}