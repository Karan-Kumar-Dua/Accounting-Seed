public with sharing class BillingsPaymentReceiveHelper extends AbstractLWCHelper {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static Map<Id, Payment_Processor_Customer__c> ppcMap;

    @AuraEnabled
    public static List<BillingPaymentWrapper> receivePayments(String serializedParams) {
        try {
            List<BillingPaymentWrapper> params = (List<BillingPaymentWrapper>) JSON.deserialize(serializedParams, List<BillingPaymentWrapper>.class);
            Map<BillingPaymentWrapper, PaymentSaleItem.Errors> errorsByWrappers = validate(params);
            List<BillingPaymentWrapper> validParams = new List<BillingsPaymentReceiveHelper.BillingPaymentWrapper>();
            Set<Id> billingIds = new Set<Id>();
            for (BillingPaymentWrapper wrapper : params) {
                if (errorsByWrappers.get(wrapper) == null || errorsByWrappers.get(wrapper).isEmpty()) {
                    validParams.add(wrapper);
                    billingIds.addAll(wrapper.billingIds);
                } else if (!errorsByWrappers.get(wrapper).isEmpty()) {
                    wrapper.errors.add(errorsByWrappers.get(wrapper).errorsHolder[0].get('message'));
                }
            }

            Map<Id, Billing__c> billingsByIds = new Map<Id, Billing__c>(getFullBillings(billingIds));
            Map<Id, Set<Id>> processorIdsByCustomerIds = new Map<Id, Set<Id>>();
            Map<Id, Account> customersByCustomerIds = new Map<Id, Account>();
            for (BillingPaymentWrapper wrapper : validParams) {
                Billing__c billing = billingsByIds.get(wrapper.billingIds[0]);
                Set<Id> processorIds = processorIdsByCustomerIds.containsKey(billing?.Customer__c)
                        ? processorIdsByCustomerIds.get(billing?.Customer__c)
                        : new Set<Id>();
                processorIds.add(Id.valueOf(wrapper.selectedPP));
                processorIdsByCustomerIds.put(billing?.Customer__c, processorIds);
                customersByCustomerIds.put(billing?.Customer__c, billing?.Customer__r);
            }

            Map<Id, PaymentMethodProvider> providersByCustomerIds = new Map<Id, PaymentMethodProvider>();
            for (Id customerId : processorIdsByCustomerIds.keySet()) {
                Account customer = customersByCustomerIds.get(customerId);
                providersByCustomerIds.put(
                        customerId,
                        new PaymentMethodProvider(customer, new PaymentGateway())
                            .onlyProcessorIds(processorIdsByCustomerIds.get(customerId))
                            .receiveStripeSources()
                            .leaveAvailableForSelectionOnly()
                            .bindWithSF()
                            .createSelectOption()
                );
            }

            List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            List<List<Billing__c>> billingBatches = new List<List<Billing__c>>();
            for (BillingPaymentWrapper wrapper : validParams) {
                List<Billing__c> billings = new List<Billing__c>();
                for (Id billingId : wrapper.billingIds) {
                    billings.add(billingsByIds.get(billingId));
                }
                billingBatches.add(billings);

                Cash_Receipt__c cashReceipt = prepareCashReceipt(billings[0], wrapper);
                PaymentMethodProvider provider = providersByCustomerIds.get(billings[0].Customer__c);
                saleItems.add(new PaymentSaleItem(
                        provider.getStripeSourceBySelectedSource(wrapper.selectedPM),
                        cashReceipt,
                        billings
                ));
                cashReceipts.add(cashReceipt);
            }

            if (!saleItems.isEmpty()) {
                saleItems = (new PaymentGateway()).sale(saleItems);

                Map<Cash_Receipt__c, List<Billing__c>> billingsByCashReceipts = new Map<Cash_Receipt__c, List<Billing__c>>();
                for (Integer index = 0; index < validParams.size(); index++) {
                    BillingPaymentWrapper wrapper = validParams[index];
                    List<Billing__c> billings = billingBatches[index];
                    if (saleItems[index].errors.isEmpty() && isCurrentAccountingPeriodOpen(cashReceipts[index].Receipt_Date__c, billings[0].Accounting_Period__c)) {
                        billingsByCashReceipts.put(saleItems[index].cashReceipt, billingBatches[index]);
                    } else if (!saleItems[index].errors.isEmpty()) {
                        wrapper.errors.addAll(saleItems[index].errors.errorsHolder[0].values());
                    }
                }

                if (!billingsByCashReceipts.isEmpty()) {
                    Map<Id, String> errorMessagesByCashReceiptIds = createBillingCashReceipts(billingsByCashReceipts);
                    for (Integer index = 0; index < validParams.size(); index++) {
                        BillingPaymentWrapper wrapper = validParams[index];
                        PaymentSaleItem saleItem = saleItems[index];
                        if (errorMessagesByCashReceiptIds.containsKey(saleItem.cashReceipt.Id)) {
                            String message = errorMessagesByCashReceiptIds.get(saleItem.cashReceipt.Id);
                            if(String.isBlank(message) != true){
                                wrapper.errors.add(message);
                            }
                        }
                    }
                }
            }

            return params;
        } catch(CardknoxProcessorV1.CardknoxProcessorV1AuthenticationException cpV1){
            throw new AuraHandledException(cpV1.getMessage());
        }catch(DmlException ex) {
            throw new AuraHandledException(ex.getDmlMessage(0));
        } catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static BillingPaymentWrapper receivePayment(String serializedParams) {
        try {
            BillingPaymentWrapper params = (BillingPaymentWrapper) JSON.deserialize(serializedParams, BillingPaymentWrapper.class);
            PaymentSaleItem.Errors errors = validate(params);
            if (errors.isEmpty()) {
                List<Billing__c> billings = getFullBillings(new Set<Id> (params.billingIds));
                Cash_Receipt__c cashReceipt = prepareCashReceipt(billings[0], params);

                PaymentMethodProvider provider = new PaymentMethodProvider(billings[0].Customer__r, new PaymentGateway())
                    .receiveStripeSources()
                    .leaveAvailableForSelectionOnly()
                    .bindWithSF()
                    .createSelectOption();

                List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>{new PaymentSaleItem(
                    provider.getStripeSourceBySelectedSource(params.selectedPM),
                    cashReceipt, billings
                )};
                if (!saleItems.isEmpty()) {
                    saleItems = (new PaymentGateway()).sale(saleItems);

                    if (saleItems[0].errors.isEmpty() && isCurrentAccountingPeriodOpen(cashReceipt.Receipt_Date__c, billings[0].Accounting_Period__c)) {
                        String message = createBCR(saleItems[0].cashReceipt, billings, params);
                        if(String.isBlank(message) != true){
                            params.errors.add(message);
                        }
                    } else if (!saleItems[0].errors.isEmpty()) {
                        params.errors.addAll(saleItems[0].errors.errorsHolder[0].values());
                    }
                }
            } else if (!errors.isEmpty()) {
                params.errors.add(errors.errorsHolder[0].get('message'));
            }

            return params;
        } catch(CardknoxProcessorV1.CardknoxProcessorV1AuthenticationException cpV1){
            throw new AuraHandledException(cpV1.getMessage());
        }catch(DmlException ex) {
            throw new AuraHandledException(ex.getDmlMessage(0));
        } catch(Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
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

    private static Map<BillingPaymentWrapper, PaymentSaleItem.Errors> validate(List<BillingPaymentWrapper> params) {
        Map<BillingPaymentWrapper, PaymentSaleItem.Errors> errorsByWrappers = new Map<BillingPaymentWrapper, PaymentSaleItem.Errors>();
        for (BillingPaymentWrapper wrap: params) {
            errorsByWrappers.put(wrap, validate(wrap));
        }
        return errorsByWrappers;
    }

    private static PaymentSaleItem.Errors validate(BillingPaymentWrapper params) {
        PaymentSaleItem.Errors errors = new PaymentSaleItem.Errors();

        Decimal amount = params.paymentAmount;
        if (amount == 0) {
            errors.add(BillingPaymentReceive.AMOUNT_ZERO_ERROR, BillingPaymentReceive.StatusCode.AMOUNT_ZERO_ERROR.name());
        }
        if (amount < 0) {
            errors.add(BillingPaymentReceive.NEGATIVE_AMOUNT_ERROR_MESSAGE, BillingPaymentReceive.StatusCode.NEGATIVE_AMOUNT_ERROR_MESSAGE.name());
        }
        if (!LedgerHandler.getInstanceWithoutSharing().isActiveLedger(params.ledgerId)) {
            errors.add(Label.ERR_LEDGER_ACTIVE_ONLY, BillingPaymentReceive.StatusCode.INACTIVE_LEDGER_ERROR.name());
        }

        return errors;
    }

    private static Cash_Receipt__c prepareCashReceipt(Billing__c billing, BillingPaymentWrapper params) {
        String paymentProcessorId = params.selectedPP;
        Decimal amount = params.paymentAmount;
        Date paymentDate = Date.today();
        Cash_Receipt__c cashReceipt = (Cash_Receipt__c) params.cashReceipt.obj;

        cashReceipt.Amount__c = amount;
        cashReceipt.Account__c = billing.Customer__c;
        cashReceipt.Ledger__c = billing.Ledger__c;
        cashReceipt.Receipt_Date__c = paymentDate;
        cashReceipt.Convenience_Fees_Charged__c = params.convenienceFee;
        cashReceipt.Accounting_Period__c = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(paymentDate)?.Id != NULL
            ? AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(paymentDate).Id
            : NULL;
        cashReceipt.Payment_Processor__c = paymentProcessorId;

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            cashReceipt.put('CurrencyIsoCode', billing.get('CurrencyIsoCode'));
        }
        return cashReceipt;
    }

    private static String createBCR(Cash_Receipt__c cashReceipt, List<Billing__c> billings, BillingPaymentWrapper params) {
        try{
            if (isCurrentAccountingPeriodOpen(cashReceipt.Receipt_Date__c, billings[0].Accounting_Period__c)) {
                createBillingCashReceipt(cashReceipt, billings, params);
            }
            return '';
        }catch (DmlException dmlEx) {
            return dmlEx.getMessage();
        }catch(Exception billEx){
            return billEx.getMessage();
        }
    }
    private static Map<Id, String> createBillingCashReceipts(Map<Cash_Receipt__c, List<Billing__c>> billingsByCashReceipts) {
        Map<Id, String> statusesByCashReceiptIds = new Map<Id, String>();
        List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
        Set<Id> processorIds = new Set<Id>();
        for (Cash_Receipt__c cashReceipt : billingsByCashReceipts.keySet()) {
            List<Billing__c> billings = billingsByCashReceipts.get(cashReceipt);
            if (!billings.isEmpty() && isCurrentAccountingPeriodOpen(cashReceipt.Receipt_Date__c, billings[0].Accounting_Period__c)) {
                processorIds.add(cashReceipt.Payment_Processor__c);
                for (Billing__c bill : billings) {
                    Boolean isBillingPeriodInFuture = AccountingPeriodHandler.getInstance().getAccountingPeriodById(bill.Accounting_Period__c).Start_Date__c >
                            AccountingPeriodHandler.getInstance().getAccountingPeriodById(cashReceipt.Accounting_Period__c).End_Date__c;

                    Billing_Cash_Receipt__c billingCashReceipt = new Billing_Cash_Receipt__c(
                            Accounting_Period__c = isBillingPeriodInFuture ? bill.Accounting_Period__c : cashReceipt.Accounting_Period__c,
                            Billing__c = bill.Id,
                            Cash_Receipt__c = cashReceipt.Id,
                            Applied_Date__c = isBillingPeriodInFuture
                                    ? AccountingPeriodHandler.getInstance().getAccountingPeriodById(bill.Accounting_Period__c).Start_Date__c
                                    : cashReceipt.Receipt_Date__c,
                            Applied_Amount__c = bill.Balance__c
                    );
                    if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                        billingCashReceipt.put('CurrencyIsoCode', cashReceipt.get('CurrencyIsoCode'));
                    }

                    billingCashReceipts.add(billingCashReceipt);
                }
            } else {
                statusesByCashReceiptIds.put(cashReceipt.Id, '');
            }
        }

        Map<Id, Payment_Processor__c> paymentProcessorsByIds = new Map<Id, Payment_Processor__c>(DomainUtils.getPaymentProcessorsById(processorIds));

        Map<Id, Cash_Receipt__c> cashReceiptsByIds = new Map<Id, Cash_Receipt__c>(new List<Cash_Receipt__c>(billingsByCashReceipts.keySet()));
        Map<Id, Cash_Receipt__c> namedCashReceiptsByIds = new Map<Id, Cash_Receipt__c>(DomainUtils.getCashReceiptById(cashReceiptsByIds.keySet()));

        List<Database.SaveResult> results = SFDCSecurityUtils.insertCheckCRUDAndFLS(billingCashReceipts, new List<String>(),false);
        for (Integer index = 0; index < results.size(); index++) {
            Database.SaveResult result = results[index];
            if (!result.isSuccess()) {
                Billing_Cash_Receipt__c billingCashReceipt = billingCashReceipts[index];
                Cash_Receipt__c cashReceipt = namedCashReceiptsByIds.get(billingCashReceipt.Cash_Receipt__c);
                Payment_Processor__c paymentProcessor = paymentProcessorsByIds.get(cashReceipt.Payment_Processor__c);

                String errorMessage = '';
                if (paymentProcessor != null) {
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED,
                            new List<String>{
                                    paymentProcessor.Type__c,
                                    cashReceipt.Payment_Reference__c,
                                    StripeProcessorV1.composeErrorMsg(result),
                                    cashReceipt.Name});
                } else {
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED_WITH_PAYMENT_REFERENCE,
                            new List<String>{
                                    StripeProcessorV1.composeErrorMsg(result),
                                    cashReceipt.Name});
                }
                statusesByCashReceiptIds.put(cashReceipt.Id, errorMessage);
            }
        }
        return statusesByCashReceiptIds;
    }

    private static List<Billing_Cash_Receipt__c> createBillingCashReceipt(Cash_Receipt__c cashReceipt, List<Billing__c> billings, BillingPaymentWrapper params) {
        List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
        for (Billing__c bill : billings) {
            Boolean isBillingPeriodInFuture = AccountingPeriodHandler.getInstance().getAccountingPeriodById(bill.Accounting_Period__c).Start_Date__c >
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(cashReceipt.Accounting_Period__c).End_Date__c;

            Billing_Cash_Receipt__c billingCashReceipt = new Billing_Cash_Receipt__c(
                Accounting_Period__c = isBillingPeriodInFuture ? bill.Accounting_Period__c : cashReceipt.Accounting_Period__c,
                Billing__c = bill.Id,
                Cash_Receipt__c = cashReceipt.Id,
                Applied_Date__c = isBillingPeriodInFuture
                    ? AccountingPeriodHandler.getInstance().getAccountingPeriodById(bill.Accounting_Period__c).Start_Date__c
                    : cashReceipt.Receipt_Date__c,
                Applied_Amount__c = bill.Balance__c
            );
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                billingCashReceipt.put('CurrencyIsoCode', cashReceipt.get('CurrencyIsoCode'));
            }

            billingCashReceipts.add(billingCashReceipt);
        }

        List<Payment_Processor__c> paymentProcessors =
                DomainUtils.getPaymentProcessorsById(new Set<Id>{cashReceipt.Payment_Processor__c});

        List<Cash_Receipt__c> namedCashReceipt =
                DomainUtils.getCashReceiptById(new Set<Id>{cashReceipt.Id});

        List<Database.SaveResult> results = SFDCSecurityUtils.insertCheckCRUDAndFLS(billingCashReceipts, new List<String>(),false);
        for (Integer index = 0; index < results.size(); index++) {
            Database.SaveResult result = results[index];
            if (!result.isSuccess()) {
                String errorMessage = '';
                if(!paymentProcessors.isEmpty()) {
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED,
                            new List<String>{
                                    paymentProcessors[0].Type__c,
                                    cashReceipt.Payment_Reference__c,
                                    StripeProcessorV1.composeErrorMsg(result),
                                    namedCashReceipt[0].Name}).replace('..', '.');
                } else {
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED_WITH_PAYMENT_REFERENCE,
                            new List<String>{
                                    StripeProcessorV1.composeErrorMsg(result),
                                    namedCashReceipt[0].Name});
                }
                throw new BillingPaymentReceiveHelper.BillingPaymentReceiveException(errorMessage);
            }
        }
        return billingCashReceipts;
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, Map<String, Object>> bankAccountsByLedgerIds() {
        Map<String, Map<String, Object>> bankAccountsByLedgerIds = new Map<String, Map<String, Object>>();
        for (Ledger__c ledger : LedgerHandler.getInstanceWithoutSharing().getAllLedgers()) {
            bankAccountsByLedgerIds.put(ledger.Id, new Map<String, Object>{
                    'id' => ledger.Default_Bank_Account__c
            });
        }
        return bankAccountsByLedgerIds;
    }

    @AuraEnabled(Cacheable=true)
    public static String getBillings(List<Id> billingIds, Boolean isAggregate) {
        List<BillingPaymentWrapper> results = new List<BillingPaymentWrapper>();
        try {
            AccountingPeriodHandler handler = AccountingPeriodHandler.getInstance();
            Accounting_Period__c period = handler.getAccountingPeriodByDate(Date.today());
            if (handler.isConsideredClosed(period.Id, Cash_Receipt__c.SObjectType)) {
                throw new BillingPaymentReceiveHelper.BillingPaymentReceiveException(String.format(
                    Label.ERR_NO_OPEN_PERIOD_FOR_DATE,
                    new List<String>{Date.today().format()}
                ));
            }
            if (!billingIds.isEmpty()
                && AccountingPeriodHandler.getInstance().isConsideredOpen(AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today()))
                && PaymentGateway.getDefaultPaymentProcessorId() != null) {

                List<Billing__c> billings = getFullBillings(new Set<Id> (billingIds));
                getPaymentProcessorCustomerMap(billings);

                for (List<Billing__c> bills : aggregateBillings(billings, isAggregate)) {
                    if (ppcMap.containsKey(bills[0].Customer__c)) {
                        results.add(new BillingPaymentWrapper(bills, isAggregate));
                    }
                }
            }

        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return JSON.serialize(results);
    }

    private static void getPaymentProcessorCustomerMap(List<Billing__c> billings) {
        ppcMap = new Map<Id, Payment_Processor_Customer__c>();
        Set<Id> customerIds = new Set<Id>();
        for (Billing__c bill : billings) {
            customerIds.add(bill.Customer__c);
        }
        for (Payment_Processor_Customer__c ppc : DomainUtils.getPaymentProcessorByCustomers(customerIds)) {
            if (!ppcMap.containsKey(ppc.Account__c)) {
                ppcMap.put(ppc.Account__c, ppc);
            }
        }
    }

    public static List<List<Billing__c>> aggregateBillings(List<Billing__c> billings, Boolean isAggregate) {
        List<List<Billing__c>> aggregatedBillings = new List<List<Billing__c>>();
        Map<String, List<Billing__c>> aggregatedBillingsMap = new Map<String, List<Billing__c>>();
        Set<Id> customerIds = new Set<Id>();

        for (Billing__c bill : billings) {
            customerIds.add(bill.Customer__c);
            if (isAggregate) {
                String currencyIsoCode = MultiCurrencyHandler.isMultiCurrencyEnabled ? (String) bill.get('CurrencyIsoCode') : '';
                if (aggregatedBillingsMap.containsKey((String) bill.Customer__c + (String) bill.Ledger__c + currencyIsoCode)) {
                    aggregatedBillingsMap.get((String) bill.Customer__c + (String) bill.Ledger__c + currencyIsoCode).add(bill);
                }
                else {
                    aggregatedBillingsMap.put((String) bill.Customer__c + (String) bill.Ledger__c + currencyIsoCode, new List<Billing__c> {bill});
                }
            }
            else {
                aggregatedBillings.add(new List<Billing__c> {bill});
            }
        }

        if (!aggregatedBillingsMap.isEmpty()) {
            aggregatedBillings.addAll(aggregatedBillingsMap.values());
        }
        return aggregatedBillings;
    }



    public static List<Billing__c> getFullBillings(Set<Id> billingIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Customer__c',
            'Balance__c',
            'Total__c',
            'Type__c',
            'Received_Amount__c',
            'Discount_Due_Date__c',
            'Discount_Amount__c',
            'Customer__c',
            'Customer__r.Stripe_Customer_Id__c',
            'Customer__r.Name',
            'Customer__r.GL_Account_Variable_1__c',
            'Customer__r.GL_Account_Variable_2__c',
            'Customer__r.GL_Account_Variable_3__c',
            'Customer__r.GL_Account_Variable_4__c',
            'Accounting_Period__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Default_Bank_Account__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :billingIds AND Balance__c != 0 AND Total__c > 0';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    public with sharing class BillingPaymentWrapper {
        @AuraEnabled
        public String Id;
        @AuraEnabled
        public List<String> errors = new List<String>();
        @AuraEnabled
        public Boolean isAggregate = false;
        @AuraEnabled
        public String actionName;
        @AuraEnabled
        public Boolean actionDisabled = true;
        @AuraEnabled
        public List<Id> billingIds = new List<Id>();
        @AuraEnabled
        public String status;
        @AuraEnabled
        public SObjectData billing;
        @AuraEnabled
        public SObjectData cashReceipt;
        @AuraEnabled
        public String customerId;
        @AuraEnabled
        public String customerUrl;
        @AuraEnabled
        public String customerName;
        @AuraEnabled
        public String ledgerUrl;
        @AuraEnabled
        public String ledgerName;
        @AuraEnabled
        public String ledgerId;
        @AuraEnabled
        public Decimal billingsTotal;
        @AuraEnabled
        public Decimal priorAmount;
        @AuraEnabled
        public Decimal convenienceFee;
        @AuraEnabled
        public Decimal paymentAmount;
        @AuraEnabled
        public Decimal billingsBalance;
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        @AuraEnabled
        public String currencyIsoCode;
        @AuraEnabled
        public List<CustomSelectOption> availablePP = new List<CustomSelectOption>();
        @AuraEnabled
        public String selectedPP;
        @AuraEnabled
        public List<CustomSelectOption> availablePM = new List<CustomSelectOption>();
        @AuraEnabled
        public String selectedPM;


        public BillingPaymentWrapper(List<Billing__c> bills, Boolean isAggregate) {
            this.Id = bills[0].Id;
            this.status = '';
            this.isAggregate = isAggregate;
            setBilling(bills[0]);
            setCustomer(bills[0]);
            setLedger(bills[0]);
            setCashReceipt(bills[0]);
            setAmounts(bills);
            this.currencyIsoCode = AbstractLWCHelper.getCurrencyIsoCode(bills[0]);
        }

        public void setBilling(Billing__c bill) {
            this.billing = new SObjectData();
            this.billing.obj = bill;
            this.billing.sobjType = PACKAGE_QUALIFIER + 'Billing__c';
            this.billing.recordURL = AbstractLWCHelper.getUrl(bill.Id);
        }

        public void setCustomer(Billing__c bill) {
            this.customerId = bill.Customer__c;
            this.customerName = bill.Customer__r.Name;
            this.customerUrl = AbstractLWCHelper.getUrl(bill.Customer__c);
        }

        public void setLedger(Billing__c bill) {
            this.ledgerName = bill.Ledger__r.Name;
            this.ledgerUrl = AbstractLWCHelper.getUrl(bill.Ledger__c);
            this.ledgerId = bill.Ledger__c;
        }

        public void setCashReceipt(Billing__c bill) {
            this.cashReceipt = new SObjectData();
            this.cashReceipt.obj = new Cash_Receipt__c();
            this.cashReceipt.sobjType = PACKAGE_QUALIFIER + 'Cash_Receipt__c';
            this.cashReceipt.recordURL = '';
            this.cashReceipt.obj.put(PACKAGE_QUALIFIER + 'Bank_Account__c', bill.Ledger__r.Default_Bank_Account__c);
            this.cashReceipt.obj.put(PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c', bill.Customer__r.GL_Account_Variable_1__c);
            this.cashReceipt.obj.put(PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c', bill.Customer__r.GL_Account_Variable_2__c);
            this.cashReceipt.obj.put(PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c', bill.Customer__r.GL_Account_Variable_3__c);
            this.cashReceipt.obj.put(PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c', bill.Customer__r.GL_Account_Variable_4__c);
        }

        public void setAmounts(List<Billing__c> bills) {
            this.billingsTotal = 0;
            this.priorAmount = 0;
            this.paymentAmount = 0;
            this.billingsBalance = 0;

            for (Billing__c bill : bills) {
                this.billingIds.add(bill.Id);
                this.billingsTotal += bill.Total__c;
                this.priorAmount += bill.Received_Amount__c;
                this.paymentAmount += bill.Balance__c;
                this.billingsBalance += bill.Balance__c;
            }
        }

    }

}