public with sharing class RecurringBillingFromOpportunity {

    @TestVisible
    private static final String NO_ACCOUNT_ERROR =
        Label.ERR_NO_ACCOUNT;
    @TestVisible
    private static final String NO_RB_LINES_SELECTED_ERROR = Label.ERR_NO_RB_LINES_SELECTED;
    @TestVisible
    private static final String HEADER_RATE_LABEL = Label.COMMON_PRICE;
    @TestVisible
    private static final String RECURRING_BILLING_EXISTS_WARNING =
        Label.ERR_RECURRING_BILLING_EXISTS;
    @TestVisible
    private static final String ACCOUNTING_PERIOD_DOES_NOT_EXIST_ERROR =
        Label.ERR_ACCOUNTING_PERIOD_DOES_NOT_EXIST_OPPORTUNITY;

    @TestVisible
    private Boolean isProductDiscount;
    private List<Recurring_Billing_Line__c> recurringBillingLines;
    private Opportunity sourceRecord;
    public Boolean isHeaderLevelPostEnabled {get; set;}
    public Boolean isError {get; private set;}
    public Boolean isExistingRBill {get; private set;}
    public Boolean showOnlyMessages {get; private set;}
    public Boolean createInitialBilling {get; set;}
    public Boolean isMultiCurrencyEnabled {get ;set;}
    public Boolean isAvalaraTaxCalcEnabled {get ;set;}
    public RecurringBillingWrapper mainDTO {get; set;}
    public String nexDateConst {get; set;}
    public String currencyIsoCode {get; set;}
    public String nextDateFormatted{get; private set;}

    public String getHEADER_RATE_LABEL() {
        return HEADER_RATE_LABEL;
    }

    public RecurringBillingFromOpportunity(ApexPages.StandardController controller) {
        createInitialBilling = false;
        try {
            isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
            //check if there are some Opp Products with Discount
            isProductDiscount = DomainUtils.isDiscountIncludedInOpportunityLineItems(new Set<Id>{controller.getId()});
            recurringBillingLines = new List<Recurring_Billing_Line__c>();
            //Query Opportunity with Opportunity Line Items
            sourceRecord = queryOpportunity((String) controller.getId());
            if (isMultiCurrencyEnabled) {
                currencyIsoCode = (String) sourceRecord.get('CurrencyIsoCode');
            }
            if (sourceRecord.AccountId == NULL) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_ACCOUNT_ERROR));
                isError = true;
                showOnlyMessages = true;
                return;
            }
            if (isRecurringBillingExists(sourceRecord.Id)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.WARNING, RECURRING_BILLING_EXISTS_WARNING));
                isError = true;
            }

            wrapperInit(LedgerHandler.getLedgerId());
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isError = true;
            showOnlyMessages = true;
        }
    }

    private void wrapperInit(Id ledgerId) {
        //Determine the next Date
        Boolean setBillingDateToCurrentDate = AccountingSettingsHandler.getAccountingSettings().Set_Billing_Date_To_Current_Date__c;
        Date nextDateToSet = setBillingDateToCurrentDate ? Date.today() : sourceRecord.CloseDate;

        nextDateFormatted = String.valueOf(nextDateToSet.format());
        nexDateConst = String.valueOf(nextDateToSet);

        //Create Recurring Billing
        Recurring_Billing__c rBill = new Recurring_Billing__c(
            Opportunity__c = sourceRecord.Id,
            Name = sourceRecord.Name,
            Customer__c = sourceRecord.AccountId,
            Status__c = 'Active',
            Next_Billing_Date__c = nextDateToSet,
            Ledger__c = ledgerId,
            Billing_Frequency__c = 'Monthly'
        );

        isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(rBill);

        if (isMultiCurrencyEnabled) {
            rBill.put('CurrencyIsoCode', currencyIsoCode);
        }
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
        //Create new Recurring Billing Lines based on existed Opportunity Line Items (or just empty line )
        //and wrap them
        List<RecurringBillingLineWrapper> wrappedLines = new List<RecurringBillingLineWrapper>();
        for (OpportunityLineItem oli : sourceRecord.OpportunityLineItems) {
            Recurring_Billing_Line__c rBillLine = new Recurring_Billing_Line__c();
            rBillLine.Opportunity_Product_Id__c = oli.Id;
            rBillLine.List_Price__c = oli.ListPrice;
            rBillLine.Date__c = setBillingDateToCurrentDate ?
                Date.today() :
                (oli.ServiceDate != NULL ? oli.ServiceDate : sourceRecord.CloseDate);
            rBillLine.Quantity__c = oli.Quantity;
            rBillLine.Rate__c =
                oli.UnitPrice * (isProductDiscount && oli.Discount != NULL ? (100 - oli.Discount) / 100 : 1);

            rBillLine.Revenue_GL_Account__c =
                (isAvalaraTaxCalcEnabled && oli.PriceBookEntry.Product2Id == AvaTaxHelper.getSalesTaxProductId(rBill))
                    ? AvaTaxHelper.getAvaTaxGLAccount(rBill)
                    : ((oli.PriceBookEntry.Product2.Revenue_GL_Account__c != NULL)
                    ? oli.PriceBookEntry.Product2.Revenue_GL_Account__c
                    : defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c);

            rBillLine.Tax_Group__c = oli.Tax_Group__c;
            rBillLine.Project__c = oli.Project__c;
            rBillLine.Project_Task__c = oli.Project_Task__c;
            rBillLine.Product__c = oli.PriceBookEntry.Product2Id;
            rBillLine.Product__r = oli.PriceBookEntry.Product2;
            rBillLine.Comment__c = oli.Description;

            rBillLine.GL_Account_Variable_1__c =
                oli.GL_Account_Variable_1__c != NULL
                    ? oli.GL_Account_Variable_1__c
                    : oli.PriceBookEntry.Product2.GL_Account_Variable_1__c;

            rBillLine.GL_Account_Variable_2__c =
                oli.GL_Account_Variable_2__c != NULL
                    ? oli.GL_Account_Variable_2__c
                    : oli.PriceBookEntry.Product2.GL_Account_Variable_2__c;

            rBillLine.GL_Account_Variable_3__c =
                oli.GL_Account_Variable_3__c != NULL
                    ? oli.GL_Account_Variable_3__c
                    : oli.PriceBookEntry.Product2.GL_Account_Variable_3__c;

            rBillLine.GL_Account_Variable_4__c =
                oli.GL_Account_Variable_4__c != NULL
                    ? oli.GL_Account_Variable_4__c
                    : oli.PriceBookEntry.Product2.GL_Account_Variable_4__c;

            RecurringBillingLineWrapper wrappedLine = new RecurringBillingLineWrapper(rBill, rBillLine, oli);
            if (oli.Tax_Group__c != NULL) {
                wrappedLine.setLineTaxRate(oli.Tax_Group__r.Combined_Tax_Rate__c);
                recurringBillingLines.add(rBillLine);
            }
            wrappedLines.add(wrappedLine);
        }

        if (wrappedLines.isEmpty()) {
            Recurring_Billing_Line__c rBillLine = new Recurring_Billing_Line__c();

            rBillLine.Date__c = nextDateToSet;
            rBillLine.Quantity__c = 1;
            rBillLine.Rate__c = sourceRecord.Amount;
            rBillLine.Revenue_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)?.GL_Account__c;

            wrappedLines.add(new RecurringBillingLineWrapper(rBill, rBillLine, NULL));
        }

        //Fill Main DTO
        mainDTO = new RecurringBillingWrapper(
            rBill, sourceRecord, wrappedLines
        );
        if (isHeaderLevelPostEnabled && !isAvalaraTaxCalcEnabled) {
            setTaxAmount();
        }

        if (isAvalaraTaxCalcEnabled && isHeaderLevelPostEnabled) {
            handleAvaTaxCalculation(false);
        }

    }

    public List<SelectOption> getAllLedgers() {
        return LedgerHandler.getInstanceWithSharing().getTransactionalActiveLedgerSelectOptions();
    }

    private void setTaxAmount() {
        if (!recurringBillingLines.isEmpty()) {
            HeaderLevelTaxHelper.calculateTaxAmountAndSetTaxGroup(recurringBillingLines, NULL);
        }
    }

    private Opportunity queryOpportunity(String opportunityId) {
        //Query Opportunity with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Account.Name',
            'Account.ShippingStreet',
            'Account.ShippingCity',
            'Account.ShippingState',
            'Account.ShippingCountry',
            'Account.ShippingPostalCode',
            'Account.VAT_Business_Identification_Number__c',
            'Account.Entity_Use_Code__c',
            'Account.Exemption_Number__c',
            'AccountId',
            'isWon',
            'CloseDate',
            'Amount',
            'Description'
        };

        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id = :opportunityId';

        List<String> subQueryFields = new List<String>{
            'Id',
            'UnitPrice',
            'ListPrice',
            'Description',
            'ServiceDate',
            'Quantity',
            'Tax_Group__c',
            'Tax_Group__r.Combined_Tax_Rate__c',
            'PricebookEntry.Pricebook2Id',
            'PricebookEntry.Product2Id',
            'PricebookEntry.Product2.Id',
            'PricebookEntry.Product2.Name',
            'PricebookEntry.Product2.ProductCode',
            'PricebookEntry.Product2.Tax_Code__c',
            'PricebookEntry.Product2.Description',
            'PriceBookEntry.Product2.Revenue_GL_Account__c',
            'PriceBookEntry.Product2.GL_Account_Variable_1__c',
            'PriceBookEntry.Product2.GL_Account_Variable_2__c',
            'PriceBookEntry.Product2.GL_Account_Variable_3__c',
            'PriceBookEntry.Product2.GL_Account_Variable_4__c',
            'Project__c',
            'Project_Task__c',
            'GL_Account_Variable_4__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_1__c'
        };

        if (isProductDiscount) {
            subQueryFields.add('Discount');
        }

        String subQueryRelationshipName = 'OpportunityLineItems';
        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('OpportunityLineItem', 'SortOrder', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Opportunity.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, true)
            .setEnforceFLS(true)
            .selectFields(subQueryFields)
            .addOrdering(ordering);

        return (Opportunity) Database.query(theQuery.toSOQL());
    }

    private Boolean isRecurringBillingExists(Id opportunityId) {
        return DomainUtils.countRecurringBillingsByOpportunity(opportunityId) > 0;
    }

    public PageReference createRecurringBilling() {
        if (isAvalaraTaxCalcEnabled && isHeaderLevelPostEnabled) {
            if (AbstractTaxService.isLedgerTaxSettingsEmpty(mainDTO.recurringBilling)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, TaxService.getNoTaxSettingErrorMessage(false)));
                isError = true;
                return NULL;
            }
            handleAvaTaxCalculation(true);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            List<Recurring_Billing_Line__c> rbLinesToInsert = mainDTO.extractSelectedRecBillLines();
            if (rbLinesToInsert.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_RB_LINES_SELECTED_ERROR));
                isError = true;
                return NULL;
            }
            //Insert Recurring Billing record first to have its Id
            if (createInitialBilling) {
                mainDTO.setLastBillingDate();
            }
            SFDCSecurityUtils.insertCheckCRUDAndFLS(mainDTO.recurringBilling, new List<String>{
                'Name',
                'Next_Billing_Date__c',
                'Customer__c',
                'Opportunity__c'
            });
            //Insert Recurring Billing Lines
            for (Recurring_Billing_Line__c rBillLine : rbLinesToInsert) {
                rBillLine.Recurring_Billing__c = mainDTO.recurringBilling.Id;
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(rbLinesToInsert, new List<String>{
                'Date__c',
                'Quantity__c',
                'Rate__c',
                'Revenue_GL_Account__c',
                'Project__c',
                'Project_Task__c',
                'Product__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c'
            });

            //If Create Initial Billing? checkbox is checked
            //We will create Billing record using data taken from Opportunity(and Opp Products for Billing Lines)
            if (createInitialBilling) {
                //Since Accounting Period is required for Billing record
                //We have to be sure that there is an existed Accounting Period in org
                // corresponding to the Closed Date on Opportunity record
                Accounting_Period__c billingPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(mainDTO.opp.CloseDate);
                if (billingPeriod == NULL) {
                    throw new AccountingPeriodHandler.AccountingPeriodException(ACCOUNTING_PERIOD_DOES_NOT_EXIST_ERROR);
                }

                //compute the billing date
                Date billingDateToSet;
                if(AccountingSettingsHandler.getAccountingSettings().Set_Billing_Date_To_Current_Date__c) {
                    billingDateToSet = Date.today();
                } else {
                    billingDateToSet = mainDTO.opp.CloseDate;
                }
                //If an appropriate Accounting Period exists - just continue with Billing creation
                Billing__c billing = new Billing__c(
                    Customer__c = mainDTO.opp.AccountId,
                    Date__c = billingDateToSet,
                    Opportunity__c = mainDTO.opp.Id,
                    Billing_Comment__c = mainDTO.opp.Description,
                    Recurring_Billing__c = mainDTO.recurringBilling.Id,
                    Ledger__c = mainDTO.recurringBilling.Ledger__c
                );
                if (isMultiCurrencyEnabled) {
                    billing.put('CurrencyIsoCode', currencyIsoCode);
                }
                SFDCSecurityUtils.insertCheckCRUDAndFLS(billing, new List<String>{
                    'Opportunity__c',
                    'Billing_Comment__c',
                    'Customer__c',
                    'Date__c',
                    'Recurring_Billing__c'
                });
                //Create Billing Lines based on RB Lines
                List<Billing_Line__c> billingLines = new List<Billing_Line__c>();
                for (Recurring_Billing_Line__c rBillLine : rbLinesToInsert) {
                    billingLines.add(convertRBLineToBillingLine(rBillLine, billing.Id));
                }
                if (billingLines.isEmpty()) {
                    Billing_Line__c billLine = new Billing_Line__c();
                    billLine.Billing__c = billing.Id;
                    billLine.Date__c = mainDTO.opp.CloseDate;
                    billLine.Hours_Units__c = 1;
                    billLine.Rate__c = mainDTO.opp.Amount != NULL ? mainDTO.opp.Amount : mainDTO.recurringBillingLineWrappers[0].rbLine.Rate__c;
                }
                SFDCSecurityUtils.insertCheckCRUDAndFLS(billingLines, new List<String>{
                    'Opportunity_Product_Id__c',
                    'Project__c',
                    'Project_Task__c',
                    'Date__c',
                    'List_Price__c',
                    'Revenue_GL_Account__c',
                    'Comment__c',
                    'GL_Account_Variable_1__c',
                    'GL_Account_Variable_2__c',
                    'GL_Account_Variable_3__c',
                    'GL_Account_Variable_4__c',
                    'Product__c',
                    'Hours_Units__c',
                    'Rate__c'
                });
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            isError = true;
            ApexPages.addMessages(ex);
            return NULL;
        }

        return new PageReference('/' + mainDTO.recurringBilling.Id);
    }

    private Billing_Line__c convertRBLineToBillingLine(Recurring_Billing_Line__c recBillLine, Id billingId) {
        Billing_Line__c billingLine = new Billing_Line__c(
            Billing__c = billingId,
            Opportunity_Product_Id__c = recBillLine.Opportunity_Product_Id__c,
            Project__c = recBillLine.Project__c,
            Project_Task__c = recBillLine.Project_Task__c,
            Date__c = recBillLine.Date__c,
            List_Price__c = recBillLine.List_Price__c,
            Revenue_GL_Account__c = recBillLine.Revenue_GL_Account__c,
            Comment__c = recBillLine.Comment__c,
            GL_Account_Variable_1__c = recBillLine.GL_Account_Variable_1__c,
            GL_Account_Variable_2__c = recBillLine.GL_Account_Variable_2__c,
            GL_Account_Variable_3__c = recBillLine.GL_Account_Variable_3__c,
            GL_Account_Variable_4__c = recBillLine.GL_Account_Variable_4__c,
            Product__c = recBillLine.Product__c,
            Hours_Units__c = recBillLine.Quantity__c,
            Rate__c = recBillLine.Rate__c,
            Tax_Amount2__c = recBillLine.Tax_Amount__c,
            Tax_Group__c = recBillLine.Tax_Group__c
        );
        return billingLine;
    }

    @TestVisible
    private void populateCurrencyConversionRate() {
        if (isMultiCurrencyEnabled
                && LedgerHandler.isUSDLedger(mainDTO.recurringBilling.Ledger__c)) {

            List<SObject> rates = DomainUtils.getDatedConversionRateByCurrencyISOCodesAndDates(
                new Set<String>{currencyIsoCode}, new Set<Date>{mainDTO.opp.CloseDate}
            );

            if (!rates.isEmpty()) {
                mainDTO.setCurrencyConversionRate((Decimal) rates[0].get('ConversionRate'));
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

        try {
            if (doRefreshProduct) {
                mainDTO.refreshProducts();
            }

            Boolean isTaxableByCurrency =
                isMultiCurrencyEnabled
                    ? LedgerHandler.isUSDLedger(mainDTO.recurringBilling.Ledger__c)
                    : true;


            if (!isTaxableByCurrency || !mainDTO.taxableLineExists()) {
                //clear Tax Amount field
                if (isHeaderLevelPostEnabled) {
                    mainDTO.clearTaxAmount();
                }
            }

            if (isTaxableByCurrency && mainDTO.taxableLineExists()) {
                AvaTaxService.CreateTransactionModel request = mainDTO.getCreateTransactionModel();
                AvaTaxHelper.sourceRecord = mainDTO.recurringBilling;
                AvaTaxService.TransactionModel response = AvaTaxHelper.calcTax(request);
                mainDTO.updateTaxAmount(response);
            }
            else {

            }
        }
        catch (Exception ex) {
            //if AvaTax calculation failed - do not block the main flow
        }
    }

    public String getSubTotalLabel() {
        String result = Schema.Opportunity.Amount.getDescribe().getLabel();
        if (isHeaderLevelPostEnabled) {
            result = Schema.Recurring_Billing_Line__c.Sub_Total__c.getDescribe().getLabel();
        }
        return result;
    }

    public pageReference selectLedger() {
        try {
            wrapperInit(mainDTO.recurringBilling.Ledger__c);
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            showOnlyMessages = false;
        }
        return null;
    }

    public with sharing class RecurringBillingWrapper {
        private Decimal currencyConversionRate;
        @TestVisible
        private Map<String, Recurring_Billing_Line__c> rbLineMappedByOppLineItemId = new Map<String, Recurring_Billing_Line__c>();
        private Boolean isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();

        public Opportunity opp {get; set;}
        public Recurring_Billing__c recurringBilling {get; set;}
        public List<RecurringBillingLineWrapper> recurringBillingLineWrappers {get; set;}
        public String taxMethod {get; set;}
        public Boolean isTaxMethodError {get; set;}

        public RecurringBillingWrapper(Recurring_Billing__c recBill, Opportunity sourcedFrom, List<RecurringBillingLineWrapper> wrappedLines) {
            this.opp = sourcedFrom;
            this.recurringBilling = recBill;
            this.recurringBillingLineWrappers = wrappedLines;
            this.currencyConversionRate = 1.0;//default value, must be updated before RB creation
            this.taxMethod = new NativeTaxHeaderLevel().getTaxMethod(this.recurringBilling);
            isTaxMethodError = taxMethod == null ? true : false;
        }

        public void setCurrencyConversionRate(Decimal value) {
            this.currencyConversionRate = value;
        }

        public Decimal getCurrencyConversionRate() {
            return this.currencyConversionRate;
        }

        public Decimal getTotalAmount() {
            Decimal result = 0;
            for (RecurringBillingLineWrapper line : recurringBillingLineWrappers) {
                Decimal total = line.rbLine.Quantity__c * line.rbLine.Rate__c;
                if (this.isHlpMode) {
                    if (line.isAvalaraTaxCalcEnabled) {
                        total = total + ((line.rbLine.Tax_Amount__c != NULL) ? line.rbLine.Tax_Amount__c : 0);
                    }
                    else if (line.taxRate != NULL) {
                        total = total + (total * line.taxRate);
                    }
                }
                result += total;
            }
            return result.setScale(2, System.RoundingMode.HALF_UP);
        }

        public List<Recurring_Billing_Line__c> extractSelectedRecBillLines() {
            if (this.recurringBillingLineWrappers == NULL || this.recurringBillingLineWrappers.isEmpty()) {
                return new List<Recurring_Billing_Line__c>();
            }
            List<Recurring_Billing_Line__c> extractedLines = new List<Recurring_Billing_Line__c>();
            for (RecurringBillingLineWrapper wrappedLine : this.recurringBillingLineWrappers) {
                if (wrappedLine.isSelected) {
                    extractedLines.add(wrappedLine.rbLine);
                }
            }
            return extractedLines;
        }

        public void setLastBillingDate() {
            this.recurringBilling.Last_Billing_Date__c = opp.CloseDate;
        }

        public Boolean taxableLineExists() {
            for (RecurringBillingLineWrapper wrappedLine : recurringBillingLineWrappers) {
                if (AvaTaxHelper.validateRecurringBillingLineIsTaxable(wrappedLine.rbLine)) {
                    return true;
                }
            }
            return false;
        }

        public void refreshProducts() {
            Set<Id> productIds = new Set<Id>();
            for (RecurringBillingLineWrapper wrappedLine : recurringBillingLineWrappers) {
                if (wrappedLine.rbLine.Product__c != NULL) {
                    productIds.add(wrappedLine.rbLine.Product__c);
                }
            }

            Map<Id, Product2> productMap = new Map<Id, Product2>(
                DomainUtils.getProductsById(productIds)
            );

            for (RecurringBillingLineWrapper wrappedLine : recurringBillingLineWrappers) {
                if (wrappedLine.rbLine.Product__c != NULL) {
                    wrappedLine.rbLine.Product__r = productMap.get(wrappedLine.rbLine.Product__c);
                }
            }
        }

        public void clearTaxAmount() {
            for (RecurringBillingLineWrapper wrappedLine : recurringBillingLineWrappers) {
                wrappedLine.rbLine.Tax_Amount__c = NULL;
            }
        }

        public void updateTaxAmount(AvaTaxService.TransactionModel avaTaxTransaction) {
            AvaTaxHelper.populateTaxAmountOnVirtualLines(avaTaxTransaction, rbLineMappedByOppLineItemId, getCurrencyConversionRate());
            for (RecurringBillingLineWrapper wrappedLine : recurringBillingLineWrappers) {
                if (rbLineMappedByOppLineItemId.containsKey(wrappedLine.rbLine.Opportunity_Product_Id__c)) {
                    wrappedLine.rbLine = rbLineMappedByOppLineItemId.get(wrappedLine.rbLine.Opportunity_Product_Id__c);
                }
            }
        }

        public AvaTaxService.CreateTransactionModel getCreateTransactionModel() {
            rbLineMappedByOppLineItemId.clear();
            AvaTaxService.CreateTransactionModel result = new AvaTaxService.CreateTransactionModel();
            result.companyCode = AvaTaxHelper.getCompanyCode((SObject) recurringBilling);
            result.type = AvaTaxService.DocumentType.SalesOrder;
            result.avaTaxDate = opp.CloseDate;
            result.customerCode = recurringBilling.Customer__c;
            result.businessIdentificationNo = opp.Account.VAT_Business_Identification_Number__c;
            result.entityUseCode = opp.Account.Entity_Use_Code__c;
            result.exemptionNo = opp.Account.Exemption_Number__c;
            result.addresses = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(this.opp, (SObject) recurringBilling), AvaTaxHelper.getDestinationAddressInfo(this.opp), (SObject) recurringBilling);
            result.currencyCode = 'USD';//currently we support only USD

            result.lines = getLines();

            result.doCommit = false;

            return result;
        }

        private List<AvaTaxService.LineItemModel> getLines() {
            List<AvaTaxService.LineItemModel> result = new List<AvaTaxService.LineItemModel>();
            for (RecurringBillingLineWrapper rbLine : recurringBillingLineWrappers) {
                if (rbLine.isSelected && AvaTaxHelper.validateRecurringBillingLineIsTaxable(rbLine.rbLine)) {
                    //map all Recurring Billing Lines by source Opportunity Product Line b/c they do not have ID yet
                    String uniqKey = rbLine.rbLine.Opportunity_Product_Id__c;
                    rbLineMappedByOppLineItemId.put(uniqKey, rbLine.rbLine);
                    //include only Taxable Line into request data
                    AvaTaxService.LineItemModel tempLine = new AvaTaxService.LineItemModel();
                    tempLine.avaTaxNumber = uniqKey;
                    tempLine.amount = (rbLine.rbLine.Quantity__c * rbLine.rbLine.Rate__c) / getCurrencyConversionRate();
                    tempLine.quantity = Math.abs(rbLine.rbLine.Quantity__c);
                    AvaTaxHelper.putItemCodeOnLine(tempLine, rbLine.rbLine.Product__r);
                    tempLine.description = rbLine.rbLine.Product__r.Description;
                    result.add(tempLine);
                }
            }
            return result;
        }
    }

    public with sharing class RecurringBillingLineWrapper {
        public Boolean isSelected {get; set;}
        public Boolean isLockedDownRow {get; set;}
        public Recurring_Billing_Line__c rbLine {get; set;}
        public Decimal taxRate {get; set;}
        private OpportunityLineItem oli;
        private Boolean isAvalaraTaxCalcEnabled;

        public RecurringBillingLineWrapper(Recurring_Billing__c rBill, Recurring_Billing_Line__c valLine, OpportunityLineItem oli) {
            this.isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(rBill);
            this.isSelected = true;
            this.rbLine = valLine;
            this.oli = oli;
            this.isLockedDownRow = (isAvalaraTaxCalcEnabled && valLine.Product__c == AvaTaxHelper.getSalesTaxProductId(rBill));
            if (isLockedDownRow) {
                this.isSelected = false;
            }
        }

        public void setLineTaxRate(Decimal combinedTaxRate) {
            taxRate = combinedTaxRate / 100;
        }
    }

}