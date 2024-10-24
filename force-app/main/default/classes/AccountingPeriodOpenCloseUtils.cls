public with sharing class AccountingPeriodOpenCloseUtils {

    public static final Integer PAYABLE_AND_BILLING_AGING_BATCH_SIZE = 200;
    public static final Integer ACCOUNTING_PERIOD_OPEN_BATCH_SIZE = 2000;
    public static final String JOB_IN_PROGRESS_ERROR = Label.ERR_ACCOUNTING_PERIOD_JOB_IN_PROGRESS;
    public static final String CURRENT_EARNINGS_ERROR = Label.ERR_ACCOUNTING_PERIOD_CURRENT_EARNINGS;
    public static final String RETAINED_EARNINGS_ERROR = Label.ERR_ACCOUNTING_PERIOD_RETAINED_EARNINGS;
    public static final String ARCHIVE_SUCCESSFUL_EMAIL_SUBJECT = Label.INF_ACCOUNTING_PERIOD_ARCHIVE_SUCCESSFUL_EMAIL_SUBJECT;
    public static final String ARCHIVE_SUCCESSFUL_EMAIL_BODY = Label.INF_ACCOUNTING_PERIOD_ARCHIVE_SUCCESSFUL_EMAIL_BODY;
    public static final String ARCHIVE_FAILED_EMAIL_SUBJECT = Label.INF_ACCOUNTING_PERIOD_ARCHIVE_FAILED_EMAIL_SUBJECT;
    public static final String ARCHIVE_FAILED_EMAIL_BODY = Label.INF_ACCOUNTING_PERIOD_ARCHIVE_FAILED_EMAIL_BODY;
    public static final String NEXT_PERIOD_DOES_NOT_EXISTS_ERROR_MESSAGE = Label.ERR_ACCOUNTING_PERIOD_NEXT_PERIOD_DOES_NOT_EXISTS;
    public static final String ACCOUNTING_PERIOD_CLOSE_REQUEST_EMAIL_SUBJECT = Label.INF_ACCOUNTING_PERIOD_CLOSE_REQUEST_EMAIL_SUBJECT;

    public static final Set<String> openCloseAccountingPeriodClasses = new Set<String>{
        'AccountingPeriodCloseBatchProcessor',
        'AccountingPeriodCloseBillingAging',
        'AccountingPeriodCloseAPAging',
        'AccountingPeriodOpenBatchProcessor',
        'AccountingPeriodOpenBillingAging',
        'AccountingPeriodOpenAPAging',
        'AccountingPeriodDeleteEarningsCubesBatch',
        'AccountingPeriodCloseRetainedEarnings'
    };

    public static final Set<String> archiveAccountingPeriodClasses = new Set<String>{
        'AccountingPeriodArchiveTransactionBatch',
        'AccountingPeriodArchiveFCubes',
        'AccountingPeriodDeleteTransactionBatch'
    };

    public static Boolean isPreventJobSearchSkip = true;

    public enum PeriodUpdateContext {OPENING, CLOSING, SOFT_OPEN, SOFT_CLOSE}

    public static Boolean isAccountingPeriodJobInProgress() {
        //1. First validation step - query running Jobs
        List<AsyncApexJob> runningApexJobs = DomainUtils.getOpeningClosingPeriodRelatedAsyncApexJobs();
        if (!runningApexJobs.isEmpty() && isPreventJobSearchSkip) {
            return true;
        }

        //2. Second step - even if previous query did not return any running jobs - the chain may not be completed yet
        //So we have to be sure that there are no any completed jobs which were completed in previous 2 minutes
        Set<String> classNames = new Set<String>();
        classNames.addAll(openCloseAccountingPeriodClasses);
        classNames.addAll(archiveAccountingPeriodClasses);

        List<AsyncApexJob> recentlyCompletedJobs = DomainUtils.getRecentAsyncApexJobByApexClassNameAndStatus(
            classNames, new Set<String>{'Completed'}, System.now().addMinutes(-2)
        );

        if (!recentlyCompletedJobs.isEmpty() && isPreventJobSearchSkip) {
            return true;
        }

        return false;
    }

    public static void updatePeriodStatus(List<Accounting_Period__c> periods, String status) {
        Set<Id> acctPeriodIds = new Map<Id, Accounting_Period__c>(periods).keySet();
        List<Accounting_Period__c> periodsToUpdate = AccountingPeriodHandler.getInstance().getAccountingPeriodsById(acctPeriodIds);
        for (Accounting_Period__c periodToUpdate : periodsToUpdate) {
            periodToUpdate.Status__c = status;
        }
        AccountingPeriodActions.isFirstRun = false;
        SFDCSecurityUtils.updateProxy(periodsToUpdate);
    }

    // Delete all current year earnings and retained earning from accounting period; set all next period cube values to null
    public static void openAccountingPeriods(List<Accounting_Period__c> newPeriods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        List<Accounting_Period__c> sortableCollection = getSortedCollection(newPeriods);

        if (newPeriods[0].Status__c == AccountingPeriodActions.OPEN_STATUS
                && oldPeriodMap.get(newPeriods[0].Id).Status__c == AccountingPeriodActions.CLOSED_STATUS) {

            try {
                if (!isAccountingPeriodJobInProgress()) {
                    AccountingPeriodOpenCloseOptions periodInfoContainer =
                        new AccountingPeriodOpenCloseOptions(
                            sortableCollection, sortableCollection.size() -1, PeriodUpdateContext.OPENING
                        );

                    Database.executeBatch(new AccountingPeriodOpenBatchProcessor(periodInfoContainer), ACCOUNTING_PERIOD_OPEN_BATCH_SIZE);
                    updatePeriodStatus(sortableCollection, AccountingPeriodActions.OPEN_INTERIM_STATUS);
                }
                else {
                    throw new AccountingPeriodHandler.AccountingPeriodException(JOB_IN_PROGRESS_ERROR);
                }
            }
            catch (Exception ex) {
                handleError(newPeriods, ex);
            }
        }
    }
    
    public static void closeAccountingPeriods(List<Accounting_Period__c> newPeriods, Map<Id, Accounting_Period__c> oldPeriodMap) {
        try {
            List<Accounting_Period__c> sortableCollection = getSortedCollection(newPeriods);

            if (oldPeriodMap.get(newPeriods[0].Id).Status__c == AccountingPeriodActions.OPEN_STATUS
                    && newPeriods[0].Status__c == AccountingPeriodActions.CLOSED_STATUS) {
                if (!isAccountingPeriodJobInProgress()) {
                    validateNextPeriod(newPeriods, sortableCollection);

                    AccountingPeriodOpenCloseOptions periodInfoContainer =
                        new AccountingPeriodOpenCloseOptions(
                            sortableCollection,
                            0,
                            PeriodUpdateContext.CLOSING
                        );

                        deleteCurrentAndRetainedEarningsBeforeNextBatch(periodInfoContainer);
                }
                else {
                    handleError(newPeriods, JOB_IN_PROGRESS_ERROR);
                }
            }
        }
        catch (AccountingPeriodHandler.AccountingPeriodException ex) {
            //When next period does not exist
            handleError(newPeriods, ex);
        }
        catch (Exception ex) {
            handleError(newPeriods, ex);
        }
    }

    private static void handleError(List<Accounting_Period__c> newPeriods, String error) {
        for (Accounting_Period__c period : newPeriods) {
            period.addError(error);
        }
    }

    private static void handleError(List<Accounting_Period__c> newPeriods, Exception error) {
        for (Accounting_Period__c period : newPeriods) {
            period.addError(error);
        }
    }

    private static void validateNextPeriod(List<Accounting_Period__c> newPeriods, List<Accounting_Period__c> sortableCollection) {
        //check next period after last period in batch
        Accounting_Period__c lastPeriodInCollection = sortableCollection[sortableCollection.size() - 1];
        Accounting_Period__c nextPeriod =
            AccountingPeriodHandler.getInstance().getNextAccountingPeriod(lastPeriodInCollection);

        String errorMessage = String.format(
            NEXT_PERIOD_DOES_NOT_EXISTS_ERROR_MESSAGE,
            new List<String>{nextPeriod.Name, lastPeriodInCollection.Name}
        );

        if (nextPeriod.Id == NULL) {//means next period does not exist
            //if this is batch period processing and there is no next period after last period in the selected list
            //=> add DML error to last period in collection and remove this period from the list
            if (newPeriods.size() > 1) {
                for (Accounting_Period__c newPeriod : newPeriods) {
                    if (newPeriod.Id == lastPeriodInCollection.Id) {
                        newPeriod.addError(errorMessage);
                    }
                }

                sortableCollection.remove(sortableCollection.size() - 1);
            }
            else {
                //if this is single period processing and there is no next period for the current one
                //=> throw an exception to prevent further processing
                throw new AccountingPeriodHandler.AccountingPeriodException(errorMessage);
            }
        }
    }

    public static void deleteCurrentAndRetainedEarningsBeforeNextBatch(AccountingPeriodOpenCloseOptions periodInfoContainer) {
        try {
            Set<Id> currentPeriodIds = new Set<Id>();
            Set<Id> nextPeriodIds = new Set<Id>();
            if (periodInfoContainer.context == PeriodUpdateContext.CLOSING) {
                //get current period Ids for CYE
                currentPeriodIds = new Map<Id, Accounting_Period__c>(periodInfoContainer.selectedPeriods).keySet();
                //get next period Ids for RE
                for (Id currentPeriodId : currentPeriodIds) {
                    Accounting_Period__c nextPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentPeriodId);
                    if (nextPeriod.Id != NULL) {//means existed in org
                        nextPeriodIds.add(nextPeriod.Id);
                    }
                }
            }
            else if (periodInfoContainer.context == PeriodUpdateContext.OPENING) {
                currentPeriodIds = new Set<Id>{periodInfoContainer.getCurrentPeriod().Id};
                nextPeriodIds = new Set<Id>{periodInfoContainer.getNextPeriod().Id};
            }
            //Remove CYE and RE fin cubes in async context
            Database.executeBatch(new AccountingPeriodDeleteEarningsCubesBatch(periodInfoContainer, currentPeriodIds, nextPeriodIds));
            //Since for the AP Closing process batch job started above will be the very first step of the routine -
            //we have to set interim status on AP records
            if (periodInfoContainer.context == PeriodUpdateContext.CLOSING) {
                updatePeriodStatus(periodInfoContainer.selectedPeriods, AccountingPeriodActions.CLOSE_INTERIM_STATUS);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static List<Accounting_Period__c> getSortedCollection(List<Accounting_Period__c> newPeriods) {
        List<Accounting_Period__c> sortableCollection = new List<Accounting_Period__c>();
        for (Accounting_Period__c period : newPeriods) {
            sortableCollection.add(period);
        }
        sortableCollection.sort();
        return sortableCollection;
    }


    //============================================================================================================
    //group of methods to handle use cases when there is some exception during Accounting Period close/open routine
    //============================================================================================================
    public static void rollBackAndNotify(Exception ex, AccountingPeriodOpenCloseOptions periodInfoContainer) {
        notifyInCaseOfFailure(ex, periodInfoContainer);
        rollbackPeriodStatus(periodInfoContainer);
    }

    private static void notifyInCaseOfFailure(Exception ex, AccountingPeriodOpenCloseOptions periodInfoContainer) {
        try {
            String closeProcessingEmailSubject = Label.INF_PERIOD_CLOSE_REQUEST_NOT_PROCESSED;
            String openProcessingEmailSubject = Label.INF_PERIOD_OPEN_REQUEST_NOT_PROCESSED;
            String closeProcessingEmailBody = Label.INF_FOLLOWING_PERIOD_NOT_CLOSED + ':';
            String openProcessingEmailBody = Label.INF_FOLLOWING_PERIOD_NOT_OPENED + ':';
            String periodNames = getProcessedPeriodNames(periodInfoContainer.getUnprocessedPeriods());
            String debugInfo = '\n' + Label.INF_FOR_AS_SUPPORT_TEAM + ':\n' + Label.INF_EXCEPTION_MESSAGE + ':\n' + ex.getMessage() + '\n' + Label.INF_STACK_TRACE + ':\n' + ex.getStackTraceString();

            if (!FinancialSuiteUtils.canSendEmail()) {
                return;
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
            mail.setToAddresses(toAddresses);
            mail.setSubject(
                (periodInfoContainer.context == AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING)
                    ? openProcessingEmailSubject
                    : closeProcessingEmailSubject
            );

            String textBody = '';
            if (periodInfoContainer.context == AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING) {
                textBody += openProcessingEmailBody;
            }
            else {
                textBody += closeProcessingEmailBody;
            }
            textBody += periodNames;
            textBody += debugInfo;

            mail.setPlainTextBody(textBody);
            if (!Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            }
        }
        catch (Exception finEx) {

        }
    }

    private static void rollbackPeriodStatus(AccountingPeriodOpenCloseOptions periodInfoContainer) {
        try {
            String status =
                (periodInfoContainer.context == AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING)
                    ? AccountingPeriodActions.CLOSED_STATUS
                    : AccountingPeriodActions.OPEN_STATUS;

            List<Accounting_Period__c> periodsToRollback = periodInfoContainer.getUnprocessedPeriods();
            for (Accounting_Period__c eachPeriod : periodsToRollback) {
                //only periods after the one which has been failed during processing will be rolled back
                if (eachPeriod.Id != periodInfoContainer.getCurrentPeriod().Id) {
                    eachPeriod.Status__c = status;
                }
            }

            AccountingPeriodActions.isFirstRun = false;
            SFDCSecurityUtils.updateProxy(periodsToRollback);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static Object sendPeriodCloseRequestProcessedEmail(String periodNames) {
        Object result;
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
        mail.setToAddresses(toAddresses);
        mail.setSubject(ACCOUNTING_PERIOD_CLOSE_REQUEST_EMAIL_SUBJECT);
        mail.setPlainTextBody(
            Label.INF_FOLLOWING_PERIOD_CLOSED + ': \n' +
                periodNames +
                '\n' + Label.INF_WAIT_BEFORE_RUNNING_FINANCIAL_REPORT_OR_CHANGING_PERIOD);
        if (!Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
            result = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
        else {
            //for a unit test
            result = mail;
        }
        return result;
    }

    public static Object sendPeriodOpenRequestProcessedEmail(String periodNames) {
        Object result;
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
        mail.setToAddresses(toAddresses);
        mail.setSubject('Accounting Seed: Your Accounting Period(s) Open request has been processed');
        mail.setPlainTextBody('The following Accounting Period(s) have been opened: '
            + periodNames +
            '\nPlease wait a few minutes before running any financial reports or opening/closing/archiving any accounting periods.');

        if (!Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
            result = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
        else {
            //for a unit test
            result = mail;
        }
        return result;
    }

    public static String getProcessedPeriodNames(List<Accounting_Period__c> processedPeriods) {
        String result = '\n';
        for (Accounting_Period__c period : processedPeriods) {
            result += period.Name + '\n';
        }
        return result;
    }

    //========================================================================================================
    //========================================================================================================
    //update Accounting period status and notify user during Archiving routine
    public static void updateAndNotify(Accounting_Period__c period, String newStatus, String mailSubject, String mailBody) {
        try {
            if (FinancialSuiteUtils.canSendEmail()) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                String[] toAddresses = new String[] {UserInfo.getUserEmail()};
                mail.setToAddresses(toAddresses);
                mail.setSubject(mailSubject);
                mail.setPlainTextBody(mailBody);
                if (!Test.isRunningTest()) {
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
                }
            }

            period.Status__c = newStatus;
            AccountingPeriodActions.isPreventUpdateOverride = true;
            AccountingPeriodActions.isFirstRun = false;
            SFDCSecurityUtils.updateProxy(period);
            AccountingPeriodActions.isPreventUpdateOverride = false;
        }
        catch (Exception ex) {
            throw ex;
        }
    }

}