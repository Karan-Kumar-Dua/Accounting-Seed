public with sharing class BillingPaymentReceive {

    private Map<Id, Account> accountMap;
    private Boolean singleBilling;
    private Boolean noStripeConnectedId;
    private List<GL_Account__c> bankAccounts = DomainUtils.getGlAccountsForCashFlowStatementReport();

    public List<Billing__c> bills {get; set;}
    public List<BillingPaymentWrapper> wrappedBillings {get; set;}
    public String selectedTransactionType {get; set;}

    public static final String STRIPE_PAYMENT_LABEL = 'Electronic';
    public static final String CHECK_LABEL = 'Check';
    public static final String AMOUNT_ZERO_ERROR = ' ' + Label.ERR_AMOUNT_ZERO;
    public static final String NO_DATA_ERROR_MESSAGE = Label.ERR_BILLING_VF_NO_DATA;

    public static final String BOTH_MODES_ERROR_MESSAGE =
        'The billings you have selected are associated with default payment methods that are in both \'Test\' and \'Live\' modes.' +
        '<br/>Please select billings associated with either only \'Test\' mode or only \'Live\' mode payment methods.';
    public static final String NEGATIVE_AMOUNT_ERROR_MESSAGE = Label.ERR_NEGATIVE_AMOUNT_RECEIVED;
    public static final String NO_OPEN_PERIOD_ERROR_MESSAGE = Label.ERR_NO_OPEN_PERIOD_FOR_DATE;
    public static final String NO_EXIST_PERIOD_ERROR_MESSAGE = Label.ERR_NO_EXIST_PERIOD_FOR_DATE;
    public static final String SUCCESS_PAYMENTS_MESSAGE = Label.INF_CASH_RECEIPTS_CREATED;
    public static final String LINE_LIMIT_EXCEEDED_ERROR_MESSAGE = Label.ERR_PAYMENT_LINE_LIMIT_EXCEEDED;
    public static final String EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE = Label.ERR_EMPTY_ADJUSTMENT_ACCOUNT;

    public Boolean isMultiCurrencyEnabled {get ;set;}
    public String currencyIsoCode {get; private set;}
    public Boolean isError {get; set;}
    public Boolean isSuccess {get; set;}
    public Boolean isDataAvailableError {get; set;}
    public Boolean isPaymentMethodError {get; set;}
    public Boolean isBothPaymentMode { get { return isBothPaymentMode != null && isBothPaymentMode; } set; }
    public Boolean isActionSelect {
        get {
            if (selectedTransactionType != NULL && selectedTransactionType != '') {
                return true;
            }
            return false;
        }
        set;
    }

    public String actionName {
        get {
            if (isActionSelect) {
                return (selectedTransactionType == STRIPE_PAYMENT_LABEL ? 'Payment' : 'Receipt');
            }
            return '';
        }
        set;
    }
    //public instance
    public class BillingPaymentReceiveException extends Exception {}

    public BillingPaymentReceive(ApexPages.StandardController controller) {
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        bills = getFullBillings(new Set<Id>{controller.getId()});
        noStripeConnectedId = StripeService.checkStripeConnectedId();
        isError = false;
        singleBilling = true;
        currencyIsoCode =
            isMultiCurrencyEnabled
                ? String.valueOf(bills[0].get('CurrencyIsoCode')) : MultiCurrencyHandler.CORPORATE_CURRENCY;
        initConstructor();
    }

    public BillingPaymentReceive(ApexPages.StandardSetController setController) {
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        bills = getFullBillings((List<Billing__c>) setController.getSelected());
        noStripeConnectedId = StripeService.checkStripeConnectedId();
        isError = false;
        singleBilling = false;
        if (noStripeConnectedId) {
            isError = true;
            isDataAvailableError = true;
            isPaymentMethodError = true;
            ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, NO_DATA_ERROR_MESSAGE));
        }
        if (!AccountingPeriod.isPeriodOpen(AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today()), Billing__c.sObjectType)) {
            isError = true;
            isDataAvailableError = true;
            isPaymentMethodError = true;
            ApexPages.addMessage(
                new ApexPages.MESSAGE(
                    ApexPages.SEVERITY.ERROR,
                    String.format(
                        NO_OPEN_PERIOD_ERROR_MESSAGE,
                        new List<String>{Date.today().format()}
                    )
                )
            );
        }
        if (!isError) {
            initConstructor();
            validateProcessorModes();
        }
    }

    private void initConstructor() {
        try {
            accountMap = new Map<Id, Account>();
            for (Billing__c billing : bills) {
                accountMap.put(billing.Customer__c, billing.Customer__r);
            }
            wrappedBillings = new List<BillingPaymentWrapper>();
            isDataAvailableError = false;
            isPaymentMethodError = false;
            isSuccess = false;
            if (bankAccounts.isEmpty()) {
                isError = true;
                isDataAvailableError = true;
                isPaymentMethodError = true;
                ApexPages.addMessage(
                    new ApexPages.MESSAGE(
                        ApexPages.SEVERITY.ERROR,
                        NO_DATA_ERROR_MESSAGE
                    )
                );
            }
            if (!isError) {
                init();
            }
            setSelectedTransactionType();
            updateProcessorAndBankInformation();
            checkReceiptTypeErrors();
        }
        catch (Exception ex) {
            isError = true;
            isDataAvailableError = true;
            isPaymentMethodError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
    }

    private void setSelectedTransactionType() {
        if(!StripeService.checkStripeConnectedId() && !isPaymentMethodError(false)) {
            selectedTransactionType = STRIPE_PAYMENT_LABEL;
        }
        else {
            selectedTransactionType = CHECK_LABEL;
        }
    }

    public List<SelectOption> getAvailableTypes() {
        List<SelectOption> result = new List<SelectOption>();
        if(!StripeService.checkStripeConnectedId()) {
            result.add(new SelectOption(STRIPE_PAYMENT_LABEL, STRIPE_PAYMENT_LABEL));
        }
        result.add(new SelectOption(CHECK_LABEL, CHECK_LABEL));
        return result;
    }

    public List<SelectOption> getBankAccounts() {
        List<SelectOption> result = new List<SelectOption>();
        for (GL_Account__c ba : bankAccounts) {
            result.add(new SelectOption(ba.Id, ba.Name));
        }
        return result;
    }

    private Boolean isValidProcessorModes() {
        Set<Id> selectedProcessorIds = new Set<Id>();
        for (BillingPaymentWrapper wrappedBilling : wrappedBillings) {
            selectedProcessorIds.add((Id)wrappedBilling.pmProvider.selectedProcessorId);
        }
        Map<Id, Payment_Processor__c> paymentProcessorsByIds = new Map<Id, Payment_Processor__c>();
        if (!selectedProcessorIds.isEmpty()) {
            paymentProcessorsByIds = new Map<Id, Payment_Processor__c>(DomainUtils.getPaymentProcessorsById(selectedProcessorIds));
        }
        Set<Boolean> modes = new Set<Boolean>();
        for (BillingPaymentWrapper wrappedBilling : wrappedBillings) {
            Payment_Processor__c paymentProcessor = paymentProcessorsByIds.get((Id)wrappedBilling.pmProvider.selectedProcessorId);
            if (paymentProcessor != null) {
                modes.add(paymentProcessor.Test_Mode__c);
            }
        }
        Boolean isValid = !modes.containsAll(new Set<Boolean>{true, false});
        if (!isValid) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, BOTH_MODES_ERROR_MESSAGE));
            isBothPaymentMode = true;
        } else {
            isBothPaymentMode = false;
        }
        return isValid;
    }

    public PageReference validateProcessorModes() {
        isValidProcessorModes();
        return null;
    }

    public PageReference checkReceiptTypeErrors() {
        isPaymentMethodError = false;
        if (selectedTransactionType == STRIPE_PAYMENT_LABEL) {
            if (!AccountingPeriod.isPeriodOpen(AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today()), Billing__c.SObjectType)) {
                isPaymentMethodError = true;
                ApexPages.addMessage(
                    new ApexPages.MESSAGE(
                        ApexPages.SEVERITY.ERROR,
                        String.format(
                            NO_OPEN_PERIOD_ERROR_MESSAGE,
                            new List<String>{Date.today().format()})
                    )
                );
            }
            if (noStripeConnectedId) {
                isPaymentMethodError = true;
                ApexPages.addMessage(
                    new ApexPages.MESSAGE(
                        ApexPages.SEVERITY.ERROR,
                        NO_DATA_ERROR_MESSAGE
                    )
                );
            }
            if (!isPaymentMethodError) {
                isPaymentMethodError = isPaymentMethodError(true);
            }
        }

        return NULL;
    }

    private Boolean isPaymentMethodError(Boolean needSetError) {
        Boolean result = false;
        for (BillingPaymentWrapper bp : wrappedBillings) {
            if (bp.pmProvider.noActiveSources) {
                if (needSetError) {
                    bp.bills[0].addError(NO_DATA_ERROR_MESSAGE);
                }
                result = true;
            }
        }
        return result;
    }

    private void populateBillingLedgerFieldIfBlank() {
        for (Billing__c bill : bills) {
            if (bill.Ledger__c == NULL) {
                bill.Ledger__c = LedgerHandler.getLegacyDefaultLedgerId();
            }
        }
    }

    private Map<CompositeKey, List<Billing__c>> groupSelectedBillings() {
        Map<CompositeKey, List<Billing__c>> result = new Map<CompositeKey, List<Billing__c>>();
        for (Billing__c bill : bills) {
            if (bill.Type__c != 'Invoice') {
                continue;
            }
            CompositeKey compKey = getCompositeKeyByBilling(bill);
            if (result.containsKey(compKey)) {
                result.get(compKey).add(bill);
            }
            else {
                result.put(compKey, new List<Billing__c>{bill});
            }
        }
        return result;
    }

    private CompositeKey getCompositeKeyByBilling(Billing__c selectedBilling) {
        CompositeKey result = new CompositeKey(
            selectedBilling.Customer__c,
            selectedBilling.Ledger__c,
            isMultiCurrencyEnabled ? (String) selectedBilling.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY
        );
        return result;
    }

    public PageReference init() {
        populateBillingLedgerFieldIfBlank();
        Map<CompositeKey, List<Billing__c>> groupedBillings = groupSelectedBillings();
        if (groupedBillings.keySet().size() > 50) {
            isDataAvailableError = true;
            ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, LINE_LIMIT_EXCEEDED_ERROR_MESSAGE));
        }
        else {
            PaymentGateway gtwy = new PaymentGateway();

            for (CompositeKey compKey : groupedBillings.keySet()) {
                BillingPaymentWrapper tempWrappedLine = new BillingPaymentWrapper(
                    accountMap.get(compKey.customerId),
                    groupedBillings.get(compKey),
                    isMultiCurrencyEnabled,
                    gtwy
                );

                if (!singleBilling) {
                    if (!tempWrappedLine.pmProvider.noActiveSources && tempWrappedLine.cashReceipt.Amount__c != 0) {
                        wrappedBillings.add(tempWrappedLine);
                    }
                }
                else {
                    wrappedBillings.add(tempWrappedLine);
                }
            }
        }

        wrappedBillings.sort();
        if (!isDataAvailableError && wrappedBillings.isEmpty()) {
            isDataAvailableError = true;
            ApexPages.addMessage(new ApexPages.MESSAGE(ApexPages.SEVERITY.ERROR, NO_DATA_ERROR_MESSAGE));
        }
        return NULL;
    }

    public PageReference createItems() {
        Set<Id> paymentProcessorsIds = new Set<Id>();
        Set<Id> cashReceiptIds = new Set<Id>();
        try {
            if (!isValidProcessorModes()) return null;

            isError = false;

            for (BillingPaymentWrapper bp : wrappedBillings) {
                bp.theStatusCode = StatusCode.NO_ERRORS;
                if (bp.cashReceipt.Amount__c == 0) {
                    bp.theStatusCode = StatusCode.AMOUNT_ZERO_ERROR;
                    if (singleBilling) {
                        isError = true;
                        bp.cashReceipt.Amount__c.addError(AMOUNT_ZERO_ERROR);
                    }
                }
                if (bp.cashReceipt.Amount__c < 0) {
                    bp.theStatusCode = StatusCode.NEGATIVE_AMOUNT_ERROR_MESSAGE;
                    if (singleBilling) {
                        isError = true;
                        bp.cashReceipt.Amount__c.addError(NEGATIVE_AMOUNT_ERROR_MESSAGE);
                    }
                }
                if (bp.proxyBillingCashReceipt.Adjustment_Amount__c > 0
                        && bp.proxyBillingCashReceipt.Adjustment_GL_Account__c == NULL) {

                    bp.theStatusCode = StatusCode.EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE;
                    if (singleBilling) {
                        isError = true;
                        bp.proxyBillingCashReceipt.Adjustment_GL_Account__c.addError(EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE);
                    }
                }
            }

            if (selectedTransactionType == STRIPE_PAYMENT_LABEL) {
                if (!isError) {

                    checkAccessOnSubmit();
                    List<PaymentSaleItem> saleItems = new List<PaymentSaleItem>();
                    for (BillingPaymentWrapper bp : wrappedBillings) {
                        if (bp.theStatusCode == StatusCode.NO_ERRORS) {
                            saleItems.add(bp.saleItem(new PaymentSaleItem(
                                    bp.pmProvider.getStripeSourceBySelectedSource(),
                                    bp.cashReceipt,
                                    bp.bills
                            )).saleItem);
                        }
                    }

                    if (!saleItems.isEmpty()) {
                        saleItems = (new PaymentGateway()).sale(saleItems);
                    }

                    for (BillingPaymentWrapper wrapper : wrappedBillings) {
                        if (wrapper.saleItem != null && !wrapper.saleItem.errors.isEmpty()) {
                            wrapper.errorMessage = wrapper.saleItem.errors.errorsHolder[0].get('message');
                            if (wrapper.saleItem.errors.errorsHolder[0].get('code') == StatusCode.STRIPE_ERROR.name()) {
                                wrapper.theStatusCode = StatusCode.STRIPE_ERROR;
                            } else {
                                wrapper.theStatusCode = StatusCode.EXTERNAL_ERROR;
                            }
                            if (singleBilling) throw new StripeService.StripeServiceException(wrapper.errorMessage);
                        }
                    }

                    List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
                    for (BillingPaymentWrapper bp : wrappedBillings) {
                        if (bp.theStatusCode == StatusCode.NO_ERRORS && bp.isAccountingPeriodOpen) {
                            billingCashReceipts.addAll(createBillingCashReceipt(bp));
                            cashReceiptIds.add(bp.cashReceipt.Id);
                            paymentProcessorsIds.add(bp.cashReceipt.Payment_Processor__c);
                        }
                    }

                    if (!billingCashReceipts.isEmpty()) {
                        insertBillingCashReceipts(billingCashReceipts,paymentProcessorsIds,cashReceiptIds);
                    }

                    if (singleBilling) {
                        return new PageReference('/' + wrappedBillings[0].bills[0].Id);
                    }

                    List<BillingPaymentWrapper> wrappersForRefresh = new List<BillingPaymentWrapper>();
                    for (BillingPaymentWrapper bp : wrappedBillings) {
                        if (bp.theStatusCode == StatusCode.NO_ERRORS) {
                            wrappersForRefresh.add(bp);
                        }
                    }

                    refreshReceivedAmountAndBalance(wrappersForRefresh);

                    isSuccess = true;
                    for (BillingPaymentWrapper bp : wrappedBillings) {
                        if (bp.theStatusCode == StatusCode.NO_ERRORS) {
                            bp.theStatusCode = StatusCode.CREATED;
                        }
                        else {
                            isSuccess = false;
                        }
                    }

                    if (isSuccess) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, SUCCESS_PAYMENTS_MESSAGE));
                    }
                }
            }

            if (selectedTransactionType == CHECK_LABEL) {
                if (!isError) {
                    for (BillingPaymentWrapper bp : wrappedBillings) {
                        Accounting_Period__c period = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(
                            bp.cashReceipt.Receipt_Date__c
                        );
                        if (period == NULL) {
                            isError = true;
                            bp.cashReceipt.addError(NO_EXIST_PERIOD_ERROR_MESSAGE);
                        }
                        else if (period != NULL && !(AccountingPeriod.isPeriodOpen(period, Cash_Receipt__c.sObjectType))) {
                            isError = true;
                            bp.cashReceipt.addError(
                                String.format(
                                    NO_OPEN_PERIOD_ERROR_MESSAGE,
                                    new List<String>{bp.cashReceipt.Receipt_Date__c.format()}
                                )
                            );
                        }
                        else if (period != NULL) {
                            bp.cashReceipt.Accounting_Period__c = period.Id;
                        }
                    }
                }
                if (!isError) {
                    List<Cash_Receipt__c> cashReceiptsForInsert = new List<Cash_Receipt__c>();
                    for (BillingPaymentWrapper bp : wrappedBillings) {
                        cashReceiptsForInsert.add(bp.cashReceipt);
                    }

                    Savepoint sp = Database.setSavepoint();
                    try {
                        //Save Cash Receipt(s)
                        insertCashReceipt(cashReceiptsForInsert);
                        //Save BCR(s)
                        List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
                        for (BillingPaymentWrapper bp : wrappedBillings) {
                            if (bp.isAccountingPeriodOpen) {
                                billingCashReceipts.addAll(createBillingCashReceipt(bp));
                                cashReceiptIds.add(bp.cashReceipt.Id);
                                paymentProcessorsIds.add(bp.cashReceipt.Payment_Processor__c);
                            }
                        }
                        insertBillingCashReceipts(billingCashReceipts,paymentProcessorsIds,cashReceiptIds);
                    }catch(BillingPaymentReceiveException billEx){
                        Database.rollback(sp);
                        throw billEx;
                    }
                    catch (DmlException dmlEx) {
                        Database.rollback(sp);
                        throw dmlEx;
                    }

                    if (singleBilling) {
                        return new PageReference('/' + wrappedBillings[0].bills[0].Id);
                    }
                }
            }
        }catch (StripeService.StripeServiceException stripeEx) {
            createNewPaymentMethods(wrappedBillings);
            createFailedPaymentActivities(wrappedBillings);
            isError = true;
            ApexPages.addMessages(stripeEx);
            for (BillingPaymentWrapper bp : wrappedBillings) {
                bp.theStatusCode = StatusCode.NO_ERRORS;
            }
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
            for (BillingPaymentWrapper bp : wrappedBillings) {
                if (bp.cashReceipt != null && bp.cashReceipt.Id != null) {
                    bp.cashReceipt.Id = null;
                }
                bp.theStatusCode = StatusCode.NO_ERRORS;
            }
        }
        return NULL;
    }

    private void refreshReceivedAmountAndBalance(List<BillingPaymentWrapper> billingPaymentWrappers) {
        Set<Id> ids = new Set<Id>();
        for (BillingPaymentWrapper bpw : billingPaymentWrappers) {
            for (Billing__c bill : bpw.bills) {
                ids.add(bill.Id);
            }
        }
        if (!ids.isEmpty()) {
            Map<Id, Billing__c> billingById = new Map<Id, Billing__c>(getFullBillings(ids));
            for (BillingPaymentWrapper bpw : billingPaymentWrappers) {
                List<Billing__c> newBillings = new List<Billing__c>();
                for (Billing__c bill : bpw.bills) {
                    newBillings.add(billingById.get(bill.Id));
                }
                bpw.bills = newBillings;
                bpw.getTotals();
                bpw.cashReceipt.Amount__c = 0;
            }
        }
    }

    private List<Billing__c> getFullBillings(List<Billing__c> selectedBillings) {
        return getFullBillings(new Map<Id, Billing__c>(selectedBillings).keySet());
    }

    public List<Billing__c> getFullBillings(Set<Id> billingIds) {
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
            'Customer__r.Stripe_Customer_Id__c',
            'Customer__r.Name',
            'Customer__r.GL_Account_Variable_1__c',
            'Customer__r.GL_Account_Variable_2__c',
            'Customer__r.GL_Account_Variable_3__c',
            'Customer__r.GL_Account_Variable_4__c',
            'Accounting_Period__c',
            'Ledger__c'
        };

        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :billingIds ';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false) // fls checked in vf page itself
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    private void insertCashReceipt(List<Cash_Receipt__c> cashReceipts) {
        SFDCSecurityUtils.insertCheckCRUDAndFLS(cashReceipts, new List<String>{
            'Amount__c',
            'Account__c'
        });
    }

    private List<Billing_Cash_Receipt__c> createBillingCashReceipt(BillingPaymentWrapper bpw) {
        List<Billing_Cash_Receipt__c> result = new List<Billing_Cash_Receipt__c>();
        for (Billing__c bill : bpw.bills) {
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = isBillingPeriodInFuture(bill.Accounting_Period__c, bpw.cashReceipt.Accounting_Period__c)
            ? bill.Accounting_Period__c : bpw.cashReceipt.Accounting_Period__c;
            bcr.Billing__c = bill.Id;
            bcr.Cash_Receipt__c = bpw.cashReceipt.Id;
            //Note: Cash Receipt's Receipt Date is set to Date.today() when CR is created
            bcr.Applied_Date__c = isBillingPeriodInFuture(bill.Accounting_Period__c, bpw.cashReceipt.Accounting_Period__c)
            ? AccountingPeriodHandler.getInstance().getAccountingPeriodById(bill.Accounting_Period__c).Start_Date__c : bpw.cashReceipt.Receipt_Date__c;
            if (isMultiCurrencyEnabled) {
                bcr.put('CurrencyIsoCode', bpw.cashReceipt.get('CurrencyIsoCode'));
            }
            setAppliedAndAdjustmentAmount(bpw, bcr, bill);
            result.add(bcr);
        }
        return result;
    }

    private Boolean isBillingPeriodInFuture(Id billPeriod, Id receiptPeriod) {
        return AccountingPeriodHandler.getInstance().getAccountingPeriodById(billPeriod).Start_Date__c >
            AccountingPeriodHandler.getInstance().getAccountingPeriodById(receiptPeriod).End_Date__c ;
    }

    private void setAppliedAndAdjustmentAmount(BillingPaymentWrapper bpw, Billing_Cash_Receipt__c bcr, Billing__c bill) {
        bcr.Applied_Amount__c = bpw.bills.size() > 1 ? bill.Balance__c : bpw.cashReceipt.Amount__c;
        if (bpw.bills.size() == 1
                && bpw.proxyBillingCashReceipt.Adjustment_GL_Account__c != NULL) {

            bcr.Adjustment_Amount__c = bpw.proxyBillingCashReceipt.Adjustment_Amount__c;
            bcr.Adjustment_GL_Account__c = bpw.proxyBillingCashReceipt.Adjustment_GL_Account__c;
        }
    }

    private void insertBillingCashReceipts(List<Billing_Cash_Receipt__c> billingCashReceipts,Set<Id> ppIds, Set<Id> crIds) {
        Map<Id,Payment_Processor__c> paymentProcessors = new Map<Id,Payment_Processor__c>(
            DomainUtils.getPaymentProcessorsById(ppIds));
        
        Map<Id,Cash_Receipt__c> namedCashReceipt = new Map<Id,Cash_Receipt__c>(
            DomainUtils.getCashReceiptById(crIds));

        List<String> errorsList = new List<String>();
        List<Database.SaveResult> results = SFDCSecurityUtils.insertCheckCRUDAndFLS(billingCashReceipts, new List<String>(),false);
        for (Integer index = 0; index < results.size(); index++) {
            Database.SaveResult result = results[index];
            if (!result.isSuccess()) {
                String errorMessage = '';
                if(paymentProcessors.get(namedCashReceipt.get(billingCashReceipts[index].Cash_Receipt__c).Payment_Processor__c) != null){
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED, 
                            new List<String>{
                                paymentProcessors.get(namedCashReceipt.get(billingCashReceipts[index].Cash_Receipt__c).Payment_Processor__c).Type__c,
                                namedCashReceipt.get(billingCashReceipts[index].Cash_Receipt__c).Payment_Reference__c,
                                StripeProcessorV1.composeErrorMsg(result),
                                namedCashReceipt.get(billingCashReceipts[index].Cash_Receipt__c).Name});
                }else{
                    errorMessage = String.format(Label.ERR_BILLING_CASH_RECEIPT_FAILED_WITH_PAYMENT_REFERENCE, 
                    new List<String>{
                        StripeProcessorV1.composeErrorMsg(result),
                        namedCashReceipt.get(billingCashReceipts[index].Cash_Receipt__c).Name});
                }
                errorsList.add(errorMessage);
            }
        }
        if(errorsList.size() > 0){
            throw new BillingPaymentReceiveException(String.join(errorsList,'</br>'));
        }
    }

    private void createPaymentRecords(List<BillingPaymentWrapper> bpws) {
        List<BillingPaymentWrapper> successfulPaymentWrappers = new List<BillingPaymentWrapper>();
        List<BillingPaymentWrapper> failedOnStripePaymentWrappers = new List<BillingPaymentWrapper>();
        for (BillingPaymentWrapper pw : bpws) {
            if (pw.theStatusCode == StatusCode.NO_ERRORS) {
                successfulPaymentWrappers.add(pw);
            }
            else if (pw.theStatusCode == StatusCode.STRIPE_ERROR) {
                failedOnStripePaymentWrappers.add(pw);
            }
        }

        if (!successfulPaymentWrappers.isEmpty()) {
            createNewPaymentMethods(successfulPaymentWrappers);
            createSuccessfulPaymentActivities(successfulPaymentWrappers);
        }

        if (!failedOnStripePaymentWrappers.isEmpty()) {
            createNewPaymentMethods(failedOnStripePaymentWrappers);
            createFailedPaymentActivities(failedOnStripePaymentWrappers);
        }
    }

    private void createSuccessfulPaymentActivities(List<BillingPaymentWrapper> bpws) {
        List<Payment_Activity__c> newPaymentActivities = new List<Payment_Activity__c>();
        try {
            for (BillingPaymentWrapper pw : bpws) {
                Payment_Activity__c newPaymentActivity = PaymentActivityHelper.createPaymentActivity(
                    pw.cashReceipt.Id,
                    pw.createdStripeCharge,
                    pw.pmProvider.getExistedPaymentMethodBySelectedSource().Id
                );
                newPaymentActivities.add(newPaymentActivity);
            }
            SFDCSecurityUtils.insertCheckCRUDAndFLS(newPaymentActivities, new List<String>{
                'Type__c',
                'Cash_Receipt__c'
            });
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void createFailedPaymentActivities(List<BillingPaymentWrapper> bpws) {
        List<Payment_Activity__c> newPaymentActivities = new List<Payment_Activity__c>();
        try {
            for (BillingPaymentWrapper pw : bpws) {
                Payment_Activity__c newPaymentActivity = PaymentActivityHelper.createPaymentActivity(
                    pw.pmProvider.getExistedPaymentMethodBySelectedSource().Id,
                    pw.cashReceipt.Amount__c,
                    pw.stripeErrorDetails
                );
                newPaymentActivities.add(newPaymentActivity);
            }
            SFDCSecurityUtils.insertCheckCRUDAndFLS(newPaymentActivities, new List<String>{
                'Type__c',
                'Cash_Receipt__c'
            });
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void createNewPaymentMethods(List<BillingPaymentWrapper> bpws) {
        try {
            List<Payment_Method__c> newPaymentMethods = new List<Payment_Method__c>();
            for (BillingPaymentWrapper pw : bpws) {
                if (pw.pmProvider.getExistedPaymentMethodBySelectedSource() == NULL) {
                    Payment_Method__c newPaymentMethod = PaymentMethodHelper.createPaymentMethod(pw.pmProvider);
                    pw.pmProvider.addExistedPM(newPaymentMethod);
                    newPaymentMethods.add(newPaymentMethod);
                }
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(newPaymentMethods, new List<String>{
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
        catch (Exception ex) {
            throw ex;
        }
    }

    public PageReference updateSuggestedDiscountAmount() {
        for (BillingPaymentWrapper bpw : wrappedBillings) {
            bpw.updateSuggestedDiscountAmount();
        }
        return NULL;
    }

    private void checkAccessOnSubmit() {
        SFDCSecurityUtils.checkInsert(Cash_Receipt__c.SObjectType, new List<String>{
                'Amount__c',
                'Account__c'
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

    public enum StatusCode {
        AMOUNT_ERROR,
        AMOUNT_ZERO_ERROR,
        CREATED,
        EXTERNAL_ERROR,
        NEGATIVE_AMOUNT_ERROR_MESSAGE,
        NO_ERRORS,
        NO_PROJECT_TASK,
        CRUD_FLS_ERROR,
        EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE,
        STRIPE_ERROR,
        INACTIVE_LEDGER_ERROR
    }

    public with sharing class CompositeKey {
        private String customerId;
        private String ledgerId;
        private String currencyIsoCode;

        public CompositeKey(String customerId, String ledgerId, String currencyIsoCode) {
            this.customerId = customerId;
            this.ledgerId = ledgerId;
            this.currencyIsoCode = currencyIsoCode;
        }

        public String getKeyString() {
            return this.customerId + this.ledgerId + this.currencyIsoCode;
        }

        public Boolean equals(Object obj) {
            if (obj instanceof CompositeKey) {
                CompositeKey extCompositeKey = (CompositeKey) obj;
                return getKeyString().equalsIgnoreCase(extCompositeKey.getKeyString());
            }
            return false;
        }

        public Integer hashCode() {
            return getKeyString().hashCode();
        }
    }

    public void updateSelectedProcessor() {
        for (BillingPaymentWrapper wrap : wrappedBillings) {
            wrap.pmProvider.updateSelectedPaymentMethod();
        }
        updateProcessorAndBankInformation();
    }

    private void updateProcessorAndBankInformation() {
        if (selectedTransactionType != STRIPE_PAYMENT_LABEL) {
            // method only applies to electronic transactions
            return;
        }

        Set<Id> selectedProcessorIds = new Set<Id>();
        for (BillingPaymentWrapper wrap : wrappedBillings) {
            if (wrap.pmProvider.selectedProcessorId != null) {
                selectedProcessorIds.add(wrap.pmProvider.selectedProcessorId);
            } 
        }

        List<Payment_Processor__c> processors = paymentProcessorUtils.getPaymentProcessors(selectedProcessorIds);
        Map<Id,Payment_Processor__c> processorsById = new Map<Id,Payment_Processor__c>(processors);
        for (BillingPaymentWrapper wrap : wrappedBillings) {
            Payment_Processor__c processor = processorsById.get(wrap.pmProvider.selectedProcessorId);
            if (processor != null) {
                wrap.isCardknoxTypeProcessor = processor?.Type__c == PaymentProcessorActions.CARDKNOX_TYPE;
                if (wrap.isCardknoxTypeProcessor) {
                    wrap.cashReceipt.Bank_Account__c = processor.Merchant_GL_Account__c;
                } else {
                    wrap.cashReceipt.Bank_Account__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(wrap.bills[0].Ledger__c).Default_Bank_Account__c;
                }
            }
        }
    }

    public with sharing class BillingPaymentWrapper implements Comparable {
        public Account customer {get; private set;}
        public List<Billing__c> bills {get; private set;}
        public Cash_Receipt__c cashReceipt {get; private set;}
        public Billing_Cash_Receipt__c proxyBillingCashReceipt {get; private set;}
        public PaymentMethodProvider pmProvider {get; private set;}
        public StripeService.StripeCharge createdStripeCharge {get; set;}
        public StripeService.StripeErrorDetails stripeErrorDetails {get; private set;}
        public String customerName {get; private set;}
        public Decimal totalAmount {get; private set;}
        public Decimal totalReceivedAmount {get; private set;}
        @TestVisible
        public Decimal totalBalance {get; private set;}
        public Accounting_Period__c currentAccountingPeriod {get; private set;}
        public StatusCode theStatusCode {get; private set;}
        public String errorMessage {get; private set;}
        public String currencyIsoCode {get; private set;}
        public Boolean isCardknoxTypeProcessor {get; private set;}

        public transient PaymentSaleItem saleItem;

        private Boolean isMultiCurrencyEnabled;
        private String stripeIdempotencyKey {get; private set;}
        private PaymentGateway gtwy;

        public Boolean isAccountingPeriodOpen {
            get {
                getCurrentAccountingPeriod();
                if (currentAccountingPeriod.Id != NULL
                        && AccountingPeriod.isPeriodOpen(currentAccountingPeriod, Billing_Cash_Receipt__c.sObjectType)) {

                    return true;
                }
                return false;
            }
            set;
        }

        public BillingPaymentWrapper(Account customer, List<Billing__c> bills, Boolean isMultiCurrencyEnabled, PaymentGateway gtwy) {
            this.isCardknoxTypeProcessor = false;
            this.customer = customer;
            this.bills = bills;
            this.customerName = customer.Name;
            this.isMultiCurrencyEnabled = isMultiCurrencyEnabled;
            this.currencyIsoCode =
                isMultiCurrencyEnabled ? (String) bills[0].get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            this.theStatusCode = StatusCode.NO_ERRORS;
            this.cashReceipt = getCashReceipt();
            getCurrentAccountingPeriod();
            getTotals();

            this.stripeIdempotencyKey = FinancialSuiteUtils.getUUID();
            this.gtwy = gtwy;
            this.pmProvider = new PaymentMethodProvider(customer, gtwy)
                .receiveStripeSources()
                .leaveAvailableForSelectionOnly()
                .bindWithSF()
                .createSelectOption();
            getProxyBCR();
        }

        public String getMessage() {
            String message = '';

            if (theStatusCode == StatusCode.CREATED) {
                message = '<span style="font-weight:bold;color:#390">' + Label.COMMON_CREATED + '<br/><a href="/' + cashReceipt.id + '" target="_blank">' + Label.COMMON_VIEW_RECORD + '</span>';
            }
            else if (theStatusCode == StatusCode.AMOUNT_ERROR) {
                message = Label.COMMON_CANNOT_BE_MORE_THAN + ': ' + totalBalance + '<br/>';
            }
            else if (theStatusCode == StatusCode.AMOUNT_ZERO_ERROR) {
                message = Label.COMMON_NOT_CREATED + '<br/>' + Label.ERR_PAYMENT_NOT_EQUAL_TO_0;
            }
            else if (theStatusCode == StatusCode.NEGATIVE_AMOUNT_ERROR_MESSAGE) {
                message = Label.COMMON_NOT_CREATED + '<br/>' + Label.ERR_NEGATIVE_AMOUNT_RECEIVED;
            }
            else if (theStatusCode == StatusCode.NO_PROJECT_TASK) {
                message = Label.COMMON_NOT_CREATED + '<br/>' + Label.ERR_PROJECT_TASK_REQUIRED;
            }
            else if (theStatusCode == StatusCode.EMPTY_ADJUSTMENT_ACCOUNT_ERROR_MESSAGE) {
                message = Label.COMMON_NOT_CREATED + '<br/>' + Label.INF_ADJUSTMENT_GL_ACCOUNT_REQ;
            }
            else if (theStatusCode == StatusCode.EXTERNAL_ERROR) {
                message = Label.COMMON_NOT_CREATED + ' - ' + Label.COMMON_EXCEPTION + '<br/>' + errorMessage + '';
            }
            else if (theStatusCode == StatusCode.STRIPE_ERROR) {
                message = Label.COMMON_NOT_CREATED + ' - ' + Label.COMMON_STRIPE_ERROR +': ' + '<br/>' + errorMessage;
            }
            return message;
        }

        private void getProxyBCR() {
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(bills[0].Ledger__c);
            proxyBillingCashReceipt = new Billing_Cash_Receipt__c();
            if (isMultiCurrencyEnabled) {
                proxyBillingCashReceipt.put('CurrencyIsoCode', this.currencyIsoCode);
            }
            proxyBillingCashReceipt.Adjustment_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT)?.GL_Account__c;
            proxyBillingCashReceipt.Adjustment_Amount__c = 0;//Discount/Adjustment Amount input field
            proxyBillingCashReceipt.Applied_Amount__c = 0;//Suggested Discount output fields

            if (!bills.isEmpty()) {
                proxyBillingCashReceipt.Applied_Date__c = bills[0].Discount_Due_Date__c;
                if (isDiscountEligible(bills[0])) {
                    proxyBillingCashReceipt.Applied_Amount__c = bills[0].Discount_Amount__c;
                }
            }
            cashReceipt.Amount__c = cashReceipt.Amount__c - proxyBillingCashReceipt.Adjustment_Amount__c;
        }

        public void updateSuggestedDiscountAmount() {
            if (proxyBillingCashReceipt != NULL && !bills.isEmpty()) {
                this.proxyBillingCashReceipt.Applied_Amount__c =
                    (isDiscountEligible(bills[0])) ? bills[0].Discount_Amount__c : 0;
            }
        }

        public Boolean isDiscountEligible(Billing__c bill) {
            return cashReceipt.Receipt_Date__c <= bill.Discount_Due_Date__c && bill.Discount_Amount__c > 0;
        }

        private Cash_Receipt__c getCashReceipt() {
            Cash_Receipt__c cr = new Cash_Receipt__c();
            Decimal paymentAmount = 0;
            for (Billing__c bill : bills) {
                paymentAmount += bill.Balance__c;
            }
            totalBalance = paymentAmount;
            if (isMultiCurrencyEnabled) {
                cr.put('CurrencyIsoCode', currencyIsoCode);
            }
            cr.Account__c = bills[0].Customer__c;
            cr.Ledger__c = bills[0].Ledger__c;
            cr.Amount__c = paymentAmount;
            cr.Receipt_Date__c = Date.today();
            cr.Purpose__c = 'Customer Receipt';
            cr.Accounting_Period__c =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today()).Id != NULL
                    ? AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today()).Id
                    : NULL;
            cr.Bank_Account__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(bills[0].Ledger__c).Default_Bank_Account__c;
            cr.GL_Account_Variable_1__c = bills[0].Customer__r.GL_Account_Variable_1__c;
            cr.GL_Account_Variable_2__c = bills[0].Customer__r.GL_Account_Variable_2__c;
            cr.GL_Account_Variable_3__c = bills[0].Customer__r.GL_Account_Variable_3__c;
            cr.GL_Account_Variable_4__c = bills[0].Customer__r.GL_Account_Variable_4__c;
            return cr;
        }

        public void getTotals() {
            Decimal total = 0;
            Decimal received = 0;
            for (Billing__c bill : bills) {
                total += bill.Total__c;
                received += bill.Received_Amount__c;
            }
            totalAmount = total;
            totalReceivedAmount = received;
        }

        private void getCurrentAccountingPeriod() {
            Map<Date, Accounting_Period__c> allPeriods = new Map<Date, Accounting_Period__c>();
            allPeriods.put(AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(cashReceipt.Receipt_Date__c).Start_Date__c,
                    AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(cashReceipt.Receipt_Date__c)
            );
            for (Billing__c bill : bills) {
                allPeriods.put(AccountingPeriodHandler.getInstance().getAccountingPeriodById(bill.Accounting_Period__c).Start_Date__c,
                        AccountingPeriodHandler.getInstance().getAccountingPeriodById(bill.Accounting_Period__c)
                );
            }
            List<Date> sortedDate = new List<Date> (allPeriods.keySet());
            sortedDate.sort();

            if (!allPeriods.keySet().isEmpty()) {
                currentAccountingPeriod = allPeriods.get(sortedDate[sortedDate.size() - 1]);
            }
        }

        private String getKeyString() {
            return this.customerName + bills[0].Ledger__c + currencyIsoCode;
        }

        public Integer compareTo(Object compareTo) {
            BillingPaymentWrapper extBPW = (BillingPaymentWrapper) compareTo;
            if (getKeyString() == extBPW.getKeyString()) {
                return 0;
            }
            if (getKeyString() > extBPW.getKeyString()) {
                return 1;
            }
            return -1;
        }

        public BillingPaymentWrapper saleItem(PaymentSaleItem saleItem) {
            this.saleItem = saleItem;
            return this;
        }
    }

}