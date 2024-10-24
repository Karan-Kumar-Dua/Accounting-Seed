trigger AcctSeedContact on Contact (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        AcctSeedContactActions.apAutomationPostMessage(Trigger.newMap,null);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        AcctSeedContactActions.apAutomationPostMessage(Trigger.newMap,Trigger.oldMap);
    }
}