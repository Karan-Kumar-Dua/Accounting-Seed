global with sharing class AmortizationOptions {

    global AmortizationOptions() {}

    @InvocableVariable(label='Amount' description='Amount to Amortize.  Typically set to the Sub_Total__c value on Billing or Payable or Sub_Total__c on Billing and Payable lines, but it can be set to any amount you wish to amortize' )
    global Decimal amount;

    @InvocableVariable(label='Start Date' description='Start Date' required=true)
    global Date startDate;

    @InvocableVariable(label='End Date' description='End Date' required=false)
    global Date endDate;

    @InvocableVariable(label='Number Of Periods' description='Number Of Periods' required=false)
    global Integer numberOfPeriods;

    @InvocableVariable(label='Record to Amortize Id' description='The Id for the record to create amortization entries' required=true)
    global Id sourceDocument;

    @InvocableVariable(label='Amortization Method' description='Amortization Method to use as defined in the Label field on the Binding Custom Metadata Type' required=true )
    global String amortizationMethod;
    
    @InvocableVariable(label='Debit GL Account Id' description='Upon posting a debit entry will be made to this GL account.' )
    global Id debitGlAccount;
    
    @InvocableVariable(label='Credit GL Account Id' description='Upon posting a credit entry will be made to this GL account.' )
    global Id creditGlAccount;
    
    @InvocableVariable(label='Related Product Id' description='Related Product' )
    global Id product;
    
    @InvocableVariable(label='Project Id' description='Typically used to track customer engagements or events' )
    global Id project;
    
    @InvocableVariable(label='Project Task Id' description='Used to track a detailed component of Project' )
    global Id projectTask;
    
    @InvocableVariable(label='GL Account Variable 1 Id' description='General Ledger segment used for reporting of a business unit such as division or department.' )
    global Id glVariable1;
    
    @InvocableVariable(label='GL Account Variable 2 Id' description='General Ledger segment used for reporting of a business unit such as division or department.' )
    global Id glVariable2;
    
    @InvocableVariable(label='GL Account Variable 3 Id' description='General Ledger segment used for reporting of a business unit such as division or department.' )
    global Id glVariable3;
    
    @InvocableVariable(label='GL Account Variable 4 Id' description='General Ledger segment used for reporting of a business unit such as division or department.' )
    global Id glVariable4;
   
    @InvocableVariable(label='Description' description='Used to capture any external source document identifier or description.' )
    global String description;

    @InvocableVariable(label='Accrual and/or Cash' description='Indicate on which Ledger(s) to create and post this record.' )
    global String accrualCash;
    
    @InvocableVariable(label='Default Revenue/Prepaid Expense enablement' description='Used to capture value from Amortize_Default_Revenue_Prepaid_Expense__c field from Accounting Settings.' )
    global Boolean amortizeDefaultRevenuePrepaidExpense = DomainUtils.getAccountingSettings()[0].Amortize_Default_Revenue_Prepaid_Expense__c;
}