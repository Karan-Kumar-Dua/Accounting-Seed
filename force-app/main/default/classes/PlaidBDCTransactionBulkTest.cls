@isTest
public class PlaidBDCTransactionBulkTest {

    @isTest
    private static void PlaidBDCTransactionBulk_Success() {

        TestDataSuite testData = TestDataSuite.getInstance(true);
        String finInstIdenId = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].Id;
        String finInstId = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].financialInstitutionId;
        testData.createBdcAccessToken(finInstIdenId, finInstId);

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>();
        SingleRequestMock categoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.CATEGORIES_TEST_JSON, 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        SingleRequestMock transactionRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.TRANSACTION_TEST_JSON, 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        PlaidBDCConnector connector = new PlaidBDCConnector();
        requestMockByEndpointUrl.put(connector.PLAID_API_ENDPOINT + '/categories/get', categoriesRequestMock);
        requestMockByEndpointUrl.put(connector.PLAID_API_ENDPOINT + '/transactions/get', transactionRequestMock);
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        PlaidBDCTransactionBulk bdcBulk = new PlaidBDCTransactionBulk();

        List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
        testData.createGlams();
        glams.add(testData.glams[2]);
        System.Test.startTest();
        BDCServiceResult callResult = bdcBulk.startTransactionProcess(glams);
        System.Test.stopTest();

        List<Bank_Transaction__c> bdcTransactions = [SELECT Id FROM Bank_Transaction__c];

        System.assertEquals(1, bdcTransactions.size());

    }

    @isTest
    private static void PlaidBDCTransactionBulkMaxTrans_Success() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        String finInstIdenId = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].Id;
        String finInstId = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].financialInstitutionId;
        testData.createBdcAccessToken(finInstIdenId, finInstId);
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>();
        SingleRequestMock categoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.CATEGORIES_TEST_JSON, 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        SingleRequestMock transactionRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.TRANSACTION_BULK_TEST_JSON(), 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        PlaidBDCConnector connector = new PlaidBDCConnector();

        requestMockByEndpointUrl.put(connector.PLAID_API_ENDPOINT + '/categories/get', categoriesRequestMock);
        requestMockByEndpointUrl.put(connector.PLAID_API_ENDPOINT + '/transactions/get', transactionRequestMock);
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        //String accId = BDCMocker.testBDCDataModel().bdcAccounts[0].Id;

        PlaidBDCTransactionBulk bdcBulk = new PlaidBDCTransactionBulk();

        List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
        testData.createGlams();
        glams.add(testData.glams[2]);
        System.Test.startTest();
        BDCServiceResult callResult = bdcBulk.startTransactionProcess(glams);
        System.Test.stopTest();

        List<Bank_Transaction__c> bdcTransactions = [SELECT Id, High_Level_Category_Id__c, Category_Id__c, Detail_Category_Id__c FROM Bank_Transaction__c];

        System.assertEquals(49, bdcTransactions.size());
    }
}