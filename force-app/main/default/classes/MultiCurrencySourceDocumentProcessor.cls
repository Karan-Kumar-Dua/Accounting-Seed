public with sharing class MultiCurrencySourceDocumentProcessor {
    @TestVisible
    private List<SourceDocumentMultiCurrency> sourceDocNoConversionRateList;
    private String recordDateField;
    private String parentField;
    @TestVisible
    private Set<String> currencyISOCodes;
    @TestVisible
    private Set<Date> recordDateSet;
    private List<SObject> datedConversionRates;
    private Boolean isParentFieldLedger;
    private Id legacyLedgerId;
    @TestVisible
    private DatedConversionRateHandler datedConversionRateHandler;
    private static MultiCurrencySourceDocumentProcessor instance = NULL;
    private static String packageQualifier = GlobalVariables.PACKAGE_QUALIFIER;

    public static MultiCurrencySourceDocumentProcessor getInstance() {
        if (instance == NULL) {
            instance = new MultiCurrencySourceDocumentProcessor();
        }
        return instance;
    }

    private MultiCurrencySourceDocumentProcessor() {
        datedConversionRateHandler = new DatedConversionRateHandler();

    }

    @TestVisible
    private void init(String recordDateField, String parentField) {
        this.recordDateField = recordDateField;
        this.parentField = parentField;
        isParentFieldLedger = parentField.toLowerCase().contains('ledger');
        sourceDocNoConversionRateList = new List<SourceDocumentMultiCurrency>();
        currencyISOCodes = new Set<String>();
        recordDateSet = new Set<Date>();
        datedConversionRates = new List<SObject>();
    }

    private void setPackageQualifier(List<SObject> newRecords) {
        if (!newRecords.isEmpty()) {
            packageQualifier = SObjectActions.getPackageQualifierBySObject(newRecords);
        }
    }

    public void setCCRSourceDocumentToParent(Map<Id, SObject> oldRecordsMap, List<SObject> newRecords, String recordDateField, String parentField) {
        init(recordDateField, parentField);
        setPackageQualifier(newRecords);
        setParentIsoCodeByLedger(oldRecordsMap, newRecords);
        setParentIsoCodeByParentRelationship(oldRecordsMap, newRecords);
        queryDatedConversionRatesByCurrenciesCodesAndDateRange();
        setDatedConversionRateMap();
        setCurrencyConversionRateRecords();
    }

    @TestVisible
    private void setParentIsoCodeByParentRelationship(Map<Id, SObject> oldRecordsMap, List<SObject> newRecords) {
        if (!isParentFieldLedger && !newRecords.isEmpty()) {
            Map<Id,SObject> parentRecordsMap = new Map<Id,SObject>();
            for (SObject obj : newRecords) {
                Id parentFieldId = (Id)obj.get(parentField);
                if (parentFieldId != NULL) {
                    parentRecordsMap.put(parentFieldId, NULL);
                }
            }

            parentRecordsMap = DomainUtils.getParentISOCode(parentRecordsMap.keySet(), parentField);
            for (SObject obj : newRecords) {
                SourceDocumentMultiCurrency sdm = new SourceDocumentMultiCurrency(isParentFieldLedger);
                sdm.newRecord = obj;
                sdm.oldRecord = oldRecordsMap != NULL ? oldRecordsMap.get(obj.Id) : NULL;
                Id parentFieldId = (Id)obj.get(parentField);

                if (parentRecordsMap.containsKey(parentFieldId)) {
                    sdm.parentISOCode = (String) parentRecordsMap.get(parentFieldId).get('CurrencyIsoCode');
                }
                setCurrencyConversionRateOrAddRetrievalList(sdm);
            }
        }
    }

    @TestVisible
    private void setParentIsoCodeByLedger(Map<Id, SObject> oldRecordsMap, List<SObject> newRecords) {
        if (isParentFieldLedger && !newRecords.isEmpty()) {
            legacyLedgerId = legacyLedgerId != NULL ? LedgerHandler.getLegacyDefaultLedgerId() : legacyLedgerId;

            for (SObject obj : newRecords) {
                SourceDocumentMultiCurrency sdm = new SourceDocumentMultiCurrency(isParentFieldLedger);
                sdm.newRecord = obj;
                sdm.oldRecord = oldRecordsMap != NULL ? oldRecordsMap.get(obj.Id) : NULL;
                sdm.currencyConversionRate = (Decimal) obj.get(packageQualifier + 'Currency_Conversion_Rate__c');
                sdm.parentISOCode = getLedgerIsoCode(sdm);
                setCurrencyConversionRateOrAddRetrievalList(sdm);
            }
        }
    }

    private String getLedgerIsoCode(SourceDocumentMultiCurrency sdm) {
        Id ledgerId = (Id) sdm.newRecord.get(packageQualifier + 'Ledger__c');
        ledgerId = ledgerId != NULL ? ledgerId : legacyLedgerId;
        return LedgerHandler.getLedgerCurrency(ledgerId);
    }

    @TestVisible
    private void setCurrencyConversionRateOrAddRetrievalList(SourceDocumentMultiCurrency sdm) {
        if (sdm.isCalculateCurrencyConversionRate()
                && sdm.isCurrencyConversionRateOne()) {


            sdm.currencyConversionRate = 1;
            sdm.setCurrencyConversionRateRecord();
        }
        else if (sdm.isCalculateCurrencyConversionRate()) {
            sdm.currencyConversionRate = getConversionRateBySourceDocumentAndParent(sdm);
            sdm.setCurrencyConversionRateRecord();
        }

        if (!sdm.isCurrencyConversionRate()) {
            recordDateSet.add(sdm.getDateFieldValue(recordDateField));
            currencyISOCodes.add(sdm.parentISOCode);
            currencyISOCodes.add(sdm.recordIsoCode());
            sourceDocNoConversionRateList.add(sdm);
        }
    }

    private void queryDatedConversionRatesByCurrenciesCodesAndDateRange() {
        if (!currencyISOCodes.isEmpty() && !recordDateSet.isEmpty()) {
            datedConversionRates = DomainUtils.getDatedConversionRateByCurrencyISOCodesAndDates(currencyISOCodes, recordDateSet);
        }
    }

    private void setDatedConversionRateMap() {

        for (Sobject datedConversionRate : datedConversionRates) {
            String ccrIsoCode = (String) datedConversionRate.get('IsoCode');
            Date ccrStartDate = (Date) datedConversionRate.get('StartDate');
            Date ccrNextStartDate = (Date) datedConversionRate.get('NextStartDate');
            Double ccr = (Double) datedConversionRate.get('ConversionRate');

            DatedConversionRate dcr = new DatedConversionRate(ccrStartDate,ccrNextStartDate,ccrIsoCode,ccr);
            datedConversionRateHandler.addDatedConversionRate(dcr);
        }
    }

    @TestVisible
    private void setCurrencyConversionRateRecords() {
        for (SourceDocumentMultiCurrency sdm : sourceDocNoConversionRateList) {
            if (!sdm.isCurrencyConversionRate()) {
                sdm.currencyConversionRate = getConversionRateBySourceDocumentAndParent(sdm);
                sdm.setCurrencyConversionRateRecord();
            }
        }
        sourceDocNoConversionRateList.clear();
    }

    private Decimal getConversionRateBySourceDocumentAndParent(SourceDocumentMultiCurrency sdm) {
        Date recordDate = sdm.getDateFieldValue(recordDateField);
        Decimal sourceConversionRate = datedConversionRateHandler.getConversionRateByDateAndIsoCode(sdm.recordIsoCode(),recordDate);
        Decimal parentConversionRate = datedConversionRateHandler.getConversionRateByDateAndIsoCode(sdm.parentISOCode,recordDate);
        Decimal conversionRate;

        if (sourceConversionRate != NULL && parentConversionRate != NULL && parentConversionRate != 0) {
            conversionRate = (sourceConversionRate/parentConversionRate).setScale(6, System.RoundingMode.HALF_UP);
        }
        else if (sourceConversionRate != NULL) {//get direct CCR from source record
            conversionRate = sourceConversionRate.setScale(6, System.RoundingMode.HALF_UP);
        }

        return conversionRate;
    }

    public class SourceDocumentMultiCurrency {
        public SObject newRecord {get; set;}
        public SObject oldRecord {get; set;}
        public String parentISOCode {get; set;}
        public Decimal currencyConversionRate {get; set;}
        public Boolean isParentFieldLedger {get; set;}

        public SourceDocumentMultiCurrency(Boolean isParentFieldLedger) {
            this.isParentFieldLedger = isParentFieldLedger;
        }

        public Boolean isCalculateCurrencyConversionRate() {
            return parentISOCode != NULL && isCurrencyConversionRateNull()
                || isCurrencyChanged()
                || isLedgerChanged();
        }

        public Boolean isCurrencyConversionRateNull() {
            return newRecord.get(packageQualifier + 'Currency_Conversion_Rate__c') == NULL;
        }

        public Boolean isLedgerChanged() {
            return (isOldRecordNotNull() && isParentFieldLedger && (oldRecord.get(packageQualifier + 'Ledger__c') != newRecord.get(packageQualifier + 'Ledger__c')));
        }

        public Boolean isCurrencyChanged() {
            return isOldRecordNotNull() && oldRecord.get('CurrencyIsoCode') != newRecord.get('CurrencyIsoCode');
        }

        public Boolean isOldRecordNotNull() {
            return oldRecord != NULL;
        }

        public Boolean isParentISOCodeNull() {
            return parentIsoCode == NULL;
        }

        public Boolean isParentISOCodeSame() {
            return !isParentISOCodeNull() && newRecord.get('CurrencyIsoCode') == parentIsoCode;
        }

        public Boolean isSourceDocumentPosted() {
            return isParentFieldLedger && newRecord.get(packageQualifier + 'Status__c') == 'Posted';
        }

        public Boolean isCurrencyConversionRateOne() {
            return
            (isCurrencyConversionRateNull()
                && isSourceDocumentPosted())
                || isParentISOCodeSame();
        }

        public Boolean isCurrencyConversionRate() {
            return currencyConversionRate != NULL;
        }

        public void setCurrencyConversionRateRecord() {
            newRecord.put(packageQualifier + 'Currency_Conversion_Rate__c', currencyConversionRate);
        }

        public String recordIsoCode() {
            return (String) newRecord.get('CurrencyIsoCode');
        }

        public Date getDateFieldValue(String dateField) {
            Object currencyDate = newRecord.get(dateField);
            return currencyDate != NULL ? Date.valueOf(currencyDate) : System.today();
        }
    }

    public class DatedConversionRateHandler {
        @TestVisible
        private Map<String, List<Date>> orderedDateMap;
        @TestVisible
        private Map<String, List<DatedConversionRate>> datedConversionRateMap;

        public DatedConversionRateHandler() {
            orderedDateMap = new Map<String, List<Date>>();
            datedConversionRateMap = new Map<String, List<DatedConversionRate>>();
        }

        public Double getConversionRateByDateAndIsoCode(String isoCode, Date docDate) {
            Double ccr;
            if (datedConversionRateMap.containsKey(isoCode)) {
                List<Date> orderedDates = orderedDateMap.get(isoCode);
                Integer arrayIndex = searchLeastGreatestDate(orderedDates, docDate);
                if (arrayIndex >= 0) {
                    //We have to divide original array index by 2
                    //because "orderedDates" list is twice as much as "datedConversionRateMap.get(isoCodeKey)" list
                    arrayIndex = arrayIndex / 2;
                    DatedConversionRate dcr = datedConversionRateMap.get(isoCode)[arrayIndex];
                    ccr = dcr.ccr;
                }
            }

            return ccr;
        }

        public void addDatedConversionRate(DatedConversionRate dcr) {
            String isoCode = dcr.isoCode;
            if (!datedConversionRateMap.containsKey(isoCode)) {
                datedConversionRateMap.put(isoCode, new List<DatedConversionRate>());
                orderedDateMap.put(isoCode, new List<Date>());
            }
            datedConversionRateMap.get(isoCode).add(dcr);
            orderedDateMap.get(isoCode).add(dcr.startDate);
            orderedDateMap.get(isoCode).add(dcr.nextStartDate);
            orderedDateMap.get(isoCode).sort();
            datedConversionRateMap.get(isoCode).sort();
        }

        private Integer searchLeastGreatestDate(List<Date> dateList, Date value) {
            if (dateList.isEmpty()) {
                return -1;
            }
            if (value < dateList[0]) {
                return -1;
            }
            if (value > dateList[dateList.size() - 1]) {
                return -1;
            }

            Integer first = 0;
            Integer last = dateList.size() - 1;

            while (first <= last) {
                Integer mid = (last + first) / 2;

                if (value < dateList[mid]) {
                    last = mid - 1;
                }
                else if (value >= dateList[mid]) {
                    first = mid + 1;
                }
                else {
                    return mid;
                }
            }

            return (dateList[first].daysBetween(value)) < (value.daysBetween(dateList[last])) ? first : last;
        }
    }

    public class DatedConversionRate implements Comparable {
        public Date startDate;
        public Date nextStartDate;
        public String isoCode;
        public Double ccr;

        public DatedConversionRate(Date startDate, Date nextStartDate, String isoCode, Double ccr) {
            this.startDate = startDate;
            this.nextStartDate = nextStartDate;
            this.isoCode = isoCode;
            this.ccr = ccr;
        }

        // Implement the compareTo() method
        public Integer compareTo(Object compareTo) {
            DatedConversionRate compareToDCR = (DatedConversionRate)compareTo;
            if (startDate == compareToDCR.startDate) return 0;
            if (startDate > compareToDCR.startDate) return 1;
            return -1;
        }
    }
}