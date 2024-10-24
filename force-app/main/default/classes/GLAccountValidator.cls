public with sharing class GLAccountValidator {

    @TestVisible
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    @TestVisible
    private static final String AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER = GlobalVariables.AVALARA_VAT_REPORTING_PACKAGE_QUALIFIER;
    public static final String NON_VALID_TYPE_ERROR = Label.ERR_GL_ACCOUNT_NON_VALID_TYPE;
    public static final String NON_VALID_TYPE_AND_SUBTYPE1_ERROR = Label.ERR_NON_VALID_TYPE_AND_SUBTYPE1;
    @TestVisible
    private static final String AVAVAT_NON_VALID_TYPE_ERROR = Label.ERR_AVAVAT_NON_VALID_TYPE;
    public static final String NOT_BANK_ERROR = Label.ERR_GL_ACCOUNT_NOT_BANK;
    public static final String IS_BANK_ERROR = Label.ERR_GL_ACCOUNT_IS_BANK_CHECKED;
    public static final String NOT_CASH_FLOW_CATEGORY_ERROR = Label.ERR_CASH_FLOW_CATEGORY;
    public static final String IS_CASH_FLOW_CATEGORY_ERROR = Label.ERR_IS_CASH_FLOW_CATEGORY;
    @TestVisible
    private static final String INPUT_VAT_CATEGORY_ERROR = Label.ERR_GL_ACCOUNT_INPUT_VAT_CATEGORY;
    @TestVisible
    private static final String OUTPUT_VAT_CATEGORY_ERROR = Label.ERR_GL_ACCOUNT_OUTPUT_VAT_CATEGORY;
    @TestVisible
    private static final String INPUT_VAT_CATEGORY_NOT_ALLOWED_ERROR = Label.ERR_INPUT_VAT_CATEGORY_NOT_ALLOWED;
    @TestVisible
    private static final String OUTPUT_VAT_CATEGORY_NOT_ALLOWED_ERROR = Label.ERR_OUTPUT_VAT_CATEGORY_NOT_ALLOWED;
    public static final String EXISTED_TRANSACTION_ERROR = Label.ERR_GL_ACCOUNT_EXISTED_TRANSACTION;
    @TestVisible
    private static final String USED_IN_SETTING_ERROR = Label.ERR_GL_ACCOUNT_IS_NOT_ALLOWED;

    private static Map<SObjectType, List<String>> glLookupFieldNamesBySObjectType = new Map<SObjectType, List<String>>{
        //==================== Billing Line =====================================
        Billing_Line__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Expense_GL_Account__c',
            PACKAGE_QUALIFIER + 'Inventory_GL_Account__c',
            PACKAGE_QUALIFIER + 'Revenue_GL_Account__c'
        },
        //==================== Recurring Billing Line ===========================
        Recurring_Billing_Line__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Revenue_GL_Account__c'
        },
        //==================== Cash Receipt =====================================
        Cash_Receipt__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
            PACKAGE_QUALIFIER + 'Credit_GL_Account__c',
            PACKAGE_QUALIFIER + 'Bank_Account__c'
        },
        //==================== Billing Cash Receipt =============================
        Billing_Cash_Receipt__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Adjustment_GL_Account__c'
        },
        //==================== Payable Line =====================================
        Account_Payable_Line__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Expense_GL_Account__c'
        },
        //==================== Recurring Payable Line ===========================
        Recurring_Account_Payable_Line__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Expense_GL_Account__c'
        },
        //==================== Cash Disbursement ================================
        Cash_Disbursement__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
            PACKAGE_QUALIFIER + 'Debit_GL_Account__c',
            PACKAGE_QUALIFIER + 'Bank_Account__c'
        },
        //==================== Journal Entry Line ===============================
        Journal_Entry_Line__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
            PACKAGE_QUALIFIER + 'GL_Account__c'
        },
        //==================== Recurring Journal Entry Line ===============================
        Recurring_Journal_Entry_Line__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Cash_Flow_Category__c',
            PACKAGE_QUALIFIER + 'GL_Account__c'
        },
        //==================== Amortization Entry ===============================
        Scheduled_Revenue_Expense__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Credit_GL_Account__c',
            PACKAGE_QUALIFIER + 'Debit_GL_Account__c'
        },
        //==================== Project Task =====================================
        Project_Task__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Labor_GL_Account__c'
        },
        //==================== Account ==========================================
        Account.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Default_Expense_GL_Account__c'
        },
        //==================== Product ==========================================
        Product2.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Expense_GL_Account__c',
            PACKAGE_QUALIFIER + 'Inventory_GL_Account__c',
            PACKAGE_QUALIFIER + 'Revenue_GL_Account__c'
        },
        Accounting_Settings__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Default_Project_Task_Labor_GL_Account__c'
        },
        //==================== Bank Deposit ========================================
        Bank_Deposit__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Bank_Account__c'
        },
        //==================== Bank Reconciliation =================================
        Bank_Reconciliation2__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Bank_Account__c'
        },
        //==================== Ledger =================================
        Ledger__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Default_Bank_Account__c'
        },
        //==================== Expense Line =====================================
        Expense_Line__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Expense_GL_Account__c'
        },
        //==================== Tax Rate =========================================
        Tax_Rate__c.SObjectType => new List<String>{
            PACKAGE_QUALIFIER + 'Purchase_Tax_Expense_GL_Account__c',
            PACKAGE_QUALIFIER + 'Sales_Tax_Liability_GL_Account__c'
        }
    };

    private static Set<String> defaultSetIncludedDefaults = new Set<String>{
        GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT,
        GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT,
        GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT,
        GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT
    };

    private static Set<String> defaultSmallSetIncludedDefaults = new Set<String>{
        GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT,
        GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT,
        GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT
    };

    private static Map<SObjectType, Set<String>> includedDefaultsBySObjectType = new Map<SObjectType, Set<String>>{
        //==================== Payable Line =====================================
        Account_Payable_Line__c.SObjectType => defaultSmallSetIncludedDefaults,
        //==================== Recurring Payable Line ===========================
        Recurring_Account_Payable_Line__c.SObjectType => defaultSmallSetIncludedDefaults,
        //==================== Bank Deposit =====================================
        Bank_Deposit__c.SObjectType => defaultSmallSetIncludedDefaults,
        //==================== Billing Line =====================================
        Billing_Line__c.SObjectType => defaultSetIncludedDefaults,
        //==================== Recurring Billing Line ===========================
        Recurring_Billing_Line__c.SObjectType => defaultSmallSetIncludedDefaults,
        //==================== Billing Cash Receipt =============================
        Billing_Cash_Receipt__c.SObjectType => defaultSetIncludedDefaults,
        //==================== Cash Receipt =====================================
        Cash_Receipt__c.SObjectType => defaultSetIncludedDefaults,
        //==================== Cash Disbursement ================================
        Cash_Disbursement__c.SObjectType => defaultSetIncludedDefaults,
        //==================== Expense Line =====================================
        Expense_Line__c.SObjectType => defaultSetIncludedDefaults,
        //==================== Project Task =====================================
        Project_Task__c.SObjectType => defaultSetIncludedDefaults,
        //==================== Product ==========================================
        Product2.SObjectType => defaultSmallSetIncludedDefaults,
        //==================== Amortization Entry ===============================
        Scheduled_Revenue_Expense__c.SObjectType => defaultSetIncludedDefaults,
        //==================== Journal Entry Line ===============================
        Journal_Entry_Line__c.SObjectType => new Set<String>{
            GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT
        },
        //==================== Recurring Journal Entry Line =====================
        Recurring_Journal_Entry_Line__c.SObjectType => new Set<String>{
            GLAccountDefaultsHandler.CURRENT_YEAR_EARNINGS_GL_ACCOUNT
        },
        //==================== Tax Rate =========================================
        Tax_Rate__c.SObjectType => defaultSetIncludedDefaults
    };

    @TestVisible
    private static String cumulativeErrorMessage;

    private List<SObject> recs;
    private SObjectType objType;
    private Map<Id, SObject> oldRecordMap;
    private List<DescribeFieldResult> validatedFields;
    private Map<DescribeFieldResult, GLAccountLookupValidationRule> validationRules;
    private Set<String> objFields;

    private Map<Id, GL_Account__c> glAccountMap;
    
    @TestVisible private Map<ID, AggregateResult> glAccountFinCubeCountMap;
    
    private Set<Id> glAccountIds;
    private Map<String, Object> accountingSettingMap;

    public GLAccountValidator(List<SObject> records, Map<Id, SObject> oldRecordMap) {
        if (AccountingSettingsHandler.isNPSPEnabled()) {
            glLookupFieldNamesBySObjectType.put(((SObject)Type.forName('npsp__General_Accounting_Unit__c').newInstance()).getSObjectType(), 
                new List<String>{
                    'AcctSeedExt__Debit_GL_Account__c',
                    'AcctSeedExt__Credit_GL_Account__c'
                });

            includedDefaultsBySObjectType.put(((SObject)Type.forName('npsp__General_Accounting_Unit__c').newInstance()).getSObjectType(),
                defaultSetIncludedDefaults);
        }
        this.recs = records;
        this.oldRecordMap = oldRecordMap;
        this.objType = records.getSObjectType();
        this.validatedFields = getValidatedFields();
        this.validationRules = getValidationRules();
        this.objFields = this.objType.getDescribe().fields.getMap().keySet();
    }

    public List<GLAccountValidator.RecordValidationResult> validate() {
        List<GLAccountValidator.RecordValidationResult> results = new List<GLAccountValidator.RecordValidationResult>();
        glAccountIds = new Set<Id>();
        for (SObject newRecord : recs) {
            SObject oldRecord;
            if (oldRecordMap != null && oldRecordMap.containsKey(newRecord.Id)) {
                oldRecord = oldRecordMap.get(newRecord.Id);
            }
            for (DescribeFieldResult fieldResult : validatedFields) {
                glAccountIds.add((Id) newRecord.get(fieldResult.getName()));

                if (oldRecord != null) {
                    glAccountIds.add((Id) oldRecord.get(fieldResult.getName()));
                }
            }
        }
        initGLAccountMap();
        for (SObject newRecord : recs) {
            List<GLAccountValidator.FieldValidationResult> fieldValResults = new List<GLAccountValidator.FieldValidationResult>();
            if (oldRecordMap != null) {//UPDATE trigger
                for (DescribeFieldResult fieldResult : validatedFields) {
                    //field has been changed
                    if (newRecord.get(fieldResult.getName()) != oldRecordMap.get(newRecord.Id).get(fieldResult.getName())) {
                        fieldValResults.add(checkGLAccount(newRecord, fieldResult, true));
                    }
                    else {
                        fieldValResults.add(new GLAccountValidator.FieldValidationResult(true, fieldResult, null));
                    }
                }
            }
            else {//INSERT trigger
                for (DescribeFieldResult fieldResult : validatedFields) {
                    fieldValResults.add(checkGLAccount(newRecord, fieldResult, false));
                }
            }

            GLAccountValidator.RecordValidationResult recordValRes =
                new GLAccountValidator.RecordValidationResult(newRecord.Id, fieldValResults);
            results.add(recordValRes);
        }
        return results;
    }

    private GLAccountValidator.FieldValidationResult checkGLAccount(SObject newRecord, DescribeFieldResult field, Boolean isUpdate) {
        GLAccountValidator.FieldValidationResult result;
        Boolean isError = false;
        List<String> errorMessages = new List<String>();
        GLAccountValidator.GLAccountLookupValidationRule theRule = validationRules.get(field);

        GL_Account__c glAccountToCheck;
        if (newRecord.get(field.getName()) != null) {
            glAccountToCheck = glAccountMap.get((Id) newRecord.get(field.getName()));
            String glCategory = glAccountToCheck.GL_Category__c;
            if (!theRule.supportedTypes.contains(glAccountToCheck.Type__c) || theRule.supportedSubTypes1 != null) {
                if (theRule.supportedSubTypes1 != null
                    && (!theRule.supportedSubTypes1.contains(glAccountToCheck.Sub_Type_1__c)
                    || !theRule.supportedTypes.contains(glAccountToCheck.Type__c))) {

                    List<String> errors = new List<String> (theRule.supportedTypes);
                    errors.add(new List<String>(theRule.supportedSubTypes1)[0]);
                    errorMessages.add(String.format(NON_VALID_TYPE_AND_SUBTYPE1_ERROR, errors));
                    isError = true;
                }
                else if (!theRule.supportedTypes.contains(glAccountToCheck.Type__c) && theRule.supportedSubTypes1 == null) {
                    errorMessages.add(String.format(NON_VALID_TYPE_ERROR, new List<String> (theRule.supportedTypes)));
                    isError = true;
                }
            }
            if (theRule.bankOnly && !glAccountToCheck.Bank__c) {
                isError = true;
                errorMessages.add(NOT_BANK_ERROR);
            }
            if (theRule.notBankOnly && glAccountToCheck.Bank__c) {
                isError = true;
                errorMessages.add(IS_BANK_ERROR);
            }
            if (theRule.cashFlowOnly && (glAccountToCheck.Type__c != 'Cash Flow')) {
                isError = true;
                errorMessages.add(NOT_CASH_FLOW_CATEGORY_ERROR);
            }
            if (theRule.notCashFlowOnly && (glAccountToCheck.Type__c == 'Cash Flow')) {
                isError = true;
                errorMessages.add(IS_CASH_FLOW_CATEGORY_ERROR);
            }
            if (theRule.checkInputVAT 
                    && theRule.isAvaVATReportingEnabled 
                    && !(new Set<String>{'Balance Sheet', 'Revenue', 'Expense'}).contains(glAccountToCheck.Type__c)
                    && newRecord.get('Tax_Group_External_Id__c') != null) {

                isError = true;
                errorMessages.add(AVAVAT_NON_VALID_TYPE_ERROR);
            }
            if (theRule.checkOutputVAT 
                    && theRule.isAvaVATReportingEnabled 
                    && glCategory != 'Output VAT'
                    && newRecord.get('Tax_Group_External_Id__c') != null) {

                isError = true;
                errorMessages.add(OUTPUT_VAT_CATEGORY_ERROR);
            }
            if (theRule.checkInputVAT 
                    && (glCategory == 'Input VAT' || glCategory == 'Output VAT')
                    && (!theRule.isAvaVATReportingEnabled || newRecord.get('Tax_Group_External_Id__c') == null)) {

                isError = true;
                errorMessages.add(INPUT_VAT_CATEGORY_NOT_ALLOWED_ERROR);
            }
            if (theRule.checkOutputVAT 
                    && (glCategory == 'Output VAT' || glCategory == 'Input VAT')
                    && (!theRule.isAvaVATReportingEnabled || newRecord.get('Tax_Group_External_Id__c') == null)) {

                isError = true;
                errorMessages.add(OUTPUT_VAT_CATEGORY_NOT_ALLOWED_ERROR);
            }
            if (theRule.needCheckSettingAccounts && isUsedInDefaultsAndNotAllow(glAccountToCheck, newRecord, theRule.needCheckSettingAccountsByObjectType)) {
                isError = true;
                errorMessages.add(String.format(USED_IN_SETTING_ERROR, new List<String>{glAccountToCheck.Name}));
            }

            if (theRule.needCheckTransactionOnNew && getGLAccountWithCubeCountMap().containsKey(glAccountToCheck.Id)) {
                isError = true;
                errorMessages.add(String.format(EXISTED_TRANSACTION_ERROR, new List<String>{glAccountToCheck.Name}));
            }
            if (isUpdate && theRule.needCheckTransaction) {
                GL_Account__c oldGlAccountToCheck = glAccountMap.get((Id) oldRecordMap.get(newRecord.Id).get(field.getName()));
                if (oldGlAccountToCheck != null && getGLAccountWithCubeCountMap().containsKey(oldGlAccountToCheck.Id)) {
                    isError = true;
                    errorMessages.add(String.format(EXISTED_TRANSACTION_ERROR, new List<String>{oldGlAccountToCheck.Name}));
                }
            }
            result = new GLAccountValidator.FieldValidationResult(!isError, field, errorMessages);
        }
        else {
            result = new GLAccountValidator.FieldValidationResult(true, field, null);
        }
        return result;
    }

    private Boolean isUsedInDefaultsAndNotAllow(GL_Account__c glAccountToCheck, SObject newRecord, Boolean isNeedToCheckByObject) {
        Boolean result = isUsedInLedgerDefaults(glAccountToCheck, newRecord);
        if (isNeedToCheckByObject) {
            result = result && !isAllowedByObjectType(glAccountToCheck, newRecord);
        }
        return result;
    }

    private Boolean isAllowedByObjectType(GL_Account__c glAccountToCheck, SObject newRecord) {
        Boolean result = false;
        if (objType == Cash_Disbursement__c.SObjectType
            && (String) newRecord.get(Cash_Disbursement__c.Source__c) == 'Manual'
            && GLAccount.glAccountDefaultsMapByLedgerId((Id) newRecord.get(Cash_Disbursement__c.Ledger__c)).get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c == glAccountToCheck.Id) {
            result = true;
        }
        if (objType == Cash_Disbursement__c.SObjectType
            && CashDisbursementActions.isSourcePayable((Cash_Disbursement__c)newRecord)
            && GLAccount.glAccountDefaultsMapByLedgerId((Id) newRecord.get(Cash_Disbursement__c.Ledger__c)).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c == glAccountToCheck.Id) {
            result = true;
        }
        if (objType == Billing_Line__c.SObjectType
            && GLAccount.glAccountDefaultsMapByLedgerId((Id) newRecord.get(Billing_Line__c.Ledger__c)).get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c == glAccountToCheck.Id) {
            result = true;
        }
        return result;
    }

    private Id getLedgerId(SObject newRecord) {
        Id ledgerId;
        if (objType == Ledger__c.SObjectType) {
            ledgerId = newRecord.Id;
        }
        if (objFields.contains(PACKAGE_QUALIFIER.toLowerCase() + 'ledger__c')) {
            ledgerId = (Id) newRecord.get(PACKAGE_QUALIFIER + 'Ledger__c');
        }
        return ledgerId;
    }

    private Set<Id> getDefaultsByLedger(Id ledgerId) {
        List<GL_Account_Default__c> defaults = new List<GL_Account_Default__c>();
        Set<Id> result = new Set<Id>();
        if (ledgerId != null) {
            defaults.addAll(GLAccount.glAccountDefaultsMapByLedgerId(ledgerId).values());
        }
        else {
            for (Map<String, GL_Account_Default__c> defaultMap : GLAccount.glAccountDefaultsMapByLedgerId(LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().keySet()).values()) {
                defaults.addAll(defaultMap.values());
            }
        }

        for (GL_Account_Default__c def : defaults) {
            if (includedDefaultsBySObjectType.get(objType) != null && includedDefaultsBySObjectType.get(objType).contains(def.GL_Account_Specification__c)) {
                result.add(def.GL_Account__c);
            }
        }
        return result;
    }

    private Boolean isUsedInLedgerDefaults(GL_Account__c glAccountToCheck, SObject newRecord) {
        Boolean result = false;
        if (getDefaultsByLedger(getLedgerId(newRecord)).contains(glAccountToCheck.Id)) {
            result = true;
        }
        return result;
    }

    private void initGLAccountMap() {
        if (glAccountMap == null) {
            glAccountMap = new Map<Id, GL_Account__c>(DomainUtils.getGlAccountsById(glAccountIds));            
        }
    }

    private Map<Id, AggregateResult> getGLAccountWithCubeCountMap() {
        if (glAccountFinCubeCountMap == null) {
            try {
                glAccountFinCubeCountMap = new Map<Id, AggregateResult>(DomainUtils.getGLAccountsWithFinCubesCount(glAccountIds));
            }
            catch (QueryException qEx) {
                //In case of non-selective query our assumption is that each GL Account has at least one related FC
                //Only the key matters in the map, so values can be nulls
                glAccountFinCubeCountMap = new Map<Id, AggregateResult>();
                for (Id glAccountId : glAccountIds) {
                    glAccountFinCubeCountMap.put(glAccountId, null);
                }
            }
        }

        return glAccountFinCubeCountMap;
    }
    

    private Map<DescribeFieldResult, GLAccountLookupValidationRule> getValidationRules() {
        Map<DescribeFieldResult, GLAccountLookupValidationRule> rules =
            new Map<DescribeFieldResult, GLAccountValidator.GLAccountLookupValidationRule>();
        for (DescribeFieldResult fieldResult : validatedFields) {
            GLAccountValidator.GLAccountLookupValidationRule newRule = new GLAccountValidator.GLAccountLookupValidationRule(
                objType, fieldResult
            );
            rules.put(fieldResult, newRule);
        }
        return rules;
    }

    public static void validateGlAccountLookups(List<SObject> newRecords, Map<Id, SObject> oldRecordMap, Boolean bypassValidation) {
        if (bypassValidation) {
            return;
        }
        else {
            validateGlAccountLookups(newRecords, oldRecordMap);
        }
    }

    public static void validateGlAccountLookups(List<SObject> newRecords, Map<Id, SObject> oldRecordMap) {
        GLAccountValidator validator = new GLAccountValidator(newRecords, oldRecordMap);
        List<GLAccountValidator.RecordValidationResult> recValResults = validator.validate();

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>(newRecords);
        for (GLAccountValidator.RecordValidationResult valResult : recValResults) {
            cumulativeErrorMessage = null;
            List<GLAccountValidator.FieldValidationResult> fieldValResults = valResult.fieldValidationResults;

            for (GLAccountValidator.FieldValidationResult fieldValResult : fieldValResults) {
                if (!fieldValResult.isValid) {
                    allErrorsInOneMessage(fieldValResult);
                }
            }

            if (cumulativeErrorMessage != null) {
                newRecordsMap.get(valResult.recordId).addError(cumulativeErrorMessage, false);
            }
        }
    }

    public static void allErrorsInOneMessage(GLAccountValidator.FieldValidationResult fieldValResult) {
        if (cumulativeErrorMessage == null) {
            cumulativeErrorMessage = '';
        }
        for (String errorMessage : fieldValResult.errorMessages) {
            if (!String.isBlank(cumulativeErrorMessage)) {
                cumulativeErrorMessage += '<br/>';
            }
            cumulativeErrorMessage += fieldValResult.field.getLabel() + ': ' + errorMessage;
        }
    }

    private List<DescribeFieldResult> getValidatedFields() {
        List<DescribeFieldResult> result = new List<DescribeFieldResult>();
        List<String> fieldNames = glLookupFieldNamesBySObjectType.get(objType);
        for (String fieldName : fieldNames) {
            DescribeFieldResult dfr = convertFieldNameToDescribeFieldResult(fieldName);
            if (dfr != null) {
                result.add(dfr);
            }
        }
        return result;
    }

    private DescribeFieldResult convertFieldNameToDescribeFieldResult(String fieldName) {
        DescribeFieldResult descFieldResult;
        if (objType != null) {
            SObjectField sObjField = SchemaDescribe.getDescribe(objType).getField(fieldName);
            if (sObjField != null) {
                descFieldResult = sObjField.getDescribe();
            }
        }
        return descFieldResult;
    }

    public with sharing class RecordValidationResult {
        public Id recordId {get; set;}
        public List<FieldValidationResult> fieldValidationResults {get; set;}

        public RecordValidationResult(Id recId, List<FieldValidationResult> fieldValidationResults) {
            this.recordId = recId;
            this.fieldValidationResults = fieldValidationResults;
        }
    }

    public with sharing class FieldValidationResult {
        public DescribeFieldResult field {get; set;}
        public List<String> errorMessages {get; set;}
        public Boolean isValid {get; set;}

        public FieldValidationResult(Boolean isValid, DescribeFieldResult fieldResult, List<String> errorMsgs) {
            this.isValid = isValid;
            this.field = fieldResult;
            this.errorMessages = errorMsgs;
        }
    }

    public with sharing class GLAccountLookupValidationRule {
        public Set<String> supportedTypes {get; private set;}
        public Set<String> supportedSubTypes1 {get; private set;}
        public Boolean bankOnly {get; private set;}
        public Boolean notBankOnly {get; private set;}
        public Boolean cashFlowOnly {get; private set;}
        public Boolean notCashFlowOnly {get; private set;}
        public Boolean isAvaVATReportingEnabled {get; private set;}
        public Boolean checkInputVAT {get; private set;}
        public Boolean checkOutputVAT {get; private set;}
        public Boolean needCheckTransaction {get; private set;}
        public Boolean needCheckTransactionOnNew {get; private set;}
        public Boolean needCheckSettingAccounts {get; private set;}
        public Boolean needCheckSettingAccountsByObjectType {get; private set;}

        public GLAccountLookupValidationRule(SObjectType objType, DescribeFieldResult fieldResult) {
            needCheckTransactionOnNew = false;
            needCheckSettingAccountsByObjectType = false;
            isAvaVATReportingEnabled = AccountingSettingsHandler.isAvaVATReportingEnabled();
            checkInputVAT = false;
            checkOutputVAT = false;

            if (objType == Billing_Line__c.SObjectType) {
                if (fieldResult == SObjectType.Billing_Line__c.fields.Expense_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
                if (fieldResult == SObjectType.Billing_Line__c.fields.Revenue_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                    needCheckSettingAccountsByObjectType = true;
                }
                if (fieldResult == SObjectType.Billing_Line__c.fields.Inventory_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
            }

            if (objType == Recurring_Billing_Line__c.SObjectType) {
                if (fieldResult == SObjectType.Recurring_Billing_Line__c.fields.Revenue_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
            }

            if (objType == Cash_Receipt__c.SObjectType) {
                if (fieldResult == SObjectType.Cash_Receipt__c.fields.Cash_Flow_Category__c) {
                    init(null, false, false, true, false, false, false);
                }
                if (fieldResult == SObjectType.Cash_Receipt__c.fields.Credit_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
                if (fieldResult == SObjectType.Cash_Receipt__c.fields.Bank_Account__c) {
                    init(null, true, false, false, true, false, true);
                }
            }

            if (objType == Billing_Cash_Receipt__c.SObjectType) {
                if (fieldResult == SObjectType.Billing_Cash_Receipt__c.fields.Adjustment_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
            }

            if (objType == Account_Payable_Line__c.SObjectType) {
                if (fieldResult == SObjectType.Account_Payable_Line__c.fields.Expense_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
            }

            if (objType == Recurring_Account_Payable_Line__c.SObjectType) {
                if (fieldResult == SObjectType.Recurring_Account_Payable_Line__c.fields.Expense_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
            }

            if (objType == Cash_Disbursement__c.SObjectType) {
                if (fieldResult == SObjectType.Cash_Disbursement__c.fields.Cash_Flow_Category__c) {
                    init(null, false, false, true, false, false, false);
                }
                if (fieldResult == SObjectType.Cash_Disbursement__c.fields.Debit_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                    needCheckSettingAccountsByObjectType = true;
                }
                if (fieldResult == SObjectType.Cash_Disbursement__c.fields.Bank_Account__c) {
                    init(null, true, false, false, true, false, true);
                }
            }

            if (objType == Journal_Entry_Line__c.SObjectType) {
                if (fieldResult == SObjectType.Journal_Entry_Line__c.fields.Cash_Flow_Category__c) {
                    init(null, false, false, true, false, false, false);
                }
                if (fieldResult == SObjectType.Journal_Entry_Line__c.fields.GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
            }

            if (objType == Recurring_Journal_Entry_Line__c.SObjectType) {
                if (fieldResult == SObjectType.Recurring_Journal_Entry_Line__c.fields.Cash_Flow_Category__c) {
                    init(null, false, false, true, false, false, false);
                }
                if (fieldResult == SObjectType.Recurring_Journal_Entry_Line__c.fields.GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
            }

            if (objType == Scheduled_Revenue_Expense__c.SObjectType) {
                if (fieldResult == SObjectType.Scheduled_Revenue_Expense__c.fields.Credit_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
                if (fieldResult == SObjectType.Scheduled_Revenue_Expense__c.fields.Debit_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
            }

            if (objType == Project_Task__c.SObjectType) {
                if (fieldResult == SObjectType.Project_Task__c.fields.Labor_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
            }

            if (objType == Account.SObjectType) {
                if (fieldResult == SObjectType.Account.fields.Default_Expense_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
            }

            if (objType == Product2.SObjectType) {
                if (fieldResult == SObjectType.Product2.fields.Expense_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
                if (fieldResult == SObjectType.Product2.fields.Revenue_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
                if (fieldResult == SObjectType.Product2.fields.Inventory_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                }
            }

            if (objType == Accounting_Settings__c.SObjectType) {
                if (fieldResult == SObjectType.Accounting_Settings__c.fields.Default_Project_Task_Labor_GL_Account__c) {
                    init(NULL, false, false, false, true, false, false);
                }
            }

            if (objType == Ledger__c.SObjectType) {
                if (fieldResult == SObjectType.Ledger__c.fields.Default_Bank_Account__c) {
                    init(null, true, false, false, true, false, true);
                }
            }

            if (objType == Bank_Deposit__c.SObjectType) {
                if (fieldResult == SObjectType.Bank_Deposit__c.fields.Bank_Account__c) {
                    init(null, true, false, false, false, false, true);
                }
            }

            if (objType == Bank_Reconciliation2__c.SObjectType) {
                if (fieldResult == SObjectType.Bank_Reconciliation2__c.fields.Bank_Account__c) {
                    init(null, true, false, false, false, false, true);
                }
            }

            if (objType == Expense_Line__c.SObjectType) {
                if (fieldResult == SObjectType.Expense_Line__c.fields.Expense_GL_Account__c) {
                    init(null, false, true, false, true, false, true);
                }
            }

            if (objType == Tax_Rate__c.SObjectType) {
                if (fieldResult == SObjectType.Tax_Rate__c.fields.Purchase_Tax_Expense_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                    checkInputVAT = true;
                }
                if (fieldResult == SObjectType.Tax_Rate__c.fields.Sales_Tax_Liability_GL_Account__c) {
                    init(null, false, false, false, true, false, true);
                    checkOutputVAT = true;
                }
            }

            if (AccountingSettingsHandler.isNPSPEnabled()) {
                Schema.SObjectType gauType = ((SObject)Type.forName('npsp__General_Accounting_Unit__c').newInstance()).getSObjectType();
                if (objType == gauType) {
                    Map<String, Schema.SObjectField> gauFields = gauType.getDescribe().fields.getMap();
                    if (fieldResult == (gauFields.get('AcctSeedExt__Debit_GL_Account__c').getDescribe())) {
                        init(null, false, false, false, true, false, true);
                    }
                    if (fieldResult == (gauFields.get('AcctSeedExt__Credit_GL_Account__c').getDescribe())) {
                        init(null, false, false, false, true, false, true);
                    }
                }
            }

        }

        private void init(
            Set<String> types,
            Boolean bankOnly,
            Boolean notBankOnly,
            Boolean cashFlowOnly,
            Boolean notCashFlowOnly,
            Boolean needCheckTransaction,
            Boolean needCheckSettingAccounts) {

            this.supportedTypes = (types != null) ? types : new Set<String>{'Balance Sheet', 'Revenue', 'Expense', 'Cash Flow'};
            
            this.bankOnly = bankOnly;
            this.notBankOnly = notBankOnly;
            this.cashFlowOnly = cashFlowOnly;
            this.notCashFlowOnly = notCashFlowOnly;
            this.needCheckTransaction = needCheckTransaction;
            this.needCheckSettingAccounts = needCheckSettingAccounts;
        }
    }

}