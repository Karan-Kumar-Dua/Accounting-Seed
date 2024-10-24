@IsTest
public class AvaTaxServiceTest {

    @IsTest
    public static void testPing() {
        HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
        Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

        Test.startTest();
        AvaTaxService.PingResultModel pingResponse = AvaTaxService.ping();
        System.assertEquals(true, pingResponse.authenticated);
    }

    @IsTest
    public static void testListTransactionsByCompany() {
        SingleRequestMock xGetListTransactionByCompanyRequestMock = new SingleRequestMock(
            200,
            'Complete',
            getListTransactionByCompanyResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Test.setMock(HttpCalloutMock.class, xGetListTransactionByCompanyRequestMock);

        Test.startTest();
        AvaTaxService.FetchResultTransactionModel fetchResult =
            AvaTaxService.listTransactionsByCompany(
                'companyCode',
                new List<String>{'anyName'},
                Date.today().addDays(-60),
                Date.today(),
                AvaTaxService.DocumentStatus.Committed,
                new List<String>{'SummaryOnly'}
            );
        System.assertEquals(123456789, fetchResult.getTransactionList()[0].id);
    }

    @IsTest
    public static void testListTransactionsByCompanyUnderNonUsLocale() {
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User sysAdminUser = new User(
            alias = 'sysAdmin',
            email = 'sysAdmin.email@fakemail.com',
            emailencodingkey = 'UTF-8',
            lastname = 'SysAdmin',
            languagelocalekey = Userinfo.getLanguage(),
            localesidkey = 'de_DE',
            profileid = sysAdminProfile.Id,
            timezonesidkey = Userinfo.getTimeZone().getID(),
            Username = 'acctSeed.sysAdmin.username@as.acctseed.com' + DateTime.now().getTime()            
        );
        insert sysAdminUser;

        System.runAs(sysAdminUser) {
            SingleRequestMock xGetListTransactionByCompanyRequestMock = new SingleRequestMock(
                200,
                'Complete',
                getListTransactionByCompanyResponseBody(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xGetListTransactionByCompanyRequestMock);

            Test.startTest();
            AvaTaxService.FetchResultTransactionModel fetchResult =
                AvaTaxService.listTransactionsByCompany(
                    'companyCode',
                    new List<String>{'anyName'},
                    Date.today().addDays(-60),
                    Date.today(),
                    AvaTaxService.DocumentStatus.Committed,
                    new List<String>{'SummaryOnly'}
                );
            System.assertEquals(123456789, fetchResult.getTransactionList()[0].id);
        }
    }

    @IsTest
    public static void testResolveAddress() {
        HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
        Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

        Test.startTest();
        AvaTaxService.AddressResolutionModel addressResModel = AvaTaxService.resolveAddress(NULL);
        System.assertEquals('Some street', addressResModel.address.line1);
    }

    @IsTest
    public static void testCreateOrAdjustTransaction() {
        HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
        Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

        Test.startTest();
        AvaTaxService.TransactionModel transactionModel = AvaTaxService.createOrAdjustTransaction(NULL);
        System.assertEquals('AP-00000', transactionModel.code);
    }

    @IsTest
    public static void testCreateOrAdjustTransactionWhenLongAddress() {
        HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
        Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

        Test.startTest();
        AvaTaxService.CreateOrAdjustTransactionModel request = new AvaTaxService.CreateOrAdjustTransactionModel();
        AvaTaxService.CreateTransactionModel transactionModel = new AvaTaxService.CreateTransactionModel();
        AvaTaxService.AddressInfo address = new AvaTaxService.AddressInfo(
            'Long street address 0123456789, 0123456789, 0123456789, 0123456789, 0123456789',
            'New York',
            'NY',
            'US',
            '99856'
        );
        AvaTaxService.AddressesModel addressModel = new AvaTaxService.AddressesModel();
        addressModel.singleLocation = address;
        transactionModel.addresses = addressModel;
        request.createTransactionModel = transactionModel;
        System.assertEquals(50, request.createTransactionModel.addresses.singleLocation.line1.length());
        AvaTaxService.TransactionModel result = AvaTaxService.createOrAdjustTransaction(request);
        System.assertEquals('AP-00000', result.code);
    }

    @IsTest
    public static void testUncommitTransaction() {
        SingleRequestMock xPostUncommitTransactionRequestMock = new SingleRequestMock(
            200,
            'Complete',
            getUncommitTransactionResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Test.setMock(HttpCalloutMock.class, xPostUncommitTransactionRequestMock);

        Test.startTest();
        AvaTaxService.AvaTaxException avaTaxEx = NULL;
        try {
            AvaTaxService.uncommitTransaction('companyCode', 'transactionCode', 'accountId', 'licenseKey');
        }
        catch (AvaTaxService.AvaTaxException ex) {
            avaTaxEx = ex;
        }
        System.assertEquals(NULL, avaTaxEx);
    }

    //==========================================================================================================
    //================================ Create Multi-Response Generator =========================================
    //==========================================================================================================
    private static MultiRequestMock createResponseGenerators() {
        //======
        SingleRequestMock xGetPingRequestMock = new SingleRequestMock(
            200,
            'Complete',
            getPingResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        //======
        SingleRequestMock xPostResolveAddressRequestMock = new SingleRequestMock(
            200,
            'Complete',
            getResolveAddressResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        //======
        SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
            200,
            'Complete',
            getCreateTransactionResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======

        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(AvaTaxService.SERVICE_URL + '/api/v2/utilities/ping', xGetPingRequestMock);
        endpoint2TestResp.put(AvaTaxService.SERVICE_URL + '/api/v2/addresses/resolve', xPostResolveAddressRequestMock);
        endpoint2TestResp.put(AvaTaxService.SERVICE_URL + '/api/v2/transactions/createoradjust?$include=Lines', xPostCreateOrAdjustTransactionRequestMock);

        MultiRequestMock multiCalloutMockInstance = new MultiRequestMock(endpoint2TestResp);

        return multiCalloutMockInstance;
    }

    //==========================================================================================================
    //================================ JSON Response Bodies ====================================================
    //==========================================================================================================
    private static String getPingResponseBody() {
        AvaTaxService.PingResultModel pingResponse = new AvaTaxService.PingResultModel();
        pingResponse.version = '1.0.0.0';
        pingResponse.authenticated = true;
        pingResponse.authenticationType = 'AccountIdLicenseKey';
        pingResponse.authenticatedUserName = 'TestUser';
        pingResponse.authenticatedUserId = '98765';
        pingResponse.authenticatedAccountId = '123456789';
        pingResponse.crmid = '1111';

        return JSON.serialize(pingResponse);
    }

    private static String getListTransactionByCompanyResponseBody() {
        AvaTaxService.FetchResultTransactionModel result = new AvaTaxService.FetchResultTransactionModel();
        AvaTaxService.TransactionModel trans1 = new AvaTaxService.TransactionModel();
        trans1.id = 123456789;
        trans1.code = 'dcca7719-74ad-451e-b65f-55d242379c2f';
        trans1.companyId = 12345;
        trans1.avaTaxDate = Date.today();
        trans1.totalTax = 62.5;

        AvaTaxService.TransactionModel trans2 = new AvaTaxService.TransactionModel();
        trans2.id = 987654321;
        trans2.code = 'xxx-xxx-xxxx-xxxxx';
        trans2.companyId = 12345;
        trans2.avaTaxDate = Date.today();
        trans2.totalTax = 49.99;

        result.setValue(new List<AvaTaxService.TransactionModel>{trans1, trans2});
        return JSON.serialize(result);
    }

    private static String getResolveAddressResponseBody() {
        AvaTaxService.AddressResolutionModel result = new AvaTaxService.AddressResolutionModel();
        result.address = new AvaTaxService.AddressInfo();
        result.address.line1 = 'Some street';

        return JSON.serialize(result);
    }

    private static String getCreateTransactionResponseBody() {
        AvaTaxService.CreateTransactionModel trModel = new AvaTaxService.CreateTransactionModel();
        trModel.code = 'AP-00000';

        return JSON.serialize(trModel);
    }

    private static String getUncommitTransactionResponseBody() {
        AvaTaxService.TransactionModel trModel = new AvaTaxService.TransactionModel();
        trModel.id = 123456789;
        trModel.code = 'AP-00000';

        return JSON.serialize(trModel);
    }

}