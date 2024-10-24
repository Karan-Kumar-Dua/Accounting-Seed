global with sharing class FinancialReporterInvocableOptions  {

    @InvocableVariable(label='Report Type: PROFIT_AND_LOSS, PROFIT_AND_LOSS_VS_BUDGET, BALANCE_SHEET, TRIAL_BALANCE, CASH_FLOW, CUSTOM' description='One of the following: PROFIT_AND_LOSS, PROFIT_AND_LOSS_VS_BUDGET, BALANCE_SHEET, TRIAL_BALANCE, CASH_FLOW, CUSTOM' required=true)
    global String reportType;

    @InvocableVariable(label='Ledger Id' description='Ledger Id' )
    global Id ledger;
     
    @InvocableVariable(label='Starting Accounting Period Id' description='Starting Accounting Period Id' )
    global Id startingAccountingPeriod;

    @InvocableVariable(label='Ending Accounting Period Id' description='Ending Accounting Period Id' )
    global Id endingAccountingPeriod;
     
    @InvocableVariable(label='Subtitle' description='Subtitle' )
    global String subtitle;
     
    @InvocableVariable(label='Include Sub Type 1' description='Include Sub Type 1' )
    global Boolean includeSubType1;
     
    @InvocableVariable(label='Include Sub Type 2' description='Include Sub Type 2' )
    global Boolean includeSubType2;

    @InvocableVariable(label='Suppress Zero Amount Rows' description='Suppress Zero Amount Rows' )
    global Boolean suppressZeroAmountRows;

    @InvocableVariable(label='GL Variable 1' description='GL Variable 1' )
    global Id glVariable1;  
    
    @InvocableVariable(label='GL Variable 2' description='GL Variable 2' )
    global Id glVariable2;

    @InvocableVariable(label='GL Variable 3' description='GL Variable 3' )
    global Id glVariable3;

    @InvocableVariable(label='GL Variable 4' description='GL Variable 4' )
    global Id glVariable4;
   
    @InvocableVariable(label='Custom Report Id' description='Custom Report Id' )
    global Id financialReportDefinitionId;

    @InvocableVariable(label='Currency ISO Code' description='Currency ISO Code' )
    global String currencyISO;

    @InvocableVariable(label='Suppress Opening Balance' description='Suppress Opening Balance' )
    global Boolean suppressOpeningBalanceAndPeriodColumns;

    @InvocableVariable(label='Budget Ledger' description='Budget Ledger' )
    global Id budgetLedger;

    @InvocableVariable(label='Show All Periods' description='Show All Periods' )
    global Boolean showAllPeriods;

    @InvocableVariable(label='Rounding Mode:  NO_ROUNDING, WHOLE_AMOUNTS, ROUND_TO_1000' description='Rounding Mode' )
    global String roundingMode;

   
}