public with sharing class AccountingSettingsHelper {

    private static final String AJR_RETENTION_JOB_NAME = 'AJR Retention Job';
    private static final String AJR_RETENTION_SCHEDULER_CLASS = 'AutomatedJobResultsRetentionScheduler';
    private static final String AJR_RETENTION_JOB_CHRON_EXP = '0 0 {0} * * ?';
    private static final String AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER = GlobalVariables.AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER;
    private static final String STRIPE_URL = 'https://connect.stripe.com/oauth/authorize';

    @TestVisible
    private static Boolean overrideAvaVATReportingEnabled;
    private static Set<String> PAYMENT_LINK_PERMISSION_SETS = new Set<String>{'AS_Full_Admin', 'Accounting_Manager'};

    public with sharing class AccountingSettingsHelperException extends Exception{}

    /**
     * Returns accounting settings plus additional configuration info.
     * @return description of the orgs accounting configurations
     */
    @AuraEnabled(Cacheable=true)
    public static Map<String,Object> getConfigs() {
        try {
            Map<String,Object> configs = new Map<String,Object>{
                'enablements' => new Map<String,Boolean>{
                    'headerLevelPostEnabled' => AccountingSettingsHandler.isHeaderLevelPost(),
                    'productCostingEnabled'  => AccountingSettingsHandler.isProductCostingEnabled(),
                    'standardCostingEnabled' => AccountingSettingsHandler.isStandardCostProductCostingEnabled(),
                    'multiCurrencyEnabled'   => MultiCurrencyHandler.isMultiCurrencyEnabled,
                    'largeDataVolumeModeEnabled' => FeatureManagementHandler.isLargeDataVolumeModeEnabled()
                },
                'pkgs' => new Map<String,Object>{
                    'fs' => new Map<String,Object>{
                        'installed'  => true,
                        'qualifier'  => GlobalVariables.PACKAGE_QUALIFIER
                    },
                    'avaVAT'         => new Map<String,Object>{
                        'installed'  => AccountingSettingsHandler.isAvaVATInstalled(),
                        'qualifier'  => GlobalVariables.AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER
                    },
                    'erp'            => new Map<String,Object>{
                        'installed'  => AccountingSettingsHandler.isERPEnabled(),
                        'qualifier'  => GlobalVariables.ERPPACKAGE_QUALIFIER
                    },
                    'npsp'           => new Map<String,Object>{
                        'installed'  => AccountingSettingsHandler.isNPSPEnabled(),
                        'qualifier'  => GlobalVariables.NPSP_PACKAGE_QUALIFIER
                    }
                },
                'settings' => AccountingSettingsHandler.getAccountingSettings(),
                'jobs' => new Map<String,Object>{
                    'ajrRetentionJob' => new Map<String,Object>{
                        'nextFire' => getAJRRetentionJobScheduledTime()
                    }
                }
            };

            return configs;
        } 
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * Gets the accounting settings.
     * @return the `Accounting_Settings__c` record for the org
     */
    @AuraEnabled(Cacheable=true)
    public static Accounting_Settings__c getSettings() {
        try {
            return AccountingSettingsHandler.getAccountingSettings();
        } 
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * Used to save accounting settings and schedule the `AJR Retention Job`.
     * @param settings - the accounting settings to save.
     * @param ajrRetentionJobTime - the hour of the next fire time for `AJR Retention Job`.
     */
    @AuraEnabled
    public static void saveWithAJRRetentionJobTime(Accounting_Settings__c settings, String ajrRetentionJobTime) {
        try {
            Accounting_Settings__c newSettings = settings;
            Accounting_Settings__c oldSettings = AccountingSettingsHandler.getAccountingSettings();
            if (oldSettings == null) {
                oldSettings = new Accounting_Settings__c();
            }

            List<String> errors = new List<String>();

            Id prevDefaultLedgerId = oldSettings.Default_Ledger__c;
            if (prevDefaultLedgerId != null && prevDefaultLedgerId != newSettings.Default_Ledger__c) {
                try {
                    String queryCondition = 'Ledger__c = :prevDefaultLedgerId';
                    SOQLBuilder theQuery = new SOQLBuilder(Financial_Cube__c.SObjectType);
                    theQuery.setEnforceFLS(false).setCondition(queryCondition).setLimit(1);
                    Financial_Cube__c fc = (Financial_Cube__c) Database.query(theQuery.toSOQL());
                    if (fc != null) {
                        errors.add(Label.ERR_DEFAULT_LEDGER);
                    }
                }
                catch (QueryException ex) {}
            }
            
            if (AccountingSettingsHandler.isStandardCostProductCostingEnabled() 
                    && newSettings.Inventory_Variance_GL_Account__c == null) {
                errors.add(Label.ERR_INVENTORY_VARIANCE_GL_ACCOUNT);
            }
            
            if (AccountingSettingsHandler.isProductCostingEnabled() 
                    && newSettings.Vouchers_Payable_GL_Account__c == null) {
                errors.add(Label.ERR_VOUCHERS_PAYABLE_GL_ACCOUNT);
            }

            if (newSettings.Enable_Cash_Flow_Statement__c) {
                enableCashFlowStatement(newSettings);
                if (newSettings.Default_Cash_Receipt_Category__c == null
                        || newSettings.Default_Cash_Disbursement_Category__c == null
                        || newSettings.Default_Journal_Entry_Line_Category__c == null) {
                    errors.add(Label.ERR_DEFAULT_CASH_FLOW_CATEGORY_REQUIRED);
                }
            }

            if (newSettings.Enable_Avalara_Tax_Calculation__c) {
                if (String.isBlank(newSettings.Avalara_Account_Id__c)) {
                    errors.add(Label.ERR_AVATAX_ACCOUNT_ID_REQUIRED);
                }
                if (String.isBlank(newSettings.Avalara_License_Key__c)) {
                    errors.add(Label.ERR_AVATAX_LICENSE_KEY_REQUIRED);
                }
                if (String.isBlank(newSettings.Company_Code__c)) {
                    errors.add(Label.ERR_AVATAX_COMPANY_CODE_REQUIRED);
                }
                if (newSettings.Tax_Calculation_Mode__c == null) {
                    errors.add(Label.ERR_TAX_CALCULATION_MODE_REQUIRED);
                }
                if (newSettings.Avalara_Sales_Tax_GL_Account__c == null) {
                    errors.add(Label.ERR_AVALARA_GL_ACCOUNT_REQUIRED);
                }
                if (!isValidAvalaraProduct(newSettings)) {
                    errors.add(Label.ERR_AVALARA_TAX_PRODUCT_REQUIRED);
                }

                if (!isValidAvalaraOriginAddress(newSettings)) {
                    errors.add(Label.ERR_AVATAX_ADDRESS_REQUIRED);
                }

                if (!isValidCountryCode(newSettings.Country_Code__c)) {
                    errors.add(Label.ERR_AVATAX_COUNTRY_CODE_RESTRICTED);
                }
            }
            
            if (isAvalaraVATReportingEnabled(newSettings)) {
                if (overrideAvaVATReportingEnabled == true 
                        || String.isBlank((String) newSettings.get(AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER + 'Avalara_VAT_Reporting_Account_Id__c'))) {
                    errors.add(Label.ERR_AVAVAT_ACCOUNT_ID_REQUIRED);
                }
                if (overrideAvaVATReportingEnabled == true 
                        || String.isBlank((String) newSettings.get(AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER + 'Avalara_VAT_Reporting_License_Key__c'))) {
                    errors.add(Label.ERR_AVAVAT_LICENSE_KEY_REQUIRED);
                }
                if (newSettings.Post_Settings__c != HeaderLevelTaxConsts.HEADER_LEVEL_POST) {
                    errors.add(Label.ERR_AVAVAT_HLP_REQUIRED);
                }
            }

            if (newSettings.Automated_Job_Results_Retention_Days__c == null
                    || newSettings.Automated_Job_Results_Retention_Days__c < 1
                    || newSettings.Automated_Job_Results_Retention_Days__c > 365) {
                errors.add(String.format(Label.ERR_RANGE, new String[]{'1','365'}));
            }

            if (oldSettings.Enable_Retention_Period__c != newSettings.Enable_Retention_Period__c
                    || ajrRetentionJobTime != getAJRRetentionJobScheduledTime()) {
                runAJRRetentionPeriodJob(newSettings, ajrRetentionJobTime);
            }

            if (!errors.isEmpty()) {
                throw new AccountingSettingsHelperException(String.join(errors,' '));
            }

            if (oldSettings.Default_Ledger__c != newSettings.Default_Ledger__c) {
                Ledger_Custom_Settings__c ledgerSettings = Ledger_Custom_Settings__c.getOrgDefaults();
                ledgerSettings.Ledger_Id__c = newSettings.Default_Ledger__c;
                SFDCSecurityUtils.upsertCheckCRUDAndFLS(ledgerSettings, new List<String>());
            }

            if (newSettings.Id != null) {
                AccountingSettingsActions.skipAvalaraFieldsUpdateValidation = true;
                SFDCSecurityUtils.updateCheckCRUDAndFLS(newSettings, new List<String>());
                AccountingSettingsActions.skipAvalaraFieldsUpdateValidation = false;
            }
            else {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(newSettings, new List<String>());
            }
        }
        catch (AccountingSettingsHelperException e) {
            throw e;
        }
        catch (DmlException dmlEx) {
            throw new AccountingSettingsHelperException(dmlEx.getDmlMessage(0));
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * Saves the accounting settings.
     * @param settings - the settings to save.
     */
    @AuraEnabled
    public static void save(Accounting_Settings__c settings) {
        try {
            saveWithAJRRetentionJobTime(settings, getAJRRetentionJobScheduledTime());
        }
        catch (AccountingSettingsHelperException e) {
            throw e;
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    @AuraEnabled (Cacheable=true)
    public static List<Map<String, Object>> getLedgers() {
        try {
            List<Map<String, Object>> options = new List<Map<String, Object>>();
            List<SelectOption> selectOptions = LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgerSelectOptions();
            for (SelectOption so : selectOptions) {
                if (!LedgerHandler.getInstanceWithoutSharing().isShadowLedger(so.getValue())) {
                    options.add(new Map<String, Object> {
                        'label' => so.getLabel(),
                        'value' => so.getValue()
                    });
                }
            }
            return options;
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * Test connectivity with Avalara Tax.
     * @return {
     *           'authenticated' => Boolean,
     *           'authenticationType' => String,
     *           'authenticatedAccountId' => String,
     *           'version' => String
     *         }
     */
    @AuraEnabled
    public static Map<String,Object> pingAvaTax(String licenseId) {
        try {
            List<AvaTax_License__c> licenses = DomainUtils.getAvaTaxLicenses(new Set<Id>{licenseId});
            AvaTaxService.PingResultModel pingResult = (new AvaTaxService(
                    licenses[0].AvaTax_Account_ID__c,
                    licenses[0].AvaTax_License_Key__c,
                    licenses[0].Active_AvaTax_Endpoint__c == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT)).pingInst();
            return new Map<String,Object>{
                'authenticated' => pingResult.authenticated,
                'authenticationType' => pingResult.authenticationType,
                'authenticatedAccountId' => pingResult.authenticatedAccountId,
                'version' => pingResult.version
            };
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * Gets the available tax methods.
     * @return the list of available tax options
     */
    @AuraEnabled(Cacheable=true)
    public static List<AbstractLWCHelper.CustomSelectOption> getTaxCalculationOptions() {
        try {
            List<AbstractLWCHelper.CustomSelectOption> opts = new List<AbstractLWCHelper.CustomSelectOption>();
            opts.add(new AbstractLWCHelper.CustomSelectOption(
                Label.TAX_OPTION_NATIVE, Label.TAX_OPTION_NATIVE));
            opts.add(new AbstractLWCHelper.CustomSelectOption(
                Label.TAX_OPTION_AVATAX, Label.TAX_OPTION_AVATAX));
            if (AccountingSettingsHandler.isAvaVATInstalled()){
                opts.add(new AbstractLWCHelper.CustomSelectOption(
                    label.TAX_OPTION_AVAVAT, label.TAX_OPTION_AVAVAT));
            }
            return opts;
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * True if user has a permission set wich grants access to Stripe / Payment Link configuration page.
     * @return true if user has access, else false
     */
    @AuraEnabled
    public static Boolean userHasPaymentLinkAccess() {
        try {
            List<PermissionSetAssignment> permissionSetAssignments =
                DomainUtils.getPermissionSetAssignmentsByAssigneeAndName(
                    new Set<Id>{UserInfo.getUserId()},
                    PAYMENT_LINK_PERMISSION_SETS
                );

            return !permissionSetAssignments.isEmpty();
        }
        catch (Exception e) {
            return false;
        }
    }

    /**
     * Gets the available Avalara Tax endpoints.
     * @return the list of available endpoints
     */
    @AuraEnabled(Cacheable=true)
    public static List<AbstractLWCHelper.CustomSelectOption> getAvaTaxEndpointOptions() {
        try {
            return new List<AbstractLWCHelper.CustomSelectOption>{
                new AbstractLWCHelper.CustomSelectOption('false', Label.SANDBOX),
                new AbstractLWCHelper.CustomSelectOption('true', Label.PRODUCTION)
            };
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * Gets the available Avalara VAT endpoints.
     * @return the list of available endpoints
     */
    @AuraEnabled(Cacheable=true)
    public static List<AbstractLWCHelper.CustomSelectOption> getAvaVATEndpointOptions() {
        try {
            return new List<AbstractLWCHelper.CustomSelectOption>{
                new AbstractLWCHelper.CustomSelectOption('false',  Label.SANDBOX),
                new AbstractLWCHelper.CustomSelectOption('true', Label.PRODUCTION)
            };
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static List<AbstractLWCHelper.CustomSelectOption> getAvaVATLedgerCountryOptions() {
        try {
            List<AbstractLWCHelper.CustomSelectOption> pickListValuesList = new List<AbstractLWCHelper.CustomSelectOption>();
            if (AccountingSettingsHandler.isAvaVATInstalled()) {
                Map<String, Schema.SObjectField> field_map = Ledger__c.getSObjectType().getDescribe().fields.getMap();
                List<Schema.PicklistEntry> ple = field_map.get(AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER.toLowerCase() + 'vat_country__c').getDescribe().getPickListValues();
                for( Schema.PicklistEntry pickListVal : ple){
                    pickListValuesList.add(new AbstractLWCHelper.CustomSelectOption(pickListVal.getValue(),  pickListVal.getLabel()));
                }
            }
            return pickListValuesList;
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> saveLedgersWithDMLDetails(List<Ledger__c> ledgers) {
        return saveLedgers(ledgers, true);
    }
    
    /**
     * Updates the input ledgers.
     * @param ledgers to update
     */
    @AuraEnabled
    public static Map<String, Object> saveLedgers(List<Ledger__c> ledgers) {
        return saveLedgers(ledgers, false);
    }

    private static Map<String, Object> saveLedgers(List<Ledger__c> ledgers, Boolean needDMLError) {
        Map<String, Object> result = new Map<String, Object>{'status' => 'success'};
        try {
            SFDCSecurityUtils.updateCheckCRUDAndFLS(ledgers, new List<String>());
        } catch (DmlException e) {

            if (needDMLError) {
                List<Map<String, Object>> errors = new List<Map<String, Object>>();
                for (Integer index = 0; index < e.getNumDml(); index++) {
                    errors.add(new Map<String, Object>{
                            'id' => e.getDmlId(index),
                            'msg' => e.getDmlMessage(index),
                            'fields' => e.getDmlFieldNames(index)
                    });
                }
                result = new Map<String, Object>{
                        'status' => 'error',
                        'errors' => errors
                };
            } else {
                throw new AccountingSettingsHelperException(e.getDmlMessage(0));
            }
        } catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }

        return result;
    }
    /**
     * Gets all transactional type ledgers.
     * @return all transactional ledgers
     */
    @AuraEnabled(Cacheable=true)
    public static List<Ledger__c> getTransactionalLedgers() {
        try {
            return DomainUtils.getLedgerByType(new Set<String> {LedgerActions.LEDGER_TYPE_TRANSACTIONAL});
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    /**
     * Gets the PaymentLink authorization url, used for connecting Accounting Seed to PaymentLink.
     * @return the authorization url
     */
    @AuraEnabled(Cacheable=true)
    public static String getPaymentLinkAuthrizationURL() {
        try {
            External_Settings__mdt paymentLinkSettings = GlobalVariables.paymentLinkSettings;
            if (paymentLinkSettings == null) {
                return null;
            }
            return paymentLinkSettings.Value_1__c + '/auth/authorize?ref=' +
                EncodingUtil.urlEncode(URL.getOrgDomainUrl().toExternalForm(), 'UTF-8');
        }
        catch (Exception e) {
            throw new AccountingSettingsHelperException(e.getMessage());
        }
    }

    // ==============================
    // ========== HELPERS ===========
    // ==============================

    private static void enableCashFlowStatement(Accounting_Settings__c settings) {
        List<GL_Account__c> existedCashFlowCategories = DomainUtils.getCashFlowCategories();
        if (existedCashFlowCategories.isEmpty()) {
            List<GL_Account__c> cashFlowCategories = new List<GL_Account__c>();

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Receipts from customers',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Payments to suppliers',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Payments to employees',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Interest received',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Interest Paid',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Taxes Paid',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Other Operating',
                    Sub_Type_1__c = 'Operating',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Proceeds from sale of fixed assets',
                    Sub_Type_1__c = 'Investing',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Payment for fixed assets',
                    Sub_Type_1__c = 'Investing',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Other Investing',
                    Sub_Type_1__c = 'Investing',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Proceeds from issuance of debt',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Repayment of debt',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Proceeds from issuance of equity',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Distributions of equity',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );

            cashFlowCategories.add(
                new GL_Account__c(
                    Name = 'Other Financing',
                    Sub_Type_1__c = 'Financing',
                    Type__c = 'Cash Flow'
                )
            );

            SFDCSecurityUtils.insertProxy(cashFlowCategories);
        }

        List<GL_Account__c> defaultCFC;
        if (settings.Default_Cash_Receipt_Category__c == null) {
            defaultCFC = DomainUtils.getCashFlowCategoriesByName(new Set<String>{'Receipts from customers'});
            settings.Default_Cash_Receipt_Category__c = defaultCFC.isEmpty() ? null : defaultCFC[0].Id;
        }
        if (settings.Default_Cash_Disbursement_Category__c == null) {
            defaultCFC = DomainUtils.getCashFlowCategoriesByName(new Set<String>{'Payments to suppliers'});
            settings.Default_Cash_Disbursement_Category__c = defaultCFC.isEmpty() ? null : defaultCFC[0].Id;
        }
        if (settings.Default_Journal_Entry_Line_Category__c == null) {
            defaultCFC = DomainUtils.getCashFlowCategoriesByName(new Set<String>{'Payments to suppliers'});
            settings.Default_Journal_Entry_Line_Category__c = defaultCFC.isEmpty() ? null : defaultCFC[0].Id;
        }

        if (existedCashFlowCategories.isEmpty()) {
            Set<Id> ledgeIds = new Set<Id>();
            ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()).keySet());
            ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getBudgetLedgers()).keySet());
            GLAccount.createGLAccountDefaultsByLedger(ledgeIds, true);
        }
        else {
            List<GL_Account_Default__c> cfSpecs =  DomainUtils.gLAccountDefaultsBySpecification(GLAccountDefaultsHandler.instance.cashFlowSpecifications);
            for (GL_Account_Default__c cashFlowSpec : cfSpecs) {
                if (cashFlowSpec.GL_Account_Specification__c == 'Default_Cash_Receipt_Category') {
                    cashFlowSpec.GL_Account__c = settings.Default_Cash_Receipt_Category__c;
                }
                if (cashFlowSpec.GL_Account_Specification__c == 'Default_Cash_Disbursement_Category') {
                    cashFlowSpec.GL_Account__c = settings.Default_Cash_Disbursement_Category__c;
                }
                if (cashFlowSpec.GL_Account_Specification__c == 'Default_Journal_Entry_Line_Category') {
                    cashFlowSpec.GL_Account__c = settings.Default_Journal_Entry_Line_Category__c;
                }
            }

            SFDCSecurityUtils.updateProxy(cfSpecs);
        }
    }

    private static Boolean isValidAvalaraProduct(Accounting_Settings__c settings) {
        if (AccountingSettingsHandler.isHeaderLevelPost()) {
            return true;
        }
        else {
            if (settings.Avalara_Tax_Product__c == null) {
                return false;
            }
            return DomainUtils.countPricebookEntriesByProduct(new Set<Id>{settings.Avalara_Tax_Product__c}) > 0;
        }
    }

    private static Boolean isValidAvalaraOriginAddress(Accounting_Settings__c settings) {
        return !String.isBlank(settings.Street__c)
            && !String.isBlank(settings.City__c)
            && !String.isBlank(settings.Region__c)
            && !String.isBlank(settings.Country_Code__c);
    }

    private static Boolean isValidCountryCode(String countryCode) {
        return !String.isBlank(countryCode) && countryCode.equalsIgnoreCase('us');
    }

    private static Boolean isAvalaraVATReportingEnabled(Accounting_Settings__c settings) {
        return overrideAvaVATReportingEnabled == null 
            ? AccountingSettingsHandler.isAvaVATInstalled() && (Boolean) settings.get(AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER + 'Enable_Avalara_VAT_Reporting__c')
            : overrideAvaVATReportingEnabled; 
    }

    private static void runAJRRetentionPeriodJob(Accounting_Settings__c settings, String hour) {
        String cronTime = String.isBlank(hour) ? '0' : hour;
        String cronExp = String.format(AJR_RETENTION_JOB_CHRON_EXP, new String[]{cronTime});
        List<AsyncApexJob> retentionJobList = getRunningAJRRetentionPeriodJobs();

        if (settings.Enable_Retention_Period__c && retentionJobList.isEmpty()) {
            runAJRRetentionPeriodJob(cronExp);
        }
        else if (settings.Enable_Retention_Period__c && !retentionJobList.isEmpty()) {
            abortAJRRetentionPeriodJob();
            runAJRRetentionPeriodJob(cronExp);
        }
        else if (!settings.Enable_Retention_Period__c && !retentionJobList.isEmpty()) {
            abortAJRRetentionPeriodJob();
        }
    }

    private static void runAJRRetentionPeriodJob(String cronExp) {
        AutomatedJobResultsRetentionScheduler.startAutomatedJobResultsRetentionScheduler(cronExp, AJR_RETENTION_JOB_NAME);
    }

    private static void abortAJRRetentionPeriodJob() {
        List<CronTrigger> ct = DomainUtils.getCronTriggerByJobName(new Set<String> {AJR_RETENTION_JOB_NAME});
        if (!ct.isEmpty()) {
            System.abortJob(ct[0].Id);
        }
    }

    private static List<AsyncApexJob> getRunningAJRRetentionPeriodJobs() {
        List<AsyncApexJob> apexJobInAction = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            new Set<String> {AJR_RETENTION_SCHEDULER_CLASS}, GlobalVariables.APEX_JOB_STATUSES
        );
        return apexJobInAction;
    }

    private static String getAJRRetentionJobScheduledTime() {
        String result = '0';
        String nextFireTime;
        List<CronTrigger> ct = DomainUtils.getCronTriggerByJobName(new Set<String> {AJR_RETENTION_JOB_NAME});
        if (!ct.isEmpty() && ct[0].NextFireTime != NULL) {
            nextFireTime = ct[0].NextFireTime.format().substringAfter(' ');
        }
        for (Integer timeKey = 0; timeKey < 24; timeKey++) {
            if (DateTime.newInstance(2008, 12, 1, timeKey, 00, 0).format().substringAfter(' ') == nextFireTime) {
                result = String.valueOf(timeKey);
            }
        }
        return result;
    }

}