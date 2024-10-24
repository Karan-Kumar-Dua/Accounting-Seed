public with sharing class CashReceiptVoidHelper {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    /**
     * Check the cash flow statement is enabled and we have one payment activity related to the current cash receipt
     */
    @AuraEnabled(cacheable=true)
    public static VoidDetails getVoidDetails(){
        try {
            return new VoidDetails();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * Void a Cash Receipt with the provided details
     */
    @AuraEnabled
    public static void voidCashReceipt(String recordId, String jsonReq){
        try {
            //deserialize the request into the VoidData wrapper 
            VoidData data = (VoidData)JSON.deserialize(jsonReq, VoidData.class);
            //call the the method to complete the void
            new CashReceiptVoid().voidCashReceipt(data);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    //void detail wrapper to hold initial details for the Void UI
    public class VoidDetails{
        @AuraEnabled
        public Boolean isCashFlowStatementEnabled{get; set;}
        public VoidDetails(){
            this.isCashFlowStatementEnabled = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
        }
    }
    //void data wrapper
    public class VoidData{
        public String cashReceiptId{get;set;}
        public Date voidReceiptDate{get; set;}
        public String description{get; set;}
        public String cashFlowCategory{get; set;}
        public String paymentId{get;set;}
        public VoidData(){}
    }
}