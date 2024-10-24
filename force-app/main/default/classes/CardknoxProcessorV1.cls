public with sharing class CardknoxProcessorV1 implements PaymentProcessor {

    private static final String PAYMENT_ERROR = 'Error';
    private static final String PAYMENT_DECLINED = 'Declined';
    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    // allow mocking service dependency
    private CxClient cxSrvc;
    
    // exception classes
    public class CardknoxProcessorV1Exception extends Exception {}
    public class CardknoxProcessorV1AuthenticationException extends Exception {}

    public CardknoxProcessorV1() {
        this.cxSrvc = new CxClient();
    }

    // allow injecting mock dependencies
    @TestVisible
    private CardknoxProcessorV1(CxClient cxSrvc) {
        this.cxSrvc = cxSrvc;
    }

    /**
     * Creates a Cardknox customer for the provided Account.
     */
    public Payment_Processor_Customer__c createCustomer(Payment_Processor_Customer__c processorCustomer) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(processorCustomer.Processor__c);

        // get account
        Account account = PaymentProcessorUtils.getAccountWithDetails(processorCustomer.Account__c);

        //metadata to attach to a customer
        Map<String, String> metadata = getPreparedMetadata(account);

        // create the cardknox customer
        CardknoxService.Customer cardknoxCutomer = CardknoxService.createCardknoxCustomer(metadata,p);
        
        // make sure the XKey is valid
        checkIfXKeysAreInvalid(cardknoxCutomer.Error);

        // update junction object with cardknox customer id
        processorCustomer.External_Id__c = cardknoxCutomer.CustomerId;

        SFDCSecurityUtils.insertCheckCRUDAndFLS(processorCustomer, new List<String>{
            'External_Id__c',
            'Account__c',
            'Processor__c'
        });

        return processorCustomer;
    }
    /**
     * delete a specific customer in the cardknox
     */
    public void deleteCustomer(Payment_Processor_Customer__c processorCustomer) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(processorCustomer.Processor__c);

        // check compatibility
        if (processorCustomer.External_Id__c == null) {
            throw new CardknoxProcessorV1Exception(Label.ERR_CUSTOMER_NOT_FOUND_FOR_DELETE);
        }

        // get the cardknox customer
        CardknoxService.Customer cardknoxCutomer = CardknoxService.deleteCardknoxCustomer(processorCustomer.External_Id__c,p);

        // make sure the XKey is valid
        checkIfXKeysAreInvalid(cardknoxCutomer.Error);

        //deleting the payment processor customer from sf
        if(cardknoxCutomer.Result == 'S'){
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(processorCustomer);
        }else{
            throw new CardknoxProcessorV1Exception(Label.ERR_CUSTOMER_NOT_FOUND_FOR_DELETE);
        }
    }

    /**
     * Not implemented.
     */
    public Payment_Processor_Customer__c getCustomer(Payment_Processor_Customer__c processorCustomer) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(processorCustomer.Processor__c);

        // check compatibility
        if (processorCustomer.External_Id__c == null) {
            throw new CardknoxProcessorV1Exception(Label.ERR_CUSTOMER_NOT_FOUND);
        }

        // get the cardknox customer
        CardknoxService.Customer cardknoxCutomer = CardknoxService.getCardknoxCustomer(processorCustomer.External_Id__c,p);

        if(cardknoxCutomer.Result == 'E'){
            throw new CardknoxProcessorV1Exception(getComparedErrorMessage(cardknoxCutomer.Error,Label.ERR_CUSTOMER_NOT_FOUND));
        }
        return processorCustomer;
    }

    /**
     * Not implemented.
     */
    public List<Payment_Processor_Customer__c> getCustomers(Payment_Processor__c paymentProcessor) {
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
    }

    /**
     * Updates a cardknox customer with the associated Account details.
     */
    public Payment_Processor_Customer__c updateCustomer(Payment_Processor_Customer__c processorCustomer) {
        // TODO: implement
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
    }

    // ===== Payment Methods =====

    /**
     * 
     */
    public Payment_Method__c createPaymentMethod(Payment_Method__c paymentMethod, String paymentToken) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(paymentMethod.Payment_Processor__c);

        Payment_Processor_Customer__c ppc = PaymentProcessorUtils.getPaymentProcessorCustomer(
            paymentMethod.Payment_Processor__c, paymentMethod.Customer__c);

        Account acct = PaymentProcessorUtils.getAccountWithDetails(paymentMethod.Customer__c);

        if (acct == null) {
            // customer could not be found
            throw new CardknoxProcessorV1Exception(Label.ERR_PAYMENT_METHOD_ACCT_MISSING);
        }
        CardknoxService.PaymentMethod pm;
        if (ppc == null) {
            Map<String, String> metadata = getPreparedMetadata(acct);
            // create customer + payment method
            ppc = createCustomerInCardknox(metadata,acct,paymentMethod,p);
            try{
                pm = createPaymentMethod(ppc.External_Id__c,paymentMethod,paymentToken,p);
            }catch(CardknoxProcessorV1AuthenticationException exp){
                CardknoxService.deleteCardknoxCustomer(ppc.External_Id__c, p);
                throw new CardknoxProcessorV1AuthenticationException(exp.getMessage());
            }
            Payment_Method__c defaultMethod = DomainUtils.getCustomerDefaultPaymentMethod(acct.Id);
            paymentMethod.Default__c = defaultMethod == null;
        } else {
            // customer exists, just create payment method
            pm = createPaymentMethod(ppc.External_Id__c,paymentMethod,paymentToken,p);
        }
        if (pm.Result == 'E') {
            if (ppc.Id == null) {
                // ppc doesn't exist yet, so insert it
                insertPaymentProcessorCustomer(ppc);
            }
            // error creating cardknox source
            throw new CardknoxProcessorV1Exception(getComparedErrorMessage(pm.Error,String.format(
                                                                Label.ERR_PMT_PROCESSOR_CREATE, 
                                                                new List<String>{ SObjectType.Payment_Method__c.getLabel() }
                                                            )));
        }

        // populate the cardknox source data on the payment method
        paymentMethod.Last_Four_Digits__c = paymentToken.substring(paymentToken.indexOf(';')-4, paymentToken.indexOf(';'));
        paymentMethod.Customer__c = acct.Id;
        paymentMethod.Payment_Processor__c = p.Id;

         //GetPaymentMethod API to get Card Type
         pm = CardknoxService.getPaymentMethod(pm.PaymentMethodId,p);

        // make sure the XKey is valid
        checkIfXKeysAreInvalid(pm.Error);

        populateSourceData(paymentMethod, pm,true);

        try{
            //insert payment processor customer if it doesn't exist
            if (ppc.Id == null) {
                insertPaymentProcessorCustomer(ppc);
            }
        }catch(Exception ex){
            throw new CardknoxProcessorV1Exception(ex.getMessage());
        }
        try{
            //insert payment method
            insertPaymentMethod(paymentMethod);
        }catch(Exception ex){
            throw new CardknoxProcessorV1Exception(ex.getMessage());
        }

        // convert cardknox source to payment method
        return paymentMethod;
    }
    private static void insertPaymentProcessorCustomer(Payment_Processor_Customer__c ppc){
        if(ppc.Id == null){
            SFDCSecurityUtils.insertCheckCRUDAndFLS(ppc, new List<String>{
                'Processor__c',
                'External_Id__c',
                'Account__c'
            });
        }
    }
    private static List<Database.SaveResult> insertPaymentMethod(Payment_Method__c pm) {
        return insertPaymentMethod(new List<Payment_Method__c>{pm}, true);
    }
    private static List<Database.SaveResult> insertPaymentMethod(List<Payment_Method__c> paymentMethods, Boolean allOrNone) {
        List<Database.SaveResult> result = SFDCSecurityUtils.insertCheckCRUDAndFLS(paymentMethods, new List<String>{
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
        return result;
    }
    /**
     * 
     */
    public void deletePaymentMethod (Payment_Method__c paymentMethod) {
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
            // delete payment method in cardknox
            CardknoxService.PaymentMethod result = CardknoxService.deletePaymentMethod(paymentMethod.External_Id__c,p);

            // make sure the XKey is valid
            checkIfXKeysAreInvalid(result.Error);

            if(result.Result == 'E'){
                throw new CardknoxService.CardknoxServiceException(result.Error);
            }
        }
        // delete the payment method in SF
        SFDCSecurityUtils.deleteCheckCRUDAndFLS(pm);
    }

    /**
     * Get the payment method from cardknox
     */
    public Payment_Method__c getPaymentMethod(Payment_Method__c paymentMethod) {

        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(paymentMethod.Payment_Processor__c);

        Payment_Processor_Customer__c ppc = PaymentProcessorUtils.getPaymentProcessorCustomer(
            paymentMethod.Payment_Processor__c, paymentMethod.Customer__c);

        CardknoxService.PaymentMethod pm = CardknoxService.getPaymentMethod(paymentMethod.External_Id__c,p);

        if (pm.Result == 'E') { 
            // error creating cardknox source
            throw new CardknoxProcessorV1Exception(getComparedErrorMessage(pm.Error, Label.ERR_CUSTOMER_NOT_FOUND));
        }
        // convert cardknox source to payment method
        return paymentMethod;
    }

    /**
     * 
     */
    public List<Payment_Method__c> getPaymentMethods(Payment_Processor_Customer__c processorCustomer) {
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(processorCustomer.Processor__c);

        //get all existing payment methods through processor and customer
        Map<String,Payment_Method__c> paymentMethodsByExternalId = PaymentProcessorUtils.getPaymentMethodsByExternalId(processorCustomer.Account__c,processorCustomer.Processor__c);

        CardknoxService.ListPaymentMethod lstPaymentMethods = CardknoxService.listPaymentMethods(processorCustomer.External_Id__c,p);

        // make sure the XKey is valid
        checkIfXKeysAreInvalid(lstPaymentMethods.Error);

        // convert cardknox sources to SF payment methods
        List<Payment_Method__c> pmtMethods = new List<Payment_Method__c>();
        for (CardknoxService.PaymentMethod pmCardknox : lstPaymentMethods.PaymentMethods) {
            Payment_Method__c pm = convert(pmCardknox,paymentMethodsByExternalId);
            if (pm != null) {
                pm.Customer__c = processorCustomer.Account__c;
                pm.Payment_Processor__c = processorCustomer.Processor__c;
                pmtMethods.add(pm);
            }
        }
        return pmtMethods;
    }
    private static Payment_Method__c convert(CardknoxService.PaymentMethod pmCardknox,Map<String,Payment_Method__c> paymentMethodsByExternalId) {
        if (pmCardknox.TokenType != 'CC' && pmCardknox.TokenType != 'Check') {
            // unsupported type
            return null;
        }

        Payment_Method__c pm = new Payment_Method__c();

        // filter status from existing payment method as cardknox does not have status feature
        // else put active status
        pm.Status__c = paymentMethodsByExternalId.containsKey(pmCardknox.PaymentMethodId) ? 
                        paymentMethodsByExternalId.get(pmCardknox.PaymentMethodId).Status__c : 
                        PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE;
        pm.External_Id__c = pmCardknox.PaymentMethodId;
        pm.Last_Four_Digits__c = pmCardknox.MaskedNumber.substring(pmCardknox.MaskedNumber.length() - 4,pmCardknox.MaskedNumber.length());
        if (pmCardknox.TokenType == 'CC') { // credit card
            // add CC details
            pm.Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
            pm.Type__c = pmCardknox.Issuer == null ? pmCardknox.CardType : pmCardknox.Issuer;
            //to save consistency of Expiration Month in whole product
            //it must be 2-characters-wide
            pm.Expiration_Month__c = ((String.valueOf(pmCardknox.Exp).length() == 4)
            ? String.valueOf(pmCardknox.Exp).substring(0,2)
            : String.valueOf(pmCardknox.Exp));
            pm.Expiration_Year__c = ((String.valueOf(pmCardknox.Exp).length() == 4)
            ? String.valueOf(pmCardknox.Exp).substring(2,4)
            : String.valueOf(pmCardknox.Exp));
            pm.Card_Holder_Name__c = pmCardknox.Name;
        } else if (pmCardknox.TokenType == 'Check') { // ach
            // add ACH details
            pm.Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE;
            pm.Bank_Account_Type__c = PaymentMethodActions.INDIVIDUAL_TYPE;
            pm.Verification_Status__c = PaymentMethodActions.VERIFIED_STATUS;
            pm.Card_Holder_Name__c = pmCardknox.Name;
        }

        return pm;
    }
    /**
     * 
     */
    public Payment_Method__c updatePaymentMethod(Payment_Method__c paymentMethod) {
        // get sObject with all fields needed
        Payment_Method__c pm = DomainUtils.getPaymentMethod(paymentMethod.Id);
        // get processor
        Payment_Processor__c p = PaymentProcessorUtils.getPaymentProcessor(pm.Payment_Processor__c);

        List<Payment_Processor_Customer__c> ppcs = DomainUtils.getPaymentProcessorCustomer(
            pm.Payment_Processor__c, 
            pm.Customer__c
        );
        Payment_Processor_Customer__c ppc = ppcs == null || ppcs.isEmpty() ? null : ppcs.get(0);
        if (ppc == null) {
            throw new CardknoxProcessorV1Exception(Label.ERR_PAYMENTS_NO_CUSTOMER_FOR_PMT_METHOD);
        }

        Map<String, String> payload = new Map<String, String>();
        String monthValue = '';
        if (pm.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE) {
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Card_Holder_Name__c')) {
                payload.put('Name', paymentMethod.Card_Holder_Name__c);
            }
        } else if (pm.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE) {
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Card_Holder_Name__c')) {
                payload.put('Name', paymentMethod.Card_Holder_Name__c);
            }
            if (paymentMethod.isSet(PACKAGE_QUALIFIER + 'Expiration_Month__c') && paymentMethod.isSet(PACKAGE_QUALIFIER + 'Expiration_Year__c')) {
                monthValue = paymentMethod.Expiration_Month__c.length() >= 2
                    ? paymentMethod.Expiration_Month__c.right(2)
                    : paymentMethod.Expiration_Month__c.leftPad(2,'0');
                monthValue = monthValue + paymentMethod.Expiration_Year__c.right(2);
                payload.put('Exp', monthValue);
            }

        }

        // update payment mehtod in cardknox
        if (!payload.isEmpty()) {
            CardknoxService.PaymentMethod response = CardknoxService.updatePaymentMethod(paymentMethod,payload,p);
            if (response.Result == 'E') {
                // error creating cardknox source
                throw new CardknoxProcessorV1Exception(getComparedErrorMessage(response.Error,Label.ERR_CARDKNOX_SOURCE_UPDATE_FAILED));
            }
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
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c ccCapture(Payment_Method__c paymentMethod) {
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c ccCredit(Payment_Method__c paymentMethod) {
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c ccRefund(Payment_Method__c paymentMethod) {
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
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
        voidTransaction(paymentActivity);
    }

    // ===== ACH =====

    /**
     * Not Implemented.
     */
    public Payment_Activity__c achCredit(Payment_Method__c paymentMethod) {
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
    }

    /**
     * Not Implemented.
     */
    public Payment_Activity__c achRefund(Payment_Method__c paymentMethod) {
        throw new CardknoxProcessorV1Exception(Label.COMMON_METHOD_NOT_IMPLEMENTED);
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
        voidTransaction(paymentActivity);
    }

    private void voidTransaction(Payment_Activity__c paymentActivity){
        // get processor
        Payment_Processor__c pp = PaymentProcessorUtils.getPaymentProcessor(paymentActivity.Cash_Receipt__r.Payment_Processor__c);

        CardknoxService.VoidReport voidReportdata = CardknoxService.voidTransaction(paymentActivity, pp);
 
        // make sure the XKey is valid
        checkIfXKeysAreInvalid(voidReportdata.xError);

        if(voidReportdata.xResult == 'E'){
            String message = voidReportdata.xError == Label.ERR_CARDKNOX_TRANSACTION_CAN_NO_LONGER_VOIDED_REFUND || 
                                voidReportdata.xError == Label.ERR_CARDKNOX_TRANSACTION_SETTELED_CANNOT_BE_VOIDED ? 
                                Label.ERR_CARDKNOX_VOID_FAILED_PAYMENT_BATCH_CLOSED : voidReportdata.xError;
            throw new CardknoxProcessorV1Exception(message);
        }

    }
    // ===== Payment Activity Status =====

    /**
     * Method to update the payment activity which are pendings, with their corresponding status from cardknox
     */
    public List<Payment_Activity__c> getPaymentActivityStatus(List<Payment_Activity__c> paymentActivities) {
        // sort by processor because there can be a mix. For example Cardknox Account 1 and Cardnox Account 2
        Map<Id,List<Payment_Activity__c>> processorToActivities = new Map<Id,List<Payment_Activity__c>>();
        Map<Id,List<String>> processorToRefs = new Map<Id,List<String>>();
        
        for (Payment_Activity__c activity : paymentActivities) {
           Id processorId = activity.Payment_Method__r.Payment_Processor__c;
           if (!processorToActivities.containsKey(processorId)) {
               processorToActivities.put(processorId, new List<Payment_Activity__c>());
               processorToRefs.put(processorId, new List<String>());
           }
           processorToActivities.get(processorId).add(activity);

           if(activity?.Merchant_Reference__c != null){
               processorToRefs.get(processorId).add(activity.Merchant_Reference__c);
           }
        }

       Map<Id,Payment_Processor__c> paymentProcessors = new Map<Id,Payment_Processor__c>(
       DomainUtils.getPaymentProcessorsById(processorToActivities.keySet()));

       // for each processor...
       for (Id processorId : processorToActivities.keySet()) {
           CardknoxService.Report report;
           try {
               // fetch the cardknox transaction related to the payment activity    
               report = cxSrvc.getTransactionReport(processorToRefs.get(processorId), paymentProcessors.get(processorId));
           } catch (CardknoxService.CardknoxServiceException e) {
               throw e;
           } catch (Exception e) {
               throw new CardknoxProcessorV1Exception(
                   String.format(Label.ERR_RETRIEVING_PMT_ACTIVITY_UPDATES, new List<String>{Label.COMMON_CARDKNOX}) 
                   + ': ' + e.getMessage() + '\n' + e.getStackTraceString()
               );
           }
               
           // error fetching report data
           if (report.xResult.equalsIgnoreCase(CardknoxService.RESP_ERROR_CODE) || report.xStatus.equalsIgnoreCase(CardknoxService.RESP_RESULT_ERROR)) {
               throw new CardknoxProcessorV1Exception(String.format(Label.ERR_RETRIEVING_PMT_ACTIVITY_UPDATES, new List<String>{Label.COMMON_CARDKNOX})+ ': ' + report.xError);    
           }

           // create map to avoid nested for loop when matching activity to report data
           Map<String, CardknoxService.ReportData> dataByRefNum = new Map<String, CardknoxService.ReportData>();
           for (CardknoxService.ReportData data : report.xReportData) {
               dataByRefNum.put(data.xRefNum, data);
           }

           // update activities with report data
           for (Payment_Activity__c activity : paymentActivities) {
               CardknoxService.ReportData data = dataByRefNum.get(activity.Merchant_Reference__c);
               if (data == null) {
                   // transaction not included in cardknox report
                   continue; 
               }
               activity.Error_Type__c = data.xErrorCode;
               activity.Error_Message__c = data.xResponseError;
               activity.Merchant_Reference__c = data.xRefNum;
               activity.Merchant_Batch_Id__c = data.xResponseBatch;
               activity.Fee__c = data.xProcessingFee;
               activity.Payment_Date__c = data.xEnteredDateUTC();
               activity.Status__c = getPaymentActivityStatus(data);
           }
       }

       return paymentActivities;
    }

    // ======================================

    private Payment_Processor_Customer__c createCustomerInCardknox(
        Map<String,String> metadata,Account acct, Payment_Method__c paymentMethod,Payment_Processor__c pp) {

        CardknoxService.Customer customer = CardknoxService.createCardknoxCustomer(metadata,pp);

        // make sure the XKey is valid
        checkIfXKeysAreInvalid(customer.Error);

        // create payment processor customer
        Payment_Processor_Customer__c ppc = new Payment_Processor_Customer__c(
            External_Id__c = customer.customerId,
            Account__c = acct.Id,
            Processor__c = paymentMethod.Payment_Processor__c
        );
        
        return ppc;
    }

    private CardknoxService.PaymentMethod createPaymentMethod(
            String customerId, Payment_Method__c payMethod,String token,Payment_Processor__c pp) {
        CardknoxService.PaymentMethod pm = CardknoxService.createPaymentMethod(customerId,payMethod,token,pp);
        
        // make sure the XKey is valid
        checkIfXKeysAreInvalid(pm.Error);

        return pm;
    }

    private Payment_Method__c populateSourceData(Payment_Method__c paymentMethod, CardknoxService.PaymentMethod pm,Boolean extIdReqr) {
        paymentMethod.Status__c = CardknoxService.PAYMENT_METHOD_STATUS_ACTIVE;
        if(extIdReqr){
            paymentMethod.External_Id__c = pm.PaymentMethodId;
        }
        if(paymentMethod.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE){
            paymentMethod.Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
            paymentMethod.Type__c = pm.Issuer;
        }else{
            paymentMethod.Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE;
            paymentMethod.Bank_Account_Type__c = 'Individual';
        }

        return paymentMethod;
    }

    /**
     * method to prepare metadata for the update anf create a cutomer
     */
    private static Map<String,String> getPreparedMetadata(Account a){
        Map<String,String> metadata = new Map<String,String>();

        if(a.Billing_Contact__c != null){
            metadata.put('BillPhone',a.Billing_Contact__r.Phone);
            metadata.put('BillEmail',a.Billing_Contact__r.Email);
            metadata.put('BillFirstName',a.Billing_Contact__r.FirstName);
            metadata.put('BillLastName',a.Billing_Contact__r.LastName);
        }
        if(a.Shipping_Contact__c != null){
            metadata.put('ShipPhone',a.Shipping_Contact__r.Phone);
            metadata.put('ShipEmail',a.Shipping_Contact__r.Email);
            metadata.put('ShipFirstName',a.Shipping_Contact__r.FirstName);
            metadata.put('ShipLastName',a.Shipping_Contact__r.LastName);
        }
        metadata.put('Name',a.Name);
        metadata.put('AccountId',a.Id);
        metadata.put('BillStreet',a.BillingStreet);
        metadata.put('BillCity',a.BillingCity);
        metadata.put('BillState',a.BillingState);
        metadata.put('BillZip',a.BillingPostalCode);
        metadata.put('BillCountry',a.BillingCountry);
        metadata.put('ShipStreet',a.ShippingStreet);
        metadata.put('ShipCity',a.ShippingCity);
        metadata.put('ShipState',a.ShippingState);
        metadata.put('ShipZip',a.ShippingPostalCode);
        metadata.put('ShipCountry',a.ShippingCountry);
        return metadata;
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

        List<ChargeWrap> chargeWraps = new List<ChargeWrap>();
        Set<String> chargeIds = new Set<String>();
        for (PaymentSaleItem saleItem : saleItems) {
            String currencyCode = currencyCode(saleItem.cashReceipt);
            
            if(MultiCurrencyHandler.isMultiCurrencyEnabled){
                if (!LedgerHandler.isLedgerCurrency(String.valueOf(saleItem.cashReceipt.get('CurrencyIsoCode')),saleItem.cashReceipt.Ledger__c)) {
                    saleItem.errors.add(Label.ERR_CARDKNOX_PAYMENT_SHOULD_BE_IN_LEDGER_CURRENCY);
                    continue;
                }
            }
            if (saleItem.cashReceipt.Bank_Account__c == null) {
                // default bank account to the processor's merchant processing account
                saleItem.cashReceipt.Bank_Account__c = paymentProcessors.get(saleItem.paymentMethod.Payment_Processor__c)?.Merchant_GL_Account__c;
            }
            if (saleItem.cashReceipt.Bank_Account__c == null ||
                saleItem.cashReceipt.Bank_Account__c != paymentProcessors.get(saleItem.paymentMethod.Payment_Processor__c)?.Merchant_GL_Account__c) {
                // bank account must match the processor's merchant processing account
                saleItem.errors.add(Label.ERR_CARDKNOX_PAYMENT_REQUIRES_MERCHANT_GL);
                continue;
            }

            String processorCustomerKey = PaymentProcessorUtils.composeKey(new List<String>{
                    saleItem.paymentMethod.Payment_Processor__c, saleItem.paymentMethod.Customer__c
            });
            Payment_Processor_Customer__c ppcRecord = ppcRecordsByProcessorCustomerKeys.get(processorCustomerKey) != null && !ppcRecordsByProcessorCustomerKeys.get(processorCustomerKey).isEmpty()
                ? ppcRecordsByProcessorCustomerKeys.get(processorCustomerKey)[0] : null;
            if (ppcRecord != null) {
                try {
                     // process the transaction in cardknox
                    CardknoxService.PaymentTransaction payment = 
                            CardknoxService.doProcessTransaction(
                                saleItem,
                                currencyCode,
                                paymentProcessors.get(saleItem.paymentMethod.Payment_Processor__c));
                   
                    if(payment.GatewayStatus == PAYMENT_ERROR || String.isBlank(payment.Error) == false){
                        saleItem.errors.add(payment.GatewayErrorMessage, 'CARDKNOX_ERROR');
                        saleItem.paymentActivity(PaymentActivityHelper.createPaymentActivity(
                            saleItem,
                            payment,
                            paymentProcessors.get(saleItem.paymentMethod.Payment_Processor__c)));
                        continue;
                    }else if(payment.GatewayStatus == PAYMENT_DECLINED){
                        saleItem.errors.add(Label.ERR_YOUR_CARD_WAS_DECLINED, 'CARDKNOX_ERROR');
                        saleItem.paymentActivity(PaymentActivityHelper.createPaymentActivity(
                                payment,
                                saleItem,
                                Label.ERR_YOUR_CARD_WAS_DECLINED
                        ));
                        continue;
                    }
                    chargeIds.add(payment.GatewayRefNum);
                    chargeWraps.add(new ChargeWrap(payment, saleItem));
                } catch (Exception e) {
                    saleItem.errors.add(e.getMessage(), 'CARDKNOX_ERROR');
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

        List<ChargeWrap> chargeWraps4CashReceipts = new List<ChargeWrap>();
        Map<String, Cash_Receipt__c> cashReceiptsByRefs = PaymentProcessorUtils.cashReceiptsByRefs(chargeIds);
        for (ChargeWrap wrap : chargeWraps) {
            if (cashReceiptsByRefs.get(wrap.payment.GatewayRefNum) == null) {
                chargeWraps4CashReceipts.add(wrap);
            } else {
                wrap.saleItem.errors.add(Label.ERR_PAYMENTS_DUPLICATE_FOUND + ' ' + SObjectType.Cash_Receipt__c.getLabel() + ' ' + cashReceiptsByRefs.get(wrap.payment.GatewayRefNum).Name);
            }
        }

        chargeWraps4CashReceipts = createCashReceipt(chargeWraps4CashReceipts,paymentProcessors);
        for (ChargeWrap wrap : chargeWraps4CashReceipts) {
            if (wrap.saleItem.errors.isEmpty()) {
                wrap.saleItem.paymentActivity(PaymentActivityHelper.createPaymentActivity(
                        wrap.saleItem,
                        wrap.payment,
                        paymentProcessors.get(wrap.saleItem.paymentMethod.Payment_Processor__c)
                ));
            }
        }

        List<Payment_Method__c> paymentMethods4Insert = new List<Payment_Method__c>();
        Map<String,Id> extIdWithPMId = new Map<String,Id>();
        
        for (PaymentSaleItem saleItem : saleItems) {
            if (String.isBlank(saleItem.paymentMethod.Id)) {
                paymentMethods4Insert.add(saleItem.paymentMethod);
            }
        }
        
        if (!paymentMethods4Insert.isEmpty()) {
            List<Database.SaveResult> pms = insertPaymentMethod(paymentMethods4Insert, false);
            for(Integer i = 0; i < pms.size(); i++) {
                if(pms[i].isSuccess()){
                    extIdWithPMId.put(paymentMethods4Insert[i].External_Id__c, pms[i].getId());
                }
        	}
        }
        
        for (PaymentSaleItem saleItem : saleItems) {
            if (String.isBlank(saleItem.paymentMethod.Id)) {
                saleItem.paymentMethod.Id = extIdWithPMId.get(saleItem.paymentMethod.External_Id__c);
            }
        }


        saleItems = createPaymentActivities(saleItems,paymentProcessors);

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
    private static List<ChargeWrap> createCashReceipt(List<ChargeWrap> chargeWraps,Map<Id,Payment_Processor__c> paymentProcessors) {
        List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
        for (ChargeWrap wrap : chargeWraps) {
            wrap.saleItem.cashReceipt.Payment_Reference__c = wrap.payment.GatewayRefNum;
            wrap.saleItem.cashReceipt.Payment_Processor__c = wrap.saleItem.paymentMethod.Payment_Processor__c;
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
                            cashReceipts[index].Payment_Reference__c,
                            composeErrorMsg(result)
                        }
                    );
                    chargeWraps[index].saleItem.errors.add(errorMessage);
                }
            }
        }
        return chargeWraps;
    }
    private static List<PaymentSaleItem> createPaymentActivities(List<PaymentSaleItem> saleItems,Map<Id,Payment_Processor__c> paymentProcessors) {
        List<Payment_Activity__c> paymentActivities = new List<Payment_Activity__c>();
        List<PaymentSaleItem> saleItemWithActivities = new List<PaymentSaleItem>();
        List<Id> paymentProcessorsIds = new List<Id>();
        Set<Id> cashReceiptIds = new Set<Id>();
        for (PaymentSaleItem saleItem : saleItems) {
            if (saleItem.paymentActivity != null) {
                saleItem.paymentActivity.Payment_Method__c = saleItem.paymentMethod.Id;
                paymentProcessorsIds.add(saleItem.paymentMethod.Payment_Processor__c);
                paymentActivities.add(saleItem.paymentActivity);
                saleItemWithActivities.add(saleItem);
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
                                paymentActivities[index].Merchant_Reference__c,
                                composeErrorMsg(result),
                                cashReceipts.get(saleItemWithActivities[index].cashReceipt?.Id)?.Name});

                    }else{
                        errorMessage = String.format(Label.ERR_PAYMENTS_STRIPE_CREATE_CHARGE_ACTIVITY, 
                            new List<String>{
                                paymentProcessors?.get(paymentProcessorsIds[index]).Type__c,
                                paymentActivities[index].Merchant_Reference__c,
                                composeErrorMsg(result)
                            });
                    }

                    saleItemWithActivities[index].errors.add(errorMessage);             
                }
            }
        }

        return saleItems;
    }

    private static String composeErrorMsg(Database.SaveResult result) {
        return PaymentGateway.composeErrorMsg(result);
    }
    // if entered xkey on the payment processor is invalid or wrong throw a custom exception
    private static void checkIfXKeysAreInvalid(String errorMessage){
        // throw error if entered key is invalid
        if(errorMessage == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX || 
            errorMessage == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX_KEY_INACTIVE || 
            errorMessage == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX_ACCESS_DENIED){
            throw new CardknoxProcessorV1AuthenticationException(Label.ERR_INVALID_XKEY_VALUE);
        }else if(errorMessage == Label.ERR_INVALID_IFIELDS_ERROR_FROM_CARDKNOX){
            throw new CardknoxProcessorV1AuthenticationException(Label.ERR_INVALID_IFIELDS_VALUE);
        }
    }
    // use to get the compared error message between xkey invalid or a different error
    private static String getComparedErrorMessage(String errorToCompare, String defaultMessage){
        return errorToCompare == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX  ||  
                errorToCompare == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX_KEY_INACTIVE || 
                errorToCompare == Label.ERR_INVALID_XKEY_ERROR_MESSAGE_FROM_CARDKNOX_ACCESS_DENIED ? 
                Label.ERR_INVALID_XKEY_VALUE : 
                errorToCompare == Label.ERR_INVALID_IFIELDS_ERROR_FROM_CARDKNOX ? 
                Label.ERR_INVALID_IFIELDS_VALUE :
                defaultMessage;
    }

    // translates a transaction status into a payment activity status
    @TestVisible
    private static String getPaymentActivityStatus(CardknoxService.ReportData txn) {
        // xResponseResult is the Gateway status. 0 = pending, 6 = awaiting response, 14 = chargeback, 16 = settled
        // xStatus is the ACH Status. Approved, Declined, Error
        // xCommand = transaction type. ie. sale, auth, void, capture, refund, credit
        if (txn.isVoid()) {
            return PaymentActivityHelper.VOID_STATUS;
        } else if (isSuccessStatus(txn)) {
            return PaymentActivityHelper.SUCCESS_STATUS;
        } else if (isErrorStatus(txn)) {
            return PaymentActivityHelper.ERROR_STATUS;
        }else if (isDeclinedStatus(txn)) {
            return PaymentActivityHelper.DECLINED_STATUS;
        } else if (isPendingStatus(txn)) {
            return PaymentActivityHelper.PENDING_STATUS;
        }
        return PaymentActivityHelper.ERROR_STATUS;
    }

    private static Boolean isSuccessStatus(CardknoxService.ReportData txn) {
        return ((CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
                && CardknoxService.COMMAND_CC_SALE.equalsIgnoreCase(txn.xCommand))
            || (CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
                && CardknoxService.COMMAND_CHECK_SALE.equalsIgnoreCase(txn.xCommand)
                && CardknoxService.STATUS_SETTLED == txn.xStatus));
    }

    private static Boolean isErrorStatus(CardknoxService.ReportData txn) {
        return (CardknoxService.RESP_RESULT_ERROR.equalsIgnoreCase(txn.xResponseResult)
                || (CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
                    && CardknoxService.COMMAND_CHECK_SALE.equalsIgnoreCase(txn.xCommand)
                    && CardknoxService.STATUS_CHARGEBACK == txn.xStatus));
    }

    private static Boolean isDeclinedStatus(CardknoxService.ReportData txn) {
        return CardknoxService.RESP_RESULT_DECLINED.equalsIgnoreCase(txn.xResponseResult);
    }

    private static Boolean isPendingStatus(CardknoxService.ReportData txn) {
        return (CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
            && CardknoxService.COMMAND_CHECK_SALE.equalsIgnoreCase(txn.xCommand)
            && (CardknoxService.STATUS_PENDING == txn.xStatus 
                || CardknoxService.STATUS_AWAITING_RESPONSE == txn.xStatus));
    }

    private class ChargeWrap {
        public CardknoxService.PaymentTransaction payment;
        public PaymentSaleItem saleItem;

        public ChargeWrap(CardknoxService.PaymentTransaction payment, PaymentSaleItem saleItem) {
            this.payment = payment;
            this.saleItem = saleItem;
        }
    }
}