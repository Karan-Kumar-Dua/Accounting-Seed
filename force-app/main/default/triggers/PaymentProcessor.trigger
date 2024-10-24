trigger PaymentProcessor on Payment_Processor__c (after insert, after update,before insert, before update,after delete) {
    switch on Trigger.operationType {
        when AFTER_INSERT {
            PaymentProcessorActions.validateFeeSetup(Trigger.new);
            PaymentProcessorActions.validateLedgerAndActiveField(Trigger.new);
            PaymentProcessorActions.validateDefaultPaymentProcessors(Trigger.new);
            TriggerObserver.getInstance().validateObservedContent(Trigger.new);
        }
        when AFTER_UPDATE {
            SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
            PaymentProcessorActions.validateFeeSetup(Trigger.new);
            PaymentProcessorActions.validateTestMode(Trigger.new, Trigger.oldMap);
            PaymentProcessorActions.validateFeeMapping(Trigger.new, Trigger.oldMap);
            PaymentProcessorActions.validateLedgerAndActiveField(Trigger.new);
            PaymentProcessorActions.validateDefaultPaymentProcessors(Trigger.new);
            PaymentProcessorActions.validateLedgerField(Trigger.new);
        } 
        when BEFORE_INSERT {
            PaymentProcessorActions.preventInsertWhenExternalKeyNotEmpty(Trigger.new);
            PaymentProcessorActions.defaultExternalKey(Trigger.new);
            PaymentProcessorActions.validateLedgerAndActiveField(Trigger.new);
            PaymentProcessorActions.validateLedgerField(Trigger.new);
            PaymentProcessorActions.validateGLAccounts(Trigger.new);
            TriggerObserver.getInstance().watch(Trigger.new);
            SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, PaymentProcessorActions.CURRENCY_AND_NUMBER_FIELDS);

        }
        when BEFORE_UPDATE {
            SourceDocumentUpdateFieldValidator.validate(Trigger.oldMap, Trigger.newMap);
            PaymentProcessorActions.validateLedgerAndActiveField(Trigger.new);
            PaymentProcessorActions.validateGLAccounts(Trigger.new);
            SObjectActions.normalizeNumericAndCurrencyFields(Trigger.new, PaymentProcessorActions.CURRENCY_AND_NUMBER_FIELDS);

        }
        when AFTER_DELETE{
            PaymentProcessorActions.deleteRelatedKeys(Trigger.old);
        }
    }
}