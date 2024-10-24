trigger AcctSeedAddress on AcctSeed__Address__c (after update) {
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        AddressActions.apAutomationPostMessage(Trigger.new, Trigger.oldMap);
    }
}