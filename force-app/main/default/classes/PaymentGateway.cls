/**
 * Payments entry point.
 * 
 * 
 * It also handles common logic such as vlaidations. The logic is here
 * rather than in triggers, because there are callouts to third 
 * party payment processors. If a record was successfully created
 * in the external system but the corresponding object failed to 
 * be saved in salesforce because of a trigger validation the data 
 * would be out of sync between the two systems.
 * 
 */
public with sharing class PaymentGateway {

    public static final Set<String> EXCLUDE_FIELDS_FOR_MESSAGES = new Set<String>{
            Label.ERR_LEDGER_ACTIVE_ONLY
    };

    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    // the Id field label is always `Id`. use this to avoid describe call.
    private static final String ID_FIELD_NAME = 'Id';

    // zero decimal currencies 
    private static final Set<String> ZERO_DECIMAL_CURRENCIES = new Set<String>{
        'JPY', 'BIF', 'CLP', 'DJF', 'GNF', 'KMF', 'KRW', 'MGA', 'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };

    // Gets correct implementation of `PaymentProcessor`
    @TestVisible
    private PaymentProcessorFactory factory;

    public class PaymentGatewayException extends Exception {}

    public PaymentGateway() {
        this.factory = new PaymentProcessorFactory();
    }

    public Payment_Processor_Customer__c createCustomer(Payment_Processor_Customer__c processorCustomer) {
        // validations
        if (processorCustomer == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Processor_Customer__c.getLabel()));
        }
        if (processorCustomer.Id != null) {
            String msg = getExistsMessage(
                    SObjectType.Payment_Processor_Customer__c.getLabel());
            throw new PaymentGatewayException(msg + ' ' + processorCustomer.Id);
        }
        if (processorCustomer.Account__c == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Processor_Customer__c.Account__c.getDescribe().getLabel()));
        }
        if (processorCustomer.Processor__c == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Processor_Customer__c.Processor__c.getDescribe().getLabel()));
        }

        List<Payment_Processor_Customer__c> existingPPCs = DomainUtils.getPaymentProcessorCustomer(
            processorCustomer.Processor__c, 
            processorCustomer.Account__c
        );
        if (existingPPCs != null && !existingPPCs.isEmpty()) {
            String msg = getExistsMessage(
                    SObjectType.Payment_Processor_Customer__c.getLabel());
            throw new PaymentGatewayException(msg + ' ' + existingPPCs.get(0).Id);
        }
        // validations end

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(
            new Payment_Processor__c(Id = processorCustomer.Processor__c)
        ));
        return p.createCustomer(processorCustomer);
    }

    public void deleteCustomer(Payment_Processor_Customer__c processorCustomer) {
        if (processorCustomer == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Processor_Customer__c.getLabel()));
        }
        if (processorCustomer.Id == null) {
            throw new PaymentGatewayException(getRequiredMessage(ID_FIELD_NAME));
        }

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(processorCustomer));
        p.deleteCustomer(processorCustomer);
    }

    public Payment_Processor_Customer__c getCustomer(Payment_Processor_Customer__c processorCustomer) {
        if (processorCustomer == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Processor_Customer__c.getLabel()));
        }
        if (processorCustomer.Id == null) {
            throw new PaymentGatewayException(getRequiredMessage(ID_FIELD_NAME));
        }

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(processorCustomer));
        return p.getCustomer(processorCustomer);
    }

    public Payment_Method__c createPaymentMethod(Payment_Method__c paymentMethod, String token) {
        // validations
        if (String.isBlank(token)) {
            throw new PaymentGatewayException(getRequiredMessage('token'));
        }
        if (paymentMethod == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Method__c.getLabel()));
        }
        if (paymentMethod.Id != null) {
            String msg = getExistsMessage(
                    SObjectType.Payment_Method__c.getLabel());
            throw new PaymentGatewayException(msg + ' ' + paymentMethod.Id);
        }
        if (paymentMethod.Payment_Processor__c == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Method__c.Payment_Processor__c.getDescribe().getLabel()));
        }
        if (paymentMethod.Customer__c == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Method__c.Customer__c.getDescribe().getLabel()));
        }
        if (paymentMethod.Payment_Method_Type__c == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Method__c.Payment_Method_Type__c.getDescribe().getLabel()));
        }
        // check if payment method already exists in SF
        if (paymentMethodExistsInSF(paymentMethod)) {
            throw new PaymentGatewayException(Label.ERR_DUPLICATED_PAYMENT_METHOD);
        }
        // validations end

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(new Payment_Processor__c(
            Id = paymentMethod.Payment_Processor__c
        )));
        return p.createPaymentMethod(paymentMethod, token);
    }

    public void deletePaymentMethod (Payment_Method__c paymentMethod) {
        if (paymentMethod == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Method__c.getLabel()));
        }
        if (Payment_Method__c.Id == null) {
            throw new PaymentGatewayException(getRequiredMessage(ID_FIELD_NAME));
        }

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(paymentMethod));
        p.deletePaymentMethod(paymentMethod);
    }

    public Payment_Method__c getPaymentMethod(Payment_Method__c paymentMethod) {
        if (paymentMethod == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Method__c.getLabel()));
        }
        if (Payment_Method__c.Id == null) {
            throw new PaymentGatewayException(getRequiredMessage(ID_FIELD_NAME));
        }

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(paymentMethod));
        return p.getPaymentMethod(paymentMethod);
    }

    public List<Payment_Method__c> getPaymentMethods(Payment_Processor_Customer__c processorCustomer) {
        return getPaymentMethods(processorCustomer, false);
    }

    public List<Payment_Method__c> getPaymentMethods(Payment_Processor_Customer__c processorCustomer, Boolean isSkipQuery) {
        if (processorCustomer == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Processor_Customer__c.getLabel()));
        }
        if (!processorCustomer.isSet(PACKAGE_QUALIFIER + 'External_Id__c') 
                || String.isBlank(processorCustomer.External_Id__c)) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Processor_Customer__c.External_Id__c.getDescribe().getLabel()));
        }
        if (!processorCustomer.isSet(PACKAGE_QUALIFIER + 'Processor__c')
                || String.isBlank(processorCustomer.Processor__c)) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Processor_Customer__c.Processor__c.getDescribe().getLabel()));       
        }

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(processorCustomer, isSkipQuery));
        return p.getPaymentMethods(processorCustomer);
    }

    public Payment_Method__c updatePaymentMethod(Payment_Method__c paymentMethod) {
        // validations
        if (paymentMethod == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Method__c.getLabel()));
        }
        if (paymentMethod.Id == null) {
            throw new PaymentGatewayException(getRequiredMessage(ID_FIELD_NAME));
        }
        // external id was explicitly removed
        if ((paymentMethod.isSet(PACKAGE_QUALIFIER + 'External_Id__c') 
                && String.isBlank(paymentMethod.External_Id__c))) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Method__c.External_Id__c.getDescribe().getLabel()));
        }
        // get sObject with all fields needed for validations
        Payment_Method__c pm = DomainUtils.getPaymentMethod(paymentMethod.Id);
        if (pm.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE 
                && pm.Verification_Status__c != 'verified') {
            throw new PaymentGatewayException(Label.ERR_PAYMENT_METHOD_SET_DEFAULT);
        }
        // end validations

        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(paymentMethod));
        return p.updatePaymentMethod(paymentMethod);
    }

    /* ********************
     * Transaction Status
     * ********************/

     /**
      * This method will be resposible to apply the required validation on the data being passed
      * and also to call the appropriate method from the processor class
      * transactionId the payment id that needs to be voided
      * cr the cash recieipt that is going to be voided
      */
    public void voidTransaction(Payment_Activity__c paymentActivity){
        // validations
        if (paymentActivity == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Activity__c.getLabel()));
        }
        if (String.isBlank(paymentActivity.Merchant_Reference__c)) {
            throw new PaymentGatewayException(
                getRequiredMessage(Payment_Activity__c.Merchant_Reference__c.getDescribe().getLabel()));
        }
        if (paymentActivity.Cash_Receipt__c == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Cash_Receipt__c.getLabel()));
        }
        if (paymentActivity.Cash_Receipt__r.Payment_Processor__c == null) {
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Processor__c.getLabel()));
        }

        if(paymentActivity.Payment_Method__c == null){
            throw new PaymentGatewayException(
                getRequiredMessage(SObjectType.Payment_Method__c.getLabel()));
        }

        // get the payment processor 
        PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(new Payment_Processor__c(
            Id = paymentActivity.Cash_Receipt__r.Payment_Processor__c
        )));

        //if belongs to CC call ccVoid, if belongs to ACH call achVoid
        if(paymentActivity.Payment_Method__r.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE){
            p.ccVoid(paymentActivity);
        }else if(paymentActivity.Payment_Method__r.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE){
            p.achVoid(paymentActivity);
        }else{
            throw new PaymentGatewayException(Label.ERR_CARDKNOX_INVALID_PAYMENT_METHOD_TYPE);
        }
    }

    /**
     * Retrieves the latest status of the provided `paymentActivities` from
     * external payment processing systems. 
     */
    public List<Payment_Activity__c> getPaymentActivityStatus(List<Payment_Activity__c> paymentActivities) {
        // validations
        if (paymentActivities == null || paymentActivities.isEmpty()) {
            return paymentActivities;
        }

        // sort by processor type. there can be a mix. for example, Cardknox and Stripe
        Map<String,List<Payment_Activity__c>> typeToActivities = new Map<String,List<Payment_Activity__c>>();
        for (Payment_Activity__c activity : paymentActivities) {
            String t = activity.Payment_Method__r.Payment_Processor__r.Type__c;
            if (!typeToActivities.containsKey(t)) {
                typeToActivities.put(t, new List<Payment_Activity__c>());
            }
            // clone so input is not modified. 
            // the caller may need to compare the orignal and updated values.
            Payment_Activity__c clone = activity.clone(true, true, true, true);
            typeToActivities.get(t).add(clone);
        }

        // get updated activites for each processor type
        List<Payment_Activity__c> updatedActivities = new List<Payment_Activity__c>();
        for (String t : typeToActivities.keySet()) {
            PaymentProcessor p = throwIfNull(factory.getPaymentProcessor(typeToActivities.get(t).get(0)));
            updatedActivities.addAll(p.getPaymentActivityStatus(typeToActivities.get(t)));
        }

        return updatedActivities;
    }

    /**
     * Determines if the org is connected to at least one external
     * payment processing system.
     * 
     * True if a `Payment_Processor__c` record (visible to the user) 
     * exists which meets the following conditions, else false.
     * 
     * 1. `Active__c` is true
     * 2. `Connected_Account_Token__c` is not null
     */
    public static Boolean connected() {
        List<String> fields = new List<String>{'Id'};
        String condition = 'Active__c = TRUE';

        SOQLBuilder q = new SOQLBuilder(Payment_Processor__c.SObjectType);
        q.assertIsAccessible()
         .setEnforceFLS(true)
         .selectFields(fields)
         .setCondition(condition);

        List<Payment_Processor__c> ps = (List<Payment_Processor__c>) Database.query(q.toSOQL());
        
        return !(ps == null || ps.isEmpty());
    }

    /**
     * Creates a payment using the provided `paymentMethod` and `cashReceipt`.
     * 
     * Inserts the following records
     *      - `Cash_Receipt__c` record that was passed in as `cashReceipt`.
     *      - `Billing_Cash_Receipt__c` record to link the `Cash_Receipt__c` to a `Billing__c`.
     *      - `Payment_Activity__c` record to link the payment to the `Cash_Receipt__c`.
     * 
     * @param paymentMethod - which payment method to charge
     * @param cashReceipt - payment details, for example payment amount. 
     *              The cash receipt should not have an Id, ie. not yet inserted.
     *              It will be inserted by this method after payment.
     */
    public List<PaymentSaleItem> sale(List<PaymentSaleItem> saleItems) {
        for (PaymentSaleItem saleItem : saleItems) {
            //update cash reciept currencies if they belongs to a zero decimal currrency
            preProcessSale(saleItem);
            String errorMessage = validateSale(saleItem);
            if (String.isNotBlank(errorMessage)) {
                saleItem.errors.add(errorMessage);
            }
        }

        Map<PaymentProcessor, Map<String, List<PaymentSaleItem>>> saleItemsByInstances = factory.getPaymentProcessor(saleItems);
        for (PaymentProcessor paymentProcessorInstance : saleItemsByInstances.keySet()) {
            if (paymentProcessorInstance == null) {
                paymentsValidProcessorNotFound(saleItemsByInstances.get(paymentProcessorInstance)?.values());
                continue;
            }

            Map<String, List<PaymentSaleItem>> itemsByMethodTypes = saleItemsByInstances.get(paymentProcessorInstance);
            for (String methodType : itemsByMethodTypes.keySet()) {
                if (String.isNotBlank(methodType) && methodType.equalsIgnoreCase(PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE)) {
                    paymentProcessorInstance.ccSale(itemsByMethodTypes.get(methodType));
                } else if (String.isNotBlank(methodType) && methodType.equalsIgnoreCase(PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE)) {
                    paymentProcessorInstance.achSale(itemsByMethodTypes.get(methodType));
                } else if (itemsByMethodTypes.get(methodType) != null) {
                    for (PaymentSaleItem saleItem : itemsByMethodTypes.get(methodType)) {
                        saleItem.errors.add(Label.ERR_PAYMENTS_UNSUPPORTED_PAYMENT_MEHTHOD_TYPE);
                    }
                }
            }
        }
        return saleItems;
    }

    public static Id getDefaultPaymentProcessorId() {
        Id processorId = null;
        try {
            processorId = (Id) AccountingSettingsHandler.getAccountingSettings().Stripe_Connected_Account_Id__c;
        } catch (StringException e) {
            // string is not an ID type
        }
        return processorId;
    }
    
    @TestVisible
    private static void preProcessSale(PaymentSaleItem item) {
        // get the payment currency
        String currencyIsoCode = MultiCurrencyHandler.isMultiCurrencyEnabled 
            ? String.valueOf(item.cashReceipt.get('CurrencyIsoCode')) 
            : String.valueOf(MultiCurrencyHandler.CORPORATE_CURRENCY);

        // if the currency is a zero decimal currency, convert the amount to a currency’s smallest unit
        if (ZERO_DECIMAL_CURRENCIES.contains(currencyIsoCode)) {
            item.cashReceipt.Amount__c = Decimal.valueOf(Integer.valueOf(item.cashReceipt.Amount__c));
        }

        // Values will be sent to the payment processor before being saved to database. 
        // This means rounding which is normally handled in triggers must be handled 
        // upfront to ensure we send the rounded values which will be recorded in SF
        // to the payment processor.
        SObjectActions.normalizeNumericAndCurrencyFields(new List<Cash_Receipt__c>{item.cashReceipt}, CashReceiptActions.currencyAndNumberFields);
    }

    private static void paymentsValidProcessorNotFound(List<List<PaymentSaleItem>> saleItemsBatches) {
        if (saleItemsBatches != null) {
            for (List<PaymentSaleItem> saleItems : saleItemsBatches) {
                for (PaymentSaleItem saleItem : saleItems) {
                    saleItem.errors.add(Label.ERR_PAYMENTS_VALID_PROCESSOR_NOT_FOUND);
                }
            }
        }
    }

    private static String getRequiredMessage(String s) {
        return String.format(Label.ERR_X_IS_REQUIRED, new List<String>{ s });
    }

    private static String getExistsMessage(String s) {
        return String.format(Label.ERR_X_ALREADY_EXISTS, new List<String>{ s });
    }

    private static Boolean paymentMethodExistsInSF(Payment_Method__c paymentMethod) {
        String newKey = PaymentMethodActions.buildCompositeKeyForPaymentMethod(paymentMethod);
        if (newKey == null) {
            return false;
        }
        String existingKey;
        for (Payment_Method__c pm : DomainUtils.getPaymentMethodsByAccountAndProcessor(paymentMethod.Customer__c, paymentMethod.Payment_Processor__c)) {
            existingKey = PaymentMethodActions.buildCompositeKeyForPaymentMethod(pm);
            if (newKey.equalsIgnoreCase(existingKey)) {
                return true;
            }
        }
        return false;
    }

    private static PaymentProcessor throwIfNull(PaymentProcessor p) {
        if (p == null) {
            throw new PaymentGatewayException(Label.ERR_PAYMENTS_VALID_PROCESSOR_NOT_FOUND);
        }
        return p;
    }

    private static void validateSale(Payment_Method__c paymentMethod, Cash_Receipt__c cashReceipt) {
        String errorMessage = validateSale(new PaymentSaleItem(paymentMethod, cashReceipt, null));
        if (String.isNotBlank(errorMessage)) {
            throw new PaymentGatewayException(errorMessage);
        }
    }

    private static String validateSale(PaymentSaleItem saleItem) {
        String errorMessage = null;
        if (saleItem.paymentMethod == null) {
            errorMessage = getRequiredMessage(SObjectType.Payment_Method__c.getLabel());
        }
        if (saleItem.cashReceipt == null) {
            errorMessage = getRequiredMessage(SObjectType.Cash_Receipt__c.getLabel());
        }
        if (saleItem.cashReceipt.Amount__c == null || saleItem.cashReceipt.Amount__c <= 0) {
            errorMessage = Label.ERR_PAYMENTS_SALE_NEGATIVE_AMOUNT;
        }
        if (saleItem.cashReceipt.Bank_Account__c == null) {
            errorMessage = getRequiredMessage(Cash_Receipt__c.Bank_Account__c.getDescribe().getLabel());
        }
        if (saleItem.cashReceipt.Accounting_Period__c == null && saleItem.cashReceipt.Receipt_Date__c == null) {
            errorMessage = getRequiredMessage(Cash_Receipt__c.Accounting_Period__c.getDescribe().getLabel());
        }

        if (String.isBlank(saleItem.paymentMethod.Customer__c) && String.isBlank(saleItem.cashReceipt.Account__c)) {
            errorMessage = getRequiredMessage(Payment_Method__c.Customer__c.getDescribe().getLabel());
        } else if (String.isNotBlank(saleItem.paymentMethod.Customer__c) && String.isNotBlank(saleItem.cashReceipt.Account__c)
                && saleItem.paymentMethod.Customer__c != saleItem.cashReceipt.Account__c) {
            errorMessage = Label.ERR_PAYMENTS_CREATE_CHARGE_ACCOUNT_MISMATCH;
        } else if (String.isNotBlank(saleItem.paymentMethod.Customer__c) && String.isBlank(saleItem.cashReceipt.Account__c)) {
            saleItem.cashReceipt.Account__c = saleItem.paymentMethod.Customer__c;
        } else if (String.isBlank(saleItem.paymentMethod.Customer__c) && String.isNotBlank(saleItem.cashReceipt.Account__c)) {
            saleItem.paymentMethod.Customer__c = saleItem.cashReceipt.Account__c;
        }

        return errorMessage;
    }

    public static String composeErrorMsg(Database.SaveResult result) {
        List<String> msgParts = new List<String>();
        if (result.errors != null && !result.errors.isEmpty()) {
            String message = result.errors[0].message;
            if (PaymentGateway.EXCLUDE_FIELDS_FOR_MESSAGES.contains(result.errors[0].message) && message.containsIgnoreCase('.')) {
                message = message.removeEnd('.');
            }
            msgParts.add(message);
            if (result.errors[0].fields != null
                    && !result.errors[0].fields.isEmpty()
                    && !PaymentGateway.EXCLUDE_FIELDS_FOR_MESSAGES.contains(result.errors[0].message)) {
                msgParts.add(result.errors[0].fields[0]);
            }
        }

        String msg = String.join(msgParts, ': ');
        return FinancialSuiteUtils.punctuate(msg);
    }
}