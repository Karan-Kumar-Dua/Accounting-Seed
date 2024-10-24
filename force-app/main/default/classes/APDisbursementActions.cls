public with sharing class APDisbursementActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String DELETION_ERROR = Label.ERR_AP_DISBURSEMENT_DELETE;
    public static final String AUTO_POST_FAILED_ERROR = Label.ERR_AP_DISBURSEMENT_AUTO_POST_FAILED;
    public static final String APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR = Label.ERR_APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD;
    public static final String APD_IN_FUTURE_ERROR = Label.ERR_BCR_APD_IN_FUTURE_PERIOD;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        AP_Disbursement__c.Paid_Amount__c => 2
    };

    public static void requireFields(List<AP_Disbursement__c> apDisbursements) {
        for (AP_Disbursement__c ad : apDisbursements) {
            if (ad.Accounting_Period__c == NULL) {
                ad.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static Boolean isPreventInsertOverride = false;

    public static void setDefaultFields(List<AP_Disbursement__c> apDisbursements) {
        try {
            Map<Id, Cash_Disbursement__c> disbursementMap = new Map<Id, Cash_Disbursement__c>();
            if (FeatureManagementHandler.isLargeDataVolumeModeEnabled() && AccountingSettingsHandler.isAutoPostAPDisbursementsEnabled()) {
                for (AP_Disbursement__c apd : apDisbursements) {
                    disbursementMap.put(apd.Cash_Disbursement__c, null);
                }
                disbursementMap = new Map<Id, Cash_Disbursement__c>(DomainUtils.getCashDisbursementById(disbursementMap.keySet()));
            }

            String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(AP_Disbursement__c.Status__c);
            for (AP_Disbursement__c apd : apDisbursements) {
                apd.Status__c = (apd.Status__c == NULL || SObjectActions.isPostedStatus(apd) ? defaultValue : apd.Status__c);
                if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()
                    && AccountingSettingsHandler.isAutoPostAPDisbursementsEnabled()
                    && disbursementMap.containsKey(apd.Cash_Disbursement__c)
                    && disbursementMap.get(apd.Cash_Disbursement__c).Source__c != AccountPayablePaymentHandler.CD_SOURCE_PAYABLE
                ) {
                    apd.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS;
                }
            }
        }
        catch (Exception ex) {
            for (AP_Disbursement__c apd : apDisbursements) {
                apd.addError(ex.getMessage(), false);
            }
        }
    }

    public static void handleDeletion(List<AP_Disbursement__c> apDisbursements) {
        if (!FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            Map<Id, AP_Disbursement__c> validForDeleteMap =
                new Map<Id, AP_Disbursement__c>(getValidForDeleteOnly(apDisbursements));

            for (AP_Disbursement__c apDisbursement : apDisbursements) {
                if (!validForDeleteMap.containsKey(apDisbursement.Id) && !TriggerObserver.bypassDeleteApDisbursement) {
                    apDisbursement.addError(DELETION_ERROR, false);
                }
            }

            if (!validForDeleteMap.isEmpty() && !TriggerObserver.bypassDeleteApDisbursement) {
                AbstractPostHandler postHandler = new APDisbursementPostHandler();
                postHandler.unpost(validForDeleteMap.values());
            }
        } else {
            List<AP_Disbursement__c> postedRecords = new List<AP_Disbursement__c>();
            for (AP_Disbursement__c apd : apDisbursements) {
                if (apd.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                    postedRecords.add(apd);
                }
            }
            if (!postedRecords.isEmpty()) {
                for (AP_Disbursement__c apd : postedRecords) {
                    apd.addError(DELETION_ERROR);
                }
            }
        }
    }

    public static void post(List<AP_Disbursement__c> newRecords) {
        if (AccountingSettingsHandler.isAutoPostAPDisbursementsEnabled()) {
            List<AP_Disbursement__c> validRecords = getValidForPostOnly(newRecords);
            if (!FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                if (!validRecords.isEmpty()) {
                    AbstractPostHandler postHandler = new APDisbursementPostHandler();
                    List<PostResult> postResults = postHandler.post(validRecords);
                    //Check posting results
                    Map<Id, String> notPostedRecordIdToErrorMsg = new Map<Id, String>();
                    for (PostResult result : postResults) {
                        if (!result.isSuccess) {
                            String errorMessage = (result.errors != NULL && !result.errors.isEmpty()) ? result.errors[0].message : 'N/A';
                            notPostedRecordIdToErrorMsg.put(result.id, errorMessage);
                        }
                    }
                    //If any valid-for-posting APD has not been posted - block insertion of the record
                    for (AP_Disbursement__c apd : newRecords) {
                        if (notPostedRecordIdToErrorMsg.containsKey(apd.Id)) {
                            apd.addError(String.format(AUTO_POST_FAILED_ERROR, new List<String>{notPostedRecordIdToErrorMsg.get(apd.Id)}));
                        }
                    }
                }
            } else {
                List<Id> apdIds = new List<Id>();
                for (AP_Disbursement__c adp : validRecords) {
                    apdIds.add(adp.Id);
                }
                new PostProcessor().post(apdIds);
            }
        }
    }

    public static List<AP_Disbursement__c> getValidForPostOnly(List<AP_Disbursement__c> apDisbursements) {
        List<AP_Disbursement__c> validRecords = new List<AP_Disbursement__c>();
        Set<Id> apDisbIds = new Map<Id, AP_Disbursement__c>(apDisbursements).keySet();
        List<AP_Disbursement__c> apDisbursementsList = DomainUtils.getApDisbursementsById(apDisbIds);

        Map<Id, Id> apdByLedgers = SObjectActions.ledgerIdBySourceId(apDisbursementsList);
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (apdByLedgers.values()));


        for (AP_Disbursement__c apDisbursement : apDisbursementsList) {

            if (apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c != NULL
                    && defaults.containsKey(apdByLedgers.get(apDisbursement.Id))
                    && defaults.get(apdByLedgers.get(apDisbursement.Id)).containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
                    && apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c !=
                    defaults.get(apdByLedgers.get(apDisbursement.Id)).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c
                    && AccountingPeriodHandler.getInstance().isConsideredOpen(apDisbursement.Accounting_Period__c, AP_Disbursement__c.sObjectType)) {

                validRecords.add(apDisbursement);
            }
        }

        return validRecords;
    }

    public static List<AP_Disbursement__c> getValidForDeleteOnly(List<AP_Disbursement__c> apDisbursements) {
        List<AP_Disbursement__c> validRecords = new List<AP_Disbursement__c>();
        Set<Id> apDisbIds = new Map<Id, AP_Disbursement__c>(apDisbursements).keySet();
        List<AP_Disbursement__c> apDisbursementsList = DomainUtils.getApDisbursementsById(apDisbIds);

        Map<Id, Id> apdByLedgers = SObjectActions.ledgerIdBySourceId(apDisbursementsList);
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (apdByLedgers.values()));

        for (AP_Disbursement__c apDisbursement : apDisbursementsList) {
            //check if this APD was created as part of reverse CD Apply process and period is open
            //if these conditions are all true - then such APDs can be deleted (with preliminary unpost call)
            if (apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c != NULL
                    && defaults.containsKey(apdByLedgers.get(apDisbursement.Id))
                    && defaults.get(apdByLedgers.get(apDisbursement.Id)).containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
                    && apDisbursement.Cash_Disbursement__r.Debit_GL_Account__c !=
                    defaults.get(apdByLedgers.get(apDisbursement.Id)).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c
                    && apDisbursement.Accounting_Period__r.Status__c == AccountingPeriodActions.OPEN_STATUS) {

                validRecords.add(apDisbursement);
            }
        }

        return validRecords;
    }

    public static void setAccountingPeriod(List<AP_Disbursement__c> newAPDisbursements) {
        List<AP_Disbursement__c> apDisbursementsWithNullAppliedDate = new List<AP_Disbursement__c>();
        List<AP_Disbursement__c> apDisbursementsWithAppliedDateSet = new List<AP_Disbursement__c>();
        Set<Id> cdIds = new Set<Id>();

        for (AP_Disbursement__c apDisbursement : newAPDisbursements) {
            if (apDisbursement.Accounting_Period__c == NULL) {
                if (apDisbursement.Applied_Date__c == NULL) {
                    apDisbursementsWithNullAppliedDate.add(apDisbursement);
                    cdIds.add(apDisbursement.Cash_Disbursement__c);
                } else {
                    apDisbursementsWithAppliedDateSet.add(apDisbursement);
                }                
            }
        }
        
        //For APD's with the applied date set, use the accounting period of the applied date
        SObjectActions.setAccountingPeriod(apDisbursementsWithAppliedDateSet, AP_Disbursement__c.Applied_Date__c);
        
        //For APD's without the applied date set, 
        //take Accounting Period from Master Record(Cash Disbursement in this case) and put it into the AP Disbursement's
        if (!apDisbursementsWithNullAppliedDate.isEmpty()) {
            Map<Id, Cash_Disbursement__c> cashDisbursementMap = new Map<Id, Cash_Disbursement__c>(
                DomainUtils.getCashDisbursementByIdForUpdate(cdIds)
            );

            for (AP_Disbursement__c apDisbursement : apDisbursementsWithNullAppliedDate) {
                //since Accounting Period assumed to be always set on Cash Disbursement record(is required by trigger validation)
                //we don't need any additional checks here
                apDisbursement.Accounting_Period__c = cashDisbursementMap.get(apDisbursement.Cash_Disbursement__c) != NULL ? cashDisbursementMap.get(apDisbursement.Cash_Disbursement__c).Accounting_Period__c : NULL;
            }
        }
    }

    public static void setAppliedDateIfBlank(List<AP_Disbursement__c> apDisbursements) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            
            for (AP_Disbursement__c apd : apDisbursements) {
                if (apd.Accounting_Period__c != NULL && apd.Applied_Date__c == NULL) {
                    apd.Applied_Date__c = acctPeriodHandler.getAccountingPeriodById(apd.Accounting_Period__c).Start_Date__c;
                }
            }
        }
        catch (Exception ex) {
            for (AP_Disbursement__c apd : apDisbursements) {
                apd.addError(ex.getMessage(), false);
            }
        }
    }

    public static void validateAppliedDateIsInAppliedAccountingPeriod (List<AP_Disbursement__c> apDisbursements) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            for (AP_Disbursement__c apd : apDisbursements) {
                if (apd.Accounting_Period__c != NULL && apd.Applied_Date__c != NULL) {
                    Accounting_Period__c acctPeriod = acctPeriodHandler.getAccountingPeriodById(apd.Accounting_Period__c);
                    if (apd.Applied_Date__c < acctPeriod.Start_Date__c || apd.Applied_Date__c > acctPeriod.End_Date__c) {
                        apd.addError(APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR, true);
                    }
                }
            }
        }
        catch (Exception ex) {
            for (AP_Disbursement__c apd : apDisbursements) {
                apd.addError(ex.getMessage(), false);
            }
        }
    }

    // This method differs from the SObjectActions method in that it allows updating a field if the initial value is NULL
    public static void preventUpdateAction(Map<Id, SObject> oldMap, List<SObject> objectList, List<String> nonUpdateFields, Boolean isPreventUpdateOverride) {
        if (!isPreventUpdateOverride) {
            Schema.SObjectType sObjectType = objectList.getSObjectType();
            Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();

            for (SObject newObj : objectList) {
                SObject oldObj = (oldMap != NULL && oldMap.containsKey(newObj.Id) ? oldMap.get(newObj.Id) : NULL);
                for (String field : nonUpdateFields) {
                    if (!TriggerObserver.getInstance().isUnlockedField(fieldMap.get(field))) {
                        if (oldObj == NULL && newObj.get(field) != NULL || (oldObj != NULL && oldObj.get(field) != NULL && oldObj.get(field) != newObj.get(field))) {
                            newObj.addError(
                                String.format(
                                    SObjectActions.UPDATE_ERROR,
                                    new List<String>{FinancialSuiteUtils.formatFieldStrings(sObjectType, nonUpdateFields)}
                                ), false
                            );
                        }
                    }
                }
            }
        }
    }

    public static void setPostingStatusForLegacyRecords(List<AP_Disbursement__c> newRecords) {
        Set<Id> legacyPostedBcrIds = getLegacyPostedApdIds(
            getBCRsWithNotPostedStatus(newRecords)
        );

        if (!legacyPostedBcrIds.isEmpty()) {
            TriggerObserver.getInstance().unlockField(AP_Disbursement__c.Status__c);
            for (AP_Disbursement__c newBCR : newRecords) {
                if (legacyPostedBcrIds.contains(newBCR.Id)) {
                    newBCR.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
                }
            }
        }

    }

    private static List<AP_Disbursement__c> getBCRsWithNotPostedStatus(List<AP_Disbursement__c> newRecords) {
        List<AP_Disbursement__c> retVal = new List<AP_Disbursement__c>();
        for (AP_Disbursement__c newRecord : newRecords) {
            if (newRecord.Status__c == NULL || newRecord.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED) {
                retVal.add(newRecord);
            }
        }
        return retVal;
    }

    private static Set<Id> getLegacyPostedApdIds(List<AP_Disbursement__c> scope) {
        Set<Id> legacyPostedApdIds = new Set<Id>();
        if (!scope.isEmpty()) {
            for (Transaction__c tr : DomainUtils.getTransactionsByApd((List<AP_Disbursement__c>) scope)) {
                legacyPostedApdIds.add(tr.AP_Disbursement__c);
            }
        }
        return legacyPostedApdIds;
    }
    //prevent insert when parent CD has a Posted status and source = payable
    public static void preventInsertWhenCDIsPostedWithSourcePayable(List<AP_Disbursement__c> apdRecords){
        // does not apply to void cash disbursement context
        if (MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext) {
            return;
        }

        Set<Id> cdIds = new Set<Id>();

        //collect CD ids
        for(AP_Disbursement__c apd : apdRecords){
            cdIds.add(apd.Cash_Disbursement__c);
        }

        //fetch CD's that are posted as well as source with payable
        Map<Id,Cash_Disbursement__c> cds =
                    new Map<Id,Cash_Disbursement__c>(DomainUtils.getCashDisbursementByIdWithPostedStatus(cdIds));

        //add error to the records if the parent CD is posted and Source = payable
        for(AP_Disbursement__c apd : apdRecords){
            if(cds.containsKey(apd.Cash_Disbursement__c)){
                apd.addError(Label.ERR_WHEN_PAYABLE_IS_APPLIED_TO_POSTED_CD);
            }
        }
    }

    public static void preventIfExistAPDInFutureAccountingPeriod(Map<Id, AP_Disbursement__c> apdMap) {
        if (AccountingPeriodActions.isDelarcInProgress) {
            return;
        }
        List<AP_Disbursement__c> apDisbursements = DomainUtils.getApDisbursementsById(apdMap.keySet());

        Map<Id, Set<Id>> payableByAPD = new Map<Id, Set<Id>>();
        for (AP_Disbursement__c apd : apDisbursements) {
            if (payableByAPD.containsKey(apd.Account_Payable__c)) {
                payableByAPD.get(apd.Account_Payable__c).add(apd.Id);
            } else {
                payableByAPD.put(apd.Account_Payable__c, new Set<Id> {apd.Id});
            }
        }

        List<AP_Disbursement__c> apdByPayable = DomainUtils.getAPDisbursementByPayableId(payableByAPD.keySet());

        for (AP_Disbursement__c apd : apdByPayable) {
            if (usesCashLedger(apd) && payableByAPD.containsKey(apd.Account_Payable__c)) {
                for (Id existedAPD : payableByAPD.get(apd.Account_Payable__c)) {
                    if (AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                        apd.Accounting_Period__c,
                        apdMap.get(existedAPD).Accounting_Period__c) == 1) {
                        if(!System.Trigger.isExecuting){
                            throw new DmlException(APD_IN_FUTURE_ERROR);
                        } else {
                            apdMap.get(existedAPD).addError(APD_IN_FUTURE_ERROR, false);
                        }
                    }
                }
            }
        }

        Map<Id, AP_Credit_Memo__c> payableCreditMemos = new Map<Id,AP_Credit_Memo__c>(DomainUtils.getApCreditMemosByInvoiceId(payableByAPD.keySet()));

        Map<Id, Set<Id>> payableByAPCM = new Map<Id, Set<Id>>();
        for (AP_Credit_Memo__c payCM : payableCreditMemos.values()) {
            if (payableByAPCM.containsKey(payCM.Account_Payable_Invoice__c)) {
                payableByAPCM.get(payCM.Account_Payable_Invoice__c).add(payCM.Id);
            } else {
                payableByAPCM.put(payCM.Account_Payable_Invoice__c, new Set<Id> {payCM.Id});
            }
        }

        if(!payableByAPCM.isEmpty()){
            for (AP_Disbursement__c apDisbursement : apDisbursements) {
                if (usesCashLedger(apDisbursement) && payableByAPCM.containsKey(apDisbursement.Account_Payable__c)) {
                    for (Id existedAPCM : payableByAPCM.get(apDisbursement.Account_Payable__c)) {
                        if (AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                            payableCreditMemos.get(existedAPCM).Accounting_Period__c,
                            apDisbursement.Accounting_Period__c) == 1) {
                            if(!System.Trigger.isExecuting){
                                throw new DmlException(APD_IN_FUTURE_ERROR);
                            } else {
                                apdMap.get(apDisbursement.Id).addError(APD_IN_FUTURE_ERROR, false);
                            }
                        }
                    }
                }
            }
        }
    }

    private static Boolean usesCashLedger(AP_Disbursement__c apd) {
        return LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(apd.Account_Payable__r.Ledger__c)
            || LedgerHandler.getInstanceWithoutSharing().isCashLedger(apd.Account_Payable__r.Ledger__c);
    }

    public static void preventPartialPayIfDiscount(Map<Id, AP_Disbursement__c> apdMap) {
        if (AccountingPeriodActions.isDelarcInProgress || isPreventInsertOverride) {
            return;
        }
        Set<Id> payableIds = new Set<Id>();
        for (AP_Disbursement__c apd : apdMap.values()) {
            if (apd.Discount_Amount__c != null && apd.Discount_Amount__c != 0) {
                payableIds.add(apd.Account_Payable__c);
            }
        }
        if (!payableIds.isEmpty()) {
            Map<Id, Account_Payable__c>  payables = new Map<Id, Account_Payable__c> (DomainUtils.getAccountPayablesById(payableIds));
            for (AP_Disbursement__c apd : apdMap.values()) {
                if (apd.Discount_Amount__c != null && apd.Discount_Amount__c != 0
                    && (apd.Paid_Amount__c - payables.get(apd.Account_Payable__c).Balance__c) != 0) {
                    apd.addError(Label.ERR_DISCOUNTED_AMOUNT_MUST_PAY_IN_FULL, false);
                }
            }
        }
    }

}