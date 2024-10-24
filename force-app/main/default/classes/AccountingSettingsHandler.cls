public without sharing class AccountingSettingsHandler {

    //this property will store Accounting Settings record till the end of transaction
    @TestVisible
    private static Accounting_Settings__c acctSeedSettings;
    @TestVisible
    private static Boolean isERPEnabled;
    private static Boolean isNPSPEnabled;
    private static Boolean isWOEnabled;
    private static Boolean isAvaVATInstalled;
    private static Boolean isFSLExtInstalled;
    private static Boolean isAvaVATReportingEnabled;
    private static String AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER = GlobalVariables.AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER;
    private static String FSL_EXT_PACKAGE_QUALIFIER = GlobalVariables.FSL_EXT_PACKAGE_QUALIFIER;
    @TestVisible
    private static String AMOUNT_VALUE = 'Amount';
    @TestVisible
    private static String QUANTITY_VALUE = 'Quantity';
    
    /*
    * Use this static method to Read settings from the Accounting Settings record
    * This is safe for using many time per transaction,
    * so feel free to call it inside loops, etc
     */
    public static Accounting_Settings__c getAccountingSettings() {
        if (acctSeedSettings == NULL) {
            acctSeedSettings = queryAccountingSettings();
        }
        return acctSeedSettings;
    }

    public static Boolean isERPEnabled() {
        if (isERPEnabled == NULL) {
            isERPEnabled = (System.Type.forName('AcctSeedERP__Inventory_Balance__c') != NULL || System.Type.forName('Inventory_Balance__c') != NULL);
        }
        return isERPEnabled;
    }

    public static Boolean isAvaVATInstalled() {
        if (isAvaVATInstalled == NULL) {
            isAvaVATInstalled = doAvaVATFieldsExist();
        }
        return isAvaVATInstalled;
    }

    public static Boolean doAvaVATFieldsExist() {
        Set<String> objectFields = Schema.SObjectType.Accounting_Settings__c.fields.getMap().keySet();
        return objectFields.contains(AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER.toLowerCase() + 'avalara_vat_reporting_account_id__c');                
    }

    public static Boolean isNPSPEnabled() {
        if (isNPSPEnabled == NULL) {
            isNPSPEnabled = Type.forName('NPSP', 'Allocation__c') != NULL;
        }
        return isNPSPEnabled;
    }

    public static Boolean isFSLExtensionInstalled() {
        if (isFSLExtInstalled == NULL) {
            Set<String> billingFields = Schema.SObjectType.Billing__c.fields.getMap().keySet();
            isFSLExtInstalled = billingFields.contains(FSL_EXT_PACKAGE_QUALIFIER.toLowerCase() + 'work_order__c');
        }
        return isFSLExtInstalled;
    }

    public static Boolean isFSLExtensionEnabled() {
        return isWOEnabled() && isFSLExtensionInstalled();
    }

    @TestVisible
    private static void setIsERPEnabled(Boolean setERPEnabled) {
        isERPEnabled = setERPEnabled;
    }

    @TestVisible
    private static void setIsNPSPEnabled(Boolean setNPSPEnabled) {
        isNPSPEnabled = setNPSPEnabled;
    }

    @TestVisible
    private static void setIsAvaVATInstalled(Boolean setAvaVATEnabled) {
        isAvaVATInstalled = setAvaVATEnabled;        
    }

    @TestVisible
    private static void setIsAvaVATReportingEnabled(Boolean setAvaVATReportingEnabled) {
        isAvaVATReportingEnabled = setAvaVATReportingEnabled;
    }

    @TestVisible
    private static void setIsFSLExtensionInstalled(Boolean setFSLExtInstalled) {
        isFSLExtInstalled = setFSLExtInstalled;        
    }

    @TestVisible
    private static void setIsWOEnabled(Boolean setWOEnabled) {
        isWOEnabled = setWOEnabled;        
    }

    public static Boolean isWOEnabled() {
        if (isWOEnabled == NULL) {
            isWOEnabled = (System.Type.forName('WorkOrder') != NULL);
        }
        return isWOEnabled;
    }

    //If Accounting Settings record was not queried before during the current transaction lifetime,
    //this method will dynamically query Accounting Settings record with all fields existed in Accounting_Settings__c object
    private static Accounting_Settings__c queryAccountingSettings() {
        Accounting_Settings__c result;

        try {
            List<Accounting_Settings__c> settings = DomainUtils.getAccountingSettings();
            result = settings[0];
        }
        catch (Exception ex) {
            result = new Accounting_Settings__c();
        }

        return result;
    }

    public static void resetAccountingSettings() {
        AccountingSettingsHandler.acctSeedSettings = NULL;
    }

    public static Boolean isProductCostingEnabled() {
        return (isInventoryValuationStandardCost() && getAccountingSettings().Enable_Product_Costing__c)
                    || (isInventoryValuationAverageCost() && isERPEnabled());
    }

    public static Boolean isStandardCostProductCostingEnabled() {
        return (isInventoryValuationStandardCost() && getAccountingSettings().Enable_Product_Costing__c);
    }

    public static void setEnableProductCosting(Boolean value) {
        getAccountingSettings();
        acctSeedSettings.Enable_Product_Costing__c = value;
        AccountingSettingsActions.isPreventUpdateOverride = true;
        SFDCSecurityUtils.updateProxy(acctSeedSettings);
        AccountingSettingsActions.isPreventUpdateOverride = false;
        getAccountingSettings();
    }

    public static Boolean isInventoryValuationAverageCost() {
        return getAccountingSettings().Inventory_Valuation_Method__c == 'Average Cost';
    }

    public static Boolean isInventoryValuationStandardCost() {
        return getAccountingSettings().Inventory_Valuation_Method__c == 'Standard Cost';
    }

    public static Boolean isHeaderLevelPost() {
        return getAccountingSettings().Post_Settings__c == HeaderLevelTaxConsts.HEADER_LEVEL_POST;
    }

    public static Boolean isLineLevelPost() {
        return getAccountingSettings().Post_Settings__c == HeaderLevelTaxConsts.LINE_LEVEL_POST;
    }

    public static Boolean isAvalaraTaxCalculationEnabled() {
        return getAccountingSettings().Enable_Avalara_Tax_Calculation__c;
    }

    public static Boolean isAvaVATReportingEnabled() {
        Boolean retVal = false;
        if (isAvaVATReportingEnabled != NULL) {
            return isAvaVATReportingEnabled;
        }
        if (isAvaVATInstalled() && doAvaVATFieldsExist()) {
            String fieldName = AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER + 'Enable_Avalara_VAT_Reporting__c';
            retVal = getAccountingSettings().get(fieldName) != NULL ? (Boolean) getAccountingSettings().get(fieldName) : retVal;
        }
        return retVal;
    }

    public static Boolean isAutoPostCashReceiptsEnabled() {
        return getAccountingSettings().Auto_Post_Cash_Receipts__c;
    }

    public static Boolean isAutoPostBillingCashReceiptsEnabled() {
        return getAccountingSettings().Auto_Post_Billing_Cash_Receipts__c;
    }

    public static Boolean isAutoPostAmortizationEntriesEnabled() {
        return getAccountingSettings().Auto_Post_Amortization_Entries__c;
    }

    public static Boolean isAutoPostAPDisbursementsEnabled() {
        return getAccountingSettings().Auto_Post_AP_Disbursements__c;
    }
    
    public static Object fetchAccountingSettingsValue(SObjectField field) {
        return getAccountingSettings().get(field);
    }

    public static Boolean isEmailConfirmationsDisabled() {
        return getAccountingSettings().Disable_Email_Confirmations__c;
    }

    @TestVisible
    private static void setEmailConfirmationsDisabled(Boolean value) {
        getAccountingSettings().Disable_Email_Confirmations__c = value;
        updateSettingsAndReset();
    }

    public static Decimal getAutomatedJobResultsRetentionDays() {
        return getAccountingSettings().Automated_Job_Results_Retention_Days__c;
    }

    public static Boolean isEnableRetentionPeriod() {
        return getAccountingSettings().Enable_Retention_Period__c;
    }

    //====== Bank Transaction Automation related methods ====================
    public static Boolean isGlobalAutomatedMatchEnabled() {
        return getAccountingSettings().Enable_Global_Automated_Match__c;
    }
    @TestVisible
    private static void setGlobalAutomatedMatch(Boolean value) {
        getAccountingSettings().Enable_Global_Automated_Match__c = value;
        updateSettingsAndReset();
    }

    public static Boolean isGlobalAutomatedAddEnabled() {
        return getAccountingSettings().Enable_Global_Automated_Add__c;
    }
    @TestVisible
    private static void setGlobalAutomatedAdd(Boolean value) {
        getAccountingSettings().Enable_Global_Automated_Add__c = value;
        updateSettingsAndReset();
    }

    public static Decimal getCashInDefaultMatchingSetting() {
        return getAccountingSettings().Cash_In_Default_Matching_Setting__c;
    }
    @TestVisible
    private static void setCashInDefaultMatchingSetting(Integer value) {
        getAccountingSettings().Cash_In_Default_Matching_Setting__c = value;
        updateSettingsAndReset();
    }

    public static Decimal getCashOutDefaultMatchingSetting() {
        return getAccountingSettings().Cash_Out_Default_Matching_Setting__c;
    }
    @TestVisible
    private static void setCashOutDefaultMatchingSetting(Integer value) {
        getAccountingSettings().Cash_Out_Default_Matching_Setting__c = value;
        updateSettingsAndReset();
    }

    public static String getCashInDefaultSourceRecordType() {
        return getAccountingSettings().Cash_In_Default_Source_Record_Type__c;
    }
    @TestVisible
    private static void setCashInDefaultSourceRecordType(String value) {
        getAccountingSettings().Cash_In_Default_Source_Record_Type__c = value;
        updateSettingsAndReset();
    }

    public static String getCashOutDefaultSourceRecordType() {
        return getAccountingSettings().Cash_Out_Default_Source_Record_Type__c;
    }
    @TestVisible
    private static void setCashOutDefaultSourceRecordType(String value) {
        getAccountingSettings().Cash_Out_Default_Source_Record_Type__c = value;
        updateSettingsAndReset();
    }
    //==========================================================================

    public static void updateSettingsAndReset() {
        AccountingSettingsActions.isPreventUpdateOverride = true;
        SFDCSecurityUtils.updateProxy(getAccountingSettings());
        AccountingSettingsActions.isPreventUpdateOverride = false;
        resetAccountingSettings();
        getAccountingSettings();
    }

    private static void setInventoryValuation(String valuationMethod) {
        getAccountingSettings().Inventory_Valuation_Method__c = valuationMethod;
        updateSettingsAndReset();
    }

    private static void setPostSettings(String postSettings) {
        getAccountingSettings().Post_Settings__c = postSettings;
        updateSettingsAndReset();
    }

    public static void setHeaderLevelPost() {
        setPostSettings(HeaderLevelTaxConsts.HEADER_LEVEL_POST);
    }

    public static void setLineLevelPost() {
        setPostSettings(HeaderLevelTaxConsts.LINE_LEVEL_POST);
    }

    public static void setInventoryValuationStandardCost() {
        setInventoryValuation('Standard Cost');
    }

    public static void setInventoryValuationAverageCost() {
        setInventoryValuation('Average Cost');
    }

    public static void setAutoPostSourceDocuments(Boolean autoPostValue) {
        getAccountingSettings().Auto_Post_Cash_Receipts__c = autoPostValue;
        getAccountingSettings().Auto_Post_Billing_Cash_Receipts__c = autoPostValue;
        getAccountingSettings().Auto_Post_Amortization_Entries__c = autoPostValue;
        getAccountingSettings().Auto_Post_AP_Disbursements__c = autoPostValue;
        updateSettingsAndReset();
    }

    public static void setAutoPostSourceDocuments(SObjectField field, Boolean autoPostValue) {
        getAccountingSettings().put(field, autoPostValue);
        updateSettingsAndReset();
    }

    public static Boolean isCreditMemoDefaultAmount() {
        return getAccountingSettings().Credit_Memo_Default__c == AMOUNT_VALUE;
    }

    public static Boolean isCreditMemoDefaultQuantity() {
        return getAccountingSettings().Credit_Memo_Default__c == QUANTITY_VALUE;
    }

    public static void setCreditMemoDefault(String creditMemoDefaultValue) {
        getAccountingSettings().Credit_Memo_Default__c = creditMemoDefaultValue;
        updateSettingsAndReset();
    }

    public static Boolean isAutoClearJobDisabled() {
        return getAccountingSettings().Disable_Auto_Clear_job__c;
    }

}