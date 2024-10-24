public with sharing class PaymentActivityACHStatus {

    @AuraEnabled
    public static Integer initOnLoad() {
        try {
            checkAccess();
            return countPendingPayments();
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public static void checkAccess() {
        SFDCSecurityUtils.checkRead(
            Payment_Activity__c.getSObjectType(),
            new List<String>{
                'Cash_Receipt__c',
                'Error_Message__c',
                'Error_Type__c'
            }
        );

        SFDCSecurityUtils.checkRead(Cash_Receipt__c.getSObjectType(), new List<String>());

        SFDCSecurityUtils.checkUpdate(
            Payment_Activity__c.getSObjectType(),
            new List<String>{
                'Error_Message__c',
                'Error_Type__c'
            }
        );
    }

    public static Integer countPendingPayments() {
        return [SELECT count() FROM Payment_Activity__c WHERE Status__c = 'Pending'];
    }

    @AuraEnabled
    public static Boolean startStatusProcessing() {
        try {
            PaymentActivityACHStatusBatch batchInstance = new PaymentActivityACHStatusBatch();
            Database.executeBatch(batchInstance, 100);
            return true;
        }
        catch (Exception ex) {
            return false;
        }
    }

}