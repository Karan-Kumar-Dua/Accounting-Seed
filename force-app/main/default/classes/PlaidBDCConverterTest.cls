@IsTest
public class PlaidBDCConverterTest {

    private static final String ERR_BDC_PLAID_API = Label.ERR_BDC_PLAID_API;

    /*
    * Method to set up Test Data
    */
    @TestSetup
    private static void setupTestData() {
         //create access token
         BDC_Access_Tokens__c bdcAccessToken = new BDC_Access_Tokens__c();
         bdcAccessToken.Financial_Institution_Id__c = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].financialInstitutionId;
         bdcAccessToken.Financial_Institution_Identity_Id__c = BDCMocker.testBDCDataModel().bdcFinancialInstitutionIdentities[0].Id;
         bdcAccessToken.Source__c = 'Plaid';
         bdcAccessToken.Token__c = '123xyz';
         bdcAccessToken.Name = 'Test Access Token 1';
         bdcAccessToken.Identity_Name__c = 'Connection_1';
         insert bdcAccessToken;
    }

    /*
    * Method to test Access Token method
    */
    @isTest 
    private static void convertAccessTokenTest() {
        HttpResponse validResponse = new HttpResponse();

        String testInstitutionId = 'bank_123';
        validResponse.setBody(PlaidBDCTest.ACCESS_TOKEN_TEST_JSON);

        Map<String, HttpResponse> validResponses = new Map<String, HttpResponse>();
        validResponses.put(testInstitutionId, validResponse);

        System.Test.startTest();
        PlaidBDCConverter converter = new PlaidBDCConverter();
        converter.convertAccessTokens(validResponses);
        System.Test.stopTest();

        List<BDC_Access_Tokens__c> insertedTokens = [
            SELECT 
                Id, 
                Financial_Institution_Id__c,
                Financial_Institution_Identity_Id__c,
                Token__c
            FROM BDC_Access_Tokens__c
            WHERE Financial_Institution_Id__c = 'bank_123'
        ];

        System.assertEquals(1, insertedTokens.size());
        BDC_Access_Tokens__c targetToken = insertedTokens[0];
        System.assertEquals('bank_123', targetToken.Financial_Institution_Id__c);
        System.assertEquals('RqXeZp9W8BidE3KTwRzoSk98V4lx7RHRXQ58x', targetToken.Financial_Institution_Identity_Id__c);
        System.assertEquals('access-sandbox-2d22d222-2dd2-222d-222d-2d222d222222', targetToken.Token__c);

    }

    /*
    * Method to test Transactions conversion method
    */
    @isTest 
    private static void convertTransactionsTest() {
        //insert an access token that will represent the identity retrieved (matches JSON data in the PlaidBDCTest class)
        BDC_Access_Tokens__c accToken = new BDC_Access_Tokens__c();
        accToken.Financial_Institution_Id__c = 'ins_3';
        accToken.Financial_Institution_Identity_Id__c = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Source__c = 'Plaid';
        accToken.Identity_Name__c = 'Connection_1';
        accToken.Name = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Token__c = 'bogustoken555';
        insert accToken;        

        HttpResponse validResponse = new HttpResponse();

        validResponse.setBody(PlaidBDCTest.TRANSACTION_TEST_JSON);
        validResponse.setStatusCode(200);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        List<BDCTransaction> returnedObjects = converter.convertTransactions(validResponses).data.bdcTransactions;

        BDCTransaction aTransaction = returnedObjects[0];
        System.assertEquals('lPNjeW1nR6CDn5okmGQ6hEpMo4lLNoSrzqDje', aTransaction.id);
        System.assertEquals('AS_Bank_Identity_Acc_0', aTransaction.accountId);
        System.assertEquals('12008000', aTransaction.categoryId);
        System.assertEquals(2307.21, aTransaction.amount);
        System.assertEquals(Date.newInstance(2022, 11, 02), aTransaction.transactionDate);
        System.assertEquals(Date.newInstance(2022, 11, 02), aTransaction.postDate);
        System.assertEquals('Apple Store', aTransaction.description);
        System.assertEquals('USD', aTransaction.currencyIsoCode);
        System.assertEquals('Apple', aTransaction.merchantName);
        System.assertEquals(null, aTransaction.checkNumber);
        System.assertEquals('place', aTransaction.type);
        System.assertEquals('depository', aTransaction.Container);
        System.assertEquals('Debit', aTransaction.baseType);
    }

    /*
    * Method to test Transactions conversion failed method
    */
    @isTest 
    private static void convertTransactionsFailTest() {

        //insert an access token that will represent the identity retrieved (matches JSON data in the PlaidBDCTest class)
        BDC_Access_Tokens__c accToken = new BDC_Access_Tokens__c();
        accToken.Financial_Institution_Id__c = 'ins_3';
        accToken.Financial_Institution_Identity_Id__c = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Source__c = 'Plaid';
        accToken.Identity_Name__c = 'Connection_1';
        accToken.Name = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Token__c = 'bogustoken555';
        insert accToken;

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.TRANSACTION_FAILED_TEST_JSON);
        validResponse.setStatusCode(400);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Exception expectedExp;
        Test.startTest();
        try {
            converter.convertTransactions(validResponses);
        }
        catch(Exception exp) {
            expectedExp = exp;
        }
        Test.stopTest();
        System.assertEquals('Connection_1 ' + 'TRANSACTIONS_LIMIT'+ ': ' + 'rate limit exceeded for attempts to access this item. please try again later', expectedExp.getMessage());
    }
    /*
    * Method to test that the correct error is produced when the financial institution is not yet ready to retrieve transactions
    */
    @isTest 
    private static void convertTransactionsFailNotReadyTest() {
        //insert an access token that will represent the identity retrieved (matches JSON data in the PlaidBDCTest class)
        BDC_Access_Tokens__c accToken = new BDC_Access_Tokens__c();
        accToken.Financial_Institution_Id__c = 'ins_3';
        accToken.Financial_Institution_Identity_Id__c = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Source__c = 'Plaid';
        accToken.Identity_Name__c = 'Connection_1';
        accToken.Name = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Token__c = 'bogustoken555';
        insert accToken;

        HttpResponse invalidResponse = new HttpResponse();
        invalidResponse.setBody(PlaidBDCTest.TRANSACTION_NOT_READY_TEST_JSON);
        invalidResponse.setStatusCode(400);

        List<HttpResponse> invalidResponses = new List<HttpResponse>();
        invalidResponses.add(invalidResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Exception expectedExp;
        Test.startTest();
        try {
            converter.convertTransactions(invalidResponses);
        }
        catch(Exception exp) {
            expectedExp = exp;
        }
        Test.stopTest();
        System.assertEquals('Connection_1 ' + PlaidBDCConverter.INSTITUTION_NOT_READY, expectedExp.getMessage());
    }


    /*
    * Method to test Accounts conversion method
    */
    @isTest
    private static void convertAccountsTest() {
        HttpResponse validResponse = new HttpResponse();

        validResponse.setBody(PlaidBDCTest.ACCOUNT_TEST_JSON);
        validResponse.setStatusCode(200);

        List<HttpResponse> resList = new List<HttpResponse>();
        resList.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        List<BDCAccount> convertedObjects = converter.convertAccounts(resList).data.bdcAccounts;
        System.assertEquals(5, convertedObjects.size());
        System.assertEquals('Plaid Checking', convertedObjects[0].nickname);
        System.assertEquals('Plaid Gold Standard 0% Interest Checking', convertedObjects[0].name);
        System.assertEquals('depository', convertedObjects[0].accountType);
        System.assertEquals('0000', convertedObjects[0].maskedAccountNumber);
        System.assertEquals('Plaid', convertedObjects[0].source);
        System.assertNotEquals(null, convertedObjects[0].lastRefreshDate);
        System.assertEquals(110, convertedObjects[0].currentBalance);
        System.assertEquals(100, convertedObjects[0].availableBalance);
        System.assertEquals('CAD', convertedObjects[0].bdcCurrencyISOCode);
        System.assertNotEquals(null, convertedObjects[0].lastUpdated);
        System.assertEquals('ins_43', convertedObjects[0].financialInstitutionId);
        System.assertEquals('wnVRXPmk3mt3wepjXEeXsbN4NWe5V9FrNeEN1', convertedObjects[0].financialInstitutionIdentity);
    }

    /*
    * Method to test Accounts conversion failed method
    */
    @isTest 
    private static void convertAccountsFailTest() {

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.ACCOUNT_FAILED_TEST_JSON);
        validResponse.setStatusCode(400);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Test.startTest();
        BDCServiceResult bdcServiceResult = converter.convertAccounts(validResponses);
        Test.stopTest();
        List<BDCServiceResult.BDCError> bdcErrors = bdcServiceResult.errors;
        System.assertEquals(false, bdcServiceResult.isSuccess);
        System.assertEquals(null, bdcServiceResult.data);
        System.assertEquals(ERR_BDC_PLAID_API + ' HNTDNrA8F1shFEW.',bdcErrors[0].detail);
       
    }

    /*
    * Method to test FinancialInstitutions conversion method
    */
    @isTest
    private static void convertFinancialInstitutionsTest() {

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON);
        validResponse.setStatusCode(200);

        List<HttpResponse> resList = new List<HttpResponse>();
        resList.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        List<BDCFinancialInstitution> convertedObjects = converter.convertFinancialInstitutions(resList).data.bdcFinancialInstitutions;
        System.assertEquals(1, convertedObjects.size());
        System.assertEquals('ins_3', convertedObjects[0].Id);
        System.assertEquals('Chase', convertedObjects[0].name);
        System.assertEquals('Plaid', convertedObjects[0].source);
    }

    /*
    * Method to test FinancialInstitutions conversion failed method
    */
    @isTest 
    private static void convertFinancialInstitutionsFailTest() {

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.ACCOUNT_FAILED_TEST_JSON);
        validResponse.setStatusCode(400);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Test.startTest();
        BDCServiceResult bdcServiceResult = converter.convertFinancialInstitutions(validResponses);
        Test.stopTest();
        List<BDCServiceResult.BDCError> bdcErrors = bdcServiceResult.errors;
        System.assertEquals(false, bdcServiceResult.isSuccess);
        System.assertEquals(null, bdcServiceResult.data);
        System.assertEquals(ERR_BDC_PLAID_API + ' HNTDNrA8F1shFEW.',bdcErrors[0].detail);
       
    }

    /*
    * Method to test FinancialInstitutionIdentities conversion method
    */
    @isTest
    private static void convertFinancialInstitutionIdentitiesTest() {

        //insert an access token that will represent the identity retrieved (matches JSON data in the PlaidBDCTest class)
        BDC_Access_Tokens__c accToken = new BDC_Access_Tokens__c();
        accToken.Financial_Institution_Id__c = 'ins_3';
        accToken.Financial_Institution_Identity_Id__c = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Source__c = 'Plaid';
        accToken.Identity_Name__c = 'Connection_1';
        accToken.Name = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Token__c = 'bogustoken555';
        insert accToken;

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON);
        validResponse.setStatusCode(200);

        List<HttpResponse> resList = new List<HttpResponse>();
        resList.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        List<BDCFinancialInstitutionIdentity> convertedObjects = converter.convertFinancialInstitutionIdentities(resList).data.bdcFinancialInstitutionIdentities;
        BDCFinancialInstitutionIdentity convertedObject = convertedObjects[0];

        System.assertEquals('yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9', convertedObject.Id);
        System.assertEquals('ins_3', convertedObject.financialInstitutionId);
        System.assertEquals('OK', convertedObject.status);
        System.assertEquals('Plaid', convertedObject.source);

    }

    /*
    * Method to test FinancialInstitutionIdentities conversion failed method
    */
    @isTest 
    private static void convertFinancialInstitutionIdentitiesFailTest() {
        //insert an access token that will represent the identity retrieved (matches JSON data in the PlaidBDCTest class)
        BDC_Access_Tokens__c accToken = new BDC_Access_Tokens__c();
        accToken.Financial_Institution_Id__c = 'ins_3';
        accToken.Financial_Institution_Identity_Id__c = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Source__c = 'Plaid';
        accToken.Identity_Name__c = 'Connection_1';
        accToken.Name = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        accToken.Token__c = 'bogustoken555';
        insert accToken;

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_FAILED_TEST_JSON);
        validResponse.setStatusCode(400);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Test.startTest();
        BDCServiceResult bdcServiceResult = converter.convertFinancialInstitutionIdentities(validResponses);
        Test.stopTest();
        List<BDCServiceResult.BDCError> bdcErrors = bdcServiceResult.errors;
        //on api failure. Identities are still returned.
        System.assertEquals(true, bdcServiceResult.isSuccess);
        System.assertNotEquals(null, bdcServiceResult.data);
        System.assertEquals('Connection_1:  ' + ERR_BDC_PLAID_API + ' HNTDNrA8F1shFEW.',bdcErrors[0].detail);
       
    }

    /*
    * Categories truncated for test class brevity
    */
    @isTest
    private static void convertCategoriesTest() {
        HttpResponse validResponse = new HttpResponse();

        validResponse.setBody(PlaidBDCTest.CATEGORIES_TEST_JSON);
        validResponse.setStatusCode(200);

        List<HttpResponse> resList = new List<HttpResponse>();
        resList.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Map<String, BDCCategory> convertedObjects = converter.convertCategories(resList).data.bdcCategories;
        BDCCategory convertedObject0 = convertedObjects.get('12000000');
        BDCCategory convertedObject1 = convertedObjects.get('12008000');
        BDCCategory convertedObject2 = convertedObjects.get('12008001');


        System.assertEquals('12000000', convertedObject0.Id);
        System.assertEquals('Shops', convertedObject0.name);
        System.assertEquals('Plaid', convertedObject0.source);
        System.assertEquals(null, convertedObject0.parentCategoryId);

        System.assertEquals('12008000', convertedObject1.Id);
        System.assertEquals('Computers and Electronics', convertedObject1.name);
        System.assertEquals('Plaid', convertedObject1.source);
        System.assertEquals('12000000', convertedObject1.parentCategoryId);

        System.assertEquals('12008001', convertedObject2.Id);
        System.assertEquals('Mobile Phones', convertedObject2.name);
        System.assertEquals('Plaid', convertedObject2.source);
        System.assertEquals('12008000', convertedObject2.parentCategoryId);

    }

    /*
    * Method to test Categories conversion failed method
    */
    @isTest 
    private static void convertCategoriesFailTest() {

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.CATEGORIES_FAILED_TEST_JSON);
        validResponse.setStatusCode(400);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Test.startTest();
        BDCServiceResult bdcServiceResult = converter.convertCategories(validResponses);
        Test.stopTest();
        List<BDCServiceResult.BDCError> bdcErrors = bdcServiceResult.errors;
        System.assertEquals(false, bdcServiceResult.isSuccess);
        System.assertEquals(null, bdcServiceResult.data);
        System.assertEquals(ERR_BDC_PLAID_API + ' HNTDNrA8F1shFEW.',bdcErrors[0].detail);
       
    }

    /*
    * Method to test Delete FinancialInstitutionIdentity conversion method
    */
    @isTest 
    private static void convertDeleteFinancialInstitutionIdentityTest() {

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_DELETE_TEST_JSON);
        validResponse.setStatusCode(200);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        List<BDC_Access_Tokens__c> insertedTokens = [
            SELECT 
                Id, 
                Financial_Institution_Id__c,
                Financial_Institution_Identity_Id__c,
                Token__c
            FROM BDC_Access_Tokens__c
        ];

        BDCFinancialInstitutionIdentity bDCFinancialInstitutionIdentity = new BDCFinancialInstitutionIdentity();
        bDCFinancialInstitutionIdentity.Id = insertedTokens[0].Financial_Institution_Identity_Id__c;
        bDCFinancialInstitutionIdentity.financialInstitutionId = insertedTokens[0].Financial_Institution_Id__c;

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Test.startTest();
        BDCServiceResult bdcServiceResult = converter.convertDeleteFinancialInstitutionIdentity(validResponses, bDCFinancialInstitutionIdentity);
        Test.stopTest();
        System.assertEquals(true, bdcServiceResult.isSuccess);
    }

    /*
    * Method to test Delete FinancialInstitutionIdentity conversion failed method
    */
    @isTest 
    private static void convertDeleteFinancialInstitutionIdentityFailTest() {

        HttpResponse validResponse = new HttpResponse();
        validResponse.setBody(PlaidBDCTest.FINANCIAL_IDENTIIES_DELETE_FAILED_TEST_JSON);
        validResponse.setStatusCode(400);

        List<HttpResponse> validResponses = new List<HttpResponse>();
        validResponses.add(validResponse);

        List<BDC_Access_Tokens__c> insertedTokens = [
            SELECT 
                Id, 
                Financial_Institution_Id__c,
                Financial_Institution_Identity_Id__c,
                Token__c
            FROM BDC_Access_Tokens__c
        ];

        BDCFinancialInstitutionIdentity bDCFinancialInstitutionIdentity = new BDCFinancialInstitutionIdentity();
        bDCFinancialInstitutionIdentity.Id = insertedTokens[0].Financial_Institution_Identity_Id__c;
        bDCFinancialInstitutionIdentity.financialInstitutionId = insertedTokens[0].Financial_Institution_Id__c;

        PlaidBDCConverter converter = new PlaidBDCConverter();
        Test.startTest();
        BDCServiceResult bdcServiceResult = converter.convertDeleteFinancialInstitutionIdentity(validResponses, bDCFinancialInstitutionIdentity);
        Test.stopTest();
        List<BDCServiceResult.BDCError> bdcErrors = bdcServiceResult.errors;
        System.assertEquals(false, bdcServiceResult.isSuccess);
        System.assertEquals(null, bdcServiceResult.data);
        System.assertEquals(ERR_BDC_PLAID_API + ' GIu8mBj99mRlr0E.',bdcErrors[0].detail);
    }
}