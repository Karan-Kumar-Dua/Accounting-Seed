public with sharing class CashDisbursementBatchRenumber {
   
    public static final String NO_STARTING_NUMBER_ERROR = Label.ERR_CD_BATCH_NO_STARTING_CHECK;
    public static final String POSTED_CD_ERROR = Label.ERR_CD_BATCH_UNPOST_RENUMBER;
    public static final String CONFIRMATION_MESSAGE = Label.WRN_RENUMBER_ALL_CHECKS;
    public static final String OPERATION_SUCCESS_MESSAGE = Label.INF_CD_RENUMBERED_SUCCESS;

    private final ApexPages.StandardController stdController;
    private Cash_Disbursement_Batch__c cashDisbursementBatch {get; set;}
    public Boolean isValidationPassed {get; set;}

    public CashDisbursementBatchRenumber(ApexPages.StandardController controller) {
        this.stdController = controller;
        if (!Test.isRunningTest()) {
            this.stdController.addFields(new List<String>{'Starting_Check_Number__c'});
        }
        this.cashDisbursementBatch = (Cash_Disbursement_Batch__c) this.stdController.getRecord();
        this.isValidationPassed = validateOnLoad();
    }

    private Boolean validateOnLoad() {
        //=================================================================
        // CRUD and FLS not performed as aggregation query is used to perform system validation
        // and no information will not be exposed to the end user
        //=================================================================
        Integer postedCount = DomainUtils.getCountOfCashDisbursementsByCDB(cashDisbursementBatch.Id, 'Posted');

        if (postedCount > 0) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, POSTED_CD_ERROR));
            return false;
        }

        if (cashDisbursementBatch.Starting_Check_Number__c == NULL) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, NO_STARTING_NUMBER_ERROR));
            return false;
        }

        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, CONFIRMATION_MESSAGE));
        return true;
    }

    public PageReference renumberChecks() {
        if (this.isValidationPassed) {
            try {
                List<Cash_Disbursement__c> updateList = new List<Cash_Disbursement__c>();
                String cashDisbursementBatchId = cashDisbursementBatch.Id;

                //Prepare SOQL Query to query Cash Disbursements with CRUD and FLS checks
                List<String> queryFields = new List<String>{
                    'Id',
                    'Check_Number__c'
                };

                String queryCondition =
                    'Cash_Disbursement_Batch__c = :cashDisbursementBatchId ' +
                    'ORDER BY Check_Number__c ASC';

                SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
                theQuery
                    .assertIsAccessible()
                    .setEnforceFLS(true)
                    .selectFields(queryFields)
                    .setCondition(queryCondition);

                for (Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL())) {
                    cashDisbursement.Check_Number__c = cashDisbursementBatch.Starting_Check_Number__c;
                    updateList.add(cashDisbursement);
                    cashDisbursementBatch.Starting_Check_Number__c += 1;
                }

                SFDCSecurityUtils.updateCheckCRUDAndFLS(updateList, new List<String>{
                    'Check_Number__c'
                });
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, OPERATION_SUCCESS_MESSAGE));
                isValidationPassed = false;
            }
            catch (Exception ex) {
                ApexPages.addMessages(ex);
            }
        }
        return NULL;
    }

}