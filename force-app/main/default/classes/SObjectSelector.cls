public abstract with sharing class SObjectSelector {

    /**
     * Sharing options to use when querying the sobject.
     * The use of enum is preferred over a boolean flag for 
     * readability. Making the security decisions obvious
     * is a top priority.
     */
    public enum SharingMode { WITH_SHARING, WITHOUT_SHARING }

    // CRUD and FLS permissions to respect when querying the sobject
    @TestVisible
    private System.AccessLevel accessLevel;
    // sharing mode to use when querying the sobject
    @TestVisible
    private SharingMode sharingType;
    // field sets to include when querying the sobject
    private List<Schema.FieldSet> fieldSets;
    
    /**
     * Constructor: uses the most restrictive security settings.
     */
    public SObjectSelector() {
        this(System.AccessLevel.USER_MODE, SharingMode.WITH_SHARING);
    }

    /**
     * Constructor: uses the given security settings.
     */
    public SObjectSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        this.accessLevel = accessLevel ?? System.AccessLevel.USER_MODE;
        this.sharingType = sharingType ?? SharingMode.WITH_SHARING;
    }

    /**
     * Returns the sobject type that the selector is responsible for.
     */
    public abstract Schema.SObjectType getSObjectType();

    /**
     * Returns a list of fields that should be selected when querying the sobject.
     */
    public abstract List<Schema.SObjectField> getSObjectFields();

    /**
     * The selector should include the given field sets' fields when querying the sobject.
     * The provided fields sets will replace any previously included field sets.
     */
    public void includeFieldSets(List<Schema.FieldSet> fieldSets) {
        this.fieldSets = fieldSets;
    }

    /**
     * Returns a list of sobjects that match the given ids.
     */
    public virtual List<SObject> selectSObjectsById(Set<Id> ids) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.setCondition('Id IN :ids');
        Map<String,Object> bindMap = new Map<String,Object>{'ids' => ids};
        return database().queryWithBinds(builder.toSOQL(), bindMap);
    }

    /**
     * Returns a query locator for the sobjects that match the given ids.
     */
    public virtual Database.QueryLocator queryLocatorById(Set<Id> ids) {
        SOQLBuilder builder = getSOQLBuilder();
        builder.setCondition('Id IN :ids');
        Map<String,Object> bindMap = new Map<String,Object>{'ids' => ids};
        return database().getQueryLocatorWithBinds(builder.toSOQL(), bindMap);
    }

    /**
     * Returns a new DBProxy instance based on the sharing settings.
     */
    protected DBProxy database() {
        if (sharingType == SharingMode.WITHOUT_SHARING) {
            return new DBProxyWithoutSharing(accessLevel);
        }
        return new DBProxyWithSharing(accessLevel);
    }

    /**
     * Returns the name of the sobject that the selector is responsible for.
     * This is useful when building a query via String concatenation.
     */
    @TestVisible
    protected String getSObjectName() {
        return getSObjectType().getDescribe().getName();
    }

    /**
     * Returns the list of field names that will be selected when querying the sobject.
     * This is useful when building a query via String concatenation.
     */
    @TestVisible
    protected Set<String> getSObjectFieldNames() {
        Set<String> fieldNames = new Set<String>();
        for (Schema.SObjectField field : getSObjectFields()) {
            fieldNames.add(field.getDescribe().getName());
        }
        return fieldNames;
    }

    /**
     * Utility method to join the fields of a related sobject to the current sobject.
     * The resulting fields can then be used in a SOQL query.
     */
    protected Set<String> join(SObjectField joinField, SObjectSelector selector) {
        Set<String> fieldNames = new Set<String>();
        String relationshipName = joinField.getDescribe().getRelationshipName();
        for (String fieldName : selector.getSObjectFieldNames()) {
            fieldNames.add(relationshipName + '.' + fieldName);
        }
        return fieldNames;
    }

    /**
     * Adds the security settings to the given SOQLBuilder.
     * If you need to build a special query and don't want to use the 
     * more general getSOQLBuilder, but would still like to apply the 
     * proper security settings.
     */
    protected SOQLBuilder addSecuritySettings(SOQLBuilder builder) {
        // crud and fls permissions
        if (accessLevel == System.AccessLevel.SYSTEM_MODE) {
            builder.setEnforceFLS(false);
        } else {
            builder.assertIsAccessible();
            builder.setEnforceFLS(true);
        }
        
        return builder;
    }

    /**
     * Adds the fields to select to the given SOQLBuilder.
     * If you need to build a special query and don't want to use the 
     * more general getSOQLBuilder, but would still like to add
     * the fields defined by the selector.
     */
    protected SOQLBuilder addSelectFields(SOQLBuilder builder) {
        // add fields to select
        builder.selectFields(getSObjectFields());

        // add field set fields to select
        if (fieldSets != null) {
            for (Schema.FieldSet fieldSet : fieldSets) {
                builder.selectFieldSet(fieldSet);
            }
        }

        return builder;
    }

    /**
     * Returns a new SOQLBuilder with SELECT and FROM clauses set.
     * In addition the settings for CRUD and FLS enforcement are applied.
     */
    protected SOQLBuilder getSOQLBuilder() {
        // create a new soql builder for the sobject type
        SOQLBuilder builder = new SOQLBuilder(getSObjectType());

        // add CRUD and FLS security
        addSecuritySettings(builder);

        // add fields to select
        addSelectFields(builder);

        return builder;
    }

    /**
     * A proxy for the Database class.
     */
    public interface DBProxy {
        List<SObject> query(String query);
        List<SObject> queryWithBinds(String query, Map<String,Object> bindMap);
        Database.QueryLocator getQueryLocator(String query);
        Database.QueryLocator getQueryLocatorWithBinds(String query, Map<String,Object> bindMap);
    }

    /**
     * A DBProxy that respects sharing settings.
     */
    public with sharing class DBProxyWithSharing implements DBProxy {
        
        System.AccessLevel accessLevel;

        DBProxyWithSharing(System.AccessLevel accessLevel) {
            this.accessLevel = accessLevel;
        }

        public List<SObject> query(String query) {
            return Database.query(query, accessLevel);
        }
        public List<SObject> queryWithBinds(String query, Map<String,Object> bindMap) {
            return Database.queryWithBinds(query, bindMap, accessLevel);
        }
        public Database.QueryLocator getQueryLocator(String query) {
            return Database.getQueryLocator(query, accessLevel);
        }
        public Database.QueryLocator getQueryLocatorWithBinds(String query, Map<String,Object> bindMap) {
            return Database.getQueryLocatorWithBinds(query, bindMap, accessLevel);
        }
    }

    /**
     * A DBProxy that does not respect sharing settings.
     */
    public with sharing class DBProxyWithoutSharing implements DBProxy {

        System.AccessLevel accessLevel;

        DBProxyWithoutSharing(System.AccessLevel accessLevel) {
            this.accessLevel = accessLevel;
        }

        public List<SObject> query(String query) {
            return DomainUtils.query(query, accessLevel);
        }
        public List<SObject> queryWithBinds(String query, Map<String,Object> bindMap) {
            return DomainUtils.queryWithBinds(query, bindMap, accessLevel);
        }
        public Database.QueryLocator getQueryLocator(String query) {
            return DomainUtils.getQueryLocator(query, accessLevel);
        }
        public Database.QueryLocator getQueryLocatorWithBinds(String query, Map<String,Object> bindMap) {
            return DomainUtils.getQueryLocatorWithBinds(query, bindMap, accessLevel);
        }
    }
    
}