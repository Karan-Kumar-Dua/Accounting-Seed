@IsTest 
public with sharing class PaymentProposalReportingTest {

    @IsTest
    public static void testSetReportFiltersInvalidReport(){
        TestDataSuite testData = TestDataSuite.getInstance(true);
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);

        Report rpt =  (Report)Json.deserialize(
                          '{"ID": "00O000000000000",' +
                          ' "DeveloperName": "Payment Proposal Search" , ' +
                          ' "Format": "Tabular"}',
                          Report.class);   
     
        List <Report> reportList = new List<Report>{rpt};

        System.runAs(testData.users[1]) {
            Test.startTest();
                try{
                    Payment_Proposal__c pp =
                        new Payment_Proposal__c(
                            Description__c = 'Test Payment Proposal 1',
                            Account__c = testData.Accounts[0].id,
                            Proprietary_Payable_Number__c = '1',
                            Payment_Date__c = Date.Today(),
                            Type__c = 'Check', 
                            Ledger__c = testData.ledgers[0].Id,
                            Bank_GL_Account__c = testData.glAccounts[0].id
                        ); 
                    insert pp;
                    
                    ReportFilters filters = new ReportFilters();
                    filters.initialReportColumnName = 'AS Pay Type';
                    filters.reportColumnName = 'AS Pay Type';
                    filters.operator = 'equals';
                    filters.value = 'Check,ACH,Virtual Card,';
                    
                    List<ReportFilters> repFilters = new List<ReportFilters>();
                    repFilters.add(filters);

                    
                    PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.setReportFilters(
                                                                                    JSON.serialize(repFilters), 
                                                                                    reportList[0].Name, 
                                                                                    String.valueOF(pp.Id)
                                                                                );
                }
                catch(Exception ex){
                    Assert.isTrue(ex.getMessage().contains(Label.ERR_INVALID_REPORT_NAME));
                }

            Test.stopTest();
        }
    }

/* REMOVING SeeAllData Test as it is causing an issue with the build
    //Using SeeAllData to have access to the packaged report to test saving filters from report to Payment Proposal.  
    @IsTest (SeeAllData=true)
    public static void testGetSetReportFilters(){
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);

        //Using SeeAllData we can not always count on the org having these values.
        List <Report> reportList = [SELECT Id,Name FROM Report WHERE Name = 'Payment Proposal Search'];
        User usr = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Ledger__c ledger = [SELECT Id FROM Ledger__c LIMIT 1];
        GL_Account__c glAccount = [SELECT Id FROM GL_Account__c LIMIT 1];
        //If any of them are not present then end the test
        if(reportList == null || usr == null || acc == null || ledger == null || glAccount == null){
            return;
        }else{
            System.runAs(usr) {
                Test.startTest();
                    Payment_Proposal__c pp =
                        new Payment_Proposal__c(
                            Description__c = 'Test Payment Proposal 1',
                            Account__c = acc.Id,
                            Proprietary_Payable_Number__c = '1',
                            Payment_Date__c = Date.Today(),
                            Type__c = 'Check', 
                            Ledger__c = ledger.Id,
                            Bank_GL_Account__c = glAccount.Id
                        ); 
                    insert pp;
                    
                    ReportFilters filters = new ReportFilters();
                    filters.initialReportColumnName = 'AS Pay Type';
                    filters.reportColumnName = 'AS Pay Type';
                    filters.operator = 'equals';
                    filters.value = 'Check,ACH,Virtual Card,';
                    
                    List<ReportFilters> repFilters = new List<ReportFilters>();
                    repFilters.add(filters);

                    try{
                    
                    //Test getting Report Filters
                    Map<String, String> filterDetails = (Map<String, String>) PaymentProposal.getReportFilters(reportList[0].Name);
                    Assert.isTrue(filterDetails.keySet().size() > 0);

                    PaymentProposalSearchService.AdvanceSearchWrapper wrapper = (PaymentProposalSearchService.AdvanceSearchWrapper) PaymentProposal.setReportFilters(
                                                                                    JSON.serialize(repFilters), 
                                                                                    reportList[0].Name, 
                                                                                    String.valueOF(pp.Id)
                                                                                );
                    }catch(Exception ex){
                        Assert.isTrue(ex.getMessage().contains(Label.INFO_NO_RECORD_MSG));
                    }
                    
                    Payment_Proposal__c pps = [Select Id, Report_Filters__c FROM Payment_Proposal__c where id=:pp.Id];

                    //Assert to verify whether filters are saved successfully to PPR record or not.
                    Assert.isTrue(pps.Report_Filters__c.contains(filters.initialReportColumnName));
                    Assert.isTrue(pps.Report_Filters__c.contains(filters.operator));
                    Assert.isTrue(pps.Report_Filters__c.contains(filters.value));
                Test.stopTest();
            }
        }
       
    }
*/
}