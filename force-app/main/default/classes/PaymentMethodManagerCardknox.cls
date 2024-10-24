/*
 * Description:
 * Class provides a means to enter a new payment method and manage existing payment methods for Cardknox payment gateway.
 */
public with sharing class PaymentMethodManagerCardknox {
    
    public class PaymentMethodManagerCardknoxException extends Exception {}
    private Payment_Method__c paymentMethod;
    public Boolean noCardknoxConnected {get; private set;}
    
    public PageReference creditCardInputs(){
        String accToken = String.escapeSingleQuotes(apexpages.currentPage().getParameters().get('cardToken'));
        String expM = String.escapeSingleQuotes(apexpages.currentPage().getParameters().get('expMonth'));
        String expY = String.escapeSingleQuotes(apexpages.currentPage().getParameters().get('expYear'));
        String name = String.escapeSingleQuotes(apexpages.currentPage().getParameters().get('holderName'));

        paymentMethod = new Payment_Method__c();

        paymentMethod.Customer__c = this.theAccount.Id;
        paymentMethod.Expiration_Month__c = getCreditCardMonth(expM);
        paymentMethod.Expiration_Year__c = getCreditCardYear(expY);
        paymentMethod.Payment_Method_Type__c = 'Credit Card';
        paymentMethod.Payment_Processor__c = this.selectedProcessor;
        paymentMethod.Card_Holder_Name__c = name;

        //call cardknox processor for creating a payment method
        try{
            PaymentGateway gtwy = new PaymentGateway();
            gtwy.createPaymentMethod(paymentMethod,accToken);
            initExistedPMs();
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.SEVERITY.CONFIRM, StripeService.PAYMENT_METHOD_CREATE_SUCCESS
            ));
        }catch(CardknoxProcessorV1.CardknoxProcessorV1Exception ex){
            String errorMessage = ex.getMessage().contains(Label.ERR_DUPLICATED_PAYMENT_METHOD) == true ?
                                    Label.ERR_DUPLICATED_PAYMENT_METHOD : ex.getMessage();
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, errorMessage));
        }catch(Exception ex){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
        return null;
    }
    @TestVisible
    // get month prefixed by 0 if user puts only 1 digit
    private String getCreditCardMonth(String expM){
        return (expM != NULL && expM.trim().length() < 2)
                    ? ('0' + expM.trim())
                    : expM.trim().subString(0,2);
    }
    @TestVisible
    // get current year prefixed if user puts less than 4 digits
    private String getCreditCardYear(String expY){
        return (expY != NULL && expY.trim().length() < 4)
                    ? (String.valueOf(System.today().year()).left(4 - expY.length()) + expY)
                    : expY.trim().subString(0,4);
    }
    public PageReference achInputs(){
        String achToken = String.escapeSingleQuotes(apexpages.currentPage().getParameters().get('achToken'));
        String routing = String.escapeSingleQuotes(apexpages.currentPage().getParameters().get('routing'));
        String name = String.escapeSingleQuotes(apexpages.currentPage().getParameters().get('name'));

        paymentMethod = new Payment_Method__c();

        paymentMethod.Customer__c = this.theAccount.Id;
        paymentMethod.Routing_Number__c = routing;
        paymentMethod.Card_Holder_Name__c = name;
        paymentMethod.Payment_Method_Type__c = 'Bank';
        paymentMethod.Payment_Processor__c = this.selectedProcessor;
        paymentMethod.Verification_Status__c = PaymentMethodActions.VERIFIED_STATUS;

        //call cardknox processor for creating a payment method
        try{
            PaymentGateway gtwy = new PaymentGateway();
            gtwy.createPaymentMethod(paymentMethod,achToken);
            initExistedPMs();
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.SEVERITY.CONFIRM, StripeService.PAYMENT_METHOD_CREATE_SUCCESS
            ));
        }catch(CardknoxProcessorV1.CardknoxProcessorV1Exception ex){
            String errorMessage = ex.getMessage().contains(Label.ERR_DUPLICATED_PAYMENT_METHOD) == true ?
                                    Label.ERR_DUPLICATED_PAYMENT_METHOD : ex.getMessage();
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, errorMessage));
        }catch(Exception ex){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        } 
        return null; 
    }
    /* Instance Variables */
    private ApexPages.StandardController controller;
    @TestVisible
    private PaymentProcessor processor;

    public Account theAccount {get; private set;}
    public String payMethodIdForChangeStatus {get; set;}
    public String payMethodIdForSetDefault {get; set;}
    public List<Payment_Method__c> ccPaymentMethods {get; set;}
    public List<Payment_Method__c> achPaymentMethods {get; set;}
    public Boolean isError {get; private set;}
    public List<SelectOption> processorOptions {get; set;}
    public Id selectedProcessor {get; set;}
    public String iFieldsKey{get; private set;}
    

    /* Constructors */
    public PaymentMethodManagerCardknox(ApexPages.StandardController controller) {
        try {
            this.controller = controller;
            //check appropriate level of access to all related entities
            checkAccess();
            theAccount = (Account) controller.getRecord();
            initExistedPMs();
            initProcessor();
            isError = false;
        }
        catch (Exception ex) {
            ccPaymentMethods =  new List<Payment_Method__c>();
            achPaymentMethods = new List<Payment_Method__c>();
            isError = true;
            ApexPages.addMessages(ex);
        }
    }

    // Initialize payment processor options and default w/ creds
    private void initProcessor() {
        processorOptions = new List<SelectOption>();
        for (Payment_Processor__c p : queryPaymentProcessors()) {
            processorOptions.add(new SelectOption(p.Id, p.Name));
        }
        selectedProcessor = processorOptions == null || processorOptions.isEmpty() 
            ? null 
            : processorOptions.get(0)?.getValue();
        if (selectedProcessor != null) {
            noCardknoxConnected = false;
            Payment_Processor__c p = DomainUtils.getPaymentProcessorById(selectedProcessor);
            if (p != null) {
                PaymentProcessorFactory ppf = new PaymentProcessorFactory();
                processor = ppf.getPaymentProcessor(p);
                iFieldsKey = getIFieldsKey(p);
            }
        } else {
            noCardknoxConnected = true;
        }
    }

    /* Instance Methods */
    private List<Payment_Method__c> queryPaymentMethods(String customerId, String pmType) {
        List<String> queryFields = new List<String>{
            'Id',
            'Customer__c',
            'Card_Holder_Name__c',
            'Type__c',
            'Bank_Account_Type__c',
            'Bank_Name__c',
            'Status__c',
            'Default__c',
            'Expiration_Month__c',
            'Expiration_Year__c',
            'Last_Four_Digits__c',
            'External_Id__c',
            'Verification_Status__c',
            'Payment_Method_Type__c',
            'CreatedDate',
            'Payment_Processor__c',
            'Payment_Processor__r.Test_Mode__c'
        };

        String queryCondition = (pmType == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE)
            ? '(Payment_Method_Type__c = :pmType OR Payment_Method_Type__c = NULL)'
            : 'Payment_Method_Type__c = :pmType';
        queryCondition += ' AND External_Use_Only__c = FALSE AND Customer__c = :customerId AND Payment_Processor__r.Type__c = \'Cardknox\'';

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Payment_Method__c', 'CreatedDate', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering);

        return (List<Payment_Method__c>) Database.query(theQuery.toSOQL());
    }

    private List<Payment_Processor__c> queryPaymentProcessors() {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'External_Key__c'
        };

        String condition = 'Active__c = TRUE AND AcctSeed__Type__c = \'Cardknox\'';

        SOQLBuilder.Ordering order = new SOQLBuilder.Ordering('Payment_Processor__c', 'CreatedDate', SOQLBuilder.SortOrder.DESCENDING);

        SOQLBuilder q = new SOQLBuilder(Payment_Processor__c.SObjectType);
        q.assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fields)
            .setCondition(condition)
            .addOrdering(order);

        return (List<Payment_Processor__c>) Database.query(q.toSOQL());
    }

    private void initExistedPMs() {
        ccPaymentMethods = queryPaymentMethods(theAccount.Id, PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE);
        achPaymentMethods = queryPaymentMethods(theAccount.Id, PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE);
    }

    public PageReference updateProcessor() {
        try{
            if (selectedProcessor != null) {
                Payment_Processor__c p = DomainUtils.getPaymentProcessorById(selectedProcessor);
                if (p != null) {
                    PaymentProcessorFactory ppf = new PaymentProcessorFactory();
                    processor = ppf.getPaymentProcessor(p);
                    iFieldsKey = getIFieldsKey(p);
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            return NULL;
        }
        return null;
    }

    /**
    * Method updates status of selected Payment Method
    * @return PageReference returns always null because action performs on the same page
    */
    public PageReference switchStatusOfPaymentMethod() {
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Status__c',
                'External_Id__c',
                'Payment_Method_Type__c',
                'Bank_Name__c',
                'Last_Four_Digits__c',
                'Expiration_Month__c',
                'Expiration_Year__c',
                'Type__c',
                'Customer__r.Stripe_Customer_Id__c'
            };
            String queryCondition = 'Id = :payMethodIdForChangeStatus LIMIT 1';

            SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            List<Payment_Method__c> paymentMethodsToSwitchStatus =
                (List<Payment_Method__c>) Database.query(theQuery.toSOQL());

            if (paymentMethodsToSwitchStatus[0].Status__c == CardknoxService.PAYMENT_METHOD_STATUS_ACTIVE) {
                paymentMethodsToSwitchStatus[0].Status__c = CardknoxService.PAYMENT_METHOD_STATUS_INACTIVE;
            }
            else if (paymentMethodsToSwitchStatus[0].Status__c == CardknoxService.PAYMENT_METHOD_STATUS_INACTIVE) {
                paymentMethodsToSwitchStatus[0].Status__c = CardknoxService.PAYMENT_METHOD_STATUS_ACTIVE;
            }

            //Update Payment Method Record in the Salesforce DB
            PaymentMethodEditController pmEditController =
                new PaymentMethodEditController(paymentMethodsToSwitchStatus[0]);
            pmEditController.updateOnSFSideOnly();
            initExistedPMs();
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            return NULL;
        }

        return NULL;
    }

    /**
    * Method marks selected Payment Method as a Default
    * @return PageReference returns always null because action performs on the same page
    */
    public PageReference setDefaultPaymentMethod() {
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Default__c',
                'External_Id__c',
                'Verification_Status__c',
                'Payment_Method_Type__c',
                'Payment_Processor__c',
                'Bank_Name__c',
                'Customer__r.Stripe_Customer_Id__c'
            };
            String queryCondition = 'Id = :payMethodIdForSetDefault LIMIT 1';

            SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            List<Payment_Method__c> paymentMethodsToSetDefault =
                (List<Payment_Method__c>) Database.query(theQuery.toSOQL());

            //Update Payment Method Record in the Salesforce DB
            paymentMethodsToSetDefault[0].Default__c = true;
            PaymentMethodEditController pmEditController =
                new PaymentMethodEditController(paymentMethodsToSetDefault[0]);
            if(paymentMethodsToSetDefault[0] != null){
                changeDefaultInCardknox(paymentMethodsToSetDefault[0]);
            }
            pmEditController.updateOnSFSideOnly();
            initExistedPMs();
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            return NULL;
        }

        return NULL;
    }
    private static void changeDefaultInCardknox(Payment_Method__c pm){
        try {
            CardknoxProcessorV1 cp = new CardknoxProcessorV1();
            pm = cp.updatePaymentMethod(pm);
        }
        catch (Exception ex) {
            throw ex;
        }
    }
    private static String getIFieldsKey(Payment_Processor__c pp){
        if(String.isBlank(pp.External_Key__c) == true){
            throw new PaymentMethodManagerCardknoxException(Label.CRDKNX_INVALID_IFIELDKEY);
        }
        Keys__c key = Keys__c.getValues(pp.External_Key__c);
        if(key == null || String.isBlank(key.Value_2__c) == true){
            throw new PaymentMethodManagerCardknoxException(Label.CRDKNX_NO_IFIELDKEY);
        }
        return key.Value_2__c;
    }
    private void checkAccess() {
        SFDCSecurityUtils.checkUpdate(Account.getSObjectType(), new List<String>{'Stripe_Customer_Id__c'});
        SFDCSecurityUtils.checkInsert(Payment_Method__c.getSObjectType(), new List<String>{
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
        });
        SFDCSecurityUtils.checkUpdate(Payment_Method__c.getSObjectType(), new List<String>{
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
        });
    }

}