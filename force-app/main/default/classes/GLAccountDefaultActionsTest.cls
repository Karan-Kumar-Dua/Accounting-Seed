@IsTest
private class GLAccountDefaultActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGlValidatorForPrepaidExpenseGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            String key = String.join(new List<String>{
                    'Prepaid_Expense_GL_Account',
                    testData.ledgers[0].Id
            }, ':');
            List<GL_Account_Default__c> glAccountDefaults = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE Unique_Key__c =: key
            ];
            GL_Account__c bankGlAccount = GLAccountValidatorTest.createBankGlAccount();
            glAccountDefaults[0].GL_Account__c = bankGlAccount.Id; //WRONG VALUE

            DmlException dmlEx;
            try {
                update glAccountDefaults;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountValidator.IS_BANK_ERROR, dmlEx.getDmlMessage(0));

            GLAccountDefaultActions.isPreventUpdateOverride = true;
            DmlException dmlEx2;
            try {
                update glAccountDefaults;
            }
            catch (DmlException ex) {
                dmlEx2 = ex;
            }

            System.assertEquals(NULL, dmlEx2);
        }
    }

    @IsTest
    public static void testGlValidatorForAccountingSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            GL_Account__c bankGlAccount = GLAccountValidatorTest.createBankGlAccount();

            Cash_Receipt__c testCR = new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = 100,
                    Payment_Reference__c = 'xxxxxxx',
                    Status__c = 'Approved',
                    Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = bankGlAccount.Id,
                    Credit_GL_Account__c = testData.glAccounts[8].Id
            );

            insert testCR;

            System.assertEquals(
                    false,
                    [SELECT Id FROM Transaction__c WHERE GL_Account__c = :testData.glAccounts[8].Id].isEmpty()
            );

            String key = String.join(new List<String>{
                    'Retained_Earnings_GL_Account',
                    testData.ledgers[0].Id
            }, ':');
            List<GL_Account_Default__c> glAccountDefaults = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE Unique_Key__c =: key
            ];
            glAccountDefaults[0].GL_Account__c = testData.glAccounts[11].Id;

            DmlException dmlEx;
            try {
                update glAccountDefaults;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(String.format(GLAccountValidator.EXISTED_TRANSACTION_ERROR, new List<String>{testData.glAccounts[8].Name}), dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testGlValidatorForAccountingSettingsTypeAndSubtype1() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            GL_Account_Default__c glAccountDefault = new GL_Account_Default__c(
                    GL_Account__c = testData.glAccounts[0].Id,
                    Ledger__c = testData.ledgers[0].Id,
                    GL_Account_Specification__c = 'CTA_GL_Account'
            );

            DmlException dmlEx;
            try {
                insert glAccountDefault;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(String.format(GLAccountValidator.NON_VALID_TYPE_AND_SUBTYPE1_ERROR, new List<String>{
                    'Balance Sheet', 'Owners Equity'
            }), dmlEx.getDmlMessage(0));
            System.assert(dmlEx.getDmlMessage(0).contains('Subtype 1'));
        }
    }

    @IsTest
    public static void testGlValidatorNotBankAccountingSettingField() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashDisbursementBatches()
                .createCashDisbursements();

        System.runAs(testData.users[1]) {
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = 'Revenue_GL_Account'];

            GL_Account_Default__c glAccountDefault1 = new GL_Account_Default__c(
                    GL_Account__c = testData.glAccounts[0].Id,
                    Ledger__c = testData.ledgers[0].Id,
                    GL_Account_Specification__c = 'Revenue_GL_Account'
            );
            DmlException dmlEx;
            try {
                insert glAccountDefault1;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountValidator.IS_BANK_ERROR, dmlEx.getDmlMessage(0));

            String key = String.join(new List<String>{
                    'AP_Control_GL_Account',
                    testData.ledgers[0].Id
            }, ':');
            List<GL_Account_Default__c> glAccountDefaults = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE Unique_Key__c =: key
            ];
            glAccountDefaults[0].GL_Account__c = testData.glAccounts[0].Id;

            try {
                update glAccountDefaults;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountValidator.IS_BANK_ERROR, dmlEx.getDmlMessage(0));

            key = String.join(new List<String>{
                    'AR_Control_GL_Account',
                    testData.ledgers[0].Id
            }, ':');
            glAccountDefaults = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE Unique_Key__c =: key
            ];
            glAccountDefaults[0].GL_Account__c = testData.glAccounts[0].Id;

            try {
                update glAccountDefaults;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(GLAccountValidator.IS_BANK_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testValidateUniqueGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            GL_Account_Default__c arDef = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE Ledger__c =: testData.ledgers[0].Id
                        AND GL_Account_Specification__c =: GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT
            ];
            GL_Account_Default__c apDef = [
                    SELECT Id
                    FROM GL_Account_Default__c
                    WHERE Ledger__c =: testData.ledgers[0].Id
                    AND GL_Account_Specification__c =: GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT
            ];

            try {
                arDef.GL_Account__c = testData.glAccounts[4].Id;
                apDef.GL_Account__c = testData.glAccounts[2].Id;
                update new List<GL_Account_Default__c>{arDef, apDef};
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL ,dmlEx);

            try {
                arDef.GL_Account__c = testData.glAccounts[2].Id;
                update arDef;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                    GLAccountDefaultActions.UNIQUE_GL_ACCOUNT_ERROR,
                    dmlEx.getDmlMessage(0)
            );

        }
    }

    @IsTest
    public static void testValidateUniqueGLAccountAmortizationFields() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;

            try {
                GL_Account_Default__c arDef = [
                        SELECT Id
                        FROM GL_Account_Default__c
                        WHERE Ledger__c =: testData.ledgers[0].Id
                        AND GL_Account_Specification__c =: GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT
                ];
                GL_Account_Default__c apDef = [
                        SELECT Id
                        FROM GL_Account_Default__c
                        WHERE Ledger__c =: testData.ledgers[0].Id
                        AND GL_Account_Specification__c =: GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT
                ];
                arDef.GL_Account__c = testData.glAccounts[4].Id;
                apDef.GL_Account__c = testData.glAccounts[2].Id;
                update new List<GL_Account_Default__c>{arDef, apDef};
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL ,dmlEx);

            try {
                GL_Account_Default__c debitGlRevDef = [
                        SELECT Id
                        FROM GL_Account_Default__c
                        WHERE Ledger__c =: testData.ledgers[0].Id
                        AND GL_Account_Specification__c =: GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE
                ];
                debitGlRevDef.GL_Account__c = testData.glAccounts[2].Id;
                update debitGlRevDef;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                    GLAccountDefaultActions.UNIQUE_AMORT_GL_ACCOUNT_ERROR,
                    dmlEx.getDmlMessage(0)
            );
        }
    }
}