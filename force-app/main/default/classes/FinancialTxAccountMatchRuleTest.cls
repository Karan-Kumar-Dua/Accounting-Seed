@IsTest
public with sharing class FinancialTxAccountMatchRuleTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testIsEnabledTrue() {
        TestDataSuite testData = TestDataSuite.getInstance().enablePrePopulateAccountInfo();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Boolean enabled = FinancialTxAccountMatchRule.isEnabled();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            Test.stopTest();

            System.assert(enabled);
            System.assertNotEquals(null, rule);
        }
    }

    @IsTest
    private static void testIsEnabledFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Boolean enabled = FinancialTxAccountMatchRule.isEnabled();
            Exception expectedEx;
            try {
                FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            } catch(FinancialTxAccountMatchRule.ActionDisabledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();

            System.assert(!enabled);
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest
    private static void testTransferAccountDataCR() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Receipt__c cr = testData.cashReceipts[0];
            cr.Account__c = null;
            cr.GL_Account_Variable_1__c = null;
            cr.GL_Account_Variable_2__c = null;
            cr.GL_Account_Variable_3__c = null;
            cr.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = a.Name;

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cr);
            Test.stopTest();

            System.assertEquals(a.Id, cr.Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, cr.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cr.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cr.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cr.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataCD() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = null;
            cd.Debit_GL_Account__c = null;
            cd.GL_Account_Variable_1__c = null;
            cd.GL_Account_Variable_2__c = null;
            cd.GL_Account_Variable_3__c = null;
            cd.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = a.Name;

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cd);
            Test.stopTest();

            System.assertEquals(a.Id, cd.Vendor__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, cd.Debit_GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, cd.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cd.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cd.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataJEL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Journal_Entry_Line__c jel = testData.journalEntryLines[0];
            jel.Account__c = null;
            jel.GL_Account__c = null;
            jel.GL_Account_Variable_1__c = null;
            jel.GL_Account_Variable_2__c = null;
            jel.GL_Account_Variable_3__c = null;
            jel.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = a.Name;

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, jel);
            Test.stopTest();

            System.assertEquals(a.Id, jel.Account__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, jel.GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, jel.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, jel.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, jel.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, jel.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataJELs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Journal_Entry_Line__c jelCredit = testData.journalEntryLines[0];
            jelCredit.Account__c = null;
            jelCredit.GL_Account__c = null;
            jelCredit.GL_Account_Variable_1__c = null;
            jelCredit.GL_Account_Variable_2__c = null;
            jelCredit.GL_Account_Variable_3__c = null;
            jelCredit.GL_Account_Variable_4__c = null;

            Journal_Entry_Line__c jelDebit = testData.journalEntryLines[1];
            jelDebit.Account__c = null;
            jelDebit.GL_Account__c = null;
            jelDebit.GL_Account_Variable_1__c = null;
            jelDebit.GL_Account_Variable_2__c = null;
            jelDebit.GL_Account_Variable_3__c = null;
            jelDebit.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = a.Name;

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, jelCredit, jelDebit);
            Test.stopTest();

            System.assertEquals(a.Id, jelDebit.Account__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, jelDebit.GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, jelDebit.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, jelDebit.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, jelDebit.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, jelDebit.GL_Account_Variable_4__c);

            System.assertEquals(a.Id, jelCredit.Account__c);
            System.assertEquals(null, jelCredit.GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, jelCredit.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, jelCredit.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, jelCredit.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, jelCredit.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataNoMatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = null;
            cd.Debit_GL_Account__c = null;
            cd.GL_Account_Variable_1__c = null;
            cd.GL_Account_Variable_2__c = null;
            cd.GL_Account_Variable_3__c = null;
            cd.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = 'iuytryexdfcgvhbjnkmohubgyvftcdrsxedghun';

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cd);
            Test.stopTest();

            System.assertEquals(null, cd.Vendor__c);
            System.assertEquals(null, cd.Debit_GL_Account__c);
            System.assertEquals(null, cd.GL_Account_Variable_1__c);
            System.assertEquals(null, cd.GL_Account_Variable_2__c);
            System.assertEquals(null, cd.GL_Account_Variable_3__c);
            System.assertEquals(null, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataImportMatchName() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.File_Import_Match_Name__c = 'xyz:456';
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = null;
            cd.Debit_GL_Account__c = null;
            cd.GL_Account_Variable_1__c = null;
            cd.GL_Account_Variable_2__c = null;
            cd.GL_Account_Variable_3__c = null;
            cd.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = '123:xyz:456:abc:789';

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cd);
            Test.stopTest();

            System.assertEquals(a.Id, cd.Vendor__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, cd.Debit_GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, cd.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cd.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cd.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataCreditTx() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.File_Import_Match_Name__c = 'xyz:456';
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = null;
            cd.Debit_GL_Account__c = null;
            cd.GL_Account_Variable_1__c = null;
            cd.GL_Account_Variable_2__c = null;
            cd.GL_Account_Variable_3__c = null;
            cd.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[0];
            tx.Description__c = '123:xyz:456:abc:789';

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cd);
            Test.stopTest();

            System.assertEquals(a.Id, cd.Vendor__c);
            System.assertEquals(null, cd.Debit_GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, cd.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cd.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cd.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataNoOverwrite() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.File_Import_Match_Name__c = 'abc:789';
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = null;
            cd.Debit_GL_Account__c = testData.glAccounts[1].Id;
            cd.GL_Account_Variable_1__c = testData.accountingVariables1[1].Id;
            cd.GL_Account_Variable_2__c = testData.accountingVariables2[1].Id;
            cd.GL_Account_Variable_3__c = testData.accountingVariables3[1].Id;
            cd.GL_Account_Variable_4__c = testData.accountingVariables4[1].Id;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = '123:xyz:456:abc:789';

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cd);
            Test.stopTest();

            System.assertEquals(a.Id, cd.Vendor__c);
            System.assertEquals(testData.glAccounts[1].Id, cd.Debit_GL_Account__c);
            System.assertEquals(testData.accountingVariables1[1].Id, cd.GL_Account_Variable_1__c);
            System.assertEquals(testData.accountingVariables2[1].Id, cd.GL_Account_Variable_2__c);
            System.assertEquals(testData.accountingVariables3[1].Id, cd.GL_Account_Variable_3__c);
            System.assertEquals(testData.accountingVariables4[1].Id, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataSkipWhenAccountSet() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.File_Import_Match_Name__c = 'abc:789';
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = testData.accounts[0].Id;
            cd.Debit_GL_Account__c = null;
            cd.GL_Account_Variable_1__c = null;
            cd.GL_Account_Variable_2__c = null;
            cd.GL_Account_Variable_3__c = null;
            cd.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = '123:xyz:456:abc:789';

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cd);
            Test.stopTest();

            System.assertEquals(testData.accounts[0].Id, cd.Vendor__c);
            System.assertEquals(null, cd.Debit_GL_Account__c);
            System.assertEquals(null, cd.GL_Account_Variable_1__c);
            System.assertEquals(null, cd.GL_Account_Variable_2__c);
            System.assertEquals(null, cd.GL_Account_Variable_3__c);
            System.assertEquals(null, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataSkipCustomerAccounts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.File_Import_Match_Name__c = '123:xyz';
            a.Accounting_Type__c = 'Customer';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = null;
            cd.Debit_GL_Account__c = null;
            cd.GL_Account_Variable_1__c = null;
            cd.GL_Account_Variable_2__c = null;
            cd.GL_Account_Variable_3__c = null;
            cd.GL_Account_Variable_4__c = null;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = '123:xyz:456:abc:789';

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, cd);
            Test.stopTest();

            System.assertEquals(null, cd.Vendor__c);
            System.assertEquals(null, cd.Debit_GL_Account__c);
            System.assertEquals(null, cd.GL_Account_Variable_1__c);
            System.assertEquals(null, cd.GL_Account_Variable_2__c);
            System.assertEquals(null, cd.GL_Account_Variable_3__c);
            System.assertEquals(null, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testTransferAccountDataDynamicDispatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .createAccountingVariables()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[0].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Vendor__c = null;
            cd.Debit_GL_Account__c = null;
            cd.GL_Account_Variable_1__c = null;
            cd.GL_Account_Variable_2__c = null;
            cd.GL_Account_Variable_3__c = null;
            cd.GL_Account_Variable_4__c = null;
            SObject generic = cd;

            Bank_Transaction__c tx = testData.bankTransactions[1];
            tx.Description__c = a.Name;

            Test.startTest();
            FinancialTxAccountMatchRule rule = FinancialTxAccountMatchRule.getInstance();
            rule.transferAccountData(tx, generic);
            Test.stopTest();

            System.assertEquals(a.Id, cd.Vendor__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, cd.Debit_GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, cd.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cd.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cd.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cd.GL_Account_Variable_4__c);
        }
    }

}