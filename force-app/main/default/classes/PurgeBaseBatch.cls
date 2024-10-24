public with sharing abstract class PurgeBaseBatch implements Database.Batchable<SObject>, Database.Stateful {

    protected final String objectLabel;
    protected Boolean isCashFlowStatementEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
    protected Boolean isSendEmail = true;

    protected Set<Id> getClosedAccountingPeriodsById(Id valueAccPeriod) {
        Set<Id> result;
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            Accounting_Period__c theAccountingPeriod = acctPeriodHandler.getAccountingPeriodById(valueAccPeriod);
            if (theAccountingPeriod != NULL) {
                Map<Id, Accounting_Period__c> closedAccPeriods = new Map<Id, Accounting_Period__c>(
                    acctPeriodHandler.getPreviousAccountingPeriods(
                        theAccountingPeriod,
                        new Set<String>{AccountingPeriodActions.CLOSED_STATUS, AccountingPeriodActions.ARCHIVED_STATUS},
                        true
                    )
                );
                result = closedAccPeriods.keySet();
            }
        }
        catch (Exception ex) {
            throw new AccountingPeriodHandler.AccountingPeriodException(ex.getMessage());
        }
        return result;
    }

    public abstract Database.QueryLocator start(Database.BatchableContext bc);

    public virtual void execute(Database.BatchableContext bc, List<SObject> scope) {
        SFDCSecurityUtils.deleteProxy(scope);
        Database.emptyRecycleBin(scope);
    }

    public void finish(Database.BatchableContext bc) {
        List<AsyncApexJob> runningAsyncApexJobs = DomainUtils.getAsyncApexJobById(new Set<Id>{bc.getJobId()});

        if (!runningAsyncApexJobs.isEmpty()) {
            AsyncApexJob a = runningAsyncApexJobs[0];
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>{a.CreatedBy.Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject(Label.COMMON_ACCOUNTING_SEED_FINANCIAL_SUITE + objectLabel + Label.COMMON_PURGE_JOB_COMPLETED);
            mail.setPlainTextBody(
                Label.COMMON_PURGING_PROCESSED + a.TotalJobItems +
                    Label.COMMON_BATCHES_WITH+ a.NumberOfErrors + Label.COMMON_FAILURES_PURGING_OF + objectLabel + Label.COMMON_FINISHED_WITH +
                    a.Status + Label.COMMON_STATUS_VALUE
            );
            if (!Test.isRunningTest() && isSendEmail) {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            }
        }

    }

}