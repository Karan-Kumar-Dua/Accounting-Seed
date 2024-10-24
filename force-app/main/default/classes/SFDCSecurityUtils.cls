/**
 * Utility class for checking FLS/CRUD. NOTE: all "check" methods will throw a SecurityException (or subclass) if the
 * user does not have the proper security granted.
 **/
public class SFDCSecurityUtils {//No explicit sharing declaration - inherit from caller
    @TestVisible
    private Enum OperationType {CREATE, READ, MODIFY, DEL} //UPDATE and DELETE are reserved words
    @TestVisible
    private static final String CRUD_ERROR =
        Label.ERR_PLEASE_SET_PERMISSION_SET;
    @TestVisible
    private static final String UNABLE_TO_CHECK_CRUD_FLS_ERROR =
        Label.ERR_CHECK_CRUD_AND_FLS_PERMISSIONS;
    private static final String FLS_ERROR = Label.ERR_NEED_TO_SET_FLS_PERMISSION;

    public static FlsInspector flsInspector = new FlsInspector();

    public virtual class SecurityException extends Exception {
        protected OperationType m_operation;
        protected Schema.SObjectType m_objectType;

        protected void setMessage() {
            this.setMessage(
                String.format(
                    CRUD_ERROR,
                    new List<String>{
                        resolveOperationType(),
                        m_objectType.getDescribe().getLabel()
                    }
                )
            );
        }
    
        private String resolveOperationType() {
            String opType;

            if (m_operation == OperationType.CREATE) {
                opType = Label.COMMON_CREATE;
            }
            else if (m_operation == OperationType.READ) {
                opType = Label.COMMON_READ;
            }
            else if (m_operation == OperationType.MODIFY) {
                opType = Label.COMMON_EDIT;
            }
            else if (m_operation == OperationType.DEL) {
                opType = Label.COMMON_DELETE;
            }
            
            return opType;
        }
    }

    /**
     * CrudException represents a running user's lack of read/create/update/delete access at a profile (or permission set)
     * level. Sharing and field level security issues will never cause this.
     **/
    public class CrudException extends SecurityException {

        private CrudException(OperationType operation, Schema.SObjectType objectType) {
            this.m_operation = operation;
            this.m_objectType = objectType;

            setMessage();
        }
    }
    /**
     * FlsException represents a running user's lack of field level security to a specific field at a profile (or permission set) level
     * Sharing and CRUD security issues will never cause this to be thrown.
     **/
    public class FlsException extends SecurityException {
        private List<Schema.SObjectField> m_fieldTokens;
        private SObjectType m_objectType;
        private Map<Schema.SObjectType, List<Schema.SObjectField>> typeToFields;

        private FlsException(OperationType operation, Map<Schema.SObjectType, List<Schema.SObjectField>> typeToFields) {
            this.m_operation = operation;
            this.typeToFields = typeToFields;

            this.setMessage(createMessage());
        }

        private String createMessage() {
            String result = '';
            for (Schema.SObjectType sObjectType : typeToFields.keySet()) {
                result += String.format(FLS_ERROR,
                                        new String[]{
                                            resolveFLSOperationType(),
                                            sObjectType.getDescribe().getLabel()
                                        });

                Set<String> uniqFieldLabels = new Set<String>();
                for (Schema.SObjectField fieldToken : typeToFields.get(sObjectType)) {
                    uniqFieldLabels.add(fieldToken.getDescribe().getLabel());
                }

                result = result + String.join(new List<String>(uniqFieldLabels), ', ');
            }
            return result;
        }

        private String resolveFLSOperationType() {
            String opType;

            if (m_operation == OperationType.READ) {
                opType = Label.COMMON_READ_ACCESS;
            }
            else {
                opType = Label.COMMON_EDIT_ACCESS;
            }
            
            return opType;
        }

    }

