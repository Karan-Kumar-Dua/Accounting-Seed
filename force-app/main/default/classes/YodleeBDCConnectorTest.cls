@isTest
public with sharing class YodleeBDCConnectorTest {
    
    private static String cleanJsonResponse(String json, Map<String,String> mpOfReplacerToReplace) {
        for(String key : mpOfReplacerToReplace.keySet()){ 
            json = json.replaceAll(key, mpOfReplacerToReplace.get(key));
        }
        return json;
    }
    
    @isTest
    public static void getAccountsFromFinancialInstitutionIdentitiesFailTest() {
        List<HTTPResponse> responses;
        try{
            Test.startTest();
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            BDCFinancialInstitutionIdentity bfc = new BDCFinancialInstitutionIdentity();
            bfc.id = '16441';
            
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            responses = yodleeConnect.getAccountsFromFinancialInstitutionIdentities(new List<BDCFinancialInstitutionIdentity>{bfc});
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getAccountsFromFinancialInstitutionIdentitiesTest() {
        SingleRequestMock xDeleteProviderAccountsRequestMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.ACCOUNTS_FROM_FID_TEST_JSON ,
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xDeleteProviderAccountsRequestMock);
        
        BDCFinancialInstitutionIdentity bfc = new BDCFinancialInstitutionIdentity();
        bfc.id = '16441';
        Test.startTest();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        List<HTTPResponse> resp = yodleeConnect.getAccountsFromFinancialInstitutionIdentities(new List<BDCFinancialInstitutionIdentity>{bfc});
        Test.stopTest();
        
        AbstractBDCRouter router = new YodleeBDCRouter();
        List<BDCAccount> bdcAccounts = new List<BDCAccount>(router.getConverter().convertAccounts(resp).data.bdcAccounts);
        System.assertEquals(resp[0].getStatusCode() == 200 , true);
        System.assertEquals(resp[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(resp[0].getBody()) , true);
        System.assertEquals(bdcAccounts[0].financialInstitutionIdentity, '21759841');
        System.assertEquals(bdcAccounts[0].name, 'Dag Saving Plus');
        System.assertEquals(bdcAccounts[0].accountNumber, '4197');
        System.assertEquals(bdcAccounts[0].id, '29462280');
        System.assertEquals(bdcAccounts[0].accountType, 'SAVINGS');

        System.assertEquals(bdcAccounts[1].name, 'Dag Fixed Term Deposit');
        System.assertEquals(bdcAccounts[1].accountNumber, '88108044789881');
        System.assertEquals(bdcAccounts[1].id, '29462279');
        System.assertEquals(bdcAccounts[1].accountType, 'CD');
        
        System.assertEquals(bdcAccounts[2].name, 'Dag Checking Account');
        System.assertEquals(bdcAccounts[2].accountNumber, '2345');
        System.assertEquals(bdcAccounts[2].id, '29462278');
        System.assertEquals(bdcAccounts[2].accountType, 'CHECKING');
        
        System.assertEquals(bdcAccounts[3].name, 'Dag Checking Account1');
        System.assertEquals(bdcAccounts[3].accountNumber, '23456');
        System.assertEquals(bdcAccounts[3].id, '29462270');
        System.assertEquals(bdcAccounts[3].accountType, 'SAVING');
    }
    
    @isTest
    public static void getFinancialInstitutionsIdFailTest() {
        List<HTTPResponse> responses;
        try{
            Test.startTest();
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            
            BDCServiceOptions options = new BDCServiceOptions();
            BDCDataModel model =  BDCMocker.testBDCDataModel();
            options.bdcFinancialInstitutionIdentities = model.bdcFinancialInstitutionIdentities;
            
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            responses = yodleeConnect.getFinancialInstitution('16441');
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getFinancialInstitutionsIdTest() {
        SingleRequestMock xDeleteProviderAccountsRequestMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_ID_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xDeleteProviderAccountsRequestMock);
        
        Test.startTest();
        BDCServiceOptions options = new BDCServiceOptions();
        BDCDataModel model =  BDCMocker.testBDCDataModel();
        options.bdcFinancialInstitutionIdentities = model.bdcFinancialInstitutionIdentities;
        
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        List<HTTPResponse> resp = yodleeConnect.getFinancialInstitution('16441');
        Test.stopTest();
        
        AbstractBDCRouter router = new YodleeBDCRouter();
        List<BDCFinancialInstitution> financialInstitutions = new List<BDCFinancialInstitution>();
        financialInstitutions = router.getConverter().convertFinancialInstitutions(resp).data.bdcFinancialInstitutions;
        
        System.assertEquals(resp[0].getStatusCode() == 200 , true);
        System.assertEquals(resp[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(resp[0].getBody()) , true);
        System.assertEquals(financialInstitutions[0].Name, 'AS Financial Inst');
        System.assertEquals(financialInstitutions[0].id, '16441');
        
        System.assertEquals(financialInstitutions[1].Name, 'AS Financial Inst1');
        System.assertEquals(financialInstitutions[1].id, '16441');
        
        System.assertEquals(financialInstitutions[2].Name, 'AS Financial Inst2');
        System.assertEquals(financialInstitutions[2].id, '16441');
    }
    
    @isTest
    public static void getFinancialInstitutionsFailTest() {
        List<HTTPResponse> responses;
        try{
            Test.startTest();
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            
            BDCServiceOptions options = new BDCServiceOptions();
            BDCDataModel model =  BDCMocker.testBDCDataModel();
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            options.bdcFinancialInstitutionIdentities = model.bdcFinancialInstitutionIdentities;
            responses = yodleeConnect.getFinancialInstitutions(options.bdcFinancialInstitutionIdentities);
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getFinancialInstitutionsTest() {
        SingleRequestMock xDeleteProviderAccountsRequestMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xDeleteProviderAccountsRequestMock);
        
        Test.startTest();
        BDCServiceOptions options = new BDCServiceOptions();
        BDCDataModel model =  BDCMocker.testBDCDataModel();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        options.bdcFinancialInstitutionIdentities = model.bdcFinancialInstitutionIdentities;
        List<HTTPResponse> resp = yodleeConnect.getFinancialInstitutions(options.bdcFinancialInstitutionIdentities);
        Test.stopTest();
        
        AbstractBDCRouter router = new YodleeBDCRouter();
        List<BDCFinancialInstitution> financialInstitutions = new List<BDCFinancialInstitution>();
        financialInstitutions = router.getConverter().convertFinancialInstitutions(resp).data.bdcFinancialInstitutions;
        
        System.assertEquals(resp[0].getStatusCode() == 200 , true);
        System.assertEquals(resp[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(resp[0].getBody()) , true);
        System.assertEquals(financialInstitutions[0].Name,  'AS Financial Inst');
        System.assertEquals(financialInstitutions[0].id,  '16441');
        
        System.assertEquals(financialInstitutions[1].Name,  'AS Financial Inst1');
        System.assertEquals(financialInstitutions[1].id,  '16442');
        
        System.assertEquals(financialInstitutions[2].Name,  'AS Financial Inst2');
        System.assertEquals(financialInstitutions[2].id,  '16443');
        
        System.assertEquals(financialInstitutions[3].Name,  'AS Financial Inst3');
        System.assertEquals(financialInstitutions[3].id,  '16444');
    }
    
    @isTest
    public static void getTransactionsCountFailTest() {
        List<HTTPResponse> responses;
        try{
            Test.startTest();
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            responses = yodleeConnect.getTransactionsCount(System.Date.today().addDays(-90), System.Date.today(), new List<String>{});
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getTransactionsCountTest() {
        YodleeService.TransactionsCountResponse transCount = new YodleeService.TransactionsCountResponse();
        YodleeService.TransactionsTotal total = new YodleeService.TransactionsTotal(4);
        YodleeService.TransactionModel trnasModel = new YodleeService.TransactionModel();
        trnasModel.accountId = '123456';
        trnasModel.container =  'Credit';
        trnasModel.baseType = 'Account';
        trnasModel.yodleeDate = System.today();   
        trnasModel.status = 'SUCCESS';
        trnasModel.TOTAL = total;
        transCount.yodleeTransaction = trnasModel;
        
        SingleRequestMock xDeleteProviderAccountsRequestMock = new SingleRequestMock(
            200,
            'Complete',
            System.JSON.serializePretty(transCount),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xDeleteProviderAccountsRequestMock);
        
        Test.startTest();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        List<HttpResponse> responses = yodleeConnect.getTransactionsCount(System.Date.today().addDays(-90), System.Date.today(), new List<String>{'123456'});
        Test.stopTest();
        
        YodleeBDCConverter yodleeConvert = new YodleeBDCConverter();
        integer transactionCount = 0;
        transactionCount = yodleeConvert.convertTransactionCount(responses);
        System.assertEquals(responses[0].getStatusCode(), 200);
        System.assertEquals(responses[0].getStatus(), 'Complete');

        System.assertEquals(transactionCount, 4);
    }
    
    @isTest
    public static void getdeleteFinancialInstitutionIdentityFailTest() {
        try{
            TestDataSuite testData = TestDataSuite.getInstance(true);
            
            GL_Account_Mapping__c glam = new GL_Account_Mapping__c (
                External_Id__c = '1',
                GL_Account__c = testData.glAccounts[0].Id,
                Ledger__c = testData.ledgers[0].Id,
                Financial_Institution__c = 'Provider1',
                Financial_Institution_Id__c = '111',
                Initial_Start_Date__c = Date.today(),
                Source__c = 'Yodlee'
            );
            insert glam; 
            
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            
            System.runAs(testData.users[1]) {
                Test.startTest();
                BDCFinancialInstitutionIdentity bfc = new BDCFinancialInstitutionIdentity();
                bfc.id = glam.Financial_Institution_Id__c;
                YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
                yodleeConnect.deleteFinancialInstitutionIdentity(bfc);
                
                List<GL_Account_Mapping__c> glams = [
                    SELECT External_Id__c,
                    GL_Account__c,
                    Ledger__c,
                    Financial_Institution__c,
                    Financial_Institution_Id__c,
                    Initial_Start_Date__c,
                    Inactive__c
                    FROM GL_Account_Mapping__c
                ];
                System.assertEquals(false, glams[0].Inactive__c); //inactive should false becoz this glam is not deleted due to integration issue
            }
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
        }
    }
    
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
            Source__c = 'Yodlee'
        );
        insert glam; 
        
        SingleRequestMock xDeleteProviderAccountsRequestMock = new SingleRequestMock(
            200,
            'Complete',
            '',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xDeleteProviderAccountsRequestMock);
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            BDCFinancialInstitutionIdentity bfc = new BDCFinancialInstitutionIdentity();
            bfc.id = glam.Financial_Institution_Id__c;
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            yodleeConnect.deleteFinancialInstitutionIdentity(bfc);
            
            List<GL_Account_Mapping__c> glams = [
                SELECT External_Id__c,
                GL_Account__c,
                Ledger__c,
                Financial_Institution__c,
                Financial_Institution_Id__c,
                Initial_Start_Date__c,
                Inactive__c
                FROM GL_Account_Mapping__c
            ];
            System.assertEquals(true, glams[0].Inactive__c);
        }
    }
    
    @isTest
    public static void getFinancialInstitutionIdentitiesFailTest() {
        List<HttpResponse> responses;
        try{
            Test.startTest();
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            responses = yodleeConnect.getFinancialInstitutionIdentities();
            Test.stopTest();
        } 
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getFinancialInstitutionIdentitiesStatusFailedTest() {
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_STATUS_FAILED_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
        
        Test.startTest();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        List<HttpResponse> responses = yodleeConnect.getFinancialInstitutionIdentities();
        Test.stopTest();
        
        AbstractBDCRouter router = new YodleeBDCRouter();
        List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>();
        financialInstitutionIdentities = router.getConverter().convertFinancialInstitutionIdentities(responses).data.bdcFinancialInstitutionIdentities;
        
        System.assertEquals(responses[0].getStatusCode() == 200 , true);
        System.assertEquals(responses[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
        System.assertEquals(financialInstitutionIdentities[0].financialInstitutionId , '16441');
        System.assertEquals(financialInstitutionIdentities[0].id , '21769933');
        System.assertEquals(financialInstitutionIdentities[0].status , 'FAILED');

        System.assertEquals(financialInstitutionIdentities[1].financialInstitutionId , '16441');
        System.assertEquals(financialInstitutionIdentities[1].id , '21759841');
    }
    
    @isTest
    public static void getFinancialInstitutionIdentitiesTest() {
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
        
        Test.startTest();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        List<HttpResponse> responses = yodleeConnect.getFinancialInstitutionIdentities();
        Test.stopTest();
        
        AbstractBDCRouter router = new YodleeBDCRouter();
        List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>();
        financialInstitutionIdentities = router.getConverter().convertFinancialInstitutionIdentities(responses).data.bdcFinancialInstitutionIdentities;
        
        System.assertEquals(responses[0].getStatusCode() == 200 , true);
        System.assertEquals(responses[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
        System.assertEquals(financialInstitutionIdentities[0].financialInstitutionId , '16441');
        System.assertEquals(financialInstitutionIdentities[0].id , '21769933');
        System.assertEquals(financialInstitutionIdentities[0].status , 'USER_INPUT_REQUIRED');
        
        System.assertEquals(financialInstitutionIdentities[1].financialInstitutionId , '16441');
        System.assertEquals(financialInstitutionIdentities[1].id , '21759841');
        
        System.assertEquals(financialInstitutionIdentities[2].id , '21759844');
        System.assertEquals(financialInstitutionIdentities[2].status , 'FAILED');
        System.assertEquals(financialInstitutionIdentities[2].financialInstitutionId , '25789');
    }
    
    @isTest
    public static void getTransactionsFailTest() {
        List<HttpResponse> responses;
        try{
            Test.startTest();
            BDCServiceOptions options = new BDCServiceOptions();
            options.fromDate = System.Date.today().addDays(-90);
            options.toDate = System.Date.today();
            options.bdcAccountIds = new List<String>{'123456'}; 
                YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            options.offset = 5;
            options.maxRecords = 10;

            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            
            Map<String, String> mpOfReplacerToReplace = new Map<String,String>();
            mpOfReplacerToReplace.put('"transaction":','"yodleeTransaction":');
            mpOfReplacerToReplace.put('"date":','"yodleeDate":');
            mpOfReplacerToReplace.put('"currency":','"yodleeCurrency":');
            
   
            responses = yodleeConnect.getTransactions(options);
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getTransactionsTest() {
        Test.startTest();
        BDCServiceOptions options = new BDCServiceOptions();
        options.fromDate = System.Date.today().addDays(-90);
        options.toDate = System.Date.today();
        options.bdcAccountIds = new List<String>{'123456'};
        options.offset = 5;
        options.maxRecords = 10;
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                200,
                'Complete',
                YodleeBDCTest.TRANSACTION_TEST_JSON , 
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        
        Map<String, String> mpOfReplacerToReplace = new Map<String,String>();
        mpOfReplacerToReplace.put('"transaction":','"yodleeTransaction":');
        mpOfReplacerToReplace.put('"date":','"yodleeDate":');
        mpOfReplacerToReplace.put('"currency":','"yodleeCurrency":');
        
        List<HttpResponse> responses = yodleeConnect.getTransactions(options);
        
        AbstractBDCRouter router = new YodleeBDCRouter();
        List<BDCTransaction> convertedTransactions = new List<BDCTransaction>();
        convertedTransactions = router.getConverter().convertTransactions(responses).data.bdcTransactions;
        Test.stopTest();
        
        System.assertEquals(responses[0].getStatusCode() == 200 , true);
        System.assertEquals(responses[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
        System.assertEquals(5, convertedTransactions.size());
        System.assertEquals(convertedTransactions[0].accountId , '12345678');
        System.assertEquals(convertedTransactions[0].baseType , 'Credit');
        System.assertEquals(convertedTransactions[0].id , '11111111');
        System.assertEquals(convertedTransactions[0].categoryId , null);
        System.assertEquals(convertedTransactions[0].status , 'POSTED');
        System.assertEquals(convertedTransactions[0].transactionDate , Date.newInstance(2022, 7, 31));
        
        System.assertEquals(convertedTransactions[1].accountId , '12345678');
        System.assertEquals(convertedTransactions[1].baseType , 'Debit');
        System.assertEquals(convertedTransactions[1].id , '22222222');
        System.assertEquals(convertedTransactions[1].categoryId , null);
        System.assertEquals(convertedTransactions[1].status , 'POSTED');
        System.assertEquals(convertedTransactions[1].transactionDate , Date.newInstance(2022, 7, 30));
        
        System.assertEquals(convertedTransactions[2].accountId , '123456789001');
        System.assertEquals(convertedTransactions[2].baseType , 'Mastercard');
        System.assertEquals(convertedTransactions[2].id , '33333333');
        System.assertEquals(convertedTransactions[2].categoryId , null);
        System.assertEquals(convertedTransactions[2].status , 'POSTED');
        System.assertEquals(convertedTransactions[2].transactionDate , Date.newInstance(2022, 7, 30));
        
        System.assertEquals(convertedTransactions[3].accountId , '123456789');
        System.assertEquals(convertedTransactions[3].baseType , 'platinum');
        System.assertEquals(convertedTransactions[3].id , '44444444');
        System.assertEquals(convertedTransactions[3].categoryId , null);
        System.assertEquals(convertedTransactions[3].status , 'POSTED');
        System.assertEquals(convertedTransactions[3].transactionDate , Date.newInstance(2022, 7, 30));

        System.assertEquals(convertedTransactions[4].accountId , '123456789');
        System.assertEquals(convertedTransactions[4].baseType , 'platinum');
        System.assertEquals(convertedTransactions[4].id , '55555555');
        System.assertEquals(convertedTransactions[4].categoryId , null);
        System.assertEquals(convertedTransactions[4].status , 'POSTED');
        System.assertEquals(convertedTransactions[4].transactionDate , Date.newInstance(2022, 7, 30));
    }
    
    @isTest
    public static void getAccountsFailTest() {
        List<HttpResponse> responses;
        try{
            Test.startTest();
            //mock data model
            BDCDataModel model = BDCMocker.testBDCDataModel();        
            //get acct Ids
            List < String > acctIds = new List < String > ();
            for (BDCAccount acct: model.bdcAccounts) {
                acctIds.add(acct.id);
            }
            
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'fail',
                JSON.serializePretty(yError) ,
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);
            
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            responses = yodleeConnect.getAccounts(acctIds);
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getAccountstest() {
        //mock data model
        BDCDataModel model = BDCMocker.testBDCDataModel();        
        //get acct Ids
        List < String > acctIds = new List < String > ();
        for (BDCAccount acct: model.bdcAccounts) {
            acctIds.add(acct.id);
        }
        
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.ACCOUNT_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);
        
        Test.startTest();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        List<HttpResponse> responses = yodleeConnect.getAccounts(acctIds);
        Test.stopTest();
        
        AbstractBDCRouter router = new YodleeBDCRouter();
        List<BDCAccount> bdcAccounts = new List<BDCAccount>();
        bdcAccounts = router.getConverter().convertAccounts(responses).data.bdcAccounts;
        
        System.assertEquals(responses[0].getStatusCode() == 200 , true);
        System.assertEquals(responses[0].getStatus() == 'Complete' , true);
        System.assertEquals(String.isNotBlank(responses[0].getBody()) , true);
        System.assertEquals(bdcAccounts[0].name , 'Dag Checking Account');
        System.assertEquals(bdcAccounts[0].financialInstitutionIdentity, '21769933');
        System.assertEquals(bdcAccounts[0].accountNumber, '2345');
        
        System.assertEquals(bdcAccounts[1].name, 'Dag Saving Plus');
        System.assertEquals(bdcAccounts[1].financialInstitutionIdentity, '21759841');
        System.assertEquals(bdcAccounts[1].accountNumber, '4197');  
        
        System.assertEquals(bdcAccounts[2].name, 'Dag Fixed Term Deposit');
        System.assertEquals(bdcAccounts[2].financialInstitutionIdentity, '21759841');
        System.assertEquals(bdcAccounts[2].accountNumber, '88108044789881');  
        
        System.assertEquals(bdcAccounts[3].name, 'Dag Checking Account');
        System.assertEquals(bdcAccounts[3].financialInstitutionIdentity, '21759841');
        System.assertEquals(bdcAccounts[3].accountNumber, '2345');  
        
    }
    
    @isTest
    public static void registerUserFailTest() {
        List<HttpResponse> responses ;
        try{
            Test.startTest();
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'Fail',
                JSON.serializePretty(yError),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            BDCServiceResult result = yodleeConnect.registerUser();
            Test.stopTest();

            System.assertEquals(FALSE, result.isSuccess);
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
           
        }
    }
    
    @isTest
    public static void registerUserTest() {
        YodleeBDCConnector.UserPayload userPayload = new YodleeBDCConnector.UserPayload();
        userPayload.user = new YodleeBDCConnector.UserModel();
        userPayload.user.loginName = 'asyd' + UserInfo.getOrganizationId();
        userPayload.user.email = 'asyd' + UserInfo.getOrganizationId() + '@as.com';
        userPayload.user.preferences = new YodleeBDCConnector.PreferencesModel();
        userPayload.user.preferences.locale = UserInfo.getLocale();
        userPayload.user.preferences.timeZone = UserInfo.getTimeZone().getId();
        userPayload.user.preferences.currencyCode = MultiCurrencyHandler.CORPORATE_CURRENCY;
        
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            JSON.serializePretty(userPayload),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);
        
        Test.startTest();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        BDCServiceResult result = yodleeConnect.registerUser();
        Test.stopTest();
        
        System.assertEquals(TRUE, result.isSuccess); 
      
    }
    
    @isTest
    public static void getCategoriesFailTest() {
        List<HttpResponse> responses;
        try{
            YodleeBDCConnector.YodleeError yError = new YodleeBDCConnector.YodleeError();
            yError.errorCode = '400';
            yError.errorMessage = 'Bad Request';
            yError.referenceCode = '400';
            SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
                400,
                'Fail',
                JSON.serializePretty(yError),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock); 
            Test.startTest();
            YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
            responses = yodleeConnect.getCategories();
            Test.stopTest();
        }
        catch(Exception ex){
            System.assertEquals('Bad Request', ex.getMessage());
            System.assertEquals(responses == null, TRUE);
        }
    }
    
    @isTest
    public static void getCategoriesTest() {
        List<YodleeService.TransactionCategoryModel> lstOftransactionCatagoryModel = new List<YodleeService.TransactionCategoryModel>();
        
        YodleeService.TransactionCategoriesResponse transactionCatagories = new YodleeService.TransactionCategoriesResponse();
        YodleeService.TransactionCategoryModel transactionCatagoryModel = new YodleeService.TransactionCategoryModel();
        transactionCatagoryModel.category = 'test';
        transactionCatagoryModel.source = 'testing';
        transactionCatagoryModel.highLevelCategoryId = 1234567890;
        transactionCatagoryModel.highLevelCategoryName = 'Test Debit';
        transactionCatagoryModel.type = 'Catagory';
        
        YodleeService.TransactionCategoryModel transactionCatagoryModel1 = new YodleeService.TransactionCategoryModel();
        transactionCatagoryModel1.category = 'test1';
        transactionCatagoryModel1.source = 'testing1';
        transactionCatagoryModel1.highLevelCategoryId = 1234567891;
        transactionCatagoryModel1.highLevelCategoryName = 'Test Debit1';
        transactionCatagoryModel1.type = 'Catagory1';
        
        YodleeService.TransactionCategoryModel transactionCatagoryModel2 = new YodleeService.TransactionCategoryModel();
        transactionCatagoryModel2.category = 'test2';
        transactionCatagoryModel2.source = 'testing2';
        transactionCatagoryModel2.highLevelCategoryId = 1234567892;
        transactionCatagoryModel2.highLevelCategoryName = 'Test Debit2';
        transactionCatagoryModel2.type = 'Catagory2';
        lstOftransactionCatagoryModel.add(transactionCatagoryModel);
        lstOftransactionCatagoryModel.add(transactionCatagoryModel1);
        lstOftransactionCatagoryModel.add(transactionCatagoryModel2);
        
        transactionCatagories.transactionCategory = lstOftransactionCatagoryModel;
        
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            System.JSON.serialize(transactionCatagories),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);
        
        Test.startTest();
        YodleeBDCConnector yodleeConnect = new YodleeBDCConnector();
        List<HttpResponse> responses = yodleeConnect.getCategories();
        AbstractBDCConverter convertor = new YodleeBDCConverter();
        List<BDCCategory> bdcCatagories = convertor.convertCategories(responses).data.bdcCategories.values();
        Test.stopTest();
        
        System.assertEquals(responses != null, TRUE);
        System.assertEquals(responses.size() == 1, TRUE);
        System.assertEquals(responses[0].getStatus() == 'Complete', TRUE);
        System.assertEquals(responses[0].getStatusCode() == 200, TRUE);
        System.assertEquals(bdcCatagories[0].name, 'Test Debit');
        System.assertEquals(bdcCatagories[0].source, 'testing');
        
        System.assertEquals(bdcCatagories[1].name, 'test2');
        System.assertEquals(bdcCatagories[1].source, 'testing2');
        
        System.assertEquals(bdcCatagories[2].name, 'Test Debit1');
        System.assertEquals(bdcCatagories[2].source, 'testing1');
    }
    
    @isTest
    public static void getAuthtokenTest() {
        Test.startTest();
        String authToken = YodleeBDCConnector.getAuthToken();
        Test.stopTest();
        
        System.assertEquals(String.isNotBlank(authToken), TRUE);
    }
    
    @isTest
    public static void getUsertokenTest() {
        Test.startTest();
        String Token = YodleeBDCConnector.getuserToken();
        Test.stopTest();
        
        System.assertEquals(String.isNotBlank(Token), TRUE);
        
    }
    
    @isTest
    public static void getAuthtokenExpiredTest() {
        Test.startTest();
        Boolean isAuthExpired = YodleeBDCConnector.isAuthTokenExpired();
        Test.stopTest();
        
        System.assertEquals(isAuthExpired, true);
    }
    
    @isTest
    public static void isUserTokenExpiredTest() {
        Test.startTest();
        Boolean isExpired = YodleeBDCConnector.isUserTokenExpired();
        Test.stopTest();
        
        System.assertEquals(isExpired, false);
    }
    
}