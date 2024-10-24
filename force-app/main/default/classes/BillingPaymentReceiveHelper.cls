public with sharing class BillingPaymentReceiveHelper {

    //private instance
    private static SchemaDescribe cashReceiptSchema = SchemaDescribe.getDescribe(Cash_Receipt__c.SObjectType);
    // package qualifier
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    //public instance
    public class BillingPaymentReceiveException extends Exception {}
    @AuraEnabled(cacheable=true)
    public static PaymentWrapper getPaymentProcessors(String customerId){
        if(customerId == null || customerId == ''){return null;}
        Account customer = PaymentProcessorUtils.getAccount((Id)customerId);
        return filterPaymentProcessors(customer);
    }
    private static PaymentWrapper filterPaymentProcessors(Account customer){
        PaymentGateway gtwy = new PaymentGateway();
        PaymentMethodProvider pmProvider = new PaymentMethodProvider(customer, gtwy);

        try{
            pmProvider
                .receiveStripeSources()
                .leaveAvailableForSelectionOnly(true)
                .bindWithSF()
                .createSelectOption();

            return new PaymentWrapper(
                        preparePaymentProcessors(pmProvider.processorSelectOptions),
                        getPaymentMethodsWithProcessors(pmProvider.sourcesByProcessorId),
                        pmProvider.selectedProcessorId,
                        pmProvider.selectedSourceId,
                        pmProvider.getPaymentSources()
                        ).initPaymentProcessorDetailsByIds().paymentMethodDetailsByExternalIds(pmProvider.sourceIdToStripeSourceMap);
        }catch(Exception e){
            return new PaymentWrapper(e.getMessage());
        }
    }
    @TestVisible
    private static List<AbstractLWCHelper.CustomSelectOption> preparePaymentProcessors(List<SelectOption> processors){
        List<AbstractLWCHelper.CustomSelectOption> opts = new List<AbstractLWCHelper.CustomSelectOption>();

        for(SelectOption processor : processors){
            opts.add(new AbstractLWCHelper.CustomSelectOption(processor.getValue(),processor.getLabel()));
        }
        return opts;
    }
    @TestVisible
    private static Map<Id,List<AbstractLWCHelper.CustomSelectOption>> getPaymentMethodsWithProcessors(Map<Id,List<SelectOption>> sourcesByProcessorId){
        Map<Id,List<AbstractLWCHelper.CustomSelectOption>> pmWithProcessors = new Map<Id,List<AbstractLWCHelper.CustomSelectOption>>();
        
        for(Id ppId : sourcesByProcessorId.keySet()){
            List<AbstractLWCHelper.CustomSelectOption> opts = new List<AbstractLWCHelper.CustomSelectOption>();
            for(SelectOption opt : sourcesByProcessorId.get(ppId)){
                opts.add(new AbstractLWCHelper.CustomSelectOption(opt.getValue(),opt.getLabel()));
            }
            pmWithProcessors.put(ppId,opts);
        }
        return pmWithProcessors;
    }
    @AuraEnabled(cacheable=true)
    public static BillingPaymentWrapper getWrappedBillings(String billingId){
        try{
            Billing__c bill = BillingPaymentReceiveService.getFullBillings(billingId);
            checkValidations(bill);
            return new BillingPaymentWrapper(bill);
        }catch(Exception ex){
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> receivePayment(Map<String, Object> params) {
        try {
            PaymentSaleItem.Errors errors = validate(params);
            if (errors.isEmpty()) {
                String recordId = params.get('recordId') != null ? String.valueOf(params.get('recordId')) : null;
                String paymentType = params.get('payment-type') != null ? String.valueOf(params.get('payment-type')) : null;

                Billing__c billing = BillingPaymentReceiveService.getFullBillings(recordId);
                checkValidations(billing);
                Cash_Receipt__c cashReceipt = prepareCashReceipt(billing, params);

                if (paymentType == BillingPaymentReceive.STRIPE_PAYMENT_LABEL) {
                    AccountingPeriodHandler periodHandler = AccountingPeriodHandler.getInstance();
                    Accounting_Period__c period = periodHandler.getAccountingPeriodByDate(Date.today());
                    if (periodHandler.isConsideredClosed(period.Id, Cash_Receipt__c.SObjectType)) {
                        throw new BillingPaymentReceiveHelper.BillingPaymentReceiveException(String.format(
                            Label.ERR_NO_OPEN_PERIOD_FOR_DATE,
                            new List<String>{
                                Date.today().format()
                            }
                        ));
                    }

                    PaymentMethodProvider provider = new PaymentMethodProvider(billing.Customer__r, new PaymentGateway())
                        .receiveStripeSources()
                        .leaveAvailableForSelectionOnly()
                        .bindWithSF()
                        .createSelectOption();

                    String paymentMethodExternalId = params.get('payment-methods') != null ? String.valueOf(params.get('payment-methods')) : null;
                    List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>{
                        new PaymentSaleItem(
                            provider.getStripeSourceBySelectedSource(paymentMethodExternalId),
                            cashReceipt, new List<Billing__c>{
                                billing
                            }
                        )
                    };
                    if (!saleItems.isEmpty()) {
                        saleItems = (new PaymentGateway()).sale(saleItems);

                        if (saleItems[0].errors.isEmpty() && isCurrentAccountingPeriodOpen(cashReceipt.Receipt_Date__c, billing.Accounting_Period__c)) {
                            String message = createBCR(saleItems[0].cashReceipt, billing, params);
                            if (String.isBlank(message) != true) {
                                errors.add(message);
                            }
                        } else if (!saleItems[0].errors.isEmpty()) {
                            errors.addAll(saleItems[0].errors.errorsHolder);
                        }
                    }
                } else {
                    Date paymentDate = params.get('payment-date') != null ? Date.valueOf((String) params.get('payment-date')) : Date.today();
                    Accounting_Period__c period = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(paymentDate);
                    if (period == null) {
                        errors.add(BillingPaymentReceive.NO_EXIST_PERIOD_ERROR_MESSAGE);
                    } else if (period != null && AccountingPeriodHandler.getInstance().isConsideredClosed(period.Id, Cash_Receipt__c.SObjectType)) {
                        errors.add(String.format(
                            BillingPaymentReceive.NO_OPEN_PERIOD_ERROR_MESSAGE,
                            new List<String>{
                                paymentDate.format()
                            }
                        ));
                    } else if (period != null) {
                        cashReceipt.Accounting_Period__c = period.Id;
                    }

                    if (errors.isEmpty()) {
                        Savepoint sp = Database.setSavepoint();
                        try {
                            SFDCSecurityUtils.insertCheckCRUDAndFLS(new List<Cash_Receipt__c>{
                                cashReceipt
                            }, new List<String>{
                                'Amount__c',
                                'Account__c'
                            });
                            String message = createBCR(cashReceipt, billing, params);
                            if (String.isBlank(message) != true) {
                                errors.add(message);
                            }
                        } catch (DmlException dmlEx) {
                            Database.rollback(sp);
                            errors.add(dmlEx.getDmlMessage(0));
                        } catch (BillingPaymentReceiveException billEx) {
                            errors.add(billEx.getMessage());
                        }
                    }
                }
            }

            return new Map<String, Object>{'errors' => errors.errorsHolder};
        } catch (CardknoxProcessorV1.CardknoxProcessorV1AuthenticationException cpV1) {
            throw new AuraHandledException(cpV1.getMessage());
        } catch (BillingPaymentReceiveException billEx) {
            throw new AuraHandledException(billEx.getMessage());
        } catch (DmlException ex) {
            throw new AuraHandledException(ex.getDmlMessage(0));
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static String createBCR(Cash_Receipt__c cashReceipt, Billing__c billing, Map<String, Object> params) {
        try{
            if (isCurrentAccountingPeriodOpen(cashReceipt.Receipt_Date__c, billing.Accounting_Period__c)) {
                createBillingCashReceipt(cashReceipt, billing, params);
            }
            return '';
        }catch (DmlException dmlEx) {
            return dmlEx.getMessage();
        }catch(BillingPaymentReceiveException billEx){
            return billEx.getMessage();
        }
    }

    private static Billing_Cash_Receipt__c createBillingCashReceipt(Cash_Receipt__c cashReceipt, Billing__c billing, Map<String, Object> params) {
        Boolean isBillingPeriodInFuture = AccountingPeriodHandler.getInstance().getAccountingPeriodById(billing.Accounting_Period__c).Start_Date__c >
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(cashReceipt.Accounting_Period__c).End_Date__c;

        Decimal discountAmount = String.isNotBlank((String)params.get('discount-amount'))
        ? Decimal.valueOf((String)params.get('discount-amount'))
        : null;

        Id conFeeGLAccount = String.isNotBlank((String)params.get('confeeGLAccount'))
        ? Id.valueOf((String)params.get('confeeGLAccount'))
        : null;

        Decimal convenienceFeeAmount = (Decimal)params.get('convenienceFees') != null ? (Decimal)params.get('convenienceFees') : 0.0;
        String adjustmentGLAccount = (String)params.get('adjustment-gl-account');

        List<Cash_Receipt__c> namedCashReceipt =
                        DomainUtils.getCashReceiptById(new Set<Id>{cashReceipt.Id});

        Billing_Cash_Receipt__c billingCashReceipt = new Billing_Cash_Receipt__c(
                Accounting_Period__c = isBillingPeriodInFuture ? billing.Accounting_Period__c : cashReceipt.Accounting_Period__c,
                Billing__c = billing.Id,
                Cash_Receipt__c = cashReceipt.Id,
                Applied_Date__c = isBillingPeriodInFuture
                        ? AccountingPeriodHandler.getInstance().getAccountingPeriodById(billing.Accounting_Period__c).Start_Date__c
                        : cashReceipt.Receipt_Date__c,
                Applied_Amount__c = namedCashReceipt[0].Balance__c,
                Adjustment_GL_Account__c = String.isNotBlank(adjustmentGLAccount) ? adjustmentGLAccount : null,
                Adjustment_Amount__c = String.isNotBlank(adjustmentGLAccount) ? discountAmount : null
        );
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            billingCashReceipt.put('CurrencyIsoCode', cashReceipt.get('CurrencyIsoCode'));
        }
        
        List<Payment_Processor__c> paymentProcessors = 
            DomainUtils.getPaymentProcessorsById(new Set<Id>{cashReceipt.Payment_Processor__c});

        List<Database.SaveResult> results = SFDCSecurityUtils.insertCheckCRUDAndFLS(new List<Billing_Cash_Receipt__c>{billingCashReceipt}, new List<String>(),false);
        for (Integer index = 0; index < results.size(); index++) {
            Database.SaveResult result = results[index];
            if (!result.isSuccess()) {
                String errorMessage = '';
                if(!paymentProcessors.isEmpty()){
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED, 
                            new List<String>{
                                paymentProcessors[0].Type__c,
                                cashReceipt.Payment_Reference__c,
                                StripeProcessorV1.composeErrorMsg(result),
                                namedCashReceipt[0].Name});
                }else{
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED_WITH_PAYMENT_REFERENCE, 
                            new List<String>{
                                StripeProcessorV1.composeErrorMsg(result),
                                namedCashReceipt[0].Name});
                }
                throw new BillingPaymentReceiveException(errorMessage);
            }
        }
        return billingCashReceipt;
    }
    
    private static Boolean isCurrentAccountingPeriodOpen(Date receiptDate, Id billAccountingPeriodId) {
        Accounting_Period__c currentAccountingPeriod = getCurrentAccountingPeriod(receiptDate, billAccountingPeriodId);
        return currentAccountingPeriod != null && String.isNotBlank(currentAccountingPeriod.Id) && currentAccountingPeriod.Status__c == AccountingPeriodActions.OPEN_STATUS;
    }

    private static Accounting_Period__c getCurrentAccountingPeriod(Date receiptDate, Id billAccountingPeriodId) {
        Map<Date, Accounting_Period__c> allPeriods = new Map<Date, Accounting_Period__c>{
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(receiptDate).Start_Date__c =>
                        AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(receiptDate),
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(billAccountingPeriodId).Start_Date__c =>
                        AccountingPeriodHandler.getInstance().getAccountingPeriodById(billAccountingPeriodId)
        };

        List<Date> sortedDate = new List<Date> (allPeriods.keySet());
        sortedDate.sort();

        return !allPeriods.keySet().isEmpty() ? allPeriods.get(sortedDate[sortedDate.size() - 1]) : null;
    }

    private static PaymentSaleItem.Errors validate(Map<String, Object> params) {
        PaymentSaleItem.Errors errors = new PaymentSaleItem.Errors();

        Decimal amount = String.isNotBlank((String)params.get('amount')) ? Decimal.valueOf((String)params.get('amount')) : null;
        if (amount == 0) {
            errors.add(BillingPaymentReceive.AMOUNT_ZERO_ERROR, BillingPaymentReceive.StatusCode.AMOUNT_ZERO_ERROR.name());
        }
        if (amount < 0) {
            errors.add(BillingPaymentReceive.NEGATIVE_AMOUNT_ERROR_MESSAGE, BillingPaymentReceive.StatusCode.NEGATIVE_AMOUNT_ERROR_MESSAGE.name());
        }

        String project = (String)params.get('project');
        String projectTask = (String)params.get('projectTask');
        if (String.isNotBlank(project) && String.isBlank(projectTask)) {
            errors.add('A project task is required if a project is selected.', BillingPaymentReceive.StatusCode.NO_PROJECT_TASK.name());
        }

        Decimal discountAmount = String.isNotBlank((String)params.get('discount-amount'))
                ? Decimal.valueOf((String)params.get('discount-amount'))
                : null;
        String adjustmentGLAccount = (String)params.get('adjustment-gl-account');
        if (discountAmount > 0 && String.isBlank(adjustmentGLAccount)) {
            errors.add(BillingPaymentReceive.EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE, BillingPaymentReceive.StatusCode.EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE.name());
        }
        return errors;
    }

    private static Cash_Receipt__c prepareCashReceipt(Billing__c billing, Map<String, Object> params) {
        String paymentProcessorId = params.get('payment-processor') != null ? String.valueOf(params.get('payment-processor')) : null;
        Decimal amount = (Decimal)params.get('totalPaymentAmount');
        Date paymentDate = params.get('payment-date') != null ? Date.valueOf((String)params.get('payment-date')) : Date.today();

        Cash_Receipt__c cashReceipt = (Cash_Receipt__c)JSON.deserialize(JSON.serialize(params.get('cashReceipt')), Cash_Receipt__c.class);

        cashReceipt.Amount__c = amount;
        cashReceipt.Account__c = billing.Customer__c;
        cashReceipt.Ledger__c = billing.Ledger__c;
        cashReceipt.Receipt_Date__c = paymentDate;
        cashReceipt.Accounting_Period__c = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(paymentDate)?.Id != NULL
                        ? AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(paymentDate).Id
                        : NULL;
        cashReceipt.Bank_Account__c = (String)params.get('bank-account');
        cashReceipt.Payment_Processor__c = paymentProcessorId;
        cashReceipt.Payment_Reference__c = (String)params.get('payment-reference');
        cashReceipt.Convenience_Fees_Charged__c =  (Decimal)params.get('convenienceFees');
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            cashReceipt.put('CurrencyIsoCode', billing.get('CurrencyIsoCode'));
        }
        return cashReceipt;
    }

    private static void checkValidations(Billing__c bill){
        AccountingPeriodHandler handler = AccountingPeriodHandler.getInstance();
        Accounting_Period__c period = handler.getAccountingPeriodByDate(Date.today());
        if (handler.isConsideredClosed(period)) {
            throw new BillingPaymentReceiveException(String.format(
                Label.ERR_NO_OPEN_PERIOD_FOR_DATE,
                new List<String>{Date.today().format()}
            ));
        }
        if (!LedgerHandler.getInstanceWithoutSharing().isActiveLedger(bill.Ledger__c)) {
            throw new BillingPaymentReceiveException(Label.ERR_LEDGER_ACTIVE_ONLY);
        }
        if(bill.Type__c != BillingActions.INVOICE_TYPE){
            throw new BillingPaymentReceiveException(Label.ERR_RECEIVE_PAYMENT_TYPE_MUST_BE_INVOICE);
        }   
        if(bill.Balance__c <= 0){
            throw new BillingPaymentReceiveException(Label.BILLING_BALANCE_MUST_GREATER_THAN_ZERO);
        }
    }
    public class PaymentWrapper{
        @AuraEnabled
        public List<Payment_Processor__c> processorRecords;
        @AuraEnabled
        public List<Payment_Method__c> paymentMethods;
        @AuraEnabled
        public Map<String, Object> paymentProcessorDetailsByIds;
        @AuraEnabled
        public Map<String, Map<String, Object>> paymentMethodDetailsByExternalIds;
        @AuraEnabled
        public List<AbstractLWCHelper.CustomSelectOption> paymentProcessors;
        @AuraEnabled
        public Map<Id,List<AbstractLWCHelper.CustomSelectOption>> paymentMethodsWithProcessor;
        @AuraEnabled
        public String selectedPPId;
        @AuraEnabled
        public String selectedPMId;
        @AuraEnabled
        public Boolean noDataAvailable;
        @AuraEnabled
        public String errorMessage;
        public PaymentWrapper(){
            this.noDataAvailable = true;
        }
        public PaymentWrapper(String errorMessage){
            this.noDataAvailable = true;
            this.errorMessage = errorMessage;
        }
        public PaymentWrapper(List<AbstractLWCHelper.CustomSelectOption> pp, Map<Id,List<AbstractLWCHelper.CustomSelectOption>> pms,
                                String ppId, String pmId, List<Payment_Method__c> paymentMethods){
            this.paymentProcessors = pp;
            this.paymentMethods = paymentMethods;
            this.paymentMethodsWithProcessor = pms;
            this.selectedPPId = ppId;
            this.selectedPMId = pmId;
            this.noDataAvailable = false;
        }
        public PaymentWrapper paymentMethodDetailsByExternalIds(Map<String, Payment_Method__c> paymentMethodsByExternalIds) {
            this.paymentMethodDetailsByExternalIds = new Map<String, Map<String, Object>>();
            for (String externalId : paymentMethodsByExternalIds.keySet()) {
                Payment_Method__c paymentMethod = paymentMethodsByExternalIds.get(externalId);
                this.paymentMethodDetailsByExternalIds.put(externalId, new Map<String, Object>{
                        'methodType' => paymentMethod.Payment_Method_Type__c
                });
            }
            return this;
        }
        public PaymentWrapper initPaymentProcessorDetailsByIds() {
            Set<Id> paymentProcessorIds = new Set<Id>();
            for (AbstractLWCHelper.CustomSelectOption option : paymentProcessors) {
                paymentProcessorIds.add((Id)option.value);
            }
            List<Payment_Processor__c> processors = PaymentProcessorUtils.getPaymentProcessors(paymentProcessorIds);
            this.paymentProcessorDetailsByIds = new Map<String, Object>();
            for (Payment_Processor__c paymentProcessor : processors) {
                paymentProcessorDetailsByIds.put(paymentProcessor.Id, new Map<String, Object>{
                        'isTestMode' => paymentProcessor.Test_Mode__c
                });
            }
            processorRecords = processors;
            return this;
        }
    }
    public with sharing class BillingPaymentWrapper{
        @AuraEnabled
        public String billLedgerName;
        @AuraEnabled
        public String billCurrencyIsoCode;
        @AuraEnabled
        public Date crReceiptDate;
        @AuraEnabled
        public String crReference;
        @AuraEnabled
        public Decimal billBillingTotal;
        @AuraEnabled
        public String crBankAccount;
        @AuraEnabled
        public Map<String,String> crBankAccounts;
        @AuraEnabled
        public Decimal billCrEarlyDiscount;
        @AuraEnabled
        public Date billDiscountDueDate;
        @AuraEnabled
        public Decimal billCrAdjustment;
        @AuraEnabled
        public String billCrAdjustmentGlAccount;
        @AuraEnabled
        public String billCrObjectName;
        @AuraEnabled
        public Decimal billTotalReceivedAmount;
        @AuraEnabled
        public Decimal billTotalBalance;
        @AuraEnabled
        public Decimal billTotalAmount;
        @AuraEnabled
        public Account customer;
        @AuraEnabled
        public Billing__c bill;
        @AuraEnabled
        public Cash_Receipt__c cashReceipt;
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled;
        @AuraEnabled
        public Billing_Cash_Receipt__c proxyBillingCashReceipt;
        @AuraEnabled
        public Map<String, Object> additionalLookupValues;
        @AuraEnabled
        public Boolean billPpEnableFee;
        @AuraEnabled
        public String billPpFeeType;
        @AuraEnabled
        public Decimal billPpCcPercent;
        @AuraEnabled
        public Decimal billPpCcFlatFee;
        @AuraEnabled
        public String conFeeGLAccount;
        @AuraEnabled
        public Decimal billSubTotal;
        @AuraEnabled
        public Decimal billSalesTax;
        @AuraEnabled
        public Boolean isLineLevelPost;
        @AuraEnabled
        public FieldSetHandler.FieldSetResponse fieldSetColumns;
        private List<String> fieldsToIgnore;
        public BillingPaymentWrapper(Billing__c  bill) {
            this.fieldsToIgnore = new List<String>{PACKAGE_QUALIFIER +'Receipt_Date__c',PACKAGE_QUALIFIER +'Payment_Reference__c',
                                                    PACKAGE_QUALIFIER +'Bank_Account__c',PACKAGE_QUALIFIER + 'Amount__c',
                                                    PACKAGE_QUALIFIER + 'Ledger__c', 'CurrencyIsoCode', PACKAGE_QUALIFIER + 'Payment_Type__c'};
            this.bill = bill;
            this.billLedgerName = bill.Ledger__c;
            this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.billCurrencyIsoCode =
                isMultiCurrencyEnabled ? (String) bill.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            this.cashReceipt = getCashReceipt();
            this.crReceiptDate = this.cashReceipt.Receipt_Date__c;
            this.crReference = this.cashReceipt.Payment_Reference__c;
            this.billBillingTotal = this.bill.Total__c;
            this.proxyBillingCashReceipt = getProxyBCR();
            this.billCrEarlyDiscount = this.proxyBillingCashReceipt.Applied_Amount__c;
            this.billDiscountDueDate = this.bill.Discount_Due_Date__c;
            this.billCrAdjustment = this.billCrEarlyDiscount;
            this.billCrAdjustmentGlAccount = this.proxyBillingCashReceipt.Adjustment_GL_Account__c;
            this.billTotalReceivedAmount = bill.Received_Amount__c;
            this.billTotalBalance = bill.Balance__c;
            this.billTotalAmount = bill.Total__c;
            this.conFeeGLAccount = bill.Payment_Processor__r.Convenience_Fees_GL_Account__c;
            this.crBankAccount = this.cashReceipt.Bank_Account__c;
            this.crBankAccounts = getBankAccounts();
            this.billPpEnableFee = bill.Payment_Processor__r.Enable_Convenience_Fees__c;
            this.billPpFeeType = bill.Payment_Processor__r.Credit_Card_Convenience_Fee_Type__c;
            this.billPpCcFlatFee = bill.Payment_Processor__r.CC_Flat_Fee__c;
            this.billPpCcPercent = bill.Payment_Processor__r.CC_Percent__c;
            this.billCrObjectName = PACKAGE_QUALIFIER + 'GL_Account__c';
            this.billSubTotal = bill.Sub_Total__c;
            this.isLineLevelPost = AccountingSettingsHandler.isLineLevelPost();
            this.billSalesTax = this.isLineLevelPost == true ? bill.Sales_Tax2__c : bill.Sales_Tax3__c;
            this.fieldSetColumns = removeDuplicateFields(FieldSetHelper.getColumns(JSON.serialize(getFieldSetRequest(PACKAGE_QUALIFIER + 'Cash_Receipt__c',
                                                            PACKAGE_QUALIFIER + 'Receive_Payment_from_a_Billing_Record'))));
            this.additionalLookupValues = new Map<String, Object>{'parentObj' => PACKAGE_QUALIFIER + 'Cash_Receipt__c'};
        }
        private FieldSetHandler.FieldSetRequest getFieldSetRequest(String objectName, String fieldSetName){
            return new FieldSetHandler.FieldSetRequest(objectName,fieldSetName,'','');
        }
        private Map<String,String> getBankAccounts(){
            Map<String,String> banks = new Map<String,String>();
            List<GL_Account__c> bankAccounts = BillingPaymentReceiveService.getAdjustMentGlAccounts();
            for(GL_Account__c gl : bankAccounts){
                banks.put(gl.Id,gl.Name);
            }
            return banks;
        }
        private Billing_Cash_Receipt__c getProxyBCR() {
            Billing_Cash_Receipt__c proxyBillingCashReceipt = new Billing_Cash_Receipt__c();
            if (isMultiCurrencyEnabled) {
                proxyBillingCashReceipt.put('CurrencyIsoCode', this.billCurrencyIsoCode);
            }
            proxyBillingCashReceipt.Adjustment_GL_Account__c = AccountingSettingsHandler.getAccountingSettings().Customer_Payment_Adjustment_GL_Account__c;
            proxyBillingCashReceipt.Adjustment_Amount__c = 0;//Discount/Adjustment Amount input field
            proxyBillingCashReceipt.Applied_Amount__c = 0;//Suggested Discount output fields

            if (this.bill != null) {
                proxyBillingCashReceipt.Applied_Date__c = this.bill.Discount_Due_Date__c;
                if (isDiscountEligible(this.bill)) {
                    proxyBillingCashReceipt.Applied_Amount__c = this.bill.Discount_Amount__c;
                }
            }
            cashReceipt.Amount__c = cashReceipt.Amount__c - proxyBillingCashReceipt.Adjustment_Amount__c;
            return proxyBillingCashReceipt;
        }
        public Boolean isDiscountEligible(Billing__c bill) {
            return cashReceipt.Receipt_Date__c <= bill.Discount_Due_Date__c && bill.Discount_Amount__c > 0;
        }
        private Cash_Receipt__c getCashReceipt() {
            Cash_Receipt__c cr = new Cash_Receipt__c();
            if (isMultiCurrencyEnabled) {
                cr.put('CurrencyIsoCode', this.billCurrencyIsoCode);
            }
            cr.Account__c = bill.Customer__c;
            cr.Ledger__c = bill.Ledger__c;
            cr.Amount__c = bill.Balance__c;
            cr.Receipt_Date__c = Date.today();
            cr.Purpose__c = 'Customer Receipt';
            cr.Accounting_Period__c =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today()).Id != NULL
                    ? AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today()).Id
                    : NULL;
            cr.Bank_Account__c = bill.Ledger__r.Default_Bank_Account__c;
            cr.GL_Account_Variable_1__c = bill.Customer__r.GL_Account_Variable_1__c;
            cr.GL_Account_Variable_2__c = bill.Customer__r.GL_Account_Variable_2__c;
            cr.GL_Account_Variable_3__c = bill.Customer__r.GL_Account_Variable_3__c;
            cr.GL_Account_Variable_4__c = bill.Customer__r.GL_Account_Variable_4__c;
            
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            if (settings.Enable_Cash_Flow_Statement__c) {
                cr.Cash_Flow_Category__c = settings.Default_Cash_Receipt_Category__c;
            }
            return cr;
        }
        private FieldSetHandler.FieldSetResponse removeDuplicateFields(FieldSetHandler.FieldSetResponse fieldSetCols) {
            FieldSetHandler.FieldSetResponse filteredFieldSetCols = new FieldSetHandler.FieldSetResponse();

            for(Integer i = 0; i < fieldSetCols.mainColumns.size(); i++){
                if(fieldSetCols.mainColumns[i].apiName == PACKAGE_QUALIFIER +'Cash_Flow_Category__c'){
                    Boolean eCFS = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
                    fieldSetCols.mainColumns[i].isRequired = eCFS == true ? true : fieldSetCols.mainColumns[i].isRequired;
                }
                if(!this.fieldsToIgnore.contains(fieldSetCols.mainColumns[i].apiName)){
                    filteredFieldSetCols.mainColumns.add(fieldSetCols.mainColumns[i]);
                }
            }
            return filteredFieldSetCols;
        }
    }
    public class LookupWrapper{
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String selectedValue;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String lookupObjectName;
        @AuraEnabled
        public String objectLabel;
        @AuraEnabled
        public Boolean required;
        @AuraEnabled
        public String controllingField;

        public LookupWrapper(String key, String val, String fName,String lookupObjectName){
            this.key = key;
            this.selectedValue = val;
            this.fieldName = fName;
            this.lookupObjectName = lookupObjectName;
            this.objectLabel = getObjectLabel();
            this.controllingField = getControllingField();
        }
        private String getControllingField(){
            Schema.FilteredLookupInfo filterInfo= cashReceiptSchema.getField(this.fieldName)?.getDescribe().getFilteredLookupInfo();
            return filterInfo != null 
                        ? filterInfo.getControllingFields().size() > 0 
                            ? filterInfo.getControllingFields()[0] 
                                : null 
                        : null;
        }
        private String getObjectLabel(){
            return cashReceiptSchema.getField(this.fieldName).getDescribe().getLabel();
        }
        public LookupWrapper required(Boolean required) {
            this.required = required;
            return this;
        }
    }
}