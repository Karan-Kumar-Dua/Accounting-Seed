/**
 * Specification for Accounting Seed payment processors.
 */
public interface PaymentProcessor {

    // ********************
    // ***** customer *****
    // ********************

    /**
     * Create a customer.
     */
    Payment_Processor_Customer__c createCustomer(Payment_Processor_Customer__c processorCustomer);
    
    /**
     * Delete a customer.
     */
    void deleteCustomer(Payment_Processor_Customer__c processorCustomer);
    
    /**
     * Fetch a customer.
     */
    Payment_Processor_Customer__c getCustomer(Payment_Processor_Customer__c processorCustomer);
    
    /**
     * Fetch customers.
     */
    List<Payment_Processor_Customer__c> getCustomers(Payment_Processor__c paymentProcessor);
    
    /**
     * Update a customer.
     */
    Payment_Processor_Customer__c updateCustomer(Payment_Processor_Customer__c processorCustomer);


    // **************************
    // ***** Payment Method *****
    // **************************

    /**
     * Creates a payment method.
     * Creates the payment method in the external system and inserts the 
     * payment method in Salesforce. Sensitive payment information should 
     * not be handled or stored in Salesforce. Use a front end library 
     * provided by your payment processor to gather and tokenize payment 
     * methods.
     * 
     * Warning!!!
     * Do not store creidt card numbers. If you handle raw credit card 
     * information you are responsible for PCI complience.
     * 
     * @param paymentMethod - New payment method.
     * @param token - Tokenized payment method. 
     */
    Payment_Method__c createPaymentMethod(Payment_Method__c paymentMethod, String token);
    
    /**
     * Delete a payment method.
     * Deletes a payment method in the external system and in Salesforce.
     * 
     * @param paymentMethod - Payment method to delete.
     */
    void deletePaymentMethod (Payment_Method__c paymentMethod);
   
    /**
     * Fetch a payment method.
     */
    Payment_Method__c getPaymentMethod(Payment_Method__c paymentMethod);
    
    /**
     * Fetch payment methods related to a customer.
     */
    List<Payment_Method__c> getPaymentMethods(Payment_Processor_Customer__c processorCustomer);
    
    /**
     * Update a payment method.
     */
    Payment_Method__c updatePaymentMethod(Payment_Method__c paymentMethod);


    // ***********************
    // ***** Credit Card *****
    // ***********************

    /**
     * Authorize a charge.
     */
    Payment_Activity__c ccAuthorization(Payment_Method__c paymentMethod);
    
    /**
     * Capture a charge.
     */
    Payment_Activity__c ccCapture(Payment_Method__c paymentMethod);
   
    /**
     * Credit the card.
     */
    Payment_Activity__c ccCredit(Payment_Method__c paymentMethod);
   
    /**
     * Refund a charge.
     */
    Payment_Activity__c ccRefund(Payment_Method__c paymentMethod);
    
    /**
     * Create a charge.
     */
    List<PaymentSaleItem> ccSale(List<PaymentSaleItem> saleItems);
    
    /**
     * Void a payment
     */
    void ccVoid(Payment_Activity__c paymentActivity);


    // ***************
    // ***** ACH *****
    // ***************

    /**
     * Credit the account.
     */
    Payment_Activity__c achCredit(Payment_Method__c paymentMethod);
    
    /**
     * Refund a charge.
     */
    Payment_Activity__c achRefund(Payment_Method__c paymentMethod);
    
    /**
     * Create a charge.
     */
    List<PaymentSaleItem> achSale(List<PaymentSaleItem> saleItems);
    
    /**
     * Void a payment
     */
    void achVoid(Payment_Activity__c paymentActivity);


    // ****************************
    // ***** Payment Activity *****
    // ****************************

    /**
     *  Fetch payment activity updates.
     */
    List<Payment_Activity__c> getPaymentActivityStatus(List<Payment_Activity__c> paymentActivities);
}