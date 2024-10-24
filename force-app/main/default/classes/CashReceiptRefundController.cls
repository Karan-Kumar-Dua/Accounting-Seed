public with sharing class CashReceiptRefundController extends AbstractLWCHelper {
    @AuraEnabled
    public static Map<String, Object> create(Map<String, Object> params) {
        Map<String, Object> response;
        try {

        } catch (DmlException ex) {
            throw new AuraHandledException(ex.getDmlMessage(0));
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return response;
    }
}