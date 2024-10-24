/**
 * Address validation helpers for LWCs.
 */
public with sharing class AddressValidationHelper {
    
    // use for injection during unit tests
    @TestVisible
    private static AddressValidationProvider provider;

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> fetchConfig() {
        Map<String, Object> result = new Map<String, Object>();
        try {
            result.put('avaTaxLicenses', queryAvaTaxLicenses());
        }
        catch (Exception e) {
            throw new AddressValidationHelperException(e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static AddressValidationProvider.ValidationResult validate(
            String street, 
            String city, 
            String state, 
            String postalCode, 
            String country,
            Id licenseLinkedId,
            Id avaTaxLicenseId) {
        
        try {
            // create address model
            AddressValidationProvider.ValidationAddress address = new AddressValidationProvider.ValidationAddress();
            address.street = street;
            address.city = city;
            address.state = state;
            address.postalCode = postalCode;
            address.country = country;

            AvaTax_License__c avaTaxLicense = null;
            if (String.isNotBlank(licenseLinkedId) && licenseLinkedId.getSobjectType() == Tax_Settings__c.getSObjectType()) {
                List<Tax_Settings__c> taxSettings = queryTaxSettingsByIds(new Set<Id>{licenseLinkedId});
                avaTaxLicense = !taxSettings.isEmpty() && taxSettings[0].AvaTax_License__r != null ?
                        taxSettings[0].AvaTax_License__r : avaTaxLicense;
            } else if (String.isNotBlank(licenseLinkedId) && licenseLinkedId.getSobjectType() == Billing__c.getSObjectType()) {
                List<Billing__c> billings = queryBillings(new Set<Id>{licenseLinkedId});
                avaTaxLicense = !billings.isEmpty() && billings[0].Ledger__r != null && billings[0].Ledger__r.Tax_Settings__r != null && billings[0].Ledger__r.Tax_Settings__r.AvaTax_License__r != null ?
                        billings[0].Ledger__r.Tax_Settings__r.AvaTax_License__r : avaTaxLicense;
            } else if ((String.isNotBlank(licenseLinkedId) && licenseLinkedId.getSobjectType() == AvaTax_License__c.getSObjectType()) ||
                    (String.isNotBlank(avaTaxLicenseId) && licenseLinkedId.getSobjectType() == Account.getSObjectType())) {
                List<AvaTax_License__c> avaTaxLicenses = queryAvaTaxLicenses(new Set<Id>{licenseLinkedId, avaTaxLicenseId});
                avaTaxLicense = !avaTaxLicenses.isEmpty() ? avaTaxLicenses[0] : avaTaxLicense;
            }

            // get address validation provider
            AddressValidationProvider provider = getProvider(avaTaxLicense);

            return provider.validate(address);
        }
        catch (Exception e) {
            throw new AddressValidationHelperException(e.getMessage());
        }
    }

    private static List<Tax_Settings__c> queryTaxSettingsByIds(Set<Id> ids) {
        SOQLBuilder theQuery = new SOQLBuilder(Tax_Settings__c.SObjectType)
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(new List<String>{
                'AvaTax_License__r.AvaTax_Account_ID__c',
                'AvaTax_License__r.AvaTax_License_Key__c',
                'AvaTax_License__r.Active_AvaTax_Endpoint__c'
            })
            .setCondition(String.join(new List<String>{'Id =: ids'}, ' AND '));

        return (List<Tax_Settings__c>) Database.query(theQuery.toSOQL());
    }

    private static List<Billing__c> queryBillings(Set<Id> ids) {
        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType)
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(new List<String>{
                'Ledger__r.Tax_Settings__r.AvaTax_License__r.AvaTax_Account_ID__c',
                'Ledger__r.Tax_Settings__r.AvaTax_License__r.AvaTax_License_Key__c',
                'Ledger__r.Tax_Settings__r.AvaTax_License__r.Active_AvaTax_Endpoint__c'
            })
            .setCondition(String.join(new List<String>{'Id =: ids'}, ' AND '));

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    private static List<AvaTax_License__c> queryAvaTaxLicenses() {
        return queryAvaTaxLicenses(null);
    }

    private static List<AvaTax_License__c> queryAvaTaxLicenses(Set<Id> ids) {
        List<String> conditions = new List<String>();
        if (ids != null) {
            conditions.add('Id =: ids');
        }
        SOQLBuilder theQuery = new SOQLBuilder(AvaTax_License__c.SObjectType)
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(new List<String>{
                        'Id',
                        'Name',
                        'AvaTax_Account_ID__c',
                        'AvaTax_License_Key__c',
                        'Active_AvaTax_Endpoint__c'
                });
        (!conditions.isEmpty() ? theQuery.setCondition(String.join(conditions, ' AND ')) : theQuery)
                .addOrdering(AvaTax_License__c.Name, SOQLBuilder.SortOrder.ASCENDING);
        return (List<AvaTax_License__c>) Database.query(theQuery.toSOQL());
    }

    private static AddressValidationProvider getProvider() {
        return getProvider(null);
    }

    private static AddressValidationProvider getProvider(AvaTax_License__c license) {
        // no provider injected
        if (provider == null) {
            return license != null ?
                    new AvaTaxAddressValidator().avaTaxLicense(license) :
                    new AvaTaxAddressValidator();
        }
        // return injected provider
        return provider;
    }

    public with sharing class AddressValidationHelperException extends Exception{}


    @AuraEnabled
    public static AddressValidationProvider.ValidationResult precheck(
            String street, 
            String city, 
            String state, 
            String postalCode, 
            String country) {
        try {
            // create address model
            AddressValidationProvider.ValidationAddress address = new AddressValidationProvider.ValidationAddress();
            address.street = street;
            address.city = city;
            address.state = state;
            address.postalCode = postalCode;
            address.country = country;

            // get address validation provider
            AddressValidationProvider provider = getProvider();

            return provider.precheck(address);
        }
        catch (Exception e) {
            throw new AddressValidationHelperException(e.getMessage());
        }
    }

}