public with sharing class GLAccountActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static String ERP_PACKAGE_QUALIFIER = GlobalVariables.ERPPACKAGE_QUALIFIER;
    //=== TYPE picklist values =======================================================
    public static final String GL_ACCOUNT_TYPE_BALANCE_SHEET = 'Balance Sheet';
    public static final String GL_ACCOUNT_TYPE_REVENUE = 'Revenue';
    public static final String GL_ACCOUNT_TYPE_EXPENSE = 'Expense';
    public static final String GL_ACCOUNT_TYPE_CASH_FLOW = 'Cash Flow';
    //=== SUB TYPE 1 picklist values ==================================================
    public static final String GL_ACCOUNT_SUB_TYPE_1_OPERATING = 'Operating';
    public static final String GL_ACCOUNT_SUB_TYPE_1_INVESTING = 'Investing';
    public static final String GL_ACCOUNT_SUB_TYPE_1_FINANCING = 'Financing';
    public static final String GL_ACCOUNT_SUB_TYPE_1_ASSETS = 'Assets';
    public static final String GL_ACCOUNT_SUB_TYPE_1_LIABILITIES = 'Liabilities';
    public static final String GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY = 'Owners Equity';


    public static final String TYPE_CHANGE_ERROR = Label.ERR_TYPE_CHANGE_GL_RECORD;
    public static final String SUB_TYPE_1_CHANGE_ERROR = Label.ERR_SUBTYPE_CHANGE_GL_RECORD;
    public static final String TYPE_PICKLIST_ERROR = Label.ERR_TYPE_PICKLIST;
    public static final String CATEGORY_PICKLIST_INPUT_ERROR = Label.ERR_CATEGORY_PICKLIST_INPUT;
    public static final String CATEGORY_PICKLIST_OUTPUT_ERROR = Label.ERR_CATEGORY_PICKLIST_OUTPUT;
    public static final String NON_VALID_TYPE_ERROR = Label.ERR_NON_VALID_TYPE_GL_ACCOUNT_BALANCE;
    public static final String NOT_LIABILITIES_SUB_TYPE_1_ERROR = Label.ERR_NOT_LIABILITIES_SUB_TYPE_1;
    public static final String SUB_TYPE_1_PICKLIST_ERROR = Label.ERR_TYPE_BALANCE_SHEET_SUB_TYPE_1;
    public static final String CASH_FLOW_SUB_TYPE_1_PICKLIST_ERROR = Label.ERR_CASH_FLOW_SUB_TYPE_1;
    public static final String BANK_CHANGE_FIN_CUBES_EXISTED_ERROR = Label.ERR_BANK_CHANGE_FIN_CUBES_EXISTED;
    public static final String GL_CATEGORY_CHANGE_ERROR = Label.ERR_EDIT_GL_ACCOUNT_CATEGORY;

    private static final Set<String> typeFieldValueSet = new Set<String>{'Revenue', 'Expense', 'Balance Sheet', 'Cash Flow'};
    private static final Set<String> subType1FieldValueSet = new Set<String>{
        GL_ACCOUNT_SUB_TYPE_1_ASSETS, GL_ACCOUNT_SUB_TYPE_1_LIABILITIES, GL_ACCOUNT_SUB_TYPE_1_OWNERS_EQUITY
    };
    private static final Set<String> subType1CashFlowFieldValueSet = new Set<String>{
        GL_ACCOUNT_SUB_TYPE_1_OPERATING, GL_ACCOUNT_SUB_TYPE_1_INVESTING, GL_ACCOUNT_SUB_TYPE_1_FINANCING
    };
    public static final String DELETE_ERROR = Label.ERR_DELETE_GL_ACCOUNT;
    public static Boolean isPreventUpdateOverride = false;
    @TestVisible
    private static final Integer GL_ACCOUNT_TOTAL_LIMIT = FeatureManagementHandler.getCurrentGlAccountLimit();
    @TestVisible
    private static final String GL_ACCOUNT_MAX_LIMIT_REACHED = String.format(Label.ERR_GL_ACCOUNT_MAX_LIMIT_REACHED, 
                                                                            new List<Object>{ GL_ACCOUNT_TOTAL_LIMIT });

    public static final List<String> relatedObjectForDeleteValidation {
        get {
            relatedObjectForDeleteValidation = new List<String> {
                PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c',
                PACKAGE_QUALIFIER + 'Account_Payable_Line__c',
                PACKAGE_QUALIFIER + 'Billing_Line__c',
                PACKAGE_QUALIFIER + 'Cash_Receipt__c',
                PACKAGE_QUALIFIER + 'Cash_Disbursement__c',
                PACKAGE_QUALIFIER + 'Expense_Line__c',
                PACKAGE_QUALIFIER + 'Journal_Entry_Line__c',
                PACKAGE_QUALIFIER + 'Recurring_Account_Payable_Line__c',
                PACKAGE_QUALIFIER + 'Recurring_Billing_Line__c',
                PACKAGE_QUALIFIER + 'Recurring_Journal_Entry_Line__c',
                PACKAGE_QUALIFIER + 'Financial_Cube__c',
                PACKAGE_QUALIFIER + 'Ledger__c'
            };

            if (AccountingSettingsHandler.isERPEnabled()) {
                relatedObjectForDeleteValidation.add(ERP_PACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c');
                relatedObjectForDeleteValidation.add(ERP_PACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c');
            }
            return relatedObjectForDeleteValidation;
        }
        private set;
    }

    public static void requireFields(List<GL_Account__c> glAccounts) {
        for (GL_Account__c gLAccount : glAccounts) {
            if (glAccount.Type__c == NULL) {
                glAccount.Type__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    // Prevent changing the type field if there are associated financial cubes
    public static void preventChangeTypeField(Map<Id, GL_Account__c> oldGlAccountMap, Map<Id, GL_Account__c> newGlAccountMap) {
        if (isPreventUpdateOverride) {
            return;
        }

        Set<Id> glAccountTypeChangedSet = new Set<Id>();
        Set<Id> glAccountSubType1ChangedSet = new Set<Id>();

        for (GL_Account__c newGLAccount : newGlAccountMap.values()) {
            GL_Account__c oldGlAccount = oldGlAccountMap.get(newGlAccount.Id);

            if (oldGlAccount.Type__c != newGlAccount.Type__c && typeFieldValueSet.contains(oldGlAccount.Type__c)) {
                glAccountTypeChangedSet.add(newGlAccount.Id);
            }

            if (oldGlAccount.Type__c == newGLAccount.Type__c
                    && newGLAccount.Type__c == 'Balance Sheet'
                    && oldGlAccount.Sub_Type_1__c != NULL
                    && oldGlAccount.Sub_Type_1__c != newGLAccount.Sub_Type_1__c) {

                glAccountSubType1ChangedSet.add(newGlAccount.Id);
            }
        }

        Set<Id> commonGLAccountIdSet = new Set<Id>();
        commonGLAccountIdSet.addAll(glAccountTypeChangedSet);
        commonGLAccountIdSet.addAll(glAccountSubType1ChangedSet);

        for (Financial_Cube__c fc : DomainUtils.getFinancialCubesByGLAccount(commonGLAccountIdSet)) {
            newGlAccountMap.get(fc.GL_Account__c).addError(
                (glAccountTypeChangedSet.contains(fc.GL_Account__c)) ? TYPE_CHANGE_ERROR : SUB_TYPE_1_CHANGE_ERROR,
                false
            );
        }
    }

    // Prevent changing the type field to "Cash Flow" if there are associated financial statement rows
    public static void preventChangeTypeToCashFlowIfReportRowsExist(Map<Id, GL_Account__c> oldGlAccountMap, Map<Id, GL_Account__c> newGlAccountMap) {
        if (isPreventUpdateOverride) {
            return;
        }
        Set<Id> glAccountSet = new Set<Id>();

        for (GL_Account__c newGLAccount : newGlAccountMap.values()) {
            GL_Account__c oldGlAccount = oldGlAccountMap.get(newGlAccount.Id);

            if (oldGlAccount.Type__c != 'Cash Flow' && newGLAccount.Type__c == 'Cash Flow') {
                glAccountSet.add(newGlAccount.Id);
            }
        }

        for (Financial_Report_Row__c frr : DomainUtils.getFinancialReportRowsByGLAccountId(glAccountSet)) {
            newGlAccountMap.get(frr.GL_Account__c)
                .addError(FinancialReportRowActions.CASH_FLOW_RELATED_GL_ACCOUNT_ERROR, false);
        }
    }
    
    // Validate picklist values are in defined range
    public static void validatePicklistValues(List<GL_Account__c> glAccounts, Map<Id, GL_Account__c> oldGLAccountsMap) {

        Boolean isUpdate = (oldGLAccountsMap != NULL) ? true : false;
        
        for (GL_Account__c gLAccount : glAccounts) {

            if (isUpdate) {//AFTER UPDATE

                if (gLAccount.Type__c != NULL
                        && !typeFieldValueSet.contains(glAccount.Type__c)
                        && typeFieldValueSet.contains(oldGLAccountsMap.get(gLAccount.Id).Type__c)) {

                    gLAccount.Type__c.addError(TYPE_PICKLIST_ERROR);
                }

                if (glAccount.Type__c == 'Balance Sheet'
                        && !subType1FieldValueSet.contains(glAccount.Sub_Type_1__c)
                        /* Legacy support (prior to Sub Type 1 restrictions)
                        *  1. When Sub Type 1 is changed from valid value to a wrong value
                        *  2. When Type is changed
                        */
                        && (oldGLAccountsMap.get(gLAccount.Id).Type__c != glAccount.Type__c
                                || subType1FieldValueSet.contains(oldGLAccountsMap.get(gLAccount.Id).Sub_Type_1__c))) {

                    gLAccount.Sub_Type_1__c.addError(SUB_TYPE_1_PICKLIST_ERROR);
                }

                if (glAccount.Type__c == 'Cash Flow'
                        && !subType1CashFlowFieldValueSet.contains(glAccount.Sub_Type_1__c)
                        && subType1CashFlowFieldValueSet.contains(oldGLAccountsMap.get(gLAccount.Id).Sub_Type_1__c)) {
                    gLAccount.Sub_Type_1__c.addError(CASH_FLOW_SUB_TYPE_1_PICKLIST_ERROR);
                }

                if (glAccount.GL_Category__c == 'Input VAT' || glAccount.GL_Category__c == 'Output VAT') {
                    if (glAccount.Type__c != 'Balance Sheet') {
                        glAccount.Type__c.addError(NON_VALID_TYPE_ERROR);                        
                    }
                    if (glAccount.Sub_Type_1__c != 'Liabilities') {
                        glAccount.Sub_Type_1__c.addError(NOT_LIABILITIES_SUB_TYPE_1_ERROR);
                    }
                }

            } else {//AFTER INSERT

                if (glAccount.Type__c != NULL && !typeFieldValueSet.contains(glAccount.Type__c)) {
                    gLAccount.Type__c.addError(TYPE_PICKLIST_ERROR);
                }

                if (glAccount.Type__c == 'Balance Sheet' && !subType1FieldValueSet.contains(glAccount.Sub_Type_1__c)) {
                    gLAccount.Sub_Type_1__c.addError(SUB_TYPE_1_PICKLIST_ERROR);
                }

                if (glAccount.Type__c == 'Cash Flow' && !subType1CashFlowFieldValueSet.contains(glAccount.Sub_Type_1__c)) {
                    gLAccount.Sub_Type_1__c.addError(CASH_FLOW_SUB_TYPE_1_PICKLIST_ERROR);
                }
                if (glAccount.GL_Category__c == 'Input VAT' || glAccount.GL_Category__c == 'Output VAT') {
                    if (glAccount.Type__c != 'Balance Sheet') {
                        glAccount.Type__c.addError(NON_VALID_TYPE_ERROR);                        
                    }
                    if (glAccount.Sub_Type_1__c != 'Liabilities') {
                        glAccount.Sub_Type_1__c.addError(NOT_LIABILITIES_SUB_TYPE_1_ERROR);
                    }
                }

            }

        }

    }

    public static void validateInputOutputGLAccounts(List<GL_Account__c> glAccounts, Map<Id, GL_Account__c> oldGLAccountsMap) {

        Boolean isUpdate = (oldGLAccountsMap != NULL) ? true : false;
        List<Gl_Account__c> existingInputOutputGlAccounts = DomainUtils.getInputOutputGLAccounts();
        Map<String, Integer> glAccountCountsByGlCategory = DomainUtils.countGLAccountsByGlCategory(existingInputOutputGlAccounts);

        Integer inputGLCount = glAccountCountsByGlCategory.get('Input VAT');
        if (inputGLCount == null) {
            inputGLCount = 0;
        }
        Integer outputGLCount = glAccountCountsByGlCategory.get('Output VAT');
        if (outputGLCount == null) {
            outputGLCount = 0;
        }
        for (GL_Account__c gLAccount : glAccounts) {
            if (!isUpdate || (isUpdate && gLAccount.GL_Category__c != oldGLAccountsMap.get(gLAccount.Id).GL_Category__c)) {
                if (gLAccount.GL_Category__c == 'Input VAT') {
                    if (inputGLCount > 0) {
                        gLAccount.GL_Category__c.addError(CATEGORY_PICKLIST_INPUT_ERROR);
                    }
                    else {
                        inputGLCount++;
                    }
                }                    
                else if (gLAccount.GL_Category__c == 'Output VAT') {
                    if (outputGLCount > 0) {
                        gLAccount.GL_Category__c.addError(CATEGORY_PICKLIST_OUTPUT_ERROR);
                    }
                    else {
                        outputGLCount++;
                    }
                }          
            }
        }
    }

    public static void preventChangeBankCheckboxIfCubesExist(List<GL_Account__c> newGlAccounts, Map<Id, GL_Account__c> oldGlAccountMap) {
        if (isPreventUpdateOverride) {
            return;
        }

        Set<Id> glAccountIds = new Set<Id>();
        for (GL_Account__c newGLA : newGlAccounts) {
            GL_Account__c oldGlAccount = oldGlAccountMap.get(newGLA.Id);
            if (newGLA.Bank__c != oldGlAccount.Bank__c) {
                glAccountIds.add(newGLA.Id);
            }
        }

        if (!glAccountIds.isEmpty()) {
            Map<Id, List<Financial_Cube__c>> cubeMap = new Map<Id, List<Financial_Cube__c>>();
            for (Financial_Cube__c cube : DomainUtils.getFinancialCubesByGLAccount(glAccountIds)) {
                if (cubeMap.containsKey(cube.GL_Account__c)) {
                    cubeMap.get(cube.GL_Account__c).add(cube);
                }
                else {
                    cubeMap.put(cube.GL_Account__c, new List<Financial_Cube__c> {cube});
                }
            }

            for (GL_Account__c newGLA : newGlAccounts) {
                if (cubeMap.containsKey(newGLA.Id) && !cubeMap.get(newGLA.Id).isEmpty()) {
                    newGLA.Bank__c.addError(BANK_CHANGE_FIN_CUBES_EXISTED_ERROR);
                }
            }
        }

    }

    public static void preventChangeGLCategoryIfCubesExist(List<GL_Account__c> newGlAccounts, Map<Id, GL_Account__c> oldGlAccountMap) {
        if (isPreventUpdateOverride) {
            return;
        }

        Set<Id> glAccountIds = new Set<Id>();
        for (GL_Account__c newGLA : newGlAccounts) {
            GL_Account__c oldGlAccount = oldGlAccountMap.get(newGLA.Id);
            if (newGLA.GL_Category__c != oldGlAccount.GL_Category__c) {
                glAccountIds.add(newGLA.Id);
            }
        }

        if (!glAccountIds.isEmpty()) {
            Map<Id, List<Financial_Cube__c>> cubeMap = new Map<Id, List<Financial_Cube__c>>();
            for (Financial_Cube__c cube : DomainUtils.getFinancialCubesByGLAccount(glAccountIds)) {
                if (cubeMap.containsKey(cube.GL_Account__c)) {
                    cubeMap.get(cube.GL_Account__c).add(cube);
                }
                else {
                    cubeMap.put(cube.GL_Account__c, new List<Financial_Cube__c> {cube});
                }
            }

            for (GL_Account__c newGLA : newGlAccounts) {
                if (cubeMap.containsKey(newGLA.Id) && !cubeMap.get(newGLA.Id).isEmpty()) {
                    newGLA.GL_Category__c.addError(GL_CATEGORY_CHANGE_ERROR);
                }
            }
        }

    }

    public static void preventDeleteIfRelatedRecordsExist(Map<Id, GL_Account__c> oldGLAccountMap) {
        Set<Id> glAccountIdsHavingRelatedRecs = new Set<Id> ();
        Schema.DescribeSObjectResult glAccountDescribe = Schema.getGlobalDescribe()
            .get(String.valueOf(GL_Account__c.SObjectType))
            .getDescribe();

        List<Schema.ChildRelationship> glAccountRelationships = glAccountDescribe.getChildRelationships();
        Set<Id> glAccountIdsToValidate = new Set<Id>(oldGLAccountMap.keySet());

        for (Schema.ChildRelationship glAccountRelationship : glAccountRelationships) {
            //any GL Account record will be validated only if it was not defined as not valid during prior loop steps
            if (!glAccountIdsToValidate.isEmpty()
                && isFieldFromAccountingSeedNamespace(glAccountRelationship.getField().getDescribe().getName())
                && relatedObjectForDeleteValidation.contains(glAccountRelationship.getChildSObject().getDescribe().getName())) {

                Map<Id, AggregateResult> results = new Map<Id, AggregateResult>(
                    DomainUtils.getRelatedObjectCountByApiNameAndLookupName(
                        glAccountIdsToValidate,
                        glAccountRelationship.getChildSObject().getDescribe().getName(),
                        glAccountRelationship.getField().getDescribe().getName()
                    )
                );

                for (Id resId : results.keySet()) {
                    if (results.get(resId).get('itemCount') != 0) {
                        //to add DML Error on specific record later
                        glAccountIdsHavingRelatedRecs.add(resId);
                        //to not make redundant checks (by next child relationship) when its already not valid
                        glAccountIdsToValidate.remove(resId);
                    }
                }
            }
        }

        if (!glAccountIdsHavingRelatedRecs.isEmpty()) {
            for (Id oldGLAccountId : glAccountIdsHavingRelatedRecs) {
                oldGLAccountMap.get(oldGLAccountId).addError(DELETE_ERROR);
            }
        }

    }

    public static Boolean isFieldFromAccountingSeedNamespace(String fieldApiName) {
        Boolean result = false;
        if (fieldApiName.containsIgnoreCase(PACKAGE_QUALIFIER)
                || (AccountingSettingsHandler.isERPEnabled()
                && fieldApiName.containsIgnoreCase(ERP_PACKAGE_QUALIFIER))) {

            result = true;
        }
        return result;
    }

    public static void validateTotalLimit(List<GL_Account__c> newGlAccounts) {
        Integer totalNmbOfGlAccounts = DomainUtils.countActiveGlAccounts(
            new List<String>{
                GLAccountActions.GL_ACCOUNT_TYPE_REVENUE,
                GLAccountActions.GL_ACCOUNT_TYPE_EXPENSE,
                GLAccountActions.GL_ACCOUNT_TYPE_BALANCE_SHEET
            }
        );
        if (totalNmbOfGlAccounts > GL_ACCOUNT_TOTAL_LIMIT) {
            for (GL_Account__c glAccount : newGlAccounts) {
                glAccount.addError(GL_ACCOUNT_MAX_LIMIT_REACHED);
            }
        }
    }

}