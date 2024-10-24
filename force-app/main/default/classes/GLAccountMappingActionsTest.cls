@IsTest
private class GLAccountMappingActionsTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
        BDCMocker.testBDCBinding();
        
        BDC_Binding__c testBinding = new BDC_Binding__c();
        testBinding.Name = 'Plaid';
        testBinding.To__c = 'PlaidBDCRouter';
        testBinding.Type__c = 'AbstractBDCRouter';
        testBinding.Is_Active__c = true;
        insert testBinding;
    }

    @IsTest
    private static void testPreventUpdateGLAM() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            GL_Account_Mapping__c testGLAM = testData.glams.get(0);
            DmlException dmlEx;
            try {
                testGLAM.External_Id__c = 'testAccountId';
                update testGLAM;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountMappingActions.GLAM_UPDATE_DML_RESTRICTION_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testBypassPreventUpdateGLAM() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            GL_Account_Mapping__c testGLAM = testData.glams.get(0);
            DmlException dmlEx;
            try {
                testGLAM.External_Id__c = 'testAccountId';
                GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
                update testGLAM;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }

    private static void testFFIGLAMUpdateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();
        List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
        glams.add(new GL_Account_Mapping__c(
            External_Id__c = 'FFI-1',
            Financial_Institution__c = 'Test-FFI-1',
            Financial_Institution_Id__c = 'Test-FFI-ID-1',
            GL_Account__c = testData.glAccounts.get(0).Id,
            Ledger__c = testData.ledgers.get(0).Id,
            Inactive__c = false,
            Initial_Start_Date__c = testData.acctPeriods.get(0).Start_Date__c,
            Source__c = BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT
        ));
        insert glams;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            GL_Account_Mapping__c testGLAM = testData.glams.get(2);
            DmlException dmlEx;
            try {
                testGLAM.External_Id__c = 'testAccountId';
                update testGLAM;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);            
        }
    }

    private static void testEditSourceFailure() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();
        List<GL_Account_Mapping__c> glams = new List<GL_Account_Mapping__c>();
        glams.add(new GL_Account_Mapping__c(
            External_Id__c = 'FFI-1',
            Financial_Institution__c = 'Test-FFI-1',
            Financial_Institution_Id__c = 'Test-FFI-ID-1',
            GL_Account__c = testData.glAccounts.get(0).Id,
            Ledger__c = testData.ledgers.get(0).Id,
            Inactive__c = false,
            Initial_Start_Date__c = testData.acctPeriods.get(0).Start_Date__c,
            Source__c = BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT
        ));
        insert glams;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            GL_Account_Mapping__c testGLAM = testData.glams.get(2);
            DmlException dmlEx;
            try {
                testGLAM.Source__c = 'Yodlee';
                update testGLAM;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountMappingActions.GLAM_UPDATE_DML_RESTRICTION_ERROR, dmlEx.getDmlMessage(0));         

            testGLAM = testData.glams.get(0);
            dmlEx = NULL;
            try {
                testGLAM.Source__c = BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT;
                update testGLAM;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(GLAccountMappingActions.GLAM_UPDATE_DML_RESTRICTION_ERROR, dmlEx.getDmlMessage(0));         
        }
    }

    @IsTest
    private static void testDuplicateGLAMMappingActions() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();
        TestDataSuite testData1 = TestDataSuite.getInstance(true);
        List<GL_Account_Mapping__c> testGLAMs = new List<GL_Account_Mapping__c>{testData.glams.get(0),testData.glams.get(1)};
            
            System.runAs(testData.users.get(1)) {
                Test.startTest();
                try{
                    testData.settings.Single_FIA_per_Bank_Account__c = true;
                    update testData.settings;
                    testGLAMs[0].AcctSeed__Account_Name__c = 'testing account1';
                    testGLAMs[0].GL_Account__c = testData1.glAccounts.get(3).Id;
                    testGLAMs[1].AcctSeed__Account_Name__c = 'testing account';
                    testGLAMs[1].GL_Account__c = testData1.glAccounts.get(3).Id;
                    GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
                    update testGLAMs;
                    GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;
                }catch (Exception ex) {
                    System.assertEquals(ex.getMessage().contains(GLAccountMappingActions.GLAM_UPDATE_DUPLICACY_ERROR), TRUE);  
                    System.assertEquals(ex.getMessage().contains('testing account1'),TRUE); 
                    System.assertEquals(ex.getMessage().contains('testing account'),TRUE); 
                }
                Test.stopTest();
            }
    }
    
    @IsTest
    private static void testValidGLAMMappingActions() {
        TestDataSuite testData = TestDataSuite.getInstance().createGLAMs();
        TestDataSuite testData1 = TestDataSuite.getInstance(true);
        List<GL_Account_Mapping__c> testGLAMs = new List<GL_Account_Mapping__c>{testData.glams.get(0),testData.glams.get(1)};
            
            System.runAs(testData.users.get(1)) {
                Test.startTest();
                try{
                    testData.settings.Single_FIA_per_Bank_Account__c = true;
                    update testData.settings;
                    testGLAMs[0].AcctSeed__Account_Name__c = 'testing account1';
                    testGLAMs[1].AcctSeed__Account_Name__c = 'testing account';
                    testGLAMs[0].GL_Account__c = testData1.glAccounts.get(3).Id;
                    testGLAMs[1].GL_Account__c = testData1.glAccounts.get(4).Id;
                    update testGLAMs;
                    //Assert the newly succesfully updated GLAMS
                    List<GL_Account_Mapping__c> updateGlams = [Select Id, AcctSeed__Account_Name__c, GL_Account__r.name from GL_Account_Mapping__c LIMIT 2];
                    System.assertEquals(updateGlams[0].AcctSeed__Account_Name__c != NULL, TRUE); 
                    System.assertEquals(updateGlams[0].AcctSeed__Account_Name__c == 'testing account1', TRUE); 
                    System.assertEquals(updateGlams[1].AcctSeed__Account_Name__c != NULL, TRUE); 
                    System.assertEquals(updateGlams[1].AcctSeed__Account_Name__c == 'testing account', TRUE); 
                    System.assertEquals(updateGlams[0].GL_Account__r.name != NULL, TRUE); 
                    System.assertEquals(updateGlams[0].GL_Account__r.name == '1600-Work In Process', TRUE); 
                    System.assertEquals(updateGlams[1].GL_Account__r.name != NULL, TRUE); 
                    System.assertEquals(updateGlams[1].GL_Account__r.name == '2000-Accounts Payable', TRUE); 
                }catch (Exception ex) {}
                Test.stopTest();
            }
    }
    
    @IsTest
    private static void testInsertDuplicateGLAMMappingActions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.settings.Single_FIA_per_Bank_Account__c = true;
        update testData.settings;
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try{
                testData.createGlams();
                //Assert to verify whether GLAMs are inserted or not
                List<GL_Account_Mapping__c> insertedGlams = [Select Id from GL_Account_Mapping__c LIMIT 2];
                System.assertEquals(insertedGlams == null, TRUE);  
            }catch (Exception ex) {
                System.assertEquals(ex.getMessage().contains(GLAccountMappingActions.GLAM_UPDATE_DUPLICACY_ERROR), TRUE);  
            }
            Test.stopTest();
        }
    }
    
}