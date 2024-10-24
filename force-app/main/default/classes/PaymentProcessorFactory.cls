/**
 * Factory for `PaymentProcessor` interface.
 * Caches created instances for efficency.
 */
public with sharing class PaymentProcessorFactory {

    /* 
     * Caches instances which have already been created. 
     * Avoids creation of multiple instances during bulk processing.
     * 
     * name of the binding => concrete instance
     */
    private Map<String,PaymentProcessor> instanceCache;

    public PaymentProcessorFactory() {
        this.instanceCache = new Map<String,PaymentProcessor>();
    }

    public Map<PaymentProcessor, Map<String, List<PaymentSaleItem>>> getPaymentProcessor(List<PaymentSaleItem> saleItems) {
        Set<Id> paymentProcessorIds = new Set<Id>();
        Set<Id> paymentMethodIds = new Set<Id>();
        for (PaymentSaleItem saleItem : saleItems) {
            if (String.isBlank(saleItem.paymentMethod.Id)) {
                paymentProcessorIds.add(saleItem.paymentMethod.Payment_Processor__c);
            } else {
                paymentMethodIds.add(saleItem.paymentMethod.Id);
            }
        }

        Map<Id, Payment_Processor__c> paymentProcessorsByIds = !paymentProcessorIds.isEmpty() ?
            new Map<Id, Payment_Processor__c>(queryPaymentProcessors(paymentProcessorIds)) : new Map<Id, Payment_Processor__c>();
        Map<Id, Payment_Method__c> paymentMethodsByIds = !paymentMethodIds.isEmpty() ?
            new Map<Id, Payment_Method__c>(queryPaymentMethods(paymentMethodIds)) : new Map<Id, Payment_Method__c>();

        Map<String, Map<String, List<PaymentSaleItem>>> saleItemsByTypes = new Map<String, Map<String, List<PaymentSaleItem>>>();
        for (PaymentSaleItem saleItem : saleItems) {
            if (!saleItem.errors.isEmpty()) { continue; }

            String typeKey = null;
            if (paymentProcessorsByIds.get(saleItem.paymentMethod.Payment_Processor__c) != null) {
                typeKey = paymentProcessorsByIds.get(saleItem.paymentMethod.Payment_Processor__c).Type__c;
            } else if (paymentMethodsByIds.get(saleItem.paymentMethod.Id) != null) {
                typeKey = paymentMethodsByIds.get(saleItem.paymentMethod.Id).Payment_Processor__r.Type__c;
            }

            Map<String, List<PaymentSaleItem>> itemsByMethodTypes = saleItemsByTypes.containsKey(typeKey) ?
                saleItemsByTypes.get(typeKey) : new Map<String, List<PaymentSaleItem>>();

            List<PaymentSaleItem> tempSalesItems = itemsByMethodTypes.containsKey(saleItem.paymentMethod.Payment_Method_Type__c) ?
                itemsByMethodTypes.get(saleItem.paymentMethod.Payment_Method_Type__c) : new List<PaymentSaleItem>();
            tempSalesItems.add(saleItem);
            itemsByMethodTypes.put(saleItem.paymentMethod.Payment_Method_Type__c, tempSalesItems);
            saleItemsByTypes.put(typeKey, itemsByMethodTypes);
        }

        Map<PaymentProcessor, Map<String, List<PaymentSaleItem>>> saleItemsByInstances = new Map<PaymentProcessor, Map<String, List<PaymentSaleItem>>>();
        for (String typeKey : saleItemsByTypes.keySet()) {
            saleItemsByInstances.put(getProcessorInstance(typeKey), saleItemsByTypes.get(typeKey));
        }
        return saleItemsByInstances;
    }

    private List<Payment_Processor__c> queryPaymentProcessors(Set<Id> ids) {
        return (List<Payment_Processor__c>) Database.query(
            (new SOQLBuilder(Payment_Processor__c.SObjectType))
                .assertIsAccessible()
                .selectFields(new List<String>{
                    'Id',
                    'Type__c'
                })
                .setCondition('Id IN :ids AND Active__c = TRUE')
                .toSOQL()
        );
    }

    private List<Payment_Method__c> queryPaymentMethods(Set<Id> ids) {
        return (List<Payment_Method__c>) Database.query(
            (new SOQLBuilder(Payment_Method__c.SObjectType))
                .assertIsAccessible()
                .selectFields(new List<String>{
                    'Id',
                    'Payment_Processor__r.Type__c'
                })
                .setCondition('Id IN :ids AND Payment_Processor__r.Active__c = TRUE')
                .toSOQL()
        );
    }

    public PaymentProcessor getPaymentProcessor(Payment_Processor__c paymentProcessor) {
        if (paymentProcessor == null) {
            return null;
        } 

        List<Payment_Processor__c> pmtProc = queryPaymentProcessors(new Set<Id>{paymentProcessor.Id});
        
        if (pmtProc == null || pmtProc.isEmpty()) {
            return null;
        }

        PaymentProcessor p = getProcessorInstance(pmtProc[0].Type__c);
        
        return p;
    }

    public PaymentProcessor getPaymentProcessor(Billing__c billing) {
        if (billing == null) {
            return null;
        }

        List<String> fields = new List<String>{
            'Id',
            'Payment_Processor__c',
            'Payment_Processor__r.Type__c'
        };
        Id billingId = billing.Id;
        String condition = 'Id = :billingId AND Payment_Processor__r.Active__c = TRUE';
        SOQLBuilder q = new SOQLBuilder(Billing__c.SObjectType);
        q.assertIsAccessible()
            .selectFields(fields)
            .setCondition(condition);

        List<Billing__c> bill = (List<Billing__c>) Database.query(q.toSOQL());
        
        if (bill == null || bill.isEmpty()) {
            return null;
        }

        PaymentProcessor p = getProcessorInstance(bill[0].Payment_Processor__r.Type__c);
        
        return p;
    }

    public PaymentProcessor getPaymentProcessor(Payment_Activity__c paymentActivity) {
        if (paymentActivity == null) {
            return null;
        }

        List<String> fields = new List<String>{
            'Id',
            'Payment_Method__r.Payment_Processor__c',
            'Payment_Method__r.Payment_Processor__r.Type__c'
        };
        Id paymentActivityId = paymentActivity.Id;
        String condition = 'Id = :paymentActivityId AND Payment_Method__r.Payment_Processor__r.Active__c = TRUE';
        SOQLBuilder q = new SOQLBuilder(Payment_Activity__c.SObjectType);
        q.assertIsAccessible()
            .selectFields(fields)
            .setCondition(condition);

        List<Payment_Activity__c> pmtActivity = (List<Payment_Activity__c>) Database.query(q.toSOQL());
        
        if (pmtActivity == null || pmtActivity.isEmpty()) {
            return null;
        }

        PaymentProcessor p = getProcessorInstance(pmtActivity[0].Payment_Method__r.Payment_Processor__r.Type__c);
        
        return p;
    }

    public PaymentProcessor getPaymentProcessor(Payment_Method__c paymentMethod) {
        if (paymentMethod == null) {
            return null;
        }

        List<Payment_Method__c> pmtMethods = queryPaymentMethods(new Set<Id>{paymentMethod.Id});

        if (pmtMethods == null || pmtMethods.isEmpty()) {
            return null;
        }

        PaymentProcessor p = getProcessorInstance(pmtMethods[0].Payment_Processor__r.Type__c);
        
        return p;
    }

    public PaymentProcessor getPaymentProcessor(Payment_Processor_Customer__c processorCustomer) {
        return getPaymentProcessor(processorCustomer, false);
    }

    public PaymentProcessor getPaymentProcessor(Payment_Processor_Customer__c processorCustomer, Boolean isSkipQuery) {
        if (processorCustomer == null) {
            return null;
        }

        String processorType = processorCustomer.Processor__r.Type__c;
        if (!isSkipQuery) {
            List<String> fields = new List<String>{
                    'Id',
                    'Processor__r.Type__c'
            };
            Id processorCustomerId = processorCustomer.Id;
            String condition = 'Id = :processorCustomerId AND Processor__r.Active__c = TRUE';
            SOQLBuilder q = new SOQLBuilder(Payment_Processor_Customer__c.SObjectType);
            q.assertIsAccessible()
                    .selectFields(fields)
                    .setCondition(condition);

            List<Payment_Processor_Customer__c> cust = (List<Payment_Processor_Customer__c>) Database.query(q.toSOQL());

            if (cust == null || cust.isEmpty()) {
                return null;
            }
            processorType = cust[0].Processor__r.Type__c;
        }

        PaymentProcessor p = getProcessorInstance(processorType);
        
        return p;
    }

    /*
     * Get concrete `PaymentProcessor` implementation from cache. 
     * Cache misses will create a new instance based on metadata.
     */ 
    private PaymentProcessor getProcessorInstance(String bindingName) {
        if (!instanceCache.containsKey(bindingName)) {
            PaymentProcessor instance = (PaymentProcessor) MdtBindingHandler.getInstance().resolve(
                PaymentProcessorUtils.PMT_PROC_BINDING_TYPE, bindingName);
            
            instanceCache.put(bindingName, instance);
        }
        return instanceCache.get(bindingName);
    }

}