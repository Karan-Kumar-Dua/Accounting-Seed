public with sharing class BillingCashReceiptActions {
    
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static final String AUTO_POST_FAILED_ERROR = Label.ERR_BCR_AUTO_POST_FAILED;
    public static final String ACCOUNTING_PERIOD_CLOSED_ERROR = Label.ERR_BR_ACCOUNTING_PERIOD_CLOSED;
    public static final String BCR_IN_FUTURE_ERROR = Label.ERR_BCR_APD_IN_FUTURE_PERIOD;
    public static final String ADJUSTMENT_ERROR = Label.ERR_ADJUSTMENT_ACC_REQ;
    public static final String POSTED_UPDATE_ERROR = Label.ERR_POSTED_UPDATE_APPLIED_DATE;
    public static final String APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR = Label.ERR_APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD;
    public static final String LDO_POSTED_DELETE_ERROR = Label.ERR_BCR_DELETE;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Billing_Cash_Receipt__c.Applied_Amount__c => 2,
        Billing_Cash_Receipt__c.Adjustment_Amount__c => 2
    };

    public static Boolean isFirstRun = true;

    public static void requireFields(List<Billing_Cash_Receipt__c> billingCashReceipts) {
        for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
            if (bcr.Accounting_Period__c == null) {
                bcr.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }            
        }
    }

    public static void setAccountingPeriod(List<Billing_Cash_Receipt__c> billingCashReceipts) {
        
        List<Billing_Cash_Receipt__c> receiptsWithNullAppliedDate = new List<Billing_Cash_Receipt__c>();
        List<Billing_Cash_Receipt__c> receiptsWithAppliedDateSet = new List<Billing_Cash_Receipt__c>();

        for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
            if (bcr.Applied_Date__c == null) {
                receiptsWithNullAppliedDate.add(bcr);
            } else {
                receiptsWithAppliedDateSet.add(bcr);
            }
        }
        SObjectActions.setAccountingPeriod(receiptsWithNullAppliedDate, Billing_Cash_Receipt__c.CreatedDate);
        SObjectActions.setAccountingPeriod(receiptsWithAppliedDateSet, Billing_Cash_Receipt__c.Applied_Date__c);
    }
    
    public static void setAppliedDateIfBlank(List<Billing_Cash_Receipt__c> billingCashReceipts) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            
            for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
                if (bcr.Accounting_Period__c != null && bcr.Applied_Date__c == null) {
                    bcr.Applied_Date__c = acctPeriodHandler.getAccountingPeriodById(bcr.Accounting_Period__c).Start_Date__c;
                }
            }
        }
        catch (Exception ex) {
            for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
                bcr.addError(ex.getMessage(), false);
            }
        }
    }

    public static void validateAppliedDateIsInAppliedAccountingPeriod (List<Billing_Cash_Receipt__c> billingCashReceipts) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
                if (bcr.Accounting_Period__c != null && bcr.Applied_Date__c != null) {
                    Accounting_Period__c acctPeriod = acctPeriodHandler.getAccountingPeriodById(bcr.Accounting_Period__c);
                    if (bcr.Applied_Date__c < acctPeriod.Start_Date__c || bcr.Applied_Date__c > acctPeriod.End_Date__c) {
                        bcr.addError(APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR, false);
                    }
                }
            }
        }
        catch (Exception ex) {
            for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
                bcr.addError(ex.getMessage(), false);
            }
        }
    }
    
    public static void setDefaultFields(List<Billing_Cash_Receipt__c> billingCashReceipts) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(Billing_Cash_Receipt__c.Status__c);
            for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
                bcr.Status__c = (bcr.Status__c == null || SObjectActions.isPostedStatus(bcr) ? defaultValue : bcr.Status__c);
                if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()
                    && AccountingSettingsHandler.isAutoPostBillingCashReceiptsEnabled()
                    && bcr.Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND) {
                    bcr.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS;
                }
                if (bcr.Accounting_Period__c != null && bcr.Applied_Date__c == null) {
                    bcr.Applied_Date__c = acctPeriodHandler.getAccountingPeriodById(bcr.Accounting_Period__c).Start_Date__c;
                }
            }
        }
        catch (Exception ex) {
            for (Billing_Cash_Receipt__c bcr : billingCashReceipts) {
                bcr.addError(ex.getMessage(), false);
            }
        }
    }

    public static void checkControlAccount(List<Billing_Cash_Receipt__c> billingCashReceipts) {
        List<Billing_Cash_Receipt__c> bsrList = DomainUtils.getBillingCashReceiptsByIdForUpdate((new Map<Id, Billing_Cash_Receipt__c> (billingCashReceipts)).keySet());
        Map<Id, Id> bcrByLedgers = SObjectActions.ledgerIdBySourceId(bsrList);
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (bcrByLedgers.values()));

        for (Billing_Cash_Receipt__c billReceipt : billingCashReceipts) {
            if (!defaults.containsKey(bcrByLedgers.get(billReceipt.Id))
                || !defaults.get(bcrByLedgers.get(billReceipt.Id)).containsKey(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)
                || !defaults.get(bcrByLedgers.get(billReceipt.Id)).containsKey(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)) {
                billReceipt.addError(BillingCashReceiptPostHandler.NO_CONTROL_ACCOUNT_MESSAGE, false);
            }
        }
    }

    public static void requireAdjustmentGLAccountAndAmount(List<Billing_Cash_Receipt__c> billingCashReceipts) {
        for (Billing_Cash_Receipt__c billReceipt : billingCashReceipts) {
            if ((billReceipt.Adjustment_Amount__c == null && billReceipt.Adjustment_GL_Account__c != null)
                    || (billReceipt.Adjustment_Amount__c != null && billReceipt.Adjustment_GL_Account__c == null)) {

                billReceipt.addError(ADJUSTMENT_ERROR, false);
            }
        }
    }
    
    public static void preventDeleteClosedAccountingPeriod(Map<Id, Billing_Cash_Receipt__c> billingCashReceiptsMap) {
        if (AccountingPeriodActions.isDelarcInProgress) {
            return;
        }
        for (Billing_Cash_Receipt__c billReceipt : DomainUtils.getBillingCashReceiptsByIdForUpdate(billingCashReceiptsMap.keySet())) {
            if (billReceipt.Accounting_Period__r.Status__c != AccountingPeriodActions.OPEN_STATUS) {
                billingCashReceiptsMap.get(billReceipt.Id).addError(ACCOUNTING_PERIOD_CLOSED_ERROR, false);
            }
        }
    }

    public static void preventIfExistBCRInFutureAccountingPeriod(Map<Id, Billing_Cash_Receipt__c> billingCashReceiptsMap) {
        if (AccountingPeriodActions.isDelarcInProgress) {
            return;
        }
        List<Billing_Cash_Receipt__c> billingCashReceipts = DomainUtils.getBillingCashReceiptsById(billingCashReceiptsMap.keySet());

        Map<Id, Set<Id>> billingByBCR = new Map<Id, Set<Id>>();
        for (Billing_Cash_Receipt__c billReceipt : billingCashReceipts) {
            if (billingByBCR.containsKey(billReceipt.Billing__c)) {
                billingByBCR.get(billReceipt.Billing__c).add(billReceipt.Id);
            } else {
                billingByBCR.put(billReceipt.Billing__c, new Set<Id> {billReceipt.Id});
            }
        }

        List<Billing_Cash_Receipt__c> billingCashReceiptsByBilling = DomainUtils.getBillingCashReceiptsByBillingId(billingByBCR.keySet());

        for (Billing_Cash_Receipt__c billReceipt : billingCashReceiptsByBilling) {
            if (usesCashLedger(billReceipt) && billingByBCR.containsKey(billReceipt.Billing__c)) {
                for (Id existedBCR : billingByBCR.get(billReceipt.Billing__c)) {
                    Id periodOne = billReceipt.Accounting_Period__c;
                    Id periodTwo = billingCashReceiptsMap.get(existedBCR).Accounting_Period__c;
                    if (isPeriodOneAfterPeriodTwo(PeriodOne, PeriodTwo)) {
                        if(!System.Trigger.isExecuting){
                            throw new DmlException(BCR_IN_FUTURE_ERROR);
                        } else {
                            billingCashReceiptsMap.get(existedBCR).addError(BCR_IN_FUTURE_ERROR, false);
                        }
                    }
                }
            }
        }

        Map<Id, Billing_Credit_Memo__c> billingCreditMemos = new Map<Id,Billing_Credit_Memo__c>(DomainUtils.getBillingCreditMemosByInvoiceId(billingByBCR.keySet()));

        Map<Id, Set<Id>> billingByBCM = new Map<Id, Set<Id>>();
        for (Billing_Credit_Memo__c billCM : billingCreditMemos.values()) {
            if (billingByBCM.containsKey(billCM.Billing_Invoice__c)) {
                billingByBCM.get(billCM.Billing_Invoice__c).add(billCM.Id);
            } else {
                billingByBCM.put(billCM.Billing_Invoice__c, new Set<Id> {billCM.Id});
            }
        }

        if(!billingByBCM.isEmpty()){
            for (Billing_Cash_Receipt__c billReceipt : billingCashReceipts) {
                if (usesCashLedger(billReceipt) && billingByBCM.containsKey(billReceipt.Billing__c)) {
                    for (Id existedBCM : billingByBCM.get(billReceipt.Billing__c)) {
                        Id PeriodOne = billingCreditMemos.get(existedBCM).Accounting_Period__c;
                        Id PeriodTwo = billReceipt.Accounting_Period__c;
                        if (isPeriodOneAfterPeriodTwo(PeriodOne, PeriodTwo)) {
                            if(!System.Trigger.isExecuting){
                                throw new DmlException(BCR_IN_FUTURE_ERROR);
                            } else {
                                billingCashReceiptsMap.get(billReceipt.Id).addError(BCR_IN_FUTURE_ERROR, false);
                            }
                        }
                    }
                }
            }
        }
    }

    private static Boolean usesCashLedger(Billing_Cash_Receipt__c bcr) {
        return LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(bcr.Billing__r.Ledger__c)
        || LedgerHandler.getInstanceWithoutSharing().isCashLedger(bcr.Billing__r.Ledger__c);
    }

    private static Boolean isPeriodOneAfterPeriodTwo(Id periodOne, Id periodTwo) {
        return AccountingPeriodHandler.getInstance().compareAccountingPeriods(periodOne, periodTwo) == 1;
    }

    public static void post(List<Billing_Cash_Receipt__c> newRecords) {
        if (AccountingSettingsHandler.isAutoPostBillingCashReceiptsEnabled()) {
            List<Billing_Cash_Receipt__c> recordsToPost = getBCRsToPostUnpost(newRecords);
            if (!FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
                isFirstRun = false;//to bypass GLAccountValidator after Posting Status change

                List<PostResult> postResults = postHandler.post(recordsToPost);
                //Check posting results
                Map<Id, String> notPostedRecordIdToErrorMsg = new Map<Id, String>();
                for (PostResult result : postResults) {
                    if (!result.isSuccess) {
                        String errorMessage = (result.errors != null && !result.errors.isEmpty()) ? result.errors[0].message : 'N/A';
                        notPostedRecordIdToErrorMsg.put(result.id, errorMessage);
                    }
                }
                //If any BCR has not been posted - block insertion of the record
                for (Billing_Cash_Receipt__c bcr : newRecords) {
                    if (notPostedRecordIdToErrorMsg.containsKey(bcr.Id)) {
                        bcr.addError(String.format(AUTO_POST_FAILED_ERROR, new List<String>{notPostedRecordIdToErrorMsg.get(bcr.Id)}));
                    }
                }
            } else {
                List<Id> bcrIds = new List<Id>();
                for (Billing_Cash_Receipt__c bcr : recordsToPost) {
                    bcrIds.add(bcr.Id);
                }
                new PostProcessor().post(bcrIds);
            }
        }
    }

    public static void unpost(List<Billing_Cash_Receipt__c> newRecords) {
        if (!FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            List<Billing_Cash_Receipt__c> recordsToUnPost = new List<Billing_Cash_Receipt__c>();
            recordsToUnPost = getBCRsToPostUnpost(newRecords);

            AbstractPostHandler postHandler = new BillingCashReceiptPostHandler();
            postHandler.unpost(recordsToUnPost);
        } else {
            List<Billing_Cash_Receipt__c> postedRecords = new List<Billing_Cash_Receipt__c>();
            for (Billing_Cash_Receipt__c bcr : newRecords) {
                if (bcr.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                    postedRecords.add(bcr);
                }
            }
            if (!postedRecords.isEmpty()) {
                for (Billing_Cash_Receipt__c bcr : postedRecords) {
                    bcr.addError(LDO_POSTED_DELETE_ERROR);
                }
            }
        }
    }

    public static void setPostingStatusForLegacyRecords(List<Billing_Cash_Receipt__c> newRecords) {
        Set<Id> legacyPostedBcrIds = getLegacyPostedBcrIds(
            getBCRsWithNotPostedStatus(newRecords)
        );

        if (!legacyPostedBcrIds.isEmpty()) {
            TriggerObserver.getInstance().unlockField(Billing_Cash_Receipt__c.Status__c);
            for (Billing_Cash_Receipt__c newBCR : newRecords) {
                if (legacyPostedBcrIds.contains(newBCR.Id)) {
                    newBCR.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
                }
            }
        }

    }

    private static List<Billing_Cash_Receipt__c> getBCRsWithNotPostedStatus(List<Billing_Cash_Receipt__c> newRecords) {
        List<Billing_Cash_Receipt__c> retVal = new List<Billing_Cash_Receipt__c>();
        for (Billing_Cash_Receipt__c newRecord : newRecords) {
            if (newRecord.Status__c == null || newRecord.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED) {
                retVal.add(newRecord);
            }
        }
        return retVal;
    }

    private static Set<Id> getLegacyPostedBcrIds(List<Billing_Cash_Receipt__c> scope) {
        Set<Id> legacyPostedBcrIds = new Set<Id>();
        if (!scope.isEmpty()) {
            for (Transaction__c tr : DomainUtils.getTransactionsByBcr((List<Billing_Cash_Receipt__c>) scope)) {
                legacyPostedBcrIds.add(tr.Billing_Cash_Receipt__c);
            }
        }
        return legacyPostedBcrIds;
    }

    private static List<Billing_Cash_Receipt__c> getBCRsToPostUnpost(List<Billing_Cash_Receipt__c> newRecords) {
        List<Billing_Cash_Receipt__c> recordsToPostUnpost = new List<Billing_Cash_Receipt__c>();
        for(Billing_Cash_Receipt__c billingCashReceipt : newRecords){
            if(billingCashReceipt.Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND){
                recordsToPostUnpost.add(billingCashReceipt);
            }
        }
        return recordsToPostUnpost;
    }

}