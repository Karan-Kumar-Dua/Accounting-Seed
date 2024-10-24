public with sharing class FinancialCubeTransactionActions {
   
    public static final String INSERT_ERROR = Label.ERR_FINANCE_CUBE_INSERT;
    public static final String UPDATE_ERROR = Label.ERR_FINANCE_CUBE_UPDATE;
    public static final String DELETE_ERROR = Label.ERR_FINANCE_CUBE_DELETE;
    public static Boolean isPreventOverride = false;

    public static void preventInsert(List<Financial_Cube_Transaction__c> fcTransactions) {
        if (!isPreventOverride) {
            for (Financial_Cube_Transaction__c fc : fcTransactions) {
                fc.addError(INSERT_ERROR, false);
            }
        }
    }

    public static void preventUpdate(List<Financial_Cube_Transaction__c> fcTransactions) {
        if (!isPreventOverride) {
            for (Financial_Cube_Transaction__c fc : fcTransactions) {
                fc.addError(UPDATE_ERROR, false);
            }
        }
    }

    public static void preventDelete(List<Financial_Cube_Transaction__c> fcTransactions) {
        if (!isPreventOverride) {
            for (Financial_Cube_Transaction__c fc : fcTransactions) {
                fc.addError(DELETE_ERROR, false);
            }
        }
    }

    public static void setRequiredFields(List<Financial_Cube_Transaction__c> fcTransactions) {
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            Map<Id, Transaction__c> transactionMap;
            Set<Id> transactionIds = new Set<Id>();
            for (Financial_Cube_Transaction__c newFCTR : fcTransactions) {
                transactionIds.add(newFCTR.Transaction__c);
            }
            transactionMap = new Map<Id, Transaction__c>(DomainUtils.getTransactionsById(transactionIds));

            for (Financial_Cube_Transaction__c newFCTR : fcTransactions) {
                if (transactionMap.get(newFCTR.Transaction__c) != NULL) {
                    newFCTR.put('CurrencyIsoCode', transactionMap.get(newFCTR.Transaction__c).get('CurrencyIsoCode'));
                }
            }
        }
    }

}