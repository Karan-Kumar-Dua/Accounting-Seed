public with sharing class BillingCreateService {
   
    @TestVisible
    private static final String REQUIRED_FIELD_ERROR = Label.COMMON_REQUIRED_FIELDs_MISSING;
    @TestVisible
    private static final String BILLING_MODEL_ERROR = Label.ERR_INCORRECT_BILLING_FIELD_DATATYPE;
    @TestVisible
    private static final String BILLING_LINE_MODEL_ERROR = Label.ERR_INCORRECT_BILLING_LINE_DATATYPE;
    @TestVisible
    private static final String NO_PERIOD_ERROR_MESSAGE = Label.ERR_NO_AP_WITH_DATE;
    @TestVisible
    private static final String AVALARA_ERROR = Label.ERR_ALVARA_EXCEPTION;

    @TestVisible
    private static Map<String, Schema.SObjectField> billingFieldMap = Schema.SObjectType.Billing__c.fields.getMap();
    @TestVisible
    private static Map<String, Schema.SObjectField> billingLineFieldMap = Schema.SObjectType.Billing_Line__c.fields.getMap();
    private static Billing__c billing;
    private static Boolean postContext = false;
    private static Map<String, String> billingMap = new Map<String, String>();
    private static Map<String, String> billingLineMap = new Map<String, String>();

    public with sharing class BillingModel {
        public Id accountingPeriodId {get; set;}
        public Date billingDate {get; set;}
        public String billingCity {get; set;}
        public String billingComment {get; set;}
        public Id billingContactId {get; set;}
        public String billingCountry {get; set;}
        public Date billingCycleEndDate {get; set;}
        public Date billingCycleStartDate {get; set;}
        public Id billingFormatId {get; set;}
        public String billingPostalCode {get; set;}
        public String billingState {get; set;}
        public String billingStreet {get; set;}
        public String billingTermsName {get; set;}
        public Id customerId {get; set;}
        public Decimal discountPercent {get; set;}
        public Date dueDate {get; set;}
        public Date discountDueDate {get; set;}
        public Id ledgerId {get; set;}
        public Id opportunityId {get; set;}
        public String poNumber {get; set;}
        public String status {get; set;}
        public String proprietaryBillingNumber {get; set;}
        public Id recurringBillingId {get; set;}
        public String shippingCity {get; set;}
        public String shippingPostalCode {get; set;}
        public String shippingCountry {get; set;}
        public String shippingState {get; set;}
        public String shippingStreet {get; set;}
        public Id shippingContactId {get; set;}
        public Map<String, String> fieldMappings {get;set;}
        public List<BillingLineModel> billingLines {get; set;}

        public BillingModel() {
            fieldMappings = new Map<String, String>();
        }
    }

    public with sharing class BillingLineModel {
        public Id productId {get; set;}
        public Date billingLineDate {get; set;}
        public Decimal unitPrice {get; set;}
        public Decimal quantity {get; set;}
        public Decimal listPrice {get; set;}
        public String comment {get; set;}
        public Id revenueGLAccountId {get; set;}
        public Id glAccountVariable1 {get; set;}
        public Id glAccountVariable2 {get; set;}
        public Id glAccountVariable3 {get; set;}
        public Id glAccountVariable4 {get; set;}
        public Id employeeId {get; set;}
        public Id expenseGLAccountId {get; set;}
        public Id inventoryGLAccountId {get; set;}
        public String opportunityProductId {get; set;}
        public Decimal productUnitCost {get; set;}
        public Id projectId {get; set;}
        public Id projectTaskId {get; set;}
        public Id recurringBillingLineId {get; set;}
        public Boolean taxLine {get; set;}
        public Id timeCardVariable1 {get; set;}
        public Id timeCardVariable2 {get; set;}
        public Map<String, String> fieldMappings {get;set;}

        public BillingLineModel() {
            fieldMappings = new Map<String, String>();
        }
    }

    public static List<RestResult> createBilling(BillingModel billModel) {
        List<RestResult> result = new List<RestResult>();
        try {
            if (!requiredFieldCheck(billModel)) {
                result.add(new RestResult(false, NULL,
                    new List<RestResult.RestErrorResult> {new RestResult.RestErrorResult(NULL, REQUIRED_FIELD_ERROR)}
                ));
                return result;
            }

            try {
                billing = getBillingFromModel(billModel);
            }
            catch (JSONException jex) {
                result.add(new RestResult(false, NULL,
                    new List<RestResult.RestErrorResult> {new RestResult.RestErrorResult(NULL, BILLING_MODEL_ERROR)}
                ));
                return result;
            }

            if (!isAccountingPeriodExists(billing.Date__c)) {
                result.add(new RestResult(false, NULL,
                    new List<RestResult.RestErrorResult> {new RestResult.RestErrorResult(NULL, NO_PERIOD_ERROR_MESSAGE)}
                ));
                return result;
            }

            if (billing.Status__c != 'Approved' && postContext) {
                billing.Status__c = 'Approved';
            }

            List<String> billFields = new List<String>{
                'Customer__c',
                'Date__c',
                'Due_Date2__c'
            };
            billFields.addAll(billingMap.values());

            List<Billing_Line__c> billLines = new List<Billing_Line__c>();
            List<String> billLineFields;
            Boolean avalaraError = false;

            if (billModel.billingLines != NULL && !billModel.billingLines.isEmpty()) {
                try {
                    billLines = getBillingLinesFromModel(billModel.billingLines, billing);
                }
                catch (JSONException jex) {
                    result.add(new RestResult(false, NULL,
                        new List<RestResult.RestErrorResult> {new RestResult.RestErrorResult(NULL, BILLING_LINE_MODEL_ERROR)}
                    ));
                    return result;
                }
                billLineFields = new List<String>{
                    'Date__c',
                    'List_Price__c',
                    'Revenue_GL_Account__c',
                    'Comment__c',
                    'GL_Account_Variable_1__c',
                    'GL_Account_Variable_2__c',
                    'GL_Account_Variable_3__c',
                    'GL_Account_Variable_4__c',
                    'Product__c',
                    'Hours_Units__c',
                    'Rate__c'
                };
                billLineFields.addAll(billingLineMap.values());

                billing.Ledger__c = billing.Ledger__c != NULL ? billing.Ledger__c : LedgerHandler.getLedgerIdWithSharing();
                if (AvaTaxHelper.isAvalaraTaxCalculationEnabled(billing)) {
                    try {
                        billLines = calcAvalaraTaxes(billing, billLines);
                    }
                    catch (Exception ex) {
                        avalaraError = true;
                        result.add(new RestResult(false, NULL,
                            new List<RestResult.RestErrorResult> {new RestResult.RestErrorResult(ex.getTypeName(), AVALARA_ERROR)}
                        ));
                    }
                }
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(new List<Billing__c> {billing}, billFields);
            if (!billLines.isEmpty()) {
                setBillingId(billing, billLines);
                SFDCSecurityUtils.insertCheckCRUDAndFLS(billLines, billLineFields);
            }

            if (!avalaraError
                && !postContext
                && !Test.isRunningTest()
                && AvaTaxHelper.isAvalaraTaxCalculationEnabled(billing)
                && !billLines.isEmpty()) {
                AvaTaxHelper.asyncCreateTransaction(new List<SObject> {billing}, false);
            }

            result.add(new RestResult(true, billing.Id, new List<RestResult.RestErrorResult> ()));
        }
        catch (Exception ex) {
            result.add(new RestResult(false, NULL,
                new List<RestResult.RestErrorResult> {new RestResult.RestErrorResult(ex.getTypeName(), ex.getMessage())}
            ));
        }

        return result;
    }

    public static List<RestResult> createBillingAndPost(BillingModel billModel) {
        postContext = true;
        List<RestResult> createResult = createBilling(billModel);
        if (billing != NULL && billing.Id != NULL && !AbstractTaxService.isLedgerTaxSettingsEmpty(billing)) {
            AbstractPostHandler postHandler = new BillingPostHandler();
            AsyncPostHandlersExecutor asyncPHExecutor = new AsyncPostHandlersExecutor(new List<SObject> {billing}, postHandler);
            System.enqueueJob(asyncPHExecutor);
        } else if (AbstractTaxService.isLedgerTaxSettingsEmpty(billing)) {
            createResult.add(new RestResult(false, NULL,
                new List<RestResult.RestErrorResult> {new RestResult.RestErrorResult(null, TaxService.getNoTaxSettingErrorMessage(true))}
            ));
        }

        return createResult;
    }

    @TestVisible
    private static void setBillingId(Billing__c billing, List<Billing_Line__c> lines) {
        for (Billing_Line__c line : lines) {
            line.Billing__c = billing.Id;
        }
    }

    @TestVisible
    private static List<RestResult> validatePostResult(List<PostResult> results) {
        List<RestResult> result = new List<RestResult>();
        for (PostResult res : results) {
            List<RestResult.RestErrorResult> errorList = new List<RestResult.RestErrorResult> ();
            if (res.errors != NULL && !res.errors.isEmpty()) {
                for (PostResult.PostErrorResult err : res.errors) {
                    errorList.add(new RestResult.RestErrorResult('Post Result Error', err.message));
                }
            }
            result.add(new RestResult(res.isSuccess, res.Id, errorList));
        }
        return result;
    }

    @TestVisible
    private static Boolean isAccountingPeriodExists(Date billDate) {
        Boolean result = false;
        if (AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(billDate) != NULL) {
            result = true;
        }
        return result;
    }

    @TestVisible
    private static Boolean requiredFieldCheck(BillingModel bill) {
        Boolean result = true;
        if (bill.customerId == NULL || bill.billingDate == NULL ) {
            result = false;
        }

        if (bill.billingLines != NULL) {
            for (BillingLineModel blm : bill.billingLines) {
                if (blm.billingLineDate == NULL || blm.unitPrice == NULL || blm.quantity == NULL ) {
                    result = false;
                }
            }
        }
        return result;
    }

    @TestVisible
    private static String normalizeKey(String value) {
        if (value.countMatches('__') > 1) {
            return value.substringBetween('__').remove('_').toLowerCase();
        }
        else {
            return value.substringBefore('__').remove('_').toLowerCase();
        }
    }

    @TestVisible
    private static Map<String, String> getFieldMappings(Map<String, Schema.SObjectField> schemaFieldMap, Map<String, String> fieldMapping, Set<String> packageFields) {
        Map<String, String> result = new Map<String, String>();
        for (String key : schemaFieldMap.keySet()) {
            if (!packageFields.contains(schemaFieldMap.get(key).getDescribe().getName())) {
                for (String fieldKey : fieldMapping.keySet()) {
                    if (normalizeKey(schemaFieldMap.get(key).getDescribe().getLocalName()) == fieldKey.toLowerCase()) {
                        result.put(fieldKey, schemaFieldMap.get(key).getDescribe().getName());
                    }
                }
            }
        }
        return result;
    }

    @TestVisible
    private static Billing__c getBillingFromModel (BillingModel billModel) {
        SObject tempSObject = getBilling(billModel);
        Map<String, Object> tempMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(tempSObject));
        if (!billModel.fieldMappings.isEmpty()) {
            billingMap = getFieldMappings(billingFieldMap, billModel.fieldMappings, tempMap.keySet());
        }

        for (String key : billingMap.keySet()) {
            if (!tempMap.containsKey(billingMap.get(key))) {
                tempMap.put(billingMap.get(key), billModel.fieldMappings.get(key));
            }
        }
        Billing__c result = (Billing__c)JSON.deserialize(JSON.serialize(tempMap), Billing__c.class);
        return result;
    }

    @TestVisible
    private static List<Billing_Line__c> getBillingLinesFromModel (List<BillingLineModel> billLineModel, Billing__c billing) {
        List<Billing_Line__c> result = new List<Billing_Line__c>();
        Set<String> currentFieldMappingsKeys = new Set<String>();

        for (BillingLineModel blm : billLineModel) {
            SObject tempSObject = getBillingLines(blm, billing.Id);
            Map<String, Object> tempMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(tempSObject));
            if (!blm.fieldMappings.isEmpty()) {
                if (currentFieldMappingsKeys != blm.fieldMappings.keySet()) {
                    billingLineMap = getFieldMappings(billingLineFieldMap, blm.fieldMappings, tempMap.keySet());
                    currentFieldMappingsKeys = blm.fieldMappings.keySet();
                }
                for (String key : billingLineMap.keySet()) {
                    if (!tempMap.containsKey(billingLineMap.get(key))) {
                        tempMap.put(billingLineMap.get(key), blm.fieldMappings.get(key));
                    }
                }
            }
            result.add((Billing_Line__c)JSON.deserialize(JSON.serialize(tempMap), Billing_Line__c.class));
        }
        return result;
    }

    @TestVisible
    private static Billing__c getBilling (BillingModel bill) {
        Billing__c result = new Billing__c();
        result.Accounting_Period__c = bill.accountingPeriodId;
        result.Billing_Comment__c = bill.billingComment;
        result.Billing_City__c = bill.billingCity;
        result.Billing_Contact__c = bill.billingContactId;
        result.Billing_Country__c = bill.billingCountry;
        result.Billing_Cycle_End_Date__c = bill.billingCycleEndDate;
        result.Billing_Cycle_Start_Date__c = bill.billingCycleStartDate;
        result.Billing_Format__c = bill.billingFormatId;
        result.Billing_PostalCode__c = bill.billingPostalCode;
        result.Billing_State__c = bill.billingState;
        result.Billing_Street__c = bill.billingStreet;
        result.Billing_Terms_Name__c = bill.billingTermsName;
        result.Customer__c = bill.customerId;
        result.Date__c = bill.billingDate;
        result.Due_Date2__c = bill.dueDate;
        result.Discount_Percent__c = bill.discountPercent;
        result.Discount_Due_Date__c = bill.discountDueDate;
        result.Ledger__c = bill.ledgerId;
        result.Opportunity__c = bill.opportunityId;
        result.PO_Number__c = bill.poNumber;
        result.Status__c = bill.status;
        result.Proprietary_Billing_Number__c = bill.proprietaryBillingNumber;
        result.Recurring_Billing__c = bill.recurringBillingId;
        result.Shipping_City__c = bill.shippingCity;
        result.Shipping_Contact__c = bill.shippingContactId;
        result.Shipping_Country__c = bill.shippingCountry;
        result.Shipping_PostalCode__c = bill.shippingPostalCode;
        result.Shipping_State__c = bill.shippingState;
        result.Shipping_Street__c = bill.shippingStreet;


        return result;
    }

    @TestVisible
    private static Billing_Line__c getBillingLines (BillingLineModel blm, Id billingId) {
        Billing_Line__c billLine = new Billing_Line__c();
        billLine.Billing__c = billingId;
        billLine.Date__c = blm.billingLineDate;
        billLine.List_Price__c = blm.listPrice;
        billLine.Revenue_GL_Account__c = blm.revenueGLAccountId;
        billLine.Comment__c = blm.comment;
        billLine.Product__c = blm.productId;
        billLine.Hours_Units__c = blm.quantity;
        billLine.Rate__c = blm.unitPrice;
        billLine.GL_Account_Variable_1__c = blm.glAccountVariable1;
        billLine.GL_Account_Variable_2__c = blm.glAccountVariable2;
        billLine.GL_Account_Variable_3__c = blm.glAccountVariable3;
        billLine.GL_Account_Variable_4__c = blm.glAccountVariable4;
        billLine.Employee__c = blm.employeeId;
        billLine.Expense_GL_Account__c = blm.expenseGLAccountId;
        billLine.Inventory_GL_Account__c = blm.inventoryGLAccountId;
        billLine.Opportunity_Product_Id__c = blm.opportunityProductId;
        billLine.Product_Unit_Cost__c = blm.productUnitCost;
        billLine.Project__c = blm.projectId;
        billLine.Project_Task__c = blm.projectTaskId;
        billLine.Recurring_Billing_Line__c = blm.recurringBillingLineId;
        billLine.Tax_Line__c = blm.taxLine != NULL ? blm.taxLine : false;
        billLine.Time_Card_Variable_1__c = blm.timeCardVariable1;
        billLine.Time_Card_Variable_2__c = blm.timeCardVariable2;

        return billLine;
    }

    //================ Avalara methods=================================

    private static Map<String, Billing_Line__c> billingLineMappedByRecUUId;
    private static Decimal ccr;

    private static List<Billing_Line__c> calcAvalaraTaxes(Billing__c billing, List<Billing_Line__c> lines) {
        List<Billing_Line__c> result = lines;
        Boolean isTaxableByCurrency =
            MultiCurrencyHandler.isMultiCurrencyEnabled
                ? LedgerHandler.isUSDLedger(billing.Ledger__c)
                : true;

        if (isTaxableByCurrency && taxableLineExists(billing, lines)) {
            billingLineMappedByRecUUId = new Map<String, Billing_Line__c>();
            try {
                ccr = populateCurrencyConversionRate(billing);
            }
            catch (Exception ex) {
                throw ex;
            }

            AvaTaxService.CreateTransactionModel request = getCreateTransactionModel(billing, lines);
            AvaTaxHelper.sourceRecord = billing;
            AvaTaxService.TransactionModel response = AvaTaxHelper.calcTax(request);

            if (AccountingSettingsHandler.isHeaderLevelPost()) {
                result = updateTaxAmount(response);
            }
            else {
                result = upsertSalesTaxLine(response, lines, billing);
            }
        }
        return result;
    }

    private static Boolean taxableLineExists(Billing__c billing, List<Billing_Line__c> lines) {
        for (Billing_Line__c billLine : lines) {
            if (AvaTaxHelper.validateBillingLineIsTaxable(billLine, billing)) {
                return true;
            }
        }
        return false;
    }

    private static Decimal populateCurrencyConversionRate(Billing__c bill) {
        Decimal result = 1;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(
                NULL,
                new List<Billing__c>{bill},
                'Date__c'
            );
            result = bill.Currency_Conversion_Rate__c;
        }
        return result;
    }

    private static List<Billing_Line__c> upsertSalesTaxLine(AvaTaxService.TransactionModel avaTaxTransaction, List<Billing_Line__c> lines, Billing__c billing) {
        Billing_Line__c newSalesTaxLine = new Billing_Line__c();
        newSalesTaxLine.Date__c = avaTaxTransaction.avaTaxDate;
        newSalesTaxLine.Revenue_GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(billing);
        newSalesTaxLine.Product__c = AvaTaxHelper.getSalesTaxProductId(billing);
        newSalesTaxLine.Hours_Units__c = 1;
        newSalesTaxLine.Rate__c = avaTaxTransaction.totalTax * ccr;
        newSalesTaxLine.List_Price__c = 0;
        lines.add(newSalesTaxLine);
        return lines;
    }

    private static List<Billing_Line__c> updateTaxAmount(AvaTaxService.TransactionModel avaTaxTransaction) {
        AvaTaxHelper.populateTaxAmountOnVirtualLines(avaTaxTransaction, billingLineMappedByRecUUId, ccr);
        return billingLineMappedByRecUUId.values();
    }

    private static AvaTaxService.CreateTransactionModel getCreateTransactionModel(Billing__c billing, List<Billing_Line__c> lines) {
        List<Account> customer = DomainUtils.getAccountsById(new Set<Id> {billing.Customer__c});
        AvaTaxService.CreateTransactionModel result = new AvaTaxService.CreateTransactionModel();
        result.companyCode = AvaTaxHelper.getCompanyCode(billing);
        result.type = AvaTaxService.DocumentType.SalesOrder;
        result.avaTaxDate = billing.Date__c;
        result.customerCode = billing.Customer__c;
        result.businessIdentificationNo = customer[0].VAT_Business_Identification_Number__c;
        result.entityUseCode = customer[0].Entity_Use_Code__c;
        result.exemptionNo = customer[0].Exemption_Number__c;
        result.addresses = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(customer[0], billing), AvaTaxHelper.getDestinationAddressInfo(customer[0]), billing);
        result.currencyCode = 'USD';//currently we support only USD
        result.lines = getLines(billing, lines);
        result.doCommit = false;
        return result;
    }

    private static List<AvaTaxService.LineItemModel> getLines(Billing__c billing, List<Billing_Line__c> lines) {
        Map<Id, Product2> productMap = getProductMapByLines(lines);
        List<AvaTaxService.LineItemModel> result = new List<AvaTaxService.LineItemModel>();
        for (Billing_Line__c billLine : lines) {
            //map all Billing Lines by source Recurring Billing Line b/c they do not have ID yet
            String uniqKey = FinancialSuiteUtils.getUUID();
            billingLineMappedByRecUUId.put(uniqKey, billLine);
            //include only Taxable Line into request data
            if (AvaTaxHelper.validateBillingLineIsTaxable(billLine, billing)) {
                AvaTaxService.LineItemModel tempLine = new AvaTaxService.LineItemModel();
                tempLine.avaTaxNumber = uniqKey;
                tempLine.amount = (billLine.Hours_Units__c * billLine.Rate__c) / ccr;
                tempLine.quantity = Math.abs(billLine.Hours_Units__c);
                AvaTaxHelper.putItemCodeOnLine(tempLine, productMap.get(billLine.Product__c));
                tempLine.description = productMap.get(billLine.Product__c).Description;
                result.add(tempLine);
            }
        }
        return result;
    }

    private static Map<Id, Product2> getProductMapByLines(List<Billing_Line__c> lines) {
        Set<Id> prodIds = new Set<Id>();
        for (Billing_Line__c line : lines) {
            if (line.Product__c != NULL) {
                prodIds.add(line.Product__c);
            }
        }
        return new Map<Id, Product2> (DomainUtils.getProductsById(prodIds));
    }

}