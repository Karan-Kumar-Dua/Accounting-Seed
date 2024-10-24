public with sharing class BillingSelector extends SObjectSelector {
    public BillingSelector() {
        super();
    }

    public BillingSelector(System.AccessLevel accessLevel, SharingMode sharingType) {
        super(accessLevel, sharingType);
    }

    public override Schema.SObjectType getSObjectType() {
        return Billing__c.SObjectType;
    }

    public override List<Schema.SObjectField> getSObjectFields() {
        List<Schema.SObjectField> fields = new List<Schema.SObjectField> {
            Billing__c.Id,
            Billing__c.Name,
            Billing__c.Accounting_Period__c,
            Billing__c.Accounting_Year__c,
            Billing__c.Age__c,
            Billing__c.Balance__c,
            Billing__c.Billing_Cash_Receipt_Count__c,
            Billing__c.Billing_City__c,
            Billing__c.Billing_Comment__c,
            Billing__c.Billing_Contact__c,
            Billing__c.Billing_Country__c,
            Billing__c.Billing_Cycle_End_Date__c,
            Billing__c.Billing_Cycle_Start_Date__c,
            Billing__c.Billing_Format__c,
            Billing__c.Billing_PostalCode__c,
            Billing__c.Billing_State__c,
            Billing__c.Billing_Street__c,
            Billing__c.Billing_Terms_Name__c,
            Billing__c.Cash_Application_Adjustment_Amount__c,
            Billing__c.Closed_Accounting_Period__c,
            Billing__c.Credit_Memo_Applied_Amount__c,
            Billing__c.Credit_Memo_Reason__c,
            Billing__c.Currency_Conversion_Rate__c,
            Billing__c.Customer__c,
            Billing__c.Date__c,
            Billing__c.Destination_Address_Override__c,
            Billing__c.Discount_Amount__c,
            Billing__c.Discount_Due_Date__c,
            Billing__c.Discount_Percent__c,
            Billing__c.Due_Date2__c,
            Billing__c.Funded_Amount__c,
            Billing__c.Ledger__c,
            Billing__c.Ledger_Amount__c,
            Billing__c.Line_Count__c,
            Billing__c.Locked_In_AvaTax__c,
            Billing__c.Opportunity__c,
            Billing__c.Origin_Address_Override__c,
            Billing__c.Paid_Date__c,
            Billing__c.Payment_Link__c,
            Billing__c.Payment_Processor__c,
            Billing__c.Payment_Site_URL__c,
            Billing__c.PDF_Email_Status__c,
            Billing__c.PO_Number__c,
            Billing__c.Proprietary_Billing_Number__c,
            Billing__c.Received_Amount__c,
            Billing__c.Recurring_Billing__c,
            Billing__c.Sales_Tax2__c,
            Billing__c.Sales_Tax3__c,
            Billing__c.Shipping_City__c,
            Billing__c.Shipping_Contact__c,
            Billing__c.Shipping_Country__c,
            Billing__c.Shipping_PostalCode__c,
            Billing__c.Shipping_State__c,
            Billing__c.Shipping_Street__c,
            Billing__c.Status__c,
            Billing__c.Sub_Total__c,
            Billing__c.Total__c,
            Billing__c.Type__c,
            Billing__c.VAT_Line_Count__c
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Schema.SObjectField currencyIsoCode = SchemaDescribe.getDescribe(Billing__c.SObjectType).getField('CurrencyIsoCode');
            fields.add(currencyIsoCode);
        }

        return fields;
    }

}