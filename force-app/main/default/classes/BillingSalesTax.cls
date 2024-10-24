public with sharing class BillingSalesTax extends AbstractTaxTableHelper {

    @TestVisible
    private static final String POSTED_RECORD_ERROR_MESSAGE = Label.ERR_TAXES_POSTED_RECORD;
    @TestVisible
    private static final String APPLIED_RECORD_ERROR_MESSAGE = Label.ERR_AVATAX_CANNOT_APPLIED_CALCULATED;
    @TestVisible
    private static final String NO_TAXABLE_PRODUCTS_MESSAGE = Label.ERR_NO_TAXABLE_PRODUCTS_BILLING_LINE;
    @TestVisible
    private static final String NO_BILLING_LINE_WITH_PRODUCT_MESSAGE = Label.ERR_NO_BILLING_LINE_WITH_PRODUCT;
    @TestVisible
    private static final String NO_AVAILABLE_TAXES = Label.ERR_NO_AVAILABLE_TAX_RECORD;
    @TestVisible
    private static final List<String> APPLICABLE_TYPES_OF_TAXES = new List<String>{
        'Sales',
        'Sales & Purchase'
    };
    private static final String LINES_CREATED_MESSAGE = Label.INF_TAX_LINES_CREATED;

    private final ApexPages.StandardController stdController;

    private List<Billing_Line__c> existedBillingLines;
    private List<Billing_Line__c> taxableProductBillingLines;
    private List<Billing_Line__c> billingLinesToDelete;
    private List<Billing_Line__c> billingLinesToInsert;
    private List<Account_Tax__c> taxes;
    @TestVisible
    private Billing__c theBilling;
    private List<Billing__c> theBillings;
    private Id customerId;
    private List<Decimal> dobTotal;
    private Boolean isUIContext;

    public Boolean isTaxableProductsExisted {get; set;}
    public Boolean isValidationPassed {get; set;}
    public Boolean isMultiCurrencyEnabled {get; set;}
    public String currencyIsoCode {get; private set;}

    //Constructor
    public BillingSalesTax(ApexPages.StandardController controller) {
        this.stdController = controller;
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        this.isUIContext = true;
    }

    public BillingSalesTax(List<Billing__c> billings) {
        this.theBillings = billings;
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    }

    private List<Billing__c> queryBillings(Set<Id> billingIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Customer__c',
            'Customer__r.Name',
            'Status__c',
            'Ledger__c',
            'Billing_Cash_Receipt_Count__c',
            'Credit_Memo_Applied_Amount__c',
            'Line_Count__c'
        };
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        //set query condition
        String queryCondition = 'Id IN :billingIds';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    private List<Billing_Line__c> queryBillingLines(Set<Id> billingIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Product__c',
            'Total__c',
            'Sub_Total__c',
            'Product__r.Accounting_Type__c',
            'Product__r.Name',
            'Billing__r.Customer__c'
        };
        //set query condition
        String queryCondition = 'Product__c != NULL AND Billing__c IN :billingIds';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing_Line__c>) Database.query(theQuery.toSOQL());
    }

    private List<Account_Tax__c> queryAccountTaxes(Set<Id> customerIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Account__c',
            'Tax_Rate__c',
            'Tax_Type__c',
            'Tax_Rate__r.Name',
            'Tax_Rate__r.Tax_Rate__c',
            'Tax_Rate__r.Revenue_GL_Account__c'
        };
        //set query condition
        String queryCondition = 'Account__c IN :customerIds AND Tax_Type__c IN :APPLICABLE_TYPES_OF_TAXES';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Tax__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Account_Tax__c>) Database.query(theQuery.toSOQL());
    }

    public PageReference save() {
        if (isValidationPassed) {
            List<TaxServiceResult> taxCalcResult;
            Savepoint sp = Database.setSavepoint();
            try {
                taxCalcResult = TaxService.calcTaxes(new List<Billing__c> {theBilling});
            }
            catch (Exception e) {
                Database.rollback(sp);
                isValidationPassed = false;
                ApexPages.addMessages(e);
                return NULL;
            }

            if (taxCalcResult[0].isSuccess) {
                PageReference page = new PageReference('/' + theBilling.Id);
                return page;
            }
        }

        return NULL;
    }

    /*
    * This method is used as a part of Calc Tax & Post functionality
    * It is common for single record and multiple records processing
    * Any validation errors appeared will be wrapped using PostResult class
    * and put in the dispatcher instance.
    * Any caller method must handle these results on its level.
    * */
    public void batchCalcTaxes(PostResultDispatcher dispatcher) {
        try {
            billingLinesToInsert = new List<Billing_Line__c>();
            billingLinesToDelete = new List<Billing_Line__c>();
            Map<Id, List<Decimal>> billingIdToTotals = new Map<Id, List<Decimal>>();
            Map<Id, List<Account_Tax__c>> billingIdToCustomerTaxes = new Map<Id, List<Account_Tax__c>>();
            Set<Id> billingIds = new Map<Id, Billing__c>(theBillings).keySet();
            theBillings = queryBillings(billingIds);
            Map<Id, Billing__c> billingMap = new Map<Id, Billing__c>(theBillings);
            List<Billing_Line__c> billingLines = queryBillingLines(billingIds);
            Map<Id, List<Billing_Line__c>> masterToDetails = new Map<Id, List<Billing_Line__c>>();

            for (Billing_Line__c eachLine : billingLines) {
                if (masterToDetails.containsKey(eachLine.Billing__c)) {
                    masterToDetails.get(eachLine.Billing__c).add(eachLine);
                }
                else {
                    masterToDetails.put(eachLine.Billing__c, new List<Billing_Line__c>{eachLine});
                }
            }

            //Check for NO LINES
            for (Billing__c eachBilling : billingMap.values()) {
                if (!masterToDetails.containsKey(eachBilling.Id)) {
                    dispatcher.addPostErrorResult(
                        eachBilling,
                        new PostResult.PostErrorResult(
                            eachBilling,
                            PostResult.StatusCode.TAX_NO_PRODUCT_LINES,
                            NO_BILLING_LINE_WITH_PRODUCT_MESSAGE
                        )
                    );
                }
            }

            for (Id eachBillingId : masterToDetails.keySet()) {
                for (Billing_Line__c eachLine : masterToDetails.get(eachBillingId)) {
                    if (eachLine.Product__r.Accounting_Type__c == 'Tax Rate') {
                        billingLinesToDelete.add(eachLine);
                    }
                    else if (eachLine.Product__r.Accounting_Type__c == 'Taxable Product') {
                        if (billingIdToTotals.containsKey(eachBillingId)) {
                            billingIdToTotals.get(eachBillingId).add(eachLine.Total__c);
                        }
                        else {
                            billingIdToTotals.put(eachBillingId, new List<Decimal>{eachLine.Total__c});
                        }
                    }
                }
                //Check for TAXABLE PRODUCT
                if (billingIdToTotals.get(eachBillingId) == NULL) {//no Totals - no taxable lines
                    dispatcher.addPostErrorResult(
                        billingMap.get(eachBillingId),
                        new PostResult.PostErrorResult(
                            billingMap.get(eachBillingId),
                            PostResult.StatusCode.TAX_NO_TAXABLE_PRODUCT,
                            NO_TAXABLE_PRODUCTS_MESSAGE
                        )
                    );
                }
            }
            Set<Id> customerIds = new Set<Id>();
            for (Id eachBillingId : masterToDetails.keySet()) {
                //no lines - no need to calc taxes
                if (masterToDetails.get(eachBillingId) != NULL && !masterToDetails.get(eachBillingId).isEmpty()) {
                    customerIds.add(billingMap.get(eachBillingId).Customer__c);
                }
            }
            Map<Id, List<Account_Tax__c>> customerIdToTaxes = new Map<Id, List<Account_Tax__c>>();
            for (Account_Tax__c tax : queryAccountTaxes(customerIds)) {
                if (customerIdToTaxes.containsKey(tax.Account__c)) {
                    customerIdToTaxes.get(tax.Account__c).add(tax);
                }
                else {
                    customerIdToTaxes.put(tax.Account__c, new List<Account_Tax__c>{tax});
                }
            }
            for (Id eachBillingId : masterToDetails.keySet()) {
                //no lines - no need to calc taxes
                if (masterToDetails.get(eachBillingId) != NULL && !masterToDetails.get(eachBillingId).isEmpty()) {
                    billingIdToCustomerTaxes.put(
                        eachBillingId,
                        customerIdToTaxes.get(
                            billingMap.get(eachBillingId).Customer__c
                        )
                    );
                }
            }
            //Check for TAXES
            for (Id eachBillingId : masterToDetails.keySet()) {
                if (billingIdToCustomerTaxes.get(eachBillingId) == NULL) {
                    dispatcher.addPostErrorResult(
                        billingMap.get(eachBillingId),
                        new PostResult.PostErrorResult(
                            billingMap.get(eachBillingId),
                            PostResult.StatusCode.TAX_NO_TAXES_ON_ACCOUNT,
                            String.format(
                                NO_AVAILABLE_TAXES,
                                new List<String>{
                                    billingMap.get(eachBillingId).Customer__r.Name,
                                    APPLICABLE_TYPES_OF_TAXES[0],
                                    APPLICABLE_TYPES_OF_TAXES[1]
                                }
                            )
                        )
                    );
                }
            }
            //all data is prepared - time to create tax lines
            //1. Delete old tax lines
            if (!billingLinesToDelete.isEmpty()) {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(billingLinesToDelete);
            }
            //2. Create new tax lines for each Payables
            for (Billing__c billing : billingMap.values()) {
                if (masterToDetails.get(billing.Id) != NULL //if lines exist
                        && billingIdToTotals.get(billing.Id) != NULL //if taxable lines exist
                        && billingIdToCustomerTaxes.get(billing.Id) != NULL) {//if taxes exist

                    for (Account_Tax__c eachTax : billingIdToCustomerTaxes.get(billing.Id)) {
                        if (eachTax.Tax_Rate__r.Revenue_GL_Account__c != NULL) {
                            Decimal total = 0.00;
                            for (Decimal dob : billingIdToTotals.get(billing.Id)) {
                                total += ((eachTax.Tax_Rate__r.Tax_Rate__c / 100) * dob);
                            }
                            total = total.setScale(2, System.RoundingMode.HALF_UP);

                            Billing_Line__c tempTaxLine = new Billing_Line__c();
                            tempTaxLine.Hours_Units__c = 1;
                            tempTaxLine.Billing__c = billing.Id;
                            tempTaxLine.Rate__c = total;
                            tempTaxLine.Product__c = eachTax.Tax_Rate__c;
                            tempTaxLine.Revenue_GL_Account__c = eachTax.Tax_Rate__r.Revenue_GL_Account__c;
                            tempTaxLine.List_Price__c = total;
                            billingLinesToInsert.add(tempTaxLine);
                        }
                    }
                }
            }
            if (!billingLinesToInsert.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(billingLinesToInsert, new List<String>{
                    'Hours_Units__c',
                    'Rate__c',
                    'Product__c',
                    'Revenue_GL_Account__c',
                    'List_Price__c'
                });
            }
        }
        catch (Exception ex) {
            for (Billing__c bill : theBillings) {
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.SYSTEM_EXCEPTION,
                        ex.getMessage()
                    )
                );
            }
        }
    }

    public PageReference init() {

        dobTotal = new List<Decimal>();
        isValidationPassed = true;
        isTaxableProductsExisted = false;
        billingLinesToInsert = new List<Billing_Line__c>();
        billingLinesToDelete = new List<Billing_Line__c>();
        taxableProductBillingLines = new List<Billing_Line__c>();

        try {
            if (AccountingSettingsHandler.isHeaderLevelPost()) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.INFO, HeaderLevelTaxConsts.NO_SUPPORT_INFO_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            // Get Billing Record details
            theBilling = queryBillings(new Set<Id>{stdController.getId()})[0];
            if (theBilling.Line_Count__c > (ldvCalcTaxLineLimit + 2) && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(Label.ERR_LDV_CALC_TAX_LIMIT, new List<String>{SObjectType.Billing__c.getLabel(),  String.valueOf(ldvCalcTaxLineLimit)})
                    )
                );
                isValidationPassed = false;
                return NULL;
            }

            if (AbstractTaxService.isLedgerTaxSettingsEmpty(theBilling)) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, TaxService.getNoTaxSettingErrorMessage(false))
                );
                isValidationPassed = false;
                return NULL;
            }
            if (isMultiCurrencyEnabled) {
                this.currencyIsoCode = (String) theBilling.get('CurrencyIsoCode');
            }
            if (theBilling.Status__c == 'Posted') {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, POSTED_RECORD_ERROR_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            if (SourceDocumentUpdateFieldValidator.hasAppliedRecord(theBilling)) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, APPLIED_RECORD_ERROR_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            // Get Customer Id (Account Id)
            customerId = theBilling.Customer__c;
            // Query Existed Billing lines
            existedBillingLines = queryBillingLines(new Set<Id>{stdController.getId()});
            if (existedBillingLines.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, NO_BILLING_LINE_WITH_PRODUCT_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            else {
                for (Billing_Line__c billLine : existedBillingLines) {
                    if (billLine.Product__r.Accounting_Type__c == 'Tax Rate') {
                        billingLinesToDelete.add(billLine);
                    }
                    else if (billLine.Product__r.Accounting_Type__c == 'Taxable Product') {
                        isTaxableProductsExisted = true;
                        taxableProductBillingLines.add(billLine);
                        dobTotal.add(billLine.Sub_Total__c);
                    }
                }
            }

            if (theBilling.Line_Count__c > (ldvCalcTaxLineLimit + (billingLinesToDelete.isEmpty() ? 0 : 1))
                && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(Label.ERR_LDV_CALC_TAX_LIMIT, new List<String>{SObjectType.Billing__c.getLabel(),  String.valueOf(ldvCalcTaxLineLimit)})
                    )
                );
                isValidationPassed = false;
                return NULL;
            }

            if (!isTaxableProductsExisted) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.SEVERITY.INFO, BillingSalesTax.NO_TAXABLE_PRODUCTS_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }

            // Query Available Account Taxes
            taxes = queryAccountTaxes(new Set<Id>{customerId});
            if (taxes.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(
                            NO_AVAILABLE_TAXES,
                            new List<String>{
                                theBilling.Customer__r.Name,
                                APPLICABLE_TYPES_OF_TAXES[0],
                                APPLICABLE_TYPES_OF_TAXES[1]
                            }
                        )
                    )
                );
                isValidationPassed = false;
                return NULL;
            }

            //Validate each Taxes' Revenue GL Account
            String taxesErrorMessage = getTaxesErrorMessage();
            if (!String.isBlank(taxesErrorMessage)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, taxesErrorMessage));
                isValidationPassed = false;
                return NULL;
            }

            //if all validations were passed
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, BillingSalesTax.LINES_CREATED_MESSAGE));
            getTableData(taxes, taxableProductBillingLines);
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isValidationPassed = false;
        }
        return NULL;
    }

    private String getTaxesErrorMessage() {
        List<String> messages = new List<String>();
        for (Account_Tax__c tax : taxes) {
            if (tax.Tax_Rate__r.Revenue_GL_Account__c == NULL) {
                String taxProductMissing = String.format(Label.ERR_TAX_PRODUCT_MISSING_REVENUE_GL_ACCOUNT, new List<Object>{tax.Tax_Rate__r.Name});
                messages.add(taxProductMissing);
            }
        }
        return String.join(messages, '</br>');
    }

}