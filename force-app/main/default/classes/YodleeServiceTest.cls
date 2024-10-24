@IsTest
public class YodleeServiceTest {

    @IsTest
    private static void testGetUserToken() {
        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        System.assertNotEquals(true, YodleeService.isUserTokenExpired());
    }

    @IsTest
    private static void testGetAuthToken() {
        Test.startTest();
        String token = YodleeService.getAuthToken();
        System.assertNotEquals('', token);
        System.assertNotEquals(true, YodleeService.isAuthTokenExpired());
    }

    @IsTest
    private static void testGetAccountById() {
        //Create Yodlee account model
        YodleeService.AccountModel accountModel = buildAccountModel(
            '12345678', 
            new YodleeService.Money(10000, 'USD'), 
            new YodleeService.Money(10000, 'USD'), 
            'Account1',
            'First Account',
            '11111',
            'ProviderAccount1',
            Date.today().addDays(-1)
        );
        SingleRequestMock xGetGetAccountByIdRequestMock = YodleeServiceTest.initGetAccountByIdRequestMock(accountModel);
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getAccountByIdURL(accountModel.id, NULL) => xGetGetAccountByIdRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        YodleeService.AccountModel accountModelFromResponse = YodleeService.getAccountById(token, accountModel.id, NULL);
        System.assertEquals(accountModel.id, accountModelFromResponse.id);
        System.assertEquals('xxxx5678', accountModelFromResponse.getMaskedAccountNumber());
    }

    @IsTest
    private static void testGetMaskedAccountNumber() {
        //Create Yodlee account model
        YodleeService.AccountModel accountModel = buildAccountModel(
            NULL, 
            new YodleeService.Money(10000, 'USD'), 
            new YodleeService.Money(10000, 'USD'), 
            'Account1',
            'First Account',
            '11111',
            'ProviderAccount1',
            Date.today().addDays(-1)
        );
        SingleRequestMock xGetGetAccountByIdRequestMock = YodleeServiceTest.initGetAccountByIdRequestMock(accountModel);
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getAccountByIdURL(accountModel.id, NULL) => xGetGetAccountByIdRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        YodleeService.AccountModel accountModelFromResponse = YodleeService.getAccountById(token, accountModel.id, NULL);
        System.assertEquals(accountModel.id, accountModelFromResponse.id);
        System.assertEquals('', accountModelFromResponse.getMaskedAccountNumber());
    }

    @IsTest
    private static void testGetAccounts() {
        //Create Yodlee account models
        YodleeService.AccountModel accountModel1 = buildAccountModel(
            '12345678', 
            new YodleeService.Money(10000, 'USD'), 
            new YodleeService.Money(10000, 'USD'), 
            'Account1',
            'First Account',
            '11111',
            'ProviderAccount1',
            Date.today().addDays(-1)
        );
        YodleeService.AccountModel accountModel2 = buildAccountModel(
            '87654321', 
            new YodleeService.Money(20000, 'USD'), 
            new YodleeService.Money(30000, 'USD'), 
            'Account2',
            'Second Account',
            '22222',
            'ProviderAccount2',
            Date.today().addDays(-2)
        );
        SingleRequestMock xGetGetAccountsRequestMock = YodleeServiceTest.initGetAccountsRequestMock(
            new List<YodleeService.AccountModel>{accountModel1, accountModel2}
        );
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getAccountsURL(NULL) => xGetGetAccountsRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        List<YodleeService.AccountModel> accountModelsFromResponse = YodleeService.getAccounts(token, NULL);
        System.assertNotEquals(true, accountModelsFromResponse.isEmpty());
        System.assertEquals(accountModel1.id, accountModelsFromResponse[0].id);
        System.assertEquals(accountModel2.id, accountModelsFromResponse[1].id);
    }

    @IsTest
    private static void testGetProviders() {
        //Create Yodlee provider models
        YodleeService.ProviderModel providerModel1 = buildProviderModel(
            '12345678', 'Provider1', Date.today().addDays(-1), 'ACTIVE'
        );
        YodleeService.ProviderModel providerModel2 = buildProviderModel(
            '87654321', 'Provider2', Date.today().addDays(-2), 'ACTIVE'
        );
        SingleRequestMock xGetGetProvidersRequestMock = YodleeServiceTest.initGetProvidersRequestMock(
            new List<YodleeService.ProviderModel>{providerModel1, providerModel2}
        );
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getProvidersURL(NULL) => xGetGetProvidersRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        List<YodleeService.ProviderModel> providerModelsFromResponse = YodleeService.getProviders(token, NULL);
        System.assertNotEquals(true, providerModelsFromResponse.isEmpty());
        System.assertEquals(providerModel1.id, providerModelsFromResponse[0].id);
        System.assertEquals(providerModel2.id, providerModelsFromResponse[1].id);
    }

