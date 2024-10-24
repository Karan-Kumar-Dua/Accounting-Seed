public with sharing class AvaTaxExceptionReportController {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
    
    @TestVisible
    private static final Integer MAX_LINE_LIMIT = (Test.isRunningTest()) ? 50 : 500;

    @TestVisible
    private static final String NO_MATCHING_TRANSACTIONS = Label.ERR_NO_MATCHING_AVALARA_TRANSACTIONS_COMMITED;
    @TestVisible
    private static final String AMOUNT_MISMATCH = Label.COMMON_AMOUNT_MISMATCH_AVALARA_TRN;
    private static final String ADDRESS_MISMATCH = Label.COMMON_ADDRESS_MISMATCH_AVALARA_TRN;
    private static final String NOTHING_TO_SHOW = Label.COMMON_NO_DISCREPANCIES_SELECTED_DATE;
    @TestVisible
    private static final String MAX_LINE_LIMIT_INFO_MESSAGE = Label.INF_BILLINGS_MAX_LINE_LIMIT_DATE_RANGE;

    @TestVisible
    private Boolean skipCallout = false;
    @TestVisible
    private AvaTaxService.FetchResultTransactionModel testResponse;

    public Billing__c dateRangeProxyObj {get; set;}
    public Boolean isStartDateError {get; set;}
    public Boolean isEndDateError {get; set;}
    public Boolean isReportLineExists {get; set;}
    public Boolean isHlpMode {get; set;}
    public List<AvaTaxExceptionReportController.TaxExceptionReportLine> taxExceptionReportLines {get; set;}
    public Map<Id, Ledger__c> avataxLedgersMap {get; set;}
    public List<SelectOption> avataxLedgerOptions {get; set;}
    public Id currentLedgerId {get; set;}

    public AvaTaxExceptionReportController() {
        this.isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();
        this.dateRangeProxyObj = new Billing__c(
            Billing_Cycle_Start_Date__c = getDefaultStartDate(),
            Billing_Cycle_End_Date__c = getDefaultEndDate()
        );
        this.taxExceptionReportLines = new List<AvaTaxExceptionReportController.TaxExceptionReportLine>();
        fetchAvataxLedgers();
        buildSelectOptions();
        resetErrorFlags();
    }

    public Boolean hasAvataxLedger {
        get {
            return !avataxLedgersMap.isEmpty();
        }
    }

    public Boolean isLedgerSelected {
        get {
            return currentLedgerId != null;
        }
    }

    public PageReference changeLedger() {
        resetErrorFlags();
        return null;
    }

    private void buildSelectOptions() {
        this.avataxLedgerOptions = new List<SelectOption>();
        if (!this.avataxLedgersMap.isEmpty()) {
            this.currentLedgerId = avataxLedgersMap.values().get(0).Id;
            for (Ledger__c ledger : avataxLedgersMap.values()) {
                this.avataxLedgerOptions.add(new SelectOption(ledger.Id, ledger.Name));
            }
        }
    }

    private void fetchAvataxLedgers() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Type__c',
            'Sales_Tax_Company_Code__c',
            'Tax_Settings__c',
            'Tax_Settings__r.Tax_Settings_Method__c',
            'Tax_Settings__r.Origin_Address__r.City__c',
            'Tax_Settings__r.Origin_Address__r.Country_Code__c',
            'Tax_Settings__r.Origin_Address__r.Postal_Code__c',
            'Tax_Settings__r.Origin_Address__r.State_Province__c',
            'Tax_Settings__r.Origin_Address__r.Street__c',
            'Tax_Settings__r.AvaTax_License__r.AvaTax_Account_ID__c',
            'Tax_Settings__r.AvaTax_License__r.AvaTax_License_Key__c',
            'Tax_Settings__r.AvaTax_License__r.Active_AvaTax_Endpoint__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition =
            'Type__c =\'' + String.escapeSingleQuotes(LedgerActions.LEDGER_TYPE_TRANSACTIONAL) + '\'' +
            ' AND Tax_Settings__c != NULL' +
            ' AND Tax_Settings__r.Tax_Settings_Method__c = \'' + String.escapeSingleQuotes(TaxSettingsActions.AVA_TAX_METHOD) + '\'';

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryCondition += ' AND CurrencyIsoCode = \'USD\'';
        }

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Ledger__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Ledger__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering);

        this.avataxLedgersMap = new Map<Id, Ledger__c>((List<Ledger__c>) Database.query(theQuery.toSOQL()));
    }

    private void resetErrorFlags() {
        this.isStartDateError = false;
        this.isEndDateError = false;
        this.isReportLineExists = false;
    }

    private Date getDefaultStartDate() {
        return Date.today().addDays(-30);
    }

    private Date getDefaultEndDate() {
        return Date.today();
    }

    private Boolean validateEnteredCriteria() {
        Boolean result = true;
        if (dateRangeProxyObj.Billing_Cycle_Start_Date__c == NULL) {
            isStartDateError = true;
            result = false;
        }

        if (dateRangeProxyObj.Billing_Cycle_End_Date__c == NULL) {
            isEndDateError = true;
            result = false;
        }

        if (result) {//if both dates were populated
            if (dateRangeProxyObj.Billing_Cycle_Start_Date__c > dateRangeProxyObj.Billing_Cycle_End_Date__c) {
                isEndDateError = true;
                result = false;
            }
        }

        return result;
    }

    public PageReference runSalesTaxReport() {
        resetErrorFlags();

        try {
            if (validateEnteredCriteria()) {
                List<Billing__c> billingsForThisRange = queryBillingsForReport(
                    dateRangeProxyObj.Billing_Cycle_Start_Date__c,
                    dateRangeProxyObj.Billing_Cycle_End_Date__c
                );

                Integer recordCounter = 0;

                if (!billingsForThisRange.isEmpty()) {
                    //exclude Billings which do not have Sales Tax Line
                    List<Billing__c> billingsForReport = new List<Billing__c>();

                    for (Billing__c bill : billingsForThisRange) {
                        if (recordCounter < MAX_LINE_LIMIT && !bill.Project_Billing_Lines__r.isEmpty()) {
                            billingsForReport.add(bill);
                            recordCounter++;
                        }
                    }

                    if (!billingsForReport.isEmpty()) {
                        taxExceptionReportLines = compareWithAvalaraSide(
                            billingsForReport,
                            dateRangeProxyObj.Billing_Cycle_Start_Date__c,
                            dateRangeProxyObj.Billing_Cycle_End_Date__c
                        );
                        if (!taxExceptionReportLines.isEmpty()) {
                            isReportLineExists = true;
                        }
                    }
                }

                if (!isReportLineExists) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, NOTHING_TO_SHOW));
                }

                if (recordCounter == MAX_LINE_LIMIT) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, String.format(MAX_LINE_LIMIT_INFO_MESSAGE, new String[]{String.valueOf(MAX_LINE_LIMIT)})));
                }
            }
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
        }

        return NULL;
    }

    private List<Billing__c> queryBillingsForReport(Date startDate, Date endDate) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Date__c',
            'Shipping_Street__c',
            'Shipping_Country__c',
            'Shipping_State__c',
            'Shipping_PostalCode__c',
            'Shipping_City__c',
            'Sales_Tax2__c',
            'Sales_Tax3__c',
            'Destination_Address_Override__c',
            'Destination_Address_Override__r.Street__c',
            'Destination_Address_Override__r.City__c',
            'Destination_Address_Override__r.Postal_Code__c',
            'Destination_Address_Override__r.State_Province__c',
            'Destination_Address_Override__r.Country_Code__c',
            'Origin_Address_Override__c',
            'Origin_Address_Override__r.Street__c',
            'Origin_Address_Override__r.City__c',
            'Origin_Address_Override__r.Postal_Code__c',
            'Origin_Address_Override__r.State_Province__c',
            'Origin_Address_Override__r.Country_Code__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
            queryFields.add('Currency_Conversion_Rate__c');
        }

        String queryCondition = 'Date__c >= :startDate AND Date__c <= :endDate AND Status__c = \'Posted\' AND Ledger__c = :currentLedgerId';
        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Billing__c', 'Date__c', SOQLBuilder.SortOrder.DESCENDING);

        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Project_Billing_Lines__r';
        List<String> subQueryFields = new List<String>{
            'Id',
            'Product__c',
            'Total__c'
        };

        String subQueryCondition = 'Product__c != NULL';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering)
            .subselectQuery(subQueryRelationshipName, true)
            .setEnforceFLS(true)
            .selectFields(subQueryFields)
            .setCondition(subQueryCondition)
            .setLimit(1);/*nested query limit*/

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    private List<TaxExceptionReportLine> compareWithAvalaraSide(List<SObject> sfSideRecords, Date startDate, Date endDate) {
        List<TaxExceptionReportLine> result = new List<TaxExceptionReportLine>();
        List<String> docCodes = new List<String>();
        for (SObject doc : sfSideRecords) {
            docCodes.add((String) doc.get('Name'));
        }

        Ledger__c currentLedger = avataxLedgersMap.get(currentLedgerId);
        String companyCode = currentLedger.Sales_Tax_Company_Code__c;
        String accountId = currentLedger.Tax_Settings__r.AvaTax_License__r.AvaTax_Account_ID__c;
        String licenseKey = currentLedger.Tax_Settings__r.AvaTax_License__r.AvaTax_License_Key__c;
        Boolean isProduction = currentLedger.Tax_Settings__r.AvaTax_License__r.Active_AvaTax_Endpoint__c == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT;
        AvaTaxService.AddressInfo originAddressFromTaxSettings = new AvaTaxService.AddressInfo();
        originAddressFromTaxSettings.line1 = currentLedger.Tax_Settings__r.Origin_Address__r.Street__c;
        originAddressFromTaxSettings.city = currentLedger.Tax_Settings__r.Origin_Address__r.City__c;
        originAddressFromTaxSettings.region = currentLedger.Tax_Settings__r.Origin_Address__r.State_Province__c;
        originAddressFromTaxSettings.postalCode = currentLedger.Tax_Settings__r.Origin_Address__r.Postal_Code__c;
        originAddressFromTaxSettings.country = currentLedger.Tax_Settings__r.Origin_Address__r.Country_Code__c;

        AvaTaxService.FetchResultTransactionModel fetchResult;
        if (!skipCallout) {
            AvaTaxService avaTaxServiceInst = new AvaTaxService(accountId, licenseKey, isProduction);
            fetchResult = avaTaxServiceInst.listTransactionsByCompanyInst(
                companyCode,
                docCodes,
                startDate,
                endDate,
                AvaTaxService.DocumentStatus.Committed,
                new List<String>{'Addresses'}
            );
        }
        else {
            fetchResult = testResponse;
        }

        Map<String, AvaTaxService.TransactionModel> avaTaxTransactionMap = fetchResult.getTransactionMap();

        String siteUrl = GlobalVariables.AVALARA_SITE_URL(isProduction);
        for (SObject doc : sfSideRecords) {
            TaxExceptionReportLine tempReportLine;
            AvaTaxService.TransactionModel avalaraTransaction = avaTaxTransactionMap.get((String) doc.get('Name'));
            if (avalaraTransaction != NULL) {
                tempReportLine = new TaxExceptionReportLine(doc, avalaraTransaction, originAddressFromTaxSettings, accountId, isHlpMode, siteUrl);
            }
            else {
                tempReportLine = new TaxExceptionReportLine(doc, isHlpMode);
            }
            //no difference between SF and Avalara side - not shown in the report
            if (tempReportLine.reportStatus != 'OK') {
                result.add(tempReportLine);
            }
        }
        return result;
    }

    public with sharing class TaxExceptionReportLine {
        private AvaTaxService.TransactionModel avalaraTransaction;
        private AvaTaxService.AddressInfo sfSideOriginAddress;
        private AvaTaxService.AddressInfo sfSideDestinationAddress;
        private AvaTaxService.AddressInfo originAddressFromSettings;
        private String accountId;
        private Boolean isHeaderLevelPostEnabled;
        private String siteUrl;

        public SObject obj {get; set;}
        public String reportStatus {get; set;}
        public String statusDescription {get; set;}
        public Decimal avalaraTaxAmount {get; set;}
        public Decimal sfTaxAmount {get; set;}
        public String avalaraTransactionUrl {get; set;}

        public TaxExceptionReportLine(SObject sfSideRecord, Boolean isHlpMode) {
            this.obj = sfSideRecord;
            this.isHeaderLevelPostEnabled = isHlpMode;
            this.reportStatus = 'No Transaction';
            this.statusDescription = NO_MATCHING_TRANSACTIONS;
            this.avalaraTaxAmount = NULL;
            this.sfTaxAmount = getTaxLineAmount();
        }

        public TaxExceptionReportLine(
            SObject sfSideRecord,
            AvaTaxService.TransactionModel avalaraTransaction,
            AvaTaxService.AddressInfo originAddressFromSettings,
            String accountId,
            Boolean isHlpMode,
            String siteUrl) {

            this.obj = sfSideRecord;
            this.isHeaderLevelPostEnabled = isHlpMode;
            this.avalaraTransaction = avalaraTransaction;
            this.sfSideOriginAddress = new AvaTaxService.AddressInfo();
            this.sfSideDestinationAddress = new AvaTaxService.AddressInfo();
            this.originAddressFromSettings = originAddressFromSettings;
            this.accountId = accountId;
            this.avalaraTaxAmount = avalaraTransaction.totalTax;
            this.sfTaxAmount = getTaxLineAmount();
            this.siteUrl = siteUrl;
            getReportStatus();
            buildAvalaraTransactionUrl();
        }

        private Decimal getTaxLineAmount() {
            Schema.SObjectField salesTaxFieldToken = (isHeaderLevelPostEnabled) ? Billing__c.Sales_Tax3__c : Billing__c.Sales_Tax2__c;
            Decimal result = (Decimal) obj.get(salesTaxFieldToken);
            if (result == NULL) {
                result = 0;
            }

            if (IS_MULTI_CURRENCY_ENABLED && result != 0) {
                result = (result / (Decimal) obj.get(Billing__c.Currency_Conversion_Rate__c)).setScale(2, System.RoundingMode.HALF_UP);
            }

            return result;
        }

        private void getReportStatus() {
            if (sfTaxAmount != avalaraTransaction.totalTax) {
                reportStatus = 'Incorrect Tax Value';
                statusDescription = AMOUNT_MISMATCH;
            }
            else if (!checkAddressesEquality()) {
                reportStatus = 'Different Addresses';
                statusDescription = ADDRESS_MISMATCH;
            }
            else {
                //this line will not be displayed since it is not an exception case
                //we will filter this before return on a client side
                reportStatus = 'OK';
                statusDescription = 'No issues.';
            }
        }

        private void buildAvalaraTransactionUrl() {
            avalaraTransactionUrl =
                siteUrl +
                    '/cup/a/' + accountId + '/c/' + avalaraTransaction.companyId +
                    '/transactions/' + avalaraTransaction.id;
        }

        private Boolean checkAddressesEquality() {
            Boolean result = true;
            if (obj.get('Origin_Address_Override__c') == null) {
                sfSideOriginAddress.line1 = originAddressFromSettings.line1;
                sfSideOriginAddress.city = originAddressFromSettings.city;
                sfSideOriginAddress.region = originAddressFromSettings.region;
                sfSideOriginAddress.postalCode = originAddressFromSettings.postalCode;
                sfSideOriginAddress.country = originAddressFromSettings.country;
            } else {
                Billing__c castedBill = (Billing__c) obj;
                sfSideOriginAddress.line1 = castedBill.Origin_Address_Override__r.Street__c;
                sfSideOriginAddress.city = castedBill.Origin_Address_Override__r.City__c;
                sfSideOriginAddress.region = castedBill.Origin_Address_Override__r.State_Province__c;
                sfSideOriginAddress.postalCode= castedBill.Origin_Address_Override__r.Postal_Code__c;
                sfSideOriginAddress.country = castedBill.Origin_Address_Override__r.Country_Code__c;
            }

            if (obj.get('Destination_Address_Override__c') == null) {
                sfSideDestinationAddress.line1 = (String) obj.get('Shipping_Street__c');
                sfSideDestinationAddress.city = (String) obj.get('Shipping_City__c');
                sfSideDestinationAddress.region = (String) obj.get('Shipping_State__c');
                sfSideDestinationAddress.postalCode = (String) obj.get('Shipping_PostalCode__c');
                sfSideDestinationAddress.country = (String) obj.get('Shipping_Country__c');
            } else {
                Billing__c castedBill = (Billing__c) obj;
                sfSideDestinationAddress.line1 = castedBill.Destination_Address_Override__r.Street__c;
                sfSideDestinationAddress.city = castedBill.Destination_Address_Override__r.City__c;
                sfSideDestinationAddress.region = castedBill.Destination_Address_Override__r.State_Province__c;
                sfSideDestinationAddress.postalCode= castedBill.Destination_Address_Override__r.Postal_Code__c;
                sfSideDestinationAddress.country = castedBill.Destination_Address_Override__r.Country_Code__c;
            }

            //if there is only one address on Avalara side
            if (avalaraTransaction.originAddressId == avalaraTransaction.destinationAddressId) {
                result = compareAddresses(sfSideOriginAddress, avalaraTransaction.addresses[0])
                            || compareAddresses(sfSideDestinationAddress, avalaraTransaction.addresses[0]);
            }
            else {//if there are both addresses (origin & destination) on Avalara side
                result = (
                    (
                        compareAddresses(sfSideOriginAddress, avalaraTransaction.addresses[0])
                            || compareAddresses(sfSideOriginAddress, avalaraTransaction.addresses[1])
                    ) && (
                        compareAddresses(sfSideDestinationAddress, avalaraTransaction.addresses[0])
                            || compareAddresses(sfSideDestinationAddress, avalaraTransaction.addresses[1])
                    )
                );
            }

            return result;
        }

        private Boolean compareAddresses(AvaTaxService.AddressInfo address1, AvaTaxService.AddressInfo address2) {
            //normalize addresses
            address1.line1 = (address1.line1 != NULL) ? address1.line1.trim().toUpperCase() : NULL;
            address1.city = (address1.city != NULL) ? address1.city.trim().toUpperCase() : NULL;
            address1.region = (address1.region != NULL) ? address1.region.trim().toUpperCase() : NULL;
            address1.postalCode = (address1.postalCode != NULL) ? address1.postalCode.trim().toUpperCase() : '';

            address2.line1 = (address2.line1 != NULL) ? address2.line1.trim().toUpperCase() : NULL;
            address2.city = (address2.city != NULL) ? address2.city.trim().toUpperCase() : NULL;
            address2.region = (address2.region != NULL) ? address2.region.trim().toUpperCase() : NULL;
            address2.postalCode = (address2.postalCode != NULL) ? address2.postalCode.trim().toUpperCase() : '';

            return address1.line1 == address2.line1
                    && address1.city == address2.city
                    && address1.region == address2.region
                    && address1.postalCode.left(5) == address2.postalCode.left(5);
        }

        public Long getAvalaraTransactionId() {
            if (avalaraTransaction != NULL) {
                return avalaraTransaction.id;
            }
            else {
                return NULL;
            }
        }

    }

}