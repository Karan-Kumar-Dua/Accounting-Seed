@isTest
public class PlaidTransactionsDownloadQueueableTest{
    /*
    * tests the second constructor that runs after the queuable chains.
    * it must be tested separately since queueables cannot be chained in tests
    */
    @isTest
    public static void PlaidTransactionsDownloadQueueable_chain_Test() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        String finInstIdenId = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].Id;
        String finInstId = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].financialInstitutionId;
        testData.createBdcAccessToken(finInstIdenId, finInstId);

        SingleRequestMock transactionRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.TRANSACTION_TEST_JSON, 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Test.setMock(HttpCalloutMock.class, transactionRequestMock);

        testData.createGlams();
        List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
        GL_Account_Mapping__c targetGlam = testData.glams[2];
        glams.add(targetGlam);

        BDCFinancialInstitutionIdentity targetFinancialInstitutionIdentity = new BDCFinancialInstitutionIdentity();
        targetFinancialInstitutionIdentity.id = 'AS_Bank_Identity';
        targetFinancialInstitutionIdentity.financialInstitutionId = 'AS_Bank';


        PlaidBDCConverter converter = new PlaidBDCConverter();
        String catResponseString = PlaidBDCTest.CATEGORIES_TEST_JSON;
        HttpResponse catResponse = new HttpResponse();
        catResponse.setBody(catResponseString);
        catResponse.setStatusCode(200);
        List<HttpResponse> catResponseList = new List<HttpResponse>();
        catResponseList.add(catResponse);
        Map<String, BDCCategory> categoryMap = converter.convertCategories(catResponseList).data.bdcCategories;

        Test.startTest();
        PlaidTransactionsDownloadQueueable tQueueable = new PlaidTransactionsDownloadQueueable(
            targetGlam.Initial_Start_Date__c,
            Date.newInstance(2022, 11, 04),
            1000,
            50,
            targetFinancialInstitutionIdentity,
            categoryMap,
            glams,
            1,
            0
        );
        System.enqueueJob(tQueueable);

        Test.stopTest();

        List<Bank_Transaction__c> bdcTransactions = [SELECT Id, High_Level_Category_Id__c, Category_Id__c, Detail_Category_Id__c FROM Bank_Transaction__c];

        System.assertEquals(1, bdcTransactions.size());
    }
}