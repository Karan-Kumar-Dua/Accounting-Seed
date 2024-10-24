public with sharing class NativeTaxLineLevel extends AbstractTaxService {
    public static Boolean doCommit = true;
    public static Set<SObjectType> skipCalculation4SObjectTypes = new Set<SObjectType>{
        Recurring_Billing_Line__c.getSObjectType(),
        Recurring_Account_Payable_Line__c.getSObjectType()
    };
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Map<SObjectType, List<String>> APPLICABLE_TYPES_OF_TAXES_BY_TYPES = new Map<SObjectType, List<String>>{
            Account_Payable__c.getSObjectType() => new List<String>{
                    'Purchase',
                    'Sales & Purchase'
            },
            Billing__c.getSObjectType() => new List<String>{
                    'Sales',
                    'Sales & Purchase'
            },
            Opportunity.getSObjectType() => new List<String>{
                    'Sales',
                    'Sales & Purchase'
            }
    };
    public static final String TAX_TYPE_TAX_RATE = 'Tax Rate';
    public static final String TAX_TYPE_TAX_PRODUCT = 'Taxable Product';

    private static Map<SObjectType, SObjectField> totalFieldByObjectTypes = new Map<SObjectType, SObjectField>{
        Billing_Line__c.SObjectType => Billing_Line__c.Total__c,
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Amount__c
    };

    private static Map<SObjectType, SObjectField> accountFieldByObjectTypes = new Map<SObjectType, SObjectField>{
        Billing__c.SObjectType => Billing__c.Customer__c,
        Account_Payable__c.SObjectType => Account_Payable__c.Vendor__c,
        Opportunity.SObjectType => Opportunity.AccountId
    };

    private Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    private List<SObject> linesToInsert;
    private List<SObject> linesToDelete;
    private Map<Id, List<Decimal>> sourceIdToTotals = new Map<Id, List<Decimal>>();
    private Map<Id, List<Account_Tax__c>> sourceIdToAccountTaxes = new Map<Id, List<Account_Tax__c>>();
    private Map<Id, PricebookEntry> pricebookEntriesByProductIds = new Map<Id, PricebookEntry>();
    private Map<String, Map<Id, PricebookEntry>> pricebookEntriesMapByCurrency = new Map<String, Map<Id, PricebookEntry>>();
    private List<String> applicableTypesOfTaxes = new List<String>();

    public override TaxServiceResult calcTaxes(List<SObject> sourceDocs) {
        TaxServiceResult result = new TaxServiceResult();
        if (!sourceDocs.isEmpty()) {
            result.sourceDocs.addAll(processCalcTaxes(sourceDocs).values());
        }
        return result;
    }

    public override TaxServiceResult calcTaxes(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        markTaxLine(sourceDocs);
        return setTaxServiceResult(sourceDocs);
    }

    public override TaxServiceResult validate(List<SObject> sourceDocs, Map<Id, SObject> sourceDocsMap) {
        validateTaxLine(sourceDocs);
        return setTaxServiceResult(sourceDocs);
    }

    //====================controller methods=================================================

    private Map<Id, TaxServiceResult.TaxServiceResultLine> processCalcTaxes(List<SObject> sourceDocs) {
        Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds = setTaxServiceResultMap(sourceDocs);
        this.sources = querySource(sourceDocs);
        this.linesBySourceIds = linesBySourceIds(querySourceLines(sourceDocs));
        this.applicableTypesOfTaxes = this.sources != null && !this.sources.isEmpty() ?
                APPLICABLE_TYPES_OF_TAXES_BY_TYPES.get(this.sources[0].getSObjectType()) : this.applicableTypesOfTaxes;
        resultLinesByIds = doValidation(resultLinesByIds);
        resultLinesByIds = validateProductLines(resultLinesByIds);
        this.sourceIdToTotals = calculateTotals();
        resultLinesByIds = checkForTaxableProduct(resultLinesByIds);
        this.sourceIdToAccountTaxes = getTaxesByAccount();
        resultLinesByIds = checkForTaxes(resultLinesByIds);
        if (!sources.isEmpty() && sources[0].getSObjectType() == Opportunity.SObjectType) {
            getPriceBookEntriesByProductId();
        }
        if (!linesToDelete.isEmpty() && doCommit) {
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(linesToDelete);
        }
        resultLinesByIds = calculateTaxes(resultLinesByIds);
        if (!linesToInsert.isEmpty() && doCommit) {
            SObjectActions.isSkipDefaultGLAccounts = true;
            SFDCSecurityUtils.insertCheckCRUDAndFLS(linesToInsert, getFieldsListBySobject());
            SObjectActions.isSkipDefaultGLAccounts = false;
        }
        return resultLinesByIds;
    }

    private Map<Id, TaxServiceResult.TaxServiceResultLine> setTaxServiceResultMap(List<SObject> sourceDocs) {
        Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds = new Map<Id, TaxServiceResult.TaxServiceResultLine>();
        for (SObject obj : sourceDocs) {
            TaxServiceResult.TaxServiceResultLine line = new TaxServiceResult.TaxServiceResultLine();
            line.isSuccess = false;
            resultLinesByIds.put(obj.Id, line);
        }
        return resultLinesByIds;
    }

    private List<SObject> querySource(List<SObject> sourceDocs) {
        List<SObject> sources = new List<SObject>();
        switch on sourceDocs[0] {
            when Account_Payable__c objRecord {
                sources = queryAccountPayables(new Map<Id, SObject>(sourceDocs).keySet());
            }
            when Billing__c objRecord {
                sources = queryBillings(new Map<Id, SObject>(sourceDocs).keySet());
            }
            when Opportunity objRecord {
                sources = queryOpportunities(new Map<Id, SObject>(sourceDocs).keySet());
            }
        }
        return sources;
    }

    private List<SObject> querySourceLines(List<SObject> sourceDocs) {
        List<SObject> result = new List<SObject>();
        switch on sourceDocs[0] {
            when Account_Payable__c objRecord {
                linesToDelete = new List<Account_Payable_Line__c>();
                result = queryAccountPayableLines(new Map<Id, SObject>(sourceDocs).keySet());
            }
            when Billing__c objRecord {
                linesToDelete = new List<Billing_Line__c>();
                result = queryBillingLines(new Map<Id, SObject>(sourceDocs).keySet());
            }
            when Opportunity objRecord {
                linesToDelete = new List<OpportunityLineItem>();
                result = queryOppLineItems(new Map<Id, SObject>(sourceDocs).keySet());
            }
        }
        return result;
    }

    private Map<Id, TaxServiceResult.TaxServiceResultLine> validateProductLines(Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds) {
        for (SObject eachSource : sources) {
            if (!linesBySourceIds.containsKey(eachSource.Id)) {
                resultLinesByIds.get(eachSource.Id).errors.add(Label.ERR_NO_PRODUCT_TAX_LINE);
            }
        }
        return resultLinesByIds;
    }

    private Map<Id, List<Decimal>> calculateTotals() {
        Map<Id, List<Decimal>> sourceIdToTotals = new Map<Id, List<Decimal>>();
        for (Id eachLineId : linesBySourceIds.keySet()) {
            for (SObject eachLine : linesBySourceIds.get(eachLineId)) {
                if (getProductLine(eachLine) == TAX_TYPE_TAX_RATE) {
                    linesToDelete.add(eachLine);
                }
                else if (getProductLine(eachLine) == TAX_TYPE_TAX_PRODUCT) {
                    List<Decimal> totals = sourceIdToTotals.containsKey(eachLineId) ? sourceIdToTotals.get(eachLineId) : new List<Decimal>();
                    totals.add(getTotal(eachLine));
                    sourceIdToTotals.put(eachLineId, totals);
                }
            }
        }
        return sourceIdToTotals;
    }

    private Map<Id, TaxServiceResult.TaxServiceResultLine> checkForTaxableProduct(Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds) {
        //Check for TAXABLE PRODUCT
        for (Id eachLineId : linesBySourceIds.keySet()) {
            if (sourceIdToTotals.get(eachLineId) == NULL) {//no Totals - no taxable lines
                resultLinesByIds.get(eachLineId).errors.add(Label.ERR_NO_TAXABLE_PRODUCT);
            }
        }
        return resultLinesByIds;
    }

    private Decimal getTotal(SObject line) {
        Decimal result;
        switch on line {
            when OpportunityLineItem objRecord {
                result = (objRecord.UnitPrice * (100 - getDiscount(objRecord)) / 100) * objRecord.Quantity;
            }
            when else {
                result = (Decimal) line.get(totalFieldByObjectTypes.get(line.getSObjectType()));
            }
        }
        return result;
    }

    private Decimal getDiscount(OpportunityLineItem line) {
        Decimal discountValue = 0;
        if (line.getPopulatedFieldsAsMap().get('Discount') != NULL) {
            discountValue = line.Discount;
        }
        return discountValue;
    }

    private String getProductLine(SObject line) {
        String result;
        switch on line {
            when OpportunityLineItem objRecord {
                result = objRecord.PriceBookEntry.Product2.Accounting_Type__c;
            }
            when else {
                result = (String) line.getSObject('Product__r').get(PACKAGE_QUALIFIER + 'Accounting_Type__c');
            }
        }
        return result;
    }

    private Map<Id, List<Account_Tax__c>> getTaxesByAccount() {
        Map<Id, List<Account_Tax__c>> sourceIdToAccountTaxes = new Map<Id, List<Account_Tax__c>>();
        Set<Id> accountIds = new Set<Id>();
        Map<Id, SObject> sourceMap = new Map<Id, SObject>(sources);
        for (Id eachLineId : linesBySourceIds.keySet()) {
            //no lines - no need to calc taxes
            if (linesBySourceIds.get(eachLineId) != null && !linesBySourceIds.get(eachLineId).isEmpty()) {
                accountIds.add((Id) sourceMap.get(eachLineId).get(accountFieldByObjectTypes.get(sourceMap.get(eachLineId).getSObjectType())));
            }
        }
        Map<Id, List<Account_Tax__c>> accountIdToTaxes = new Map<Id, List<Account_Tax__c>>();
        for (Account_Tax__c tax : queryAccountTaxes(accountIds)) {
            List<Account_Tax__c> accountTaxes = accountIdToTaxes.containsKey(tax.Account__c) ? accountIdToTaxes.get(tax.Account__c) : new List<Account_Tax__c>();
            accountTaxes.add(tax);
            accountIdToTaxes.put(tax.Account__c, accountTaxes);
        }
        for (Id eachLineId : linesBySourceIds.keySet()) {
            //no lines - no need to calc taxes
            if (linesBySourceIds.get(eachLineId) != null && !linesBySourceIds.get(eachLineId).isEmpty()) {
                sourceIdToAccountTaxes.put(
                    eachLineId,
                    accountIdToTaxes.get(
                        (Id) sourceMap.get(eachLineId).get(accountFieldByObjectTypes.get(sourceMap.get(eachLineId).getSObjectType()))
                    )
                );
            }
        }
        return sourceIdToAccountTaxes;
    }

    private Map<Id, TaxServiceResult.TaxServiceResultLine> checkForTaxes(Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds) {
        Map<Id, SObject> sourceMap = new Map<Id, SObject>(sources);
        for (Id eachLineId : linesBySourceIds.keySet()) {
            if (sourceIdToAccountTaxes.get(eachLineId) == null) {
                resultLinesByIds.get(eachLineId).errors.add(
                    String.format(
                        Label.ERR_NO_AVAILABLE_TAX_RECORD,
                        new List<String>{
                            getAccountName(sourceMap.get(eachLineId)),
                            applicableTypesOfTaxes[0],
                            applicableTypesOfTaxes[1]
                        }
                    )
                );
            }
        }
        return resultLinesByIds;
    }

    private String getAccountName(SObject obj) {
        String result;
        switch on obj {
            when Opportunity objRecord {
                result = objRecord.Account.Name;
            }
            when Billing__c objRecord {
                result = objRecord.Customer__r.Name;
            }
            when Account_Payable__c objRecord {
                result = objRecord.Vendor__r.Name;
            }
        }
        return result;
    }

    private Map<Id, TaxServiceResult.TaxServiceResultLine> calculateTaxes(Map<Id, TaxServiceResult.TaxServiceResultLine> resultLinesByIds) {
        Set<Id> productIds = new Set<Id>();
        switch on sources[0] {
            when Account_Payable__c objRecord {
                linesToInsert = new List<Account_Payable_Line__c>();
            }
            when Billing__c objRecord {
                linesToInsert = new List<Billing_Line__c>();
            }
            when Opportunity objRecord {
                linesToInsert = new List<OpportunityLineItem>();
            }
        }
        for (SObject obj: sources) {
            if (linesBySourceIds.get(obj.Id) != null //if lines exist
                && sourceIdToTotals.get(obj.Id) != null //if taxable lines exist
                && sourceIdToAccountTaxes.get(obj.Id) != null) {//if taxes exist

                for (Account_Tax__c eachTax : sourceIdToAccountTaxes.get(obj.Id)) {
                    if (obj.getSObjectType() == Account_Payable__c.SObjectType
                        ? eachTax.Tax_Rate__r.Expense_GL_Account__c != null
                        : eachTax.Tax_Rate__r.Revenue_GL_Account__c != null) {
                        Decimal total = 0.00;
                        for (Decimal dob : sourceIdToTotals.get(obj.Id)) {
                            total += ((eachTax.Tax_Rate__r.Tax_Rate__c / 100) * dob);
                        }
                        total = total.setScale(2, System.RoundingMode.HALF_UP);

                        switch on obj {
                            when Account_Payable__c objRecord {
                                Account_Payable_Line__c tempTaxLine = new Account_Payable_Line__c();
                                tempTaxLine.Account_Payable__c = obj.Id;
                                tempTaxLine.Quantity__c = 1;
                                tempTaxLine.Amount__c = total;
                                tempTaxLine.Product__c = eachTax.Tax_Rate__c;
                                tempTaxLine.Expense_GL_Account__c = eachTax.Tax_Rate__r.Expense_GL_Account__c;
                                linesToInsert.add(tempTaxLine);
                            }
                            when Billing__c objRecord {
                                Billing_Line__c tempTaxLine = new Billing_Line__c();
                                tempTaxLine.Hours_Units__c = 1;
                                tempTaxLine.Billing__c = obj.Id;
                                tempTaxLine.Rate__c = total;
                                tempTaxLine.Product__c = eachTax.Tax_Rate__c;
                                tempTaxLine.Revenue_GL_Account__c = eachTax.Tax_Rate__r.Revenue_GL_Account__c;
                                tempTaxLine.List_Price__c = total;
                                linesToInsert.add(tempTaxLine);
                                productIds.add(tempTaxLine.Product__c);
                            }
                            when Opportunity objRecord {
                                Id priceBookId = isMultiCurrencyEnabled
                                    ? pricebookEntriesMapByCurrency.get((String) objRecord.get('CurrencyIsoCode'))?.get(eachTax.Tax_Rate__c)?.Id
                                    : pricebookEntriesByProductIds.get(eachTax.Tax_Rate__c)?.Id;
                                if (String.isBlank(priceBookId)) {
                                    resultLinesByIds.get(obj.Id).errors.add(
                                        String.format(
                                            Label.PRODUCT_HAS_NOT_BEEN_ADDED_TO_THE_PRICE_BOOK,
                                            new List<String>{eachTax.Tax_Rate__r.Name}
                                        )
                                    );
                                }
                                OpportunityLineItem tempTaxLine = new OpportunityLineItem();
                                tempTaxLine.Quantity = 1;
                                tempTaxLine.OpportunityId = obj.Id;
                                tempTaxLine.UnitPrice = total;
                                tempTaxLine.PricebookEntryId = priceBookId;
                                tempTaxLine.Product2Id = eachTax.Tax_Rate__c;
                                linesToInsert.add(tempTaxLine);
                            }
                        }
                    }
                }
                resultLinesByIds.get(obj.Id).sourceObjLines = linesToInsert;
            }
            resultLinesByIds.get(obj.Id).sourceObj = obj;
            resultLinesByIds.get(obj.Id).isSuccess = resultLinesByIds.get(obj.Id).errors.isEmpty();
        }

        if(!productIds.isEmpty()){
            Map<Id, Product2> productMap = new Map<Id, Product2>(DomainUtils.getProductsById(productIds));
            for(Billing_Line__c bL : (List<Billing_Line__c>) linesToInsert){
                Product2 prod = productMap.get(bl.Product__c);
                bL.GL_Account_Variable_1__c = prod.GL_Account_Variable_1__c;
                bL.GL_Account_Variable_2__c = prod.GL_Account_Variable_2__c;
                bL.GL_Account_Variable_3__c = prod.GL_Account_Variable_3__c;
                bL.GL_Account_Variable_4__c = prod.GL_Account_Variable_4__c;
            }
        }
        
        return resultLinesByIds;
    }

    private List<String> getFieldsListBySobject() {
        List<String> result = new List<String>();
        switch on linesToInsert[0] {
            when Account_Payable_Line__c objRecord {
                result = new List<String>{
                    'Quantity__c',
                    'Amount__c',
                    'Product__c',
                    'Expense_GL_Account__c'
                };
            }
            when Billing_Line__c objRecord {
                result = new List<String>{
                    'Hours_Units__c',
                    'Rate__c',
                    'Product__c',
                    'Revenue_GL_Account__c',
                    'List_Price__c',
                    'GL_Account_Variable_1__c',
                    'GL_Account_Variable_2__c',
                    'GL_Account_Variable_3__c',
                    'GL_Account_Variable_4__c'
                };
            }
        }
        return result;
    }

    private void getPriceBookEntriesByProductId() {
        Set<Id> priceBookIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();

        for (SObject sourceObj : sources) {
            List<Account_Tax__c> accountTaxes = sourceIdToAccountTaxes.get(sourceObj.Id);
            if (accountTaxes != null) {
                for (Account_Tax__c eachTax : accountTaxes) {
                    productIds.add(eachTax.Tax_Rate__c);
                }
            }
            priceBookIds.add(((Opportunity) sourceObj).Pricebook2Id);
        }

        List<PricebookEntry> priceBookEntries = DomainUtils.getPricebookEntriesByProductAndPriceBookId(productIds, priceBookIds);

        for (PricebookEntry pbe : priceBookEntries) {
            if (isMultiCurrencyEnabled) {
                if (pricebookEntriesMapByCurrency.containsKey(String.valueOf(pbe.get('CurrencyIsoCode')))) {
                    pricebookEntriesMapByCurrency.get(String.valueOf(pbe.get('CurrencyIsoCode'))).put(pbe.Product2Id, pbe);
                }
                else {
                    pricebookEntriesMapByCurrency.put(String.valueOf(pbe.get('CurrencyIsoCode')), new Map<Id, PricebookEntry> {pbe.Product2Id => pbe});
                }
            }
            else {
                pricebookEntriesByProductIds.put(pbe.Product2Id, pbe);
            }
        }
    }

    //====================trigger methods=================================================

    private void markTaxLine(List<SObject> newLines) {
        if (newLines != null && !newLines.isEmpty() && !skipCalculation4SObjectTypes.contains(newLines[0].getSObjectType())) {
            for (SObject line : newLines) {
                //checkbox on a line should only be modified by our code base
                line.put(PACKAGE_QUALIFIER + 'Tax_Line__c', false);
                if ((line.getSObjectType() == Billing_Line__c.SObjectType || line.getSObjectType() == Account_Payable_Line__c.SObjectType)
                    && line.get(PACKAGE_QUALIFIER + 'Product_Tax_Type__c') == 'Tax Rate') {
                    line.put(PACKAGE_QUALIFIER + 'Tax_Line__c', true);
                }
            }
        }
    }

    private void validateTaxLine(List<SObject> newLines) {
        if (newLines != null && !newLines.isEmpty() && !skipCalculation4SObjectTypes.contains(newLines[0].getSObjectType())) {
            for (SObject line : newLines) {
                if ((line.getSObjectType() == Billing_Line__c.SObjectType || line.getSObjectType() == Account_Payable_Line__c.SObjectType)
                    && line.get(PACKAGE_QUALIFIER + 'Tax_Line__c') == true && line.get(PACKAGE_QUALIFIER + 'Product_Tax_Type__c') != 'Tax Rate') {
                    line.addError(Label.ERR_NOT_VALID_TAX_LINE);
                }
            }
        }
    }

    //========================================================================================

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
            'Credit_Memo_Applied_Amount__c'
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
            'Credit_Memo_Applied_Amount__c'
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

    private List<Opportunity> queryOpportunities(Set<Id> oppIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Amount',
            'AccountId',
            'Account.Name',
            'Pricebook2Id',
            'Tax_Amount__c'

        };
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        //set query condition
        String queryCondition = 'Id IN :oppIds';

        SOQLBuilder theQuery = new SOQLBuilder(Opportunity.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Opportunity>) Database.query(theQuery.toSOQL());
    }

    private List<OpportunityLineItem> queryOppLineItems(Set<Id> oppIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
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
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Project__c',
            'Project_Task__c',
            'Description',
            'Tax_Group__c',
            'Tax_Group__r.Combined_Tax_Rate__c'
        };

        if (DomainUtils.isDiscountIncludedInOpportunityLineItems(oppIds)) {
            queryFields.add('Discount');
        }
        //set query condition
        String queryCondition = 'OpportunityId IN :oppIds';

        SOQLBuilder theQuery = new SOQLBuilder(OpportunityLineItem.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<OpportunityLineItem>) Database.query(theQuery.toSOQL());
    }

    private List<Account_Tax__c> queryAccountTaxes(Set<Id> accountIds) {
        //define fields to query
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Account__c',
            'Tax_Rate__c',
            'Tax_Type__c',
            'Tax_Rate__r.Name',
            'Tax_Rate__r.Tax_Rate__c',
            'Tax_Rate__r.Expense_GL_Account__c',
            'Tax_Rate__r.Revenue_GL_Account__c'
        };
        //set query condition
        String queryCondition = 'Account__c IN :accountIds AND Tax_Type__c IN :applicableTypesOfTaxes';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Tax__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Account_Tax__c>) Database.query(theQuery.toSOQL());
    }
}