trigger ImportField on Import_Field__c (before insert) {
    ImportFieldActions.handleBeforeInsert(Trigger.new);
}