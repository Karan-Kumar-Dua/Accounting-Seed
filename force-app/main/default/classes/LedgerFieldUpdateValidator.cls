public with sharing class LedgerFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {
    public static Set<SObjectField> lockedUpdateFieldsNormalLedger = new Set<SObjectField>{
            Ledger__c.Accounting_Method__c,
            Ledger__c.Related_Ledger__c,
            Ledger__c.Active__c,
            Ledger__c.Accounting_Method_Last_Modified_Date__c
    };
    public static Set<SObjectField> lockedUpdateFieldsL {
        get {
            lockedUpdateFieldsL = new Set<SObjectField> {
                    Ledger__c.Accounting_Method__c,
                    Ledger__c.Billing_Activity_Statement_Format__c,
                    Ledger__c.Billing_Outstanding_Statement_Format__c,
                    Ledger__c.Consolidation_Ledger_ID__c,
                    Ledger__c.Default_Bank_Account__c,
                    Ledger__c.Default_Billing_Format__c,
                    Ledger__c.Default_Packing_Slip_Format__c,
                    Ledger__c.Default_Purchase_Order_Format__c,
                    Ledger__c.Enable_Pre_Tax_Discount_Calculation__c,
                    Ledger__c.Financial_Reporter_Settings__c,
                    Ledger__c.Related_Ledger__c,
                    Ledger__c.Type__c,
                    Ledger__c.Active__c,
                    Ledger__c.Accounting_Method_Last_Modified_Date__c
            };

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                lockedUpdateFieldsL.add(Schema.SObjectType.Ledger__c.fields.getMap().get('CurrencyIsoCode'));
            }
            return lockedUpdateFieldsL;
        }
        private set;
    }

    public LedgerFieldUpdateValidator() {
        lockedUpdateFields = lockedUpdateFieldsL;
        customValidationErrorMsg = Label.ERR_ACCOUNTING_METHOD_CHANGE_FROM_CASH_TO_ACCRUAL;
    }

    public override void setValidationRules() {
        preventUpdateAction();
        preventUpdateCustomAction();
    }

    public override Boolean skipLegacyRecordValidation(SObjectField field) {
        Boolean isShadowLedgerAndNotEL = String.isNotBlank((String)oldObj.get(Ledger__c.Related_Ledger__c))
                && LedgerHandler.isShadowLedger((Ledger__c)oldObj)
                && !LedgerHandler.isEliminationLedger((String)oldObj.get(Ledger__c.Type__c));
        Boolean isSkip = !(lockedUpdateFieldsNormalLedger.contains(field) || isShadowLedgerAndNotEL);

        if (!isSkip && lockedUpdateFieldsWrapper != null) {
            if (isShadowLedgerAndNotEL) {
                lockedUpdateFieldsWrapper.fields = lockedUpdateFieldsL;
            } else {
                lockedUpdateFieldsWrapper.fields = lockedUpdateFieldsNormalLedger;
            }
        }

        if (field == Ledger__c.Accounting_Method__c && !CONSOLIDATIONS_ELIMINATIONS_TYPES.contains((String)newObj.get(Ledger__c.Type__c))) {
            // allow Accounting Method field population for legacy items.
            if (!isSkip && field == Ledger__c.Accounting_Method__c && isFirstFieldChanges(field)) {
                isSkip = true;
            }

            if (!isSkip && (changedFromAccrualToAccrualCash() || changedFromAccrualToCash())) {
                isSkip = true;
            }
        }

        if (field == Ledger__c.Accounting_Method__c
                && CONSOLIDATIONS_ELIMINATIONS_TYPES.contains((String)newObj.get(Ledger__c.Type__c))
                && newObj.get(Ledger__c.Accounting_Method__c) != oldObj.get(Ledger__c.Accounting_Method__c)) {
            isSkip = true;
        }

        return isSkip;
    }

    private Boolean changedFromAccrualToAccrualCash() {
        return LedgerActions.isAccrualAccountingMethod(oldObj) && LedgerActions.isAccrualAndCashAccountingMethod(newObj);
    }

    private Boolean changedFromAccrualToCash() {
        return LedgerActions.isCashAccountingMethod(newObj) && LedgerActions.isAccrualAccountingMethod(oldObj);
    }



    public override Boolean customValidationRules() {
        return oldObj.get(Ledger__c.Accounting_Method__c) == LedgerActions.ACCOUNTING_METHOD_CASH
            && newObj.get(Ledger__c.Accounting_Method__c) == LedgerActions.ACCOUNTING_METHOD_ACCRUAL ;
    }

    public static final Set<String> CONSOLIDATIONS_TYPES = new Set<String>{
            LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
            LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET
    };

    public static final Set<String> ELIMINATIONS_TYPES = new Set<String>{
            LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL,
            LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
    };

    public static final Set<String> CONSOLIDATIONS_ELIMINATIONS_TYPES = new Set<String>{
            LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL,
            LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET,
            LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL,
            LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
    };
}