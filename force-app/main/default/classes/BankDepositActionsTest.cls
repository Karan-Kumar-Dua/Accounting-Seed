@IsTest
public class BankDepositActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBankDepositPreventUpdateBankReconciliationFieldSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            testData.bankDeposits[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

            DMLException dmlEx;
            try {
                update testData.bankDeposits[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }

    @IsTest
    public static void testBankDepositPreventUpdateAmountFieldSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits();

        System.runAs(testData.users[1]) {
            testData.bankDeposits[0].Amount__c = 3453464;

            DMLException dmlEx;
            try {
                update testData.bankDeposits[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }

    @IsTest
    public static void testBankDepositPreventUpdateFieldsChildRecordsCR() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            update testData.cashReceipts[0];

            DMLException dmlEx;
            try {
                testData.bankDeposits[0].Bank_Account__c = testData.glAccounts[5].Id;
                update testData.bankDeposits[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }

    @IsTest
    public static void testBankDepositPreventUpdateFieldsChildRecordsJE() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createBankDeposits()
            .createJournalEntries();

        System.runAs(testData.users[1]) {
            testData.journalEntryLines[0].Bank_Deposit__c = testData.bankDeposits[0].Id;

            testData.bankDeposits[0].Deposit_Date__c = Date.today();
            update testData.bankDeposits[0];

            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Deposit__c);
            update testData.journalEntryLines[0];
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Deposit__c);

            DMLException dmlEx;
            try {
                testData.bankDeposits[0].Bank_Account__c = testData.glAccounts[5].Id;
                update testData.bankDeposits[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }
    }
    
    @IsTest
    public static void testBankDepositPreventUpdateFieldsChildRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            update testData.cashReceipts[0];

            DMLException dmlEx;
            try {
                update testData.bankDeposits[0];

            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }

    }
 
    @IsTest
    public static void testBankDepositSetDefaultFieldValuesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Bank_Deposit__c bd = testData.bankDeposits[0].clone(false, true);
            bd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            bd.Amount__c = 23456;
            insert bd;

            System.assertEquals(NULL, [SELECT Id, Bank_Reconciliation__c FROM Bank_Deposit__c WHERE Id = :bd.Id].Bank_Reconciliation__c);
            System.assertEquals(0, [SELECT Id, Amount__c FROM Bank_Deposit__c WHERE Id = :bd.Id].Amount__c);
        }

    }
    
    @IsTest
    public static void testBankDepositPreventDeleteError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Bank_Deposit__c bd = testData.bankDeposits[0].clone(false,true);
            insert bd;

            bd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            bd.Amount__c = 23456;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Bank_Deposit__c.Bank_Reconciliation__c,
                    Bank_Deposit__c.Amount__c
                }
            );
            update bd;
            TriggerObserver.reset();

            DMLException dmlEx;
            try {
                delete bd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankDepositActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testBankDepositPreventLedgerUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Deposit__c bd = testData.bankDeposits[0].clone(false, true);
            bd.Ledger__c = testData.ledgers[0].Id;
            insert bd;

            bd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            bd.Amount__c = 23456;
            bd.Cleared_Date__c = System.today();

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Bank_Deposit__c.Bank_Reconciliation__c,
                    Bank_Deposit__c.Amount__c
                }
            );
            update bd;
            TriggerObserver.reset();

            bd.Ledger__c = testData.ledgers[2].Id;
            DMLException dmlEx;
            try {
                update bd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BankDepositActions.LEDGER_UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testBankDepositNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            Bank_Deposit__c bd = new Bank_Deposit__c();
            try {
                insert bd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testBankDepositNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                DMLException dmlEx;
                Bank_Deposit__c bd = new Bank_Deposit__c();
                try {
                    insert bd;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }


    @IsTest
    public static void testBankDepositSetLedgerAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits();

        System.runAs(testData.users[1]) {
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Bank_Deposit__c.Ledger_Amount__c,
                    Bank_Deposit__c.Amount__c
                }
            );
           
            testData.bankDeposits[0].Amount__c = 12345;
            testData.bankDeposits[0].Ledger_Amount__c = null;
            update testData.bankDeposits[0];
            TriggerObserver.reset();
            System.assertEquals(12345, [SELECT Id, Ledger_Amount__c FROM Bank_Deposit__c WHERE Id = :testData.bankDeposits[0].id].Ledger_Amount__c);
        }

    }

    @IsTest
    public static void testBankDepositSetLedgerAmountMultiCurr_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency()
                .createBankDeposits();

            System.runAs(testData.users[1]) {
                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Bank_Deposit__c.Ledger_Amount__c,
                        Bank_Deposit__c.Amount__c
                    }
                );

                testData.bankDeposits[0].Amount__c = 12345;
                testData.bankDeposits[0].Ledger_Amount__c = null;
                update testData.bankDeposits[0];
                TriggerObserver.reset();
                System.assertEquals(0, [SELECT Id, Ledger_Amount__c FROM Bank_Deposit__c WHERE Id = :testData.bankDeposits[0].id].Ledger_Amount__c);

            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }
}