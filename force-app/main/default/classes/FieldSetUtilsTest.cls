@IsTest
public with sharing class FieldSetUtilsTest {
    private static FieldSetUtils.DataTableResponse fieldSetData;
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static Billing__c getBilling(Id billingId, list<string> FieldsetFields) {
        return getBillings(new List<Id> { billingId }, FieldsetFields).get(0);
    }

    private static List<Billing__c> getBillings(List<Id> billingIds, list<string> FieldsetFields) {
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'Type__c',
            'Accounting_Period__c',
            'Date__c',
            'LastModifiedDate'
        };
        queryFields.addall(FieldsetFields);
        String queryCondition = 'Id IN :billingIds';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    private static List<String> getignoredFields(){
        return new List<String>{ 'Name'};
    } 

    //look into creating fielset via APi
    @IsTest
    private static void testGetFieldSetData() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        
        System.runAs(testData.users[1]) {
            Schema.SObjectType SObjectTypeObj = Schema.getGlobalDescribe().get(PACKAGE_QUALIFIER + 'Billing__c');
            Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
            Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldsets.getMap().get(PACKAGE_QUALIFIER + 'CashReceiptApply');

            //testing with existing fieldset.  It is referenced in LWC helpers so if it is missing a failed test wopuld be expected
            fieldSetData = FieldSetUtils.getColumnsFromFieldSet(
                PACKAGE_QUALIFIER + 'Billing__c',
                PACKAGE_QUALIFIER + 'CashReceiptApply',
                getignoredFields()
            );

            for(schema.FieldSetMember FSM : fieldSetObj.getFields()){
                if(!getignoredFields().contains(FSM.getFieldPath())){
                    System.assertEquals(true, fieldSetData.fieldNames.contains(FSM.getFieldPath()), 'Fieldset field not found in fieldset collection');
                }
            }

            Billing__c credit = getBilling(testData.billings[2].Id, fieldSetData.fieldNames);
            Map<String, Object> FieldSetValuesFromString = new Map<String, Object>();
            Map<String, Object> FieldSetValuesFromDatatable = new Map<String, Object>();

            Test.startTest();
            FieldSetValuesFromString = FieldSetUtils.getFieldSetData(fieldSetData.fieldNames, credit);
            FieldSetValuesFromDatatable = FieldSetUtils.getFieldSetData(fieldSetData, credit);
            Test.stopTest();

            System.assertNotEquals(0, FieldSetValuesFromString.size());
            System.assertNotEquals(0, FieldSetValuesFromDatatable.size());
        }
       
    }
}