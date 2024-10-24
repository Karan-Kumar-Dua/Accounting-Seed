public with sharing class BankManagerHelper {

    public with sharing class SourceObject {
        @AuraEnabled
        public String sourceName {get; set;}
        @AuraEnabled
        public String sourceId {get; set;}
        @AuraEnabled
        public String sourceType {get; set;}
        @AuraEnabled
        public String baseURL {get; set;}

        public SourceObject(String id, String name, String type) {
            this.sourceType = type;
            this.sourceName = name;
            this.sourceId = id;
            this.baseURL = URL.getOrgDomainUrl().toExternalForm();
        }
    }

    public with sharing class Money {
        @AuraEnabled
        public Decimal recordAmount;
        @AuraEnabled
        public String recordCurrency;
        @AuraEnabled
        public Decimal ledgerAmount;
        @AuraEnabled
        public String ledgerCurrency;

        public Money(Decimal recAmount, String recCurrency, Decimal ledgerAmount, String ledgerCurrency) {
            this.recordAmount = recAmount;
            this.recordCurrency = recCurrency;
            this.ledgerAmount = ledgerAmount;
            this.ledgerCurrency = ledgerCurrency;
        }
    }

    public with sharing class VendorInfo {
        @AuraEnabled
        public String vendorName;
        @AuraEnabled
        public String vendorId;
        
        public VendorInfo(String vendorName, String vendorId) {
            this.vendorName = vendorName;
            this.vendorId = vendorId;
        }
    }

    public static String getLedgerCondition(String ledgerId, String ledgerSourceName) {
        String ledgerCondition;
        if (String.isBlank(ledgerId)) {
            String defaultLedger = LedgerHandler.getLegacyDefaultLedgerId();
            ledgerCondition = 'AND (' + ledgerSourceName + ' = \'' + defaultLedger + '\' OR ' + ledgerSourceName + ' = NULL)';
        }
        else if (LedgerHandler.isLedgerEqualLegacyLedger(ledgerId)) {
            ledgerCondition = 'AND (' + ledgerSourceName + ' = :ledgerId OR ' + ledgerSourceName + ' = NULL)';
        }
        else {
            ledgerCondition = 'AND ' + ledgerSourceName + ' = :ledgerId';
        }
        return ledgerCondition;
    }

    public static String getCurrencyCondition(String ledgerId, String currencyIsoCode) {
        if (String.isBlank(ledgerId)) {
            ledgerId = LedgerHandler.getLegacyDefaultLedgerId();
        }
        String currencyCondition;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled
                && LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId).get('CurrencyIsoCode') != currencyIsoCode) {

            currencyCondition = ' AND CurrencyIsoCode = :currencyIsoCode ';
        }
        else {
            currencyCondition = '';
        }
        return currencyCondition;
    }

    public static Boolean needShowLedgerAmount(String ledgerId, String currencyIsoCode) {
        if (!MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return false;
        }
        if (String.isBlank(ledgerId)) {
            ledgerId = LedgerHandler.getLegacyDefaultLedgerId();
        }
        if (LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId).get('CurrencyIsoCode') != currencyIsoCode) {
            return false;
        }
        else {
            return true;
        }
    }

    public static String getGlavVariablePredicate(String glavVar1, String glavVar2, String glavVar3, String glavVar4) {
        String queryString = '';
        if (!String.isBlank(glavVar1)) {
            queryString += ' AND GL_Account_Variable_1__c = :glavVar1 ';
        }

        if (!String.isBlank(glavVar2)) {
            queryString += ' AND GL_Account_Variable_2__c = :glavVar2 ';
        }

        if (!String.isBlank(glavVar3)) {
            queryString += ' AND GL_Account_Variable_3__c = :glavVar3 ';
        }

        if (!String.isBlank(glavVar4)) {
            queryString += ' AND GL_Account_Variable_4__c = :glavVar4 ';
        }

        return queryString;
    }

}