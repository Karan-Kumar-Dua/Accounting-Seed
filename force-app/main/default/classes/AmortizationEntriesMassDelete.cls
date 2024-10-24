public with sharing class AmortizationEntriesMassDelete {

    private final ApexPages.StandardSetController setController;
    private List<Scheduled_Revenue_Expense__c> selectedRecords;
    private List<Scheduled_Revenue_Expense__c> validForDeletionRecords;

    public static final String NO_SELECTION_ERROR_MESSAGE = Label.ERR_NO_SELECTION_POSTED_DELETE_BLOCK;
    public static final String CONFIRMATION_MESSAGE = Label.COMMON_RECORDS_DELETED;

    public Boolean showDeleteButton {get; set;}

    public AmortizationEntriesMassDelete(ApexPages.StandardSetController setCntrl) {
        this.setController = setCntrl;
        this.showDeleteButton = true;
        this.selectedRecords = querySelectedRecords(setController.getSelected());
    }

    private List<Scheduled_Revenue_Expense__c> querySelectedRecords(List<SObject> selectedRecs) {
        List<String> queryFields = new List<String>{
            'Id', 'Status__c'
        };

        String queryCondition = 'Id IN :selectedRecs';
        SOQLBuilder theQuery = new SOQLBuilder(Scheduled_Revenue_Expense__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(200);

        return (List<Scheduled_Revenue_Expense__c>) Database.query(theQuery.toSOQL());
    }

    public PageReference validateSelectedRecords() {
        this.validForDeletionRecords = new List<Scheduled_Revenue_Expense__c>();
        for (Scheduled_Revenue_Expense__c selectedRecord : this.selectedRecords) {
            if (selectedRecord.Status__c != 'Posted') {
                this.validForDeletionRecords.add(selectedRecord);
            }
        }

        if (this.validForDeletionRecords.isEmpty()) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    AmortizationEntriesMassDelete.NO_SELECTION_ERROR_MESSAGE
                )
            );
            showDeleteButton = false;
        }

        return NULL;
    }

    public PageReference deleteRecords() {
        try {
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(validForDeletionRecords);
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.CONFIRM,
                    AmortizationEntriesMassDelete.CONFIRMATION_MESSAGE
                )
            );
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }

        showDeleteButton = false;
        return NULL;
    }

}