@IsTest
private class GLAccountActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testRequireFieldsInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[0].clone(false, true);

            DMLException dmlEx;
            try {
                glAccount.Type__c = NULL;
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testRequireFieldsUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                testData.glAccounts[0].Type__c = NULL;
                update testData.glAccounts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testValidatePicklistValuesError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[0].clone(false, true);

            DMLException dmlEx;
            try {
                glAccount.Type__c = 'This is wrong value';
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.TYPE_PICKLIST_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidatePicklistValuesErrorOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[18];

            DMLException dmlEx;
            try {
                glAccount.Type__c = 'This is wrong value';
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.TYPE_PICKLIST_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateGLCategoryValuesErrorOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[32];

            DMLException dmlEx;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;
                glAccount.Sub_Type_1__c = '';
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.NON_VALID_TYPE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                glAccount.Sub_Type_1__c = 'Assets';
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.NOT_LIABILITIES_SUB_TYPE_1_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateOnlyOneInputGLAccountErrorOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[28];
            
            DMLException dmlEx;
            try {
                glAccount.GL_Category__c = 'Input VAT';
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CATEGORY_PICKLIST_INPUT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateOnlyOneOutputGLAccountErrorOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[28];
            
            DMLException dmlEx;
            try {
                glAccount.GL_Category__c = 'Output VAT';
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CATEGORY_PICKLIST_OUTPUT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateOnlyOneInputGLAccountErrorOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[28].clone(false, true);
            
            DMLException dmlEx;
            try {
                glAccount.GL_Category__c = 'Input VAT';
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CATEGORY_PICKLIST_INPUT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateOnlyOneOutputGLAccountErrorOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[28].clone(false, true);
            
            DMLException dmlEx;
            try {
                glAccount.GL_Category__c = 'Output VAT';
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CATEGORY_PICKLIST_OUTPUT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateGLCategoryInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[28].clone(false, true);
            
            DMLException dmlEx;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;
                glAccount.GL_Category__c = 'Input VAT';
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.NON_VALID_TYPE_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                glAccount.Sub_Type_1__c = 'Assets';
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.NOT_LIABILITIES_SUB_TYPE_1_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidatePicklistValuesSub1TypeFieldBalanceSheetInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[0].clone(false, true);

            DMLException dmlEx;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                glAccount.Sub_Type_1__c = NULL;
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                glAccount.Sub_Type_1__c = 'this is wrong';
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidatePicklistValuesSub1TypeFieldBalanceSheetUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //From valid value to empty
            DMLException dmlEx;
            try {
                testData.glAccounts[9].Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                testData.glAccounts[9].Sub_Type_1__c = NULL;
                update testData.glAccounts[9];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));

            //From valid value to a wrong value
            dmlEx = NULL;
            try {
                testData.glAccounts[9].Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                testData.glAccounts[9].Sub_Type_1__c = 'this is wrong';
                update testData.glAccounts[9];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));
            //From Revenue Type with empty Sub Type 1 to Balance Sheet Type with empty Sub Type 1 value
            dmlEx = NULL;
            try {
                //Create new Revenue GL Account
                GL_Account__c testGlAccount = new GL_Account__c(
                    Name = '9999-Test GL Account',
                    Active__c = true,
                    Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
                );
                insert testGlAccount;

                testGlAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                update testGlAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testValidatePicklistValuesSub1TypeFieldBalanceSheetSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[0].clone(false, true);

            DMLException dmlEx;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET;
                glAccount.Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_ASSETS;
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            dmlEx = NULL;
            try {
                glAccount.Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_LIABILITIES;
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }

    }

    @IsTest
    private static void testValidatePicklistValuesSub1TypeFieldCashFlowInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = testData.glAccounts[0].clone(false, true);

            DMLException dmlEx;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_CASH_FLOW;
                glAccount.Sub_Type_1__c = NULL;
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CASH_FLOW_SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                glAccount.Type__c = GLAccountActions.GL_ACCOUNT_TYPE_CASH_FLOW;
                glAccount.Sub_Type_1__c = 'this is wrong';
                insert glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CASH_FLOW_SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testValidatePicklistValuesSub1TypeFieldCashFlowUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            GL_Account__c glAccount = new GL_Account__c(
                Name = 'Taxes Paid',
                Active__c = true,
                Type__c = GLAccountActions.GL_ACCOUNT_TYPE_CASH_FLOW,
                Bank__c = false,
                Sub_Type_1__c = GLAccountActions.GL_ACCOUNT_SUB_TYPE_1_INVESTING
            );

            insert glAccount;

            DMLException dmlEx;
            try {
                glAccount.Sub_Type_1__c = NULL;
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CASH_FLOW_SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            try {
                glAccount.Sub_Type_1__c = 'this is wrong';
                update glAccount;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.CASH_FLOW_SUB_TYPE_1_PICKLIST_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventChangeTypeField() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Financial_Cube__c newCube = new Financial_Cube__c();
            newCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            newCube.GL_Account__c = testData.glAccounts[0].Id;
            newCube.Opening_Balance__c = 0;
            newCube.Year__c = 1996;
            newCube.Ledger__c = testData.ledgers[0].Id;
            newCube.Cube_Type__c = 'Period';
            FinancialCubeActions.isPreventOverride = true;
            insert newCube;
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                testData.glAccounts[0].Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;
                update testData.glAccounts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.TYPE_CHANGE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventChangeTypeToCashFlowIfReportRowsExist() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Financial_Report_Definition__c testFRD = new Financial_Report_Definition__c(
                Name = 'Test Report 1'
            );
            insert testFRD;

            Financial_Report_Row__c testFRR = new Financial_Report_Row__c(
                Financial_Report_Definition__c = testFRD.Id,
                Row_Label__c = testData.glAccounts[0].Name,
                Type__c = 'GL Account',
                GL_Account__c = testData.glAccounts[0].Id,
                Position__c = 1,
                Normal_Balance__c = 'Credit'
            );
            insert testFRR;

            DMLException dmlEx;
            try {
                testData.glAccounts[0].Type__c = GLAccountActions.GL_ACCOUNT_TYPE_CASH_FLOW;
                update testData.glAccounts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(FinancialReportRowActions.CASH_FLOW_RELATED_GL_ACCOUNT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testBypassValidationRules() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Financial_Cube__c newCube = new Financial_Cube__c();
            newCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            newCube.GL_Account__c = testData.glAccounts[0].Id;
            newCube.Opening_Balance__c = 0;
            newCube.Year__c = 1996;
            newCube.Ledger__c = testData.ledgers[0].Id;
            newCube.Cube_Type__c = 'Period';
            FinancialCubeActions.isPreventOverride = true;
            insert newCube;
            FinancialCubeActions.isPreventOverride = false;

            DMLException dmlEx;
            try {
                testData.glAccounts[0].Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;
                update testData.glAccounts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);

            RestResult result;
            DMLException dmlEx2;
            try {
                testData.glAccounts[0].Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE;

                String authKey = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY)));
                Callable extension = (Callable) Type.forName('FinancialSuiteService').newInstance();
                result = (RestResult) extension.call('updateGLAccount', new Map<String, Object> {
                    'authKey' => authKey,
                    'data' => new List<GL_Account__c> {testData.glAccounts[0]},
                    'bypass' => true
                });
            }
            catch (DMLException ex) {
                dmlEx2 = ex;
            }
            System.assertEquals(NULL, dmlEx2);
            System.assertEquals(true, result.isSuccess);
        }

    }

    @IsTest
    private static void testPreventChangeBankCheckboxIfCubesExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                testData.glAccounts[0].Bank__c = false;
                update testData.glAccounts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.BANK_CHANGE_FIN_CUBES_EXISTED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventChangeGLCategoryIfCubesExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                testData.glAccounts[0].GL_Category__c = 'Input VAT';
                update testData.glAccounts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.GL_CATEGORY_CHANGE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventDeleteIfRelatedCRExists() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            GL_Account__c testGL = new GL_Account__c(
                Name = 'test-gl',
                Active__c = true,
                Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
            );
            insert testGL;

            Cash_Receipt__c newItem = testData.cashReceipts[0].clone(false);
            newItem.Credit_GL_Account__c = testGL.Id;
            insert newItem;
            System.assertEquals(1, [SELECT Id FROM Cash_Receipt__c WHERE Credit_GL_Account__c = :testGL.Id].size());

            DMLException dmlEx;
            try {
                delete testGL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedCDExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            GL_Account__c testGL = new GL_Account__c(
                Name = 'test-gl',
                Active__c = true,
                Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
            );
            insert testGL;

            Cash_Disbursement__c newItem = testData.cashDisbursements[0].clone(false);
            newItem.Debit_GL_Account__c = testGL.Id;
            insert newItem;

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Debit_GL_Account__c = :testGL.Id].size());

            DMLException dmlEx;
            try {
                delete testGL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventDeleteIfRelatedAmortizationExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            GL_Account__c testGL = new GL_Account__c(
                Name = 'test-gl',
                Active__c = true,
                Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
            );
            insert testGL;

            Scheduled_Revenue_Expense__c newItem = testData.scheduledRevenues[0].clone(false);
            newItem.Debit_GL_Account__c = testGL.Id;
            insert newItem;
            System.assertEquals(1, [SELECT Id FROM Scheduled_Revenue_Expense__c WHERE Debit_GL_Account__c = :testGL.Id].size());

            DMLException dmlEx;
            try {
                delete testGL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedPayableLineExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            GL_Account__c testGL = new GL_Account__c(
                Name = 'test-gl',
                Active__c = true,
                Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
            );
            insert testGL;

            Account_Payable_Line__c newItem = testData.payableLines[0].clone(false);
            newItem.Expense_GL_Account__c = testGL.Id;
            insert newItem;
            System.assertEquals(1, [SELECT Id FROM Account_Payable_Line__c WHERE Expense_GL_Account__c = :testGL.Id].size());

            DMLException dmlEx;
            try {
                delete testGL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedBillingLineExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            GL_Account__c testGL = new GL_Account__c(
                Name = 'test-gl',
                Active__c = true,
                Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
            );
            insert testGL;

            Billing_Line__c newItem = testData.billingLines[0].clone(false);
            newItem.Revenue_GL_Account__c = testGL.Id;
            insert newItem;
            System.assertEquals(1, [SELECT Id FROM Billing_Line__c WHERE Revenue_GL_Account__c = :testGL.Id].size());

            DMLException dmlEx;
            try {
                delete testGL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedJELineExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createBankDeposits()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            GL_Account__c testGL = new GL_Account__c(
                Name = 'test-gl',
                Active__c = true,
                Type__c = GLAccountActions.GL_ACCOUNT_TYPE_REVENUE
            );
            insert testGL;

            Journal_Entry_Line__c newItem = testData.journalEntryLines[0].clone(false);
            newItem.GL_Account__c = testGL.Id;
            insert newItem;
            System.assertEquals(1, [SELECT Id FROM Journal_Entry_Line__c WHERE GL_Account__c = :testGL.Id].size());

            DMLException dmlEx;
            try {
                delete testGL;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedRecurringBillingLineExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                delete testData.glAccounts[11];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedRecurringPayableLineExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                delete testData.glAccounts[11];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedRecurringJELineExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringJournalEntry()
            .createRecurringJournalEntryLines();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                delete testData.glAccounts[16];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedExpenseLineExists() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createExpenseReports()
            .createExpenseLines();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                delete testData.glAccountsExpense[2];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventDeleteIfRelatedLedgerExists() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                delete testData.glAccounts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testGLAccountNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                GL_Account__c ga = new GL_Account__c();

                try {
                    insert ga;
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
    private static void testTotalNumberOfGlAccountsLimit() {
        FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_GL_ACCOUNT_LIMIT, 30);
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Integer currentNumberOfExistedGLAccounts = DomainUtils.countActiveGlAccounts(
                new List<String>{
                    GLAccountActions.GL_ACCOUNT_TYPE_REVENUE,
                    GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE,
                    GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET
                }
            );
            System.assertEquals(testData.glAccounts.size(), currentNumberOfExistedGLAccounts);
            System.assertEquals(30, GLAccountActions.GL_ACCOUNT_TOTAL_LIMIT);

            List<GL_Account__c> newGLAccounts = new List<GL_Account__c>{
                testData.glAccounts[0].clone(),
                testData.glAccounts[0].clone()
            };

            DMLException dmlEx;
            try {
                insert newGLAccounts;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountActions.GL_ACCOUNT_MAX_LIMIT_REACHED, dmlEx.getDmlMessage(0));
        }
    }

}