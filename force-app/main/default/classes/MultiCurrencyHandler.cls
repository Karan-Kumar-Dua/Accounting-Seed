public without sharing class MultiCurrencyHandler {
    public static Boolean isMultiCurrencyEnabled {
        get {
            try {
                if (isMultiCurrencyEnabled == NULL) {//request value from DB only one time per transaction
                    isMultiCurrencyEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Multi_Currency__c && UserInfo.isMultiCurrencyOrganization();
                }

                return isMultiCurrencyEnabled;
            }
            catch (Exception ex) {
                return false;
            }
        }
        set;
    }

    public static String CORPORATE_CURRENCY {
        get {
            if (CORPORATE_CURRENCY == NULL) {
                try {
                    if (isMultiCurrencyEnabled) {
                        List<SObject> currencyType = Database.query(
                            'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = true LIMIT 1'
                        );
                        CORPORATE_CURRENCY = (String) currencyType[0].get('IsoCode');
                    }
                    else {
                        CORPORATE_CURRENCY = UserInfo.getDefaultCurrency();
                    }
                }
                catch (Exception ex) {
                    return NULL;
                }
            }
            return CORPORATE_CURRENCY;
        }
        set;
    }

    //key: CurrencyIsoCode => value: CurrencyType
    public static Map<String, SObject> allCurrencies {
        get {
            if (allCurrencies == NULL) {
                allCurrencies = new Map<String, SObject>();
                for (SObject currencyType : DomainUtils.getCurrencyTypes()) {
                    allCurrencies.put((String) currencyType.get('IsoCode'), currencyType);
                }
            }
            return allCurrencies;
        }
        private set;
    }

    public static List<SelectOption> getAllCurrenciesSelectOptions() {
        List<SelectOption> result = new List<SelectOption>();
        for (String currencyIsoCode : allCurrencies.keySet()) {
            result.add(new SelectOption(currencyIsoCode, currencyIsoCode));
        }
        return result;
    }

    public static List<SelectOption> getActiveCurrenciesSelectOptions() {
        List<SelectOption> result = new List<SelectOption>();
        Boolean active;
        for (SObject currencyType : allCurrencies.values()) {
            active = (Boolean) currencyType.get('IsActive');
            if (active) {
                String currencyIsoCode = (String) currencyType.get('IsoCode');
                result.add(new SelectOption(currencyIsoCode, currencyIsoCode));
            }
        }
        return result;
    }

    public static Double getConversionRateByCurrencyCode(String isoCode) {
        if (allCurrencies.get(isoCode) != NULL) {
            return (Double) allCurrencies.get(isoCode).get('ConversionRate');
        }
        else {
            return 1;
        }
    }

    public static Map<Id, String> getCurrencyMap(List<SObject> recList) {
        Map<Id, String> result = new Map<Id, String>();
        if (isMultiCurrencyEnabled) {
            for (SObject obj : recList) {
                result.put((Id) obj.get('Id'), (String) obj.get('CurrencyIsoCode'));
            }
        }
        return result;
    }

    public static Map<Id, Decimal> getCurrencyConversionRate(List<SObject> recList) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        for (SObject obj : recList) {
            result.put((Id) obj.get('Id'), (Decimal) obj.get('Currency_Conversion_Rate__c'));
        }
        return result;
    }

    public static Decimal getRecordBaseAmount(SObject record) {
        Decimal result;
        if (isMultiCurrencyEnabled) {
            result = (Decimal) record.get('Ledger_Amount__c');
        }
        else {
            result = ((Decimal) record.get('Total__c'));
        }

        return result;
    }

    public static Decimal getAmountInBaseCurrency(Decimal sourceAmount, Decimal currencyConversionRate) {
        Decimal result;
        if (sourceAmount == NULL) {
            return 0;
        }
        if (isMultiCurrencyEnabled) {
            if (currencyConversionRate == NULL) {
                result = sourceAmount;
            }
            else {
                result = (sourceAmount / currencyConversionRate);
            }
        }
        else {
            result = sourceAmount;
        }

        return result;
    }

    public static Decimal getNormalizedBalance(Decimal value, String expectedCurrency) {
        Decimal result;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled && MultiCurrencyHandler.CORPORATE_CURRENCY != expectedCurrency) {
            Decimal conversionRate = MultiCurrencyHandler.getConversionRateByCurrencyCode(expectedCurrency);
            result = value * conversionRate;
        }
        else {
            result = value;
        }
        return result;
    }

    public static Boolean isSameCurrency(String bankTransactionCurrencyCode, SObject existedRecord) {
        Boolean result = true;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            if (bankTransactionCurrencyCode == NULL) {
                bankTransactionCurrencyCode = 'USD';
            }
            String currencyCodeOfExistedRecord = (String) existedRecord.get('CurrencyIsoCode');
            if (!bankTransactionCurrencyCode.equalsIgnoreCase(currencyCodeOfExistedRecord)) {
                result = false;
            }
        }
        return result;
    }

    //=================================================================================================
    //================================== SET CURRENCY CONVERSION RATE METHODS =========================
    //=================================================================================================

    private static String packageQualifier = GlobalVariables.PACKAGE_QUALIFIER;

    public static void setCurrencyConversionRateBySourceDocumentAndParent(Map<Id, SObject> oldRecordsMap, List<SObject> newRecords, String recordDateField, String parentField) {
        if (isMultiCurrencyEnabled) {
            MultiCurrencySourceDocumentProcessor.getInstance().setCCRSourceDocumentToParent(oldRecordsMap, newRecords, recordDateField, parentField);
        }
    }

    public static void setCurrencyConversionRateBySourceDocumentAndLedger(Map<Id, SObject> oldRecordsMap, List<SObject> newRecords, String recordDateField) {
        if (isMultiCurrencyEnabled) {
            MultiCurrencySourceDocumentProcessor.getInstance().setCCRSourceDocumentToParent(oldRecordsMap, newRecords, recordDateField, 'Ledger__c');
        }
    }

    public static void setCurrencyIsoCodeByLedger(List<SObject> newRecords) {
        if (isMultiCurrencyEnabled) {
            for (SObject obj : newRecords) {
                setCurrencyIsoCodeByLedger(obj);
            }
        }
    }

    public static void revertCurrencyIsoCodeIfNull(Map<Id, SObject> oldRecordsMap, List<SObject> newRecords) {
        if (isMultiCurrencyEnabled) {
            for (SObject obj : newRecords) {
                SObject oldObj = oldRecordsMap.get(obj.Id);
                if (obj.get('CurrencyIsoCode') == NULL) {
                    obj.put('CurrencyIsoCode', oldObj.get('CurrencyIsoCode'));
                }
            }
        }
    }
    
    public static void setCurrencyIsoCodeByLedger(SObject obj) {
        if (isMultiCurrencyEnabled) {
            Ledger__c recLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById((Id) obj.get(packageQualifier + 'Ledger__c'));
            String ledgerCurrencyIsoCode = (recLedger != NULL) ? (String) recLedger.get('CurrencyIsoCode') : NULL;
            obj.put('CurrencyIsoCode', ledgerCurrencyIsoCode);
        }
    }

    public static void setCurrencyIsoCodeToUserCurrency(SObject obj) {
        if (isMultiCurrencyEnabled && obj.get('CurrencyIsoCode') == NULL) {
            obj.put('CurrencyIsoCode', UserInfo.getDefaultCurrency());
        }
    }

    public static void setCurrencyIsoCodeToUserCurrency(List<SObject> objList) {
        if (isMultiCurrencyEnabled) {
            for (SObject obj : objList) {
                setCurrencyIsoCodeToUserCurrency(obj);
            }
        }
    }
}