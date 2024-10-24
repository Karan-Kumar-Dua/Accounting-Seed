public with sharing class BillingCreditMemoActions {

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Billing_Credit_Memo__c.Amount__c => 2
    };

    public static void updateBillings(List<Billing_Credit_Memo__c> billingCreditMemos) {
        Map<Id, Billing__c> billings = new Map<Id, Billing__c>();

        for (Billing_Credit_Memo__c bcm : billingCreditMemos) {
            billings.put(bcm.Billing_Invoice__c, NULL);
            billings.put(bcm.Billing_Credit_Memo__c, NULL);
        }

        for (Billing__c bill : DomainUtils.getBillingsById(billings.keySet())) {
            billings.put(bill.Id, bill);
        }

        try {
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{Billing__c.Credit_Memo_Applied_Amount__c}
            );
            SFDCSecurityUtils.updateProxy(billings.values());
            TriggerObserver.reset();
        }
        catch (DmlException dmlEx) {
            for (Billing_Credit_Memo__c bcm : billingCreditMemos) {
                bcm.addError(dmlEx.getDmlMessage(0));
            }
        }
        catch (Exception ex) {
            for (Billing_Credit_Memo__c bcm : billingCreditMemos) {
                bcm.addError(ex);
            }
        }
    }

    public static void setAppliedDateIfBlank(List<Billing_Credit_Memo__c> billingCreditMemos) {
        try {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            
            for (Billing_Credit_Memo__c bcm : billingCreditMemos) {
                if (bcm.Accounting_Period__c != NULL && bcm.Applied_Date__c == NULL) {
                    bcm.Applied_Date__c = acctPeriodHandler.getAccountingPeriodById(bcm.Accounting_Period__c).Start_Date__c;
                }
            }
        }
        catch (Exception ex) {
            for (Billing_Credit_Memo__c bcm : billingCreditMemos) {
                bcm.addError(ex.getMessage(), false);
            }
        }
    }

    public static void preventIfExistBCRInFutureAccountingPeriod(Map<Id, Billing_Credit_Memo__c> billingCreditMemos) {
        if (AccountingPeriodActions.isDelarcInProgress) {
            return;
        }
        Map<Id, Set<Id>> billingByBCM = new Map<Id, Set<Id>>();
        for (Billing_Credit_Memo__c billCM : billingCreditMemos.values()) {
            if (billingByBCM.containsKey(billCM.Billing_Invoice__c)) {
                billingByBCM.get(billCM.Billing_Invoice__c).add(billCM.Id);
            } else {
                billingByBCM.put(billCM.Billing_Invoice__c, new Set<Id> {billCM.Id});
            }
        }

        for (Billing_Cash_Receipt__c billReceipt : DomainUtils.getBillingCashReceiptsByBillingId(billingByBCM.keySet())) {
            if ((LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(billReceipt.Billing__r.Ledger__c)
                || LedgerHandler.getInstanceWithoutSharing().isCashLedger(billReceipt.Billing__r.Ledger__c))
                && billingByBCM.containsKey(billReceipt.Billing__c)) {
                for (Id existedBCM : billingByBCM.get(billReceipt.Billing__c)) {
                    if (billReceipt.Accounting_Period__c == billingCreditMemos.get(existedBCM).Accounting_Period__c) {
                        billingCreditMemos.get(existedBCM).addError(
                            Trigger.isDelete ? Label.ERR_BCR_APD_IN_FUTURE_PERIOD : Label.ERR_CM_IN_FUTURE_PERIOD,
                            false
                        );
                    } else if (AccountingPeriodHandler.getInstance().compareAccountingPeriods(
                        billReceipt.Accounting_Period__c,
                        billingCreditMemos.get(existedBCM).Accounting_Period__c) == 1) {
                        billingCreditMemos.get(existedBCM).addError(Label.ERR_BCR_APD_IN_FUTURE_PERIOD, false);
                    }
                }
            }
        }
    }

    public static void preventIfInvoiceStatusIsInProgress(Map<Id, Billing_Credit_Memo__c> billingCreditMemos) {
        Map<Id, Set<Id>> billByBCM = new Map<Id, Set<Id>>();
        for (Billing_Credit_Memo__c billCM : billingCreditMemos.values()) {
            if (billByBCM.containsKey(billCM.Billing_Invoice__c)) {
                billByBCM.get(billCM.Billing_Invoice__c).add(billCM.Id);
            } else {
                billByBCM.put(billCM.Billing_Invoice__c, new Set<Id> {billCM.Id});
            }
        }

        Map<Id, Billing__c> billingsMap = new Map<Id, Billing__c> (DomainUtils.getBillingsById(billByBCM.keySet()));

        for (Billing_Credit_Memo__c bpm : billingCreditMemos.values()) {
            if (billingsMap.containsKey(bpm.Billing_Invoice__c) && SObjectActions.isLDOInProgressStatus(billingsMap.get(bpm.Billing_Invoice__c))) {
                bpm.addError(Label.ERR_CM_APPLY_IF_BILLING_IN_PROGRESS, false);
            }
        }

        for (Billing_Cash_Receipt__c billReceipt : DomainUtils.getBillingCashReceiptsByBillingId(billByBCM.keySet())) {
            if (billByBCM.containsKey(billReceipt.Billing__c) && SObjectActions.isLDOInProgressStatus(billReceipt)) {
                for (Id existedBCM : billByBCM.get(billReceipt.Billing__c)) {
                    billingCreditMemos.get(existedBCM).addError(Label.ERR_CM_APPLY_IF_BILLING_IN_PROGRESS, false);
                }
            }
        }
    }

}