public with sharing class AccountUpdateStatementStatusCntrlExt {

    public static final String NO_RECORDS_SELECTED_ERROR = Label.COMMON_NO_RECORDS_SELECTED_ERROR;
    public static final String SUCCESS_MESSAGE = Label.INF_UPDATE_STATEMENT_STATUS_JOB_MESSAGE;
    public Boolean isSuccess {get; set;}
    private List<Account> selectedAccounts;


    public AccountUpdateStatementStatusCntrlExt(ApexPages.StandardSetController setController) {
        selectedAccounts = setController.getSelected();
        isSuccess = false;
        if (selectedAccounts.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_RECORDS_SELECTED_ERROR));
            isSuccess = true;
        }
    }

    public PageReference runAction() {
        Set<Id> selectedIds = new Set<Id>();
        for (Account acc : selectedAccounts) {
            selectedIds.add(acc.Id);
        }
        AccountUpdateStatementStatusBatch updateBatch = new AccountUpdateStatementStatusBatch(selectedIds);
        Database.executeBatch(updateBatch);

        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, SUCCESS_MESSAGE));
        isSuccess = true;
        return NULL;
    }
}