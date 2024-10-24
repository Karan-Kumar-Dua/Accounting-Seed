@IsTest
public with sharing class PaymentProposalActionsTest {
    private static final String ERROR_PPL_CREDIT_MEMO_ON_PP = Label.ERROR_PPL_CREDIT_MEMO_ON_PP;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static String getObjectLabel() {
        schema.SObjectType sObjType = Payment_Proposal__c.sobjectType;
        Schema.DescribeSObjectResult dr = sObjType.getDescribe();
        return dr.getLabel();
    }

    @IsTest
    public static void testPaymentProposalObjectRestrictOnPaymentFeatureDisable() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, False);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

            try {
                testData.createPaymentProposals();
            } catch (DMLException ex) {
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_OBJECT_FEATURE_DISABLED, new List<String>{getObjectLabel()})));
            }

            Test.stopTest();
        }
    }

    @IsTest
    public static void testPPRestrictOnPaymentFeatureEnable(){
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
            TestDataSuite testPayProps = testData.createPaymentProposals();

            Test.stopTest();

            Assert.areEqual(3, testPayProps.paymentProposals.size());
        }
    }

    @IsTest
    public static void testUpdatePPRestrictOnPaymentFeatureDisable(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, False);
        System.runAs(testData.users[1]) {
            Test.startTest();
            try {
                Payment_Proposal__c payProp = testData.paymentProposals[0];
                payProp.Description__c = 'updated desc';
                update payProp;

            } catch (DMLException ex) {
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_OBJECT_FEATURE_DISABLED, new List<String>{getObjectLabel()})));
            }

            Test.stopTest();
        }
    }

    @IsTest
    public static void testUpdatePPRestrictOnPaymentFeatureEnable(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Payment_Proposal__c payProp = testData.paymentProposals[0];
            payProp.Description__c = 'updated desc';
            update payProp;

            Test.stopTest();

            Assert.areEqual('updated desc', [SELECT Description__c FROM Payment_Proposal__c WHERE Id = :payProp.Id].Description__c);
        }
    }

    @IsTest
    public static void testPPAggregateByPayeeTrueToFalse(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Proposal__c payProp = testData.paymentProposals[0];
            List<Payment_Proposal_Line__c> ppLines = [
                    SELECT Id, Due_Date__c, Payment_Proposal__c, Payable__c, Posting_Status__c
                    FROM Payment_Proposal_Line__c
                    WHERE Payment_Proposal__c = :payProp.Id
            ];
            Assert.areEqual(3, ppLines.size());

            //disable Agg By Payee
            payProp = testData.paymentProposals[0];
            payProp.Aggregate_by_Payee__c = false;
            update payProp;

            ppLines = [
                    SELECT Id, Parent__c
                    FROM Payment_Proposal_Line__c
                    WHERE Payment_Proposal__c = :testData.paymentProposals[0].Id
            ];
            Assert.areEqual(2, ppLines.size());
            Assert.areEqual(ppLines[0].Parent__c, null);
            Test.stopTest();


        }
    }

    @IsTest
    public static void testValidatePayableCreditMemo(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        System.runAs(testData.users[1]) {
            Payment_Proposal__c payProp = testData.paymentProposals[2];
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                payProp.Aggregate_by_Payee__c = false;
                update payProp;
            } catch (Exception ex) {
                exceptionThrown = (ex.getMessage().contains(ERROR_PPL_CREDIT_MEMO_ON_PP)) ? true : false;
            }

            Assert.isTrue(exceptionThrown);

            Test.stopTest();
        }
    }
    
    @IsTest 
    public static void testValidateCurrencyCodeUpdate(){
        Test.startTest();
        Boolean exceptionThrown = false;
        try {

            TestDataSuite testData = TestDataSuite.getInstance()
            .enableMultiCurrency()
            .createPayables()
            .createPaymentProposals();
        
        System.runAs(testData.users[1]) {
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
            String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
            
            //If there is no another currency except current - there is nothing to test
            if (String.isBlank(theNewCurrencyIsoCode)) {
                return;
            }
            TestDataSuite testPayProps = testData.createPaymentProposals();

            Payment_Proposal__c payProp = testPayProps.paymentProposals[2];

           	payProp.put('CurrencyIsoCode', theNewCurrencyIsoCode);
            update payProp;
           }
            
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
        catch(Exception ex) {
            exceptionThrown =  (ex.getMessage().contains(Label.ERR_PP_CANNOT_UPDATE_CURRENCY_PPL_EXIST)) ? true : false; 
            Assert.isTrue(exceptionThrown);
        }
        
        Test.stopTest();
    }
    
    @IsTest
    private static void testValidateCurrencyISOCode() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPayables().createPaymentProposals();

            Test.startTest();
            System.runAs(testData.users[1]) {

                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Boolean exceptionThrown = false;

                Payment_Proposal__c paymentProposal = testData.paymentProposals[0].clone();
                paymentProposal.put('CurrencyISOCode', theNewCurrencyIsoCode);
                insert paymentProposal;

                paymentProposal.Type__c = 'AS Pay';

                try {
                    update paymentProposal;
                } catch (Exception e) {
                    exceptionThrown = e.getMessage().contains(Label.ERROR_INVALID_CURRENCYISOCODE_PAYMENTPROPOSAL);
                }

                Assert.isTrue(exceptionThrown);
            }
            Test.stopTest();
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testPaymentProposalDateFilters(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                Payment_Proposal__c payProp = testData.paymentProposals[0];
                payProp.AcctSeed__Payment_Proposal_Date__c = null;
                payProp.Relative_Due_Date__c = 'TODAY';
                update payProp;

            } catch (DMLException ex) {
                exceptionThrown = (ex.getMessage().contains(Label.ERR_PP_DATE_IS_REQUIRED)) ? true : false;
            }

            Assert.isTrue(exceptionThrown);

            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testPPLedgerValue(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        System.runAs(testData.users[1]) {
            Test.startTest();
                Payment_Proposal__c payProp = testData.paymentProposals[0];
                payProp.AcctSeed__Ledger__c = null;
                update payProp;
				
            	Accounting_Settings__c accSettingRec = [SELECT ID,Default_Ledger__c,Default_Ledger__r.Name FROM Accounting_Settings__c LIMIT 1];
				
            	Payment_Proposal__c ppRec = [SELECT ID,Ledger__r.Name FROM Payment_Proposal__c WHERE ID=:payProp.Id];
            
            	System.assertEquals(ppRec.Ledger__r.Name,accSettingRec.Default_Ledger__r.Name);
            	
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPpBankAccountEnrollmentStatus(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals().createBankAccounts();
        System.runAs(testData.users[1]) {
            Test.startTest();
                Boolean exceptionThrown = false;
                Bank_Account__c bankRec = [SELECT ID,NAME FROM Bank_Account__c WHERE ID =: testData.bankAccounts[0].Id];
                try{
                    GL_Account__c glAccountRec = testData.glAccounts[0];
                    glAccountRec.Bank_Account__c = testData.bankAccounts[0].Id;
                    update glAccountRec;

                    Payment_Proposal__c payProp = testData.paymentProposals[0];
                    payProp.Type__c = 'AS Pay';
                    payProp.Bank_GL_Account__c = glAccountRec.Id;
                    update payProp;

                }catch(DmlException ex){
                    exceptionThrown = (ex.getMessage().contains(String.format(Label.ERR_REQUIRED_APPROVED_BANK_ACC_ON_GLACCOUNT_OF_CD, 
                    new List<String>{String.valueOf(bankRec.Name)}))) ? true : false;
                }
            	
            Assert.isTrue(exceptionThrown);
            
            Test.stopTest();

        }
    }

}