public with sharing class RecurringBillingDeepClone extends AbstractDeepClone {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private SObject setHeader(SObject headerObject, Map<String,Object> fieldMap){
        for(String key : fieldMap.keySet()){
            headerObject.put(key, fieldMap.get(key));
        }
        headerObject.put('End_Date__c', null);
        headerObject.put('Exclude_From_Automation__c', false);
        headerObject.put('Last_Billing_Date__c', null);
        headerObject.put('Status__c', 'Active');
        return headerObject;
    }
    private List<SObject> setLines(List<SObject> objectList, SObject headerObject){
        List<SObject> updatedObjectList = new List<SObject>();
        for(SObject lineObject : objectList){
            lineObject.put('Recurring_Billing__c', headerObject.Id);
            lineObject.put('Date__c', headerObject.get('Next_Billing_Date__c'));
            updatedObjectList.add(lineObject);
        }
        return updatedObjectList;
    }
    private Boolean getAccountingPeriodStatus(Map<String,Object> headerFieldOverrides){
        Date nextBillingDate = Date.valueOf(headerFieldOverrides.get(PACKAGE_QUALIFIER+'Next_Billing_Date__c'));
        Accounting_Period__c period = AccountingPeriodHandler.getInstance()
                                     .getAccountingPeriodByDateAndStatus(nextBillingDate, 
                                                                         new Set<String>{AccountingPeriodActions.OPEN_STATUS}, 
                                                                         Recurring_Billing__c.sobjectType);
        Boolean status;
        if(period != null && AccountingPeriod.isPeriodOpen(period, Recurring_Billing__c.sobjectType)){
            status = true;
        }
        else{
            status = false;
        }
        return status;
    }

    public override List<String> getFields(){
        List<String> fields = new List<String>();
        fields.add(PACKAGE_QUALIFIER+'Next_Billing_Date__c');
        if(MultiCurrencyHandler.isMultiCurrencyEnabled){
            fields.add('CurrencyIsoCode');
        }
        return fields;
    }

    public override Id clone(Id headerId, Map<String,Object> headerFieldOverrides){
        Savepoint sp = Database.setSavepoint();
        try {
            SObject headerObject = getHeader(headerId);
            if(getAccountingPeriodStatus(headerFieldOverrides)){
                SObject clonedObject = setHeader(headerObject, headerFieldOverrides);
                SFDCSecurityUtils.insertProxy(clonedObject);
                List<SObject> clonedLinesObject = getLinesClone(headerId);
                clonedLinesObject = setLines(clonedLinesObject, clonedObject);
                SFDCSecurityUtils.insertProxy(clonedLinesObject);
                return clonedObject.Id;
            }
            else{
                String dateLabel = Label.COMMON_NEXT_BILLING_DATE;
                Date dateValue = Date.valueOf(headerFieldOverrides.get(PACKAGE_QUALIFIER+'Next_Billing_Date__c'));
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