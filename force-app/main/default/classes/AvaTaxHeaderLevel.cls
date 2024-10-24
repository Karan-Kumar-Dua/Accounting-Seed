public with sharing class AvaTaxHeaderLevel extends AbstractTaxService {
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

                            resultLinesByIds.get(source.Id).sourceObj = source;
                            resultLinesByIds.get(source.Id).sourceObjLines = lines;
                            resultLinesByIds.get(source.Id).isSuccess = resultLinesByIds.get(source.Id).errors.isEmpty();
                        }
                    }
                }
            }
        }

        result.sourceDocs = resultLinesByIds.values();

        if (!sourceRecordLines.isEmpty() && !this.sources.isEmpty()) {
            switch on this.sources[0] {
                when Opportunity objRecord {
                    TaxService.sobjectByLedgerId.put(this.sources[0], TaxService.sobjectByLedgerId.get(TaxService.getKeySobject(sourceDocs[0])));
                    result = prepareOpportunityResult(result, this.sources);
                }
                when else {
                    result.avaTaxCalcResult =
                            AvaTaxHelper.calcTaxes(this.sources, getSourceLinesBySource(this.sources, sourceRecordLines), documentType, doCommit);
                }
            }
        }
        return result;
    }

    public override TaxServiceResult calcTaxes(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        switch on sourceDocs[0] {
            when Account_Payable_Line__c objRecord {
                HeaderLevelTaxHelper.calculateTaxAmountAndSetTaxGroup(sourceDocs, sourceDocsMap);
            }
            when Recurring_Account_Payable_Line__c objRecord {
                HeaderLevelTaxHelper.calculateTaxAmountAndSetTaxGroup(sourceDocs, sourceDocsMap);
            }
            when else {
                HeaderLevelTaxHelper.clearTaxGroupInAvaTaxMode(sourceDocs, sourceDocsMap);
            }
        }
        return setTaxServiceResult(sourceDocs);
    }

    public override TaxServiceResult validate(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        switch on sourceDocs[0] {
            when Account_Payable_Line__c objRecord {
                HeaderLevelTaxHelper.validate(sourceDocs, sourceDocsMap);
                return setTaxServiceResult(sourceDocs);
            }
            when Recurring_Account_Payable_Line__c objRecord {
                HeaderLevelTaxHelper.validate(sourceDocs, sourceDocsMap);
                return setTaxServiceResult(sourceDocs);
            }
        }
        return new TaxServiceResult();
    }

    //====================controller methods=================================================

    private TaxServiceResult prepareOpportunityResult(TaxServiceResult result, List<SObject> sources) {
        if (!sources.isEmpty()) {
            documentType = AvaTaxService.DocumentType.SalesOrder;
            if (result.sourceDocs[0].errors.isEmpty()) {
                Double currencyConversionRate = AvaTaxHelper.getCurrencyConversionRateForOpportunity(sources[0]);
                AvaTaxService.TransactionModel transactionModel = AvaTaxHelper.calcTax(sources[0], getSourceLinesBySource(sources, sourceRecordLines), documentType, doCommit);
                List<OpportunityLineItem> lines = (List<OpportunityLineItem>)this.linesBySourceIds.get(sources[0].Id);
                Double taxAmount = 0;
                if (lines != null) {
                    for (OpportunityLineItem line : lines) {
                        if (transactionModel.getLinesMap().containsKey(line.Id)) {
                            line.Tax_Amount__c = transactionModel.getLinesMap().get(line.Id).taxCalculated * currencyConversionRate;
                            taxAmount += line.Tax_Amount__c;
                        }
                    }
                }

                if (result.sourceDocs[0].sourceObj != null) {
                    result.sourceDocs[0].sourceObj.put(PACKAGE_QUALIFIER + 'Tax_Amount__c', taxAmount);
                    result.avaTaxCalcResult = new AvaTaxHelper.AvaTaxCalculationResult();
                    result.avaTaxCalcResult.addAvaTaxReport(new AvaTaxHelper.AvaTaxCalculationReport(
                        true, sources[0].Id, lines, NULL
                    ));
                }
            }
        }

        return result;
    }

    private List<SObject> fetchSourceLines(List<SObject> sourceDocs) {
        List<SObject> lines = new List<SObject>();
        switch on sourceDocs[0] {
            when Opportunity objRecord {
                lines = queryOppLineItems(
                        new Map<Id, SObject>(sourceDocs).keySet(),
                        new List<String>{
                                'Id',
                                'Name',
                                'TotalPrice',
                                'ServiceDate',
                                'Quantity',
                                'UnitPrice',
                                'OpportunityId',
                                'Description',
                                'PricebookEntry.Pricebook2Id',
                                'PricebookEntry.Product2Id',
                                'PricebookEntry.Product2.Id',
                                'PricebookEntry.Product2.Name',
                                'PricebookEntry.Product2.ProductCode',
                                'PricebookEntry.Product2.Tax_Code__c',
                                'PricebookEntry.Product2.Description',
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