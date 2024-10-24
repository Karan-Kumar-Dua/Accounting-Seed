@IsTest
private class BankTransactionsAutomatedAddBatchTest {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
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
            BankTransactionsAutomatedAddBatch batchInstance = new BankTransactionsAutomatedAddBatch(
                testData.bankTransactions
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();

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
            BankTransactionsAutomatedAddBatch batchInstance = new BankTransactionsAutomatedAddBatch(
                testData.bankTransactions
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();

            List<Cash_Disbursement__c> addedCDs = [SELECT Id, Cleared_Date__c FROM Cash_Disbursement__c WHERE Bank_Transaction__c != NULL];
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
            BankTransactionsAutomatedAddBatch batchInstance = new BankTransactionsAutomatedAddBatch(
                testData.bankTransactions
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();

            List<Journal_Entry__c> addedJEs = [SELECT Id FROM Journal_Entry__c];
            System.assertEquals(testData.bankTransactions.size(), addedJEs.size());
            List<Journal_Entry_Line__c> addedJELs = [
                SELECT Id, Bank_Transaction__c, Cleared_Date__c
                FROM Journal_Entry_Line__c
                WHERE Bank_Transaction__c != NULL
            ];
            System.assertEquals(testData.bankTransactions.size(), addedJELs.size());
            System.assertNotEquals(NULL, addedJELs[0].Cleared_Date__c);
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
            BankTransactionsAutomatedAddBatch batchInstance = new BankTransactionsAutomatedAddBatch(
                new List<Bank_Transaction__c>{testBankTransaction}
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();

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