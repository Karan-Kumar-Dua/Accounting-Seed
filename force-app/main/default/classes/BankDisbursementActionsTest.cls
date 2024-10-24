@IsTest
public with sharing class BankDisbursementActionsTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static String getObjectLabel() {
        schema.SObjectType sObjType = Bank_Disbursement__c.sobjectType;
        Schema.DescribeSObjectResult dr = sObjType.getDescribe();
        return dr.getLabel();
    }
    
    @IsTest 
    public static void testBankDisObjectRestrictOnPaymentFeatureDisable(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            try {
                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, False);
                testData.createBankDisbursements();

            }
            catch(DMLException ex) {
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_OBJECT_FEATURE_DISABLED, new List<String>{getObjectLabel()})));
            }

            Test.stopTest();
        }
    }

    @IsTest 
    public static void testpreventUpdatingBankGLAccIfChildRecords(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts()
            							.createBankDisbursements().createCashDisbursementBatches().createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
                try {
                    testData.cashDisbursements[0].Bank_Disbursement__c = testData.bankDisbursements[0].Id;
                    update testData.cashDisbursements[0];
                    
                    testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
                    update testData.bankDisbursements[0];
                }
                catch(DMLException ex) {
                    Assert.isNotNull(ex);
                    Assert.isTrue(ex.getMessage().contains(Label.ERR_PREVENT_FIELDS_UPDATE_IF_RECORDS_ASSOCIATD_ON_BD));
                }
            Test.stopTest();
        }
    }

    @IsTest 
    public static void testpreventUpdatingGlVariable1IfChildRecords(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables().createBankDisbursements().createCashDisbursementBatches().createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
                try {
                    testData.cashDisbursements[0].Bank_Disbursement__c = testData.bankDisbursements[0].Id;
                    update testData.cashDisbursements[0];

                    testData.bankDisbursements[0].GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
                    update testData.bankDisbursements[0];
                }
                catch(DMLException ex) {
                    Assert.isNotNull(ex);
                    Assert.isTrue(ex.getMessage().contains(Label.ERR_PREVENT_FIELDS_UPDATE_IF_RECORDS_ASSOCIATD_ON_BD));
                }
            Test.stopTest();
        }
    }

    @IsTest 
    public static void testpreventUpdatingLedgerIfChildRecords(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
                DMLException dmlEx;
                try {
                    testData.cashDisbursements[0].Bank_Disbursement__c = testData.bankDisbursements[0].Id;
                    update testData.cashDisbursements[0];

                    testData.bankDisbursements[0].Ledger__c = testData.ledgers.get(2).Id;
                    update testData.bankDisbursements[0];
                }
                catch(DMLException ex) {
                    dmlEx = ex;
                }
                System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
            Test.stopTest();
        }
    }

    @IsTest 
    public static void testpreventUpdatingCurrencyIfChildRecords(){
        try {
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createBankDisbursements().createCashDisbursementBatches().createCashDisbursements(false);
            
            System.runAs(testData.users[1]) {
                Test.startTest();
                
                
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                
                testData.cashDisbursements[0].Bank_Disbursement__c = testData.bankDisbursements[0].Id;
                update testData.cashDisbursements[0];
                
                testData.bankDisbursements[0].put('CurrencyIsoCode', 'EUR');
                
                DmlException dmlEx;
                try {
                    update testData.bankDisbursements[0];
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
                
                Test.stopTest();
            }
        }
        catch(TestDataSuite.TestDataSuiteException ex) {
            ex = ex;
        }
    }

    @IsTest
    public static void testLedgerAmountUpdate() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements();

            System.runAs(testData.users[1]) {
                testData.bankDisbursements[0].Ledger_Amount__c = 100;
    
                DMLException dmlEx;
                try {
                    update testData.bankDisbursements[0];
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
            }

    }

    @IsTest
    public static void testBankRecUpdate() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createBankReconciliations();

            System.runAs(testData.users[1]) {
                testData.bankDisbursements[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
    
                DMLException dmlEx;
                try {
                    update testData.bankDisbursements[0];
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
            }
    }

    @IsTest
    public static void testRequireFieldsUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.bankDisbursements[0].Ledger__c = NULL;

            DMLException dmlEx;
            try {
                update testData.bankDisbursements[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testDefaultValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            
            Bank_Disbursement__c bankDisbRec = new Bank_Disbursement__c(
                Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c,
                Bank_GL_Account__c = testData.glAccounts[0].Id,
                Disbursement_Reference__c = 'the reference 1'
            );

            insert bankDisbRec;

            Bank_Disbursement__c bankDisb = [SELECT Id, Ledger__c FROM Bank_Disbursement__c WHERE Id =: bankDisbRec.Id];

            Test.stopTest();

            Id expected = LedgerHandler.getLedgerIdWithSharing();
            System.assertEquals(expected, bankDisb.Ledger__c);
        }
    }

    @IsTest
    public static void testValidateLedgerType() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDisbursements();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        
        System.runAs(testData.users.get(1)) {
            //Create Consolidation & Elimination Ledger
            Ledger__c consLedger = testData.ledgers.get(0).clone();
            consLedger.Type__c = LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL;
            insert consLedger;

            List<Ledger__c> eliminationLedgers = [
                SELECT Id FROM Ledger__c WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
            ];
            System.assertNotEquals(true, eliminationLedgers.isEmpty());
            testData.bankDisbursements[0].Ledger__c = consLedger.Id;

            Test.startTest();

            DmlException dmlEx;
            try {
                update testData.bankDisbursements[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(
                Label.ERR_LEDGER_TYPE_TRANSACTIONAL_ONLY, dmlEx.getDmlMessage(0)
            );
        }

    }
}