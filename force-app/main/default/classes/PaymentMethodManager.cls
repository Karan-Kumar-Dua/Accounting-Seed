/*
 * Description:
 * Class provides a means to enter a new payment method and manage existing payment methods for Stripe payment gateway.
 */
public with sharing class PaymentMethodManager {

    /* Constants */
    public static String CONFIRMATION_QUESTION {
        get {
            return Label.CONFIRM_PMT_PROCESSOR_STATUS_CHANGE;
        }
    }

    /* Instance Variables */
    private ApexPages.StandardController controller;
    @TestVisible
    private PaymentGateway gtwy;

    public Account theAccount {get; private set;}
    public String platformPublishableKey {get; set;}
    public String serializedStripeSourceToken {get; set;}
    public StripeService.StripeSourceToken sToken {get; set;}
    public String payMethodIdForChangeStatus {get; set;}
    public String payMethodIdForSetDefault {get; set;}
    public String payMethodIdToVerify {get; set;}
    public Integer firstDeposit {get; set;}
    public Integer secondDeposit {get; set;}
    public List<Payment_Method__c> ccPaymentMethods {get; set;}
    public List<Payment_Method__c> achPaymentMethods {get; set;}
    public Boolean noStripeConnectedId {get; private set;}
    public String stripeConnectedId {get; private set;}
    public Boolean isError {get; private set;}
    public List<SelectOption> processorOptions {get; set;}
    public Id selectedProcessor {get; set;}
    

    /* Constructors */
    public PaymentMethodManager(ApexPages.StandardController controller) {
        try {
            this.controller = controller;
            //check appropriate level of access to all related entities
            checkAccess();
            this.theAccount = (Account) controller.getRecord();
            initExistedPMs();
            initProcessor();
            this.gtwy = new PaymentGateway();
            this.isError = false;
        }
        catch (Exception ex) {
            this.ccPaymentMethods =  new List<Payment_Method__c>();
            this.achPaymentMethods = new List<Payment_Method__c>();
            this.isError = true;
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
            Payment_Processor__c p = DomainUtils.getPaymentProcessorById(selectedProcessor);
            // stripe connected account id (customer account)
            stripeConnectedId = p?.Connected_Account_Token__c;
            noStripeConnectedId = String.isBlank(stripeConnectedId);
            // stripe connect account key (AS account)
            platformPublishableKey = p?.Test_Mode__c
                    ? StripeService.TEST_PLATFORM_PUBLISHABLE_KEY
                    : StripeService.PLATFORM_PUBLISHABLE_KEY;
        } else {
            noStripeConnectedId = true;
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
            ? 'Customer__c = :customerId AND Payment_Processor__r.Type__c = \'Stripe\' AND (Payment_Method_Type__c = :pmType OR Payment_Method_Type__c = NULL) ORDER BY CreatedDate ASC'
            : 'Customer__c = :customerId AND Payment_Processor__r.Type__c = \'Stripe\' AND Payment_Method_Type__c = :pmType ORDER BY CreatedDate ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Payment_Method__c>) Database.query(theQuery.toSOQL());
    }

    private List<Payment_Processor__c> queryPaymentProcessors() {
        List<String> fields = new List<String>{
            'Id',
            'Name'
        };

        String condition = 'Active__c = TRUE AND AcctSeed__Type__c = \'Stripe\'';

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
        if (selectedProcessor != null) {
            Payment_Processor__c p = DomainUtils.getPaymentProcessorById(selectedProcessor);
            stripeConnectedId = p?.Connected_Account_Token__c;
            noStripeConnectedId = String.isBlank(stripeConnectedId);
            platformPublishableKey = p?.Test_Mode__c
                    ? StripeService.TEST_PLATFORM_PUBLISHABLE_KEY
                    : StripeService.PLATFORM_PUBLISHABLE_KEY;
        }
        return null;
    }

    /**
    * Method determines create Card/Bank Account or Customer + Card/Bank Account
    * @return PageReference returns always null because action performs on the same page
    */
    public PageReference createPaymentMethod() {
        try {
            if (String.isBlank(selectedProcessor)) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR, Label.ERR_SELECT_PMT_PROCESSOR
                    )
                );
                return null;
            }

            sToken = (StripeService.StripeSourceToken) JSON.deserialize(
                serializedStripeSourceToken, StripeService.StripeSourceToken.class);

            Payment_Method__c pm = new Payment_Method__c(
                Customer__c = theAccount.Id,
                Payment_Processor__c = selectedProcessor,
                Type__c = sToken.type == 'card' ? sToken.card.brand : null,
                Expiration_Month__c = sToken.type == 'card' 
                    ? String.valueOf(sToken.card.exp_month).length() < 2
                        ? '0' + String.valueOf(sToken.card.exp_month)
                        : String.valueOf(sToken.card.exp_month)
                    : null,
                Expiration_Year__c = sToken.type == 'card' ? String.valueOf(sToken.card.exp_year) : null,
                Last_Four_Digits__c = sToken.type == 'card' 
                    ? sToken.card.last4 
                    : (sToken.type == 'bank_account' ? sToken.bank_account.last4 : null),
                Payment_Method_Type__c = sToken.type == 'card'
                    ? PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE 
                    : PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE,
                Bank_Name__c = sToken.type == 'bank_account' ? sToken.bank_account.bank_name : null
            );

            gtwy.createPaymentMethod(pm, sToken.id);
            
            initExistedPMs();
            
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.SEVERITY.CONFIRM, StripeService.PAYMENT_METHOD_CREATE_SUCCESS
            ));
        }
        catch (PaymentGateway.PaymentGatewayException ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
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
                'Status__c'
            };
            String queryCondition = 'Id = :payMethodIdForChangeStatus LIMIT 1';

            SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            List<Payment_Method__c> pmtMethods =
                (List<Payment_Method__c>) Database.query(theQuery.toSOQL());

            Payment_Method__c pmtMethod = pmtMethods == null || pmtMethods.isEmpty() ? null : pmtMethods.get(0);

            if (pmtMethod.Status__c == PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE) {
                pmtMethod.Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_INACTIVE;
            }
            else if (pmtMethod.Status__c == PaymentMethodActions.PAYMENT_METHOD_STATUS_INACTIVE) {
                pmtMethod.Status__c = PaymentMethodActions.PAYMENT_METHOD_STATUS_ACTIVE;
            }

            // save changes
            gtwy.updatePaymentMethod(pmtMethod);

            // refresh payment methods for ui
            initExistedPMs();
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
        return null;
    }

    /**
    * Method marks selected Payment Method as a Default
    * @return PageReference returns always null because action performs on the same page
    */
    public PageReference setDefaultPaymentMethod() {
        try {
            List<String> fields = new List<String>{
                'Id',
                'Default__c'
            };
            String condition = 'Id = :payMethodIdForSetDefault';

            SOQLBuilder q = new SOQLBuilder(Payment_Method__c.SObjectType);
            q.assertIsAccessible()
             .setEnforceFLS(true)
             .selectFields(fields)
             .setCondition(condition)
             .setLimit(1);

            List<Payment_Method__c> pm = (List<Payment_Method__c>) Database.query(q.toSOQL());
            Payment_Method__c defaultMethod = pm == null || pm.isEmpty() ? null : pm.get(0);
            defaultMethod.Default__c = true;

            gtwy.updatePaymentMethod(defaultMethod);

            // refresh payment methods for ui
            initExistedPMs();
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            return null;
        }

        return null;
    }

    /**
     * Verify selected Payment Method
     * @return PageReference returns always null because action performs on the same page
     */
    public PageReference verifyBankAccount() {
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Verification_Status__c',
                'External_Id__c',
                'Payment_Processor__c',
                'Customer__c'
            };
            String queryCondition = 'Id = :payMethodIdToVerify';

            SOQLBuilder theQuery = new SOQLBuilder(Payment_Method__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(1);

            List<Payment_Method__c> pmtMethods =
                (List<Payment_Method__c>) Database.query(theQuery.toSOQL());

            Payment_Method__c pmtMethod = pmtMethods == null || pmtMethods.isEmpty() ? null : pmtMethods.get(0);

            Payment_Processor__c processor = PaymentProcessorUtils.getPaymentProcessor(
                pmtMethod.Payment_Processor__c);

            Payment_Processor_Customer__c customer = PaymentProcessorUtils.getPaymentProcessorCustomer(
                    processor.Id, pmtMethod.Customer__c);

            if (String.isBlank(customer.External_Id__c)
                    || String.isBlank(pmtMethod.External_Id__c)
                    || String.isBlank(processor.Connected_Account_Token__c)) {

                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR, StripeService.PAYMENT_METHOD_UPDATE_ERROR
                    )
                );
            }
            else {
                StripeService.StripeSource verifiedBankAccount = StripeService.verifyStripeBankAccount(
                    customer.External_Id__c,
                    pmtMethod.External_Id__c,
                    String.valueOf(firstDeposit),
                    String.valueOf(secondDeposit),
                    processor
                );

                pmtMethod.Verification_Status__c = verifiedBankAccount.status;

                //Update Payment Method Record in the Salesforce DB
                PaymentMethodEditController pmEditController =
                    new PaymentMethodEditController(pmtMethod);
                pmEditController.updateOnSFSideOnly();

                initExistedPMs();
            }
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            return NULL;
        }

        return NULL;
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