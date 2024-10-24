public with sharing class ArchiveTransactionsController {

    @TestVisible
    private static final String NOT_VALID_PERIOD_ERROR = Label.ERR_NOT_VALID_AP_ARCHIVE;
    @TestVisible
    private static final String PRIOR_PERIOD_NOT_ARCHIVED_ERROR = Label.ERR_PRIOR_PERIOD_NOT_ARCHIVED;
    @TestVisible
    private static final String ARCHIVING_STARTED_CONFIRMATION = Label.WRN_ARCHIVING_STARTED_CONFIRMATION;
    @TestVisible
    private static final Integer MOST_RECENT_VALID_PERIOD_OFFSET = getArchivePeriodOffset();
    public static final String JOB_IN_PROGRESS_ERROR = Label.ERR_JOB_IN_PROGRESS_ACCOUNTING_PERIOD;
    @TestVisible
    private static Date testableTodayDate {get; set;}

    public Accounting_Period__c acctPeriod {get; set;}
    public Boolean isError {get; set;}


    public ArchiveTransactionsController(ApexPages.StandardController controller) {
        try {
            checkAccess();
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            this.acctPeriod = acctPeriodHandler.getAccountingPeriodById(controller.getId());
            this.isError = isPeriodNotValid(acctPeriod);
            //first check the selected period
            if (isError) {
                String periodOffset = String.valueOf(MOST_RECENT_VALID_PERIOD_OFFSET * -1);
                String validAccountingPeriod = acctPeriodHandler.getAccountingPeriodByOffset(
                    acctPeriodHandler.getAccountingPeriodByDate(
                        (Test.isRunningTest()) ? ArchiveTransactionsController.testableTodayDate : Date.today()
                    ).Id,
                    MOST_RECENT_VALID_PERIOD_OFFSET
                ).Name;
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(NOT_VALID_PERIOD_ERROR, new List<String>{periodOffset, validAccountingPeriod})
                    )
                );
            }
            else {
                //then check the status of prior period (must be 'Archived')
                this.isError = isPriorPeriodNotValid(acctPeriod);
                if (isError) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, PRIOR_PERIOD_NOT_ARCHIVED_ERROR));
                }
            }

            if (isConsolidationJobInProgress()) {
                this.isError = true;
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    AccountingPeriodActions.CONSOLIDATION_IN_PROGRESS_ERROR
                ));
            }
        }
        catch (Exception ex) {
            this.isError = true;
            ApexPages.addMessages(ex);
        }
    }

    public PageReference doArchiving() {
        ArchiveResult result = archive(acctPeriod.Id);
        if (result.isSuccess) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, result.message));
        }
        else {
            if (ApexPages.getMessages().isEmpty()) {
                // avoid showing same dml errors twice (one at field level + one at object level)
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, result.message));
            }
        }
        isError = true;//acts as process end indicator
        return NULL;
    }

    private static Integer getArchivePeriodOffset() {
        AccountingLimitHandler aLimitHandler = AccountingLimitHandler.getInstance();
        return aLimitHandler.getLimit(AccountingLimitHandler.LimitType.ARCHIVE_PERIOD_OFFSET) * -1;
    }

    public ArchiveResult archive(String acctPeriodId) {
        try {
            Accounting_Period__c acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(acctPeriodId);

            if (isConsolidationJobInProgress()) {
                return new ArchiveResult(false, AccountingPeriodActions.CONSOLIDATION_IN_PROGRESS_ERROR);
            }

            if (isPeriodNotValid(acctPeriod)) {
                return new ArchiveResult(false, NOT_VALID_PERIOD_ERROR);
            }

            if (isAccountingPeriodJobInProgress()) {
                return new ArchiveResult(false, JOB_IN_PROGRESS_ERROR);
            }

            acctPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            AccountingPeriodActions.isPreventUpdateOverride = true;
            SFDCSecurityUtils.updateProxy(acctPeriod);
            AccountingPeriodActions.isPreventUpdateOverride = false;

            /*
            * Start batch jobs chain
            * 1. ArchiveDeleteFCubesBatch
            * 2. ArchiveFCubesBatch
            * 3. ArchiveAndDeleteTransactionsBatch
            * */
            Database.executeBatch(new ArchiveDeleteFCubesBatch(acctPeriod), 2000);
        }
        catch (Exception ex) {
            return new ArchiveResult(false, Label.ERR_PERIOD_STATUS_CANNOT_UPDATE + ': ' + ex.getMessage());
        }

        return new ArchiveResult(true, ARCHIVING_STARTED_CONFIRMATION);
    }

    private Boolean isPeriodNotValid(Accounting_Period__c acctPeriod) {
        Boolean result = false;
        Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(
            (Test.isRunningTest()) ? ArchiveTransactionsController.testableTodayDate : Date.today()
        );
        Accounting_Period__c mostRecentValidPeriod =
            AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, MOST_RECENT_VALID_PERIOD_OFFSET);

        if (acctPeriod.Status__c != AccountingPeriodActions.CLOSED_STATUS
                || mostRecentValidPeriod.Id == NULL/*means there is no any valid periods on org*/
                || acctPeriod.Name > mostRecentValidPeriod.Name) {

            result = true;
        }

        return result;
    }

    private Boolean isPriorPeriodNotValid(Accounting_Period__c acctPeriod) {
        Boolean result = false;
        Accounting_Period__c priorAcctPeriod =
            AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(acctPeriod);

        if (priorAcctPeriod.Id != NULL && priorAcctPeriod.Status__c != AccountingPeriodActions.ARCHIVED_STATUS) {
            result = true;
        }
        return result;
    }

    private Boolean isAccountingPeriodJobInProgress() {
        return AccountingPeriodOpenCloseUtils.isAccountingPeriodJobInProgress();
    }

    private Boolean isConsolidationJobInProgress() {
        List<AsyncApexJob> asyncApexJobs = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            AccountingPeriodActions.consolidationRoutineClasses, AccountingPeriodActions.JOB_STATUSES
        );
        return asyncApexJobs != NULL && !asyncApexJobs.isEmpty();
    }

    public with sharing class ArchiveResult {
        public Boolean isSuccess {get; set;}
        public String message {get; set;}

        public ArchiveResult(Boolean isSuccess, String message) {
            this.isSuccess = isSuccess;
            this.message = message;
        }
    }

    private void checkAccess() {
        SFDCSecurityUtils.checkRead(Accounting_Period__c.getSObjectType(), new List<String>{'Status__c'});
        SFDCSecurityUtils.checkUpdate(Accounting_Period__c.getSObjectType(), new List<String>{'Status__c'});
        SFDCSecurityUtils.checkRead(
            Financial_Cube__c.getSObjectType(),
            new List<String>{'Transaction_Amount__c', 'Amount__c', 'Archived_Amount__c', 'Cube_Type__c', 'Opening_Balance__c'}
        );
        SFDCSecurityUtils.checkUpdate(
            Financial_Cube__c.getSObjectType(),
            new List<String>{'Amount__c', 'Archived_Amount__c'}
        );
        SFDCSecurityUtils.checkObjectIsDeletable(Financial_Cube__c.getSObjectType());
        SFDCSecurityUtils.checkRead(
            Transaction__c.getSObjectType(),
            new List<String>{
                'Account__c',
                'Accounting_Period__c',
                'Accounting_Year__c',
                'Scheduled_Revenue_Expense__c',
                'Amount__c',
                'AP_Disbursement__c',
                'Billing_Cash_Receipt__c',
                'Billing__c',
                'Billing_Line__c',
                'Account_Payable__c',
                'Account_Payable_Line__c',
                'Cash_Disbursement__c',
                'Cash_Flow_Category__c',
                'Cash_Receipt__c',
                'Contact__c',
                'Currency_Conversion_Rate__c',
                'Date__c',
                'Employee__c',
                'Foreign_Amount__c',
                'Foreign_Currency__c',
                'GL_Account__c',
                'GL_Account_Type__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Journal_Entry_Line__c',
                'Ledger__c',
                'Note__c',
                'Product__c',
                'Project__c',
                'Project_Task__c',
                'Units__c',
                'Report_Amount__c',
                'Time_Card_Day__c',
                'Time_Card_Variable_1__c',
                'Time_Card_Variable_2__c'
            }
        );
        SFDCSecurityUtils.checkObjectIsDeletable(Transaction__c.getSObjectType());
        SFDCSecurityUtils.checkInsert(
            Transaction_Archive__b.getSObjectType(),
            new List<String>{
                'AP_Disbursement__c',
                'Account__c',
                'Accounting_Period__c',
                'Accounting_Year__c',
                'Amortization_Entry__c',
                'Amount__c',
                'Billing_Cash_Receipt__c',
                'Billing__c',
                'Billing_Line__c',
                'Cash_Disbursement__c',
                'Cash_Flow_Category__c',
                'Cash_Receipt__c',
                'Contact__c',
                'Currency_Conversion_Rate__c',
                'Date__c',
                'Employee__c',
                'Financial_Cube__c',
                'Financial_Cube_Type__c',
                'Foreign_Amount__c',
                'Foreign_Currency__c',
                'GL_Account_Type__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'GL_Account__c',
                'Journal_Entry_Line__c',
                'Ledger__c',
                'Note__c',
                'Payable__c',
                'Payable_Line__c',
                'Product__c',
                'Project_Task__c',
                'Project__c',
                'Quantity__c',
                'Report_Amount__c',
                'Time_Card_Day__c',
                'Time_Card_Variable_1__c',
                'Time_Card_Variable_2__c',
                'Transaction_Id__c',
                'Source_Name__c'
            }
        );
    }

}