@IsTest
public with sharing class PaymentProposalLineActionsTest{
    private static final String ERROR_PPL_CREDIT_MEMO = Label.ERROR_PPL_CREDIT_MEMO;
    @TestSetup
    private static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPaymentProposalLineObjectVendorValidation(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        System.runAs(testData.users[1]){
            Test.startTest();
            Boolean exceptionThrown = false;
            try{
                Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                    Payment_Proposal__c = testData.paymentProposals[0].Id, 
                    Vendor__c = testData.accounts[1].Id, 
                    Payable__c = testData.payables[0].Id
                );

                insert ppl;
            } catch (Exception ex){
                exceptionThrown = (ex.getMessage().contains(Label.ERROR_VENDOR_PPL)) ? true : false;
            }
            Assert.isTrue(exceptionThrown);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPaymentProposalLineObjectVendorValidationUpdate(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        System.runAs(testData.users[1]){
            Test.startTest();
            Boolean isError = false;
            try{
                Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                    Payment_Proposal__c = testData.paymentProposals[0].Id, 
                    Vendor__c = testData.accounts[0].Id, 
                    Payable__c = testData.payables[0].Id
                );

                insert ppl;

                ppl.Vendor__c = testData.accounts[1].Id;
                update ppl;
            } catch (Exception ex){
                isError = true;
            }
            Assert.isTrue(isError);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPaymentProposalLineObjectAmountValidation(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        System.runAs(testData.users[1]){
            Test.startTest();
            Boolean isError = false;
            try{
                Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                    Payment_Proposal__c = testData.paymentProposals[0].Id, 
                    Payable__c = testData.payables[0].Id, 
                    Amount__c = 10000
                );

                insert ppl;
            } catch (Exception ex){
                isError = true;
            }
            Assert.isTrue(isError);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPaymentProposalLineAmountValidationUpdate(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        System.runAs(testData.users[1]){
            Test.startTest();
            Boolean isError = false;
            try{
                Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                    Payment_Proposal__c = testData.paymentProposals[0].Id, 
                    Payable__c = testData.payables[0].Id, 
                    Amount__c = 10
                );

                insert ppl;

                ppl.Amount__c = 100000;
                update ppl;
            } catch (Exception ex){
                isError = true;
            }
            Assert.isTrue(isError);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testValidatePayableCreditMemo(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        System.runAs(testData.users[1]){
            Test.startTest();
            Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                Amount__c = 0, 
                Payable__c = testData.payables[4].Id, 
                Payment_Proposal__c = testData.paymentProposals[1].Id, 
                Vendor__c = testData.accounts[0].Id
            );

            Boolean exceptionThrown = false;
            try{
                insert ppl;
            } catch (Exception ex){
                exceptionThrown = (ex.getMessage().contains(ERROR_PPL_CREDIT_MEMO)) ? true : false;
            }
            Assert.isTrue(exceptionThrown);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPPLIsParentField() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Proposal__c plRec = new Payment_Proposal__c(
                    Description__c = 'Test Payment Proposal 0',
                    Account__c = testData.accounts.get(1).Id,
                    Proprietary_Payable_Number__c = '1',
                    Payment_Date__c = testData.acctPeriods[1].Start_Date__c,
                    Ledger__c = testData.ledgers[0].Id,
                    Type__c = 'Check',
                    Bank_GL_Account__c = testData.glAccounts[0].id,
                    Aggregate_By_Payee__c = true,
                    Status__c = 'Approved'
            );

            insert plRec;

            Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                    Payment_Proposal__c = plRec.Id,
                    Amount__c = 10
            );
            insert ppl;

            Payment_Proposal_Line__c pplRec = [SELECT Id, Is_Parent__c FROM Payment_Proposal_Line__c LIMIT 1];
            Assert.areEqual(true, pplRec.Is_Parent__c);

            ppl.Payable__c = testData.payables[0].Id;
            update ppl;

            Payment_Proposal_Line__c updatedPplRec = [SELECT Id, Is_Parent__c FROM Payment_Proposal_Line__c LIMIT 1];
            Assert.areEqual(false, updatedPplRec.Is_Parent__c);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testValidateCurrencyIsoCode(){
        try {
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPayables().createPaymentProposals();

            Test.startTest();
            String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();

            if (String.isBlank(theNewCurrencyIsoCode)) {
                return;
            }

            Account_Payable__c testPayable = testData.payables[0].clone();
            testPayable.put('CurrencyIsoCode', theNewCurrencyIsoCode);
            testPayable.put('Currency_Conversion_Rate__c', MultiCurrencyHandler.getConversionRateByCurrencyCode(theNewCurrencyIsoCode));
            testPayable.put('Payee_Reference__c', '3525125131ananananana');
            insert testPayable;

            Payment_Proposal_Line__c testPaymentProposalLine = testData.paymentProposalLines[0].clone();
            testPaymentProposalLine.put('AcctSeed__Amount__c', 0);
            testPaymentProposalLine.put('Payable__c', testPayable.Id);

            Boolean exceptionThrown = false;

            try {
                insert testPaymentProposalLine;
            } catch (Exception e) {
                exceptionThrown = e.getMessage().contains(Label.ERROR_INVALID_CURRENCYISOCODE_PAYABLE);
            }

            Assert.isTrue(exceptionThrown);
            Test.stopTest();
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testPPLForNegativeDiscountAmt() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        System.runAs(testData.users[1]) {
            Test.startTest();
                Boolean isError = false;
                try {
                    Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                        Payment_Proposal__c = testData.paymentProposals[0].Id,
                        Payable__c = testData.payables[0].Id,
                        Amount__c = 10000,
                        Discount_Amount__c = -1
                    );

                    insert ppl;
                }catch(Exception ex) {
                    isError = ex.getMessage().contains(Label.ERR_PPL_DISCOUNT_AMOUNT_LESS_THAN_ZERO)?true:false;
                }
                Assert.isTrue(isError);
            Test.stopTest();
        }
    }
    
    @IsTest
    public static void testPPLForDiscountAmtMoreThenCurrentAmt() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        System.runAs(testData.users[1]) {
            Test.startTest();
                Boolean isError = false;
                try {
                        Payment_Proposal__c plRec = new Payment_Proposal__c(
                        Description__c = 'Test Payment Proposal 0',
                        Account__c = testData.accounts.get(1).Id,
                        Proprietary_Payable_Number__c = '1',
                        Payment_Date__c = testData.acctPeriods[1].Start_Date__c,
                        Ledger__c = testData.ledgers[0].Id,
                        Type__c = 'Check',
                        Bank_GL_Account__c = testData.glAccounts[0].id, 
                        Aggregate_By_Payee__c = true,
                        Status__c = 'Approved'
                    );
                    
                    insert plRec;
                        
                    Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(
                        Payment_Proposal__c = plRec.Id,
                        Amount__c = 10,
                        Discount_Amount__c = 10
                    );
                    insert ppl;
                    
                }catch(Exception ex) {
                    isError = ex.getMessage().contains(Label.ERR_PPL_DISCOUNT_AMOUNT_NOT_MORE_THAN_CURRENT_BALANCE)?true:false;
                }
                Assert.isTrue(isError);
            Test.stopTest();
        }
    }

    
    @IsTest
    public static void testValidatePaymentBalance() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                Payment_Proposal_Line__c testPaymentProposalLine = testData.paymentProposalLines[0];
                testPaymentProposalLine.Amount__c = null;
                testPaymentProposalLine.Payable__c = testData.payables[6].Id;
                update testPaymentProposalLine;
            } catch (Exception e) {
                exceptionThrown = e.getMessage().contains(Label.ERROR_CANNOT_ADD_PAYABLE_WITH_0_BALANCE);
            }
            Assert.isTrue(exceptionThrown);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testValidatePayable(){
        Test.startTest();
        Boolean exceptionThrown = false;
        try {

            TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users[1]) {
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);

            testData.payables[0].On_Hold__c = true;
            update testData.payables[0];

            TestDataSuite testPayProps = testData.createPaymentProposals();
           }

        }
        catch(Exception ex) {
            exceptionThrown = ex.getMessage().contains(Label.ERROR_PAYABLE_ON_HOLD_PPL);
        }

        Assert.isTrue(exceptionThrown);

        Test.stopTest();
    }
}