@IsTest
public class LedgerActionsTest {

    private static Ledger__c createTestLedger(TestDataSuite testData) {
        Ledger__c testLedger = new Ledger__c(
            Name = 'Actual Test',
            Type__c = 'Transactional',
            Default_Bank_Account__c = testData.glAccounts[0].Id,
            Default_Billing_Format__c = testData.billingFormats[0].Id,
            Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
            Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
        );
        return testLedger;
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
 
    @IsTest
    public static void testLedgerActionsTypeFieldRequiredError() {
        
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Budget 2014';
        ledger.Type__c = null;
        
        DmlException dmlEx;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testTransactionalFieldsRequiredError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT,25);
        
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Transactional Test';
        ledger.Type__c ='Transactional';

        DmlException dmlEx;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

        ledger.Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id;
        dmlEx = null;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

        ledger.Default_Bank_Account__c = testData.glAccounts[0].Id;
        dmlEx = null;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

        ledger.Default_Billing_Format__c = testData.billingFormats[0].Id;
        dmlEx = null;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

        ledger.Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id;
        dmlEx = null;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(null, dmlEx);
    }

    @IsTest
    public static void testPreventMaxQuantityError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT,25);

        Test.startTest();
        List<Ledger__c> ledgers = new List<Ledger__c>();
        for (Integer i = 0; i <= 30; i++) {
            Ledger__c ledger = new Ledger__c();
            ledger.Name = 'Transactional Test' + i;
            ledger.Type__c ='Transactional';
            ledger.Default_Bank_Account__c = testData.glAccounts[0].Id;
            ledger.Default_Billing_Format__c = testData.billingFormats[0].Id;
            ledger.Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id;
            ledger.Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id;
            ledgers.add(ledger);
        }

        DmlException dmlEx;
        try {
            insert ledgers;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(String.format(LedgerActions.MAX_QUANTITY_ERROR, new List<String>{'25'}), dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventMaxQuantityOnlyForTransactionalType() {
        TestDataSuite testData = TestDataSuite.getInstance();
        AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT,10);

        Test.startTest();
        List<Ledger__c> allLedgerByType = DomainUtils.getLedgerByType(
            new Set<String> {LedgerActions.LEDGER_TYPE_TRANSACTIONAL, LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL}
        );

        System.assertEquals(5, allLedgerByType.size());

        List<Ledger__c> ledgers = new List<Ledger__c>();
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Transactional Test 1';
        ledger.Type__c = LedgerActions.LEDGER_TYPE_TRANSACTIONAL;
        ledger.Default_Bank_Account__c = testData.glAccounts[0].Id;
        ledger.Default_Billing_Format__c = testData.billingFormats[0].Id;
        ledger.Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id;
        ledger.Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id;
        ledgers.add(ledger);

        Ledger__c ledger2 = new Ledger__c();
        ledger2.Name = 'Transactional Test 2';
        ledger2.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
        ledger2.Default_Bank_Account__c = testData.glAccounts[0].Id;
        ledger2.Default_Billing_Format__c = testData.billingFormats[0].Id;
        ledger2.Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id;
        ledger2.Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id;
        ledgers.add(ledger2);

        Ledger__c ledger3 = new Ledger__c();
        ledger3.Name = 'Budget Test 1';
        ledger3.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET;
        ledgers.add(ledger3);

        Ledger__c ledger4 = new Ledger__c();
        ledger4.Name = 'Budget Test 2';
        ledger4.Type__c = LedgerActions.LEDGER_TYPE_BUDGET;
        ledgers.add(ledger4);


        DmlException dmlEx;
        try {
            insert ledgers;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }

        System.assertEquals(null, dmlEx);
    }

    @IsTest
    public static void testLedgerActionsTypeFieldRequiredSuccess() {
        
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Budget 2014';
        ledger.Type__c = 'Budget';
        
        DmlException dmlEx;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(null, dmlEx);
    }

    @IsTest
    public static void testPreventChangeTypeTransactionalToBudget() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        DmlException dmlEx;
        try {
            testData.ledgers[0].Type__c = LedgerActions.LEDGER_TYPE_BUDGET;
            update testData.ledgers[0];
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.TYPE_CHANGE_FC_OR_LH_EXISTS_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventChangeTypeTransactionalToConsolidation() {
        TestDataSuite testData = TestDataSuite.getInstance();

        DmlException dmlEx;
        try {
            testData.ledgers[0].Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
            update testData.ledgers[0];
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.TYPE_CHANGE_TO_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventChangeTypeConsolidationsToTransactional() {
        TestDataSuite testData = TestDataSuite.getInstance().createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            Ledger__c consLedger = [
                SELECT Id, Type__c
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL
                LIMIT 1
            ];

            DmlException dmlEx;
            try {
                consLedger.Type__c = LedgerActions.LEDGER_TYPE_TRANSACTIONAL;
                update consLedger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(LedgerActions.TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventCurrencyChange() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Ledger__c actualLedger = testData.ledgers[0];
                actualLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                DmlException dmlEx;
                try {
                    update actualLedger;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }
                System.assertEquals(LedgerActions.CURRENCY_CHANGE_ERROR, dmlEx.getDmlMessage(0));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testLedgerNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            try {
                Ledger__c led = new Ledger__c();
                insert led;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            if (dmlEx != null) {
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
    }

    @IsTest
    public static void testLedgerNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DmlException dmlEx;
                try {
                    Ledger__c led = new Ledger__c();
                    insert led;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                if (dmlEx != null) {
                    System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
                }
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testPreventLedgerWithRelatedPayablesDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        Test.startTest();
        LedgerHandler.reset();
        Ledger__c testLedger = createTestLedger(testData);
        insert testLedger;

        Account_Payable__c newItem = testData.payables[0].clone(false);
        newItem.Ledger__c = testLedger.Id;
        newItem.Payee_Reference__c = 'test ref';
        insert newItem;

        System.assertEquals(1, [SELECT Id FROM Account_Payable__c WHERE Ledger__c = :testLedger.Id].size());

        DmlException dmlEx;
        try {
            delete testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventLedgerWithRelatedBillingsDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        Test.startTest();
        LedgerHandler.reset();
        Ledger__c testLedger = createTestLedger(testData);
        insert testLedger;

        Billing__c newItem = testData.billings[0].clone(false);
        newItem.Ledger__c = testLedger.Id;
        insert newItem;

        System.assertEquals(1, [SELECT Id FROM Billing__c WHERE Ledger__c = :testLedger.Id].size());

        DmlException dmlEx;
        try {
            delete testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventLedgerWithRelatedCashReceiptsDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        Test.startTest();
        LedgerHandler.reset();
        Ledger__c testLedger = createTestLedger(testData);
        insert testLedger;

        Cash_Receipt__c newItem = testData.cashReceipts[0].clone(false);
        newItem.Ledger__c = testLedger.Id;
        insert newItem;

        System.assertEquals(1, [SELECT Id FROM Cash_Receipt__c WHERE Ledger__c = :testLedger.Id].size());

        DmlException dmlEx;
        try {
            delete testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventLedgerWithRelatedCashDisbursementsDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();
        Test.startTest();
        LedgerHandler.reset();
        Ledger__c testLedger = createTestLedger(testData);

        insert testLedger;

        Cash_Disbursement__c newItem = testData.cashDisbursements[0].clone(false);
        newItem.Ledger__c = testLedger.Id;

        insert newItem;

        System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Ledger__c = :testLedger.Id].size());

        DmlException dmlEx;
        try {
            delete testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventLedgerWithRelatedJournalEntriesDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();
        LedgerHandler.reset();
        Ledger__c testLedger = createTestLedger(testData);

        insert testLedger;

        Journal_Entry__c newItem = testData.journalEntries[0].clone(false);
        newItem.Ledger__c = testLedger.Id;

        insert newItem;

        System.assertEquals(1, [SELECT Id FROM Journal_Entry__c WHERE Ledger__c = :testLedger.Id].size());

        DmlException dmlEx;
        try {
            delete testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventLedgerWithRelatedTimeCardsDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();
        Test.startTest();
        LedgerHandler.reset();
        Ledger__c testLedger = createTestLedger(testData);

        insert testLedger;

        Time_Card__c newItem = testData.timeCards[0].clone(false);
        newItem.Ledger__c = testLedger.Id;

        insert newItem;

        System.assertEquals(1, [SELECT Id FROM Time_Card__c WHERE Ledger__c = :testLedger.Id].size());

        DmlException dmlEx;
        try {
            delete testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventLedgerWithRelatedExpenseReportsDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createExpenseReports();
        LedgerHandler.reset();
        Ledger__c testLedger = createTestLedger(testData);

        insert testLedger;

        Expense_Report__c newItem = testData.expenseReports[0].clone(false);
        newItem.Ledger__c = testLedger.Id;

        insert newItem;

        System.assertEquals(1, [SELECT Id FROM Expense_Report__c WHERE Ledger__c = :testLedger.Id].size());

        DmlException dmlEx;
        try {
            delete testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testLedgerHandlerCachedQueryResults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            LedgerHandler.getInstanceWithoutSharing();//1 SOQL query to fill the cache
            LedgerHandler.getInstanceWithSharing();//1 SOQL query to fill the cache
            LedgerHandler.getInstanceWithSharing(true);//1 SOQL to fill the cache
            //count total SOQL queries made at this point
            Integer queriesExecuted = Limits.getQueries();
            //no more SOQL queries expected because we have full set of cached data at this point
            LedgerHandler.getInstanceWithoutSharing();//no SOQL query - cached date is used
            LedgerHandler.getInstanceWithSharing();//no SOQL query - cached date is used
            LedgerHandler.getInstanceWithSharing(true);//no SOQL query - cached date is used

            System.assertEquals(queriesExecuted, Limits.getQueries());
        }
    }

    @IsTest
    public static void testInsertEliminationForConsolidation() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Consolidation-TR';
        ledger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
        
        DmlException dmlEx;
        System.runAs(testData.users.get(1)) {
            try {
                insert ledger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);

            Ledger__c eliminationLedger = [
                SELECT Id, Consolidation_Ledger_ID__c, Name
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                AND Consolidation_Ledger_ID__c = :ledger.Id
            ];
            System.assertEquals(ledger.Name + ' - EL', eliminationLedger.Name);
            System.assertEquals(ledger.Id, eliminationLedger.Consolidation_Ledger_ID__c);
        }
    }

    @IsTest
    public static void testUpdateEliminationAfterConsolidation() {
        TestDataSuite testData = TestDataSuite.getInstance();

        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Consolidation-TR';
        ledger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;

        System.runAs(testData.users.get(1)) {
            insert ledger;
            System.assertEquals(
                    LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                    [SELECT Accounting_Method__c FROM Ledger__c WHERE Id =: ledger.Id LIMIT 1].Accounting_Method__c
            );
            System.assertEquals(
                    LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                    [SELECT Accounting_Method__c FROM Ledger__c WHERE Consolidation_Ledger_ID__c =: ledger.Id LIMIT 1].Accounting_Method__c
            );

            ledger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_CASH;
            upsert ledger;
            System.assertEquals(
                    LedgerActions.ACCOUNTING_METHOD_CASH,
                    [SELECT Accounting_Method__c FROM Ledger__c WHERE Id =: ledger.Id LIMIT 1].Accounting_Method__c
            );
            System.assertEquals(
                    LedgerActions.ACCOUNTING_METHOD_CASH,
                    [SELECT Accounting_Method__c FROM Ledger__c WHERE Consolidation_Ledger_ID__c =: ledger.Id LIMIT 1].Accounting_Method__c
            );

            ledger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            upsert ledger;
            System.assertEquals(
                    LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                    [SELECT Accounting_Method__c FROM Ledger__c WHERE Id =: ledger.Id LIMIT 1].Accounting_Method__c
            );
            System.assertEquals(
                    LedgerActions.ACCOUNTING_METHOD_ACCRUAL,
                    [SELECT Accounting_Method__c FROM Ledger__c WHERE Consolidation_Ledger_ID__c =: ledger.Id LIMIT 1].Accounting_Method__c
            );
        }
    }

    @IsTest
    public static void testInsertEliminationForConsolidationLongName(){
        TestDataSuite testData = TestDataSuite.getInstance();
        
        Ledger__c ledger = new Ledger__c();
        ledger.Name = '';
        for (Integer i = 0; i < 80; i++) {
            ledger.Name += 'x';
        }
        ledger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
        
        DmlException dmlEx;
        System.runAs(testData.users.get(1)) {
            try {
                insert ledger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);

            Ledger__c eliminationLedger = [
                SELECT Id, Consolidation_Ledger_ID__c, Name
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                AND Consolidation_Ledger_ID__c = :ledger.Id
            ];
            System.assertEquals(ledger.Name.left(75) + ' - EL', eliminationLedger.Name);
            System.assertEquals(ledger.Id, eliminationLedger.Consolidation_Ledger_ID__c);
        }

    }

    @IsTest
    public static void testDeleteEliminationForConsolidation() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Consolidation-TR';
        ledger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
        insert ledger;

        Ledger__c eliminationLedger = [
            SELECT Id, Consolidation_Ledger_ID__c, Name
            FROM Ledger__c
            WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
            AND Consolidation_Ledger_ID__c = :ledger.Id
        ];
        System.assertEquals(ledger.Id, eliminationLedger.Consolidation_Ledger_ID__c);

        DmlException dmlEx;
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                delete ledger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);

            Ledger__c deletedConsolidationLedger = [SELECT Id, IsDeleted FROM Ledger__c WHERE Id = :ledger.Id ALL ROWS ];
            System.assertEquals(deletedConsolidationLedger.IsDeleted, true);

            Ledger__c deletedEliminationLedger = [SELECT Id, IsDeleted FROM Ledger__c WHERE Id = :eliminationLedger.Id ALL ROWS];
            System.assertEquals(deletedEliminationLedger.IsDeleted, true);
        }
    }

    @IsTest
    public static void testPreventEliminationLedgerDelete(){
        TestDataSuite testData = TestDataSuite.getInstance();
        
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Consolidation-TR';
        ledger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
        insert ledger;

        Ledger__c eliminationLedger = [
            SELECT Id, Consolidation_Ledger_ID__c, Name
            FROM Ledger__c
            WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
            AND Consolidation_Ledger_ID__c = :ledger.Id
        ];

        DmlException dmlEx;
        System.runAs(testData.users.get(1)) {
            try {
                delete eliminationLedger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(LedgerActions.ELIMINATIONS_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventLedgerWithRelatedLedgerHierarchy() {
        TestDataSuite testData = TestDataSuite.getInstance();

        Ledger__c testLedger = new Ledger__c(
            Name = 'Consolidation Test',
            Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL
        );
        insert testLedger;

        Ledger_Hierarchy__c lH = new Ledger_Hierarchy__c(
           Name = 'Consolidation',
           Ledger__c = testLedger.Id,
           Last_Period__c = testData.acctPeriods[0].Id,
           Last_Run__c = Datetime.now()
        );
        insert lH;

        System.assertEquals(1, [SELECT Id FROM Ledger_Hierarchy__c WHERE Ledger__c = :testLedger.Id].size());

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            try {
                delete testLedger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(LedgerActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventEliminationLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Ledger__c testLedger = new Ledger__c(
                Name = 'Elimination Test',
                Type__c = LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
            );

            DmlException dmlEx;
            try {
                insert testLedger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(LedgerActions.MANUAL_ELIMINATION_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventChangeTypeConsolidationsTransactionalToAnother() {
        TestDataSuite testData = TestDataSuite.getInstance().createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            Ledger__c consLedger = [
                SELECT Id, Type__c
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL
                LIMIT 1
            ];

            DmlException dmlEx;
            try {
                consLedger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET;
                update consLedger;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(LedgerActions.TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testCreateGLAccountDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Ledger__c budgetLedger = new Ledger__c(
                Name = 'Budget Test',
                Type__c = 'Budget'
            );

            insert budgetLedger;

            List<GLAccountDefault> result = GLAccount.retrieveDefaults(budgetLedger.Id);

            System.assertEquals(16, result.size());
        }
    }

    @IsTest
    public static void testCreateGLAccountDefaults2() {
        TestDataSuite testData = TestDataSuite.getInstance();

        Ledger_Custom_Settings__c.getOrgDefaults().Ledger_Id__c = testData.ledgers[0].Id;
        update Ledger_Custom_Settings__c.getOrgDefaults();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = DomainUtils.getGlAccountsByName(new List<String> {'4000-Product Revenue'})[0];

            GL_Account__c newGlAccount = glAccount.clone();
            newGlAccount.Name = '4006-Product Revenue';
            newGlAccount.Active__c = true;
            newGlAccount.Type__c = 'Revenue';
            newGlAccount.Sub_Type_1__c = 'Product Revenue';
            newGlAccount.Sub_Type_2__c = 'Product Family 1';
            insert newGlAccount;

            List<GL_Account_Default__c> glAccountDefaults = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE GL_Account_Specification__c =: GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT AND Ledger__c =: testData.ledgers[0].Id
            ];
            glAccountDefaults[0].GL_Account__c = newGlAccount.Id;
            update glAccountDefaults;

            List<GL_Account_Default__c> newGLAccountDefaults = new List<GL_Account_Default__c>{
                new GL_Account_Default__c(
                    GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                    Ledger__c = testData.ledgers[0].Id,
                    GL_Account__c = testData.glAccounts[7].Id
                )
            };
            insert newGLAccountDefaults;
            GLAccountDefaultsHandler.instance = null;
            LedgerHandler.reset();
            Ledger__c budgetLedger = new Ledger__c(
                    Name = 'Budget Test',
                    Type__c = 'Budget'
            );

            insert budgetLedger;

            Map<String, GL_Account_Default__c> glAccountDefaultsBySpecNames =
                    GLAccountDefaultsHandler.instance.glAccountDefaultsMapByLedgerIds.get(budgetLedger.Id);

            System.assertEquals(17, glAccountDefaultsBySpecNames.size());
            System.assertEquals(newGlAccount.Id, glAccountDefaultsBySpecNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT).GL_Account__c);
            System.assertEquals(testData.glAccounts[7].Id, glAccountDefaultsBySpecNames.get(GLAccountDefaultsHandler.CTA_GL_ACCOUNT).GL_Account__c);
        }
    }




    @IsTest 
    public static void testInsertLedgerFieldRestrictOnPaymentFeatureDisable(){
        TestDataSuite testData = TestDataSuite.getInstance();
        AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT,25);
                
        System.runAs(testData.users[1]) {
            Test.startTest();
                
            try {
                Ledger__c ledger = testData.ledgers[0].clone(false, true);
                ledger.Enrolled_in_Payment_Services__c = true;
                insert ledger;
            }
            catch(DmlException ex) {
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<String>{getLedgerRestrictFields()})));
            }

            Test.stopTest();
        }
    }


    @IsTest 
    public static void testUpdateLedgerFieldRestrictOnPaymentFeatureDisable(){
        TestDataSuite testData = TestDataSuite.getInstance();
                
        System.runAs(testData.users[1]) {
            Test.startTest();
                
            try {
                testData.ledgers[0].Enrolled_in_Payment_Services__c = true;
                update testData.ledgers[0];
            }
            catch(DmlException ex) {
                Assert.isNotNull(ex);
                Assert.areEqual(ex.getDmlMessage(0), String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<String>{getLedgerRestrictFields()}));
            }

            Test.stopTest();
        }
    }

    @IsTest 
    public static void testUpdatePayableFieldRestrictOnPaymentFeatureEnable(){
        TestDataSuite testData = TestDataSuite.getInstance();
                
        System.runAs(testData.users[1]) {
            Test.startTest();
                     //Setting of mock
                     SingleRequestMock awsSuccess = new SingleRequestMock(
                        200,
                        'Complete',
                        AwsServiceTest.CREATE_COMPANY_JSON , 
                        new Map<String, String>{'Content-Type' => 'application/json'}
                    );
        
                Test.setMock(HttpCalloutMock.class, awsSuccess); 
                
                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
                testData.ledgers[0].Enrolled_in_Payment_Services__c = true;
                update testData.ledgers[0];
            
            Test.stopTest();

            Assert.areEqual(true, [SELECT Enrolled_in_Payment_Services__c FROM Ledger__c WHERE Id = :testData.ledgers[0].Id].Enrolled_in_Payment_Services__c);
        }
    }

    private static String getLedgerRestrictFields() { 
        APAutomationControl service = new APAutomationControl();
        return service.getFieldLabels(service.getFieldGrants().get(Ledger__c.SObjectType));
    }

    @IsTest 
    public static void testCallAwsToPostPayload(){
        TestDataSuite testData = TestDataSuite.getInstance();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
                 //Setting of mock
                 SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.CREATE_COMPANY_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                    
                Ledger__c ledger = testData.ledgers[0].clone(false, true);
                ledger.Enrolled_in_Payment_Services__c = true;
                insert ledger;

            Test.stopTest();

            Assert.isNotNull(ledger.Id);
        }
    }

    @IsTest 
    public static void testCallAwsToPostPayloadForUpdate(){
        TestDataSuite testData = TestDataSuite.getInstance();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;
            Test.startTest();
                 //Setting of mock
                 SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.UPDATE_COMPANY_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                try {
                    Ledger__c ledger = testData.ledgers[0].clone(false, true);
                    ledger.Enrolled_in_Payment_Services__c = true;
                    insert ledger;

                    ledger = [SELECT Id, Payment_Services_Company_Code__c FROM Ledger__c WHERE Enrolled_in_Payment_Services__c = TRUE][0];
                    ledger.Payment_Services_Company_Code__c = '12345';
                    update ledger;
                    isSuccess = true;
                }
                catch (Exception ex) {
                    isSuccess = false;
                }
                
            Test.stopTest();

            Assert.isTrue(isSuccess);
        }
    }
    @IsTest 
    public static void testCallAwsToPostPayloadForUpdatePaymentNotification(){
        TestDataSuite testData = TestDataSuite.getInstance();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;
            Test.startTest();
                 //Setting of mock
                 SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.UPDATE_COMPANY_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
    
                Test.setMock(HttpCalloutMock.class, awsSuccess); 

                try {
                    Ledger__c ledger = testData.ledgers[0].clone(false, true);
                    ledger.Enrolled_in_Payment_Services__c = true;
                    insert ledger;

                    ledger = [SELECT Id, Payment_Notifications_Email__c FROM Ledger__c WHERE Enrolled_in_Payment_Services__c = TRUE][0];
                    ledger.Payment_Notifications_Email__c = 'abc@gmail.com';
                    update ledger;
                    isSuccess = true;
                }
                catch(Exception ex) {
                    isSuccess = false;
                }
                
            Test.stopTest();

            Assert.isTrue(isSuccess);
        }
    }

    @IsTest
    public static void testCallAwsToPostPayloadForUpdateBankAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;

            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.UPDATE_COMPANY_JSON,
                new Map<String, String>{
                    'Content-Type' => 'application/json'
                }
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            try {
                Ledger__c ledger = testData.ledgers[0].clone(false, true);
                ledger.Enrolled_in_Payment_Services__c = true;
                ledger.AcctSeed__Payment_Services_Company_Code__c = '34234';
                insert ledger;


                Bank_Account__c bankAccount = new Bank_Account__c(
                    Name = 'Test Account1',
                    Payment_Services_Enrollment_Status__c = 'Not Enrolled',
                    Account_Number__c = '123456789',
                    Routing_Number__c = '123456789',
                    Ledger__c = ledger.Id,
                    Enable_for_Payment_Services__c = true
                );
                insert bankAccount;

                ledger = [SELECT Id, Payment_Withdrawal_Method__c FROM Ledger__c WHERE Enrolled_in_Payment_Services__c = TRUE][0];
                ledger.Payment_Withdrawal_Method__c = 'By Transaction';
                update ledger;
                isSuccess = true;
            } catch (Exception ex) {
                isSuccess = false;
            }

            Test.stopTest();

            Assert.isTrue(isSuccess);
        }
    }

    @IsTest
    public static void testCallAwsToPostPayloadForUpdatePaymentWithdraw() {
        TestDataSuite testData = TestDataSuite.getInstance();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;

            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.CREATE_COMPANY_JSON,
                new Map<String, String>{
                    'Content-Type' => 'application/json'
                }
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            try {
                Ledger__c ledger = testData.ledgers[0].clone(false, true);
                ledger.Enrolled_in_Payment_Services__c = true;
                insert ledger;

                ledger = [SELECT Id, Payment_Withdrawal_Method__c FROM Ledger__c WHERE Enrolled_in_Payment_Services__c = TRUE][0];
                ledger.Payment_Withdrawal_Method__c = 'By Transaction';
                update ledger;
                isSuccess = true;
            } catch (Exception ex) {
                isSuccess = false;
            }

            Test.stopTest();

            Assert.isTrue(isSuccess);
        }
    }

    @IsTest 
    public static void testUpdateLedgerCreatePaymentProcessor(){
        TestDataSuite testData = TestDataSuite.getInstance();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

        System.runAs(testData.users[1]) {
            Test.startTest();
                   
                Ledger__c ledger = testData.ledgers[0];
                ledger.Payment_Services_Company_Code__c = '123456';
                update ledger;

            Test.stopTest();

            List<Payment_Processor__c> pps = [SELECT Id FROM Payment_Processor__c WHERE Type__c = :PaymentProcessorActions.EDENRED_TYPE];
            Assert.areEqual(1, pps.size());
        }
    }

    @IsTest
    public static void testPreventAccountingMethodChangeOnShadowLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();
        LedgerHandler.reset();
        Ledger__c testLedger = new Ledger__c(
            Name = 'Actual Test',
            Type__c = 'Transactional',
            Default_Bank_Account__c = testData.glAccounts[0].Id,
            Default_Billing_Format__c = testData.billingFormats[0].Id,
            Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
            Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
            Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
        );
        insert testLedger;

        List<Ledger__c> shadowLedgers = [SELECT Id FROM Ledger__c WHERE Related_Ledger__c = :testLedger.Id];
        System.assertEquals(false, shadowLedgers.isEmpty());

        DmlException dmlEx;
        try {
            Ledger__c shadowLedger = shadowLedgers.get(0);
            shadowLedger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            TriggerObserver.getInstance().unlockField(Ledger__c.Accounting_Method__c);
            update shadowLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.ACCOUNTING_METHOD_CHANGE_ON_SHADOW_LEDGER_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventAccountingMethodChangeFromCashToAccrualOnLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();
        LedgerHandler.reset();
        Ledger__c testLedger = new Ledger__c(
            Name = 'Actual Test',
            Type__c = 'Transactional',
            Default_Bank_Account__c = testData.glAccounts[0].Id,
            Default_Billing_Format__c = testData.billingFormats[0].Id,
            Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
            Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
            Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_CASH
        );
        insert testLedger;

        DmlException dmlEx;
        try {
            testLedger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            TriggerObserver.getInstance().unlockField(Ledger__c.Accounting_Method__c);
            update testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.ACCOUNTING_METHOD_CHANGE_FROM_CASH_TO_ACCRUAL_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testPreventAccountingMethodChangeFromAccrualToCashOnLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();
        LedgerHandler.reset();
        Ledger__c testLedger = new Ledger__c(
            Name = 'Actual Test',
            Type__c = 'Transactional',
            Default_Bank_Account__c = testData.glAccounts[0].Id,
            Default_Billing_Format__c = testData.billingFormats[0].Id,
            Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
            Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
            Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL
        );
        insert testLedger;

        DmlException dmlEx;
        try {
            testLedger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_CASH;
            TriggerObserver.getInstance().unlockField(Ledger__c.Accounting_Method__c);
            update testLedger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(LedgerActions.ACCOUNTING_METHOD_CHANGE_FROM_ACCRUAL_TO_CASH_ERROR, dmlEx.getDmlMessage(0));
    }

    @IsTest
    private static void testapAutomationPostMsgOnAddressUpdate(){
        TestDataSuite testData = TestDataSuite.getInstance().createAddressObjects();

        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;

            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.UPDATE_COMPANY_JSON,
                new Map<String, String>{
                    'Content-Type' => 'application/json'
                }
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            try {
                Ledger__c ledger = testData.ledgers[0].clone(false, true);
                insert ledger;

                ledger.Address__c = testData.addressObjects[0].Id;
                update ledger;
                isSuccess = true;

            } catch (Exception ex) {
                isSuccess = false;
            }

            Test.stopTest();

            Assert.isTrue(isSuccess);
        }
    }

    @IsTest 
    private static void testapAutomationPostMsgOnNameUpdate(){
        TestDataSuite testData = TestDataSuite.getInstance().createAddressObjects();
        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;
            Test.startTest();
                //Setting of mock
                SingleRequestMock awsSuccess = new SingleRequestMock(
                    200,
                    'Complete',
                    AwsServiceTest.UPDATE_COMPANY_JSON,
                    new Map<String, String>{
                        'Content-Type' => 'application/json'
                    }
                );
                Test.setMock(HttpCalloutMock.class, awsSuccess);
                try {
                    Ledger__c ledger = testData.ledgers[0].clone(false, true);
                    insert ledger;

                    ledger.Name = 'Test Ledger';
                    update ledger;
                    isSuccess = true;   
                } catch (Exception ex) {
                    isSuccess = false;
                }

            Test.stopTest();
            Assert.isTrue(isSuccess);
        }
    }

    @IsTest 
    private static void testapAutomationPostMsgOnSalesTaxCodeUpdate(){
        TestDataSuite testData = TestDataSuite.getInstance().createAddressObjects();
        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;
            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.UPDATE_COMPANY_JSON,
                new Map<String, String>{
                    'Content-Type' => 'application/json'
                }
            );
            Test.setMock(HttpCalloutMock.class, awsSuccess);
            try {
                Ledger__c ledger = testData.ledgers[0].clone(false, true);
                insert ledger;

                    ledger.Sales_Tax_Company_Code__c = 'Test Company Code';
                update ledger;
                isSuccess = true;
            } catch (Exception ex) {
                isSuccess = false;
            }

            Test.stopTest();
            Assert.isTrue(isSuccess);
        }
    }

    @IsTest
    private static void testapAutomationPostMsgOnLogoUpdate(){
        TestDataSuite testData = TestDataSuite.getInstance().createAddressObjects();

        System.runAs(testData.users[1]) {
            Boolean isSuccess = false;

            Test.startTest();
            //Setting of mock
            SingleRequestMock awsSuccess = new SingleRequestMock(
                200,
                'Complete',
                AwsServiceTest.UPDATE_COMPANY_JSON,
                new Map<String, String>{
                    'Content-Type' => 'application/json'
                }
            );

            Test.setMock(HttpCalloutMock.class, awsSuccess);

            try {
                Ledger__c ledger = testData.ledgers[0].clone(false, true);
                insert ledger;

                ledger.logo__c = 'ABC';
                update ledger;
                isSuccess = true;

            } catch (Exception ex) {
                isSuccess = false;
            }

            Test.stopTest();

            Assert.isTrue(isSuccess);
        }
    }

    @IsTest
    public static void testLedgerAccountingMethodForConsolidationTransactionalError() {
        LedgerService.setLedgerLimit(
            10,
            EncodingUtil.base64Encode(
                Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
            )
        );
        LedgerHandler.reset();
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Test 0001';
        ledger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
        ledger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH;

        DmlException dmlEx;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(
            String.format(
            Label.ERR_NOT_VALID_METHOD_FOR_CONSOLIDATION,
            new List<String>{(String) ledger.get(Ledger__c.Type__c)}),
            dmlEx.getDmlMessage(0));
    }

    @IsTest
    public static void testLedgerAccountingMethodForConsolidationBudgetError() {
        LedgerService.setLedgerLimit(
            10,
            EncodingUtil.base64Encode(
                Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
            )
        );
        LedgerHandler.reset();
        Ledger__c ledger = new Ledger__c();
        ledger.Name = 'Test 0001';
        ledger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET;
        ledger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH;

        DmlException dmlEx;
        try {
            insert ledger;
        }
        catch (DmlException ex) {
            dmlEx = ex;
        }
        System.assertEquals(
            String.format(
                Label.ERR_NOT_VALID_METHOD_FOR_CONSOLIDATION,
                new List<String>{(String) ledger.get(Ledger__c.Type__c)}),
            dmlEx.getDmlMessage(0));
    }

}