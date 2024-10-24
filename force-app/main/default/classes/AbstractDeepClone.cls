public with sharing abstract class AbstractDeepClone {
    public class DeepCloneException extends Exception {}
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;

    private static final String RECURRING_BILLING_OBJECT = 'Recurring_Billing__c';
    private static final String RECURRING_PAYABLE_OBJECT = 'Recurring_Account_Payable__c';
    private static final String RECURRING_JOURNAL_ENTRY_OBJECT = 'Recurring_Journal_Entry__c';
    private static final String SALES_ORDER_OBJECT = 'Sales_Order__c';
    private static final String PURCHASE_ORDER_OBJECT = 'Purchase_Order__c';

    private static final String RECURRING_BILLING_LINE_OBJECT = 'Recurring_Billing_Line__c';
    private static final String RECURRING_PAYABLE_LINE_OBJECT = 'Recurring_Account_Payable_Line__c';
    private static final String RECURRING_JOURNAL_ENTRY_LINE_OBJECT = 'Recurring_Journal_Entry_Line__c';
    private static final String SALES_ORDER_LINE_OBJECT = 'Sales_Order_Line__c';
    private static final String PURCHASE_ORDER_LINE_OBJECT = 'Purchase_Order_Line__c';
    
    private static final Map<String,String> HEADER_LINE_MAP = new Map<String,String>{
        PACKAGE_QUALIFIER+RECURRING_BILLING_OBJECT => PACKAGE_QUALIFIER+RECURRING_BILLING_LINE_OBJECT,
        PACKAGE_QUALIFIER+RECURRING_PAYABLE_OBJECT => PACKAGE_QUALIFIER+RECURRING_PAYABLE_LINE_OBJECT,
        PACKAGE_QUALIFIER+RECURRING_JOURNAL_ENTRY_OBJECT => PACKAGE_QUALIFIER+RECURRING_JOURNAL_ENTRY_LINE_OBJECT,
        ERP_PACKAGE_QUALIFIER+SALES_ORDER_OBJECT => ERP_PACKAGE_QUALIFIER+SALES_ORDER_LINE_OBJECT,
        ERP_PACKAGE_QUALIFIER+PURCHASE_ORDER_OBJECT => ERP_PACKAGE_QUALIFIER+PURCHASE_ORDER_LINE_OBJECT
    };

    public abstract Id clone(Id headerId, Map<String,Object> headerFieldOverrides);
    public abstract List<String> getFields();

    public static AbstractDeepClone getInstance(Id headerId){
        String objectName = headerId.getSObjectType().getDescribe().getName();
        AbstractDeepClone adc;
        if(objectName == PACKAGE_QUALIFIER+RECURRING_BILLING_OBJECT){
            adc = new RecurringBillingDeepClone();
        }
        else if(objectName == PACKAGE_QUALIFIER+RECURRING_JOURNAL_ENTRY_OBJECT){
            adc = new RecurringJournalEntryDeepClone();
        }
        else if(objectName == PACKAGE_QUALIFIER+RECURRING_PAYABLE_OBJECT){
            adc = new RecurringAccountPayableDeepClone();
        }
        else if(objectName == ERP_PACKAGE_QUALIFIER+SALES_ORDER_OBJECT){
            adc = new SalesOrderDeepClone();
        }
        else{
            adc = new PurchaseOrderDeepClone();
        } 
        return adc;
    }

    protected SObject getHeader(Id sourceId){
        SObjectType sObjType = sourceId.getSObjectType();
        List<String> fieldnames = new List<String>(getFieldNames(sObjType));
        String query = new SOQLBuilder(sObjType)
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(fieldnames)
                .setCondition('Id = :sourceId LIMIT 1')
                .toSOQL();
        SObject src = Database.query(query);
        SObject target = src.clone(false,false,false,false);
        return target;

    }

    protected List<SObject> getLinesClone(Id headerId){
        SObjectType headerObjType = headerId.getSObjectType();
        String headerObjectName = headerObjType.getDescribe().getName();
        String lineObjectName = HEADER_LINE_MAP.get(headerObjectName);
        SObjectType lineObjectType = ((SObject)Type.forName('Schema', lineObjectName).newInstance()).getSObjectType();
        List<String> fieldnames = new List<String>(getFieldNames(lineObjectType));
        String query = new SOQLBuilder(lineObjectType)
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(fieldnames)
                .setCondition(headerObjectName+' = :headerId')
                .toSOQL();
        List<SObject> sourceList = Database.query(query);
        List<SObject> targetList = new List<SObject>();
        for(SObject obj : sourceList){
            SObject tObj = obj.clone(false,false,false,false);
            targetList.add(tObj);
        }
        return targetList;
    }

    protected Set<String> getFieldNames(SObjectType sObjType){
        Map<String, Schema.SObjectField> fields = sObjType.getDescribe().fields.getMap();
        Set<String> fieldnames = new Set<String>();
        for (String fieldname : fields.keySet()) {
            Schema.DescribeFieldResult field = fields.get(fieldname).getDescribe();
            if (field.isUpdateable() == true && field.isCreateable() == true && field.isUnique() == false) {
                fieldnames.add(field.getName());
            }
        }
        return fieldnames;
    }
}