public with sharing class SObjectSelectorFactory {
    
    public with sharing class InvalidTypeException extends Exception {}

    public static void require(SObjectType T) {
        if (T == null) {
            throw new InvalidTypeException(String.format(Label.ERR_SELECTOR_UNSUPPORTED_SOBJECT_TYPE, new List<String>{'null'}));
        }
    }

    public static InvalidTypeException getUnsupportedTypeException(SObjectType T) {
        return new InvalidTypeException(String.format(Label.ERR_SELECTOR_UNSUPPORTED_SOBJECT_TYPE, new List<String>{T.getDescribe().getName()}));
    }

    public static SObjectSelector getSelector(SObjectType T, System.AccessLevel accessLevel, SObjectSelector.SharingMode sharingType) {
        require(T);
        switch on T.newSObject() {
            when Billing__c b {
                return new BillingSelector(accessLevel, sharingType);
            }
            when Product2 p {
                return new ProductSelector(accessLevel, sharingType);
            }
            when Recurring_Billing_Line__c rbl {
                return new RecurringBillingLineSelector(accessLevel, sharingType);
            }
            when Recurring_Account_Payable_Line__c rapl {
                return new RecurringAccountPayableLineSelector(accessLevel, sharingType);
            }
            when Recurring_Journal_Entry_Line__c rjel {
                return new RecurringJournalEntryLineSelector(accessLevel, sharingType);
            }
            when Transaction_Group__c tg {
                return new TransactionGroupSelector(accessLevel, sharingType);
            }
            when Journal_Entry__c je{
                return new JournalEntrySelector(accessLevel, sharingType);
            }
            when Account_Payable__c ap{
                return new AccountPayableSelector(accessLevel, sharingType);
            }
            when else {
                throw getUnsupportedTypeException(T);
            }
        }
    }

    public static RecurringLineSelector getRecurringLineSelector(SObjectType T, System.AccessLevel accessLevel, SObjectSelector.SharingMode sharingType) {
        require(T);
        switch on T.newSObject() {
            when Recurring_Billing_Line__c rbl {
                return new RecurringBillingLineSelector(accessLevel, sharingType);
            }
            when Recurring_Account_Payable_Line__c rapl {
                return new RecurringAccountPayableLineSelector(accessLevel, sharingType);
            }
            when Recurring_Journal_Entry_Line__c rjel {
                return new RecurringJournalEntryLineSelector(accessLevel, sharingType);
            }
            when else {
                throw getUnsupportedTypeException(T);
            }
        }
    }

}