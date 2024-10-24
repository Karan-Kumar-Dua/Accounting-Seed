public with sharing class OpportunitySalesAvaTax extends AbstractAvaTaxController {

    private static final String NO_ACCOUNT_ERROR_MESSAGE = Label.ERR_NO_ACCOUNT_ON_OPPORTUNITY;
    private static final String PRICE_BOOK_ENTRY_ERROR_MESSAGE = Label.ERR_PRICE_BOOK_ENTRY;
    private PricebookEntry pbe;
    private Double ccr;

    public Boolean isHeaderLevelPostEnabled {get; set;}
    public List<OpportunityLineDataWrapper> oppLineItemsWithEstimatedTaxAmount {get; set;}
    public Boolean isError {get; set;}
    public Boolean isIncorrectCurrency {get; set;}
    public String selectedLedger {get; set;}
    public Boolean showDiscount {get; set;}
    public Decimal oppSubTotal {get; set;}
    public Decimal oppTaxAmount {get; set;}
    public Decimal oppTotal {get; set;}
    public String currencyIsoCode {get; private set;}
    public class OpportunitySalesAvaTaxException extends Exception{}

    public OpportunitySalesAvaTax(ApexPages.StandardController con) {
        try {
            isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
            isError = false;
            isIncorrectCurrency = false;
            sourceRecordId = (Id) con.getId();
            selectedLedger = LedgerHandler.getLedgerId();
            sourceRecord = AvaTaxHelper.queryOpportunityById(sourceRecordId);
            if (isMulticurrencyEnabled) {
                this.currencyIsoCode = (String) sourceRecord.get('CurrencyIsoCode');
            }
            if (sourceRecord.get('AccountId') == NULL) {
                throw new AvaTaxService.AvaTaxException(NO_ACCOUNT_ERROR_MESSAGE);
            }
            ccr = AvaTaxHelper.getCurrencyConversionRateForOpportunity(sourceRecord);
            sourceRecordLines = AvaTaxHelper.queryTaxableOpportunityLineItemsByOpportunityId(sourceRecord, selectedLedger);
            if (sourceRecordLines.isEmpty()) {
                throw new AvaTaxService.AvaTaxException(NO_LINES_ERROR_MESSAGE);
            }
            showDiscount = validateDiscountPresence();
            setPriceBookEntry();
            validateSelectedLedger();
        }
        catch (OpportunitySalesAvaTaxException ex) {
            isIncorrectCurrency = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
    }

    private Boolean validateDiscountPresence() {
        Boolean result = false;
        if (isHeaderLevelPostEnabled && !sourceRecordLines.isEmpty()) {
            for (SObject oppLineItem : sourceRecordLines) {
                if (oppLineItem.getPopulatedFieldsAsMap().get('Discount') != NULL) {
                    result = true;
                }
            }
        }
        return result;
    }

    public void estimateTax() {
        if (!isError && !isIncorrectCurrency) {
            try {
                oppLineItemsWithEstimatedTaxAmount = new List<OpportunityLineDataWrapper>();

                AvaTaxService.TransactionModel responseResult = AvaTaxHelper.calcTax(
                    sourceRecord, sourceRecordLines, AvaTaxService.DocumentType.SalesOrder, false
                );

                if (isHeaderLevelPostEnabled) {
                    oppSubTotal = 0;
                    oppTaxAmount = 0;
                    oppTotal = 0;
                    for (OpportunityLineItem oppLineItem : (List<OpportunityLineItem>) sourceRecordLines) {
                        if (responseResult.getLinesMap().containsKey(oppLineItem.Id)) {
                            OpportunityLineDataWrapper line = new OpportunityLineDataWrapper(oppLineItem);
                            line.setLineTaxAmount(responseResult.getLinesMap().get(oppLineItem.Id).taxCalculated * ccr);
                            //calc Header values
                            oppSubTotal += line.getLineSubTotal();
                            oppTaxAmount += line.getLineTaxAmount();
                            oppTotal += line.getLineTotal();
                            oppLineItemsWithEstimatedTaxAmount.add(line);
                        }
                    }
                }
                else {
                    OpportunityLineItem taxOppLineItem = new OpportunityLineItem(
                        OpportunityId = sourceRecord.Id,
                        Quantity = 1,
                        Description = (AvaTaxHelper.getSalesTaxProduct(sourceRecord) != NULL) ? AvaTaxHelper.getSalesTaxProduct(sourceRecord).Description : NULL,
                        PricebookEntryId = pbe.Id,
                        Product2Id = AvaTaxHelper.getSalesTaxProductId(sourceRecord),
                        UnitPrice = responseResult.totalTax * ccr
                    );
                    OpportunityLineDataWrapper line = new OpportunityLineDataWrapper(taxOppLineItem);
                    oppLineItemsWithEstimatedTaxAmount.add(line);
                }
            }
            catch (Exception ex) {
                isError = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            }
        }
    }

    public override AvaTaxService.AvaTaxResult pushAvaTaxTransaction() {
        AvaTaxService.AvaTaxResult result;
        try {
            AvaTaxService.TransactionModel responseResult = AvaTaxHelper.calcTax(
                sourceRecord, sourceRecordLines, AvaTaxService.DocumentType.SalesOrder, false
            );

            //remove all existed sales tax line(s)
            List<OpportunityLineItem> existedSaleTaxLines = AvaTaxHelper.queryExistedSalesTaxOpportunityProductLines(
                sourceRecord.Id, AvaTaxHelper.getSalesTaxProductId(sourceRecord)
            );

            if (!existedSaleTaxLines.isEmpty()) {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(existedSaleTaxLines);
            }

            //If Header Level Posting is Enabled -> update all taxable Opportunity Line Items
            // and populate aggregated Tax Amount on Opportunity record
            if (isHeaderLevelPostEnabled) {
                List<OpportunityLineItem> linesToUpdate = new List<OpportunityLineItem>();
                for (OpportunityLineItem oppLineItem : (List<OpportunityLineItem>) sourceRecordLines) {
                    if (responseResult.getLinesMap().containsKey(oppLineItem.Id)) {
                        Decimal lineTax = ((Decimal) responseResult.getLinesMap().get(oppLineItem.Id).taxCalculated * ccr).setScale(2, System.RoundingMode.HALF_UP);
                        oppLineItem.Tax_Amount__c = lineTax;
                        linesToUpdate.add(oppLineItem);
                    }
                }
                SFDCSecurityUtils.updateCheckCRUDAndFLS(linesToUpdate, new List<String>());
                sourceRecord.put(Schema.Opportunity.Tax_Amount__c, oppTaxAmount.setScale(2, System.RoundingMode.HALF_UP));
                SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecord, new List<String>());
            }
            else {//If LLP mode -> create new sales tax line
                OpportunityLineItem taxOppLineItem = new OpportunityLineItem(
                    OpportunityId = sourceRecord.Id,
                    Quantity = 1,
                    Description = (AvaTaxHelper.getSalesTaxProduct(sourceRecord) != NULL) ? AvaTaxHelper.getSalesTaxProduct(sourceRecord).Description : NULL,
                    UnitPrice = responseResult.totalTax * AvaTaxHelper.getCurrencyConversionRateForOpportunity(sourceRecord),
                    ServiceDate = responseResult.avaTaxDate,
                    PricebookEntryId = pbe.Id
                );

                SFDCSecurityUtils.insertCheckCRUDAndFLS(taxOppLineItem, new List<String>{
                    'Description', 'ServiceDate'
                });
            }

            result = new AvaTaxService.AvaTaxResult(true, NULL);
        }
        catch (AvaTaxService.AvaTaxException avTaxEx) {
            result = new AvaTaxService.AvaTaxResult(false, avTaxEx.atError);
        }
        catch (Exception ex) {
            result = new AvaTaxService.AvaTaxResult(false, new AvaTaxService.AvaTaxError(ex.getMessage()));
        }

        return result;
    }

    private void setPriceBookEntry() {
        if (!isHeaderLevelPostEnabled) {
            Id salesTaxProductId = AvaTaxHelper.getSalesTaxProductId(sourceRecord);
            Id priceBookId = (Id) sourceRecord.get('Pricebook2Id');

            List<PricebookEntry> priceBookEntries = DomainUtils.getPricebookEntriesByProductAndPriceBookId(
                new Set<Id>{salesTaxProductId}, new Set<Id>{priceBookId}
            );

            if (priceBookEntries.isEmpty()) {
                throw new AvaTaxService.AvaTaxException(
                    new AvaTaxService.AvaTaxError(PRICE_BOOK_ENTRY_ERROR_MESSAGE)
                );
            }

            PricebookEntry result;
            if (isMultiCurrencyEnabled) {
                for (PricebookEntry pbe : priceBookEntries) {
                    if (String.valueOf(pbe.get('CurrencyIsoCode')).equalsIgnoreCase(String.valueOf(sourceRecord.get('CurrencyIsoCode')))) {
                        result = pbe;
                    }
                }
                if (result == NULL) {
                    throw new AvaTaxService.AvaTaxException(
                        new AvaTaxService.AvaTaxError(PRICE_BOOK_ENTRY_ERROR_MESSAGE)
                    );
                }
            }
            else {
                result = priceBookEntries[0];
            }

            this.pbe = result;
        }
    }

    public PageReference commitTax() {
        try {
            setOpportunityLedgerMap();
            AvaTaxService.AvaTaxResult result = pushAvaTaxTransaction();
            if (result.isSuccess) {
                return new PageReference('/' + sourceRecord.Id);
            }
            else {
                throw new AvaTaxService.AvaTaxException(result.error);
            }
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            isError = true;
        }

        return NULL;
    }

    public List<SelectOption> getAllLedgers() {
        return LedgerHandler.getInstanceWithSharing().getTransactionalLedgerSelectOptions();
    }

    public Boolean getIsMultiLedgerEnabled() {
        if (LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers().size() > 1) {
            return true;
        }
        else {
            return false;
        }
    }

    public String getSelectedLedgerCurrency(String ledgerId) {
        Ledger__c theLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
        return (String) theLedger.get('CurrencyIsoCode');
    }

    private void validateSelectedLedger() {
        if (isMultiCurrencyEnabled && getSelectedLedgerCurrency(selectedLedger) != 'USD') {
            throw new OpportunitySalesAvaTaxException(INCORRECT_CURRENCY_ERROR_MESSAGE);
        }
    }

    public PageReference changeLedger() {
        isIncorrectCurrency = false;
        try {
            validateSelectedLedger();
            setOpportunityLedgerMap();
            estimateTax();
        }
        catch (OpportunitySalesAvaTaxException ex) {
            isIncorrectCurrency = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
        return NULL;
    }

    public String getPageBlockTitle() {
        String result = '';
        if (isHeaderLevelPostEnabled) {
            result = Label.COMMON_ESTIMATED_CALCULATED_TAX;
        }
        else {
            result = Label.COMMON_CREATE_OR_UPDATE_TAX_LINE;
        }
        return result;
    }

    public String getLineTableSectionTitle() {
        String result = '';
        if (isHeaderLevelPostEnabled) {
            result = Label.OPPORTUNITY_PRODUCT_LINE;
        }
        else {
            result = Label.COMMON_ESTIMATED_TAX_LINE;
        }
        return result;
    }

    private void setOpportunityLedgerMap() {
        TaxService.sobjectByLedgerId = new Map<SObject, Id> {sourceRecord => selectedLedger};
    }

    public with sharing class OpportunityLineDataWrapper {
        public OpportunityLineItem opportunityLineItem {get; set;}

        public OpportunityLineDataWrapper(OpportunityLineItem opportunityLineItem) {
            this.opportunityLineItem = opportunityLineItem;
        }

        private Decimal getDiscount() {
            Decimal discountValue = 0;
            if (opportunityLineItem.getPopulatedFieldsAsMap().get('Discount') != NULL) {
                discountValue = opportunityLineItem.Discount;
            }
            return discountValue;
        }

        public void setLineTaxAmount(Decimal taxAmount) {
            opportunityLineItem.Tax_Amount__c = taxAmount;
        }

        public Decimal getLineTaxAmount() {
            return opportunityLineItem.Tax_Amount__c;
        }

        public Decimal getLineSubTotal() {
            return (opportunityLineItem.UnitPrice * (100 - getDiscount()) / 100) * opportunityLineItem.Quantity;
        }

        public Decimal getLineTotal() {
            return getLineSubTotal() + opportunityLineItem.Tax_Amount__c;
        }

        public Decimal getLineDiscountAmount() {
            return (opportunityLineItem.UnitPrice * opportunityLineItem.Quantity) * (getDiscount() / 100);
        }

    }

}