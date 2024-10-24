public with sharing class ExchangeRateActions {

    public static final String SAME_TABLE_ERROR = Label.ERR_DUPLICATED_RATE;
    public static Map<String, ExchangeRateProvider.ExchangeRateWrapper> existedTablesLast;
    public static Map<String, Exchange_Rate__c> existedTablesFirst;
    public static List<ExchangeRateProvider.ExchangeRateWrapper> newTables = new List<ExchangeRateProvider.ExchangeRateWrapper>();

    public static void setDefaultFields(List<Exchange_Rate__c> tables) {
        for (Exchange_Rate__c table : tables) {
            table.Next_Exchange_Rate__c = null;
        }
    }

    public static void getExistedTables(List<Exchange_Rate__c> tables) {
        Set<String> currencyCodes = new Set<String>();
        Set<String> types = new Set<String>();
        newTables = new List<ExchangeRateProvider.ExchangeRateWrapper>();
        for (Exchange_Rate__c table : tables) {
            currencyCodes.add(table.From_Currency_Code__c);
            currencyCodes.add(table.To_Currency_Code__c);
            types.add(table.Rate_Type__c);
            ExchangeRateProvider.ExchangeRateWrapper cew = new ExchangeRateProvider.ExchangeRateWrapper(table);
            newTables.add(cew);
        }
        existedTablesLast = getExistedTablesMap(DomainUtils.getLastExchangeRateTableByTypeAndCurrency(types, currencyCodes));
        existedTablesFirst = getFirstTablesMap(DomainUtils.getFirstExchangeRateTableByTypeAndCurrency(types, currencyCodes));

        //set Next_Exchange_Rate__c for new records in prior period
        for (ExchangeRateProvider.ExchangeRateWrapper table : newTables) {
            if (existedTablesFirst.containsKey(table.getShortKey())
                    && table.fromDate < existedTablesFirst.get(table.getShortKey()).Effective_From__c) {

                table.table.Next_Exchange_Rate__c = existedTablesFirst.get(table.getShortKey()).Id;
            }
        }
    }

    public static void setRelatedTableToDate(Map<Id, Exchange_Rate__c> tables) {
        List<Exchange_Rate__c> updateList = new List<Exchange_Rate__c>();
        Map<String, ExchangeRateProvider.ExchangeRateWrapper> newTablesMap = new Map<String, ExchangeRateProvider.ExchangeRateWrapper>();
        Set<String> existedKeys = new Set<String>();
        newTables.sort();

        for (ExchangeRateProvider.ExchangeRateWrapper table : newTables) {
            if (existedTablesLast.keySet().contains(table.getShortKey())
                    && existedTablesFirst.containsKey(table.getShortKey())
                    && table.fromDate <= existedTablesLast.get(table.getShortKey()).fromDate
                    && table.fromDate >= existedTablesFirst.get(table.getShortKey()).Effective_From__c) {

                tables.get(table.table.Id).addError(SAME_TABLE_ERROR);
            }
            else if (existedTablesLast.keySet().contains(table.getShortKey())
                        && !existedKeys.contains(table.getShortKey())
                        && table.fromDate > existedTablesLast.get(table.getShortKey()).fromDate) {

                Exchange_Rate__c existedTable = existedTablesLast.get(table.getShortKey()).table;
                existedTable.Next_Exchange_Rate__c = table.table.Id;
                updateList.add(existedTable);
                existedKeys.add(table.getShortKey());
            }

            if (newTablesMap.keySet().contains(table.getShortKey()) && table.fromDate > newTablesMap.get(table.getShortKey()).fromDate) {
                Exchange_Rate__c previousTable = newTablesMap.get(table.getShortKey()).table.clone(true, true);
                previousTable.Next_Exchange_Rate__c = table.table.Id;
                updateList.add(previousTable);
            }
            else if (newTablesMap.keySet().contains(table.getShortKey()) && table.fromDate == newTablesMap.get(table.getShortKey()).fromDate) {
                tables.get(table.table.Id).addError(SAME_TABLE_ERROR);
            }

            newTablesMap.put(table.getShortKey(), table);
        }
        proxyUpdate(updateList);
    }

    private static void proxyUpdate(List<Exchange_Rate__c> updateList) {
        if (!updateList.isEmpty()) {
            TriggerObserver.getInstance().unlockField(Exchange_Rate__c.Next_Exchange_Rate__c);
            SFDCSecurityUtils.updateProxy(updateList);
            TriggerObserver.purgeUnlockedFields(Exchange_Rate__c.Next_Exchange_Rate__c);
        }
    }

    private static Map<String, ExchangeRateProvider.ExchangeRateWrapper> getExistedTablesMap(List<Exchange_Rate__c> existedTables) {
        Map<String, ExchangeRateProvider.ExchangeRateWrapper> existedTablesMap = new Map<String, ExchangeRateProvider.ExchangeRateWrapper>();
        for (Exchange_Rate__c table : existedTables) {
            ExchangeRateProvider.ExchangeRateWrapper cew = new ExchangeRateProvider.ExchangeRateWrapper(table);
            if (!existedTablesMap.keySet().contains(cew.getShortKey())) {
                existedTablesMap.put(cew.getShortKey(), cew);
            }
        }
        return existedTablesMap;
    }

    private static Map<String, Exchange_Rate__c> getFirstTablesMap(List<Exchange_Rate__c> existedTables) {
        Map<String, Exchange_Rate__c> result = new Map<String, Exchange_Rate__c>();
        for (Exchange_Rate__c table : existedTables) {
            String key = table.From_Currency_Code__c + table.To_Currency_Code__c + table.Rate_Type__c;
            if (!result.containsKey(key)) {
                result.put(key, table);
            }
        }
        return result;
    }

    public static void updateRelatedNextTable(Map<Id, Exchange_Rate__c> oldTables) {
        List<Exchange_Rate__c> updateList = new List<Exchange_Rate__c>();
        List<Exchange_Rate__c> updateTables = DomainUtils.getExchangeRateTableByNextTableId(oldTables.keySet());

        for (Exchange_Rate__c table : updateTables) {
            if (!oldTables.keySet().contains(table.Id)) {
                table.Next_Exchange_Rate__c = getNextId(table, oldTables);
                updateList.add(table);
            }
        }
        proxyUpdate(updateList);
    }

    private static Id getNextId(Exchange_Rate__c table, Map<Id, Exchange_Rate__c> oldTables) {
        if (oldTables.keySet().contains(table.Next_Exchange_Rate__c)) {
            table.Next_Exchange_Rate__c = oldTables.get(table.Next_Exchange_Rate__c).Next_Exchange_Rate__c;
            return getNextId(table, oldTables);
        }
        else {
            return table.Next_Exchange_Rate__c;
        }
    }

}