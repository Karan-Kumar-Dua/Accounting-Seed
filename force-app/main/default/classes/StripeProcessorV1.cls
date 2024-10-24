public with sharing class StripeProcessorV1 implements PaymentProcessor {
    
    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public class StripeProcessorV1Exception extends Exception {}

    // ===== Customer =====

    /**
     * Creates a Stripe customer for the provided Account.
     */
    public Payment_Processor_Customer__c createCustomer(Payment_Processor_Customer__c processorCustomer) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(processorCustomer.Processor__c);

        // get account
        Account a = PaymentProcessorUtils.getAccount(processorCustomer.Account__c);

        // StripeService takes a source token which can be used
        // to create a customer and default payment method in one request.
        // Here we just leave it uninitialized since no payment method is created. 
        StripeService.StripeSourceToken sToken = new StripeService.StripeSourceToken();

        // metadata to attach to customer in stripe
        Map<String, String> metadata = new Map<String, String>{
            'Name' => a.Name,
            'ExternalId' => a.Id
        };

        // create the stripe customer
        StripeService.StripeCustomer stripeCustomer = StripeService.createStripeCustomer(
            sToken, metadata, null, p);
        
        // update junction object with stripe customer id
        processorCustomer.External_Id__c = stripeCustomer.id;

        SFDCSecurityUtils.insertCheckCRUDAndFLS(processorCustomer, new List<String>{
            'External_Id__c',
            'Account__c',
            'Processor__c'
        });

        return processorCustomer;
    }

    /**
     * Not implemented.
     */
    public void deleteCustomer(Payment_Processor_Customer__c processorCustomer) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Not implemented.
     */
    public Payment_Processor_Customer__c getCustomer(Payment_Processor_Customer__c processorCustomer) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Not implemented.
     */
    public List<Payment_Processor_Customer__c> getCustomers(Payment_Processor__c paymentProcessor) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Updates a Stripe customer with the associated Account details.
     */
    public Payment_Processor_Customer__c updateCustomer(Payment_Processor_Customer__c processorCustomer) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    // ===== Payment Methods =====

    /**
     * Creates a stripe payment method. If a stripe customer does not
     * already exists for the Payment_Method__c.Customer__c create one
     * and attach the payment method as the default.
     */
    public Payment_Method__c createPaymentMethod(Payment_Method__c paymentMethod, String token) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(paymentMethod.Payment_Processor__c);

        // Check stripe customer exists
        //      yes => create payment method only
        //      no  => create customer + payment method
        List<Payment_Processor_Customer__c> ppcs = DomainUtils.getPaymentProcessorCustomer(
            paymentMethod.Payment_Processor__c, paymentMethod.Customer__c);
        Payment_Processor_Customer__c ppc = ppcs == null || ppcs.isEmpty() ? null : ppcs.get(0);

        Account acct = PaymentProcessorUtils.getAccount(paymentMethod.Customer__c);

        if (acct == null) {
            // customer could not be found
            throw new StripeProcessorV1Exception(Label.ERR_PAYMENT_METHOD_ACCT_MISSING);
        }

        // the stripe source token (tokenized payment method)
        StripeService.StripeSourceToken sToken = new StripeService.StripeSourceToken();
        sToken.id = token;
        
        StripeService.StripeSource src;
        if (ppc == null) {
            // create customer + payment method
            src = createCustomerAndPaymentMethod(p, acct, sToken);
            // if no default payment method set as default
            Payment_Method__c defaultMethod = DomainUtils.getCustomerDefaultPaymentMethod(acct.Id);
            paymentMethod.Default__c = defaultMethod == null;
        } else {
            // customer exists, just create payment method
            src = createPaymentMethod(p, ppc, sToken);
        }

        if (src == null) {
            // error creating stripe source
            throw new StripeProcessorV1Exception(
                String.format(
                    Label.ERR_PMT_PROCESSOR_CREATE, 
                    new List<String>{ SObjectType.Payment_Method__c.getLabel() }
                )
            );
        }

        // populate the stripe source data on the payment method
        populateSourceData(paymentMethod, src);
        paymentMethod.Customer__c = acct.Id;
        paymentMethod.Payment_Processor__c = p.Id;

        // save the payment method in SF
        insertPaymentMethod(paymentMethod);

        // convert stripe source to payment method
        return paymentMethod;
    }

    /**
     * 
     */
    public void deletePaymentMethod(Payment_Method__c paymentMethod) {
        // get payment method
        Payment_Method__c pm = DomainUtils.getPaymentMethod(paymentMethod.Id); 
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(pm.Payment_Processor__c);
        // get customer
        List<Payment_Processor_Customer__c> ppcs = DomainUtils.getPaymentProcessorCustomer(
            pm.Payment_Processor__c, 
            pm.Customer__c
        );

        Payment_Processor_Customer__c ppc = ppcs == null || ppcs.isEmpty() ? null : ppcs.get(0);
        
        if (ppc != null && !String.IsBlank(ppc.External_Id__c) && !String.isBlank(pm.External_Id__c)) {
            // delete payment method in stripe
            StripeService.deleteStripeSource(ppc.External_Id__c, pm.External_Id__c, p);
        }

        // delete payment method in SF
        SFDCSecurityUtils.deleteCheckCRUDAndFLS(pm);
    }

    /**
     * 
     */
    public Payment_Method__c getPaymentMethod(Payment_Method__c paymentMethod) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * 
     */
    public List<Payment_Method__c> getPaymentMethods(Payment_Processor_Customer__c processorCustomer) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(processorCustomer.Processor__c);

        List<StripeService.StripeSource> srcs = new List<StripeService.StripeSource>();

        // get stripe sources: credit card
        srcs.addAll(StripeService.getListAllCustomerCards(processorCustomer.External_Id__c, p));
        // get stripe sources: ach
        srcs.addAll(StripeService.getListAllCustomerBankAccounts(processorCustomer.External_Id__c, p));

        // convert stripe sources to SF payment methods
        List<Payment_Method__c> pmtMethods = new List<Payment_Method__c>();
        for (StripeService.StripeSource src : srcs) {
            Payment_Method__c pm = convert(src);
            if (pm != null) {
                pm.Customer__c = processorCustomer.Account__c;
                pm.Payment_Processor__c = processorCustomer.Processor__c;
                pmtMethods.add(pm);
            }
        }

        return pmtMethods;
    }

    /**
     * 
     */
    public Payment_Method__c updatePaymentMethod(Payment_Method__c paymentMethod) {
        // get sObject with all fields needed
        Payment_Method__c pm = DomainUtils.getPaymentMethod(paymentMethod.Id);
        // get processor record which will be used
        Payment_Processor__c processor = PaymentProcessorUtils.getPaymentProcessor(pm.Payment_Processor__c);
        // get processor customer
        List<Payment_Processor_Customer__c> ppcs = DomainUtils.getPaymentProcessorCustomer(
            pm.Payment_Processor__c, 
            pm.Customer__c
        );
        Payment_Processor_Customer__c ppc = ppcs == null || ppcs.isEmpty() ? null : ppcs.get(0);
        if (ppc == null) {
            throw new StripeProcessorV1Exception(Label.ERR_PAYMENTS_NO_CUSTOMER_FOR_PMT_METHOD);
        }

        // default was updated
        if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Default__c')) {
            // update the customer's default card in stripe
            Map<String, String> payload = new Map<String, String>{
                'default_source' => pm.External_Id__c
            };
            StripeService.updateStripeCustomer(ppc.External_Id__c, payload, processor);
        }

        Map<String, String> payload = new Map<String, String>();
        Map<String, String> metadata = new Map<String, String>();

        if (pm.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE) {
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Card_Holder_Name__c')) {
                payload.put('account_holder_name', paymentMethod.Card_Holder_Name__c);
            }

            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Bank_Account_Type__c')) {
                payload.put('account_holder_type', new Map<String, String>{
                    'Individual' => 'individual', 
                    'Business' => 'company'
                }.get(paymentMethod.Bank_Account_Type__c));
            }
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Status__c')) {
                metadata.put('status', paymentMethod.Status__c);
            }
        } else if (pm.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE) {
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Status__c')) {
                metadata.put('status', paymentMethod.Status__c);
            }
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Card_Holder_Name__c')) {
                payload.put('name', paymentMethod.Card_Holder_Name__c);
            }
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Expiration_Month__c')) {
                payload.put('exp_month', paymentMethod.Expiration_Month__c);
            }
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Expiration_Year__c')) {
                payload.put('exp_year', paymentMethod.Expiration_Year__c);
            }
        }

        // update payment mehtod in stripe
        if (!payload.isEmpty() || !metadata.isEmpty()) {
            StripeService.updateStripeSource(ppc.External_Id__c, pm.External_Id__c, payload, metadata, processor);
        }
        
        // get the populated fields that require fls inspection
        Map<String,Object> populatedFields = paymentMethod.getPopulatedFieldsAsMap();
        SchemaDescribe describe = SchemaDescribe.getDescribe(Payment_Method__c.SObjectType);

        List<String> fnames = new List<String>();
        for (String fname : populatedFields.keySet()) {
            if (describe.getField(fname).getDescribe().isUpdateable()) {
                fnames.add(fname);
            }
        }
        // save the input sObject
        SFDCSecurityUtils.updateCheckCRUDAndFLS(paymentMethod, fnames);

        return paymentMethod;
    }

    // ===== Credit Card =====

    /**
     * Not Implemented.
     */
    public Payment_Activity__c ccAuthorization(Payment_Method__c paymentMethod) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c ccCapture(Payment_Method__c paymentMethod) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c ccCredit(Payment_Method__c paymentMethod) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c ccRefund(Payment_Method__c paymentMethod) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Charges the provided Payment Method for the amount specified by the Cash Receipt.
     */
    public List<PaymentSaleItem> ccSale(List<PaymentSaleItem> saleItems) {
        return sale(saleItems);
    }

    /**
     * Not Implemented.
     */
    public void ccVoid(Payment_Activity__c paymentActivity) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    // ===== ACH =====

    /**
     * Not Implemented.
     */
    public Payment_Activity__c achCredit(Payment_Method__c paymentMethod) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c achRefund(Payment_Method__c paymentMethod) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    /**
     * Charges the provided Payment Method for the amount specified by the ach Receipt.
     */
    public List<PaymentSaleItem> achSale(List<PaymentSaleItem> saleItems) {
        return sale(saleItems);
    }

    /**
     * Not Implemented.
     */
    public void achVoid(Payment_Activity__c paymentActivity) {
        throw new StripeProcessorV1Exception('Not Implemented');
    }

    // ===== Payment Activity Status =====

    /**
     * 
     */
    public List<Payment_Activity__c> getPaymentActivityStatus(List<Payment_Activity__c> paymentActivities) {
        // sort by processor because there can be a mix. For example Stripe Account 1 and Stripe Account 2
        Map<Id,List<Payment_Activity__c>> processorToActivities = new Map<Id,List<Payment_Activity__c>>();
        for (Payment_Activity__c activity : paymentActivities) {
            Id processorId = activity.Payment_Method__r.Payment_Processor__c;
            if (!processorToActivities.containsKey(processorId)) {
                processorToActivities.put(processorId, new List<Payment_Activity__c>());
            }
            processorToActivities.get(processorId).add(activity);
        }

        Map<Id,Payment_Processor__c> processors = new Map<Id,Payment_Processor__c>(
            PaymentProcessorUtils.getPaymentProcessors(processorToActivities.keySet()));

        // for each processor...
        for (Id processorId : processorToActivities.keySet()) {
            Payment_Processor__c processor = processors.get(processorId);
            // for each activity...
            for (Payment_Activity__c activity : processorToActivities.get(processorId)) {
                // fetch the stripe charge related to the payment activity
                StripeService.StripeCharge charge;
                try {
                    // fetch the stripe charge
                    charge = StripeService.getStripeCharge(activity.Cash_Receipt__r.Payment_Reference__c, processor);
                    // map stripe charge fields to payment activity fields
                    activity.Error_Type__c = charge.failure_code;
                    activity.Error_Message__c = charge.failure_message;
                    if (charge.status == 'succeeded') {
                        activity.Status__c = 'Success';
                    } else if (charge.status == 'failed') {
                        activity.Status__c = 'Declined';
                    } else if (charge.status == 'pending') {
                        activity.Status__c = 'Pending';
                    }
                } catch (StripeService.StripeServiceException e) {
                    activity.Status__c = 'Error';
                    activity.Error_Type__c = 'Stripe Error';
                    activity.Error_Message__c = e.getMessage();
                }
            }
        }

        return paymentActivities;
    }

    // // =============== private ==================

    private static StripeService.StripeSource createCustomerAndPaymentMethod(
            Payment_Processor__c pmtProc, Account acct, StripeService.StripeSourceToken sToken) {

        Map<String, String> metadata = new Map<String, String>{
            'Name' => acct.Name,
            'ExternalId' => acct.Id
        };

        StripeService.StripeCustomer stripeCustomer = StripeService.createStripeCustomer(
            sToken, metadata, null, pmtProc);

        // create payment processor customer
        Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
            External_Id__c = stripeCustomer.id,
            Account__c = acct.Id,
            Processor__c = pmtProc.Id
        );
        ppc.External_Id__c = stripeCustomer.id;
        SFDCSecurityUtils.insertCheckCRUDAndFLS(ppc, new List<String>{
            'Processor__c',
            'External_Id__c',
            'Account__c'
        });
        
        // get the new stripe source
        StripeService.StripeSource src;
        if (stripeCustomer.sources != null 
                && stripeCustomer.sources.stripeData != null 
                && !stripeCustomer.sources.stripeData.isEmpty()) {
            // source was created
            src = stripeCustomer.sources.stripeData.get(0);
        }
        return src;
    }

    private static StripeService.StripeSource createPaymentMethod(
            Payment_Processor__c pmtProc, Payment_Processor_Customer__c ppc, StripeService.StripeSourceToken sToken) {

        // check for duplicates in stripe
        StripeService.StripeSource duplicate = StripeService.getDuplicatedStripeSourceIfExists(
            ppc.External_Id__c, sToken, pmtProc);

        StripeService.StripeSource src;
        if (duplicate == null) {
            // create the stripe source
            src = StripeService.createStripeSource(
                ppc.External_Id__c, sToken, null, pmtProc);
        } else {
            // stripe source already exists in stripe but not SF
            src = duplicate;
        }
        return src;
    }

    private static Payment_Method__c populateSourceData(Payment_Method__c paymentMethod, StripeService.StripeSource src) {
        paymentMethod.Status__c = StripeService.PAYMENT_METHOD_STATUS_ACTIVE;
        paymentMethod.External_Id__c = src.id;
        paymentMethod.Last_Four_Digits__c = src.last4;

        if (src.stripeObject == 'card') {
            // add CC details
            paymentMethod.Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
            paymentMethod.Type__c = src.brand;
            //to save consistency of Expiration Month in whole product
            //it must be 2-characters-wide
            paymentMethod.Expiration_Month__c = ((String.valueOf(src.exp_month).length() < 2)
                    ? ('0' + String.valueOf(src.exp_month))
                    : String.valueOf(src.exp_month));
            paymentMethod.Expiration_Year__c = String.valueOf(src.exp_year);
            paymentMethod.Card_Holder_Name__c = src.name;
        } else if (src.stripeObject == 'bank_account') {
            // add ACH details
            paymentMethod.Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE;
            paymentMethod.Bank_Name__c = src.bank_name;
            paymentMethod.Bank_Account_Type__c = new Map<String, String>{
                'individual' => 'Individual',
                'company' => 'Business'
            }.get(src.account_holder_type);
            paymentMethod.Verification_Status__c = src.status;
            paymentMethod.Card_Holder_Name__c = src.account_holder_name;
        } else {
            // stripe source is unsuported in accounting seed
            throw new StripeProcessorV1Exception('The payment type ' + src.stripeObject + ' is not supported.');
        }

        return paymentMethod;
    }

    // ============ private static ===============

    private static String getRequiredMessage(String s) {
        return String.format(Label.ERR_X_IS_REQUIRED, new List<String>{ s });
    }

    private static String getExistsMessage(String s) {
        return String.format(Label.ERR_X_ALREADY_EXISTS, new List<String>{ s });
    }

    private static Payment_Method__c convert(StripeService.StripeSource src) {
        if (src.stripeObject != 'card' && src.stripeObject != 'bank_account') {
            // unsupported type
            return null;
        }

        Payment_Method__c pm = new Payment_Method__c();

        // common
        pm.Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_INACTIVE.equalsIgnoreCase(src.metadata?.status) 
            ? PaymentMethodActions.PAYMENT_METHOD_STATUS_INACTIVE 
            : PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE;
        pm.External_Id__c = src.id;
        pm.Last_Four_Digits__c = src.last4;

        if (src.stripeObject == 'card') { // credit card
            // add CC details
            pm.Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
            pm.Type__c = src.brand;
            //to save consistency of Expiration Month in whole product
            //it must be 2-characters-wide
            pm.Expiration_Month__c = ((String.valueOf(src.exp_month).length() < 2)
                    ? ('0' + String.valueOf(src.exp_month))
                    : String.valueOf(src.exp_month));
            pm.Expiration_Year__c = String.valueOf(src.exp_year);
            pm.Card_Holder_Name__c = src.name;
        } else if (src.stripeObject == 'bank_account') { // ach
            // add ACH details
            pm.Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE;
            pm.Bank_Name__c = src.bank_name;
            pm.Bank_Account_Type__c = new Map<String, String>{
                'individual' => 'Individual',
                'company' => 'Business'
            }.get(src.account_holder_type);
            pm.Verification_Status__c = src.status;
            pm.Card_Holder_Name__c = src.account_holder_name;
        }

        return pm;
    }

    private static List<PaymentSaleItem> sale(List<PaymentSaleItem> saleItems) {
        Set<Id> paymentProcessorIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (PaymentSaleItem saleItem : saleItems) {
            paymentProcessorIds.add(saleItem.paymentMethod.Payment_Processor__c);
            accountIds.add(saleItem.paymentMethod.Customer__c);
        }
        Map<String, List<Payment_Processor_Customer__c>> ppcRecordsByProcessorCustomerKeys =
                DomainUtils.getPaymentProcessorCustomer(paymentProcessorIds, accountIds);

        Map<Id,Payment_Processor__c> paymentProcessors = new Map<Id,Payment_Processor__c>(
                DomainUtils.getPaymentProcessorsById(paymentProcessorIds));

        Map<Id,String> ppWithChargeId = new Map<Id,String>();

        List<ChargeWrap> chargeWraps = new List<StripeProcessorV1.ChargeWrap>();
        Set<String> chargeIds = new Set<String>();
        for (PaymentSaleItem saleItem : saleItems) {
            String currencyCode = currencyCode(saleItem.cashReceipt);

            String processorCustomerKey = PaymentProcessorUtils.composeKey(new List<String>{
                    saleItem.paymentMethod.Payment_Processor__c, saleItem.paymentMethod.Customer__c
            });
            Payment_Processor_Customer__c ppcRecord = ppcRecordsByProcessorCustomerKeys.get(processorCustomerKey) != null && !ppcRecordsByProcessorCustomerKeys.get(processorCustomerKey).isEmpty()
                ? ppcRecordsByProcessorCustomerKeys.get(processorCustomerKey)[0] : null;
    
            if (ppcRecord != null) {
                try {
                    StripeService.StripeCharge charge = StripeService.createCharge(
                            ppcRecord.External_Id__c,
                            saleItem.paymentMethod.External_Id__c,
                            saleItem.cashReceipt.Amount__c,
                            currencyCode,
                            saleItem.cashReceipt.Description__c,
                            getIdempotencyKey(saleItem, ppcRecord),
                            ppcRecord.Processor__r
                    );
                    ppWithChargeId.put(saleItem.paymentMethod.Payment_Processor__c,charge.id);
                    chargeIds.add(charge.id);
                    chargeWraps.add(new ChargeWrap(charge, saleItem));
                } catch (StripeService.StripeServiceException e) {
                    saleItem.errors.add(e.stripeErrorObj.getMessage(), 'STRIPE_ERROR');
                    saleItem.paymentActivity(PaymentActivityHelper.createPaymentActivity(
                        saleItem.paymentMethod.Id,
                        saleItem.cashReceipt.Amount__c,
                        e.stripeErrorObj.error
                    ));
                } catch (CalloutException e) {
                    saleItem.errors.add(e.getMessage(), 'STRIPE_ERROR');
                    saleItem.paymentActivity(PaymentActivityHelper.createPaymentActivity(
                        null,
                        saleItem,
                        e.getMessage()
                    ));
                }
            } else {
                saleItem.errors.add(Label.ERR_PAYMENTS_NO_CUSTOMER_FOR_PMT_METHOD);
            }
        }

        // if stripe recieves a request with same idempotency key + body within 24 hrs it will replay
        // the same response. need to check if we already have a cash receipt for the charge incase
        // of a replayed response.
        List<ChargeWrap> chargeWraps4CashReceipts = new List<StripeProcessorV1.ChargeWrap>();
        Map<String, Cash_Receipt__c> cashReceiptsByRefs = PaymentProcessorUtils.cashReceiptsByRefs(chargeIds);
        for (ChargeWrap wrap : chargeWraps) {
            if (cashReceiptsByRefs.get(wrap.charge.id) == null) {
                chargeWraps4CashReceipts.add(wrap);
            } else {
                wrap.saleItem.errors.add(Label.ERR_PAYMENTS_DUPLICATE_FOUND + ' ' + SObjectType.Cash_Receipt__c.getLabel() + ' ' + cashReceiptsByRefs.get(wrap.charge.id).Name);
            }
        }
        chargeWraps4CashReceipts = createCashReceipt(chargeWraps4CashReceipts,ppWithChargeId,paymentProcessors);
        for (ChargeWrap wrap : chargeWraps4CashReceipts) {
            if (wrap.saleItem.errors.isEmpty()) {
                wrap.saleItem.paymentActivity(PaymentActivityHelper.createPaymentActivity(
                        wrap.saleItem.cashReceipt.Id,
                        wrap.charge,
                        wrap.saleItem.paymentMethod.Id
                ));
            }
        }

        List<Payment_Method__c> paymentMethods4Insert = new List<Payment_Method__c>();
        for (PaymentSaleItem saleItem : saleItems) {
            if (String.isBlank(saleItem.paymentMethod.Id)) {
                paymentMethods4Insert.add(saleItem.paymentMethod);
            }
        }
        if (!paymentMethods4Insert.isEmpty()) {
            insertPaymentMethod(paymentMethods4Insert, false);
        }

        saleItems = createPaymentActivities(saleItems,ppWithChargeId,paymentProcessors);

        return saleItems;
    }

    private static String currencyCode(Cash_Receipt__c cashReceipt) {
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

    private static List<ChargeWrap> createCashReceipt(List<ChargeWrap> chargeWraps,Map<Id,String> ppWithChargeId,Map<Id,Payment_Processor__c> paymentProcessors) {
        List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
        for (ChargeWrap wrap : chargeWraps) {
            wrap.saleItem.cashReceipt.Amount__c = wrap.charge.getAmountInDefaultCurrencyUnits();
            wrap.saleItem.cashReceipt.Payment_Reference__c = wrap.charge.id;
            wrap.saleItem.cashReceipt.Payment_Processor__c = wrap.saleItem.paymentMethod.Payment_Processor__c;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                wrap.saleItem.cashReceipt.put('CurrencyIsoCode', wrap.charge.stripeCurrency.toUpperCase());
            }

            cashReceipts.add(wrap.saleItem.cashReceipt);
        }
        if (!cashReceipts.isEmpty()) {
            List<Database.SaveResult> results = SFDCSecurityUtils.insertCheckCRUDAndFLS(cashReceipts, new List<String>{
                    'Purpose__c',
                    'GL_Account_Variable_1__c',
                    'GL_Account_Variable_2__c',
                    'GL_Account_Variable_3__c',
                    'GL_Account_Variable_4__c',
                    'Project__c',
                    'Project_Task__c'
            }, false);
            for (Integer index = 0; index < results.size(); index++) {
                Database.SaveResult result = results[index];
                if (!result.isSuccess()) {
                    String errorMessage = String.format(Label.ERR_PAYMENTS_STRIPE_CREATE_CHARGE_CR, 
                            new List<String>{
                                paymentProcessors?.get(cashReceipts[index].Payment_Processor__c).Type__c,
                                ppWithChargeId?.get(cashReceipts[index].Payment_Processor__c),
                                composeErrorMsg(result)});
                    chargeWraps[index].saleItem.errors.add(errorMessage);
                }
            }
        }
        return chargeWraps;
    }

    private static List<PaymentSaleItem> createPaymentActivities(List<PaymentSaleItem> saleItems,Map<Id,String> ppWithChargeId,Map<Id,Payment_Processor__c> paymentProcessors) {
        List<Payment_Activity__c> paymentActivities = new List<Payment_Activity__c>();
        List<PaymentSaleItem> saleItemWithActivities = new List<PaymentSaleItem>();
        List<Id> paymentProcessorsIds = new List<Id>();
        Set<Id> cashReceiptIds = new Set<Id>();
        for (PaymentSaleItem saleItem : saleItems) {
            if (saleItem.paymentActivity != null) {
                saleItem.paymentActivity.Payment_Method__c = saleItem.paymentMethod.Id;
                saleItemWithActivities.add(saleItem);
                paymentProcessorsIds.add(saleItem.paymentMethod.Payment_Processor__c);
                paymentActivities.add(saleItem.paymentActivity);
                cashReceiptIds.add(saleItem.cashReceipt.Id);
            }
        }
        Map<Id,Cash_Receipt__c> cashReceipts = new Map<Id,Cash_Receipt__c>(DomainUtils.getCashReceiptById(cashReceiptIds));

        if (!paymentActivities.isEmpty()) {
            List<Database.SaveResult> results = SFDCSecurityUtils.insertProxy(paymentActivities, false);
            for (Integer index = 0; index < results.size(); index++) {
                Database.SaveResult result = results[index];
                if (!result.isSuccess()) {
                    String errorMessage = '';
                    if(saleItemWithActivities[index].billings != null && !(saleItemWithActivities[index].billings).isEmpty()){
                        errorMessage = String.format(Label.ERR_PAYMENTS_STRIPE_CREATE_CHARGE_ACTIVITY_EMPTY_BILLING, 
                            new List<String>{
                                paymentProcessors?.get(paymentProcessorsIds[index]).Type__c,
                                ppWithChargeId?.get(paymentProcessorsIds[index]),
                                composeErrorMsg(result),
                                cashReceipts.get(saleItemWithActivities[index].cashReceipt?.Id)?.Name});
                    }else{
                        errorMessage = String.format(Label.ERR_PAYMENTS_STRIPE_CREATE_CHARGE_ACTIVITY, 
                            new List<String>{
                                paymentProcessors?.get(paymentProcessorsIds[index]).Type__c,
                                ppWithChargeId?.get(paymentProcessorsIds[index]),
                                composeErrorMsg(result)
                            });
                    }

                    saleItemWithActivities[index].errors.add(errorMessage);  
                }
            }
        }

        return saleItems;
    }

    public static String composeErrorMsg(Database.SaveResult result) {
        return PaymentGateway.composeErrorMsg(result);
    }

    private static void insertPaymentMethod(Payment_Method__c pm) {
        insertPaymentMethod(new List<Payment_Method__c>{pm}, true);
    }
    private static void insertPaymentMethod(List<Payment_Method__c> paymentMethods, Boolean allOrNone) {
        SFDCSecurityUtils.insertCheckCRUDAndFLS(paymentMethods, new List<String>{
            'Verification_Status__c',
            'Bank_Account_Type__c',
            'Bank_Name__c',
            'Payment_Method_Type__c',
            'Customer__c',
            'Type__c',
            'Status__c',
            'Expiration_Month__c',
            'Expiration_Year__c',
            'External_Id__c',
            'Card_Holder_Name__c',
            'Default__c'
        }, allOrNone);
    }

    private class ChargeWrap {
        public StripeService.StripeCharge charge;
        public PaymentSaleItem saleItem;

        public ChargeWrap(StripeService.StripeCharge charge, PaymentSaleItem saleItem) {
            this.charge = charge;
            this.saleItem = saleItem;
        }
    }

    // get the idempotency key. used to prevent duplicate requests for 24 hrs
    private static String getIdempotencyKey(PaymentSaleItem saleItem, Payment_Processor_Customer__c customer) {
        Id customerId = customer.Id;
        Id processorId = saleItem.paymentMethod.Payment_Processor__c;
        Decimal amount = saleItem.cashReceipt.Amount__c;
        String paymentMethodId = saleItem.paymentMethod.External_Id__c;
        String description = saleItem.cashReceipt.Description__c;
        String combinedBillingIds = 'none';

        if (saleItem.billings != null && !saleItem.billings.isEmpty()) {
            Set<String> billingIds = new Set<String>();
            for (Billing__c billing : saleItem.billings) {
                if (billing.Id != null) {
                    billingIds.add(billing.Id);
                }
            }
            List<String> sortedBillingIds = new List<String>(billingIds);
            sortedBillingIds.sort();
            combinedBillingIds = String.join(sortedBillingIds, '');
        }

        String k = customerId + '-' + processorId + '-' + paymentMethodId + '-' + amount + '-' + description + '-' + combinedBillingIds;
        return String.valueOf(k.hashCode());
    }
}