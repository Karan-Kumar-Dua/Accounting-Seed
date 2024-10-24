trigger LedgerHierarchy on Ledger_Hierarchy__c (before insert, before update, before delete, after insert, after update, after delete) {
    switch on Trigger.operationType {

        when BEFORE_INSERT {
            LedgerHierarchyActions.initialValidation(Trigger.new);
            LedgerHierarchyActions.setDefaultSortOrder(Trigger.new);
        }
        when AFTER_INSERT {
            LedgerHierarchyActions.createEliminationHierarchy(Trigger.new);
        }

        when BEFORE_UPDATE {
            SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
            LedgerHierarchyActions.checkConsolidationRoutine(Trigger.new);
            LedgerHierarchyActions.updateValidation(Trigger.new);
        }

        when BEFORE_DELETE {
            LedgerHierarchyActions.checkConsolidationRoutine(Trigger.old);
            LedgerHierarchyActions.checkClosedConsolidationFinancialCube(Trigger.old);
            LedgerHierarchyActions.checkCLedgerWithChildren(Trigger.oldMap);
            LedgerHierarchyActions.prepareRecords4Remove(Trigger.oldMap);
        }
        when AFTER_DELETE {
            LedgerHierarchyActions.removeEliminationHierarchy(Trigger.oldMap);
        }
    }
}