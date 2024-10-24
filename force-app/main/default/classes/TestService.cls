global with sharing class TestService {
    @TestVisible
    private enum StatusCode {SETUP_TEST_DATA_NOT_EXECUTED, MULTI_CURRENCY_NOT_ENABLED}
    @TestVisible
    private static final String SETUP_TEST_DATA_NOT_EXECUTED_ERROR = Label.ERR_SETUP_TEST_DATA_NOT_EXECUTED;
    @TestVisible
    private static final String MULTI_CURRENCY_NOT_ENABLED = Label.ERR_MULTI_CURRENCY_NOT_ENABLED;
    @TestVisible
    private static Boolean isMultiCurrencyOrg = UserInfo.isMultiCurrencyOrganization();

    @TestVisible
    private ServiceResult serviceResult;
    @TestVisible
    private APIServiceContext.APIServiceEntry serviceEntry;

    public TestService () {
        serviceEntry = new APIServiceContext.APIServiceEntry();
        serviceEntry.isOnlyTestContextAccessible = true;
        serviceEntry.isRestContextAccessible = false;
    }

    /*************** GLOBAL METHODS (used as API entry points) *******************************/
    global static ServiceResult setupTestData() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.setupTestDataImpl(true, false, false);
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult setupTestData(Boolean isBaseInitNeeded, Boolean createStandardObjects, Boolean includeStandardFieldPerms) {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.setupTestDataImpl(isBaseInitNeeded, createStandardObjects, includeStandardFieldPerms);
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    public static ServiceResult getTestData() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.getTestDataImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult getUserActiveLedgerId() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.getUserActiveLedgerIdImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult setUserActiveLedgerId(Id ledgerId) {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.setUserActiveLedgerIdImpl(ledgerId);
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult getOrgDefaultLedgerId() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.getOrgDefaultLedgerIdImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult setOrgDefaultLedgerId(Id ledgerId) {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.setOrgDefaultLedgerIdImpl(ledgerId);
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static Integer getLedgerLimit() {
        TestService ts = new TestService();
        ServiceResult sr = APIServiceContext.validateServiceContext(ts.serviceEntry);
        Integer result;

        if (sr.isSuccess) {
            result = ts.getLedgerLimitImpl();
        }
        return result;
    }

    global static ServiceResult setLedgerLimit(Integer newLedgerLimit) {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.setLedgerLimitImpl(newLedgerLimit);
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult setInventoryValuationStandardCost() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.setInventoryValuationStandardCostImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult setInventoryValuationAverageCost() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.setInventoryValuationAverageCostImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult getInventoryValuation() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.getInventoryValuationImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult disableAutoPostSourceDocuments() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.disableAutoPostSourceDocumentsImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult enableAutoPostSourceDocuments() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.enableAutoPostSourceDocumentsImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult enableMultiCurrency() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.enableMultiCurrencyImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static ServiceResult enableAvalaraVATReporting() {
        ServiceResult serviceResult;
        try {
            TestService ts = new TestService();
            serviceResult = APIServiceContext.validateServiceContext(ts.serviceEntry);

            if (serviceResult.isSuccess) {
                serviceResult = ts.enableAvalaraVATReportingImpl();
            }
        }
        catch (Exception ex) {
            serviceResult = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return serviceResult;
    }

    global static Boolean isAvalaraVATReportingEnabled() {
        TestService ts = new TestService();
        ServiceResult sr = APIServiceContext.validateServiceContext(ts.serviceEntry);
        Boolean resBoolean;

        if (sr.isSuccess) {
            resBoolean = ts.isAvalaraVATReportingEnabledImpl();
        }
        return resBoolean;
    }

    global static Boolean isMultiCurrencyEnabled() {
        TestService ts = new TestService();
        ServiceResult sr = APIServiceContext.validateServiceContext(ts.serviceEntry);
        Boolean resBoolean;

        if (sr.isSuccess) {
            resBoolean = ts.isMultiCurrencyEnabledImpl();
        }
        return resBoolean;
    }

    /*************** INSTANCE METHODS (actual processing and response result composition) *******************/
    private ServiceResult getTestDataImpl() {
        if (validateSetupTestDataExecuted()) {
            Map<String, List<SObject>> data = buildTestDataMap(TestDataSuite.getInstance(), false);
            serviceResult = new ServiceResult(JSON.serialize(data), true);
        }
        return serviceResult;
    }

    private Map<String, List<SObject>> buildTestDataMap(TestDataSuite testData, Boolean includeStandardObjectsData) {
        Map<String, List<SObject>> resultMap = new Map<String, List<SObject>>();
        resultMap.put('accountingPeriods', testData.acctPeriods);
        resultMap.put('glAccounts', testData.glAccounts);
        resultMap.put('billingFormats', testData.billingFormats);
        resultMap.put('ledgers', testData.ledgers);
        resultMap.put('accountingSettings', new List<Accounting_Settings__c>{testData.settings});
        if (includeStandardObjectsData) {
            resultMap.put('accounts', testData.accounts);
            resultMap.put('contacts', testData.contacts);
            resultMap.put('opportunities', testData.opportunities);
        }
        return resultMap;
    }

    private ServiceResult setupTestDataImpl(Boolean isBaseInitNeeded, Boolean createStandardObjectData, Boolean includeStandardFieldPerms) {
        TestDataSuite testData;
        if (!isBaseInitNeeded && !validateSetupTestDataExecuted()) {
            testData = TestDataSuite.getInstance(true, createStandardObjectData, includeStandardFieldPerms);
        }
        else {
            testData = TestDataSuite.getInstance(isBaseInitNeeded, createStandardObjectData, includeStandardFieldPerms);
        }
        Map<String, List<SObject>> data = buildTestDataMap(testData, createStandardObjectData);
        serviceResult = new ServiceResult(JSON.serialize(data), true);
        return serviceResult;
    }

    private ServiceResult getUserActiveLedgerIdImpl() {
        if (validateSetupTestDataExecuted()) {
            serviceResult = new ServiceResult(LedgerService.getActiveLedgerId(), true);
        }
        return serviceResult;
    }

    private ServiceResult setUserActiveLedgerIdImpl(Id ledgerId) {
        if (validateSetupTestDataExecuted()) {
            LedgerService.setTestUserActiveLedger(ledgerId);
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private ServiceResult getOrgDefaultLedgerIdImpl() {
        if (validateSetupTestDataExecuted()) {
            serviceResult = new ServiceResult(LedgerService.getDefaultLedgerId(), true);
        }
        return serviceResult;
    }

    private ServiceResult setOrgDefaultLedgerIdImpl(Id ledgerId) {
        if (validateSetupTestDataExecuted()) {
            LedgerService.setTestOrgDefaultLedger(ledgerId);
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private Integer getLedgerLimitImpl() {
        if (validateSetupTestDataExecuted()) {
            return LedgerService.getLedgerLimit();
        }
        return NULL;
    }

    private ServiceResult setLedgerLimitImpl(Integer newLedgerLimit) {
        if (validateSetupTestDataExecuted()) {
            LedgerService.setLedgerLimit(
                newLedgerLimit,
                EncodingUtil.base64Encode(
                    Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
                )
            );
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private ServiceResult setInventoryValuationStandardCostImpl() {
        if (validateSetupTestDataExecuted()) {
            AccountingSettingsHandler.setInventoryValuationStandardCost();
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private ServiceResult setInventoryValuationAverageCostImpl() {
        if (validateSetupTestDataExecuted()) {
            AccountingSettingsHandler.setInventoryValuationAverageCost();
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private ServiceResult getInventoryValuationImpl() {
        if (validateSetupTestDataExecuted()) {
            serviceResult = new ServiceResult(
                AccountingSettingsHandler.getAccountingSettings().Inventory_Valuation_Method__c,
                true
            );
        }
        return serviceResult;
    }

    private ServiceResult disableAutoPostSourceDocumentsImpl() {
        if (validateSetupTestDataExecuted()) {
            AccountingSettingsHandler.setAutoPostSourceDocuments(false);
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private ServiceResult enableAutoPostSourceDocumentsImpl() {
        if (validateSetupTestDataExecuted()) {
            AccountingSettingsHandler.setAutoPostSourceDocuments(true);
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private ServiceResult enableMultiCurrencyImpl() {
        if (validateSetupTestDataExecuted()) {
            if (isMultiCurrencyOrg) {
                Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
                settings.Enable_Multi_Currency__c = true;

                List<GL_Account_Default__c> currencyDefs = new List<GL_Account_Default__c>();
                Set<Id> ledgeIds = new Set<Id>();
                ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgers()).keySet());
                ledgeIds.addAll(new Map<Id, Ledger__c> (LedgerHandler.getInstanceWithoutSharing().getBudgetLedgers()).keySet());

                Id currencyGainLoss = createCurrencyGainLossGLAccount();

                for (Id ledgerId : ledgeIds) {
                    GL_Account_Default__c def = new GL_Account_Default__c(
                        Ledger__c = ledgerId,
                        GL_Account__c = currencyGainLoss,
                        GL_Account_Specification__c = GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT
                    );
                    currencyDefs.add(def);
                }

                SFDCSecurityUtils.insertProxy(currencyDefs);

                AccountingSettingsHandler.updateSettingsAndReset();
                MultiCurrencyHandler.isMultiCurrencyEnabled = NULL;
                serviceResult = new ServiceResult(NULL, true);
            }
            else {
                serviceResult = new ServiceResult(
                    NULL,
                    false,
                    new List<ServiceResult.Error>{
                        new ServiceResult.Error(
                            StatusCode.MULTI_CURRENCY_NOT_ENABLED.name(),
                            MULTI_CURRENCY_NOT_ENABLED
                        )
                    }
                );
            }
        }
        return serviceResult;
    }

    private Boolean isMultiCurrencyEnabledImpl() {
        if (validateSetupTestDataExecuted()) {
            return MultiCurrencyHandler.isMultiCurrencyEnabled;
        }
        return NULL;
    }


    private ServiceResult enableAvalaraVATReportingImpl() {
        if (validateSetupTestDataExecuted()) {
            TestDataSuite.getInstance().setAvaVATSelected();
            serviceResult = new ServiceResult(NULL, true);
        }
        return serviceResult;
    }

    private Boolean isAvalaraVATReportingEnabledImpl() {
        if (validateSetupTestDataExecuted()) {
            return AccountingSettingsHandler.isAvaVATReportingEnabled();
        }
        return NULL;
    }

    /******************* UTILITY METHODS  *******************************************/
    private Id createCurrencyGainLossGLAccount() {
        GL_Account__c glAccount = new GL_Account__c();
        glAccount.Name = '8040-Currency Gain/Loss';
        glAccount.Active__c = true;
        glAccount.Type__c = 'Expense';
        glAccount.Sub_Type_1__c = 'General & Administrative';
        glAccount.Sub_Type_2__c = 'Accounting';
        SFDCSecurityUtils.insertProxy(glAccount);

        return glAccount.Id;
    }

    private Boolean validateSetupTestDataExecuted() {
        Boolean result = false;
        Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
        if (settings.Id != NULL) {
            result = true;
        }
        else {
            serviceResult = new ServiceResult(NULL, StatusCode.SETUP_TEST_DATA_NOT_EXECUTED.name(), SETUP_TEST_DATA_NOT_EXECUTED_ERROR);
        }
        return result;
    }

}