    @IsTest
    private static void testGetSingleProvider() {
        //Create Yodlee provider models
        YodleeService.ProviderModel providerModel1 = buildProviderModel(
            '12345678', 'Provider1', Date.today().addDays(-1), 'ACTIVE'
        );        
        SingleRequestMock xGetGetProvidersRequestMock = YodleeServiceTest.initGetProvidersRequestMock(
            new List<YodleeService.ProviderModel>{providerModel1}
        );
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getSingleProviderURL('12345678') => xGetGetProvidersRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        List<YodleeService.ProviderModel> providerModelsFromResponse = YodleeService.getProvider(token, '12345678');
        System.assertNotEquals(true, providerModelsFromResponse.isEmpty());
        System.assertEquals(providerModel1.id, providerModelsFromResponse[0].id);
    }

    @IsTest
    private static void testGetProviderAccounts() {
        //Create Yodlee provider models
        YodleeService.ProviderAccountModel providerAccountModel1 = buildProviderAccountModel(
            '12345678', '64414', 'ProviderAccount1', Date.today().addDays(-1), Date.today(), 'SUCCESS'
        );
        YodleeService.ProviderAccountModel providerAccountModel2 = buildProviderAccountModel(
            '87654321', '64414', 'Provider2', Date.today().addDays(-2), Date.today(), 'SUCCESS'
        );
        SingleRequestMock xGetGetProviderAccountsRequestMock = YodleeServiceTest.initGetProviderAccountsRequestMock(
            new List<YodleeService.ProviderAccountModel>{providerAccountModel1, providerAccountModel2}
        );
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getProviderAccountsURL(NULL) => xGetGetProviderAccountsRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        List<YodleeService.ProviderAccountModel> providerAccountModelsFromResponse = YodleeService.getProviderAccounts(token, NULL);
        System.assertNotEquals(true, providerAccountModelsFromResponse.isEmpty());
        System.assertEquals(providerAccountModel1.id, providerAccountModelsFromResponse[0].id);
        System.assertEquals(providerAccountModel2.id, providerAccountModelsFromResponse[1].id);
    }

