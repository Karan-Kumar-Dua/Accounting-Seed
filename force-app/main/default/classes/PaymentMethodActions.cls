public with sharing class PaymentMethodActions {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String BANK_PAYMENT_METHOD_TYPE = 'Bank Account';
    public static final String CREDIT_CARD_PAYMENT_METHOD_TYPE = 'Credit Card';
    public static final String ACH_PAYMENT_METHOD_TYPE = 'ACH Bank Account';
    public static final String VCARD_PAYMENT_METHOD_TYPE = 'Virtual Card';
    public static final String ATTEMPT_TO_CHANGE_PM_TYPE_ERROR = Label.ERR_ATTEMPT_TO_CHANGE_PM_TYPE;
    public static final String DUPLICATED_PAYMENT_METHOD_ERROR = Label.ERR_DUPLICATED_PAYMENT_METHOD;    
    public static final String VERIFIED_STATUS = 'verified';
    public static final String INDIVIDUAL_TYPE = 'Individual';    
    public static final String PAYMENT_METHOD_STATUS_ACTIVE = 'Active';
    public static final String PAYMENT_METHOD_STATUS_INACTIVE = 'Inactive';
    public static final String STANDARD_DELETE_METHOD_NOT_ALLOWED_ERROR =
        Label.ERR_STANDARD_DELETE_METHOD_NOT_ALLOWED;
    public static final String STANDARD_EDIT_METHOD_NOT_ALLOWED_ERROR =
        Label.ERR_STANDARD_EDIT_METHOD_NOT_ALLOWED;
    public static final String STRIPE_IMMUTABLE_FIELD_UPDATE_ERROR =
        Label.ERR_STRIPE_IMMUTABLE_FIELD_UPDATE;
    public static final String ERROR_FOR_CUSTOMER_OR_VENDOR_FIELD =
        Label.ERR_SPECIFY_VENDOR_OR_CUSTOMER_ON_PM;

    public static Set<String> stripeImmutableFields = new Set<String>{
        PACKAGE_QUALIFIER + 'Customer__c',
        PACKAGE_QUALIFIER + 'External_Id__c',
        PACKAGE_QUALIFIER + 'Last_Four_Digits__c',
        PACKAGE_QUALIFIER + 'Type__c'
    };
    public static final String EXTERNAL_USE_UPDATE_ERROR = Label.ERR_EXTERNALUSE_PAYMENT_METHOD;
    public static final String DEFAULT_PAYMENT_METHOD_ERROR = Label.ERR_DEFAULT_PAYMENT_METHOD;
    public static final String PLACEHOLDER_CARD_EXTERNAL_ID = 'external_card';
    public static final String PLACEHOLDER_ACH_EXTERNAL_ID = 'external_ach';
    public static final String PLACEHOLDER_TYPE = 'Unknown';
    public static final String PLACEHOLDER_LAST_FOUR = 'xxxx';
    public static final String PLACEHOLDER_EXPIRATION_MONTH = '01';
    public static final String PLACEHOLDER_EXPIRATION_YEAR = '5000';
    public static final String PLACEHOLDER_ROUTING_NUMBER = 'xxxxxxxxx';
    public static final String PLACEHOLDER_BANK_ACCOUNT_TYPE = INDIVIDUAL_TYPE;
    public static final String PLACEHOLDER_BANK_NAME = 'Unknown';
    
    public static Boolean isFirstRun = true;
    public static PaymentMethodDeleteController deleteController;
    public static PaymentMethodEditController editController;
    public static Boolean isPreventUpdateOverride = false;

    public static void preventStandardDeletion(List<Payment_Method__c> recordsToDelete) {
        if (deleteController == NULL || (deleteController.isDeletionAllowed != true)) {
            for (Payment_Method__c pm : recordsToDelete) {
                pm.addError(STANDARD_DELETE_METHOD_NOT_ALLOWED_ERROR);
            }
        }
    }

    public static void preventStandardUpdate(   List<Payment_Method__c> recordsToUpdate,
                                                Map<Id, Payment_Method__c> oldRecordsMap    ) {

        if (editController == NULL || (editController.isUpdateAllowed != true)) {
            for (Payment_Method__c pm : recordsToUpdate) {
                pm.addError(STANDARD_EDIT_METHOD_NOT_ALLOWED_ERROR);
            }
        }
        else {
            PaymentMethodActions.preventUpdateMappedFields(recordsToUpdate, oldRecordsMap);
        }
    }

    public static void preventUpdateMappedFields(   List<Payment_Method__c> newRecords,
                                                    Map<Id, Payment_Method__c> oldRecordsMap    ) {

        for (Payment_Method__c newPM : newRecords) {
            if(newPM.AP_Payment_Method__c){
                continue;
            }

            Payment_Method__c oldPM = oldRecordsMap.get(newPM.Id);
            for (String fieldAPIName : stripeImmutableFields) {
                if (newPM.get(fieldAPIName) != oldPM.get(fieldAPIName)) {
                    newPM.addError(String.format(STRIPE_IMMUTABLE_FIELD_UPDATE_ERROR, new List<String>{fieldAPIName}));
                    break;
                }
            }
        }
    }

    public static void preventChangePaymentMethodType(  List<Payment_Method__c> newRecords,
                                                        Map<Id, Payment_Method__c> oldRecordsMap) {

        for (Payment_Method__c pm : newRecords) {
            Payment_Method__c oldPm = oldRecordsMap.get(pm.Id);
            if (oldPm.Payment_Method_Type__c != NULL && oldPm.Payment_Method_Type__c != pm.Payment_Method_Type__c) {
                pm.Payment_Method_Type__c.addError(ATTEMPT_TO_CHANGE_PM_TYPE_ERROR);
            }
        }

    }

    public static void preventUpdateOnExtUse(List<Payment_Method__c> newPaymentMethods) {
        for (Payment_Method__c newPaymentMethod : newPaymentMethods) {

            if (newPaymentMethod.External_Use_Only__c) {
                newPaymentMethod.addError(EXTERNAL_USE_UPDATE_ERROR);
            }
        }
    }

    public static void preventDuplicatePaymentMethod(List<Payment_Method__c> newPaymentMethods) {

        if (isPreventUpdateOverride) {
            return;
        }

        Map<String, Payment_Method__c> compositeKeyToPM = new Map<String, Payment_Method__c>();
        List<Payment_Method__c> duplicates = new List<Payment_Method__c>();
        
        //check uniqueness among new records
        for (Payment_Method__c newPaymentMethod : newPaymentMethods) {
            if(newPaymentMethod.AP_Payment_Method__c){
                continue;
            }

            String compositeKey = buildCompositeKeyForPaymentMethod(newPaymentMethod);

            if (compositeKeyToPM.containsKey(compositeKey)) {
                duplicates.add(newPaymentMethod);
            }
            else {
                compositeKeyToPM.put(compositeKey, newPaymentMethod);
            }
        }

        if (!duplicates.isEmpty()) {
            for (Payment_Method__c duplicatedPM : duplicates) {
                duplicatedPM.addError(DUPLICATED_PAYMENT_METHOD_ERROR);
            }
        }
        else {//if all new records are unique between themselves - check among the already existing records
            for (Payment_Method__c existedPaymentMethod : DomainUtils.getAllPaymentMethods()) {
                if(existedPaymentMethod.AP_Payment_Method__c){
                    continue;
                }

                String compositeKey = buildCompositeKeyForPaymentMethod(existedPaymentMethod);
                if (compositeKeyToPM.containsKey(compositeKey)) {
                    //only if it is not the same record which was just updated
                    if (compositeKeyToPM.get(compositeKey).Id != existedPaymentMethod.Id) {
                        Payment_Method__c duplicatedPM = compositeKeyToPM.get(compositeKey);
                        duplicates.add(duplicatedPM);
                    }
                }
            }
        }

        if (!duplicates.isEmpty()) {
            for (Payment_Method__c duplicatedPM : duplicates) {
                duplicatedPM.addError(DUPLICATED_PAYMENT_METHOD_ERROR);
            }
        }
    }

    public static String buildCompositeKeyForPaymentMethod(Payment_Method__c pm) {
        String compositeKey;
        if (pm.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE) {
            compositeKey =
                '' + pm.Payment_Processor__c + pm.Customer__c + pm.Type__c +
                ((pm.Expiration_Month__c != NULL && pm.Expiration_Month__c.trim().length() < 2)
                    ? ('0' + pm.Expiration_Month__c.trim())
                    : pm.Expiration_Month__c) +
                pm.Expiration_Year__c +
                pm.Last_Four_Digits__c;
        }
        else if (pm.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE) {
            compositeKey = '' + pm.Payment_Processor__c + pm.Customer__c + pm.Bank_Name__c + pm.Last_Four_Digits__c;
        }
        return compositeKey;
    }

    public static void requireFields(List<Payment_Method__c> newPaymentMethods) {
        for (Payment_Method__c pm : newPaymentMethods) {
            if (pm.Payment_Method_Type__c == CREDIT_CARD_PAYMENT_METHOD_TYPE && pm.Type__c == NULL) {
                pm.Type__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (pm.Payment_Method_Type__c == BANK_PAYMENT_METHOD_TYPE && pm.Bank_Account_Type__c == NULL) {
                pm.Bank_Account_Type__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (pm.Payment_Method_Type__c == CREDIT_CARD_PAYMENT_METHOD_TYPE && pm.Expiration_Month__c == NULL) {
                pm.Expiration_Month__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (pm.Payment_Method_Type__c == CREDIT_CARD_PAYMENT_METHOD_TYPE && pm.Expiration_Year__c == NULL) {
                pm.Expiration_Year__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (pm.Status__c == NULL) {
                pm.Status__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void setDefaultFields(List<Payment_Method__c> newPaymentMethods) {

        for (Payment_Method__c pm : newPaymentMethods) {
            if (pm.Payment_Method_Type__c == NULL) {
                pm.Payment_Method_Type__c = CREDIT_CARD_PAYMENT_METHOD_TYPE;
            }
        }
    }

    //set the Ext Ids for ACH AP Auto records that do not have an Ext Id value.
    //records originating from Edenred will be upserted with the ext id values
    public static void setAPExternalID(List<Payment_Method__c> newPaymentMethods){
        for (Payment_Method__c pm : newPaymentMethods) {
            if (pm.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE && pm.Vendor__c != NULL && pm.AP_External_Id__c == NULL) {
                String compositeKey = buildCompositeKeyForAPBankPaymentMethod(pm);
                pm.AP_External_Id__c = compositeKey;
                pm.External_Id__c = compositeKey;
            }
        }
    }

    public static String buildCompositeKeyForAPBankPaymentMethod(Payment_Method__c pm) {
        String compositeKey;
        compositeKey ='' + pm.Vendor__c + '-' + pm.Routing_Number__c.right(4) + '-' + pm.Account_Number__c.right(4);     
        return compositeKey;
    }

    public static void onlyOneDefaultPaymentMethodBefore(List<Payment_Method__c> newPaymentMethods) {
        Set<Id> customerSet = new Set<Id>();
        //set only one default PM in whole set of the new records
        for (Payment_Method__c newPM : newPaymentMethods) {
            if (!newPM.AP_Payment_Method__c) {
                if (customerSet.contains(newPM.Customer__c)){
                    newPM.Default__c = false;
                } else if (newPM.Default__c) {
                    customerSet.add(newPM.Customer__c);
                }
            }
        }
    }

    public static void onlyOneDefaultPaymentMethodAfter(List<Payment_Method__c> newPaymentMethods) {
        Set<Id> customerSet = new Set<Id>();
        //set only one default PM in whole set of the new records
        for (Payment_Method__c newPM : newPaymentMethods) {
            if (newPM.Default__c && !newPM.AP_Payment_Method__c) {
                customerSet.add(newPM.Customer__c);
            }
        }

        //check existed records and update it if there was another default PM
        if (isFirstRun) {
            Set<Id> newPMIds = (newPaymentMethods[0].Id == NULL) ? NULL : new Map<Id, Payment_Method__c>(newPaymentMethods).keySet();
            List<Payment_Method__c> existedDefaultPMs = DomainUtils.getExistedDefaultPaymentMethods(customerSet, newPMIds);

            for (Payment_Method__c existingDefaultPM : existedDefaultPMs) {
                existingDefaultPM.Default__c = false;
            }
            //Although this logic is bulkified - only one PM will be updated because there can be only one old Default PM
            PaymentMethodEditController pmEditController = new PaymentMethodEditController(existedDefaultPMs);
            pmEditController.updateOnSFSideOnly();
            isFirstRun = false;
        }
    }

    public static void onlyOneDefaultAPPaymentMethod(List<Payment_Method__c> newPaymentMethods){
        Set<Id> newPaymentVendorIds = new Set<Id>();
        List<Id> paymentMethodIds = new List<Id>();
        List<Payment_Method__c> defaultPaymentMethods = new List<Payment_Method__c>();

        for (Payment_Method__c newPaymentMethod : newPaymentMethods){
            if (newPaymentMethod.AP_Payment_Method__c && newPaymentMethod.Default__c && newPaymentMethod.Vendor__c != null){
                //If there are more than one Payment Methods being set as default in the same transaction, just keep one as default
                if (newPaymentVendorIds.contains(newPaymentMethod.Vendor__c)) {
                    newPaymentMethod.Default__c = false;
                } else {
                    newPaymentVendorIds.add(newPaymentMethod.Vendor__c);
                    defaultPaymentMethods.add(newPaymentMethod);
                }
            }
            if (newPaymentMethod.Id != null) {
                paymentMethodIds.add(newPaymentMethod.Id);
            }
        }

        if (!newPaymentVendorIds.isEmpty()){
            Map<Id, Payment_Method__c> vendorIdVsPaymentMethod = new Map<Id, Payment_Method__c>();
            for (Payment_Method__c paymentMethod : DomainUtils.getDefaultPaymentMethodByVendor(newPaymentVendorIds, paymentMethodIds)){
                vendorIdVsPaymentMethod.put(paymentMethod.Vendor__c, paymentMethod);
            }
            if (!vendorIdVsPaymentMethod.isEmpty()){
                for (Payment_Method__c newPaymentMethod : defaultPaymentMethods){
                    if (vendorIdVsPaymentMethod.containsKey(newPaymentMethod.Vendor__c)){
                        newPaymentMethod.addError(String.format(DEFAULT_PAYMENT_METHOD_ERROR, new List<String>{ vendorIdVsPaymentMethod.get(newPaymentMethod.Vendor__c).Vendor__r.Name }));
                    }
                }
            }
        }
    }

    public static void apAutomationPostMessage(List<Payment_Method__c> listOfPaymentMethods, Map<Id,Payment_Method__c> oldPaymentMethodMap)
    {
        Set<Id> vendorIds = new Set<Id>();
        List<Id> accountIdsWithUpdatedPaymentMethod = new List <Id>();
        Map<ID,Account> mapOfIdAndAccount = new Map<Id, Account>();

        for (Payment_Method__c pmRec : listOfPaymentMethods) {
            if(pmRec.AcctSeed__Vendor__c != NULL){
                vendorIds.add(pmRec.AcctSeed__Vendor__c);
            }   
        }
        
        if(!vendorIds.isEmpty()) {

            List<String> queryFields = new List<String>{
                'Id'
            };

            String queryCondition = 'ID IN :vendorIds AND AcctSeed__Enable_Payment_Services__c = true';

            SOQLBuilder theQuery = new SOQLBuilder(Account.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            mapOfIdAndAccount = new Map<Id, Account>((List<Account>) Database.query(theQuery.toSOQL()));
            
            for(Payment_Method__c pmRec : listOfPaymentMethods)
            {
                if(Trigger.isInsert) {
                    if(pmRec.Default__c && mapOfIdAndAccount.containsKey(pmRec.AcctSeed__Vendor__c)) {
                        accountIdsWithUpdatedPaymentMethod.add(pmRec.AcctSeed__Vendor__c);
                    }   
                }else if(Trigger.isUpdate){
                    UpdateControlService updateService = new UpdateControlService(new APAutomationUpdateControl(), Payment_Method__c.SObjectType);
                    if((pmRec.Default__c || (!pmRec.Default__c && oldPaymentMethodMap.get(pmRec.Id).Default__c == true))
                        && mapOfIdAndAccount.containsKey(pmRec.AcctSeed__Vendor__c) && updateService.checkUpdateFieldChanges()){ 
                            accountIdsWithUpdatedPaymentMethod.add(pmRec.AcctSeed__Vendor__c); 
                    }
                }else if(Trigger.isDelete){
                    if((pmRec.Default__c || (!pmRec.Default__c && oldPaymentMethodMap.get(pmRec.Id).Default__c == true))){
                        accountIdsWithUpdatedPaymentMethod.add(pmRec.AcctSeed__Vendor__c);
                    }
                }
            }

            if(!accountIdsWithUpdatedPaymentMethod.isEmpty()){
                APAutomationService.postMessage(accountIdsWithUpdatedPaymentMethod, APAutomationService.APAutomationActions.UPDATE_VENDOR.name());   
            }
        }        
    }

    public static void validationOnCustomerAndVendorField(List<Payment_Method__c> listOfPaymentMethods){
        if(!listOfPaymentMethods.isEmpty())
        {
            for(Payment_Method__c pmRec : listOfPaymentMethods)
            {
                if((pmRec.Customer__c != null && pmRec.Vendor__c != null)
                    || (pmRec.Customer__c == null && pmRec.Vendor__c == null)){
                        pmRec.addError(ERROR_FOR_CUSTOMER_OR_VENDOR_FIELD);
                }
            }
        }
    }
}