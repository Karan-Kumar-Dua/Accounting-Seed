public inherited sharing class PaymentProcessorActions {

    public static final String STRIPE_TYPE = 'Stripe';
    public static final String CARDKNOX_TYPE = 'Cardknox';
    public static final String EDENRED_TYPE = 'Edenred';
    public static final String CC_PERCENT = 'CC Percent';
    public static final String CC_FLAT_FEE = 'CC Flat Fee';
    public static final String ACH_PERCENT = 'ACH Percent';
    public static final String ACH_FLAT_FEE = 'ACH Flat Fee';
    
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Map<SObjectField, Integer> CURRENCY_AND_NUMBER_FIELDS = new Map<SObjectField, Integer> {
        Payment_Processor__c.CC_Percent__c => 2,
        Payment_Processor__c.CC_Flat_Fee__c => 2,
        Payment_Processor__c.ACH_Flat_Fee__c => 2,
        Payment_Processor__c.ACH_Percent__c => 2
    };
   
   // test mode can't be changed after connected account token is set
    public static void validateTestMode(List<Payment_Processor__c> procsNew, Map<Id,Payment_Processor__c> procsOld) {
        Payment_Processor__c pOld;
        for (Payment_Processor__c pNew : procsNew) {
            pOld = procsOld.get(pNew.Id);
            if (String.isNotBlank(pOld.Connected_Account_Token__c) && pOld.Test_Mode__c != pNew.Test_Mode__c) {
                pNew.Test_Mode__c.addError(Label.ERR_PAYMENTS_PROC_TEST_MODE_LOCKED);
            }
        }
    }

    public static void validateLedgerAndActiveField(List<Payment_Processor__c> procs){
        for(Payment_Processor__c pros : procs){
            if(String.isBlank(pros.Connected_Account_Token__c) && pros.Type__c == STRIPE_TYPE && pros.Active__c == true){
                pros.Active__c.addError(Label.ERR_PAYMENTS_CAN_NO_LONGER_ACTIVE);
            }else if(pros.Type__c == CARDKNOX_TYPE && pros.Active__c == true){
                Keys__c userKeys = Keys__c.getValues(pros.External_Key__c);
                if(userKeys == null || String.isBlank(userKeys.Value_1__c) || String.isBlank(userKeys.Value_2__c)){
                    pros.Type__c.addError(Label.ERR_CRDNX_IFIELDS_XKEY_REQUIRED);                 
                }
            }
        }
    }

    public static void validateDefaultPaymentProcessors(List<Payment_Processor__c> procs){
        Id defaultProcessor = PaymentGateway.getDefaultPaymentProcessorId();
        for(Payment_Processor__c pros : procs){
            if((pros.Global_Default_Payment_Processor__c == true && pros.Id != defaultProcessor)
                || (pros.Global_Default_Payment_Processor__c == false && pros.Id == defaultProcessor)){
                pros.Global_Default_Payment_Processor__c.addError(Label.ERR_PAYMENTS_CAN_NOT_GLOBAL_DEFAULT);
            }
        }
    }
    public static void deleteRelatedKeys(List<Payment_Processor__c> procs){
        List<Keys__c> keys = new List<Keys__c>();

        for(Payment_Processor__c pros : procs){
            Keys__c userKeys = Keys__c.getValues(pros.External_Key__c);
            if(userKeys != null){
                keys.add(userKeys);
            }
        }

        if(keys.size() != 0){
            SFDCSecurityUtils.deleteProxy(keys);
        }
    }

    public static void defaultExternalKey(List<Payment_Processor__c> procs){
        for(Payment_Processor__c pros : procs){
            pros.External_Key__c = FinancialSuiteUtils.getUUIDNoTestCheck();
        }
    }
    public static void preventInsertWhenExternalKeyNotEmpty(List<Payment_Processor__c> procs){
        for(Payment_Processor__c pros : procs){
            if(!String.isBlank(pros.External_Key__c)){
                pros.External_Key__c.addError(String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR,new List<String>{
                    Payment_Processor__c.External_Key__c.getDescribe().getLabel()
                }));
            }
        }
    }
    public static void validateLedgerField(List<Payment_Processor__c> procs){
        for(Payment_Processor__c pros : procs){
            if(pros.Type__c == CARDKNOX_TYPE && pros.Default_Ledger__c == null){
                pros.Default_Ledger__c.addError(String.format(Label.ERR_FIELD_VALUE_MISSING, new List<String> {
                    Payment_Processor__c.Default_Ledger__c.getDescribe().getLabel()
                }));
            }
        }
    }

    public static void validateGLAccounts(List<Payment_Processor__c> processors){ 
        for (Payment_Processor__c processor : processors) {
            if (processor.Type__c == CARDKNOX_TYPE) {
                // for cardknox type processors
                if (processor.Bank_GL_Account__c == null) {
                    // required field
                    processor.Bank_GL_Account__c.addError(String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_RQUIRED_FIELD, new List<String> {
                        Payment_Processor__c.Bank_GL_Account__c.getDescribe().getLabel()
                    }));
                } 
                if (processor.Merchant_GL_Account__c == null) {
                    // required field
                    processor.Merchant_GL_Account__c.addError(String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_RQUIRED_FIELD, new List<String> {
                        Payment_Processor__c.Merchant_GL_Account__c.getDescribe().getLabel()
                    }));
                } 
                if (processor.Merchant_Fees_GL_Account__c == null) {
                    // requried field
                    processor.Merchant_Fees_GL_Account__c.addError(String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_RQUIRED_FIELD, new List<String> {
                        Payment_Processor__c.Merchant_Fees_GL_Account__c.getDescribe().getLabel()
                    }));
                }
                if (processor.Bank_GL_Account__c != null && (processor.Bank_GL_Account__c == processor.Merchant_GL_Account__c)) {
                    // bank and merchant accounts can't use the same GL account
                    processor.addError(String.format(Label.ERR_CARDKNOX_PMT_PROCESSOR_BANK_MATCHES_MERCHANT, new List<String> {
                        Payment_Processor__c.Bank_GL_Account__c.getDescribe().getLabel(),
                        Payment_Processor__c.Merchant_GL_Account__c.getDescribe().getLabel()
                    }));
                }
            }
        }
    }

    public static void validateFeeSetup(List<Payment_Processor__c> processors){
        for (Payment_Processor__c p : processors) {
            if (p.Type__c == CARDKNOX_TYPE && p.Enable_Convenience_Fees__c) {
                if (p.Convenience_Fees_GL_Account__c == null) {
                    p.Convenience_Fees_GL_Account__c.addError(Label.ERR_PAYMENT_PROCESSOR_REQUIRED_FOR_FEES);
                }
                if (p.Convenience_Fee_Mapping__c == null) {
                    p.Convenience_Fee_Mapping__c.addError(Label.ERR_PAYMENT_PROCESSOR_REQUIRED_FOR_FEES);
                }
                if (p.Original_Amount_Mapping__c == null) {
                    p.Original_Amount_Mapping__c.addError(Label.ERR_PAYMENT_PROCESSOR_REQUIRED_FOR_FEES);
                }
                if (p.Convenience_Fee_Mapping__c != null && p.Convenience_Fee_Mapping__c == p.Original_Amount_Mapping__c) {
                    p.Convenience_Fee_Mapping__c.addError(Label.ERR_PAYMENT_PROCESSOR_DUPLICATE_FIELD_MAPPING);
                    p.Original_Amount_Mapping__c.addError(Label.ERR_PAYMENT_PROCESSOR_DUPLICATE_FIELD_MAPPING);
                }
            }
        }
    }

    public static void validateFeeMapping(List<Payment_Processor__c> procsNew, Map<Id,Payment_Processor__c> procsOld){
        Payment_Processor__c pOld;
        for (Payment_Processor__c pNew : procsNew) {
            pOld = procsOld.get(pNew.Id);

            if (pOld.Convenience_Fee_Mapping__c != null && pNew.Convenience_Fee_Mapping__c == null) {
                pNew.Convenience_Fee_Mapping__c.addError(Label.ERR_REQUIRED_FIELD);
            }
            if (pOld.Original_Amount_Mapping__c != null && pNew.Original_Amount_Mapping__c == null) {
                pNew.Original_Amount_Mapping__c.addError(Label.ERR_REQUIRED_FIELD);
            }
        }
    }

}