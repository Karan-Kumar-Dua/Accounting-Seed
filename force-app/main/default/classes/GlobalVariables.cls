public without sharing class GlobalVariables {
    
    public static String PACKAGE_QUALIFIER {
        get {
            if (System.Type.forName('AcctSeed__Billing__c') != NULL) {
                return 'AcctSeed__';
            }
            else {
                return '';
            }
        }
        private set;
    }

    public static String PACKAGE_NAME {
        get {
            return PACKAGE_QUALIFIER.replaceAll('_','');
        }
        private set;
    }

    public static String ERPPACKAGE_QUALIFIER {
        get {
            if (System.Type.forName('AcctSeedERP__Shipment__c') != NULL) {
                return 'AcctSeedERP__';
            }
            else {
                return '';
            }
        }
        private set;
    }

    public static String NPSP_PACKAGE_QUALIFIER {
        get {
            if (System.Type.forName('npsp__Allocation__c') != NULL) {
                return 'npsp__';
            }
            else {
                return '';
            }
        }
        private set;
    }

    public static String AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER {
        get {
            Set<String> objectFields = Schema.SObjectType.Accounting_Settings__c.fields.getMap().keySet();
            if (objectFields.contains('acctseedext__avalara_vat_reporting_account_id__c')) {
                return 'AcctSeedExt__';                
            }
            else {
                return '';
            }
        }
        private set;
    }

    public static String FSL_EXT_PACKAGE_QUALIFIER {
        get {
            Set<String> billingFields = Schema.SObjectType.Billing__c.fields.getMap().keySet();
            if (billingFields.contains('acctseedext__work_order__c')) {
                return 'AcctSeedExt__';                
            }
            else {
                return '';
            }
        }
        private set;
    }

    public static Boolean isContactsToMultipleAccountsEnabled {
        get {
            if (isContactsToMultipleAccountsEnabled == NULL) {
                isContactsToMultipleAccountsEnabled = (Schema.getGlobalDescribe().get('AccountContactRelation') != NULL);
            }
            return isContactsToMultipleAccountsEnabled;
        }
        private set;
    }

    public static Boolean isPersonAccountEnabled {
        get {
            if (isPersonAccountEnabled == NULL) {
                isPersonAccountEnabled = (Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount'));
            }
            return isPersonAccountEnabled;
        }
        private set;
    }

    public static Boolean isMyDomainEnabled {
        get {
            String hostUrl = URL.getOrgDomainUrl().getHost();
            return hostUrl.endsWith('my.salesforce.com') || hostUrl.contains('--');
        }
        private set;
    }

    public static External_Settings__mdt ledSettings {
        get {
            if (ledSettings == NULL) {
                try {
                    ledSettings = DomainUtils.getExternalSettingsByName('LED_Settings');
                    return ledSettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return ledSettings;
            }
        }
        private set;
    }

    public static External_Settings__mdt stripeSettings {
        get {
            if (stripeSettings == NULL) {
                try {
                    stripeSettings = DomainUtils.getExternalSettingsByName('Stripe_Settings');
                    return stripeSettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return stripeSettings;
            }
        }
        private set;
    }

    public static External_Settings__mdt stripeTestSettings {
        get {
            if (stripeTestSettings == NULL) {
                try {
                    stripeTestSettings = DomainUtils.getExternalSettingsByName('Stripe_Test_Settings');
                    return stripeTestSettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return stripeTestSettings;
            }
        }
        private set;
    }

    public static External_Settings__mdt fastLinkSettings {
        get {
            if (fastLinkSettings == NULL) {
                try {
                    fastLinkSettings = DomainUtils.getExternalSettingsByName('FastLink_Settings');
                    return fastLinkSettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return fastLinkSettings;
            }
        }
        private set;
    }

    public static External_Settings__mdt avaTaxSettings {
        get {
            if (avaTaxSettings == NULL) {
                try {
                    avaTaxSettings = DomainUtils.getExternalSettingsByName('Avalara_Settings');
                    return avaTaxSettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return avaTaxSettings;
            }
        }
        private set;
    }

    public static String AVALARA_REST_ENDPOINT {
        get {
            String result;
            Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
            if (main.Avalara_Production_Endpoint__c) {
                result = avaTaxSettings.Value_3__c;
            }
            else {
                result = avaTaxSettings.Value_1__c;
            }
            return result;
        }
        private set;
    }

    public static String AVALARA_REST_ENDPOINT(Boolean isProduction) {
        return isProduction ? avaTaxSettings.Value_3__c : avaTaxSettings.Value_1__c;
    }

    public static String AVALARA_SITE_URL(Boolean isProduction) {
        return isProduction ? avaTaxSettings.Value_4__c : avaTaxSettings.Value_2__c;
    }

    public static External_Settings__mdt paymentLinkSettings {
        get {
            if (paymentLinkSettings == NULL) {
                try {
                    paymentLinkSettings = DomainUtils.getExternalSettingsByName('Payment_Link_Settings');
                    return paymentLinkSettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return paymentLinkSettings;
            }
        }
        private set;
    }

    public static External_Settings__mdt acctSecuritySettings {
        get {
            if (acctSecuritySettings == NULL) {
                try {
                    acctSecuritySettings = DomainUtils.getExternalSettingsByName('Accounting_Security_Settings');
                    return acctSecuritySettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return acctSecuritySettings;
            }
        }
        private set;
    }

    private static External_Settings__mdt transactionSecuritySettings {
        get {
            if (transactionSecuritySettings == NULL) {
                try {
                    transactionSecuritySettings = DomainUtils.getExternalSettingsByName('Transaction_Settings');
                    return transactionSecuritySettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return transactionSecuritySettings;
            }
        }
        private set;
    }

    public static List<Binding__mdt> abstractAmortizationBindings {
        get {
            if (abstractAmortizationBindings == NULL) {
                try {
                    abstractAmortizationBindings = DomainUtils.getBindingsByType(AmortizationMethodFactory.AMORTIZATION_TYPE_BINDING);
                    return abstractAmortizationBindings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return abstractAmortizationBindings;
            }
        }
        private set;
    }
    public static External_Settings__mdt cardknoxSettings {
        get {
            if (cardknoxSettings == NULL) {
                try {
                    cardknoxSettings = DomainUtils.getExternalSettingsByName('Cardknox_Settings');
                    return cardknoxSettings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return cardknoxSettings;
            }
        }
        private set;
    }

    public static External_Settings__mdt AccountingSeedHubSettings {
        get {
            if (AccountingSeedHubSettings == NULL) {
                try {
                    AccountingSeedHubSettings = DomainUtils.getExternalSettingsByName('Accounting_Seed_Hub_settings');
                    return AccountingSeedHubSettings;
                }
                catch (Exception ex) {
                    throw ex;
                }
            }
            else {
                return AccountingSeedHubSettings;
            }
        }
        private set;
    }

    public static List<BDC_Binding__c> abstractBDCBindings {
        get {
            if (abstractBDCBindings == NULL) {
                try {
                    abstractBDCBindings = DomainUtils.getAllBDCBindings();
                    return abstractBDCBindings;
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            else {
                return abstractBDCBindings;
            }
        }
        private set;
    }
    

    public static final String TRANSACTION_CREATE_KEY = transactionSecuritySettings.Value_1__c;
    public static final String TRANSACTION_UPDATE_DELETE_KEY = transactionSecuritySettings.Value_2__c;
    public static final String UNIVERSAL_AUTH_KEY = acctSecuritySettings.Value_1__c;
    public static final String FORCE_MATCH_PERMISSION_KEY = acctSecuritySettings.Value_2__c;
    public static final String PACKAGE_RELEASE_VERSION_NAME = 'Magnolia';

    public static final Set<String> APEX_JOB_STATUSES = new Set<String>{
        'Queued', 'Processing', 'Preparing', 'Holding'
    };

    public static final String APEX_URL_PATH = '/apex/';

}