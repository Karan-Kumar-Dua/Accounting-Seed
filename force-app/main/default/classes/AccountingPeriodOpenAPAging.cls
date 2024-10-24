public with sharing class AccountingPeriodOpenAPAging implements Database.Batchable<sObject>, Database.Stateful {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    private AccountingPeriodOpenCloseOptions periodInfoContainer;
    private Accounting_Period__c currentPeriod;
    private String query;

    public Accounting_Settings__c main;
    
    public AccountingPeriodOpenAPAging(AccountingPeriodOpenCloseOptions periodInfoContainer) {
        main = AccountingSettingsHandler.getAccountingSettings();
        this.periodInfoContainer = periodInfoContainer;
        this.currentPeriod = periodInfoContainer.getCurrentPeriod();
        this.query =
            'SELECT Id, ' +
                    PACKAGE_QUALIFIER + 'Account_Payable__r.' + PACKAGE_QUALIFIER + 'Closed_Accounting_Period__c ' +
            'FROM ' + PACKAGE_QUALIFIER + 'AP_Aging_History__c ' + 
            'WHERE ' + PACKAGE_QUALIFIER + 'Accounting_Period__c = \'' + currentPeriod.Id + '\'';
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            if(!(this.currentPeriod.Close_AP__c)){
                SFDCSecurityUtils.deleteProxy(scope, false);
            }
        }
        catch (Exception ex) {
            //The AP and Billing aging history close and open routines should silently fail with an exception.
            // The accounting period open and close processes should continue in this case.
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        try {
            if(periodInfoContainer.context != AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_OPEN){

                //change interim status to final state
                AccountingPeriodOpenCloseUtils.updatePeriodStatus(new List<Accounting_Period__c>{currentPeriod}, AccountingPeriodActions.OPEN_STATUS);

                if (periodInfoContainer.hasPrevious()) {
                    Integer previousIndex = periodInfoContainer.getIndex() - 1;
                    periodInfoContainer.setIndex(previousIndex);
                    Database.executeBatch(new AccountingPeriodOpenBatchProcessor(periodInfoContainer));
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
                        FinancialSuiteService.executeInventoryHistoryDeleteBatch(closeDates);
                    }
                    
                    AccountingPeriodOpenCloseUtils.sendPeriodOpenRequestProcessedEmail(periodInfoContainer.getPeriodNames());
                }
            }
            else{

                if (periodInfoContainer.hasNext()) {
                    Integer nextIndex = periodInfoContainer.getIndex() + 1;
                    periodInfoContainer.setIndex(nextIndex);
                    Database.executeBatch(new AccountingPeriodOpenAPAging(periodInfoContainer));
                }
            }
        }
        catch (Exception ex) {
        }
    }

}