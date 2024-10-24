/*
 * Description:
 * Class provides a means for end users to process payments with the Accounting Seed Financial Suite application. Provides the ability to create a new payment for Stripe payment gateway
 */
public with sharing class PaymentManager {
    public static final String CANNOT_CREATE_PAYMENT_ERROR_MESSAGE =
            Label.ERR_COMMON_TOAST_ERROR_TITLE + ':<br/>' +
            Label.ERR_PAYMENT_ERROR_MESSAGE_PT1 + ':<br/><ul>' +
            '<li>'+Label.ERR_PAYMENT_ERROR_MESSAGE_PT2+'</li>\n' +
            '<li>'+Label.ERR_PAYMENT_ERROR_MESSAGE_PT3+'</li>\n' +
            '<li>'+Label.ERR_PAYMENT_ERROR_MESSAGE_PT4+'</li></ul>';

    /* Constants */
    private static String ACCOUNTING_PERIOD_OPEN_ERROR = Label.ERR_ACCOUNTING_PERIOD_OPEN;
    private static final String COMMON_NONE = 'None';
    private static final String CC_FLAT_FEE = PaymentProcessorActions.CC_FLAT_FEE;
    private static final String CC_PERCENT = PaymentProcessorActions.CC_PERCENT;
    private static final String CREDIT_CARD = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
    private static final String ACH_FLAT_FEE = PaymentProcessorActions.ACH_FLAT_FEE;
    private static final String ACH_PERCENT = PaymentProcessorActions.ACH_PERCENT;
    private static final String ACH_TYPE = PaymentMethodActions.ACH_PAYMENT_METHOD_TYPE;

    /* Instance Variables */
    private ApexPages.StandardController controller;
    @TestVisible
    private Date receiptDate;
    private List<SelectOption> glAccounts;
    private PaymentGateway gtwy;
    private Payment_Processor__c paymentProcessor;

    public Account account {get; private set;}
    public PaymentMethodProvider pmProvider {get; set;}
    public Cash_Receipt__c amountObject { get; set; }
    public String description { get; set; }
    public Boolean isErrorMode {get; private set;}
    public Boolean isAmountError {get; set;}
    public String amountError {get; private set;}
    public Boolean isSourceNotSelected {get; set;}
    public Boolean noStripeConnectedId {get; private set;}
    public Boolean isSuccess {get; set;}
    public String stripeIdempotencyKey {get; private set;}
    public String selectedCurrency {get; set;}
    public Boolean isMultiCurrencyEnabled {get; private set;}
    public Boolean isCardknoxTypeProcessor {get; private set;}

    //convenience fees varibale
    public Boolean enableConvenienceFee{get; set;}
    public Boolean disableCheckbox{get; set;}
    public Decimal convenienceFee{get; set;}
    public Decimal totalAmount{get; set;}

    private Boolean excludeConvenienceFee = false;
    /* Constructors */
    public PaymentManager(ApexPages.StandardController controller) {
        try {
            noStripeConnectedId = !PaymentGateway.connected();
            if (noStripeConnectedId) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, CANNOT_CREATE_PAYMENT_ERROR_MESSAGE));
                return;
            }

            isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            if (isMultiCurrencyEnabled) {
                selectedCurrency =
                    (String) LedgerHandler.getInstanceWithoutSharing()
                        .getLedgerById(LedgerHandler.getLedgerId())
                        .get('CurrencyIsoCode');
            }
            isErrorMode = false;
            isAmountError = false;
            amountError = '';
            isSourceNotSelected = false;
            isSuccess = false;
            amountObject = new Cash_Receipt__c();
            amountObject.Ledger__c = LedgerHandler.getLedgerId();
            amountObject.Bank_Account__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(amountObject.Ledger__c).Default_Bank_Account__c;
            this.controller = controller;
            account = (Account) controller.getRecord();
            receiptDate = System.today();
            stripeIdempotencyKey = FinancialSuiteUtils.getUUID();
            checkAccessOnLoad();//Stripe_Customer_Id__c may be not accessible for current user
            this.gtwy = new PaymentGateway();
            pmProvider = new PaymentMethodProvider(account, gtwy);
            initSources();
        }
        catch (Exception ex) {
            isErrorMode = true;
            ApexPages.addMessages(ex);
        }
    }

    public List<SelectOption> getCurrencySelectOptions() {
        if (isMultiCurrencyEnabled) {
            return MultiCurrencyHandler.getActiveCurrenciesSelectOptions();
        }
        else {
            return NULL;
        }
    }

    public List<SelectOption> getAllLedgers() {
        return LedgerHandler.getInstanceWithSharing().getTransactionalActiveLedgerSelectOptions();
    }

    public List<SelectOption> getGLAccounts() {
        if (glAccounts == NULL) {
            glAccounts = new List<SelectOption>();
            for (GL_Account__c glAccount : DomainUtils.getBankGlAccounts()) {
                glAccounts.add(new SelectOption(glAccount.Id, glAccount.Name));
            }
            if (glAccounts.isEmpty()) {
                glAccounts.add(new SelectOption('', Label.SELECT_OPTION_NONE));
            }
        }
        return glAccounts;
    }

    public PageReference changeLedger() {
        updateBankAcount();
        if (isMultiCurrencyEnabled) {
            selectedCurrency = (String) LedgerHandler.getInstanceWithoutSharing().getLedgerById(amountObject.Ledger__c).get('CurrencyIsoCode');
        }
        return NULL;
    }

    public PageReference checkPMType() {
        excludeConvenienceFee = false;
        pmProvider.updateSelectedSourceType();
        calculateAmountCnvFee();
        return NULL;
    }

    public Pagereference updateProcessor() {
        excludeConvenienceFee = false;
        pmProvider.updateSelectedPaymentMethod();
        updateBankAcount();

        if (pmProvider.isTestModeSelected()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.WARNING, Label.INFO_PAYMENTS_PROCESSOR_TEST_MODE));
        }

        if (pmProvider.sourceIdsSelectOptions == null || pmProvider.sourceIdsSelectOptions.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, Label.ERR_PAYMENTS_NO_PROCESSOR_FOUND));
        }

        return null;
    }

    private void initSources() {
        try {
            pmProvider
                .receiveStripeSources()
                .leaveAvailableForSelectionOnly(true)
                .bindWithSF()
                .createSelectOption();
        } catch (StripeService.StripeServiceException e) {
            if (e.getMessage() == Label.ERR_PAYMENTS_NO_ACTIVE_PAYMENT_METHOD) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, CANNOT_CREATE_PAYMENT_ERROR_MESSAGE));
                noStripeConnectedId = true;
            } else {
                throw e;
            }
        }

        if (pmProvider.processorSelectOptions == null || pmProvider.processorSelectOptions.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, Label.ERR_PAYMENTS_NO_PROCESSOR_FOUND));
        }

        if (pmProvider.sourceIdsSelectOptions == null || pmProvider.sourceIdsSelectOptions.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, Label.ERR_PAYMENTS_NO_PROCESSOR_FOUND));
        }

        if (pmProvider.isTestModeSelected()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.WARNING, Label.INFO_PAYMENTS_PROCESSOR_TEST_MODE));
        }

        updateBankAcount();
    }

    /* Instance Methods */
    /**
    * Method creates Charge for Existing Stripe Card
    * @return PageReference returns always null because action performs on the same page
    */
    public PageReference submitPayment() {
        Boolean isValidationError = false;
        isAmountError = false;
        isSourceNotSelected = false;
        amountError = '';
        isSuccess = false;

        try {
            if (isNotOpenAccountingPeriod()) {
                isValidationError = true;
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        String.format(ACCOUNTING_PERIOD_OPEN_ERROR, new String[]{receiptDate.format()})
                    )
                );
            }

            if (!LedgerHandler.getInstanceWithoutSharing().isActiveLedger(amountObject.Ledger__c)) {
                isValidationError = true;
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        Label.ERR_LEDGER_ACTIVE_ONLY)
                );
            }

            if (amountObject.Amount__c == NULL || amountObject.Amount__c == 0) {
                isValidationError = true;
                isAmountError = true;
                amountError = ' ' + SObjectActions.REQUIRED_FIELD_ERROR;
            }

            if (amountObject.Amount__c == NULL || amountObject.Amount__c < 0) {
                isValidationError = true;
                isAmountError = true;
                amountError = ' ' + Label.COMMON_MUST_BE_POSITIVE_NUMBER;
            }

            if (String.isBlank(pmProvider.selectedSourceId) || pmProvider.selectedSourceId == 'NONE') {
                isValidationError = true;
                isSourceNotSelected = true;
            }

            checkAccessOnSubmit();//will throw Exception in case of missing access

            if (isValidationError) {
                return NULL;
            }

            Cash_Receipt__c cr = amountObject.clone(false, true, false, false);
            cr.Account__c = account.Id;
            cr.Ledger__c = amountObject.Ledger__c;
            cr.Bank_Account__c = amountObject.Bank_Account__c;
            cr.GL_Account_Variable_1__c = amountObject.GL_Account_Variable_1__c;
            cr.GL_Account_Variable_2__c = amountObject.GL_Account_Variable_2__c;
            cr.GL_Account_Variable_3__c = amountObject.GL_Account_Variable_3__c;
            cr.GL_Account_Variable_4__c = amountObject.GL_Account_Variable_4__c;
            cr.Receipt_Date__c = receiptDate;
            cr.Project__c = amountObject.Project__c;
            cr.Project_Task__c = amountObject.Project_Task__c;
            cr.Description__c = description;
            cr.Purpose__c = 'Customer Receipt';
            cr.Amount__c = totalAmount;
            cr.Convenience_Fees_Charged__c = convenienceFee;
            if (isMultiCurrencyEnabled) {
                cr.put('CurrencyIsoCode', selectedCurrency);
            }
            
            Payment_Method__c pm = pmProvider.getStripeSourceBySelectedSource();
            List<PaymentSaleItem> activity = gtwy.sale(new List<PaymentSaleItem> { new PaymentSaleItem(pm, cr)});

            // if payment method did not exist in SF, but was created as part of the
            // above operation, this will add it to the list of existing payment methods
            pmProvider.addExistedPM(pm);
            if(!activity[0].errors.isEmpty()){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, activity[0].errors.errorsHolder[0].get('message')));
                isSuccess = false;
            }
            else if (activity[0].paymentActivity.Status__c == PaymentActivityHelper.SUCCESS_STATUS
                    || activity[0].paymentActivity.Status__c == PaymentActivityHelper.PENDING_STATUS) {
                if(convenienceFee != null && (convenienceFee != 0.00 || convenienceFee != 0)){
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, '<b>' +Label.INF_PAYMENT_PROCESSED_SUCCESSFULLY_TITLE + '</b>:<br/>'+ Label.INF_PAYMENT_PROCESSED_SUCCESSFULLY_MESSAGE));
                }else{
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, StripeService.PAYMENT_SUCCESSFUL));
                }
                isSuccess = true;
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, activity[0].paymentActivity.Status__c + ': ' + activity[0].paymentActivity.Error_Message__c));
                isSuccess = false;
            }
        }
        catch (PaymentGateway.PaymentGatewayException e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
        }
        catch (StripeProcessorV1.StripeProcessorV1Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
        }
        catch (DmlException e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getDmlMessage(0)));
        }
        catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
        }

        return NULL;
    }

    @TestVisible
    private Boolean isNotOpenAccountingPeriod() {
        Boolean retVal = false;

        try {
            //==============================================================================================
            // Query must be executed in the System Context to count the number of "Open" Accounting Periods
            // regardless of current user permissions. This is used to implement application business rule.
            //==============================================================================================
            Accounting_Period__c openAcctPeriodForDate =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(receiptDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS},Cash_Receipt__c.sObjectType);

            if (openAcctPeriodForDate == NULL) {
                retVal = true;
            }
        }
        catch (Exception ex) {
            retVal = true;
        }

        return retVal;
    }

    private void checkAccessOnLoad() {
        SFDCSecurityUtils.checkRead(Payment_Processor_Customer__c.getSObjectType(), new List<String>{'External_Id__c'});
    }

    private void checkAccessOnSubmit() {
        SFDCSecurityUtils.checkInsert(Cash_Receipt__c.SObjectType, new List<String>{
            'Purpose__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Project__c',
            'Project_Task__c'
        });

        SFDCSecurityUtils.checkInsert(Payment_Activity__c.SObjectType, new List<String>{
            'Type__c',
            'Cash_Receipt__c',
            'Status__c'
        });

        SFDCSecurityUtils.checkInsert(Payment_Method__c.SObjectType, new List<String>{
            'Type__c',
            'Status__c',
            'Expiration_Month__c',
            'Expiration_Year__c',
            'Card_Holder_Name__c',
            'Bank_Name__c',
            'Bank_Account_Type__c',
            'Verification_Status__c'
        });
    }

    private void updateBankAcount() {
        paymentProcessor = DomainUtils.getPaymentProcessorById(pmProvider.selectedProcessorId);
        isCardknoxTypeProcessor = paymentProcessor?.Type__c == PaymentProcessorActions.CARDKNOX_TYPE;
        if (isCardknoxTypeProcessor) {
            amountObject.Bank_Account__c = paymentProcessor.Merchant_GL_Account__c;
        } else {
            amountObject.Bank_Account__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(amountObject.Ledger__c).Default_Bank_Account__c;
        }
        calculateAmountCnvFee();
    }
    private void calculateAmountCnvFee(){
        if(paymentProcessor.Type__c == PaymentProcessorActions.CARDKNOX_TYPE && paymentProcessor.Enable_Convenience_Fees__c == true 
                && paymentProcessor.Credit_Card_Convenience_Fee_Type__c != COMMON_NONE 
                && paymentProcessor.Credit_Card_Convenience_Fee_Type__c != null 
                && paymentProcessor.Credit_Card_Convenience_Fee_Type__c != '' 
                && pmProvider.getSelectedSourceTypeAsLabel() == CREDIT_CARD){
                    if(paymentProcessor.Credit_Card_Convenience_Fee_Type__c == CC_FLAT_FEE && paymentProcessor.CC_Flat_Fee__c != null){
                        enableConvenienceFee = true;
                        disableCheckbox = false;
                        convenienceFee = scaleHalfUp(paymentProcessor.CC_Flat_Fee__c);
                    }else if(paymentProcessor.Credit_Card_Convenience_Fee_Type__c == CC_PERCENT && paymentProcessor.CC_Percent__c != null){
                        enableConvenienceFee = true;
                        disableCheckbox = false;
                        convenienceFee = amountObject.Amount__c != null ? scaleHalfUp((amountObject.Amount__c * paymentProcessor.CC_Percent__c) / 100) : 0.00;
                    }else{
                        disableCnvFee();
                    }
        }else if(paymentProcessor.Type__c == PaymentProcessorActions.CARDKNOX_TYPE && paymentProcessor.Enable_Convenience_Fees__c == true 
                && paymentProcessor.ACH_Convenience_Fee_Type__c != COMMON_NONE 
                && paymentProcessor.ACH_Convenience_Fee_Type__c != null 
                && paymentProcessor.ACH_Convenience_Fee_Type__c != '' 
                && pmProvider.getSelectedSourceTypeAsLabel() == ACH_TYPE){
                    if(paymentProcessor.ACH_Convenience_Fee_Type__c == ACH_FLAT_FEE && paymentProcessor.ACH_Flat_Fee__c != null){
                        enableConvenienceFee = true;
                        disableCheckbox = false;
                        convenienceFee = scaleHalfUp(paymentProcessor.ACH_Flat_Fee__c);
                    }else if(paymentProcessor.ACH_Convenience_Fee_Type__c == ACH_PERCENT && paymentProcessor.ACH_Percent__c != null){
                        enableConvenienceFee = true;
                        disableCheckbox = false;
                        convenienceFee = amountObject.Amount__c != null ? scaleHalfUp((amountObject.Amount__c * paymentProcessor.ACH_Percent__c) / 100) : 0.00;
                    }else{
                        disableCnvFee();
                    }
        }else{
            disableCnvFee();
        }
        if(excludeConvenienceFee == true){
            convenienceFee = 0.00;
            enableConvenienceFee = false;
        }
        totalAmount = amountObject.Amount__c != null ?  scaleHalfUp(amountObject.Amount__c + convenienceFee) : convenienceFee;
    }
    private Decimal scaleHalfUp(Decimal value) {
        return value.setScale(2, System.RoundingMode.HALF_UP);
    }
    private void disableCnvFee(){
        disableCheckbox = true;
        enableConvenienceFee = false;
        convenienceFee = 0.00;
    }
    public PageReference updateAmount() {
        calculateAmountCnvFee();
        return NULL;
    }
    public PageReference handleEnableFee(){
        if(enableConvenienceFee == false){
            excludeConvenienceFee = true;
            convenienceFee = 0.00;
            totalAmount = amountObject.Amount__c != null ? amountObject.Amount__c.setScale(2, System.RoundingMode.HALF_UP) : convenienceFee;
        }else{
            excludeConvenienceFee = false;
            calculateAmountCnvFee();
        }
        return NULL;
    }
    public class CashReceiptDMLException extends Exception {}

}