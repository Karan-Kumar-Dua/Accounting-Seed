public with sharing class LookupHelper {

    // error messages
    @TestVisible
    private static final String REQUIRED_INPUT = 'missing_required_input';
    @TestVisible
    private static final String INVALID_OBJECT_NAME = 'invalid_object_name';
    @TestVisible
    private static final String UNAUTHORIZED = 'unauthorized';
    @TestVisible
    private static final String UNKNOWN =  'unknown';

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String DEFAULT_ICON = 'custom:custom7';
    private static final Integer DEFAULT_LIMIT = 5;
    private static final String DEFAULT_SEARCH_GROUP = 'ALL';
    private static final String DEFAULT_DISPLAY_FIELD = 'Name';
    private static final Set<String> SEARCH_GROUP_WHITELIST = new Set<String> { 
        'ALL',
        'NAME',
        'EMAIL',
        'PHONE'
    };
    private static final Integer COUNT_QUERY_LIMITER = 10;
    private static final String LAST_VIEWED_FIELD_API_NAME = 'LastViewedDate';
    private static final String LAST_MODIFIED_FIELD_API_NAME = 'LastModifiedDate';

    public class LookupOptions {
        public String queryTerm {
            get {
                return String.escapeSingleQuotes(queryTerm);
            }}
        public String searchTerm {
            get {
                return String.escapeSingleQuotes(searchTerm) + '*';
            }}
        public String searchGroup {
            get {
                String s = DEFAULT_SEARCH_GROUP;
                if (String.isNotBlank(searchGroup) 
                    && SEARCH_GROUP_WHITELIST.contains(searchGroup.toUpperCase())) {
                    s = searchGroup.toUpperCase();
                }
                return s;
            }}
        public String searchObject {
            get {
                return String.escapeSingleQuotes(searchObject);
            }}

        public List<String> searchObjectList {
            get {
                List<String> result = new List<String>();
                result = searchObject.split('\\,');
                return result;
            }}
        public String searchDisplayField {
            get {
                String s = DEFAULT_DISPLAY_FIELD;
                if (String.isNotBlank(searchDisplayField)) {
                    s = String.escapeSingleQuotes(searchDisplayField);
                }
                return s;
            }}
        public Integer searchLimit {
            get {
                Integer i = DEFAULT_LIMIT;
                if (searchLimit != null || searchLimit < 1) {
                    i = searchLimit;
                }
                return i;
            }}
        public Map<String, List<String>> retrieveFields {
            get; set;
        }
    }

    public class LookupSearchResult {
        private SObject obj;
        private String label;
        private String icon;
        private String currencyIsoCode;

        public LookupSearchResult(SObject queryResult, String label, String icon, String currencyIsoCode) {
            this.obj = queryResult;
            this.label = label;
            this.icon = icon;
            this.currencyIsoCode = currencyIsoCode;
        }

        @AuraEnabled
        public SObject getObj() {
            return obj;
        }

        @AuraEnabled
        public String getLabel() {
            return label;
        }

        @AuraEnabled
        public String getIcon() {
            return icon;
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

    private static List<LookupSearchResult> transformSOSLResults(List<List<SObject>> soslResults, Map<SObjectType, DescribeSObjectResult> odMap) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();
        if (soslResults.size() > 0) {
            for (List<SObject> objList : soslResults) {
                for (SObject obj : objList) {
                    results.add(
                        new LookupSearchResult(
                            obj, 
                            odMap.get(obj.getSObjectType()).getLabel(), 
                            getIcon(odMap.get(obj.getSObjectType()).getName()), 
                            AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED ? (String) obj.get('CurrencyIsoCode') : AbstractLWCHelper.CORPORATE_CURRENCY                        
                        )
                    );
                }
            }
        }
        return results;
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

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchRecent(String searchOptionsJson, String searchFilterJson) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();
        try {
            requireInput(searchOptionsJson);
            LookupOptions options = (LookupOptions) JSON.deserialize(searchOptionsJson, LookupOptions.class);
            requireInput(options.searchObject);

            // Prepare query paramters
            List<String> fields = new List<String> {'Id'};
            fields.add(options.searchDisplayField);
            if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                fields.add('CurrencyIsoCode');
            }
            String searchTerm = options.queryTerm;
            searchTerm = String.isNotBlank(searchTerm) ? searchTerm + '%' : searchTerm;

            String whereClause = LookupQL.deserializeWhere(searchFilterJson);
            if (String.isNotBlank(searchTerm)) {
                String searchCondition = DEFAULT_DISPLAY_FIELD + ' LIKE: searchTerm';
                whereClause = String.isNotBlank(whereClause) ?
                    whereClause + ' AND ' + searchCondition : 'WHERE ' + searchCondition;
            }

            Integer searchLimit = options.searchLimit;

            Map<SObjectType, DescribeSObjectResult> odMap = new Map<SObjectType, DescribeSObjectResult>();
            List<String> queries = new List<String>();
            String dateField = LAST_VIEWED_FIELD_API_NAME;
            for (String obj : options.searchObjectList) {
                if (SchemaDescribe.getDescribe(obj).getField(LAST_VIEWED_FIELD_API_NAME) == null) {
                    dateField = LAST_MODIFIED_FIELD_API_NAME;
                }
                fields.add(dateField);
                DescribeSObjectResult od = getObjectTypeInfo(obj);
                String objectName = od.getName();
                Set<String> fields4Object = new Set<String>(fields);
                if (options.retrieveFields != null && options.retrieveFields.get(objectName) != null) {
                    fields4Object.addAll(options.retrieveFields.get(objectName));
                }
                queries.add(String.format('SELECT {0} FROM {1} {2}', new List<String>{
                        String.join(new List<String>(fields4Object), ','),
                        objectName,
                        (String.isNotBlank(whereClause) ? whereClause : '') +
                                ' ORDER BY ' + dateField + ' DESC LIMIT :searchLimit'
                }));
                odMap.put(od.getSObjectType(), od);
                // check CRUD + FLS
                SFDCSecurityUtils.checkCRUDAndFLS(od.getSObjectType(), new List<String>(fields4Object));
            }

            Map<Datetime, List<SObject>> searchResults = new Map<Datetime, List<SObject>>();
            Integer countQueryLimiter = searchLimit < COUNT_QUERY_LIMITER ? searchLimit : COUNT_QUERY_LIMITER;
            for (Integer index = 0; index < queries.size() && index < countQueryLimiter; index++) {
                List<SObject> records = Database.query(queries[index]);
                for (SObject record: records) {
                    Datetime key = (Datetime)record.get(dateField);
                    List<SObject> tempResult = searchResults.containsKey(key) ?
                            searchResults.get(key) : new List<SObject>();
                    tempResult.add(record);
                    searchResults.put(key, tempResult);
                }
            }
            List<Datetime> lastViewedKeys = new List<Datetime>(searchResults.keySet());
            lastViewedKeys.sort();

            List<SObject> sortedResults = new List<SObject>();
            for (Integer index = lastViewedKeys.size() - 1; index >= 0; index--) {
                sortedResults.addAll(searchResults.get(lastViewedKeys[index]));
            }

            for (SObject sortedResult : sortedResults) {
                results.add(new LookupSearchResult(
                        sortedResult,
                        odMap.get(sortedResult.getSObjectType()).getLabel(),
                        getIcon(odMap.get(sortedResult.getSObjectType()).getName()),
                        AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED ? (String) sortedResult.get('CurrencyIsoCode') : AbstractLWCHelper.CORPORATE_CURRENCY
                ));
            }

        } catch (RequiredInputException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (InvalidObjectNameException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (SFDCSecurityUtils.CrudException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (SFDCSecurityUtils.FlsException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        return results;
    }

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> search(String searchOptionsJson, String searchFilterJson) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        try {
            requireInput(searchOptionsJson);
            LookupOptions options = (LookupOptions) JSON.deserialize(searchOptionsJson, LookupOptions.class);
            requireInput(options.searchObject);
            requireInput(options.searchTerm);

            // Prepare query paramters
            List<String> fields = new List<String> {'Id'};
            fields.add(options.searchDisplayField);
            if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                fields.add('CurrencyIsoCode');
            }
            String searchTerm = options.searchTerm;
            String whereClause = LookupQL.deserializeWhere(searchFilterJson);
            Integer searchLimit = options.searchLimit;

            Map<SObjectType, DescribeSObjectResult> odMap = new Map<SObjectType, DescribeSObjectResult>();
            String queryString = '';

            for (String obj : options.searchObjectList) {
                DescribeSObjectResult od = getObjectTypeInfo(obj);
                String objectName = od.getName();
                Set<String> fields4Object = new Set<String>(fields);
                if (options.retrieveFields != null && options.retrieveFields.get(objectName) != null) {
                    fields4Object.addAll(options.retrieveFields.get(objectName));
                }

                queryString += (od.getName() + ' (' + String.join(new List<String>(fields4Object), ',') + ' ' + whereClause + ' ORDER BY ' + DEFAULT_DISPLAY_FIELD + '), ');
                odMap.put(od.getSObjectType(), od);
                // check CRUD + FLS
                SFDCSecurityUtils.checkCRUDAndFLS(od.getSObjectType(), new List<String>(fields4Object));
            }
            // execute search query
            String query = 
                'FIND :searchTerm ' + 
                'IN ' + options.searchGroup + ' FIELDS ' + 
                'RETURNING ' + queryString.removeEnd(', ') +
                ' LIMIT :searchLimit';
            List<List<SObject>> searchResults = search.query(query);

            // convert search results into LookupSearchResult
            results = transformSOSLResults(searchResults, odMap);

        } catch (RequiredInputException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (InvalidObjectNameException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (SFDCSecurityUtils.CrudException ex) {
            throw new AuraHandledException(ex.getMessage());  
        } catch (SFDCSecurityUtils.FlsException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        return results;
    }

    @AuraEnabled(Cacheable=true)
    public static LookupSearchResult getSObjectValue(String objApiName, String objId) {
        return fetchRecord(objApiName, objId, null);
    }

    @AuraEnabled(Cacheable=true)
    public static LookupSearchResult fetchRecord(String objApiName, String objId, Map<String, List<String>> retrieveFields) {
        LookupSearchResult result;
        try {
            requireInput(objApiName);
            requireInput(objId);

            DescribeSObjectResult od = getObjectTypeInfo(objApiName);

            Set<String> queryFields = new Set<String>{
                'Id',
                'Name'
            };
            if (retrieveFields != null && retrieveFields.get(objApiName) != null) {
                queryFields.addAll(retrieveFields.get(objApiName));
            }

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
            throw new AuraHandledException(ex.getMessage());
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
            obj,
            od.getLabel(),
            getIcon(od.getName()),
            AbstractLWCHelper.CORPORATE_CURRENCY
        );
        return result;
    }

}