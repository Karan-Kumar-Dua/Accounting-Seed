public inherited sharing class SOQLAccessDecisionUtil {

    private List<SObject> objs;
    private SObjectAccessDecision decision;
    private AccessType selectedAccessType = AccessType.READABLE;
    private Boolean enforceCRUD = true;
    private Boolean isCRUDException = false;

    public SOQLAccessDecisionUtil() {
        this.objs = new List<SObject>();
    }

    public SOQLAccessDecisionUtil(List<SObject> objs) {
        this.objs = objs;
        getAccessDecision();
    }

    public SOQLAccessDecisionUtil(List<SObject> objs, AccessType accessType) {
        this.objs = objs;
        this.selectedAccessType = accessType;
        getAccessDecision();
    }

    public SOQLAccessDecisionUtil(List<SObject> objs, AccessType accessType, Boolean enforceCRUD) {
        this.objs = objs;
        this.selectedAccessType = accessType;
        this.enforceCRUD = enforceCRUD;
        getAccessDecision();
    }

    public void setAccessType(AccessType accessType) {
        this.selectedAccessType = accessType;
    }

    public void setEnforceCRUD(Boolean enforceCRUD) {
        this.enforceCRUD = enforceCRUD;
    }

    public void setSObjects(List<SObject> objs) {
        this.objs = objs;
        getAccessDecision();
    }

    public List<SObject> getRecords() {
        return isAccessDecision() ? decision.getRecords() : new List<SObject>();
    }

    public Map<String, Set<String>> getRemovedFields() {
        return isAccessDecision() ? decision.getRemovedFields() : new Map<String, Set<String>>();
    }

    public Boolean isAccessDecision() {
        return decision != NULL;
    }

    public Boolean isAccessDecisionCRUDException() {
        return isCRUDException;
    }

    private void getAccessDecision() {
        try {
            decision = Security.stripInaccessible(selectedAccessType, objs, enforceCRUD);
        }
        catch (Exception ex) {
            isCRUDException = true;
        }
    }

}