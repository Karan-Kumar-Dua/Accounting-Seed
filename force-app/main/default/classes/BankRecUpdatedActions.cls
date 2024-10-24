public with sharing class BankRecUpdatedActions {
    public static final String UNEXPECTED_GL_ACCOUNT_BALANCE_CALCULATION_ERROR = Label.ERR_UNEXP_GL_ACCT_BAL_CALC;
    public static final String QUEUEABLE_JOBS_LIMIT_REACHED = Label.ERR_QUEUEABLE_JOBS_LIMIT_REACHED;
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static void handleCompletedStatusChange(List<Consumable> events) {
        Set<Id> reconciledIds = new Set<Id>();
        for (Consumable event : events) {
            reconciledIds.add(event.getId());
        }
        try {
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                //pass list of reconciled ids to async job that updates unreconciled amounts and GL Account Balance
                System.enqueueJob(
                    new BankRecCompletedStatusChangeQueueable(
                        Test.isRunningTest() ? null : BankRecCompletedStatusChangeQueueable.Step.UPDATE_UNCLEARED_VALUES,
                        reconciledIds
                    )
                );
            }
            else {
                throw new BankReconciliation.BankReconciliationException(QUEUEABLE_JOBS_LIMIT_REACHED);
            }
        } catch (Exception ex) {
            Map<Id, String> errors = new Map<Id, String>();
            for (String bankRecId : reconciledIds) {
                errors.put(bankRecId, ex.getMessage());
            }
            logErrorsToBankRecs(errors);
        }
    }

    public static void handleInProgressStatusChange(List<Consumable> events) {
        Set<Id> reconciledIds = new Set<Id>();
        for (Consumable event : events) {
            reconciledIds.add(event.getId());
        }               
            
        try {
            deleteUnclearedBankReconciliationLines(reconciledIds);
        } catch (Exception ex) {
            Map<Id,String> errors = new Map<Id,String>();
            for (String bankRecId : reconciledIds) {
                errors.put(bankRecId, ex.getMessage());
            }
            logErrorsToBankRecs(errors);
        }
    }

    public static void handleClearItems(List<Consumable> events) {
        try {
            List<Bank_Reconciliation2__c> brecs = new List<Bank_Reconciliation2__c>();
            for (Consumable event : events) {
                brecs.add(new Bank_Reconciliation2__c(
                    Id = event.getId(),
                    Status__c = BankReconciliation.IN_PROGRESS
                ));
            }
            BankReconciliationActions.overrideDifferenceCheck = true;
            BankReconciliationActions.bypassClearJobIsRunningCheck = true;
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.Status__c});
            List<Database.SaveResult> results = SFDCSecurityUtils.updateProxy(brecs, false);
            TriggerObserver.reset();
            logErrorsToBankRecs(brecs, results);
        } catch (Exception ex) {
            Map<Id,String> errors = new Map<Id,String>();
            for (Consumable event : events) {
                errors.put(event.getId(), ex.getMessage());
            }
            logErrorsToBankRecs(errors);
        }
    }

    public static void handleGLAccountBalanceCalculated(List<Consumable> events) {
        try {
            Map<Id,Consumable> eventMap = new Map<Id,Consumable>();
            for (Consumable event : events) {
                eventMap.put(event.getId(), event);
            }

            List<Bank_Reconciliation2__c> brecs = DomainUtils.getBankRecsById(eventMap.keySet());
            for (Bank_Reconciliation2__c brec : brecs) {
                Decimal type = brec.Type__c == BankReconciliation.BANK_TYPE ? 1 : -1;
                // 'Bank' = identity, 'Credit Card' = inverse
                GLAccountBalance.Balance calculationResult = (GLAccountBalance.Balance) eventMap.get(brec.Id).getPayload();
                brec.GL_Ending_Balance__c = calculationResult.balance * type;
                brec.Status__c = BankReconciliation.COMPLETED;
            }

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.GL_Ending_Balance__c, Bank_Reconciliation2__c.Status__c}); 
            List<Database.SaveResult> results = SFDCSecurityUtils.updateProxy(brecs, false);
            TriggerObserver.reset();
            logErrorsToBankRecs(brecs, results);
        } catch (Exception ex) {
            Map<Id,String> errors = new Map<Id,String>();
            for (Consumable event : events) {
                errors.put(event.getId(), ex.getMessage());
            }
            logErrorsToBankRecs(errors);
        }
    }

    private static void deleteUnclearedBankReconciliationLines(Set<Id> reconciliedIds) {
        List<Id> recIds = new List<Id>();
        recIds.addAll(reconciliedIds);
        for (Id recId : recIds) {
            try {
                ServiceResult sr = BankReconciliation.deleteUnclearedBankReconciliationLines(recId);
                if (!sr.isSuccess) {
                    logErrorToBankRec(recId, String.join(sr.errors, ','));
                }
            } catch (DMLException dmlEx) {
                logErrorToBankRec(recId, dmlEx.getDMLMessage(0));
            } catch (Exception ex) {
                logErrorToBankRec(recId, ex.getMessage());
            }
        }
    }
    
    public static String getErrorMessage(ServiceResult result) {
        String message;
        if (result.errors <> null && !result.errors.isEmpty()) {
            message = '';
            for (ServiceResult.Error error : result.errors) {
                message += error.detail;
                message += '\n';
            }
            message.trim();
        }
        if (String.isBlank(message)) {
            message = UNEXPECTED_GL_ACCOUNT_BALANCE_CALCULATION_ERROR;
        }
        return message;
    }
    
    public static void logErrorToBankRec(Id bankRecId, String errorMessage) {
        logErrorsToBankRecs(new Map<Id,String> {
            bankRecId => errorMessage
        });
    }

    public static void logErrorsToBankRecs(Map<Id,String> bankRecIdToErrorMsg) {
        List<Bank_Reconciliation2__c> brecs = new List<Bank_Reconciliation2__c>();
        for (Id brecId : bankRecIdToErrorMsg.keySet()) {
            brecs.add(new Bank_Reconciliation2__c(
                Id = brecId,
                Error__c = bankRecIdToErrorMsg.get(brecId).abbreviate(255)
            ));
        }
        TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.Error__c});       
        SFDCSecurityUtils.updateProxy(brecs);
        TriggerObserver.reset();
    }

    private static void logErrorsToBankRecs(
        List<Bank_Reconciliation2__c> attemptedSaves, 
        List<Database.SaveResult> results
    ) {
        Map<Id,String> errors = new Map<Id,String>();
        Integer idx = 0;
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                errors.put(attemptedSaves.get(idx).Id, result.getErrors().get(0).getMessage());
            }
            idx++;
        }
        if (!errors.isEmpty()) {
            logErrorsToBankRecs(errors);
        }
    }

}