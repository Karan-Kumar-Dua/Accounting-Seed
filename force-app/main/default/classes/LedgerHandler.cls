public with sharing class LedgerHandler {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    private static LedgerHandler instance;
    private static Map<String, Map<Id, Ledger__c>> availableLedgersBySharingContext;
    private SharingContext aSharingContext;
    private Boolean isFullFieldsSet;
    private String currentCompositeKey;

    public class LedgerException extends Exception {}

    private LedgerHandler(SharingContext sContext, Boolean queryAllFields) {
        this.aSharingContext = sContext;
        this.isFullFieldsSet = queryAllFields;
        this.currentCompositeKey = aSharingContext.name() + String.valueOf(isFullFieldsSet);
        init();
    }

    private static LedgerHandler getInstance(SharingContext sContext, Boolean queryAllFields) {
        if (instance == null || instance.aSharingContext != sContext || instance.isFullFieldsSet != queryAllFields) {
            instance = new LedgerHandler(sContext, queryAllFields);
        }
        return instance;
    }

    public static LedgerHandler getInstanceWithSharing(Boolean queryAllFields) {
        return getInstance(LedgerHandler.SharingContext.WITH_SHARING, queryAllFields);
    }

    public static LedgerHandler getInstanceWithSharing() {
        return getInstanceWithSharing(false);
    }

    public static LedgerHandler getInstanceWithoutSharing() {
        return getInstance(LedgerHandler.SharingContext.WITHOUT_SHARING, true);
    }

    private void init() {
        if (availableLedgersBySharingContext == null) {
            availableLedgersBySharingContext = new Map<String, Map<Id, Ledger__c>>();
        }
        try {
            if (availableLedgersBySharingContext.get(currentCompositeKey) == null) {
                switch on aSharingContext {
                    when WITH_SHARING {
                        availableLedgersBySharingContext.put(currentCompositeKey, new Map<Id, Ledger__c>(queryLedgers()));
                    }
                    when WITHOUT_SHARING {
                        availableLedgersBySharingContext.put(currentCompositeKey, new Map<Id, Ledger__c>(DomainUtils.getLedgers()));
                    }
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private List<Ledger__c> queryLedgers() {
        List<String> queryFields = new List<String>{'Id', 'Name', PACKAGE_QUALIFIER + 'Type__c', PACKAGE_QUALIFIER + 'Is_Shadow__c', PACKAGE_QUALIFIER + 'Active__c'};

        if (isFullFieldsSet) {
            queryFields.add(PACKAGE_QUALIFIER + 'Billing_Activity_Statement_Format__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Billing_Outstanding_Statement_Format__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Default_Bank_Account__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Default_Billing_Format__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Default_Purchase_Order_Format__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Default_Packing_Slip_Format__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Financial_Reporter_Settings__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Consolidation_Ledger_ID__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Tax_Settings__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Sales_Tax_Company_Code__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Tax_Settings__r.' + PACKAGE_QUALIFIER + 'Tax_Settings_Method__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Accounting_Method__c');
            queryFields.add(PACKAGE_QUALIFIER + 'Related_Ledger__c');
        }

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryString = 'SELECT ' + String.join(queryFields,',') + ' FROM ' +
            PACKAGE_QUALIFIER + 'Ledger__c ORDER BY ' + PACKAGE_QUALIFIER + 'Type__c DESC, Name ASC';
        
        return (Ledger__c[]) Database.query(queryString);
    }

    public static void reset() {
        instance = null;
        availableLedgersBySharingContext = null;
    }

    public enum SharingContext {
        WITH_SHARING,
        WITHOUT_SHARING
    }


    //=================================================================================================
    //================================== INSTANCE UTILITY METHODS =====================================
    //=================================================================================================

    public List<Ledger__c> getAllLedgers() {
        return availableLedgersBySharingContext.get(currentCompositeKey).values();
    }

    public Map<Id, Ledger__c> getAllLedgersMap() {
        return availableLedgersBySharingContext.get(currentCompositeKey);
    }

    public List<Ledger__c> getPrimaryTransactionalLedgers() {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Ledger__c eachLedger : getTransactionalLedgers()) {
            if (!eachLedger.Is_Shadow__c) {
                result.add(eachLedger);
            }
        }
        return result;
    }

    public List<Ledger__c> getPrimaryActiveTransactionalLedgers() {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Ledger__c eachLedger : getTransactionalLedgers()) {
            if (!eachLedger.Is_Shadow__c && eachLedger.Active__c) {
                result.add(eachLedger);
            }
        }
        return result;
    }

    public List<Ledger__c> getTransactionalLedgers() {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Ledger__c eachLedger : getAllLedgers()) {
            if (eachLedger.Type__c == LedgerActions.LEDGER_TYPE_TRANSACTIONAL) {
                result.add(eachLedger);
            }
        }
        return result;
    }

    public List<Ledger__c> getAllTransactionalTypeLedgers() {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Ledger__c eachLedger : getAllLedgers()) {
            if (isTransactionalLedger(eachLedger.Type__c)) {
                result.add(eachLedger);
            }
        }
        return result;
    }

    public List<Ledger__c> getEliminationsTransactionalLedgers() {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Ledger__c eachLedger : getAllLedgers()) {
            if (eachLedger.Type__c == LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL) {
                result.add(eachLedger);
            }
        }
        return result;
    }

    public List<Ledger__c> getTransactionalLedgersById(Set<Id> ledgerIds) {
        List<Ledger__c> result = new List<Ledger__c>();
        Map<Id, Ledger__c> transactionalLedgersMap = new Map<Id, Ledger__c>(
            getTransactionalLedgers()
        );
        for (Id lId : ledgerIds) {
            Ledger__c led = transactionalLedgersMap.get(lId);
            if (led != null) {
                result.add(led);
            }
        }
        return result;
    }

    public List<Ledger__c> getBudgetLedgers() {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Ledger__c eachLedger : getAllLedgers()) {
            if (eachLedger.Type__c == LedgerActions.LEDGER_TYPE_BUDGET) {
                result.add(eachLedger);
            }
        }
        return result;
    }

    public Ledger__c getLedgerById(Id ledgerId) {
        List<Ledger__c> result = getLedgerById(new Set<Id> {ledgerId});
        return (!result.isEmpty()) ? result[0] : null;
    }

    public List<Ledger__c> getLedgerById(Set<Id> ledgerIds) {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Id lId : ledgerIds) {
            Ledger__c led = getAllLedgersMap().get(lId);
            if (led != null) {
                result.add(led);
            }
        }
        return result;
    }

    public List<Ledger__c> getLedgerByName(Set<String> names) {
        List<Ledger__c> result = new List<Ledger__c>();
        for (Ledger__c eachLedger : getAllLedgers()) {
            if (names.contains(eachLedger.Name)) {
                result.add(eachLedger);
            }
        }
        return result;
    }

    public List<SelectOption> getTransactionalActiveLedgerSelectOptions() {
        return getTransactionalActiveLedgerSelectOptions(false);
    }

    public List<SelectOption> getTransactionalActiveLedgerSelectOptions(Boolean includeNone) {
        List<SelectOption> result  = new List<SelectOption>();
        //Include --None-- option
        if (includeNone) {
            result.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
        }
        for (Ledger__c ledger : getPrimaryActiveTransactionalLedgers()) {
            result.add(new SelectOption(ledger.Id, ledger.Name));
        }
        if (result.isEmpty()) {
            result.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
        }
        return result;
    }

    public List<SelectOption> getTransactionalLedgerSelectOptions() {
        return getTransactionalLedgerSelectOptions(false);
    }

    public List<SelectOption> getTransactionalLedgerSelectOptions(Boolean includeNone) {
        List<SelectOption> result  = new List<SelectOption>();
        //Include --None-- option
        if (includeNone) {
            result.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
        }
        for (Ledger__c ledger : getPrimaryTransactionalLedgers()) {
            result.add(new SelectOption(ledger.Id, ledger.Name));
        }
        if (result.isEmpty()) {
            result.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
        }
        return result;
    }

    public List<SelectOption> getBudgetLedgerSelectOptions() {
        List<SelectOption> result  = new List<SelectOption>();
        for (Ledger__c ledger : getBudgetLedgers()) {
            result.add(new SelectOption(ledger.Id, ledger.Name));
        }
        if (result.isEmpty()) {
            result.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
        }
        return result;
    }

    public List<SelectOption> getBudgetLedgerSelectOptions(String currencyIsoCode) {
        if (IS_MULTI_CURRENCY_ENABLED && !String.isBlank(currencyIsoCode)) {
            List<SelectOption> result  = new List<SelectOption>();
            for (Ledger__c ledger : getBudgetLedgers()) {
                if (ledger.get('CurrencyIsoCode') == currencyIsoCode) {
                    result.add(new SelectOption(ledger.Id, ledger.Name));
                }
            }
            if (result.isEmpty()) {
                result.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
            }
            return result;
        }
        else {
            return getBudgetLedgerSelectOptions();
        }
    }

    public Map<Id, Ledger__c> eliminationLedgersByConsolidationIds(Set<Id> consolidationLedgerIds) {
        List<Ledger__c> filteredLedgers = getEliminationLedgersByConsolidationIds(consolidationLedgerIds);
        Map<Id, Ledger__c> eliminationLedgersByConsolidationIds = new Map<Id, Ledger__c>();
        for (Ledger__c ledger : filteredLedgers) {
            eliminationLedgersByConsolidationIds.put(Id.valueOf(ledger.Consolidation_Ledger_ID__c), ledger);
        }
        return eliminationLedgersByConsolidationIds;
    }

    public List<Ledger__c> getEliminationLedgersByConsolidationIds(Set<Id> consolidationLedgerIds) {
        List<Ledger__c> filteredLedgers = new List<Ledger__c>();
        for (Ledger__c ledger : getAllLedgers()) {
            if (isEliminationLedger(ledger) && consolidationLedgerIds.contains(ledger.Consolidation_Ledger_ID__c)) {
                filteredLedgers.add(ledger);
            }
        }
        return filteredLedgers;
    }

    public Boolean isEliminationLedgerById(Id ledgerId) {
        return isEliminationLedger(getLedgerById(ledgerId));
    }

    public Boolean isActiveLedger(Id ledgerId) {
        return isActiveLedger(getLedgerById(ledgerId));
    }

    public Boolean isShadowLedger(Id ledgerId) {
        return isShadowLedger(getLedgerById(ledgerId));
    }

    public Boolean isCashLedger(Id ledgerId) {
        Ledger__c ledger = getLedgerById(ledgerId);
        return ledger.Accounting_Method__c != null && ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH && String.isBlank(ledger.Related_Ledger__c);
    }

    public Boolean isAccrualAndCashLedger(Id ledgerId) {
        Ledger__c ledger = getLedgerById(ledgerId);
        return ledger.Accounting_Method__c != null && ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH;
    }

    public Boolean isAccrualLedger(Id ledgerId) {
        Ledger__c ledger = getLedgerById(ledgerId);
        return ledger.Accounting_Method__c == null || ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL;
    }

    public Ledger__c getShadowLedgerByParent(Id ledgerId) {
        Ledger__c ledger = getLedgerById(ledgerId);
        return ledger.Accounting_Method__c != null && ledger.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
            ? getLedgerById(ledger.Related_Ledger__c) : ledger;
    }

    //=================================================================================================
    //================================== STATIC UTILITY METHODS =====================================
    //=================================================================================================

    public static Boolean isActiveLedger(Ledger__c ledger) {
        return ledger.Active__c;
    }

    public static Boolean isShadowLedger(Ledger__c ledger) {
        return ledger.Is_Shadow__c;
    }

    public static Id getLedgerId() {
        Ledger_Custom_Settings__c ledgerCustomSettings = Ledger_Custom_Settings__c.getValues(UserInfo.getUserId());
        return
            ledgerCustomSettings != null && LedgerHandler.getInstanceWithoutSharing().isActiveLedger(ledgerCustomSettings.Ledger_Id__c)
                ? ledgerCustomSettings.Ledger_Id__c
                : Ledger_Custom_Settings__c.getOrgDefaults().Ledger_Id__c;
    }

    public static Id getLedgerIdWithSharing() {
        Ledger_Custom_Settings__c ledgerCustomSettings = Ledger_Custom_Settings__c.getValues(UserInfo.getUserId());
        Id ledgerId =
                ledgerCustomSettings != null && LedgerHandler.getInstanceWithoutSharing().isActiveLedger(ledgerCustomSettings.Ledger_Id__c)
                    ? ledgerCustomSettings.Ledger_Id__c
                    : Ledger_Custom_Settings__c.getOrgDefaults().Ledger_Id__c;
        Ledger__c ledgerCheck = getInstanceWithSharing().getLedgerById(ledgerId);
        return ledgerCheck != null ? ledgerCheck.Id : null;
    }

    public static Id getOrgDefaultLedgerId() {
        return Ledger_Custom_Settings__c.getOrgDefaults().Ledger_Id__c;
    }

    public static Boolean isLedgerEqualLegacyLedger(Id ledgerId) {
        return (getLegacyDefaultLedgerId() == ledgerId);
    }

    public static Id getLegacyDefaultLedgerId() {
        Id result = AccountingSettingsHandler.getAccountingSettings().Legacy_Default_Ledger__c;
        if (result == null) {
            throw new LedgerException(
                Label.ERR_DEFAULT_LEDGER_NOT_SET_CORRECTLY_LEGACY_RECORDS
            );
        }
        return result;
    }

    public static String getLedgerCurrency(Id ledgerId) {
        String result = MultiCurrencyHandler.CORPORATE_CURRENCY;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
            result = ledger != null ? (String) ledger.get('CurrencyIsoCode') : result;
        }
        return result;
    }

    public static String getLedgerAccountingMethod(Id ledgerId) {
        Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
        return ledger?.Accounting_Method__c;
    }

    public static Ledger__c getShadowLedger(Id ledgerId) {
        Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
        return LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledger?.Related_Ledger__c);
    }

    public static Boolean isLedgerCurrency(String sourceRecordCurrencyCode, Id ledgerId) {
        Boolean result = true;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            String ledgerCurrency = getLedgerCurrency(ledgerId);
            result = ledgerCurrency.equalsIgnoreCase(sourceRecordCurrencyCode);
        }
        return result;
    }

    public static Boolean isUSDLedger(Id ledgerIdToCheck) {
        LedgerHandler lh = LedgerHandler.getInstanceWithoutSharing();
        Ledger__c ledgerToCheck;
        if (ledgerIdToCheck == null) {
            ledgerToCheck = lh.getAllLedgersMap().get(getLegacyDefaultLedgerId());
        }
        else {
            ledgerToCheck = lh.getAllLedgersMap().get(ledgerIdToCheck);
        }
        return (MultiCurrencyHandler.isMultiCurrencyEnabled)
            ? String.valueOf(ledgerToCheck.get('CurrencyIsoCode')) == 'USD'
            : true;
    }

    public static Boolean isConsolidationLedger(String ledgerType) {
        return
            ledgerType == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL || ledgerType == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET;
    }

    public static Boolean isConsolidationLedger(Ledger__c aLedger) {
        return isConsolidationLedger(aLedger.Type__c);
    }

    public static Boolean isEliminationLedger(String ledgerType) {
        return
            ledgerType == LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL || ledgerType == LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET;
    }

    public static Boolean isEliminationLedger(Ledger__c aLedger) {
        return isEliminationLedger(aLedger.Type__c);
    }

    public static Boolean isBudgetLedger(Ledger__c aLedger) {
        return
            aLedger.Type__c == LedgerActions.LEDGER_TYPE_BUDGET
                || aLedger.Type__c == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET
                || aLedger.Type__c == LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET;
    }

    public static Boolean isBudgetLedger(String ledgerType) {
        return
            ledgerType == LedgerActions.LEDGER_TYPE_BUDGET
                || ledgerType == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_BUDGET
                || ledgerType == LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET;
    }

    public static Boolean isTransactionalLedger(String ledgerType) {
        return
            ledgerType == LedgerActions.LEDGER_TYPE_TRANSACTIONAL
                || ledgerType == LedgerActions.LEDGER_TYPE_CONSOLIDATIONS_TRANSACTIONAL
                || ledgerType == LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL;
    }

    public static Boolean isTransactionalLedger(Ledger__c aLedger) {
        return isTransactionalLedger(aLedger.Type__c);
    }

}