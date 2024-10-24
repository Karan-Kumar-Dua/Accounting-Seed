@IsTest
public class FinancialCubeActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testFinancialCubeActionsSetRequiredCubeFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = null,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                String.valueOf(testData.acctPeriods[2].Id) +
                    String.valueOf(testData.ledgers[0].Id) +
                    'RetainedEarnings' +
                    String.valueOf(testData.glAccounts[9].Id) +
                    'nullnullnullnull',
                String.valueOf([SELECT Key__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Key__c)
            );
            System.assertEquals(
                String.valueOf(testData.ledgers[0].Id) +
                    'RetainedEarnings' +
                    String.valueOf(testData.glAccounts[9].Id) +
                    'nullnullnullnull',
                [SELECT Key_Group__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Key_Group__c
            );
            System.assertEquals(
                testData.acctPeriods[2].Start_Date__c.year(),
                [SELECT Year__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Year__c
            );
            System.assertEquals(
                0,
                [SELECT Amount__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Amount__c
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsSetRequiredCubeFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            fcList[0].Accounting_Period__c = testData.acctPeriods[1].Id;
            fcList[0].GL_Account__c = testData.glAccounts[10].Id;
            fcList[0].Opening_Balance__c = 1200;
            fcList[0].Amount__c = null;
            fcList[0].Key__c = null;
            fcList[0].Key_Group__c = null;
            update fcList[0];

            System.assertEquals(
                String.valueOf(testData.acctPeriods[1].Id) +
                    String.valueOf(testData.ledgers[1].Id) +
                    'RetainedEarnings' +
                    String.valueOf(testData.glAccounts[10].Id) +
                    'nullnullnullnull',
                String.valueOf([SELECT Key__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Key__c)
            );
            System.assertEquals(
                String.valueOf(testData.ledgers[1].Id) +
                    'RetainedEarnings' +
                    String.valueOf(testData.glAccounts[10].Id) +
                    'nullnullnullnull',
                [SELECT Key_Group__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Key_Group__c
            );
            System.assertEquals(
                testData.acctPeriods[1].Start_Date__c.year(),
                [SELECT Year__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Year__c
            );
            System.assertEquals(
                0,
                [SELECT Amount__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id].Amount__c
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventInsertActionError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );

            DMLException dmlEx;
            try {
                insert fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(FinancialCubeActions.INSERT_ERROR, new List<String>{testData.ledgers[0].Type__c}),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventInsertBudgetTranslatedCubeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
                    IsTranslatedCube__c = true
                )
            );

            DMLException dmlEx;
            try {
                insert fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(FinancialCubeActions.INSERT_ERROR, new List<String>{testData.ledgers[1].Type__c}),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventInsertActionConsolidationsError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        Ledger__c consolidationLedger = null;
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedger = ledger;
            }
        }

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = consolidationLedger.Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                )
            );

            DMLException dmlEx;
            try {
                insert fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(FinancialCubeActions.INSERT_ERROR, new List<String>{consolidationLedger.Type__c}),
                dmlEx.getDMLMessage(0)
            );
        }
    }


    @IsTest
    public static void testFinancialCubeActionsPreventInsertActionSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );

            DMLException dmlEx;
            try {
                FinancialCubeActions.isPreventOverride = true;
                insert fcList[0];
                FinancialCubeActions.isPreventOverride = false;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Opening_Balance__c = 14000;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(FinancialCubeActions.nonUpdateableFields)),
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionLedgerTransactionalToBudgetError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Ledger__c = testData.ledgers[1].Id;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(FinancialCubeActions.nonUpdateableFields)),
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionLedgerBudgetToTransactionalError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Ledger__c = testData.ledgers[0].Id;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(FinancialCubeActions.nonUpdateableFields)),
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionConsolidationsAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        Ledger__c consolidationLedger = null;
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedger = ledger;
            }
        }

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 1456,
                    Ledger__c = consolidationLedger.Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Amount__c = 12800;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', 'Amount'),
                    new List<String>{consolidationLedger.Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionConsolidationsNonUpdateableError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        Ledger__c consolidationLedger = null;
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedger = ledger;
            }
        }

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 1456,
                    Ledger__c = consolidationLedger.Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS;
                fcList[0].Year__c = 1900;
                fcList[0].Opening_Balance__c = 2000;
                fcList[0].Ledger__c = testData.ledgers[0].Id;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(FinancialCubeActions.nonUpdateableFields)),
                    new List<String>{consolidationLedger.Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionCurrentYearEarningsAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 1456,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Amount__c = 12800;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', 'Amount'),
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionRetainedEarningsAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 1456,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Amount__c = 12800;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', 'Amount'),
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionArchivedAccountingPeriodAmountFieldError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[4].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 1000,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            AccountingPeriodActions.isPreventUpdateOverride = true;
            testData.acctPeriods[4].Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            update testData.acctPeriods[4];
            AccountingPeriodActions.isPreventUpdateOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Amount__c = 14000;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', 'Amount'),
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionOpeningBalanceSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[4].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200.892345,
                    Amount__c = 1000,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Opening_Balance__c = 1200.89;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionOpeningBalanceError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[4].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200.892345,
                    Amount__c = 1000,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(
                1200.892345, [
                    SELECT Id, Opening_Balance__c FROM Financial_Cube__c WHERE Id = :fcList[0].Id
                ].Opening_Balance__c
            );

            DMLException dmlEx;
            try {
                fcList[0].Opening_Balance__c = 1200.90;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(FinancialCubeActions.nonUpdateableFields)),
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateTranslatedBudgetError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[4].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200.892345,
                    Amount__c = 1000,
                    Ledger__c = testData.ledgers[1].Id,
                    Translated_Rate__c = 0.93,
                    IsTranslatedCube__c = true,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Translated_Rate__c = 0.8;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(FinancialCubeActions.nonUpdateableFields)),
                    new List<String>{testData.ledgers[1].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateBudgetCubeTranslatedFieldsError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[4].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200.892345,
                    Amount__c = 1000,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Translated_Rate__c = 0.8;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', FinancialSuiteUtils.formatFieldStrings(FinancialCubeActions.nonUpdateableFields)),
                    new List<String>{testData.ledgers[1].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateTranslatedBudgetAmountError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[4].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200.892345,
                    Amount__c = 1000,
                    Ledger__c = testData.ledgers[1].Id,
                    Translated_Rate__c = 0.93,
                    IsTranslatedCube__c = true,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Amount__c = 300;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', 'Amount'),
                    new List<String>{testData.ledgers[1].Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventUpdateActionSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                fcList[0].Opening_Balance__c = 14000;
                update fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(null,dmlEx);
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionTransactionError() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost()
            .createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Financial_Cube_Transaction__c fct = [
                SELECT Id, Amount__c, Financial_Cube__r.Id, Financial_Cube__r.Ledger_Type__c
                FROM Financial_Cube_Transaction__c
                WHERE Transaction__r.Billing_Line__c = :testData.billingLines[0].Id LIMIT 1
            ];

            DMLException dmlEx;
            try {
                delete fct.Financial_Cube__r;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.DELETE_ERROR,
                    new List<String>{fct.Financial_Cube__r.Ledger_Type__c}
                ),
                dmlEx.getDmlMessage(0)
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionOpeningBalanceError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[4].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD;

            FinancialCubeActions.isPreventOverride = true;
            insert fCube;
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fCube;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.DELETE_ERROR,
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionConsolidationsOpeningBalanceError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            Ledger__c consolidationLedger = null;
            for (Ledger__c ledger : testData.ledgers) {
                if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                    consolidationLedger = ledger;
                }
            }

            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = consolidationLedger.Id;
            fCube.Accounting_Period__c = testData.acctPeriods[4].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS;

            FinancialCubeActions.isPreventOverride = true;
            insert fCube;
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fCube;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.DELETE_ERROR,
                    new List<String>{consolidationLedger.Type__c}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionCurrentYearEarningsError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[4].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CURRENT_YEAR_EARNINGS;

            FinancialCubeActions.isPreventOverride = true;
            insert fCube;
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fCube;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.DELETE_ERROR,
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionRetainedEarningsError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[4].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS;

            FinancialCubeActions.isPreventOverride = true;
            insert fCube;
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fCube;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.DELETE_ERROR,
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionNoTransactionsOpeningBalanceError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )

            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.DELETE_ERROR,
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionNoTransactionAndOpeningBalanceZeroSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 0,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )

            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteArchivedAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[4].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 0,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            AccountingPeriodActions.isPreventUpdateOverride = true;
            testData.acctPeriods[4].Status__c = 'Archived';
            update testData.acctPeriods[4];
            AccountingPeriodActions.isPreventUpdateOverride = false;

            DMLException dmlEx;
            try {
                delete fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    FinancialCubeActions.DELETE_ERROR,
                    new List<String>{testData.ledgers[0].Type__c}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionBudgetSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[1].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )

            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testFinancialCubeActionsPreventDeleteActionOverrideDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            testData.settings.Financial_Suite_Key__c = UserInfo.getOrganizationId();
            update testData.settings;
            AccountingSettingsHandler.acctSeedSettings = NULL;

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                )

            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                delete fcList[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testFinancialCubeCurrencyIsAlwaysLedgerCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }
                String ledgerCurrency = (String) Database.query(
                    'SELECT Id, CurrencyIsoCode ' +
                        'FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c ' +
                        'WHERE Id = \'' + String.escapeSingleQuotes(testData.ledgers[0].Id) + '\''
                )[0].get('CurrencyIsoCode');

                List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
                fcList.add(
                    new Financial_Cube__c(
                        Accounting_Period__c = testData.acctPeriods[2].Id,
                        GL_Account__c = testData.glAccounts[9].Id,
                        Opening_Balance__c = 1200,
                        Amount__c = NULL,
                        Ledger__c = testData.ledgers[0].Id,
                        Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_RETAINED_EARNINGS
                    )
                );

                fcList[0].put('CurrencyIsoCode', newCurrency);

                FinancialCubeActions.isPreventOverride = true;
                insert fcList[0];
                FinancialCubeActions.isPreventOverride = false;

                Financial_Cube__c fCube = (Financial_Cube__c) Database.query(
                    'SELECT Id, CurrencyIsoCode ' +
                        'FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Financial_Cube__c ' +
                        'WHERE Id = \'' + String.escapeSingleQuotes(fcList[0].Id) + '\''
                );
                System.assertEquals(ledgerCurrency, fCube.get('CurrencyIsoCode'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testFinancialCubeNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Financial_Cube__c fc = new Financial_Cube__c();
                insert fc;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testFinancialCubeNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;
                try {
                    Financial_Cube__c fc = new Financial_Cube__c();
                    insert fc;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testFinancialCubeActionsValidateCubeTypeFromCubeType() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        Ledger__c consolidationLedger = null;
        for (Ledger__c ledger : testData.ledgers) {
            if (ledger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                consolidationLedger = ledger;
            }
        }

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = consolidationLedger.Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                )
            );
            FinancialCubeActions.isPreventOverride = true;
            insert fcList[0];
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                FinancialCubeActions.isPreventOverride = true;
                insert new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = consolidationLedger.Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                );
                FinancialCubeActions.isPreventOverride = false;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                FinancialCubeActions.CONSOLIDATION_FINANCE_CUBE_4_CONSOLIDATION_LEDGER_ERROR,
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsValidateCubeTypeFromCLedger(){
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Financial_Cube__c> fcList = new List<Financial_Cube__c>();
            fcList.add(
                new Financial_Cube__c(
                    Accounting_Period__c = testData.acctPeriods[2].Id,
                    GL_Account__c = testData.glAccounts[9].Id,
                    Opening_Balance__c = 1200,
                    Amount__c = 0,
                    Ledger__c = testData.ledgers[0].Id,
                    Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS
                )
            );

            DMLException dmlEx;
            try {
                FinancialCubeActions.isPreventOverride = true;
                insert fcList[0];
                FinancialCubeActions.isPreventOverride = false;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                FinancialCubeActions.CONSOLIDATION_FINANCE_CUBE_4_CONSOLIDATION_LEDGER_ERROR,
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testFinancialCubeActionsAllowInsertForELBudgetLedger(){
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            // get ledger w/ type elimination budget
            Ledger__c ledger = [
                SELECT Id
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
            ];

            Financial_Cube__c cube = new Financial_Cube__c(
                Accounting_Period__c = testData.acctPeriods[2].Id,
                GL_Account__c = testData.glAccounts[9].Id,
                Opening_Balance__c = 1200,
                Amount__c = 0,
                Ledger__c = ledger.Id,
                Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD
            );

            insert cube;

            System.assertNotEquals(null, [SELECT Id FROM Financial_Cube__c WHERE Id = :cube.Id]);
        }
    }

    @IsTest
    private static void testPreventUpdateAmountOnEliminationsTransactionalFC() {
        TestDataSuite testData = TestDataSuite.getInstance().createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            List<Ledger__c> eliminationLedgers = [
                SELECT Id, Type__c
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
            ];
            System.assertEquals(false, eliminationLedgers.isEmpty());

            Ledger__c eliminationLedger = eliminationLedgers.get(0);

            Journal_Entry__c testJE = new Journal_Entry__c(
                Name = 'testJournal 1',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Journal_Date__c = testData.acctPeriods[0].Start_Date__c,
                Ledger__c = eliminationLedger.Id
            );
            insert testJE;

            List<Journal_Entry_Line__c> jeLines = new List<Journal_Entry_Line__c>();
            jeLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testJE.Id,
                    Credit__c = 100,
                    GL_Account__c = testData.glAccounts[0].Id,
                    Units__c = 1,
                    Reference__c = 'credit-line'
                )
            );
            jeLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = testJE.Id,
                    Debit__c = 100,
                    GL_Account__c = testData.glAccounts[10].Id,
                    Units__c = 1,
                    Reference__c = 'debit-line'
                )
            );
            insert jeLines;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(true, postResults[0].isSuccess);

            Test.startTest();
            Financial_Cube__c testFC = [
                SELECT Id, Amount__c
                FROM Financial_Cube__c
                WHERE Ledger__c = :eliminationLedger.Id
                AND GL_Account__c = :testData.glAccounts[10].Id
            ];

            DmlException dmlEx;
            try {
                testFC.Amount__c = 200;//Error expected
                update testFC;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(
                String.format(
                    FinancialCubeActions.UPDATE_ERROR.replace('<FIELDS>', 'Amount'),
                    new List<String>{eliminationLedger.Type__c}
                ),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    private static void testAllowUpdateAmountOnEliminationsBudgetFC() {
        TestDataSuite testData = TestDataSuite.getInstance().createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            List<Ledger__c> eliminationLedgers = [
                SELECT Id, Type__c
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
            ];
            System.assertEquals(false, eliminationLedgers.isEmpty());

            Ledger__c eliminationLedger = eliminationLedgers.get(0);

            Test.startTest();
            Financial_Cube__c testFC = new Financial_Cube__c(
                Ledger__c = eliminationLedger.Id,
                GL_Account__c = testData.glAccounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD,
                Amount__c = 100
            );
            insert testFC;

            DmlException dmlEx;
            try {
                //Allowed b/c Budget
                testFC.Amount__c = 200;
                update testFC;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
        }
    }

    @IsTest
    private static void testDeleteTranslationCubes() {
        try {
            Test.startTest();
            TestDataSuite testData = TestDataSuite.getInstance()
                    .enableMultiCurrency()
                    .createExchangeRates()
                    .createBillings(true);

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode) || !testData.isValidCurrencyForExchangeRateTable(newCurrencyIsoCode)) {
                    return;
                }
                GL_Account_Default__c ctaDef = new GL_Account_Default__c(
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CTA_GL_ACCOUNT,
                        GL_Account__c = testData.glAccounts[7].Id,
                        Ledger__c = testData.ledgers[0].Id
                );
                insert ctaDef;

                testData.glAccounts[2].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[2];

                testData.glAccounts[10].Rate_Type__c = 'Monthly Average';
                update testData.glAccounts[10];

                Map<Id, Financial_Cube__c> sourceCubes = new Map<Id, Financial_Cube__c>([SELECT Id FROM Financial_Cube__c]);
                System.assertEquals(false, sourceCubes.isEmpty());

                FinancialCubeTranslationBatch translationBatch = new FinancialCubeTranslationBatch(new Set<Id> {testData.ledgers[0].Id}, testData.acctPeriods[0].Id, newCurrencyIsoCode);
                Database.QueryLocatorIterator queryLocatorIterator = translationBatch.start(null).iterator();
                List<SObject> scope = new List<SObject>();
                while (queryLocatorIterator.hasNext()) {
                    scope.add(queryLocatorIterator.next());
                }
                translationBatch.execute(null, scope);
                translationBatch.finish(null);

                System.assertEquals(false, [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true].isEmpty());

                FinancialCubeActions.isPreventOverride = true;
                delete sourceCubes.values();
                FinancialCubeActions.isPreventOverride = false;
                Test.stopTest();

                System.assertEquals(true, [SELECT Id FROM Financial_Cube__c WHERE IsTranslatedCube__c = true AND Source_Cube__c =: sourceCubes.keySet()].isEmpty());
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }
}