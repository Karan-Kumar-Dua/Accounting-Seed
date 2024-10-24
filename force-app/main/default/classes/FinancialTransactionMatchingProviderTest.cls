@IsTest
public class FinancialTransactionMatchingProviderTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGetMatchingDebitRecords() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0];
            testCD.Reference__c = NULL;
            testCD.Bank_Id__c = NULL;
            update testCD;

            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Date endDate = testData.acctPeriods[0].End_Date__c;

            Test.startTest();

            FinancialTransactionMatchingProvider matchingProvider =
                new FinancialTransactionMatchingProvider(
                    startDate,
                    endDate,
                    NULL,
                    new Set<Decimal>{testCD.Amount__c},
                    testData.ledgers[0].Id,
                   testData.glAccounts[0].Id
                );

            FinancialImportLineWrapper bankTransactionLine = new FinancialImportLineWrapper(
                'externalId',
                'Some Company',
                'debit',
                startDate,
                testCD.Amount__c,
                'USD',
                (String)testData.glAccounts[0].Id
            );

            List<FinancialTransactionMatchingProvider.MatchingRecordWrapper> matchingRecords =
                matchingProvider.getMatchingRecords(bankTransactionLine);

            System.assertEquals(false, matchingRecords.isEmpty());
        }

    }

    @IsTest
    public static void testGetMatchingCreditRecords() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Bank_Deposit__c testBankDeposit = testData.bankDeposits[0];
            testBankDeposit.Deposit_Date__c = testData.acctPeriods[0].Start_Date__c;
            testBankDeposit.Deposit_Reference__c = NULL;
            testBankDeposit.Bank_Id__c = NULL;
            testBankDeposit.Amount__c = 100.00;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Bank_Deposit__c.Amount__c,
                    Bank_Deposit__c.Bank_Reconciliation__c
                }
            );
            update testBankDeposit;

            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Date endDate = testData.acctPeriods[0].End_Date__c;

            FinancialTransactionMatchingProvider matchingProvider =
                new FinancialTransactionMatchingProvider(startDate,
                    endDate,
                    NULL,
                    new Set<Decimal>{100.00},
                    testData.ledgers[0].Id,
                   testData.glAccounts[0].Id
                );

            FinancialImportLineWrapper bankTransactionLine = new FinancialImportLineWrapper(
                'externalId',
                'Some Company',
                'credit',
                startDate,
                100.00,
                'USD',
                (String)testData.glAccounts[0].Id
            );

            List<FinancialTransactionMatchingProvider.MatchingRecordWrapper> matchingRecords =
                matchingProvider.getMatchingRecords(bankTransactionLine);

            System.assertEquals(false, matchingRecords.isEmpty());
        }

    }

    @IsTest
    public static void testGetMatchingRecordsAssociatedWithBankDeposit() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Date endDate = testData.acctPeriods[0].End_Date__c;

            List<Cash_Receipt__c> testCRs = new List<Cash_Receipt__c>();
            Cash_Receipt__c testCashReceipt1 = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Amount__c = 400,
                Payment_Reference__c = 'test_cr1',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c =testData.glAccounts[0].Id,
                Credit_GL_Account__c =testData.glAccounts[1].Id
            );
            testCRs.add(testCashReceipt1);

            Cash_Receipt__c testCashReceipt2 = new Cash_Receipt__c(
                Account__c = testData.accounts[0].Id,
                Amount__c = 400,
                Payment_Reference__c = 'test_cr2',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c =testData.glAccounts[0].Id,
                Credit_GL_Account__c =testData.glAccounts[1].Id
            );
            testCRs.add(testCashReceipt2);

            insert testCRs;

            List<Bank_Deposit__c> testBankDeposits = new List<Bank_Deposit__c>();
            Bank_Deposit__c testBankDeposit1 = new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[0].Start_Date__c,
                Bank_Account__c =testData.glAccounts[0].Id,
                Deposit_Reference__c = 'testBankDeposit1'
            );
            testBankDeposits.add(testBankDeposit1);

            Bank_Deposit__c testBankDeposit2 = new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[0].Start_Date__c,
                Bank_Account__c =testData.glAccounts[0].Id,
                Deposit_Reference__c = 'testBankDeposit2'
            );
            testBankDeposits.add(testBankDeposit2);

            insert testBankDeposits;

            Journal_Entry__c testJournalEntry = new Journal_Entry__c(
                Name = 'Test JE',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Journal_Date__c = testData.acctPeriods[0].Start_Date__c,
                Status__c = 'Approved'
            );

            insert testJournalEntry;

            List<Journal_Entry_Line__c> testJeLines = new List<Journal_Entry_Line__c>();
            Journal_Entry_Line__c testDebitJELine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = testJournalEntry.Id,
                Debit__c = 400,
                Reference__c = 'testDebitJELine1',
                GL_Account__c =testData.glAccounts[0].Id,
                Date__c = testJournalEntry.Journal_Date__c
            );
            testJeLines.add(testDebitJELine1);

            Journal_Entry_Line__c testDebitJELine2 = new Journal_Entry_Line__c(
                Journal_Entry__c = testJournalEntry.Id,
                Debit__c = 400,
                Reference__c = 'testDebitJELine2',
                GL_Account__c =testData.glAccounts[0].Id,
                Date__c = testJournalEntry.Journal_Date__c
            );
            testJeLines.add(testDebitJELine2);

            Journal_Entry_Line__c testCreditJELine1 = new Journal_Entry_Line__c(
                Journal_Entry__c = testJournalEntry.Id,
                Credit__c = 400,
                Reference__c = 'testCreditJELine1',
                GL_Account__c =testData.glAccounts[0].Id,
                Date__c = testJournalEntry.Journal_Date__c
            );
            testJeLines.add(testCreditJELine1);

            Journal_Entry_Line__c testCreditJELine2 = new Journal_Entry_Line__c(
                Journal_Entry__c = testJournalEntry.Id,
                Credit__c = 400,
                Reference__c = 'testCreditJELine2',
                GL_Account__c =testData.glAccounts[0].Id,
                Date__c = testJournalEntry.Journal_Date__c
            );
            testJeLines.add(testCreditJELine2);

            insert testJeLines;

            AbstractPostHandler jePostHandler = new JournalEntryPostHandler();
            List<PostResult> jePostResults = jePostHandler.post(new List<Journal_Entry__c>{testJournalEntry});
            System.assertEquals(true, jePostResults[0].isSuccess);

            //Associate CR with Bank Deposit
            List<BankDepositManager.AssociableRecordWrapper> associableRecords =
                BankDepositManager.getUnassociatedRecords(
                    BankDepositManager.ANY_TYPE,
                    startDate.format(),
                    endDate.format(),
                    (String)testData.glAccounts[0].Id,
                    '', '', '', '',
                    4000,
                    'usd',
                    testData.ledgers[0].Id
                );
            System.assertEquals(6, associableRecords.size());

            List<BankDepositManager.AssociableRecordWrapper> selectedAssociableRecords =
                new List<BankDepositManager.AssociableRecordWrapper>();

            for (BankDepositManager.AssociableRecordWrapper associableRecord : associableRecords) {
                if (associableRecord.reference == 'test_cr2') {
                    associableRecord.selected = true;
                    selectedAssociableRecords.add(associableRecord);
                }
            }

            BankManagerHelper.Money result1 = BankDepositManager.processAssociation(
                selectedAssociableRecords, (String) testBankDeposit1.Id, true
            );

            System.assertEquals(400, result1.recordAmount);
            System.assertEquals(
                testBankDeposit1.Id, [
                    SELECT Id, Bank_Deposit__c
                    FROM Cash_Receipt__c
                    WHERE Id = :selectedAssociableRecords[0].obj.Id
                ].Bank_Deposit__c
            );
            //Associate JE Line with Bank Deposit
            List<BankDepositManager.AssociableRecordWrapper> associableRecords2 =
                BankDepositManager.getUnassociatedRecords(
                    BankDepositManager.ANY_TYPE,
                    startDate.format(),
                    endDate.format(),
                    (String)testData.glAccounts[0].Id,
                    '', '', '', '',
                    4000,
                    'usd',
                    testData.ledgers[0].Id
                );
            System.assertEquals(5, associableRecords2.size());

            List<BankDepositManager.AssociableRecordWrapper> selectedAssociableRecords2 =
                new List<BankDepositManager.AssociableRecordWrapper>();

            for (BankDepositManager.AssociableRecordWrapper associableRecord : associableRecords2) {
                if (associableRecord.reference == 'testDebitJELine2'
                        || associableRecord.reference == 'testCreditJELine2') {

                    associableRecord.selected = true;
                    selectedAssociableRecords2.add(associableRecord);
                }
            }

            BankManagerHelper.Money result2 = BankDepositManager.processAssociation(
                selectedAssociableRecords2, (String) testBankDeposit2.Id, true
            );

            System.assertEquals(0, result2.recordAmount);//400 + (-400)
            System.assertEquals(
                testBankDeposit2.Id, [
                    SELECT Id, Bank_Deposit__c
                    FROM Journal_Entry_Line__c
                    WHERE Id = :selectedAssociableRecords2[0].obj.Id
                ].Bank_Deposit__c
            );

            FinancialTransactionMatchingProvider matchingProvider =
                new FinancialTransactionMatchingProvider(startDate,
                    endDate,
                    NULL,
                    new Set<Decimal>{400.00},
                    testData.ledgers[0].Id,
                   testData.glAccounts[0].Id
                );

            FinancialImportLineWrapper bankTransactionLine = new FinancialImportLineWrapper(
                'externalId',
                'Some Company',
                'credit',
                startDate,
                400.00,
                'USD',
                (String)testData.glAccounts[0].Id
            );

            List<FinancialTransactionMatchingProvider.MatchingRecordWrapper> matchingRecords =
                matchingProvider.getMatchingRecords(bankTransactionLine);

            System.assertEquals(false, matchingRecords.isEmpty());
            System.assertEquals(3, matchingRecords.size());
        }

    }

    @IsTest
    public static void testGetMatchingCreditRecordsWhenLegacyRecordExists() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Receipt__c legacyCR = testData.cashReceipts[2];
            Cash_Receipt__c testCR = testData.cashReceipts[2].clone(false, true, false, false);
            insert testCR;

            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Date endDate = testData.acctPeriods[0].End_Date__c;

            FinancialTransactionMatchingProvider matchingProvider =
                new FinancialTransactionMatchingProvider(
                    startDate,
                    endDate,
                    new Set<Id>{legacyCR.Id},
                    new Set<Decimal>{300.00},
                    testData.ledgers[0].Id,
                   testData.glAccounts[0].Id
                );

            FinancialImportLineWrapper bankTransactionLine = new FinancialImportLineWrapper(
                'externalId',
                'Some Company',
                'credit',
                startDate,
                300,
                'USD',
                (String)testData.glAccounts[0].Id
            );

            List<FinancialTransactionMatchingProvider.MatchingRecordWrapper> matchingRecords =
                matchingProvider.getMatchingRecords(bankTransactionLine);

            System.assertEquals(false, matchingRecords.isEmpty());
            System.assertEquals(1, matchingRecords.size());
            System.assertEquals(testCR.Id, matchingRecords[0].obj.Id);
        }

    }

    @IsTest
    public static void testGetMatchingAccountExists() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Account testAccount = testData.accounts[0];
            testAccount.Accounting_Active__c = true;
            testAccount.Accounting_Type__c = 'Vendor';
            update testAccount;

            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Date endDate = testData.acctPeriods[0].End_Date__c;

            Test.startTest();

            FinancialTransactionMatchingProvider matchingProvider =
                new FinancialTransactionMatchingProvider(startDate,
                    endDate,
                    NULL,
                    new Set<Decimal>{12},
                    testData.ledgers[0].Id,
                   testData.glAccounts[0].Id
                );

            FinancialImportLineWrapper bankTransactionLine = new FinancialImportLineWrapper(
                'externalId',
                'Test Account',
                'debit',
                startDate,
                12,
                'USD',
                (String)testData.glAccounts[0].Id
            );

            Id accountId = matchingProvider.getMatchingVendorId(bankTransactionLine.name);

            System.assertEquals(testAccount.Id, accountId);
        }

    }

    @IsTest
    public static void testPopulateDefaultGLAccountFromAcctSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Account testAccount = testData.accounts[0];
            testAccount.Accounting_Active__c = true;
            testAccount.Accounting_Type__c = 'Vendor';
            update testAccount;

            testData.settings.Default_Vendor__c = testAccount.Id;
            update testData.settings;
            AccountingSettingsHandler.acctSeedSettings = NULL;

            Date startDate = testData.acctPeriods[0].Start_Date__c;
            Date endDate = testData.acctPeriods[0].End_Date__c;

            Test.startTest();

            FinancialTransactionMatchingProvider matchingProvider =
                new FinancialTransactionMatchingProvider(startDate,
                    endDate,
                    NULL,
                    new Set<Decimal>{12},
                    testData.ledgers[0].Id,
                   testData.glAccounts[0].Id
                );

            FinancialImportLineWrapper bankTransactionLine = new FinancialImportLineWrapper(
                'externalId',
                'Some Company Name',
                'debit',
                startDate,
                12,
                'USD',
                (String)testData.glAccounts[0].Id
            );

            Id accountId = matchingProvider.getMatchingVendorId(bankTransactionLine.name);

            System.assertEquals(testData.settings.Default_Vendor__c, accountId);
        }

    }

}