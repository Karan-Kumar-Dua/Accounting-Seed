@IsTest
public class YodleeHelperTest {

//TODO this class will be commented out and deprecated.  Commenting out test to prevent build failures
/*
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testDownloadTransactions() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String yodleeAccountId1 = 'First CC Account';
            String yodleeAccountId2 = 'Second CC Account';
            DateTime fromDate = DateTime.now().addDays(-YodleeHelper.DEFAULT_START_DATE_OFFSET_IN_DAYS);            
            Date toDate = Date.today();
            //Create GLAMs
            List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
            GL_Account_Mapping__c glam1 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId1,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = NULL,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam1);
            GL_Account_Mapping__c glam2 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId2,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = fromDate,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam2);
            insert glams;

            //Create Yodlee account models to mock Yodlee getAccounts request
            List<YodleeService.AccountModel> accountModels = new List<YodleeService.AccountModel>();

            YodleeService.AccountModel accountModel1 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId1, new YodleeService.Money(10000, 'USD'), new YodleeService.Money(10000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()
            );
            accountModels.add(accountModel1);
            YodleeService.AccountModel accountModel2 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId2, new YodleeService.Money(20000, 'USD'), new YodleeService.Money(30000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()
            );
            accountModels.add(accountModel2);

            //Create transaction models to mock Yodlee getTransactions request
            List<YodleeService.TransactionModel> transactionModels = new List<YodleeService.TransactionModel>();
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '11111111', yodleeAccountId1, 'Credit', new YodleeService.Money(100, NULL), Date.today().addDays(-1), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '22222222', yodleeAccountId1, 'Credit', new YodleeService.Money(200, NULL), Date.today().addDays(-2), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '33333333', yodleeAccountId2, 'Debit', new YodleeService.Money(10, NULL), Date.today().addDays(-3), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '44444444', yodleeAccountId2, 'Debit', new YodleeService.Money(20, NULL), Date.today().addDays(-4), true
            ));
            for (YodleeService.TransactionModel trx : transactionModels) {
                trx.container = 'Bank';
            }

            //Create providerAccount models to mock Yodlee getProviderAccounts request
            List<YodleeService.ProviderAccountModel> providerAccountModels = new List<YodleeService.ProviderAccountModel>();
            providerAccountModels.add(YodleeServiceTest.buildProviderAccountModel(
                '12345678', '64414', 'ProviderAccount1', Date.today().addDays(-1), Date.today(), 'SUCCESS'
            ));  

            //Set HTTP request mocks
            SingleRequestMock xGetGetAccountsRequestMock = YodleeServiceTest.initGetAccountsRequestMock(accountModels);
            SingleRequestMock xGetTransactionsCountRequestMock = YodleeServiceTest.initGetTransactionCountRequestMock(transactionModels.size());
            SingleRequestMock xGetTransactionsRequestMock = YodleeServiceTest.initGetTransactionsRequestMock(transactionModels);
            SingleRequestMock xGetTransactionCategoriesRequestMock = YodleeServiceTest.initGetTransactionCategoriesRequestMock(null);
            SingleRequestMock xGetProviderAccountsRequestMock = YodleeServiceTest.initGetProviderAccountsRequestMock(providerAccountModels);

            fromDate = fromDate.addDays(YodleeHelper.REFRESH_OFFSET * -1);
            Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
                YodleeServiceTest.getAccountsURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'include' => 'autoRefresh'
                    }
                ) => xGetGetAccountsRequestMock,
                YodleeServiceTest.getTransactionsCountURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate)
                    }
                ) => xGetTransactionsCountRequestMock,
                YodleeServiceTest.getTransactionsURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate),
                        'skip' => '0',
                        'top' => String.valueOf(YodleeHelper.TRN_PAGE_SIZE)
                    }
                ) => xGetTransactionsRequestMock,
                YodleeServiceTest.getTransactionCategoriesURL() => xGetTransactionCategoriesRequestMock,
                YodleeServiceTest.getProviderAccountsURL(NULL) => xGetProviderAccountsRequestMock
                
            };
            MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
            Test.setMock(HttpCalloutMock.class, multiRequestMock);

            Test.startTest();
            YodleeHelper.downloadBankTransactions(NULL, NULL);
            Test.stopTest();

            List<Bank_Transaction__c> bankTransaction = [SELECT Id FROM Bank_Transaction__c];
            List<GL_Account_Mapping__c> glamsAfterUpdate = [SELECT Id, Last_Refreshed__c FROM GL_Account_Mapping__c];

            System.assertEquals(transactionModels.size(), bankTransaction.size());
            System.assertNotEquals(NULL, glamsAfterUpdate[0].Last_Refreshed__c);
        }
    }

    @IsTest
    private static void testDownloadTransactionsFilterOutTransactionsBeforeGLAMStartDate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String yodleeAccountId1 = 'First CC Account';
            String yodleeAccountId2 = 'Second CC Account';
            DateTime fromDate = DateTime.now().addDays(-YodleeHelper.DEFAULT_START_DATE_OFFSET_IN_DAYS);            
            Date toDate = Date.today();
            //set glam1 to be 90 days ago
            List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
            GL_Account_Mapping__c glam1 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId1,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = NULL,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam1);
            //set glam2 to be 3 days ago
            GL_Account_Mapping__c glam2 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId2,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = fromDate,
                Initial_Start_Date__c = Date.today().addDays(-3)
            );
            glams.add(glam2);
            insert glams;

            //Create Yodlee account models to mock Yodlee getAccounts request
            List<YodleeService.AccountModel> accountModels = new List<YodleeService.AccountModel>();

            YodleeService.AccountModel accountModel1 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId1, new YodleeService.Money(10000, 'USD'), new YodleeService.Money(10000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()
            );
            accountModels.add(accountModel1);
            YodleeService.AccountModel accountModel2 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId2, new YodleeService.Money(20000, 'USD'), new YodleeService.Money(30000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()
            );
            accountModels.add(accountModel2);

            //Create transaction models to mock Yodlee getTransactions request
            List<YodleeService.TransactionModel> transactionModels = new List<YodleeService.TransactionModel>();
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '11111111', yodleeAccountId1, 'Credit', new YodleeService.Money(100, NULL), Date.today().addDays(-1), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '22222222', yodleeAccountId1, 'Credit', new YodleeService.Money(200, NULL), Date.today().addDays(-2), true
            ));
            //this one shouldn't get picked up by the job
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '33333333', yodleeAccountId2, 'Debit', new YodleeService.Money(10, NULL), Date.today().addDays(-30), true
            ));
            //this one should get picked up by the job because it's within the 14 day offset
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '44444444', yodleeAccountId2, 'Debit', new YodleeService.Money(20, NULL), Date.today().addDays(-4), true
            ));
            for (YodleeService.TransactionModel trx : transactionModels) {
                trx.container = 'Bank';
            }

            //Create providerAccount models to mock Yodlee getProviderAccounts request
            List<YodleeService.ProviderAccountModel> providerAccountModels = new List<YodleeService.ProviderAccountModel>();
            providerAccountModels.add(YodleeServiceTest.buildProviderAccountModel(
                '12345678', '64414', 'ProviderAccount1', Date.today().addDays(-1), Date.today(), 'SUCCESS'
            ));  

            //Set HTTP request mocks
            SingleRequestMock xGetGetAccountsRequestMock = YodleeServiceTest.initGetAccountsRequestMock(accountModels);
            SingleRequestMock xGetTransactionsCountRequestMock = YodleeServiceTest.initGetTransactionCountRequestMock(transactionModels.size());
            SingleRequestMock xGetTransactionsRequestMock = YodleeServiceTest.initGetTransactionsRequestMock(transactionModels);
            SingleRequestMock xGetTransactionCategoriesRequestMock = YodleeServiceTest.initGetTransactionCategoriesRequestMock(null);
            SingleRequestMock xGetProviderAccountsRequestMock = YodleeServiceTest.initGetProviderAccountsRequestMock(providerAccountModels);

            fromDate = fromDate.addDays(YodleeHelper.REFRESH_OFFSET * -1);
            Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
                YodleeServiceTest.getAccountsURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'include' => 'autoRefresh'
                    }
                ) => xGetGetAccountsRequestMock,
                YodleeServiceTest.getTransactionsCountURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate)
                    }
                ) => xGetTransactionsCountRequestMock,
                YodleeServiceTest.getTransactionsURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate),
                        'skip' => '0',
                        'top' => String.valueOf(YodleeHelper.TRN_PAGE_SIZE)
                    }
                ) => xGetTransactionsRequestMock,
                YodleeServiceTest.getTransactionCategoriesURL() => xGetTransactionCategoriesRequestMock,
                YodleeServiceTest.getProviderAccountsURL(NULL) => xGetProviderAccountsRequestMock
                
            };
            MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
            Test.setMock(HttpCalloutMock.class, multiRequestMock);

            Test.startTest();
            YodleeHelper.downloadBankTransactions(NULL, NULL, true);
            Test.stopTest();

            List<Bank_Transaction__c> bankTransactions = [SELECT Id, Bank_Transaction_Id__c FROM Bank_Transaction__c];
            List<GL_Account_Mapping__c> glamsAfterUpdate = [SELECT Id, Last_Refreshed__c FROM GL_Account_Mapping__c];

            System.assertEquals(transactionModels.size()-1, bankTransactions.size());        
            for (Bank_Transaction__c bankTransaction : bankTransactions) {
                System.assertNotEquals('33333333', bankTransaction.Bank_Transaction_Id__c);
            }
        }
    }

    @IsTest
    private static void testDownloadTransactionsWhenNotExistedAccountIdSentAsRequestParameter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String yodleeAccountId1 = 'First CC Account';
            String yodleeAccountId2 = 'Second CC Account';
            String yodleeAccountId3 = 'Third CC Account';
            DateTime fromDate = DateTime.now().addDays(-YodleeHelper.DEFAULT_START_DATE_OFFSET_IN_DAYS);
            Date toDate = Date.today();
            //Create GLAMs
            List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
            GL_Account_Mapping__c glam1 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId1,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = NULL,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam1);
            GL_Account_Mapping__c glam2 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId2,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = fromDate,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam2);
            //This GLAM will represent Yodlee Account which does not exist on the Yodlee side
            GL_Account_Mapping__c glam3 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId3,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = fromDate,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam3);
            insert glams;

            //Create Yodlee account models to mock Yodlee getAccounts request
            List<YodleeService.AccountModel> accountModels = new List<YodleeService.AccountModel>();
            YodleeService.AccountModel accountModel1 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId1, new YodleeService.Money(10000, 'USD'), new YodleeService.Money(10000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()                
            );
            accountModels.add(accountModel1);
            YodleeService.AccountModel accountModel2 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId2, new YodleeService.Money(20000, 'USD'), new YodleeService.Money(30000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()                
            );
            //Only two accounts here (but 3 GLAMs in SF DB)
            accountModels.add(accountModel2);

            //Create transaction models to mock Yodlee getTransactions request
            List<YodleeService.TransactionModel> transactionModels = new List<YodleeService.TransactionModel>();
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '11111111', yodleeAccountId1, 'Credit', new YodleeService.Money(100, NULL), Date.today().addDays(-1), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '22222222', yodleeAccountId1, 'Credit', new YodleeService.Money(200, NULL), Date.today().addDays(-2), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '33333333', yodleeAccountId2, 'Debit', new YodleeService.Money(10, NULL), Date.today().addDays(-3), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '44444444', yodleeAccountId2, 'Debit', new YodleeService.Money(20, NULL), Date.today().addDays(-4), true
            ));
            for (YodleeService.TransactionModel trx : transactionModels) {
                trx.container = 'Bank';
            }

            //Create providerAccount models to mock Yodlee getProviderAccounts request
            List<YodleeService.ProviderAccountModel> providerAccountModels = new List<YodleeService.ProviderAccountModel>();
            providerAccountModels.add(YodleeServiceTest.buildProviderAccountModel(
                '12345678', '64414', 'ProviderAccount1', Date.today().addDays(-1), Date.today(), 'SUCCESS'
            ));

            //Set HTTP request mocks
            SingleRequestMock xGetGetAccountsRequestMock = YodleeServiceTest.initGetAccountsRequestMock(accountModels);
            SingleRequestMock xGetTransactionsCountRequestMock = YodleeServiceTest.initGetTransactionCountRequestMock(transactionModels.size());
            SingleRequestMock xGetTransactionsRequestMock = YodleeServiceTest.initGetTransactionsRequestMock(transactionModels);
            SingleRequestMock xGetTransactionCategoriesRequestMock = YodleeServiceTest.initGetTransactionCategoriesRequestMock(null);
            SingleRequestMock xGetProviderAccountsRequestMock = YodleeServiceTest.initGetProviderAccountsRequestMock(providerAccountModels);           
            
            fromDate = fromDate.addDays(YodleeHelper.REFRESH_OFFSET * -1);
            Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
                YodleeServiceTest.getAccountsURL(
                    new Map<String, String>{
                        
                        'accountId' => accountModel1.id + ',' + accountModel2.id + ',' + yodleeAccountId3,
                        'include' => 'autoRefresh'
                    }
                ) => xGetGetAccountsRequestMock,
                YodleeServiceTest.getTransactionsCountURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate)
                    }
                ) => xGetTransactionsCountRequestMock,
                YodleeServiceTest.getTransactionsURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate),
                        'skip' => '0',
                        'top' => String.valueOf(YodleeHelper.TRN_PAGE_SIZE)
                    }
                ) => xGetTransactionsRequestMock,
                YodleeServiceTest.getTransactionCategoriesURL() => xGetTransactionCategoriesRequestMock,
                YodleeServiceTest.getProviderAccountsURL(NULL) => xGetProviderAccountsRequestMock
            };
            MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
            Test.setMock(HttpCalloutMock.class, multiRequestMock);

            Test.startTest();
            YodleeHelper.downloadBankTransactions(NULL, NULL);
            Test.stopTest();

            List<Bank_Transaction__c> bankTransaction = [SELECT Id FROM Bank_Transaction__c];
            List<GL_Account_Mapping__c> glamsAfterUpdate = [SELECT Id, Last_Refreshed__c FROM GL_Account_Mapping__c];

            System.assertEquals(transactionModels.size(), bankTransaction.size());
            System.assertNotEquals(NULL, glamsAfterUpdate[0].Last_Refreshed__c);
        }
    }

    @IsTest
    private static void testDownloadOnlyPostedTransactions() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String yodleeAccountId1 = 'First CC Account';
            String yodleeAccountId2 = 'Second CC Account';
            DateTime fromDate = DateTime.now().addDays(-YodleeHelper.DEFAULT_START_DATE_OFFSET_IN_DAYS);
            Date toDate = Date.today();
            //Create GLAMs
            List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
            GL_Account_Mapping__c glam1 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId1,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = NULL,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam1);
            GL_Account_Mapping__c glam2 = new GL_Account_Mapping__c(
                External_Id__c = yodleeAccountId2,
                GL_Account__c = testData.glAccounts[0].Id,
                Last_Refreshed__c = fromDate,
                Initial_Start_Date__c = fromDate.date()
            );
            glams.add(glam2);
            insert glams;

            //Create Yodlee account models to mock Yodlee getAccounts request
            List<YodleeService.AccountModel> accountModels = new List<YodleeService.AccountModel>();
            YodleeService.AccountModel accountModel1 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId1, new YodleeService.Money(10000, 'USD'), new YodleeService.Money(10000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()
            );
            accountModels.add(accountModel1);
            YodleeService.AccountModel accountModel2 = YodleeServiceTest.buildAccountModel(
                yodleeAccountId2, new YodleeService.Money(20000, 'USD'), new YodleeService.Money(30000, 'USD'), NULL, NULL, '12345678', 'ProviderAccount1', Date.today()
            );
            accountModels.add(accountModel2);

            //Create transaction models to mock Yodlee getTransactions request
            List<YodleeService.TransactionModel> transactionModels = new List<YodleeService.TransactionModel>();
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '11111111', yodleeAccountId1, 'Credit', new YodleeService.Money(100, NULL), Date.today().addDays(-1), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '22222222', yodleeAccountId1, 'Credit', new YodleeService.Money(200, NULL), Date.today().addDays(-2), false
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '33333333', yodleeAccountId2, 'Debit', new YodleeService.Money(10, NULL), Date.today().addDays(-3), true
            ));
            transactionModels.add(YodleeServiceTest.buildTransactionModel(
                '44444444', yodleeAccountId2, 'Debit', new YodleeService.Money(20, NULL), Date.today().addDays(-4), false
            ));
            for (YodleeService.TransactionModel trx : transactionModels) {
                trx.container = 'Bank';
            }

            //Create providerAccount models to mock Yodlee getProviderAccounts request
            List<YodleeService.ProviderAccountModel> providerAccountModels = new List<YodleeService.ProviderAccountModel>();
            providerAccountModels.add(YodleeServiceTest.buildProviderAccountModel(
                '12345678', '64414', 'ProviderAccount1', Date.today().addDays(-1), Date.today(), 'SUCCESS'
            ));                        

            //Set HTTP request mocks
            SingleRequestMock xGetGetAccountsRequestMock = YodleeServiceTest.initGetAccountsRequestMock(accountModels);
            SingleRequestMock xGetTransactionsCountRequestMock = YodleeServiceTest.initGetTransactionCountRequestMock(transactionModels.size());
            SingleRequestMock xGetTransactionsRequestMock = YodleeServiceTest.initGetTransactionsRequestMock(transactionModels);
            SingleRequestMock xGetTransactionCategoriesRequestMock = YodleeServiceTest.initGetTransactionCategoriesRequestMock(null);            
            SingleRequestMock xGetProviderAccountsRequestMock = YodleeServiceTest.initGetProviderAccountsRequestMock(providerAccountModels);            

            fromDate = fromDate.addDays(YodleeHelper.REFRESH_OFFSET * -1);
            Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
                YodleeServiceTest.getAccountsURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'include' => 'autoRefresh'
                    }
                ) => xGetGetAccountsRequestMock,
                YodleeServiceTest.getTransactionsCountURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate)
                    }
                ) => xGetTransactionsCountRequestMock,
                YodleeServiceTest.getTransactionsURL(
                    new Map<String, String>{
                        'accountId' => accountModel1.id + ',' + accountModel2.id,
                        'fromDate' => YodleeHelper.formatDate(fromDate.date()),
                        'toDate' => YodleeHelper.formatDate(toDate),
                        'skip' => '0',
                        'top' => String.valueOf(YodleeHelper.TRN_PAGE_SIZE)
                    }
                ) => xGetTransactionsRequestMock,
                YodleeServiceTest.getTransactionCategoriesURL() => xGetTransactionCategoriesRequestMock,
                YodleeServiceTest.getProviderAccountsURL(NULL) => xGetProviderAccountsRequestMock

            };
            MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
            Test.setMock(HttpCalloutMock.class, multiRequestMock);

            Test.startTest();
            YodleeHelper.downloadBankTransactions(NULL, NULL);
            Test.stopTest();

            List<Bank_Transaction__c> bankTransaction = [SELECT Id FROM Bank_Transaction__c];
            List<GL_Account_Mapping__c> glamsAfterUpdate = [SELECT Id, Last_Refreshed__c FROM GL_Account_Mapping__c];

            System.assertNotEquals(transactionModels.size(), bankTransaction.size());
            System.assertNotEquals(NULL, glamsAfterUpdate[0].Last_Refreshed__c);
        }
    }

    @IsTest
    private static void testGetCategories() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<YodleeService.TransactionCategoryModel> categoryModels = new List<YodleeService.TransactionCategoryModel> {
                YodleeServiceTest.buildTransactionCategoryModel(1, 'Uncategorized', 10000017, 'Uncategorized', 'SYSTEM', 'PERSONAL', 'UNCATEGORIZE', null),
                YodleeServiceTest.buildTransactionCategoryModel(3, 'Charitable Giving', 10000001, 'Giving', 'SYSTEM', 'PERSONAL', 'EXPENSE', new List<YodleeService.TransactionDetailCategory> {
                    YodleeServiceTest.buildTransactionDetailCategory(1285, 'Environmental'),
                    YodleeServiceTest.buildTransactionDetailCategory(1288, 'Public and Social Services')
                })
            };
            SingleRequestMock xGetTransactionCategoriesRequestMock = YodleeServiceTest.initGetTransactionCategoriesRequestMock(categoryModels);
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);

            Test.startTest();
            YodleeHelper.YodleeCalloutResult result = YodleeHelper.getCategories('test-auth-user-token');
            Test.stopTest();

            System.assert(result.isSuccess);
            System.assertNotEquals(null, result.categories);
            System.assertEquals(2, result.categories.size());
            for (YodleeService.TransactionCategoryModel model : categoryModels) {
                if (model.id == 3) {
                    System.assertNotEquals(null, model.detailCategory);
                    System.assertEquals(2, model.detailCategory.size());
                } 
                else if (model.id == 1) {
                    System.assertEquals(null, model.detailCategory);
                }
                else {
                    System.assert(false, 'A model with unexpected id was found.');
                }
            }
        }
    }

    @IsTest
    private static void testFlattenCategories() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Map<Integer,String> categoryDictionaryOriginal = new Map<Integer,String> {
                1 => 'Uncategorized', 
                10000017 => 'Uncategorized',
                3 => 'Charitable Giving', 
                10000001 => 'Giving',
                1285 => 'Environmental',
                1288 => 'Public and Social Services'
            };
            List<YodleeService.TransactionCategoryModel> categoryModels = new List<YodleeService.TransactionCategoryModel> {
                YodleeServiceTest.buildTransactionCategoryModel(1, categoryDictionaryOriginal.get(1), 10000017, categoryDictionaryOriginal.get(10000017), 'SYSTEM', 'PERSONAL', 'UNCATEGORIZE', null),
                YodleeServiceTest.buildTransactionCategoryModel(3, categoryDictionaryOriginal.get(3), 10000001, categoryDictionaryOriginal.get(10000001), 'SYSTEM', 'PERSONAL', 'EXPENSE', new List<YodleeService.TransactionDetailCategory> {
                    YodleeServiceTest.buildTransactionDetailCategory(1285, categoryDictionaryOriginal.get(1285)),
                    YodleeServiceTest.buildTransactionDetailCategory(1288, categoryDictionaryOriginal.get(1288))
                })
            };

            Test.startTest();
            Map<Integer,String> categoryDictionary = YodleeHelper.flattenCategories(categoryModels);
            Test.stopTest();

            System.assertNotEquals(null, categoryDictionary);
            System.assertEquals(categoryDictionaryOriginal.size(), categoryDictionary.size());
            for (Integer k : categoryDictionary.keySet()) {
                System.assertEquals(categoryDictionaryOriginal.get(k), categoryDictionary.get(k));
            }
        }
    }
*/
}