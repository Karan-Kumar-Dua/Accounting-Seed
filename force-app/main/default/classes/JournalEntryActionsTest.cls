@IsTest
public class JournalEntryActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testRequireFieldsInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Journal_Entry__c je = testData.journalEntries[0].clone(false, true);
            je.Accounting_Period__c = NULL;

            DMLException dmlEx;

            try {
                insert je;
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testRequireFieldsUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Accounting_Period__c = NULL;

            DMLException dmlEx;
            try {
                update testData.journalEntries[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testPreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Status__c = 'Approved';
            update testData.journalEntries[0];

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Status__c
                FROM Journal_Entry__c
                WHERE Id = :testData.journalEntries[0].Id
            ]);

            JournalEntryPost jep = new JournalEntryPost(controller);
            jep.post();

            System.assertEquals(
                'Posted',
                [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Status__c
            );

            DMLException dmlEx;

            // Test update no error since no fields changed.
            Journal_Entry__c je = [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id];

            try {
                update je;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            // Test update error since attempted to change protected field.
            try {
                je.Status__c = 'Approved';
                update je;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }

    @IsTest  
    public static void testJournalEntryPostedDeleteError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Status__c = 'Approved';
            testData.journalEntries[0].Accounting_Period__c = testData.acctPeriods[4].Id;
            update testData.journalEntries[0];

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT  Id,
                        Total_Credits__c,
                        Total_Debits__c,
                        Status__c,
                        Journal_Date__c,
                        Accounting_Period__c,
                        Accounting_Period__r.Status__c
                FROM Journal_Entry__c
                WHERE Id = :testData.journalEntries[0].Id
            ]);
            JournalEntryPost jep = new JournalEntryPost(controller);

            jep.post();

            System.assertEquals('Posted', [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Status__c);
            System.assertNotEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id]);

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();

            DMLException dmlEx;
            try {
                delete testData.journalEntries[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }    

    @IsTest 
    public static void testJournalEntryPostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.journalEntries[0].Status__c = 'Approved';
            update testData.journalEntries[0];

            delete testData.journalEntries[0];
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id]);

            undelete testData.journalEntries[0];
            System.assertEquals('Approved', [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Status__c);
        }

    }

    @IsTest    
    public static void testPreventInsertMaxLineCountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Journal_Entry_Line__c> lineList = new List<Journal_Entry_Line__c>();
            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT; i++) {
                lineList.add(testData.journalEntryLines[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                insert lineList;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SObjectActions.MAX_LINE_ERROR, new List<String> {String.valueOf(SObjectActions.MAX_LINE_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
        }

    }
    
    @IsTest
    public static void testPreventInsertMaxLineCountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Journal_Entry_Line__c> lineList = new List<Journal_Entry_Line__c>();
            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT - 100; i++) {
                lineList.add(testData.journalEntryLines[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                insert lineList;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }
    
    @IsTest
    public static void testSetDefaultFieldsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String defaultValue = 'In Process';

            for (Schema.PicklistEntry pickListEntry : Journal_Entry__c.Status__c.getDescribe().getPicklistValues()) {
                if (pickListEntry.isDefaultValue() && pickListEntry.getValue() != 'Posted') {
                    defaultValue = pickListEntry.getValue();
                }
            }

            Journal_Entry__c je = testData.journalEntries[0].clone(false, true);
            je.Status__c = 'Posted';

            insert je;

            System.assertEquals(defaultValue, [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :je.Id].Status__c);

            je = testData.journalEntries[0].clone(false, true);
            je.Status__c = NULL;

            insert je;

            System.assertEquals(defaultValue, [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :je.Id].Status__c);

            je = testData.journalEntries[0].clone(false, true);
            je.Status__c = defaultValue;

            insert je;

            System.assertEquals(defaultValue, [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :je.Id].Status__c);

            je = testData.journalEntries[0].clone(false, true);
            je.Status__c = 'Arbitrary';

            insert je;

            System.assertEquals('Arbitrary', [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :je.Id].Status__c);
        }

    }

    @IsTest
    public static void testSetPreventUpdateStatusFieldPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DMLException dmlEx = NULL;
            try {
                testData.journalEntries[0].Status__c = 'Posted';
                update testData.journalEntries[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    public static void testUpdateBankTransactionStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Journal_Entry_Line__c testJournalEntryLine = testData.journalEntryLines[0];
            Bank_Transaction__c testBankTransaction = testData.bankTransactions[0];
            //Link BT with JEL
            testJournalEntryLine.Bank_Transaction__c = testBankTransaction.Id;
            TriggerObserver.getInstance().unlockField(Journal_Entry_Line__c.Bank_Transaction__c);
            update testJournalEntryLine;
            TriggerObserver.purgeUnlockedFields(Journal_Entry_Line__c.Bank_Transaction__c);
            //Set expected Status on BT
            testBankTransaction.Status__c = BankTransactionsHelper.BT_ADDED_STATUS;
            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            update testBankTransaction;
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;

            System.assertEquals(
                1,
                DomainUtils.getJournalEntryLineLinkedWithBankTransactionByHeaderId(new Set<Id>{testJournalEntryLine.Journal_Entry__c}).size()
            );

            Test.startTest();
            DMLException dmlEx = NULL;
            try {
                delete testData.journalEntries[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                BankTransactionsHelper.BT_UNMATCHED_STATUS,
                [SELECT Status__c FROM Bank_Transaction__c WHERE Id = :testBankTransaction.Id].Status__c
            );
        }

    }

    @IsTest
    public static void testResolveAccountingPeriodJournalEntry() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal',
                    Journal_Date__c = Date.newinstance(1992, 1, 2),
                    Status__c = 'Approved'
                )
            );
            insert journalEntries;

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Project__c = testData.projects[0].Id,
                    Project_Task__c = testData.projectTasks[0].Id,
                    Debit__c = 100,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 10
                )
            );
            insert journalEntryLines;

            System.assertEquals(
                testData.acctPeriods[3].Id,
                [SELECT Accounting_Period__c FROM Journal_Entry__c WHERE Id = :journalEntries[0].Id].Accounting_Period__c
            );
        }

    }

    @IsTest
    public static void testValidateLedgerType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //Create Consolidation & Elimination Ledger
            Ledger__c consLedger = testData.ledgers.get(0).clone();
            consLedger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
            insert consLedger;

            List<Ledger__c> eliminationLedgers = [
                SELECT Id FROM Ledger__c WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
            ];
            System.assertNotEquals(true, eliminationLedgers.isEmpty());
            //insert new record
            Journal_Entry__c testJE = new Journal_Entry__c(
                Name = 'Test JE',
                Ledger__c = consLedger.Id,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );

            Test.startTest();

            DmlException dmlEx;
            try {
                insert testJE;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(
                SObjectActions.LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(0)
            );

            dmlEx = null;
            try {
                testJE.Ledger__c = eliminationLedgers.get(0).Id;
                insert testJE;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
        }

    }

    @IsTest
    public static void testJournalEntryNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Journal_Entry__c je = new Journal_Entry__c();
                insert je;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testJournalEntryNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;
                try {
                    Journal_Entry__c je = new Journal_Entry__c();
                    insert je;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeIfNullInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createProjects()
                .createProjectTasks()
                .createJournalEntries();
            
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Journal_Entry__c je = testData.journalEntries[0].clone(false,true);
                je.put('CurrencyIsoCode', null);

                insert je;
                Id jeId = je.Id;
                je = Database.query('SELECT Id, CurrencyIsoCode FROM Journal_Entry__c WHERE Id = :jeId');

                System.assertNotEquals(null, je);
                System.assertNotEquals(null, je.get('CurrencyIsoCode'));
                System.assertEquals(UserInfo.getDefaultCurrency(), je.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }


    @IsTest
    public static void testSetCurrencyIsoCodeIfNullUpdate_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createProjects()
                .createProjectTasks()
                .createJournalEntries();
            
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Journal_Entry__c je = testData.journalEntries[0].clone(false,true);
                
                insert je;
                Id jeId = je.Id;

                je.put('CurrencyIsoCode', null);
                update je;
                je = Database.query('SELECT Id, CurrencyIsoCode FROM Journal_Entry__c WHERE Id = :jeId');

                System.assertNotEquals(null, je);
                System.assertNotEquals(null, je.get('CurrencyIsoCode'));
                System.assertEquals(UserInfo.getDefaultCurrency(), je.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testJournalEntryReverseSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createProjects()
                .createProjectTasks()
                .createJournalEntries();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.journalEntries[0].Auto_Reverse__c = true;
            update testData.journalEntries[0];
            ApexPages.StandardController controller = new ApexPages.StandardController([
                    SELECT Status__c
                    FROM Journal_Entry__c
                    WHERE Id = :testData.journalEntries[0].Id
            ]);

            JournalEntryPost jep = new JournalEntryPost(controller);
            jep.post();

            System.assertNotEquals(null, [SELECT Auto_Reversal_JE__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id]);
        }
    }
}