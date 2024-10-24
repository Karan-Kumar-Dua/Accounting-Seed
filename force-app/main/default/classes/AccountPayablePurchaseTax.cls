public with sharing class AccountPayablePurchaseTax extends AbstractTaxTableHelper {

    @TestVisible
    private static final String POSTED_RECORD_ERROR_MESSAGE = Label.ERR_TAXES_POSTED_RECORD;
    @TestVisible
    private static final String APPLIED_RECORD_ERROR_MESSAGE = Label.ERR_AVATAX_CANNOT_APPLIED_CALCULATED;
    @TestVisible
    private static final String NO_TAXABLE_PRODUCTS_MESSAGE = Label.ERR_NO_TAXABLE_PRODUCTS_PAYABLE;
    @TestVisible
    private static final String NO_PAYABLE_LINE_WITH_PRODUCT_MESSAGE = Label.ERR_NO_PAYABLE_LINE_WITH_PRODUCT;
    @TestVisible
    private static final String NO_AVAILABLE_TAXES = Label.ERR_NO_AVAILABLE_TAX_RECORD;
    @TestVisible
    private static final List<String> APPLICABLE_TYPES_OF_TAXES = new List<String>{
        'Purchase',
        'Sales & Purchase'
    };
    private static final String LINES_CREATED_MESSAGE = Label.INF_TAX_LINES_CREATED;


    private final ApexPages.StandardController stdController;

    private List<Account_Payable_Line__c> existedPayableLines;
    private List<Account_Payable_Line__c> taxableProductPayableLines;
    private List<Account_Payable_Line__c> payableLinesToDelete;
    private List<Account_Payable_Line__c> payableLinesToInsert;
    private List<Account_Tax__c> taxes;
    @TestVisible
    private Account_Payable__c thePayable;
    private List<Account_Payable__c> thePayables;
    private Id vendorId;
    private List<Decimal> dobTotal;

    public Boolean isTaxableProductsExisted {get; set;}
    public Boolean isValidationPassed {get; set;}
    public Boolean isMultiCurrencyEnabled {get; set;}
    public String currencyIsoCode {get; private set;}

    //Constructor
    public AccountPayablePurchaseTax(ApexPages.StandardController controller) {
        this.stdController = controller;
        this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    }

    public AccountPayablePurchaseTax(List<Account_Payable__c> payables) {
        this.thePayables = payables;
        this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    }

    private List<Account_Payable__c> queryAccountPayables(Set<Id> acctPayableIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Vendor__c',
            'Vendor__r.Name',
            'Status__c',
            'Ledger__c',
            'AP_Disbursement_Count__c',
            'Credit_Memo_Applied_Amount__c',
            'Line_Count__c'
        };
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        //set query condition
        String queryCondition = 'Id IN :acctPayableIds';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Account_Payable__c>) Database.query(theQuery.toSOQL());
    }

    private List<Account_Payable_Line__c> queryAccountPayableLines(Set<Id> acctPayableIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Product__c',
            'Amount__c',
            'Sub_Total__c',
            'Product__r.Name',
            'Product__r.Accounting_Type__c',
            'Account_Payable__r.Vendor__c'
        };
        //set query condition
        String queryCondition = 'Product__c != NULL AND Account_Payable__c IN :acctPayableIds';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Account_Payable_Line__c>) Database.query(theQuery.toSOQL());
    }

    private List<Account_Tax__c> queryAccountTaxes(Set<Id> vendorIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Account__c',
            'Tax_Rate__c',
            'Tax_Type__c',
            'Tax_Rate__r.Name',
            'Tax_Rate__r.Tax_Rate__c',
            'Tax_Rate__r.Expense_GL_Account__c'
        };
        //set query condition
        String queryCondition = 'Account__c IN :vendorIds AND Tax_Type__c IN :APPLICABLE_TYPES_OF_TAXES';

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
            Savepoint sp = Database.setSavepoint();
            TaxServiceResult taxCalcResult;
            try {
                AbstractTaxService service = (AbstractTaxService) new NativeTaxLineLevel();
                taxCalcResult = service.calcTaxes(new List<Account_Payable__c> {thePayable});
            }
            catch (Exception e) {
                Database.rollback(sp);
                ApexPages.addMessages(e);
                return NULL;
            }

            if (taxCalcResult.isSuccess) {
                PageReference page = new PageReference('/' + thePayable.Id);
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
            payableLinesToInsert = new List<Account_Payable_Line__c>();
            payableLinesToDelete = new List<Account_Payable_Line__c>();
            Map<Id, List<Decimal>> payableIdToTotals = new Map<Id, List<Decimal>>();
            Map<Id, List<Account_Tax__c>> payableIdToVendorTaxes = new Map<Id, List<Account_Tax__c>>();
            Set<Id> acctPayableIds = new Map<Id, Account_Payable__c>(thePayables).keySet();
            thePayables = queryAccountPayables(acctPayableIds);
            Map<Id, Account_Payable__c> payableMap = new Map<Id, Account_Payable__c>(thePayables);
            List<Account_Payable_Line__c> payableLines = queryAccountPayableLines(acctPayableIds);
            Map<Id, List<Account_Payable_Line__c>> masterToDetails = new Map<Id, List<Account_Payable_Line__c>>();

            for (Account_Payable_Line__c eachLine : payableLines) {
                if (masterToDetails.containsKey(eachLine.Account_Payable__c)) {
                    masterToDetails.get(eachLine.Account_Payable__c).add(eachLine);
                }
                else {
                    masterToDetails.put(eachLine.Account_Payable__c, new List<Account_Payable_Line__c>{eachLine});
                }
            }

            //Check for NO LINES
            for (Account_Payable__c eachPayable : payableMap.values()) {
                if (!masterToDetails.containsKey(eachPayable.Id)) {
                    dispatcher.addPostErrorResult(
                        eachPayable,
                        new PostResult.PostErrorResult(
                            eachPayable,
                            PostResult.StatusCode.TAX_NO_PRODUCT_LINES,
                            NO_PAYABLE_LINE_WITH_PRODUCT_MESSAGE
                        )
                    );
                }
            }

            for (Id eachPayableId : masterToDetails.keySet()) {
                for (Account_Payable_Line__c eachLine : masterToDetails.get(eachPayableId)) {
                    if (eachLine.Product__r.Accounting_Type__c == 'Tax Rate') {
                        payableLinesToDelete.add(eachLine);
                    }
                    else if (eachLine.Product__r.Accounting_Type__c == 'Taxable Product') {
                        if (payableIdToTotals.containsKey(eachPayableId)) {
                            payableIdToTotals.get(eachPayableId).add(eachLine.Amount__c);
                        }
                        else {
                            payableIdToTotals.put(eachPayableId, new List<Decimal>{eachLine.Amount__c});
                        }
                    }
                }
                //Check for TAXABLE PRODUCT
                if (payableIdToTotals.get(eachPayableId) == NULL) {//no Totals - no taxable lines
                    dispatcher.addPostErrorResult(
                        payableMap.get(eachPayableId),
                        new PostResult.PostErrorResult(
                            payableMap.get(eachPayableId),
                            PostResult.StatusCode.TAX_NO_TAXABLE_PRODUCT,
                            NO_TAXABLE_PRODUCTS_MESSAGE
                        )
                    );
                }
            }
            Set<Id> vendorIds = new Set<Id>();
            for (Id eachPayableId : masterToDetails.keySet()) {
                //no lines - no need to calc taxes
                if (masterToDetails.get(eachPayableId) != NULL && !masterToDetails.get(eachPayableId).isEmpty()) {
                    vendorIds.add(payableMap.get(eachPayableId).Vendor__c);
                }
            }
            Map<Id, List<Account_Tax__c>> vendorIdToTaxes = new Map<Id, List<Account_Tax__c>>();
            for (Account_Tax__c tax : queryAccountTaxes(vendorIds)) {
                if (vendorIdToTaxes.containsKey(tax.Account__c)) {
                    vendorIdToTaxes.get(tax.Account__c).add(tax);
                }
                else {
                    vendorIdToTaxes.put(tax.Account__c, new List<Account_Tax__c>{tax});
                }
            }
            for (Id eachPayableId : masterToDetails.keySet()) {
                //no lines - no need to calc taxes
                if (masterToDetails.get(eachPayableId) != NULL && !masterToDetails.get(eachPayableId).isEmpty()) {
                    payableIdToVendorTaxes.put(
                        eachPayableId,
                        vendorIdToTaxes.get(
                            payableMap.get(eachPayableId).Vendor__c
                        )
                    );
                }
            }
            //Check for TAXES
            for (Id eachPayableId : masterToDetails.keySet()) {
                if (payableIdToVendorTaxes.get(eachPayableId) == NULL) {
                    dispatcher.addPostErrorResult(
                        payableMap.get(eachPayableId),
                        new PostResult.PostErrorResult(
                            payableMap.get(eachPayableId),
                            PostResult.StatusCode.TAX_NO_TAXES_ON_ACCOUNT,
                            String.format(
                                NO_AVAILABLE_TAXES,
                                new List<String>{
                                    payableMap.get(eachPayableId).Vendor__r.Name,
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
            if (!payableLinesToDelete.isEmpty()) {
                SFDCSecurityUtils.deleteCheckCRUDAndFLS(payableLinesToDelete);
            }
            //2. Create new tax lines for each Payables
            for (Account_Payable__c payable : payableMap.values()) {
                if (masterToDetails.get(payable.Id) != NULL //if lines exist
                        && payableIdToTotals.get(payable.Id) != NULL //if taxable lines exist
                        && payableIdToVendorTaxes.get(payable.Id) != NULL) {//if taxes exist

                    for (Account_Tax__c eachTax : payableIdToVendorTaxes.get(payable.Id)) {
                        if (eachTax.Tax_Rate__r.Expense_GL_Account__c != NULL) {
                            Decimal total = 0.00;
                            for (Decimal dob : payableIdToTotals.get(payable.Id)) {
                                total += ((eachTax.Tax_Rate__r.Tax_Rate__c / 100) * dob);
                            }
                            total = total.setScale(2, System.RoundingMode.HALF_UP);

                            Account_Payable_Line__c tempTaxLine = new Account_Payable_Line__c();
                            tempTaxLine.Account_Payable__c = payable.Id;
                            tempTaxLine.Quantity__c = 1;
                            tempTaxLine.Amount__c = total;
                            tempTaxLine.Product__c = eachTax.Tax_Rate__c;
                            tempTaxLine.Expense_GL_Account__c = eachTax.Tax_Rate__r.Expense_GL_Account__c;

                            payableLinesToInsert.add(tempTaxLine);
                        }
                    }
                }
            }
            if (!payableLinesToInsert.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(payableLinesToInsert, new List<String>{
                    'Quantity__c',
                    'Amount__c',
                    'Product__c',
                    'Expense_GL_Account__c'
                });
            }
        }
        catch (Exception ex) {
            for (Account_Payable__c eachPayable : thePayables) {
                dispatcher.addPostErrorResult(
                    eachPayable,
                    new PostResult.PostErrorResult(
                        eachPayable,
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
        payableLinesToInsert = new List<Account_Payable_Line__c>();
        payableLinesToDelete = new List<Account_Payable_Line__c>();
        taxableProductPayableLines = new List<Account_Payable_Line__c>();


        try {
            if (AccountingSettingsHandler.isHeaderLevelPost()) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.INFO, HeaderLevelTaxConsts.NO_SUPPORT_INFO_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            // Get Payable Record details
            thePayable = queryAccountPayables(new Set<Id>{stdController.getId()})[0];
            if (thePayable.Line_Count__c > (ldvCalcTaxLineLimit + 2) && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(Label.ERR_LDV_CALC_TAX_LIMIT, new List<String>{SObjectType.Account_Payable__c.getLabel(),  String.valueOf(ldvCalcTaxLineLimit)})
                    )
                );
                isValidationPassed = false;
                return NULL;
            }

            if (isMultiCurrencyEnabled) {
                this.currencyIsoCode = (String) thePayable.get('CurrencyIsoCode');
            }
            if (thePayable.Status__c == 'Posted') {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, POSTED_RECORD_ERROR_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            if (SourceDocumentUpdateFieldValidator.hasAppliedRecord(thePayable)) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, APPLIED_RECORD_ERROR_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            // Get Customer Id (Account Id)
            vendorId = thePayable.Vendor__c;
            // Query Existed Billing lines
            existedPayableLines = queryAccountPayableLines(new Set<Id>{stdController.getId()});
            if (existedPayableLines.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.Severity.ERROR, NO_PAYABLE_LINE_WITH_PRODUCT_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }
            else {
                for (Account_Payable_Line__c payableLine : existedPayableLines) {
                    if (payableLine.Product__r.Accounting_Type__c == 'Tax Rate') {
                        payableLinesToDelete.add(payableLine);
                    }
                    else if (payableLine.Product__r.Accounting_Type__c == 'Taxable Product') {
                        isTaxableProductsExisted = true;
                        taxableProductPayableLines.add(payableLine);
                        dobTotal.add(payableLine.Sub_Total__c);
                    }
                }
            }

            if (thePayable.Line_Count__c > (ldvCalcTaxLineLimit + (payableLinesToDelete.isEmpty() ? 0 : 1))
                && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(Label.ERR_LDV_CALC_TAX_LIMIT, new List<String>{SObjectType.Account_Payable__c.getLabel(),  String.valueOf(ldvCalcTaxLineLimit)})
                    )
                );
                isValidationPassed = false;
                return NULL;
            }

            if (!isTaxableProductsExisted) {
                ApexPages.addMessage(
                    new ApexPages.Message(ApexPages.SEVERITY.INFO, NO_TAXABLE_PRODUCTS_MESSAGE)
                );
                isValidationPassed = false;
                return NULL;
            }

            // Query Available Account Taxes
            taxes = queryAccountTaxes(new Set<Id>{vendorId});
            if (taxes.isEmpty()) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        String.format(
                            NO_AVAILABLE_TAXES,
                            new List<String>{
                                thePayable.Vendor__r.Name,
                                APPLICABLE_TYPES_OF_TAXES[0],
                                APPLICABLE_TYPES_OF_TAXES[1]
                            }
                        )
                    )
                );
                isValidationPassed = false;
                return NULL;
            }

            //Validate each Taxes' Expense GL Account
            String taxesErrorMessage = getTaxesErrorMessage();
            if (!String.isBlank(taxesErrorMessage)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, taxesErrorMessage));
                isValidationPassed = false;
                return NULL;
            }

            //if all validations were passed
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, AccountPayablePurchaseTax.LINES_CREATED_MESSAGE));
            getTableData(taxes, taxableProductPayableLines);
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
            String taxProductMissing = String.format(Label.ERR_TAX_PRODUCT_MISSING_EXPENSE_GL_ACCOUNT, new List<Object>{ tax.Tax_Rate__r.Name });
            if (tax.Tax_Rate__r.Expense_GL_Account__c == NULL) {
                messages.add(taxProductMissing);
            }
        }
        return String.join(messages, '</br>');
    }

}