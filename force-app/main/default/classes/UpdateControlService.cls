/**
 * This class will treat as a service to identify any set of fields has been changed or not.
 */
public with sharing class UpdateControlService extends AccessControlService{
    
    public UpdateControlService(AccessControlInterface fieldSet, Schema.SObjectType sObjType) {
        super(fieldSet, sObjType);
    }

    /**
     * This method check field value changed or not in insert case only
    */
    public Boolean checkInsertFieldChanges() {
        return isInsertFieldsChanged();
    }
    
    /**
     * This method check field value changed or not in update case only
    */
    public Boolean checkUpdateFieldChanges() {
        return isUpdateFieldsChanged();
    }
}