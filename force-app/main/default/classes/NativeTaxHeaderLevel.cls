public with sharing class NativeTaxHeaderLevel extends AbstractTaxService {

    public override TaxServiceResult calcTaxes(List<SObject> sourceDocs) {
        TaxServiceResult result = new TaxServiceResult();
        try {
            if (!sourceDocs.isEmpty()) {
                result.sourceDocs.addAll(processCalcTaxes(sourceDocs).values());
            }
        }
        catch (Exception ex) {
        }
        return result;
    }

    public override TaxServiceResult calcTaxes(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        HeaderLevelTaxHelper.calculateTaxAmountAndSetTaxGroup(sourceDocs, sourceDocsMap);
        return setTaxServiceResult(sourceDocs);
    }

    public override TaxServiceResult validate(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        HeaderLevelTaxHelper.validate(sourceDocs, sourceDocsMap);
        return setTaxServiceResult(sourceDocs);
    }

    //====================controller methods=================================================

    private Map<Id, TaxServiceResult.TaxServiceResultLine> processCalcTaxes(List<SObject> sourceDocs) {
        Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds = prepareTaxResultLines(sourceDocs);

        this.sources = fetchSources(sourceDocs);
        this.linesBySourceIds = fetchSourceLines(sourceDocs);

        resultLinesByIds = doValidation(resultLinesByIds);

        return calculateTaxes(resultLinesByIds);
    }

    private Map<Id, TaxServiceResult.TaxServiceResultLine> calculateTaxes(Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds) {
        switch on this.sources[0] {
            when Opportunity objRecord {
                for (Opportunity source : (List<Opportunity>)this.sources) {
                    if (resultLinesByIds.get(source.Id)?.errors?.isEmpty()) {
                        source.Tax_Amount__c = 0;
                        List<OpportunityLineItem> lines = (List<OpportunityLineItem>)this.linesBySourceIds.get(source.Id);
                        for (OpportunityLineItem lineItem : lines) {
                            setLineTaxGroup(lineItem);
                            Decimal lineSubTotal = (lineItem.UnitPrice * (100 - getDiscount(lineItem)) / 100) * lineItem.Quantity;
                            lineItem.Tax_Amount__c = (lineSubTotal * getLineTaxRate(lineItem)).setScale(2, System.RoundingMode.HALF_UP);

                            source.Tax_Amount__c += lineItem.Tax_Amount__c;
                        }

                        source.Tax_Amount__c = source.Tax_Amount__c.setScale(2, System.RoundingMode.HALF_UP);

                        resultLinesByIds.get(source.Id).sourceObj = source;
                        resultLinesByIds.get(source.Id).sourceObjLines = lines;
                        resultLinesByIds.get(source.Id).isSuccess = resultLinesByIds.get(source.Id).errors.isEmpty();
                    }
                }
            }
        }
        return resultLinesByIds;
    }

    private Decimal getDiscount(SObject lineItem) {
        Decimal discountValue = 0;
        switch on this.sources[0] {
            when Opportunity objRecord {
                OpportunityLineItem oppLineItem = (OpportunityLineItem)lineItem;
                if (oppLineItem.getPopulatedFieldsAsMap().get('Discount') != NULL) {
                    discountValue = oppLineItem.Discount;
                }
            }
        }
        return discountValue;
    }

    private Decimal setLineTaxGroup(SObject lineItem) {
        Decimal taxRate = 0;
        switch on this.sources[0] {
            when Opportunity objRecord {
                OpportunityLineItem oppLineItem = (OpportunityLineItem)lineItem;
                if (isPreviewParamsIsEmpty(oppLineItem)
                    && oppLineItem.Tax_Group__c == null
                    && oppLineItem.PriceBookEntry.Product2.Tax_Group__c != null
                    && HeaderLevelTaxConsts.SALES_TAX_RATE_TYPES.contains(oppLineItem.PriceBookEntry.Product2.Tax_Group__r.Tax_Type__c)) {
                    oppLineItem.Tax_Group__c = oppLineItem.PriceBookEntry.Product2.Tax_Group__c;
                }
            }
        }
        return taxRate;
    }

    private Decimal getLineTaxRate(SObject lineItem) {
        Decimal taxRate = 0;
        switch on this.sources[0] {
            when Opportunity objRecord {
                OpportunityLineItem oppLineItem = (OpportunityLineItem)lineItem;
                if (TaxService.previewParamsByIds != null && TaxService.previewParamsByIds.get(oppLineItem.Id) != null &&
                        TaxService.previewParamsByIds.get(oppLineItem.Id).get('taxSettingCombinedRate') != null) {
                    Decimal taxSettingCombinedRate = (Decimal)TaxService.previewParamsByIds.get(oppLineItem.Id).get('taxSettingCombinedRate');
                    taxRate = taxSettingCombinedRate / 100;
                } else if (isPreviewParamsIsEmpty(oppLineItem) && oppLineItem.Tax_Group__r != null) {
                    taxRate = oppLineItem.Tax_Group__r.Combined_Tax_Rate__c / 100;
                } else if (isPreviewParamsIsEmpty(oppLineItem) && oppLineItem.PriceBookEntry.Product2.Tax_Group__c != null
                    && HeaderLevelTaxConsts.SALES_TAX_RATE_TYPES.contains(oppLineItem.PriceBookEntry.Product2.Tax_Group__r.Tax_Type__c)) {
                    taxRate = oppLineItem.PriceBookEntry.Product2.Tax_Group__r.Combined_Tax_Rate__c / 100;
                }
            }
        }
        return taxRate;
    }

    private Boolean isPreviewParamsIsEmpty(OpportunityLineItem oppLineItem) {
        return TaxService.previewParamsByIds == null || !TaxService.previewParamsByIds.containsKey(oppLineItem.Id);
    }

    private Map<Id, List<SObject>> fetchSourceLines(List<SObject> sourceDocs) {
        Map<Id, List<SObject>> linesBySourceIds = new Map<Id, List<SObject>>();
        switch on sourceDocs[0] {
            when Opportunity objRecord {
                linesBySourceIds = linesBySourceIds(queryOppLineItems(
                        new Map<Id, SObject>(sourceDocs).keySet(),
                        new List<String>{
                                'Id',
                                'Name',
                                'TotalPrice',
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
                                'PriceBookEntry.Product2.Tax_Group__c',
                                'PriceBookEntry.Product2.Tax_Group__r.Combined_Tax_Rate__c',
                                'PriceBookEntry.Product2.Tax_Group__r.Tax_Type__c',
                                'GL_Account_Variable_1__c',
                                'GL_Account_Variable_2__c',
                                'GL_Account_Variable_3__c',
                                'GL_Account_Variable_4__c',
                                'Project__c',
                                'Project_Task__c',
                                'Description',
                                'Tax_Group__c',
                                'Tax_Group__r.Combined_Tax_Rate__c'
                        },
                        true,
                        true
                    )
                );
            }
        }
        return linesBySourceIds;
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
                                'Amount',
                                'AccountId',
                                'Account.Name',
                                'Pricebook2Id',
                                'Tax_Amount__c'

                        },
                        true,
                        true
                );
            }
        }

        return sources;
    }
}