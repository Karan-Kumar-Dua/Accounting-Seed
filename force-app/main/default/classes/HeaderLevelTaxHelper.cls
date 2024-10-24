public with sharing class HeaderLevelTaxHelper {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String NO_SUPPORT_INFO_MESSAGE = HeaderLevelTaxConsts.NO_SUPPORT_INFO_MESSAGE;
    public static final String UNIT_COST_REQUIRED_ERROR = HeaderLevelTaxConsts.UNIT_COST_REQUIRED_ERROR;
    public static final String HEADER_LEVEL_POST = HeaderLevelTaxConsts.HEADER_LEVEL_POST;
    public static final String LINE_LEVEL_POST = HeaderLevelTaxConsts.LINE_LEVEL_POST;
    public static final String HEADER_LEVEL_POSTING_SET_ERROR = HeaderLevelTaxConsts.HEADER_LEVEL_POSTING_SET_ERROR;
    public static final List<String> SALES_TAX_RATE_TYPES = HeaderLevelTaxConsts.SALES_TAX_RATE_TYPES;
    public static final List<String> PURCHASE_TAX_RATE_TYPES = HeaderLevelTaxConsts.PURCHASE_TAX_RATE_TYPES;

    public static final String NOT_SALES_TAX_GROUP_ERROR = HeaderLevelTaxConsts.NOT_SALES_TAX_GROUP_ERROR;
    public static final String NOT_PURCHASE_TAX_GROUP_ERROR = HeaderLevelTaxConsts.NOT_PURCHASE_TAX_GROUP_ERROR;
    public static final String TAX_GROUP_WITHOUT_TAX_RATE_ERROR = HeaderLevelTaxConsts.TAX_GROUP_WITHOUT_TAX_RATE_ERROR;

    public static final Map<SObjectType, SObjectField> taxAmountFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Tax_Amount__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Tax_Amount__c,
        Billing_Line__c.SObjectType => Billing_Line__c.Tax_Amount2__c,
        Recurring_Billing_Line__c.SObjectType => Recurring_Billing_Line__c.Tax_Amount__c,
        OpportunityLineItem.SObjectType => OpportunityLineItem.Tax_Amount__c
    };

    public static final Map<SObjectType, SObjectField> taxGroupFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Tax_Group__c,
        Billing_Line__c.SObjectType => Billing_Line__c.Tax_Group__c,
        Recurring_Billing_Line__c.SObjectType => Recurring_Billing_Line__c.Tax_Group__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Tax_Group__c,
        OpportunityLineItem.SObjectType => OpportunityLineItem.Tax_Group__c
    };

    public static Map<SObjectType, SObjectField> quantityFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Quantity__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Quantity__c,
        Billing_Line__c.SObjectType => Billing_Line__c.Hours_Units__c,
        Recurring_Billing_Line__c.SObjectType => Recurring_Billing_Line__c.Quantity__c,
        OpportunityLineItem.SObjectType => OpportunityLineItem.Quantity
    };

    public static Map<SObjectType, SObjectField> unitCostFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Unit_Cost__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Unit_Cost__c,
        Billing_Line__c.SObjectType => Billing_Line__c.Rate__c,
        Recurring_Billing_Line__c.SObjectType => Recurring_Billing_Line__c.Rate__c,
        OpportunityLineItem.SObjectType => OpportunityLineItem.UnitPrice
    };

    public static Map<SObjectType, SObjectField> productFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Product__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Product__c,
        Billing_Line__c.SObjectType => Billing_Line__c.Product__c,
        Recurring_Billing_Line__c.SObjectType => Recurring_Billing_Line__c.Product__c,
        OpportunityLineItem.SObjectType => OpportunityLineItem.Product2Id
    };

    public static Map<SObjectType, SObjectField> taxInclusiveFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Tax_Inclusive__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Tax_Inclusive__c,
        Billing_Line__c.SObjectType => Billing_Line__c.Tax_Inclusive__c,
        Recurring_Billing_Line__c.SObjectType => Recurring_Billing_Line__c.Tax_Inclusive__c,
        OpportunityLineItem.SObjectType => null
    };

    public static Map<SObjectType, SObjectField> combinedTaxRateFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Combined_Tax_Rate__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Combined_Tax_Rate__c,
        Billing_Line__c.SObjectType => Billing_Line__c.Combined_Tax_Rate__c,
        Recurring_Billing_Line__c.SObjectType => Recurring_Billing_Line__c.Combined_Tax_Rate__c,
        OpportunityLineItem.SObjectType => null
    };

    private static Map<SObjectType, List<SObjectField>> masterFieldNames = new Map<SObjectType, List<SObjectField>> {
        Account_Payable_Line__c.SObjectType => new List<SObjectField> {
            Account_Payable_Line__c.Amount__c,
            Account_Payable_Line__c.Tax_Group__c,
            Account_Payable_Line__c.Tax_Amount__c,
            Account_Payable_Line__c.Unit_Cost__c,
            Account_Payable_Line__c.Quantity__c
        },
        Recurring_Account_Payable_Line__c.SObjectType => new List<SObjectField> {
            Recurring_Account_Payable_Line__c.Amount2__c,
            Recurring_Account_Payable_Line__c.Tax_Group__c,
            Recurring_Account_Payable_Line__c.Tax_Amount__c,
            Recurring_Account_Payable_Line__c.Unit_Cost__c,
            Recurring_Account_Payable_Line__c.Quantity__c
        },
        Billing_Line__c.SObjectType => new List<SObjectField> {
            Billing_Line__c.Tax_Group__c,
            Billing_Line__c.Hours_Units__c,
            Billing_Line__c.Rate__c,
            Billing_Line__c.Tax_Amount2__c
        },
        Recurring_Billing_Line__c.SObjectType => new List<SObjectField> {
            Recurring_Billing_Line__c.Tax_Amount__c,
            Recurring_Billing_Line__c.Tax_Group__c,
            Recurring_Billing_Line__c.Rate__c,
            Recurring_Billing_Line__c.Quantity__c
        }
    };

    public class SourceDocumentTaxDecorator {
        private SObject oldObj;
        private SObject newObj;
        private SObjectType sobjectTypeValue;
        private Tax_Group__c taxGroup;
        private SObjectField taxGroupFieldName;
        private SObjectField taxAmountFieldName;
        private SObjectField unitCostFieldName;
        private SObjectField quantityFieldName;
        private SObjectField productFieldName;
        private SObjectField taxInclusiveField;
        private SObjectField combinedTaxRateField;

        public SourceDocumentTaxDecorator(SObject newObj) {
            this.newObj = newObj;
            sobjectTypeValue = newObj.getSObjectType();
            taxGroupFieldName = taxGroupFieldNames.get(sobjectTypeValue);
            taxAmountFieldName = taxAmountFieldNames.get(sobjectTypeValue);
            unitCostFieldName = unitCostFieldNames.get(sobjectTypeValue);
            quantityFieldName = quantityFieldNames.get(sobjectTypeValue);
            productFieldName = productFieldNames.get(sobjectTypeValue);
            taxInclusiveField = taxInclusiveFieldNames.get(sobjectTypeValue);
            combinedTaxRateField = combinedTaxRateFieldNames.get(sobjectTypeValue);
        }

        public SourceDocumentTaxDecorator(SObject oldObj, SObject newObj) {
            this(newObj);
            this.oldObj = oldObj;
        }

        public Decimal getUnitCost() {
            Decimal unitCost = (Decimal)newObj.get(unitCostFieldName);
            if(unitCost != null){
                unitCost = unitCost.setScale(6, RoundingMode.HALF_UP);
            }
            return unitCost;
        }

        public Decimal getQuantity() {
            Decimal Quantity = (Decimal)newObj.get(quantityFieldName);
            if(Quantity != null){
                Quantity = Quantity.setScale(6, RoundingMode.HALF_UP);
            }
            return Quantity;
        }

        public Id getTaxGroupId() {
            return (Id) newObj.get(taxGroupFieldName);
        }

        public Tax_Group__c getAssociatedTaxGroup() {
            return taxGroup;
        }

        public Id getProductId() {
            return (Id) newObj.get(productFieldName);
        }

        public void setQuantity(Decimal quantity) {
            newObj.put(quantityFieldName, quantity);
        }

        public void setTaxAmount(Decimal amount) {
            newObj.put(taxAmountFieldName, amount);
        }

        public void setTaxGroup(Id taxGroupId) {
            newObj.put(taxGroupFieldName, taxGroupId);
        }

        public void setAssociatedTaxGroup(Tax_Group__c taxGroup) {
            this.taxGroup = taxGroup;
            // set reference data
            if (taxInclusiveField != null && newObj.get(taxInclusiveField) != taxGroup?.Tax_Inclusive__c) {
                newObj.put(taxInclusiveField, taxGroup?.Tax_Inclusive__c);
            }
            if (combinedTaxRateField != null && newObj.get(combinedTaxRateField) != taxGroup?.Combined_Tax_Rate__c) {
                newObj.put(combinedTaxRateField, taxGroup?.Combined_Tax_Rate__c);
            }
        }

        public void setTaxAmountZero() {
            newObj.put(taxAmountFieldName, 0);
        }

        public Boolean isUnitCostNull() {
            return getUnitCost() == NULL;
        }

        public Boolean isQuantityNull() {
            return getQuantity() == NULL;
        }

        public Boolean isTaxGroupNull() {
            return getTaxGroupId() == NULL;
        }

        public Boolean isTaxGroupChanged() {
            return isUpdate() && newObj.get(taxGroupFieldName) != oldObj.get(taxGroupFieldName);
        }

        public Boolean isProductNull() {
            return getProductId() == NULL;
        }

        public Boolean isProductChanged() {
            return isUpdate() && newObj.get(productFieldName) != oldObj.get(productFieldName);
        }

        public Boolean isInsert() {
            return oldObj == NULL;
        }

        public Boolean isUpdate() {
            return oldObj != NULL;
        }

        public Boolean isBillingLine() {
            return sobjectTypeValue == Billing_Line__c.SObjectType || sobjectTypeValue == Recurring_Billing_Line__c.SObjectType;
        }

        public Boolean isPayableLine() {
            return sobjectTypeValue == Account_Payable_Line__c.SObjectType || sobjectTypeValue == Recurring_Account_Payable_Line__c.SObjectType;
        }

        public Boolean isOpportunityLineItem() {
            return sobjectTypeValue == OpportunityLineItem.SObjectType;
        }

        private Boolean isNeedCalculateTaxAmount() {
            Boolean result = false;
            if (!isOpportunityLineItem()) {
                if (isUpdate()) {
                    for (SObjectField field : masterFieldNames.get(sobjectTypeValue)) {
                        Integer scale = field.getDescribe().getScale();
                        Schema.DisplayType fieldType = field.getDescribe().getType();

                        if ((fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Double)
                            && (newObj.get(field) != NULL && oldObj.get(field) != NULL)
                            && (((Decimal)newObj.get(field)).setScale(scale, RoundingMode.HALF_UP) != (((Decimal)oldObj.get(field)).setScale(scale, RoundingMode.HALF_UP)))) {
                            result = true;
                        }
                        else if (newObj.get(field) != oldObj.get(field)) {
                            result = true;
                        }
                    }
                } else {
                    result = true;
                }
            }
            return result && !isUnitCostNull();
        }

        private Boolean isNeedSetTaxGroup() {
            Boolean result = false;
            if (isInsert()
                    && isTaxGroupNull()
                    && !isProductNull()) {

                result = true;
            }
            return result;
        }

        private Boolean isNeedValidateTaxGroupType() {
            return !isTaxGroupNull();
        }

        private Boolean isNeedValidateUnitCost() {
            return !isTaxGroupNull() && (isInsert()
                || (isTaxGroupChanged()
                && isTaxGroupNull()));
        }

        public Decimal calculateTaxAmount() {
            Decimal taxAmount = 0;
            if(taxGroup != NULL ){
                if (taxGroup.Tax_Inclusive__c) {
                    // tax is already included in the cost, so we must determine what amount of the total is attributable to tax
                    // in other words, given an amount including tax determine how much is tax
                    Decimal taxRate = taxGroup.Combined_Tax_Rate__c/100;
                    Decimal extCost = (getUnitCost() * getQuantity()).setScale(2, RoundingMode.HALF_UP);
                    taxAmount = extCost - (extCost / (1 + taxRate));
                } else {
                    // tax is not included in the cost, so we must determine the appropriate tax amount to add to the subtotal
                    // in other words, given an amount excluding tax determine how much tax to charge
                    for(Tax_Rate__c taxGroupRate : taxGroup.Tax_Rates__r){
                        Decimal taxRate = taxGroupRate.Tax_Rate__c/100;
                        Decimal extCost = (getUnitCost() * getQuantity()).setScale(2, RoundingMode.HALF_UP);
                        taxAmount += (taxRate * extCost);
                    }
                }
            }
            return taxAmount.setScale(2, RoundingMode.HALF_UP);
        }

        public void calculateAndSetTaxAmount() {
            setTaxAmount(calculateTaxAmount());
        }

        private Boolean isTaxGroupValid(Tax_Group__c taxGroup) {
            Boolean result = true;
            if ((isBillingLine() || isOpportunityLineItem()) && !SALES_TAX_RATE_TYPES.contains(taxGroup.Tax_Type__c) ) {
                result = false;
            }
            else if (isPayableLine() && !PURCHASE_TAX_RATE_TYPES.contains(taxGroup.Tax_Type__c)) {
                result = false;
            }
            return result;
        }

        private void validateTaxGroupType() {

            if (taxGroup != NULL) {
                switch on newObj {
                    when Billing_Line__c bLine {
                        if (!SALES_TAX_RATE_TYPES.contains(taxGroup.Tax_Type__c)) {
                            bLine.Tax_Group__c.addError(
                                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {Label.COMMON_BILLING_LINE})
                            );
                        }
                    }
                    when Recurring_Billing_Line__c recurringBillingLine {
                        if (!SALES_TAX_RATE_TYPES.contains(taxGroup.Tax_Type__c)) {
                            recurringBillingLine.Tax_Group__c.addError(
                                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {Label.COMMON_RECURRING_BILLING_LINE})
                            );
                        }
                    }
                    when Account_Payable_Line__c apLine {
                        if (!PURCHASE_TAX_RATE_TYPES.contains(taxGroup.Tax_Type__c)) {
                            apLine.Tax_Group__c.addError(
                                String.format(HeaderLevelTaxHelper.NOT_PURCHASE_TAX_GROUP_ERROR, new List<String> {Label.COMMON_PAYABLE_LINE})
                            );
                        }
                    }
                    when Recurring_Account_Payable_Line__c recurringPayableLine {
                        if (!PURCHASE_TAX_RATE_TYPES.contains(taxGroup.Tax_Type__c)) {
                            recurringPayableLine.Tax_Group__c.addError(
                                String.format(HeaderLevelTaxHelper.NOT_PURCHASE_TAX_GROUP_ERROR, new List<String> {Label.COMMON_RECURRING_PAYABLE_LINE})
                            );
                        }
                    }
                    when OpportunityLineItem oli {
                        if (!SALES_TAX_RATE_TYPES.contains(taxGroup.Tax_Type__c)) {
                            oli.addError(
                                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {Label.COMMON_OPPORTUNITY_PRODUCT})
                            );
                        }
                    }
                    when else {
                        return;
                    }
                }
            }
        }

        public void validateTaxGroupHasTaxRate() {
            if (taxGroup != NULL && taxGroup.Tax_Rate_Count__c == 0) {
                switch on newObj {
                    when Billing_Line__c bLine {
                        bLine.Tax_Group__c.addError(HeaderLevelTaxHelper.TAX_GROUP_WITHOUT_TAX_RATE_ERROR);
                    }
                    when Recurring_Billing_Line__c recurringBillingLine {
                        recurringBillingLine.Tax_Group__c.addError(HeaderLevelTaxHelper.TAX_GROUP_WITHOUT_TAX_RATE_ERROR);
                    }
                    when Account_Payable_Line__c apLine {
                        apLine.Tax_Group__c.addError(HeaderLevelTaxHelper.TAX_GROUP_WITHOUT_TAX_RATE_ERROR);
                    }
                    when Recurring_Account_Payable_Line__c recurringPayableLine {
                        recurringPayableLine.Tax_Group__c.addError(HeaderLevelTaxHelper.TAX_GROUP_WITHOUT_TAX_RATE_ERROR);
                    }
                    when OpportunityLineItem oli {
                        oli.Tax_Group__c.addError(HeaderLevelTaxHelper.TAX_GROUP_WITHOUT_TAX_RATE_ERROR);
                    }
                    when else {
                        return;
                    }
                }
            }
        }

        private void validateUnitCost() {
            if (isUnitCostNull() && !isTaxGroupNull()) {
                switch on newObj {
                    when Account_Payable_Line__c apLine {
                        apLine.Unit_Cost__c.addError(HeaderLevelTaxHelper.UNIT_COST_REQUIRED_ERROR);
                    }
                    when Recurring_Account_Payable_Line__c apLine {
                        apLine.Unit_Cost__c.addError(HeaderLevelTaxHelper.UNIT_COST_REQUIRED_ERROR);
                    }
                }
            }
        }
    }

    public static void validate(List<SObject> newLines, Map<Id, SObject> oldLines) {
        TaxGroupHandler taxGroupHandler = TaxGroupHandler.getInstance();
        Set<Id> taxGroupIds = new Set<Id>();

        for (SObject newLine : newLines) {
            SObject oldLine = oldLines != NULL ? oldLines.get((Id) newLine.get('Id')) : NULL;
            SourceDocumentTaxDecorator sdt = new SourceDocumentTaxDecorator(oldLine, newLine);
            if (!sdt.isTaxGroupNull()) {
                taxGroupIds.add(sdt.getTaxGroupId());
            }
        }

        if (!taxGroupIds.isEmpty()) {
            taxGroupHandler.setTaxGroupsByTaxGroupIds(taxGroupIds);
        }

        for (SObject newLine : newLines) {
            SObject oldLine = oldLines != NULL ? oldLines.get((Id) newLine.get('Id')) : NULL;
            SourceDocumentTaxDecorator sdt = new SourceDocumentTaxDecorator(oldLine, newLine);

            if (sdt.isNeedValidateUnitCost()) {
                sdt.validateUnitCost();
            }

            if (sdt.isNeedValidateTaxGroupType() && taxGroupHandler.hasTaxGroup(sdt.getTaxGroupId())) {
                Tax_Group__c taxGroup = taxGroupHandler.getTaxGroup(sdt.getTaxGroupId());
                sdt.setAssociatedTaxGroup(taxGroup);
                sdt.validateTaxGroupType();
                sdt.validateTaxGroupHasTaxRate();
            }
        }
    }

    public static void calculateTaxAmountAndSetTaxGroup(List<SObject> newLines, Map<Id, SObject> oldLines) {
        TaxGroupHandler taxGroupHandler = TaxGroupHandler.getInstance();

        Set<Id> taxGroupIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();

        for (SObject newLine : newLines) {
            SObject oldLine = oldLines != NULL ? oldLines.get((Id) newLine.get('Id')) : NULL;
            SourceDocumentTaxDecorator sdt = new SourceDocumentTaxDecorator(oldLine, newLine);

            //tax amount should be 0 on insert or update
            sdt.setTaxAmountZero();

            if (!sdt.isProductNull() && sdt.isTaxGroupNull()) {
                productIds.add(sdt.getProductId());
            }
            //collect all tax groups populated on lines
            if (!sdt.isTaxGroupNull()) {
                taxGroupIds.add(sdt.getTaxGroupId());
            }
        }

        //if there is some source for tax amount calculation (Product with Tax Group or Tax Group)
        if (!taxGroupIds.isEmpty() || !productIds.isEmpty()) {
            taxGroupHandler.setTaxGroupsByProductIds(productIds).setTaxGroupsByTaxGroupIds(taxGroupIds);
        }

        for (SObject newLine : newLines) {
            SObject oldLine = oldLines != NULL ? oldLines.get((Id) newLine.get('Id')) : NULL;
            SourceDocumentTaxDecorator sdt = new SourceDocumentTaxDecorator(oldLine, newLine);

            if (!taxGroupIds.isEmpty() || !productIds.isEmpty()) {
                if (sdt.isNeedSetTaxGroup()
                        && taxGroupHandler.hasTaxGroupByProductId(sdt.getProductId())
                        && sdt.isTaxGroupValid(taxGroupHandler.getTaxGroupByProductId(sdt.getProductId()))) {

                    Tax_Group__c taxGroup = taxGroupHandler.getTaxGroupByProductId(sdt.getProductId());
                    sdt.setTaxGroup(taxGroup.Id);
                }
                if (!sdt.isTaxGroupNull() && sdt.isPayableLine() && sdt.isQuantityNull()) {
                    sdt.setQuantity(1);
                }
                //try to calculate Tax Amount based on populated Tax Group on the line
                if (!sdt.isTaxGroupNull()) {
                    Tax_Group__c taxGroup = taxGroupHandler.getTaxGroup(sdt.getTaxGroupId());
                    sdt.setAssociatedTaxGroup(taxGroup);
                    if (sdt.isNeedCalculateTaxAmount()) {
                        sdt.calculateAndSetTaxAmount();
                    }
                }
            }
        }
    }

    public static void clearTaxGroupInAvaTaxMode(List<SObject> newLines, Map<Id, SObject> oldLines) {
        for (SObject newLine : newLines) {
            SObject oldLine = oldLines != null ? oldLines.get((Id) newLine.get('Id')) : null;
            SourceDocumentTaxDecorator sdt = new SourceDocumentTaxDecorator(oldLine, newLine);
            sdt.setTaxGroup(null);
            if (sdt.isProductChanged() && sdt.isProductNull()) {
                sdt.setTaxAmount(0);
            }
        }
    }
}