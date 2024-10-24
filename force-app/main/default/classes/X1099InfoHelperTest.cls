@IsTest
public with sharing class X1099InfoHelperTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetFormTypes() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(NULL);
            List<Form_Type__mdt> allFormTypes = [SELECT Id from Form_Type__mdt];
            system.assertEquals(formTypesAll.size(), allFormTypes.size());

            List<Form_Type__mdt> formTypes2020 = X1099InfoHelper.getFormTypes(2020);
            List<Form_Type__mdt> formTypes2020Queried = [Select Id from Form_Type__mdt WHERE Effective_Year__c <= 2020];
            system.assertEquals(formTypes2020.size(), formTypes2020Queried.size());
            
        }
    } 

    @IsTest
    static void testGetFormCategoriesMap() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Map<Id, Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesMap();
            for (Form_Category__mdt category : [Select Id from Form_Category__mdt]) {
                System.assertEquals(true, formCategories.containsKey(category.Id));
            }
        }
    }
    
    @IsTest
    static void testGetFormCategoriesByFormType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            Map<String, Integer> formCategoryCountsByFormType = new Map<String, Integer>();
            for (Form_Category__mdt category : [SELECT Id, Form_Type__c from Form_Category__mdt]) {
                Integer typeCount = 0;
                if (formCategoryCountsByFormType.containsKey(category.Form_Type__c)) {
                    typeCount = formCategoryCountsByFormType.get(category.Form_Type__c) + 1;
                } else {
                    typeCount++;
                }
                formCategoryCountsByFormType.put(category.Form_Type__c, typeCount);
            }
            test.startTest();            
            system.assertEquals(0, X1099InfoHelper.getFormCategoriesByFormType('').size());

            for (Form_Type__mdt type : [SELECT Id FROM Form_Type__mdt]) {
                system.assertEquals(X1099InfoHelper.getFormCategoriesByFormType(type.Id).size(), formCategoryCountsByFormType.get(type.Id));
            }
        }
    } 

    @IsTest
    static void testAccountGetSingleRecordValues() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            
            test.startTest();            
            List<Id> accountIds = new List<Id>{testData.accounts[0].Id};
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( accountIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    formCategories[0].Id, 
                                                                    '123');
            system.assertEquals(true, sr.isSuccess);
            X1099InfoHelper.X1099Response acctResponseAfterSave = X1099InfoHelper.getSingleRecordValues(testData.accounts[0].Id);
            system.assertEquals(acctResponseAfterSave.isSuccess, true);
            system.assertEquals(acctResponseAfterSave.errors, NULL);
            system.assertEquals(acctResponseAfterSave.X1099Vendor, true);
            system.assertEquals(acctResponseAfterSave.taxpayerId, '123');
            system.assertEquals(acctResponseAfterSave.default1099Box, formCategories[0].Id);
            system.assertEquals(acctResponseAfterSave.default1099Type, formTypesAll[0].Id);
        }
    }

    @IsTest
    static void testContactGetSingleRecordValues() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            
            test.startTest();            
            List<Id> contactIds = new List<Id>{testData.contacts[0].Id};
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( contactIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    formCategories[0].Id, 
                                                                    '123');
            system.assertEquals(true, sr.isSuccess);
            X1099InfoHelper.X1099Response contResponseAfterSave = X1099InfoHelper.getSingleRecordValues(testData.contacts[0].Id);
            system.assertEquals(contResponseAfterSave.isSuccess, true);
            system.assertEquals(contResponseAfterSave.errors, NULL);
            system.assertEquals(contResponseAfterSave.X1099Vendor, true);
            system.assertEquals(contResponseAfterSave.taxpayerId, '123');
            system.assertEquals(contResponseAfterSave.default1099Box, formCategories[0].Id);
            system.assertEquals(contResponseAfterSave.default1099Type, formTypesAll[0].Id);
        }
    }

    @IsTest
    static void testGetSingleRecordValuesError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            
            test.startTest();            
            X1099InfoHelper.X1099Response response = X1099InfoHelper.getSingleRecordValues('123000000000000000');
            system.assertEquals(response.isSuccess, false);
            system.assertNotEquals(response.errors.size(), 0);
            system.assertEquals(response.X1099Vendor, NULL);
            system.assertEquals(response.taxpayerId, NULL);
            system.assertEquals(response.default1099Box, NULL);
            system.assertEquals(response.default1099Type, NULL);
        }
    }

    @IsTest
    static void testValidateFormTypeForDistributionDate() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Map<Id, Form_Type__mdt> types = new Map<Id, Form_Type__mdt>([SELECT Id, Effective_Year__c FROM Form_Type__mdt ]);

        System.runAs(testData.users[1]) {

            test.startTest();
            //test true return
            for (Id typeId : types.keyset()) {
                Integer effectiveYear = (Integer)types.get(typeId).Effective_Year__c;
                System.assertEquals(true, X1099InfoHelper.validateFormTypeForDistributionDate(typeId, Date.newInstance(effectiveYear, 1, 1)));
            }

            //test false return
            System.assertEquals(false, X1099InfoHelper.validateFormTypeForDistributionDate(new list<Id>(types.keyset())[0], Date.newInstance(1000, 1, 1)));
        }
    }

    //******************************** Save Methods *****************************//

    @IsTest
    static void testSaveAccountsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> accountIds = new List<Id>();
            for (Account acct : testData.accounts) {
                accountIds.add(acct.Id);
            }
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( accountIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    formCategories[0].Id, 
                                                                    '123');
            system.assertEquals(true, sr.IsSuccess);        
            system.assertEquals(testData.accounts.size(), sr.successfulRecordCount);    
            List<Account> accountsToTest = [SELECT 
                                                Id, 
                                                X1099_Vendor__c, 
                                                Default_Form_1099_Box__c, 
                                                Taxpayer_Identification_Number__c 
                                            FROM 
                                                Account 
                                            WHERE 
                                                Id IN :accountIds];
            for (Account a : accountsToTest) {
                system.assertEquals(true, a.X1099_Vendor__c);
                system.assertEquals(formTypesAll[0].Label + ' - ' + formCategories[0].Label, a.Default_Form_1099_Box__c);
                system.assertEquals(NULL, a.Taxpayer_Identification_Number__c);
            }
        }
    } 

    @IsTest
    static void testSaveContactsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>();
            for (Contact cont : testData.contacts) {
                contactIds.add(cont.Id);
            }
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( contactIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    formCategories[0].Id, 
                                                                    '123');
            system.assertEquals(true, sr.IsSuccess);            
            system.assertEquals(testData.contacts.size(), sr.successfulRecordCount);    
            List<Contact> contactsToTest = [SELECT 
                                                Id, 
                                                X1099_Vendor__c, 
                                                Default_Form_1099_Box__c, 
                                                Taxpayer_Identification_Number__c
                                            FROM 
                                                Contact 
                                            WHERE 
                                                Id IN :contactIds];
            for (Contact c : contactsToTest) {
                system.assertEquals(true, c.X1099_Vendor__c);
                system.assertEquals(formTypesAll[0].Label + ' - ' + formCategories[0].Label, c.Default_Form_1099_Box__c);
                system.assertEquals(NULL, c.Taxpayer_Identification_Number__c);
            }
        }
    } 

    @IsTest
    static void testSaveTypeWithBlankBoxId() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>();
            for (Contact cont : testData.contacts) {
                contactIds.add(cont.Id);
            }
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( contactIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    '', 
                                                                    '123');
            system.assertEquals(false, sr.IsSuccess);            
            system.assertEquals(0, sr.successfulRecordCount);                
            for (String error : sr.errors) {
                system.assertEquals(X1099InfoHelper.SAVE_ERROR, error);
            }
        }
    } 

    @IsTest
    static void testSaveSingleAccountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> accountIds = new List<Id>{testData.accounts[0].Id};
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( accountIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    formCategories[0].Id, 
                                                                    '123');
            system.assertEquals(true, sr.IsSuccess);        
            system.assertEquals(1, sr.successfulRecordCount);    
            List<Account> accountsToTest = [SELECT 
                                                Id, 
                                                X1099_Vendor__c,
                                                Default_Form_1099_Box__c, 
                                                Taxpayer_Identification_Number__c 
                                            FROM 
                                                Account];
            for (Account a : accountsToTest) {
                if (a.Id == testData.accounts[0].Id) {
                    system.assertEquals(true, a.X1099_Vendor__c);
                    system.assertEquals(formTypesAll[0].Label + ' - ' + formCategories[0].Label, a.Default_Form_1099_Box__c);
                    system.assertEquals('123', a.Taxpayer_Identification_Number__c);
                } else {
                    system.assertEquals(false, a.X1099_Vendor__c);
                    system.assertEquals(NULL, a.Default_Form_1099_Box__c);
                    system.assertEquals(NULL, a.Taxpayer_Identification_Number__c);
                }
            }
        }
    } 

    @IsTest
    static void testSaveSingleContactSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>{testData.contacts[0].Id};
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( contactIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    formCategories[0].Id, 
                                                                    '123');
            system.assertEquals(true, sr.IsSuccess);            
            system.assertEquals(1, sr.successfulRecordCount);    
            List<Contact> contactsToTest = [SELECT 
                                                Id, 
                                                X1099_Vendor__c, 
                                                Default_Form_1099_Box__c, 
                                                Taxpayer_Identification_Number__c
                                            FROM 
                                                Contact];
            for (Contact c : contactsToTest) {
                
                if (c.Id == testData.contacts[0].Id) {
                    system.assertEquals(true, c.X1099_Vendor__c);
                    system.assertEquals(formTypesAll[0].Label + ' - ' + formCategories[0].Label, c.Default_Form_1099_Box__c);
                    system.assertEquals('123', c.Taxpayer_Identification_Number__c);
                } else {
                    system.assertEquals(false, c.X1099_Vendor__c);
                    system.assertEquals(NULL, c.Default_Form_1099_Box__c);
                    system.assertEquals(NULL, c.Taxpayer_Identification_Number__c);
                }                
            }
        }
    } 

    @IsTest
    static void testSaveSingleRecordTypeWithBlankBoxId() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>{testData.contacts[0].Id};
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save( contactIds, 
                                                                    true, 
                                                                    formTypesAll[0].Id, 
                                                                    '', 
                                                                    '123');
            system.assertEquals(false, sr.IsSuccess);            
            system.assertEquals(0, sr.successfulRecordCount);    
            system.assertEquals(X1099InfoHelper.SAVE_ERROR, sr.errors[0]);            
        }
    } 

    @IsTest
    static void testSaveNoRecordIds() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>();
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save(contactIds, true, formTypesAll[0].Id, formCategories[0].Id, '');
            system.assertEquals(true, sr.IsSuccess);            
            system.assertEquals(0, sr.successfulRecordCount);    
        }
    } 

    @IsTest
    static void testSaveBadData() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>();
            for (Contact cont : testData.contacts) {
                contactIds.add(cont.Id);
            }

            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save(contactIds, true, '123', '123', '');
            system.assertEquals(false, sr.IsSuccess);            
            system.assertEquals(0, sr.successfulRecordCount);    
            system.assertEquals(false, sr.errors.isEmpty());
        }
    }

    @IsTest
    static void testPartialSave() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>();
            List<Contact> additionalContacts = new List<Contact>();
            for (Integer i = 0; i < 3; i++) {
                additionalContacts.add(new Contact(
                    LastName = 'Bad Contact - ' + i
                ));
            }
            insert additionalContacts;

            for (Contact cont : additionalContacts) {
                contactIds.add(cont.Id);
            }
            
            //force an error by deleting the first contact, but keep the Ids in the list
            delete additionalContacts[0];

            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);    
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);                  
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save(contactIds, true, formTypesAll[0].Id, formCategories[0].Id, '');            
            system.assertEquals(false, sr.IsSuccess);            
            system.assertEquals(2, sr.successfulRecordCount);    
            system.assertEquals(false, sr.errors.isEmpty());
            system.assertEquals(1, sr.errors.size()); 
        }
    } 

    @IsTest
    static void testPartialSaveOver5() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {            
            List<Id> contactIds = new List<Id>();
            List<Contact> additionalContacts = new List<Contact>();
            for (Integer i = 0; i < 10; i++) {
                additionalContacts.add(new Contact(
                    LastName = 'Bad Contact - ' + i
                ));
            }
            insert additionalContacts;

            for (Contact cont : additionalContacts) {
                contactIds.add(cont.Id);
            }
            
            //force an error by deleting the first 7 contacts, but keep the Ids in the list
            List<Contact> deleteContacts = new List<Contact>();
            for (Integer i = 0; i < 7; i++) {
                deleteContacts.add(additionalContacts[i]);
            }
            delete deleteContacts;

            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);  
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);          
            test.startTest();
            X1099InfoHelper.SaveResponse sr = X1099InfoHelper.save(contactIds, true, formTypesAll[0].Id, formCategories[0].Id, '');
            system.assertEquals(false, sr.IsSuccess);            
            system.assertEquals(3, sr.successfulRecordCount);    
            system.assertEquals(false, sr.errors.isEmpty());
            system.assertEquals(6, sr.errors.size()); //anything over 5 adds an additional catch-all error 
        }
    } 

    @IsTest
    static void testGet1099InfoForCD() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {  
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(formTypesAll[0].Id);
            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            cd.Form_Category_Id__c = formCategories[0].Id;
            cd.Disbursement_Date__c = Date.newInstance(2020, 1, 1);
            update cd;

            Test.startTest();              

            X1099InfoHelper.X1099Response resp = X1099InfoHelper.get1099InfoForCD(cd.Id);
            
            Test.stopTest();

            system.assertEquals(resp.isSuccess, true);
            system.assertEquals(resp.errors, NULL);
            system.assertEquals(resp.default1099Box, formCategories[0].Id);
            system.assertEquals(resp.default1099Type, formTypesAll[0].Id);
        }
    }

    @IsTest
    static void testGet1099InfoForCDError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {  
            Test.startTest();              

            X1099InfoHelper.X1099Response resp = X1099InfoHelper.get1099InfoForCD(FinancialSuiteUtils.getFakeId(Cash_Disbursement__c.SObjectType));
            
            Test.stopTest();

            system.assertEquals(resp.isSuccess, false);
            system.assertNotEquals(resp.errors.size(), 0);
            system.assertEquals(resp.default1099Box, null);
            system.assertEquals(resp.default1099Type, null);
        }
    }

    @IsTest
    static void testSave1099InfoForCDs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {  
            
            List<Id> recordIds = new List<Id>();
            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                cd.Disbursement_Date__c = Date.newInstance(2020, 1, 1);
                recordIds.add(cd.Id);
            }
            update testData.cashDisbursements;
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            String form1099TypeId = formTypesAll[0].Id;

            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(form1099TypeId);
            String form1099BoxId = formCategories[0].Id;

            Test.startTest();              
            X1099InfoHelper.SaveResponse resp = X1099InfoHelper.save1099InfoForCDs(
                recordIds, 
                form1099TypeId, 
                form1099BoxId
            );
            Test.stopTest();

            System.assert(resp.isSuccess);
            String expectedLabel = formTypesAll[0].Label + ' - ' + formCategories[0].Label;
            for (Cash_Disbursement__c cd : [
                SELECT 
                    Form_Category_Id__c, 
                    Form_1099_Box__c
                FROM Cash_Disbursement__c
                WHERE Id IN :recordIds
            ]) {
                System.assertEquals(form1099BoxId, cd.Form_Category_Id__c);
                System.assertEquals(expectedLabel, cd.Form_1099_Box__c);
            }
        }
    }

    @IsTest
    static void testSave1099InfoForCDsWithBlankBox() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {  
            List<Id> recordIds = new List<Id>{ testData.cashDisbursements[0].Id };
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            String form1099TypeId = formTypesAll[0].Id;
            String form1099BoxId = null;

            Test.startTest();              
            X1099InfoHelper.SaveResponse resp = X1099InfoHelper.save1099InfoForCDs(
                recordIds, 
                form1099TypeId, 
                form1099BoxId
            );
            Test.stopTest();

            system.assertEquals(false, resp.IsSuccess);            
            system.assertEquals(0, resp.successfulRecordCount);                
            for (String error : resp.errors) {
                system.assertEquals(X1099InfoHelper.SAVE_ERROR, error);
            }
        }
    }

    @IsTest
    static void testSave1099InfoForCDsWithZeroRecords() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {  
            List<Id> recordIds = new List<Id>();
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            String form1099TypeId = formTypesAll[0].Id;

            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(form1099TypeId);
            String form1099BoxId = formCategories[0].Id;

            Test.startTest();              
            X1099InfoHelper.SaveResponse resp = X1099InfoHelper.save1099InfoForCDs(
                recordIds, 
                form1099TypeId, 
                form1099BoxId
            );
            Test.stopTest();

            system.assertEquals(true, resp.IsSuccess);            
            system.assertEquals(0, resp.successfulRecordCount);                
        }
    }

    @IsTest
    static void testSave1099InfoForCDsWithPartialSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {  
            
            List<Id> recordIds = new List<Id>();
            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                recordIds.add(cd.Id);
                cd.Disbursement_Date__c = Date.newInstance(2020, 1, 1);
            }
            testData.cashDisbursements[0].Disbursement_Date__c = Date.newInstance(2019, 1, 1);
            update testData.cashDisbursements;
            
            List<Form_Type__mdt> formTypesAll = X1099InfoHelper.getFormTypes(2020);
            String form1099TypeId = formTypesAll[0].Id;

            List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(form1099TypeId);
            String form1099BoxId = formCategories[0].Id;

            Test.startTest();              
            X1099InfoHelper.SaveResponse resp = X1099InfoHelper.save1099InfoForCDs(
                recordIds, 
                form1099TypeId, 
                form1099BoxId
            );
            Test.stopTest();

            System.assertEquals(false, resp.isSuccess);
            System.assertEquals(recordIds.size() - 1, resp.successfulRecordCount);    
            System.assertEquals(false, resp.errors.isEmpty());
            System.assertEquals(1, resp.errors.size());
        }
    }

}