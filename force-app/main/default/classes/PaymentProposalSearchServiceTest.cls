@IsTest
public with sharing class PaymentProposalSearchServiceTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest 
    public static void testSearchPayablesWithoutPPL(){
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
                TestDataSuite testPayProps = testData.createPaymentProposals();
                
                List<AcctSeedReportData> datas = new List<AcctSeedReportData>();

                AcctSeedReportData reptData1 = new AcctSeedReportData();
                reptData1.setValue(JSON.serialize(testData.payables[2].Id));
                AcctSeedReportData reptData2 = new AcctSeedReportData();
                reptData2.setValue(JSON.serialize(testData.payables[1].Id));
                datas.add(reptData1);
                datas.add(reptData2);

                PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) 
                                                                            PaymentProposalSearchService.searchPayables
                                                                            (
                                                                                testPayProps.paymentProposals[0],
                                                                                datas
                                                                            );
                List<AcctSeed__Account_Payable__c> paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(2, paybles.size());
            Test.stopTest();
        } 
    }

    @IsTest 
    public static void testSearchPayablesWithtPPL(){
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();

                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
                TestDataSuite testPayProps = testData.createPaymentProposals();

                List<Payment_Proposal_Line__c> ppLines = new  List<Payment_Proposal_Line__c>();
                Payment_Proposal_Line__c ppLine;
                
                for(Account_Payable__c payble : new List<Account_Payable__c>{testData.payables[0],testData.payables[2]}) {
                    ppLine = new Payment_Proposal_Line__c();
                    ppLine.Payable__c = payble.Id;
                    ppLine.Vendor__c = payble.Vendor__c;
                    ppLine.Payment_Proposal__c = testPayProps.paymentProposals[0].id;
                    ppLine.Amount__c = payble.Balance__c;
                    ppLines.add(ppLine);
                }

                insert ppLines;

                List<AcctSeedReportData> datas = new List<AcctSeedReportData>();

                AcctSeedReportData reptData1 = new AcctSeedReportData();
                reptData1.setValue(JSON.serialize(testData.payables[0].Id));
                AcctSeedReportData reptData2 = new AcctSeedReportData();
                reptData2.setValue(JSON.serialize(testData.payables[1].Id));
                datas.add(reptData1);
                datas.add(reptData2);

                PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) 
                                                                            PaymentProposalSearchService.searchPayables
                                                                            (
                                                                                testPayProps.paymentProposals[0],
                                                                                datas
                                                                            );
                List<AcctSeed__Account_Payable__c> paybles = (List<AcctSeed__Account_Payable__c>) wrapper.data;
                Assert.areEqual(1, paybles.size());
                Assert.areEqual(paybles[0].id, testData.payables[1].Id);
            Test.stopTest();

        } 
    }
}