    public with sharing class FlsInspector {
        private Map<Schema.SObjectType, List<FlsInspectionResult>> inspectionResultMap;

        public FlsInspector() {
            this.inspectionResultMap = new Map<Schema.SObjectType, List<FlsInspectionResult>>();
        }

        public void addFlsInspectionResult(FlsInspectionResult result) {
            if (inspectionResultMap.containsKey(result.objectType)) {
                inspectionResultMap.get(result.objectType).add(result);
            }
            else {
                inspectionResultMap.put(result.objectType, new List<FlsInspectionResult>{result});
            }
        }

        public List<FlsInspectionResult> getFlsInspectionResults(Schema.SObjectType objectType) {
            return inspectionResultMap.get(objectType);
        }

        public List<FlsInspectionResult> getFlsInspectionResults() {
            List<FlsInspectionResult> allResults = new List<FlsInspectionResult>();
            for (List<FlsInspectionResult> results : inspectionResultMap.values()) {
                allResults.addAll(results);
            }
            return allResults;
        }

        public void clearInspectionResultMap() {
            inspectionResultMap.clear();
        }

        public void checkResults() {
            SFDCSecurityUtils.OperationType operation;
            Map<Schema.SObjectType, List<Schema.SObjectField>> objectTypeToNotAccessibleFields = new Map<SObjectType, List<SObjectField>>();
            List<Schema.SObjectField> fieldTokens;
            for (SObjectType sObjectType : inspectionResultMap.keySet()) {
                fieldTokens = new List<SObjectField>();
                for (FlsInspectionResult result : inspectionResultMap.get(sObjectType)) {
                    if (result.inspectionFailed) {
                        if (operation == NULL) {//common for all results
                            operation = result.operation;
                        }
                        fieldTokens.add(result.fieldToken);
                    }
                }
                if (!fieldTokens.isEmpty()) {
                    objectTypeToNotAccessibleFields.put(sObjectType, fieldTokens);
                }
            }

            if (!objectTypeToNotAccessibleFields.isEmpty()) {
                throw new SFDCSecurityUtils.FlsException(operation, objectTypeToNotAccessibleFields);
            }
        }
    }

    public with sharing class FlsInspectionResult {
        public Boolean inspectionFailed;
        private OperationType operation;
        private Schema.SObjectType objectType;
        private Schema.SObjectField fieldToken;

        public FlsInspectionResult(Boolean inspectionFailed, OperationType operation, Schema.SObjectType objectType, Schema.SObjectField fieldToken) {
            this.inspectionFailed = (inspectionFailed != NULL) ? inspectionFailed : false;
            this.operation = operation;
            this.objectType = objectType;
            this.fieldToken = fieldToken;
        }

        public FlsInspectionResult(Boolean inspectionFailed, OperationType operation, Schema.SObjectType objectType, String fieldName) {
            this.inspectionFailed = (inspectionFailed != NULL) ? inspectionFailed : false;
            this.operation = operation;
            this.objectType = objectType;
            this.fieldToken = SchemaDescribe.getDescribe(objectType).getField(fieldName);
        }
    }
    
    /**
     * If set to true all check methods will always return void, and never throw exceptions.
     * This should really only be set to true if an app-wide setting to disable in-apex
     * FLS and CRUD checks exists and is enabled.
     * Per security best practices setting BYPASS should be an a opt-in, and not the default behavior.
     **/
    public static Boolean BYPASS_INTERNAL_FLS_AND_CRUD = false;

    /**
    * Check{Insert,Read,Update} methods check both FLS and CRUD
    **/
    
