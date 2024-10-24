public with sharing class CashDisbursementBatchActions {
   
    public static final String DELETE_ERROR = Label.ERR_CD_BATCH_DELETE;
    public static final String UPDATE_CURRENCY_ERROR = Label.ERR_CD_BATCH_UPDATE_CURRENCY;

    public static Boolean isPreventUpdateOverride = false;

    public static void preventDeleteAction(Map<Id, Cash_Disbursement_Batch__c> cBatchMap) {
        for (Cash_Disbursement_Batch__c cdb : DomainUtils.getCashDisbursementBatchWithPostedCDsById(cBatchMap.keySet())) {
            if (cdb.Cash_Disbursements__r != NULL && cdb.Cash_Disbursements__r.size() > 0) {
                cBatchMap.get(cdb.Id).addError(DELETE_ERROR);
            }
        }
    }

    public static void preventUpdateCurrency(Map<Id, Cash_Disbursement_Batch__c> newCDBatchMap,
                                             Map<Id, Cash_Disbursement_Batch__c> oldCDBatchMap) {

        if (!MultiCurrencyHandler.isMultiCurrencyEnabled || isPreventUpdateOverride) {
            return;
        }

        Set<Id> cdbWithChangedCurrencyIds = new Set<Id>();
        for (Cash_Disbursement_Batch__c newCDB : newCDBatchMap.values()) {
            Cash_Disbursement_Batch__c oldCDB = oldCDBatchMap.get(newCDB.Id);
            if (newCDB.get('CurrencyIsoCode') != oldCDB.get('CurrencyIsoCode')) {
                cdbWithChangedCurrencyIds.add(newCDB.Id);
            }
        }

        if (!cdbWithChangedCurrencyIds.isEmpty()) {
            for (Cash_Disbursement_Batch__c cdb : DomainUtils.getCashDisbursementBatchById(cdbWithChangedCurrencyIds, true)) {
                if (!cdb.Cash_Disbursements__r.isEmpty()) {
                    newCDBatchMap.get(cdb.Id).addError(UPDATE_CURRENCY_ERROR);
                }
            }
        }

    }

    public static void deleteSourceRecordUpdateBTStatus(Map<Id, Cash_Disbursement_Batch__c> oldCDBsMap) {
        Set<Id> cdbIds = oldCDBsMap.keySet();
        List<Cash_Disbursement__c> cashDisbursements = new List<Cash_Disbursement__c>();
        for (Cash_Disbursement_Batch__c cdb : DomainUtils.getCashDisbursementBatchWithMatchedCDsById(cdbIds)) {
            if (!cdb.Cash_Disbursements__r.isEmpty()) {
                cashDisbursements.addAll(cdb.Cash_Disbursements__r);
            }
        }
        if (!cashDisbursements.isEmpty()) {
            SObjectActions.deleteSourceRecordUpdateBTStatus(cashDisbursements);
        }
    }

}