public with sharing class MassAddEditLineController {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private ApexPages.StandardSetController setController;
    private Id masterRecordId;

    public SObject masterRecord {get; set;}
    public Boolean isError {get; set;}
    public Boolean isRecordPosted {get; set;}
    public class MassAddRowException extends Exception {}

    public MassAddEditLineController(ApexPages.StandardSetController setCon) {
        this.setController = setCon;
        this.masterRecordId = ApexPages.currentPage().getParameters().get('id');
        this.isError = false;
        this.isRecordPosted = false;
        try {
            init();
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
        }
    }

    private void init() {
        if (masterRecordId == NULL) {
            throw new MassAddRowException(Label.INF_ID_MASTER_RECORD_REQUIRED_PARAMETER);
        }

        String masterRecordAPIName = masterRecordId.getSObjectType().getDescribe().getName();
        String masterRecordSObjectLabel = masterRecordId.getSObjectType().getDescribe().getLabel();
        
        //===============================================================================================
        // This controller extension will always be bound to a custom button on a detail page related list. It stands to reason that 
        // a user would not be able to access the this controller extension if they did not have read access to the object.
        // An FLS check is not performed because the Status__c field is needed by the system to check whether further processing can occur.
        // This check must be performed regardless of user FLS access.
        //===============================================================================================
        String dynamicQuery =
            'SELECT Id, ' +
                    String.escapeSingleQuotes(PACKAGE_QUALIFIER + 'Status__c ') +
            'FROM ' + String.escapeSingleQuotes(masterRecordAPIName) + ' ' +
            'WHERE Id = :masterRecordId LIMIT 1';
        try {
            masterRecord = Database.query(dynamicQuery)[0];
        }
        catch (Exception ex) {
            throw new MassAddRowException(Label.ERR_CANNOT_QUERY_MASTER_RECORD_ERROR + ex.getMessage());
        }

        if (masterRecord.get('Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
            || masterRecord.get('Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS
            || masterRecord.get('Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS) {
            isRecordPosted = true;
        }
    }

}