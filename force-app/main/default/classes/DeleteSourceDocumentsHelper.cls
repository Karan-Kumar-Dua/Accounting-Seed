public with sharing class DeleteSourceDocumentsHelper extends AbstractLWCHelper {

    @AuraEnabled
    public static void startDeleteSourceDocumentsJob(Id periodId) {
        try {
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(periodId), null);

            Accounting_Period__c currentAccountingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(periodId);
            currentAccountingPeriod.Source_Docs_Deleted__c = true;
            AccountingPeriodActions.isDelarcInProgress = true;
            SFDCSecurityUtils.updateProxy(currentAccountingPeriod);
            AccountingPeriodActions.isDelarcInProgress = false;
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

    }

    @AuraEnabled
    public static void validateDeleteSourceDocuments(Id periodId) {
        try {
            String message;
            Accounting_Period__c selectedPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodById(periodId);

            if (!FeatureManagementHandler.isDeleteArchivedSourceDocsEnabled()) {
                message = Label.ERR_FEATURE_NOT_ENABLED;
            }
            if (selectedPeriod.Status__c != AccountingPeriodActions.ARCHIVED_STATUS) {
                message = message != null ? message + '{ERR}' + Label.ERR_PERIOD_NOT_ARCHIVED : Label.ERR_PERIOD_NOT_ARCHIVED;
            }

            if (message != null) {
                throw buildException(ExceptionCode.VALIDATION, message);
            }
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }

    }
}