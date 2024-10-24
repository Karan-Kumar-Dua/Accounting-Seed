@IsTest
public class X1099File2BatchTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    
    @IsTest
    public static void testCreateFileDataNotFound() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        Id x1099FormTypeId = X1099InfoHelper.getFormTypes(2020)[0].Id;
        system.assertNotEquals(NUll, x1099FormTypeId);

        Test.startTest();
        X1099File2Batch xb = new X1099File2Batch('2020', testData.ledgers[0].Id, x1099FormTypeId);
        Database.executeBatch(xb);
        Test.stopTest();

        System.assertEquals(false, X1099File2Batch.isSendFileEmail);
        System.assertEquals(true, X1099File2Batch.isSendEmptyEmail);
    }

    @IsTest
    public static void testCreateFileSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        testData.accounts[0].X1099_Vendor__c = true;
        update testData.accounts[0];

        testData.contacts[0].X1099_Vendor__c = true;
        update testData.contacts[0];

        testData.cashDisbursements[0].Amount__c = 10;
        testData.cashDisbursements[0].Disbursement_Date__c = Date.newInstance(2020, 10, 1);
        update testData.cashDisbursements[0];

        Id x1099FormTypeId = X1099InfoHelper.getFormTypes(2020)[0].Id;
        system.assertNotEquals(NUll, x1099FormTypeId);


        Test.startTest();
        X1099File2Batch xb = new X1099File2Batch('2020', testData.ledgers[0].Id, x1099FormTypeId);
        Database.executeBatch(xb);
        Test.stopTest();

        System.assertEquals(true, X1099File2Batch.isSendFileEmail);
    }



    @IsTest
    public static void testMappingRecipientAccountFields() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        testData.accounts[0].X1099_Vendor__c = true;
        testData.accounts[0].BillingStreet = 'Test str';
        testData.accounts[0].BillingCity = 'Test City';
        testData.accounts[0].BillingState = 'Test State';
        testData.accounts[0].BillingPostalCode = 'Test PostalCode';
        testData.accounts[0].Taxpayer_Identification_Number__c = '123';
        update testData.accounts[0];


        X1099File2Batch.RecipientWrapper rw = new X1099File2Batch.RecipientWrapper(testData.accounts[0]);

        System.assertEquals(testData.accounts[0].Name, rw.recCompanyName);
        System.assertEquals('Test str', rw.recStreet);
        System.assertEquals('Test City', rw.recCity);
        System.assertEquals('Test State', rw.recState);
        System.assertEquals('Test PostalCode', rw.recZip);
        System.assertEquals('123', rw.recIdNumber);
    }

    

    @IsTest
    public static void testMappingRecipientContactFields() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        testData.contacts[0].X1099_Vendor__c = true;
        testData.contacts[0].MailingStreet = 'Test str';
        testData.contacts[0].MailingCity = 'Test City';
        testData.contacts[0].MailingState = 'Test State';
        testData.contacts[0].MailingPostalCode = 'Test PostalCode';
        testData.contacts[0].Taxpayer_Identification_Number__c = '123';
        testData.contacts[0].FirstName = 'Test First Name';
        testData.contacts[0].LastName = 'Test Last Name';

        update testData.contacts[0];


        X1099File2Batch.RecipientWrapper rw = new  X1099File2Batch.RecipientWrapper(testData.contacts[0]);

        System.assertEquals('Test First Name', rw.recFirstName);
        System.assertEquals('Test Last Name', rw.recLastName);
        System.assertEquals('Test str', rw.recStreet);
        System.assertEquals('Test City', rw.recCity);
        System.assertEquals('Test State', rw.recState);
        System.assertEquals('Test PostalCode', rw.recZip);
        System.assertEquals('123', rw.recIdNumber);
    }

    

    @IsTest
    public static void testCreateFileSuccessForAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements()
            .createApDisbursements();

        testData.accounts[0].X1099_Vendor__c = true;
        update testData.accounts[0];

        List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
        List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id); 

        testData.cashDisbursements[0].Amount__c = 10;
        testData.cashDisbursements[0].Form_Category_Id__c = formCategories[0].Id;
        testData.cashDisbursements[0].Disbursement_Date__c = Date.newInstance(2020, 10, 1);
        update testData.cashDisbursements[0];
        
        Cash_Disbursement__c newCashDisbursement = testData.cashDisbursements[0].clone();
        newCashDisbursement.Form_Category_Id__c = formCategories[1].Id;
        newCashDisbursement.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
        insert newCashDisbursement;

        Cash_Disbursement__c unCategorizedCashDisbursement = testData.cashDisbursements[0].clone();
        unCategorizedCashDisbursement.Form_Category_Id__c = null;
        unCategorizedCashDisbursement.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
        insert unCategorizedCashDisbursement;
       

        X1099File2Batch xb = new X1099File2Batch('2020', testData.ledgers[0].Id, formTypesAll[0].Id);
        Database.executeBatch(xb);
        Test.stopTest();
        System.assertEquals(1, X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.accounts[0].Id).size());
        System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.accounts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(formCategories[0].Id), 
                            testData.cashDisbursements[0].Amount__c);
        System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.accounts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(formCategories[1].Id), 
                            newCashDisbursement.Amount__c);
        System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.accounts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(X1099File2Batch.NON_CATEGORIZED_PAYMENTS), 
                            unCategorizedCashDisbursement.Amount__c);
    }

    @IsTest
    public static void testCreateFileSuccessForContact() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();
        Test.startTest();
        testData.createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();

        testData.contacts[0].X1099_Vendor__c = true;
        update testData.contacts[0];

        List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
        List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id); 

        testData.cashDisbursements[1].Amount__c = 20;
        testData.cashDisbursements[1].Form_Category_Id__c = formCategories[0].Id;
        testData.cashDisbursements[1].Disbursement_Date__c = Date.newInstance(2020, 10, 1);
        update testData.cashDisbursements[1];
        
        Cash_Disbursement__c newCashDisbursement = testData.cashDisbursements[1].clone();
        newCashDisbursement.Amount__c = 20;
        newCashDisbursement.Form_Category_Id__c = formCategories[1].Id;
        newCashDisbursement.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
        insert newCashDisbursement;

        Cash_Disbursement__c unCategorizedCashDisbursement = testData.cashDisbursements[1].clone();
        unCategorizedCashDisbursement.Amount__c = 20;
        unCategorizedCashDisbursement.Form_Category_Id__c = null;
        unCategorizedCashDisbursement.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
        insert unCategorizedCashDisbursement;

        X1099File2Batch xb = new X1099File2Batch('2020', testData.ledgers[0].Id, formTypesAll[0].Id);
        Database.executeBatch(xb);
        Test.stopTest();

        System.assertEquals(1, X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).size());
        System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(formCategories[0].Id), 
                            testData.cashDisbursements[1].Amount__c);
        System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(formCategories[1].Id), 
                            newCashDisbursement.Amount__c);
        System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(X1099File2Batch.NON_CATEGORIZED_PAYMENTS), 
                            unCategorizedCashDisbursement.Amount__c);
    }

    @isTest
    public static void testCreateFileSuccessForAccount_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users.get(1)) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
                List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id); 

                Cash_Disbursement_Batch__c newCDB = testData.cashDisbursementBatch[0].clone();
                newCDB.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newCDB;

                testData.cashDisbursements[0].Amount__c = 20;
                testData.cashDisbursements[0].Form_Category_Id__c = formCategories[0].Id;
                testData.cashDisbursements[0].Disbursement_Date__c = Date.newInstance(2020, 10, 1);
                update testData.cashDisbursements[0];

                Cash_Disbursement__c newCurrencyCD = testData.cashDisbursements[0].clone();
                newCurrencyCD.Cash_Disbursement_Batch__c = newCDB.Id;
                newCurrencyCD.put('CurrencyIsoCode', newCurrencyIsoCode);
                newCurrencyCD.Form_Category_Id__c = formCategories[0].Id;
                newCurrencyCD.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
                newCurrencyCD.Amount__c = 130;
                insert newCurrencyCD;

                
                Cash_Disbursement__c unCategorizedCashDisbursement = testData.cashDisbursements[1].clone();
                unCategorizedCashDisbursement.Amount__c = 20;
                unCategorizedCashDisbursement.Form_Category_Id__c = null;
                unCategorizedCashDisbursement.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
                insert unCategorizedCashDisbursement;

                testData.accounts[0].X1099_Vendor__c = true;
                update testData.accounts[0];


                Test.startTest();
                X1099File2Batch xb = new X1099File2Batch('2020', testData.ledgers[0].Id, formTypesAll[0].Id);
                Database.executeBatch(xb);
                Test.stopTest();

                System.assertEquals(2, X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.accounts[0].Id).size());

                System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(formCategories[0].Id), 
                testData.cashDisbursements[0].Ledger_Amount__c);
                System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(newCurrencyIsoCode).get(formCategories[0].Id), 
                newCurrencyCD.Ledger_Amount__c);
                System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(X1099File2Batch.NON_CATEGORIZED_PAYMENTS), 
                unCategorizedCashDisbursement.Ledger_Amount__c);

            }
        }
        catch (Exception ex) {

        }

    }

    @isTest
    public static void testCreateFileSuccessForContact_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users.get(1)) {

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
                List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id); 

                Cash_Disbursement_Batch__c newCDB = testData.cashDisbursementBatch[0].clone();
                newCDB.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newCDB;

                testData.cashDisbursements[1].Amount__c = 20;
                testData.cashDisbursements[1].Form_Category_Id__c = formCategories[0].Id;
                testData.cashDisbursements[1].Disbursement_Date__c = Date.newInstance(2020, 10, 1);
                update testData.cashDisbursements[1];


                Cash_Disbursement__c newCurrencyCD = testData.cashDisbursements[1].clone();
                newCurrencyCD.Cash_Disbursement_Batch__c = newCDB.Id;
                newCurrencyCD.put('CurrencyIsoCode', newCurrencyIsoCode);
                newCurrencyCD.Form_Category_Id__c = formCategories[0].Id;
                newCurrencyCD.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
                newCurrencyCD.Amount__c = 130;
                insert newCurrencyCD;

                Cash_Disbursement__c unCategorizedCashDisbursement = testData.cashDisbursements[1].clone();
                unCategorizedCashDisbursement.Amount__c = 20;
                unCategorizedCashDisbursement.Form_Category_Id__c = null;
                unCategorizedCashDisbursement.Disbursement_Date__c = Date.newInstance(2020, 10, 1);
                insert unCategorizedCashDisbursement;

                testData.contacts[0].X1099_Vendor__c = true;
                update testData.contacts[0];

                Test.startTest();
                X1099File2Batch xb = new X1099File2Batch('2020', testData.ledgers[0].Id, formCategories[0].Id);
                Database.executeBatch(xb);
                Test.stopTest();

                System.assertEquals(2, X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).size());

                System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(formCategories[0].Id), 
                testData.cashDisbursements[1].Ledger_Amount__c);

                System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(newCurrencyIsoCode).get(formCategories[0].Id), 
                newCurrencyCD.Ledger_Amount__c);

                System.assertEquals(X1099File2Batch.testpayeeIdToDisbursementAmountByCategory.get(testData.contacts[0].Id).get(MultiCurrencyHandler.CORPORATE_CURRENCY).get(X1099File2Batch.NON_CATEGORIZED_PAYMENTS), 
                unCategorizedCashDisbursement.Ledger_Amount__c);
            }
        }
        catch (Exception ex) {

        }
    }

}