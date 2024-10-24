public with sharing abstract class AbstractTaxService {

    //labels
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String NO_ACCOUNT_ERROR_MESSAGE = Label.NO_ACCOUNT_ERROR_MESSAGE;
    public static final String NO_ACCOUNT_ERROR_CODE = Label.ERR_NO_ACCOUNT_ERROR_CODE;
    public static final String NO_OPPORTUNITY_PRODUCT_LINE_MESSAGE = Label.NO_OPPORTUNITY_PRODUCT_LINE_MESSAGE;
    public static final String NO_OPPORTUNITY_PRODUCT_LINE_CODE = Label.ERR_NO_OPPORTUNITY_PRODUCT_LINE_CODE;

    public List<SObject> sources = new List<SObject> ();
    public Map<Id, List<SObject>> linesBySourceIds = new Map<Id, List<SObject>>();

    public static Map<SObjectType, SObjectField> parentObjectByObjectTypes = new Map<SObjectType, SObjectField>{
        Billing_Line__c.SObjectType => Billing_Line__c.Billing__c,
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Account_Payable__c,
        OpportunityLineItem.SObjectType => OpportunityLineItem.OpportunityId
    };

    public TaxServiceResult calcTax(SObject sourceDoc) {
        return this.calcTaxes(new List<SObject>{sourceDoc});
    }

    public abstract TaxServiceResult calcTaxes(List<SObject> sourceDocs);
    // trigger version of calcTaxes
    public abstract TaxServiceResult calcTaxes(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap);
    // trigger validation for calcTaxes
    public virtual TaxServiceResult validate(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        return new TaxServiceResult();
    }

    protected Map<Id, TaxService.TaxSetting> getTaxSettings() {
        return TaxService.getTaxSettings();
    }

    protected TaxService.TaxSetting getTaxSettings(Id ledgerId) {
        return getTaxSettings().get(ledgerId);
    }

    protected TaxService.TaxSetting getTaxSettings(SObject sourceDoc) {
        return TaxService.getTaxSettings(sourceDoc);
    }

    public Decimal getTaxRoundingThreshold(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.taxRoundingThreshold;
    }

    public String getAvalaraAccountID(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.license?.avaTaxAccountId;
    }

    public String getAvalaraLicenseKey(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.license?.avaTaxLicenseKey;
    }

    public String getAvalaraEndpoint(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.license?.activeAvaTaxEndpoint;
    }

    public String getTaxMethod(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.taxMethod;
    }

    public String getOriginAddressId(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.originAddressId;
    }

    public TaxService.OriginAddress getOriginAddress(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.originAddress;
    }

    public String getSalesTaxGLAccount(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.salesTaxGLAccountId;
    }

    public String getSalesTaxProduct(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.salesTaxProductId;
    }

    public String getSalesTaxCalculationMode(SObject sourceDoc) {
        return getTaxSettings(sourceDoc)?.salesTaxCalculationMode;
    }

    protected String getPostSettings() {
        return AccountingSettingsHandler.getAccountingSettings().Post_Settings__c;
    }

    public String getSalesTaxCompanyCode(SObject sourceDoc) {
        return LedgerHandler.getInstanceWithoutSharing().getLedgerById(TaxService.getLedgerIdBySobject(sourceDoc))?.Sales_Tax_Company_Code__c;
    }

    protected TaxServiceResult setTaxServiceResult(List<SObject> objects) {
        TaxServiceResult result = new TaxServiceResult();
        for (SObject obj : objects) {
            TaxServiceResult.TaxServiceResultLine line = new TaxServiceResult.TaxServiceResultLine();
            line.isSuccess = true;
            line.sourceObj = obj;
            if (!obj.getErrors().isEmpty()) {
                line.isSuccess = false;
                for (Database.Error dbError : obj.getErrors()) {
                    line.errors.add(dbError.getMessage());
                }
            }
            result.sourceDocs.add(line);
        }
        return result;
    }

    protected List<SObject> getSourceLinesBySource(List<SObject> sourceDocs, List<SObject> sourceRecordLines) {
        List<SObject> result = new List<SObject>();
        Map<Id, SObject> sourceDocsByIds = new Map<Id, SObject>(sourceDocs);
        for (SObject line : sourceRecordLines) {
            SObjectField field = parentObjectByObjectTypes.get(line.getSObjectType());
            if (sourceDocsByIds.containsKey((Id) line.get(field))) {
                result.add(line);
            }
        }
        return result;
    }

    protected Map<Id, List<SObject>> linesBySourceIds(List<SObject> sourceLines) {
        Map<Id, List<SObject>> linesBySourceIds = new Map<Id, List<SObject>>();
        if (!sourceLines.isEmpty()) {
            SObjectField field = parentObjectByObjectTypes.get(sourceLines[0].getSObjectType());
            for (SObject line : sourceLines) {
                Id sourceId = (Id) line.get(field);
                List<SObject> tempSourceLines = linesBySourceIds.containsKey(sourceId) ?
                    linesBySourceIds.get(sourceId) : new List<SObject>();
                tempSourceLines.add(line);
                linesBySourceIds.put(sourceId, tempSourceLines);
            }
        }
        return linesBySourceIds;
    }

    public static Boolean isLedgerTaxSettingsEmpty(SObject sourceDoc) {
        return LedgerHandler.getInstanceWithoutSharing().getLedgerById(TaxService.getLedgerIdBySobject(sourceDoc))?.Tax_Settings__c == null;
    }

    public static List<Opportunity> getOpportunitiesByIds(Set<Id> ids, List<String> queryFields, Boolean assertIsAccessible, Boolean isEnforceFLS) {
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Opportunity.SObjectType);
        (assertIsAccessible ? (theQuery.assertIsAccessible()) : theQuery)
                .setEnforceFLS(isEnforceFLS)
                .selectFields(queryFields)
                .setCondition(queryCondition);

        return (List<Opportunity>) Database.query(theQuery.toSOQL());
    }

    public static List<OpportunityLineItem> queryOppLineItems(Set<Id> opportunityIds, List<String> queryFields, Boolean assertIsAccessible, Boolean isEnforceFLS) {
        return queryOppLineItems(opportunityIds, queryFields, assertIsAccessible, isEnforceFLS, new List<String>{'OpportunityId = :opportunityIds'});
    }

    public static List<OpportunityLineItem> queryOppLineItems(Set<Id> opportunityIds, List<String> queryFields, Boolean assertIsAccessible, Boolean isEnforceFLS, List<String> conditions) {
        if (DomainUtils.isDiscountIncludedInOpportunityLineItems(opportunityIds)) {
            queryFields.add('Discount');
        }

        SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
        (assertIsAccessible ? (theQuery.assertIsAccessible()) : theQuery)
                .setEnforceFLS(isEnforceFLS)
                .selectFields(queryFields)
                .setCondition(String.join(conditions, ' AND '));

        return (List<OpportunityLineItem>) Database.query(theQuery.toSOQL());
    }

    protected Map<Id, TaxServiceResult.TaxServiceResultLine> prepareTaxResultLines(List<SObject> sourceDocs) {
        Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds = new Map<Id, TaxServiceResult.TaxServiceResultLine>();
        for (SObject obj : sourceDocs) {
            TaxServiceResult.TaxServiceResultLine line = new TaxServiceResult.TaxServiceResultLine();
            line.isSuccess = false;
            resultLinesByIds.put(obj.Id, line);
        }
        return resultLinesByIds;
    }

    protected virtual Map<Id, TaxServiceResult.TaxServiceResultLine> doValidation(Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds) {
        if (!this.sources.isEmpty()) {
            switch on this.sources[0] {
                when Opportunity objRecord {
                    for (Opportunity source: (List<Opportunity>)this.sources) {
                        if (String.isBlank(source.AccountId)) {
                            resultLinesByIds.get(source.Id).errors.add(NO_ACCOUNT_ERROR_MESSAGE, NO_ACCOUNT_ERROR_CODE);
                        }
                        if (linesBySourceIds.get(source.Id) == null || linesBySourceIds.get(source.Id).isEmpty()) {
                            resultLinesByIds.get(source.Id).errors.add(NO_OPPORTUNITY_PRODUCT_LINE_MESSAGE, NO_OPPORTUNITY_PRODUCT_LINE_CODE);
                        }
                    }
                }
            }
        }
        return resultLinesByIds;
    }

    public static Map<Id, Decimal> getTaxRateAdjustmentByAmount (Decimal amount, List<Tax_Rate__c> rates) {
        Map<Id, Decimal> rateToDecimalMap = new Map<Id, Decimal>();
        Decimal rawTaxAmount = 0;
        Decimal roundedTaxAmount = 0;

        for (Tax_Rate__c taxGroupRate : rates) {
            Decimal taxRate = taxGroupRate.Tax_Rate__c/100;
            rawTaxAmount += (taxRate * amount);
            roundedTaxAmount += (taxRate * amount).setScale(2, RoundingMode.HALF_UP);
        }

        if (roundedTaxAmount.setScale(2, RoundingMode.HALF_UP) != rawTaxAmount.setScale(2, RoundingMode.HALF_UP)) {
            Tax_Rate__c maxRate = rates[0];
            for (Tax_Rate__c taxRate : rates) {
                if (maxRate.Tax_Rate__c < taxRate.Tax_Rate__c) {
                    maxRate = taxRate;
                }
            }

            rateToDecimalMap.put(maxRate.Id, rawTaxAmount.setScale(2, RoundingMode.HALF_UP) - roundedTaxAmount.setScale(2, RoundingMode.HALF_UP));
        }
        return rateToDecimalMap;
    }

    /**
     * Calculate adustment when the line is tax inclusive. 
     * This means the tax amount recorded on the source document or line is using the 
     * combined tax rate form the tax group. However, the tax amount calculated by the
     * posting processes used the individual tax rates. Any differences bewteen the 
     * combined rate caluclation and the individual rate calculation must be adjusted
     * so that the source doc matches the transaction amount.
     */
    public static Map<Id, Decimal> getTaxRateAdjustmentByAmount (Decimal amount, List<Tax_Rate__c> rates, Decimal combinedTaxAmount) {
        Map<Id, Decimal> rateToDecimalMap = new Map<Id, Decimal>();
        Decimal roundedTaxAmount = 0;

        for (Tax_Rate__c taxGroupRate : rates) {
            Decimal taxRate = taxGroupRate.Tax_Rate__c/100;
            roundedTaxAmount += (taxRate * amount).setScale(2, RoundingMode.HALF_UP);
        }

        if (roundedTaxAmount != combinedTaxAmount) {
            Tax_Rate__c maxRate = rates[0];
            for (Tax_Rate__c taxRate : rates) {
                if (maxRate.Tax_Rate__c < taxRate.Tax_Rate__c) {
                    maxRate = taxRate;
                }
            }
            rateToDecimalMap.put(maxRate.Id, combinedTaxAmount - roundedTaxAmount);
        }

        return rateToDecimalMap;
    }

}