    /**
     * Checks both insert FLS and CRUD for the specified object type and fields.
     * @exception FlsException if the running user does not have insert rights to any fields in {@code fieldNames}.
     * @exception CrudException if the running user does not have insert rights to {@code objType}
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
     **/
    public static void checkInsert(SObjectType objType, List<String> fieldNames) {
        if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
            if (objType == NULL) {
                throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
            }
            checkObjectIsInsertable(objType);
            for (String fieldName : fieldNames) {
                flsInspector.addFlsInspectionResult(checkFieldIsInsertable(objType, fieldName));
            }
            flsInspector.checkResults();
        }
    }
    
    /**
     * Identical to {@link #checkInsert(SObjectType,List<String>)}, except with SObjectField instead of String field references.
     * @exception FlsException if the running user does not have insert rights to any fields in {@code fieldTokens}.
     * @exception CrudException if the running user does not have insert rights to {@code objType}
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
     **/
    public static void checkInsert(SObjectType objType, List<SObjectField> fieldTokens) {
        if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
            if (objType == NULL) {
                throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
            }
            checkObjectIsInsertable(objType);
            for (SObjectField fieldToken : fieldTokens) {
                flsInspector.addFlsInspectionResult(checkFieldIsInsertable(objType, fieldToken));
            }
            flsInspector.checkResults();
        }
    }

    private static void parseFieldApiName(Map<SObjectType, Set<String>> fieldsByTypes, SObjectType objType, String fieldApiName) {
        if (fieldApiName.containsIgnoreCase('.')) {
            String firstPartField = fieldApiName.substringBefore('.');
            List<SObjectType> rTypes = SchemaDescribe.getDescribe(objType).getField(firstPartField)?.getDescribe()?.referenceTo;

            if (!rTypes.isEmpty()) {
                parseFieldApiName(fieldsByTypes, rTypes[0], fieldApiName.substringAfter('.'));
            }
        } else {
            Set<String> fields = fieldsByTypes.containsKey(objType) ?
                    fieldsByTypes.get(objType) : new Set<String>();
            fields.add(fieldApiName);
            fieldsByTypes.put(objType, fields);
        }
    }

    /**
     * Checks both read FLS and CRUD for the specified object type and fields.
     * @exception FlsException if the running user does not have read rights to any fields in {@code fieldNames}.
     * @exception CrudException if the running user does not have read rights to {@code objType}
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
     **/
    public static void checkCRUDAndFLS(SObjectType objType, List<String> fieldApiNames) {
        Map<SObjectType, Set<String>> fieldsByTypes = new Map<SObjectType, Set<String>>();
        for (String fieldApiName : fieldApiNames) {
            parseFieldApiName(fieldsByTypes, objType, fieldApiName);
        }
        for (SObjectType type : fieldsByTypes.keySet()) {
            SFDCSecurityUtils.checkRead(type, new List<String>(fieldsByTypes.get(type)));
        }
    }

    /**
     * Checks both read FLS and CRUD for the specified object type and fields.
     * @exception FlsException if the running user does not have read rights to any fields in {@code fieldNames}.
     * @exception CrudException if the running user does not have read rights to {@code objType}
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
     **/
    public static void checkRead(SObjectType objType, List<String> fieldNames) {
        if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
            if (objType == NULL) {
                throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
            }
            checkObjectIsReadable(objType);
            for (String fieldName : fieldNames) {
                flsInspector.addFlsInspectionResult(checkFieldIsReadable(objType, fieldName));
            }
            flsInspector.checkResults();
        }
    }
    
    /**
     * Identical to {@link #checkRead(SObjectType,List<String>)}, except with SObjectField instead of String field references.
     * @exception FlsException if the running user does not have read rights to any fields in {@code fieldTokens}.
     * @exception CrudException if the running user does not have read rights to {@code objType}
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
     **/
    public static void checkRead(SObjectType objType, List<SObjectField> fieldTokens) {
        if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
            if (objType == NULL) {
                throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
            }
            checkObjectIsReadable(objType);
            for (SObjectField fieldToken : fieldTokens) {
                flsInspector.addFlsInspectionResult(checkFieldIsReadable(objType, fieldToken));
            }
            flsInspector.checkResults();
        }
    }

    /**
     * Checks both update FLS and CRUD for the specified object type and fields.
     * @exception FlsException if the running user does not have update rights to any fields in {@code fieldNames}.
     * @exception CrudException if the running user does not have update rights to {@code objType}
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
     **/
    public static void checkUpdate(SObjectType objType, List<String> fieldNames) {
        if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
            if (objType == NULL) {
                throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
            }
            checkObjectIsUpdateable(objType);
            for (String fieldName : fieldNames) {
                flsInspector.addFlsInspectionResult(checkFieldIsUpdateable(objType, fieldName));
            }
            flsInspector.checkResults();
        }
    }
    
    /**
     * Identical to {@link #checkUpdate(SObjectType,List<String>)}, except with SObjectField instead of String field references.
     * @exception FlsException if the running user does not have update rights to any fields in {@code fieldTokens}.
     * @exception CrudException if the running user does not have update rights to {@code objType}
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
     **/
    public static void checkUpdate(SObjectType objType, List<SObjectField> fieldTokens) {
        if (!BYPASS_INTERNAL_FLS_AND_CRUD) {
            if (objType == NULL) {
                throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
            }
            checkObjectIsUpdateable(objType);
            for (SObjectField fieldToken : fieldTokens) {
                flsInspector.addFlsInspectionResult(checkFieldIsUpdateable(objType, fieldToken));
            }
            flsInspector.checkResults();
        }
    }

    /**
    * CheckFieldIs* method check only FLS
    **/

    /**
     * Checks insert field level security only (no CRUD) for the specified fields on {@code objType}
     * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsInsertable(SObjectType objType, String fieldName) {
        return checkFieldIsInsertable(objType, SchemaDescribe.getDescribe(objType).getField(fieldName));
    }
    /**
     * Identical to {@link #checkFieldIsInsertable(SObjectType,String)}, except with SObjectField instead of String field reference.
     * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsInsertable(SObjectType objType, SObjectField fieldToken) {
        return checkFieldIsInsertable(objType, fieldToken.getDescribe());
    }
    /**
     * Identical to {@link #checkFieldIsInsertable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
     * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsInsertable(SObjectType objType, DescribeFieldResult fieldDescribe) {
        Boolean checkFailed = false;
        if (!BYPASS_INTERNAL_FLS_AND_CRUD && !fieldDescribe.isCreateable()) {
            checkFailed = true;
        }
        return new FlsInspectionResult(checkFailed, OperationType.CREATE, objType, fieldDescribe.getSObjectField());
    }
    /**
     * Checks read field level security only (no CRUD) for the specified fields on {@code objType}
     * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsReadable(SObjectType objType, String fieldName) {
        return checkFieldIsReadable(objType, SchemaDescribe.getDescribe(objType).getField(fieldName));
    }
    /**
     * Identical to {@link #checkFieldIsReadable(SObjectType,String)}, except with SObjectField instead of String field reference.
     * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsReadable(SObjectType objType, SObjectField fieldToken) {
        return checkFieldIsReadable(objType, fieldToken.getDescribe());
    }
    /**
     * Identical to {@link #checkFieldIsReadable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
     * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsReadable(SObjectType objType, DescribeFieldResult fieldDescribe) {
        Boolean checkFailed = false;
        if (!BYPASS_INTERNAL_FLS_AND_CRUD && !fieldDescribe.isAccessible()) {
            checkFailed = true;
        }
        return new FlsInspectionResult(checkFailed, OperationType.READ, objType, fieldDescribe.getSObjectField());
    }
    /**
     * Checks update field level security only (no CRUD) for the specified fields on {@code objType}
     * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsUpdateable(SObjectType objType, String fieldName) {
        return checkFieldIsUpdateable(objType, SchemaDescribe.getDescribe(objType).getField(fieldName));
    }
    /**
     * Identical to {@link #checkFieldIsUpdateable(SObjectType,String)}, except with SObjectField instead of String field reference.
     * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsUpdateable(SObjectType objType, SObjectField fieldToken) {
        return checkFieldIsUpdateable(objType, fieldToken.getDescribe());
    }
    /**
     * Identical to {@link #checkFieldIsUpdateable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
     * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
    **/
    public static FlsInspectionResult checkFieldIsUpdateable(SObjectType objType, DescribeFieldResult fieldDescribe) {
        Boolean checkFailed = false;
        if (!BYPASS_INTERNAL_FLS_AND_CRUD && !fieldDescribe.isUpdateable()) {
            checkFailed = true;
        }
        return new FlsInspectionResult(checkFailed, OperationType.MODIFY, objType, fieldDescribe.getSObjectField());
    }
    /**
    * CheckObjectIs* methods check only CRUD
    **/
    
    /**
     * Checks insert CRUD for the specified object type.
     * @exception CrudException if the running under does not have insert rights to the {@code objType} SObject.
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
    **/
    public static void checkObjectIsInsertable(SObjectType objType) {
        if (BYPASS_INTERNAL_FLS_AND_CRUD) {
            return;
        }

        if (objType == NULL) {
            throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
        }

        if (!objType.getDescribe().isCreateable()) {
            throw new CrudException(OperationType.CREATE, objType);
        }
    }
    /**
     * Checks read CRUD for the specified object type.
     * @exception CrudException if the running under does not have read rights to the {@code objType} SObject.
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
    **/
    public static void checkObjectIsReadable(SObjectType objType) {
        if (BYPASS_INTERNAL_FLS_AND_CRUD) {
            return;
        }

        if (objType == NULL) {
            throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
        }

        if (!objType.getDescribe().isAccessible()) {
            throw new CrudException(OperationType.READ, objType);
        }
    }
    /**
     * Checks update CRUD for the specified object type.
     * @exception CrudException if the running under does not have update rights to the {@code objType} SObject.
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
    **/
    public static void checkObjectIsUpdateable(SObjectType objType) {
        if (BYPASS_INTERNAL_FLS_AND_CRUD) {
            return;
        }

        if (objType == NULL) {
            throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
        }

        if (!objType.getDescribe().isUpdateable()) {
            throw new CrudException(OperationType.MODIFY, objType);
        }
    }
    /**
     * Checks delete CRUD for the specified object type.
     * @exception CrudException if the running under does not have delete rights to the {@code objType} SObject.
     * @exception SecurityException if the method was invoked without appropriate SObjectType argument
    **/
    public static void checkObjectIsDeletable(SObjectType objType) {
        if (BYPASS_INTERNAL_FLS_AND_CRUD) {
            return;
        }

        if (objType == NULL) {
            throw new SecurityException(UNABLE_TO_CHECK_CRUD_FLS_ERROR);
        }

        if (!objType.getDescribe().isDeletable()) {
            throw new CrudException(OperationType.DEL, objType);
        }
    }

    //////////////////////////////////////////////
    // DML operation running in System Context
    // without CRUD and FLS checking
    //////////////////////////////////////////////

    //insert single record
    public static void insertProxy(SObject obj) {
        insertProxy(makeListFromSingleSObject(obj));
    }
    //bulk insert
    public static void insertProxy(List<SObject> objs) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        helper.insertByProxy(objs);
    }
    public static List<Database.SaveResult> insertProxy(List<SObject> objs, Boolean allOrNone) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        return helper.insertByProxy(objs, allOrNone);
    }
    //update single record
    public static void updateProxy(SObject obj) {
        updateProxy(makeListFromSingleSObject(obj));
    }
    //bulk update
    public static void updateProxy(List<SObject> objs) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        helper.updateByProxy(objs);
    }
    public static List<Database.SaveResult> updateProxy(List<SObject> objs, Boolean allOrNone) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        return helper.updateByProxy(objs, allOrNone);
    }
    //upsert single record
    public static void upsertProxy(SObject obj) {
        upsertProxy(makeListFromSingleSObject(obj));
    }
    //bulk upsert
    public static void upsertProxy(List<SObject> objs) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        helper.upsertByProxy(objs);
    }

    public static List<Database.UpsertResult> upsertProxy(List<SObject> objs, Boolean allOrNone) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        return helper.upsertByProxy(objs, allOrNone);
    }

    //delete single record
    public static void deleteProxy(SObject obj) {
        deleteProxy(makeListFromSingleSObject(obj));
    }
    //bulk delete
    public static void deleteProxy(List<SObject> objs) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        helper.deleteByProxy(objs);
    }
    public static void deleteProxy(List<SObject> objs, Boolean allOrNone) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        helper.deleteByProxy(objs, allOrNone);
    }
    public static void deleteProxy(List<Id> objsIds) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        helper.deleteByProxy(objsIds);
    }

    public static List<Database.DeleteResult> deleteProxyDatabase(List<SObject> objs, Boolean allOrNone) {
        ProxyDMLHelper helper = new ProxyDMLHelper();
        return helper.deleteByProxyDatabase(objs, allOrNone);
    }

    //////////////////////////////////////////////
    // DML operation running in the User Context
    // with CRUD and FLS checking
    //////////////////////////////////////////////

    // Insert
    public static Database.SaveResult insertCheckCRUDAndFLS(SObject obj, List<String> fields) {
        return insertCheckCRUDAndFLS(makeListFromSingleSObject(obj), fields)[0];
    }

    public static List<Database.SaveResult> insertCheckCRUDAndFLS(List<SObject> objs, List<String> fields) {
        checkInsert(objs.getSObjectType(), fields);
        return Database.insert(objs);
    }

    public static List<Database.SaveResult> insertCheckCRUDAndFLS(List<SObject> objs, List<String> fields, Boolean allOrNone) {
        checkInsert(objs.getSObjectType(), fields);
        return Database.insert(objs, allOrNone);
    }

    // Update
    public static Database.SaveResult updateCheckCRUDAndFLS(SObject obj, List<String> fields) {
        return updateCheckCRUDAndFLS(makeListFromSingleSObject(obj), fields)[0];
    }

    public static List<Database.SaveResult> updateCheckCRUDAndFLS(List<SObject> objs, List<String> fields) {
        checkUpdate(objs.getSObjectType(), fields);
        return Database.update(objs);
    }

    public static List<Database.SaveResult> updateCheckCRUDAndFLS(List<SObject> objs, List<String> fields, Boolean allOrNone) {
        checkUpdate(objs.getSObjectType(), fields);
        return Database.update(objs, allOrNone);
    }

    // Upsert
    public static Database.SaveResult upsertCheckCRUDAndFLS(SObject obj, List<String> fields) {
        if (obj.get('Id') == NULL) {
            return insertCheckCRUDAndFLS(obj, fields);
        }
        else {
            return updateCheckCRUDAndFLS(obj, fields);
        }
    }

    public static List<Database.UpsertResult> upsertCheckCRUDAndFLS(List<SObject> objs, List<String> fields) {
        List<SObject> recordsToInsert = new List<SObject>();
        List<SObject> recordsToUpdate = new List<SObject>();

        for (SObject record : objs) {
            if (record.get('Id') == NULL) {
                recordsToInsert.add(record);
            }
            else {
                recordsToUpdate.add(record);
            }
        }

        if (!recordsToInsert.isEmpty()) {
            checkInsert(objs.getSObjectType(), fields);
        }

        if (!recordsToUpdate.isEmpty()) {
            checkUpdate(objs.getSObjectType(), fields);
        }

        return Database.upsert(objs);
    }

    public static List<Database.UpsertResult> upsertCheckCRUDAndFLS(List<SObject> objs, List<String> fields, Boolean allOrNone) {
        List<SObject> recordsToInsert = new List<SObject>();
        List<SObject> recordsToUpdate = new List<SObject>();

        for (SObject record : objs) {
            if (record.get('Id') == NULL) {
                recordsToInsert.add(record);
            }
            else {
                recordsToUpdate.add(record);
            }
        }

        if (!recordsToInsert.isEmpty()) {
            checkInsert(objs.getSObjectType(), fields);
        }

        if (!recordsToUpdate.isEmpty()) {
            checkUpdate(objs.getSObjectType(), fields);
        }

        return Database.upsert(objs, allOrNone);
    }

    // Delete
    public static Database.DeleteResult deleteCheckCRUDAndFLS(SObject obj) {
        return deleteCheckCRUDAndFLS(makeListFromSingleSObject(obj))[0];
    }

    public static List<Database.DeleteResult> deleteCheckCRUDAndFLS(List<SObject> objs) {
        checkObjectIsDeletable(objs.getSObjectType());
        return Database.delete(objs);
    }

    public static List<Database.DeleteResult> deleteCheckCRUDAndFLS(List<SObject> objs, Boolean allOrNone) {
        checkObjectIsDeletable(objs.getSObjectType());
        return Database.delete(objs, allOrNone);
    }

    public static List<Database.DeleteResult> deleteCheckCRUDAndFLS(List<Id> recordIds, Boolean allOrNone) {
        SObjectType sObjType = !recordIds.isEmpty() ? recordIds[0].getSobjectType() : null;
        if (sObjType != null) {
            checkObjectIsDeletable(sObjType);
            return Database.delete(recordIds, allOrNone);
        }
        return new List<Database.DeleteResult>();
    }

    private static List<SObject> makeListFromSingleSObject(SObject obj) {
        String listType = 'List<' + obj.getSObjectType() + '>';
        List<SObject> castRecords = (List<SObject>) Type.forName(listType).newInstance();
        castRecords.add(obj);
        return castRecords;
    }

    public static Set<String> getOnlyAccessibleFields(Schema.SObjectType sObjType) {
        Set<String> results = new Set<String>();
        if (sObjType != NULL) {
            Map<String, Schema.SObjectField> allFieldMap = sObjType.getDescribe().fields.getMap();
            for (String fieldName : allFieldMap.keyset()) {
                Schema.DescribeFieldResult theField = allFieldMap.get(fieldName).getDescribe();
                if (theField.isAccessible()) {
                    results.add(theField.getName());
                }
            }
        }
        return results;
    }

    public static Set<String> getUpdateableCreatableFields(Schema.SObjectType sObjType) {
        Set<String> results = new Set<String>();
        if (sObjType != NULL) {
            Map<String, Schema.SObjectField> allFieldMap = sObjType.getDescribe().fields.getMap();
            for (String fieldName : allFieldMap.keyset()) {
                Schema.DescribeFieldResult theField = allFieldMap.get(fieldName).getDescribe();
                if (theField.isAccessible() && (theField.isUpdateable() || theField.isCreateable())) {
                    results.add(theField.getName());
                }
            }
        }
        return results;
    }

    public static Set<String> getOnlyCustomAndAccessibleFields(Schema.SObjectType sObjType) {
        Set<String> results = new Set<String>();
        if (sObjType != NULL) {
            Map<String, Schema.SObjectField> allFieldMap = sObjType.getDescribe().fields.getMap();
            for (String fieldName : allFieldMap.keyset()) {
                Schema.DescribeFieldResult theField = allFieldMap.get(fieldName).getDescribe();
                if ((theField.isCustom() || theField.isNameField()) && theField.isAccessible()) {
                    results.add(theField.getName());
                }
            }
        }
        return results;
    }

    //Inner class to operate in without sharing context
    private without sharing class ProxyDMLHelper {
        //bulk insert
        public void insertByProxy(List<SObject> objs) {
            insert objs;
        }
        //bulk insert with AllOrNothing parameter
        public List<Database.SaveResult> insertByProxy(List<SObject> objs, Boolean allOrNone) {
            return Database.insert(objs, allOrNone);
        }
        //bulk update
        public void updateByProxy(List<SObject> objs) {
            update objs;
        }
        //bulk update with AllOrNone parameter
        public List<Database.SaveResult> updateByProxy(List<SObject> objs, Boolean allOrNone) {
            return Database.update(objs, allOrNone);
        }
        //bulk upsert
        public void upsertByProxy(List<SObject> objs) {
            upsert objs;
        }

        public List<Database.UpsertResult> upsertByProxy(List<SObject> objs, Boolean allOrNone) {
            return Database.upsert(objs, allOrNone);
        }

        //bulk delete
        public void deleteByProxy(List<SObject> objs) {
            delete objs;
        }
        //bulk delete with AllOrNone parameter
        public void deleteByProxy(List<SObject> objs, Boolean allOrNone) {
            Database.delete(objs, allOrNone);
        }

        public void deleteByProxy(List<Id> objsIds) {
            Database.delete(objsIds);
        }

        public List<Database.DeleteResult> deleteByProxyDatabase(List<SObject> objs, Boolean allOrNone) {
            return Database.delete(objs, allOrNone);
        }
    }

}