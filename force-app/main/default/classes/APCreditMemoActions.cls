public with sharing class APCreditMemoActions {

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        AP_Credit_Memo__c.Amount__c => 2
    };

    public static void updateAccountPayables(List<AP_Credit_Memo__c> apCreditMemos) {
        Map<Id, Account_Payable__c> invoices = new Map<Id, Account_Payable__c>();
        
        for (AP_Credit_Memo__c acm : apCreditMemos) {
            invoices.put(acm.Account_Payable_Invoice__c, NULL);
            invoices.put(acm.Account_Payable_Credit_Memo__c, NULL);
        }
        
        for (Account_Payable__c ap : DomainUtils.getAccountPayablesById(invoices.keySet())) {
            invoices.put(ap.Id, ap);
        }
        
        try {
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{Account_Payable__c.Credit_Memo_Applied_Amount__c}
            );
            SFDCSecurityUtils.updateProxy(invoices.values());
        }
        catch (DmlException dmlEx) {
            for (AP_Credit_Memo__c acm : apCreditMemos) {
                acm.addError(dmlEx.getDmlMessage(0));
            }
        }
        catch (Exception ex) {
            for (AP_Credit_Memo__c acm : apCreditMemos) {
                acm.addError(ex);
            }
        }
    }

    public static void setAppliedDateIfBlank(List<AP_Credit_Memo__c> apCreditMemos) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();

            for (AP_Credit_Memo__c apCreditMemo : apCreditMemos) {
                if (apCreditMemo.Accounting_Period__c != NULL && apCreditMemo.Applied_Date__c == NULL) {
                    apCreditMemo.Applied_Date__c = acctPeriodHandler.getAccountingPeriodById(apCreditMemo.Accounting_Period__c).Start_Date__c;
                }
            }
        }
        catch (Exception ex) {
            for (AP_Credit_Memo__c apCreditMemo : apCreditMemos) {
                apCreditMemo.addError(ex.getMessage(), false);
            }
        }
    }

    public static void preventIfExistAPDInFutureAccountingPeriod(Map<Id, AP_Credit_Memo__c> apCreditMemos) {
        if (AccountingPeriodActions.isDelarcInProgress) {
            return;
        }
        Map<Id, Set<Id>> payableByAPCM = new Map<Id, Set<Id>>();
        for (AP_Credit_Memo__c payCM : apCreditMemos.values()) {
            if (payableByAPCM.containsKey(payCM.Account_Payable_Invoice__c)) {
                payableByAPCM.get(payCM.Account_Payable_Invoice__c).add(payCM.Id);
            } else {
                payableByAPCM.put(payCM.Account_Payable_Invoice__c, new Set<Id> {payCM.Id});
            }
        }

        for (AP_Disbursement__c apd : DomainUtils.getAPDisbursementByPayableId(payableByAPCM.keySet())) {
            if ((LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(apd.Account_Payable__r.Ledger__c)
                || LedgerHandler.getInstanceWithoutSharing().isCashLedger(apd.Account_Payable__r.Ledger__c))
                && payableByAPCM.containsKey(apd.Account_Payable__c)) {
                for (Id existedAPCM : payableByAPCM.get(apd.Account_Payable__c)) {
                    if (apd.Accounting_Period__c == apCreditMemos.get(existedAPCM).Accounting_Period__c) {
                        apCreditMemos.get(existedAPCM).addError(
                            Trigger.isDelete ? Label.ERR_BCR_APD_IN_FUTURE_PERIOD : Label.ERR_CM_IN_FUTURE_PERIOD,
                            false
                        );
                    } else if (AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                        apd.Accounting_Period__c,
                        apCreditMemos.get(existedAPCM).Accounting_Period__c) == 1) {
                        apCreditMemos.get(existedAPCM).addError(Label.ERR_BCR_APD_IN_FUTURE_PERIOD, false);
                    }
                }
            }
        }
    }

    public static void preventIfInvoiceStatusIsInProgress(Map<Id, AP_Credit_Memo__c> apCreditMemos) {
        Map<Id, Set<Id>> payableByAPCM = new Map<Id, Set<Id>>();
        for (AP_Credit_Memo__c payCM : apCreditMemos.values()) {
            if (payableByAPCM.containsKey(payCM.Account_Payable_Invoice__c)) {
                payableByAPCM.get(payCM.Account_Payable_Invoice__c).add(payCM.Id);
            } else {
                payableByAPCM.put(payCM.Account_Payable_Invoice__c, new Set<Id> {payCM.Id});
            }
        }

        Map<Id, Account_Payable__c> payablesMap = new Map<Id, Account_Payable__c> (DomainUtils.getAccountPayablesById(payableByAPCM.keySet()));

        for (AP_Credit_Memo__c apm : apCreditMemos.values()) {
            if (payablesMap.containsKey(apm.Account_Payable_Invoice__c) && SObjectActions.isLDOInProgressStatus(payablesMap.get(apm.Account_Payable_Invoice__c))) {
                apm.addError(Label.ERR_CM_APPLY_IF_PAYABLE_IN_PROGRESS, false);
            }
        }

        for (AP_Disbursement__c apd : DomainUtils.getAPDisbursementByPayableId(payableByAPCM.keySet())) {
            if (payableByAPCM.containsKey(apd.Account_Payable__c) && SObjectActions.isLDOInProgressStatus(apd)) {
                for (Id existedAPCM : payableByAPCM.get(apd.Account_Payable__c)) {
                    apCreditMemos.get(existedAPCM).addError(Label.ERR_CM_APPLY_IF_PAYABLE_IN_PROGRESS, false);
                }
            }
        }
    }

}