public with sharing class AccountPayableSelector extends SObjectSelector {
    public AccountPayableSelector() {
        super();
    }

    public AccountPayableSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }

    public override Schema.SObjectType getSObjectType() {
        return Account_Payable__c.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        List<Schema.SObjectField> fields = new List<Schema.SObjectField> {
            Account_Payable__c.Id,
            Account_Payable__c.Name,
            Account_Payable__c.Accounting_Period__c,
            Account_Payable__c.Accounting_Year__c,
            Account_Payable__c.Age__c,
            Account_Payable__c.AP_Disbursement_Count__c,
            Account_Payable__c.Balance__c,
            Account_Payable__c.Balance_Minus_Discount__c,
            Account_Payable__c.Closed_Accounting_Period__c,
            Account_Payable__c.Contact__c,
            Account_Payable__c.Credit_Memo_Applied_Amount__c,
            Account_Payable__c.Currency_Conversion_Rate__c,
            Account_Payable__c.Default_File_Id__c,
            Account_Payable__c.Discount_Amount__c,
            Account_Payable__c.Due_Date__c,
            Account_Payable__c.EarlyPayDate__c,
            Account_Payable__c.Employee__c,
            Account_Payable__c.Fixed_Asset__c,
            Account_Payable__c.Date__c,
            Account_Payable__c.Ledger__c,
            Account_Payable__c.Ledger_Amount__c,
            Account_Payable__c.Line_Count__c,
            Account_Payable__c.Net_Amount__c,
            Account_Payable__c.On_Hold__c,
            Account_Payable__c.Paid_Amount__c,
            Account_Payable__c.Payee__c,
            Account_Payable__c.Payee_Id__c,
            Account_Payable__c.Payee_Reference__c,
            Account_Payable__c.Payment_Services_Eligible__c,
            Account_Payable__c.AS_Pay_Type__c,
            Account_Payable__c.Payment_Status__c,
            Account_Payable__c.Status__c,
            Account_Payable__c.Proprietary_Payable_Number__c,
            Account_Payable__c.Purchase_Tax2__c,
            Account_Payable__c.Purchase_Tax3__c,
            Account_Payable__c.Recurring_Account_Payable__c,
            Account_Payable__c.Reverse_Charge__c,
            Account_Payable__c.Reverse_Charge_Count__c,
            Account_Payable__c.Sub_Total__c,
            Account_Payable__c.Total__c,
            Account_Payable__c.Type__c,
            Account_Payable__c.VAT_Line_Count__c,
            Account_Payable__c.Vendor__c
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Schema.SObjectField currencyIsoCode = SchemaDescribe.getDescribe(Account_Payable__c.SObjectType).getField('CurrencyIsoCode');
            fields.add(currencyIsoCode);
        }

        return fields;
    }
}