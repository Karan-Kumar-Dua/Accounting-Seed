public with sharing class PaymentMethodEditController {

    public static final String UPDATE_SUCCESS = Label.INF_PAYMENT_METHOD_UPDATE_SUCCESS;
    private final ApexPages.StandardController stdController;

    private Account customer {get; set;}
    private Payment_Method__c pmSnapshot;

    public Payment_Method__c paymentMethod {get; set;}
    public List<Payment_Method__c> paymentMethods {get; set;}
    public Boolean isACH {get; set;}
    public Boolean isVerified {get; set;}
    public Boolean isSaveable {get; set;}
    public String selectedBankAccountType {get; set;}

    public Boolean isUpdateAllowed {get; private set;}

    //Constructor
    //to update Payment Method Record(s) only on the SF side
    public PaymentMethodEditController(List<Payment_Method__c> paymentMethods) {
        this.paymentMethods = paymentMethods;
        this.isUpdateAllowed = false;
        this.isSaveable = true;
    }

    public PaymentMethodEditController(Payment_Method__c paymentMethod) {
        this.paymentMethods = new List<Payment_Method__c>{paymentMethod};
        this.isUpdateAllowed = false;
        this.isSaveable = true;
    }

    //Constructor
    //to update Payment Method Record on both sides (SF & Stripe)
    public PaymentMethodEditController(ApexPages.StandardController stdController) {
        try {
            this.stdController = stdController;
            this.isUpdateAllowed = false;
            this.isACH = false;
            this.isVerified = true;
            this.isSaveable = true;

            paymentMethod = queryPaymentMethod(stdController.getId());
            if (paymentMethod.External_Use_Only__c) {
                this.isSaveable = false;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, Label.ERR_EXTERNALUSE_PAYMENT_METHOD));
            }
            if (paymentMethod.Payment_Method_Type__c == 'Bank Account') {
                this.isACH = true;
                this.isVerified = (paymentMethod.Verification_Status__c == 'verified') ? true : false;
                this.selectedBankAccountType = paymentMethod.Bank_Account_Type__c;
            }
            pmSnapshot = paymentMethod.clone(false, true, false, false);
            this.customer = new Account(
                Id = paymentMethod.Customer__c,
                Stripe_Customer_Id__c = paymentMethod.Customer__r.Stripe_Customer_Id__c
            );
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    public List<SelectOption> getBankAccountTypes() {
        return new List<SelectOption>{
            new SelectOption('Individual', Label.COMMON_INDIVIDUAL),
            new SelectOption('Business', Label.COMMON_BUSINESS)
        };
    }

    private void updateCorrespondingEntryFromExternalSystem() {
        try {
            Boolean isChanged = false;

            if (isACH) {
                // change in ACH data
                isChanged = (
                    paymentMethod.Card_Holder_Name__c != pmSnapshot.Card_Holder_Name__c 
                    || paymentMethod.Bank_Account_Type__c != pmSnapshot.Bank_Account_Type__c
                );
            }
            else {
                // change in card data
                isChanged = (
                    paymentMethod.Card_Holder_Name__c != pmSnapshot.Card_Holder_Name__c
                    || paymentMethod.Expiration_Month__c != pmSnapshot.Expiration_Month__c
                    || paymentMethod.Expiration_Year__c != pmSnapshot.Expiration_Year__c
                );
            }

            // change in general data
            isChanged = isChanged || (
                paymentMethod.Status__c != pmSnapshot.Status__c
                || paymentMethod.Default__c != pmSnapshot.Default__c
            );

            if (isChanged) {
                PaymentGateway gtwy = new PaymentGateway();
                gtwy.updatePaymentMethod(paymentMethod);
                paymentMethod = queryPaymentMethod(stdController.getId());
                pmSnapshot = paymentMethod.clone(false, true, false, false);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    public PageReference updateViaUI() {
        try {
            if (isACH) {
                paymentMethod.Bank_Account_Type__c = selectedBankAccountType;
            }
            if (String.isNotBlank(paymentMethod.Expiration_Month__c)) {
                String month = paymentMethod.Expiration_Month__c.trim();
                month = month.length() >= 2 ? month.right(2) : month.leftPad(2,'0');
                paymentMethod.Expiration_Month__c = month;
            }
            if (String.isNotBlank(paymentMethod.Expiration_Year__c)) {
                String year = paymentMethod.Expiration_Year__c.trim(); 
                year = year.length() == 2 ? String.valueOf(System.today().year()).left(2) + year : year;
                paymentMethod.Expiration_Year__c = year;
            }
            updateCorrespondingEntryFromExternalSystem();
            isUpdateAllowed = true;
            PaymentMethodActions.editController = this;

            // Check sobject accessibility;
            // all fields to be updated bound to input field elements on VF page;
            // FLS is handled by VF page.
            SFDCSecurityUtils.updateCheckCRUDAndFLS(paymentMethod, new String[]{});

            pmSnapshot = paymentMethod.clone(false, true, false, false);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM,  
                            String.format(UPDATE_SUCCESS, new List<String>{
                                paymentMethod.Payment_Processor__r.Type__c == PaymentProcessorActions.CARDKNOX_TYPE ?
                                PaymentProcessorActions.CARDKNOX_TYPE : 
                                PaymentProcessorActions.STRIPE_TYPE
                            })));
        }
        catch (StripeService.StripeServiceException stripeEx) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, stripeEx.getMessage()));
            return NULL;
        }
        catch (Exception ex) {
            rollBackChangesOnStripeSide((String) paymentMethod.Id, isACH);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
            return NULL;
        }
        return NULL;
    }

    public void updateOnSFSideOnly() {
        isUpdateAllowed = true;
        PaymentMethodActions.editController = this;
        try {
            SFDCSecurityUtils.updateProxy(paymentMethods);
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    @Future(callout=true)
    private static void rollBackChangesOnStripeSide(String pmId, Boolean isACH) {
        Payment_Method__c rolledBackPaymentMethod = queryPaymentMethod(pmId);
        PaymentGateway gtwy = new PaymentGateway();
        gtwy.updatePaymentMethod(rolledBackPaymentMethod);
    }

    private static Payment_Method__c queryPaymentMethod(Id paymentMethodId) {
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
            'Payment_Processor__r.Type__c',
            'External_Use_Only__c'
        };

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
        String queryCondition = 'Id = :paymentMethodId';
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Payment_Method__c) Database.query(theQuery.toSOQL());
    }
}