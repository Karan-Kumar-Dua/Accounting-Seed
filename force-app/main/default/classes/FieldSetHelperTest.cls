@IsTest
public with sharing class FieldSetHelperTest {
    private static FieldSetHandler.FieldSetResponse fieldSetData;
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetColumns() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        
        System.runAs(testData.users[1]) {
            Schema.SObjectType SObjectTypeObj = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Billing__c');
            Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
            Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(PACKAGE_QUALIFIER + 'MassAddEditRows');

            FieldSetHandler.FieldSetRequest fsRequest = new FieldSetHandler.FieldSetRequest();
            fsRequest.sObjectName = PACKAGE_QUALIFIER + 'Billing__c.'+ PACKAGE_QUALIFIER + 'Billing_Line__c';
            fsRequest.mainFieldSetName = PACKAGE_QUALIFIER + 'MassAddEditRows';
            fsRequest.extraFieldSetName = PACKAGE_QUALIFIER + 'CreditMemoApply';
            fsRequest.reOrderFieldName = '';
            fsRequest.subquerySObjectName = '';
            fsRequest.subqueryRelationshipName = '';
            fsRequest.subqueryRelationshipFieldset = '';

            fieldSetData = FieldSetHelper.getColumns(JSON.serialize(fsRequest));
            for(schema.FieldSetMember FSM : fieldSetObj.getFields()){
                System.assertEquals(true, fieldSetData.fieldNames.contains(FSM.getFieldPath()), 'Fieldset field not found in fieldset collection');
            }
        } 
    }
    @isTest
    private static void testGetQueryString(){
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        String valuesFromQueryString = '';
        Test.startTest();

        FieldSetHandler.FieldSetRequest fsRequest = new FieldSetHandler.FieldSetRequest();
        fsRequest.sObjectName = PACKAGE_QUALIFIER + 'Recurring_Journal_Entry_Line__c.'+ PACKAGE_QUALIFIER + 'Recurring_Journal_Entry__c';
        fsRequest.mainFieldSetName = PACKAGE_QUALIFIER + 'Advanced_Line_Manager_Columns';
        fsRequest.extraFieldSetName = PACKAGE_QUALIFIER + 'Advanced_Line_Manager_Columns_Drawer';
        fsRequest.reOrderFieldName = '';
        fsRequest.subquerySObjectName = '';
        fsRequest.subqueryRelationshipName = '';
        fsRequest.subqueryRelationshipFieldset = '';
        fsRequest.filter = testData.billings[0].Id;

        valuesFromQueryString = FieldSetHelper.getQueryString(JSON.serialize(fsRequest));

        Schema.DescribeFieldResult describeResult = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Billing__c').getDescribe().fields.getMap().get('AcctSeed__Credit_Memo_Reason__c').getDescribe();
        FieldSetHandler fsh = new FieldSetHandler();
        fsh.dependentPicklistEntries(describeResult);
        Test.stopTest();

        System.assertNotEquals('', valuesFromQueryString);
        System.assertNotEquals(0, valuesFromQueryString.length());
    }
    @IsTest
    private static void testGetColumnsWithSubGrid() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        
        System.runAs(testData.users[1]) {
            Schema.SObjectType SObjectTypeObj = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Account_Payable__c');
            Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
            Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(PACKAGE_QUALIFIER + 'MassAddEditRows');

            FieldSetHandler.FieldSetRequest fsRequest = new FieldSetHandler.FieldSetRequest();
            fsRequest.sObjectName = PACKAGE_QUALIFIER + 'Account_Payable__c.'+ PACKAGE_QUALIFIER + 'Account_Payable_Line__c';
            fsRequest.mainFieldSetName = PACKAGE_QUALIFIER + 'MassAddEditRows';
            fsRequest.extraFieldSetName = PACKAGE_QUALIFIER + 'MassAddEditRows';
            fsRequest.reOrderFieldName = '';
            fsRequest.subquerySObjectName = PACKAGE_QUALIFIER + 'Account_Payable_Line__c';
            fsRequest.subqueryRelationshipName = PACKAGE_QUALIFIER + 'Account_Payable_Line__r';
            fsRequest.subqueryRelationshipFieldset = PACKAGE_QUALIFIER +  'MassAddEditRows';

            fieldSetData = FieldSetHelper.getColumns(JSON.serialize(fsRequest));

            Assert.areNotEqual(null,fieldSetData.subGridColumns);
            Assert.areEqual(false,fieldSetData.subGridFieldNames.isEmpty());
            for(schema.FieldSetMember FSM : fieldSetObj.getFields()){
                Assert.areEqual(true, fieldSetData.fieldNames.contains(FSM.getFieldPath()), 'Fieldset field not found in fieldset collection');
            }
        } 
    }
    @IsTest
    private static void testGetColumnsWithSubGridQueryString() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        
        System.runAs(testData.users[1]) {
            Schema.SObjectType SObjectTypeObj = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Account_Payable__c');
            Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
            Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(PACKAGE_QUALIFIER + 'MassAddEditRows');

            FieldSetHandler.FieldSetRequest fsRequest = new FieldSetHandler.FieldSetRequest();
            fsRequest.sObjectName = PACKAGE_QUALIFIER + 'Account_Payable__c.'+ PACKAGE_QUALIFIER + 'Account_Payable_Line__c';
            fsRequest.mainFieldSetName = PACKAGE_QUALIFIER + 'MassAddEditRows';
            fsRequest.extraFieldSetName = PACKAGE_QUALIFIER + 'MassAddEditRows';
            fsRequest.reOrderFieldName = '';
            fsRequest.subquerySObjectName = PACKAGE_QUALIFIER + 'Account_Payable_Line__c';
            fsRequest.subqueryRelationshipName = PACKAGE_QUALIFIER + 'Account_Payable_Line__r';
            fsRequest.subqueryRelationshipFieldset = PACKAGE_QUALIFIER +  'MassAddEditRows';

            String valuesFromQueryString = FieldSetHelper.getQueryString(JSON.serialize(fsRequest));
            Assert.areNotEqual(true,String.isBlank(valuesFromQueryString));
            Assert.areEqual(true,valuesFromQueryString.contains(fsRequest.subqueryRelationshipName));
        } 
    }
}