public with sharing virtual class AccessControlService { 
 
    public class AccessControlException extends Exception{} 
    private AccessControlInterface control; 
    public Boolean hasAccess; 
    public Boolean isTriggerExecuting = Trigger.isExecuting; 
    public Boolean isInsert = Trigger.isInsert; 
    public Boolean isUpdate = Trigger.isUpdate; 
    @TestVisible 
    private List<sObject> newRecs; 
    @TestVisible 
    private List<sObject> oldRecs; 
    @TestVisible
    private Set<String> fieldApiNames;
    public List<Schema.SObjectField> fields;
    @TestVisible
    private Schema.SObjectType sObjType;
    @TestVisible
    private String fieldLabelsString; 
 
    /*constructor contains two Params that is className that implement "AccessControlInterface" and second is sobject type 
      which required validation based on specific features
    */ 
    public AccessControlService(AccessControlInterface control, Schema.SObjectType sObjType){ 
        this.control = control; 
        // hasAccess used to determine whether passed feature is enabled on not in subscriber org.
        this.hasAccess = this.control.isFeatureEnabled(); 
        // fields used to collect all the fields which are part of passed feature corrospond to object
        fields = this.control.getFieldGrants().get(sObjType);
        // variable used to hold field label of selected object field from its field api name
        fieldLabelsString =  this.control.getFieldLabels(fields);
        //if we are only checking object grants then we may not have a collection of fields to check
        if(fields != null ){
            fieldApiNames = this.getFieldApiNames(fields); 
        }
        this.sObjType = sObjType;

        if(this.isInsert || this.isUpdate){ 
            this.newRecs = Trigger.new; 
        } 
        if(this.isUpdate){ 
            this.oldRecs = Trigger.old; 
        } 
    }
    
    public AccessControlService(List<Schema.SObjectField> individualFields){
        fields = individualFields;

        if(fields != null ){
            fieldApiNames = this.getFieldApiNames(fields); 
        }

        if(this.isInsert || this.isUpdate){ 
            this.newRecs = Trigger.new; 
        } 
        if(this.isUpdate){ 
            this.oldRecs = Trigger.old; 
        } 
    } 
 
    /**
     * This method is used to check the object can be used or not with respect to enabled feature if the 
     * feature is not enabled and passed object has been used as part of provided feature then it should throw error.
     */
    public void checkObjectGrant(){ 
        //verify access to the feature and the target object 
        if(!this.hasAccess && this.isTriggerExecuting && this.control.getSObjectsGrants().contains(sObjType)){ 
            Schema.DescribeSObjectResult dr = sObjType.getDescribe();
            //use trigger.new for object level check for insert and update and use otrigger.old for delete context
            for(sObject s : Trigger.isDelete ? Trigger.old : Trigger.new) { 
                s.addError( String.format(Trigger.isDelete ? Label.ERR_OBJECT_FEATURE_DISABLED_DELETE : Label.ERR_OBJECT_FEATURE_DISABLED, new List<String>{dr.getLabel()}) );
            } 
        } 
    }

    /**
     * This method is useed to return treu/false based on invalid sobject record that has been inserted
     * without provided feature enable.
    */
    public Boolean isInsertFieldsChanged() {
        return getInsertFieldChangeRecord() != null;
    }

    /**
     * This method is useed to return invalid sobject record that has been changed while inserting,
     * and that returned sobject has been used for further processing like addError etc....
    */    
    public sObject getInsertFieldChangeRecord() {
        for(sObject s : this.newRecs) { 
            for (Schema.SObjectField fld : fields) { 
                
                Schema.DescribeFieldResult dfr = fld.getDescribe();
                //Verify the field is empty/null or false (in the case of booleans) 
                if(s.get(fld) != null && s.get(fld) != false) {
                    return s;
                }
            }
        }
        return null;
    }
    
    /**
     * This method is used to check the fields can be used or not with respect to enabled feature if the 
     * feature is not enabled and passed fields related to object has been used as part of provided feature 
     * in INSERT operation of trigger then it should throw error.
    */
    public void checkInsertFieldGrants(){ 
        if(!this.hasAccess && this.isTriggerExecuting){ 
            sObject rec = getInsertFieldChangeRecord();
            if(rec != null) {
                rec.addError(String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<String>{fieldLabelsString}));  
            }
        } 
    }

    /**
     * This method is useed to return treu/false based on invalid sobject record that has been updated.
    */
    public Boolean isUpdateFieldsChanged() {
        return getUpdateFieldChangeRecord() != null;
    }
    
    /**
     * This method is useed to return invalid sobject record that has been changed while updating records,
     * and that returned sobject has been used for
     * further processing like addError etc....
    */
    public sObject getUpdateFieldChangeRecord() {
        Map<Id, sObject> mOldRecs = new Map<Id, sObject>(this.oldRecs); 
        for(sObject newRec : this.newRecs) { 
            sObject iOldRec = mOldRecs.get(newRec.Id); 
            Map<String, Object> mNewFields = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(newRec, true)); 
            Map<String, Object> mOldFields = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(iOldRec, true)); 
            mNewFields.keySet().retainAll(fieldApiNames); 
            mOldFields.keySet().retainAll(fieldApiNames);
            //Check if the values of the access controlled fields have changed by examining the old/new map key/value equality 
            if(!mNewFields.equals(mOldFields)){ 
                return newRec;            
            } 
        }
        return null;
    }
    
    /**
     * This method is used to check the fields can be used or not with respect to enabled feature if the 
     * feature is not enabled and passed fields related to object has been used as part of provided feature 
     * in UPDATE operation of trigger then it should throw error.
     */
    public void checkUpdateFieldGrants(){ 
        if(!this.hasAccess && this.isTriggerExecuting){ 
            sObject newRec = getUpdateFieldChangeRecord();
            if(newRec != null){ 
                newRec.addError(String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<String>{fieldLabelsString})); 
            } 
        }
    } 
 
    private Set<String> getFieldApiNames(List<Schema.SObjectField> fields){ 
        Set<String> fieldApiNames = new Set<String>(); 
        for(Schema.SObjectField f : fields){ 
            fieldApiNames.add(String.valueOf(f)); 
        } 
        return fieldApiNames; 
    } 
 
}