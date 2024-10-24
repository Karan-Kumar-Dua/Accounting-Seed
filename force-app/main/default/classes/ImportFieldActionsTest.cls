@IsTest
public with sharing class ImportFieldActionsTest {
    @TestSetup
    static void makeData(){
        TestDataSuite.getInstance(true);
    }
    @IsTest
    static void testHandleBeforeInsert(){
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)){
            Test.startTest();
            Import_Template__c temp = new Import_Template__c(Name = 'Test');
            INSERT temp;

            List<Import_Field__c> fields = new List<Import_Field__c>();
            for(Integer i = 0; i< 3;i++){
                fields.add(new Import_Field__c(Import_Template__c = temp.id,Target_Object__c = 'AcctSeed__Recurring_Account_Payable_Line__c', Target_Field__c = 'Test Field', Column_Header__c = 'Name', Column_Index__c = i));
            }

            INSERT fields;
            Test.stopTest();
            
            for(Import_Field__c field : [SELECT Id, Import_Key__c FROM Import_Field__c]){
                System.assertEquals('Test|AcctSeed__Recurring_Account_Payable_Line__c|Test Field', field.Import_Key__c);
            }
        }
    }
}