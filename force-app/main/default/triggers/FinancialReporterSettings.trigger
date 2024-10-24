trigger FinancialReporterSettings on Financial_Reporter_Settings__c (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        FinancialReporterSettingsActions.preventInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        FinancialReporterSettingsActions.preventUpdate(Trigger.new);
    }

}