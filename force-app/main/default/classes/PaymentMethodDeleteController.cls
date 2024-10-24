public with sharing class PaymentMethodDeleteController {

    private static final String WRN_NOT_CONNECTED_WITH_STRIPE_SIDE_ERROR = Label.WRN_NOT_CONNECTED_WITH_STRIPE_SIDE_ERROR;
    private static final String WRN_NOT_CONNECTED_WITH_CARDKNOX_SIDE_ERROR = Label.WRN_NOT_CONNECTED_WITH_CARDKNOX_SIDE_ERROR;
    private static final String INVALID_PAYMENT_METHOD_ID = 'Invalid xPaymentMethodID';
    private static final String MISSING_PAYMENT_METHOD_ID = 'Missing: PaymentMethodId';
    private final ApexPages.StandardController stdController;

    private Payment_Processor_Customer__c customer {get; set;}
    private Payment_Method__c paymentMethod {get; set;}

    @TestVisible
    public Boolean isDeletionAllowed {get; private set;}
    public Boolean isConnectedWithStripe {get; private set;}
    public Boolean isACH {get; set;}
    public String warnMessage {get; set;}

    public PaymentMethodDeleteController(ApexPages.StandardController stdController) {

        try {
            this.stdController = stdController;
            this.isDeletionAllowed = false;
            this.isConnectedWithStripe = true;
            this.paymentMethod = queryPaymentMethod(this.stdController.getId());
            if (paymentMethod.Payment_Method_Type__c == 'Bank Account') {
                this.isACH = true;
            }
            this.warnMessage = paymentMethod.Payment_Processor__r.Type__c == PaymentProcessorActions.CARDKNOX_TYPE 
                ? Label.WRN_PAYMENT_METHOD_DELETE_WARNING_CARDKNOX 
                : Label.WRN_PAYMENT_METHOD_DELETE_WARNING_STRIPE;
            List<Payment_Processor__c> pp = DomainUtils.getPaymentProcessorsById(new Set<Id>{this.paymentMethod.Payment_Processor__c});

            List<Payment_Processor_Customer__c> customers = DomainUtils.getPaymentProcessorCustomer(
                this.paymentMethod.Payment_Processor__c, 
                this.paymentMethod.Customer__c
            );
            this.customer = customers == null || customers.isEmpty() ? null : customers.get(0);
            if (this.customer == null || String.isBlank(this.customer.External_Id__c)
                    || String.isBlank(this.paymentMethod.External_Id__c)) {
                this.isConnectedWithStripe = false;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 
                    pp[0].Type__c == PaymentProcessorActions.CARDKNOX_TYPE ? WRN_NOT_CONNECTED_WITH_CARDKNOX_SIDE_ERROR : WRN_NOT_CONNECTED_WITH_STRIPE_SIDE_ERROR));
           }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    private Payment_Method__c queryPaymentMethod(String pmId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Customer__c',
            'Customer__r.Stripe_Customer_Id__c',
            'Type__c',
            'Card_Holder_Name__c',
            'Last_Four_Digits__c',
            'Default__c',
            'Expiration_Month__c',
            'Expiration_Year__c',
            'External_Id__c',
            'Status__c',
            'Bank_Account_Type__c',
            'Bank_Name__c',
            'Payment_Method_Type__c',
            'Verification_Status__c',
            'Payment_Processor__c',
            'Payment_Processor__r.Type__c'
        };
        String queryCondition = 'Id = :pmId';

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Payment_Method__c) Database.query(theQuery.toSOQL());
    }

    private void deleteCorrespondingEntryFromExternalSystem() {
        PaymentGateway gtwy = new PaymentGateway();
        gtwy.deletePaymentMethod(this.paymentMethod);
    }

    //Used on the VF page
    public PageReference deleteViaUI() {
        PageReference pr = new PageReference('/' + ((Payment_Method__c)stdController.getRecord()).Customer__c);        
        try {
            isDeletionAllowed = true;
            PaymentMethodActions.deleteController = this;
            deleteCorrespondingEntryFromExternalSystem();
        }
        catch (StripeService.StripeServiceException stripeEx) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, WRN_NOT_CONNECTED_WITH_STRIPE_SIDE_ERROR));
            isConnectedWithStripe = false;
            return NULL;
        }
        catch (CardknoxService.CardknoxServiceException crdknxEx) {
            String errorMessage = crdknxEx.getMessage().contains(INVALID_PAYMENT_METHOD_ID) || crdknxEx.getMessage().contains(MISSING_PAYMENT_METHOD_ID) ? 
                                WRN_NOT_CONNECTED_WITH_CARDKNOX_SIDE_ERROR : 
                                crdknxEx.getMessage() + ' '+ Label.ERR_FORCE_DELETE_PAYMENT_METHOD_FROM_SALESFORCE_NOT_FROM_CARDKNOX;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, errorMessage));
            isConnectedWithStripe = false;
            return NULL;
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, ex.getMessage()));
            isConnectedWithStripe = false;
            return NULL;
        }

        return pr;
    }

    public PageReference forceDelete() {
        PageReference pr = new PageReference('/' + ((Payment_Method__c)stdController.getRecord()).Customer__c);        
        try {
            isDeletionAllowed = true;
            PaymentMethodActions.deleteController = this;
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(stdController.getRecord());
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, ex.getMessage()));
            return NULL;
        }

        return pr;
    }

    //Used from Apex code without UI
    public OperationResult deleteViaAPI() {
        OperationResult result;
        try {
            isDeletionAllowed = true;
            PaymentMethodActions.deleteController = this;
            deleteCorrespondingEntryFromExternalSystem();
            result = new OperationResult(true, NULL);
        }
        catch (Exception ex) {
            result = new OperationResult(false, ex.getMessage());
        }

        return result;
    }

    public with sharing class OperationResult {
        public Boolean status;
        public String message;

        public OperationResult(Boolean status, String message) {
            this.status = status;
            this.message = message;
        }
    }

}