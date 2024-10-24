trigger TaxSettings on Tax_Settings__c (after insert, after update) {
    switch on Trigger.operationType {
        when AFTER_INSERT {
            TaxSettingsActions.requireFields(Trigger.new);
        }
        when AFTER_UPDATE {
            TaxSettingsActions.requireFields(Trigger.new);
        }
    }
}