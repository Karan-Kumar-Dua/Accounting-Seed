@isTest
public with sharing class PlaidBDCConnectorTest {

    @TestSetup
    private static void setupTestData() {
         //create access token
         BDC_Access_Tokens__c bdcAccessToken = new BDC_Access_Tokens__c();
         bdcAccessToken.Financial_Institution_Id__c = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].financialInstitutionId;
         bdcAccessToken.Financial_Institution_Identity_Id__c = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].Id;
         bdcAccessToken.Source__c = 'Plaid';
         bdcAccessToken.Token__c = '123xyz';
         bdcAccessToken.Name = 'Test Access Token 1';
         insert bdcAccessToken;
    }

    //Method to test the Financial Intitution Identies
    @isTest
    public static void getFinancialInstitutionIdentitiesTest() {

        //Sets the Mock
        SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON.substringBeforeLast(';'), 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 
        
        Test.startTest();
        PlaidBDCConnector bdcPlaidConnect = new PlaidBDCConnector();
        List<HttpResponse> responses = bdcPlaidConnect.getFinancialInstitutionIdentities();
        Test.stopTest();
        
        //Assert to verify response
        System.assertEquals(responses[0].getStatusCode() == 200 , true);
        System.assertEquals(responses[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
        System.assertEquals(responses[0].getBody(), PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON);
    }

    //Method to test the Transactions
    @isTest
    public static void getTransactionsTest() {

        //Creation of object to store FromDate, ToDate and MaxRecords
        BDCServiceOptions options = new BDCServiceOptions();
        options.fromDate = System.Date.today().addDays(-90);
        options.toDate = System.Date.today();
        options.offset = 0;
        options.maxRecords = 5;

        //Setting of mock
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.TRANSACTION_TEST_JSON.substringBeforeLast(';') , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 

        Test.startTest();
        PlaidBDCConnector plaidConnect = new PlaidBDCConnector();
        List<HttpResponse> responses = plaidConnect.getTransactions(options);
        Test.stopTest();
        
        //Assert to verify response
        System.assertEquals(responses[0].getStatusCode() == 200 , true);
        System.assertEquals(responses[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
        System.assertEquals(responses[0].getBody(), PlaidBDCTest.TRANSACTION_TEST_JSON);
    }

    //Method to test the failed Transactions
    @isTest
    public static void getTransactionsFailedTest() {
        List<HttpResponse> responses;

        //Creation of object to store FromDate, ToDate and MaxRecords
        BDCServiceOptions options = new BDCServiceOptions();
        options.fromDate = System.Date.today().addDays(-90);
        options.toDate = System.Date.today();
        options.maxRecords = 900;

        //Sets the mock
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.TRANSACTION_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 

        Test.startTest();
        //Exception is expected in this case
        PlaidBDCConnector plaidConnect = new PlaidBDCConnector();
        try {
            responses = plaidConnect.getTransactions(options);
        }
         
        catch(Exception ex) {
            System.assertEquals(Label.ERR_TOO_MANY_TRANSACTIONS_REQUESTED + String.valueOf(plaidConnect.maxTransactionRecordsPerCallout()), ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
        Test.stopTest();
        
    }

    //Method to test the Financial Intitutions
    @isTest
    public static void getFinancialInstitutionsTest() {

        //Sets the mock
        SingleRequestMock xFinancialInstitutionsRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xFinancialInstitutionsRequestMock);
        
        BDCServiceOptions options = new BDCServiceOptions();
        BDCDataModel model =  BDCMocker.testBDCDataModel();
        options.bdcFinancialInstitutionIdentities = model.bdcFinancialInstitutionIdentities;

        Test.startTest();
        PlaidBDCConnector plaidConnect = new PlaidBDCConnector();
        List<HTTPResponse> resp = plaidConnect.getFinancialInstitutions(options.bdcFinancialInstitutionIdentities);
        Test.stopTest();
        
        //Assert to verify response
        System.assertEquals(resp[0].getStatusCode() == 200 , true);
        System.assertEquals(resp[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(resp[0].getBody()) , true);
        System.assertEquals(resp[0].getBody() , PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON);
    }

    //Method to test the categories
    @isTest
    public static void getCategoriesTest() {

        //Sets the mock
        SingleRequestMock xCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.CATEGORIES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xCategoriesRequestMock);
        
        Test.startTest();
        PlaidBDCConnector plaidConnect = new PlaidBDCConnector();
        List<HTTPResponse> resp = plaidConnect.getCategories();
        Test.stopTest();
        
        //Assert to verify response
        System.assertEquals(resp[0].getStatusCode() == 200 , true);
        System.assertEquals(resp[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(resp[0].getBody()) , true);
        System.assertEquals(resp[0].getBody() , PlaidBDCTest.CATEGORIES_TEST_JSON);
    }


    //Method to test the Accounts
    @isTest
    public static void getAccountstest() {
        //mock data model
        BDCDataModel model = BDCMocker.testBDCDataModel();        
        //get acct Ids
        List < String > acctIds = new List < String > ();
        for (BDCAccount acct: model.bdcAccounts) {
            acctIds.add(acct.id);
        }
        
        //sets the mock
        SingleRequestMock xGetAccountRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNT_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetAccountRequestMock);
        
        Test.startTest();
        PlaidBDCConnector plaidConnect = new PlaidBDCConnector();
        List<HttpResponse> responses = plaidConnect.getAccounts(acctIds);
        Test.stopTest();
        
         //Assert to verify response
        System.assertEquals(responses[0].getStatusCode() == 200 , true);
        System.assertEquals(responses[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
        System.assertEquals(responses[0].getBody() ,  PlaidBDCTest.ACCOUNT_TEST_JSON);
    }

    //Method to test the deletion of Financial Intitution Identity
    @isTest
    public static void getdeleteFinancialInstitutionIdentityTest() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        
        GL_Account_Mapping__c glam = new GL_Account_Mapping__c (
            External_Id__c = '1',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'Provider1',
            Financial_Institution_Id__c = '111',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Plaid'
        );
        insert glam; 
        
        SingleRequestMock xDeleteProviderAccountsRequestMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_DELETE_TEST_JSON,
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xDeleteProviderAccountsRequestMock);
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            BDCFinancialInstitutionIdentity bfc = new BDCFinancialInstitutionIdentity();
            bfc.id = glam.Financial_Institution_Id__c;
            PlaidBDCConnector plaidConnect = new PlaidBDCConnector();
            List<HttpResponse> responses = plaidConnect.deleteFinancialInstitutionIdentity(bfc);
            Test.stopTest();

            System.assertEquals(responses[0].getStatusCode() == 200 , true);
            System.assertEquals(responses[0].getStatus() == 'Complete' , true);
            System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
            System.assertEquals(responses[0].getBody() ,  PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_DELETE_TEST_JSON);
        }
    }
}