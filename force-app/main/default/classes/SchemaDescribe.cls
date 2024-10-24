/**
 * SchemaDescribe is a semi-intelligent wrapper for standard apex Schema methods.
 * It provides an internal caching layer, to avoid hitting describe limits from repeated use,
 * as well as wrapper classes and methods to make common tasks like working with relationship field name oddities
 * as well namespace handling.
 *
 * Of particular note for use in contexts that may be released as managed packages are the #getFields and get #getGlobalDescribe methods 
 * These return special immutable wrapper objects that automatically imply the current namespace (detected as the one this class is contained in)
 * and allow an older API style of omitting the namespace when working with fields or global describe maps.
 * This allows both upgrading old code to APIv29 by making use of these as a nearly drop in replacement, as well as keeping
 * namespace detection logic encapsulated.
**/
public without sharing class SchemaDescribe {
    //internal implementation details
    private Schema.SObjectType token;
    private Schema.SObjectField nameField;
    private Schema.DescribeSObjectResult describe { //lazy load - keep this leightweight until we need more data
        get {
            if (describe == NULL) {
                describe = token.getDescribe();
            }
            return describe;
        }
        set;
    }

    private Map<String, Schema.SObjectField> fields {
        get {
            if (fields == NULL) {
                fields = describe.fields.getMap();
            }
            return fields;
        }
        set;
    }

    private Map<String, Schema.FieldSet> fieldSets {
        get {
            if (fieldSets == NULL) {
                fieldSets = describe.fieldSets.getMap();
            }
            return fieldSets;
        }
        set;
    }

    private FieldsMap wrappedFields {
        get {
            if (wrappedFields == NULL) {
                wrappedFields = new FieldsMap(this.fields);
            }
            return wrappedFields;
        }
        set;
    }

    private SchemaDescribe(Schema.SObjectType token) {
        if (token == NULL) {
            throw new InvalidDescribeException(Label.ERR_INVALID_SOBJECT_TYPE_NULL);
        }

        if(instanceCache.containsKey( String.valueOf(token) )) {
            throw new DuplicateDescribeException(token + Label.ERR_ALREADY_IN_DESCRIBE_CACHE);
        }
        this.token = token;
        instanceCache.put(String.valueOf(token).toLowerCase(), this);
    }

    //public instace methods
	/**
	 * Returns the Schema.SObjectType this SchemaDescribe instance is based on.
	**/
    public Schema.SObjectType getSObjectType() {
        return token;
    }
	/**
	 * This method is a convenient shorthand for calling getField(name, true)
	**/
    public Schema.SObjectField getField(String name) {
        return this.getField(name, true);
    }
	/**
	 * This method provides a simplified shorthand for calling #getFields and getting the provided field.
	 * Additionally it handles finding the correct SObjectField for relationship notation,
	 * e.g. getting the Account field on Contact would fail without being referenced as AccountId - both work here.
	**/
    public Schema.SObjectField getField(String fieldName, Boolean implyNamespace) {
        Schema.SObjectField result = wrappedFields.get(
            //resolve custom field cross-object (__r) syntax
            (fieldName.endsWithIgnoreCase('__r') ? (fieldName.removeEndIgnoreCase('__r') + '__c') : fieldName), implyNamespace);
        if (result == NULL) {
            result = wrappedFields.get(fieldName + 'Id', implyNamespace); //in case it's a standard lookup in cross-object format
        }
        return result;
    }

	/**
	* Returns the field where isNameField() is true (if any); otherwise returns NULL
	**/
    public Schema.SObjectField getNameField() {
        if (nameField == NULL) {
            for (Schema.SObjectField field : wrappedFields.values()) {
                if (field.getDescribe().isNameField()) {
                    nameField = field;
                    break;
                }
            }
        }
        return nameField;
    }

	/**
	 * Returns the raw Schema.DescribeSObjectResult an SchemaDescribe instance wraps.
	**/
    public Schema.DescribeSObjectResult getDescribe() {
        return describe;
    }
	/**
	 * This method returns the raw data and provides no namespace handling.
	 * Due to this, __use of this method is discouraged__ in favor of getFields(). 
	**/
    public Map<String, Schema.SObjectField> getFieldsMap() {
        return fields;
    }

    public FieldsMap getFields() {
        return wrappedFields;
    }

    public Map<String, Schema.FieldSet> getFieldSetsMap(){
        return fieldSets;
    }

    private static Map<String, Schema.SObjectType> rawGlobalDescribe {
        get {
            if (rawGlobalDescribe == NULL) {
                rawGlobalDescribe = Schema.getGlobalDescribe();
            }
            return rawGlobalDescribe;
        }
        set;
    }

    private static GlobalDescribeMap wrappedGlobalDescribe{
        get {
            if (wrappedGlobalDescribe == NULL) {
                wrappedGlobalDescribe = new GlobalDescribeMap(rawGlobalDescribe);
            }
            return wrappedGlobalDescribe;
        }
        set;
    }
	/**
	 * This is used to cache SchemaDescribe instances as they're consutrcted
	 * to prevent repeatedly re-constructing the same type.
	 * These instances are not guaranteed to be, but typically will be, unique per sObject type due to the presence of flushCache.
	**/
    private static Map<String, SchemaDescribe> instanceCache {
        get {
            if (instanceCache == NULL) {
                instanceCache = new Map<String, SchemaDescribe>();
            }

            return instanceCache;
        }
        set;
    }

    public static SchemaDescribe getDescribe(String sObjectName) {
        if (String.isBlank(sObjectName)) {
            return NULL;
        }

        SchemaDescribe result = instanceCache.get(sObjectName.toLowerCase());
        if (result == NULL) {
            Schema.SObjectType token = wrappedGlobalDescribe.get(sObjectName.toLowerCase());
            if (token == NULL) {
                result = NULL;
            }
            else {
                result = new SchemaDescribe(token);
            }

        }
        return result;
    }

    public static SchemaDescribe getDescribe(Schema.SObjectType token) {
        if (token == NULL) {
            return NULL;
        }

        SchemaDescribe result = instanceCache.get(String.valueOf(token).toLowerCase());

        if (result == NULL) {
            result = new SchemaDescribe(token);
        }

        return result;
    }

    public static SchemaDescribe getDescribe(Schema.DescribeSObjectResult nativeDescribe) {
        if (nativeDescribe == NULL) {
            return NULL;
        }

        SchemaDescribe result = instanceCache.get(nativeDescribe.getName().toLowerCase());
        if (result == NULL) {
            result = new SchemaDescribe(nativeDescribe.getSobjectType());
        }

        return result;
    }

    public static SchemaDescribe getDescribe(SObject instance) {
        if (instance == NULL) {
            return NULL;
        }
        return getDescribe(instance.getSobjectType());
    }

    //returns the same results as the native method, just with caching built in to avoid limits
    public static Map<String, SObjectType> getRawGlobalDescribe() {
        return rawGlobalDescribe;
    }

    public static GlobalDescribeMap getGlobalDescribe() {
        return wrappedGlobalDescribe;
    }
    //Useful when working in heap space constrained environments.
    //Existing references to SObjectDescribe instances will continue to work.
    public static void flushCache() {
        rawGlobalDescribe = NULL;
        instanceCache = NULL;
    }
	/**
	 * This class handles emulating a Map<String,Object>'s non-mutating instance methods and helps navigate the complex topic of
	 * handling implicit namespace behavior like pre-APIv29 did, while also allowing fully qualified references.
	 * Note that this requires the API version of SchemaDescribe to be 29 or higher to function properly.
 	 *
	 * Due to the lack of language support for covariant return types sublasses are responsible for implementing the get methods.
	 * A minimal implementation of these would be a cast and returning getObject's result.
	**/
    private abstract class NamespacedAttributeMap {
        @TestVisible
        protected String currentNamespace;
        protected Map<String,Object> values;

        protected NamespacedAttributeMap(Map<String, Object> values) {
            //namespace detection courtesey http://salesforce.stackexchange.com/a/28977/60
            currentNamespace = SchemaDescribe.class.getName().substringBefore('SchemaDescribe').removeEnd('.').toLowerCase();
            this.values = values;
        }
        //A no-args constructor to allow subclasses with different contructor signatures
        protected NamespacedAttributeMap() {
            this(new Map<String, Object>());
        }
		/**
		 * A convenient shortcut for invoking #getObject(name, true)
		**/
        protected virtual Object getObject(String name) {
            return this.getObject(name, true);
        }
		/**
		 *  
		**/
        protected virtual Object getObject(String name, Boolean implyNamespace) {
            if (name == NULL) {
                return NULL;
            } //short-circuit lookup logic since null can't possibly be a valid field name, and it saves us null checking

            String preferredValue = ((implyNamespace ? currentNamespace + '__' : '') + name).toLowerCase();
            if (values.containsKey(preferredValue)) {
                return values.get(preferredValue);
            }
            else if (implyNamespace) {
                return values.get(name.toLowerCase());
            }
            else {
                return NULL;
            }
        }

        public virtual Boolean containsKey(String name) {
            return this.containsKey(name, true);
        }

        public virtual Boolean containsKey(String name, Boolean implyNamespace) {
            if (name == NULL) {
                return NULL;
            } //short-circuit lookup logic since null can't possibly be a valid field name, and it saves us null checking

            String preferredValue = ((implyNamespace ? currentNamespace + '__' : '') + name).toLowerCase();
            return (values.containsKey(preferredValue) || implyNamespace && values.containsKey(name.toLowerCase()));
        }

        public virtual Integer size() {
            return values.size();
        }
		/**
		 * Returns the key set of the map.
		 * Note: unlike other NamespacedAttributeMap methods keySet defaults implyNamespace to false if not specified.
		**/
        public virtual Set<String> keySet() {
            return this.keySet(false);
        }

        public virtual Set<String> keySet(Boolean implyNamespace) {
            if (implyNamespace) {
                Set<String> result = new Set<String>();
                for (String key:values.keySet()) {
                    result.add(key.removeStartIgnoreCase(currentNamespace + '__'));
                }
                return result;
            }
            else {
                return values.keySet();
            }
        }
    }

	/**
	 * A subclass of NamespacedAttributeMap for handling the data returned by #Schema.DescribeSObjectResult.fields.getMap
	**/
    public class FieldsMap extends NamespacedAttributeMap {

        @TestVisible
        private FieldsMap(Map<String, Schema.SObjectField> values) {
            super(values);
        }

        public Schema.SObjectField get(String name) {
            return this.get(name, true);
        }

        public Schema.SObjectField get(String name, Boolean implyNamespace){
            return (Schema.SObjectField) this.getObject(name, implyNamespace);
        }

        public List<Schema.SObjectField> values() {
            return (List<Schema.SObjectField>) values.values();
        }

    }
	/**
	 * A subclass of NamespacedAttributeMap for handling the data returned by #Schema.getGlobalDescribe
	**/
    public class GlobalDescribeMap extends NamespacedAttributeMap {
        @TestVisible
        private GlobalDescribeMap(Map<String, Schema.SObjectType> values) {
            super(values);
        }

        public Schema.SObjectType get(String name) {
            return this.get(name, true);
        }
        public Schema.SObjectType get(String name, Boolean implyNamespace) {
            return (Schema.SObjectType) this.getObject(name, implyNamespace);
        }
        public List<Schema.SObjectType> values() {
            return (List<Schema.SObjectType>) values.values();
        }
    }

    public abstract class DescribeException extends Exception{}
    public class DuplicateDescribeException extends DescribeException{} //Test coverage for this requires APIv28's @testVisbile annotation to force exception cases.
    public class InvalidDescribeException extends DescribeException{}

}