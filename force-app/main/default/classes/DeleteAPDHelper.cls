public with sharing class DeleteAPDHelper extends AbstractLWCHelper {

    @AuraEnabled
    public static String validateAPDs(Id cdId) {
        ValidatedDisbursements validatedDisbursements;
        try {
            validatedDisbursements = validateAPD(cdId);

            if (validatedDisbursements.apDisbursements.isEmpty()
                && String.isBlank(validatedDisbursements.successMessage)
                && String.isBlank(validatedDisbursements.message)) {
                validatedDisbursements.successMessage = Label.INF_NO_APD_DELETE;
            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return String.isNotBlank(validatedDisbursements.successMessage) ? validatedDisbursements.successMessage : validatedDisbursements.message;
    }

    @AuraEnabled
    public static String startDeleteAPDJob(Id cdId) {
        ValidatedDisbursements validatedDisbursements;
        try {
            validatedDisbursements = validateAPD(cdId);

            if (validatedDisbursements.message != null) {
                throw buildException(ExceptionCode.VALIDATION, validatedDisbursements.message);
            }

            if (!validatedDisbursements.apDisbursements.isEmpty() && String.isNotBlank(validatedDisbursements.successMessage)) {
                Set<Id> apdIds = new Map<Id, AP_Disbursement__c> (validatedDisbursements.apDisbursements).keySet();
                Database.executeBatch(new DeleteAPDBatch(apdIds, validatedDisbursements.cashDisbursement), 100);
            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }

        return validatedDisbursements.successMessage;
    }

    private static ValidatedDisbursements validateAPD(Id cdId) {
        ValidatedDisbursements result = new ValidatedDisbursements();
        result.apDisbursements = new List<AP_Disbursement__c>();

        List<AP_Disbursement__c> apDisbursements = DomainUtils.getApDisbursementsByDisbursement(new Set<Id> {cdId});

        if (!apDisbursements.isEmpty()) {
            for (AP_Disbursement__c apd : apDisbursements) {
                if (apd.Cash_Disbursement__r.Source__c == CashDisbursementActions.SOURCE_MANUAL
                    && !AccountingPeriodHandler.getInstance().isConsideredOpen(apd.Cash_Disbursement__r.Accounting_Period__c)) {
                    result.message = Label.ERR_APD_CD_ASSOCIATED_IN_CLOSED_PERIOD;
                    break;
                }

                if (apd.Cash_Disbursement__r.Source__c == CashDisbursementActions.SOURCE_PAYABLE
                    && !AccountingPeriodHandler.getInstance().isConsideredOpen(apd.Cash_Disbursement__r.Accounting_Period__c)) {
                    result.message = Label.ERR_CD_ASSOCIATED_IN_CLOSED_PERIOD;
                    break;
                }

                if (apd.Cash_Disbursement__r.Source__c == CashDisbursementActions.SOURCE_MANUAL
                    && AccountingPeriodHandler.getInstance().isConsideredOpen(apd.Accounting_Period__c)) {
                    result.apDisbursements.add(apd);
                }
            }

            if (apDisbursements[0].Cash_Disbursement__r.Source__c == CashDisbursementActions.SOURCE_MANUAL) {
                if (result.apDisbursements.isEmpty()) {
                    result.message = Label.ERR_APD_CD_ASSOCIATED_IN_CLOSED_PERIOD;
                }
                else {
                    result.successMessage = Label.APD_OPEN_PERIOD_DELETE_BATCH_SUCCESS;
                }
            }

            if (apDisbursements[0].Cash_Disbursement__r.Source__c == CashDisbursementActions.SOURCE_PAYABLE
                && apDisbursements[0].Cash_Disbursement__r.Payment_Status__c == CashDisbursementActions.STATUS_PAID
                && String.isBlank(result.message)) {

                result.apDisbursements.addAll(apDisbursements);
                result.cashDisbursement = apDisbursements[0].Cash_Disbursement__r;
                result.successMessage = Label.APD_CD_DELETE_BATCH_SUCCESS;
            }

            if (apDisbursements[0].Cash_Disbursement__r.Source__c == CashDisbursementActions.SOURCE_PAYABLE
                && apDisbursements[0].Cash_Disbursement__r.Payment_Status__c == CashDisbursementActions.STATUS_VOID
                && String.isBlank(result.message)) {
                result.apDisbursements.addAll(apDisbursements);
                result.successMessage = Label.APD_DELETE_BATCH_SUCCESS;
            }
        }
        return result;
    }

    public with sharing class ValidatedDisbursements {
        public Cash_Disbursement__c cashDisbursement;
        public String message;
        public String successMessage;
        public List<AP_Disbursement__c> apDisbursements;
    }

}