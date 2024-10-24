public with sharing class AccountingPeriodCloseBillingAging implements Database.Batchable<sObject>, Database.Stateful {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private Accounting_Period__c currentPeriod;
    private Id currentPeriodId;
    private String currentPeriodName;
    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    private String query;
    public Accounting_Settings__c main;

    public AccountingPeriodCloseBillingAging(AccountingPeriodOpenCloseOptions periodInfoContainer) {

        main = AccountingSettingsHandler.getAccountingSettings();

        this.periodInfoContainer = periodInfoContainer;
        this.currentPeriod = periodInfoContainer.getCurrentPeriod();
        this.currentPeriodId = currentPeriod.Id;
        this.currentPeriodName = currentPeriod.Name;

        this.query =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Period__c, ' +
                    PACKAGE_QUALIFIER + 'Total__c, ' +
                    PACKAGE_QUALIFIER + 'Ledger__c, ' +
                    PACKAGE_QUALIFIER + 'Ledger_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c, ' +
                    PACKAGE_QUALIFIER + 'Balance__c, '+
                    PACKAGE_QUALIFIER + 'Type__c, ' +
                    PACKAGE_QUALIFIER + 'Closed_Accounting_Period__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Billing__c ' +
            'WHERE (' + PACKAGE_QUALIFIER + 'Closed_Accounting_Period__c = NULL ' +
            'OR ' + PACKAGE_QUALIFIER + 'Closed_Accounting_Period__r.Name >= \'' + currentPeriodName + '\') ' +
            'AND ' + PACKAGE_QUALIFIER + 'Accounting_Period__r.Name <= \'' + currentPeriodName + '\' ';

    }
    
    public Database.QueryLocator start(Database.BatchableContext batchableContext) {
        return DomainUtils.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        Map<Id, Billing_Aging_History__c> billingAgingHistoryMap = new Map<Id, Billing_Aging_History__c>();
        List<Billing__c> updateBillings = new List<Billing__c>();

        List<AgingHandler.SourceDocumentAgingDecorator> sddList = new List<AgingHandler.SourceDocumentAgingDecorator>();
        Set <Id> billIds = new Set<Id>();
        for (Billing__c bill : (List<Billing__c>) scope) {
            sddList.add(new AgingHandler.SourceDocumentAgingDecorator(bill));
            billIds.add(bill.Id);
        }

        AgingHandler.currentPeriod = currentPeriod;
        AgingHandler.setRelatedChildObjects(sddList[0].getNewObject(), billIds);

        List<Billing_Aging_History__c> deleteBillingAgingHistories =
                DomainUtils.getBillingAHByRelatedBillingIdAndAccPeriodId(billIds, currentPeriodId);

        try {
            for (AgingHandler.SourceDocumentAgingDecorator sdd : sddList) {

                sdd.setCreditMemoObjects(AgingHandler.creditMemoObjectsByIds.get(sdd.getObjectId()));
                sdd.setCreditMemoInvoiceObjects(AgingHandler.creditMemoInvoiceObjectsByIds.get(sdd.getObjectId()));
                sdd.setAppliedObjects(AgingHandler.appliedObjectsByIds.get(sdd.getObjectId()));

                Boolean isRefundCreditMemo = sdd.isCreditMemoType() && sdd.isRefundAppliedObjectsExist();
                if (!isRefundCreditMemo && (!sdd.isZeroBalance() || sdd.isMostRecentPeriodSourceExist())) {
                    Billing_Aging_History__c bph = new Billing_Aging_History__c(
                        Amount__c = sdd.getAmountBalance().setScale(2, System.RoundingMode.HALF_UP),
                        Accounting_Period__c = currentPeriod.Id,
                        Billing__c = sdd.getObjectId()
                    );

                    billingAgingHistoryMap.put(sdd.getObjectId(), bph);
                }

                if (sdd.isZeroBalance() && !sdd.isMostRecentPeriodSourceExist() && sdd.getClosedAccountingPeriodValue() == NULL) {
                    sdd.setClosedAccountingPeriodCurrentPeriod();
                    updateBillings.add((Billing__c) sdd.getNewObject());
                }
            }

            if (!updateBillings.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Billing__c.Closed_Accounting_Period__c);
                Integer recCount = 0;
                for (Database.SaveResult sr : Database.update(updateBillings, false)) {
                    if (!sr.isSuccess()) {
                        billingAgingHistoryMap.remove(updateBillings[recCount].Id);
                    }
                    recCount++;
                }
                TriggerObserver.purgeUnlockedFields(Billing__c.Closed_Accounting_Period__c);
            }

            if (main != NULL && main.Enable_Billing_Period_Sensitive_Aging__c) {
                SFDCSecurityUtils.deleteProxy(deleteBillingAgingHistories);
                SFDCSecurityUtils.insertProxy(billingAgingHistoryMap.values());
            }
        }
        catch (Exception ex) {
            //The AP and Billing aging history close and open routines should silently fail with an exception.
            // The accounting period open and close processes should continue in this case.
        }
    }
    
    public void finish(Database.BatchableContext batchableContext) {
    
        // if period is not soft close i.e., AR_close__C checkbox is uncheked  and status is open then simply finish the Batch Finish method.
            if(periodInfoContainer.context != AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_CLOSE){
                Database.executeBatch(
                    new AccountingPeriodCloseAPAging(periodInfoContainer),
                    AccountingPeriodOpenCloseUtils.PAYABLE_AND_BILLING_AGING_BATCH_SIZE
                );
            }else{

                if (periodInfoContainer.hasNext()) {
                    Integer nextIndex = periodInfoContainer.getIndex() + 1;
                    periodInfoContainer.setIndex(nextIndex);
                    Database.executeBatch(new AccountingPeriodCloseBillingAging(periodInfoContainer));
                }
            }
    }

}