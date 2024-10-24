@isTest
private class BankSettingsHelperTest {

    
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
        Test.stoptest();
    }

    
    @isTest
    private static void testDeleteFinancialInstitutionIdentity() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            '',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 

        System.runAs(testData.users[1]) {
            Test.startTest();
            BDCDataModel model =  BDCMocker.testBDCDataModel();
            BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.deleteFinancialInstitutionIdentity('Yodlee', model.bdcFinancialInstitutionIdentities[0].id);
            Test.stopTest();
        
            System.assertEquals(saveData != NULL, TRUE);
            System.assertEquals(saveData.isSuccess, TRUE);
            System.assertEquals(saveData.errors == NULL, TRUE);
        }
    }

    @isTest
    private static void testFailDeleteFinancialInstitutionIdentity() {
        Test.startTest();
        BDC_Binding__c yodleeBinding = [Select id, Is_Active__c from BDC_Binding__c where Name = 'Yodlee' LIMIT 1];
        yodleeBinding.Is_active__c = false;
        update yodleeBinding;

        BDCDataModel model =  BDCMocker.testBDCDataModel();
        BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.deleteFinancialInstitutionIdentity('Yodlee', model.bdcFinancialInstitutionIdentities[0].id);
        Test.stopTest();

        System.assertEquals(saveData != NULL, TRUE);
        System.assertEquals(saveData.isSuccess, false);
        System.assertEquals(saveData.errors == NULL, false);
    }
    
    @isTest
    private static void testPlaidDeleteFinancialInstitutionIdentity() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
            200,
            'Complete',
            '1234567890',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 

        System.runAs(testData.users[1]) {
            Test.startTest();
            BDCDataModel model =  BDCMocker.testBDCDataModel();
            BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.deleteFinancialInstitutionIdentity('Plaid', model.bdcFinancialInstitutionIdentities[0].id);
            Test.stopTest();
        
            System.assertEquals(saveData != NULL, TRUE);
            System.assertEquals(saveData.isSuccess, TRUE);
            System.assertEquals(saveData.errors == NULL, TRUE);
        }
    }

    @isTest
    private static void testPlaidFailDeleteFinancialInstitutionIdentity() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            BDC_Binding__c plaidBinding = [Select id, Is_Active__c from BDC_Binding__c where Name = 'Plaid' LIMIT 1];
            plaidBinding.Is_active__c = false;
            update plaidBinding;

            BDCDataModel model =  BDCMocker.testBDCDataModel();
            BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.deleteFinancialInstitutionIdentity('Plaid', model.bdcFinancialInstitutionIdentities[0].financialInstitutionId);
            Test.stopTest();
            
            System.assertEquals(saveData != NULL, TRUE);
            System.assertEquals(saveData.isSuccess, false);
            System.assertEquals(saveData.errors == NULL, false);
        }
    }

    @isTest
    private static void testPlaidServiceFailedDeleteFinancialInstitutionIdentity() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        SingleRequestMock xGetFinancialInstitutionIdentitiesRequestMock = new SingleRequestMock(
            400,
            'fail',
            '',
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetFinancialInstitutionIdentitiesRequestMock); 

        System.runAs(testData.users[1]) {
            Test.startTest();
            BDCDataModel model =  BDCMocker.testBDCDataModel();
            BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.deleteFinancialInstitutionIdentity('Plaid', model.bdcFinancialInstitutionIdentities[0].id);
            Test.stopTest();
    
            System.assertEquals(saveData != NULL, TRUE);
            System.assertEquals(saveData.isSuccess, false);
            System.assertEquals(saveData.errors == NULL, false);
        }
    }

    @isTest
    private static void testPlaidRegisterProviders() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            BDC_Binding__c plaidBinding = [Select id, Is_Active__c, Name from BDC_Binding__c where Name = 'Plaid' LIMIT 1];

            BankSettingsHelper.providersResponse providerData = new BankSettingsHelper.providersResponse();
            providerData.registerProvider = true;
            providerData.deRegisterProvider = false;
            providerData.binding = plaidBinding;

            List<BankSettingsHelper.providersResponse> lstProviderResp = new List<BankSettingsHelper.providersResponse>();
            lstProviderResp.add(providerData);
            
            String response = (String) BankSettingsHelper.registerDeregisterProviders(JSON.serialize(lstProviderResp));
            BankSettingsHelper.ResponseData returnedData = (BankSettingsHelper.ResponseData) JSON.deserialize(response, BankSettingsHelper.ResponseData.class);
            Test.stopTest();

            System.assertEquals(returnedData != NULL, TRUE);
            System.assertEquals(returnedData.isSuccess, TRUE);
            System.assertEquals(returnedData.serviceFaultProviders.size()==0, TRUE);
            System.assertEquals(String.IsBlank(returnedData.faultMessage), TRUE);
        }
    }

    @isTest
    private static void testPlaidDeregisterProviders() {

        TestDataSuite testData = TestDataSuite.getInstance(true);
        
        System.runAs(testData.users[1]) {
        Test.startTest();
        
        GL_Account_Mapping__c glam = new GL_Account_Mapping__c (
            External_Id__c = '1',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'Provider1',
            Financial_Institution_Id__c = '111',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Plaid',
            Inactive__c = false
        );
        insert glam; 

        BDC_Binding__c plaidBinding = [Select id, Is_Active__c, Name from BDC_Binding__c where Name = 'Plaid' LIMIT 1];

        BankSettingsHelper.providersResponse providerData = new BankSettingsHelper.providersResponse();
        providerData.registerProvider = false;
        providerData.deRegisterProvider = True;
        providerData.binding = plaidBinding;

        List<BankSettingsHelper.providersResponse> lstProviderResp = new List<BankSettingsHelper.providersResponse>();
        lstProviderResp.add(providerData);
        
        String response = (String) BankSettingsHelper.registerDeregisterProviders(JSON.serialize(lstProviderResp));
        BankSettingsHelper.ResponseData returnedData = (BankSettingsHelper.ResponseData) JSON.deserialize(response, BankSettingsHelper.ResponseData.class);

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
        Test.stopTest();

        System.assertEquals(returnedData != NULL, TRUE);
        System.assertEquals(returnedData.isSuccess, TRUE);
        System.assertEquals(returnedData.serviceFaultProviders.size()==0, TRUE);
        System.assertEquals(String.IsBlank(returnedData.faultMessage), TRUE);
         // assert before deregister of provider
        System.assertEquals(glam.Inactive__c, false);
        System.assertEquals(glam.Source__c == 'Plaid', TRUE);
        // assert after deregister of provider
        System.assertEquals(glams[0].Inactive__c, TRUE);
      }
    }

    @isTest
    private static void testYodleeDeregisterProviders() {

        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
        Test.startTest();

        GL_Account_Mapping__c glam = new GL_Account_Mapping__c (
            External_Id__c = '1',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'Provider1',
            Financial_Institution_Id__c = '111',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Yodlee',
            Inactive__c = false
        );
        insert glam; 

        BDC_Binding__c plaidBinding = [Select id, Is_Active__c, Name from BDC_Binding__c where Name = 'Yodlee' LIMIT 1];

        BankSettingsHelper.providersResponse providerData = new BankSettingsHelper.providersResponse();
        providerData.registerProvider = false;
        providerData.deRegisterProvider = True;
        providerData.binding = plaidBinding;

        List<BankSettingsHelper.providersResponse> lstProviderResp = new List<BankSettingsHelper.providersResponse>();
        lstProviderResp.add(providerData);
        
        String response = (String) BankSettingsHelper.registerDeregisterProviders(JSON.serialize(lstProviderResp));
        BankSettingsHelper.ResponseData returnedData = (BankSettingsHelper.ResponseData) JSON.deserialize(response, BankSettingsHelper.ResponseData.class);

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
        Test.stopTest();

        System.assertEquals(returnedData != NULL, TRUE);
        System.assertEquals(returnedData.isSuccess, TRUE);
        System.assertEquals(returnedData.serviceFaultProviders.size()==0, TRUE);
        System.assertEquals(String.IsBlank(returnedData.faultMessage), TRUE);
         // assert before deregister of provider
        System.assertEquals(glam.Inactive__c, false);
        System.assertEquals(glam.Source__c == 'Yodlee', TRUE);
        // assert after deregister of provider
        System.assertEquals(glams[0].Inactive__c, TRUE);
      }
    }

    @isTest
    private static void testYodleeRegisterProviders() {
        YodleeBDCConnector.UserPayload userPayload = new YodleeBDCConnector.UserPayload();
        userPayload.user = new YodleeBDCConnector.UserModel();
        userPayload.user.loginName = 'xyz' + UserInfo.getOrganizationId();
        userPayload.user.email = 'test' + UserInfo.getOrganizationId() + '@test.com';
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
        BDC_Binding__c YodleeBinding = [Select id, Is_Active__c, Name from BDC_Binding__c where Name = 'Yodlee' LIMIT 1];
        
        BankSettingsHelper.providersResponse providerData = new BankSettingsHelper.providersResponse();
        providerData.registerProvider = true;
        providerData.deRegisterProvider = false;
        providerData.binding = YodleeBinding;

        List<BankSettingsHelper.providersResponse> lstProviderResp = new List<BankSettingsHelper.providersResponse>();
        lstProviderResp.add(providerData);
    
        String response = (String) BankSettingsHelper.registerDeregisterProviders(JSON.serialize(lstProviderResp));
        
        BankSettingsHelper.ResponseData returnedData = (BankSettingsHelper.ResponseData) JSON.deserialize(response, BankSettingsHelper.ResponseData.class);
        Test.stopTest();

        System.assertEquals(returnedData != NULL, TRUE);
        System.assertEquals(returnedData.isSuccess, TRUE);
        System.assertEquals(returnedData.serviceFaultProviders.size()==0, TRUE);
        System.assertEquals(String.IsBlank(returnedData.faultMessage), TRUE);
    }

    @isTest
    private static void testFailYodleeRegisterProviders() {
        YodleeBDCConnector.UserPayload userPayload = new YodleeBDCConnector.UserPayload();
        userPayload.user = new YodleeBDCConnector.UserModel();
        userPayload.user.loginName = 'xyz' + UserInfo.getOrganizationId();
        userPayload.user.email = 'test' + UserInfo.getOrganizationId() + '@test.com';
        userPayload.user.preferences = new YodleeBDCConnector.PreferencesModel();
        userPayload.user.preferences.locale = UserInfo.getLocale();
        userPayload.user.preferences.timeZone = UserInfo.getTimeZone().getId();
        userPayload.user.preferences.currencyCode = MultiCurrencyHandler.CORPORATE_CURRENCY;
        
        SingleRequestMock xGetTransactionCategoriesRequestMock = new SingleRequestMock(
            400,
            'fail',
            JSON.serializePretty(userPayload),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Test.setMock(HttpCalloutMock.class, xGetTransactionCategoriesRequestMock);

        Test.startTest();
        BDC_Binding__c YodleeBinding = [Select id, Is_Active__c, Name from BDC_Binding__c where Name = 'Yodlee' LIMIT 1];
        
        BankSettingsHelper.providersResponse providerData = new BankSettingsHelper.providersResponse();
        providerData.registerProvider = true;
        providerData.deRegisterProvider = false;
        providerData.binding = YodleeBinding;

        List<BankSettingsHelper.providersResponse> lstProviderResp = new List<BankSettingsHelper.providersResponse>();
        lstProviderResp.add(providerData);
    
        String response = (String) BankSettingsHelper.registerDeregisterProviders(JSON.serialize(lstProviderResp));
        
        BankSettingsHelper.ResponseData returnedData = (BankSettingsHelper.ResponseData) JSON.deserialize(response, BankSettingsHelper.ResponseData.class);
        Test.stopTest();

        System.assertEquals(returnedData != NULL, TRUE);
        System.assertEquals(returnedData.isSuccess, TRUE);
        System.assertEquals(returnedData.serviceFaultProviders.size()>0, TRUE);
        System.assertEquals(returnedData.serviceFaultProviders[0], 'Yodlee');
        System.assertEquals(returnedData.faultMessage, Label.REG_DEREG_ERROR_MSG.replace('**', String.join(returnedData.serviceFaultProviders, ',')+'.'));
    }

    @isTest
    private static void testAccountingSettingSaveSingleFIA() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        
        System.runAs(testData.users[1]) {
        Test.startTest();

        BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.saveBankSettings(false, false, 0.0, 0.0,'Cash Receipt', 'Cash Disbursement', new List<string>{}, false, true);
        List<Accounting_Settings__c> accSettings = [Select Single_FIA_per_Bank_Account__c, Enable_Global_Automated_Add__c,
                                              Enable_Global_Automated_Match__c, Cash_In_Default_Matching_Setting__c,
                                              Cash_Out_Default_Matching_Setting__c, Cash_In_Default_Source_Record_Type__c,
                                              Cash_Out_Default_Source_Record_Type__c, Pre_Populate_Account_Info__c 
                                              FROM Accounting_Settings__c LIMIT 1];
        Test.stopTest();

        System.assertEquals(saveData != NULL, TRUE);
        System.assertEquals(saveData.isSuccess, TRUE);
        //before save singleFIA should be false
        System.assertEquals(testData.settings.Single_FIA_per_Bank_Account__c, FALSE);
        //after save
        System.assertEquals(accSettings[0].Single_FIA_per_Bank_Account__c, TRUE);
        System.assertEquals(accSettings[0].Enable_Global_Automated_Add__c, FALSE);
        System.assertEquals(accSettings[0].Enable_Global_Automated_Match__c, FALSE);
        System.assertEquals(accSettings[0].Cash_In_Default_Matching_Setting__c, 0.0);
        System.assertEquals(accSettings[0].Cash_Out_Default_Matching_Setting__c, 0.0);
        System.assertEquals(accSettings[0].Cash_In_Default_Source_Record_Type__c, 'Cash Receipt');
        System.assertEquals(accSettings[0].Cash_Out_Default_Source_Record_Type__c, 'Cash Disbursement');
        System.assertEquals(accSettings[0].Pre_Populate_Account_Info__c, FALSE);
      }
    }

    @isTest
    private static void testFailAccountingSettingSave() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
        Test.startTest();
    
        BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.saveBankSettings(false, false, 0.0, 0.0,'test', 'test', new List<string>{}, false, true);
        List<Accounting_Settings__c> accSettings = [Select Single_FIA_per_Bank_Account__c, Enable_Global_Automated_Add__c,
                                              Enable_Global_Automated_Match__c, Cash_In_Default_Matching_Setting__c,
                                              Cash_Out_Default_Matching_Setting__c, Cash_In_Default_Source_Record_Type__c,
                                              Cash_Out_Default_Source_Record_Type__c, Pre_Populate_Account_Info__c 
                                              FROM Accounting_Settings__c LIMIT 1];
        Test.stopTest();

        System.assertEquals(saveData != NULL, TRUE);
        System.assertEquals(saveData.isSuccess, FALSE);
        System.assertEquals(saveData.errors.size() > 0, TRUE);
        //before save singleFIA should be false
        System.assertEquals(testData.settings.Single_FIA_per_Bank_Account__c, FALSE);
        //after save
        System.assertEquals(accSettings[0].Single_FIA_per_Bank_Account__c, FALSE);
     }
    }

    @isTest
    private static void testAccountingSettingAndExistingGlamsSave() {
     TestDataSuite testData = TestDataSuite.getInstance(true);
     System.runAs(testData.users[1]) {
        Test.startTest();
        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = '111',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'Provider1',
            Financial_Institution_Id__c = '111',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Yodlee',
            Inactive__c = false
        );
        insert objglam; 

        BankSettingsHelper.glamSaveItem glam = new BankSettingsHelper.glamSaveItem();
        glam.id = '111';
        glam.glAccountId = testData.glAccounts[13].Id;
        glam.ledgerId = testData.ledgers[0].Id;
        glam.financialInstitutionId = 'Provider1';
        glam.financialInstitutionIdentityId = '111';
        glam.initialStartDate = Date.today();
        glam.name = 'Dag Checking Account - xxxx2345';
        glam.financialInstitutionName = 'Dag Site Captcha';
        glam.currencyIsoCode = 'USD';
        glam.currentBalance = 1600;
        glam.availableBalance = 1500;
        glam.fiaStatus = 'Action Required - Additional user authentication information is needed.';
        glam.source = 'Yodlee';
        glam.lastRefreshedDate = System.now();
        
        BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.saveBankSettings(false, false, 0.0, 0.0, 'Cash Receipt', 'Cash Disbursement', new List<String>{JSON.serializePretty(glam)}, false, true);
        
        List<GL_Account_Mapping__c> lstOfGlams = [Select Ledger__c, GL_Account__c, Account_Name__c, Financial_Institution__c,
                                                  Initial_Start_Date__c, Financial_Institution_Id__c, Source__c,
                                                  Available_Balance__c, Current_Balance__c, FIA_Status__c FROM 
                                                  GL_Account_Mapping__c LIMIT 1];
        Test.stopTest();

        System.assertEquals(saveData != NULL, TRUE);
        System.assertEquals(saveData.isSuccess, TRUE);
        System.assertEquals(saveData.errors == null, TRUE);
        System.assertEquals(lstOfGlams[0].Ledger__c, testData.ledgers[0].Id);
        System.assertEquals(lstOfGlams[0].Account_Name__c, 'Dag Checking Account - xxxx2345');
        System.assertEquals(lstOfGlams[0].Financial_Institution__c, 'Dag Site Captcha');
        System.assertEquals(lstOfGlams[0].Initial_Start_Date__c,  Date.today());
        System.assertEquals(lstOfGlams[0].Financial_Institution_Id__c, '111');
        System.assertEquals(lstOfGlams[0].Source__c, 'Yodlee');
        System.assertEquals(lstOfGlams[0].Available_Balance__c, 1500);
        System.assertEquals(lstOfGlams[0].Current_Balance__c, 1600);
        System.assertEquals(lstOfGlams[0].FIA_Status__c, 'Action Required - Additional user authentication information is needed.');
     }
    }

    /**
     * method for testing one GL account map to one FI when single FIA is checked
     */
    @isTest
    private static void testFailAccountingSettingAndExistingGlamsSave() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
        Test.startTest();
    
        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = '111',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'Provider1',
            Financial_Institution_Id__c = '111',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Yodlee',
            Inactive__c = false
        );
        insert objglam; 

        BankSettingsHelper.glamSaveItem glam = new BankSettingsHelper.glamSaveItem();
        glam.id = '111';
        glam.glAccountId = testData.glAccounts[0].Id;
        glam.ledgerId = testData.ledgers[0].Id;
        glam.financialInstitutionId = 'Provider1';
        glam.financialInstitutionIdentityId = '111';
        glam.initialStartDate = Date.today();
        glam.name = 'Dag Checking Account - xxxx2345';
        glam.financialInstitutionName = 'Dag Site Captcha';
        glam.currencyIsoCode = 'USD';
        glam.currentBalance = 1600;
        glam.availableBalance = 1500;
        glam.fiaStatus = 'Action Required - Additional user authentication information is needed.';
        glam.source = 'Yodlee';
        glam.lastRefreshedDate = System.now();
        
        BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.saveBankSettings(false, false, 0.0, 0.0, 'Cash Receipt', 'Cash Disbursement', new List<String>{JSON.serializePretty(glam)}, false, true);
        Test.stopTest();

        System.assertEquals(saveData != NULL, TRUE);
        System.assertEquals(saveData.isSuccess, FALSE);
        System.assertEquals(saveData.errors.size()>0, TRUE);
      }
    }

    @isTest
    private static void testAccountingSettingAndNewlyGlamsSave() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        
        System.runAs(testData.users[1]) {
         Test.startTest();

        BankSettingsHelper.glamSaveItem glam = new BankSettingsHelper.glamSaveItem();
        glam.id = '111';
        glam.glAccountId = testData.glAccounts[0].Id;
        glam.ledgerId = testData.ledgers[0].Id;
        glam.financialInstitutionId = 'Provider1';
        glam.financialInstitutionIdentityId = '111';
        glam.initialStartDate = Date.today();
        glam.name = 'Dag Checking Account - xxxx2345';
        glam.financialInstitutionName = 'Dag Site Captcha';
        glam.currencyIsoCode = 'USD';
        glam.currentBalance = 1600;
        glam.availableBalance = 1500;
        glam.source = 'Yodlee';
        glam.lastRefreshedDate = System.now();
        
        BankSettingsHelper.SaveResponse saveData = BankSettingsHelper.saveBankSettings(false, false, 0.0, 0.0, 'Cash Receipt', 'Cash Disbursement', new List<String>{JSON.serializePretty(glam)}, false, false);
        List<GL_Account_Mapping__c> lstOfGlams = [Select Ledger__c, GL_Account__c, Account_Name__c, Financial_Institution__c,
                                                  Initial_Start_Date__c, Financial_Institution_Id__c, Source__c,
                                                  Available_Balance__c, Current_Balance__c, FIA_Status__c FROM 
                                                  GL_Account_Mapping__c LIMIT 1];
        Test.stopTest();

        System.assertEquals(saveData != NULL, TRUE);
        System.assertEquals(saveData.isSuccess, TRUE);
        System.assertEquals(saveData.errors == null, TRUE);
        //assert new Glam after save
        System.assertEquals(lstOfGlams[0].GL_Account__c, testData.glAccounts[0].Id);
        System.assertEquals(lstOfGlams[0].Ledger__c, testData.ledgers[0].Id);
        System.assertEquals(lstOfGlams[0].Account_Name__c, 'Dag Checking Account - xxxx2345');
        System.assertEquals(lstOfGlams[0].Financial_Institution__c, 'Dag Site Captcha');
        System.assertEquals(lstOfGlams[0].Initial_Start_Date__c,  Date.today());
        System.assertEquals(lstOfGlams[0].Financial_Institution_Id__c, '111');
        System.assertEquals(lstOfGlams[0].Source__c, 'Yodlee');
        System.assertEquals(lstOfGlams[0].Available_Balance__c, 1500);
        System.assertEquals(lstOfGlams[0].Current_Balance__c, 1600);
      }
    }

    @isTest
    private static void testYodleeGetBankSettings() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
        BDC_Binding__c plaidBinding = [Select id from BDC_Binding__c WHERE Name = 'Plaid' LIMIT 1];
        delete plaidBinding;

        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = '111',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'AS Financial Inst',
            Financial_Institution_Id__c = '16441',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Yodlee',
            Inactive__c = false
        );
        insert objglam;

        Map<String, String> providerParams = new Map<String, String>();
        providerParams.put('providerId', '16441');

        Map<String, String> accountsParams2 = new Map<String, String>();
        accountsParams2.put('status', 'ACTIVE');
        accountsParams2.put('container', 'creditCard');  
        accountsParams2.put('include', 'autoRefresh');
        accountsParams2.put('providerAccountId', '21769933,21759841');

        Map<String, String> accountsParams1 = new Map<String, String>();
        accountsParams1.put('status', 'ACTIVE');
        accountsParams1.put('container', 'bank');  
        accountsParams1.put('include', 'autoRefresh');
        accountsParams1.put('providerAccountId', '21769933,21759841');

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON1 , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON1 , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.ACCOUNTS_FROM_FID_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getProviderAccountsURL(NULL) => xGetFIdsMock,
            YodleeServiceTest.getProvidersURL(providerParams) => xGetFInsMock,
            YodleeServiceTest.getAccountsURL(accountsParams2) => xGetAccsMock,
            YodleeServiceTest.getAccountsURL(accountsParams1) => xGetAccsMock
        };

        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        List<GL_Account_Mapping__c> lstOfGlamsDb = [Select id, Inactive__c, Source__c FROM GL_Account_Mapping__c LIMIT 10];
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().contains('Yodlee'), TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].name, 'AS Financial Inst');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].id, '16441');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].fiaStatus, 'USER_INPUT_REQUIRED');

        System.assertEquals(lstOfGlamsDb[0].Inactive__c, TRUE);
        System.assertEquals(lstOfGlamsDb[0].Source__c, 'Yodlee');

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        System.assertEquals(bankWrapper.glams[0].availableBalance, 105);
        System.assertEquals(bankWrapper.glams[0].financialInstitutionId, '16441');
        System.assertEquals(bankWrapper.glams[0].id, '29462280');
        System.assertEquals(bankWrapper.glams[0].ledgerName, null);
        System.assertEquals(bankWrapper.glams[0].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[0].name, 'Dag Saving Plus - xxxx4197');
        System.assertEquals(bankWrapper.glams[0].financialInstitutionName, 'AS Financial Inst');
        System.assertEquals(bankWrapper.glams[0].Source, 'Yodlee');

        System.assertEquals(bankWrapper.glams[1].availableBalance, 0);
        System.assertEquals(bankWrapper.glams[1].financialInstitutionId, '16441');
        System.assertEquals(bankWrapper.glams[1].id, '29462279');
        System.assertEquals(bankWrapper.glams[1].ledgerName, null);
        System.assertEquals(bankWrapper.glams[1].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[1].name, 'Dag Fixed Term Deposit - xxxx9881');
        System.assertEquals(bankWrapper.glams[1].financialInstitutionName, 'AS Financial Inst');
        System.assertEquals(bankWrapper.glams[1].Source, 'Yodlee');
     }
    }

    @isTest
    private static void testYodleeGetBankSettingsOnInactiveExisitngGlams() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
        BDC_Binding__c plaidBinding = [Select id from BDC_Binding__c WHERE Name = 'Plaid' LIMIT 1];
        delete plaidBinding;

        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = '29462280',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'AS Financial Inst',
            Financial_Institution_Id__c = '16441',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Yodlee',
            Inactive__c = TRUE
        );
        insert objglam;

        Map<String, String> providerParams = new Map<String, String>();
        providerParams.put('providerId', '16441');

        Map<String, String> accountsParams2 = new Map<String, String>();
        accountsParams2.put('status', 'ACTIVE');
        accountsParams2.put('container', 'creditCard');  
        accountsParams2.put('include', 'autoRefresh');
        accountsParams2.put('providerAccountId', '21769933,21759841');

        Map<String, String> accountsParams1 = new Map<String, String>();
        accountsParams1.put('status', 'ACTIVE');
        accountsParams1.put('container', 'bank');  
        accountsParams1.put('include', 'autoRefresh');
        accountsParams1.put('providerAccountId', '21769933,21759841');

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON1 , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON1 , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.ACCOUNTS_FROM_FID_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getProviderAccountsURL(NULL) => xGetFIdsMock,
            YodleeServiceTest.getProvidersURL(providerParams) => xGetFInsMock,
            YodleeServiceTest.getAccountsURL(accountsParams2) => xGetAccsMock,
            YodleeServiceTest.getAccountsURL(accountsParams1) => xGetAccsMock
        };

        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        List<GL_Account_Mapping__c> lstOfGlamsDb = [Select id, Inactive__c, Source__c, GL_Account__r.Name FROM GL_Account_Mapping__c LIMIT 10];
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().contains('Yodlee'), TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].name, 'AS Financial Inst');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].id, '16441');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].fiaStatus, 'USER_INPUT_REQUIRED');

        System.assertEquals(lstOfGlamsDb[0].Inactive__c, FALSE);
        System.assertEquals(lstOfGlamsDb[0].Source__c, 'Yodlee');

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        System.assertEquals(bankWrapper.glams[0].availableBalance, 105);
        System.assertEquals(bankWrapper.glams[0].financialInstitutionId, '16441');
        System.assertEquals(bankWrapper.glams[0].id, '29462280');
        System.assertEquals(bankWrapper.glams[0].ledgerName, 'Actual');
        System.assertEquals(bankWrapper.glams[0].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[0].name, 'Dag Saving Plus - xxxx4197');
        System.assertEquals(bankWrapper.glams[0].financialInstitutionName, 'AS Financial Inst');
        System.assertEquals(bankWrapper.glams[0].Source, 'Yodlee');
        System.assertEquals(bankWrapper.glams[0].glAccountId, testData.glAccounts[0].Id);
        System.assertEquals(bankWrapper.glams[0].glAccountName, lstOfGlamsDb[0].GL_Account__r.Name);
        System.assertEquals(bankWrapper.glams[0].ledgerId, testData.ledgers[0].Id);
        System.assertEquals(bankWrapper.glams[0].initialStartDate, Date.today());

        System.assertEquals(bankWrapper.glams[1].availableBalance, 0);
        System.assertEquals(bankWrapper.glams[1].financialInstitutionId, '16441');
        System.assertEquals(bankWrapper.glams[1].id, '29462279');
        System.assertEquals(bankWrapper.glams[1].ledgerName, null);
        System.assertEquals(bankWrapper.glams[1].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[1].name, 'Dag Fixed Term Deposit - xxxx9881');
        System.assertEquals(bankWrapper.glams[1].financialInstitutionName, 'AS Financial Inst');
        System.assertEquals(bankWrapper.glams[1].Source, 'Yodlee');
     }
    }

    @isTest
    private static void testYodleeGetBankSettingsOnExisitngGlams() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
        BDC_Binding__c plaidBinding = [Select id from BDC_Binding__c WHERE Name = 'Plaid' LIMIT 1];
        delete plaidBinding;

        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = '29462280',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'AS Financial Inst',
            Financial_Institution_Id__c = '16441',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Yodlee',
            Inactive__c = false
        );
        insert objglam;

        Map<String, String> providerParams = new Map<String, String>();
        providerParams.put('providerId', '16441');

        Map<String, String> accountsParams2 = new Map<String, String>();
        accountsParams2.put('status', 'ACTIVE');
        accountsParams2.put('container', 'creditCard');  
        accountsParams2.put('include', 'autoRefresh');
        accountsParams2.put('providerAccountId', '21769933,21759841');

        Map<String, String> accountsParams1 = new Map<String, String>();
        accountsParams1.put('status', 'ACTIVE');
        accountsParams1.put('container', 'bank');  
        accountsParams1.put('include', 'autoRefresh');
        accountsParams1.put('providerAccountId', '21769933,21759841');

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON1 , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON1 , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.ACCOUNTS_FROM_FID_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getProviderAccountsURL(NULL) => xGetFIdsMock,
            YodleeServiceTest.getProvidersURL(providerParams) => xGetFInsMock,
            YodleeServiceTest.getAccountsURL(accountsParams2) => xGetAccsMock,
            YodleeServiceTest.getAccountsURL(accountsParams1) => xGetAccsMock
        };

        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        List<GL_Account_Mapping__c> lstOfGlamsDb = [Select id, Inactive__c, Source__c, GL_Account__r.Name FROM GL_Account_Mapping__c LIMIT 10];
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().contains('Yodlee'), TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].name, 'AS Financial Inst');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].id, '16441');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].fiaStatus, 'USER_INPUT_REQUIRED');

        System.assertEquals(lstOfGlamsDb[0].Inactive__c, FALSE);
        System.assertEquals(lstOfGlamsDb[0].Source__c, 'Yodlee');

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        System.assertEquals(bankWrapper.glams[0].availableBalance, 105);
        System.assertEquals(bankWrapper.glams[0].financialInstitutionId, '16441');
        System.assertEquals(bankWrapper.glams[0].id, '29462280');
        System.assertEquals(bankWrapper.glams[0].ledgerName, 'Actual');
        System.assertEquals(bankWrapper.glams[0].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[0].name, 'Dag Saving Plus - xxxx4197');
        System.assertEquals(bankWrapper.glams[0].financialInstitutionName, 'AS Financial Inst');
        System.assertEquals(bankWrapper.glams[0].Source, 'Yodlee');
        System.assertEquals(bankWrapper.glams[0].glAccountId, testData.glAccounts[0].Id);
        System.assertEquals(bankWrapper.glams[0].glAccountName, lstOfGlamsDb[0].GL_Account__r.Name);
        System.assertEquals(bankWrapper.glams[0].ledgerId, testData.ledgers[0].Id);
        System.assertEquals(bankWrapper.glams[0].initialStartDate, Date.today());

        System.assertEquals(bankWrapper.glams[1].availableBalance, 0);
        System.assertEquals(bankWrapper.glams[1].financialInstitutionId, '16441');
        System.assertEquals(bankWrapper.glams[1].id, '29462279');
        System.assertEquals(bankWrapper.glams[1].ledgerName, null);
        System.assertEquals(bankWrapper.glams[1].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[1].name, 'Dag Fixed Term Deposit - xxxx9881');
        System.assertEquals(bankWrapper.glams[1].financialInstitutionName, 'AS Financial Inst');
        System.assertEquals(bankWrapper.glams[1].Source, 'Yodlee');
     }
    }

    @isTest
    private static void testPlaidGetBankSettingsOnInactiveExisitngGlams() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        BDC_Binding__c yodleeBinding = [Select id from BDC_Binding__c WHERE Name = 'Yodlee' LIMIT 1];
        delete yodleeBinding;

        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = 'j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'AS Financial Inst',
            Financial_Institution_Id__c = 'ins_3',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Plaid',
            Inactive__c = TRUE
        );
        insert objglam;

        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        List<GL_Account_Mapping__c> lstOfGlamsDb = [Select id, Inactive__c, Source__c, GL_Account__r.Name FROM GL_Account_Mapping__c LIMIT 10];
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().contains('Plaid'), TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].name, 'Chase');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].id, 'ins_3');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].fiaStatus, 'OK');

        System.assertEquals(lstOfGlamsDb[0].Inactive__c, FALSE);
        System.assertEquals(lstOfGlamsDb[0].Source__c, 'Plaid');

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        System.assertEquals(bankWrapper.glams[0].availableBalance, 100);
        System.assertEquals(bankWrapper.glams[0].financialInstitutionId, 'ins_3');
        System.assertEquals(bankWrapper.glams[0].id, 'j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv');
        System.assertEquals(bankWrapper.glams[0].ledgerName, 'Actual');
        System.assertEquals(bankWrapper.glams[0].singleLedgerOrg, FALSE);
        System.assertEquals(bankWrapper.glams[0].name, 'Plaid Gold Standard 0% Interest Checking (Plaid Checking) - 0000');
        System.assertEquals(bankWrapper.glams[0].financialInstitutionName, 'Chase');
        System.assertEquals(bankWrapper.glams[0].Source, 'Plaid');
        System.assertEquals(bankWrapper.glams[0].glAccountId, testData.glAccounts[0].Id);
        System.assertEquals(bankWrapper.glams[0].glAccountName, lstOfGlamsDb[0].GL_Account__r.Name);
        System.assertEquals(bankWrapper.glams[0].ledgerId, testData.ledgers[0].Id);
        System.assertEquals(bankWrapper.glams[0].initialStartDate, Date.today());

        System.assertEquals(bankWrapper.glams[1].availableBalance, 200);
        System.assertEquals(bankWrapper.glams[1].financialInstitutionId, 'ins_3');
        System.assertEquals(bankWrapper.glams[1].id, '7nb9NbQr8GHy963VVNGbcJM1pBVJWei11mplM');
        System.assertEquals(bankWrapper.glams[1].ledgerName, null);
        System.assertEquals(bankWrapper.glams[1].singleLedgerOrg, FALSE);
        System.assertEquals(bankWrapper.glams[1].name, 'Plaid Silver Standard 0.1% Interest Saving (Plaid Saving) - 1111');
        System.assertEquals(bankWrapper.glams[1].financialInstitutionName, 'Chase');
        System.assertEquals(bankWrapper.glams[1].Source, 'Plaid');
     }
    }

    @isTest
    private static void testPlaidGetBankSettingsOnActiveExisitngGlams() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        BDC_Binding__c yodleeBinding = [Select id from BDC_Binding__c WHERE Name = 'Yodlee' LIMIT 1];
        delete yodleeBinding;

        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = 'j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'AS Financial Inst',
            Financial_Institution_Id__c = 'ins_3',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Plaid',
            Inactive__c = FALSE
        );
        insert objglam;

        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        List<GL_Account_Mapping__c> lstOfGlamsDb = [Select id, Inactive__c, Source__c, GL_Account__r.Name FROM GL_Account_Mapping__c LIMIT 10];
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().contains('Plaid'), TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].name, 'Chase');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].id, 'ins_3');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].fiaStatus, 'OK');

        System.assertEquals(lstOfGlamsDb[0].Inactive__c, FALSE);
        System.assertEquals(lstOfGlamsDb[0].Source__c, 'Plaid');

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        System.assertEquals(bankWrapper.glams[0].availableBalance, 100);
        System.assertEquals(bankWrapper.glams[0].financialInstitutionId, 'ins_3');
        System.assertEquals(bankWrapper.glams[0].id, 'j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv');
        System.assertEquals(bankWrapper.glams[0].ledgerName, 'Actual');
        System.assertEquals(bankWrapper.glams[0].singleLedgerOrg, FALSE);
        System.assertEquals(bankWrapper.glams[0].name, 'Plaid Gold Standard 0% Interest Checking (Plaid Checking) - 0000');
        System.assertEquals(bankWrapper.glams[0].financialInstitutionName, 'Chase');
        System.assertEquals(bankWrapper.glams[0].Source, 'Plaid');
        System.assertEquals(bankWrapper.glams[0].glAccountId, testData.glAccounts[0].Id);
        System.assertEquals(bankWrapper.glams[0].glAccountName, lstOfGlamsDb[0].GL_Account__r.Name);
        System.assertEquals(bankWrapper.glams[0].ledgerId, testData.ledgers[0].Id);
        System.assertEquals(bankWrapper.glams[0].initialStartDate, Date.today());

        System.assertEquals(bankWrapper.glams[1].availableBalance, 200);
        System.assertEquals(bankWrapper.glams[1].financialInstitutionId, 'ins_3');
        System.assertEquals(bankWrapper.glams[1].id, '7nb9NbQr8GHy963VVNGbcJM1pBVJWei11mplM');
        System.assertEquals(bankWrapper.glams[1].ledgerName, null);
        System.assertEquals(bankWrapper.glams[1].singleLedgerOrg, FALSE);
        System.assertEquals(bankWrapper.glams[1].name, 'Plaid Silver Standard 0.1% Interest Saving (Plaid Saving) - 1111');
        System.assertEquals(bankWrapper.glams[1].financialInstitutionName, 'Chase');
        System.assertEquals(bankWrapper.glams[1].Source, 'Plaid');
     }
    }

    @isTest
    private static void testPlaidGetBankSettingsOnNewlyGlams() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        BDC_Binding__c yodleeBinding = [Select id from BDC_Binding__c WHERE Name = 'Yodlee' LIMIT 1];
        delete yodleeBinding;

        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().contains('Plaid'), TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].name, 'Chase');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].id, 'ins_3');
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Plaid')[0].fiaStatus, 'OK');

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        System.assertEquals(bankWrapper.glams[0].availableBalance, 100);
        System.assertEquals(bankWrapper.glams[0].financialInstitutionId, 'ins_3');
        System.assertEquals(bankWrapper.glams[0].id, 'j45865ZowDsopRELL3VkfV65bAdV9zuGGBAMv');
        System.assertEquals(bankWrapper.glams[0].ledgerName, null);
        System.assertEquals(bankWrapper.glams[0].singleLedgerOrg, FALSE);
        System.assertEquals(bankWrapper.glams[0].name, 'Plaid Gold Standard 0% Interest Checking (Plaid Checking) - 0000');
        System.assertEquals(bankWrapper.glams[0].financialInstitutionName, 'Chase');
        System.assertEquals(bankWrapper.glams[0].Source, 'Plaid');
        System.assertEquals(bankWrapper.glams[0].glAccountId, Null);
        System.assertEquals(bankWrapper.glams[0].ledgerId, null);
        System.assertEquals(bankWrapper.glams[0].initialStartDate, Date.today().addMonths(-3));

        System.assertEquals(bankWrapper.glams[1].availableBalance, 200);
        System.assertEquals(bankWrapper.glams[1].financialInstitutionId, 'ins_3');
        System.assertEquals(bankWrapper.glams[1].id, '7nb9NbQr8GHy963VVNGbcJM1pBVJWei11mplM');
        System.assertEquals(bankWrapper.glams[1].ledgerName, null);
        System.assertEquals(bankWrapper.glams[1].singleLedgerOrg, FALSE);
        System.assertEquals(bankWrapper.glams[1].name, 'Plaid Silver Standard 0.1% Interest Saving (Plaid Saving) - 1111');
        System.assertEquals(bankWrapper.glams[1].financialInstitutionName, 'Chase');
        System.assertEquals(bankWrapper.glams[1].Source, 'Plaid');
     }
    }

    @isTest
    private static void testPlaidGetBankSettingsOnNewGlamsNullBankName() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_NAME , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        Test.stopTest();

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        //if the official name is null the the parens are removed and nickname is used
        //'Plaid Gold Standard 0% Interest Checking (Plaid Checking) - 0000'
        System.assertEquals('Plaid Checking - 0000', bankWrapper.glams[0].name);


     }
    }

    @isTest
    private static void testPlaidGetBankSettingsOnNewGlamsNullNickName() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_NICKNAME , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        Test.stopTest();

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        //if the nickname is null the the parens are removed and nickname is removed
        //'Plaid Gold Standard 0% Interest Checking (Plaid Checking) - 0000'
        System.assertEquals('Plaid Gold Standard 0% Interest Checking - 0000', bankWrapper.glams[0].name);

     }
    }
    
    @isTest
    private static void testPlaidGetBankSettingsOnNewGlamsNullAcctMask() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_ACCT_MASK , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        Test.stopTest();

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        //if the acct mask is null the then be sure it's removed
        //'Plaid Gold Standard 0% Interest Checking (Plaid Checking) - 0000'
        System.assertEquals('Plaid Gold Standard 0% Interest Checking (Plaid Checking)', bankWrapper.glams[0].name);

     }
    }

    @isTest
    private static void testPlaidGetBankSettingsOnNewGlamsNullAcctInfo() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            PlaidBDCTest.ACCOUNTS_FROM_FINANCIAL_INSTITUITONS_TEST_JSON_NULL_ACCT_INFO , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        Test.stopTest();

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        //if the acct info is all null then display default label
        System.assertEquals(Label.NO_ACCOUNT_INFO, bankWrapper.glams[0].name);

     }
    }

    @isTest
    private static void testPlaidFailedGetBankSettingsOnNewlyGlams() {
        
        TestDataSuite testData = TestDataSuite.getInstance(true);
        PlaidBDCConnector plaidConnector = new PlaidBDCConnector();

        System.runAs(testData.users[1]) {
        BDC_Binding__c yodleeBinding = [Select id from BDC_Binding__c WHERE Name = 'Yodlee' LIMIT 1];
        delete yodleeBinding;

        External_Settings__mdt plaidSettings = External_Settings__mdt.getInstance('Plaid_Settings');
        String PLAID_API_ENDPOINT = plaidSettings.Value_1__c;

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            400,
            'fail',
            '', 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            400,
            'fail',
            '', 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            400,
            'fail',
            '', 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        Map<string, string> params = new Map<String, String>();

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            PLAID_API_ENDPOINT + '/item/get' + plaidConnector.populateUrlParameters(params) => xGetFIdsMock,
            PLAID_API_ENDPOINT + '/institutions/get_by_id' + plaidConnector.populateUrlParameters(params) => xGetFInsMock,
            PLAID_API_ENDPOINT + '/accounts/get' +  plaidConnector.populateUrlParameters(params) => xGetAccsMock
        };
    
        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().size() == 0, TRUE);

        System.assertEquals(bankWrapper.glams == Null, FALSE);
     }
    }

    //Yodlee potentially returns provider accounts (FII) that have a reference to a provider (FI) that does not exist
    @isTest
    private static void testYodleeGetBankSettingsWithOrphanedProvider() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users[1]) {
        BDC_Binding__c plaidBinding = [Select id from BDC_Binding__c WHERE Name = 'Plaid' LIMIT 1];
        delete plaidBinding;

        GL_Account_Mapping__c objglam = new GL_Account_Mapping__c (
            External_Id__c = '29462280',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'AS Financial Inst',
            Financial_Institution_Id__c = '16441',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Yodlee',
            Inactive__c = false
        );
        insert objglam;

        Map<String, String> providerParams = new Map<String, String>();
        providerParams.put('providerId', '55555');

        Map<String, String> accountsParams2 = new Map<String, String>();
        accountsParams2.put('status', 'ACTIVE');
        accountsParams2.put('container', 'creditCard');  
        accountsParams2.put('include', 'autoRefresh');
        accountsParams2.put('providerAccountId', '21769933,21759841');

        Map<String, String> accountsParams1 = new Map<String, String>();
        accountsParams1.put('status', 'ACTIVE');
        accountsParams1.put('container', 'bank');  
        accountsParams1.put('include', 'autoRefresh');
        accountsParams1.put('providerAccountId', '21769933,21759841');

        SingleRequestMock xGetFIdsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON_MISSING_FI, 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetFInsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.FINANCIAL_INSTITUTIONS_TEST_JSON1 , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        SingleRequestMock xGetAccsMock = new SingleRequestMock(
            200,
            'Complete',
            YodleeBDCTest.ACCOUNTS_FROM_FID_TEST_JSON , 
            new Map<String, String>{'Content-Type' => 'application/json'}
        );

        Map<String, HttpCalloutMock> requestMockByEndpointUrl = new Map<String, HttpCalloutMock>{
            YodleeServiceTest.getProviderAccountsURL(NULL) => xGetFIdsMock,
            YodleeServiceTest.getProvidersURL(providerParams) => xGetFInsMock,
            YodleeServiceTest.getAccountsURL(accountsParams2) => xGetAccsMock,
            YodleeServiceTest.getAccountsURL(accountsParams1) => xGetAccsMock
        };

        MultiRequestMock multiRequestMock = new MultiRequestMock(requestMockByEndpointUrl);
        Test.setMock(HttpCalloutMock.class, multiRequestMock);
        
        Test.startTest();
        BankSettingsHelper.BankSettingsWrapper bankWrapper = BankSettingsHelper.getBankSettings();
        List<GL_Account_Mapping__c> lstOfGlamsDb = [Select id, Inactive__c, Source__c, GL_Account__r.Name FROM GL_Account_Mapping__c LIMIT 10];
        Test.stopTest();
        
        System.assertEquals(bankWrapper.allowEdit, TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.keySet().contains('Yodlee'), TRUE);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].name, null);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].id, null);
        System.assertEquals(bankWrapper.mFinancialInstitutitonBySource.get('Yodlee')[0].fiaStatus, 'USER_INPUT_REQUIRED');

        System.assertEquals(lstOfGlamsDb[0].Inactive__c, FALSE);
        System.assertEquals(lstOfGlamsDb[0].Source__c, 'Yodlee');

        System.assertEquals(bankWrapper.glams.size() > 0, TRUE);
        System.assertEquals(bankWrapper.glams[0].availableBalance, 105);
        System.assertEquals(bankWrapper.glams[0].financialInstitutionId, null);
        System.assertEquals(bankWrapper.glams[0].id, '29462280');
        System.assertEquals(bankWrapper.glams[0].ledgerName, 'Actual');
        System.assertEquals(bankWrapper.glams[0].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[0].name, 'Dag Saving Plus - xxxx4197');
        System.assertEquals(bankWrapper.glams[0].financialInstitutionName, 'AS Financial Inst');
        System.assertEquals(bankWrapper.glams[0].Source, 'Yodlee');
        System.assertEquals(bankWrapper.glams[0].glAccountId, testData.glAccounts[0].Id);
        System.assertEquals(bankWrapper.glams[0].glAccountName, lstOfGlamsDb[0].GL_Account__r.Name);
        System.assertEquals(bankWrapper.glams[0].ledgerId, testData.ledgers[0].Id);
        System.assertEquals(bankWrapper.glams[0].initialStartDate, Date.today());

        System.assertEquals(bankWrapper.glams[1].availableBalance, 0);
        System.assertEquals(bankWrapper.glams[1].financialInstitutionId, null);
        System.assertEquals(bankWrapper.glams[1].id, '29462279');
        System.assertEquals(bankWrapper.glams[1].ledgerName, null);
        System.assertEquals(bankWrapper.glams[1].singleLedgerOrg, TRUE);
        System.assertEquals(bankWrapper.glams[1].name, 'Dag Fixed Term Deposit - xxxx9881');
        System.assertEquals(bankWrapper.glams[1].financialInstitutionName, null);
        System.assertEquals(bankWrapper.glams[1].Source, 'Yodlee');
     }
    }

    @isTest
    private static void testBuildAccountNamString_fullName() {
        String officialName = 'ABC Bank Checking';
        String nickname = 'My Checking';
        String maskedAccountNumber = '0000';

        String finalAccountName = BankSettingsHelper.buildAccountNameString(officialName, nickname, maskedAccountNumber);
        System.assertEquals(finalAccountName, 'ABC Bank Checking (My Checking) - 0000');
    }

    @isTest
    private static void testBuildAccountNamString_noNickname() {
        String officialName = 'ABC Bank Checking';
        String nickname = null;
        String maskedAccountNumber = '0000';

        String finalAccountName = BankSettingsHelper.buildAccountNameString(officialName, nickname, maskedAccountNumber);
        System.assertEquals(finalAccountName, 'ABC Bank Checking - 0000');
    }

    @isTest
    private static void testBuildAccountNamString_noOfficialName() {
        String officialName = '';
        String nickname = 'My Checking';
        String maskedAccountNumber = '0000';

        String finalAccountName = BankSettingsHelper.buildAccountNameString(officialName, nickname, maskedAccountNumber);
        System.assertEquals(finalAccountName, 'My Checking - 0000');
    }

    @isTest
    private static void testBuildAccountNamString_noOfficialNameOrNickname() {
        String officialName = '';
        String nickname = null;
        String maskedAccountNumber = '0000';

        String finalAccountName = BankSettingsHelper.buildAccountNameString(officialName, nickname, maskedAccountNumber);
        System.assertEquals(finalAccountName, '0000');
    }

    @isTest
    private static void testBuildAccountNamString_noOfficialNameOrNumber() {
        String officialName = '';
        String nickname = 'My Checking';
        String maskedAccountNumber = null;

        String finalAccountName = BankSettingsHelper.buildAccountNameString(officialName, nickname, maskedAccountNumber);
        System.assertEquals(finalAccountName, 'My Checking');
    }

}