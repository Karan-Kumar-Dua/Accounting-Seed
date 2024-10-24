public with sharing class BankRecCalculatorHelper {
    @AuraEnabled
    public static BRECResponse getMultiCurrencyStatus(Id bankRecId){
        Boolean currencyMismatch = false;
        Boolean isClearJobRunning = false;
        try {
            Bank_Reconciliation2__c brec = getBRECById(bankRecId);
            isClearJobRunning = BatchJobUtils.checkJobRunning( new Set<String>{'BankReconciliationClearItemsBatch'} );
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {                
                Ledger__c ledger = LedgerHandler.getInstanceWithSharing().getLedgerById(brec.Ledger__c);                
                currencyMismatch = !MultiCurrencyHandler.isSameCurrency((String)brec.get('CurrencyIsoCode'), ledger);
            }
        } catch (exception ex) {
            String errMsg = ex.getMessage();
                errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('EXCEPTION,') - 10);
                if (errMsg.contains('>')) {
                    errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('>') - 1);
                    errMsg = errMsg.left(errMsg.indexOf('<'));
                }
                else {
                    errMsg = errMsg.left(errMsg.indexOf(': ['));
                }
                return new BRECResponse(currencyMismatch, isClearJobRunning, new List<String>{errMsg});
        }
        return new BRECResponse(currencyMismatch, isClearJobRunning, NULL);
    }

    @AuraEnabled
    public static String getAccountingPeriodStatus(Date theDate) {
        return AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(theDate)?.Status__c;
    }

    private static Bank_Reconciliation2__c getBRECById(Id bankRecId) {
        return DomainUtils.getBankRecsById(new Set<Id>{bankRecId})[0];
    }

    public class BRECResponse {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public List<String> errors;
        @AuraEnabled
        public Boolean currencyMismatch;
        @AuraEnabled
        public Boolean isClearJobRunning;
        
        public BRECResponse(Boolean currencyMismatch, Boolean isClearJobRunning, List<String> errors) {
            this.isSuccess = errors == null || errors.isEmpty();
            this.currencyMismatch = currencyMismatch;
            this.isClearJobRunning = isClearJobRunning;
            this.errors = errors;        
        }
    }


}