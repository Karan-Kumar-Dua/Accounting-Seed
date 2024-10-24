@IsTest
private class BankTransactionsHelperTest {

    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        GL_Account_Mapping__c objGlam = new GL_Account_Mapping__c (
            External_Id__c = 'PlaidAccount-1',
            GL_Account__c = testData.glAccounts[0].Id,
            Ledger__c = testData.ledgers[0].Id,
            Financial_Institution__c = 'Test-Financial-Institution-1',
            Financial_Institution_Id__c = 'Test-Financial-Institution-ID-1',
            Initial_Start_Date__c = Date.today(),
            Source__c = 'Plaid',
            Inactive__c = false
        );
        insert objGlam; 
    }
    
    @IsTest
    private static void testUpdateGLAM() {
        
        List<User> users = [Select id FROM User];
        System.runAs(users.get(1)) {
            GL_Account_Mapping__c objGlam = [Select Id, External_Id__c, GL_Account__c, Ledger__c, Financial_Institution__c,
                                             Financial_Institution_Id__c, Initial_Start_Date__c, Source__c, Inactive__c
                                             FROM GL_Account_Mapping__c WHERE External_Id__c = 'PlaidAccount-1'];
            
            BDCAccount bdcAcc = new BDCAccount();
            bdcAcc.Id = 'PlaidAccount-1';
            bdcAcc.name = 'BDCAccount';
            bdcAcc.ledgerId = objGlam.Ledger__c;
            bdcAcc.glAccountId = objGlam.GL_Account__c;
            bdcAcc.source = 'Plaid';
            bdcAcc.currentBalance = 123.34;
            bdcAcc.availableBalance = 500.33;
            bdcAcc.lastUpdated = System.now();
            
            BDCFinancialInstitutionIdentity bdcFinIdentityId = new BDCFinancialInstitutionIdentity();
            bdcFinIdentityId.Id = 'Test-Financial-Institution-ID-1';
            bdcFinIdentityId.financialInstitutionId = 'Test-Financial-Institution-1';
            bdcFinIdentityId.status = 'Success';
            bdcFinIdentityId.source = 'Plaid';
            
            Test.startTest();
            BankTransactionsHelper.updateGLAM(new BDCAccount[]{bdcAcc}, new BDCFinancialInstitutionIdentity[]{bdcFinIdentityId});
            
            List<GL_Account_Mapping__c> glams = DomainUtils.getGLAccountMappingsByExternalIds(new Set<String>{'PlaidAccount-1'});
            
            for (GL_Account_Mapping__c glam : glams) {
                System.assertEquals(glam.Available_Balance__c, bdcAcc.availableBalance);
                System.assertEquals(glam.Current_Balance__c, bdcAcc.currentBalance);
                System.assertEquals(glam.FIA_Status__c, BankTransactionsHelper.NO_ACTION_REQUIRED_MSG);
                System.assertEquals(glam.Last_Refreshed__c, bdcAcc.lastUpdated);
            }
            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testUpdateGLAMFailedProviderAccountStatus() {
        
        List<User> users = [Select id FROM User];
        System.runAs(users.get(1)) {
            GL_Account_Mapping__c objGlam = [Select Id, External_Id__c, GL_Account__c, Ledger__c, Financial_Institution__c,
                                             Financial_Institution_Id__c, Initial_Start_Date__c, Source__c, Inactive__c
                                             FROM GL_Account_Mapping__c WHERE External_Id__c = 'PlaidAccount-1'];
            
            BDCAccount bdcAcc = new BDCAccount();
            bdcAcc.Id = 'PlaidAccount-1';
            bdcAcc.name = 'BDCAccount';
            bdcAcc.ledgerId = objGlam.Ledger__c;
            bdcAcc.glAccountId = objGlam.GL_Account__c;
            bdcAcc.source = 'Plaid';
            bdcAcc.currentBalance = 123.34;
            bdcAcc.availableBalance = 500.33;
            bdcAcc.lastUpdated = System.now();
            
            BDCFinancialInstitutionIdentity bdcFinIdentityId = new BDCFinancialInstitutionIdentity();
            bdcFinIdentityId.Id = 'Test-Financial-Institution-ID-1';
            bdcFinIdentityId.financialInstitutionId = 'Test-Financial-Institution-1';
            bdcFinIdentityId.status = BankTransactionsHelper.PROVIDER_STATUS_FAILED;
            bdcFinIdentityId.source = 'Plaid';
            
            Test.startTest();
            BankTransactionsHelper.updateGLAM(new BDCAccount[]{bdcAcc}, new BDCFinancialInstitutionIdentity[]{bdcFinIdentityId});
            
            List<GL_Account_Mapping__c> glams = DomainUtils.getGLAccountMappingsByExternalIds(new Set<String>{'PlaidAccount-1'});
            
            for (GL_Account_Mapping__c glam : glams) {
                System.assertEquals(glam.Available_Balance__c, bdcAcc.availableBalance);
                System.assertEquals(glam.Current_Balance__c, bdcAcc.currentBalance);
                System.assertEquals(glam.FIA_Status__c, BankTransactionsHelper.FAILED_ERROR_MSG);
                System.assertEquals(glam.Last_Refreshed__c, bdcAcc.lastUpdated);
            }
            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testUpdateGLAM_Failed() {
        
        List<User> users = [Select id FROM User];
        System.runAs(users.get(1)) {
            try{
                Test.startTest();
                BankTransactionsHelper.updateGLAM(null, null);
                Test.stopTest();
            }catch(Exception ex){
                System.assertEquals(TRUE, ex.getMessage().contains('null object'));
            }
        }
    }
    
    @IsTest
    private static void testprocessDownloadedBankTransactions() {
        
        List<User> users = [Select id FROM User]; 
        List<Cash_Receipt__c> cashReceipts = TestDataSuite.getInstance().createCashReceipts().cashReceipts;       
        System.runAs(users.get(1)) {

            Accounting_Settings__c accSetting = [Select id, Enable_Global_Automated_Match__c, Enable_Global_Automated_Add__c
                                                 FROM  Accounting_Settings__c LIMIT 1];
            accSetting.Enable_Global_Automated_Match__c = true;
            accSetting.Enable_Global_Automated_Add__c   = true;        
            UPDATE accSetting;        

            Map<String, BDCCategory> categoriesById = new Map<String, BDCCategory>();

            BDCTransaction bdcTransaction = new BDCTransaction();
            bdcTransaction.id = 'Transaction-1';
            bdcTransaction.accountId = 'PlaidAccount-1'; 
            bdcTransaction.categoryId = 'Transaction-Categroy 1' ;
            bdcTransaction.amount = 500.00; 
            bdcTransaction.transactionDate = System.today(); 
            bdcTransaction.basetype = 'Credit';
            bdcTransaction.container = 'Credit';
            bdcTransaction.categoryLevel1Id = 'Transaction-Categroy Level1';
            bdcTransaction.categoryLevel2Id = 'Transaction-Categroy Level2';
            bdcTransaction.categoryLevel3Id = 'Transaction-Categroy Level3';
            
            BDCCategory bdcCategory1 = new BDCCategory();
            bdcCategory1.Id = 'Transaction-Categroy 1';
            bdcCategory1.name = 'test1';
            bdcCategory1.source = 'Financial File Import';
            bdcCategory1.parentCategoryId = 'Transaction-Categroy Level1';

            BDCCategory bdcCategory2 = new BDCCategory();
            bdcCategory2.Id = 'Transaction-Categroy 1';
            bdcCategory2.name = 'test2';
            bdcCategory2.source = 'Financial File Import';
            bdcCategory2.parentCategoryId = 'Transaction-Categroy Level2';

            BDCCategory bdcCategory3 = new BDCCategory();
            bdcCategory3.Id = 'Transaction-Categroy 1';
            bdcCategory3.name = 'test3';
            bdcCategory3.source = 'Financial File Import';
            bdcCategory3.parentCategoryId = 'Transaction-Categroy Level3';

            
            categoriesById.put('Transaction-Categroy Level1', bdcCategory1);
            categoriesById.put('Transaction-Categroy Level2', bdcCategory2);
            categoriesById.put('Transaction-Categroy Level3', bdcCategory3);

            Test.startTest();
            BankTransactionsHelper.processDownloadedBankTransactions(new BDCTransaction[]{bdcTransaction}, categoriesById, 'Financial File Import');
            
            List<Bank_Transaction__c> bankTransactions = [Select Id, Bank_Transaction_Id__c, Account_Id__c, Amount__c, Base_Type__c, 
                                                          Status__c, Date__c, Description__c FROM Bank_Transaction__c];

            System.assertEquals('Transaction-1', bankTransactions[0].Bank_Transaction_Id__c);
            System.assertEquals('PlaidAccount-1', bankTransactions[0].Account_Id__c);
            System.assertEquals(500.00, bankTransactions[0].Amount__c);
            System.assertEquals( 'Credit', bankTransactions[0].Base_Type__c);
            System.assertEquals('Unmatched', bankTransactions[0].Status__c);

            Map<Id, Sobject> sobjById = new Map<Id, Sobject>();
            sobjById.put(bankTransactions[0].Id, cashReceipts[0]);

            List<ServiceResult> serviceResults = BankTransactionsHelper.acceptMatchingRecord(sobjById, new Map<Id, Bank_Transaction__c>(bankTransactions));
            System.assertEquals(FALSE, serviceResults[0].isSuccess);
            Test.stopTest();
        }
    }
    @IsTest
    private static void testprocessDownloadedBankTransactions_DateChange() {
        
        List<User> users = [Select id FROM User]; 
        System.runAs(users.get(1)) {

            Accounting_Settings__c accSetting = [Select id, Enable_Global_Automated_Match__c, Enable_Global_Automated_Add__c
                                                 FROM  Accounting_Settings__c LIMIT 1];
            accSetting.Enable_Global_Automated_Match__c = true;
            accSetting.Enable_Global_Automated_Add__c   = true;        
            UPDATE accSetting;        

            Map<String, BDCCategory> categoriesById = new Map<String, BDCCategory>();

            BDCTransaction bdcTransaction = new BDCTransaction();
            bdcTransaction.id = 'Transaction-1';
            bdcTransaction.accountId = 'PlaidAccount-1'; 
            bdcTransaction.categoryId = 'Transaction-Categroy 1' ;
            bdcTransaction.amount = 500.00; 
            bdcTransaction.transactionDate = System.today(); 
            bdcTransaction.basetype = 'Credit';
            bdcTransaction.container = 'Credit';
            bdcTransaction.categoryLevel1Id = 'Transaction-Categroy Level1';
            bdcTransaction.categoryLevel2Id = 'Transaction-Categroy Level2';
            bdcTransaction.categoryLevel3Id = 'Transaction-Categroy Level3';
            
            BDCCategory bdcCategory1 = new BDCCategory();
            bdcCategory1.Id = 'Transaction-Categroy 1';
            bdcCategory1.name = 'test1';
            bdcCategory1.source = 'Financial File Import';
            bdcCategory1.parentCategoryId = 'Transaction-Categroy Level1';

            BDCCategory bdcCategory2 = new BDCCategory();
            bdcCategory2.Id = 'Transaction-Categroy 1';
            bdcCategory2.name = 'test2';
            bdcCategory2.source = 'Financial File Import';
            bdcCategory2.parentCategoryId = 'Transaction-Categroy Level2';

            BDCCategory bdcCategory3 = new BDCCategory();
            bdcCategory3.Id = 'Transaction-Categroy 1';
            bdcCategory3.name = 'test3';
            bdcCategory3.source = 'Financial File Import';
            bdcCategory3.parentCategoryId = 'Transaction-Categroy Level3';

            
            categoriesById.put('Transaction-Categroy Level1', bdcCategory1);
            categoriesById.put('Transaction-Categroy Level2', bdcCategory2);
            categoriesById.put('Transaction-Categroy Level3', bdcCategory3);

            Test.startTest();
            BankTransactionsHelper.processDownloadedBankTransactions(new BDCTransaction[]{bdcTransaction}, categoriesById, 'Yodlee');
            
            List<Bank_Transaction__c> bankTransactions = [Select Id, Bank_Transaction_Id__c, Account_Id__c, Amount__c, Base_Type__c, 
                                                          Status__c, Date__c, Description__c FROM Bank_Transaction__c];

            System.assertEquals('Transaction-1', bankTransactions[0].Bank_Transaction_Id__c);
            System.assertEquals('PlaidAccount-1', bankTransactions[0].Account_Id__c);
            System.assertEquals(500.00, bankTransactions[0].Amount__c);
            System.assertEquals( 'Credit', bankTransactions[0].Base_Type__c);
            System.assertEquals('Unmatched', bankTransactions[0].Status__c);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testprocessAutomatedMatchAndAddAsync() {
        
        List<User> users = [Select id FROM User]; 
        System.runAs(users.get(1)) {

            Accounting_Settings__c accSetting = [Select id, Enable_Global_Automated_Match__c, Enable_Global_Automated_Add__c
                                                 FROM  Accounting_Settings__c LIMIT 1];
            accSetting.Enable_Global_Automated_Match__c = true;
            accSetting.Enable_Global_Automated_Add__c   = true;        
            UPDATE accSetting; 
            
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = true;
            GL_Account_Mapping__c glam = [Select Id, Initial_Start_Date__c From GL_Account_Mapping__c LIMIT 1];
            glam.Initial_Start_Date__c = null;
            UPDATE glam;
            GLAccountMappingActions.isDmlRestrictionBypassEnabled = false;

            Map<String, BDCCategory> categoriesById = new Map<String, BDCCategory>();

            BDCTransaction bdcTransaction = new BDCTransaction();
            bdcTransaction.id = 'Transaction-1';
            bdcTransaction.accountId = 'PlaidAccount-1'; 
            bdcTransaction.categoryId = 'Transaction-Categroy 1' ;
            bdcTransaction.amount = 500.00; 
            bdcTransaction.transactionDate = System.today(); 
            bdcTransaction.basetype = 'Credit';
            bdcTransaction.container = 'Credit';
            bdcTransaction.categoryLevel1Id = 'Transaction-Categroy Level1';
            bdcTransaction.categoryLevel2Id = 'Transaction-Categroy Level2';
            bdcTransaction.categoryLevel3Id = 'Transaction-Categroy Level3';
            
            BDCCategory bdcCategory1 = new BDCCategory();
            bdcCategory1.Id = 'Transaction-Categroy 1';
            bdcCategory1.name = 'test1';
            bdcCategory1.source = 'Financial File Import';
            bdcCategory1.parentCategoryId = 'Transaction-Categroy Level1';

            BDCCategory bdcCategory2 = new BDCCategory();
            bdcCategory2.Id = 'Transaction-Categroy 1';
            bdcCategory2.name = 'test2';
            bdcCategory2.source = 'Financial File Import';
            bdcCategory2.parentCategoryId = 'Transaction-Categroy Level2';

            BDCCategory bdcCategory3 = new BDCCategory();
            bdcCategory3.Id = 'Transaction-Categroy 1';
            bdcCategory3.name = 'test3';
            bdcCategory3.source = 'Financial File Import';
            bdcCategory3.parentCategoryId = 'Transaction-Categroy Level3';

            
            categoriesById.put('Transaction-Categroy Level1', bdcCategory1);
            categoriesById.put('Transaction-Categroy Level2', bdcCategory2);
            categoriesById.put('Transaction-Categroy Level3', bdcCategory3);

            Test.startTest();
            BankTransactionsHelper.processDownloadedBankTransactions(new BDCTransaction[]{bdcTransaction}, categoriesById, 'Yodlee');
            
            List<Bank_Transaction__c> bankTransactions = [Select Id, Bank_Transaction_Id__c, Account_Id__c, Amount__c, Base_Type__c, 
                                                          Status__c, Date__c, Description__c FROM Bank_Transaction__c];

            BankTransactionsHelper.processAutomatedMatchAndAddAsync(bankTransactions);

            System.assertEquals('Transaction-1', bankTransactions[0].Bank_Transaction_Id__c);
            System.assertEquals('PlaidAccount-1', bankTransactions[0].Account_Id__c);
            System.assertEquals(500.00, bankTransactions[0].Amount__c);
            System.assertEquals( 'Credit', bankTransactions[0].Base_Type__c);
            System.assertEquals('Unmatched', bankTransactions[0].Status__c);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testlogOnActivity() { 

        List<User> users = [Select id FROM User]; 
        System.runAs(users.get(1)) {

            Test.startTest();
            BankTransactionsHelper.logOnActivity(new String[]{'PlaidAccount-1'}, 'Testing');

            GL_Account_Mapping__c glam = [Select Id from GL_Account_Mapping__c LIMIT 1];
            List<Task> tasks = [Select Id, WhatId, ActivityDate, Status, Priority, Subject, Description FROM Task];
            
            //Assert after activities creation.
            System.assertEquals(1, tasks.size());
            System.assertEquals(glam.Id, tasks[0].WhatId);
            System.assertEquals(System.today(), tasks[0].ActivityDate);
            System.assertEquals('Completed', tasks[0].Status);
            System.assertEquals( 'Normal', tasks[0].Priority);
            System.assertEquals(Label.ERR_DOWNLOADING_BANK_TRANSACTIONS, tasks[0].Subject);
            System.assertEquals('Testing', tasks[0].Description);
            Test.stopTest();
        }
    }
    
}