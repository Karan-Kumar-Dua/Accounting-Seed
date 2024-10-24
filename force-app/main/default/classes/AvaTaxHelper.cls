public with sharing class AvaTaxHelper {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String COMPANY_CODE_NOT_FOUND_ERROR = Label.ERR_COMPANY_CODE_NOT_FOUND;
    private static final String AVALARA_GL_ACCOUNT_NOT_FOUND_ERROR = Label.ERR_AVALARA_GL_ACCOUNT_NOT_FOUND;
    private static final String SALES_TAX_PRODUCT_NOT_FOUND_ERROR = Label.ERR_SALES_TAX_PRODUCT_NOT_FOUND;
    private static final String TAX_ADDRESS_MODE_NOT_SELECTED_ERROR = Label.ERR_TAX_ADDRESS_MODE_NOT_SELECTED;
    private static String NO_TAXABLE_LINES = Label.ERR_NO_TAXABLE_LINES_BILLING_RECORD;

    public static final Integer AVALARA_SELECTED_RECORDS_LIMIT = 100;
    public static final String AVALARA_SELECTED_RECORDS_LIMIT_EXCEEDED_ERROR_MESSAGE = Label.ERR_AVALARA_SELECTED_RECORDS_LIMIT_EXCEEDED;

    @TestVisible
    public static SObject sourceRecord;
    @TestVisible
    private static List<SObject> sourceRecordLines;
    public static Map<Id, SObject> sourceRecordMap;
    public static Map<Id, Decimal> oldTaxAmountsByLineIds = new Map<Id, Decimal>();
    public static Boolean isLDVBatchContext = false;
    private static Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
    private static Boolean IS_HEADER_LEVEL_POST = AccountingSettingsHandler.isHeaderLevelPost();
    private static AbstractTaxService service = AccountingSettingsHandler.isHeaderLevelPost()
        ? (AbstractTaxService) new AvaTaxHeaderLevel() : (AbstractTaxService) new AvaTaxLineLevel();

    public static void asyncCreateTransaction(List<SObject> billings, Boolean doCommit) {
        Set<Id> billingIds = new Map<Id, SObject>(billings).keySet();

        AvaTaxAsyncTransactionHandler taxTransactionHandler =
            new AvaTaxAsyncTransactionHandler(
                AvaTaxAsyncTransactionHandler.AvaTaxContext.CREATE, billingIds, doCommit
            );
        System.enqueueJob(taxTransactionHandler);
    }

    //Entry point for mass uncommit transactions during Unpost process
    public static void uncommitTransactions(Set<Id> billingIds) {
        List<Billing__c> billings = queryBillingById(billingIds, false);
        uncommitTransactions(billings);
    }

    public static void uncommitTransactions(List<Billing__c> billings) {
        try {
            for (Billing__c bill : billings) {
                String avaTaxAccountId = service.getAvalaraAccountID(bill);
                String avaTaxLicenseKey = service.getAvalaraLicenseKey(bill);
                if (String.isNotBlank(avaTaxAccountId) && String.isNotBlank(avaTaxLicenseKey)) {
                    (new AvaTaxService(
                            avaTaxAccountId,
                            avaTaxLicenseKey,
                            service.getAvalaraEndpoint(bill) == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT
                    )).uncommitTransactionInst(getCompanyCode(bill), bill.Name);
                }
            }
        }
        catch (Exception ex) {
            //all potential errors will be silently caught to not prevent Unpost procedure
        }
    }

    //Entry point for mass Tax calculation during Calc Tax & Post functionality execution
    public static AvaTaxHelper.AvaTaxCalculationResult calcTaxes(
        List<SObject> sourceRecords, List<SObject> sourceRecordLines, AvaTaxService.DocumentType docType, Boolean doCommit) {

        Set<Id> isNeedAddLines = new Set<Id>();
        AvaTaxHelper.AvaTaxCalculationResult result = new AvaTaxHelper.AvaTaxCalculationResult();
        try {
            Set<Id> sourceRecordIds = new Map<Id, SObject>(sourceRecords).keySet();
            sourceRecordMap = new Map<Id, SObject>();
            Map<Id, List<SObject>> masterToDetailsMap = new Map<Id, List<SObject>>();

            if (IS_MULTI_CURRENCY_ENABLED) {
                for (Billing__c billFromDB : queryBillingById(sourceRecordIds, false)) {
                    if (AvaTaxHelper.isLedgerCurrencySupportedByAvaTaxCalculation((Id) billFromDB.get(PACKAGE_QUALIFIER + 'Ledger__c'))) {
                        sourceRecordMap.put(billFromDB.Id, billFromDB);
                    }
                }
            }
            else {
                sourceRecordMap = new Map<Id, SObject>(queryBillingById(sourceRecordIds, false));
            }
            // Avalara add lines for LDV mode support
            if (FeatureManagementHandler.isLargeDataVolumeModeEnabled() && System.isBatch()) {
                for (Transaction_Group__c tg : DomainUtils.getTransactionGroupBySourceId(sourceRecordIds)) {
                    if (tg.Billing__c != null) {
                        isNeedAddLines.add(tg.Billing__c);
                    }
                }
            }

            //Filter out all non-taxable lines
            for (SObject line : sourceRecordLines) {
                if (AvaTaxHelper.validateBillingLineIsTaxable((Billing_Line__c) line, sourceRecordMap.get((Id) line.get(PACKAGE_QUALIFIER + 'Billing__c')))) {
                    //Group all taxable lines by their headers (Billing => <Billing Lines>)
                    if (masterToDetailsMap.containsKey((Id) line.get(PACKAGE_QUALIFIER + 'Billing__c'))) {
                        masterToDetailsMap.get((Id) line.get(PACKAGE_QUALIFIER + 'Billing__c')).add(line);
                    }
                    else {
                        masterToDetailsMap.put((Id) line.get(PACKAGE_QUALIFIER + 'Billing__c'), new List<SObject>{line});
                    }
                }
            }

            Map<Id, AvaTaxService.TransactionModel> calloutResultMap = new Map<Id, AvaTaxService.TransactionModel>();
            for (SObject sourceRec : sourceRecordMap.values()) {
                if (masterToDetailsMap.containsKey(sourceRec.Id)) {
                    try {
                        AvaTaxService.TransactionModel calloutResult;
                        if (isNeedAddLines.contains(sourceRec.Id)) {
                            calloutResult = addLines(sourceRec, masterToDetailsMap.get(sourceRec.Id), docType);
                        }
                        else {
                            calloutResult = calcTax(sourceRec, masterToDetailsMap.get(sourceRec.Id), docType, doCommit);
                        }
                        calloutResultMap.put(sourceRec.Id, calloutResult);
                    }
                    catch (Exception ex) {
                        result.addAvaTaxReport(
                            getAvaTaxCalculationErrorReport(
                                sourceRec.Id,
                                masterToDetailsMap.get(sourceRec.Id),
                                new AvaTaxCalculationError(
                                    AvaTaxCalculationErrorStatusCode.AVATAX_SERVICE_ERROR,
                                    ex.getMessage()
                                )
                            )
                        );
                    }
                }
            }
            //HLP: update taxable lines and populate Tax Amount for each successfully processed record
            //LLP: create/replace Sales Tax Line for each successfully processed record
            result.addAvaTaxReports(processAvaTaxCalloutResults(calloutResultMap, doCommit));
        }
        catch (Exception ex) {
            //all potential errors will be silently caught to not prevent Post procedure
        }

        return result;
    }

    private static List<AvaTaxCalculationReport> processAvaTaxCalloutResults(Map<Id, AvaTaxService.TransactionModel> calloutResultMap, Boolean doDML) {
        List<AvaTaxCalculationReport> avaTaxCalculationReports = new List<AvaTaxHelper.AvaTaxCalculationReport>();
        try {
            if (IS_HEADER_LEVEL_POST) {
                avaTaxCalculationReports = AvaTaxHelper.populateTaxAmountOnLines(calloutResultMap, doDML);
            }
            else {
                avaTaxCalculationReports = AvaTaxHelper.upsertTaxLines(calloutResultMap, doDML);
            }
        }
        catch (Exception ex) {
            avaTaxCalculationReports.add(
                getAvaTaxCalculationErrorReport(
                    NULL,
                    NULL,
                    new AvaTaxCalculationError(
                        AvaTaxCalculationErrorStatusCode.UNDEFINED_SYSTEM_ERROR,
                        ex.getMessage()
                    )
                )
            );
        }
        return avaTaxCalculationReports;
    }

    /**
    * Only supports updating the calculated tax on an unposted billing
    * */
    public static AvaTaxHelper.AvaTaxCalculationResult calcTaxAPI(Id billingId) {
        AvaTaxHelper.AvaTaxCalculationResult result = new AvaTaxHelper.AvaTaxCalculationResult();
        try {
            List<Billing__c> billings = queryBillingById(new Set<Id>{billingId}, false);
            if (!billings.isEmpty() && billings[0].Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                AvaTaxHelper.sourceRecord = billings.get(0);
                AvaTaxHelper.sourceRecordMap = new Map<Id, SObject> (billings);
                List<Billing_Line__c> taxableBillLines = queryTaxableBillingLinesByBillingId(new Set<Id>{billingId}, true, false);
                if (!taxableBillLines.isEmpty()) {
                    AvaTaxHelper.sourceRecordLines = taxableBillLines;
                    //Current Calc Tax Mode is [Document Type: SalesInvoice; commit: false]
                    AvaTaxService.DocumentType docType = AvaTaxService.DocumentType.SalesInvoice;
                    Map<Id, AvaTaxService.TransactionModel> calloutResultMap = new Map<Id, AvaTaxService.TransactionModel>();
                    try {
                        AvaTaxService.TransactionModel calloutResult = calcTax(sourceRecord, sourceRecordLines, docType, false);
                        calloutResultMap.put(sourceRecord.Id, calloutResult);
                    }
                    catch (Exception ex) {
                        result.addAvaTaxReport(
                            getAvaTaxCalculationErrorReport(
                                AvaTaxHelper.sourceRecord.Id,
                                sourceRecordLines,
                                new AvaTaxCalculationError(
                                    AvaTaxCalculationErrorStatusCode.AVATAX_SERVICE_ERROR,
                                    ex.getMessage()
                                )
                            )
                        );
                    }
                    //HLP: update taxable lines and populate Tax Amount for each successfully processed record
                    //LLP: create/replace Sales Tax Line for each successfully processed record
                    result.addAvaTaxReports(processAvaTaxCalloutResults(calloutResultMap, true));
                }
                else {
                    result.addAvaTaxReport(
                        getAvaTaxCalculationErrorReport(
                            NULL,
                            NULL,
                            new AvaTaxCalculationError(
                                AvaTaxCalculationErrorStatusCode.UNDEFINED_SYSTEM_ERROR,
                                NO_TAXABLE_LINES
                            )
                        )
                    );
                }
            }
            else {
                result.addAvaTaxReport(
                    getAvaTaxCalculationErrorReport(
                        NULL,
                        NULL,
                        new AvaTaxCalculationError(
                            AvaTaxCalculationErrorStatusCode.UNDEFINED_SYSTEM_ERROR,
                            Billing.NO_INPUT_DATA
                        )
                    )
                );
            }
        }
        catch (Exception ex) {
            result.addAvaTaxReport(
                getAvaTaxCalculationErrorReport(
                    NULL,
                    NULL,
                    new AvaTaxCalculationError(
                        AvaTaxCalculationErrorStatusCode.UNDEFINED_SYSTEM_ERROR,
                        ex.getMessage()
                    )
                )
            );
        }

        return result;
    }

    private static AvaTaxCalculationReport getAvaTaxCalculationErrorReport(Id masterId, List<SObject> lines, AvaTaxCalculationError error) {
        return new AvaTaxCalculationReport(false, masterId, lines, error);
    }

    public static AvaTaxService.TransactionModel addLines(SObject sourceRecord, List<SObject> sourceRecordLines, AvaTaxService.DocumentType docType) {
        AvaTaxHelper.sourceRecord = sourceRecord;
        AvaTaxHelper.sourceRecordLines = sourceRecordLines;
        if (AvaTaxHelper.sourceRecordMap == null || AvaTaxHelper.sourceRecordMap.isEmpty()) {
            AvaTaxHelper.sourceRecordMap = new Map<Id, SObject>{AvaTaxHelper.sourceRecord.Id => AvaTaxHelper.sourceRecord};
        }

        AvaTaxService.TransactionModel responseResult =
            (new AvaTaxService(
                service.getAvalaraAccountID(sourceRecord),
                service.getAvalaraLicenseKey(sourceRecord),
                service.getAvalaraEndpoint(sourceRecord) == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT
            )).addLines(buildAddLinesTransactionModel(docType));

        return responseResult;
    }

    private static AvaTaxService.AddLinesTransactionModel buildAddLinesTransactionModel(AvaTaxService.DocumentType docType) {
        AvaTaxService.AddLinesTransactionModel result = new AvaTaxService.AddLinesTransactionModel();
        result.transactionCode = getDocCode();
        result.companyCode = getCompanyCode(sourceRecord);
        result.type = docType;
        result.renumber = false;
        result.lines = getLines();

        return result;
    }

    //Entry point for single record tax calculation (based on prepared data structure)
    public static AvaTaxService.TransactionModel calcTax(AvaTaxService.CreateTransactionModel transModel) {
        AvaTaxService.CreateOrAdjustTransactionModel requestModel = new AvaTaxService.CreateOrAdjustTransactionModel();
        requestModel.createTransactionModel = transModel;
        AvaTaxService.TransactionModel responseResult = (new AvaTaxService(
                service.getAvalaraAccountID(sourceRecord),
                service.getAvalaraLicenseKey(sourceRecord),
                service.getAvalaraEndpoint(sourceRecord) == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT
        )).createOrAdjustTransactionInst(requestModel);

        return responseResult;
    }

    //Entry point for single record tax calculation (based on records from DB)
    public static AvaTaxService.TransactionModel calcTax(SObject sourceRecord, List<SObject> sourceRecordLines, AvaTaxService.DocumentType docType, Boolean doCommit) {
        AvaTaxHelper.sourceRecord = sourceRecord;
        AvaTaxHelper.sourceRecordLines = sourceRecordLines;
        if (AvaTaxHelper.sourceRecordMap == null || AvaTaxHelper.sourceRecordMap.isEmpty()) {
            AvaTaxHelper.sourceRecordMap = new Map<Id, SObject>{AvaTaxHelper.sourceRecord.Id => AvaTaxHelper.sourceRecord};
        }
        AvaTaxService.CreateTransactionModel transactionModel = buildCreateTransactionModel(docType, doCommit);
        AvaTaxService.CreateOrAdjustTransactionModel requestModel = new AvaTaxService.CreateOrAdjustTransactionModel();
        requestModel.createTransactionModel = transactionModel;
        AvaTaxService.TransactionModel responseResult =
            (new AvaTaxService(
                    service.getAvalaraAccountID(sourceRecord),
                    service.getAvalaraLicenseKey(sourceRecord),
                    service.getAvalaraEndpoint(sourceRecord) == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT
            )).createOrAdjustTransactionInst(requestModel);

        return responseResult;
    }

    private static AvaTaxService.CreateTransactionModel buildCreateTransactionModel(AvaTaxService.DocumentType docType, Boolean doCommit) {
        AvaTaxService.CreateTransactionModel result = new AvaTaxService.CreateTransactionModel();
        result.code = getDocCode();
        result.companyCode = getCompanyCode(sourceRecord);
        result.type = docType;
        result.avaTaxDate = getDocumentDate();
        result.purchaseOrderNo =
            (sourceRecord.getSObjectType() == Billing__c.SObjectType)
                ? (String) sourceRecord.get(PACKAGE_QUALIFIER + 'PO_Number__c') : NULL;
        result.customerCode = getAccountIdFromSource();
        result.businessIdentificationNo = getBIN();
        result.entityUseCode = getEntityUseCode();
        result.exemptionNo = getExemptionNumber();
        if (sourceRecord.getSObjectType() == Opportunity.SObjectType) {
            result.addresses = getAddresses(getOriginAddressInfo(sourceRecord), getDestinationAddressInfo(sourceRecord), sourceRecord);
        }
        result.currencyCode = 'USD';//currently we support only USD

        result.lines = getLines();

        result.doCommit = doCommit;

        return result;
    }

    public static AvaTaxService.FetchResultTransactionModel getAvalaraTransactions(List<Billing__c> bills) {
        List<String> docCodes = new List<String>();
        Date startDate;
        Date endDate;
        for (Billing__c bill : bills) {
            docCodes.add(bill.Name);
            startDate = startDate == null || startDate > bill.Date__c ? bill.Date__c : startDate;
            endDate = endDate == null || endDate < bill.Date__c ? bill.Date__c : endDate;
        }

        String accountId = service.getAvalaraAccountID(bills[0]);
        String licenseKey = service.getAvalaraLicenseKey(bills[0]);
        Boolean isProduction = service.getAvalaraEndpoint(bills[0]) == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT;

        AvaTaxService avaTaxServiceInst = new AvaTaxService(accountId, licenseKey, isProduction);
        AvaTaxService.FetchResultTransactionModel fetchResult = avaTaxServiceInst.listTransactionsByCompanyInst(
            getCompanyCode(bills[0]),
            docCodes,
            startDate,
            endDate,
            AvaTaxService.DocumentStatus.Committed,
            null
        );
        return fetchResult;
    }

    public static Double getCurrencyConversionRate(SObject sRecord) {
        if (IS_MULTI_CURRENCY_ENABLED) {
            Double result = (Double) sRecord.get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c');
            return (result != NULL) ? result : 1.0;
        }
        else {
            return 1.0;
        }
    }

    public static Double getCurrencyConversionRateForOpportunity(SObject sRecord) {
        if (IS_MULTI_CURRENCY_ENABLED) {
            Set<String> currencies = new Set<String>{(String) sRecord.get('CurrencyIsoCode')};
            Set<Date> dates = new Set<Date>{(Date) sRecord.get('CloseDate')};
            List<SObject> datedCurrencyConversionRates = DomainUtils.getDatedConversionRateByCurrencyISOCodesAndDates(
                currencies, dates
            );

            return !datedCurrencyConversionRates.isEmpty()
                ? (Decimal) datedCurrencyConversionRates[0].get('ConversionRate')
                : 1.0;
        }
        else {
            return 1.0;
        }
    }

    private static String getDocCode() {
        String result;
        if (sourceRecord.getSObjectType() == Opportunity.SObjectType) {
            result = String.valueOf(sourceRecord.Id);
        }
        else {
            result = (String) sourceRecord.get('Name');
        }
        return result;
    }

    public static String getCompanyCode(SObject obj) {
        if (service.getSalesTaxCompanyCode(obj) == NULL) {
            throw new AvaTaxService.AvaTaxException(new AvaTaxService.AvaTaxError(COMPANY_CODE_NOT_FOUND_ERROR));
        }
        return service.getSalesTaxCompanyCode(obj);
    }

    private static Date getDocumentDate() {
        Date result;
        if (sourceRecord.getSObjectType() == Opportunity.SObjectType) {
            result = (Date) sourceRecord.get('CloseDate');
        }
        else {
            result = (Date) sourceRecord.get(PACKAGE_QUALIFIER + 'Date__c');
        }
        return result;
    }

    private static Id getAccountIdFromSource() {
        String accountId;
        switch on sourceRecord {
            when Billing__c b {
                accountId = b.Customer__c;
            }
            when Opportunity o {
                accountId = o.AccountId;
            }
        }

        return accountId;
    }

    private static String getBIN() {
        String vatBIN;
        switch on sourceRecord {
            when Billing__c b {
                vatBIN = b.Customer__r.VAT_Business_Identification_Number__c;
            }
            when Opportunity o {
                vatBIN = o.Account.VAT_Business_Identification_Number__c;
            }
        }

        return vatBIN;
    }

    private static String getEntityUseCode() {
        String entityUseCode = '';
        switch on sourceRecord {
            when Billing__c b {
                entityUseCode = b.Customer__r.Entity_Use_Code__c;
            }
            when Opportunity o {
                entityUseCode = o.Account.Entity_Use_Code__c;
            }
        }

        return entityUseCode;
    }

    private static String getExemptionNumber() {
        String exemptionNumber = '';
        switch on sourceRecord {
            when Billing__c b {
                exemptionNumber = b.Customer__r.Exemption_Number__c;
            }
            when Opportunity o {
                exemptionNumber = o.Account.Exemption_Number__c;
            }
        }

        return exemptionNumber;
    }

    public static AvaTaxService.AddressInfo getOriginAddressInfo(Billing_Line__c line, Billing__c header) {
        AvaTaxService.AddressInfo originAddress = null;
        if (line.Line_Origin_Address_Override__r != null) {
            originAddress = new AvaTaxService.AddressInfo();
            originAddress.line1 = line.Line_Origin_Address_Override__r.Street__c;
            originAddress.city = line.Line_Origin_Address_Override__r.City__c;
            originAddress.region = line.Line_Origin_Address_Override__r.State_Province__c;
            originAddress.postalCode = line.Line_Origin_Address_Override__r.Postal_Code__c;
            originAddress.country = line.Line_Origin_Address_Override__r.Country_Code__c;
        }
        return originAddress != null ? originAddress : getOriginAddressInfo(header);
    }

    public static AvaTaxService.AddressInfo getOriginAddressInfo(Billing__c aBilling) {
        AvaTaxService.AddressInfo originAddress = new AvaTaxService.AddressInfo();
        if (aBilling.Origin_Address_Override__c != null) {
            originAddress.line1 = aBilling.Origin_Address_Override__r.Street__c;
            originAddress.city = aBilling.Origin_Address_Override__r.City__c;
            originAddress.region = aBilling.Origin_Address_Override__r.State_Province__c;
            originAddress.postalCode = aBilling.Origin_Address_Override__r.Postal_Code__c;
            originAddress.country = aBilling.Origin_Address_Override__r.Country_Code__c;
        } else {
            originAddress = populateAddressFromSettings(originAddress, aBilling);
        }
        return originAddress;
    }

    public static AvaTaxService.AddressInfo getOriginAddressInfo(Recurring_Billing__c recurBilling) {
        AvaTaxService.AddressInfo originAddress = new AvaTaxService.AddressInfo();
        return populateAddressFromSettings(originAddress, recurBilling);
    }

    public static AvaTaxService.AddressInfo getOriginAddressInfo(Account anAccount, SObject ledgerObj) {
        AvaTaxService.AddressInfo originAddress = new AvaTaxService.AddressInfo();
        return populateAddressFromSettings(originAddress, ledgerObj);
    }

    //returns the opportunity's related account's address. Opportunity must have an account.
    public static AvaTaxService.AddressInfo getOriginAddressInfo(Opportunity anOpp, SObject ledgerObj) {
        AvaTaxService.AddressInfo originAddress = new AvaTaxService.AddressInfo();
        return populateAddressFromSettings(originAddress, ledgerObj);
    }

    //only allows for supported types as detailed in function. Billings should have Override addresses when they exist. Opportunites should have the related account address fields.
    public static AvaTaxService.AddressInfo getOriginAddressInfo(SObject supportedObj) {
        switch on supportedObj {
            when Account anAcc {
                return getOriginAddressInfo(anAcc, sourceRecord);
            }
            when Opportunity anOpp {
                return getOriginAddressInfo(anOpp, sourceRecord);
            }
            when Billing__c aBill {
                return getOriginAddressInfo(aBill);
            }
            when Billing_Line__c bLine {
                return getOriginAddressInfo(bLine, (Billing__c)sourceRecord);
            }
            when Recurring_Billing__c anRBill {
                return getOriginAddressInfo(anRBill);
            }
            when else {
                throw new TypeException(Label.ERR_RETRIEVE_ADDRESS_UNSUPPORTED_OBJECT + ': ' + supportedObj.getSObjectType().getDescribe().getName());
            }
        }
    }


    //Billing needs either the shipping address info or the related Address__c info if the Destination Billing Overrride field is populated
    public static AvaTaxService.AddressInfo getDestinationAddressInfo(Billing__c aBilling) {
        AvaTaxService.AddressInfo destinationAddress = new AvaTaxService.AddressInfo();
        if (aBilling.Destination_Address_Override__c != null) {
            destinationAddress.line1 = aBilling.Destination_Address_Override__r.Street__c;
            destinationAddress.city = aBilling.Destination_Address_Override__r.City__c;
            destinationAddress.region = aBilling.Destination_Address_Override__r.State_Province__c;
            destinationAddress.postalCode = aBilling.Destination_Address_Override__r.Postal_Code__c;
            destinationAddress.country = aBilling.Destination_Address_Override__r.Country_Code__c;
        } else {
            destinationAddress = new AvaTaxService.AddressInfo();
            destinationAddress.line1 = aBilling.Shipping_Street__c;
            destinationAddress.city = aBilling.Shipping_City__c;
            destinationAddress.region = aBilling.Shipping_State__c;
            destinationAddress.postalCode = aBilling.Shipping_PostalCode__c;
            destinationAddress.country = aBilling.Shipping_Country__c;
        }
            return destinationAddress;
    }

    public static AvaTaxService.AddressInfo getDestinationAddressInfo(Billing_Line__c line, Billing__c header) {
        AvaTaxService.AddressInfo destinationAddress = null;
        if (line.Line_Destination_Address_Override__r != null) {
            destinationAddress = new AvaTaxService.AddressInfo();
            destinationAddress.line1 = line.Line_Destination_Address_Override__r.Street__c;
            destinationAddress.city = line.Line_Destination_Address_Override__r.City__c;
            destinationAddress.region = line.Line_Destination_Address_Override__r.State_Province__c;
            destinationAddress.postalCode = line.Line_Destination_Address_Override__r.Postal_Code__c;
            destinationAddress.country = line.Line_Destination_Address_Override__r.Country_Code__c;
        }
        return destinationAddress != null ? destinationAddress : getDestinationAddressInfo(header);
    }

    //requires the Recurring billing to have a customer (Account) with address information
    public static AvaTaxService.AddressInfo getDestinationAddressInfo(Recurring_Billing__c recurBilling) {
        return getDestinationAddressInfo(recurBilling.Customer__r);
    }

    public static AvaTaxService.AddressInfo getDestinationAddressInfo(Account anAccount) {
        AvaTaxService.AddressInfo destinationAddress = new AvaTaxService.AddressInfo();
        destinationAddress.line1 = anAccount.ShippingStreet;
        destinationAddress.city = anAccount.ShippingCity;
        destinationAddress.region = anAccount.ShippingState;
        destinationAddress.postalCode = anAccount.ShippingPostalCode;
        destinationAddress.country = anAccount.ShippingCountry;
        return destinationAddress;
    }

    //returns the opportunity's related account's address. Opportunity must have an account.
    public static AvaTaxService.AddressInfo getDestinationAddressInfo(Opportunity anOpp) {
        return getDestinationAddressInfo(anOpp.Account);
    }

    //supports types from functions listed above
    public static AvaTaxService.AddressInfo getDestinationAddressInfo(SObject supportedObj) {

        switch on supportedObj {
            when Account anAcc {
                return getDestinationAddressInfo(anAcc);
            }
            when Opportunity anOpp {
                return getDestinationAddressInfo(anOpp);
            }
            when Billing__c aBill {
                return getDestinationAddressInfo(aBill);
            }
            when Billing_Line__c bLine {
                return getDestinationAddressInfo(bLine, (Billing__c)sourceRecord);
            }
            when Recurring_Billing__c anRBill {
                return getDestinationAddressInfo(anRBill);
            }
            when else {
                throw new TypeException(Label.ERR_RETRIEVE_ADDRESS_UNSUPPORTED_OBJECT + ': ' + supportedObj.getSObjectType().getDescribe().getName());
            }
        }
    }

    private static Boolean isDestinationAddressPopulated(SObject headerRecord) {
        AvaTaxService.AddressInfo res = getDestinationAddressInfo(headerRecord);
        return !String.isBLank(res.line1) && !String.isBLank(res.city) && !String.isBLank(res.region) && !String.isBLank(res.postalCode) && !String.isBLank(res.country);
    }

    public static Boolean validateDestinationAddress(SObject headerRecord) {
        Boolean result = true;
        String taxAddressMode = AvaTaxHelper.getTaxAddressMode(headerRecord);
        if (!isDestinationAddressPopulated(headerRecord)
            && (taxAddressMode.equalsIgnoreCase('Shipment') || taxAddressMode.equalsIgnoreCase('POD'))) {

            result = false;
        }
        return result;
    }

    //takes two AddressInfo objects and returns the address model based on the current tax address mode
    public static AvaTaxService.AddressesModel getAddresses(AvaTaxService.AddressInfo originInfo, AvaTaxService.AddressInfo destInfo, SObject obj) {

        AvaTaxService.AddressesModel result = new AvaTaxService.AddressesModel();
        String taxAddressMode = getTaxAddressMode(obj);
        
        switch on taxAddressMode {
            when 'Point of Sale' {
                result.singleLocation = originInfo;
            }
            when 'Point of Destination' {
                result.singleLocation = destInfo;

            }
            when 'Shipment' {
                result.shipFrom = originInfo;
                result.shipTo = destInfo;

            }
            when else {
                throw new AvaTaxService.AvaTaxException(new AvaTaxService.AvaTaxError(TAX_ADDRESS_MODE_NOT_SELECTED_ERROR));
            }
        }
        return result;
    }

    //frequently used for Origin Address, this function populates the given address info from the saved account settings then returns it
    private static AvaTaxService.AddressInfo populateAddressFromSettings(AvaTaxService.AddressInfo addInfo, SObject obj){
        addInfo.line1 = service.getOriginAddress(obj)?.street;
        addInfo.city = service.getOriginAddress(obj)?.city;
        addInfo.region = service.getOriginAddress(obj)?.stateProvince;
        addInfo.postalCode = service.getOriginAddress(obj)?.postalCode;
        addInfo.country = service.getOriginAddress(obj)?.countryCode;
        return addInfo;
    }

    private static AvaTaxService.AddressInfo populateAddressFromSettings(AvaTaxService.AddressInfo addInfo){
        return addInfo;
    }


    public static String getTaxAddressMode(SObject obj) {
        if (String.isBlank(service.getSalesTaxCalculationMode(obj))) {
            throw new AvaTaxService.AvaTaxException(new AvaTaxService.AvaTaxError(TAX_ADDRESS_MODE_NOT_SELECTED_ERROR));
        }
        return service.getSalesTaxCalculationMode(obj);
    }

    private static List<AvaTaxService.LineItemModel> getLines() {
        List<AvaTaxService.LineItemModel> result;
        switch on sourceRecord {
            when Billing__c b {
                result = getBillingLines();
            }
            when Opportunity o {
                result = getOpportunityLines();
            }
        }

        return result;
    }

    private static List<AvaTaxService.LineItemModel> getBillingLines() {
        List<AvaTaxService.LineItemModel> result = new List<AvaTaxService.LineItemModel>();
        for (Billing_Line__c billLine : (List<Billing_Line__c>) sourceRecordLines) {
            //just in case: filter out all non-taxable lines
            if (validateBillingLineIsTaxable(billLine, sourceRecord)) {
                AvaTaxService.LineItemModel tempLine = new AvaTaxService.LineItemModel();
                tempLine.avaTaxNumber = billLine.Name;
                tempLine.amount = (billLine.Hours_Units__c * billLine.Rate__c) / getCurrencyConversionRate(sourceRecord);
                //Quantity field is required on Billing Line so no need to check for NULL value
                tempLine.quantity = Math.abs(billLine.Hours_Units__c);
                putItemCodeOnLine(tempLine, billLine.Product__r);
                tempLine.description = billLine.Product__r.Description;
                tempLine.addresses = getAddresses(getOriginAddressInfo(billLine, (Billing__c)sourceRecord), getDestinationAddressInfo(billLine, (Billing__c)sourceRecord), sourceRecord);
                result.add(tempLine);
            }
        }
        return result;
    }

    public static Boolean validateBillingLineIsTaxable(Billing_Line__c billLine, SObject ledgerSource) {
        Boolean result = false;
        if (IS_HEADER_LEVEL_POST) {
            result = billLine.Product__c != NULL && billLine.Hours_Units__c != NULL && billLine.Rate__c != NULL;
        }
        else {
            result = billLine.Product__c != NULL && billLine.Product__c != getSalesTaxProductId(ledgerSource);
        }
        return result;
    }

    //used only in HLP mode (no Tax Calc in LLP for Recurring Billings)
    public static Boolean validateRecurringBillingLineIsTaxable(Recurring_Billing_Line__c rbLine) {
        return rbLine.Product__c != NULL && rbLine.Quantity__c != NULL && rbLine.Rate__c != NULL;
    }

    public static Boolean validateOpportunityLineItemIsTaxable(OpportunityLineItem oppLineItem) {
        Boolean result = false;
        if (IS_HEADER_LEVEL_POST) {
            result = oppLineItem.PricebookEntryId != NULL
                && oppLineItem.PricebookEntry.Product2Id != NULL;
        }
        else {
            result = oppLineItem.PricebookEntryId != NULL
                && oppLineItem.PricebookEntry.Product2Id != NULL
                && oppLineItem.PricebookEntry.Product2Id != getSalesTaxProductId(sourceRecord);
        }
        return result;
    }

    @TestVisible
    private static List<AvaTaxService.LineItemModel> getOpportunityLines() {
        List<AvaTaxService.LineItemModel> result = new List<AvaTaxService.LineItemModel>();
        Double currencyConversionRateForOpportunity = getCurrencyConversionRateForOpportunity(sourceRecord);
        for (OpportunityLineItem oppLine : (List<OpportunityLineItem>) sourceRecordLines) {
            if (validateOpportunityLineItemIsTaxable(oppLine)) {
                AvaTaxService.LineItemModel tempLine = new AvaTaxService.LineItemModel();
                Decimal discountValue = 0;
                if (oppLine.getPopulatedFieldsAsMap().get('Discount') != NULL) {
                    discountValue = oppLine.Discount;
                }
                tempLine.avaTaxNumber = oppLine.Id;
                tempLine.amount = ((oppLine.UnitPrice * (100 - discountValue) / 100) * oppLine.Quantity) / currencyConversionRateForOpportunity;
                //Quantity field is required on Opportunity Line Item so no need to check for NULL value
                tempLine.quantity = Math.abs(oppLine.Quantity);
                putItemCodeOnLine(tempLine, oppLine.PricebookEntry.Product2);
                tempLine.description = oppLine.PricebookEntry.Product2.Description;
                result.add(tempLine);
            }
        }
        return result;
    }

    public static AvaTaxService.LineItemModel putItemCodeOnLine(AvaTaxService.LineItemModel tempLine, Product2 product) {
        //Item Code field on LineItemModel has max length limit (50)
        //So we will truncate any source values for this field
        tempLine.itemCode = (!String.isBlank(product.ProductCode)) ? product.ProductCode.left(50) : product.Name.left(50);
        //Avalara Tax Code field has max length: 25 which is exactly the same limit as on Avalara side, so we do not need to truncate it.
        tempLine.taxCode = (!String.isBlank(product.Tax_Code__c)) ? product.Tax_Code__c : '';
        return tempLine;
    }

    public static Id getAvaTaxGLAccount(SObject obj) {
        if (service.getSalesTaxGLAccount(obj) == NULL) {
            throw new AvaTaxService.AvaTaxException(new AvaTaxService.AvaTaxError(AVALARA_GL_ACCOUNT_NOT_FOUND_ERROR));
        }
        return service.getSalesTaxGLAccount(obj);
    }

    public static Id getSalesTaxProductId(SObject obj) {
        if (service.getSalesTaxProduct(obj) == NULL && AccountingSettingsHandler.isLineLevelPost()) {
            throw new AvaTaxService.AvaTaxException(new AvaTaxService.AvaTaxError(SALES_TAX_PRODUCT_NOT_FOUND_ERROR));
        }
        return service.getSalesTaxProduct(obj);
    }

    public static Set<Id> getSalesTaxProductIds(List<SObject> objs) {
        Set<Id> productIds = new Set<Id>();
        for (SObject obj : objs) {
            if (service.getSalesTaxProduct(obj) == NULL && AccountingSettingsHandler.isLineLevelPost()) {
                throw new AvaTaxService.AvaTaxException(new AvaTaxService.AvaTaxError(SALES_TAX_PRODUCT_NOT_FOUND_ERROR));
            }
            productIds.add(service.getSalesTaxProduct(obj));
        }
        return productIds;
    }

    public static Boolean isAvalaraTaxCalculationEnabled(SObject obj) {
        return service.getTaxMethod(obj) == TaxSettingsActions.AVA_TAX_METHOD;
    }

    public static Boolean isAvalaraTaxCalculationEnabled(List<SObject> objs) {
        for (SObject obj : objs) {
            if (service.getTaxMethod(obj) == TaxSettingsActions.AVA_TAX_METHOD) {
                return true;
            }
        }
        return false;
    }

    public static List<SObject> avalaraTaxCalculationList(List<SObject> objs) {
        List<SObject> result = new List<SObject>();
        for (SObject obj : objs) {
            if (service.getTaxMethod(obj) == TaxSettingsActions.AVA_TAX_METHOD) {
                result.add(obj);
            }
        }
        return result;
    }

    public static List<SObject> avalaraTaxCalculationBillingList(List<Billing__c> objs) {
        List<SObject> result = new List<SObject>();
        for (Billing__c obj : objs) {
            if (service.getTaxMethod(obj) == TaxSettingsActions.AVA_TAX_METHOD && !obj.Locked_In_AvaTax__c) {
                result.add(obj);
            }
        }
        return result;
    }

    public static Boolean isMultipleAvaTaxLicenseExist(List<SObject> objs) {
        Boolean result = false;
        String firstAvalaraLicense;
        for (SObject obj : objs) {
            String licenseKey;
            if (service.getAvalaraAccountID(obj) != null
                && service.getAvalaraLicenseKey(obj) != null
                && service.getAvalaraEndpoint(obj) != null) {
                licenseKey = service.getAvalaraAccountID(obj) + service.getAvalaraLicenseKey(obj) + service.getAvalaraEndpoint(obj);
                firstAvalaraLicense = firstAvalaraLicense == null ? licenseKey : firstAvalaraLicense;

                if (!result && licenseKey != firstAvalaraLicense) {
                    result = true;
                }
            }
        }
        return result;
    }
 
    public static Product2 getSalesTaxProduct(SObject obj) {
        Id salesTaxProductId = AvaTaxHelper.getSalesTaxProductId(obj);
        if (salesTaxProductId != NULL) {
            List<Product2> products = DomainUtils.getProductsById(new Set<Id>{salesTaxProductId});
            return products[0];
        }
        return NULL;
    }

    public static Map<Id, Product2> getProductDetailsById(Set<Id> productIds) {
        return  new Map<Id, Product2>(DomainUtils.getProductsById(productIds));
    }

    public static List<Billing__c> queryBillingById(Set<Id> billingIds, Boolean onlyPosted) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Date__c',
            'Customer__c',
            'Customer__r.Name',
            'Customer__r.VAT_Business_Identification_Number__c',
            'Customer__r.Entity_Use_Code__c',
            'Customer__r.Exemption_Number__c',
            'Accounting_Period__c',
            'PO_Number__c',
            'Status__c',
            'Ledger__c',
            'Line_Count__c',
            'Billing_Cash_Receipt_Count__c',
            'Credit_Memo_Applied_Amount__c',
            'Shipping_Street__c',
            'Shipping_Country__c',
            'Shipping_State__c',
            'Shipping_PostalCode__c',
            'Shipping_City__c',
            'Origin_Address_Override__c',
            'Origin_Address_Override__r.Street__c',
            'Origin_Address_Override__r.City__c',
            'Origin_Address_Override__r.Postal_Code__c',
            'Origin_Address_Override__r.State_Province__c',
            'Origin_Address_Override__r.Country_Code__c',
            'Destination_Address_Override__c',
            'Destination_Address_Override__r.Street__c',
            'Destination_Address_Override__r.City__c',
            'Destination_Address_Override__r.Postal_Code__c',
            'Destination_Address_Override__r.State_Province__c',
            'Destination_Address_Override__r.Country_Code__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
            queryFields.add('Currency_Conversion_Rate__c');
            queryFields.add('Ledger__r.CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :billingIds';

        if (onlyPosted == true) {
            queryCondition += ' AND Status__c = \'Posted\'';
        }

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    public static List<Billing_Line__c> queryTaxableBillingLinesByBillingId(Set<Id> billingIds) {
        return queryTaxableBillingLinesByBillingId(billingIds, true, false);
    }

    public static List<Billing_Line__c> queryTaxableBillingLinesByBillingId(Set<Id> billingIds, Boolean taxableOnly, boolean enforceFLS) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Billing__c',
            'Sub_Total__c',
            'Hours_Units__c',
            'Rate__c',
            'Tax_Group__c',
            'Project__c',
            'Project_Task__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Time_Card_Variable_1__c',
            'Time_Card_Variable_2__c',
            'Tax_Amount2__c',
            'Product__c',
            'Product__r.Name',
            'Product__r.ProductCode',
            'Product__r.Tax_Code__c',
            'Product__r.Description',
            'Opportunity_Product_Id__c',
            'Recurring_Billing_Line__c',
            'Line_Destination_Address_Override__r.City__c',
            'Line_Destination_Address_Override__r.Country_Code__c',
            'Line_Destination_Address_Override__r.Postal_Code__c',
            'Line_Destination_Address_Override__r.State_Province__c',
            'Line_Destination_Address_Override__r.Street__c',
            'Line_Origin_Address_Override__r.City__c',
            'Line_Origin_Address_Override__r.Country_Code__c',
            'Line_Origin_Address_Override__r.Postal_Code__c',
            'Line_Origin_Address_Override__r.State_Province__c',
            'Line_Origin_Address_Override__r.Street__c',
            'Line_Origin_Address_Override__r.Street__c',
            'Billing__r.Line_Count__c',
            'Billing__r.Customer__c',
            'Billing__r.Status__c',
            'Billing__r.Ledger__c',
            'Billing__r.Ledger__r.Accounting_Method__c',
            'Billing__r.Proprietary_Billing_Number__c',
            'Billing__r.Name',
            'Billing__r.Type__c',
            'Billing__r.Date__c',
            'Billing__r.Accounting_Period__c',
            'Revenue_GL_Account__c',
            'Employee__c',
            'Total__c',
            'Date__c',
            'Tax_Line__c',
            'Product_Unit_Cost__c',
            'Inventory_GL_Account__c',
            'Expense_GL_Account__c',
            'Ledger__c',
            'Tax_Inclusive__c',
            'Combined_Tax_Rate__c',
            'Project_Task__r.Project__c',
            'Project_Task__r.GL_Account_Variable_1__c',
            'Project_Task__r.GL_Account_Variable_2__c',
            'Project_Task__r.GL_Account_Variable_3__c',
            'Project_Task__r.GL_Account_Variable_4__c',
            'Product__r.Inventory_Product__c',
            'Product__r.Inventory_Type__c',
            'Product__r.Unit_Cost__c',
            'Product__r.GL_Account_Variable_1__c',
            'Product__r.GL_Account_Variable_2__c',
            'Product__r.GL_Account_Variable_3__c',
            'Product__r.GL_Account_Variable_4__c',
            'Product__r.Expense_GL_Account__c',
            'Product__r.Inventory_GL_Account__c',
            'Billing__r.Shipping_Street__c',
            'Billing__r.Shipping_City__c',
            'Billing__r.Shipping_State__c',
            'Billing__r.Shipping_PostalCode__c',
            'Billing__r.Shipping_Country__c',
            'Billing__r.Destination_Address_Override__c',
            'Billing__r.Destination_Address_Override__r.Street__c',
            'Billing__r.Destination_Address_Override__r.City__c',
            'Billing__r.Destination_Address_Override__r.State_Province__c',
            'Billing__r.Destination_Address_Override__r.Postal_Code__c',
            'Billing__r.Destination_Address_Override__r.Country_Code__c'
        };

        List<String> conditions = new List<String>();
        if (taxableOnly) {
            Set<Id> salesTaxProductIds = getSalesTaxProductIds(sourceRecordMap.values());
            conditions.add(
                (IS_HEADER_LEVEL_POST)
                    ? 'Billing__c IN :billingIds AND Product__c != NULL AND Hours_Units__c != NULL AND Rate__c != NULL'
                    : 'Billing__c IN :billingIds AND Product__c != NULL AND Product__c NOT IN :salesTaxProductIds');
        }
        else {
            conditions.add('Billing__c IN :billingIds');
        }

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Billing_Line__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Line__c.SObjectType);
        theQuery
            .setEnforceFLS(enforceFLS)
            .selectFields(queryFields)
            .setCondition(String.join(conditions, ' AND '))
            .addOrdering(ordering);

        return (List<Billing_Line__c>) Database.query(theQuery.toSOQL());
    }

    public static Opportunity queryOpportunityById(Id opportunityId) {
        List<Opportunity> result = queryOpportunityById(new Set<Id>{opportunityId});
        return (result.isEmpty()) ? NULL : result[0];
    }

    public static List<Opportunity> queryOpportunityById(Set<Id> opportunityIds) {
        List<String> queryFields = new List<String>{
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
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id IN :opportunityIds';

        SOQLBuilder theQuery = new SOQLBuilder(Opportunity.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Opportunity>) Database.query(theQuery.toSOQL());
    }

    public static List<OpportunityLineItem> queryTaxableOpportunityLineItemsByOpportunityId(SObject opportunity, Id ledgerId) {
        Id opportunityId = opportunity.Id;
        List<String> queryFields = new List<String>{
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
        };

        if (DomainUtils.isDiscountIncludedInOpportunityLineItems(new Set<Id>{opportunityId})) {
            queryFields.add('Discount');
        }

        TaxService.sobjectByLedgerId = new Map<SObject, Id> {opportunity => ledgerId};
        String salesTaxProductId = getSalesTaxProductId(opportunity);
        String queryCondition =
            (IS_HEADER_LEVEL_POST)
            ? 'OpportunityId = :opportunityId AND PricebookEntryId != NULL AND PricebookEntry.Product2Id != NULL'
            : 'OpportunityId = :opportunityId AND PricebookEntryId != NULL AND PricebookEntry.Product2Id != NULL AND PricebookEntry.Product2Id != :salesTaxProductId';

        SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
        theQuery
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<OpportunityLineItem>) Database.query(theQuery.toSOQL());
    }

    public static List<OpportunityLineItem> queryExistedSalesTaxOpportunityProductLines(Id opportunityId, Id salesProductId) {
        if (opportunityId == NULL || salesProductId == NULL) {
            return new List<OpportunityLineItem>();
        }
        else {
            String queryCondition = 'OpportunityId = :opportunityId AND PricebookEntry.Product2.Id = :salesProductId';
            SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
            theQuery.setCondition(queryCondition);
            return (List<OpportunityLineItem>) Database.query(theQuery.toSOQL());
        }
    }

    private static String getLineNumberKey(Billing_Line__c existedBillingLine, String source) {
        if (!Test.isRunningTest()) {
            return existedBillingLine.Name;
        }
        else {
            switch on source {
                when 'OPPORTUNITY' {
                    return existedBillingLine.Opportunity_Product_Id__c;
                }
                when 'RECURRING_BILLING' {
                    return existedBillingLine.Recurring_Billing_Line__c;
                }
                when else {
                    return existedBillingLine.Name;
                }
            }
        }
    }

    public static void populateTaxAmountOnLine(Id sourceRecordId, AvaTaxService.TransactionModel responseResult) {
        populateTaxAmountOnLines(new Map<Id, AvaTaxService.TransactionModel>{sourceRecordId => responseResult}, true);
    }

    public static List<AvaTaxCalculationReport> populateTaxAmountOnLines(Map<Id, AvaTaxService.TransactionModel> responseResults, Boolean doDML) {
        List<AvaTaxCalculationReport> result = new List<AvaTaxCalculationReport>();
        if (!responseResults.isEmpty()) {
            List<Billing_Line__c> linesToUpdate = new List<Billing_Line__c>();
            Boolean isMassTaxCalc = responseResults.size() > 1;
            for (Billing_Line__c existedBillingLine : AvaTaxHelper.queryTaxableBillingLinesByBillingId(responseResults.keySet())) {
                AvaTaxService.TransactionModel responseResult = responseResults.get(existedBillingLine.Billing__c);
                Map<String, AvaTaxService.TransactionLineModel> linesMap = responseResult.getLinesMap();
                String lineNumberKey = getLineNumberKey(existedBillingLine, responseResult.modelSourcedFrom);

                if (linesMap.containsKey(lineNumberKey)) {

                    if (isMassTaxCalc) {
                        sourceRecord = sourceRecordMap.get(existedBillingLine.Billing__c);
                    }

                    Decimal taxAmount = linesMap.get(lineNumberKey).taxCalculated * getCurrencyConversionRate(sourceRecord);
                    Boolean isTaxAmountChanged = taxAmount != existedBillingLine.Tax_Amount2__c;
                    if (isTaxAmountChanged) {
                        oldTaxAmountsByLineIds.put(existedBillingLine.Id, existedBillingLine.Tax_Amount2__c);
                    }
                    existedBillingLine.Tax_Amount2__c =
                        linesMap.get(lineNumberKey).taxCalculated * getCurrencyConversionRate(sourceRecord);

                    if (isTaxAmountChanged) {
                        linesToUpdate.add(existedBillingLine);
                    }
                }
            }

            if (doDML) {
                TriggerObserver.getInstance().unlockField(Billing_Line__c.Tax_Amount2__c);
                TriggerObserver.getInstance().unlockField(Billing__c.Total__c);
                BillingLineActions.isSkipLineUpdateTrigger4LDV = isLDVBatchContext;
                List<Database.SaveResult> srList = SFDCSecurityUtils.updateCheckCRUDAndFLS(linesToUpdate, new List<String>(), false);
                BillingLineActions.isSkipLineUpdateTrigger4LDV = false;
                TriggerObserver.purgeUnlockedFields(Billing_Line__c.Tax_Amount2__c);
                TriggerObserver.purgeUnlockedFields(Billing__c.Total__c);
                result = buildAvaTaxCalculationReports(linesToUpdate, srList);
            }
            else {
                result = buildAvaTaxCalculationReports(linesToUpdate);
            }
        }
        return result;
    }

    //build reports based on Billing Line's update DML operation results
    private static List<AvaTaxCalculationReport> buildAvaTaxCalculationReports(List<Billing_Line__c> linesToUpdate, List<Database.SaveResult> saveResults) {
        List<AvaTaxCalculationReport> result = new List<AvaTaxCalculationReport>();
        Map<Id, Billing_Line__c> billLineMap = new Map<Id, Billing_Line__c>(linesToUpdate);
        Map<Id, Database.SaveResult> mappedSaveResults = new Map<Id, Database.SaveResult>();
        Map<Id, List<Billing_Line__c>> headerToLines = new Map<Id, List<Billing_Line__c>>();
        for (Integer i = 0; i < linesToUpdate.size(); i++) {
            mappedSaveResults.put(linesToUpdate[i].Id, saveResults[i]);
            Billing_Line__c billLine = billLineMap.get(linesToUpdate[i].Id);
            Id billingId = billLine.Billing__c;
            if (headerToLines.containsKey(billingId)) {
                headerToLines.get(billingId).add(billLine);
            }
            else {
                headerToLines.put(billingId, new List<Billing_Line__c>{billLine});
            }
        }
        for (Id billingId : headerToLines.keySet()) {
            //Check Save Results for all lines
            AvaTaxCalculationError atcError;
            Boolean allBillingLinesSuccessfullyUpdated = true;
            for (Billing_Line__c line : headerToLines.get(billingId)) {
                if (!mappedSaveResults.get(line.Id).isSuccess()) {
                    allBillingLinesSuccessfullyUpdated = false;
                    String errorMsg = mappedSaveResults.get(line.Id).getErrors().get(0).message;
                    AvaTaxCalculationErrorStatusCode code;
                    if (errorMsg.contains(SObjectActions.OVER_APPLIED_ERROR.removeStart('{0}'))) {
                        code = AvaTaxCalculationErrorStatusCode.OVER_APPLY_ERROR;
                    }
                    else {
                        code = AvaTaxCalculationErrorStatusCode.DML_ERROR;
                    }
                    atcError = new AvaTaxCalculationError(code, errorMsg);
                    break;
                }
            }
            AvaTaxCalculationReport acReport = new AvaTaxCalculationReport(
                allBillingLinesSuccessfullyUpdated, billingId, headerToLines.get(billingId), atcError
            );
            result.add(acReport);
        }
        return result;
    }

    //build reports based on virtually populated Tax Amount field on Billing Lines
    private static List<AvaTaxCalculationReport> buildAvaTaxCalculationReports(List<Billing_Line__c> linesToUpdate) {
        List<AvaTaxCalculationReport> result = new List<AvaTaxCalculationReport>();
        Map<Id, List<Billing_Line__c>> headerToLines = new Map<Id, List<Billing_Line__c>>();
        for (Billing_Line__c billLine : linesToUpdate) {
            Id billingId = billLine.Billing__c;
            if (headerToLines.containsKey(billingId)) {
                headerToLines.get(billingId).add(billLine);
            }
            else {
                headerToLines.put(billingId, new List<Billing_Line__c>{billLine});
            }
        }
        result.addAll(validateOverApplicationOfBillings(headerToLines));
        return result;
    }

    private static List<AvaTaxCalculationReport> validateOverApplicationOfBillings(Map<Id, List<Billing_Line__c>> headerToLines) {
        List<AvaTaxCalculationReport> result = new List<AvaTaxCalculationReport>();
        Map<Id, Billing__c> billingsInDB = new Map<Id, Billing__c>(DomainUtils.getRollupsOnBillingById(headerToLines.keySet()));
        Map<Id, Billing_Line__c> existedLinesMap = DomainUtils.getBillingLinesByMasterId(billingsInDB.keySet());
        Map<Id, List<Billing_Line__c>> headerToLinesActual = new Map<Id, List<Billing_Line__c>>();
        for (Billing_Line__c existedLine : existedLinesMap.values()) {
            if (headerToLinesActual.containsKey(existedLine.Billing__c)) {
                headerToLinesActual.get(existedLine.Billing__c).add(existedLine);
            }
            else {
                headerToLinesActual.put(existedLine.Billing__c, new List<Billing_Line__c>{existedLine});
            }
        }
        for (Billing__c billing : billingsInDB.values()) {
            Decimal currentAppliedAbs =
                Math.abs(billing.Received_Amount__c)
                    + Math.abs(billing.Cash_Application_Adjustment_Amount__c)
                    + Math.abs(billing.Credit_Memo_Applied_Amount__c);
            AvaTaxCalculationReport tempAvaTaxCalculationReport = new AvaTaxCalculationReport(
                true, billing.Id, headerToLines.get(billing.Id), NULL
            );
            populateUpdatedTaxes(tempAvaTaxCalculationReport, headerToLinesActual.get(billing.Id));
            Decimal estimatedTotalAbs = Math.abs(calcEstimatedTotal(headerToLinesActual.get(billing.Id)));
            //if estimated Billing's Total is less then current SUM of
            //Received Amount + Cash Application Adjustment Amount + Credit Memo Applied Amount
            //we must prevent such Billing from posting
            if ((estimatedTotalAbs - currentAppliedAbs).setScale(2, System.RoundingMode.HALF_UP) < 0) {
                tempAvaTaxCalculationReport.isSuccess = false;
                tempAvaTaxCalculationReport.error = new AvaTaxCalculationError(
                    AvaTaxCalculationErrorStatusCode.OVER_APPLY_ERROR, AbstractPostHandler.BALANCE_OVERAPPLIED_HELP_TEXT
                );
            }
            result.add(tempAvaTaxCalculationReport);
        }
        return result;
    }

    private static Decimal calcEstimatedTotal(List<Billing_Line__c> lines) {
        Decimal result = 0;
        for (Billing_Line__c line : lines) {
            Decimal unitPrice = (line.Rate__c != NULL) ? line.Rate__c : 0;
            Decimal quantity = (line.Hours_Units__c != NULL) ? line.Hours_Units__c : 0;
            Decimal taxAmount = (line.Tax_Amount2__c != NULL) ? line.Tax_Amount2__c : 0;
            result += (unitPrice * quantity + taxAmount);
        }
        return result;
    }

    public static void populateUpdatedTaxes(AvaTaxHelper.AvaTaxCalculationReport report, List<Billing_Line__c> targetLines) {
        if (IS_HEADER_LEVEL_POST) {
            Map<Id, Billing_Line__c> billingLinesFromReport = new Map<Id, Billing_Line__c>((List<Billing_Line__c>) report.lines);
            for (Billing_Line__c billingLine : targetLines) {
                if (billingLinesFromReport.containsKey(billingLine.Id)) {
                    billingLine.Tax_Amount2__c = billingLinesFromReport.get(billingLine.Id).Tax_Amount2__c;
                }
            }
        }
        else {
            //In LLP mode: populate new Tax Value if there is existed Sales Tax Line
            Boolean salesTaxLineExists = false;
            Billing__c source;
            for (Billing_Line__c billingLine : targetLines) {
                if (source == null && billingLine.Billing__r != null) {
                    source = billingLine.Billing__r;
                }

                if (source != null && service.getSalesTaxProduct(source) != null && billingLine.Product__c == AvaTaxHelper.getSalesTaxProductId(source)) {
                    salesTaxLineExists = true;
                    billingLine.Rate__c = (Decimal) report.lines[0].get('Rate__c');
                }
            }
            //Or add new Sales Tax line if it's first time Tax Calculation
            if (!salesTaxLineExists) {
                targetLines.add((Billing_Line__c) report.lines[0]);
            }
        }
    }

    public static void populateTaxAmountOnVirtualLines( AvaTaxService.TransactionModel responseResult,
                                                        Map<String, Billing_Line__c> billingLineMappedByUUID,
                                                        Decimal ccr) {

        if (responseResult != NULL && billingLineMappedByUUID != NULL && !billingLineMappedByUUID.isEmpty()) {
            Map<String, AvaTaxService.TransactionLineModel> avaTaxLineItemMap = responseResult.getLinesMap();
            for (String key : billingLineMappedByUUID.keySet()) {
                if (avaTaxLineItemMap.containsKey(key) && billingLineMappedByUUID.get(key) != NULL) {
                    billingLineMappedByUUID.get(key).Tax_Amount2__c = avaTaxLineItemMap.get(key).taxCalculated * ccr;
                }
            }
        }
    }

    public static void populateTaxAmountOnVirtualLines( AvaTaxService.TransactionModel responseResult,
                                                        Map<String, Recurring_Billing_Line__c> rbLineMappedByUUID,
                                                        Decimal ccr) {

        if (responseResult != NULL && rbLineMappedByUUID != NULL && !rbLineMappedByUUID.isEmpty()) {
            Map<String, AvaTaxService.TransactionLineModel> avaTaxLineItemMap = responseResult.getLinesMap();
            for (String key : rbLineMappedByUUID.keySet()) {
                if (avaTaxLineItemMap.containsKey(key) && rbLineMappedByUUID.get(key) != NULL) {
                    rbLineMappedByUUID.get(key).Tax_Amount__c = avaTaxLineItemMap.get(key).taxCalculated * ccr;
                }
            }
        }
    }

    public static void upsertTaxLine(Id sourceRecordId, AvaTaxService.TransactionModel responseResult) {
        upsertTaxLines(new Map<Id, AvaTaxService.TransactionModel>{sourceRecordId => responseResult}, true);
    }

    public static List<AvaTaxCalculationReport> upsertTaxLines(Map<Id, AvaTaxService.TransactionModel> responseResults, Boolean doDML) {
        List<AvaTaxCalculationReport> finalReports = new List<AvaTaxCalculationReport>();
        if (!responseResults.isEmpty()) {
            finalReports = createNewBillingTaxLines(responseResults, false);

            if (doDML) {
                Set<Id> billingIdsPassedPreliminaryValidation = new Set<Id>();
                Map<Id, AvaTaxService.TransactionModel> filteredResponseResults = new Map<Id, AvaTaxService.TransactionModel>();
                List<AvaTaxCalculationReport> failedReports = new List<AvaTaxCalculationReport>();
                for (AvaTaxCalculationReport avaTaxReport : finalReports) {
                    if (avaTaxReport.isSuccess) {
                        billingIdsPassedPreliminaryValidation.add(avaTaxReport.headerId);
                        filteredResponseResults.put(avaTaxReport.headerId, responseResults.get(avaTaxReport.headerId));
                    }
                    else {
                        failedReports.add(avaTaxReport);
                    }
                }
                if (!billingIdsPassedPreliminaryValidation.isEmpty() && !filteredResponseResults.isEmpty()) {
                    TriggerObserver.getInstance().unlockField(Billing__c.Total__c);
                    List<Billing_Line__c> linesForDelete = AvaTaxHelper.queryExistedSalesTaxBillingLines(filteredResponseResults.keySet(), AvaTaxHelper.getSalesTaxProductIds(sourceRecordMap.values()));

                    if (FeatureManagementHandler.isLargeDataVolumeModeEnabled() && System.isBatch()) {
                        TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                            linesForDelete, false
                        ));
                    }

                    SFDCSecurityUtils.deleteCheckCRUDAndFLS(linesForDelete);
                    finalReports = createNewBillingTaxLines(filteredResponseResults, doDML);
                    TriggerObserver.purgeUnlockedFields(Billing__c.Total__c);
                }
                finalReports.addAll(failedReports);
            }
        }
        return finalReports;
    }

    public static List<Billing_Line__c> queryExistedSalesTaxBillingLines(Set<Id> billingIds, Set<Id> salesTaxProductIds) {
        if (billingIds == NULL || billingIds.isEmpty() || salesTaxProductIds.isEmpty() == NULL) {
            return new List<Billing_Line__c>();
        }
        else {
            List<String> queryFields = new List<String>{'Billing__c'};
            String queryCondition = 'Billing__c IN :billingIds AND Product__c IN :salesTaxProductIds';
            SOQLBuilder theQuery = new SOQLBuilder(Billing_Line__c.SObjectType);
            theQuery.selectFields(queryFields).setCondition(queryCondition);
            return (List<Billing_Line__c>) Database.query(theQuery.toSOQL());
        }
    }

    private static List<AvaTaxCalculationReport> createNewBillingTaxLines(Map<Id, AvaTaxService.TransactionModel> responseResults, Boolean doDML) {
        List<AvaTaxCalculationReport> result = new List<AvaTaxCalculationReport>();
        Map<Id, Billing_Line__c> billingToNewSalesTaxLine = new Map<Id, Billing_Line__c>();
        Boolean isMassTaxCalc = responseResults.size() > 1;
        Set<Id> productIds = new Set<Id>();
        for (Id billingId : responseResults.keySet()) {
            if (isMassTaxCalc) {
                sourceRecord = sourceRecordMap.get(billingId);
            }
            Id prodId = AvaTaxHelper.getSalesTaxProductId(sourceRecord);

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = billingId,
                Hours_Units__c = 1,
                Rate__c = responseResults.get(billingId).totalTax * getCurrencyConversionRate(sourceRecord),
                Date__c = responseResults.get(billingId).avaTaxDate,
                Revenue_GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(sourceRecord),
                Product__c = prodId
            );
            productIds.add(prodId);
            billingToNewSalesTaxLine.put(billingId, tempBillingLine);
        }

        Map<Id, Product2> productMap = getProductDetailsById(productIds);

        for(Billing_Line__c bL : billingToNewSalesTaxLine.values()){
            Product2 prod = productMap.get(bl.Product__c);
            bL.GL_Account_Variable_1__c = prod.GL_Account_Variable_1__c;
            bL.GL_Account_Variable_2__c = prod.GL_Account_Variable_2__c;
            bL.GL_Account_Variable_3__c = prod.GL_Account_Variable_3__c;
            bL.GL_Account_Variable_4__c = prod.GL_Account_Variable_4__c;
        }


        if (doDML) {
            SObjectActions.isSkipDefaultGLAccounts = true;
            List<Database.SaveResult> saveResults = SFDCSecurityUtils.insertCheckCRUDAndFLS(billingToNewSalesTaxLine.values(), new List<String>{
                'Hours_Units__c', 'Rate__c', 'Date__c', 'Revenue_GL_Account__c', 'Product__c', 'GL_Account_Variable_1__c', 'GL_Account_Variable_2__c', 'GL_Account_Variable_3__c', 'GL_Account_Variable_4__c'
            });
            SObjectActions.isSkipDefaultGLAccounts = false;
            result = buildAvaTaxCalculationReports(billingToNewSalesTaxLine.values(), saveResults);
        }
        else {
            Map<Id, Billing_Line__c> billingIdToExistedSalesTaxLine = new Map<Id, Billing_Line__c>();
            for (Billing_Line__c salesTaxLine : queryExistedSalesTaxBillingLines(responseResults.keySet(), AvaTaxHelper.getSalesTaxProductIds(sourceRecordMap.values()))) {
                billingIdToExistedSalesTaxLine.put(salesTaxLine.Billing__c, salesTaxLine);
            }
            for (Id billingId : billingToNewSalesTaxLine.keySet()) {
                if (billingIdToExistedSalesTaxLine.containsKey(billingId)) {
                    billingToNewSalesTaxLine.get(billingId).Id = billingIdToExistedSalesTaxLine.get(billingId).Id;
                }
            }
            result = buildAvaTaxCalculationReports(billingToNewSalesTaxLine.values());
        }
        return result;
    }

    private static Boolean isShippingAddressPopulated(SObject headerRecord) {
        String line1 = (String) headerRecord.get(PACKAGE_QUALIFIER + 'Shipping_Street__c');
        String city = (String) headerRecord.get(PACKAGE_QUALIFIER + 'Shipping_City__c');
        String region = (String) headerRecord.get(PACKAGE_QUALIFIER + 'Shipping_State__c');
        String postalCode = (String) headerRecord.get(PACKAGE_QUALIFIER + 'Shipping_PostalCode__c');
        String country = (String) headerRecord.get(PACKAGE_QUALIFIER + 'Shipping_Country__c');
        return !String.isBLank(line1) && !String.isBLank(city) && !String.isBLank(region) && !String.isBLank(postalCode) && !String.isBLank(country);
    }

    private static Boolean isSettingAddressPopulated(SObject headerRecord) {
        AvaTaxService.AddressInfo originAddress = new AvaTaxService.AddressInfo();
        originAddress = populateAddressFromSettings(originAddress, headerRecord);
        String line1 = originAddress.line1;
        String city = originAddress.city;
        String region = originAddress.region;
        String postalCode = originAddress.postalCode;
        String country = originAddress.country ;
        return !String.isBLank(line1) && !String.isBLank(city) && !String.isBLank(region) && !String.isBLank(postalCode) && !String.isBLank(country);
    }

    public static Boolean validateShippingAddress(SObject headerRecord) {
        Boolean result = true;
        String taxAddressMode = AvaTaxHelper.getTaxAddressMode(headerRecord);
        if ((!isShippingAddressPopulated(headerRecord) && !isSettingAddressPopulated(headerRecord))
                && (taxAddressMode.equalsIgnoreCase('Shipment') || taxAddressMode.equalsIgnoreCase('POD'))) {

            result = false;
        }
        return result;
    }

    public static Boolean isLedgerCurrencySupportedByAvaTaxCalculation(Id ledgerId) {
        return !IS_MULTI_CURRENCY_ENABLED || LedgerHandler.isUSDLedger(ledgerId);
    }

    public static String formatDate(Date aDate) {
        return aDate.month() + '/' + aDate.day() + '/' + aDate.year();
    }

    public with sharing class AvaTaxCalculationResult {
        public Map<Id, AvaTaxCalculationReport> reportMap;

        public AvaTaxCalculationResult() {
            this.reportMap = new Map<Id, AvaTaxCalculationReport>();
        }

        public void addAvaTaxReport(AvaTaxCalculationReport report) {
            this.reportMap.put(report.headerId, report);
        }

        public void addAvaTaxReports(List<AvaTaxCalculationReport> reports) {
            for (AvaTaxCalculationReport dt : reports) {
                addAvaTaxReport(dt);
            }
        }
    }

    public with sharing class AvaTaxCalculationReport {
        public Boolean isSuccess;
        public Id headerId;
        public List<SObject> lines;
        public AvaTaxCalculationError error;

        public AvaTaxCalculationReport(Boolean isSuccess, Id headerId, List<SObject> lines, AvaTaxCalculationError error) {
            this.isSuccess = isSuccess;
            this.headerId = headerId;
            this.lines = lines;
            this.error = error;
        }

        public Boolean isErrorExists(AvaTaxCalculationErrorStatusCode code) {
            return (this.error != NULL) && this.error.code == code;
        }

    }

    public with sharing class AvaTaxCalculationError {
        public AvaTaxCalculationErrorStatusCode code;
        public String errorMsg;

        public AvaTaxCalculationError(AvaTaxCalculationErrorStatusCode code, String msg) {
            this.code = code;
            this.errorMsg = msg;
        }
    }

    public enum AvaTaxCalculationErrorStatusCode {
        AVATAX_SERVICE_ERROR,
        DML_ERROR,
        UNDEFINED_SYSTEM_ERROR,
        OVER_APPLY_ERROR
    }

}