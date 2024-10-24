public with sharing class JournalEntryLineSelector extends SelectorAbstract {

    public JournalEntryLineSelector(){
        super(Journal_Entry_Line__c.getSObjectType());
        this.postingStatusField =  'Journal_Entry__r.Status__c';
    }

    public override List<Schema.SObjectField> getFields(){
        return new List<Schema.SObjectField>{
            Journal_Entry_Line__c.Id,
            Journal_Entry_Line__c.Name,
            Journal_Entry_Line__c.Reference__c,
            Journal_Entry_Line__c.Project__c,
            Journal_Entry_Line__c.Project_Task__c,
            Journal_Entry_Line__c.Product__c,
            Journal_Entry_Line__c.Journal_Entry__c,
            Journal_Entry_Line__c.Credit__c,
            Journal_Entry_Line__c.Employee__c,
            Journal_Entry_Line__c.Debit__c,
            Journal_Entry_Line__c.Units__c,
            Journal_Entry_Line__c.GL_Account__c,
            Journal_Entry_Line__c.Date__c,
            Journal_Entry_Line__c.Cash_Flow_Category__c,
            Journal_Entry_Line__c.Bank_Reconciliation__c,
            Journal_Entry_Line__c.Bank_Deposit__c,
            Journal_Entry_Line__c.Account__c,
            Journal_Entry_Line__c.Contact__c,
            Journal_Entry_Line__c.Ledger__c,
            Journal_Entry_Line__c.GL_Account_Variable_1__c,
            Journal_Entry_Line__c.GL_Account_Variable_2__c,
            Journal_Entry_Line__c.GL_Account_Variable_3__c,
            Journal_Entry_Line__c.GL_Account_Variable_4__c,
            Journal_Entry_Line__c.Time_Card_Variable_1__c,
            Journal_Entry_Line__c.Time_Card_Variable_2__c
        };
    }

    public override List<String> getAdditionalFieldPaths() {
        return new List<String>{
            'Journal_Entry__r.Line_Count__c',
            'Journal_Entry__r.Status__c',
            'Journal_Entry__r.Ledger__c',
            'Journal_Entry__r.Ledger__r.Accounting_Method__c',
            'Journal_Entry__r.Name',
            'Journal_Entry__r.Total_Credits__c',
            'Journal_Entry__r.Total_Debits__c',
            'Journal_Entry__r.Accrual_and_or_Cash__c',
            'GL_Account__r.Bank__c',
            'Journal_Entry__r.Accounting_Period__c',
            'Journal_Entry__r.Journal_Date__c',
            'GL_Account__r.Bank__c',
            'Bank_Deposit__r.Name',
            'Bank_Reconciliation__r.Name'
        };
    }

}