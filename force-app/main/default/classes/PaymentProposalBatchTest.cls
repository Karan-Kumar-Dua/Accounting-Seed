@IsTest
public with sharing class PaymentProposalBatchTest {

    private static Final String STATUS_PROCESSED = 'Processed';

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest 
    public static void testPaymentProposalAggregateByPayeeFalse(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        Test.startTest();
        testData.createPaymentProposals();
        System.runAs(testData.users[1]) {
            Payment_Proposal__c payProp = testData.paymentProposals[1];

            Database.executeBatch(new PaymentProposalBatch(payProp));
            Test.stopTest();

            Assert.areEqual(2, [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :payProp.Id ].size());
            Assert.areEqual(2, [SELECT Id FROM AP_Disbursement__c WHERE Payment_Proposal_Line__r.Payment_Proposal__r.Id = :payProp.Id].size());
            //Assert.areEqual(STATUS_PROCESSED, [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id = :payProp.Id].Status__c);
        } 
    }

    @IsTest 
    public static void testPaymentProposalAggregateByPayeeTrue(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        Test.startTest();
        testData.createPaymentProposals();

        System.runAs(testData.users[1]) {
            Payment_Proposal__c payProp = testData.paymentProposals[0];

            Database.executeBatch(new PaymentProposalBatch(payProp));
            Test.stopTest();

            Payment_Proposal__c pp = [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id= :testData.paymentProposals[0].Id];

            List<Cash_Disbursement__c> cd = [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :payProp.Id];
            Assert.areEqual(1,cd.size());

            List<AP_Disbursement__c> adps = [SELECT id FROM AP_Disbursement__c WHERE Payment_Proposal_Line__r.Payment_Proposal__r.Id = :payProp.Id];
            Assert.areEqual(2,adps.size());

            //Assert.areEqual(STATUS_PROCESSED,pp.Status__c);
        } 
    }

    @IsTest 
    public static void testPaymentProposalAggregateByPayeeTrueWithCreditMemo(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        Test.startTest();
        testData.createPaymentProposals();

        System.runAs(testData.users[1]) {
            
            Payment_Proposal__c payProp = testData.paymentProposals[2];
            Database.executeBatch(new PaymentProposalBatch(payProp));
            Test.stopTest();

            Payment_Proposal__c pp = [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id= :testData.paymentProposals[2].Id];

            List<Cash_Disbursement__c> cd = [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :payProp.Id];
            Assert.areEqual(1, cd.size());

            List<AP_Credit_Memo__c> apcm = [SELECT id FROM AP_Credit_Memo__c WHERE Payment_Proposal_Line__r.Payment_Proposal__r.Id = :payProp.Id];
            Assert.areEqual(1, apcm.size());

            List<AP_Disbursement__c> adps = [SELECT id FROM AP_Disbursement__c WHERE Payment_Proposal_Line__r.Payment_Proposal__r.Id = :payProp.Id];
            Assert.areEqual(1, adps.size());

            //Assert.areEqual(STATUS_PROCESSED, pp.Status__c);
        } 
    }

    @IsTest 
    public static void testPaymentProposalAggregateByPayeeFalseNotPosted(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        System.runAs(testData.users[1]) {
            Payment_Proposal__c payProp = testData.paymentProposals[1];
            Test.startTest();
                Database.executeBatch(new PaymentProposalBatch(payProp));
            Test.stopTest();

            Assert.areEqual(0, [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :payProp.Id].size());

            List<Payment_Proposal_Line__c> ppls = [SELECT Id, Error__c FROM Payment_Proposal_Line__c WHERE Payment_Proposal__c = :payProp.Id];
            Assert.areEqual(4, ppls.size());
            for(Payment_Proposal_Line__c ppl : ppls ){
                Assert.areEqual(SObjectType.Payment_Proposal_Line__c.getLabel() + ': ' + Label.ERR_PPL_POST_STATUS, ppl.Error__c);
            }
        
            Payment_Proposal__c pp = [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id= :payProp.Id];
            //Assert.areEqual(STATUS_PROCESSED,pp.Status__c);
        } 
    }

    @IsTest 
    public static void testPaymentProposalAggregateByPayeeFalseClosedPeriod(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        Test.startTest();
        testData.createPaymentProposals();
        List<Accounting_Period__c> initialAccountingPeriods = testData.acctPeriods;
        for (Accounting_Period__c period : initialAccountingPeriods) {
            period.Status__c = AccountingPeriodActions.CLOSED_STATUS;
        }
        Database.update(initialAccountingPeriods, false);
      
        System.runAs(testData.users[1]) {
            Payment_Proposal__c payProp = testData.paymentProposals[1];
                Database.executeBatch(new PaymentProposalBatch(payProp));
            Test.stopTest();

            Assert.areEqual(0, [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :payProp.Id].size());
            List<Payment_Proposal_Line__c> ppls = [SELECT Id, Error__c FROM Payment_Proposal_Line__c WHERE Payment_Proposal__c = :payProp.Id];
            Assert.areEqual(4, ppls.size());
            for(Payment_Proposal_Line__c ppl : ppls ){
                Assert.areEqual(SObjectType.Payment_Proposal_Line__c.getLabel() + ': ' + Label.ERR_ACCOUNTING_PERIOD_CLOSED, ppl.Error__c);
            }
        
            Payment_Proposal__c pp = [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id= :payProp.Id];
            //Assert.areEqual(STATUS_PROCESSED,pp.Status__c);
        } 
    }

    @IsTest 
    public static void testPaymentProposalAggregateByPayeeTrueInvalidAPD(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();

        List<Accounting_Period__c> initialAccountingPeriods = testData.acctPeriods;
        for (Accounting_Period__c period : initialAccountingPeriods) {
            period.Status__c = AccountingPeriodActions.CLOSED_STATUS;
        }
        Database.update(initialAccountingPeriods, false);
      
        System.runAs(testData.users[1]) {
            Payment_Proposal__c payProp = testData.paymentProposals[0];


            Test.startTest();
                Database.executeBatch(new PaymentProposalBatch(payProp));
            Test.stopTest();

            Payment_Proposal__c pp = [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id= :payProp.Id];
            List<Cash_Disbursement__c> cd = [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :payProp.Id];
            List<Payment_Proposal_Line__c> ppl = [SELECT Id, Error__c FROM Payment_Proposal_Line__c WHERE Payment_Proposal__c = :payProp.Id];
 
            Assert.areEqual(0,cd.size());
            //Assert.areEqual(STATUS_PROCESSED,pp.Status__c);
        } 
    }

    @IsTest 
    public static void testPaymentProposalMultipleRecords(){
        Test.startTest();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        testData.createPaymentProposals();

        System.runAs(testData.users[1]) {
            List<Payment_Proposal__c> ppToUpdate = new List<Payment_Proposal__c>();
            Database.executeBatch(new PaymentProposalBatch());
            Test.stopTest();  
        } 

        List<Cash_Disbursement__c> cdFromAggByPayee = [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :testData.paymentProposals[0].Id ];
        Assert.areEqual(1,cdFromAggByPayee.size());

        List<Cash_Disbursement__c> cdFromNonAggByPayee = [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :testData.paymentProposals[1].Id ];
        Assert.areEqual(2,cdFromNonAggByPayee.size());

        List<Cash_Disbursement__c> cdFromAggByPayeeWithCreditMemo = [SELECT id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :testData.paymentProposals[2].Id ];
        Assert.areEqual(1,cdFromAggByPayeeWithCreditMemo.size());

        List<AP_Credit_Memo__c> apcm = [SELECT id FROM AP_Credit_Memo__c WHERE Payment_Proposal_Line__r.Payment_Proposal__r.Id = :testData.paymentProposals[2].Id ];
        Assert.areEqual(1, apcm.size());

        List<AP_Disbursement__c> adps = [SELECT id FROM AP_Disbursement__c WHERE Payment_Proposal_Line__r.Payment_Proposal__r.Id = :testData.paymentProposals[2].Id ];
        Assert.areEqual(1, adps.size());
        
        for(Payment_Proposal__c pp : [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id= :testData.paymentProposals[0].Id]){
            //Assert.areEqual(STATUS_PROCESSED,pp.Status__c);
        }
    }

    @IsTest 
    public static void testPaymentProposalRelatedRecordsCurrency(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables(true)
                .createPaymentProposals();
            Test.startTest();
            System.runAs(testData.users[1]) {
                List<Payment_Proposal_Line__c> paymentProposalLines = new List<Payment_Proposal_Line__c>();
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                
                Payment_Proposal__c pp = testData.paymentProposals[1].clone(false,true);
                pp.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert pp;
                
                Payment_Proposal_Line__c parentPPL = new Payment_Proposal_Line__c(Payment_Proposal__c = pp.Id,Vendor__c = testData.accounts[0].Id);
            	insert parentPPL;
                
                paymentProposalLines.add(
                    new Payment_Proposal_Line__c(Amount__c = 1,
                                                 Payable__c = testData.payables[0].Id,
                                                 Payment_Proposal__c = testData.paymentProposals[0].Id,
                                                 Vendor__c = testData.payables[0].Vendor__c,
                                                 Parent__c = parentPPL.Id)
                );
                
                insert paymentProposalLines;
                Database.executeBatch(new PaymentProposalBatch(pp));
				
                Payment_Proposal__c ppRec = [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id= :pp.Id];
            	
                List<Cash_Disbursement__c> listOfCDs = [SELECT Id FROM Cash_Disbursement__c WHERE Payment_Proposal__r.Id = :pp.Id];
                List<AP_Disbursement__c> listOfAPs = [SELECT Id FROM AP_Disbursement__c WHERE Payment_Proposal_Line__r.Payment_Proposal__r.Id = :pp.Id];
                
                Assert.areEqual(ppRec.get('CurrencyISOCode'),listOfCDs[0].get('CurrencyISOCode') );
            	Assert.areEqual(ppRec.get('CurrencyISOCode'),listOfAPs[0].get('CurrencyISOCode') );
    	    }
            Test.stopTest();
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }
}