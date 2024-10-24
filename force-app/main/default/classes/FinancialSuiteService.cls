global with sharing class FinancialSuiteService implements Callable {

    private static final String AUTHORIZATION_ERROR = Label.COMMON_AUTHORIZATION_ERROR;
    private static final String ERP_SERVICE_CLASS = 'AcctSeedERP.ERPFinancialSuiteService';
    private static final String NPSP_SERVICE_CLASS = 'AcctSeedExt.NPSPFinancialSuiteService';
    @TestVisible
    private static String AVAVAT_SERVICE_CLASS = 'AcctSeedExt.AvalaraVATFinancialSuiteService';
    private Map<String, Object> data;

    public with sharing class FinancialSuiteServiceException extends Exception {}

    //OUTBOUND CALL
    private static Object callERP(String action, Map<String, Object> args) {
        Object result;
        try {
            args.put(
                'authKey',
                EncodingUtil.base64Encode(
                    Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
                ));

            Callable instance = (Callable) Type.forName(ERP_SERVICE_CLASS).newInstance();
            result = instance.call(action, args);
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //OUTBOUND CALL
    private static Object callNPSP(String action, Map<String, Object> args) {
        Object result;
        try {
            args.put(
                'authKey',
                EncodingUtil.base64Encode(
                    Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
                ));

            Type typeForName = Type.forName(NPSP_SERVICE_CLASS);
            if (typeForName != NULL) {
                Callable instance = (Callable) typeForName.newInstance();
                result = instance.call(action, args);
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //OUTBOUND CALL
    private static Object callAvaVAT(String action, Map<String, Object> args) {
        Object result;
        try {
            args.put(
                'authKey',
                EncodingUtil.base64Encode(
                    Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
                ));

            Type typeForName = Type.forName(AVAVAT_SERVICE_CLASS);
            if (typeForName != NULL) {
                Callable instance = (Callable) typeForName.newInstance();
                result = instance.call(action, args);
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    public static void executeInventoryMovementsPostBatchChain(
        List<AbstractSourceRecordPostBatch.SourceRecordType> erpTypes,
        List<AbstractSourceRecordPostBatch.ScheduledPostExecutionReport> executionReports) {

        Map<String, Object> args = new Map<String, Object>();
        String action = 'executeAutomatedPostJob';
        args.put('sourceRecordTypes', JSON.serialize(erpTypes));
        args.put('executionReports', JSON.serialize(executionReports));
        FinancialSuiteService.callERP(action, args);
    }
  
    //Callout to ERP to create Inventory Histories for a given period
    public static void executeInventoryHistoryCreateBatch(List<Date> closedDateToProcess) {
        Map<String, Object> args = new Map<String, Object>();
        String action = 'executeInventoryHistoryCreateBatch';
        args.put('historyDates', JSON.serialize(closedDateToProcess));
        FinancialSuiteService.callERP(action, args);
    }

    //Callout to ERP to create Inventory Histories for a given period
    public static void executeInventoryHistoryDeleteBatch(List<Date> historyDates) {
        Map<String, Object> args = new Map<String, Object>();
        String action = 'executeInventoryHistoryDeleteBatch';
        args.put('historyDates', JSON.serialize(historyDates));
        FinancialSuiteService.callERP(action, args);
    }

    public static void executeFinancialTransactionsBatchChain() {
        Map<String, Object> args = new Map<String, Object>();
        String action = 'executeNPSPOpportunityJournalEntriesBatchJob';
        args.put('jobFriendlyName', 'NPSP Opportunity Journal Entries');
        FinancialSuiteService.callNPSP(action, args);
    }

    public static void validateAvaVATLedgerSettings(List<Ledger__c> ledgers) {
        if (AccountingSettingsHandler.isAvaVATReportingEnabled()) {
            Map<String, Object> args = new Map<String, Object>();
            String action = 'validateAvaVATLedgerSettings';
            args.put('ledgers', ledgers);
            FinancialSuiteService.callAvaVAT(action, args);
        }
    }

    public static void validateVATCountryReportable(List<SObject> invLines) {
        if (AccountingSettingsHandler.isAvaVATReportingEnabled()) {
            Map<String, Object> args = new Map<String, Object>();
            String action = 'validateVATCountryReportable';
            args.put('invLines', invLines);
            FinancialSuiteService.callAvaVAT(action, args);
        }
    }

    public static void submitBillingsToAvaVAT(List<Id> billingIds, PostResultDispatcher.ExecutionContext execContext) {
        if (AccountingSettingsHandler.isAvaVATReportingEnabled()) {
            Map<String, Object> args = new Map<String, Object>();
            String action = 'submitBillingsToAvaVAT';
            args.put('billingIds', billingIds);
            args.put('postAction', execContext.name().toUpperCase());
            FinancialSuiteService.callAvaVAT(action, args);
        }
    }

    public static void submitPayablesToAvaVAT(List<Id> payableIds, PostResultDispatcher.ExecutionContext execContext) {
        if (AccountingSettingsHandler.isAvaVATReportingEnabled()) {
            Map<String, Object> args = new Map<String, Object>();
            String action = 'submitPayablesToAvaVAT';
            args.put('payableIds', payableIds);
            args.put('postAction', execContext.name().toUpperCase());
            FinancialSuiteService.callAvaVAT(action, args);
        }
    }

    //INBOUND CALL
    public Object call(String action, Map<String, Object> args) {
        Object result;
        try {
            if (String.isBlank(action) || args == NULL) {
                throw new FinancialSuiteServiceException(Label.COMMON_MISSING_ARGUMENTS);
            }
            checkAuthKey(action, (String) args.get('authKey'));
            result = invokeAction(action, args);
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private void checkAuthKey(String action, String authKey) {
        try {
            if (EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))) != authKey) {
                throw new FinancialSuiteServiceException(AUTHORIZATION_ERROR);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private Object invokeAction(String action, Map<String, Object> args) {
        try {
            switch on action {
                when 'updateAccountingSettings' {
                    AccountingSettingsActions.isPreventUpdateOverride = setBypass(args);
                    AccountingSettingsActions.skipAvalaraFieldsUpdateValidation = setBypass(args);
                    SFDCSecurityUtils.updateProxy((Accounting_Settings__c) args.get('data'));
                    return new RestResult(true, NULL, NULL);
                }
                when 'updateLedgers' {
                    LedgerActions.isPreventUpdateOverride = setBypass(args);
                    SFDCSecurityUtils.updateProxy((List<Ledger__c>) args.get('data'));
                    return new RestResult(true, NULL, NULL);
                }
                when 'updateGLAccount' {
                    GLAccountActions.isPreventUpdateOverride = setBypass(args);
                    SFDCSecurityUtils.updateProxy((List<GL_Account__c>) args.get('data'));
                    return new RestResult(true, NULL, NULL);
                }
                when 'updateGLAM' {
                    GLAccountMappingActions.isDmlRestrictionBypassEnabled = setBypass(args);
                    SFDCSecurityUtils.updateProxy((GL_Account_Mapping__c) args.get('data'));
                    return new RestResult(true, NULL, NULL);
                }
                when 'insertTaxRates' {
                    TaxRateActions.isPreventUpdateOverride = setBypass(args);
                    SFDCSecurityUtils.insertProxy((List<Tax_Rate__c>) args.get('data'));
                    return new RestResult(true, NULL, NULL);
                }
                when 'updateTaxRates' {
                    TaxRateActions.isPreventUpdateOverride = setBypass(args);
                    SFDCSecurityUtils.updateProxy((List<Tax_Rate__c>) args.get('data'));
                    return new RestResult(true, NULL, NULL);
                }
                when 'query' {
                    return query(args);
                }
                when 'dmlAction' {
                    return dmlAction(args);
                }
                when 'createBilling' {
                    return createBilling(args);
                }
                when 'createBillingAndPost' {
                    return createBillingAndPost(args);
                }
                when 'inventoryCostAction' {
                    return inventoryCostAction(args);
                }
                when 'multiCurrencyAction' {
                    return multiCurrencyAction(args);
                }
                when 'accountingSettingHandlerAction' {
                    return accountingSettingHandlerAction(args);
                }
                when 'ledgerHandlerAction' {
                    return ledgerHandlerAction(args);
                }
                when 'glAccountValidator' {
                    return glAccountValidatorAction(args);
                }
                when 'testDataSuiteAction' {
                    return testDataSuiteAction(args);
                }
                when 'automatedJobResultsHandler' {
                    return automatedJobResultsHandlerAction(args);
                }
                when 'redirectToSObjectURL' {
                    Id recordId = (Id) args.get('recordId');
                    SObjectType soType = (SObjectType) args.get('sobjectType');
                    Boolean toEdit = (Boolean) args.get('toEdit');
                    return FinancialSuiteUtils.getRedirectToSObjectURL(recordId, soType, toEdit);
                }
                when 'statementManager'{
                    return statementManagerAction(args);
                }
                when 'glAccountDefaults' {
                    GLAccountDefaultActions.isPreventUpdateOverride = setBypass(args);
                    return new RestResult(true, NULL, NULL);
                }
                when 'glAccountDefaultsAction' {
                    return glAccountDefaultsAction(args);
                }
                when 'ledServiceSend' {
                    LEDService.sendData();
                    return new RestResult(true, NULL, NULL);
                }
                when else {
                    throw new FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    private void parseArguments(Map<String, Object> args) {
        data = (Map<String, Object>) args.get('data');
    }

    private Boolean setBypass(Map<String, Object> args) {
        Boolean result = true;
        if (((Boolean) args.get('bypass')) != NULL) {
            result = (Boolean) args.get('bypass');
        }
        return result;
    }

    //================ QUERY ACTION ============================================================

    private Object query(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String objName = (String) data.get('sobjectType');
            SObject obj = (SObject) Type.forName(objName).newInstance();
            result = getSOQLString(obj);
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    private String getSOQLString(SObject obj) {
        SOQLBuilder builder = new SOQLBuilder(obj.getSObjectType());
        SOQLBuilder subQueryBuilder;
        // set primary CRUD and FLS condition
        if ((Boolean) data.get('queryIsAccessible') != false) {
            builder.assertIsAccessible();
        }

        if ((Boolean) data.get('querySetEnforceFLS') == false) {
            builder.setEnforceFLS(false);
        }
        else {
            builder.setEnforceFLS(true);
        }
        // set primary Field list
        if ((List<String>) data.get('queryFields') != NULL && !((List<String>) data.get('queryFields')).isEmpty()) {
            builder.selectFields((List<String>) data.get('queryFields'));
        }
        if (String.isNotBlank((String) data.get('queryCondition'))) {
            builder.setCondition((String) data.get('queryCondition'));
        }
        if ((List<String>) data.get('queryOrdering') != NULL && !((List<String>) data.get('queryOrdering')).isEmpty()) {
            String fieldName = ((List<String>) data.get('queryOrdering')).size() > 1 ? ((List<String>) data.get('queryOrdering'))[1]  : 'Name';
            builder.addOrdering(fieldName,SOQLBuilder.SortOrder.ASCENDING) ;
        }
        if ((Integer) data.get('queryLimit') != NULL) {
            builder.setLimit((Integer) data.get('queryLimit')) ;
        }
        // set secondary Relationships Name
        if (String.isNotBlank((String) data.get('subQueryObjName'))) {
            Boolean subQueryIsAccessible = (Boolean) data.get('subQueryIsAccessible') != false ? true : false;
            subQueryBuilder = builder.subselectQuery((String) data.get('subQueryObjName'), subQueryIsAccessible);
            // set secondary CRUD and FLS condition
            if ((Boolean) data.get('subQuerySetEnforceFLS') == false) {
                subQueryBuilder.setEnforceFLS(false);
            }
            else {
                subQueryBuilder.setEnforceFLS(true);
            }
            // set secondary Field list
            if ((List<String>) data.get('subQueryFields') != NULL && !((List<String>) data.get('subQueryFields')).isEmpty()) {
                subQueryBuilder.selectFields((List<String>) data.get('subQueryFields'));
            }
            if (String.isNotBlank((String) data.get('subQueryCondition'))) {
                subQueryBuilder.setCondition((String) data.get('subQueryCondition'));
            }
            if ((Integer) data.get('subQueryLimit') != NULL) {
                subQueryBuilder.setLimit((Integer) data.get('subQueryLimit'));
            }
            if ((List<String>) data.get('subQueryOrdering') != NULL && !((List<String>) data.get('subQueryOrdering')).isEmpty()) {
                String objectName = ((List<String>) data.get('subQueryOrdering'))[0];
                String fieldName = ((List<String>) data.get('subQueryOrdering')).size() > 1 ? ((List<String>) data.get('subQueryOrdering'))[1] : 'Name';
                SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering(objectName, fieldName, SOQLBuilder.SortOrder.ASCENDING);
                subQueryBuilder.addOrdering(ordering) ;
            }
        }

        return builder.toSOQL();
    }

    //================ DML ACTION =============================================================

    private Object dmlAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            List<SObject> objects = (List<SObject>) data.get('objects');
            List<String> fieldsList = (List<String>) data.get('fieldsList');
            Set<SObjectField> unlockedFields =
                data.containsKey('unlockedFields') ? (Set<SObjectField>) data.get('unlockedFields') : new Set<SObjectField>();
            TriggerObserver.getInstance().unlockFields(unlockedFields);
            
            Boolean hasAllOrNone = data.containsKey('allOrNone');
            Boolean allOrNone = false;
            if (hasAllOrNone) {
                allOrNone = (Boolean)data.get('allOrNone');
            }
            switch on method {
                when 'insertCheckCRUDAndFLS' {
                    result = hasAllOrNone ? SFDCSecurityUtils.insertCheckCRUDAndFLS(objects, fieldsList, allOrNone) : SFDCSecurityUtils.insertCheckCRUDAndFLS(objects, fieldsList);
                }
                when 'updateCheckCRUDAndFLS' {
                    result = hasAllOrNone ? SFDCSecurityUtils.updateCheckCRUDAndFLS(objects, fieldsList, allOrNone) : SFDCSecurityUtils.updateCheckCRUDAndFLS(objects, fieldsList);
                }
                when 'upsertCheckCRUDAndFLS' {
                    result = hasAllOrNone ? SFDCSecurityUtils.upsertCheckCRUDAndFLS(objects, fieldsList, allOrNone) : SFDCSecurityUtils.upsertCheckCRUDAndFLS(objects, fieldsList);
                }
                when 'deleteCheckCRUDAndFLS' {
                    result = hasAllOrNone ? SFDCSecurityUtils.deleteCheckCRUDAndFLS(objects, allOrNone) : SFDCSecurityUtils.deleteCheckCRUDAndFLS(objects);
                }
                when 'insertProxy' {
                    SFDCSecurityUtils.insertProxy(objects);
                    return new RestResult(true, NULL, NULL);
                }
                when 'updateProxy' {
                    SFDCSecurityUtils.updateProxy(objects);
                    return new RestResult(true, NULL, NULL);
                }
                when 'upsertProxy' {
                    SFDCSecurityUtils.upsertProxy(objects);
                    return new RestResult(true, NULL, NULL);
                }
                when 'deleteProxy' {
                    SFDCSecurityUtils.deleteProxy(objects);
                    return new RestResult(true, NULL, NULL);
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ CREATE BILLING ACTION ===============================================

    private Object createBilling(Map<String, Object> args) {
        Object result;
        try {
            result = BillingCreateService.createBilling(getBillingModel(args));
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    private Object createBillingAndPost(Map<String, Object> args) {
        Object result;
        try {
            result = BillingCreateService.createBillingAndPost(getBillingModel(args));
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    private BillingCreateService.BillingModel getBillingModel(Map<String, Object> args) {
        BillingCreateService.BillingModel result;
        parseArguments(args);
        if (((String) data.get('billingModel')) != NULL) {
            String billModel = (String) data.get('billingModel');
            result = (BillingCreateService.BillingModel) JSON.deserialize(billModel, BillingCreateService.BillingModel.class);
        }
        return result;
    }

    //================ INVENTORY COST ACTION =======================================

    private Object inventoryCostAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            switch on method {
                when 'upsertInventoryCost' {
                    String objects = (String) data.get('objects');
                    List<InventoryCostHandler.InventoryMovement> imObject = (List<InventoryCostHandler.InventoryMovement>) JSON.deserialize(objects, List<InventoryCostHandler.InventoryMovement>.class);
                    InventoryCostHandler.upsertInventoryCost(imObject);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'createInvCostTransactionsExcludeKitChildProducts' {
                    List<InventoryTransactionHandler.InventoryTransactionSource> objects =
                        (List<InventoryTransactionHandler.InventoryTransactionSource>) JSON.deserialize((String) data.get('objects'), List<InventoryTransactionHandler.InventoryTransactionSource>.class);
                    InventoryTransactionHandler.createInvCostTransactionsExcludeKitChildProducts(objects);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'getProductUnitCost' {
                    Set<Id> objects = (Set<Id>) data.get('objects');
                    result = JSON.serialize(InventoryCostHandler.getInstance().getUnitCostByProductId(objects));
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ MULTI CURRENCY ACTION =======================================

    private Object multiCurrencyAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            switch on method {
                when 'setCurrencyConversionRateBySourceDocumentAndLedger' {
                    List<SObject> newRecords = (List<SObject>) data.get('objects');
                    Map<Id, SObject> oldRecordsMap = (Map<Id, SObject>) data.get('objectsMap');
                    String recordDateField = (String) data.get('objectDateField');
                    MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(oldRecordsMap, newRecords, recordDateField);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'isMultiCurrencyEnabled' {
                    result = MultiCurrencyHandler.isMultiCurrencyEnabled;
                }
                when 'getCorporateCurrency' {
                    result = MultiCurrencyHandler.CORPORATE_CURRENCY;
                }
                when 'validateCurrencyConversionRate' {
                    List<SObject> newRecords = (List<SObject>) data.get('objects');
                    SObjectActions.validateCurrencyConversionRate(newRecords);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'setISOCodeFromParent' {
                    List<SObject> newRecords = (List<SObject>) data.get('objects');
                    String masterRecordLookupField = (String) data.get('masterRecordLookupField');
                    SObjectActions.setISOCodeFromParent(newRecords, masterRecordLookupField);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'revertCurrencyIsoCodeIfNull' {
                    List<SObject> newRecords = (List<SObject>) data.get('newRecords');
                    Map<Id, SObject> oldRecordsMap = (Map<Id, SObject>) data.get('oldRecordsMap');
                    MultiCurrencyHandler.revertCurrencyIsoCodeIfNull(oldRecordsMap, newRecords);
                }
                when 'setCurrencyIsoCodeToUserCurrency' {
                    List<SObject> newRecords = (List<SObject>) data.get('objects');
                    MultiCurrencyHandler.setCurrencyIsoCodeToUserCurrency(newRecords);
                    result = new RestResult(true, NULL, NULL);
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ ACCOUNTING SETTING ACTION ======================================

    private Object accountingSettingHandlerAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            switch on method {
                when 'getAccountingSettings' {
                    result = AccountingSettingsHandler.getAccountingSettings();
                }
                when 'isERPEnabled' {
                    result = AccountingSettingsHandler.isERPEnabled();
                }
                when 'isWOEnabled' {
                    result = AccountingSettingsHandler.isWOEnabled();
                }
                when 'isInventoryValuationAverageCost' {
                    result = AccountingSettingsHandler.isInventoryValuationAverageCost();
                }
                when 'isInventoryValuationStandardCost' {
                    result = AccountingSettingsHandler.isInventoryValuationStandardCost();
                }
                when 'disableAutoPostSourceDocuments' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(false);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'enableAutoPostSourceDocuments' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(true);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'disableAutoPostAmortizationEntries' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Amortization_Entries__c, false);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'enableAutoPostAmortizationEntries' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Amortization_Entries__c, true);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'disableAutoPostAPDisbursements' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_AP_Disbursements__c, false);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'enableAutoPostAPDisbursements' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_AP_Disbursements__c, true);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'disableAutoPostBillingCashReceipts' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Billing_Cash_Receipts__c, false);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'enableAutoPostBillingCashReceipts' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Billing_Cash_Receipts__c, true);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'disableAutoPostCashReceipts' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Cash_Receipts__c, false);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'enableAutoPostCashReceipts' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Cash_Receipts__c, true);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'disableAutoPostInventoryMovements' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Inventory_Movements__c, false);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'enableAutoPostInventoryMovements' {
                    AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Inventory_Movements__c, true);
                    result = new RestResult(true, NULL, NULL);
                }
                when 'isAutoPostAmortizationEntriesEnabled' {
                    result = AccountingSettingsHandler.fetchAccountingSettingsValue(Accounting_Settings__c.Auto_Post_Amortization_Entries__c);
                }
                when 'isAutoPostAPDisbursementsEnabled' {
                    result = AccountingSettingsHandler.fetchAccountingSettingsValue(Accounting_Settings__c.Auto_Post_AP_Disbursements__c);
                }
                when 'isAutoPostBillingCashReceiptsEnabled' {
                    result = AccountingSettingsHandler.fetchAccountingSettingsValue(Accounting_Settings__c.Auto_Post_Billing_Cash_Receipts__c);
                }
                when 'isAutoPostCashReceiptsEnabled' {
                    result = AccountingSettingsHandler.fetchAccountingSettingsValue(Accounting_Settings__c.Auto_Post_Cash_Receipts__c);
                }
                when 'isAutoPostInventoryMovementsEnabled' {
                    result = AccountingSettingsHandler.fetchAccountingSettingsValue(Accounting_Settings__c.Auto_Post_Inventory_Movements__c);
                }
                when 'setHeaderLevelPostSettings' {
                    AccountingSettingsHandler.setHeaderLevelPost();
                    result = new RestResult(true, NULL, NULL);
                }
                when 'setLineLevelPostSettings' {
                    AccountingSettingsHandler.setLineLevelPost();
                }
                when 'isHeaderLevelPost' {
                    result = AccountingSettingsHandler.isHeaderLevelPost();
                }
                when 'resetAccountingSettings' {
                    AccountingSettingsHandler.resetAccountingSettings();
                    result = new RestResult(true, NULL, NULL);
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ GL ACCOUNT DEFAULTS ACTION ======================================

    private Object glAccountDefaultsAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            switch on method {
                when 'glAccountDefaultsByLedgerId' {
                    result = GLAccount.glAccountDefaultsMapByLedgerId((Set<Id>) data.get('ledgerIds'));
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ GL ACCOUNT VALIDATOR ACTION ======================================

    private Object glAccountValidatorAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');            
            switch on method {
                when 'validateGlAccountLookups' {
                    List<SObject> newRecords = (List<SObject>) data.get('objects');
                    Map<Id, SObject> oldRecordsMap = (Map<Id, SObject>) data.get('objectsMap');
                    GLAccountValidator.validateGlAccountLookups(newRecords, oldRecordsMap);
                    result = newRecords;
                }                
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ LEDGER HANDLER ACTION ======================================

    private Object ledgerHandlerAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            
            Boolean sharingContext = data.get('sharingContext') == NULL ? true : (Boolean) data.get('sharingContext');
            LedgerHandler ledgerHandlerInstance;

            if (sharingContext) {
                ledgerHandlerInstance = LedgerHandler.getInstanceWithSharing(true);
            }
            else {
                ledgerHandlerInstance = LedgerHandler.getInstanceWithoutSharing();
            }

            switch on method {
                when 'getAllLedgersMap' {
                    result = ledgerHandlerInstance.getAllLedgersMap();
                }
                when 'getTransactionalLedgers' {
                    result = ledgerHandlerInstance.getTransactionalLedgers();
                }
                when 'getBudgetLedgers' {
                    result = ledgerHandlerInstance.getBudgetLedgers();
                }
                when 'getLedgerById' {
                    result = ledgerHandlerInstance.getLedgerById((Set<Id>) data.get('ledgerIds'));
                }
                when 'getTransactionalLedgerSelectOptions' {
                    result = ledgerHandlerInstance.getTransactionalLedgerSelectOptions((Boolean) data.get('includeNone'));
                }
                when 'getBudgetLedgerSelectOptions' {
                    result = ledgerHandlerInstance.getBudgetLedgerSelectOptions();
                }
                when 'getLedgerCurrency' {
                    result = LedgerHandler.getLedgerCurrency((Id) data.get('ledgerId'));
                }
                when 'resetLedgerHandler' {
                    LedgerHandler.reset();
                    result = new RestResult(true, NULL, NULL);
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ TEST DATA SUITE ACTION =======================================

    private Object testDataSuiteAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            switch on method {
                when 'enableAvalaraVATReporting' {
                    result = TestService.enableAvalaraVATReporting();
                }
                when 'isAvalaraVATReportingEnabled' {
                    result = TestService.isAvalaraVATReportingEnabled();
                }
                when 'getTestData' {
                    result = TestService.getTestData();
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ AUTOMATED JOB RESULT HANDLER ACTION ======================================

    private Object automatedJobResultsHandlerAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            switch on method {
                when 'setJobType' {
                    AutomatedJobResultsHandler.setJobType((String) data.get('jobName'));
                    result = new RestResult(true, NULL, NULL);
                }
                when 'saveAutomatedJobResults' {
                    AutomatedJobResultsHandler.saveAutomatedJobResults();
                    result = new RestResult(true, NULL, NULL);
                }
                when 'addProcessed' {
                    AutomatedJobResultsHandler.addProcessed((Integer) data.get('count'));
                    result = new RestResult(true, NULL, NULL);
                }
                when 'addSucceeded' {
                    AutomatedJobResultsHandler.addSucceeded((Integer) data.get('count'));
                    result = new RestResult(true, NULL, NULL);
                }
                when 'addFailed' {
                    AutomatedJobResultsHandler.addFailed((Integer) data.get('count'));
                    result = new RestResult(true, NULL, NULL);
                }
                when 'setError' {
                    AutomatedJobResultsHandler.setError((String) data.get('errorValue'));
                    result = new RestResult(true, NULL, NULL);
                }
                when 'getReportLink' {
                    result = AutomatedJobResultsHandler.getReportLink((String) data.get('jobName'));
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

    //================ STATEMENT PDF ======================================

    private Object statementManagerAction(Map<String, Object> args) {
        Object result;
        try {
            parseArguments(args);
            String method = (String) data.get('method');
            switch on method {
                when 'formatFileName' {
                    result = AbstractStatementManager.formatFileName((String) data.get('customerName'), (String) data.get('typePrefix'), (String) data.get('recordName'));
                }
                when else {
                    throw new FinancialSuiteService.FinancialSuiteServiceException(Label.COMMON_METHOD_NOT_IMPLEMENTED);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }

}