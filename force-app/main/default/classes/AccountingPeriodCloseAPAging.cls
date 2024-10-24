public with sharing class AccountingPeriodCloseAPAging implements Database.Batchable<sObject>, Database.Stateful {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    private Accounting_Period__c currentPeriod;
    private Id currentPeriodId;
    private String currentPeriodName;
    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    public Accounting_Settings__c main;    
    private String query; 

    public AccountingPeriodCloseAPAging(AccountingPeriodOpenCloseOptions periodInfoContainer) {
 
        main = AccountingSettingsHandler.getAccountingSettings();
        this.periodInfoContainer = periodInfoContainer;
        this.currentPeriod = periodInfoContainer.getCurrentPeriod();
        this.currentPeriodId = currentPeriod.Id;
        this.currentPeriodName = currentPeriod.Name;

        this.query =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Accounting_Period__c, ' +
                    PACKAGE_QUALIFIER + 'Discount_Amount__c, ' +
                    PACKAGE_QUALIFIER + 'Total__c, '  +
                    PACKAGE_QUALIFIER + 'Purchase_Tax3__c, '  +
                    PACKAGE_QUALIFIER + 'Ledger__c, '  +
                    PACKAGE_QUALIFIER + 'Ledger_Amount__c, '  +
                    PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c, '  +
                    PACKAGE_QUALIFIER + 'Balance__c, ' +
                    PACKAGE_QUALIFIER + 'Type__c, ' +
                    PACKAGE_QUALIFIER + 'Reverse_Charge__c, ' +
                    PACKAGE_QUALIFIER + 'Closed_Accounting_Period__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'Account_Payable__c ' + 
            'WHERE (' + PACKAGE_QUALIFIER + 'Closed_Accounting_Period__c = NULL ' +
            'OR ' + PACKAGE_QUALIFIER + 'Closed_Accounting_Period__r.Name >= \'' + currentPeriodName + '\') ' +
            'AND ' + PACKAGE_QUALIFIER + 'Accounting_Period__r.Name <= \'' + currentPeriodName + '\' ';
    }
    
    public Database.QueryLocator start(Database.BatchableContext batchableContext) {
        return DomainUtils.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext batchableContext, List<sObject> scope) {
        Map<Id, AP_Aging_History__c> apAgingHistoryMap = new Map<Id, AP_Aging_History__c>();
        List<Account_Payable__c> updateAPs = new  List<Account_Payable__c>();
        List<AgingHandler.SourceDocumentAgingDecorator> sddList = new  List<AgingHandler.SourceDocumentAgingDecorator>();

        Set <Id> apIds = new Set<Id>();
        for (Account_Payable__c ap : (List<Account_Payable__c>) scope) {
            sddList.add(new AgingHandler.SourceDocumentAgingDecorator(ap));
            apIds.add(ap.Id);
        }
        AgingHandler.currentPeriod = currentPeriod;
        AgingHandler.setRelatedChildObjects(sddList[0].getNewObject(), apIds);

        List<AP_Aging_History__c> deleteAPAgingHistory = DomainUtils.getAPAgingHistoryByRelatedAPIdAndAccPeriodId(apIds, currentPeriodId);

        try {
            for (AgingHandler.SourceDocumentAgingDecorator sdd : sddList) {
                sdd.setCreditMemoObjects(AgingHandler.creditMemoObjectsByIds.get(sdd.getObjectId()));
                sdd.setCreditMemoInvoiceObjects(AgingHandler.creditMemoInvoiceObjectsByIds.get(sdd.getObjectId()));
                sdd.setAppliedObjects(AgingHandler.appliedObjectsByIds.get(sdd.getObjectId()));

                if (!sdd.isZeroBalance() || sdd.isMostRecentPeriodSourceExist()) {
                    AP_Aging_History__c aph = new AP_Aging_History__c(
                        Amount__c = sdd.getAmountBalance().setScale(2, System.RoundingMode.HALF_UP),
                        Accounting_Period__c = currentPeriod.Id,
                        Account_Payable__c = sdd.getObjectId()
                    );

                    apAgingHistoryMap.put(sdd.getObjectId(), aph);
                }

                if (sdd.isZeroBalance() && sdd.getClosedAccountingPeriodValue() == NULL) {
                    updateAPs.add((Account_Payable__c) sdd.getNewObject());
                }
            }

            if (!updateAPs.isEmpty()) {
                TriggerObserver.getInstance().unlockField(Account_Payable__c.Closed_Accounting_Period__c);
                Integer recCount = 0;
                for (Database.SaveResult sr : Database.update(updateAPs, false)) {
                    if (!sr.isSuccess()) {
                        apAgingHistoryMap.remove(updateAPs[recCount].Id);
                    }
                    recCount++;
                }
                TriggerObserver.purgeUnlockedFields(Account_Payable__c.Closed_Accounting_Period__c);
            }

            if (main != NULL && main.Enable_AP_Period_Sensitive_Aging__c) {
                SFDCSecurityUtils.deleteProxy(deleteAPAgingHistory);
                SFDCSecurityUtils.insertProxy(apAgingHistoryMap.values());
            }

        }
        catch (Exception ex) {
            //The AP and Billing aging history close and open routines should silently fail with an exception.
            //The accounting period open and close processes should continue in this case.
        }
    }

    public void finish(Database.BatchableContext batchableContext) {
        try {
            // if period is not soft close i.e., AP_close__C checkbox is not checked and status is open then simply finish the Batch Finish method.
            if(periodInfoContainer.context != AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_CLOSE){
                
                //change interim status to final state for current period
                AccountingPeriodOpenCloseUtils.updatePeriodStatus(new List<Accounting_Period__c>{currentPeriod}, AccountingPeriodActions.CLOSED_STATUS);            

                //if there is a next Accounting Period then start the batch chain for that period
                if (periodInfoContainer.hasNext()) {
                    Integer nextIndex = periodInfoContainer.getIndex() + 1;
                    periodInfoContainer.setIndex(nextIndex);
                    Database.executeBatch(new AccountingPeriodCloseBatchProcessor(periodInfoContainer));
                }
                else {
                    List<Date> closeDates = new List<Date>(); 
                    /*  if ERP is enabled and auto inventory quantity avail histories (IQAH) is enabled then 
                        call executeInventoryHistoriesBatch from ERP for the current period
                        each period will execute it's own batch independently of the open/close batch chain */
                    
                    //Test.isRunningTest() is used to provide coverage since there is no other way to test the scenario as the fields below are from the ERP package.
                    if((AccountingSettingsHandler.isERPEnabled() && (boolean)main.get(ERP_PACKAGE_QUALIFIER + 'Enable_Inventory_Period_History__c') == true) || Test.isRunningTest())
                    {
                        for(Accounting_Period__c period: periodInfoContainer.selectedPeriods)
                        {
                            closeDates.add(period.End_Date__c);
                        }
                        //lastly execute the inventory ERP batch to create inventory movements by sinlge batch
                        FinancialSuiteService.executeInventoryHistoryCreateBatch(closeDates);
                    }
                    //the batch chain is complete for the closing the accounting periods
                    AccountingPeriodOpenCloseUtils.sendPeriodCloseRequestProcessedEmail(periodInfoContainer.getPeriodNames());
                }
                
            }
            //this is soft close context and we don't want any other batch classes to execute
            else{

                if (periodInfoContainer.hasNext()) {
                    Integer nextIndex = periodInfoContainer.getIndex() + 1;
                    periodInfoContainer.setIndex(nextIndex);
                    Database.executeBatch(new AccountingPeriodCloseAPAging(periodInfoContainer));
                }
            }
        }
        catch (Exception ex) {
        
        }
    }
}