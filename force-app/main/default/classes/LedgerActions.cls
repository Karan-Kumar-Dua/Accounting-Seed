public with sharing class LedgerActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    public static final String TYPE_CHANGE_FC_OR_LH_EXISTS_ERROR =
        Label.ERR_TYPE_CHANGE_FC_OR_LH_EXISTS;
    public static final String TYPE_CHANGE_TO_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR =
        Label.ERR_TYPE_CHANGE_TO_CONSOLIDATIONS_OR_ELIMINATIONS;
    public static final String TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR =
        Label.ERR_TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS;
    public static final String CURRENCY_CHANGE_ERROR = Label.ERR_CURRENCY_CHANGE;
    public static final String MAX_QUANTITY_ERROR = Label.ERR_MAX_QUANTITY;
    public static final String DELETE_ERROR = Label.ERR_DELETE_LEDGER;
    public static final String ELIMINATIONS_DELETE_ERROR = Label.ERR_ELIMINATIONS_DELETE;
    public static final String MANUAL_ELIMINATION_ERROR = Label.ERR_MANUAL_ELIMINATION;
    public static final String COMPANY_CODE_ERROR = Label.ERR_COMPANY_CODE;

    public static final String LEDGER_TYPE_TRANSACTIONAL = 'Transactional';
    public static final String LEDGER_TYPE_BUDGET = 'Budget';
    public static final String LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL = 'Consolidations-Transactional';
    public static final String LEDGER_TYPE_CONSOLIDATIONS_BUDGET = 'Consolidations-Budget';
    public static final String LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL = 'Eliminations-Transactional';
    public static final String LEDGER_TYPE_ELIMINATIONS_BUDGET = 'Eliminations-Budget';
    public static final String ELIMINATIONS_LEDGER_RELATED_OBJECT = 'Journal_Entry__c';

    public static final String ACCOUNTING_METHOD_ACCRUAL_CASH = 'Accrual and Cash';
    public static final String ACCOUNTING_METHOD_CASH = 'Cash';
    public static final String ACCOUNTING_METHOD_ACCRUAL = 'Accrual';
    public static final String ACCOUNTING_METHOD_CHANGE_ON_SHADOW_LEDGER_ERROR = Label.ERR_ACCOUNTING_METHOD_CHANGE_ON_SHADOW_LEDGER;
    public static final String ACCOUNTING_METHOD_CHANGE_FROM_CASH_TO_ACCRUAL_ERROR = Label.ERR_ACCOUNTING_METHOD_CHANGE_FROM_CASH_TO_ACCRUAL;
    public static final String ACCOUNTING_METHOD_CHANGE_FROM_ACCRUAL_TO_CASH_ERROR = Label.ERR_ACCOUNTING_METHOD_CHANGE_FROM_ACCRUAL_TO_CASH;

    public static final Set<String> ACCRUAL_OR_CASH = new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL, LedgerActions.ACCOUNTING_METHOD_CASH};

    public static final String SHADOW_POSTFIX = ' (Cash)';
    public static final Integer NAME_FIELD_LENGTH = 80;

    public static Boolean isPreventUpdateOverride = false;
    private static Boolean isSystemEliminationLedger = false;

    public static Set<Id> skipTriggerLedgerIds = new Set<Id>();

    public static List<String> relatedObjectForDeleteValidation {
        get {
            relatedObjectForDeleteValidation = new List<String> {
                PACKAGE_QUALIFIER + 'Account_Payable__c',
                PACKAGE_QUALIFIER + 'Billing__c',
                PACKAGE_QUALIFIER + 'Cash_Receipt__c',
                PACKAGE_QUALIFIER + 'Cash_Disbursement__c',
                PACKAGE_QUALIFIER + 'Journal_Entry__c',
                PACKAGE_QUALIFIER + 'Time_Card__c',
                PACKAGE_QUALIFIER + 'Expense_Report__c',
                PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c',
                PACKAGE_QUALIFIER + 'Financial_Cube__c',
                PACKAGE_QUALIFIER + 'Ledger_Hierarchy__c'
            };
            if (AccountingSettingsHandler.isERPEnabled()) {
                relatedObjectForDeleteValidation.add(ERP_PACKAGE_QUALIFIER + 'Sales_Order__c');
                relatedObjectForDeleteValidation.add(ERP_PACKAGE_QUALIFIER + 'Purchase_Order__c');
            }
                
            return relatedObjectForDeleteValidation;
        }
        private set;
    }

    public static void resetRelatedLedger(List<Ledger__c> ledgers) {
        for (Ledger__c ledger : ledgers) {
            if (!ledger.Is_Shadow__c) {
                ledger.Related_Ledger__c = null;
            }
        }
    }

    public static void presetAccountingMethodLastModifiedDate(List<Ledger__c> ledgers, Map<Id, Ledger__c> oldLedgersByIds) {
        for (Ledger__c ledger : ledgers) {
            if ((oldLedgersByIds == null && String.isNotBlank(ledger.Accounting_Method__c))
                    || (oldLedgersByIds != null && ledger.Accounting_Method__c != oldLedgersByIds.get(ledger.Id).Accounting_Method__c)) {
                ledger.Accounting_Method_Last_Modified_Date__c = Datetime.now();
            }
        }
    }

    public static void updateEliminationLedgers(Map<Id, Ledger__c> ledgersByIds, Map<Id, Ledger__c> oldLedgersByIds) {
        Set<Id> consolidationLedgerIds = new Set<Id>();
        for (Ledger__c ledger : ledgersByIds.values()) {
            String oldAccountingMethod = oldLedgersByIds.get(ledger.Id).Accounting_Method__c;
            if (LedgerFieldUpdateValidator.CONSOLIDATIONS_TYPES.contains(ledger.Type__c)
                    && ACCRUAL_OR_CASH.contains(oldAccountingMethod)
                    && ACCRUAL_OR_CASH.contains(ledger.Accounting_Method__c)
                    && oldAccountingMethod != ledger.Accounting_Method__c) {
                consolidationLedgerIds.add(ledger.Id);
            }
        }

        if (!consolidationLedgerIds.isEmpty()) {
            String ledgerField = PACKAGE_QUALIFIER + 'Parent_Ledger_Hierarchy__r.' + PACKAGE_QUALIFIER + 'Ledger__c';
            List<String> conditions = new List<String>{
                    ledgerField + ' =: arg0',
                    PACKAGE_QUALIFIER + 'Ledger__r.' + PACKAGE_QUALIFIER + 'Type__c !=: arg1'
            };
            List<AggregateResult> consolidationsWithChildrens = DomainUtils.recordsByConditions(
                    Ledger_Hierarchy__c.SObjectType,
                    new List<String>{'Count(Id) c0unt', ledgerField + ' refToParent'},
                    String.join(conditions, ' AND ') + ' GROUP BY ' + ledgerField,
                    new List<Object>{
                            consolidationLedgerIds,
                            new Set<String>{LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL, LEDGER_TYPE_ELIMINATIONS_BUDGET}
                    }
            );
            for (AggregateResult result : consolidationsWithChildrens) {
                Id ledgerId = (Id)result.get('refToParent');
                ledgersByIds.get(ledgerId).addError(Label.ERR_CANNOT_CHANGE_ACCOUNTING_METHOD_LEDGER_HIERARCHY);
                consolidationLedgerIds.remove(ledgerId);
            }

            if (!consolidationLedgerIds.isEmpty()) {
                Map<Id, Ledger__c> eliminationLedgersByConsolidationIds = LedgerHandler.getInstanceWithoutSharing().eliminationLedgersByConsolidationIds(consolidationLedgerIds);
                Map<Id, Ledger__c> eliminationLedgersByIds = new Map<Id, Ledger__c>(eliminationLedgersByConsolidationIds.values());
                List<AggregateResult> eliminationsWithTransactions = DomainUtils.countLinesByParentIds(
                        String.valueOf(Transaction__c.getSObjectType()),
                        String.valueOf(Transaction__c.Ledger__c),
                        eliminationLedgersByIds.keySet()
                );
                for (AggregateResult result : eliminationsWithTransactions) {
                    Id eliminationId = (Id)result.get('refToParent');
                    Id consolidationId = (Id)eliminationLedgersByIds.get(eliminationId).Consolidation_Ledger_ID__c;
                    ledgersByIds.get(consolidationId).addError(Label.ERR_CANNOT_CHANGE_ACCOUNTING_METHOD_POSTED_TRANSACTIONS);
                    consolidationLedgerIds.remove(consolidationId);
                }

                if (!consolidationLedgerIds.isEmpty()) {
                    List<Ledger__c> eliminationLedgers = new List<Ledger__c>();
                    for (Id consolidationId : consolidationLedgerIds) {
                        eliminationLedgers.add(new Ledger__c(
                                Id = eliminationLedgersByConsolidationIds.get(consolidationId).Id,
                                Accounting_Method__c = ledgersByIds.get(consolidationId).Accounting_Method__c
                        ));
                    }
                    if (!eliminationLedgers.isEmpty()) {
                        TriggerObserver.getInstance().unlockField(Ledger__c.Accounting_Method__c);
                        LedgerActions.isPreventUpdateOverride = true;
                        SFDCSecurityUtils.updateCheckCRUDAndFLS(eliminationLedgers, new List<String>());
                        TriggerObserver.purgeUnlockedFields(Ledger__c.Accounting_Method__c);
                    }
                }
            }
        }
    }

    public static void updateShadowLedgers(List<Ledger__c> ledgers, Map<Id, Ledger__c> oldLedgersByIds) {
        Set<SObjectField> fields = new Set<SObjectField>{
            Ledger__c.Name,
            Ledger__c.Billing_Activity_Statement_Format__c,
            Ledger__c.Billing_Outstanding_Statement_Format__c,
            Ledger__c.Consolidation_Ledger_ID__c,
            Ledger__c.Default_Bank_Account__c,
            Ledger__c.Default_Billing_Format__c,
            Ledger__c.Default_Packing_Slip_Format__c,
            Ledger__c.Default_Purchase_Order_Format__c,
            Ledger__c.Description__c,
            Ledger__c.Enable_Pre_Tax_Discount_Calculation__c,
            Ledger__c.Financial_Reporter_Settings__c,
            Ledger__c.Type__c
        };

        List<Ledger__c> shadowLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : ledgers) {
            if (!skipTriggerLedgerIds.contains(ledger.Id)
                    && ledger.Accounting_Method__c == ACCOUNTING_METHOD_ACCRUAL_CASH
                    && oldLedgersByIds.get(ledger.Id).Accounting_Method__c == ACCOUNTING_METHOD_ACCRUAL_CASH
                    && String.isNotBlank(ledger.Related_Ledger__c)) {
                skipTriggerLedgerIds.add(ledger.Related_Ledger__c);
                Ledger__c shadowLedger = new Ledger__c(Id = ledger.Related_Ledger__c);
                Boolean isChanged = false;
                for (SObjectField field : fields) {
                    if (ledger.get(field) != oldLedgersByIds.get(ledger.Id)?.get(field)) {
                        isChanged = true;
                        if (field == Ledger__c.Name) {
                            shadowLedger.put(field, ((String)ledger.get(field)).left(NAME_FIELD_LENGTH - SHADOW_POSTFIX.length()) + SHADOW_POSTFIX);
                        } else {
                            shadowLedger.put(field, ledger.get(field));
                        }
                    }
                }
                if (isChanged) {
                    shadowLedgers.add(shadowLedger);
                }
            }
            skipTriggerLedgerIds.add(ledger.Id);
        }
        if (!shadowLedgers.isEmpty()) {
            TriggerObserver.getInstance().unlockFields(fields);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(shadowLedgers, new List<String>());
            TriggerObserver.purgeUnlockedFields(fields);
        }
    }

    /*
    *  When a user attempts to change the ‘Accounting Method’ on a (shadow) cash ledger
    *  (in other words a Ledger where the “Related Ledger” field is not blank)
    *  from “Cash” to “Accrual” OR from “Cash” to “Accrual and Cash”, generate error message
    */
    public static void preventAccountingMethodChangeOnShadowLedger(List<Ledger__c> newLedgers, Map<Id, Ledger__c> oldLedgersMap) {
        if (!isPreventUpdateOverride) {
            for (Ledger__c newLedger : newLedgers) {
                Ledger__c oldLedger = oldLedgersMap.get(newLedger.Id);
                if (String.isNotBlank(newLedger.Related_Ledger__c)
                        && newLedger.Accounting_Method__c != oldLedger.Accounting_Method__c
                        && oldLedger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH
                        && (newLedger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL
                                || newLedger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH)) {

                    newLedger.addError(ACCOUNTING_METHOD_CHANGE_ON_SHADOW_LEDGER_ERROR);
                }
            }
        }
    }

    /*
    *  When the user changes the ‘Accounting Method’ picklist field on the ledger from “Cash” to “Accrual”,
    *  generate error message
    */
    public static void preventAccountingMethodChangeFromCashToAccrualOnLedger(List<Ledger__c> newLedgers, Map<Id, Ledger__c> oldLedgersMap) {
        if (!isPreventUpdateOverride) {
            for (Ledger__c newLedger : newLedgers) {
                Ledger__c oldLedger = oldLedgersMap.get(newLedger.Id);
                if (String.isBlank(newLedger.Related_Ledger__c)
                    && newLedger.Accounting_Method__c != oldLedger.Accounting_Method__c
                    && isCashAccountingMethod(oldLedger)
                    && isAccrualAccountingMethod(newLedger)
                    && !LedgerFieldUpdateValidator.CONSOLIDATIONS_ELIMINATIONS_TYPES.contains(newLedger.Type__c)) {

                    newLedger.addError(ACCOUNTING_METHOD_CHANGE_FROM_CASH_TO_ACCRUAL_ERROR);
                }
            }
        }
    }

    /*
    *  When a user attempts to change the ‘Accounting Method’ picklist field on the Ledger from “Accrual” to “Cash”,
    *  generate error message
    */
    public static void preventAccountingMethodChangeFromAccrualToCashOnLedger(List<Ledger__c> newLedgers, Map<Id, Ledger__c> oldLedgersMap) {
        if (!isPreventUpdateOverride) {
            for (Ledger__c newLedger : newLedgers) {
                Ledger__c oldLedger = oldLedgersMap.get(newLedger.Id);
                if (String.isBlank(newLedger.Related_Ledger__c)
                    && newLedger.Accounting_Method__c != oldLedger.Accounting_Method__c
                    && isAccrualAccountingMethod(oldLedger)
                    && isCashAccountingMethod(newLedger)
                    && !LedgerFieldUpdateValidator.CONSOLIDATIONS_ELIMINATIONS_TYPES.contains(newLedger.Type__c)) {

                    newLedger.addError(ACCOUNTING_METHOD_CHANGE_FROM_ACCRUAL_TO_CASH_ERROR);
                }
            }
        }
    }

    public static void createShadowLedgers(Map<Id, Ledger__c> ledgersByIds, Map<Id, Ledger__c> oldLedgersByIds) {
        List<Ledger__c> shadowLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : ledgersByIds.values()) {
            Ledger__c oldLedger = oldLedgersByIds != null ? oldLedgersByIds.get(ledger.Id) : null;
            if (!LedgerHandler.isEliminationLedger(ledger) &&
                ((ledger.Accounting_Method__c == ACCOUNTING_METHOD_ACCRUAL_CASH && oldLedger == null) ||
                    (oldLedger != null && oldLedger.Accounting_Method__c == ACCOUNTING_METHOD_ACCRUAL
                    && ledger.Accounting_Method__c == ACCOUNTING_METHOD_ACCRUAL_CASH))) {
                Ledger__c shadowLedger = new Ledger__c(
                        Name = ledger.Name.left(NAME_FIELD_LENGTH - SHADOW_POSTFIX.length()) + SHADOW_POSTFIX,
                        Active__c = ledger.Active__c,
                        Related_Ledger__c = ledger.Id,
                        Accounting_Method__c = ACCOUNTING_METHOD_CASH,
                        Billing_Activity_Statement_Format__c = ledger.Billing_Activity_Statement_Format__c,
                        Billing_Outstanding_Statement_Format__c = ledger.Billing_Outstanding_Statement_Format__c,
                        Consolidation_Ledger_ID__c = ledger.Consolidation_Ledger_ID__c,
                        Default_Bank_Account__c = ledger.Default_Bank_Account__c,
                        Default_Billing_Format__c = ledger.Default_Billing_Format__c,
                        Default_Packing_Slip_Format__c = ledger.Default_Packing_Slip_Format__c,
                        Default_Purchase_Order_Format__c = ledger.Default_Purchase_Order_Format__c,
                        Description__c = ledger.Description__c,
                        Enable_Pre_Tax_Discount_Calculation__c = ledger.Enable_Pre_Tax_Discount_Calculation__c,
                        Financial_Reporter_Settings__c = ledger.Financial_Reporter_Settings__c,
                        Type__c = ledger.Type__c
                );
                if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                    shadowLedger.put('CurrencyIsoCode', ledger.get('CurrencyIsoCode'));
                }
                shadowLedgers.add(shadowLedger);
            }
        }

        if (!shadowLedgers.isEmpty()) {
            List<Ledger__c> primaryLedgers = new List<Ledger__c>();
            List<Database.SaveResult> results = SFDCSecurityUtils.insertCheckCRUDAndFLS(shadowLedgers, new List<String>(), false);
            for (Integer index = 0; index < results.size(); index++) {
                Database.SaveResult result = results[index];
                Ledger__c shadowLedger = shadowLedgers[index];
                if (result.success) {
                    primaryLedgers.add(new Ledger__c(Id = shadowLedger.Related_Ledger__c, Related_Ledger__c = shadowLedger.Id));
                    skipTriggerLedgerIds.add(shadowLedger.Id);
                } else {
                    ledgersByIds.get(shadowLedger.Related_Ledger__c)?.addError(result.errors[0].message);
                }
            }

            if (!primaryLedgers.isEmpty()) {
                Set<SObjectField> unlockFields = new Set<SObjectField>{Ledger__c.Related_Ledger__c};
                TriggerObserver.getInstance().unlockFields(unlockFields);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(primaryLedgers, new List<String>(), false);
                TriggerObserver.purgeUnlockedFields(unlockFields);
            }
        }
    }

    public static void preventChangeTypeField(Map<Id, Ledger__c> oldLedgerMap, Map<Id, Ledger__c> newLedgerMap) {
        Set<Id> ledgerToValidateIdsSet = new Set<Id>();
        Set<Id> ledgersWithFCs = new Set<Id>();
        Set<Id> ledgersWithLedgerHierarchy = new Set<Id>();

        for (Ledger__c newLedger : newLedgerMap.values()) {
            Ledger__c oldLedger = oldLedgerMap.get(newLedger.Id);

            if (oldLedger.Type__c != newLedger.Type__c) {
                ledgerToValidateIdsSet.add(newLedger.Id);
            }
        }

        for (AggregateResult fc : DomainUtils.getMostRecentFinancialCubesByLedgerId(ledgerToValidateIdsSet)) {
            if (!ledgersWithFCs.contains((Id) fc.get(PACKAGE_QUALIFIER + 'Ledger__c'))) {
                ledgersWithFCs.add((Id) fc.get(PACKAGE_QUALIFIER + 'Ledger__c'));
            }
        }

        for (Ledger_Hierarchy__c lh : LedgerHierarchyHandler.getInstanceWithoutSharing().getHierarchiesByLedgerIds(ledgerToValidateIdsSet)) {
            ledgersWithLedgerHierarchy.add(lh.Ledger__c);
        }

        for (Ledger__c newLedger : newLedgerMap.values()) {
            Ledger__c oldLedger = oldLedgerMap.get(newLedger.Id);
            //Transactional → Budget
            if (oldLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL
                    && newLedger.Type__c == LEDGER_TYPE_BUDGET
                    && (ledgersWithFCs.contains(newLedger.Id) || ledgersWithLedgerHierarchy.contains(newLedger.Id))) {

                newLedger.addError(TYPE_CHANGE_FC_OR_LH_EXISTS_ERROR, false);
            }//Budget -> Transactional
            else if (oldLedger.Type__c == LEDGER_TYPE_BUDGET
                        && newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL
                        && (ledgersWithFCs.contains(newLedger.Id) || ledgersWithLedgerHierarchy.contains(newLedger.Id))) {

                newLedger.addError(TYPE_CHANGE_FC_OR_LH_EXISTS_ERROR, false);
            }//Transactional/Budget -> Consolidations/Eliminations
            else if ((oldLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL || oldLedger.Type__c == LEDGER_TYPE_BUDGET)
                        && (LedgerHandler.isConsolidationLedger(newLedger.Type__c) || LedgerHandler.isEliminationLedger(newLedger.Type__c))) {

                newLedger.addError(TYPE_CHANGE_TO_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, false);
            }//Consolidations/Eliminations -> Transactional/Budget
            else if ((LedgerHandler.isConsolidationLedger(oldLedger.Type__c) || LedgerHandler.isEliminationLedger(oldLedger.Type__c))
                        && ((newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL || newLedger.Type__c == LEDGER_TYPE_BUDGET))) {

                newLedger.addError(TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, false);
            }//Consolidations -> Eliminations
            else if (LedgerHandler.isConsolidationLedger(oldLedger.Type__c) && LedgerHandler.isEliminationLedger(newLedger.Type__c)) {
                newLedger.addError(TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, false);
            }//Eliminations -> Consolidations
            else if (LedgerHandler.isEliminationLedger(oldLedger.Type__c) && LedgerHandler.isConsolidationLedger(newLedger.Type__c)) {
                newLedger.addError(TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, false);
            }//Consolidations-Transactional -> Consolidations-Budget OR vice versa
            else if (((oldLedger.Type__c == LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL && newLedger.Type__c == LEDGER_TYPE_CONSOLIDATIONS_BUDGET)
                        || (oldLedger.Type__c == LEDGER_TYPE_CONSOLIDATIONS_BUDGET && newLedger.Type__c == LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL))) {

                newLedger.addError(TYPE_CHANGE_FROM_CONSOLIDATIONS_OR_ELIMINATIONS_ERROR, false);
            }
        }
    }

    public static void requireCompanyCode(List<Ledger__c> ledgers) {
        if (isPreventUpdateOverride) {
            return;
        }

        Set<Id> taxSettingIds = new Set<Id>();
        for (Ledger__c ledger : ledgers) {
            taxSettingIds.add(ledger.Tax_Settings__c);
        }
        Map<Id, Tax_Settings__c> taxSettingsByIds = new Map<Id, Tax_Settings__c>();
        if (!taxSettingIds.isEmpty()) {
            taxSettingsByIds.putAll([
                    SELECT Id
                    FROM Tax_Settings__c
                    WHERE Id = :taxSettingIds AND Tax_Settings_Method__c = :TaxSettingsActions.AVA_TAX_METHOD
            ]);
        }
        for (Ledger__c ledger : ledgers) {
            if (taxSettingsByIds.containsKey(ledger.Tax_Settings__c) && String.isBlank(ledger.Sales_Tax_Company_Code__c)) {
                ledger.Sales_Tax_Company_Code__c.addError(COMPANY_CODE_ERROR);
            }
        }
    }

    public static void requireTypeField(List<Ledger__c> newLedgers) {

        if (isPreventUpdateOverride) {
            return;
        }

        for (Ledger__c newLedger : newLedgers) {

            if (newLedger.Type__c == null) {
                newLedger.Type__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL && newLedger.Billing_Activity_Statement_Format__c == null) {
                newLedger.Billing_Activity_Statement_Format__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL && newLedger.Billing_Outstanding_Statement_Format__c == null) {
                newLedger.Billing_Outstanding_Statement_Format__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL && newLedger.Default_Bank_Account__c == null) {
                newLedger.Default_Bank_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL && newLedger.Default_Billing_Format__c == null) {
                newLedger.Default_Billing_Format__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (AccountingSettingsHandler.isERPEnabled() && newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL && newLedger.Default_Purchase_Order_Format__c == null) {
                newLedger.Default_Purchase_Order_Format__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (AccountingSettingsHandler.isERPEnabled() && newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL && newLedger.Default_Packing_Slip_Format__c == null) {
                newLedger.Default_Packing_Slip_Format__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void setAccountingMethod(List<Ledger__c> ledgers) {
        for (Ledger__c ledger : ledgers) {
            if (String.isBlank(ledger.Accounting_Method__c)) {
                ledger.Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
            }
        }
    }


    public static void setDefaultCurrency(List<Ledger__c> newLedgers) {
        if (!isPreventUpdateOverride && MultiCurrencyHandler.isMultiCurrencyEnabled) {

            for (Ledger__c newLedger : newLedgers) {
                if (newLedger.get('CurrencyIsoCode') == null) {
                    newLedger.put('CurrencyIsoCode', MultiCurrencyHandler.CORPORATE_CURRENCY);
                }
            }
        }
    }

    public static void preventCurrencyChange(Map<Id, Ledger__c> oldLedgerMap, Map<Id, Ledger__c> newLedgerMap) {
        if (!isPreventUpdateOverride && MultiCurrencyHandler.isMultiCurrencyEnabled) {

            for (Ledger__c newLedger : newLedgerMap.values()) {
                if (newLedger.get('CurrencyIsoCode') != oldLedgerMap.get(newLedger.Id).get('CurrencyIsoCode')) {
                    newLedger.addError(CURRENCY_CHANGE_ERROR);
                }
            }
        }

    }

    public static void preventChangeTypeOverMaxQuantity(Map<Id, Ledger__c> oldLedgerMap, Map<Id, Ledger__c> newLedgerMap) {
        List<Ledger__c> checkList = new List<Ledger__c>();

        for (Ledger__c newLedger : newLedgerMap.values()) {
            Boolean isTypeChanged = newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL
                    && newLedger.Type__c != oldLedgerMap.get(newLedger.Id).Type__c;
            Boolean isActiveChanged = newLedger.Active__c
                    && newLedger.Active__c != oldLedgerMap.get(newLedger.Id).Active__c;
            if (isTypeChanged || isActiveChanged) {
                checkList.add(newLedger);
            }
        }
        if (!checkList.isEmpty()) {
            preventInsertOverMaxQuantity(checkList);
        }
    }


    public static void preventInsertOverMaxQuantity(List<Ledger__c> newLedgers) {
        Integer ledgerLimit = AccountingLimitHandler.getInstance().getLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT);
        List<Ledger__c> allLedgerByType = DomainUtils.getLedgerByType(
                new Set<String> {LEDGER_TYPE_TRANSACTIONAL, LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL},
                new List<String>{PACKAGE_QUALIFIER + 'Active__c = true'}
        );
        if (allLedgerByType.size() > ledgerLimit) {
            for (Ledger__c newLedger : newLedgers) {
                if (newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL || newLedger.Type__c == LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL) {
                    newLedger.addError(String.format(
                       MAX_QUANTITY_ERROR,
                       new List<String> {String.valueOf(ledgerLimit)})
                   );
                }
            }
        }
    }

    public static void preventDeleteInactiveLedgers(List<Ledger__c> ledgers) {
        Set<Id> inactiveLedgerIds = new Set<Id>();
        for (Ledger__c ledger : ledgers) {
            if (!ledger.Active__c) {
                inactiveLedgerIds.add(ledger.Id);
            }
        }
        if (!inactiveLedgerIds.isEmpty()) {
            List<AggregateResult> results = DomainUtils.countLinesByParentIds(String.valueOf(Transaction__c.getSObjectType()), String.valueOf(Transaction__c.Ledger__c), inactiveLedgerIds);
            Map<Id, AggregateResult> resultsByLedgerIds = new Map<Id, AggregateResult>();
            for (AggregateResult result : results) {
                resultsByLedgerIds.put((Id)result.get('refToParent'), result);
            }
            for (Ledger__c ledger : ledgers) {
                if (resultsByLedgerIds.containsKey(ledger.Id)) {
                    ledger.addError(Label.ERR_DELETE_INACTIVE_LEDGER);
                }
            }
        }
    }

    public static void preventLedgerWithRelatedObjectDelete(Map<Id, Ledger__c> oldLedgerMap) {
        Set<Id> ledgerWithPositive = new Set<Id> ();

        for (String objName : relatedObjectForDeleteValidation) {
            Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
                DomainUtils.getRelatedObjectCountByApiNameAndLookupName(oldLedgerMap.keySet(), objName, 'Ledger__c')
            );
            for (Id resId : results.keySet()) {
                if (results.get(resId).get('itemCount') != 0) {
                    ledgerWithPositive.add(resId);
                }
            }
        }

        if (!ledgerWithPositive.isEmpty()) {
            for (Id oldLedgerId : ledgerWithPositive) {
                oldLedgerMap.get(oldLedgerId).addError(DELETE_ERROR);
            }
        }
    }

    public static void insertEliminationForConsolidation(List<Ledger__c> newLedgers) {
        List<Ledger__c> eliminationLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : newLedgers) {
            if (LedgerHandler.isConsolidationLedger(ledger)) {
                eliminationLedgers.add(buildEliminationsLedger(ledger));
            }
        }
        if (!eliminationLedgers.isEmpty()) {
            isSystemEliminationLedger = true;
            SFDCSecurityUtils.insertCheckCRUDAndFLS(eliminationLedgers, new List<String>(), false);
            isSystemEliminationLedger = false;
        }
    }

    private static Ledger__c buildEliminationsLedger(Ledger__c sourceLedger) {
        Ledger__c eliminationLedger = sourceLedger.clone();
        eliminationLedger.Accounting_Method__c = sourceLedger.Accounting_Method__c == ACCOUNTING_METHOD_ACCRUAL_CASH
                ? ACCOUNTING_METHOD_ACCRUAL
                : sourceLedger.Accounting_Method__c;
        eliminationLedger.Consolidation_Ledger_ID__c = sourceLedger.Id;
        eliminationLedger.Name = eliminationLedger.Name.left(75) + ' - EL';
        eliminationLedger.Type__c =
            LedgerHandler.isTransactionalLedger(sourceLedger)
                ? LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                : LEDGER_TYPE_ELIMINATIONS_BUDGET;
        return eliminationLedger;
    }

    public static void deleteEliminationForConsolidation(Map<Id, Ledger__c> oldLedgerMap) {

        Set<Id> elimLedgersWithChildren = new Set<Id> ();
        Set<Id> consolidationLedgerIDs = new Set<Id>();
        Set<Id> eliminationLedgerIDs = new Set<Id>();
        List<Ledger__c> eliminationLedgersToDelete = new List<Ledger__c>();

        for (Ledger__c ledger : oldLedgerMap.values()) {
            if (LedgerHandler.isConsolidationLedger(ledger)) {
                consolidationLedgerIDs.add(ledger.Id);
            }
        }

        Set<String> types = new Set<String>{LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL, LEDGER_TYPE_ELIMINATIONS_BUDGET};
        for (Ledger__c ledger : DomainUtils.getLedgerByType(types)) {
            if (consolidationLedgerIDs.contains(ledger.Consolidation_Ledger_ID__c)) {
                eliminationLedgersToDelete.add(ledger);
                eliminationLedgerIDs.add(ledger.Id);
            }
        }

        //get related EL with children
        Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
            DomainUtils.getRelatedObjectCountByApiNameAndLookupName(eliminationLedgerIDs, ELIMINATIONS_LEDGER_RELATED_OBJECT, 'Ledger__c')
        );
        for (Id resId : results.keySet()) {
            if (results.get(resId).get('itemCount') != 0) {
                elimLedgersWithChildren.add(resId);
            }
        }


        //if any related EL has children then block all theCL from being deleted as well
        if (!elimLedgersWithChildren.isEmpty()) {
            for (Ledger__c ledger : oldLedgerMap.values()) {
                oldLedgerMap.get(ledger.Id).addError(DELETE_ERROR);
            }
        }else {
            if (!eliminationLedgersToDelete.isEmpty()) {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(eliminationLedgersToDelete, true);
            }
        }
    }

    public static void preventEliminationLedgerDelete(Map<Id, Ledger__c> oldLedgerMap) {
        Set<Id> eliminationConsolidationIDs = new Set<Id>();
        for (Ledger__c ledger : oldLedgerMap.values()) { 
            if (LedgerHandler.isEliminationLedger(ledger)) {
                eliminationConsolidationIDs.add(ledger.Consolidation_Ledger_ID__c);
            }
        }

        Set<Id> consolidationLedgerIDs = new Set<Id>();
        for (Ledger__c ledger : LedgerHandler.getInstanceWithoutSharing().getLedgerById(eliminationConsolidationIDs)) {
            if (LedgerHandler.isConsolidationLedger(ledger)) {
                consolidationLedgerIDs.add(ledger.Id);
            }
        }
  
        for (Ledger__c ledger : oldLedgerMap.values()) { 
            if (consolidationLedgerIDs.contains(ledger.Consolidation_Ledger_ID__c)
                    || oldLedgerMap.get(ledger.Consolidation_Ledger_ID__c) != null) {

                oldLedgerMap.get(ledger.Id).addError(ELIMINATIONS_DELETE_ERROR);
            }
        }
    }

    public static void preventCreateEliminationManually(List<Ledger__c> newLedgers) {
        for (Ledger__c newLedger : newLedgers) {
            if (LedgerHandler.isEliminationLedger(newLedger) && !isSystemEliminationLedger) {
                newLedger.addError(MANUAL_ELIMINATION_ERROR);
            }
        }
    }

    public static void createGLAccountDefaults(List<Ledger__c> newLedgers) {
        LedgerHandler.reset();
        Map<Id, Ledger__c> newLedgerMap = new Map<Id, Ledger__c> (newLedgers);
        Set<Id> transAndBudgetLedgerIds = new Set<Id>();
        for (Ledger__c newLedger : newLedgers) {
            if (newLedger.Type__c == LEDGER_TYPE_TRANSACTIONAL || newLedger.Type__c == LEDGER_TYPE_BUDGET) {
                transAndBudgetLedgerIds.add(newLedger.Id);
            }
        }

        GLAccountDefaultsHandler.instance.setExistedGLAccountsFromDefaultLedger();
        List<ServiceResult> results = GLAccount.createGLAccountDefaultsByLedger(transAndBudgetLedgerIds);
        for (ServiceResult res : results) {
            if (!res.isSuccess && String.isNotBlank(res.data)) {
                newLedgerMap.get(GLAccountDefaultsHandler.instance.getGLAccountDefaultsById(res.data).Ledger__c).addError(res.errors[0].detail);
            }
        }
    }

    public static void setDefaultTaxSetting(List<Ledger__c> ledgers) {
        Boolean presetNativeTaxSetting = false;
        for (Ledger__c ledger : ledgers) {
            if (String.isBlank(ledger.Tax_Settings__c)
                    && (ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH
                    || ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH)) {
                presetNativeTaxSetting = true;
                break;
            }
        }
        if (presetNativeTaxSetting) {
            List<Tax_Settings__c> nativeTaxSettings = DomainUtils.taxSettingsByMethod(TaxSettingsActions.NATIVE_TAX_METHOD);
            if (!nativeTaxSettings.isEmpty()) {
                for (Ledger__c ledger : ledgers) {
                    if (String.isBlank(ledger.Tax_Settings__c)
                            && (ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH
                            || ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH)) {
                        ledger.Tax_Settings__c = nativeTaxSettings[0].Id;
                    }
                }
            }
        }
    }

    public static void setLegacyAccountingMethod(List<Ledger__c> newLedgers) {
        if (!isPreventUpdateOverride) {
            for (Ledger__c newLedger : newLedgers) {
                if (newLedger.Accounting_Method__c == null) {
                    newLedger.Accounting_Method__c = ACCOUNTING_METHOD_ACCRUAL;
                }
            }
        }
    }

    public static void preventAvaTax4CashLedger(List<Ledger__c> ledgers) {
        Set<Id> taxSettingIds = new Set<Id>();
        for (Ledger__c ledger : ledgers) {
            if (ledger.Accounting_Method__c == ACCOUNTING_METHOD_CASH && String.isNotBlank(ledger.Tax_Settings__c)) {
                taxSettingIds.add(ledger.Tax_Settings__c);
            }
        }
        Map<Id, Tax_Settings__c> avaTaxSettingsByIds = new Map<Id, Tax_Settings__c>();
        if (!taxSettingIds.isEmpty()) {
            avaTaxSettingsByIds.putAll(DomainUtils.taxSettingsByIdsAndMethods(taxSettingIds, new Set<String>{ TaxSettingsActions.AVA_TAX_METHOD }));
        }

        for (Ledger__c ledger : ledgers) {
            if (ledger.Accounting_Method__c == ACCOUNTING_METHOD_CASH && avaTaxSettingsByIds.containsKey(ledger.Tax_Settings__c)) {
                ledger.addError(Label.ERR_AVATAX_CANNOT_BE_SET_FOR_CASH);
            }
        }
    }

    public static void preventShadowLedgerDelete(List<Ledger__c> ledgers) {
        for (Ledger__c ledger : ledgers) {
            if (LedgerHandler.isShadowLedger(ledger)) {
                ledger.addError(Label.ERR_DELETE_SHADOW_LEDGER);
            }
        }
    }

    public static void deleteShadowLedger(List<Ledger__c> ledgers) {
        List<Ledger__c> shadowLedgers = new List<Ledger__c>();
        Map<Id, Ledger__c> ledgersByShadowIds = new Map<Id, Ledger__c>();
        for (Ledger__c ledger : ledgers) {
            if (ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH && String.isNotBlank(ledger.Related_Ledger__c)) {
                shadowLedgers.add(new Ledger__c(Id = ledger.Related_Ledger__c));
                ledgersByShadowIds.put(ledger.Related_Ledger__c, ledger);
            }
        }
        if (!shadowLedgers.isEmpty()) {
            List<Database.DeleteResult> results = SFDCSecurityUtils.deleteCheckCRUDAndFLS(shadowLedgers, false);
            for (Database.DeleteResult result : results) {
                if (!result.success && !result.getErrors().isEmpty() && ledgersByShadowIds.get(result.id) != null) {
                    ledgersByShadowIds.get(result.id).addError(String.join(new List<String>{Label.COMMON_SHADOW_LEDGER, result.getErrors()[0].message}, ': '));
                }
            }
        }
    }

    public static void checkFeatureParameterFieldLevelAccessInsert(){
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), Ledger__c.SObjectType);
        controlService.checkInsertFieldGrants();

    }

    public static void checkFeatureParameterFieldLevelAccessUpdate(){
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), Ledger__c.SObjectType);
        controlService.checkUpdateFieldGrants();
    }

    //Method to post message to SQS
    public static void  apAutomation(List<Ledger__c> ledgers, Map<Id,Ledger__c> oldLedgerMap) {
        List<Id> ledgerIdsToUpdateCompany = new List<Id>();
        List<Id> bankAccountToLedgerIds = new List<Id>();
        boolean createPaymentProcessor = false;

        for(Ledger__c ledger : ledgers) {
            UpdateControlService updateService = new UpdateControlService(new APAutomationUpdateControl(), Ledger__c.SObjectType);

            if(String.isNotBlank(ledger.Payment_Services_Company_Code__c) && ledger.Enrolled_in_Payment_Services__c == true && oldLedgerMap.get(ledger.Id).Enrolled_in_Payment_Services__c == true && updateService.checkUpdateFieldChanges()){
                ledgerIdsToUpdateCompany.add(ledger.Id);
            }
            
            if(ledger.Payment_Services_Company_Code__c != null && oldLedgerMap.get(ledger.Id).Payment_Services_Company_Code__c == null){
                createPaymentProcessor = true;
            }

            if(bankAccountsNeedUpdate()){
                if(String.isNotBlank(ledger.Payment_Services_Company_Code__c)){
                    bankAccountToLedgerIds.add(ledger.Id);
                }
            }
        }

        apAutoPostMessages(ledgerIdsToUpdateCompany,bankAccountToLedgerIds);
        if(createPaymentProcessor){
            apAutoCreatePaymentProcessor();
        }
    }

    public static void preventChangeTaxSettingIfLDOInProgress(Map<Id, Ledger__c> oldLedgerMap, Map<Id, Ledger__c> newLedgerMap) {
        if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            Map<Id, Ledger__c> checkList = new Map<Id, Ledger__c>();

            for (Ledger__c newLedger : newLedgerMap.values()) {
                if (newLedger.Tax_Settings__c != oldLedgerMap.get(newLedger.Id).Tax_Settings__c) {
                    checkList.put(newLedger.Id, newLedger);
                }
            }
            if (!checkList.isEmpty()) {
                Set<Id> ledgerIds = new Set<Id>();
                for (SObject obj : searchObjectsInStatus(checkList.keySet())) {
                    ledgerIds.add((Id) obj.get(PACKAGE_QUALIFIER + 'Ledger__c'));

                }
                if (!ledgerIds.isEmpty()) {
                    for (Ledger__c newLedger : newLedgerMap.values()) {
                        if (ledgerIds.contains(newLedger.Id)) {
                            newLedger.addError(Label.ERR_PREVENT_CHANGE_TAX_SETTING);
                        }
                    }
                }
            }
        }
    }

    public static void validateConsolidationAccountingMethod(List<Ledger__c> ledgers, Map<Id, Ledger__c> oldLedgersByIds) {
        if (!isPreventUpdateOverride) {
            for (Ledger__c ledger : ledgers) {
                Boolean isAccountingMethodChanged = ledger.Accounting_Method__c != oldLedgersByIds.get(ledger.Id).Accounting_Method__c;
                if (isAccountingMethodChanged && LedgerFieldUpdateValidator.ELIMINATIONS_TYPES.contains(ledger.Type__c)) {
                    ledger.addError(Label.ERR_NOT_VALID_METHOD_FOR_ELIMINATION);
                }
                if (isAccountingMethodChanged
                        && LedgerFieldUpdateValidator.CONSOLIDATIONS_TYPES.contains(ledger.Type__c)
                        && !LedgerActions.ACCRUAL_OR_CASH.contains(ledger.Accounting_Method__c)
                        && LedgerActions.ACCRUAL_OR_CASH.contains(oldLedgersByIds.get(ledger.Id).Accounting_Method__c)) {
                    ledger.addError(Label.ERR_NOT_VALID_METHOD_FOR_CONSOLIDATION);
                }
            }
        }
    }

    public static void preventConsolidationsAccrualAndCashMethod(List<Ledger__c> ledgers) {
        for (Ledger__c ledger : ledgers) {
            if (LedgerHandler.isConsolidationLedger(ledger) && isAccrualAndCashAccountingMethod(ledger)) {
                ledger.addError(String.format(
                    Label.ERR_NOT_VALID_METHOD_FOR_CONSOLIDATION,
                    new List<String>{(String) ledger.get(Ledger__c.Type__c)}
                ));
            }
        }
    }

    public static List<SObject> searchObjectsInStatus(Set<Id> ledgerIds) {
        List<SObject> result = new List<SObject>();
        Set<String> status = new Set<String> {
            AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS,
            AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
        };

        result.addAll([SELECT Id, Ledger__c FROM Billing__c WHERE Ledger__c = :ledgerIds AND Status__c = :status LIMIT 5000]);
        result.addAll([SELECT Id, Ledger__c FROM Account_Payable__c WHERE Ledger__c = :ledgerIds AND Status__c = :status LIMIT 5000]);
        result.addAll([SELECT Id, Ledger__c FROM Journal_Entry__c WHERE Ledger__c = :ledgerIds AND Status__c = :status LIMIT 5000]);
        result.addAll([SELECT Id, Ledger__c FROM Billing_Cash_Receipt__c WHERE Billing__r.Ledger__c = :ledgerIds AND Status__c = :status LIMIT 5000]);
        result.addAll([SELECT Id, Ledger__c FROM AP_Disbursement__c WHERE Account_Payable__r.Ledger__c = :ledgerIds AND Status__c = :status LIMIT 5000]);
        result.addAll([SELECT Id, Ledger__c FROM Cash_Receipt__c WHERE Ledger__c = :ledgerIds AND Status__c = :status LIMIT 5000]);
        result.addAll([SELECT Id, Ledger__c FROM Cash_Disbursement__c WHERE Ledger__c = :ledgerIds AND Status__c = :status LIMIT 5000]);
        return result;
    }

    private static void apAutoPostMessages(List<Id> ledgerIdsToUpdateCompany, List<Id> bankAccountToLedgerIds){
        // if list of ledger id is empty then do not call SQS service class to post UPDATE_COMPANY message
        if(!ledgerIdsToUpdateCompany.isEmpty()) {
            APAutomationService.postMessage(ledgerIdsToUpdateCompany, APAutomationService.APAutomationActions.UPDATE_COMPANY.name());
        }
        postMsgToBankAccountFromLedger(bankAccountToLedgerIds);
    }

    @Future
    private static void  apAutoCreatePaymentProcessor() {
        List<Payment_Processor__c> payProcessors = DomainUtils.getPaymentProcessorsByType(PaymentProcessorActions.EDENRED_TYPE);
        if(payProcessors == null || payProcessors.size() <= 0){
            Payment_Processor__c payProcess = new Payment_Processor__c(Name = PaymentProcessorActions.EDENRED_TYPE, Type__c = PaymentProcessorActions.EDENRED_TYPE, Active__c = true);
            SFDCSecurityUtils.insertProxy(payProcess);
        }

    }

    private static Boolean bankAccountsNeedUpdate() {
        AccessControlService accessControl = new AccessControlService(new List<Schema.SObjectField>
                                                                    {
                                                                        Ledger__c.TIN__c,
                                                                        Ledger__c.Payment_Services_Company_Code__c
                                                                    }
        );

        return accessControl.isUpdateFieldsChanged();
    }

    private static void postMsgToBankAccountFromLedger(List<Id> bankAccountToLedgerIds) {

        if(!bankAccountToLedgerIds.isEmpty()){
            List<String> queryFields = new List<String>{'Id'};
            List<String> subQueryFields = new List<String>{'Id'};

            String subQueryRelationshipName = 'AcctSeed__Bank_Accounts__r';
            String subQueryCondition = 'Enable_for_Payment_Services__c=true';

            SOQLBuilder theQuery = new SOQLBuilder(Ledger__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition('ID IN:bankAccountToLedgerIds')
                .subselectQuery(subQueryRelationshipName, true)
                .setEnforceFLS(true)
                .selectFields(subQueryFields)
                .setCondition(subQueryCondition);

            List<Bank_Account__c> bankAccounts = new List<Bank_Account__c>();
            List<Id> bankAccountIds = new List<Id>();

            //There can be a chances when specific ledger has a more than 50,000 records then we need to process it asynchronously
            for(Ledger__c ldg: (List<Ledger__c>) Database.query(theQuery.toSOQL())){
                bankAccounts.addAll(ldg.Bank_Accounts__r);
            }

            for(Bank_Account__c bankAcc: bankAccounts){
                bankAccountIds.add(bankAcc.Id);
            }

            // if list of bank Account id is empty then do not call SQS service class to post UPDATE_Bank_Account message
            if(!bankAccountIds.isEmpty()) {
                APAutomationService.postMessage(bankAccountIds, APAutomationService.APAutomationActions.UPDATE_BANK_ACCOUNT.name());
            }
        }
    }

    public static Boolean isCashAccountingMethod(SObject obj) {
        return obj.get(Ledger__c.Accounting_Method__c) == LedgerActions.ACCOUNTING_METHOD_CASH;
    }

    public static Boolean isAccrualAccountingMethod(SObject obj) {
        return obj.get(Ledger__c.Accounting_Method__c) == LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
    }

    public static Boolean isAccrualAndCashAccountingMethod(SObject obj) {
        return obj.get(Ledger__c.Accounting_Method__c) == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH;
    }

}