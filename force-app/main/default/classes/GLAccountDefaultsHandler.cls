public with sharing class GLAccountDefaultsHandler {
    public static String AP_CONTROL_GL_ACCOUNT = 'AP_Control_GL_Account';
    public static String AR_CONTROL_GL_ACCOUNT = 'AR_Control_GL_Account';
    public static String CTA_GL_ACCOUNT = 'CTA_GL_Account';
    public static String CURRENCY_GAIN_LOSS_GL_ACCOUNT = 'Currency_Gain_Loss_GL_Account';
    public static String CURRENT_YEAR_EARNINGS_GL_ACCOUNT = 'Current_Year_Earnings_GL_Account';
    public static String CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT = 'Customer_Payment_Adjustment_GL_Account';
    public static String DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT = 'Default_Project_Task_Labor_GL_Account';
    public static String REVENUE_GL_ACCOUNT = 'Revenue_GL_Account';
    public static String LABOR_GL_ACCOUNT = 'Labor_GL_Account';
    public static String PREPAID_EXPENSE_GL_ACCOUNT = 'Prepaid_Expense_GL_Account';
    public static String RETAINED_EARNINGS_GL_ACCOUNT = 'Retained_Earnings_GL_Account';
    public static String UNAPPLIED_CASH_GL_ACCOUNT = 'Unapplied_Cash_GL_Account';
    public static String PAYMENT_DISCOUNT_GL_ACCOUNT = 'Payment_Discount_GL_Account';
    public static String VOUCHERS_PAYABLE_GL_ACCOUNT = 'Vouchers_Payable_GL_Account';
    public static String WORK_IN_PROCESS_GL_ACCOUNT = 'Work_in_Process_GL_Account';
    public static String DEFAULT_DEBIT_GL_ACCOUNT_REVENUE = 'Default_Debit_GL_Account_Revenue';
    public static String DEFAULT_DEBIT_GL_ACCOUNT_EXPENSE = 'Default_Debit_GL_Account_Expense';
    public static String DEFAULT_CREDIT_GL_ACCOUNT_REVENUE = 'Default_Credit_GL_Account_Revenue';
    public static String DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE = 'Default_Credit_GL_Account_Expense';
    public static String DEFAULT_CASH_RECEIPT_CATEGORY = 'Default_Cash_Receipt_Category';
    public static String DEFAULT_CASH_DISBURSEMENT_CATEGORY = 'Default_Cash_Disbursement_Category';
    public static String DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY = 'Default_Journal_Entry_Line_Category';
    public static String INVENTORY_VARIANCE_GL_ACCOUNT = 'Inventory_Variance_GL_Account';
    public static String UNAPPLIED_REVENUE_GL_ACCOUNT = 'Unapplied_Revenue_GL_Account';
    public static String UNAPPLIED_EXPENSE_GL_ACCOUNT = 'Unapplied_Expense_GL_Account';

    public List<GLAccountDefault> glAccountDefaults;
    public Set<String> cashFlowSpecifications = new Set<String> {
        DEFAULT_CASH_RECEIPT_CATEGORY,
        DEFAULT_CASH_DISBURSEMENT_CATEGORY,
        DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY
    };

    public Set<String> consolidationSpecifications = new Set<String> {
        CURRENT_YEAR_EARNINGS_GL_ACCOUNT,
        RETAINED_EARNINGS_GL_ACCOUNT,
        CTA_GL_ACCOUNT
    };

    @TestVisible
    private Map<String, String> defaultGlAccountNameByDefaultsSpecifications = new Map<String, String> {
        AP_CONTROL_GL_ACCOUNT => '2000-Accounts Payable',
        AR_CONTROL_GL_ACCOUNT => '1200-Accounts Receivable',
        CURRENCY_GAIN_LOSS_GL_ACCOUNT => '8040-Currency Gain/Loss',
        CURRENT_YEAR_EARNINGS_GL_ACCOUNT => '3060-Current Year Earnings',
        CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT => '4900-Customer Payment Discounts',
        DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT => '5050-Labor',
        REVENUE_GL_ACCOUNT => '4000-Product Revenue',
        LABOR_GL_ACCOUNT => '2030-Accrued Payroll',
        PREPAID_EXPENSE_GL_ACCOUNT => '1400-Prepaid Expenses',
        RETAINED_EARNINGS_GL_ACCOUNT => '3050-Retained Earnings',
        UNAPPLIED_CASH_GL_ACCOUNT => '1205-Unapplied A/R',
        PAYMENT_DISCOUNT_GL_ACCOUNT => '5040-Vendor Payment Discounts',
        VOUCHERS_PAYABLE_GL_ACCOUNT => '2010-Vouchers Payable',
        WORK_IN_PROCESS_GL_ACCOUNT => '1600-Work In Process',
        DEFAULT_DEBIT_GL_ACCOUNT_REVENUE => '2500-Deferred Revenue',
        DEFAULT_CREDIT_GL_ACCOUNT_REVENUE => '4000-Product Revenue',
        DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE => '1450-Deferred Expenses',
        DEFAULT_CASH_RECEIPT_CATEGORY => 'Receipts from customers',
        DEFAULT_CASH_DISBURSEMENT_CATEGORY => 'Payments to suppliers',
        DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY => 'Payments to suppliers',
        UNAPPLIED_REVENUE_GL_ACCOUNT => '4015-Unapplied Revenue',
        UNAPPLIED_EXPENSE_GL_ACCOUNT => '8000-Unapplied Expense'
    };

    @TestVisible
    private Map<String, Id> glAccountIdsByDefaultsSpecifications = new Map<String, Id>();

    @TestVisible
    private Map<String, String> glAccountNameByDefaultsSpecifications {
        get {
            glAccountNameByDefaultsSpecifications = new Map<String, String> {
                DEFAULT_CASH_RECEIPT_CATEGORY => 'Receipts from customers',
                DEFAULT_CASH_DISBURSEMENT_CATEGORY => 'Payments to suppliers',
                DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY => 'Payments to suppliers'
            };
            if (!createOnlyCashFlow) {
                glAccountNameByDefaultsSpecifications.putAll(defaultGlAccountNameByDefaultsSpecifications);
            }
            glAccountNameByDefaultsSpecifications.putAll(getCTADefaults());
            return glAccountNameByDefaultsSpecifications;
        }
        private set;
    }

    private Map<Id, List<GLAccountDefault>> glAccountDefaultsByLedgerIds;
    private Map<Id, GLAccountDefault> glAccountDefaultsById;
    private Map<String, GL_Account_Specification__mdt> glAccountSpecificationsByDevNames;
    private Map<String, GL_Account__c> glAccountsForLedgerDefaultByName;
    private Map<Id, GL_Account_Default__c> glAccountDefaultsSObjById;

    public Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaultsMapByLedgerIds = new Map<Id, Map<String, GL_Account_Default__c>>();
    public Boolean createOnlyCashFlow = false;
    public static GLAccountDefaultsHandler instance {
        get {
            if (instance == null) {
                instance = new GLAccountDefaultsHandler();
            }
            return instance;
        }
        set {
            instance = value;
        }
    }

    private Map<String, String> getCTADefaults() {
        Map<String, String> result = new Map<String, String>();
        if (defaultGlAccountNameByDefaultsSpecifications.containsKey(CTA_GL_ACCOUNT)) {
            result.put(CTA_GL_ACCOUNT, defaultGlAccountNameByDefaultsSpecifications.get(CTA_GL_ACCOUNT));
        }
        return result;
    }

    private GLAccountDefaultsHandler() {
        glAccountDefaultsSObjById = new Map<Id, GL_Account_Default__c> (DomainUtils.allGLAccountDefaults());
        Map<Id, GL_Account__c> glAccountMap = new Map<Id, GL_Account__c>();

        Set<String> specificationDevNames = new Set<String>();
        for (GL_Account_Default__c glAccountDefault : glAccountDefaultsSObjById.values()) {
            specificationDevNames.add(glAccountDefault.GL_Account_Specification__c);
            glAccountMap.put(glAccountDefault.GL_Account__c, null);
        }

        Map<String, GL_Account_Specification__mdt> glAccountSpecificationsByDevNames =
                glAccountSpecificationsByDevNames(DomainUtils.glAccountSpecifications(specificationDevNames));
        glAccountMap = new Map<Id, GL_Account__c> (DomainUtils.getGlAccountsById(glAccountMap.keySet()));

        this.glAccountDefaultsById = new Map<Id, GLAccountDefault>();
        this.glAccountDefaults = new List<GLAccountDefault>();
        this.glAccountDefaultsByLedgerIds = new Map<Id, List<GLAccountDefault>>();
        for (GL_Account_Default__c glAccountDefault : glAccountDefaultsSObjById.values()) {
            GLAccountDefault glAccountDefaultWrap = new GLAccountDefault();
            glAccountDefaultWrap.glAccountDefault = glAccountDefault;
            glAccountDefaultWrap.ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(glAccountDefault.Ledger__c);
            glAccountDefaultWrap.glAccountSpecification = glAccountSpecificationsByDevNames.get(glAccountDefault.GL_Account_Specification__c);
            glAccountDefaultWrap.glAccount = glAccountMap.get(glAccountDefault.GL_Account__c);

            this.glAccountDefaults.add(glAccountDefaultWrap);
            this.glAccountDefaultsById.put(glAccountDefault.Id, glAccountDefaultWrap);

            List<GLAccountDefault> glAccountDefaultsByLedgerId = this.glAccountDefaultsByLedgerIds.containsKey(glAccountDefault.Ledger__c)
                    ? this.glAccountDefaultsByLedgerIds.get(glAccountDefault.Ledger__c)
                    : new List<GLAccountDefault>();
            glAccountDefaultsByLedgerId.add(glAccountDefaultWrap);
            this.glAccountDefaultsByLedgerIds.put(glAccountDefault.Ledger__c, glAccountDefaultsByLedgerId);
            setAccountDefaultsMapByLedgerIds(glAccountDefault);
        }
    }

    private void setAccountDefaultsMapByLedgerIds(GL_Account_Default__c glAccountDefault) {
        if (!glAccountDefaultsMapByLedgerIds.containsKey(glAccountDefault.Ledger__c)) {
            glAccountDefaultsMapByLedgerIds.put(
                glAccountDefault.Ledger__c,
                new Map<String, GL_Account_Default__c> {glAccountDefault.GL_Account_Specification__c => glAccountDefault}
            );
        }
        else {
            glAccountDefaultsMapByLedgerIds.get(glAccountDefault.Ledger__c).put(glAccountDefault.GL_Account_Specification__c, glAccountDefault);
        }
    }

    public GL_Account_Default__c getGLAccountDefaultsById(Id defaultId) {
        return glAccountDefaultsSObjById.keySet().contains(defaultId) ? glAccountDefaultsSObjById.get(defaultId) : null;
    }

    public List<GLAccountDefault> glAccountDefaultsByLedgerId(Id ledgerId) {
        return glAccountDefaultsByLedgerIds(new Set<Id>{ ledgerId }).get(ledgerId);
    }

    public Map<Id, List<GLAccountDefault>> glAccountDefaultsByLedgerIds(Set<Id> ledgerIds) {
        Map<Id, List<GLAccountDefault>> glAccountDefaultsByLedgerIds = new Map<Id, List<GLAccountDefault>>();
        for (Id ledgerId : ledgerIds) {
            glAccountDefaultsByLedgerIds.put(ledgerId, this.glAccountDefaultsByLedgerIds.get(ledgerId));
        }
        return glAccountDefaultsByLedgerIds;
    }

    public List<ServiceResult> saveGLAccountDefaults(List<GLAccountDefault> glAccountDefaults) {
        List<ServiceResult>  results = new List<ServiceResult>();
        List<GL_Account_Default__c> defaultsForUpsert = new List<GL_Account_Default__c>();
        List<GL_Account_Default__c> defaultsForDelete = new List<GL_Account_Default__c>();
        for (GLAccountDefault def : glAccountDefaults) {
            if (def.glAccountDefault.Id == null) {
                defaultsForUpsert.add(def.glAccountDefault);
            }
            else if (def.glAccount == null) {
                defaultsForDelete.add(def.glAccountDefault);
            }
            else if (def.glAccount.Id != this.glAccountDefaultsById.get(def.glAccountDefault.Id).glAccount.Id) {
                GL_Account_Default__c selectedDefault = def.glAccountDefault;
                selectedDefault.GL_Account__c = def.glAccount.Id;
                defaultsForUpsert.add(selectedDefault);
            }
        }

        if (!defaultsForUpsert.isEmpty()) {
            results.addAll(upsertDefaults(defaultsForUpsert));
        }
        if (!defaultsForDelete.isEmpty()) {
            results.addAll(deleteDefaults(defaultsForDelete));
        }

        return results;
    }

    private List<ServiceResult> upsertDefaults(List<GL_Account_Default__c> defaultsForUpsert) {
        List<ServiceResult>  results = new List<ServiceResult>();
        List<Database.UpsertResult> upsertResults = SFDCSecurityUtils.upsertProxy(defaultsForUpsert, false);

        for (Integer i = 0; i < defaultsForUpsert.size(); i++) {
            Database.UpsertResult upsertResult = upsertResults.get(i);
            Id glAccountDefaultsId = (String) defaultsForUpsert.get(i).Id;
            if (upsertResult.isSuccess()) {
                results.add(new ServiceResult(glAccountDefaultsId, true));
            }
            else {
                Database.Error err = upsertResult.getErrors()[0];
                results.add(new ServiceResult(glAccountDefaultsId, err.statusCode.name(), err.message));
            }
        }
        return results;
    }

    private List<ServiceResult> deleteDefaults(List<GL_Account_Default__c> defaultsForDelete) {
        List<ServiceResult>  results = new List<ServiceResult>();
        List<Database.DeleteResult> deleteResults = SFDCSecurityUtils.deleteProxyDatabase(defaultsForDelete, false);

        for (Integer i = 0; i < defaultsForDelete.size(); i++) {
            Database.DeleteResult deleteResult = deleteResults.get(i);
            Id glAccountDefaultsId = (String) defaultsForDelete.get(i).Id;
            if (deleteResult.isSuccess()) {
                results.add(new ServiceResult(null, true));
            }
            else {
                Database.Error err = deleteResult.getErrors()[0];
                results.add(new ServiceResult(glAccountDefaultsId, err.statusCode.name(), err.message));
            }
        }
        return results;
    }

    private Map<String, GL_Account_Specification__mdt> hardcodedGLAccountSpecificationsByDevNames() {
        Set<String> allDefaultsSpecifications = new Set<String>(glAccountNameByDefaultsSpecifications.keySet());
        allDefaultsSpecifications.addAll(new Set<String>{CTA_GL_ACCOUNT, INVENTORY_VARIANCE_GL_ACCOUNT, DEFAULT_DEBIT_GL_ACCOUNT_EXPENSE});
        Map<String, GL_Account_Specification__mdt> glAccountSpecificationsByDevNames = new Map<String, GL_Account_Specification__mdt>();
        for (String specificationDevName : allDefaultsSpecifications) {
            glAccountSpecificationsByDevNames.put(specificationDevName, new GL_Account_Specification__mdt(
                    DeveloperName = specificationDevName
            ));
        }
        return glAccountSpecificationsByDevNames;
    }

    public List<GLAccountDefault> createGLAccountDefaults(Id ledgerId) {
        Set<String> allSpecifications = new Set<String>(glAccountNameByDefaultsSpecifications.keySet());
        allSpecifications.addAll(glAccountIdsByDefaultsSpecifications.keySet());
        if (glAccountSpecificationsByDevNames == null) {
            glAccountSpecificationsByDevNames =
                glAccountSpecificationsByDevNames(DomainUtils.glAccountSpecifications(allSpecifications));
            glAccountSpecificationsByDevNames = glAccountSpecificationsByDevNames == null || glAccountSpecificationsByDevNames.isEmpty()
                ? hardcodedGLAccountSpecificationsByDevNames() : glAccountSpecificationsByDevNames;
        }
        if (glAccountsForLedgerDefaultByName == null) {
            glAccountsForLedgerDefaultByName = glAccountsByName(DomainUtils.getGlAccountsByName(glAccountNameByDefaultsSpecifications.values()));
        }

        List<GLAccountDefault> glAccountDefaults = new List<GLAccountDefault>();

        for (String specification : allSpecifications) {
            if (glAccountSpecificationsByDevNames.containsKey(specification)
                && isLedgerTypeAllowed(ledgerId, specification)
                && (glAccountsForLedgerDefaultByName.get(glAccountNameByDefaultsSpecifications.get(specification)) != null
                    || glAccountIdsByDefaultsSpecifications.get(specification) != null)) {
                GLAccountDefault def = new GLAccountDefault();
                def.ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
                def.glAccount = glAccountsForLedgerDefaultByName.get(glAccountNameByDefaultsSpecifications.get(specification));
                def.glAccountSpecification = glAccountSpecificationsByDevNames.get(specification);
                def.glAccountDefault = new GL_Account_Default__c(
                    GL_Account__c = glAccountIdsByDefaultsSpecifications.get(specification) != null
                        ? glAccountIdsByDefaultsSpecifications.get(specification)
                        : glAccountsForLedgerDefaultByName.get(glAccountNameByDefaultsSpecifications.get(specification))?.Id,
                    GL_Account_Specification__c = glAccountSpecificationsByDevNames.get(specification).DeveloperName,
                    Ledger__c = ledgerId
                );
                glAccountDefaults.add(def);
            }

        }
        return glAccountDefaults;
    }

    private Boolean isLedgerTypeAllowed(Id ledgerId, String specification) {
        Boolean result = true;
        if ((LedgerHandler.isConsolidationLedger(LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId))
            || LedgerHandler.isEliminationLedger(LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId)))
            && !consolidationSpecifications.contains(specification)) {
            result = false;
        }
        return result;
    }

    private Map<String, GL_Account__c> glAccountsByName(List<GL_Account__c> glAccounts) {
        Map<String, GL_Account__c> result = new Map<String, GL_Account__c>();
        for (GL_Account__c glAccount : glAccounts) {
            result.put(glAccount.Name, glAccount);
        }
        return result;
    }

    public void setExistedGLAccountsFromSettings() {
        Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
        Set<String> allDefaultsSpecifications = new Set<String>(defaultGlAccountNameByDefaultsSpecifications.keySet());
        allDefaultsSpecifications.addAll(new Set<String>{CTA_GL_ACCOUNT, INVENTORY_VARIANCE_GL_ACCOUNT, DEFAULT_DEBIT_GL_ACCOUNT_EXPENSE});
        for (String fieldName : allDefaultsSpecifications) {
            if (acctSettings.getPopulatedFieldsAsMap().get(GlobalVariables.PACKAGE_QUALIFIER + fieldName + '__c') != null) {
                glAccountIdsByDefaultsSpecifications.put(fieldName, (Id) acctSettings.get(fieldName + '__c'));
            }
        }
    }

    public void setExistedGLAccountsFromDefaultLedger() {
        Id defaultLedgerId = LedgerHandler.getLedgerId();
        Map<String, GL_Account_Default__c> glAccountDefaultsBySpecNames =
                GLAccountDefaultsHandler.instance.glAccountDefaultsMapByLedgerIds.get(defaultLedgerId);
        if (glAccountDefaultsBySpecNames != null) {
            for (String specName : glAccountDefaultsBySpecNames.keySet()) {
                if (glAccountDefaultsBySpecNames.get(specName) != null) {
                    glAccountIdsByDefaultsSpecifications.put(specName, glAccountDefaultsBySpecNames.get(specName).GL_Account__c);
                }
            }
        }
    }

    public static Map<String, GL_Account_Specification__mdt> glAccountSpecificationsByDevNames(List<GL_Account_Specification__mdt> glAccountSpecifications) {
        Map<String, GL_Account_Specification__mdt> glAccountSpecificationsByDevNames = new Map<String, GL_Account_Specification__mdt>();
        for (GL_Account_Specification__mdt glAccountSpecification : glAccountSpecifications) {
            glAccountSpecificationsByDevNames.put(glAccountSpecification.DeveloperName, glAccountSpecification);
        }
        return glAccountSpecificationsByDevNames;
    }
}