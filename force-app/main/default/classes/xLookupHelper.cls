public with sharing class xLookupHelper {
    private static final String DEFAULT_ICON = 'custom:custom7';
    public class LookupSearchResult {
        private String id;
        private String title;
        private String subtitle;
        private String icon;
        private String currencyIsoCode;

        public LookupSearchResult(String id,String title, String subtitle, String icon, String currencyIsoCode) {
            this.id = id;
            this.title = title.stripHtmlTags();
            this.subtitle = subtitle;
            this.icon = icon;
            this.currencyIsoCode = currencyIsoCode;
        }

        @AuraEnabled
        public String getId() {
            return id;
        }
        @AuraEnabled
        public String getTitle() {
            return title;
        }
        @AuraEnabled
        public String getIcon() {
            return icon;
        }
        @AuraEnabled
        public String getSubtitle() {
            return subtitle;
        }
        @AuraEnabled
        public String getCurrency() {
            return currencyIsoCode;
        }
    }

    public class InvalidObjectNameException extends Exception {}
    public class RequiredInputException extends Exception {}

    private static DescribeSObjectResult getObjectTypeInfo(String objectName) {
        DescribeSObjectResult objectDescription;
        try {
            objectDescription = Schema.describeSObjects(new String[]{objectName}).get(0);
        } catch (InvalidParameterValueException ex) {
            throw new InvalidObjectNameException();
        }
        return objectDescription;
    }

    private static void requireInput(Object obj) {
        if (obj == null) {
            throw new RequiredInputException();
        }
        if ((obj instanceof String) && String.isBlank((String) obj)) {
            throw new RequiredInputException();
        }
        if ((obj instanceof List<String>) && ((List<String>) obj).isEmpty()) {
            throw new RequiredInputException();
        }
    }

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchRecent(String searchTerm,String sobjectName, String sobjectFieldName,String rowData) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();
        try {
            LookupService lookup;
            if(test.isRunningTest()){
                lookup = new LookupService();
            }else{
                lookup = new LookupService(Page.AcctSeed__xUserSessionId.getContent().toString());
            }
            Schema.SObjectType s = (SObjectType) Schema.getGlobalDescribe().get(sobjectName);
            Schema.SObjectField f = s.getDescribe().fields.getMap().get(sobjectFieldName);
            List<LookupServiceResult> sortedResult = lookup.search(s,f,searchTerm,rowData);
            
            String nameField = getNameField(f.getDescribe().getReferenceTo()[0].getDescribe().getName());

            for (LookupServiceResult result : sortedResult) {
                results.add(new LookupSearchResult(
                        result.getValue('Id'),
                        result.getValue(nameField),
                        f.getDescribe().getLabel(),
                        getIcon(sobjectName),
                        AbstractLWCHelper.CORPORATE_CURRENCY
                ));
            }

        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return results;
    }
    private static String getNameField(String objName){
        return FieldSetHandler.nameFieldsBySObjects.containsKey(objName) ?
                FieldSetHandler.nameFieldsBySObjects.get(objName) : 
                FieldSetHandler.getNameField(objName);
    }

    @AuraEnabled(Cacheable=true)
    public static LookupSearchResult getSObjectValue(String objApiName, String objId) {
        LookupSearchResult result;
        try {
            requireInput(objApiName);
            requireInput(objId);

            DescribeSObjectResult od = getObjectTypeInfo(objApiName);

            List<String> queryFields = new List<String>{
                'Id',
                getNameField(od.getSObjectType().getDescribe().getName())
            };

            String queryCondition = 'Id = :objId';

            SOQLBuilder query = new SOQLBuilder(od.getSObjectType());
            query
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(1);
            SObject queryResult = Database.query(query.toSOQL());

            result = transformQueryResults(queryResult, od);
        } catch (RequiredInputException ex) {
            return null;
        } catch (InvalidObjectNameException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (SFDCSecurityUtils.CrudException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (SFDCSecurityUtils.FlsException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        return result;
    }

    private static LookupSearchResult transformQueryResults(SObject obj, DescribeSObjectResult od) {
        LookupSearchResult result = new LookupSearchResult(
            String.valueOf(obj.get('id')),
            String.valueOf(obj.get(getNameField(od.getSObjectType().getDescribe().getName()))),
            od.getLabel(),
            getIcon(od.getName()),
            AbstractLWCHelper.CORPORATE_CURRENCY
        );
        return result;
    }
    @TestVisible
    private static String getIcon(String objectName) {
        String icon = DEFAULT_ICON;
        List<Schema.DescribeTabSetResult> tabSetDesc = Schema.describeTabs();
        List<Schema.DescribeTabResult> tabDesc = new List<Schema.DescribeTabResult>();
        List<Schema.DescribeIconResult> iconDesc = new List<Schema.DescribeIconResult>();

        for(Schema.DescribeTabSetResult tsr : tabSetDesc) {
            tabDesc.addAll(tsr.getTabs());
        }
        for(Schema.DescribeTabResult tr : tabDesc) {
            if (tr.getSobjectName() == objectName) {
                if ( tr.isCustom() == true ) {
                    iconDesc.addAll(tr.getIcons());
                    break;
                } else {
                    icon = 'standard:' + getObjectName(objectName);
                    break;
                }
            }
        }
        for (Schema.DescribeIconResult ir : iconDesc) {
            if (ir.getContentType() == 'image/svg+xml') {
                icon = 'custom:' + ir.getUrl().substringBetween('custom/','.svg').substringBefore('_');
                break;
            }
        }
        
        return icon;
    }
    private static String getObjectName(String objectName) {
        return objectName == 'Product2' ? objectName.removeEnd('2').toLowerCase() : objectName.toLowerCase();
    }
}