public inherited sharing class AccountingSettingsActions {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER = GlobalVariables.AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER;    
    private static SchemaDescribe accountingSettingSchema = SchemaDescribe.getDescribe(Accounting_Settings__c.SObjectType);


    public static final String UPDATE_LEGACY_LEDGER_ERROR = Label.ERR_UPDATE_LEGACY_LEDGER;
    public static final String UPDATE_ARCHIVE_MONTH_OFFSET_ERROR = Label.ERR_UPDATE_ARCHIVE_MONTH_OFFSET;
    public static final String CONTACT_AS_SUPPORT = Label.INF_CONTACT_AS_SUPPORT;
    public static final String UPDATE_AVALARA_CONFIGURATION_ERROR = Label.ERR_UPDATE_FIELD;
    public static final String UNIQUE_GL_ACCOUNT_ERROR = Label.ERR_UNIQUE_GL_ACCOUNT;
    public static final String ON_INSERT_UNIQUE_GL_ACCOUNT_ERROR = Label.ERR_ON_INSERT_UNIQUE_GL_ACCOUNT;
    public static final String ON_INSERT_UNIQUE_AMORT_GL_ACCOUNT_ERROR = Label.ERR_ON_INSERT_UNIQUE_AMORT_GL_ACCOUNT;
    public static final String UNIQUE_AMORT_GL_ACCOUNT_ERROR = Label.ERR_UNIQUE_AMORT_GL_ACCOUNT_SUBSTITUTION;
    public static final String UNIQUE_DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT_ERROR = Label.ERR_ACCT_STNGS_DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT_UNIQUE;

    public static final String EXTRA_SETTINGS_ERROR = Label.ERR_ACCOUNTING_SETTINGS_RECORD_ONE_PER_ORG;
    @TestVisible
    private static final String AVAVAT_HLP_REQUIRED_ERROR = Label.ERR_AVAVAT_HLP_REQUIRED;
    @TestVisible
    private static final String AVALARA_GL_ACCOUNT_ERROR = Label.ERR_AVALARA_GL_ACCOUNT_TYPE;
    @TestVisible
    private static final List<String> nonUpdateAvalaraFields = new List<String>{
        PACKAGE_QUALIFIER + 'Enable_Avalara_Tax_Calculation__c',
        PACKAGE_QUALIFIER + 'Avalara_Production_Endpoint__c'
    };

    private static final Map<String, String> amortizationFields = new Map<String, String>{
        PACKAGE_QUALIFIER + 'Default_Debit_GL_Account_Revenue__c' => accountingSettingSchema.getField('Default_Debit_GL_Account_Revenue__c').getDescribe().getLabel(),
        PACKAGE_QUALIFIER + 'Default_Credit_GL_Account_Revenue__c' => accountingSettingSchema.getField('Default_Credit_GL_Account_Revenue__c').getDescribe().getLabel(),
        PACKAGE_QUALIFIER + 'Default_Debit_GL_Account_Expense__c' => accountingSettingSchema.getField('Default_Debit_GL_Account_Expense__c').getDescribe().getLabel(),
        PACKAGE_QUALIFIER + 'Default_Credit_GL_Account_Expense__c' => accountingSettingSchema.getField('Default_Credit_GL_Account_Expense__c').getDescribe().getLabel()
    };

    private static final Map<String, String> allowedSameGlAccount = new Map<String, String> {
        PACKAGE_QUALIFIER + 'Default_Project_Task_Labor_GL_Account__c' => PACKAGE_QUALIFIER + 'Labor_GL_Account__c'
    };

    public static Boolean isPreventUpdateOverride = false;
    public static Boolean skipAvalaraFieldsUpdateValidation = false;
    public static Boolean skipPreventUpdateInventoryValuationMethod = Test.isRunningTest() ? true : false;
    public static Boolean skipPreventUpdatePostSettingsValidations = Test.isRunningTest() ? true : false;
    public static Boolean skipPreventUpdatePostSettings = Test.isRunningTest() ? true : false;

    public static void checkProjectTaskLaborGLAccountUniqueness(List<Accounting_Settings__c> newSettings,
            Map<Id, Accounting_Settings__c> oldSettingsMap) {
        if (!isPreventUpdateOverride
                && String.isNotBlank(newSettings[0].Default_Project_Task_Labor_GL_Account__c)
                && newSettings[0].Default_Project_Task_Labor_GL_Account__c != oldSettingsMap.get(newSettings[0].Id).Default_Project_Task_Labor_GL_Account__c) {
            Set<String> specsWithUniqueGlAccount = new Set<String>(GLAccountDefaultActions.specsWithUniqueGlAccount);
            specsWithUniqueGlAccount.remove(GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT);
            if (GLAccountDefaultActions.allowedSameGlAccount.get(GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT) != null) {
                specsWithUniqueGlAccount.removeAll(GLAccountDefaultActions.allowedSameGlAccount.get(GLAccountDefaultsHandler.DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT));
            }
            List<GL_Account_Default__c> glAccountDefaults = DomainUtils.gLAccountDefaultsBySpecsAndLTypes(
                    specsWithUniqueGlAccount,
                    new Set<String>{ LedgerActions.LEDGER_TYPE_TRANSACTIONAL, LedgerActions.LEDGER_TYPE_BUDGET }
            );
            Map<Id, GL_Account_Default__c> glAccountDefaultsByGlAccountIds = new Map<Id, GL_Account_Default__c>();
            for (GL_Account_Default__c glAccountDefault : glAccountDefaults) {
                glAccountDefaultsByGlAccountIds.put(glAccountDefault.GL_Account__c, glAccountDefault);
            }
            if (glAccountDefaultsByGlAccountIds.get(newSettings[0].Default_Project_Task_Labor_GL_Account__c) != null) {
                GL_Account_Default__c glAccountDefault = glAccountDefaultsByGlAccountIds.get(newSettings[0].Default_Project_Task_Labor_GL_Account__c);
                List<GL_Account_Specification__mdt> specifications = DomainUtils.glAccountSpecifications(new Set<String>{ glAccountDefault.GL_Account_Specification__c });
                newSettings[0].Default_Project_Task_Labor_GL_Account__c.addError(String.format(UNIQUE_DEFAULT_PROJECT_TASK_LABOR_GL_ACCOUNT_ERROR, new List<String>{
                        !specifications.isEmpty() ? specifications[0].Label : glAccountDefault.GL_Account_Specification__c,
                        glAccountDefault.Ledger__r.Name
                }));
            }
        }
    }

    public static void preventUpdateLedgerSettings(List<Accounting_Settings__c> newSettings,
                                                    Map<Id, Accounting_Settings__c> oldSettingsMap) {

        if (!isPreventUpdateOverride) {
            for (Accounting_Settings__c newSetting : newSettings) {
                Accounting_Settings__c oldSetting = oldSettingsMap.get(newSetting.Id);
                if (oldSetting != NULL
                        && oldSetting.Ledger_Limit__c != NULL
                        && oldSetting.Ledger_Limit__c != newSetting.Ledger_Limit__c) {

                    newSetting.Ledger_Limit__c.addError(CONTACT_AS_SUPPORT);
                }
                if (oldSetting != NULL && oldSetting.Legacy_Default_Ledger__c != NULL
                        && oldSetting.Legacy_Default_Ledger__c != newSetting.Legacy_Default_Ledger__c) {

                    newSetting.Legacy_Default_Ledger__c.addError(CONTACT_AS_SUPPORT);
                }
            }
        }
    }

    public static void preventUpdateArchiveMonthOffset(List<Accounting_Settings__c> newSettings,
                                                        Map<Id, Accounting_Settings__c> oldSettingsMap) {

        if (!isPreventUpdateOverride) {
            for (Accounting_Settings__c newSetting : newSettings) {
                Accounting_Settings__c oldSetting = oldSettingsMap.get(newSetting.Id);
                if (oldSetting != NULL
                        && oldSetting.Archive_Month_Offset__c != NULL
                        && oldSetting.Archive_Month_Offset__c != newSetting.Archive_Month_Offset__c) {

                    newSetting.Archive_Month_Offset__c.addError(UPDATE_ARCHIVE_MONTH_OFFSET_ERROR);
                }
            }
        }
    }

    public static void preventEnableMultiCurrency(List<Accounting_Settings__c> newSettings,
                                                        Map<Id, Accounting_Settings__c> oldSettingsMap) {

        if (!isPreventUpdateOverride) {
            for (Accounting_Settings__c newSetting : newSettings) {
                Accounting_Settings__c oldSetting = oldSettingsMap.get(newSetting.Id);
                if (oldSettingsMap != NULL && newSetting.Enable_Multi_Currency__c != oldSetting.Enable_Multi_Currency__c) {
                    newSetting.Enable_Multi_Currency__c.addError(CONTACT_AS_SUPPORT);
                }
            }
        }
    }

    public static void preventEnableProductCosting(List<Accounting_Settings__c> newSettings,
                                                        Map<Id, Accounting_Settings__c> oldSettingsMap) {

        if (!isPreventUpdateOverride) {
            for (Accounting_Settings__c newSetting : newSettings) {
                Accounting_Settings__c oldSetting = oldSettingsMap.get(newSetting.Id);
                if (oldSettingsMap != NULL && newSetting.Enable_Product_Costing__c != oldSetting.Enable_Product_Costing__c) {
                    newSetting.Enable_Product_Costing__c.addError(CONTACT_AS_SUPPORT);
                }
            }
        }
    }

    public static void preventUpdateInventoryValuationMethod(List<Accounting_Settings__c> newSettings,
                                                             Map<Id, Accounting_Settings__c> oldSettingsMap) {

        if (!isPreventUpdateOverride && !skipPreventUpdateInventoryValuationMethod) {

            for (Accounting_Settings__c newSetting : newSettings) {
                Accounting_Settings__c oldSetting = oldSettingsMap.get(newSetting.Id);
                if (oldSetting.Inventory_Valuation_Method__c != newSetting.Inventory_Valuation_Method__c
                    && newSetting.Inventory_Valuation_Method__c != 'Average Cost') {
                    newSetting.Inventory_Valuation_Method__c.addError(CONTACT_AS_SUPPORT);
                }
            }
        }
    }

    public static void preventUpdatePostSettings(List<Accounting_Settings__c> newSettings,
                                                    Map<Id, Accounting_Settings__c> oldSettingsMap) {

        for (Accounting_Settings__c newSetting : newSettings) {
            Accounting_Settings__c oldSetting = oldSettingsMap != NULL ? oldSettingsMap.get(newSetting.Id) : NULL;
            if (!isPreventUpdateOverride && !skipPreventUpdatePostSettings
                && oldSetting != NULL && newSetting.Post_Settings__c != oldSetting.Post_Settings__c) {
                newSetting.Post_Settings__c.addError(CONTACT_AS_SUPPORT);
            }
            // Used by post install script to skip this block.
            else if (!skipPreventUpdatePostSettingsValidations) {
                if (AccountingSettingsHandler.isERPEnabled()
                    && newSetting.Post_Settings__c == HeaderLevelTaxConsts.HEADER_LEVEL_POST
                    && newSetting.Inventory_Valuation_Method__c != 'Average Cost') {
                    newSetting.Post_Settings__c.addError(HeaderLevelTaxConsts.HEADER_LEVEL_POSTING_SET_ERROR);
                }

                if (newSetting.Post_Settings__c != HeaderLevelTaxConsts.HEADER_LEVEL_POST
                    && AccountingSettingsHandler.isAvaVATReportingEnabled()) {
                    newSetting.Post_Settings__c.addError(AVAVAT_HLP_REQUIRED_ERROR);
                }
            }
        }
    }

    public static void preventUpdateAvalaraConfiguration(List<Accounting_Settings__c> newSettings,
                                                         Map<Id, Accounting_Settings__c> oldSettingsMap) {

        if (isPreventUpdateOverride) {
            return;
        }

        if (!skipAvalaraFieldsUpdateValidation) {
            for (Accounting_Settings__c newSetting : newSettings) {
                Accounting_Settings__c oldSetting = oldSettingsMap.get(newSetting.Id);
                for (String fieldName : nonUpdateAvalaraFields) {
                    if (oldSetting != NULL && oldSetting.get(fieldName) != newSetting.get(fieldName)) {
                        newSetting.addError(
                            String.format(
                                UPDATE_AVALARA_CONFIGURATION_ERROR,
                                new List<String>{
                                    FinancialSuiteUtils.formatFieldStrings(
                                        Accounting_Settings__c.SObjectType,
                                        new List<String>{fieldName}
                                    )
                                }
                            )
                        );
                    }
                }
            }
        }
    }

    public static void preventInsertSecondRecord(List<Accounting_Settings__c> newSettings) {
        if (!isPreventUpdateOverride) {
            if (newSettings.size() > 1 || AccountingSettingsHandler.getAccountingSettings().Id != NULL) {
                for (Accounting_Settings__c newSetting : newSettings) {
                    newSetting.addError(EXTRA_SETTINGS_ERROR);
                }
            }
        }
    }

    public static void validateAvaSalesTaxGLAccount(List<Accounting_Settings__c> newSettings) {
        if (!isPreventUpdateOverride) {
            Map<Id, GL_Account__c> glAccountMap = new Map<Id, GL_Account__c>();

            for (Accounting_Settings__c setting : newSettings) {
                glAccountMap.put(setting.Avalara_Sales_Tax_GL_Account__c, NULL);
            }

            glAccountMap = new Map<Id, GL_Account__c>(DomainUtils.getGlAccountsById(glAccountMap.keySet()));

            for (Accounting_Settings__c setting : newSettings) {
                Gl_Account__c taxGLAccount = glAccountMap.get(setting.Avalara_Sales_Tax_GL_Account__c);
                if (taxGLAccount != NULL
                        && (taxGLAccount.Type__c != 'Balance Sheet' || taxGLAccount.Sub_Type_1__c != 'Liabilities')) {

                    setting.Avalara_Sales_Tax_GL_Account__c.addError(AVALARA_GL_ACCOUNT_ERROR);
                }
            }
        }
    }

    public static void createLedgerCustomSettingsIfNotExist(List<Accounting_Settings__c> newSettings) {
        for (Accounting_Settings__c newSetting : newSettings) {
            Ledger_Custom_Settings__c ledgerSettings = Ledger_Custom_Settings__c.getOrgDefaults();
            if (ledgerSettings == NULL || String.isBlank(ledgerSettings.Ledger_Id__c)) {
                ledgerSettings = new Ledger_Custom_Settings__c(
                    Ledger_Id__c = newSetting.Default_Ledger__c
                );
                SFDCSecurityUtils.upsertCheckCRUDAndFLS(ledgerSettings, new List<String>());
            }
        }
    }

    public static void setRequiredFields(List<Accounting_Settings__c> newSettings) {
        for (Accounting_Settings__c setting : newSettings) {
            setting.Archive_Month_Offset__c = 15;
            setting.Ledger_Limit__c = 1;
            for (String fieldName : nonUpdateAvalaraFields) {
                setting.put(fieldName, false);
            }
        }
    }

    public static void updatePaymentProcessors(List<Accounting_Settings__c> newSettings){
        if (!isPreventUpdateOverride) {
            Set<Id> defaults = new Set<Id>();
            
            SObjectType t = Payment_Processor__c.getSObjectType();
            for (Accounting_Settings__c setting : newSettings) {
                if (FinancialSuiteUtils.isValidId(setting.Stripe_Connected_Account_Id__c, t)) {
                    defaults.add(setting.Stripe_Connected_Account_Id__c);
                }
            }

            List<Payment_Processor__c> processors = DomainUtils.getPaymentProcessorsForDefaultUpdate(defaults);
            for (Payment_Processor__c processor : processors) {
                processor.Global_Default_Payment_Processor__c = defaults.contains(processor.Id);
            }

            if (processors.isEmpty() == false) {
                SFDCSecurityUtils.updateProxy(processors);
            }
        }
    }

    public static void sendAccountingSettingInfo(List<Accounting_Settings__c> newSettings, Map<Id, Accounting_Settings__c> oldSettingsMap, TriggerOperation context) {
        List<Accounting_Settings__c> sendSettings = new List<Accounting_Settings__c>();
        for (Accounting_Settings__c newSetting : newSettings) {
            Accounting_Settings__c oldSetting = oldSettingsMap != null ? oldSettingsMap.get(newSetting.Id) : null;
            if (oldSetting == null ||
                (oldSetting != null
                && (oldSetting.Inventory_Valuation_Method__c != newSetting.Inventory_Valuation_Method__c
                || oldSetting.Post_Settings__c != newSetting.Post_Settings__c
                || oldSetting.Ledger_Limit__c != newSetting.Ledger_Limit__c
                || oldSetting.Enable_Multi_Currency__c != newSetting.Enable_Multi_Currency__c
                || oldSetting.Enable_Product_Costing__c != newSetting.Enable_Product_Costing__c))) {

                sendSettings.add(newSetting);
            }
        }

        if (!sendSettings.isEmpty()) {
            EnablementsQueueable enablementsJob = new EnablementsQueueable(context, sendSettings);
            System.enqueueJob(enablementsJob);
        }
    }

}