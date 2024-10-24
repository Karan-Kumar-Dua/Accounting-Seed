public with sharing class BillingLineSelector extends SelectorAbstract {

    public BillingLineSelector(){
        super(Billing_Line__c.getSObjectType());
        this.postingStatusField =  'Billing__r.Status__c';
    }

    public override List<Schema.SObjectField> getFields(){
        return new List<Schema.SObjectField>{
                Billing_Line__c.Id,
                Billing_Line__c.Name,
                Billing_Line__c.Billing__c,
                Billing_Line__c.Project__c,
                Billing_Line__c.Project_Task__c,
                Billing_Line__c.Product__c,
                Billing_Line__c.Rate__c,
                Billing_Line__c.Revenue_GL_Account__c,
                Billing_Line__c.Employee__c,
                Billing_Line__c.Hours_Units__c,
                Billing_Line__c.Total__c,
                Billing_Line__c.Sub_Total__c,
                Billing_Line__c.Date__c,
                Billing_Line__c.Tax_Amount2__c,
                Billing_Line__c.Tax_Line__c,
                Billing_Line__c.Product_Unit_Cost__c,
                Billing_Line__c.Inventory_GL_Account__c,
                Billing_Line__c.Expense_GL_Account__c,
                Billing_Line__c.Ledger__c,
                Billing_Line__c.GL_Account_Variable_1__c,
                Billing_Line__c.GL_Account_Variable_2__c,
                Billing_Line__c.GL_Account_Variable_3__c,
                Billing_Line__c.GL_Account_Variable_4__c,
                Billing_Line__c.Tax_Group__c,
                Billing_Line__c.Time_Card_Variable_1__c,
                Billing_Line__c.Time_Card_Variable_2__c,
                Billing_Line__c.Tax_Inclusive__c,
                Billing_Line__c.Combined_Tax_Rate__c
        };
    }

    public override List<String> getAdditionalFieldPaths() {
        return new List<String>{
            'Billing__r.Line_Count__c',
            'Billing__r.Customer__c',
            'Billing__r.Status__c',
            'Billing__r.Ledger__c',
            'Billing__r.Ledger__r.Accounting_Method__c',
            'Billing__r.Ledger__r.Tax_Settings__r.Tax_Settings_Method__c',
            'Billing__r.Proprietary_Billing_Number__c',
            'Billing__r.Name',
            'Billing__r.Type__c',
            'Billing__r.Date__c',
            'Billing__r.Accounting_Period__c',
            'Project_Task__r.Project__c',
            'Project_Task__r.GL_Account_Variable_1__c',
            'Project_Task__r.GL_Account_Variable_2__c',
            'Project_Task__r.GL_Account_Variable_3__c',
            'Project_Task__r.GL_Account_Variable_4__c',
            'Product__r.Inventory_Product__c',
            'Product__r.Inventory_Type__c',
            'Product__r.Unit_Cost__c',
            'Product__r.GL_Account_Variable_1__c',
            'Product__r.GL_Account_Variable_2__c',
            'Product__r.GL_Account_Variable_3__c',
            'Product__r.GL_Account_Variable_4__c',
            'Product__r.Expense_GL_Account__c',
            'Product__r.Inventory_GL_Account__c',
            'Product__r.ProductCode',
            'Product__r.Tax_Code__c',
            'Product__r.Name',
            'Product__r.Description',
            'Opportunity_Product_Id__c',
            'Line_Destination_Address_Override__r.City__c',
            'Line_Destination_Address_Override__r.Country_Code__c',
            'Line_Destination_Address_Override__r.Postal_Code__c',
            'Line_Destination_Address_Override__r.State_Province__c',
            'Line_Destination_Address_Override__r.Street__c',
            'Line_Origin_Address_Override__r.City__c',
            'Line_Origin_Address_Override__r.Country_Code__c',
            'Line_Origin_Address_Override__r.Postal_Code__c',
            'Line_Origin_Address_Override__r.State_Province__c',
            'Line_Origin_Address_Override__r.Street__c',
            'Billing__r.Shipping_Street__c',
            'Billing__r.Shipping_City__c',
            'Billing__r.Shipping_State__c',
            'Billing__r.Shipping_PostalCode__c',
            'Billing__r.Shipping_Country__c',
            'Billing__r.Destination_Address_Override__c',
            'Billing__r.Destination_Address_Override__r.Street__c',
            'Billing__r.Destination_Address_Override__r.City__c',
            'Billing__r.Destination_Address_Override__r.State_Province__c',
            'Billing__r.Destination_Address_Override__r.Postal_Code__c',
            'Billing__r.Destination_Address_Override__r.Country_Code__c'
        };
    }

    public override List<String> getAdditionalCondition() {
        return AccountingSettingsHandler.isLineLevelPost() && this.context == SourceDocumentBatchOptions.ExecutionContext.POST
                ? new List<String>{
                        String.format(' ({0} OR {1}) ', new List<String>{
                                'Billing__r.Ledger__r.Tax_Settings__r.Tax_Settings_Method__c = \'' + TaxSettingsActions.NATIVE_TAX_METHOD + '\'',
                                'Tax_Line__c = false'
                        })
                }
                : new List<String>();
    }

}