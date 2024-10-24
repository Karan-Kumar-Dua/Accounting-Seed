@IsTest
private class BDCSourceDocumentsFactoryTest {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testInitFactory() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setCashInDefaultSourceRecordType('Cash Receipt')
            .setCashOutDefaultSourceRecordType('Cash Disbursement')
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(testData.bankTransactions);
            System.assertEquals(testData.bankTransactions.size(), sdFactory.bankTransactions.size());
            System.assertEquals(testData.bankTransactions.size(), sdFactory.units.size());

            testData.setCashInDefaultSourceRecordType('Journal Entry');
            testData.setCashOutDefaultSourceRecordType('Journal Entry');

            sdFactory = new BDCSourceDocumentsFactory(testData.bankTransactions);
            System.assertEquals(testData.bankTransactions.size(), sdFactory.bankTransactions.size());
            System.assertEquals(testData.bankTransactions.size(), sdFactory.units.size());
        }
    }

    @IsTest
    private static void testCreateCashReceipts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setCashInDefaultSourceRecordType('Cash Receipt')
            .setCashOutDefaultSourceRecordType('Cash Disbursement')
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            List<Id> glamIds = new List<Id>();
            for (GL_Account_Mapping__c glam : testData.glams) {
                glamIds.add(glam.Id);
            }
            //Create bank rules with actions to populate required fields on source documents
            createBankRuleToPopulateRequiredFieldsOnCashReceipts(
                testData.accounts[0].Id,
                testData.glAccounts[1].Id,
                glamIds
            );

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(testData.bankTransactions);
            System.assertEquals(testData.bankTransactions.size(), sdFactory.bankTransactions.size());
            System.assertEquals(testData.bankTransactions.size(), sdFactory.units.size());

            for (BDCSourceDocumentsFactory.BDCSourceDocumentUnit unit : sdFactory.units) {
                if (unit.isCashReceiptType()) {
                    System.assertEquals(true, unit.cashReceipt.isReadyForSave());
                }
            }

            sdFactory.insertSourceDocuments();

            List<Cash_Receipt__c> addedCRs = [SELECT Id, Cleared_Date__c FROM Cash_Receipt__c WHERE Bank_Transaction__c != NULL];
            System.assertEquals(false, addedCRs.isEmpty());
            System.assertNotEquals(NULL, addedCRs[0].Cleared_Date__c);
        }
    }

    @IsTest
    private static void testCreateCashDisbursements() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setCashInDefaultSourceRecordType('Cash Receipt')
            .setCashOutDefaultSourceRecordType('Cash Disbursement')
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            List<Id> glamIds = new List<Id>();
            for (GL_Account_Mapping__c glam : testData.glams) {
                glamIds.add(glam.Id);
            }
            //Create bank rules with actions to populate required fields on source documents
            createBankRuleToPopulateRequiredFieldsOnCashDisbursement(
                testData.accounts[0].Id,
                testData.glAccounts[1].Id,
                glamIds
            );

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(testData.bankTransactions);
            System.assertEquals(testData.bankTransactions.size(), sdFactory.bankTransactions.size());
            System.assertEquals(testData.bankTransactions.size(), sdFactory.units.size());

            for (BDCSourceDocumentsFactory.BDCSourceDocumentUnit unit : sdFactory.units) {
                if (unit.isCashDisbursementType()) {
                    System.assertEquals(true, unit.cashDisbursement.getRecord().Vendor__c != NULL);
                    System.assertEquals(true, unit.cashDisbursement.getRecord().Debit_GL_Account__c != NULL);
                }
            }

            sdFactory.insertSourceDocuments();

            List<Cash_Disbursement__c> addedCDs =
            [SELECT Id, Cleared_Date__c FROM Cash_Disbursement__c WHERE Bank_Transaction__c != NULL];

            System.assertEquals(false, addedCDs.isEmpty());
            System.assertNotEquals(NULL, addedCDs[0].Cleared_Date__c);
        }
    }

    @IsTest
    private static void testCreateJournalEntries() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setCashInDefaultSourceRecordType('Journal Entry')
            .setCashOutDefaultSourceRecordType('Journal Entry')
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            List<Id> glamIds = new List<Id>();
            for (GL_Account_Mapping__c glam : testData.glams) {
                glamIds.add(glam.Id);
            }
            //Create bank rules with actions to populate required fields on source documents
            createBankRuleToPopulateRequiredFieldsOnCashInJournalEntry(
                testData.glAccounts[1].Id,
                glamIds
            );

            createBankRuleToPopulateRequiredFieldsOnCashOutJournalEntry(
                testData.glAccounts[1].Id,
                glamIds
            );

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(testData.bankTransactions);
            System.assertEquals(testData.bankTransactions.size(), sdFactory.bankTransactions.size());
            System.assertEquals(testData.bankTransactions.size(), sdFactory.units.size());

            for (BDCSourceDocumentsFactory.BDCSourceDocumentUnit unit : sdFactory.units) {
                if (unit.isJournalEntryType()) {
                    System.assertEquals(true, unit.journalEntry.getMainLine().GL_Account__c != NULL);
                }
            }

            sdFactory.insertSourceDocuments();

            List<Journal_Entry__c> addedJEs = [SELECT Id,Name FROM Journal_Entry__c];
            System.assertEquals(testData.bankTransactions.size(), addedJEs.size());
            for(Journal_Entry__c je : addedJEs){
                System.assertEquals(true, je.Name.startsWith('BDC-'));
            }
            List<Journal_Entry_Line__c> addedJELs = [
                SELECT Id, Bank_Transaction__c, Cleared_Date__c
                FROM Journal_Entry_Line__c
            ];
            // * 2 because 2 JELs per added JE
            System.assertEquals(testData.bankTransactions.size() * 2, addedJELs.size());
            for (Journal_Entry_Line__c jel : addedJELs) {
                if (jel.Bank_Transaction__c == null) {
                    // non-bank side null
                    System.assertEquals(null, jel.Cleared_Date__c);
                } 
                else {
                    // bank side not null
                    System.assertNotEquals(null, jel.Cleared_Date__c);
                }
            }
        }
    }

    @IsTest
    private static void testCreateJournalEntryWithRuleAppliedToBothLines() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setCashInDefaultSourceRecordType('Journal Entry')
            .setCashOutDefaultSourceRecordType('Journal Entry')
            .createCashFlowCategories(true)
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {
            //Create GLAM
            GL_Account_Mapping__c testGLAM = new GL_Account_Mapping__c(
                External_Id__c = 'bankAccountId',
                Financial_Institution__c = 'Bank XXX',
                Financial_Institution_Id__c = 'Bank XXX Id',
                GL_Account__c = testData.glAccounts.get(0).Id,
                Ledger__c = testData.ledgers.get(0).Id,
                Inactive__c = false,
                Source__c = BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT
            );
            insert testGLAM;
            //Create Bank Transaction
            Bank_Transaction__c testBankTransaction = new Bank_Transaction__c(
                Account_Id__c = 'bankAccountId',
                Bank_Transaction_Id__c = 'bankTransactionId',
                Container__c = 'creditline',
                Key__c = 'creditline' + 'bankTransactionId',
                Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Base_Type__c = 'Credit',
                Amount__c = 300,
                Description__c = 'Description 1',
                GL_Account_Mapping__c = testGLAM.Id
            );
            insert testBankTransaction;
            //Create Bank Rule
            Bank_Rule__c theBankRule = new Bank_Rule__c(
                Name = 'Cash In JE Rule',
                Active__c = true,
                Priority__c = 1,
                Type__c = 'Cash_In',
                Evaluation_Type__c = 'And',
                Source_Record_Type__c = PACKAGE_QUALIFIER + 'Journal_Entry_Line__c'
            );
            insert theBankRule;

            Bank_Rule_Condition__c theBankRuleCondition = new Bank_Rule_Condition__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'Amount__c',
                Operator__c = 'Greater_Than',
                Amount__c = 100
            );
            insert theBankRuleCondition;

            List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();
            //To set GL Account
            Bank_Rule_Action__c glAccountAction1 = new Bank_Rule_Action__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'GL_Account__c',
                Value__c = '{"' + PACKAGE_QUALIFIER + 'GL_Account__c" : "' + testData.glAccounts[10].Id + '"}'
            );
            actions.add(glAccountAction1);
            //To set Account
            Bank_Rule_Action__c glAccountAction2 = new Bank_Rule_Action__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'Account__c',
                Value__c = '{"' + PACKAGE_QUALIFIER + 'Account__c" : "' + testData.accounts[1].Id + '"}'
            );
            actions.add(glAccountAction2);
            //To set Cash Flow Category
            Bank_Rule_Action__c glAccountAction3 = new Bank_Rule_Action__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
                Value__c = '{"' + PACKAGE_QUALIFIER + 'Cash_Flow_Category__c" : "' + testData.cashFlowCategories[3].Id + '"}'
            );
            actions.add(glAccountAction3);
            //To set GL Variable 1
            Bank_Rule_Action__c glAccountAction4 = new Bank_Rule_Action__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
                Value__c = '{"' + PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c" : "' + testData.accountingVariables1[0].Id + '"}'
            );
            actions.add(glAccountAction4);
            //To set Project
            Bank_Rule_Action__c glAccountAction5 = new Bank_Rule_Action__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'Project__c',
                Value__c = '{"' + PACKAGE_QUALIFIER + 'Project__c" : "' + testData.projects[0].Id + '"}'
            );
            actions.add(glAccountAction5);
            //To set Project Task
            Bank_Rule_Action__c glAccountAction6 = new Bank_Rule_Action__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'Project_Task__c',
                Value__c = '{"' + PACKAGE_QUALIFIER + 'Project_Task__c" : "' + testData.projectTasks[0].Id + '"}'
            );
            actions.add(glAccountAction6);
            //To set Description
            Bank_Rule_Action__c glAccountAction7 = new Bank_Rule_Action__c(
                Bank_Rule__c = theBankRule.Id,
                Target_Field__c = PACKAGE_QUALIFIER + 'Description__c',
                Value__c = '{"' + PACKAGE_QUALIFIER + 'Description__c" : "BR Custom Description"}'
            );
            actions.add(glAccountAction7);

            insert actions;

            createBankRuleGLAMs(theBankRule.Id, new List<Id>{testGLAM.Id});

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(new List<Bank_Transaction__c>{testBankTransaction});
            System.assertEquals(1, sdFactory.bankTransactions.size());
            System.assertEquals(1, sdFactory.units.size());

            for (BDCSourceDocumentsFactory.BDCSourceDocumentUnit unit : sdFactory.units) {
                if (unit.isJournalEntryType()) {
                    System.assertEquals(true, unit.journalEntry.getMainLine().GL_Account__c != NULL);
                    System.assertEquals(true, unit.journalEntry.getOppositeLine().GL_Account__c != NULL);

                    System.assertEquals(true, unit.journalEntry.getMainLine().Account__c != NULL);
                    System.assertEquals(true, unit.journalEntry.getOppositeLine().Account__c != NULL);

                    System.assertEquals(true, unit.journalEntry.getMainLine().Cash_Flow_Category__c != NULL);
                    System.assertEquals(true, unit.journalEntry.getOppositeLine().Cash_Flow_Category__c != NULL);

                    System.assertEquals(true, unit.journalEntry.getMainLine().GL_Account_Variable_1__c != NULL);
                    System.assertEquals(true, unit.journalEntry.getOppositeLine().GL_Account_Variable_1__c != NULL);

                    System.assertEquals(true, unit.journalEntry.getMainLine().Project__c != NULL);
                    System.assertEquals(true, unit.journalEntry.getOppositeLine().Project__c != NULL);

                    System.assertEquals(true, unit.journalEntry.getMainLine().Project_Task__c != NULL);
                    System.assertEquals(true, unit.journalEntry.getOppositeLine().Project_Task__c != NULL);

                    System.assertEquals(true, unit.journalEntry.getMainLine().Description__c != NULL);
                    System.assertEquals(true, unit.journalEntry.getOppositeLine().Description__c != NULL);
                }
            }

            sdFactory.insertSourceDocuments();

            List<Journal_Entry__c> addedJEs = [SELECT Id FROM Journal_Entry__c];
            System.assertEquals(1, addedJEs.size());
            List<Journal_Entry_Line__c> addedMainJELs = [
                SELECT Id, Bank_Transaction__c, Cleared_Date__c, GL_Account__c, Account__c, Cash_Flow_Category__c,
                        GL_Account_Variable_1__c, Project__c, Project_Task__c, Description__c
                FROM Journal_Entry_Line__c
                WHERE Bank_Transaction__c != NULL
            ];
            List<Journal_Entry_Line__c> addedOppositeJELs = [
                SELECT Id, Bank_Transaction__c, Cleared_Date__c, GL_Account__c, Account__c, Cash_Flow_Category__c,
                    GL_Account_Variable_1__c, Project__c, Project_Task__c, Description__c
                FROM Journal_Entry_Line__c
                WHERE Bank_Transaction__c = NULL
            ];
            System.assertEquals(1, addedMainJELs.size());
            System.assertEquals(1, addedOppositeJELs.size());

            System.assertEquals(true, addedMainJELs[0].GL_Account__c != NULL);
            System.assertEquals(true, addedOppositeJELs[0].GL_Account__c != NULL);

            System.assertEquals(true, addedMainJELs[0].Account__c == testData.accounts[1].Id);
            System.assertEquals(true, addedOppositeJELs[0].Account__c == testData.accounts[1].Id);

            System.assertEquals(true, addedMainJELs[0].Cash_Flow_Category__c == testData.cashFlowCategories[3].Id);
            System.assertEquals(true, addedOppositeJELs[0].Cash_Flow_Category__c == testData.cashFlowCategories[3].Id);

            System.assertEquals(true, addedMainJELs[0].GL_Account_Variable_1__c == testData.accountingVariables1[0].Id);
            System.assertEquals(true, addedOppositeJELs[0].GL_Account_Variable_1__c == testData.accountingVariables1[0].Id);

            System.assertEquals(true, addedMainJELs[0].Project__c == testData.projects[0].Id);
            System.assertEquals(true, addedOppositeJELs[0].Project__c == testData.projects[0].Id);

            System.assertEquals(true, addedMainJELs[0].Project_Task__c == testData.projectTasks[0].Id);
            System.assertEquals(true, addedOppositeJELs[0].Project_Task__c == testData.projectTasks[0].Id);

            System.assertEquals(true, addedMainJELs[0].Description__c == 'BR Custom Description');
            System.assertEquals(true, addedOppositeJELs[0].Description__c == 'BR Custom Description');
        }
    }

    @IsTest
    private static void testCreateCashDisbursementWithAccountMatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .setCashInDefaultSourceRecordType('Cash Receipt')
            .setCashOutDefaultSourceRecordType('Cash Disbursement')
            .createAccountingVariables()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[17].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Bank_Transaction__c tx = testData.bankTransactions[1].clone(false, true, false, false);
            tx.Description__c = a.Name;
            tx.Bank_Transaction_Id__c = '1010101010';
            tx.Key__c = tx.Container__c + tx.Bank_Transaction_Id__c;
            insert tx;

            Bank_Transaction__c[] txs = new Bank_Transaction__c[]{ tx };

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(txs);
            sdFactory.insertSourceDocuments();
            Test.stopTest();

            List<Cash_Disbursement__c> addedCDs = [
                SELECT 
                    Cleared_Date__c
                  , Vendor__c
                  , Debit_GL_Account__c
                  , GL_Account_Variable_1__c
                  , GL_Account_Variable_2__c
                  , GL_Account_Variable_3__c
                  , GL_Account_Variable_4__c
                FROM Cash_Disbursement__c 
                WHERE Bank_Transaction__c = :tx.Id
            ];

            System.assertEquals(txs.size(), addedCDs.size());
            Cash_Disbursement__c cd = addedCDs[0];
            System.assertNotEquals(null, cd.Cleared_Date__c);
            System.assertEquals(a.Id, cd.Vendor__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, cd.Debit_GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, cd.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cd.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cd.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testCreateCashDisbursementWithBankRuleAndAccountMatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .setCashInDefaultSourceRecordType('Cash Receipt')
            .setCashOutDefaultSourceRecordType('Cash Disbursement')
            .createAccountingVariables()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            List<Id> glamIds = new List<Id>();
            for (GL_Account_Mapping__c glam : testData.glams) {
                glamIds.add(glam.Id);
            }

            createBankRuleToPopulateFieldOnCashDisbursement(
                'GL_Account_Variable_1__c',
                testData.accountingVariables1[1].Id,
                glamIds
            );

            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[17].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Bank_Transaction__c tx = testData.bankTransactions[1].clone(false, true, false, false);
            tx.Description__c = a.Name;
            tx.Bank_Transaction_Id__c = '1010101010';
            tx.Key__c = tx.Container__c + tx.Bank_Transaction_Id__c;
            insert tx;

            Bank_Transaction__c[] txs = new Bank_Transaction__c[]{ tx };

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(txs);
            sdFactory.insertSourceDocuments();
            Test.stopTest();

            List<Cash_Disbursement__c> addedCDs = [
                SELECT 
                    Cleared_Date__c
                  , Vendor__c
                  , Debit_GL_Account__c
                  , GL_Account_Variable_1__c
                  , GL_Account_Variable_2__c
                  , GL_Account_Variable_3__c
                  , GL_Account_Variable_4__c
                FROM Cash_Disbursement__c 
                WHERE Bank_Transaction__c = :tx.Id
            ];

            System.assertEquals(txs.size(), addedCDs.size());
            Cash_Disbursement__c cd = addedCDs[0];
            System.assertNotEquals(null, cd.Cleared_Date__c);
            System.assertEquals(a.Id, cd.Vendor__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, cd.Debit_GL_Account__c);
            System.assertEquals(testData.accountingVariables1[1].Id, cd.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cd.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cd.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cd.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testCreateCashReceiptWithAccountMatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enablePrePopulateAccountInfo()
            .setCashInDefaultSourceRecordType('Cash Receipt')
            .setCashOutDefaultSourceRecordType('Cash Disbursement')
            .createAccountingVariables()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Bank_Transaction__c tx = testData.bankTransactions[0].clone(false, true, false, false);
            tx.Description__c = a.Name;
            tx.Bank_Transaction_Id__c = '1010101010';
            tx.Key__c = tx.Container__c + tx.Bank_Transaction_Id__c;
            insert tx;

            Bank_Transaction__c[] txs = new Bank_Transaction__c[]{ tx };

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(txs);
            sdFactory.units.get(0).cashReceipt.getRecord().put('Credit_GL_Account__c', testData.glAccounts[28].Id);
            sdFactory.insertSourceDocuments();
            Test.stopTest();

            List<Cash_Receipt__c> addedCRs = [
                SELECT 
                    Cleared_Date__c
                  , Account__c
                  , GL_Account_Variable_1__c
                  , GL_Account_Variable_2__c
                  , GL_Account_Variable_3__c
                  , GL_Account_Variable_4__c
                FROM Cash_Receipt__c 
                WHERE Bank_Transaction__c = :tx.Id
            ];

            System.assertEquals(txs.size(), addedCRs.size());
            Cash_Receipt__c cr = addedCRs[0];
            System.assertNotEquals(null, cr.Cleared_Date__c);
            System.assertEquals(a.Id, cr.Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, cr.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, cr.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, cr.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, cr.GL_Account_Variable_4__c);
        }
    }

    @IsTest
    private static void testCreateJournalEntryWithAccountMatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .enablePrePopulateAccountInfo()
        .setCashInDefaultSourceRecordType('Journal Entry')
        .setCashOutDefaultSourceRecordType('Journal Entry')
        .createCashFlowCategories(true)
        .createAccountingVariables()
        .createProjects()
        .createProjectTasks()
        .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Account a = testData.accounts[2];
            a.Accounting_Type__c = 'Customer and Vendor';
            a.Default_Expense_GL_Account__c = testData.glAccounts[17].Id;
            a.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            a.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            a.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            a.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update a;

            Bank_Transaction__c tx = testData.bankTransactions[1].clone(false, true, false, false);
            tx.Description__c = a.Name;
            tx.Bank_Transaction_Id__c = '1010101010';
            tx.Key__c = tx.Container__c + tx.Bank_Transaction_Id__c;
            insert tx;

            Bank_Transaction__c[] txs = new Bank_Transaction__c[]{ tx };

            Test.startTest();
            BDCSourceDocumentsFactory sdFactory = new BDCSourceDocumentsFactory(txs);
            sdFactory.insertSourceDocuments();
            Test.stopTest();

            List<Journal_Entry_Line__c> jels = [
                SELECT 
                    Cleared_Date__c
                  , Account__c
                  , GL_Account__c
                  , GL_Account_Variable_1__c
                  , GL_Account_Variable_2__c
                  , GL_Account_Variable_3__c
                  , GL_Account_Variable_4__c
                  , Credit__c
                FROM Journal_Entry_Line__c 
                WHERE Bank_Transaction__c = :tx.Id
                OR GL_Account__c = :a.Default_Expense_GL_Account__c
            ];

            System.assertEquals(2, jels.size());

            Journal_Entry_Line__c credit, debit;
            if (jels[0].Credit__c > 0) {
                credit = jels[0];
                debit = jels[1];
            } else {
                credit = jels[1];
                debit = jels[0];
            }

            System.assertNotEquals(null, credit.Cleared_Date__c);
            System.assertEquals(a.Id, credit.Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, credit.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, credit.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, credit.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, credit.GL_Account_Variable_4__c);

            System.assertEquals(null, debit.Cleared_Date__c);
            System.assertEquals(a.Id, debit.Account__c);
            System.assertEquals(a.Default_Expense_GL_Account__c, debit.GL_Account__c);
            System.assertEquals(a.GL_Account_Variable_1__c, debit.GL_Account_Variable_1__c);
            System.assertEquals(a.GL_Account_Variable_2__c, debit.GL_Account_Variable_2__c);
            System.assertEquals(a.GL_Account_Variable_3__c, debit.GL_Account_Variable_3__c);
            System.assertEquals(a.GL_Account_Variable_4__c, debit.GL_Account_Variable_4__c);
        }
    }

    private static void createBankRuleToPopulateRequiredFieldsOnCashReceipts(Id accountId, Id glAccountId, List<Id> glamIds) {
        Bank_Rule__c theBankRule = new Bank_Rule__c(
            Name = 'Cash In CR Rule',
            Active__c = true,
            Priority__c = 1,
            Type__c = 'Cash_In',
            Evaluation_Type__c = 'And',
            Source_Record_Type__c = PACKAGE_QUALIFIER + 'Cash_Receipt__c'
        );
        insert theBankRule;

        Bank_Rule_Condition__c theBankRuleCondition = new Bank_Rule_Condition__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Amount__c',
            Operator__c = 'Greater_Than',
            Amount__c = 0
        );
        insert theBankRuleCondition;

        List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();
        Bank_Rule_Action__c accountAction = new Bank_Rule_Action__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Account__c',
            Value__c = '{"' + PACKAGE_QUALIFIER + 'Account__c" : "' + accountId + '"}'
        );
        actions.add(accountAction);
        Bank_Rule_Action__c creditGlAccountAction = new Bank_Rule_Action__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Credit_GL_Account__c',
            Value__c = '{"' + PACKAGE_QUALIFIER + 'Credit_GL_Account__c" : "' + glAccountId + '"}'
        );
        actions.add(creditGlAccountAction);
        insert actions;

        createBankRuleGLAMs(theBankRule.Id, glamIds);

        System.assertEquals(false, [SELECT Id FROM Bank_Rule__c WHERE Name = :theBankRule.Name].isEmpty());
    }

    private static void createBankRuleToPopulateFieldOnCashDisbursement(String field, String val, List<Id> glamIds) {
        Bank_Rule__c theBankRule = new Bank_Rule__c(
            Name = 'Cash Out CD Rule',
            Active__c = true,
            Priority__c = 1,
            Type__c = 'Cash_Out',
            Evaluation_Type__c = 'And',
            Source_Record_Type__c = PACKAGE_QUALIFIER + 'Cash_Disbursement__c'
        );
        insert theBankRule;

        Bank_Rule_Condition__c theBankRuleCondition = new Bank_Rule_Condition__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Amount__c',
            Operator__c = 'Greater_Than',
            Amount__c = 0
        );
        insert theBankRuleCondition;

        List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();
        Bank_Rule_Action__c accountAction = new Bank_Rule_Action__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + field,
            Value__c = '{"' + PACKAGE_QUALIFIER + field + '" : "' + val + '"}'
        );
        actions.add(accountAction);
        insert actions;

        createBankRuleGLAMs(theBankRule.Id, glamIds);

        System.assertEquals(false, [SELECT Id FROM Bank_Rule__c WHERE Name = :theBankRule.Name].isEmpty());
    }

    private static void createBankRuleToPopulateRequiredFieldsOnCashDisbursement(Id accountId, Id glAccountId, List<Id> glamIds) {
        Bank_Rule__c theBankRule = new Bank_Rule__c(
            Name = 'Cash Out CD Rule',
            Active__c = true,
            Priority__c = 1,
            Type__c = 'Cash_Out',
            Evaluation_Type__c = 'And',
            Source_Record_Type__c = PACKAGE_QUALIFIER + 'Cash_Disbursement__c'
        );
        insert theBankRule;

        Bank_Rule_Condition__c theBankRuleCondition = new Bank_Rule_Condition__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Amount__c',
            Operator__c = 'Greater_Than',
            Amount__c = 0
        );
        insert theBankRuleCondition;

        List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();
        Bank_Rule_Action__c accountAction = new Bank_Rule_Action__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Vendor__c',
            Value__c = '{"' + PACKAGE_QUALIFIER + 'Vendor__c" : "' + accountId + '"}'
        );
        actions.add(accountAction);
        Bank_Rule_Action__c creditGlAccountAction = new Bank_Rule_Action__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Debit_GL_Account__c',
            Value__c = '{"' + PACKAGE_QUALIFIER + 'Debit_GL_Account__c" : "' + glAccountId + '"}'
        );
        actions.add(creditGlAccountAction);
        insert actions;

        createBankRuleGLAMs(theBankRule.Id, glamIds);

        System.assertEquals(false, [SELECT Id FROM Bank_Rule__c WHERE Name = :theBankRule.Name].isEmpty());
    }

    private static void createBankRuleToPopulateRequiredFieldsOnCashInJournalEntry(Id glAccountId, List<Id> glamIds) {
        Bank_Rule__c theBankRule = new Bank_Rule__c(
            Name = 'Cash In JE Rule',
            Active__c = true,
            Priority__c = 1,
            Type__c = 'Cash_In',
            Evaluation_Type__c = 'And',
            Source_Record_Type__c = PACKAGE_QUALIFIER + 'Journal_Entry_Line__c'
        );
        insert theBankRule;

        Bank_Rule_Condition__c theBankRuleCondition = new Bank_Rule_Condition__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Amount__c',
            Operator__c = 'Greater_Than',
            Amount__c = 0
        );
        insert theBankRuleCondition;

        List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();
        Bank_Rule_Action__c glAccountAction = new Bank_Rule_Action__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'GL_Account__c',
            Value__c = '{"' + PACKAGE_QUALIFIER + 'GL_Account__c" : "' + glAccountId + '"}'
        );
        actions.add(glAccountAction);
        insert actions;

        createBankRuleGLAMs(theBankRule.Id, glamIds);

        System.assertEquals(false, [SELECT Id FROM Bank_Rule__c WHERE Name = :theBankRule.Name].isEmpty());
    }

    private static void createBankRuleToPopulateRequiredFieldsOnCashOutJournalEntry(Id glAccountId, List<Id> glamIds) {
        Bank_Rule__c theBankRule = new Bank_Rule__c(
            Name = 'Cash Out JE Rule',
            Active__c = true,
            Priority__c = 1,
            Type__c = 'Cash_Out',
            Evaluation_Type__c = 'And',
            Source_Record_Type__c = PACKAGE_QUALIFIER + 'Journal_Entry_Line__c'
        );
        insert theBankRule;

        Bank_Rule_Condition__c theBankRuleCondition = new Bank_Rule_Condition__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'Amount__c',
            Operator__c = 'Greater_Than',
            Amount__c = 0
        );
        insert theBankRuleCondition;

        List<Bank_Rule_Action__c> actions = new List<Bank_Rule_Action__c>();
        Bank_Rule_Action__c glAccountAction = new Bank_Rule_Action__c(
            Bank_Rule__c = theBankRule.Id,
            Target_Field__c = PACKAGE_QUALIFIER + 'GL_Account__c',
            Value__c = '{"' + PACKAGE_QUALIFIER + 'GL_Account__c" : "' + glAccountId + '"}'
        );
        actions.add(glAccountAction);
        insert actions;

        createBankRuleGLAMs(theBankRule.Id, glamIds);

        System.assertEquals(false, [SELECT Id FROM Bank_Rule__c WHERE Name = :theBankRule.Name].isEmpty());
    }

    private static void createBankRuleGLAMs(Id bankRuleId, List<Id> glamIds) {
        List<Bank_Rule_GLAM__c> brGLAMs = new List<Bank_Rule_GLAM__c>();
        for (Id glamId : glamIds) {
            Bank_Rule_GLAM__c brGLAM = new Bank_Rule_GLAM__c(
                Bank_Rule__c = bankRuleId,
                GL_Account_Mapping__c = glamId
            );
            brGLAMs.add(brGLAM);
        }
        insert brGLAMs;
    }

}