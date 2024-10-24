public with sharing abstract class AbstractBillingFromSource {

    public abstract void createBillings();

    @TestVisible
    private static final String HEADER_RATE_LABEL = Label.COMMON_PRICE;
    private static final String PURPOSE_CUSTOMER_RECEIPT = Label.INF_PURPOSE_CUSTOMER_RECEIPT;
    @TestVisible
    private static final String REFERENCE_NAME_DATE_FORMAT = Label.COMMON_REFERENCE_NAME_DATE_FORMAT;

    public static final String ACCOUNTING_PERIOD_ERROR = Label.ERR_SOURCE_BILLING_ACCOUNTING_PERIOD;
    public static final String BILLING_EXISTS_WARNING = Label.WNG_SOURCE_BILLING_EXISTS_WARNING;
    public static final String NO_RBLINES_SELECTED_ERROR = Label.ERR_SOURCE_BILLING_NO_RBLINES_SELECTED;
    public static final String NO_ACCOUNT_ERROR = Label.ERR_SOURCE_BILLING_NO_ACCOUNT;

    public List<BillingLineWrapper> wrappedLines {get; set;}
    public Boolean isMultiCurrencyEnabled {get; set;}
    public Boolean isAvalaraTaxCalcEnabled {get; set;}
    public Boolean isHeaderLevelPostEnabled {get; set;}
    public String currencyIsoCode {get; set;}
    public RecordFromSourceResultDispatcher dispatcher = new RecordFromSourceResultDispatcher();
    public class CreateFromSourceException extends Exception {}

    protected List<SObject> sourceRecords;
    protected List<SObject> sourceRecordLines;
    @TestVisible
    protected List<Billing__c> newBillings;
    protected List<Billing_Line__c> newBillingLines;
    protected Map<Id, Decimal> combinedTaxRateByTaxGroupId;

    //Common validation methods
    protected void validateAccountingPeriod(String sourceRecordLookupFieldApiName) {
        List<Billing__c> validBillings = new List<Billing__c>();
        for (Billing__c newBilling : newBillings) {
            if (!isAccountingPeriodExists(newBilling.Date__c)) {
                dispatcher.addError(
                    (String) newBilling.get(sourceRecordLookupFieldApiName),
                    new RecordFromSourceResult.RecordFromSourceResultError(
                        RecordFromSourceResult.StatusCode.CLOSED_ACCOUNTING_PERIOD,
                        ACCOUNTING_PERIOD_ERROR
                    )
                );
            }
            else {
                newBilling.Accounting_Period__c = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(newBilling.Date__c, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Billing__c.SObjectType).Id;
                validBillings.add(newBilling);
            }
        }

        newBillings = validBillings;
    }

    protected Boolean isAccountingPeriodExists(Date billDate) {
        Boolean retVal = false;
        Accounting_Period__c period =
            AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(billDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Billing__c.SObjectType);

        if (period != NULL) {
            retVal = true;
        }
        return retVal;
    }

    protected void validateAccountId() {
        List<SObject> validRecords = new List<SObject>();
        for (SObject sourceRecord : sourceRecords) {
            if (sourceRecord.get('AccountId') == NULL) {
                dispatcher.addError(
                    sourceRecord.Id,
                    new RecordFromSourceResult.RecordFromSourceResultError(
                        RecordFromSourceResult.StatusCode.NO_ACCOUNT_ID,
                        NO_ACCOUNT_ERROR
                    )
                );
            }
            else {
                validRecords.add(sourceRecord);
            }
        }

        sourceRecords = validRecords;
    }

    //Common functional methods
    protected List<Billing__c> showWarningMessageIfThereAreExistedBillings( String sourceRecordLookupFieldApiName,
                                                                Set<Id> sourceRecordsId,
                                                                SObjectType objType,
                                                                Boolean showError) {

        List<String> queryFields = new List<String>{
                'Name',
                'Opportunity__c'
        };
        String queryCondition = sourceRecordLookupFieldApiName + ' IN :sourceRecordsId';
        SOQLBuilder theQuery = new SOQLBuilder(objType);
        theQuery
            .assertIsAccessible()
            .selectFields(queryFields)
            .setCondition(queryCondition);
        List<Billing__c> resultList = Database.query(theQuery.toSOQL());
        if (!resultList.isEmpty() && showError) {
            String sObjectName = Id.valueOf(new List<Id>(sourceRecordsId)[0]).getSobjectType().getDescribe().getName();
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.WARNING,
                    String.format(BILLING_EXISTS_WARNING, new List<String>{sObjectName})
                )
            );
        }
        return resultList;
    }

    protected void wrapLines(Billing__c bill) {
        wrappedLines = new List<BillingLineWrapper>();
        for (Billing_Line__c line : newBillingLines) {
            BillingLineWrapper wrappedLine = new BillingLineWrapper(line, bill);
            if (line.Tax_Group__c != NULL && combinedTaxRateByTaxGroupId.keySet().contains(line.Tax_Group__c)) {
                wrappedLine.setLineTaxRate(combinedTaxRateByTaxGroupId.get(line.Tax_Group__c));
            }
            wrappedLines.add(wrappedLine);
        }
    }

    protected void unwrapLines() {
        List<Billing_Line__c> unWrappedBillingLines = new List<Billing_Line__c>();
        for (BillingLineWrapper line : wrappedLines) {
            if (line.isSelected) {
                unWrappedBillingLines.add(line.billingLineRec.clone());
            }
        }

        newBillingLines = unWrappedBillingLines;
    }

    protected Cash_Receipt__c createCashReceipt(Billing__c bill,
                                                Id accountId,
                                                Boolean useMasterCurrency) {

        Cash_Receipt__c cr = new Cash_Receipt__c(
            Account__c = accountId,
            Amount__c = bill.Total__c,
            Ledger__c = bill.Ledger__c,
            Receipt_Date__c = bill.Date__c,
            Accounting_Period__c = bill.Accounting_Period__c,
            Purpose__c = PURPOSE_CUSTOMER_RECEIPT,
            Payment_Reference__c = bill.Name + ' - ' + System.now().format(REFERENCE_NAME_DATE_FORMAT)
        );
        if (useMasterCurrency) {
            cr.put('CurrencyIsoCode', (String) bill.get('CurrencyIsoCode'));
        }

        return cr;
    }

    protected Billing_Cash_Receipt__c createBillingCashReceipt(Cash_Receipt__c cashReceipt, Billing__c bill, Boolean useMasterCurrency) {
        Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
        bcr.Accounting_Period__c = bill.Accounting_Period__c;
        bcr.Applied_Amount__c = cashReceipt.Amount__c;
        bcr.Billing__c = bill.Id;
        bcr.Cash_Receipt__c = cashReceipt.Id;
        // Set the applied date only if it falls within the accounting period.
        // Otherwise, date will be set to default on save.
        // Validated on insert -> 
        // BillingCashReceiptActions.validateAppliedDateIsInAppliedAccountingPeriod
        if (AccountingPeriodHandler.getInstance().isDateWithinTheAccountingPeriod(cashReceipt.Receipt_Date__c, bcr.Accounting_Period__c)) {
            bcr.Applied_Date__c = cashReceipt.Receipt_Date__c;
        }
        if (useMasterCurrency) {
            bcr.put('CurrencyIsoCode', (String) bill.get('CurrencyIsoCode'));
        }

        return bcr;
    }

    protected List<Billing__c> queryBillingByIds(Set<Id> billingIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Accounting_Period__c',
            'Date__c',
            'Ledger__c',
            'Total__c',
            'Customer__c',
            'Currency_Conversion_Rate__c',
            'Opportunity__c'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :billingIds';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    public String getHEADER_RATE_LABEL() {
        return HEADER_RATE_LABEL;
    }

    public String getSubTotalLabel() {
        String result = Schema.Opportunity.Amount.getDescribe().getLabel();
        if (isHeaderLevelPostEnabled) {
            result = Schema.Billing_Line__c.Sub_Total__c.getDescribe().getLabel();
        }
        return result;
    }

    protected void populateRevenueGLAccount(Id ledgerId) {
        Map<String, GL_Account_Default__c> defaults = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
        if (defaults.containsKey(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT)) {
            for (BillingLineWrapper bw : wrappedLines) {
                if (bw.billingLineRec.Revenue_GL_Account__c == NULL) {
                    bw.billingLineRec.Revenue_GL_Account__c = defaults.get(GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT).GL_Account__c;
                }
            }
        }
    }

    //Inner Classes
    public with sharing class BillingLineWrapper implements Comparable {
        public Boolean isSelected {get; set;}
        public Billing_Line__c billingLineRec {get; set;}
        public Boolean isAvalaraSalesTax {get; set;}
        public Decimal taxRate {get; set;}

        public BillingLineWrapper(Billing_Line__c billLine, Billing__c bill) {
            Boolean isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(bill);
            Boolean isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();

            this.isSelected = true;
            this.billingLineRec = billLine;
            this.isAvalaraSalesTax = (isAvalaraTaxCalcEnabled && !isHlpMode && billLine.Product__c == AvaTaxHelper.getSalesTaxProductId(bill));
        }

        public void setLineTaxRate(Decimal combinedTaxRate) {
            taxRate = combinedTaxRate / 100;
        }

        public Integer compareTo(Object wrapper) {
            BillingLineWrapper obj = (BillingLineWrapper) wrapper;
            if (billingLineRec.Rate__c == obj.billingLineRec.Rate__c) { return 0; }
            if (billingLineRec.Rate__c < obj.billingLineRec.Rate__c) { return 1; }
            return -1;
        }
    }

}