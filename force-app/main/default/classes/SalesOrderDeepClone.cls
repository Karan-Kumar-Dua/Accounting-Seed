public with sharing class SalesOrderDeepClone extends AbstractDeepClone {
    //Todo: Need to add ERP Package name as String
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
            lineObject.put(ERP_PACKAGE_QUALIFIER + 'Sales_Order__c', headerObject.Id);
            updatedObjectList.add(lineObject);
        }
        return updatedObjectList;
    }
    public override List<String> getFields(){
        List<String> fields = new List<String>();
        if(MultiCurrencyHandler.isMultiCurrencyEnabled){
            fields.add('CurrencyIsoCode');
        }
        return fields;
    }

    public override Id clone(Id headerId, Map<String,Object> headerFieldOverrides){
        Savepoint sp = Database.setSavepoint();
        try {
            SObject clonedObject = getHeader(headerId);
            clonedObject = setHeader(clonedObject, headerFieldOverrides);
            SFDCSecurityUtils.insertProxy(clonedObject);
            List<SObject> clonedLinesObject = getLinesClone(headerId);
            clonedLinesObject = setLines(clonedLinesObject, clonedObject);
            SFDCSecurityUtils.insertProxy(clonedLinesObject);
            return clonedObject.Id;
        } catch(Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }
}