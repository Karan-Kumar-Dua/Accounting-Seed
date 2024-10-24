public with sharing class OpportunitySalesTax extends AbstractTaxTableHelper {
    private static final String TAX_TYPE_TAX_RATE = 'Tax Rate';
    private static final String TAX_TYPE_TAX_PRODUCT = 'Taxable Product';

    @TestVisible
    private static final String NO_ACCOUNT_ERROR_MESSAGE = Label.ERR_NO_ACCOUNT_ON_OPPORTUNITY;
    @TestVisible
    private static final String NO_TAXABLE_PRODUCTS_MESSAGE =
        Label.ERR_NO_TAXABLE_PRODUCTS;
    @TestVisible
    private static final String NO_OPPORTUNITY_PRODUCT_LINE_MESSAGE =
        Label.ERR_NO_OPPORTUNITY_PRODUCT_LINE;
    @TestVisible
    private static final String NO_AVAILABLE_TAXES =
        Label.ERR_NO_AVAILABLE_TAX_RECORD;
    @TestVisible
    private static final List<String> APPLICABLE_TYPES_OF_TAXES = new List<String>{
        'Sales',
        'Sales & Purchase'
    };
    private static final String LINES_CREATED_MESSAGE =
        Label.INF_TAX_LINES_CREATED;

    private final ApexPages.StandardController stdController;

    private List<OpportunityLineItem> existedLines;
    private List<OpportunityLineItem> taxableLines;
    private List<OpportunityLineItem> linesToDelete;
    private List<OpportunityLineItem> linesToInsert;
    private List<Account_Tax__c> taxes;
    private Map<Id, PricebookEntry> priceBookEntryByProductId;
    @TestVisible
    private Opportunity theOpportunity;
    private Id accountId;
    @TestVisible
    private List<Decimal> dobTotal;
    private Boolean isUIContext;

    public Boolean isTaxableProductsExisted {get; set;}
    public Boolean isValidationPassed {get; set;}
    public Boolean isMultiCurrencyEnabled {get; set;}
    public Boolean isHeaderLevelPostEnabled {get; set;}
    public String currencyIsoCode {get; private set;}
    public Boolean showDiscount {get; set;}
    public HLPOpportunityDataWrapper hlpOpportunityDataWrapper {get; set;}

    //Constructor
    public OpportunitySalesTax(ApexPages.StandardController controller) {
        this.stdController = controller;
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
        this.isUIContext = true;
    }

    public OpportunitySalesTax(ApexPages.StandardController controller, Boolean isUIContext) {
        this(controller);
        this.isUIContext = isUIContext;
    }

    private Opportunity queryOpportunity() {
        String oppId = stdController.getId();
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Amount',
            'AccountId',
            'Account.Name',
            'Pricebook2Id',
            'Tax_Amount__c'

        };
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        //set query condition
        String queryCondition = 'Id = :oppId';

        SOQLBuilder theQuery = new SOQLBuilder(Opportunity.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (Opportunity) Database.query(theQuery.toSOQL());
    }

    private List<OpportunityLineItem> queryOppLineItems() {
        String oppId = stdController.getId();
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'ServiceDate',
            'Quantity',
            'UnitPrice',
            'OpportunityId',
            'PriceBookEntry.Product2Id',
            'PriceBookEntry.Product2.Name',
            'PriceBookEntry.Product2.Accounting_Type__c',
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
            'Description',
            'Tax_Group__c',
            'Tax_Group__r.Combined_Tax_Rate__c'
        };

        if (!isHeaderLevelPostEnabled) {
            queryFields.add('TotalPrice');
        }

        if (DomainUtils.isDiscountIncludedInOpportunityLineItems(new Set<Id>{oppId})) {
            queryFields.add('Discount');
        }
        //set query condition
        String queryCondition = 'OpportunityId = :oppId';

        SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<OpportunityLineItem>) Database.query(theQuery.toSOQL());
    }

    private List<Account_Tax__c> queryAccountTaxes() {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Account__c',
            'Tax_Rate__c',
            'Tax_Type__c',
            'Tax_Rate__r.Name',
            'Tax_Rate__r.Tax_Rate__c',
            'Tax_Rate__r.Revenue_GL_Account__c'
        };
        //set query condition
        String queryCondition = 'Account__c = :accountId AND Tax_Type__c IN :APPLICABLE_TYPES_OF_TAXES';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Tax__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Account_Tax__c>) Database.query(theQuery.toSOQL());
    }

    private Map<Id, PricebookEntry> getPriceBookEntriesByProductId() {
        Id priceBookId = theOpportunity.Pricebook2Id;
        Set<Id> productIds = new Set<Id>();
        Map<Id, PricebookEntry> result = new Map<Id, PricebookEntry>();

        for (Account_Tax__c eachTax : taxes)  {
            productIds.add(eachTax.Tax_Rate__c);
        }

        List<PricebookEntry> priceBookEntries = DomainUtils.getPricebookEntriesByProductAndPriceBookId(
            productIds, new Set<Id>{priceBookId}
        );

        for (PricebookEntry pbe : priceBookEntries) {
            if (isMultiCurrencyEnabled) {
                if (String.valueOf(pbe.get('CurrencyIsoCode')).equalsIgnoreCase(this.currencyIsoCode)) {
                    result.put(pbe.Product2Id, pbe);
                }
            }
            else {
                result.put(pbe.Product2Id, pbe);
            }
        }

        return result;
    }

    private Boolean validateDiscountPresence() {
        Boolean result = false;
        if (isHeaderLevelPostEnabled && !existedLines.isEmpty()) {
            for (SObject oppLineItem : existedLines) {
                if (oppLineItem.getPopulatedFieldsAsMap().get('Discount') != NULL) {
                    result = true;
                }
            }
        }
        return result;
    }

    public PageReference save() {
        if (isValidationPassed) {
            Savepoint sp = Database.setSavepoint();
            try {
                if (isHeaderLevelPostEnabled) {
                    hlpSave();
                }
                else {
                    llpSave();
                }

                PageReference page = new PageReference('/' + theOpportunity.Id);
                return page;
            }
            catch (Exception e) {
                Database.rollback(sp);
                isValidationPassed = false;
                ApexPages.addMessages(e);
                return NULL;
            }
        }

        return NULL;
    }

    private void hlpSave() {
        SFDCSecurityUtils.updateCheckCRUDAndFLS(new List<Opportunity> {hlpOpportunityDataWrapper.opportunity}, new List<String> ());
        SFDCSecurityUtils.updateCheckCRUDAndFLS(existedLines, new List<String> ());
    }

    private void llpSave() {
        List<TaxServiceResult> taxCalcResult = TaxService.calcTaxes(new Map<SObject, Id> {theOpportunity => LedgerHandler.getLedgerId()});
    }

    public PageReference init() {

        dobTotal = new List<Decimal>();
        isValidationPassed = true;
        isTaxableProductsExisted = false;
        linesToInsert = new List<OpportunityLineItem>();
        linesToDelete = new List<OpportunityLineItem>();
        taxableLines = new List<OpportunityLineItem>();

        try {
            // Get Billing Record details
            theOpportunity = queryOpportunity();
            if (isMultiCurrencyEnabled) {
                this.currencyIsoCode = (String) theOpportunity.get('CurrencyIsoCode');
            }
            // Get Customer Id (Account Id)
            accountId = theOpportunity.AccountId;
            if (accountId == NULL) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, NO_ACCOUNT_ERROR_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            // Query Existed Opportunity Line Items
            existedLines = queryOppLineItems();
            if (existedLines.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, NO_OPPORTUNITY_PRODUCT_LINE_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }

            if (isHeaderLevelPostEnabled) {
                hlpModeInit();
            }
            else {
                llpModeInit();
                if (!isTaxableProductsExisted && !isHeaderLevelPostEnabled) {
                    ApexPages.addMessage(
                        new ApexPages.Message(ApexPages.SEVERITY.INFO, OpportunitySalesTax.NO_TAXABLE_PRODUCTS_MESSAGE)
                    );
                    isValidationPassed = false;
                    return NULL;
                }

                // Query Available Account Taxes
                taxes = queryAccountTaxes();
                if (taxes.isEmpty()) {
                    ApexPages.addMessage(
                        new ApexPages.Message(
                            ApexPages.Severity.ERROR,
                            String.format(
                                NO_AVAILABLE_TAXES,
                                new List<String>{
                                    theOpportunity.Account.Name,
                                    APPLICABLE_TYPES_OF_TAXES[0],
                                    APPLICABLE_TYPES_OF_TAXES[1]
                                }
                            )
                        )
                    );
                    isValidationPassed = false;
                    return NULL;
                }
                else {//query PriceBook Entries
                    priceBookEntryByProductId = getPriceBookEntriesByProductId();
                }
                //Validate each Tax record has Revenue GL Account populated and has been added to the current Pricebook
                String taxesErrorMessage = getTaxesErrorMessage();
                if (!String.isBlank(taxesErrorMessage)) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, taxesErrorMessage));
                    isValidationPassed = false;
                    return NULL;
                }

                //if all validations were passed
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, OpportunitySalesTax.LINES_CREATED_MESSAGE));
                //get forecasted line(s) for the intermediate screen
                //not needed in case of tax calculation during post process
                if (isUIContext) {
                    getTableData(taxes, taxableLines);
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isValidationPassed = false;
        }
        return NULL;
    }

    private void llpModeInit() {
        for (OpportunityLineItem line : existedLines) {
            if (line.PriceBookEntry.Product2.Accounting_Type__c == TAX_TYPE_TAX_RATE) {
                linesToDelete.add(line);
            }
            else if (line.PriceBookEntry.Product2.Accounting_Type__c == TAX_TYPE_TAX_PRODUCT) {
                isTaxableProductsExisted = true;
                taxableLines.add(line);
                HLPOpportunityLineDataWrapper wrappedLine = new HLPOpportunityLineDataWrapper(line);
                dobTotal.add(wrappedLine.getLineSubTotal());
            }
        }
    }

    private void hlpModeInit() {
        hlpOpportunityDataWrapper = new HLPOpportunityDataWrapper(theOpportunity);
        for (OpportunityLineItem line : existedLines) {
            HLPOpportunityLineDataWrapper wrappedLine = new HLPOpportunityLineDataWrapper(line);
            hlpOpportunityDataWrapper.addEstimatedTaxAmount(wrappedLine.getLineTaxAmount());
            hlpOpportunityDataWrapper.opportunityLineItems.add(wrappedLine);
        }
        hlpOpportunityDataWrapper.setEstimatedTaxAmount();
        showDiscount = validateDiscountPresence();
    }

    private String getTaxesErrorMessage() {
        List<String> messages = new List<String>();
        for (Account_Tax__c tax : taxes) {
            if (tax.Tax_Rate__r.Revenue_GL_Account__c == NULL) {
                messages.add(
                    Label.COMMON_TAX_PRODUCT + tax.Tax_Rate__r.Name + Label.COMMON_IS_MISSING_GL_ACCOUNT
                );
            }
            else if (priceBookEntryByProductId.get(tax.Tax_Rate__c) == NULL) {
                messages.add(Label.COMMON_TAX_PRODUCT + tax.Tax_Rate__r.Name + Label.COMMON_HAS_NOT_BEEN_ADDED_CURRENT_PRICEBOOK);
            }
        }
        return String.join(messages, '</br>');
    }

    public with sharing class HLPOpportunityDataWrapper {
        public Opportunity opportunity {get; set;}
        public List<HLPOpportunityLineDataWrapper> opportunityLineItems {get; set;}

        public HLPOpportunityDataWrapper(Opportunity opportunity) {
            this.opportunity = opportunity;
            opportunityLineItems = new List<HLPOpportunityLineDataWrapper>();
            opportunity.Tax_Amount__c = 0;
        }

        public void addEstimatedTaxAmount(Decimal taxAmount) {
            opportunity.Tax_Amount__c += taxAmount;
        }

        public void setEstimatedTaxAmount() {
            opportunity.Tax_Amount__c = opportunity.Tax_Amount__c.setScale(2, System.RoundingMode.HALF_UP);
        }

        public Decimal getEstimatedTotal() {
            return opportunity.Amount + opportunity.Tax_Amount__c;
        }

    }

    public with sharing class HLPOpportunityLineDataWrapper {
        public OpportunityLineItem opportunityLineItem {get; set;}

        public HLPOpportunityLineDataWrapper(OpportunityLineItem opportunityLineItem) {
            this.opportunityLineItem = opportunityLineItem;
            setLineTaxAmount();
        }

        public Decimal getLineTaxAmount() {
            return opportunityLineItem.Tax_Amount__c;
        }

        public Decimal getLineTotal() {
            return getLineSubTotal() + opportunityLineItem.Tax_Amount__c;
        }

        private Decimal getDiscount() {
            Decimal discountValue = 0;
            if (opportunityLineItem.getPopulatedFieldsAsMap().get('Discount') != NULL) {
                discountValue = opportunityLineItem.Discount;
            }
            return discountValue;
        }

        private void setLineTaxAmount() {
            opportunityLineItem.Tax_Amount__c = (getLineSubTotal() * getLineTaxRate()).setScale(2, System.RoundingMode.HALF_UP);
        }

        private Id getLineTaxGroupId() {
            return opportunityLineItem.Tax_Group__c;
        }

        private Decimal getLineTaxRate() {
            Decimal taxRate = 0;
            if (getLineTaxGroupId() != NULL) {
                taxRate = opportunityLineItem.Tax_Group__r.Combined_Tax_Rate__c / 100;
            }
            return taxRate;
        }

        public Decimal getLineSubTotal() {
            return (opportunityLineItem.UnitPrice * (100 - getDiscount()) / 100) * opportunityLineItem.Quantity;
        }

        public Decimal getLineDiscountAmount() {
            return (opportunityLineItem.UnitPrice * opportunityLineItem.Quantity) * (getDiscount() / 100);
        }

    }

}