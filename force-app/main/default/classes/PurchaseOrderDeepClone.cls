public with sharing class PurchaseOrderDeepClone extends AbstractDeepClone {
    private static final String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    private SObject setHeader(SObject headerObject, Map<String,Object> fieldMap){
        for(String key : fieldMap.keySet()){
            headerObject.put(key, fieldMap.get(key));
        }
        return headerObject;
    }
    private List<SObject> setLines(List<SObject> objectList, SObject headerObject){
        List<SObject> updatedObjectList = new List<SObject>();
        for(SObject lineObject : objectList){
            lineObject.put(ERP_PACKAGE_QUALIFIER + 'Purchase_Order__c', headerObject.Id);
            updatedObjectList.add(lineObject);
        }
        return updatedObjectList;
    }

    private Boolean getAccountingPeriodStatus(Map<String,Object> headerFieldOverrides){
        Date orderDate = Date.valueOf(headerFieldOverrides.get(ERP_PACKAGE_QUALIFIER + 'Order_Date__c'));
        Accounting_Period__c period = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(orderDate, AccountingPeriodActions.OPEN_STATUS);
        Boolean status;
        if(period != null && period.Status__c == AccountingPeriodActions.OPEN_STATUS){
            status = true;
        }
        else{
            status = false;
        }
        return status;
    }

    public override List<String> getFields(){
        List<String> fields = new List<String>();
        fields.add(ERP_PACKAGE_QUALIFIER + 'Order_Date__c');
        if(MultiCurrencyHandler.isMultiCurrencyEnabled){
            fields.add('CurrencyIsoCode');
        }
        return fields;
    }

    public override Id clone(Id headerId, Map<String,Object> headerFieldOverrides){
        Savepoint sp = Database.setSavepoint();
        try {
            if(getAccountingPeriodStatus(headerFieldOverrides)){
                SObject clonedObject = getHeader(headerId);
                clonedObject = setHeader(clonedObject, headerFieldOverrides);
                SFDCSecurityUtils.insertProxy(clonedObject);
                List<SObject> clonedLinesObject = getLinesClone(headerId);
                clonedLinesObject = setLines(clonedLinesObject, clonedObject);
                SFDCSecurityUtils.insertProxy(clonedLinesObject);
                return clonedObject.Id;
            }
            else{
                String dateLabel = Label.COMMON_ORDER_DATE;
                Date dateValue = Date.valueOf(headerFieldOverrides.get(ERP_PACKAGE_QUALIFIER + 'Order_Date__c'));
                String message = System.Label.ERR_RECURRING_DEEP_CLONE_ACCOUNTING_PERIOD;
                message = message.replace('{0}', String.valueOf(dateLabel));
                message = message.replace('{1}', String.valueOf(dateValue));
                throw new DeepCloneException(message);
            }
        } catch(Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }
}