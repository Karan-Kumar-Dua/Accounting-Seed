public with sharing class TriggerObserver {

    private static final String OBSERVATION_ERROR =
        Label.ERR_OBSERVATION;

    private static final Map<SObjectType, Set<SObjectField>> OBSERVED_FIELDS_MAP = new Map<SObjectType, Set<SObjectField>> {
        Billing__c.getSObjectType() => new Set<SObjectField> {
            Billing__c.Credit_Memo_Applied_Amount__c,
            Billing__c.Ledger__c,
            Billing__c.Closed_Accounting_Period__c
        },
        Account_Payable__c.getSObjectType() => new Set<SObjectField> {
            Account_Payable__c.Credit_Memo_Applied_Amount__c,
            Account_Payable__c.Payment_Status__c,
            Account_Payable__c.Ledger__c,
            Account_Payable__c.Closed_Accounting_Period__c
        },
        Journal_Entry__c.getSObjectType() => new Set<SObjectField> {
            Journal_Entry__c.Ledger__c
        },
        Cash_Receipt__c.getSObjectType() => new Set<SObjectField> {
            Cash_Receipt__c.Ledger__c,
            Cash_Receipt__c.Credit_GL_Account__c
        },
        Cash_Disbursement__c.getSObjectType() => new Set<SObjectField> {
            Cash_Disbursement__c.Ledger__c
        },
        Time_Card__c.getSObjectType() => new Set<SObjectField> {
            Time_Card__c.Ledger__c
        },
        Scheduled_Revenue_Expense__c.getSObjectType() => new Set<SObjectField> {
            Scheduled_Revenue_Expense__c.Ledger__c
        },
        AP_Disbursement__c.getSObjectType() => new Set<SObjectField> {
            AP_Disbursement__c.Status__c
        },
        Billing_Cash_Receipt__c.getSObjectType() => new Set<SObjectField> {
            Billing_Cash_Receipt__c.Status__c
        },
        Account_Payable_Line__c.getSObjectType() => new Set<SObjectField> {
            Account_Payable_Line__c.Unit_Cost__c,
            Account_Payable_Line__c.Amount__c,
            Account_Payable_Line__c.Quantity__c
        },
        Recurring_Account_Payable_Line__c.getSObjectType() => new Set<SObjectField> {
            Recurring_Account_Payable_Line__c.Unit_Cost__c,
            Recurring_Account_Payable_Line__c.Amount2__c,
            Recurring_Account_Payable_Line__c.Quantity__c
        },
        Payment_Processor__c.getSObjectType() => new Set<SObjectField> {
            Payment_Processor__c.External_Key__c
        }
    };

    private static final Map<SObjectType, Set<SObjectField>> OVERRIDE_OBSERVED_FIELDS_MAP = new Map<SObjectType, Set<SObjectField>> {
        Cash_Disbursement__c.getSObjectType() => new Set<SObjectField> {
            Cash_Disbursement__c.Debit_GL_Account__c
        }
    };

    private static TriggerObserver instance;

    public static Boolean bypassDeleteApDisbursement = false;

    private Set<Schema.SObjectField> unlockedFields;
    private Map<Id, List<ObservedFieldWrapper>> observedScope;

    public class SObjectFieldUpdateObserverException extends Exception {}

    private TriggerObserver() {
        this.unlockedFields = new Set<Schema.SObjectField>();
        this.observedScope = new Map<Id, List<ObservedFieldWrapper>>();
    }

    public static TriggerObserver getInstance() {
        if (instance == NULL) {
            instance = new TriggerObserver();
        }
        return instance;
    }

    public void unlockField(Schema.SObjectField fieldToUnlock) {
        unlockFields(new Set<Schema.SObjectField>{fieldToUnlock});
    }

    public void unlockFields(Set<Schema.SObjectField> fieldsToUnlock) {
        unlockedFields.addAll(fieldsToUnlock);
    }

    public Boolean isUnlockedField(Schema.SObjectField fieldResult) {
        return unlockedFields.contains(fieldResult);
    }

    public void watch(List<SObject> records) {
        SObjectType sType = records[0].getSObjectType();
        Set<SObjectField> observedFields = getObservedFieldsBySObjectType(sType);

        for (SObject record : records) {
            for (SObjectField observedField : observedFields) {
                addToObservedScope(
                    record.Id,
                    new ObservedFieldWrapper(observedField, record.get(observedField))
                );
            }
        }
    }

    private Set<SObjectField> getObservedFieldsBySObjectType(SObjectType sType) {
        Set<SObjectField> result;
        result = OBSERVED_FIELDS_MAP.get(sType);

        if (Trigger.isExecuting && Trigger.isInsert && OVERRIDE_OBSERVED_FIELDS_MAP.containsKey(sType)) {
            result = OVERRIDE_OBSERVED_FIELDS_MAP.get(sType);
        }
        return result;
    }

    public void addToObservedScope(Id recordId, ObservedFieldWrapper ofw) {
        if (observedScope.containsKey(recordId)) {
            observedScope.get(recordId).add(ofw);
        }
        else {
            observedScope.put(recordId, new List<ObservedFieldWrapper>{ofw});
        }
    }

    public void validateObservedContent(List<SObject> records) {
        for (SObject record : records) {
            if (observedScope.containsKey(record.Id)) {
                for (ObservedFieldWrapper expectedResult : observedScope.get(record.Id)) {
                    Object newFieldValue = record.get(expectedResult.field);
                    if (newFieldValue != expectedResult.value) {
                        throw new SObjectFieldUpdateObserverException(
                            String.format(OBSERVATION_ERROR, new List<Object>{expectedResult.value, newFieldValue})
                        );
                    }
                }
            }
        }

        //clear observation targets map to avoid comparison of values set in separate trigger executions during single transactions
        observedScope.clear();
    }

    public static void reset() {
        instance = NULL;
    }

    public static void purgeUnlockedFields(Set<Schema.SObjectField> aUnlockedFields) {
        TriggerObserver.getInstance().unlockedFields.removeAll(aUnlockedFields);
    }

    public static void purgeUnlockedFields(Schema.SObjectField aUnlockedField) {
        TriggerObserver.getInstance().unlockedFields.remove(aUnlockedField);
    }

    private with sharing class ObservedFieldWrapper {
        private SObjectField field;
        private Object value;

        private ObservedFieldWrapper(SObjectField field, Object value) {
            this.field = field;
            this.value = value;
        }
    }

}