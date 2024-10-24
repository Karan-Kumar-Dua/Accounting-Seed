@IsTest
public with sharing class PaymentProposalTest {

    private static Final String STATUS_PROCESSED = 'Processed';

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest 
    public static void testSearch(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

                TestDataSuite testPayProps = testData.createPaymentProposals();
                
                Payment_Proposal__c pp = [Select Id, Payable_Name__c, Payable_Name_Operator__c,
                        Proprietary_Payable_Number__c, Proprietary_Payable_Number_Operator__c, Payee_Reference__c , Payee_Reference_Operator__c,
                        Alternate_Payee__c,Alternate_Payee_Operator__c, Relative_Due_Date__c,Relative_Early_Pay_Date__c,Relative_Issue_Date__c
                        FROM Payment_Proposal__c where Id = :testPayProps.paymentProposals[0].id];
                
                pp.Payable_Name__c = 'AP-00001';
                pp.Payable_Name_Operator__c = 'not equal to';
                pp.Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh';
                pp.Payee_Reference_Operator__c = 'equals';
                pp.Proprietary_Payable_Number__c = '1';
                pp.Proprietary_Payable_Number_Operator__c = 'contains';
                pp.Alternate_Payee__c = '99999';
                pp.Alternate_Payee_Operator__c = 'does not contain';
            	pp.AcctSeed__Conditions_Met__c = 'Any';
                update pp;
                
                PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                List<AcctSeed__Account_Payable__c> paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(5, paybles.size());         
            Test.stopTest();
        } 
    }

    @IsTest 
    public static void testBasicSearch() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

                TestDataSuite testPayProps = testData.createPaymentProposals();
                
                Payment_Proposal__c pp = testPayProps.paymentProposals[0];
                pp.Payable_Name__c = 'AP-00001';
                pp.Payable_Name_Operator__c = 'not equal to';
                pp.Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh';
                pp.Payee_Reference_Operator__c = 'equals';
                pp.Proprietary_Payable_Number__c = '1';
                pp.Proprietary_Payable_Number_Operator__c = 'contains';
                pp.Alternate_Payee__c = '99999';
                pp.Alternate_Payee_Operator__c = 'does not contain';
            	pp.AcctSeed__Conditions_Met__c = 'Any';
                update pp;

                Map<String,Object> ppMap = (Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(pp));

                for(String key : ppMap.keySet()) {
                    if(key == 'attributes' || key == 'AcctSeed__Payment_Date__c' || key == 'Id') {
                        ppMap.remove(key);
                    }
                }

                PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.basicSearch(testPayProps.paymentProposals[0].id, JSON.serialize(ppMap));
            	List<AcctSeed__Account_Payable__c> paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(5, paybles.size());
      			
            Test.stopTest();
        } 
    }

    @IsTest
    private static void testBasicSearchMC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables()
                .createPaymentProposals();
            Test.startTest();
            System.runAs(testData.users[1]) {
                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                TestDataSuite testPayProps = testData.createPaymentProposals();
                
                Payment_Proposal__c pp = testPayProps.paymentProposals[0];
                pp.Payable_Name__c = 'AP-00001';
                pp.Payable_Name_Operator__c = 'not equal to';
                pp.Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh';
                pp.Payee_Reference_Operator__c = 'equals';
                pp.Proprietary_Payable_Number__c = '1';
                pp.Proprietary_Payable_Number_Operator__c = 'contains';
                pp.Alternate_Payee__c = '99999';
                pp.Alternate_Payee_Operator__c = 'does not contain';
            	pp.AcctSeed__Conditions_Met__c = 'Any';
                pp.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                update pp;

                Map<String,Object> ppMap = (Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(pp));

                for(String key : ppMap.keySet()) {
                    if(key == 'attributes' || key == 'AcctSeed__Payment_Date__c' || key == 'Id') {
                        ppMap.remove(key);
                    }
                }

                PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.basicSearch(testPayProps.paymentProposals[0].id, JSON.serialize(ppMap));
            	List<AcctSeed__Account_Payable__c> paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                //all payables are USD so no search results
                Assert.areEqual(0, paybles.size());

            }
            Test.stopTest();
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }
    
    @IsTest 
    public static void testcreatePPLinesForPayables() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

                TestDataSuite testPayProps = testData.createPaymentProposals();
                Assert.areEqual(3, testPayProps.paymentProposals.size());

                List<String> payableIds = new List<String>{testData.payables.get(0).Id};
                List<Payment_Proposal_Line__c> lines = (List<Payment_Proposal_Line__c>) PaymentProposal.createPPLinesForPayables(JSON.serialize(payableIds), testPayProps.paymentProposals[1].id);
                Assert.areEqual(1, lines.size());

                List<Payment_Proposal_Line__c> ppLines = [SELECT Id, Due_Date__c, Payment_Proposal__c, Payable__c, Posting_Status__c 
                                                            FROM Payment_Proposal_Line__c 
                                                            WHERE Id = :lines[0].Id 
                                                        ];
                Assert.areEqual(ppLines[0].Payment_Proposal__c, testPayProps.paymentProposals[1].id);
                Assert.areEqual(ppLines[0].Payable__c, testData.payables.get(0).Id);
                Assert.areEqual(ppLines[0].Due_Date__c, testData.payables.get(0).Due_Date__c);
                Assert.areEqual(ppLines[0].Posting_Status__c, testData.payables.get(0).Status__c);

            Test.stopTest();
        } 
    }

    @IsTest 
    public static void testcreatePPLinesForPayablesAggregateByPayeeTrue() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

            Payment_Proposal__c pp =
                    new Payment_Proposal__c(
                    Description__c = 'Test Payment Proposal 1',
                    Account__c = testData.Accounts[0].id,
                    Proprietary_Payable_Number__c = '1',
                    Payment_Date__c = Date.Today(),
                    Type__c = 'Check', 
                    Aggregate_by_Payee__c = true,
                    Ledger__c = testData.ledgers[0].Id,
                    Bank_GL_Account__c = testData.glAccounts[0].id
                ); 
                insert pp;


                List<String> payableIds = new List<String>{testData.payables.get(0).Id};
                List<Payment_Proposal_Line__c> lines = (List<Payment_Proposal_Line__c>) PaymentProposal.createPPLinesForPayables(JSON.serialize(payableIds), pp.id);
                Assert.areEqual(1, lines.size());

                List<Payment_Proposal_Line__c> ppLines = [Select Id, Due_Date__c, Payment_Proposal__c, Payable__c,
                                                          Posting_Status__c FROM Payment_Proposal_Line__c where Payment_Proposal__c = :pp.id
                                                        ];
                Assert.areEqual(2, ppLines.size());
                

            Test.stopTest();
        } 
    }
    
    ///PP batch processing is tested in PaymentProposalBatchTest.  The following method is to test the @Auraenabled entry point
    @IsTest
    public static void testPublishSinglePaymentProposal(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createPaymentProposals();
        Payment_Proposal__c payProp = testData.paymentProposals[0];
        System.runAs(testData.users[1]) {
            payProp.Status__c = 'Approved';
            update payProp;

            Payment_Proposal_Line__c ppl = new Payment_Proposal_Line__c(Amount__c = 0,
            Payable__c = testData.payables[0].Id,
            Payment_Proposal__c = testData.paymentProposals[0].Id,
            Vendor__c = testData.accounts[0].Id);

            insert ppl;
            Test.startTest();
                paymentProposal.publishSinglePaymentProposal(JSON.serialize(payProp));
            Test.stopTest();
        } 

        Payment_Proposal__c pp = [SELECT Id, Status__c FROM Payment_Proposal__c WHERE Id = :payProp.id];
        Assert.areEqual(STATUS_PROCESSED , pp.Status__c);
    }
    
    //Test all possible values of Date
    @IsTest 
    public static void testBasicSearchForRelativeDueDate() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();
    
                //For 'TODAY'
                Payment_Proposal__c pp =
                    new Payment_Proposal__c(
                    Description__c = 'Test Payment Proposal 1',
                    Account__c = testData.Accounts[0].id,
                    Payment_Date__c = Date.Today(),
                    Type__c = 'Check', 
                    Aggregate_by_Payee__c = true,
                    Ledger__c = testData.ledgers[0].Id,
                    Bank_GL_Account__c = testData.glAccounts[0].id,
                    Relative_Due_Date__c = 'TODAY',
                    Payment_Proposal_Date__c = Date.newInstance(1991, 10, 31),
                    Conditions_Met__c = 'All',
                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                    Posting_Status__c = 'Approved'
                ); 
                insert pp;
            
                PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                List<AcctSeed__Account_Payable__c> paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //For YESTERDAY
                pp.Relative_Due_Date__c = 'YESTERDAY';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 11, 1);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //For TOMORROW
                pp.Relative_Due_Date__c = 'TOMORROW';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 10, 30);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //For Next n Days
                pp.Relative_Due_Date__c = 'NEXT n DAYS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 10, 28);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //For Last n Days
                pp.Relative_Due_Date__c = 'LAST n DAYS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 10, 27);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(0, paybles.size());
    
                //For THIS WEEK
                pp.Relative_Due_Date__c = 'THIS WEEK';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 10, 29);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //For LAST WEEK
                pp.Relative_Due_Date__c = 'LAST WEEK';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 11, 4);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //NEXT n WEEKS
                pp.Relative_Due_Date__c = 'NEXT n WEEKS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 10, 21);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //LAST n WEEKS
                pp.Relative_Due_Date__c = 'LAST n WEEKS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 11, 11);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //THIS MONTH
                pp.Relative_Due_Date__c = 'THIS MONTH';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 10, 2);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //LAST MONTH
                pp.Relative_Due_Date__c = 'LAST MONTH';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 11, 25);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //NEXT n MONTHS
                pp.Relative_Due_Date__c = 'NEXT n MONTHS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 09, 11);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //LAST n MONTHS
                pp.Relative_Due_Date__c = 'LAST n MONTHS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1992, 01, 01);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
    
                //THIS QUARTER
                pp.Relative_Due_Date__c = 'THIS QUARTER';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 12, 31);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //LAST QUARTER
                pp.Relative_Due_Date__c = 'LAST QUARTER';
                pp.Payment_Proposal_Date__c = Date.newInstance(1992, 1, 31);
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //NEXT n QUARTERS
                pp.Relative_Due_Date__c = 'NEXT n QUARTERS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1991, 05, 01);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
    
                //LAST n QUARTERS
                pp.Relative_Due_Date__c = 'LAST n QUARTERS';
                pp.Payment_Proposal_Date__c = Date.newInstance(1992, 02, 01);
                pp.AcctSeed__Relative_Due_Date_Number_n__c = 3;
                update pp;
                wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
            Test.stopTest();
        } 
    }
    
    //Test all possible values of String fields
    public static void testBasicSearchForStringTypeFields() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True); 
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();
    
                Payment_Proposal__c pp =
                    new Payment_Proposal__c(
                    Description__c = 'Test Payment Proposal 1',
                    Account__c = testData.Accounts[0].id,
                    Payment_Date__c = Date.Today(),
                    Type__c = 'Check', 
                    Aggregate_by_Payee__c = true,
                    Ledger__c = testData.ledgers[0].Id,
                    Bank_GL_Account__c = testData.glAccounts[0].id,
                    Payment_Proposal_Date__c = Date.newInstance(1991, 10, 31),
                    Conditions_Met__c = 'All',
                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                    Payable_Name_Operator__c ='equals',
                    AcctSeed__Payable_Name__c = 'AP-00000'
                ); 
                insert pp;
            
                PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                List<AcctSeed__Account_Payable__c> paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
            
            	pp.Payee_Reference_Operator__c = 'not equal to';
            	pp.Payee_Reference__c = '5345';
            	update pp;
            	wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(0, paybles.size());
            	
            	pp.Payee_Reference_Operator__c = '';
            	pp.Payee_Reference__c = '';
            	pp.Payable_Name_Operator__c = 'AP-00';
            	pp.AcctSeed__Payable_Name__c = 'starts with';
            	update pp;
            	wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
            
            	pp.Payee_Reference_Operator__c = '';
            	pp.Payee_Reference__c = '';
            	pp.Payable_Name_Operator__c = '00';
            	pp.AcctSeed__Payable_Name__c = 'contains';
            	update pp;
            	wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.search(pp.id);
                paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
        }
    }

    @IsTest 
    public static void testcreatePPLinesForNegativePayables() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            TestDataSuite testPayProps = testData.createPaymentProposals();
            List<String> payableIds = new List<String>{testData.payables.get(4).Id};
            try {
                PaymentProposal.createPPLinesForPayables(JSON.serialize(payableIds), testPayProps.paymentProposals[1].id);      
                Assert.fail('No Exception thrown for PaymentProposalException');
            } 
            catch(PaymentProposal.PaymentProposalException ex){
                Assert.areEqual(ex.getMessage(), Label.ERROR_PPL_CREDIT_MEMO);
            }
        } 
    }

    @IsTest
    private static void testGetCurrencyISOCode(){
        try{
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPayables().createPaymentProposals();
            Test.startTest();
            System.runAs(testData.users[1]){
                String actualCurrencyISOCode = PaymentProposal.getCurrencyISOCode(testData.paymentProposals[0].Id);
                String expectedCurrencyISOCode = (string)DomainUtils.getPaymentProposalsById( new Set<Id>{testData.paymentProposals[0].Id})[0].get('currencyisocode');
                Assert.isNotNull(actualCurrencyISOCode);
                Assert.areEqual(expectedCurrencyISOCode, actualCurrencyISOCode);
            }
            Test.stopTest();
        } catch (TestDataSuite.TestDataSuiteException ex){
            //just skip this test if it is non-MC org
        }
    }

}