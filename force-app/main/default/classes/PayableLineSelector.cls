public with sharing class PayableLineSelector extends SelectorAbstract {

    public PayableLineSelector() {
        super(Account_Payable_Line__c.getSObjectType());
        this.postingStatusField =  'Account_Payable__r.Status__c';
    }

    public override List<Schema.SObjectField> getFields() {
        return new List<Schema.SObjectField>{
                Account_Payable_Line__c.Id,
                Account_Payable_Line__c.Name,
                Account_Payable_Line__c.Account_Payable__c,
                Account_Payable_Line__c.Project__c,
                Account_Payable_Line__c.Project_Task__c,
                Account_Payable_Line__c.Product__c,
                Account_Payable_Line__c.Ledger__c,
                Account_Payable_Line__c.Expense_GL_Account__c,
                Account_Payable_Line__c.Unit_Cost__c,
                Account_Payable_Line__c.Sub_Total__c,
                Account_Payable_Line__c.Date__c,
                Account_Payable_Line__c.Tax_Line__c,
                Account_Payable_Line__c.Quantity__c,
                Account_Payable_Line__c.GL_Account_Variable_1__c,
                Account_Payable_Line__c.GL_Account_Variable_2__c,
                Account_Payable_Line__c.GL_Account_Variable_3__c,
                Account_Payable_Line__c.GL_Account_Variable_4__c,
                Account_Payable_Line__c.Tax_Group__c,
                Account_Payable_Line__c.Tax_Amount__c,
                Account_Payable_Line__c.Invoice_Comment__c,
                Account_Payable_Line__c.Internal_Comment__c,
                Account_Payable_Line__c.Amount__c,
                Account_Payable_Line__c.Tax_Inclusive__c,
                Account_Payable_Line__c.Combined_Tax_Rate__c
        };
    }

    public override List<String> getAdditionalFieldPaths() {
        return new List<String>{
                'Account_Payable__r.Line_Count__c',
                'Account_Payable__r.Vendor__c',
                'Account_Payable__r.Employee__c',
                'Account_Payable__r.Contact__c',
                'Account_Payable__r.Status__c',
                'Account_Payable__r.Ledger__c',
                'Account_Payable__r.Ledger__r.Accounting_Method__c',
                'Account_Payable__r.Payee_Reference__c',
                'Account_Payable__r.Name',
                'Account_Payable__r.Type__c',
                'Account_Payable__r.Date__c',
                'Account_Payable__r.Accounting_Period__c',
                'Account_Payable__r.Reverse_Charge__c',
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
                'Tax_Group__r.External_Id2__c'
        };
    }
}