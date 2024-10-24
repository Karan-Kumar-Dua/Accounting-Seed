public with sharing class PaymentMethodProvider {

    private PaymentGateway gtwy;
    public Map<String, Payment_Method__c> sourceIdToStripeSourceMap;
    @TestVisible
    private Map<String, Payment_Method__c> sourceIdToExistingPaymentMethodMap;
    @TestVisible
    private List<Payment_Method__c> sources;
    private Account customer;
    private Set<String> existedPMsCompositeKeys;
    private String defaultSourceId;
    private String defaultSourceType;
    private String defaultProcessorId;
    private Map<Id,String> processorIdToName;
    private Map<Id,Payment_Processor_Customer__c> customersByProcessorId;
    private Set<Id> onlyProcessorIds;

    public Map<Id,List<SelectOption>> sourcesByProcessorId;
    public List<SelectOption> sourceIdsSelectOptions {get; private set;}
    public List<SelectOption> processorSelectOptions {get; private set;}
    public String selectedSourceId { get; set; }
    public String selectedProcessorId { get; set; }
    public String selectedSourceType { get; set; }
    public Boolean noActiveSources {get; private set;}

    public PaymentMethodProvider(Account customer, PaymentGateway gtwy) {
        this.customer = customer;
        this.sources = new List<Payment_Method__c>();
        this.sourceIdToStripeSourceMap = new Map<String, Payment_Method__c>();
        this.sourceIdsSelectOptions = new List<SelectOption>();
        this.processorSelectOptions = new List<SelectOption>();
        this.sourceIdToExistingPaymentMethodMap = new Map<String, Payment_Method__c>();
        this.existedPMsCompositeKeys = new Set<String>();
        this.noActiveSources = false;
        this.processorIdToName = new Map<Id,String>();
        this.sourcesByProcessorId = new Map<Id,List<SelectOption>>();
        this.customersByProcessorId = new Map<Id,Payment_Processor_Customer__c>();
        this.gtwy = gtwy;
    }

    public PaymentMethodProvider onlyProcessorIds(Set<Id> onlyProcessorIds) {
        this.onlyProcessorIds = onlyProcessorIds;
        return this;
    }

    public List<Payment_Method__c> getPaymentSources(){
        return sourceIdToStripeSourceMap.values();
    }

    public PaymentMethodProvider receiveStripeSources() {
        List<String> fields = new List<String>{
            'Id', 
            'External_Id__c', 
            'Processor__c', 
            'Processor__r.Name',
            'Processor__r.Test_Mode__c',
            'Processor__r.Type__c',
            'Account__c',
            'Processor__r.AP_Payment_Processor__c'
        };
        String customerId = customer.Id;
        List<String> conditions = new List<String>{
                'Account__c = :customerId',
                'External_Id__c <> NULL',
                'Processor__r.Active__c = TRUE',
                'Processor__r.AP_Payment_Processor__c = FALSE'
        };
        if (onlyProcessorIds != null && !onlyProcessorIds.isEmpty()) {
            conditions.add('Processor__c =: onlyProcessorIds');
        }

        SOQLBuilder q = new SOQLBuilder(Payment_Processor_Customer__c.SObjectType);
        q.assertIsAccessible()
         .setEnforceFLS(true)
         .selectFields(fields)
         .setCondition(String.join(conditions, ' AND '));

        List<Payment_Processor_Customer__c> ppcs = (List<Payment_Processor_Customer__c>) Database.query(q.toSOQL());
        
        for (Payment_Processor_Customer__c ppc : ppcs) {
            processorIdToName.put(ppc.Processor__c, ppc.Processor__r.Name);
            customersByProcessorId.put(ppc.Processor__c, ppc);
            try {
                sources.addAll(gtwy.getPaymentMethods(ppc, true));
            }catch (CardknoxProcessorV1.CardknoxProcessorV1AuthenticationException ex){
                // throw exception if it's related to invalid xkey for cardknox 
                if(ex.getMessage() == Label.ERR_INVALID_XKEY_VALUE){
                    throw new CardknoxProcessorV1.CardknoxProcessorV1AuthenticationException(Label.ERR_INVALID_XKEY_VALUE);
                }
            } catch (Exception e) {
                // Swallow error. We want to show whatever payment methods we can.
                // For example, if Provider A has an outage we still want to show Provider B sources.
            }
        }
        return this;
    }

    public PaymentMethodProvider leaveAvailableForSelectionOnly() {
        return leaveAvailableForSelectionOnly(false);
    }
    public PaymentMethodProvider leaveAvailableForSelectionOnly(Boolean stopIfEmpty) {
        for (Payment_Method__c pm : sources) {
            if (pm.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE
                    && pm.Verification_Status__c == 'verified'
                    && pm.Status__c == PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE) {
                sourceIdToStripeSourceMap.put(pm.External_Id__c, pm);
            }
            else if (pm.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE
                        && pm.Status__c == PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE) {
                sourceIdToStripeSourceMap.put(pm.External_Id__c, pm);
            }
        }

        if (sourceIdToStripeSourceMap.isEmpty() && stopIfEmpty) {
            throw new StripeService.StripeServiceException(Label.ERR_PAYMENTS_NO_ACTIVE_PAYMENT_METHOD);
        }
        else if (sourceIdToStripeSourceMap.isEmpty()) {
            noActiveSources = true;
        }

        return this;
    }

    public PaymentMethodProvider bindWithSF() {
        for (Payment_Method__c existedPM : queryPaymentMethodByExternalId()) {
            sourceIdToExistingPaymentMethodMap.put(existedPM.External_Id__c, existedPM);
            existedPMsCompositeKeys.add(PaymentMethodActions.buildCompositeKeyForPaymentMethod(existedPM));
            if (existedPM.Default__c) {
                defaultProcessorId = existedPM.Payment_Processor__c;
                defaultSourceId = existedPM.External_Id__c;
                defaultSourceType =
                    (sourceIdToStripeSourceMap.get(defaultSourceId) != NULL)
                        ? sourceIdToStripeSourceMap.get(defaultSourceId).Payment_Method_Type__c
                        : String.isBlank(existedPM.Payment_Method_Type__c)
                                ? PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE 
                                : existedPM.Payment_Method_Type__c;
            }
            if (sourceIdToStripeSourceMap.containsKey(existedPM.External_Id__c)) {
                sourceIdToStripeSourceMap.get(existedPM.External_Id__c).Id = existedPM.Id;
            }
        }

        //init picklist default selection
        if (String.isNotBlank(defaultSourceId)) {
            selectedSourceId = defaultSourceId;
            selectedSourceType = defaultSourceType;
            selectedProcessorId = defaultProcessorId;
        }

        return this;
    }

    public PaymentMethodProvider createSelectOption() {
        for (Payment_Method__c pm : sourceIdToStripeSourceMap.values()) {
            if (sourceIdToExistingPaymentMethodMap.get(pm.External_Id__c) == NULL
                    && existedPMsCompositeKeys.contains(PaymentMethodActions.buildCompositeKeyForPaymentMethod(pm))) {

                //if Stripe PM is not linked with SF side but it duplicates some of already existed SF PM
                //we will not create picklist option for it
            }
            else {
                SelectOption opt = new SelectOption(
                    pm.External_Id__c,
                    getCombinedSourceName(pm)
                );

                Id key = pm.Payment_Processor__c;
                
                if (!sourcesByProcessorId.containsKey(key)) {
                    sourcesByProcessorId.put(key, new List<SelectOption>());
                }
                sourcesByProcessorId.get(key).add(opt);
            }
        }

        for (Id processorId : sourcesByProcessorId.keySet()) {
            if (!sourcesByProcessorId.get(processorId)?.isEmpty()) {
                // add select option for provider
                processorSelectOptions.add(
                    new SelectOption(
                        processorId,
                        processorIdToName.get(processorId)
                    )
                );
            }
            // sort provider's payment methods
            SelectOptionSorter.doSort(sourcesByProcessorId.get(processorId), SelectOptionSorter.FieldToSort.Label);
        }

        // sort providers
        SelectOptionSorter.doSort(processorSelectOptions, SelectOptionSorter.FieldToSort.Label);

        if (String.isNotBlank(selectedProcessorId)) {
            sourceIdsSelectOptions = sourcesByProcessorId.get(selectedProcessorId);
        } else if (!processorSelectOptions.isEmpty()) {
            //there is no Default PM on the SF side
            Id defaultProc = PaymentGateway.getDefaultPaymentProcessorId();
            selectedProcessorId = sourcesByProcessorId.get(defaultProc) != null
                    // use the global default payment processor
                    ? defaultProc
                    // make first option as default
                    : processorSelectOptions.get(0).getValue();

            sourceIdsSelectOptions = sourcesByProcessorId.get(selectedProcessorId);
            if (sourceIdsSelectOptions != null && !sourceIdsSelectOptions.isEmpty()) {
                selectedSourceId = sourceIdsSelectOptions[0].getValue();
                selectedSourceType = sourceIdToStripeSourceMap.get(selectedSourceId).Payment_Method_Type__c;
            }
        }

        return this;
    }

    public Boolean isTestModeSelected() {
        Payment_Method__c pm = getStripeSourceBySelectedSource();
        Payment_Processor_Customer__c cust = customersByProcessorId.get(pm?.Payment_Processor__c);
        return cust?.Processor__r?.Test_Mode__c == null ? false : cust.Processor__r.Test_Mode__c;
    }

    public void updateSelectedPaymentMethod() {
        sourceIdsSelectOptions = sourcesByProcessorId.get(selectedProcessorId);
        if (!sourceIdsSelectOptions.isEmpty()) {
            selectedSourceId = sourceIdsSelectOptions.get(0).getValue();
        } else {
            selectedSourceId = null;
        }
        updateSelectedSourceType();
    }

    public void updateSelectedSourceType() {
        if (sourceIdToStripeSourceMap.get(selectedSourceId) != NULL) {
            selectedSourceType = sourceIdToStripeSourceMap.get(selectedSourceId).Payment_Method_Type__c;
        }
    }

    public Payment_Method__c getExistedPaymentMethodBySelectedSource() {
        return sourceIdToExistingPaymentMethodMap.get(selectedSourceId);
    }

    public Payment_Method__c getStripeSourceBySelectedSource() {
        return getStripeSourceBySelectedSource(this.selectedSourceId);
    }

    public Payment_Method__c getStripeSourceBySelectedSource(String selectedSourceId) {
        return sourceIdToStripeSourceMap.get(selectedSourceId);
    }

    public void addExistedPM(Payment_Method__c paymentMethod) {
        sourceIdToExistingPaymentMethodMap.put(paymentMethod.External_Id__c, paymentMethod);
    }

    private List<Payment_Method__c> queryPaymentMethodByExternalId() {
        Set<String> stripeSourceIds = sourceIdToStripeSourceMap.keySet();
        String accountId = customer.Id;

        List<String> queryFields = new List<String>{
            'Id',
            'External_Id__c',
            'Payment_Method_Type__c',
            'Default__c',
            'Customer__c',
            'Expiration_Month__c',
            'Expiration_Year__c',
            'Last_Four_Digits__c',
            'Bank_Name__c',
            'Type__c',
            'Payment_Processor__c'
        };
        String queryCondition =
            'Customer__c = :accountId ' +
            'AND External_Id__c IN :stripeSourceIds';

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Payment_Method__c>) Database.query(theQuery.toSOQL());
    }

    public String getSelectedSourceTypeAsLabel() {
        if (selectedSourceType == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE) {
            return PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
        }
        else if (selectedSourceType == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE) {
            return 'ACH ' + PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE;
        }
        else {
            return 'N/A';
        }
    }

    private String getCombinedSourceName(Payment_Method__c pm) {
        String namePart = '';
        String brandPart = '';
        String lastFourPart = String.isNotBlank(pm.Last_Four_Digits__c) ? pm.Last_Four_Digits__c : '';
        if (pm.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE) {
            namePart = (String.isNotBlank(pm.Card_Holder_Name__c)) ? pm.Card_Holder_Name__c + ' ' : '';
            brandPart += (String.isNotBlank(pm.Type__c) ? pm.Type__c + ' ' : '');
        } else if (pm.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE) {
            brandPart += (String.isNotBlank(pm.Bank_Name__c) ? pm.Bank_Name__c + ' ' : '');
        }
        return namePart.abbreviate(100) + brandPart + lastFourPart;
    }

}