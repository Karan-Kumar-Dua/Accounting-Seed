public with sharing class TaxGroupDeepClone {

    @AuraEnabled
    public static Id deepClone(Id sourceTaxGroupId, String targetTaxGroupName) {
        Id result;
        try {
            Tax_Group__c sourceTaxGroup = queryTaxGroup(sourceTaxGroupId, getTaxGroupFields());
            List<Tax_Rate__c> sourceTaxRates = queryTaxRates(sourceTaxGroupId, getTaxRateFields());
            Tax_Group__c targetTaxGroup = sourceTaxGroup.clone(false);
            targetTaxGroup.Name = targetTaxGroupName;
            //No need to check FLS because only updateable/createable fields were populated
            SFDCSecurityUtils.insertCheckCRUDAndFLS(targetTaxGroup, new List<String>());

            List<Tax_Rate__c> targetTaxRates = new List<Tax_Rate__c>();
            for (Tax_Rate__c sourceTaxRate : sourceTaxRates) {
                Tax_Rate__c tempTaxRate = sourceTaxRate.clone(false);
                tempTaxRate.Tax_Group__c = targetTaxGroup.Id;
                targetTaxRates.add(tempTaxRate);
            }
            //No need to check FLS because only updateable/createable fields were populated
            SFDCSecurityUtils.insertCheckCRUDAndFLS(targetTaxRates, new List<String>());
            result = targetTaxGroup.Id;
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return result;
    }

    private static List<String> getTaxGroupFields() {
        List<String> result = new List<String>();
        Map<String, Schema.SObjectField> taxGroupFieldMap = Schema.SObjectType.Tax_Group__c.fields.getMap();
        for (String fieldName : taxGroupFieldMap.keyset()) {
            Schema.DescribeFieldResult dfr = taxGroupFieldMap.get(fieldName).getDescribe();
            if (dfr.isUpdateable() && dfr.isCreateable() && !dfr.isUnique()) {
                result.add(dfr.getName());
            }
        }
        return result;
    }

    private static List<String> getTaxRateFields() {
        List<String> result = new List<String>();
        Map<String, Schema.SObjectField> taxRateFieldMap = Schema.SObjectType.Tax_Rate__c.fields.getMap();
        for (String fieldName : taxRateFieldMap.keyset()) {
            Schema.DescribeFieldResult dfr = taxRateFieldMap.get(fieldName).getDescribe();
            if (dfr.isUpdateable() && dfr.isCreateable() && !dfr.isUnique()) {
                result.add(dfr.getName());
            }
        }
        return result;
    }

    private static Tax_Group__c queryTaxGroup(Id taxGroupId, List<String> fieldsToQuery) {
        String queryCondition = 'Id = :taxGroupId';

        SOQLBuilder theQuery = new SOQLBuilder(Tax_Group__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        return (Tax_Group__c) Database.query(theQuery.toSOQL());
    }

    private static List<Tax_Rate__c> queryTaxRates(Id taxGroupId, List<String> fieldsToQuery) {
        String queryCondition = 'Tax_Group__c = :taxGroupId';

        SOQLBuilder theQuery = new SOQLBuilder(Tax_Rate__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        return (List<Tax_Rate__c>) Database.query(theQuery.toSOQL());
    }

}