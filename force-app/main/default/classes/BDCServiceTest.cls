@IsTest
public  class BDCServiceTest {

    @TestSetup
    private static void setupTestData() {
        
        Test.startTest();   
        
        BDCMocker.testBDCBinding();

        BDC_Binding__c testBinding = new BDC_Binding__c();
        testBinding.Name = 'Plaid';
        testBinding.To__c = 'PlaidBDCRouter';
        testBinding.Type__c = 'AbstractBDCRouter';
        testBinding.Is_Active__c = true;
        insert testBinding;

        BDC_Access_Tokens__c bdcAccessToken = new BDC_Access_Tokens__c();
        bdcAccessToken.Financial_Institution_Id__c = 'ins_3';
        bdcAccessToken.Financial_Institution_Identity_Id__c = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        bdcAccessToken.Source__c = 'Plaid';
        bdcAccessToken.Token__c = '123xyz';
        bdcAccessToken.Name = 'Test Access Token 1';
        insert bdcAccessToken;

        Test.stopTest();
    }

    //BINDINGS***********************************************************
        @IsTest
        private static void testGetBDCBinding_Success() {
            BDC_Binding__c plaidBinding = new BDC_Binding__c();
                plaidBinding.Name = 'Plaid';
                plaidBinding.To__c = 'PlaidBDCRouter';
                plaidBinding.Type__c = 'AbstractBDCRouter';
                plaidBinding.Is_Active__c = true;
            insert plaidBinding;
            
            Test.startTest();
                BDCService service = new BDCService();
                System.assertEquals(plaidBinding, service.getBDCBinding(plaidBinding.Name));
            Test.stopTest();
        }

        @IsTest
        private static void testGetBDCBinding_Fail() {
            Test.startTest();
                BDCService service = new BDCService();
                try{
                    service.getBDCBinding('DoesNotExist');
                }catch(BDCService.BDCException ex){
                    system.assertEquals(BDCService.ERR_BDC_MISSING_ROUTER, ex.getMessage());
                }
                
            Test.stopTest();
        }

