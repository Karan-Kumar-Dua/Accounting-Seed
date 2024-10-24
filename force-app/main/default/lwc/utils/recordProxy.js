import CommonUtils from './commonUtils';

/**
 * This class allows for the handling of namespaced records and objects
 * when that namespace may be different from package to package.
 * Since we don't want to hardcode namespaces in the UI, this
 * exists as a wrapper for the results of `getObjectInfo` and
 * creates mappings of ns to non-ns fields and vice-versa.
 * It also handles conversion of records (as js objects) in each direction.
 */
export default class RecordProxy {

    /**
     * Original schema object
     */
    schema;

    /**
     * field__c to ns__field__c
     */
    proxy;

    /**
     * ns__field__c to field__c
     */
    reverseProxy;

    /**
     * objectInfo.fields with namespacing stripped off the keys
     */
    fields;

    /**
     * Quick reference to the object namespace
     */
    namespace;
 
    constructor (schema) {
        this.schema = schema; // cache original
        this.createProxy(schema);
        this.namespace = CommonUtils.getPackageQualifier(schema.apiName);
    }

    /**
     * Given a schema, build out mappings for non-namespaced fields to
     * namespaced fields and the opposite. Do similar for field info
     * for use in UIs when e.g. a `lightning-input-field` isn't viable.
     */
    createProxy (schema) {
        let proxy = new Map();
        for (let field in schema.fields) {
            proxy.set(
                this.stripFieldQualifier(field),
                field
            );
        }
        
        // Lookup field__c to ns__field__c
        this.proxy = proxy;

        // Lookup ns__field__c to field__c
        this.reverseProxy = this.createReverseProxy(proxy);

        // Field data - labels, help text, etc
        this.fields = this.proxyFieldInfo();

    }

    /**
     * Map ns__field__c to field__c
     */
    createReverseProxy (proxy) {
        return new Map(Array.from(proxy, a => a.reverse()));
    }

    /**
     * Strip namespacing off getObjectInfo.data.fields.
     */
    proxyFieldInfo () {
        const fields = {};
        Object.keys(this.schema.fields).forEach((key) => {
            let fieldName = this.stripFieldQualifier(key);
            fields[fieldName] = this.schema.fields[key];
        });
        return fields;
    }

    /**
     * Strip namespacing from a field.
     */
    stripFieldQualifier (fieldApiName) {
        return fieldApiName.replace(
            CommonUtils.getPackageQualifier(fieldApiName),
            ''
        );
    }

    /**
     * Single sObject -> namespace-less record
     */
    getRecord (record) {
        let proxiedRecord = {};
        Object.keys(record).forEach((field) => {
            proxiedRecord[this.reverseProxy.get(field)] = record[field];
        });
        return proxiedRecord;
    }

    /**
     * List of sObjects -> list of namespace-less records
     */
    getRecords (records) {
        return records.map((record) => {
            return this.getRecord(record);
        });
    }

    /**
     * Namespace-less record -> namespaced SObject format
     */
    getSObject (record) {
        let sObjectRecord = {};
        Object.keys(record).forEach((field) => {
            sObjectRecord[this.proxy.get(field)] = record[field];
        });
        return sObjectRecord;
    }

    /**
     * List of namespace-less records -> list of namespaced SObjects
     */
    getSObjects (records) {
        return records.map((record) => {
            return this.getSObject(record);
        });
    }

}