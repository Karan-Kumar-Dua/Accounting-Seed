public with sharing class BankReconciliationActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String UPDATE_ERROR = Label.ERR_UPDATE;
    public static final String STATUS_CHANGE_DIFFERENCE_NOT_ZERO_ERROR = Label.ERR_STATUS_CHANGE_DIFFERENCE_NOT_ZERO;
    public static final String STATUS_CHANGE_IN_PROGRESS_ERROR = Label.ERR_STATUS_CHANGE_IN_PROGRESS;
    public static final String STATUS_CHANGE_COMPLETED_PREVIOUS_IN_PROGRESS_ERROR = Label.ERR_STATUS_CHANGE_COMPLETED_PREVIOUS_IN_PROGRESS;
    public static final String STATUS_CHANGE_COMPLETED_PREVIOUS_WORKING_ERROR = Label.STATUS_CHANGE_COMPLETED_PREVIOUS_WORKING;
    public static final String STATUS_CHANGE_IN_PROGRESS_SUBSEQUENT_COMPLETED_ERROR = Label.ERR_STATUS_CHANGE_IN_PROGRESS_SUBSEQUENT_COMPLETED;
    public static final String CREATE_BREC_SUBSEQUENT_COMPLETED_ERROR = Label.ERR_CREATE_BREC_SUBSEQUENT_COMPLETED;
    public static final String CREATE_BREC_EXISTING_BREC_ERROR = Label.ERR_CREATE_BREC_EXISTING_BREC;
    public static final String TOO_MANY_STATUS_CHANGES_ERROR = Label.ERR_TOO_MANY_STATUS_CHANGES;
    public static final String STATUS_CHANGE_COMPLETED_WITH_EXCEPTION_ERROR = Label.ERR_STATUS_CHANGE_COMPLETED_WITH_EXCEPTION;
    public static final String RECORD_COUNT_OVER_LIMIT_CREATE = Label.ERR_RECORD_COUNT_OVER_LIMIT_CREATE;
    public static final String RECORD_COUNT_OVER_LIMIT_UPDATE = Label.ERR_RECORD_COUNT_OVER_LIMIT_UPDATE;
    public static final String LEGACY_BR_STATUS_CHANGED = Label.ERR_LEGACY_BR_STATUS_CHANGED;
    public static final String STATUS_CHANGE_WHILE_JOB_RUNNING_ERROR = Label.ERR_STATUS_CHANGE_WHILE_JOB_RUNNING;
    public static final String CREATE_BREC_WHILE_JOB_RUNNING_ERROR = Label.ERR_CREATE_BREC_WHILE_JOB_RUNNING;
    public static final String BEGINNING_BALANCE_REQUIRED = Label.ERR_BEGINNING_BALANCE_REQUIRED;
    public static final String TYPE_FIELD_REQUIRED_FOR_MODERN_BR = Label.ERR_TYPE_FIELD_REQUIRED_FOR_MODERN_BR;

    @TestVisible
    private static Integer RECORD_COUNT_LIMIT = 8000;

    private static final String WORKING = BankReconciliation.WORKING;
    private static final String COMPLETED = BankReconciliation.COMPLETED;
    private static final String IN_PROGRESS = BankReconciliation.IN_PROGRESS;
    private static final String AUTO_CLEAR_RUNNING = BankReconciliation.AUTO_CLEAR_RUNNING;

    public static Boolean overrideDifferenceCheck = false;
    public static Boolean bypassDefaultStatusWorking = false;
    public static Boolean bypassClearJobIsRunningCheck = false;
    
     
    public static void setDefaultFields(Bank_Reconciliation2__c[] bankRecList) {
        for (Bank_Reconciliation2__c bankRec : bankRecList) {
            bankRec.Cleared_Deposits__c = 0;
            bankRec.Cleared_Disbursements__c = 0;
            if (bypassDefaultStatusWorking
                    || bankRecList.size() > 1
                    || AccountingSettingsHandler.isAutoClearJobDisabled()) {

                bankRec.Status__c = IN_PROGRESS;
            } else {
                bankRec.Status__c = WORKING;
            }    
            if (!Test.isRunningTest()) {
                bankRec.Modern_BR__c = true;
            }
        }
    }

    public static void invokeEvent(Map<Id, Bank_Reconciliation2__c> oldBankRecMap, Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        BankReconciliationStatusProcessor brecProcessor = new BankReconciliationStatusProcessor();
        brecProcessor.newRecord = newBankRecMap.values()[0];
        brecProcessor.oldRecord = oldBankRecMap.get(brecProcessor.newRecord.Id);

        List<Publishable> events = new List<Publishable>();
        
        if (brecProcessor.isStatusChangedFromWorkingToCompleted()) {
            events.add(createEvent(brecProcessor.newRecord.Id, EventRegistry.RegisteredEvent.BANK_RECONCILIATION_COMPLETED_STATUS_CHANGE));
        }                         
        
        if (!events.isEmpty()) {
            EventPubSub.publish(events);
        }        
    }

    public static void setOpeningBalanceAndType(Bank_Reconciliation2__c[] bankRecList) {
        Bank_Reconciliation2__c bankRecon = bankRecList[0];

        if (bankRecon.Override_Beginning_Balance__c == true && bankRecon.Beginning_Balance__c == NULL) {
            bankRecon.Beginning_Balance__c.addError(BEGINNING_BALANCE_REQUIRED);
        }
        List<Bank_Reconciliation2__c> bankReconciliations = DomainUtils.getRelatedBankRecs(bankRecon);

        Bank_Reconciliation2__c prevBankRec = null;
        for (Integer index = bankReconciliations.size() - 1; index >= 0; index--) {
            if (bankRecon.End_Date__c > bankReconciliations[index].End_Date__c) {
                prevBankRec = bankReconciliations[index];
                break;
            }
        }
        if (prevBankRec != null) {
            bankRecon.Type__c = prevBankRec.Type__c;
            bankRecon.Beginning_Balance__c = !bankRecon.Override_Beginning_Balance__c ?
                    prevBankRec.Ending_Balance__c : bankRecon.Beginning_Balance__c;
        } else {
            bankRecon.Beginning_Balance__c = !bankRecon.Override_Beginning_Balance__c ? 0 : bankRecon.Beginning_Balance__c;
        }

    }

    private static Map<Id, List<Bank_Reconciliation2__c>> relatedBankRecsByBankRecIds = new Map<Id, List<Bank_Reconciliation2__c>>();

    private static List<Bank_Reconciliation2__c> getRelatedBankRecs(Bank_Reconciliation2__c bankRec) {
        if (!relatedBankRecsByBankRecIds.containsKey(bankRec.Id)) {
            relatedBankRecsByBankRecIds.put(bankRec.Id, DomainUtils.getRelatedBankRecs(bankRec));
        }
        return relatedBankRecsByBankRecIds.get(bankRec.Id);
    }

    public static void validateNoSubsequentReconciledReconciliations(Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        BankReconciliationStatusProcessor brecProcessor = new BankReconciliationStatusProcessor();
        brecProcessor.newRecord = newBankRecMap.values()[0];
        brecProcessor.relatedBankRecs = getRelatedBankRecs(brecProcessor.newRecord);

        if(brecProcessor.isSubsequentBankRecCompletedOrWorking()) {
            brecProcessor.newRecord.addError(CREATE_BREC_SUBSEQUENT_COMPLETED_ERROR);         
        }        
    }

    public static void validateNoRelatedWorkingReconciliations(Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        BankReconciliationStatusProcessor brecProcessor = new BankReconciliationStatusProcessor();
        brecProcessor.newRecord = newBankRecMap.values()[0];
        brecProcessor.relatedBankRecs = getRelatedBankRecs(brecProcessor.newRecord);

        if(brecProcessor.isSubsequentBankRecWorking() || brecProcessor.isPreviousBankRecWorking()) {
            brecProcessor.newRecord.addError(CREATE_BREC_WHILE_JOB_RUNNING_ERROR);
        }
    }

    public static void validateUniqueReconciliation(Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        Bank_Reconciliation2__c bankRec = newBankRecMap.values()[0];
        if (!DomainUtils.getRelatedBankRecs(bankRec, true, false, false).isEmpty()) {
            bankRec.addError(CREATE_BREC_EXISTING_BREC_ERROR);
        }

    }

    public static void checkForMultipleStatusChanges(Map<Id, Bank_Reconciliation2__c> oldBankRecMap, Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        if (!bypassClearJobIsRunningCheck) {
            Integer changedStatusCount = 0;
            for (Bank_Reconciliation2__c bankRec : newBankRecMap.values()) {
                if (oldBankRecMap.get(bankRec.Id).Status__c != bankRec.Status__c) {
                    changedStatusCount++;
                }
            }
            if (changedStatusCount > 1) {
                for (Bank_Reconciliation2__c bankRec : newBankRecMap.values()) {
                    bankRec.addError(TOO_MANY_STATUS_CHANGES_ERROR);
                }
            }
        }
    }

    public static void clearRelatedSourceDocuments(Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        if (!bypassDefaultStatusWorking && !AccountingSettingsHandler.isAutoClearJobDisabled()) {
            Database.executeBatch(new BankReconciliationClearItemsBatch(newBankRecMap.values()[0].Id), 1000);
        }
    }

    public static void validateStatusChange(Map<Id, Bank_Reconciliation2__c> oldBankRecMap, Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        BankReconciliationStatusProcessor brecProcessor = new BankReconciliationStatusProcessor();
        brecProcessor.newRecord = newBankRecMap.values()[0];
        brecProcessor.oldRecord = oldBankRecMap.get(brecProcessor.newRecord.Id);
        brecProcessor.relatedBankRecs = DomainUtils.getRelatedBankRecs(brecProcessor.newRecord);       
        
        if (!brecProcessor.isModernBankRec() && brecProcessor.isStatusChanged()) {
            brecProcessor.newRecord.addError(LEGACY_BR_STATUS_CHANGED);
        }
        
        if (brecProcessor.isStatusChangedToCompletedWithError()) {
            brecProcessor.newRecord.addError(STATUS_CHANGE_COMPLETED_WITH_EXCEPTION_ERROR);
        }

        if (!bypassClearJobIsRunningCheck && brecProcessor.isStatusChangedWhileClearJobIsRunning()) {
            brecProcessor.newRecord.addError(STATUS_CHANGE_WHILE_JOB_RUNNING_ERROR);
        }

        if (brecProcessor.isStatusChangedToCompletedOrWorking() &&
            brecProcessor.isUnclearedAmountNotZero()) {

            brecProcessor.newRecord.addError(STATUS_CHANGE_DIFFERENCE_NOT_ZERO_ERROR);
        }
        if (brecProcessor.isStatusChangedFromInProgressToCompleted() &&
            brecProcessor.isPreviousBankRecInProgress()) {

            brecProcessor.newRecord.addError(STATUS_CHANGE_COMPLETED_PREVIOUS_IN_PROGRESS_ERROR);
        }
        if (brecProcessor.isStatusChangedFromInProgressToCompleted() &&
            brecProcessor.isPreviousBankRecWorking()) {

            brecProcessor.newRecord.addError(STATUS_CHANGE_COMPLETED_PREVIOUS_WORKING_ERROR);
        }
        if (brecProcessor.isStatusChangedToInProgress() &&
            brecProcessor.isUnclearedAmountNotZero() && 
            !overrideDifferenceCheck) {

            brecProcessor.newRecord.addError(STATUS_CHANGE_IN_PROGRESS_ERROR);
        } 
        if (brecProcessor.isStatusChangedToInProgress() &&
            brecProcessor.isSubsequentBankRecCompletedOrWorking()) {

            brecProcessor.newRecord.addError(STATUS_CHANGE_IN_PROGRESS_SUBSEQUENT_COMPLETED_ERROR);
        }   
    }

    public static void handleStatusChange(Map<Id, Bank_Reconciliation2__c> oldBankRecMap, Map<Id, Bank_Reconciliation2__c> newBankRecMap) {
        BankReconciliationStatusProcessor brecProcessor = new BankReconciliationStatusProcessor();
        brecProcessor.newRecord = newBankRecMap.values()[0];
        brecProcessor.oldRecord = oldBankRecMap.get(brecProcessor.newRecord.Id);
        brecProcessor.relatedBankRecs = DomainUtils.getRelatedBankRecs(brecProcessor.newRecord);        
        
        if (brecProcessor.isStatusChangedToInProgress()) {
            //clear out any errors when going to In Progress status
            brecProcessor.newRecord.Error__c = NULL;            
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.Error__c});  

            Publishable event = createEvent(brecProcessor.newRecord.Id, EventRegistry.RegisteredEvent.BANK_RECONCILIATION_IN_PROGRESS_STATUS_CHANGE);
            EventPubSub.publish(event);
        }

        if (brecProcessor.isStatusChangedToAutoClearWorking()) {
            publishable event = createEvent(brecProcessor.newRecord.Id, EventRegistry.RegisteredEvent.BANK_RECONCILIATION_AUTO_CLEAR_RUNNING_STATUS_CHANGE);
            EventPubSub.publish(event);
        }

        if (!brecProcessor.isUnclearedAmountNotZero() &&
            brecProcessor.isStatusChangedFromInProgressToCompleted() &&
            !brecProcessor.isPreviousBankRecInProgress() &&
            !brecProcessor.isPreviousBankRecWorking()
        ) {
            if (!bypassDefaultStatusWorking) {
                brecProcessor.newRecord.Status__c = WORKING;
                Publishable event = createEvent(brecProcessor.newRecord.Id, EventRegistry.RegisteredEvent.BANK_RECONCILIATION_WORKING_STATUS_CHANGE);
                EventPubSub.publish(event);
            } else {
                brecProcessor.newRecord.Status__c = COMPLETED;
            }
            
        }
                
        if (brecProcessor.isStatusChangedFromWorkingToCompleted()) {
            Bank_Reconciliation2__c relatedBankRec = brecProcessor.getSubsequentBankRec();
            if (relatedBankRec != NULL) {
                relatedBankRec.Beginning_Balance__c = brecProcessor.newRecord.Calculated_Ending_Balance__c;
                SFDCSecurityUtils.updateProxy(relatedBankRec);
            }
        }
        
        if (brecProcessor.isStatusChangedToInProgress() &&
            !brecProcessor.isUnclearedAmountNotZero() &&
            !brecProcessor.isSubsequentBankRecCompletedOrWorking()) {

            brecProcessor.newRecord.UnCleared_Deposits__c = 0;
            brecProcessor.newRecord.UnCleared_Payments__c = 0;
            brecProcessor.newRecord.GL_Ending_Balance__c = 0;     
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{
                                                                            Bank_Reconciliation2__c.UnCleared_Deposits__c, 
                                                                            Bank_Reconciliation2__c.UnCleared_Payments__c, 
                                                                            Bank_Reconciliation2__c.GL_Ending_Balance__c});       
        }                
    }

    private static Publishable createEvent(Id bankRecId, EventRegistry.RegisteredEvent eventType) {
        return EventPubSub.createEvent(
            EventPubSub.PublishDelay.ON_COMMIT, 
            eventType, 
            bankRecId, 
            null
        );
    }

    public static void validateTypeFieldRequiredForModernBR(Bank_Reconciliation2__c[] bankRecList) {
        for (Bank_Reconciliation2__c bankRec : bankRecList) {
            if (bankRec.Type__c == null && bankRec.Modern_BR__c == true) {
                bankRec.addError(TYPE_FIELD_REQUIRED_FOR_MODERN_BR);
            }
        }
    }

    public class BankReconciliationStatusProcessor {
        public Bank_Reconciliation2__c newRecord {get; set;}
        public Bank_Reconciliation2__c oldRecord {get; set;}   
        public List<Bank_Reconciliation2__c> relatedBankRecs {get; set;}     
        public Integer recordCount {get;set;}

        public Boolean isModernBankRec() {
            return newRecord.Modern_BR__c;
        }

        public Boolean isStatusChanged() {
            return oldRecord.Status__c != newRecord.Status__c;
        }

        public Boolean isSourceDocumentRecordCountOverLimit() {
            BankReconciliationModel model = BankReconciliation.retrieveItemCount(newRecord.Id);
            recordCount = model != NULL ? model.recordCount : -1;
            return model != NULL && model.recordCount > 0 && model.recordCount > RECORD_COUNT_LIMIT;
        }

        public Boolean isStatusChangedToInProgress() {
            return oldRecord.Status__c != newRecord.Status__c && newRecord.Status__c == IN_PROGRESS;
        }

        public Boolean isStatusChangedToAutoClearWorking() {
            return oldRecord.Status__c != newRecord.Status__c && newRecord.Status__c == AUTO_CLEAR_RUNNING;
        }

        public Boolean isStatusChangedToCompletedWithError() {
            return oldRecord.Status__c != newRecord.Status__c && newRecord.Status__c == COMPLETED && !String.isEmpty((String)newRecord.Error__c);
        }
        public Boolean isStatusChangedToCompletedOrWorking() {
            return oldRecord.Status__c != newRecord.Status__c && (newRecord.Status__c == WORKING || newRecord.Status__c == COMPLETED);
        }

        public Boolean isUnclearedAmountNotZero() {
            return newRecord.Uncleared_Amount__c != 0.00;
        }

        public Boolean isStatusChangedFromInProgressToCompleted() {
            return oldRecord.Status__c == IN_PROGRESS && newRecord.Status__c == COMPLETED;
        }

        public Boolean isStatusChangedFromInProgressToWorking() {
            return oldRecord.Status__c == IN_PROGRESS && newRecord.Status__c == WORKING;
        }

        public Boolean isStatusChangedFromWorkingToCompleted() {
            return oldRecord.Status__c == WORKING && newRecord.Status__c == COMPLETED;
        }

        public Boolean isStatusChangedWhileClearJobIsRunning() {
            return oldRecord.Status__c != newRecord.Status__c && BatchJobUtils.checkJobRunning( new Set<String>{'BankReconciliationClearItemsBatch'} ) == true;
        }

        public Boolean isPreviousBankRecInProgress() {
            for (Bank_Reconciliation2__c relatedBankRec : relatedBankRecs) {
                if (relatedBankRec.End_Date__c < newRecord.End_Date__c && relatedBankRec.Status__c == IN_PROGRESS) {
                    return true;    
                }
            }
            return false;
        }

        public Boolean isPreviousBankRecWorking() {
            for (Bank_Reconciliation2__c relatedBankRec : relatedBankRecs) {
                if (relatedBankRec.End_Date__c < newRecord.End_Date__c && relatedBankRec.Status__c == WORKING) {
                    return true;    
                }
            }
            return false;
        }

        public Boolean isSubsequentBankRecCompleted() {
            for (Bank_Reconciliation2__c relatedBankRec : relatedBankRecs) {
                if (relatedBankRec.End_Date__c > newRecord.End_Date__c && relatedBankRec.Status__c == COMPLETED) {
                    return true;
                }
            }
            return false;
        }

        public Boolean isSubsequentBankRecWorking() {
            for (Bank_Reconciliation2__c relatedBankRec : relatedBankRecs) {
                if (relatedBankRec.End_Date__c > newRecord.End_Date__c && relatedBankRec.Status__c == WORKING) {
                    return true;
                }
            }
            return false;
        }

        public Boolean isSubsequentBankRecCompletedOrWorking() {
            return this.isSubsequentBankRecCompleted() || this.isSubsequentBankRecWorking();
        }

        public Bank_Reconciliation2__c getSubsequentBankRec() {
            Bank_Reconciliation2__c returnedBankRec;
            for (Bank_Reconciliation2__c relatedBankRec : relatedBankRecs) {
                if (relatedBankRec.End_Date__c > newRecord.End_Date__c) {
                    if (!relatedBankRec.Override_Beginning_Balance__c) {
                        returnedBankRec = relatedBankRec;
                    }
                    break;
                }
            }
            return returnedBankRec;
        }
    }
}