    @isTest
    private static void testDeleteProviderAccount() {
        
        SingleRequestMock xDeleteProviderAccountsRequestMock = YodleeServiceTest.initDeleteProviderAccountRequestMock();
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.deleteProviderAccountURL('11111') => xDeleteProviderAccountsRequestMock
        };
        MultiRequestMock multiRequestMock = new multiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        
        YodleeService.YodleeException yodleeEx;
        try {
            YodleeService.deleteProviderAccount(token, '11111');
        } catch (YodleeService.YodleeException ex) {
            yodleeEx = ex;
        }
        System.assertEquals(yodleeEx, NULL);
        
    }

    @isTest
    private static void testRegisterUser() {
        
        SingleRequestMock xRegisterUserRequestMock = YodleeServiceTest.initRegisterUserRequestMock();
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.registerUserURL() => xRegisterUserRequestMock
        };
        MultiRequestMock multiRequestMock = new multiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getAuthToken();
        System.assertNotEquals('', token);
        
        YodleeService.YodleeException yodleeEx;
        try {
            YodleeService.registerUser(token);
        } catch (YodleeService.YodleeException ex) {
            yodleeEx = ex;
        }
        System.assertEquals(yodleeEx, NULL);
        
    }

    @IsTest
    private static void testGetTransactionsCount() {
        Integer expectedTransactionsCount = 10;
        
        SingleRequestMock xGetTransactionsCountRequestMock = YodleeServiceTest.initGetTransactionCountRequestMock(expectedTransactionsCount);
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getTransactionsCountURL(NULL) => xGetTransactionsCountRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        Integer trCount = YodleeService.getTransactionsCount(token, NULL);
        System.assertEquals(expectedTransactionsCount, trCount);
    }

    @IsTest
    private static void testGetTransactions() {
        List<YodleeService.TransactionModel> transactionModels = new List<YodleeService.TransactionModel>{
            buildTransactionModel(
                '11111111', '12345678', 'Credit', new YodleeService.Money(550, 'USD'), Date.today().addDays(-1), true
            ),
            buildTransactionModel(
                '22222222', '12345678', 'Debit', new YodleeService.Money(660, 'USD'), Date.today().addDays(-2), true
            )
        };
        
        SingleRequestMock xGetTransactionsRequestMock = YodleeServiceTest.initGetTransactionsRequestMock(transactionModels);
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getTransactionsURL(NULL) => xGetTransactionsRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        List<YodleeService.TransactionModel> transactionModelsFromResponse = YodleeService.getTransactions(token, NULL, true);
        System.assertEquals(false, transactionModelsFromResponse.isEmpty());
        System.assertEquals(2, transactionModelsFromResponse.size());
    }

    @IsTest
    private static void testGetCategories() {
        List<YodleeService.TransactionCategoryModel> categoryModels = new List<YodleeService.TransactionCategoryModel> {
            buildTransactionCategoryModel(1, 'Uncategorized', 10000017, 'Uncategorized', 'SYSTEM', 'PERSONAL', 'UNCATEGORIZE', null),
            buildTransactionCategoryModel(3, 'Charitable Giving', 10000001, 'Giving', 'SYSTEM', 'PERSONAL', 'EXPENSE', new List<YodleeService.TransactionDetailCategory> {
                buildTransactionDetailCategory(1285, 'Environmental'),
                buildTransactionDetailCategory(1288, 'Public and Social Services')
            })
        };
       
        SingleRequestMock xGetTransactionCategoriesRequestMock = YodleeServiceTest.initGetTransactionCategoriesRequestMock(categoryModels);
        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock> {
            YodleeServiceTest.getTransactionCategoriesURL() => xGetTransactionCategoriesRequestMock
        };
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);

        Test.startTest();
        String token = YodleeService.getUserToken();
        System.assertNotEquals('', token);
        List<YodleeService.TransactionCategoryModel> categoryModelsFromResponse = YodleeService.getCategories(token);
        Test.stopTest();
        
        System.assertEquals(false, categoryModelsFromResponse.isEmpty());
        System.assertEquals(2, categoryModelsFromResponse.size());
        for (YodleeService.TransactionCategoryModel model : categoryModelsFromResponse) {
            if (model.id == 1) {
                System.assertEquals(null, model.detailCategory);
            }
            else {
                System.assertEquals(2, model.detailCategory.size());
            }
        }
        
    }

    //==========================================================================================================
    //================================ Make HTTP Request Mocks =================================================
    //==========================================================================================================
    @TestVisible
    private static SingleRequestMock initGetAccountByIdRequestMock(YodleeService.AccountModel accountModel) {
        return new SingleRequestMock(
            200,
            'Complete',
            getAccountByIdResponseBody(accountModel),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
    }
    @TestVisible
    private static SingleRequestMock initGetAccountsRequestMock(List<YodleeService.AccountModel> accountModels) {
        return new SingleRequestMock(
            200,
            'Complete',
            getAccountsResponseBody(accountModels),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
    }
    @TestVisible
    private static SingleRequestMock initGetProvidersRequestMock(List<YodleeService.ProviderModel> providerModels) {
        return new SingleRequestMock(
            200,
            'Complete',
            getProvidersResponseBody(providerModels),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
    }
    @TestVisible
    private static SingleRequestMock initGetProviderAccountsRequestMock(List<YodleeService.ProviderAccountModel> providerAccountModels) {
        return new SingleRequestMock(
            200,
            'Complete',
            getProviderAccountsResponseBody(providerAccountModels),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
    }
    @TestVisible
    private static SingleRequestMock initGetTransactionCountRequestMock(Integer count) {
        return new SingleRequestMock(
            200,
            'Complete',
            getTransactionCountResponseBody(count),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
    }
    @TestVisible
    private static SingleRequestMock initDeleteProviderAccountRequestMock() {
        return new SingleRequestMock(
            200,
            'Complete',
            '',
            new MAP<String, String>{'Content-Type' => 'application/json'}
        );
    }

    @TestVisible
    private static SingleRequestMock initRegisterUserRequestMock() {
        return new SingleRequestMock(
            200,
            'Complete',
            '',
            new MAP<String, String>{'Content-Type' => 'application/json'}
        );
    }
        
    @TestVisible
    private static SingleRequestMock initGetTransactionsRequestMock(List<YodleeService.TransactionModel> transactionModels) {
        return new SingleRequestMock(
            200,
            'Complete',
            getTransactionsResponseBody(transactionModels),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
    }

    @TestVisible
    private static SingleRequestMock initGetTransactionCategoriesRequestMock(List<YodleeService.TransactionCategoryModel> categoryModels) {
        return new SingleRequestMock(
            200,
            'Complete',
            getTransactionCategoriesResponseBody(categoryModels),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
    }   

    //==========================================================================================
    //============= Response Body Generators ===================================================
    //==========================================================================================
    private static String getAccountByIdResponseBody(YodleeService.AccountModel accountModel) {
        YodleeService.AccountsResponse acctResponse = new YodleeService.AccountsResponse();
        List<YodleeService.AccountModel> accounts = new List<YodleeService.AccountModel>();
        accounts.add(accountModel);
        acctResponse.account = accounts;
        return JSON.serialize(acctResponse);
    }

    private static String getAccountsResponseBody(List<YodleeService.AccountModel> accountModels) {
        YodleeService.AccountsResponse acctResponse = new YodleeService.AccountsResponse();
        acctResponse.account = accountModels;
        return JSON.serialize(acctResponse);
    }

    private static String getProvidersResponseBody(List<YodleeService.ProviderModel> providerModels) {
        YodleeService.ProvidersResponse provResponse = new YodleeService.ProvidersResponse();
        provResponse.provider = providerModels;
        return JSON.serialize(provResponse);
    }

    private static String getProviderAccountsResponseBody(List<YodleeService.ProviderAccountModel> providerAccountModels) {
        YodleeService.ProviderAccountsResponse provAcctResponse = new YodleeService.ProviderAccountsResponse();
        provAcctResponse.providerAccount = providerAccountModels;
        return JSON.serialize(provAcctResponse);
    }
    @TestVisible
    private static YodleeService.AccountModel buildAccountModel(
        String accountId,
        YodleeService.Money currentBalance,
        YodleeService.Money availableBalance,
        Date lastRefreshed) {

        return buildAccountModel(accountId, currentBalance, availableBalance, NULL, NULL, NULL, NULL, lastRefreshed);
    }
    @TestVisible
    private static YodleeService.AccountModel buildAccountModel(
        String accountId,
        YodleeService.Money currentBalance,
        YodleeService.Money availableBalance,
        String accountName,
        String nickname,
        String providerAccountId,
        String providerName,
        Date lastRefreshed) {

        YodleeService.AccountModel accountModel = new YodleeService.AccountModel();
        accountModel.id = accountId;
        accountModel.accountNumber = accountId;
        accountModel.lastUpdated = lastRefreshed;
        accountModel.balance = availableBalance;
        accountModel.currentBalance = currentBalance;
        accountModel.accountName = accountName;
        accountModel.nickname = nickname;
        accountModel.providerAccountId = providerAccountId;
        accountModel.providerName = providerName;
        accountModel.autoRefresh = new YodleeService.AutoRefreshModel('ENABLED', '', DateTime.now());
        return accountModel;
    }
    @TestVisible
    private static YodleeService.ProviderModel buildProviderModel(
        String providerId,
        String providerName,
        Date lastModified,
        String status) {

        YodleeService.ProviderModel providerModel = new YodleeService.ProviderModel();
        providerModel.id = providerId;
        providerModel.name = providerName;
        providerModel.lastModified = lastModified;
        providerModel.status = status;
        return providerModel;
    }
    @TestVisible
    private static YodleeService.ProviderAccountModel buildProviderAccountModel(
        String providerAccountId,
        String providerId,
        String providerAccountName,
        Date createdDate,
        Date lastUpdated,        
        String status) {

        YodleeService.ProviderAccountModel providerAccountModel = new YodleeService.ProviderAccountModel();
        providerAccountModel.id = providerAccountId;
        providerAccountModel.providerId = providerId;
        providerAccountModel.name = providerAccountName;
        providerAccountModel.createdDate = createdDate;
        providerAccountModel.lastUpdated = lastUpdated;
        providerAccountModel.status = status;
        YodleeService.DatasetModel dsm = new YodleeService.DatasetModel('BASIC_AGG_DATA', DateTime.now().addDays(1), DateTime.now(), 'AVAILABLE_DATA_RETRIEVED');
        providerAccountModel.dataset = new List<YodleeService.DatasetModel>{dsm};
        return providerAccountModel;
    }

    private static String getTransactionCountResponseBody(Integer count) {
        YodleeService.TransactionsCountResponse tcResponse = new YodleeService.TransactionsCountResponse();
        YodleeService.TransactionModel transactionModel = new YodleeService.TransactionModel();
        transactionModel.TOTAL = new YodleeService.TransactionsTotal(count);
        tcResponse.yodleeTransaction = transactionModel;
        return JSON.serialize(tcResponse);
    }

    private static String getTransactionsResponseBody(List<YodleeService.TransactionModel> transactionModels) {
        YodleeService.TransactionsResponse transactionsResponseModel = new YodleeService.TransactionsResponse();
        transactionsResponseModel.yodleeTransaction = transactionModels;
        return JSON.serialize(transactionsResponseModel);
    }

    private static String getTransactionCategoriesResponseBody(List<YodleeService.TransactionCategoryModel> categoryModels) {
        YodleeService.TransactionCategoriesResponse categoriesResponseModel = new YodleeService.TransactionCategoriesResponse();
        categoriesResponseModel.transactionCategory = categoryModels;
        return JSON.serialize(categoriesResponseModel);
    }
    
    public static YodleeService.TransactionModel buildTransactionModel(
        String transactionId, String accountId, String baseType, YodleeService.Money amount, Date aDate, Boolean isPosted) {

        YodleeService.TransactionModel transactionModel = new YodleeService.TransactionModel();
        transactionModel.accountId = accountId;
        transactionModel.id = transactionId;
        transactionModel.baseType = baseType;
        transactionModel.amount = amount;
        transactionModel.yodleeDate = aDate;
        transactionModel.status = (isPosted) ? 'POSTED' : 'PENDING';
        return transactionModel;
    }

    @TestVisible
    private static YodleeService.TransactionCategoryModel buildTransactionCategoryModel(
            Integer catId, String cat, Integer highLevelCatId, String highLevelCatName, 
            String source, String classification, String type, List<YodleeService.TransactionDetailCategory> details) {

        YodleeService.TransactionCategoryModel categoryModel = new YodleeService.TransactionCategoryModel();
        categoryModel.id = catId;
        categoryModel.category = cat;
        categoryModel.highLevelCategoryId = highLevelCatId;
        categoryModel.highLevelCategoryName = highLevelCatName;
        categoryModel.source = source;
        categoryModel.classification = classification;
        categoryModel.type = type;
        categoryModel.detailCategory = details;
        return categoryModel;
    }

    @TestVisible
    private static YodleeService.TransactionDetailCategory buildTransactionDetailCategory(Integer catId, String catName) {
        YodleeService.TransactionDetailCategory categoryDetailModel = new YodleeService.TransactionDetailCategory();
        categoryDetailModel.id = catId;
        categoryDetailModel.name = catName;
        return categoryDetailModel;
    }

    //==========================================================================================
    //============= Request URL Generators ++===================================================
    //==========================================================================================
    @TestVisible
    private static String getAuthTokenURL() {
        return YodleeService.YODLEE_API_ENDPOINT + '/auth/token';
    }
    @TestVisible
    private static String getAccountByIdURL(String accountId, Map<String, String> requestParameters) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/accounts/';
        String requestUrl = serviceEndpoint + accountId + YodleeService.populateUrlParameters(requestParameters);
        return requestUrl;
    }
    @TestVisible
    private static String getAccountsURL(Map<String, String> requestParameters) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/accounts';
        String requestUrl = serviceEndpoint + YodleeService.populateUrlParameters(requestParameters);
        return requestUrl;
    }
    @TestVisible
    private static String getProvidersURL(Map<String, String> requestParameters) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/providers';
        String requestUrl = serviceEndpoint + YodleeService.populateUrlParameters(requestParameters);
        return requestUrl;
    }
    @TestVisible
    private static String getSingleProviderURL(String providerId) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/providers/' + providerId;
        String requestUrl = serviceEndpoint;
        return requestUrl;
    }
    @TestVisible
    private static String getProviderAccountsURL(Map<String, String> requestParameters) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/providerAccounts';
        String requestUrl = serviceEndpoint + YodleeService.populateUrlParameters(requestParameters);
        return requestUrl;
    }
    @TestVisible
    private static String getTransactionsCountURL(Map<String, String> requestParameters) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/transactions/count';
        String requestUrl = serviceEndpoint + YodleeService.populateUrlParameters(requestParameters);
        return requestUrl;
    }
    @TestVisible
    private static String getTransactionsURL(Map<String, String> requestParameters) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/transactions';
        String requestUrl = serviceEndpoint + YodleeService.populateUrlParameters(requestParameters);
        return requestUrl;
    }
    @TestVisible
    private static String deleteProviderAccountURL(String providerAccountId) {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/providerAccounts/' + providerAccountId;
        String requestUrl = serviceEndpoint;
        return requestUrl;
    }
    @TestVisible
    private static String registerUserURL() {
        String serviceEndpoint = YodleeService.YODLEE_API_ENDPOINT + '/user/register';
        String requestUrl = serviceEndpoint;
        return requestUrl;
    }
    @TestVisible
    private static String getTransactionCategoriesURL() {
        return YodleeService.YODLEE_API_ENDPOINT + '/transactions/categories';
    }
}