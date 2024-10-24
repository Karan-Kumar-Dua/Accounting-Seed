public with sharing class FinancialReportResultValueActions {

    public static void setCurrencyByParentLedger(List<Financial_Report_Result_Value__c> frrList) {
        if (!MultiCurrencyHandler.isMultiCurrencyEnabled) {
            return;
        }

        Set<Id> frrIds = new Set<Id>();
        for (Financial_Report_Result_Value__c frrv : frrList) {
            frrIds.add(frrv.Financial_Report_Result__c);
        }

        Map<Id, Financial_Report_Result__c> reportResultMap = new Map<Id, Financial_Report_Result__c>(DomainUtils.getFinancialReportResultsById(frrIds));

        for (Financial_Report_Result_Value__c frrv : frrList) {
            frrv.put(
                'CurrencyIsoCode',
                LedgerHandler.getInstanceWithoutSharing()
                    .getAllLedgersMap()
                    .get(reportResultMap.get(frrv.Financial_Report_Result__c).Ledger__c)
                    .get('CurrencyIsoCode')
            );
        }
    }

}