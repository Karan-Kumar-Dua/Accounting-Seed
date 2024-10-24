public with sharing class TaxService {

    public static final String KB_LEDGER_DEFAULTS_URL = '<a href="https://support.accountingseed.com/hc/en-us/articles/4412638009747" target="_blank">Multi Ledger Defaults</a>';
    public static final String TAB_DEFAULTS_URL = '<a href="/lightning/n/' + GlobalVariables.PACKAGE_QUALIFIER + 'Multi_Ledger_Defaults" target="_blank">Multi Ledger Defaults</a>';

    private static Map<SObjectType, SObjectField> ledgerFieldsByObjectTypes = new Map<SObjectType, SObjectField>{
        Billing__c.getSObjectType() => Billing__c.Ledger__c,
        Account_Payable__c.getSObjectType() => Account_Payable__c.Ledger__c,
        Recurring_Billing__c.getSObjectType() => Recurring_Billing__c.Ledger__c,
        Recurring_Account_Payable__c.getSObjectType() => Recurring_Account_Payable__c.Ledger__c
    };

    private static Map<SObjectType, SObjectField> parentObjectByObjectTypes = new Map<SObjectType, SObjectField>{
        Billing_Line__c.getSObjectType() => Billing_Line__c.Billing__c,
        Account_Payable_Line__c.getSObjectType() => Account_Payable_Line__c.Account_Payable__c,
        Recurring_Billing_Line__c.getSObjectType() => Recurring_Billing_Line__c.Recurring_Billing__c,
        Recurring_Account_Payable_Line__c.getSObjectType() => Recurring_Account_Payable_Line__c.Recurring_Account_Payable__c
    };

    private static Map<SObjectType, SObjectField> parenLedgerFieldsByObjectTypes = new Map<SObjectType, SObjectField>{
        Billing_Line__c.getSObjectType() => Billing__c.Ledger__c,
        Account_Payable_Line__c.getSObjectType() => Account_Payable__c.Ledger__c,
        Recurring_Billing_Line__c.getSObjectType() => Recurring_Billing__c.Ledger__c,
        Recurring_Account_Payable_Line__c.getSObjectType() => Recurring_Account_Payable__c.Ledger__c
    };

    public static Map<Id, Map<String, Object>> previewParamsByIds;

    public static Map<Id, SObject> parentSObjectById;
    public static Map<SObject, Id> sobjectByLedgerId;
    private static Map<Id, TaxSetting> taxSettingsByLedgerIds;

    // use for source records without Ledger (ex. Opportunity)
    public static List<TaxServiceResult> calcTaxes(Map<SObject, Id> sourceDocsByLedger) {
        sobjectByLedgerId = sourceDocsByLedger;
        return calcTaxes(new List<SObject> (sourceDocsByLedger.keySet()));
    }

    public static List<TaxServiceResult> calcTaxes(Map<SObject, Id> sourceDocsByLedger, Map<Id, Map<String, Object>> previewParamsByIds) {
        TaxService.previewParamsByIds = previewParamsByIds;
        return calcTaxes(sourceDocsByLedger);
    }

    public static List<TaxServiceResult> calcTaxes(List<SObject> sourceDocs) {
        List<TaxServiceResult> results = new List<TaxServiceResult>();
        Map<Id, List<Sobject>> sourceByTaxSettingId = getSobjectMapByTaxSettingsIds(sourceDocs);
        Map<Id, AbstractTaxService> taxServices = TaxServiceFactory.getTaxMethod(sourceByTaxSettingId.keySet());
        for (Id taxSetting : sourceByTaxSettingId.keySet()) {
            if (taxServices.containsKey(taxSetting) && taxServices.get(taxSetting) != null) {
                results.add(taxServices.get(taxSetting).calcTaxes(sourceByTaxSettingId.get(taxSetting)));
            }
            else {
                results.add(setInvalidTaxSettingMethod(sourceByTaxSettingId.get(taxSetting)));
            }
        }
        return results;
    }

    // trigger version of calcTaxes
    public static List<TaxServiceResult> calcTaxes(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        List<TaxServiceResult> results = new List<TaxServiceResult>();
        Map<Id, List<Sobject>> sourceByTaxSettingId = getSobjectMapByTaxSettingsIds(sourceDocs);
        Map<Id, AbstractTaxService> taxServices = TaxServiceFactory.getTaxMethod(sourceByTaxSettingId.keySet());
        for (Id taxSetting : sourceByTaxSettingId.keySet()) {
            if (taxServices.containsKey(taxSetting) && taxServices.get(taxSetting) != null) {
                results.add(taxServices.get(taxSetting).calcTaxes(sourceByTaxSettingId.get(taxSetting), sourceDocsMap));
            }
            else {
                results.add(setInvalidTaxSettingMethod(sourceByTaxSettingId.get(taxSetting)));
            }
        }
        return results;
    }

    // trigger validation for calcTaxes
    public static List<TaxServiceResult> validate(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        List<TaxServiceResult> results = new List<TaxServiceResult>();
        Map<Id, List<Sobject>> sourceByTaxSettingId = getSobjectMapByTaxSettingsIds(sourceDocs);
        Map<Id, AbstractTaxService> taxServices = TaxServiceFactory.getTaxMethod(sourceByTaxSettingId.keySet());
        for (Id taxSetting : sourceByTaxSettingId.keySet()) {
            if (taxServices.containsKey(taxSetting) && taxServices.get(taxSetting) != null) {
                results.add(taxServices.get(taxSetting).validate(sourceByTaxSettingId.get(taxSetting), sourceDocsMap));
            }
            else {
                results.add(setInvalidTaxSettingMethod(sourceByTaxSettingId.get(taxSetting)));
            }
        }
        return results;
    }

    private static TaxServiceResult setInvalidTaxSettingMethod(List<SObject> sourceDocs) {
        TaxServiceResult faultResult = new TaxServiceResult();
        for (SObject obj : sourceDocs) {
            TaxServiceResult.TaxServiceResultLine line = new TaxServiceResult.TaxServiceResultLine();
            line.isSuccess = false;
            line.sourceObj = obj;
            line.errors.add(Label.ERR_NOT_VALID_TAX_SETTING_METHOD);
            faultResult.sourceDocs.add(line);
        }
        return faultResult;
    }

    public static String getNoTaxSettingErrorMessage(Boolean hideLink) {
        return String.format(
            Label.ERR_NO_LEDGER_TAX_SETTINGS,
            new List<String>{
                isAsynchronousContext() || hideLink ? Label.MULTI_LEDGER_DEFAULTS_TITLE : TAB_DEFAULTS_URL,
                isAsynchronousContext() || hideLink ? Label.MULTI_LEDGER_DEFAULTS_TITLE : KB_LEDGER_DEFAULTS_URL
            }
        );
    }

    private static Boolean isAsynchronousContext() {
        return System.isBatch() || System.isScheduled() || System.isQueueable();
    }

    public static Map<Id, TaxSetting> getTaxSettings() {
        if (taxSettingsByLedgerIds == null) {
            taxSettingsByLedgerIds = new Map<Id, TaxService.TaxSetting>();
            LedgerHandler ledgerHandlerInstance = LedgerHandler.getInstanceWithoutSharing();
            Map<Id, Id> taxSettingIdsByLedgerIds = new Map<Id, Id>();
            for (Ledger__c ledger : ledgerHandlerInstance.getAllLedgers()) {
                taxSettingIdsByLedgerIds.put(ledger.Id, ledger.Tax_Settings__c);
            }

            Map<Id, Tax_Settings__c> taxSettingsByIds = new Map<Id, Tax_Settings__c>(DomainUtils.getTaxSettingsByIds(
                    new Set<Id>(taxSettingIdsByLedgerIds.values())
            ));
            for (Id ledgerId : taxSettingIdsByLedgerIds.keySet()) {
                Tax_Settings__c  taxSetting = taxSettingsByIds.get(taxSettingIdsByLedgerIds.get(ledgerId));
                if (taxSetting != null) {
                    taxSettingsByLedgerIds.put(ledgerId, new TaxSetting(taxSetting));
                }
            }
        }
        return taxSettingsByLedgerIds;
    }

    public static Map<Id, List<Sobject>> getSobjectMapByTaxSettingsIds(List<SObject> sourceDocs) {
        Map<Id, List<Sobject>> taxSettingIds = new Map<Id, List<Sobject>>();
        for (SObject obj : sourceDocs) {
            Id taxSettingId = getTaxSettings(obj)?.recordId;
            if (!taxSettingIds.containsKey(taxSettingId)) {
                taxSettingIds.put(taxSettingId, new List<SObject> {obj});
            }
            else {
                taxSettingIds.get(taxSettingId).add(obj);
            }
        }
        return taxSettingIds;
    }

    public static TaxSetting getTaxSettings(Id ledgerId) {
        return getTaxSettings().get(ledgerId);
    }

    public static TaxSetting getTaxSettings(SObject sourceDoc) {
        return getTaxSettings(getLedgerIdBySobject(sourceDoc));
    }

    public static Id getLedgerIdBySobject(SObject sourceDoc) {
        if (ledgerFieldsByObjectTypes.containsKey(sourceDoc.getSObjectType())) {
            return (Id) sourceDoc.get(ledgerFieldsByObjectTypes.get(sourceDoc.getSObjectType()));
        }
        else if (parentSObjectById != null
                    && parentObjectByObjectTypes.get(sourceDoc.getSObjectType()) != null
                    && parentSObjectById.containsKey((Id) sourceDoc.get(parentObjectByObjectTypes.get(sourceDoc.getSObjectType())))) {

            return (Id) parentSObjectById.get((Id) sourceDoc.get(parentObjectByObjectTypes.get(sourceDoc.getSObjectType()))).get(parenLedgerFieldsByObjectTypes.get(sourceDoc.getSObjectType()));
        }
        else if (sobjectByLedgerId != null) {
            return sobjectByLedgerId.get(getKeySobject(sourceDoc));
        }
        return null;
    }

    public static Sobject getKeySobject(SObject sourceDoc) {
        for (SObject obj : sobjectByLedgerId.keySet()) {
            if (obj.Id == sourceDoc.Id) {
                return obj;
            }
        }
        return sourceDoc;
    }

    public static String getTaxMethod(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.taxMethod;
    }

    public static void reset() {
        taxSettingsByLedgerIds = null;
    }

    public static Map<Id, TaxSetting> getTaxSettingMap() {
        Map<Id, TaxSetting> taxSettingsByIds = new Map<Id, TaxService.TaxSetting>();
        for (TaxSetting ts: getTaxSettings().values()) {
            taxSettingsByIds.put(ts.recordId, ts);
        }
        return taxSettingsByIds;
    }

    public class TaxSetting {
        public Id recordId;

        public AvaTaxLicense license;
        public OriginAddress originAddress;
        public Id originAddressId;
        public String salesTaxCalculationMode;
        public Id salesTaxGLAccountId;
        public Id salesTaxProductId;
        public String taxMethod;
        public Decimal taxRoundingThreshold;

        public TaxSetting(Tax_Settings__c taxSettings) {
            this.recordId = taxSettings.Id;
            if (taxSettings.AvaTax_License__r != null) {
                this.license = new AvaTaxLicense(taxSettings.AvaTax_License__r);
            }
            if (taxSettings.Origin_Address__r != null) {
                this.originAddress = new OriginAddress(taxSettings.Origin_Address__r);
            }
            this.originAddressId = taxSettings.Origin_Address__c;
            this.salesTaxCalculationMode = taxSettings.Sales_Tax_Calculation_Mode__c;
            this.salesTaxGLAccountId = taxSettings.Sales_Tax_GL_Account__c;
            this.salesTaxProductId = taxSettings.Sales_Tax_Product__c;
            this.taxMethod = taxSettings.Tax_Settings_Method__c;
            this.taxRoundingThreshold = String.isNotBlank(taxSettings.Tax_Rounding_Threshold__c)
                    ? Decimal.valueOf(taxSettings.Tax_Rounding_Threshold__c)
                    : 0;
        }
    }

    public class AvaTaxLicense {
        public Id recordId;

        public String activeAvaTaxEndpoint;
        public String avaTaxAccountId;
        public String avaTaxLicenseKey;

        public AvaTaxLicense(String activeAvaTaxEndpoint, String avaTaxAccountId, String avaTaxLicenseKey) {
            this.activeAvaTaxEndpoint = activeAvaTaxEndpoint;
            this.avaTaxAccountId = avaTaxAccountId;
            this.avaTaxLicenseKey = avaTaxLicenseKey;
        }

        public AvaTaxLicense(AvaTax_License__c avaTaxLicense) {
            this(avaTaxLicense.Active_AvaTax_Endpoint__c, avaTaxLicense.AvaTax_Account_ID__c, avaTaxLicense.AvaTax_License_Key__c);
            this.recordId = avaTaxLicense.Id;
        }
    }

    public class OriginAddress {
        public Id recordId;
        public String city;
        public String countryCode;
        public String postalCode;
        public String stateProvince;
        public String street;

        public OriginAddress(Address__c originAddress) {
            this.recordId = originAddress.Id;
            this.city = originAddress.City__c;
            this.countryCode = originAddress.Country_Code__c;
            this.postalCode = originAddress.Postal_Code__c;
            this.stateProvince = originAddress.State_Province__c;
            this.street = originAddress.Street__c;
        }

        public OriginAddress(Accounting_Settings__c accountSettings) {
            this.city = accountSettings.City__c;
            this.countryCode = accountSettings.Country_Code__c;
            this.postalCode = accountSettings.Postal_Code__c;
            this.stateProvince = accountSettings.Region__c;
            this.street = accountSettings.Street__c;
        }
    }
}