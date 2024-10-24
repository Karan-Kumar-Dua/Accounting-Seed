public with sharing class PaymentSaleItem {
    public Payment_Method__c paymentMethod;
    public Cash_Receipt__c cashReceipt;
    public List<Billing__c> billings;
    public Payment_Activity__c paymentActivity;

    public Errors errors;

    public PaymentSaleItem(Payment_Method__c paymentMethod, Cash_Receipt__c cashReceipt) {
        this(paymentMethod, cashReceipt, null);
    }

    public PaymentSaleItem(Payment_Method__c paymentMethod, Cash_Receipt__c cashReceipt, List<Billing__c> billings) {
        this.paymentMethod = paymentMethod;
        this.cashReceipt = cashReceipt;
        this.billings = billings;
        this.errors = new Errors();
    }

    public PaymentSaleItem paymentActivity(Payment_Activity__c paymentActivity) {
        this.paymentActivity = paymentActivity;
        return this;
    }

    public class Errors {
        public List<Map<String, String>> errorsHolder;

        public Errors() {
            this.errorsHolder = new List<Map<String, String>>();
        }

        public Errors add(String message) {
            return add(message, 'ERROR');
        }

        public Errors add(String message, String code) {
            errorsHolder.add(new Map<String, String>{
                    'message' => message,
                    'code' => code
            });
            return this;
        }

        public Errors addAll(List<Map<String, String>> errorsHolder) {
            this.errorsHolder.addAll(errorsHolder);
            return this;
        }

        public Boolean isEmpty() {
            return errorsHolder.isEmpty();
        }
    }
}