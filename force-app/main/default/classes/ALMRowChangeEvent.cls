global with sharing class ALMRowChangeEvent {
    /**
     * the previous state of the changed row
     */
    global sObject oldRow;
    /**
     * the updated row 
     */
    global sObject updatedRow;
    /**
     * the parent object api name 
     */
    global String headerObjectApiName;
}