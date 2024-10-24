@isTest
public with sharing class XChildRelationshipPicklistTest {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @isTest
    private static void testGetValues() {
        VisualEditor.DesignTimePageContext context = new VisualEditor.DesignTimePageContext();
        context.entityName = PACKAGE_QUALIFIER + 'Billing__c';
        XChildRelationshipPicklist inst = new XChildRelationshipPicklist(context);
        Test.startTest();
        VisualEditor.Datarow defaultValue = inst.getDefaultValue();
        VisualEditor.DynamicPickListRows childRelationshipValues = inst.getValues();
        Test.stopTest();
        System.assertEquals('Id', defaultValue.getValue());
        System.assertEquals('Id', defaultValue.getLabel());
        System.assertEquals(false, defaultValue.isSelected());
        System.assertNotEquals(0,childRelationshipValues.size());
        System.assertNotEquals(null,childRelationshipValues.getDataRows());
        System.assertEquals(true,childRelationshipValues.containsAllRows());
    }
}