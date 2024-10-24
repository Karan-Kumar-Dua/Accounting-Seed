public with sharing class PaymentProcessorUtils {

    public static final Set<String> paymentMethodTypes = new Set<String>{
            PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE, PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE
    };
    
    private static final Integer SINGLE = 1;

    public static final String PMT_PROC_BINDING_TYPE = 'PaymentProcessor';

    public static Payment_Processor__c getPaymentProcessor(Id processorId) {
        List<Payment_Processor__c> processors = getPaymentProcessors(new Set<Id>{ processorId });
        return processors == null || processors.isEmpty() ? null : processors.get(0);
    }

    public static List<Payment_Processor__c> getPaymentProcessors(Set<Id> processorIds) {
        List<String> fields = new List<String>{
            'Active__c',
            'Connected_Account_Token__c',
            'Id',
            'Test_Mode__c',
            'Type__c',
            'External_Key__c',
            'Merchant_GL_Account__c',
            'Merchant_GL_Account__r.Name',
            'CC_Flat_Fee__c',
            'Convenience_Fees_GL_Account__c',
            'Credit_Card_Convenience_Fee_Type__c',
            'CC_Percent__c',
            'Enable_Convenience_Fees__c',
            'ACH_Flat_Fee__c',
            'ACH_Percent__c',
            'ACH_Convenience_Fee_Type__c'
        };

        String condition = 'Id IN :processorIds';

        SOQLBuilder q = new SOQLBuilder(Payment_Processor__c.SObjectType);
        q.assertIsAccessible()
            .selectFields(fields)
            .setCondition(condition);

        return (List<Payment_Processor__c>) Database.query(q.toSOQL());
    }

    public static Account getAccount(Id accountId) {
        List<String> fields = new List<String>{
            'Id',
            'Name'
        };

        String condition = 'Id = :accountId';

        SOQLBuilder q = new SOQLBuilder(Account.SObjectType);
        q.assertIsAccessible()
            .selectFields(fields)
            .setCondition(condition)
            .setLimit(SINGLE);

        List<Account> accts = (List<Account>) Database.query(q.toSOQL());

        return accts == null || accts.isEmpty() ? null : accts.get(0); 
    }

    public static Payment_Processor_Customer__c getPaymentProcessorCustomer(Id processorId, Id customerId) {
        List<String> fields = new List<String>{
            'Id', 
            'Processor__c', 
            'Account__c', 
            'External_Id__c' 
        };

        String condition = 'Processor__c = :processorId AND Account__c = :customerId';

        SOQLBuilder q = new SOQLBuilder(Payment_Processor_Customer__c.SObjectType);
        q.assertIsAccessible()
            .selectFields(fields)
            .setCondition(condition)
            .setLimit(SINGLE);

        List<Payment_Processor_Customer__c> customers = (List<Payment_Processor_Customer__c>) Database.query(q.toSOQL());

        return customers == null || customers.isEmpty() ? null : customers.get(0);
    }
    public static Payment_Processor_Customer__c getPaymentProcessorCustomer(
            Id junctionId) {
        
        List<String> fields = new List<String>{
            'Processor__c',
            'External_Id__c',
            'Account__c'
        };

        String condition = 'Id = :junctionId';

        SOQLBuilder q = new SOQLBuilder(Payment_Processor_Customer__c.SObjectType);
        q.assertIsAccessible()
            .selectFields(fields)
            .setCondition(condition)
            .setLimit(SINGLE);

        List<Payment_Processor_Customer__c> ppc = (List<Payment_Processor_Customer__c>) Database.query(q.toSOQL());

        return ppc == null || ppc.isEmpty() ? null : ppc.get(0);   
    }
    public static Account getAccountWithDetails(Id accountId) {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'BillingStreet',
            'BillingCity',
            'BillingState',
            'BillingPostalCode',
            'BillingCountry',
            'ShippingStreet',
            'ShippingCity',
            'ShippingState',
            'ShippingPostalCode',
            'ShippingCountry',
            'Billing_Contact__c',
            'Shipping_Contact__c',
            'Billing_Contact__r.LastName',
            'Billing_Contact__r.FirstName',
            'Billing_Contact__r.Phone',
            'Billing_Contact__r.Email',
            'Shipping_Contact__r.LastName',
            'Shipping_Contact__r.FirstName',
            'Shipping_Contact__r.Phone',
            'Shipping_Contact__r.Email'
        };

        String condition = 'Id = :accountId';

        SOQLBuilder q = new SOQLBuilder(Account.SObjectType);
        q.assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fields)
            .setCondition(condition)
            .setLimit(SINGLE);

        List<Account> accts = (List<Account>) Database.query(q.toSOQL());

        return accts == null || accts.isEmpty() ? null : accts.get(0); 
    }
    public static Payment_Method__c getPaymentMethod(Id paymentMethodId) {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Payment_Processor__c',
            'Customer__c',
            'External_Id__c',
            'Payment_Method_Type__c',
            'Type__c',
            'Expiration_Month__c',
            'Expiration_Year__c',
            'Last_Four_Digits__c',
            'Status__c'
        };

        String condition = 'Id = :paymentMethodId';

        SOQLBuilder q = new SOQLBuilder(Payment_Method__c.SObjectType);
        q.assertIsAccessible()
            .selectFields(fields)
            .setCondition(condition)
            .setLimit(SINGLE);

        List<Payment_Method__c> pm = (List<Payment_Method__c>) Database.query(q.toSOQL());

        return pm == null || pm.isEmpty() ? null : pm.get(0); 
    }
    public static String getCurrencyCode(Cash_Receipt__c cashReceipt){
        String currencyCode;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            currencyCode = (String) cashReceipt.get('CurrencyIsoCode');
            if (String.isBlank(currencyCode)) {
                Id ledgerId = cashReceipt.Ledger__c == null 
                    ? LedgerHandler.getOrgDefaultLedgerId() 
                    : cashReceipt.Ledger__c;
                currencyCode = LedgerHandler.getLedgerCurrency(ledgerId);
            }
        } else {
            currencyCode = MultiCurrencyHandler.CORPORATE_CURRENCY;
        }
        return currencyCode;
    }

    public static String composeKey(List<String> keyParts) {
        return String.join(keyParts, ':');
    }

    public static Map<String, Cash_Receipt__c> cashReceiptsByRefs(Set<String> refs) {
        return cashReceiptsByRefs(DomainUtils.getCashReceiptByPaymentRef(refs));
    }

    public static Map<String, Cash_Receipt__c> cashReceiptsByRefs(List<Cash_Receipt__c> cashReceipts) {
        Map<String, Cash_Receipt__c> cashReceiptsByRefs = new Map<String, Cash_Receipt__c>();
        for (Cash_Receipt__c cashReceipt : cashReceipts) {
            cashReceiptsByRefs.put(cashReceipt.Payment_Reference__c, cashReceipt);
        }
        return cashReceiptsByRefs;
    }
    public static Map<String,Payment_Method__c> getPaymentMethodsByExternalId(Id customerId,Id processorId){
        return getPaymentMethodsByExternalId(DomainUtils.getPaymentMethodsByAccountAndProcessor(customerId,processorId));
    }
    public static Map<String, Payment_Method__c> getPaymentMethodsByExternalId(List<Payment_Method__c> paymentMethods) {
        Map<String, Payment_Method__c> paymentMethodsByExternalId = new Map<String, Payment_Method__c>();
        for (Payment_Method__c paymentMethod : paymentMethods) {
            paymentMethodsByExternalId.put(paymentMethod.External_Id__c, paymentMethod);
        }
        return paymentMethodsByExternalId;
    }
}