        @IsTest
        private static void testGetBDCBindings_Success() {
            
            Test.startTest();
                BDCService service = new BDCService();
        
                List<BDC_Binding__c> bindings = new List<BDC_Binding__c>();
                bindings = service.getBDCBindings();

                List<BDC_Binding__c> existingBindings = [SELECT Name, Description__c, Type__c, To__c, Is_Active__c
                                                        FROM BDC_Binding__c];
                system.assertEquals(existingBindings.size(), bindings.size());
                
            Test.stopTest();
        }
    @IsTest
    private static void deleteFinancialInstitutionIdentity_Success() {

        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCFinancialInstitutionIdentity fIds = new BDCFinancialInstitutionIdentity();
                fIds.Id = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

                BDCServiceResult serviceResult = new BDCServiceResult();
                BDCService service = new BDCService();
                
                options.BDCBinding = [Select id, Is_Active__c,Name from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                options.bdcFinancialInstitutionIdentities = new BDCFinancialInstitutionIdentity[]{fIds};

                SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_DELETE_TEST_JSON,
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);

                serviceResult = service.deleteFinancialInstitutionIdentity(options);

                System.assertEquals(TRUE, serviceResult.isSuccess);
            Test.stopTest();
        }
    }

    @IsTest
    private static void deleteFinancialInstitutionIdentity_FailWithOptionNull() {
        try{
            Test.startTest();
            BDCServiceOptions options = new BDCServiceOptions();
            BDCServiceResult serviceResult = new BDCServiceResult();
            BDCService service = new BDCService();
            
            serviceResult = service.deleteFinancialInstitutionIdentity(null);
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals(TRUE, ex.getMessage().contains('No BDC Service Options were provided.'));   
        }
    }

    @IsTest
    private static void deleteFinancialInstitutionIdentityService_Fail() {

        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCFinancialInstitutionIdentity fIds = new BDCFinancialInstitutionIdentity();
                fIds.Id = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

                BDCServiceResult serviceResult;
                BDCService service = new BDCService();
                
                options.BDCBinding = [Select id, Is_Active__c,Name from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                options.bdcFinancialInstitutionIdentities = new BDCFinancialInstitutionIdentity[]{fIds};

                SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                    400,
                    'Fail',
                    PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_DELETE_TEST_JSON,
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);

                serviceResult = service.deleteFinancialInstitutionIdentity(options);
                
                String err = ' and provide this Plaid error code';
                System.assertEquals(FALSE, serviceResult.isSuccess);
                System.assertEquals(TRUE, serviceResult.errors.size() > 0);
                System.assertEquals(TRUE, serviceResult.errors[0].detail.contains(err));
            Test.stopTest();
        }
    }

    @IsTest
    private static void deleteFinancialInstitutionIdentity_Fail() {
        Test.startTest();
            BDCServiceOptions options = new BDCServiceOptions();
            BDCFinancialInstitutionIdentity fIds = new BDCFinancialInstitutionIdentity();
            fIds.Id = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

            BDCServiceResult serviceResult;
            BDCService service = new BDCService();
            
            options.BDCBinding = [Select id, Is_Active__c,Name from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
            options.bdcFinancialInstitutionIdentities = new BDCFinancialInstitutionIdentity[]{fIds};

            serviceResult = service.deleteFinancialInstitutionIdentity(options);
            
            System.assertEquals(FALSE, serviceResult.isSuccess);
            System.assertEquals(TRUE, serviceResult.errors.size() > 0);
        Test.stopTest();
    }
    
    //FINANCIAL INSTITUTIONS***********************************************************
        @IsTest
        private static void getFinancialInstitutions_Success() {

            TestDataSuite testData = TestDataSuite.getInstance(true);

            System.runAs(testData.users[1]) {
                Test.startTest();
                    BDCServiceOptions options = new BDCServiceOptions();
                    BDCService service = new BDCService();
                    BDCServiceResult serviceResult = new BDCServiceResult();
                    BDCFinancialInstitutionIdentity fIds = new BDCFinancialInstitutionIdentity();
                    fIds.financialInstitutionId = 'ins_3';
    
                    options.bdcFinancialInstitutionIdentities = new BDCFinancialInstitutionIdentity[]{fIds};
                    options.BDCBinding = [Select id, Is_Active__c,Name from BDC_Binding__c where Name = 'Plaid' LIMIT 1];

                    SingleRequestMock xFinancialInstitutionsRequestMock = new SingleRequestMock(
                        200,
                        'Complete',
                        PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
                        new Map<String, String>{'Content-Type' => 'application/json'}
                    );
                    Test.setMock(HttpCalloutMock.class, xFinancialInstitutionsRequestMock);

                    serviceResult = service.getFinancialInstitutions(options);

                    System.assertEquals(true, serviceResult.isSuccess);
                    System.assertEquals('ins_3', serviceResult.data.bdcFinancialInstitutions[0].id);
                    System.assertEquals('Chase', serviceResult.data.bdcFinancialInstitutions[0].Name);
                Test.stopTest();
            }
        }

        @IsTest
        private static void getFinancialInstitutions_No_Options() {
            Test.startTest();
                BDCService service = new BDCService();

                BDCServiceResult serviceResult = new BDCServiceResult();
                try{
                    serviceResult = service.getFinancialInstitutions(null);
                }catch(BDCService.BDCException e){
                    System.assertEquals(e.getMessage(), BDCService.ERR_BDC_MISSING_OPTIONS);
                }
            Test.stopTest();
        }
        
        @IsTest
        private static void getFinancialInstitutions_Connector_Exception() {

            TestDataSuite testData = TestDataSuite.getInstance(true);

            System.runAs(testData.users[1]) {
                Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();

                options.bdcFinancialInstitutionIdentities = null;
                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 
                serviceResult = service.getFinancialInstitutions(options);

                System.assertEquals(FALSE, serviceResult.isSuccess);
                System.assertEquals(BDCService.ERR_BDC_MISSING_FI_IDENTITY_IDS, serviceResult.errors[0].detail);
                Test.stopTest();
            }
        }

    //ACCOUNTS***********************************************************
        @IsTest
        private static void getAccounts_Success() {
            
            BDCService service = new BDCService();
            BDCServiceOptions options = new BDCServiceOptions();
            BDCServiceResult serviceResult = new BDCServiceResult();

            Test.startTest();
                //mock data model
                BDCDataModel model =  BDCMocker.testBDCDataModel();
                //get acct Ids
                List<String> acctIds = new List<String>();
                for(BDCAccount acct : model.bdcAccounts){
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

                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                options.bdcAccountIds = acctIds;
                serviceResult = service.getAccounts(options);
               
                System.assertEquals(true, serviceResult.isSuccess);
                System.assertEquals('PnpkZlD1rDtQZ7oxk97kSd3xJxz1pwf7bgeLk', serviceResult.data.bdcAccounts[0].id);
                System.assertEquals('Plaid Gold Standard 0% Interest Checking', serviceResult.data.bdcAccounts[0].name);
                System.assertEquals('Plaid Checking', serviceResult.data.bdcAccounts[0].nickname);
                System.assertEquals('depository', serviceResult.data.bdcAccounts[0].accountType);
                System.assertEquals('0000', serviceResult.data.bdcAccounts[0].maskedAccountNumber);
                System.assertEquals('wnVRXPmk3mt3wepjXEeXsbN4NWe5V9FrNeEN1', serviceResult.data.bdcAccounts[0].financialInstitutionIdentity);

                System.assertEquals('eNVMxpWB6WFpQmr8gvmgi3woAoQP5aHLKpbvG', serviceResult.data.bdcAccounts[1].id);
                System.assertEquals('Plaid Silver Standard 0.1% Interest Saving', serviceResult.data.bdcAccounts[1].name);
                System.assertEquals('Plaid Saving', serviceResult.data.bdcAccounts[1].nickname);
                System.assertEquals('depository', serviceResult.data.bdcAccounts[1].accountType);
                System.assertEquals('1111', serviceResult.data.bdcAccounts[1].maskedAccountNumber);
                System.assertEquals('wnVRXPmk3mt3wepjXEeXsbN4NWe5V9FrNeEN1', serviceResult.data.bdcAccounts[1].financialInstitutionIdentity);

                System.assertEquals('jQVLmWn4pnCokXGzlpXlSEKkXkd6AbT1kD7K4', serviceResult.data.bdcAccounts[2].id);
                System.assertEquals('Plaid Bronze Standard 0.2% Interest CD', serviceResult.data.bdcAccounts[2].name);
                System.assertEquals('Plaid CD', serviceResult.data.bdcAccounts[2].nickname);
                System.assertEquals('depository', serviceResult.data.bdcAccounts[2].accountType);
                System.assertEquals('2222', serviceResult.data.bdcAccounts[2].maskedAccountNumber);
                System.assertEquals('wnVRXPmk3mt3wepjXEeXsbN4NWe5V9FrNeEN1', serviceResult.data.bdcAccounts[2].financialInstitutionIdentity);
            Test.stopTest();
        }

        @IsTest
        private static void getAccounts_No_Options() {
            Test.startTest();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();
                try{
                    serviceResult = service.getAccounts(null);
                }catch(BDCService.BDCException e){
                    System.assertEquals(e.getMessage(), BDCService.ERR_BDC_MISSING_OPTIONS);
                }
            Test.stopTest();
        }
        
        @IsTest
        private static void getAccounts_Invalid_Options() {
            
            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCServiceResult serviceResult = new BDCServiceResult();
                BDCService service = new BDCService();

                //set list to empty string so validation fails
                List<String> finInstIds = new List<String>();
                options.bdcFinancialInstitutionIds = finInstIds;
                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                
                serviceResult = service.getAccounts(options);
                
                System.assertEquals(false, serviceResult.isSuccess);
                System.assertEquals(serviceResult.errors[0].detail, BDCService.ERR_BDC_MISSING_ACCOUNT_IDS);
            Test.stopTest();
        }

        @IsTest
        private static void getAccounts_Connector_Exception() {
            
            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCServiceResult serviceResult = new BDCServiceResult();
                BDCService service = new BDCService();
            
                BDC_Binding__c plaidBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                plaidBinding.To__c = null;
                
                options.BDCBinding = plaidBinding;
                serviceResult = service.getAccounts(options);
            
                System.assertEquals(false, serviceResult.isSuccess);
                System.assertEquals('Financial Institution Account Ids were not provided.', serviceResult.errors[0].detail);
            Test.stopTest();
        }
    
        //TRANSACTIONS***********************************************************
        @IsTest
        private static void getTransactions_Success() {

            TestDataSuite testData = TestDataSuite.getInstance(true);

            System.runAs(testData.users[1]) {
            Test.startTest();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();
                BDCServiceOptions options = new BDCServiceOptions();

                options.fromDate = System.Date.today().addDays(-90);
                options.toDate = System.Date.today();
                options.maxRecords = PlaidBDCConnector.MAX_TXNS_PER_CALLOUT;
                options.offset = 0;
                options.bdcAccountIds = new String[]{'AS_Bank_Identity_Acc_0'};
                //Setting of mock
                    SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                        200,
                        'Complete',
                        PlaidBDCTest.TRANSACTION_TEST_JSON , 
                        new Map<String, String>{'Content-Type' => 'application/json'}
                    );
        
                Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
                
                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                serviceResult = service.getTransactions(options);
                
                System.assertEquals(true, serviceResult.isSuccess);
                System.assertEquals('lPNjeW1nR6CDn5okmGQ6hEpMo4lLNoSrzqDje', serviceResult.data.bdcTransactions[0].id);
                System.assertEquals('AS_Bank_Identity_Acc_0', serviceResult.data.bdcTransactions[0].accountId);
                System.assertEquals('12008000', serviceResult.data.bdcTransactions[0].categoryId);
                System.assertEquals(2307.21, serviceResult.data.bdcTransactions[0].amount);
                System.assertEquals('USD', serviceResult.data.bdcTransactions[0].currencyIsoCode);
                System.assertEquals('Apple', serviceResult.data.bdcTransactions[0].merchantName);
                System.assertEquals(null, serviceResult.data.bdcTransactions[0].checkNumber);
                System.assertEquals('place', serviceResult.data.bdcTransactions[0].type);
            Test.stopTest();
        }
    }

        @IsTest
        private static void getTransactions_No_Options() {
            Test.startTest();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();
                try{
                    serviceResult = service.getTRansactions(null);
                }catch(BDCService.BDCException e){
                    System.assertEquals(e.getMessage(), BDCService.ERR_BDC_MISSING_OPTIONS);
                }
            Test.stopTest();
        }

        
        @IsTest
        private static void getTransactions_No_From_Date() {

            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();

                options.fromDate = null;
                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                serviceResult = service.getTransactions(options);

                System.assertEquals(false, serviceResult.isSuccess);
                System.assertEquals(serviceResult.errors[0].detail, BDCService.ERR_BDC_MISSING_FROM_DATE);
            Test.stopTest();
        }

        
        @IsTest
        private static void getFinancialInstitutionIdentities_Success() {

            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();

                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 
                serviceResult = service.getFinancialInstitutionIdentities(options);
                
                System.assertEquals(TRUE, serviceResult.isSuccess);
                System.assertEquals('yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9', serviceResult.data.bdcFinancialInstitutionIdentities[0].id);
                System.assertEquals('ins_3', serviceResult.data.bdcFinancialInstitutionIdentities[0].financialInstitutionid);
                System.assertEquals('OK', serviceResult.data.bdcFinancialInstitutionIdentities[0].status);
            Test.stopTest();
        }

        
        @IsTest
        private static void getFinancialInstitutionIdentities_With_No_Option() {

            Test.startTest();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();
                try{
                    serviceResult = service.getFinancialInstitutionIdentities(null);
                }catch(BDCService.BDCException e){
                    System.assertEquals(e.getMessage(), BDCService.ERR_BDC_MISSING_OPTIONS);
                }
            Test.stopTest();
        }

        @IsTest
        private static void getFinancialInstitutionIdentities_Fail() {

            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();

                BDC_Binding__c plaidBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                plaidBinding.To__c = null;
                
                options.BDCBinding =  plaidBinding;
                serviceResult = service.getFinancialInstitutionIdentities(options);
                
                System.assertEquals(FALSE, serviceResult.isSuccess);
                System.assertEquals(TRUE, serviceResult.errors.size() > 0);
            Test.stopTest();
        }
        
        @IsTest
        private static void  getCategories_Success() {
           
            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();

                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    PlaidBDCTest.CATEGORIES_TEST_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 
                serviceResult = service.getCategories(options);
                
                List<BDCCategory> bdcCatgories = serviceResult.data.bdcCategories.values();
                System.assertEquals(TRUE, serviceResult.isSuccess);
                System.assertEquals('12000000', bdcCatgories[0].id);
                System.assertEquals('Shops', bdcCatgories[0].name);
                System.assertEquals(null, bdcCatgories[0].parentCategoryId);

                System.assertEquals('12008000', bdcCatgories[1].id);
                System.assertEquals('Computers and Electronics', bdcCatgories[1].name);
                System.assertEquals('12000000', bdcCatgories[1].parentCategoryId);

                System.assertEquals('12008001', bdcCatgories[2].id);
                System.assertEquals('Mobile Phones', bdcCatgories[2].name);
                System.assertEquals('12008000', bdcCatgories[2].parentCategoryId);
            Test.stopTest();
        }

        @IsTest
        private static void getCategories_With_No_Option() {

            Test.startTest();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();
                try{
                    serviceResult = service.getCategories(null);
                }catch(BDCService.BDCException e){
                    System.assertEquals(e.getMessage(), BDCService.ERR_BDC_MISSING_OPTIONS);
                }
            Test.stopTest();
        }

        @IsTest
        private static void getCategories_Fail() {

            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();

                BDC_Binding__c plaidBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                plaidBinding.To__c = null;
                
                options.BDCBinding =  plaidBinding;
                serviceResult = service.getCategories(options);
                
                System.assertEquals(FALSE, serviceResult.isSuccess);
                System.assertEquals(TRUE, serviceResult.errors.size() > 0);
            Test.stopTest();
        }

        @IsTest
        private static void getAccountsByIdentityIds_Success() {
           
            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();
                BDCFinancialInstitutionIdentity finIds = new BDCFinancialInstitutionIdentity();
                finIds.Id = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';

                options.bdcFinancialInstitutionIdentities = new BDCFinancialInstitutionIdentity[]{finIds};
                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 
                serviceResult = service.getAccountsByIdentityIds(options);

                System.assertEquals(true, serviceResult.isSuccess);
                System.assertEquals('j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv', serviceResult.data.bdcAccounts[0].id);
                System.assertEquals('Plaid Gold Standard 0% Interest Checking', serviceResult.data.bdcAccounts[0].name);
                System.assertEquals('Plaid Checking', serviceResult.data.bdcAccounts[0].nickname);
                System.assertEquals('depository', serviceResult.data.bdcAccounts[0].accountType);
                System.assertEquals('0000', serviceResult.data.bdcAccounts[0].maskedAccountNumber);
                System.assertEquals('yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9', serviceResult.data.bdcAccounts[0].financialInstitutionIdentity);

                System.assertEquals('7nb9NbQr8GHy963VVNGbcJM1pBVJWei11mplM', serviceResult.data.bdcAccounts[1].id);
                System.assertEquals('Plaid Silver Standard 0.1% Interest Saving', serviceResult.data.bdcAccounts[1].name);
                System.assertEquals('Plaid Saving', serviceResult.data.bdcAccounts[1].nickname);
                System.assertEquals('depository', serviceResult.data.bdcAccounts[1].accountType);
                System.assertEquals('1111', serviceResult.data.bdcAccounts[1].maskedAccountNumber);
                System.assertEquals('yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9', serviceResult.data.bdcAccounts[1].financialInstitutionIdentity);
            Test.stopTest();    
        }

        @IsTest
        private static void getAccountsByIdentityIds_With_NO_Options() {

            Test.startTest();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();
                try{
                    serviceResult = service.getAccountsByIdentityIds(null);
                }catch(BDCService.BDCException e){
                    System.assertEquals(e.getMessage(), BDCService.ERR_BDC_MISSING_OPTIONS);
                }
            Test.stopTest();
        }

        @IsTest
        private static void getAccountsByIdentityIds_fail() {
           
            Test.startTest();
                BDCServiceOptions options = new BDCServiceOptions();
                BDCService service = new BDCService();
                BDCServiceResult serviceResult = new BDCServiceResult();

                options.bdcFinancialInstitutionIdentities = null;
                options.BDCBinding = [Select id, Is_Active__c,Name,To__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
                SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON , 
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );
                Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 
                serviceResult = service.getAccountsByIdentityIds(options);

                System.assertEquals(FALSE, serviceResult.isSuccess);
                System.assertEquals(BDCService.ERR_BDC_MISSING_FI_IDENTITY_IDS, serviceResult.errors[0].detail);
            Test.stopTest();    
        } 
}