public with sharing class BillingFromOpportunity extends AbstractBillingFromSource {
   
    private static final String NO_OPEN_PERIOD_ERROR_MESSAGE = Label.ERR_NO_ACCOUNTING_PERIOD_WITH_DATE;
    private static final String SUCCESS_MESSAGE = Label.INF_BILLING_CREATED;
    private static final String NO_SELECTED_ERROR_MESSAGE = Label.ERR_NO_QUALIFYING_RECORDS_SELECTED;
    @TestVisible
    private static final String CASH_RECEIPT_POSTING_ERROR = Label.ERR_CASH_RECEIPT_POSTING;

    @TestVisible
    private Boolean isNeedToPost;
    private Boolean isSingleRecord;
    private Boolean isProductDiscount;
    private Map<String, Bank_Deposit__c> deposits;
    private Map<Id, List<OpportunityLineItem>> opportunityMap;

    public Boolean showCommandButton {get; set;}
    public Boolean showOnlyMessages {get; private set;}
    public Boolean isCashSale {get; set;}
    public Boolean isDeposit {get; set;}
    public Boolean isLedgerReadMode {get; set;}
    public List<BillingOpportunityWrapper> billingsOpportunityWrappers {get; set;}
    public Map<Billing__c, List<Billing__c>> billingExistingBillingsMap {get; set;}

    public BillingFromOpportunity(ApexPages.StandardController controller) {
        try {
            isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();

            sourceRecords = AvaTaxHelper.queryOpportunityById(new Set<Id>{controller.getId()});

            if (isMultiCurrencyEnabled) {
                currencyIsoCode = (String) sourceRecords[0].get('CurrencyIsoCode');
            }

            isSingleRecord = true;
            showCommandButton = true;
            showOnlyMessages = false;
            isCashSale = false;
            isNeedToPost = false;
            isDeposit = false;
            isLedgerReadMode = false;
            combinedTaxRateByTaxGroupId = new Map<Id, Decimal>();
            validateAccountId();

            if (sourceRecords.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        dispatcher.getResults()[0].errors[0].message
                    )
                );
                showOnlyMessages = true;
                return;
            }
            singleRecordInit(LedgerHandler.getLedgerId());
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            showOnlyMessages = true;
        }
    }

    public BillingFromOpportunity(ApexPages.StandardSetController setController) {
        try {
            if (setController.getSelected().isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        NO_SELECTED_ERROR_MESSAGE
                    )
                );
                showOnlyMessages = true;
                return;
            }
            isSingleRecord = false;
            showCommandButton = true;
            showOnlyMessages = false;
            isCashSale = false;
            isNeedToPost = false;
            isDeposit = false;
            isLedgerReadMode = false;
            deposits = new Map<String, Bank_Deposit__c>();
            combinedTaxRateByTaxGroupId = new Map<Id, Decimal>();
            isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
            Set<Id> oppIds = new Map<Id, Opportunity>((List<Opportunity>) setController.getSelected()).keySet();
            sourceRecords = AvaTaxHelper.queryOpportunityById(oppIds);
            isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            if (isMultiCurrencyEnabled) {
                currencyIsoCode = (String) sourceRecords[0].get('CurrencyIsoCode');
            }
            setRecordsInit(LedgerHandler.getLedgerId());
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            showOnlyMessages = true;
        }
    }

    private void singleRecordInit(Id ledgerId) {
        setOpportunityLedgerMap(ledgerId);
        List<Billing__c> existingBillings = showWarningMessageIfThereAreExistedBillings(
            Schema.SObjectType.Billing__c.fields.Opportunity__c.getName(),
            new Set<Id>{sourceRecords[0].Id},
            Billing__c.getSObjectType(),
            true
        );
        Opportunity sourceOpportunity = (Opportunity) sourceRecords[0];
        Billing__c bill = new Billing__c(
            Customer__c = sourceOpportunity.AccountId,
            Ledger__c = ledgerId
        );
        isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(bill);
        isProductDiscount = DomainUtils.isDiscountIncludedInOpportunityLineItems(new Set<Id>{sourceOpportunity.Id});
        sourceRecordLines = queryOpportunityProducts(new Set<Id>{sourceOpportunity.Id});
        getOpportunityMap();
        newBillingLines = createNewBillingLines(sourceOpportunity, bill);
        if (isHeaderLevelPostEnabled && !isAvalaraTaxCalcEnabled) {
            setTaxAmount();
        }
        wrapLines(bill);
        populateRevenueGLAccount(ledgerId);
        billingsOpportunityWrappers = new List<BillingOpportunityWrapper>();
        billingsOpportunityWrappers.add(
            new BillingOpportunityWrapper(bill, sourceOpportunity, wrappedLines, existingBillings, ledgerId)
        );
        if (isAvalaraTaxCalcEnabled) {
            handleAvaTaxCalculation(false);
        }
        wrappedLines.sort();
    }

    private void setRecordsInit(Id ledgerId) {
        setOpportunityLedgerMap(ledgerId);
        isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(new Billing__c(Ledger__c = ledgerId));

        if (isAvalaraTaxCalcEnabled && sourceRecords.size() > AvaTaxHelper.AVALARA_SELECTED_RECORDS_LIMIT) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    AvaTaxHelper.AVALARA_SELECTED_RECORDS_LIMIT_EXCEEDED_ERROR_MESSAGE
                )
            );
            showOnlyMessages = true;
            return;
        }
        List<Billing__c> existingBillings = showWarningMessageIfThereAreExistedBillings(
            Schema.sObjectType.Billing__c.fields.Opportunity__c.getName(),
            (new Map<Id, Opportunity> ((List<Opportunity>) sourceRecords)).keySet(),
            Billing__c.getSObjectType(),
            false
        );

        sourceRecords.sort();
        isProductDiscount = DomainUtils.isDiscountIncludedInOpportunityLineItems(sourceRecords);
        sourceRecordLines = queryOpportunityProducts((new Map<Id, Opportunity> ((List<Opportunity>) sourceRecords)).keySet());
        getOpportunityMap();

        billingExistingBillingsMap = new Map<Billing__c, List<Billing__c>>();
        billingsOpportunityWrappers = new List<BillingOpportunityWrapper>();
        for (Opportunity op : (List<Opportunity>) sourceRecords) {
            Billing__c bill = new Billing__c(
                Customer__c = op.AccountId,
                Ledger__c = ledgerId
            );
            if (opportunityMap.get(op.Id) != NULL) {
                sourceRecordLines = opportunityMap.get(op.Id);
            }
            else {
                sourceRecordLines = new List<OpportunityLineItem>();
            }
            newBillingLines = createNewBillingLines(op, bill);
            if (isHeaderLevelPostEnabled && !isAvalaraTaxCalcEnabled) {
                setTaxAmount();
            }
            wrapLines(bill);
            populateRevenueGLAccount(ledgerId);
            billingExistingBillingsMap.put(bill, new List<Billing__c>());
            createDeposit(op);
            for (Billing__c existBill : existingBillings) {
                if (existBill.Opportunity__c == op.Id) {
                    List<Billing__c> temp = billingExistingBillingsMap.get(bill);
                    temp.add(existBill);
                    billingExistingBillingsMap.put(bill, temp);
                }
            }
            billingExistingBillingsMap.get(bill).sort();
            billingsOpportunityWrappers.add(
                new BillingOpportunityWrapper(bill, op, wrappedLines, billingExistingBillingsMap.get(bill), ledgerId)
            );
        }

        if (isAvalaraTaxCalcEnabled) {
            handleAvaTaxCalculation(false);
        }
    }

    private void setOpportunityLedgerMap(Id ledgerId) {
        Map<SObject, Id> oppBIdsBySObjects = new Map<SObject, Id>();
        for (Opportunity op : (List<Opportunity>) sourceRecords) {
            oppBIdsBySObjects.put(op, ledgerId);
        }
        TaxService.sobjectByLedgerId = oppBIdsBySObjects;
    }

    public List<SelectOption> getAllLedgers() {
        List<SelectOption> ledgerOptions = new List<SelectOption>();
        for (SelectOption option : LedgerHandler.getInstanceWithSharing(true).getTransactionalLedgerSelectOptions()) {
            if (LedgerHandler.getInstanceWithSharing(true).isActiveLedger(option.getValue())) {
                ledgerOptions.add(option);
            }
        }
        return ledgerOptions;
    }

    private void setTaxAmount() {
        if (!combinedTaxRateByTaxGroupId.isEmpty()) {
            HeaderLevelTaxHelper.calculateTaxAmountAndSetTaxGroup(newBillingLines, NULL);
        }
    }

    private void createDeposit(Opportunity opportunity) {
        if(isMultiCurrencyEnabled) {
            if (!deposits.containsKey((String) opportunity.get('CurrencyIsoCode'))) {
                Bank_Deposit__c newBankDeposit = new Bank_Deposit__c(
                    Deposit_Date__c = System.today(),
                    Amount__c = 0
                );
                newBankDeposit.put('CurrencyIsoCode', opportunity.get('CurrencyIsoCode'));
                deposits.put((String) opportunity.get('CurrencyIsoCode'), newBankDeposit);
            }
        }
        else {
            if (!deposits.containsKey('Default')) {
                Bank_Deposit__c newBankDeposit = new Bank_Deposit__c(
                    Deposit_Date__c = System.today(),
                    Amount__c = 0
                );
                deposits.put('Default', newBankDeposit);
            }
        }
    }

    private void getOpportunityMap() {
        opportunityMap = new Map<Id, List<OpportunityLineItem>>();
        if (!sourceRecordLines.isEmpty()) {
            for (OpportunityLineItem item : (List<OpportunityLineItem>) sourceRecordLines) {
                if (opportunityMap.containsKey(item.OpportunityId)) {
                    List<OpportunityLineItem> temp = opportunityMap.get(item.OpportunityId);
                    temp.add(item);
                    opportunityMap.put(item.OpportunityId, temp);
                }
                else {
                    opportunityMap.put(item.OpportunityId, new List<OpportunityLineItem>{item});

                }
            }
        }
    }

    private List<OpportunityLineItem> queryOpportunityProducts(Set<Id> ids) {
        List<OpportunityLineItem> result = new List<OpportunityLineItem>();
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'ServiceDate',
                'Quantity',
                'UnitPrice',
                'ListPrice',
                'Tax_Group__c',
                'Tax_Group__r.Combined_Tax_Rate__c',
                'OpportunityId',
                'PriceBookEntry.Product2Id',
                'PriceBookEntry.Product2.Name',
                'PriceBookEntry.Product2.ProductCode',
                'PriceBookEntry.Product2.Tax_Code__c',
                'PriceBookEntry.Product2.Description',
                'PriceBookEntry.Product2.Revenue_GL_Account__c',
                'PriceBookEntry.Product2.GL_Account_Variable_1__c',
                'PriceBookEntry.Product2.GL_Account_Variable_2__c',
                'PriceBookEntry.Product2.GL_Account_Variable_3__c',
                'PriceBookEntry.Product2.GL_Account_Variable_4__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Project__c',
                'Project_Task__c',
                'Description'
            };

            if (isProductDiscount) {
                queryFields.add('Discount');
            }
            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            //Add query condition
            String queryCondition = 'OpportunityId IN :ids';
            Set<Id> avataxProductIds;
            if (isAvalaraTaxCalcEnabled && isHeaderLevelPostEnabled) {
                avataxProductIds = AvaTaxHelper.getSalesTaxProductIds(sourceRecords);
                queryCondition += ' AND PriceBookEntry.Product2Id NOT IN :avataxProductIds';
            }

            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('OpportunityLineItem', 'SortOrder', SOQLBuilder.SortOrder.ASCENDING);

            SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering);

            result = (List<OpportunityLineItem>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    private List<Billing_Line__c> createNewBillingLines(Opportunity opportunity, Billing__c bill) {
        List<Billing_Line__c> result = new List<Billing_Line__c>();
        try {
            for (OpportunityLineItem eachOppLineItem : (List<OpportunityLineItem>) sourceRecordLines) {
                Billing_Line__c billLine = new Billing_Line__c();
                billLine.Opportunity_Product_Id__c = eachOppLineItem.Id;
                billLine.Project__c = eachOppLineItem.Project__c;
                billLine.Project_Task__c = eachOppLineItem.Project_Task__c;
                billLine.Date__c = (eachOppLineItem.ServiceDate != NULL ? eachOppLineItem.ServiceDate : opportunity.CloseDate);
                billLine.List_Price__c = eachOppLineItem.ListPrice;
                billLine.Tax_Group__c = eachOppLineItem.Tax_Group__c;

                billLine.Revenue_GL_Account__c =
                    (isAvalaraTaxCalcEnabled && !isHeaderLevelPostEnabled && eachOppLineItem.PriceBookEntry.Product2Id == AvaTaxHelper.getSalesTaxProductId(bill))
                        ? AvaTaxHelper.getAvaTaxGLAccount(bill)
                        : eachOppLineItem.PriceBookEntry.Product2.Revenue_GL_Account__c;

                billLine.Comment__c = eachOppLineItem.Description;

                billLine.GL_Account_Variable_1__c =
                    eachOppLineItem.GL_Account_Variable_1__c != NULL
                        ? eachOppLineItem.GL_Account_Variable_1__c
                        : eachOppLineItem.PriceBookEntry.Product2.GL_Account_Variable_1__c;

                billLine.GL_Account_Variable_2__c =
                    eachOppLineItem.GL_Account_Variable_2__c != NULL
                        ? eachOppLineItem.GL_Account_Variable_2__c
                        : eachOppLineItem.PriceBookEntry.Product2.GL_Account_Variable_2__c;

                billLine.GL_Account_Variable_3__c =
                    eachOppLineItem.GL_Account_Variable_3__c != NULL
                        ? eachOppLineItem.GL_Account_Variable_3__c
                        : eachOppLineItem.PriceBookEntry.Product2.GL_Account_Variable_3__c;

                billLine.GL_Account_Variable_4__c =
                    eachOppLineItem.GL_Account_Variable_4__c != NULL
                        ? eachOppLineItem.GL_Account_Variable_4__c
                        : eachOppLineItem.PriceBookEntry.Product2.GL_Account_Variable_4__c;

                billLine.Product__c = eachOppLineItem.PriceBookEntry.Product2Id;
                billLine.Product__r = eachOppLineItem.PriceBookEntry.Product2;
                billLine.Hours_Units__c = eachOppLineItem.Quantity;
                billLine.Rate__c =
                    eachOppLineItem.UnitPrice * (isProductDiscount && eachOppLineItem.Discount != NULL
                                                    ? (100 - eachOppLineItem.Discount) / 100
                                                    : 1);

                result.add(billLine);
                if (eachOppLineItem.Tax_Group__c != NULL) {
                    combinedTaxRateByTaxGroupId.put(eachOppLineItem.Tax_Group__c, eachOppLineItem.Tax_Group__r.Combined_Tax_Rate__c);
                }
            }

            if (result.isEmpty()) {
                Billing_Line__c billLine = new Billing_Line__c();
                billLine.Date__c = opportunity.CloseDate;
                billLine.Hours_Units__c = 1;
                billLine.Rate__c = opportunity.Amount != NULL ? opportunity.Amount : 0;
                result.add(billLine);
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    public PageReference createBilling() {
        try {
            createBillings();
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            return NULL;
        }
        if (!isSingleRecord) {
            return NULL;
        }
        else {
            return new PageReference('/' + billingsOpportunityWrappers[0].bill.Id);
        }
    }

    public PageReference createBillingAndPost() {
        try {
            isNeedToPost = true;
            createBillings();
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            return NULL;
        }
        if (!isSingleRecord) {
            return NULL;
        }
        else {
            return new PageReference('/' + billingsOpportunityWrappers[0].bill.Id);
        }
    }

    public override void createBillings() {
        if (isAvalaraTaxCalcEnabled) {
            handleAvaTaxCalculation(isSingleRecord);
        }

        List<BillingOpportunityWrapper> insertList = new List<BillingOpportunityWrapper>();
        Savepoint sp = (Test.isRunningTest() && isAvalaraTaxCalcEnabled) ? NULL : Database.setSavepoint();
        try {
            for (BillingOpportunityWrapper wrapBill : billingsOpportunityWrappers) {
                if (wrapBill.theStatusCode == StatusCode.CREATED
                        || wrapBill.theStatusCode == StatusCode.ACCOUNT_ERROR
                        || wrapBill.theStatusCode == StatusCode.TAX_CALCULATION_ERROR) {

                    continue;
                }
                if (isCashSale || isNeedToPost) {
                    wrapBill.bill.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                }
                if (!isSingleRecord) {
                    wrapBill.bill.Ledger__c = billingsOpportunityWrappers[0].bill.Ledger__c;
                }
                newBillings = new List<Billing__c>{wrapBill.bill};
                wrappedLines = wrapBill.billLines;
                unwrapLines();
                validateAccountingPeriod(Schema.SObjectType.Billing__c.fields.Opportunity__c.getName());
                if (!newBillings.isEmpty()) {
                    if (!newBillingLines.isEmpty()) {
                        wrapBill.selectedBillLines = newBillingLines;
                        insertList.add(wrapBill);
                    }
                    else {
                        if (isSingleRecord) {
                            throw new CreateFromSourceException(NO_RBLINES_SELECTED_ERROR);
                        }
                    }
                }
                else {
                    if (isSingleRecord) {
                        throw new CreateFromSourceException(dispatcher.getResults()[0].errors[0].message);
                    }
                    else {
                        wrapBill.theStatusCode = StatusCode.ACCOUNTING_PERIOD_ERROR;
                        wrapBill.bill.Date__c.addError(NO_OPEN_PERIOD_ERROR_MESSAGE);
                    }
                }
            }

            List<Billing__c> insertBillingList = new List<Billing__c>();
            for (BillingOpportunityWrapper wrapBill : insertList) {
                insertBillingList.add(wrapBill.bill);
            }

            if (!insertBillingList.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(insertBillingList, new List<String>{
                    'Opportunity__c',
                    'Billing_Comment__c'
                });
            }

            List<Billing_Line__c> insertBillingLines = new List<Billing_Line__c>();
            for (BillingOpportunityWrapper wrapBill : insertList) {
                wrapBill.populateLineId();
                insertBillingLines.addAll(wrapBill.selectedBillLines);
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(insertBillingLines, new List<String>{
                'Opportunity_Product_Id__c',
                'Project__c',
                'Project_Task__c',
                'List_Price__c',
                'Revenue_GL_Account__c',
                'Comment__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c',
                'Product__c'
            });

            if (isCashSale) {
                if (isDeposit) {
                    setDepositDateRecentBillDate(insertBillingList);
                    if (deposits.values()[0].Id == NULL && !insertBillingList.isEmpty()) {
                        for (Bank_Deposit__c deposit : deposits.values()) {
                            deposit.Ledger__c = billingsOpportunityWrappers[0].bill.Ledger__c;
                            deposit.Bank_Account__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(deposit.Ledger__c).Default_Bank_Account__c;
                        }
                        SFDCSecurityUtils.insertCheckCRUDAndFLS(deposits.values(), new List<String>{
                            'Ledger__c',
                            'Bank_Account__c',
                            'Amount__c',
                            'Deposit_Date__c'
                        });
                    }
                    for (BillingOpportunityWrapper wrapBill : insertList) {
                        if (isMultiCurrencyEnabled) {
                            deposits.get((String) wrapBill.opportunity.get('CurrencyIsoCode')).Amount__c += wrapBill.getTotalAmount();
                        }
                        else {
                            deposits.get('Default').Amount__c += wrapBill.getTotalAmount();
                        }
                    }
                    if (deposits.values()[0].Id != NULL) {
                        TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Amount__c);
                        SFDCSecurityUtils.updateCheckCRUDAndFLS(deposits.values(), new List<String>{'Amount__c'});
                    }
                }

                List<Cash_Receipt__c> insertCashReceipts = new List<Cash_Receipt__c>();
                insertList = getBillingNames(insertList);
                for (BillingOpportunityWrapper wrapBill : insertList) {
                    wrapBill.cashReceipt = createCashReceipt(
                        wrapBill.bill,
                        wrapBill.opportunity.AccountId,
                        isMultiCurrencyEnabled
                    );
                    insertCashReceipts.add(wrapBill.cashReceipt);
                }

                SFDCSecurityUtils.insertCheckCRUDAndFLS(insertCashReceipts, new List<String>{
                    'Accounting_Period__c',
                    'Purpose__c'
                });

                if (isDeposit) {
                    //first we must be sure that Cash Receipts are Posted before associate them with Bank Deposit
                    if (!AccountingSettingsHandler.isAutoPostCashReceiptsEnabled()) {
                        AbstractPostHandler postHandler = new CashReceiptPostHandler();
                        postHandler.post(insertCashReceipts);
                        if (postHandler.dispatcher.getErrorResultsQuantity() > 0) {
                            throw new AbstractPostHandler.PostHandlerException(CASH_RECEIPT_POSTING_ERROR);
                        }
                    }

                    for (Cash_Receipt__c receipt : insertCashReceipts) {
                        if (isMultiCurrencyEnabled) {
                            receipt.Bank_Deposit__c = deposits.get((String) receipt.get('CurrencyIsoCode')).Id;
                        }
                        else {
                            receipt.Bank_Deposit__c = deposits.get('Default').Id;
                        }
                    }

                    TriggerObserver.getInstance().unlockFields(
                        new Set<SObjectField>{
                            Cash_Receipt__c.Bank_Deposit__c,
                            Cash_Receipt__c.Status__c
                        }
                    );
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(insertCashReceipts, new List<String>{
                        'Bank_Deposit__c'
                    });
                }
                List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();

                for (BillingOpportunityWrapper wrapBill : insertList) {
                    wrapBill.billingCashReceipt = createBillingCashReceipt(wrapBill.cashReceipt, wrapBill.bill, isMultiCurrencyEnabled);
                    billingCashReceipts.add(wrapBill.billingCashReceipt);
                }
                SFDCSecurityUtils.insertProxy(billingCashReceipts);
            }

            if (isNeedToPost) {
                AbstractPostHandler postHandler = new BillingPostHandler();
                AsyncPostHandlersExecutor asyncPHExecutor = new AsyncPostHandlersExecutor(insertBillingList, postHandler);
                System.enqueueJob(asyncPHExecutor);
            }
            else {//if Not Posted Billings were created
                //===================================================================
                //Make call to the Avalara side to create "Uncommitted" Tax transactions
                if (!Test.isRunningTest() && isAvalaraTaxCalcEnabled) {
                    AvaTaxHelper.asyncCreateTransaction(insertBillingList, false);
                }
                //==================================================================
            }

            for (BillingOpportunityWrapper wrapBill : insertList) {
                wrapBill.theStatusCode = StatusCode.CREATED;
                isLedgerReadMode = true;
            }
            for (Integer i = 0; i < billingsOpportunityWrappers.size(); i++) {
                if (billingsOpportunityWrappers[i].theStatusCode != StatusCode.CREATED) {
                    break;
                }
                if (i == billingsOpportunityWrappers.size() - 1) {
                    showCommandButton = false;
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, SUCCESS_MESSAGE));
                }
            }
        }
        catch (Exception ex) {
            if (!(Test.isRunningTest() && isAvalaraTaxCalcEnabled)) {
                Database.rollback(sp);
            }
            for (BillingOpportunityWrapper wrapBill : billingsOpportunityWrappers) {
                if (wrapBill.theStatusCode != StatusCode.CREATED) {
                    wrapBill.cashReceipt = NULL;
                    wrapBill.billingCashReceipt = NULL;
                    wrapBill.bill.Id = NULL;
                    wrapBill.clearLineId();
                }
            }
            throw ex;
        }
    }

    private void setDepositDateRecentBillDate(List<Billing__c> billings) {
        if (isMultiCurrencyEnabled) {
            Map<String, List<Billing__c>> billingCurrencyMap = new Map<String, List<Billing__c>>();
            for (Billing__c bill : billings) {
                if (billingCurrencyMap.containsKey((String) bill.get('CurrencyIsoCode'))) {
                    billingCurrencyMap.get((String) bill.get('CurrencyIsoCode')).add(bill);
                }
                else {
                    billingCurrencyMap.put((String) bill.get('CurrencyIsoCode'), new List<Billing__c> {bill});
                }
            }
            for (String currencyCode : billingCurrencyMap.keySet()) {
                setDepositDate(
                        new List<Bank_Deposit__c> {deposits.get(currencyCode)},
                        getRecentDate(billingCurrencyMap.get(currencyCode))
                );
            }
        }
        else {
            setDepositDate(deposits.values(), getRecentDate(billings));
        }

    }

    private Date getRecentDate (List<Billing__c> billings) {
        Date recentDate;
        for (Billing__c bill : billings) {
            if (recentDate == NULL || bill.Date__c > recentDate) {
                recentDate = bill.Date__c;
            }
        }
        return recentDate;
    }

    private void setDepositDate (List<Bank_Deposit__c> deposits, Date recentDate) {
        for (Bank_Deposit__c deposit : deposits) {
            if (deposit.Deposit_Date__c < recentDate) {
                deposit.Deposit_Date__c = recentDate;
            }
        }
    }

    private List<BillingOpportunityWrapper> getBillingNames(List<BillingOpportunityWrapper> billingOpportunityWrappers) {
        Set<Id> ids = new Set<Id>();
        for (BillingOpportunityWrapper bow : billingOpportunityWrappers) {
            ids.add(bow.bill.Id);
        }
        Map<Id, Billing__c> billingMap = new Map<Id, Billing__c>(queryBillingByIds(ids));
        for (BillingOpportunityWrapper bow : billingOpportunityWrappers) {
            bow.bill = billingMap.get(bow.bill.Id);
        }
        return billingOpportunityWrappers;
    }

    @TestVisible
    private void populateCurrencyConversionRate() {
        if (isMultiCurrencyEnabled
                && LedgerHandler.isUSDLedger(billingsOpportunityWrappers[0].bill.Ledger__c)) {

            List<Billing__c> billList = new List<Billing__c>();
            for (BillingOpportunityWrapper billOppWrapper : billingsOpportunityWrappers) {
                billList.add(billOppWrapper.bill);
            }

            MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(NULL, billList, 'Date__c');

            for (BillingOpportunityWrapper billOppWrapper : billingsOpportunityWrappers) {
                billOppWrapper.setCurrencyConversionRate(
                    billOppWrapper.bill.Currency_Conversion_Rate__c
                );
            }
        }
    }

    private void handleAvaTaxCalculation(Boolean doRefreshProduct) {
        try {
            populateCurrencyConversionRate();
        }
        catch (Exception ex) {
            throw ex;
        }

        for (BillingOpportunityWrapper billOppWrapper : billingsOpportunityWrappers) {
            try {
                if (doRefreshProduct) {
                    billOppWrapper.refreshProducts();
                }

                Boolean isTaxableByCurrency =
                    isMultiCurrencyEnabled
                        ? LedgerHandler.isUSDLedger(billOppWrapper.bill.Ledger__c)
                        : true;

                if (!isTaxableByCurrency || !billOppWrapper.taxableLineExists(billOppWrapper.bill)) {
                    //Header Level Post Mode -> clear Tax Amount field
                    if (isHeaderLevelPostEnabled) {
                        billOppWrapper.clearTaxAmount();
                    }//Line Level Post mode -> remove existed Sales Tax Line
                    else {
                        //skip Sales Tax Line creation
                        billOppWrapper.removeOldSalesTaxLine();
                        wrappedLines = billOppWrapper.billLines;
                    }
                }

                //If record is taxable calculate Taxes depending on current Post Settings mode (LLP or HLP)
                if (isTaxableByCurrency && billOppWrapper.taxableLineExists(billOppWrapper.bill)) {
                    AvaTaxService.CreateTransactionModel request = billOppWrapper.getCreateTransactionModel();
                    AvaTaxHelper.sourceRecord = billOppWrapper.bill;
                    AvaTaxService.TransactionModel response = AvaTaxHelper.calcTax(request);
                    if (isHeaderLevelPostEnabled) {
                        billOppWrapper.updateTaxAmount(response);
                    }
                    else {
                        billOppWrapper.upsertSalesTaxLine(response);
                        wrappedLines = billOppWrapper.billLines;
                    }
                }
            }
            catch (Exception ex) {
                if (isSingleRecord) {
                    throw ex;
                }
                else {
                    billOppWrapper.theStatusCode = BillingFromOpportunity.StatusCode.TAX_CALCULATION_ERROR;
                    billOppWrapper.errorMessage = ex.getMessage();
                }
            }
        }
    }

    public pageReference selectLedger() {
        try {
            if (isSingleRecord) {
                singleRecordInit(billingsOpportunityWrappers[0].bill.Ledger__c);
            }
            else {
                setRecordsInit(billingsOpportunityWrappers[0].bill.Ledger__c);
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            showOnlyMessages = false;
        }
        return null;
    }

    public enum StatusCode {
        ACCOUNTING_PERIOD_ERROR,
        CREATED,
        EXTERNAL_ERROR,
        NO_ERRORS,
        OPPORTUNITY_ERROR,
        ACCOUNT_ERROR,
        TAX_CALCULATION_ERROR
    }

    public with sharing class BillingOpportunityWrapper {
        private Decimal currencyConversionRate;

        public Billing__c bill {get; set;}
        public Cash_Receipt__c cashReceipt {get; set;}
        public Billing_Cash_Receipt__c billingCashReceipt {get; set;}
        public Opportunity opportunity {get; set;}
        public List<BillingLineWrapper> billLines {get; set;}
        public StatusCode theStatusCode {get; set;}
        public String errorMessage {get; set;}
        public List<Billing__c> existingBills {get; set;}
        public List<Billing_Line__c> selectedBillLines {get; set;}
        public Boolean showLine {get; set;}
        public String taxMethod {get; set;}
        public Boolean isTaxMethodError {get; set;}
        private Boolean isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();
        private Boolean isAvaTaxMode;
        @TestVisible
        private Map<String, Billing_Line__c> billingLineMappedByOppLineItemId = new Map<String, Billing_Line__c>();

        BillingOpportunityWrapper(Billing__c bill, Opportunity opportunity, List<BillingLineWrapper> billLines, List<Billing__c> existingBills, Id ledgerId) {
            this.bill = bill;
            this.bill.Ledger__c = ledgerId;
            isAvaTaxMode = AvaTaxHelper.isAvalaraTaxCalculationEnabled(this.bill);
            taxMethod = new NativeTaxHeaderLevel().getTaxMethod(this.bill);
            isTaxMethodError = taxMethod == null ? true : false;

            if (this.bill != null) {
                if(AccountingSettingsHandler.getAccountingSettings().Set_Billing_Date_To_Current_Date__c) {
                    this.bill.Date__c = Date.today();
                } else {
                    this.bill.Date__c = opportunity.closeDate;
                }
            }
            this.opportunity = opportunity;
            setZeroOpportunityAmount();
            this.billLines = billLines;
            if (this.billLines != null && AccountingSettingsHandler.getAccountingSettings().Set_Billing_Date_To_Current_Date__c) {
                for (BillingLineWrapper billLine : this.billLines) {
                    billLine.billingLineRec.Date__c = Date.today();
                }
            }
            this.existingBills = existingBills.isEmpty() ? existingBills : new List<Billing__c> {existingBills[existingBills.size()-1]};
            this.theStatusCode = StatusCode.NO_ERRORS;
            this.selectedBillLines = new List<Billing_Line__c>();
            this.showLine = true;
            this.currencyConversionRate = 1.0;//default value, must be updated before Billing creation
            setMultiCurrency();
            bindBillingOpportunity();
            validateAccount();
        }

        public void setCurrencyConversionRate(Decimal value) {
            this.currencyConversionRate = value;
        }

        public Decimal getCurrencyConversionRate() {
            return currencyConversionRate;
        }

        //total amount based on all billing lines
        //used in case of batch processing
        public Decimal getTotalAmount() {
            Decimal result = 0;
            for (BillingLineWrapper billLine : billLines) {
                Decimal total = billLine.billingLineRec.Hours_Units__c * billLine.billingLineRec.Rate__c;
                if (this.isHlpMode) {
                    if (this.isAvaTaxMode) {
                        total = total + ((billLine.billingLineRec.Tax_Amount2__c != NULL) ? billLine.billingLineRec.Tax_Amount2__c : 0);
                    }
                    else if (billLine.taxRate != NULL) {
                        total = total + (total * billLine.taxRate);
                    }
                }
                result += total;
            }
            return result.setScale(2, System.RoundingMode.HALF_UP);
        }

        public Boolean taxableLineExists(Billing__c bill) {
            for (BillingLineWrapper billLine : billLines) {
                if (billLine.isSelected && AvaTaxHelper.validateBillingLineIsTaxable(billLine.billingLineRec, bill)) {
                    return true;
                }
            }
            return false;
        }

        public void refreshProducts() {
            Set<Id> productIds = new Set<Id>();
            for (BillingLineWrapper billLine : billLines) {
                if (billLine.billingLineRec.Product__c != NULL) {
                    productIds.add(billLine.billingLineRec.Product__c);
                }
            }

            Map<Id, Product2> productMap = new Map<Id, Product2>(
                DomainUtils.getProductsById(productIds)
            );

            for (BillingLineWrapper billLine : billLines) {
                if (billLine.billingLineRec.Product__c != NULL) {
                    billLine.billingLineRec.Product__r = productMap.get(billLine.billingLineRec.Product__c);
                }
            }
        }

        public BillingLineWrapper removeOldSalesTaxLine() {
            List<BillingLineWrapper> newLineCollection = new List<BillingLineWrapper>();
            BillingLineWrapper result;
            for (BillingLineWrapper billLine : billLines) {
                if (!billLine.isAvalaraSalesTax) {
                    newLineCollection.add(billLine);
                }
                else {
                    result = billLine;
                }
            }

            billLines = newLineCollection;
            return result;
        }

        public void upsertSalesTaxLine(AvaTaxService.TransactionModel avaTaxTransaction) {
            BillingLineWrapper oldSalesTaxLine = removeOldSalesTaxLine();

            Billing_Line__c newSalesTaxLine = new Billing_Line__c();
            newSalesTaxLine.Date__c = avaTaxTransaction.avaTaxDate;
            newSalesTaxLine.Revenue_GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(bill);
            newSalesTaxLine.Product__c = AvaTaxHelper.getSalesTaxProductId(bill);
            newSalesTaxLine.Hours_Units__c = 1;
            newSalesTaxLine.Rate__c = avaTaxTransaction.totalTax * getCurrencyConversionRate();
            newSalesTaxLine.List_Price__c = 0;
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                newSalesTaxLine.put('CurrencyIsoCode', opportunity.get('CurrencyIsoCode'));
            }

            if (oldSalesTaxLine != NULL) {
                newSalesTaxLine.Project__c = oldSalesTaxLine.billingLineRec.Project__c;
                newSalesTaxLine.Project_Task__c = oldSalesTaxLine.billingLineRec.Project_Task__c;
                newSalesTaxLine.GL_Account_Variable_1__c = oldSalesTaxLine.billingLineRec.GL_Account_Variable_1__c;
                newSalesTaxLine.GL_Account_Variable_2__c = oldSalesTaxLine.billingLineRec.GL_Account_Variable_2__c;
                newSalesTaxLine.GL_Account_Variable_3__c = oldSalesTaxLine.billingLineRec.GL_Account_Variable_3__c;
                newSalesTaxLine.GL_Account_Variable_4__c = oldSalesTaxLine.billingLineRec.GL_Account_Variable_4__c;
            }

            billLines.add(new BillingLineWrapper(newSalesTaxLine, bill));
        }

        public void clearTaxAmount() {
            for (BillingLineWrapper billLine : billLines) {
                billLine.billingLineRec.Tax_Amount2__c = NULL;
            }
        }

        public void updateTaxAmount(AvaTaxService.TransactionModel avaTaxTransaction) {
            AvaTaxHelper.populateTaxAmountOnVirtualLines(avaTaxTransaction, billingLineMappedByOppLineItemId, getCurrencyConversionRate());
            for (BillingLineWrapper billLine : billLines) {
                if (billingLineMappedByOppLineItemId.containsKey(billLine.billingLineRec.Opportunity_Product_Id__c)) {
                    billLine.billingLineRec = billingLineMappedByOppLineItemId.get(billLine.billingLineRec.Opportunity_Product_Id__c);
                }
            }
        }

        public AvaTaxService.CreateTransactionModel getCreateTransactionModel() {
            billingLineMappedByOppLineItemId.clear();
            AvaTaxService.CreateTransactionModel result = new AvaTaxService.CreateTransactionModel();
            result.companyCode = AvaTaxHelper.getCompanyCode(bill);
            result.type = AvaTaxService.DocumentType.SalesOrder;
            result.avaTaxDate = bill.Date__c;
            result.customerCode = bill.Customer__c;
            result.businessIdentificationNo = opportunity.Account.VAT_Business_Identification_Number__c;
            result.entityUseCode = opportunity.Account.Entity_Use_Code__c;
            result.exemptionNo = opportunity.Account.Exemption_Number__c;
            result.addresses = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(this.opportunity, bill), AvaTaxHelper.getDestinationAddressInfo(this.opportunity), bill);
            result.currencyCode = 'USD';//currently we support only USD

            result.lines = getLines(bill);

            result.doCommit = false;

            return result;
        }

        private List<AvaTaxService.LineItemModel> getLines(Billing__c bill) {
            List<AvaTaxService.LineItemModel> result = new List<AvaTaxService.LineItemModel>();
            for (BillingLineWrapper billLine : billLines) {
                if (billLine.isSelected && AvaTaxHelper.validateBillingLineIsTaxable(billLine.billingLineRec, bill)) {
                    //map all Billing Lines by source Opportunity Product Line b/c they do not have ID yet
                    String uniqKey = billLine.billingLineRec.Opportunity_Product_Id__c;
                    billingLineMappedByOppLineItemId.put(uniqKey, billLine.billingLineRec);
                    //include only Taxable Line into request data
                    AvaTaxService.LineItemModel tempLine = new AvaTaxService.LineItemModel();
                    tempLine.avaTaxNumber = uniqKey;
                    tempLine.amount = (billLine.billingLineRec.Hours_Units__c * billLine.billingLineRec.Rate__c) / getCurrencyConversionRate();
                    tempLine.quantity = Math.abs(billLine.billingLineRec.Hours_Units__c);
                    AvaTaxHelper.putItemCodeOnLine(tempLine, billLine.billingLineRec.Product__r);
                    tempLine.description = billLine.billingLineRec.Product__r.Description;
                    result.add(tempLine);
                }
            }
            return result;
        }

        private void setZeroOpportunityAmount() {
            if (opportunity.Amount == NULL) {
                opportunity.Amount = 0;
            }
        }

        public void populateLineId() {
            if (bill.Id != NULL) {
                for (Billing_Line__c line : selectedBillLines) {
                    line.Billing__c = bill.Id;
                }
            }
        }

        public void clearLineId() {
            for (Billing_Line__c line : selectedBillLines) {
                line.Billing__c = NULL;
            }
        }

        private void validateAccount() {
            if (opportunity.AccountId == NULL) {
                theStatusCode = StatusCode.ACCOUNT_ERROR;
                showLine = false;
            }
        }

        private void setMultiCurrency() {
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                bill.put('CurrencyIsoCode', opportunity.get('CurrencyIsoCode'));
                for (BillingLineWrapper billLine : billLines) {
                    billLine.billingLineRec.put('CurrencyIsoCode', opportunity.get('CurrencyIsoCode'));
                }
            }
        }

        private void bindBillingOpportunity() {
            bill.Opportunity__c = opportunity.Id;
            bill.Billing_Comment__c = opportunity.Description;
        }

        public String getMessage() {
            String message = '';

            if (theStatusCode == StatusCode.CREATED) {
                message = '<span style="font-weight:bold;color:#390">' + Label.COMMON_CREATED + '<br/><a href="/' + bill.id + '" target="_blank">' + Label.COMMON_VIEW_RECORD + '</span>';
            }
            else if (theStatusCode == StatusCode.ACCOUNTING_PERIOD_ERROR) {
                message = '' + BillingFromOpportunity.NO_OPEN_PERIOD_ERROR_MESSAGE.escapeHtml4() + '<br/>';
            }
            else if (theStatusCode == StatusCode.OPPORTUNITY_ERROR) {
                message = Label.COMMON_NOT_CREATED + '<br/>' + Label.COMMON_OPPORTUNITY_CLOSED_WON;
            }
            else if (theStatusCode == StatusCode.ACCOUNT_ERROR) {
                message = Label.COMMON_OPPORTUNITY_ASSOCIATED + '<br/>' + Label.INF_WITH_ACCT_CREATE_BILLING;
            }
            else if (theStatusCode == StatusCode.EXTERNAL_ERROR) {
                message = Label.COMMON_NOT_CREATED + ' - ' + Label.COMMON_EXCEPTION + '<br/>' + errorMessage.escapeHtml4() + '';
            }
            else if (theStatusCode == StatusCode.TAX_CALCULATION_ERROR) {
                message = Label.COMMON_NOT_CREATED + ' - ' + Label.ERR_TAX_CALCULATION_EXCEPTION + '<br/>' + errorMessage.escapeHtml4() + '';
            }
            return message;
        }
    }
}