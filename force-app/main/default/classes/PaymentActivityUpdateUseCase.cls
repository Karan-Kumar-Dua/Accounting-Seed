public with sharing class PaymentActivityUpdateUseCase {
    
    private PaymentGateway gtwy;

    public with sharing class UpdateResult {
        public Boolean ok;
        public Boolean cashReceiptRequiresVoid;
        public Id processorId;
        public Payment_Activity__c activity;
        public Database.Error[] errors;
        public UpdateResult(Payment_Activity__c activity) {
            this.ok = true;
            this.cashReceiptRequiresVoid = false;
            this.processorId = activity?.Payment_Method__r.Payment_Processor__c;
            this.activity = activity;
            this.errors = null;
        }
    }

    public PaymentActivityUpdateUseCase(PaymentGateway gtwy) {
        this.gtwy = gtwy;
    }

    public UpdateResult[] updatePaymentActivities(List<Payment_Activity__c> activities) {
        // callout to get latest activity status
        List<Payment_Activity__c> newActivities = gtwy.getPaymentActivityStatus(activities);

        // create a map to avoid nested for loop
        Map<Id, Payment_Activity__c> oldActivities = new Map<Id, Payment_Activity__c>(activities);

        // transform the new and old activities into UpdateResults
        Map<Id,UpdateResult> resultsByPaymentId = transformResults(newActivities, oldActivities);

        // attempt to save the activity updates
        resultsByPaymentId = saveUpdatedActivities(newActivities, oldActivities, resultsByPaymentId);

        return resultsByPaymentId.values();
    }

    private static Map<Id,UpdateResult> saveUpdatedActivities(List<Payment_Activity__c> newActivities, Map<Id, Payment_Activity__c> oldActivities, Map<Id,UpdateResult> resultsByPaymentId) {
        List<Database.SaveResult> dbResults = SFDCSecurityUtils.updateProxy(newActivities, false);
        UpdateResult result;
        for (Database.SaveResult dbResult : dbResults) {
            if (!dbResult.isSuccess()) {
                result = resultsByPaymentId.get(dbResult.getId());
                result.ok = false;
                result.cashReceiptRequiresVoid = false;
                result.errors = dbResult.getErrors();
            }
        }
        return resultsByPaymentId;
    }

    /**
     * Transforms the new and old activities into UpdateResults
     */
    private static Map<Id,UpdateResult> transformResults(List<Payment_Activity__c> newActivities, Map<Id, Payment_Activity__c> oldActivities) {
        Map<Id,UpdateResult> resultsByPaymentId = new Map<Id,UpdateResult>();

        Payment_Activity__c oldActivity;
        for (Payment_Activity__c newActivity : newActivities) {
            UpdateResult result = new UpdateResult(newActivity);

            // get the corresponding old activity
            oldActivity = oldActivities.get(newActivity.Id);

            // if the status change is not supported, then revert the status.
            // for example, we can't handle void -> success transitions, so we revert the status.
            if (!isStatusChangeSupported(newActivity, oldActivity)) {
                newActivity.Status__c = oldActivity.Status__c;
            }
            
            // does the corresponding CR need to be voided?
            result.cashReceiptRequiresVoid = isVoidRequired(newActivity, oldActivity);

            resultsByPaymentId.put(result.activity.Id, result);
        }

        return resultsByPaymentId;
    }

    /**
     * Compares the old activity status with the new activity status to determine if a void is required in AS.
     */
    @TestVisible
    private static Boolean isVoidRequired(Payment_Activity__c newActivity, Payment_Activity__c oldActivity) {
        if (newActivity.Cash_Receipt__c == null) {
            // no CR to void
            return false;
        } else if (oldActivity.Status__c == PaymentActivityHelper.PENDING_STATUS && newActivity.Status__c == PaymentActivityHelper.ERROR_STATUS) {
            // Pending -> Error - the payment should be voided in AS to effectively cancel the errant payment
            return true;
        } else if (oldActivity.Status__c == PaymentActivityHelper.PENDING_STATUS && newActivity.Status__c == PaymentActivityHelper.VOID_STATUS) {
            // Pending -> Void - the payment should be voided in AS to match the the status in external system
            return true;
        } else if (oldActivity.Status__c == PaymentActivityHelper.SUCCESS_STATUS && newActivity.Status__c == PaymentActivityHelper.VOID_STATUS) {
            // Success -> Void - the payment should be voided in AS to match the the status in external system
            return true;
        }
        // the payment should not be voided
        return false;
    }

    /**
     * Compares the old activity status with the new activity status to determine if a status change is allowed.
     * This is because there are certain scenarios we don't handle. For example, undoing a void.
     */
    @TestVisible
    private static Boolean isStatusChangeSupported(Payment_Activity__c newActivity, Payment_Activity__c oldActivity) {
        String oldStatus = oldActivity.Status__c;
        String newStatus = newActivity.Status__c;
        if (oldStatus == PaymentActivityHelper.PENDING_STATUS) {
            return newStatus == PaymentActivityHelper.PENDING_STATUS
                || newStatus == PaymentActivityHelper.DECLINED_STATUS 
                || newStatus == PaymentActivityHelper.SUCCESS_STATUS 
                || newStatus == PaymentActivityHelper.ERROR_STATUS 
                || newStatus == PaymentActivityHelper.VOID_STATUS;
        } else if (oldStatus == PaymentActivityHelper.DECLINED_STATUS) {
            return newStatus == PaymentActivityHelper.DECLINED_STATUS;
        } else if (oldStatus == PaymentActivityHelper.SUCCESS_STATUS) {
            return newStatus == PaymentActivityHelper.SUCCESS_STATUS
            || newStatus == PaymentActivityHelper.VOID_STATUS;
        } else if (oldStatus == PaymentActivityHelper.ERROR_STATUS) {
            return newStatus == PaymentActivityHelper.ERROR_STATUS;
        } else if (oldStatus ==  PaymentActivityHelper.VOID_STATUS) {
            return newStatus == PaymentActivityHelper.VOID_STATUS;   
        } else {
            return false;
        }
    }

}