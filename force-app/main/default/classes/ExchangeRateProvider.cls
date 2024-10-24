public with sharing class ExchangeRateProvider {

    public static final String EXCHANGE_RATE_ERROR = Label.ERR_Exchange_Rate_Missing;
    private static final String CTA_GL_ACCOUNT_ERROR = Label.ERR_NO_CTA_GL_ACCOUNT;
    private static ExchangeRateProvider instance;
    private Map<String, ExchangeRateWrapper> exchangeRateTables;
    private Date startDate;
    private Date endDate;
    private Set<String> currencyCodes;
    private Set<String> types;

    private ExchangeRateProvider() {
        exchangeRateTables = new Map<String, ExchangeRateWrapper>();
        currencyCodes = new Set<String>();
        types = new Set<String>();
    }

    public static ExchangeRateProvider getInstance() {
        if (instance == null) {
            instance = new ExchangeRateProvider();
        }
        return instance;
    }

    private void queryExchangeRateTable() {
        try {
            List<Exchange_Rate__c> tables = DomainUtils.getExchangeRateTableByDateAndTypeAndCurrency(
                startDate,
                endDate,
                types,
                currencyCodes
            );

            for (Exchange_Rate__c table : tables) {
                ExchangeRateWrapper cew = new ExchangeRateWrapper(table);
                if (!exchangeRateTables.keySet().contains(cew.getKey())) {
                    exchangeRateTables.put(cew.getKey(), cew);
                }
            }

        }
        catch (Exception ex) {}
    }

    private ExchangeRateWrapper getExchangeTable(ExchangeRateWrapper params) {
        if (exchangeRateTables.containsKey(params.getKey())) {
            return exchangeRateTables.get(params.getKey());
        }
        else {
            return getExchangeTableByDate(params);
        }
    }

    private ExchangeRateWrapper getExchangeTableByDate(ExchangeRateWrapper params) {
        ExchangeRateWrapper result;
        for (ExchangeRateWrapper table : exchangeRateTables.values()) {
            if (table.getShortKey() == params.getShortKey()
                && ((table.fromDate <= params.toDate && table.toDate == null)
                || (table.toDate >= params.fromDate && table.fromDate <= params.toDate && table.toDate != null))) {

                if (table.toDate == null) {
                    result = table;
                }
                else {
                    result = result == null || table.fromDate > result.fromDate ? table : result;
                }
            }
        }

        return result;
    }

    private Decimal getRateForPeriod(ExchangeRateWrapper queryParams) {
        ExchangeRateWrapper table = getExchangeTable(queryParams);
        if (table != null) {
            return table.rate;
        }
        else {
            startDate = queryParams.fromDate;
            endDate = queryParams.toDate;
            currencyCodes.add(queryParams.fromCurrency);
            currencyCodes.add(queryParams.toCurrency);
            types.add(queryParams.rateType);
            queryExchangeRateTable();
            table = getExchangeTable(queryParams);
            return table != null ? getExchangeTable(queryParams).rate : 1;
        }
    }

    private AllExchangeRateTablesValidationResult validateExchangeRateTables(List<ExchangeRateWrapper> paramsToValidate) {
        for (ExchangeRateWrapper cert : paramsToValidate) {
            startDate = startDate == null || startDate > cert.fromDate ? cert.fromDate : startDate;
            endDate = endDate == null || endDate < cert.toDate ? cert.toDate : endDate;
            currencyCodes.add(cert.fromCurrency);
            currencyCodes.add(cert.toCurrency);
            types.add(cert.rateType);
        }
        queryExchangeRateTable();
        return isAllRateTablesValid(paramsToValidate);
    }

    private AllExchangeRateTablesValidationResult isAllRateTablesValid(List<ExchangeRateWrapper> paramsToValidate) {
        Boolean isValid = true;
        List<ExchangeRateWrapper> notValidRateTables = new List<ExchangeRateProvider.ExchangeRateWrapper>();
        for (ExchangeRateWrapper cert : paramsToValidate) {
            if (getExchangeTable(cert) == null) {
                notValidRateTables.add(cert);
                isValid = false;
            }
        }
        return new AllExchangeRateTablesValidationResult(notValidRateTables, isValid);
    }

    public static Decimal getExchangeRateForPeriod(Date fromDate, Date toDate, String fromCurrency, String toCurrency, String type) {
        ExchangeRateWrapper queryParams = new ExchangeRateWrapper(fromDate, toDate, fromCurrency, toCurrency, type);
        return ExchangeRateProvider.getInstance().getRateForPeriod(queryParams);
    }

    public static AllExchangeRateTablesValidationResult isAllExchangeRateTablesValid(List<ExchangeRateWrapper> paramsToValidate) {
        return ExchangeRateProvider.getInstance().validateExchangeRateTables(paramsToValidate);
    }

    public static ServiceResult validateCumulativeTranslateGLAccount (Set<Id> ledgerIds) {
        for (Map<String, GL_Account_Default__c> defaultsBySpecDevNames : GLAccount.glAccountDefaultsMapByLedgerId(ledgerIds).values()) {
            if (defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CTA_GL_ACCOUNT)?.GL_Account__c == null) {
                return new ServiceResult(ExchangeRateProvider.CTA_GL_ACCOUNT_ERROR, false);
            }
        }
        return new ServiceResult('', true);
    }

    public class AllExchangeRateTablesValidationResult {
        public List<ExchangeRateWrapper> notValidRateTables;
        public Boolean isValid;

        public AllExchangeRateTablesValidationResult(List<ExchangeRateWrapper> notValidRateTables, Boolean isValid) {
            this.notValidRateTables = notValidRateTables;
            this.isValid = isValid;
        }
    }

    public with sharing class ExchangeRateWrapper implements Comparable {
        public Exchange_Rate__c table;
        public Date fromDate;
        public Date toDate;
        public String fromCurrency;
        public String toCurrency;
        public String rateType;
        public Decimal rate;

        public String accountingPeriodName;

        public ExchangeRateWrapper(Exchange_Rate__c table) {
            this.table = table;
            fromDate = table.Effective_From__c;
            toDate = table.Effective_To__c;
            fromCurrency = table.From_Currency_Code__c;
            toCurrency = table.To_Currency_Code__c;
            rateType = table.Rate_Type__c;
            rate = table.Exchange_Rate__c;
        }

        public ExchangeRateWrapper(Date fromDate, Date toDate, String fromCurrency, String toCurrency, String type) {
            this.fromDate = fromDate;
            this.toDate = toDate;
            this.fromCurrency = fromCurrency;
            this.toCurrency = toCurrency;
            this.rateType = type;
        }

        public String getKey() {
            return String.valueOf(fromDate) + String.valueOf(toDate) + fromCurrency + toCurrency + rateType;
        }

        public String getShortKey() {
            return fromCurrency + toCurrency + rateType;
        }

        public ExchangeRateWrapper accountingPeriodName(String accountingPeriodName) {
            this.accountingPeriodName = accountingPeriodName;
            return this;
        }

        public Integer compareTo(Object compareTo) {
            ExchangeRateWrapper compareToCER = (ExchangeRateWrapper) compareTo;
            Integer returnValue = 0;
            if (fromDate > compareToCER.fromDate) {
                returnValue = 1;
            } else if (fromDate < compareToCER.fromDate) {
                returnValue = -1;
            }
            return returnValue;
        }
    }

}