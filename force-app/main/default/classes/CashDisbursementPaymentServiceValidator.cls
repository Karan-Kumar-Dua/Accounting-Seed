public with sharing class CashDisbursementPaymentServiceValidator {
    
    public static List<SObject> sourceRecords = new List<SObject>();
    private static final String AS_PAY_TYPE = 'AS Pay';
    private static final String PAYMENT_SERVICE_VCARD_TYPE = 'Virtual Card';
    private static final String PAYMENT_SERVICE_CHECK_TYPE = 'Check';
    private static final String PAYMENT_SERVICE_ACH_TYPE = 'ACH';
    private static final String ACTIVE_STATUS_OF_PAYMENT_METHOD = 'Active';
    private static final String VERIFICATION_STATUS_OF_PAYMENT_METHOD = 'Active';
    

    private static final String VENDOR_BILLING_ADDRESS_BLANK_FOR_CHECK_PAYMENT_SERVICE = Label.ERR_CD_VENDOR_BILLING_ADDRESS_BLANK_FOR_CHECK_PAYMENT_SERVICE;
    private static final String AP_REMITTANCE_EMAIL_BLANK_FOR_VCARD_PAYMENT_SERVICE = Label.ERR_AP_REMITTANCE_EMAIL_BLANK_FOR_VCARD_PAYMENT_SERVICE;
    private static final String NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE = Label.ERR_CD_NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE;
    private static final String CD_CANNOT_BE_POSTED_FOR_CONTACT_OR_EMPLOYEE = Label.ERR_CD_CANNOT_BE_POSTED_FOR_CONTACT_OR_EMPLOYEE;
    private static final String REQUIRED_BANK_ACC_ERROR_MSG = Label.ERR_REQUIRED_APPROVED_BANK_ACC_ON_GLACCOUNT_OF_CD;
    private static final String CD_CANNOT_POST_CURRENCY_NOT_EQUALS_USD = Label.ERR_CD_CANNOT_POST_CURRENCY_NOT_EQUALS_USD;
    private static final String ERROR_LEDGER_NOT_ENROLLED = Label.ERROR_LEDGER_NOT_ENROLLED;
    private static final String CD_BALANCE_MUST_BE_ZERO = Label.CD_BALANCE_MUST_BE_ZERO_BEFORE_POSTING;
    private static final String CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_SERVICE_INACTIVE = Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_SERVICE_INACTIVE;
    private static final String ERR_DEFAULT_PAYMENT_METHOD_VERIFICATION_STATUS_NOT_ACTIVE = Label.CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_METHOD_VERIFICATION_STATUS_IS_NOT_ACTIVE;

   
    public static List<SObject> validatePaymentServiceFields(Boolean fullStatistics, List<SObject> cashDisbursementRecords, PostResultDispatcher dispatcher){
        sourceRecords = cashDisbursementRecords;
        validateASPayRelatedFields(fullStatistics,dispatcher);
        validateFieldsForACHPaymentService(fullStatistics,dispatcher); 
        return sourceRecords;
    }

    private static void validateASPayRelatedFields(Boolean fullStatistics, PostResultDispatcher dispatcher){
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();

        String defaultCorporateCurrency = MultiCurrencyHandler.CORPORATE_CURRENCY;
        Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        
        for(Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords) {
            Boolean isValidRecord = true;
            String cdCurrencyISOCode = isMultiCurrencyEnabled ? (String) cashDisbursement.get('CurrencyIsoCode') : null;
            if(cashDisbursement.Type__c == AS_PAY_TYPE){
                
                if((cashDisbursement.AcctSeed__Bank_Account__r.AcctSeed__Bank_Account__c) != NULL && 
                ((cashDisbursement.AcctSeed__Bank_Account__r.AcctSeed__Bank_Account__r.AcctSeed__Payment_Services_Enrollment_Status__c != 'Enrolled') ||
                (cashDisbursement.AcctSeed__Bank_Account__r.AcctSeed__Bank_Account__r.AcctSeed__Enable_for_Payment_Services__c == false))){

                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement, PostResult.StatusCode.RELATED_BANK_ACCOUNT_NOT_APPROVED_FOR_AS_PAY,
                    String.format(REQUIRED_BANK_ACC_ERROR_MSG, new List<String>{String.valueOf(cashDisbursement.AcctSeed__Bank_Account__r.Name)}), dispatcher);
                }
                
                if(cashDisbursement.Ledger__c != NULL && 
                (cashDisbursement.Ledger__r.Enrolled_in_Payment_Services__c == false || String.IsBlank(cashDisbursement.Ledger__r.Payment_Services_Company_Code__c))
                ){
                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement, PostResult.StatusCode.LEDGER_NOT_ENROLLED,
                    String.format(ERROR_LEDGER_NOT_ENROLLED, new List<String>{String.valueOf(cashDisbursement.Ledger__r.Name)}), dispatcher);
                }
                
                if(cashDisbursement.AcctSeed__Vendor__c != NULL && (cashDisbursement.AS_Pay_Type__c == PAYMENT_SERVICE_VCARD_TYPE || (cashDisbursement.AS_Pay_Type__c == NULL && cashDisbursement.AcctSeed__Vendor__r.AS_Pay_Type__c == PAYMENT_SERVICE_VCARD_TYPE))
                    && String.IsBlank(cashDisbursement.AcctSeed__Vendor__r.AP_Remittance_Email__c)
                ){	
                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement, PostResult.StatusCode.AP_REMITTANCE_EMAIL_BLANK_ON_VENDOR,
                    String.format(AP_REMITTANCE_EMAIL_BLANK_FOR_VCARD_PAYMENT_SERVICE, new List<String>{String.valueOf(cashDisbursement.AcctSeed__Vendor__r.Name)}), dispatcher);
                }
                
                if(cashDisbursement.AcctSeed__Vendor__c != NULL && 
                (cashDisbursement.AS_Pay_Type__c == PAYMENT_SERVICE_CHECK_TYPE || (cashDisbursement.AS_Pay_Type__c == NULL && cashDisbursement.AcctSeed__Vendor__r.AS_Pay_Type__c == PAYMENT_SERVICE_CHECK_TYPE)) &&  
                (String.IsBlank(cashDisbursement.AcctSeed__Vendor__r.BillingStreet) || 
                String.IsBlank(cashDisbursement.AcctSeed__Vendor__r.BillingCity) || 
                String.IsBlank(cashDisbursement.AcctSeed__Vendor__r.BillingPostalCode) || 
                String.IsBlank(cashDisbursement.AcctSeed__Vendor__r.BillingState) || 
                String.IsBlank(cashDisbursement.AcctSeed__Vendor__r.BillingCountry))){
                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement, PostResult.StatusCode.NO_BILLING_ADDRESS_ON_VENDOR_FOR_CHECK_PAYMENT_SERVICE,
                    String.format(VENDOR_BILLING_ADDRESS_BLANK_FOR_CHECK_PAYMENT_SERVICE, new List<String>{String.valueOf(cashDisbursement.AcctSeed__Vendor__r.Name)}), dispatcher);
                }
                
                if(((isMultiCurrencyEnabled && String.isNotBlank(cdCurrencyISOCode) && cdCurrencyISOCode != 'USD') ||
                    (isMultiCurrencyEnabled == false && defaultCorporateCurrency != 'USD')) 
                    )
                {
                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement, PostResult.StatusCode.CD_CURRENCY_NOT_USD, CD_CANNOT_POST_CURRENCY_NOT_EQUALS_USD, dispatcher);
                }
                
                if(cashDisbursement.Employee__c != NULL || cashDisbursement.Contact__c != NULL){
                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement, PostResult.StatusCode.CANT_PAY_CONTACT_OR_EMPLOYEE_FOR_TYPE_PAYMENT_SERVICE, 
                    CD_CANNOT_BE_POSTED_FOR_CONTACT_OR_EMPLOYEE, dispatcher);
                }

                if(cashDisbursement.Balance__c > 0)
                {             
                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement, PostResult.StatusCode.CASH_DISBUREMENT_BALANCE_MUST_BE_ZERO, CD_BALANCE_MUST_BE_ZERO, dispatcher);
                }
            }

            if(isValidRecord){
                validCashDisbursements.add(cashDisbursement);
            }
        }
        
        if(!fullStatistics){
            sourceRecords = validCashDisbursements;
        }
    }

    private static void throwErrorMessage(Cash_Disbursement__c cashDisbursement, PostResult.StatusCode postResultStatusCode,String errorMessage,PostResultDispatcher dispatcher){
        dispatcher.addPostErrorResult(
            cashDisbursement,
            new PostResult.PostErrorResult(
                cashDisbursement,
                postResultStatusCode,
                errorMessage
            )
        );
    }

    //Validations related to ACH Payment Service
    private static void validateFieldsForACHPaymentService(Boolean fullStatistics, PostResultDispatcher dispatcher) {
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();
        List<Payment_Method__c> listOfPaymentMethods = new List<Payment_Method__c>();
        Map<Id,List<Payment_Method__c>> mapOfVendorIdAndPaymentMethods = new Map<Id,List<Payment_Method__c>>();
        Set<Id> setOfVendorIds = new Set<Id>();
        Set<Id> setOfACHTypeVendorsIds = new Set<Id>();
        Map<Id,Account> mapOfVendorIdAndDetail = new Map<Id,Account>();

        for(Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords){
            if(cashDisbursement.Type__c == AS_PAY_TYPE && cashDisbursement.AcctSeed__Vendor__c != NULL){
                setOfVendorIds.add(cashDisbursement.AcctSeed__Vendor__c);
                if(String.isBlank(cashDisbursement.AS_Pay_Type__c)){
                    setOfACHTypeVendorsIds.add(cashDisbursement.AcctSeed__Vendor__c);
                }
            }
        }
        
        if(!setOfACHTypeVendorsIds.isEmpty()){
            mapOfVendorIdAndDetail = new Map<Id, Account>(queryVendors(setOfACHTypeVendorsIds));
        }
       
        if(!setOfVendorIds.isEmpty()){
            listOfPaymentMethods = (List<Payment_Method__c>) queryPaymentMethods(setOfVendorIds);
            for(Payment_Method__c paymentMethodRec : listOfPaymentMethods){
                if(mapOfVendorIdAndPaymentMethods.containsKey(paymentMethodRec.Vendor__c)){
                    mapOfVendorIdAndPaymentMethods.get(paymentMethodRec.Vendor__c).add(paymentMethodRec);
                }else{
                    mapOfVendorIdAndPaymentMethods.put(paymentMethodRec.Vendor__c, new List<Payment_Method__c>{paymentMethodRec});
                }   
            }
        }

        for(Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords) {
            Boolean isValidRecord = true;

            if(cashDisbursement.Vendor__c != NULL && 
                (cashDisbursement.AS_Pay_Type__c == PAYMENT_SERVICE_ACH_TYPE || 
                (cashDisbursement.AS_Pay_Type__c ==  NULL && mapOfVendorIdAndDetail.containsKey(cashDisbursement.Vendor__c) && 
                mapOfVendorIdAndDetail.get(cashDisbursement.Vendor__c).AS_Pay_Type__c == PAYMENT_SERVICE_ACH_TYPE))){

                if(!mapOfVendorIdAndPaymentMethods.containsKey(cashDisbursement.Vendor__c)){
                    isValidRecord = false;
                    throwErrorMessage(cashDisbursement,PostResult.StatusCode.NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE,
                    String.format(NO_DEFAULT_PAYMENT_METHOD_ON_VENDOR_FOR_ACH_PAYMENT_SERVICE, new List<String>{String.valueOf(cashDisbursement.AcctSeed__Vendor__r.Name)}),dispatcher);
                }else if((mapOfVendorIdAndPaymentMethods.containsKey(cashDisbursement.Vendor__c)) && 
                    (mapOfVendorIdAndPaymentMethods.get(cashDisbursement.Vendor__c))[0].Status__c != ACTIVE_STATUS_OF_PAYMENT_METHOD){
                        isValidRecord = false;
                        throwErrorMessage(cashDisbursement, PostResult.StatusCode.INACTIVE_DEFAULT_PAYMENT_METHOD,
                        CD_CANNOT_BE_POSTED_DEFAULT_PAYMENT_SERVICE_INACTIVE,dispatcher);
                }else if((mapOfVendorIdAndPaymentMethods.containsKey(cashDisbursement.Vendor__c)) && 
                    (mapOfVendorIdAndPaymentMethods.get(cashDisbursement.Vendor__c))[0].Verification_Status__c != VERIFICATION_STATUS_OF_PAYMENT_METHOD){
                        isValidRecord = false;
                        throwErrorMessage(cashDisbursement, PostResult.StatusCode.INACTIVE_VERIFICATION_STATUS_PAYMENT_METHOD,
                            ERR_DEFAULT_PAYMENT_METHOD_VERIFICATION_STATUS_NOT_ACTIVE,dispatcher);
                }else if(mapOfVendorIdAndPaymentMethods.containsKey(cashDisbursement.Vendor__c)){                
                    //there will only be one default for each vendor
                    cashDisbursement.Payment_Method__c = mapOfVendorIdAndPaymentMethods.get(cashDisbursement.Vendor__c)[0].Id;
                }
            }
            

            if(isValidRecord) {
                validCashDisbursements.add(cashDisbursement);
            }
        }   

        if(!fullStatistics){
            sourceRecords = validCashDisbursements;
        }
    } 

    //Query Payment Method Records
    private static List<Payment_Method__c> queryPaymentMethods(Set<Id> listOfVendorIds) {
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Default__c',
            'Routing_Number__c',
            'Account_Number__c',
            'Vendor__c',
            'Status__c',
            'Verification_Status__c'
        };

        String queryCondition = 'Vendor__c IN :listOfVendorIds AND Default__c = true AND Routing_Number__c != NULL AND Account_Number__c != NULL';
       
        SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }

    private static List<Account> queryVendors(Set<Id> listOfVendorIds) {
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'AS_Pay_Type__c'
        };

        String queryCondition = 'Id IN :listOfVendorIds AND AS_Pay_Type__c = \'ACH\'';
       
        SOQLBuilder theQuery = new SOQLBuilder(Account.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }

}