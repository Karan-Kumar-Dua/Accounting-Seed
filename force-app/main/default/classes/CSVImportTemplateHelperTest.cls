@isTest
public class CSVImportTemplateHelperTest {
    
    @TestSetup
    static void makeData(){
        TestDataSuite.getInstance(true);
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            AcctSeed__Import_Template__c importTemplate = new AcctSeed__Import_Template__c();
            importTemplate.AcctSeed__Detail__c = 'AcctSeed__Recurring_Journal_Entry_Line__c';
            importTemplate.AcctSeed__Parent__c = 'AcctSeed__Recurring_Journal_Entry__c';
            importTemplate.AcctSeed__Headers__c = true;
            importTemplate.Name = 'Test Record';
            
            INSERT importTemplate;

            List<AcctSeed__Import_Field__c> fields = new List<AcctSeed__Import_Field__c>();
            AcctSeed__Import_Field__c field = new AcctSeed__Import_Field__c();

            field.AcctSeed__Import_Template__c = importTemplate.Id;
            field.AcctSeed__Target_Object__c = 'AcctSeed__Recurring_Journal_Entry_Line__c';
            field.AcctSeed__Target_Field__c = 'AcctSeed__Debit__c';
            field.AcctSeed__Column_Header__c = 'DEBIT';
            fields.add(field);

            field = new AcctSeed__Import_Field__c();
            field.AcctSeed__Import_Template__c = importTemplate.Id;
            field.AcctSeed__Target_Object__c = 'AcctSeed__Recurring_Journal_Entry_Line__c';
            field.AcctSeed__Target_Field__c = 'AcctSeed__Recurring_Journal_Entry__c';
            field.AcctSeed__Lookup_Type__c = 'Id';
            field.AcctSeed__Column_Header__c= 'RECURRING JOURNAL ENTRY';
            fields.add(field);

            INSERT fields;
        }
    }
    @isTest
    static void testGetImportTemplates(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Test.startTest();
            CSVImportTemplateHandler.ImportTemplate response = CSVImportTemplateHelper.getImportTemplate([SELECT Id FROM AcctSeed__Import_Template__c][0].id);
            Test.stopTest();
            System.assertEquals('Test Record',response.name);
            System.assertNotEquals(null,response);
        }
    }
    @isTest
    static void testGetImportTemplate(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Test.startTest();
            List<CSVImportTemplateHandler.ImportTemplate> response = CSVImportTemplateHelper.getImportTemplates('AcctSeed__Recurring_Journal_Entry_Line__c', 'AcctSeed__Recurring_Journal_Entry__c');
            Test.stopTest();
            System.assertEquals('Test Record',response[0].name);
            System.assertEquals(1,response.size());
        }
    }
    @isTest
    static void testGetImportFieldDefinitions(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            AcctSeed__Import_Template__c importTemplate = [SELECT Id FROM AcctSeed__Import_Template__c][0];
            Test.startTest();
            CSVImportTemplateService.CSVFieldMapper response = CSVImportTemplateHelper.getImportFieldDefinitions(String.valueOf(importTemplate.id));
            Test.stopTest();
            System.assertNotEquals(null,response.targetObjects);
            System.assertEquals(3,response.lookupTypes.size());
        }
    }
    @isTest
    static void testGetImportFields(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            AcctSeed__Import_Template__c importTemplate = [SELECT Id FROM AcctSeed__Import_Template__c][0];
            Test.startTest();
            List<CSVImportTemplateHandler.ImportFields> response = CSVImportTemplateHelper.getImportFields(String.valueOf(importTemplate.id),new String[]{'Debit','Recurring Journal Entry'},'');
            Test.stopTest();
            System.assertNotEquals(0, response.size());
            System.assertEquals(2, response.size());
            System.assertNotEquals(null, response[0].header);
            System.assertNotEquals(null, response[0].objectName);
        }
    }
    @isTest
    static void testGetImportFieldsWithNewParent(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            AcctSeed__Import_Template__c importTemplate = new AcctSeed__Import_Template__c();
            importTemplate.AcctSeed__Detail__c = 'AcctSeed__Recurring_Journal_Entry_Line__c';
            importTemplate.AcctSeed__Parent__c = 'AcctSeed__Recurring_Journal_Entry__c';
            importTemplate.AcctSeed__Headers__c = true;
            importTemplate.Name = 'Test Record 2';
            
            INSERT importTemplate;
            Test.startTest();
            List<CSVImportTemplateHandler.ImportFields> response = CSVImportTemplateHelper.getImportFields(importTemplate.Id,new String[]{'Debit','Recurring Journal Entry'},'');
            Test.stopTest();
            System.assertNotEquals(0, response.size());
            System.assertEquals(2, response.size());
            System.assertNotEquals(null, response[0].header);
            System.assertEquals(null, response[0].lookupType);
        }
    }
    @isTest
    static void testGetrecordIds(){
        TestDataSuite testData = TestDataSuite.getInstance().createConsolidationLedgers();
        System.runAs(testData.users.get(1)){
            AcctSeed__Recurring_Journal_Entry__c entry = new Recurring_Journal_Entry__c(
                Name = 'Test Entry',
                Next_Journal_Entry_Date__c = Date.newInstance(1991, 12, 31),
                Journal_Entry_Frequency__c = 'Monthly',
                Status__c = 'Active',
                Ledger__c = testData.ledgers[0].id,
                Reference__c = 'Test Reference 1'
            );
            INSERT entry;

            List<CSVImportTemplateHandler.Records> records = new List<CSVImportTemplateHandler.Records>();
            CSVImportTemplateHandler.Records record = new CSVImportTemplateHandler.Records();
            record.name='AcctSeed__Recurring_Journal_Entry__c';
            record.field='Name';
            record.value='Test Entry';
            record.targetField='AcctSeed__Recurring_Journal_Entry__c';
            records.add(record);
            
            Test.startTest();
            List<CSVImportTemplateHandler.Records> response = CSVImportTemplateHelper.getRecordIds(JSON.serialize(records));
            Test.stopTest();
            
            System.assertEquals('AcctSeed__Recurring_Journal_Entry__c',response[0].name);
            System.assertEquals('Test Entry',response[0].value);
            System.assertEquals('AcctSeed__Recurring_Journal_Entry__c',response[0].targetField);
            System.assertNotEquals(null, response[0].id);
        }
    }
    @isTest
    static void testImportChildRecord(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            List<AcctSeed__Import_Field__c> importFields = [SELECT ID, AcctSeed__Column_Header__c, AcctSeed__Target_Object__c, AcctSeed__Target_Field__c, Name ,
            AcctSeed__Lookup_Type__c,AcctSeed__Lookup_Field__c,AcctSeed__Key_Field__c,AcctSeed__Import_Template__c FROM AcctSeed__Import_Field__c];

            List<CSVImportTemplateHandler.ImportFields> importFieldMapper = new List<CSVImportTemplateHandler.ImportFields>();
            for(AcctSeed__Import_Field__c field : importFields){
                CSVImportTemplateHandler.ImportFields importField = new CSVImportTemplateHandler.ImportFields();
                importField.header = field.AcctSeed__Column_Header__c;
                importField.objectName = field.AcctSeed__Target_Object__c;
                importField.parentId = field.AcctSeed__Import_Template__c;
                importField.targetObject = field.AcctSeed__Target_Object__c;
                if(field.AcctSeed__Target_Field__c == 'AcctSeed__Debit__c'){
                    importField.targetField = 'AcctSeed__Credit__c';
                } 
                importField.lookupType = field.AcctSeed__Lookup_Type__c;
                importField.lookupField = field.AcctSeed__Lookup_Field__c;
                importField.id = field.id;
                importFieldMapper.add(importField);
            }

            List<Account> accs = new List<Account>();
            accs.add(new Account(Name = 'Test 1'));
            accs.add(new Account(Name = 'Test 2'));

            Test.startTest();
            CSVImportTemplateHandler.Response response = CSVImportTemplateHelper.importChildRecord(JSON.serialize(accs));
            List<String> response1 = CSVImportTemplateHelper.importFields(JSON.serialize(importFieldMapper));
            Test.stopTest();
            
            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response1);
        }
    }
}