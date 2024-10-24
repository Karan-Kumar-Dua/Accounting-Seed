public with sharing class BillingSalesAvaTax extends AbstractAvaTaxController {

    public Boolean isHeaderLevelPostEnabled {get; set;}
    public String currencyIsoCode {get; set;}
    public Boolean isProcessed {get; set;}
    public Map<Id, BillingLineWrapper> billingLinesWithEstimatedTaxAmount {get; set;}
    public Decimal estimatedTaxAmount {get; set;}
    public Decimal estimatedTotal {get; set;}

    public BillingSalesAvaTax(ApexPages.StandardController con) {
        try {
            estimatedTaxAmount = 0;
            estimatedTotal = ((Billing__c) con.getRecord()).Sub_Total__c;
            isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
            isProcessed = false;
            sourceRecordId = (Id) con.getId();
            sourceRecord = AvaTaxHelper.queryBillingById(new Set<Id>{sourceRecordId}, false)[0];
            currencyIsoCode = (isMultiCurrencyEnabled) ? (String) sourceRecord.get('CurrencyIsoCode') : NULL;
            if (AbstractTaxService.isLedgerTaxSettingsEmpty(sourceRecord)) {
                throw new AvaTaxService.AvaTaxException(TaxService.getNoTaxSettingErrorMessage(false));
            }
            if (!AvaTaxHelper.isLedgerCurrencySupportedByAvaTaxCalculation((Id) sourceRecord.get(PACKAGE_QUALIFIER + 'Ledger__c'))) {
                throw new AvaTaxService.AvaTaxException(INCORRECT_CURRENCY_ERROR_MESSAGE);
            }
            if (sourceRecord.get(PACKAGE_QUALIFIER + 'Status__c') == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                throw new AvaTaxService.AvaTaxException(POSTED_RECORD_ERROR_MESSAGE);
            }
            if (SourceDocumentUpdateFieldValidator.hasAppliedRecord((Billing__c) sourceRecord)) {
                throw new AvaTaxService.AvaTaxException(APPLIED_RECORD_ERROR_MESSAGE);
            }
            AvaTaxHelper.sourceRecordMap = new Map<Id, SObject> {sourceRecordId => sourceRecord};
            sourceRecordLines = AvaTaxHelper.queryTaxableBillingLinesByBillingId(new Set<Id>{sourceRecordId}, !isHeaderLevelPostEnabled, true);
            if (sourceRecordLines.isEmpty()) {
                throw new AvaTaxService.AvaTaxException(NO_LINES_ERROR_MESSAGE);
            }
            if (((Billing__c) sourceRecord).Line_Count__c > ldvCalcTaxLineLimit && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(Label.ERR_LDV_AVALARA_CALC_TAX_LIMIT, new List<String>{SObjectType.Billing__c.getLabel(), String.valueOf(ldvCalcTaxLineLimit)})
                    )
                );
                isProcessed = true;
            }
        }
        catch (Exception ex) {
            isProcessed = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
        }
    }

    public void estimateTax() {
        if (!isProcessed) {
            try {
                billingLinesWithEstimatedTaxAmount = new Map<Id, BillingLineWrapper>();

                AvaTaxService.TransactionModel responseResult = new AvaTaxService.TransactionModel();
                Boolean doAvaTaxCalculation = true;

                if (isHeaderLevelPostEnabled) {
                    if (!AvaTaxHelper.validateShippingAddress(sourceRecord) && !AvaTaxHelper.validateDestinationAddress(sourceRecord)) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.WARNING, SHIPPING_ADDRESS_MISSING_WARNING_MESSAGE));
                        doAvaTaxCalculation = false;
                    }
                    if (!validateTaxableBillingLineExists()) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.WARNING, NO_TAXABLE_LINES_FOUND_WARNING_MESSAGE));
                        doAvaTaxCalculation = false;
                    }
                }

                if (doAvaTaxCalculation) {
                    responseResult = AvaTaxHelper.calcTax(
                        sourceRecord, sourceRecordLines, AvaTaxService.DocumentType.SalesOrder, false
                    );
                }

                Double ccr = AvaTaxHelper.getCurrencyConversionRate(sourceRecord);

                if (isHeaderLevelPostEnabled) {
                    for (Billing_Line__c billLine : (List<Billing_Line__c>) sourceRecordLines) {
                        if (responseResult.getLinesMap().containsKey(billLine.Name)) {
                            billLine.Tax_Amount2__c = responseResult.getLinesMap().get(billLine.Name).taxCalculated * ccr;
                            estimatedTaxAmount += billLine.Tax_Amount2__c;
                        }
                        BillingLineWrapper wrappedBillingLine = new BillingLineWrapper(billLine);
                        billingLinesWithEstimatedTaxAmount.put(wrappedBillingLine.billingLine.Id, wrappedBillingLine);
                    }
                    estimatedTotal += estimatedTaxAmount;
                }
                else {
                    Billing_Line__c taxBillLine = new Billing_Line__c(
                        Billing__c = sourceRecord.Id,
                        Hours_Units__c = 1,
                        Revenue_GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(sourceRecord),
                        Product__c = AvaTaxHelper.getSalesTaxProductId(sourceRecord)
                    );
                    taxBillLine.Rate__c = responseResult.totalTax * ccr;
                    BillingLineWrapper wrappedTaxBillingLine = new BillingLineWrapper(taxBillLine);
                    billingLinesWithEstimatedTaxAmount.put(wrappedTaxBillingLine.billingLine.Id, wrappedTaxBillingLine);
                }

            }
            catch (Exception ex) {
                isProcessed = true;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, ex.getMessage()));
            }
        }
    }

    public override AvaTaxService.AvaTaxResult pushAvaTaxTransaction() {
        AvaTaxService.AvaTaxResult result;
        try {
            AvaTaxService.TransactionModel responseResult = AvaTaxHelper.calcTax(
                sourceRecord, sourceRecordLines, AvaTaxService.DocumentType.SalesInvoice, false
            );

            if (isHeaderLevelPostEnabled) {
                AvaTaxHelper.populateTaxAmountOnLine(sourceRecord.Id, responseResult);
            }
            else {
                //remove any old tax lines and create new tax lines for each posted record
                AvaTaxHelper.upsertTaxLine(sourceRecord.Id, responseResult);
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

    public PageReference commitTax() {
        try {
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
        }

        isProcessed = true;
        return NULL;
    }

    public String getPageBlockTitle() {
        String result = '';
        if (isHeaderLevelPostEnabled) {
            result = Label.INF_ESTIMATED_TAXES;
        }
        else {
            result = Label.COMMON_CREATE_OR_UPDATE_TAX_LINE;
        }
        return result;
    }

    public with sharing class BillingLineWrapper {
        public Billing_Line__c billingLine {get; set;}

        public BillingLineWrapper(Billing_Line__c bLine) {
            this.billingLine = bLine;
        }

        public Decimal getEstimatedTotal() {
            return billingLine.Sub_Total__c + billingLine.Tax_Amount2__c;
        }
    }

}