public with sharing class LedgerHierarchyFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {
    public Set<SObjectField> lockedUpdateFieldsLH {
        get {
            lockedUpdateFieldsLH = new Set<SObjectField> {
                    Ledger_Hierarchy__c.Last_Period__c,
                    Ledger_Hierarchy__c.Last_Run__c,
                    Ledger_Hierarchy__c.Generated_By__c,
                    Ledger_Hierarchy__c.Parent_Ledger_Hierarchy__c,
                    Ledger_Hierarchy__c.Root_Node_ID__c,
                    Ledger_Hierarchy__c.Ledger__c,
                    Ledger_Hierarchy__c.Hierarchy_Type__c,
                    Ledger_Hierarchy__c.Hierarchy_Status__c,
                    Ledger_Hierarchy__c.Sort_Order__c,
                    Ledger_Hierarchy__c.Last_Period_Run__c
            };

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsLH.add(Schema.SObjectType.Ledger_Hierarchy__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsLH;
        }
        private set;
    }

    public LedgerHierarchyFieldUpdateValidator() {
        lockedUpdateFields = lockedUpdateFieldsLH;
    }

    public override void setValidationRules() {
        preventUpdateAction();
    }

    public override Boolean skipLegacyRecordValidation(SObjectField field) {
        Boolean result = false;
        // allow Hierarchy Status field set from In Progress to Blank.
        if (field == Ledger_Hierarchy__c.Hierarchy_Status__c
            && oldObj.get(field) == LedgerHierarchyActions.LEDGER_HIERARCHY_STATUS_IN_PROGRESS
            && String.isBlank((String) newObj.get(field))) {
            result = true;
        }
        return result;
    }
}