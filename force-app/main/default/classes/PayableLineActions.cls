public with sharing class PayableLineActions {
    public static final String TOTAL_FIELD_QUANTITY_0_ERROR = Label.ERR_TOTAL_FIELD_QUANTITY_0;
    public static final String TOTAL_FIELD_POPULATED_INSERT_ERROR = Label.ERR_TOTAL_FIELD_POPULATED_INSERT;
    public static final String TOTAL_FIELD_POPULATED_UPDATE_ERROR = Label.ERR_TOTAL_FIELD_POPULATED_UPDATE;
    public static final String MATH_DOSNT_WORK = Label.ERR_MATH_DOSNT_WORK;

    public static final Map<SObjectType, SObjectField> amountFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Amount__c,
        Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Amount2__c
    };

    public static final Map<SObjectType, SObjectField> parentFieldNamesBySObjectTypes = new Map<SObjectType, SObjectField> {
            Account_Payable_Line__c.SObjectType => Account_Payable_Line__c.Account_Payable__c,
            Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable_Line__c.Recurring_Account_Payable__c
    };

    public static final Map<SObjectType, SObjectType> parentSObjectTypesBySObjectTypes = new Map<SObjectType, SObjectType> {
            Account_Payable_Line__c.SObjectType => Account_Payable__c.SObjectType,
            Recurring_Account_Payable_Line__c.SObjectType => Recurring_Account_Payable__c.SObjectType
    };

    public static void validateAndSetAmountAndUnitCostFields(List<SObject> newLines, Map<Id, SObject> oldLines) {
        Set<Id> parentIds = new Set<Id>();
        SObjectType objectType = null;
        for (SObject objLine : newLines) {
            objectType = objectType != null ? objectType : objLine.getSObjectType();
            SObjectField field = parentFieldNamesBySObjectTypes.get(objectType);
            if (field != null) {
                parentIds.add((Id)objLine.get(field));
            }
        }
        Map<Id, SObject> payableByIdsWithTaxSettings = parentSObjectTypesBySObjectTypes.get(objectType) != null && !parentIds.isEmpty() ?
            DomainUtils.fetchPayableByIdsWithTaxSettings(parentSObjectTypesBySObjectTypes.get(objectType), parentIds) : new Map<Id, SObject>();

        SObjectField parentField = parentFieldNamesBySObjectTypes.get(objectType);
        for (SObject objLine : newLines) {

            SObject oldObjLine = oldLines != NULL ? oldLines.get(objLine.Id) : NULL;
            PayableLine pl = new PayableLine(objLine, oldObjLine);

            Boolean isAmountUpdated = false;
            if (parentField != null && payableByIdsWithTaxSettings.get((Id)objLine.get(parentField))?.getSObject('Ledger__r')?.get('Tax_Settings__c') == null) {
                pl.setTaxAmount(0);
            }
            if (pl.isAmountAndTaxGroupBothNotEmpty()) {
                pl.setErrorMessage();
            }
            if (pl.isAmountAndUnitCostBothNotEmpty()) {
                pl.setErrorMessage();
            }
            if (pl.isQuantityZeroAndAmountNotNull()) {
                pl.setErrorMessage();
            }
            if (pl.isQuantityNull() && !pl.isPosted()) {
                pl.setQuantity(1);
            }
            if (pl.isNeedToSetAmountField()) {
                pl.setAmount();
                isAmountUpdated = true;
            }
            // only set unit cost if payable is NOT posted & pl is Account_Payable_Line__c
            if (!isAmountUpdated && pl.isNeedToSetUnitCostField() && !pl.isPosted()) {
                pl.setUnitCost();
            }
        }
    }

    public with sharing class PayableLine {
        private SObject oldObj;
        private SObject newObj;
        private SObjectType sobjectTypeValue;
        private SObjectField amountField;
        private SObjectField quantityField;
        private SObjectField unitCostField;
        private SObjectField taxAmountField;
        private SObjectField taxGroupField;
        private SObjectField taxInclusiveField;

        public PayableLine(SObject newObj) {
            this.newObj = newObj;
            sobjectTypeValue = newObj.getSObjectType();
            amountField = amountFieldNames.get(sobjectTypeValue);
            quantityField = HeaderLevelTaxHelper.quantityFieldNames.get(sobjectTypeValue);
            unitCostField = HeaderLevelTaxHelper.unitCostFieldNames.get(sobjectTypeValue);
            taxAmountField = HeaderLevelTaxHelper.taxAmountFieldNames.get(sobjectTypeValue);
            taxGroupField = HeaderLevelTaxHelper.taxGroupFieldNames.get(sobjectTypeValue);
            taxInclusiveField = HeaderLevelTaxHelper.taxInclusiveFieldNames.get(sobjectTypeValue);
        }

        public PayableLine(SObject newObj, SObject oldObj) {
            this(newObj);
            this.oldObj = oldObj;
        }

        public Id getTaxGroupId() {
            return (Id) newObj.get(taxGroupField);
        }

        public Decimal getUnitCost() {
            Decimal unitCost = (Decimal) newObj.get(unitCostField);
            return unitCost != NULL ? (unitCost).setScale(unitCostField.getDescribe().getScale(), RoundingMode.HALF_UP) : unitCost;
        }

        public Boolean isPosted() {
            Boolean isPosted = false;

            switch on newObj {
                when Account_Payable_Line__c apLine {
                    isPosted =  apLine.Parent_Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED ? true : false;
                }
            }
            return isPosted;
        }

        public Decimal getQuantity() {
            Decimal quantity = (Decimal) newObj.get(quantityField);
            return quantity != NULL ? (quantity).setScale(quantityField.getDescribe().getScale(), RoundingMode.HALF_UP) : quantity;
        }

        public Decimal getRawAmount() {
            return (Decimal) newObj.get(amountField);
        }

        public Decimal getAmount() {
            Decimal amount = getRawAmount();
            return amount != NULL ? (amount).setScale(amountField.getDescribe().getScale(), RoundingMode.HALF_UP) : amount;
        }

        public Decimal getTaxAmount() {
            return (Decimal) newObj.get(taxAmountField);
        }

        public void setTaxAmount(Decimal taxAmount) {
            TriggerObserver.getInstance().unlockField(this.taxAmountField);
            newObj.put(taxAmountField, taxAmount);
        }

        public void setQuantity(Decimal quantity) {
            TriggerObserver.getInstance().unlockField(this.quantityField);
            newObj.put(quantityField, quantity);
        }

        public void setAmount() {
            TriggerObserver.getInstance().unlockField(this.amountField);
            newObj.put(amountField, calculateAmount());
        }

        public Boolean isTaxInclusive() {
            //handle the condition where taxInclusiveField is null and not included in the object definition
            Boolean taxInclusive = false;
            if (taxInclusiveField != null) {
                taxInclusive = (Boolean) newObj.get(taxInclusiveField);
            }            
            return taxInclusive == null ? false : taxInclusive;
        }

        public Decimal calculateAmount() {
            Decimal quantity = getQuantity();
            quantity = quantity != null ? quantity : 1;
            Decimal unitCost = getUnitCost();
            unitCost = unitCost != null ? unitCost : 0;
            if (isTaxInclusive()) {
                return unitCost * quantity;
            }
            return (unitCost * quantity) + (!isTaxAmountNull() ? getTaxAmount() : 0);
        }

        public void setUnitCost() {
            TriggerObserver.getInstance().unlockField(this.unitCostField);
            newObj.put(unitCostField, !isQuantityNull() && !isQuantityZero() ? getAmount() / getQuantity() : getAmount());
        }

        public Boolean isInsert() {
            return oldObj == NULL;
        }

        public Boolean isUpdate() {
            return oldObj != NULL;
        }

        public Boolean isClone() {
            return newObj.isClone();
        }

        public Boolean isTaxGroupNull() {
            return getTaxGroupId() == NULL;
        }

        public Boolean isUnitCostNull() {
            return getUnitCost() == NULL;
        }

        public Boolean isAmountNull() {
            return getAmount() == NULL;
        }

        public Boolean isQuantityNull() {
            return getQuantity() == NULL;
        }

        public Boolean isQuantityZero() {
            return getQuantity() == 0;
        }

        public Boolean isTaxAmountNull() {
            return getTaxAmount() == NULL;
        }

        public Boolean isAmountChanged() {
            return isUpdate() && compareDecimal(newObj.get(amountField), oldObj.get(amountField), amountField.getDescribe().getScale());
        }

        public Boolean isUnitCostChanged() {
            return isUpdate() && compareDecimal(newObj.get(unitCostField), oldObj.get(unitCostField), unitCostField.getDescribe().getScale());
        }

        public Boolean isQuantityChanged() {
            return isUpdate() && compareDecimal(newObj.get(quantityField), oldObj.get(quantityField), quantityField.getDescribe().getScale());
        }

        public Boolean isTaxAmountChanged() {
            return isUpdate() && compareDecimal(newObj.get(taxAmountField), oldObj.get(taxAmountField), taxAmountField.getDescribe().getScale());
        }

        public Boolean isAmountAndTaxGroupBothNotEmpty() {
            return isAmountAndTaxGroupNotEmpty()
                && ((isInsert() && !isClone()) || isAmountChanged());
        }

        public Boolean isAmountAndUnitCostBothNotEmpty() {
            return isAmountAndUnitCostNotEmpty()
                && ((isInsert() && !isClone()) || (isUnitCostChanged() && isAmountChanged()));
        }

        public Boolean isAmountMathWorks() {
            return calculateAmount() == getRawAmount();
        }

        private Boolean isAmountAndTaxGroupNotEmpty() {
            return !isTaxGroupNull() && !isAmountNull();
        }

        private Boolean isAmountAndUnitCostNotEmpty() {
            return !isUnitCostNull() && !isAmountNull();
        }

        public Boolean isNeedToSetAmountField() {
            return !isUnitCostNull()
                && ((isInsert() && (isAmountNull() || isClone()))
                || isAmountNull() || (!isAmountChanged() && (isUnitCostChanged() || isQuantityChanged() || isTaxAmountChanged())));
        }

        public Boolean isNeedToSetUnitCostField() {
            return !isAmountNull()
                && ((isInsert() && isUnitCostNull())
                || (isAmountChanged() || isQuantityChanged() || isUnitCostNull()));
        }

        public Boolean isQuantityZeroAndAmountNotNull() {
            return !isAmountNull() && isUnitCostNull() && isQuantityZero();
        }

        public void setErrorMessage() {
            switch on newObj {
                when Account_Payable_Line__c apLine {
                    if (!isTaxGroupNull() && !isAmountMathWorks()) {
                        apLine.Amount__c.addError(getTotalUpdateErrorMessage());
                    } else if (isAmountAndUnitCostBothNotEmpty() && !isAmountMathWorks()) {
                        apLine.Unit_Cost__c.addError(MATH_DOSNT_WORK);
                        apLine.Amount__c.addError(MATH_DOSNT_WORK);
                    } else if (isQuantityZeroAndAmountNotNull()) {
                        apLine.Quantity__c.addError(TOTAL_FIELD_QUANTITY_0_ERROR);
                    }
                }
                when Recurring_Account_Payable_Line__c recurringPayableLine {
                    if (!isTaxGroupNull() && !isAmountMathWorks()) {
                        recurringPayableLine.Amount2__c.addError(getTotalUpdateErrorMessage());
                    } else if (isAmountAndUnitCostBothNotEmpty() && !isAmountMathWorks()) {
                        recurringPayableLine.Unit_Cost__c.addError(MATH_DOSNT_WORK);
                        recurringPayableLine.Amount2__c.addError(MATH_DOSNT_WORK);
                    } else if (isQuantityZeroAndAmountNotNull()) {
                        recurringPayableLine.Quantity__c.addError(TOTAL_FIELD_QUANTITY_0_ERROR);
                    }
                }
            }
        }

        private String getTotalUpdateErrorMessage() {
            String resultError = '';
            if (System.Trigger.isExecuting && System.Trigger.isInsert) {
                resultError = MATH_DOSNT_WORK;
            } else if (System.Trigger.isExecuting && System.Trigger.isUpdate) {
                resultError = TOTAL_FIELD_POPULATED_UPDATE_ERROR;
            }
            return resultError;
        }

        private Boolean compareDecimal(Object newValue, Object oldValue, Integer scale) {
            Boolean result = !(newValue == NULL && oldValue == NULL);
            if (newValue != NULL && oldValue != NULL) {
                result = ((Decimal) newValue).setScale(scale, System.RoundingMode.HALF_UP) != ((Decimal) oldValue).setScale(scale, System.RoundingMode.HALF_UP);
            }
            return result;
        }
    }
}