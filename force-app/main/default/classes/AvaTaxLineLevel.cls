public with sharing class AvaTaxLineLevel extends AbstractTaxService {

    private static final String PRICE_BOOK_ENTRY_ERROR_MESSAGE = Label.ERR_SALES_TAX_PRICE_BOOK_ENTRY;

    public static Set<SObjectType> skipCalculation4SObjectTypes = new Set<SObjectType>{
        Recurring_Billing_Line__c.getSObjectType(),
        Recurring_Account_Payable_Line__c.getSObjectType()
    };
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static List<SObject> sourceRecordLines;
    public static AvaTaxService.DocumentType documentType = AvaTaxService.DocumentType.SalesInvoice;
    public static Boolean doCommit = true;

    public override TaxServiceResult calcTaxes(List<SObject> sourceDocs) {
        TaxServiceResult result = new TaxServiceResult();
        result.avaTaxCalcResult = new AvaTaxHelper.AvaTaxCalculationResult();

        Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds = prepareTaxResultLines(sourceDocs);

        this.sources = fetchSources(sourceDocs);
        sourceRecordLines = sourceRecordLines == null || sourceRecordLines.isEmpty() ? fetchSourceLines(sources) : sourceRecordLines;
        this.linesBySourceIds = linesBySourceIds(sourceRecordLines);

        resultLinesByIds = doValidation(resultLinesByIds);
        if (!this.sources.isEmpty()) {
            switch on this.sources[0] {
                when Opportunity objRecord {
                    for (Opportunity source : (List<Opportunity>)this.sources) {
                        if (resultLinesByIds.get(source.Id)?.errors?.isEmpty()) {
                            List<OpportunityLineItem> lines = (List<OpportunityLineItem>)this.linesBySourceIds.get(source.Id);
                            documentType = AvaTaxService.DocumentType.SalesOrder;
                            AvaTaxService.TransactionModel responseResult =
                                AvaTaxHelper.calcTax(source, lines, documentType, doCommit);

                            resultLinesByIds.get(source.Id).sourceObj = source;
                            resultLinesByIds.get(source.Id).sourceObjLines = new List<SObject>();
                            Double currencyConversionRate = AvaTaxHelper.getCurrencyConversionRateForOpportunity(source);
                            PricebookEntry pricebookEntryItem = fetchPricebookEntry(source);
                            if (pricebookEntryItem != null) {
                                OpportunityLineItem taxOppLineItem = new OpportunityLineItem(
                                        OpportunityId = source.Id,
                                        Quantity = 1,
                                        Description = (AvaTaxHelper.getSalesTaxProduct(source) != NULL) ? AvaTaxHelper.getSalesTaxProduct(source).Description : NULL,
                                        PricebookEntryId = pricebookEntryItem.Id,
                                        Product2Id = AvaTaxHelper.getSalesTaxProductId(source),
                                        UnitPrice = responseResult.totalTax * currencyConversionRate
                                );
                                if (doCommit) {
                                    List<OpportunityLineItem> existedSaleTaxLines = AvaTaxHelper.queryExistedSalesTaxOpportunityProductLines(
                                            source.Id, AvaTaxHelper.getSalesTaxProductId(source)
                                    );

                                    if (!existedSaleTaxLines.isEmpty()) {
                                        SFDCSecurityUtils.deleteCheckCRUDAndFLS(existedSaleTaxLines);
                                    }

                                    SFDCSecurityUtils.insertCheckCRUDAndFLS(taxOppLineItem, new List<String>{
                                            'Description', 'ServiceDate'
                                    });
                                }
                                resultLinesByIds.get(source.Id).sourceObjLines.add(taxOppLineItem);
                            } else {
                                resultLinesByIds.get(source.Id).errors.add(PRICE_BOOK_ENTRY_ERROR_MESSAGE);
                            }
                            resultLinesByIds.get(source.Id).isSuccess = resultLinesByIds.get(source.Id).errors.isEmpty();
                        }
                    }
                }
                when else {
                    if (!sourceRecordLines.isEmpty()) {
                        result.avaTaxCalcResult =
                            AvaTaxHelper.calcTaxes(sourceDocs, getSourceLinesBySource(sourceDocs, sourceRecordLines), documentType, doCommit);
                    }
                }
            }
        }

        result.sourceDocs = resultLinesByIds.values();

        return result;
    }

    private PricebookEntry fetchPricebookEntry(Opportunity sourceRecord) {
        Id salesTaxProductId = AvaTaxHelper.getSalesTaxProductId(sourceRecord);
        Id priceBookId = (Id) sourceRecord.get('Pricebook2Id');

        List<PricebookEntry> pricebookEntries = DomainUtils.getPricebookEntriesByProductAndPriceBookId(
                new Set<Id>{salesTaxProductId}, new Set<Id>{priceBookId}
        );

        PricebookEntry result = null;
        if (!pricebookEntries.isEmpty()) {
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                for (PricebookEntry entry : pricebookEntries) {
                    if (String.valueOf(entry.get('CurrencyIsoCode')).equalsIgnoreCase(String.valueOf(sourceRecord.get('CurrencyIsoCode')))) {
                        result = entry;
                        break;
                    }
                }
            } else {
                result = pricebookEntries[0];
            }
        }
        return result;
    }

    public override TaxServiceResult calcTaxes(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        markTaxLine(sourceDocs);
        return setTaxServiceResult(sourceDocs);
    }

    public override TaxServiceResult validate(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        validateTaxLine(sourceDocs);
        return setTaxServiceResult(sourceDocs);
    }

    private static void markTaxLine(List<SObject> newLines) {
        if (newLines != null && !newLines.isEmpty() && !skipCalculation4SObjectTypes.contains(newLines[0].getSObjectType())) {
            for (SObject line : newLines) {
                TaxService.TaxSetting taxSetting = TaxService.getTaxSettings(TaxService.getLedgerIdBySobject(line));
                //checkbox on a line should only be modified by our code base
                line.put(PACKAGE_QUALIFIER + 'Tax_Line__c', false);

                if (line.getSObjectType() == Billing_Line__c.getSObjectType() && taxSetting.salesTaxProductId != null) {
                    if (line.get(PACKAGE_QUALIFIER + 'Product__c') != null
                        && line.get(PACKAGE_QUALIFIER + 'Product__c') == taxSetting.salesTaxProductId) {

                        line.put(PACKAGE_QUALIFIER + 'Tax_Line__c', true);
                    }
                }
                else if (line.getSObjectType() == Account_Payable_Line__c.getSObjectType()
                    && line.get(PACKAGE_QUALIFIER + 'Product_Tax_Type__c') == 'Tax Rate') {

                    line.put(PACKAGE_QUALIFIER + 'Tax_Line__c', true);
                }
            }
        }
    }

    private static void validateTaxLine(List<SObject> newLines) {
        if (newLines != null && !newLines.isEmpty() && !skipCalculation4SObjectTypes.contains(newLines[0].getSObjectType())) {
            for (SObject line : newLines) {
                if (line.get(PACKAGE_QUALIFIER + 'Tax_Line__c') == true) {
                    TaxService.TaxSetting taxSetting = TaxService.getTaxSettings(TaxService.getLedgerIdBySobject(line));

                    if (line.getSObjectType() == Billing_Line__c.getSObjectType()
                        && (taxSetting.salesTaxProductId == NULL
                        || line.get(PACKAGE_QUALIFIER + 'Product__c') == NULL
                        || line.get(PACKAGE_QUALIFIER + 'Product__c') != taxSetting.salesTaxProductId)) {

                        line.addError(Label.ERR_NOT_VALID_TAX_LINE);
                    }
                    else if (line.getSObjectType() == Account_Payable_Line__c.getSObjectType()
                        && line.get(PACKAGE_QUALIFIER + 'Product_Tax_Type__c') != 'Tax Rate') {

                        line.addError(Label.ERR_NOT_VALID_TAX_LINE);
                    }
                }
            }
        }
    }

    //====================controller methods=================================================

    private List<SObject> fetchSourceLines(List<SObject> sourceDocs) {
        List<SObject> lines = new List<SObject>();
        switch on sourceDocs[0] {
            when Opportunity objRecord {
                lines = queryOppLineItems(
                    new Map<Id, SObject>(sourceDocs).keySet(),
                    new List<String>{
                        'Id',
                        'OpportunityId',
                        'Description',
                        'PricebookEntry.Pricebook2Id',
                        'PricebookEntry.Product2Id',
                        'PricebookEntry.Product2.Id',
                        'PricebookEntry.Product2.Name',
                        'PricebookEntry.Product2.ProductCode',
                        'PricebookEntry.Product2.Tax_Code__c',
                        'PricebookEntry.Product2.Description',
                        'Quantity',
                        'UnitPrice',
                        'Tax_Amount__c'
                    },
                    false,
                    true,
                    new List<String>{
                        'OpportunityId = :opportunityIds',
                        'PricebookEntryId != NULL',
                        'PricebookEntry.Product2Id != NULL'
                    }
                );
            }
        }
        return lines;
    }

    private List<SObject> fetchSources(List<SObject> sourceDocs) {
        List<SObject> sources = new List<SObject>();
        switch on sourceDocs[0] {
            when Opportunity objRecord {
                sources = getOpportunitiesByIds(
                    new Map<Id, SObject>(sourceDocs).keySet(),
                    new List<String>{
                        'Id',
                        'Name',
                        'AccountId',
                        'Account.Name',
                        'Account.ShippingStreet',
                        'Account.ShippingCity',
                        'Account.ShippingState',
                        'Account.ShippingCountry',
                        'Account.ShippingPostalCode',
                        'Account.VAT_Business_Identification_Number__c',
                        'Account.Entity_Use_Code__c',
                        'Account.Exemption_Number__c',
                        'Pricebook2Id',
                        'StageName',
                        'Amount',
                        'Description',
                        'CloseDate',
                        'isWon'
                    },
                    true,
                    true
                );
            }
            when else {
                sources = sourceDocs;
            }
        }

        return sources;
    }

    protected override Map<Id, TaxServiceResult.TaxServiceResultLine> doValidation(Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds) {
        resultLinesByIds = super.doValidation(resultLinesByIds);
        if (!this.sources.isEmpty()) {
            switch on this.sources[0] {
                when Opportunity objRecord {
                    for (Opportunity source: (List<Opportunity>)this.sources) {
                        if (!AvaTaxHelper.isLedgerCurrencySupportedByAvaTaxCalculation(TaxService.sobjectByLedgerId.get(TaxService.getKeySobject(this.sources[0])))) {
                            resultLinesByIds.get(source.Id).errors.add(Label.ERR_AVATAX_ONLY_USD_LEDGER);
                        }
                    }
                }
            }
        }
        return resultLinesByIds;
    }
}