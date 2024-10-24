public with sharing abstract class SourceDocumentUpdateFieldValidator {
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    
    public static final String UPDATE_APPLIED_ERROR = Label.ERR_UPDATE_APPLIED;
    public static final String UPDATE_ERROR = Label.ERR_UPDATE_FIELD;
    public static final String UPDATE_STATUS_ERROR = Label.ERR_UPDATE_STATUS;
    public static final String POSTED_UPDATE_ERROR = Label.ERR_POSTED_UPDATE;
    public static final String ALTERNATE_POSTED_UPDATE_ERROR = Label.ERR_ALTERNATE_POSTED_UPDATE;
    public static final String DELETE_APPLIED_ERROR = Label.ERR_DELETE_APPLIED;
    public static final String POSTED_DELETE_ERROR = Label.ERR_DELETE_POSTED;
    public static final String ALTERNATE_POSTED_DELETE_ERROR = Label.ERR_ALTERNATE_DELETE_POSTED;
    public static final String INSERT_APPLIED_ERROR = Label.ERR_INSERT_APPLIED;
    public static final String POSTED_INSERT_ERROR = Label.ERR_INSERT_POSTED;

    @TestVisible
    private static Boolean overridePreventUpdateStatusFieldPosted = false;

    protected SObject oldObj;
    protected SObject newObj;
    protected Map<Id, SObject> newObjectMap;
    protected Map<Id, SObject> oldObjectMap;
    @TestVisible
    protected Set<SObjectField> lockedUpdateFieldsPosted;
    @TestVisible
    protected Map<SObjectField, String> errorMessagesByLockedUpdateFieldsPosted;
    @TestVisible
    protected Set<SObjectFieldWrapper> lockedUpdateWrappedFieldsPosted;
    @TestVisible
    protected Set<SObjectField> lockedUpdateFields;
    @TestVisible
    protected Set<SObjectFieldWrapper> lockedUpdateWrappedFields;
    @TestVisible
    protected Set<SObjectField> lockedUpdateFieldsApplied;
    @TestVisible
    protected Set<SObjectFieldWrapper> lockedUpdateWrappedFieldsApplied;
    @TestVisible
    protected Set<SObjectField> lockedUpdateFieldsCustomSet;
    @TestVisible
    protected String customValidationErrorMsg;
    protected SObjectField statusField;
    protected SObjectField taxLineField;
    @TestVisible
    protected List<String> postedStatusValues = new List<String>{
        AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
        AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS,
        AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
    };
    protected Boolean allowStatusChange = false;
    @TestVisible
    protected List<Boolean> skipDeleteValidationFlags = new List<Boolean>();
    @TestVisible
    protected List<Boolean> skipUpdateValidationFlags = new List<Boolean>();
    @TestVisible
    protected Set<Id> junctionSObjectIds = new Set<Id>();
    @TestVisible
    private Set<SObjectField> nonUpdateableFields = new Set<SObjectField>();
    @TestVisible
    private Set<SObjectFieldWrapper> nonUpdateableWrappedFields = new Set<SObjectFieldWrapper>();
    @TestVisible
    private SObjectType sObjectType;

    @TestVisible
    private UpdateValidatorFieldsWrapper lockedUpdateFieldsPostedWrapper;
    @TestVisible
    protected UpdateValidatorFieldsWrapper lockedUpdateFieldsWrapper;
    @TestVisible
    private UpdateValidatorFieldsWrapper lockedUpdateFieldsAppliedWrapper;
    @TestVisible
    private UpdateValidatorFieldsWrapper lockedUpdateFieldsCustomWrapper;
    @TestVisible
    private UpdateValidatorFieldsWrapper lockedUpdateStatusFieldWrapper;
    @TestVisible
    private Boolean lockedDeletePosted = false;
    @TestVisible
    private Boolean lockedDeleteAlternatePosted = false;
    @TestVisible
    private Boolean lockedDeleteApplied = false;
    @TestVisible
    private Boolean lockedInsertPosted = false;
    @TestVisible
    private Boolean lockedInsertApplied = false;
    private Boolean isError;

    private Map<SObjectType, Set<SObjectField>> fieldsMustBeCheckedToVerifyRecordHasAppliedBySOType = new Map<SObjectType, Set<SObjectField>> {
        Billing__c.SObjectType => new Set<SObjectField> {
            Billing__c.Billing_Cash_Receipt_Count__c,
            Billing__c.Credit_Memo_Applied_Amount__c
        },
        Billing_Line__c.SObjectType => new Set<SObjectField> {
            Billing_Line__c.Billing_Has_Applied_Records__c
        },
        Account_Payable__c.SObjectType => new Set<SObjectField> {
            Account_Payable__c.AP_Disbursement_Count__c,
            Account_Payable__c.Credit_Memo_Applied_Amount__c
        },
        Account_Payable_Line__c.SObjectType => new Set<SObjectField> {
            Account_Payable_Line__c.Payable_Has_Applied_Records__c
        }
    };

    private static Map<SObjectType, String> wrapperTypeMapBySObjectType = new Map<SObjectType, String> {
        //==================== Billing =====================================
        Billing__c.SObjectType => BillingFieldUpdateValidator.class.getName(),
        Billing_Line__c.SObjectType => BillingLineFieldUpdateValidator.class.getName(),
        Billing_Credit_Memo__c.SObjectType => BillingCreditMemoFieldUpdateValidator.class.getName(),
        Billing_Cash_Receipt__c.SObjectType => BillingCashReceiptFieldUpdateValidator.class.getName(),
        //==================== Account Payable =====================================
        Account_Payable__c.SObjectType => AccountPayableFieldUpdateValidator.class.getName(),
        Account_Payable_Line__c.SObjectType => AccountPayableLineFieldUpdateValidator.class.getName(),
        AP_Credit_Memo__c.SObjectType => APCreditMemoFieldUpdateValidator.class.getName(),
        AP_Disbursement__c.SObjectType => APDisbursementFieldUpdateValidator.class.getName(),
        //==================== Time Card =====================================
        Time_Card__c.SObjectType => TimeCardFieldUpdateValidator.class.getName(),
        Time_Card_Line__c.SObjectType => TimeCardLineFieldUpdateValidator.class.getName(),
        Time_Card_Day__c.SObjectType => TimeCardDayFieldUpdateValidator.class.getName(),
        //==================== Cash Disbursement =====================================
        Cash_Disbursement__c.SObjectType => CashDisbursementFieldUpdateValidator.class.getName(),
        //==================== Cash Receipt =====================================
        Cash_Receipt__c.SObjectType => CashReceiptFieldUpdateValidator.class.getName(),
        //==================== Scheduled Revenue Expense =====================================
        Scheduled_Revenue_Expense__c.SObjectType => ScheduledRevExpenseFieldUpdateValidator.class.getName(),
        //==================== Journal Entry =====================================
        Journal_Entry__c.SObjectType => JournalEntryFieldUpdateValidator.class.getName(),
        Journal_Entry_Line__c.SObjectType => JournalEntryLineFieldUpdateValidator.class.getName(),
        //==================== Bank Deposit =====================================================
        Bank_Deposit__c.SObjectType => BankDepositFieldUpdateValidator.class.getName(),
        //==================== Bank Disbursement =====================================================
        Bank_Disbursement__c.SObjectType => BankDisbursementFieldUpdateValidator.class.getName(),
        //==================== Bank Reconciliation ==============================================
        Bank_Reconciliation2__c.SObjectType => BankReconciliationFieldUpdateValidator.class.getName(),
        //==================== Uncleared Bank Reconciliation Line ================================
        Uncleared_Bank_Reconciliation_Line__c.SObjectType => UnclearedBankRecLineFieldUpdateValidator.class.getName(),
        //==================== Ledger Hierarchy ================================
        Ledger_Hierarchy__c.SObjectType => LedgerHierarchyFieldUpdateValidator.class.getName(),
        //==================== Custom Exchange Rate Table ================================
        Exchange_Rate__c.SObjectType => ExchangeRateTableFieldUpdateValidator.class.getName(),
        //==================== Custom Payment Processor ========================
        Payment_Processor__c.SObjectType => PaymentProcessorFieldUpdateValidator.class.getName(),
        //==================== Ledger ===========================================================
        Ledger__c.SObjectType => LedgerFieldUpdateValidator.class.getName()
    };

    public static void validate(Map<Id, SObject> oldObjectMap, Map<Id, SObject> newObjectMap) {
        SObjectType sobjectTypeValue = getSObjectTypeByObjectMap(oldObjectMap, newObjectMap);
        Type t = Type.forName(wrapperTypeMapBySObjectType.get(sobjectTypeValue));
        SourceDocumentUpdateFieldValidator validator = (SourceDocumentUpdateFieldValidator) t.newInstance();

        validator.sObjectType = sobjectTypeValue;
        validator.newObjectMap = newObjectMap;
        validator.oldObjectMap = oldObjectMap;
        validator.setJunctionSObjectIds(oldObjectMap, newObjectMap);
        validator.setValidationRules();
        validator.getLockedFields();

        if (System.Trigger.isInsert && !skipInsertActionValidation(validator)) {
            for (SObject newObj : newObjectMap.values()) {
                validator.newObj = newObj;
                validator.validateInsertAction();
            }
        }
        else if (System.Trigger.isUpdate && !skipUpdateActionValidation(validator)) {
            for (SObject newObj : newObjectMap.values()) {
                SObject oldObj = (oldObjectMap != NULL && oldObjectMap.containsKey(newObj.Id) ? oldObjectMap.get(newObj.Id) : NULL);
                validator.newObj = newObj;
                validator.oldObj = oldObj;
                validator.validateLockedField();
            }
        }
        else if (System.Trigger.isDelete && !skipDeleteActionValidation(validator)) {
            for (SObject oldObj : oldObjectMap.values()) {
                validator.oldObj = oldObj;
                validator.validateDeleteAction();
            }
        }
    }

    private static SObjectType getSObjectTypeByObjectMap(Map<Id, SObject> oldObjectMap, Map<Id, SObject> newObjectMap) {
        return newObjectMap != NULL && !newObjectMap.isEmpty()
            ? newObjectMap.values()[0].getSObjectType()
            : oldObjectMap.values()[0].getSObjectType();
    }

    private static Boolean skipDeleteActionValidation(SourceDocumentUpdateFieldValidator validator) {
        return (!validator.lockedDeletePosted && !validator.lockedDeleteApplied && !validator.lockedDeleteAlternatePosted) || isCustomDeleteBypassFlagEnabled(validator);
    }

    private static Boolean isCustomDeleteBypassFlagEnabled(SourceDocumentUpdateFieldValidator validator) {
        for (Boolean customFlag : validator.skipDeleteValidationFlags) {
            if (customFlag) {
                return true;
            }
        }
        return false;
    }

    private static Boolean skipUpdateActionValidation(SourceDocumentUpdateFieldValidator validator) {
        return isCustomUpdateBypassFlagEnabled(validator);
    }

    private static Boolean isCustomUpdateBypassFlagEnabled(SourceDocumentUpdateFieldValidator validator) {
        for (Boolean customFlag : validator.skipUpdateValidationFlags) {
            if (customFlag) {
                return true;
            }
        }
        return false;
    }

    private static Boolean skipInsertActionValidation(SourceDocumentUpdateFieldValidator validator) {
        return !validator.lockedInsertPosted && !validator.lockedInsertApplied;
    }

    //================ field validator functions ==================================

    @TestVisible
    protected abstract void setValidationRules();
    @TestVisible
    protected virtual Boolean skipLegacyRecordValidation(SObjectField field) {
        return false;
    }

    @TestVisible
    protected virtual Boolean skipPostingStatusValidation(SObjectField field) {
        return false;
    }

    @TestVisible
    protected virtual Boolean customValidationRules() {
        return false;
    }

    // set Ids for query related objects, can be override in nested class if necessary
    @TestVisible
    protected virtual void setJunctionSObjectIds(Map<Id, SObject> oldObjectMap, Map<Id, SObject> newObjectMap) {
        junctionSObjectIds = newObjectMap != NULL && !newObjectMap.isEmpty() ? newObjectMap.keySet() : oldObjectMap.keySet();
    }

    protected void preventUpdateAction() {
        if (lockedUpdateFields != NULL && !lockedUpdateFields.isEmpty()) {
            lockedUpdateFieldsWrapper = new UpdateValidatorFieldsWrapper(lockedUpdateFields, UPDATE_ERROR);
        }
        else if (lockedUpdateWrappedFields != NULL && !lockedUpdateWrappedFields.isEmpty()) {
            lockedUpdateFieldsWrapper = new UpdateValidatorFieldsWrapper(lockedUpdateWrappedFields, UPDATE_ERROR);
        }
    }

    protected void preventUpdateActionPosted() {
        if (lockedUpdateFieldsPosted != NULL && !lockedUpdateFieldsPosted.isEmpty()) {
            lockedUpdateFieldsPostedWrapper = new UpdateValidatorFieldsWrapper(lockedUpdateFieldsPosted, POSTED_UPDATE_ERROR);
        }
        else if (lockedUpdateWrappedFieldsPosted != NULL && !lockedUpdateWrappedFieldsPosted.isEmpty()) {
            lockedUpdateFieldsPostedWrapper = new UpdateValidatorFieldsWrapper(lockedUpdateWrappedFieldsPosted, POSTED_UPDATE_ERROR);
        }
    }

    protected void preventUpdateActionAlternatePosted() {
        if (lockedUpdateFieldsPosted != NULL && !lockedUpdateFieldsPosted.isEmpty()) {
            lockedUpdateFieldsPostedWrapper = new UpdateValidatorFieldsWrapper(lockedUpdateFieldsPosted, ALTERNATE_POSTED_UPDATE_ERROR);
        }
        else if (lockedUpdateWrappedFieldsPosted != NULL && !lockedUpdateWrappedFieldsPosted.isEmpty()) {
            lockedUpdateFieldsPostedWrapper = new UpdateValidatorFieldsWrapper(lockedUpdateWrappedFieldsPosted, ALTERNATE_POSTED_UPDATE_ERROR);
        }
    }

    protected void preventUpdateActionApplied() {
        if (lockedUpdateFieldsApplied != NULL && !lockedUpdateFieldsApplied.isEmpty()) {
            lockedUpdateFieldsAppliedWrapper =
                new UpdateValidatorFieldsWrapper(lockedUpdateFieldsApplied, UPDATE_APPLIED_ERROR);
        }
        else if (lockedUpdateWrappedFieldsApplied != NULL && !lockedUpdateWrappedFieldsApplied.isEmpty()) {
            lockedUpdateFieldsAppliedWrapper =
                new UpdateValidatorFieldsWrapper(lockedUpdateWrappedFieldsApplied, UPDATE_APPLIED_ERROR);
        }
    }

    protected void preventUpdateCustomAction() {
        if (lockedUpdateFieldsCustomSet != NULL && !lockedUpdateFieldsCustomSet.isEmpty()) {
            lockedUpdateFieldsCustomWrapper = new UpdateValidatorFieldsWrapper(lockedUpdateFieldsCustomSet, customValidationErrorMsg);
        }
    }

    protected void preventUpdateStatusFieldPosted() {
        if (overridePreventUpdateStatusFieldPosted) {
            return;
        }
        lockedUpdateStatusFieldWrapper = new UpdateValidatorFieldsWrapper(new Set<SObjectField> {
            statusField
        }, UPDATE_STATUS_ERROR);
    }

    protected void preventInsertActionPosted() {
        lockedInsertPosted = true;
    }

    protected void preventInsertActionApplied() {
        lockedInsertApplied = true;
    }

    protected void preventDeleteActionPosted() {
        lockedDeletePosted = true;
    }

    protected void preventDeleteActionAlternatePosted() {
        lockedDeleteAlternatePosted = true;
    }

    protected void preventDeleteActionApplied() {
        lockedDeleteApplied = true;
    }

    @TestVisible
    private void getLockedFields() {
        if (lockedUpdateFields != NULL && !lockedUpdateFields.isEmpty()) {
            nonUpdateableFields.addAll(lockedUpdateFields);
        }
        if (lockedUpdateFieldsPosted != NULL && !lockedUpdateFieldsPosted.isEmpty()) {
            nonUpdateableFields.addAll(lockedUpdateFieldsPosted);
        }
        if (lockedUpdateFieldsApplied != NULL && !lockedUpdateFieldsApplied.isEmpty()) {
            nonUpdateableFields.addAll(lockedUpdateFieldsApplied);
        }
        if (lockedUpdateFieldsCustomSet != NULL && !lockedUpdateFieldsCustomSet.isEmpty()) {
            nonUpdateableFields.addAll(lockedUpdateFieldsCustomSet);
        }
        if (statusField != NULL) {
            nonUpdateableFields.add(statusField);
        }
        if (lockedUpdateWrappedFields != NULL && !lockedUpdateWrappedFields.isEmpty()) {
            nonUpdateableWrappedFields.addAll(lockedUpdateWrappedFields);
        }
        if (lockedUpdateWrappedFieldsPosted != NULL && !lockedUpdateWrappedFieldsPosted.isEmpty()) {
            nonUpdateableWrappedFields.addAll(lockedUpdateWrappedFieldsPosted);
        }
        if (lockedUpdateWrappedFieldsApplied != NULL && !lockedUpdateWrappedFieldsApplied.isEmpty()) {
            nonUpdateableWrappedFields.addAll(lockedUpdateWrappedFieldsApplied);
        }

        for (SObjectField field : nonUpdateableFields) {
            if (TriggerObserver.getInstance().isUnlockedField(field)) {
                nonUpdateableFields.remove(field);
            }
        }

        for (SObjectFieldWrapper field : nonUpdateableWrappedFields) {
            if (TriggerObserver.getInstance().isUnlockedField(field.field)) {
                nonUpdateableWrappedFields.remove(field);
            }
        }
    }

    private void validateInsertAction() {
        isError = false;
        if (!isError && lockedInsertPosted) {
            lockedInsertPostedValidate();
        }

        if (!isError && lockedInsertApplied) {
            lockedInsertAppliedValidate();
        }
    }

    private void validateDeleteAction() {
        isError = false;
        if (!isError && lockedDeletePosted) {
            lockedDeletePostedValidate();
        }

        if (!isError && lockedDeleteAlternatePosted) {
            lockedDeleteAlternatePostedValidate();
        }

        if (!isError && lockedDeleteApplied) {
            lockedDeleteAppliedValidate();
        }
    }

    private void validateLockedField() {
        isError = false;
        if (lockedUpdateStatusFieldWrapper != NULL && nonUpdateableFields.contains(statusField)) {
            lockedUpdateStatusValidate(statusField);
        }

        if (!isError) {
            for (SObjectField field : nonUpdateableFields) {
                if (isFieldChanged(field) && !skipLegacyRecordValidation(field)) {
                    if (!isError && lockedUpdateFieldsPostedWrapper != NULL && lockedUpdateFieldsPostedWrapper.fields.contains(field)) {
                        lockedUpdateFieldsPostedValidate(field);
                    }

                    if (!isError && lockedUpdateFieldsAppliedWrapper != NULL && lockedUpdateFieldsAppliedWrapper.fields.contains(field)) {
                        lockedUpdateFieldsAppliedValidate(field);
                    }

                    if (!isError && lockedUpdateFieldsWrapper != NULL && lockedUpdateFieldsWrapper.fields.contains(field)) {
                        lockedUpdateFieldsValidate(field);
                    }

                    if (!isError && lockedUpdateFieldsCustomWrapper != NULL && lockedUpdateFieldsCustomWrapper.fields.contains(field)) {
                        lockedUpdateFieldsCustomValidate(field);
                    }
                }
            }
            for (SObjectFieldWrapper field : nonUpdateableWrappedFields) {
                if (isFieldChanged(field) && !skipLegacyRecordValidation(field.field)) {
                    if (!isError && lockedUpdateFieldsPostedWrapper != NULL && lockedUpdateFieldsPostedWrapper.wrappedFields.contains(field)) {
                        lockedUpdateFieldsPostedValidate(field);
                    }

                    if (!isError && lockedUpdateFieldsAppliedWrapper != NULL && lockedUpdateFieldsAppliedWrapper.wrappedFields.contains(field)) {
                        lockedUpdateFieldsAppliedValidate(field);
                    }
                    if (!isError && lockedUpdateFieldsWrapper != NULL && lockedUpdateFieldsWrapper.wrappedFields.contains(field)) {
                        lockedUpdateFieldsValidate(field);
                    }
                }
            }
        }
    }

    private void lockedInsertPostedValidate() {
        if (postedStatusValues.contains((String)newObj.get(statusField)) && !skipPostingStatusValidation(statusField)) {
            newObj.addError(POSTED_INSERT_ERROR);
            isError = true;
        }
    }

    private void lockedInsertAppliedValidate() {
        if (hasAppliedRecords(newObj)) {
            newObj.addError(INSERT_APPLIED_ERROR);
            isError = true;
        }
    }

    private void lockedDeletePostedValidate() {
        if (postedStatusValues.contains((String)oldObj.get(statusField))) {
            oldObj.addError(POSTED_DELETE_ERROR);
            isError = true;
        }
    }

    private void lockedDeleteAlternatePostedValidate() {
        if (postedStatusValues.contains((String)oldObj.get(statusField))) {
            oldObj.addError(String.format(ALTERNATE_POSTED_DELETE_ERROR, new List<String>{(String)oldObj.get(statusField)}));
            isError = true;
        }
    }

    private void lockedDeleteAppliedValidate() {
        if (hasAppliedRecords(oldObj)) {
            oldObj.addError(DELETE_APPLIED_ERROR);
            isError = true;
        }
    }

    private void lockedUpdateStatusValidate(SObjectField field) {
        if (!allowStatusChange && !postedStatusValues.contains((String)oldObj.get(field)) && postedStatusValues.contains((String)newObj.get(field))) {
            newObj.addError(lockedUpdateStatusFieldWrapper.errorMessage);
            isError = true;
        }
    }

    private void lockedUpdateFieldsValidate(SObjectField field) {
        if (isFieldChanged(field)) {
            newObj.addError(
                String.format(
                    String.escapeSingleQuotes(lockedUpdateFieldsWrapper.errorMessage),
                    new List<String>{formatFieldStrings(lockedUpdateFieldsWrapper.fields)}
                ),
                false
            );
            isError = true;
        }
    }

    private void lockedUpdateFieldsValidate(SObjectFieldWrapper field) {
        if (isFieldChanged(field)) {
            newObj.addError(
                String.format(
                    String.escapeSingleQuotes(lockedUpdateFieldsWrapper.errorMessage),
                    new List<String>{formatFieldStrings(lockedUpdateFieldsWrapper.wrappedFields)}
                ),
                false
            );
            isError = true;
        }
    }

    private void lockedUpdateFieldsPostedValidate(SObjectField field) {
        if (postedStatusValues.contains((String)oldObj.get(statusField))) {
            Integer scale = field.getDescribe().getScale();

            String errorMessage = errorMessagesByLockedUpdateFieldsPosted != null && errorMessagesByLockedUpdateFieldsPosted.get(field) != null
                    ? errorMessagesByLockedUpdateFieldsPosted.get(field)
                    : lockedUpdateFieldsPostedWrapper.errorMessage;
            if ((isNonNumericField(field) || oldObj.get(field) == NULL || newObj.get(field) == NULL) && isFieldChanged(field)) {
                newObj.addError(
                    String.format(
                        String.escapeSingleQuotes(errorMessage),
                        new List<String>{
                            formatFieldStrings(lockedUpdateFieldsPostedWrapper.fields),
                            (String) oldObj.get(statusField)
                        }
                    ),
                    false
                );
                isError = true;
            }
            else if (isNumericField(field) && oldObj.get(field) != NULL && newObj.get(field) != NULL && isNumericFieldChanged(field, scale)) {
                newObj.addError(
                    String.format(
                        String.escapeSingleQuotes(errorMessage),
                        new List<String>{
                            formatFieldStrings(lockedUpdateFieldsPostedWrapper.fields),
                            (String) oldObj.get(statusField)
                        }
                    ),
                    false
                );
                isError = true;
            }
        }
    }

    private void lockedUpdateFieldsPostedValidate(SObjectFieldWrapper field) {
        if (postedStatusValues.contains((String)oldObj.get(statusField))) {
            Integer scale = field.field.getDescribe().getScale();

            String errorMessage = errorMessagesByLockedUpdateFieldsPosted != null && errorMessagesByLockedUpdateFieldsPosted.get(field.field) != null
                    ? errorMessagesByLockedUpdateFieldsPosted.get(field.field)
                    : lockedUpdateFieldsPostedWrapper.errorMessage;
            if ((isNonNumericField(field.field) || oldObj.get(field.field) == NULL || newObj.get(field.field) == NULL) && isFieldChanged(field)) {
                newObj.addError(
                    String.format(
                        String.escapeSingleQuotes(errorMessage),
                        new List<String>{
                            formatFieldStrings(lockedUpdateFieldsPostedWrapper.wrappedFields),
                            (String) oldObj.get(statusField)
                        }
                    ),
                    false
                );
                isError = true;
            }
            else if (isNumericField(field.field) && oldObj.get(field.field) != NULL && newObj.get(field.field) != NULL && isNumericFieldChanged(field.field, scale)) {
                newObj.addError(
                    String.format(
                        String.escapeSingleQuotes(errorMessage),
                        new List<String>{
                            formatFieldStrings(lockedUpdateFieldsPostedWrapper.wrappedFields),
                            (String) oldObj.get(statusField)
                        }
                    ),
                    false
                );
                isError = true;
            }
        }
    }

    private void lockedUpdateFieldsAppliedValidate(SObjectField field) {
        if (isFieldChanged(field) && hasAppliedRecords(newObj)) {
            newObj.addError(
                String.format(
                    String.escapeSingleQuotes(lockedUpdateFieldsAppliedWrapper.errorMessage),
                    new List<String>{formatFieldStrings(lockedUpdateFieldsAppliedWrapper.fields)}
                ),
                false
            );
            isError = true;
        }
    }

    private void lockedUpdateFieldsAppliedValidate(SObjectFieldWrapper field) {
        if (isFieldChanged(field) && hasAppliedRecords(newObj)) {
            newObj.addError(
                String.format(
                    String.escapeSingleQuotes(lockedUpdateFieldsAppliedWrapper.errorMessage),
                    new List<String>{formatFieldStrings(lockedUpdateFieldsAppliedWrapper.wrappedFields)}
                ),
                false
            );
            isError = true;
        }
    }

    private void lockedUpdateFieldsCustomValidate(SObjectField field) {
        if (isFieldChanged(field) && customValidationRules()) {
            newObj.addError(
                String.format(
                    String.escapeSingleQuotes(lockedUpdateFieldsCustomWrapper.errorMessage),
                    new List<String>{formatFieldStrings(lockedUpdateFieldsCustomWrapper.fields)}
                ),
                false
            );
            isError = true;
        }
    }

    protected Object getNewFieldValue(SObjectField field) {
        return newObj.get(field);
    }

    protected Boolean isLegacyLedgerFieldChanged(SObjectField field) {
        return oldObj.get(field) == NULL && newObj.get(field) == LedgerHandler.getLegacyDefaultLedgerId();
    }

    protected Boolean isFirstFieldChanges(SObjectField field) {
        return oldObj.get(field) == NULL && oldObj.get(field) != newObj.get(field);
    }

    private Boolean isFieldChanged(SObjectField field) {
        return oldObj.get(field) != newObj.get(field);
    }

    private Boolean isFieldChanged(SObjectFieldWrapper field) {
        //if the old field value is null, and allowUpdateIfNull is true, then isFieldChanged = false
        if (oldObj.get(field.field) == NULL && field.allowUpdateIfNull) {
            return false;
        }
        //otherwise, do the regular check        
        return oldObj.get(field.field) != newObj.get(field.field);
    }

    private Boolean isNumericFieldChanged(SObjectField field, Integer scale) {
        return ((Decimal)oldObj.get(field)).setScale(scale) != ((Decimal)newObj.get(field)).setScale(scale);
    }    

    private Boolean isNumericField(SObjectField field) {
        return field.getDescribe().getType() == Schema.DisplayType.Currency || field.getDescribe().getType() == Schema.DisplayType.Double;
    }

    private Boolean isNonNumericField(SObjectField field) {
        return field.getDescribe().getType() != Schema.DisplayType.Currency && field.getDescribe().getType() != Schema.DisplayType.Double;
    }

    private Boolean hasAppliedRecords(SObject obj) {
        Boolean result = false;
        for (SObjectField fieldToCheck : fieldsMustBeCheckedToVerifyRecordHasAppliedBySOType.get(sObjectType)) {
            //Fields validated here can have the following DisplayTypes:
            //On Billing/Payable : Number and Currency
            //On Billing Line/Payable Line : Checkbox
            DisplayType fieldDisplayType = fieldToCheck.getDescribe().getType();
            if (((fieldDisplayType == DisplayType.DOUBLE || fieldDisplayType == DisplayType.CURRENCY) && (Decimal) obj.get(fieldToCheck) != 0)
                    || (fieldDisplayType == DisplayType.BOOLEAN && (Boolean) obj.get(fieldToCheck))) {

                result = true;
                break;
            }
        }
        return result;
    }

    protected virtual Id getJunctionObjectId(SObject obj) {
        return obj.Id;
    }

    protected Boolean isTaxCalculationTransaction() {
        Boolean result = false;
        if (System.Trigger.isExecuting && (System.Trigger.isInsert || System.Trigger.isDelete)) {
            for (SObject line : (newObjectMap != NULL ? newObjectMap.values() : oldObjectMap.values())) {
                if ((Boolean) line.get(taxLineField)) {
                    result = true;
                    break;
                }
            }
        }
        return result;
    }

    @TestVisible
    private String formatFieldStrings(Set<SObjectField> fieldsSet) {
        String errorFields = '';
        List<SObjectField> fieldsList = new List<SObjectField>(fieldsSet);
        for (Integer i = 0; i < fieldsList.size(); i++)  {
            errorFields += fieldsList[i].getDescribe().getLabel() + (i == fieldsList.size() - 2 ? ', or ' : ', ');
        }

        return errorFields.subString(0, errorFields.length() - 2);
    }

     @TestVisible
    private String formatFieldStrings(Set<SObjectFieldWrapper> fieldsSet) {
        String errorFields = '';
        List<SObjectFieldWrapper> fieldsList = new List<SObjectFieldWrapper>(fieldsSet);
        for (Integer i = 0; i < fieldsList.size(); i++)  {
            errorFields += fieldsList[i].field.getDescribe().getLabel() + (i == fieldsList.size() - 2 ? ', or ' : ', ');
        }

        return errorFields.subString(0, errorFields.length() - 2);
    }

    public static Map<Id, Boolean> hasAppliedRecords(Map<Id, SObject> newObjectMap) {
        SObjectType sobjectTypeValue = getSObjectTypeByObjectMap(NULL, newObjectMap);
        Type t = Type.forName(wrapperTypeMapBySObjectType.get(sobjectTypeValue));
        SourceDocumentUpdateFieldValidator validator = (SourceDocumentUpdateFieldValidator) t.newInstance();
        validator.sObjectType = sobjectTypeValue;

        Map<Id, Boolean> hasAppliedRecordsMap = new Map<Id, Boolean>();
        for (Id recordId : newObjectMap.keySet()) {
            hasAppliedRecordsMap.put(recordId, validator.hasAppliedRecords(newObjectMap.get(recordId)));
        }

        return hasAppliedRecordsMap;
    }

    public static Boolean hasAppliedRecord(SObject record) {
        return SourceDocumentUpdateFieldValidator.hasAppliedRecords(
            new Map<Id, SObject>{record.Id => record}
        ).get(record.Id);
    }

    public static Boolean isForceMatchPermitted() {
        Boolean result = false;
        Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
        if (!String.isBlank(settings?.Financial_Suite_Key__c)
                && settings.Financial_Suite_Key__c.equalsIgnoreCase(GlobalVariables.FORCE_MATCH_PERMISSION_KEY)) {

            result = true;
        }
        return result;
    }

    public with sharing class SObjectFieldWrapper implements Comparable{
        private SObjectField field;
        private boolean allowUpdateIfNull;

        public SObjectFieldWrapper(SObjectField field, boolean allowUpdateIfNull) {
            this.field = field;
            this.allowUpdateIfNull = allowUpdateIfNull;
        }

        public Integer compareTo(Object compareTo) {
            SObjectFieldWrapper sObjectField = (SObjectFieldWrapper)compareTo;
            if (field == sObjectField.field) return 0;
            if (field == sObjectField.field) return 1;
            return -1;
        }
    }

    public with sharing class UpdateValidatorFieldsWrapper {
        private String errorMessage;
        public Set<SObjectField> fields;
        private Set<SObjectFieldWrapper> wrappedFields;

        private UpdateValidatorFieldsWrapper(Set<SObjectField> fields, String errorMessage) {
            this.fields = fields;
            this.wrappedFields = new Set<SObjectFieldWrapper>();
            this.errorMessage = errorMessage;
        }

        private UpdateValidatorFieldsWrapper(Set<SObjectFieldWrapper> fields, String errorMessage) {
            this.fields = new Set<SObjectField>();
            this.wrappedFields = fields;
            this.errorMessage = errorMessage;
        }
    }

}