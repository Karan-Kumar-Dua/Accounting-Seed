public with sharing class FeatureManagementHandler {

    @TestVisible
    private static final String FP_ACCOUNTING_PERIOD_TRANSACTION_LIMIT = 'AccountingPeriodTransactionLimit';
    @TestVisible
    private static final String FP_GLAV_LIMIT = 'AccountingVariableLimit';
    @TestVisible
    private static final String FP_GL_ACCOUNT_LIMIT = 'GLAccountLimit';
    @TestVisible
    private static final String FP_ENABLE_DELETE_ARCHIVED_SOURCE_DOCS = 'EnableDeleteArchivedSourceDocs';
    @TestVisible
    private static final String FP_PAYMENT_SERVICES_ENABLED = 'PaymentServicesEnabled';
    @TestVisible
    private static final String FP_AP_ACH_LIMIT = 'APACHLimit';
    @TestVisible
    private static final String FP_AP_CHECK_LIMIT = 'APCheckLimit';
    @TestVisible
    private static final String FP_PRODUCT_COSTING_ENABLED = 'ProductCostingEnabled';
    @TestVisible
    private static final String FP_CONSOLIDATION_ENABLED = 'ConsolidationsEnabled';
    @TestVisible
    private static final String FP_LEDGER_LIMIT = 'LedgerLimit';
    @TestVisible
    private static final String FP_MULTI_CURRENCY_ENABLED = 'MultiCurrencyEnabled';
    @TestVisible
    private static final String FP_LINE_LEVEL_POST_ENABLED = 'LineLevelPostEnabled';
    @TestVisible
    private static final String FP_AVERAGE_COST_ENABLED = 'AverageCostEnabled';
    @TestVisible
    private static final String FP_ENABLE_F_ANALYTICS = 'EnableFAnalytics';
    @TestVisible
    private static final String LARGE_DATA_VOLUME_MODE = 'LargeDataVolumeMode';

    public static Integer getCurrentAccountingPeriodTransactionLimit() {
        return FeatureManagement.checkPackageIntegerValue(FP_ACCOUNTING_PERIOD_TRANSACTION_LIMIT);
    }

    public static Integer getCurrentGLAVsLimit() {
        return FeatureManagement.checkPackageIntegerValue(FP_GLAV_LIMIT);
    }

    public static Integer getCurrentGlAccountLimit() {
        return FeatureManagement.checkPackageIntegerValue(FP_GL_ACCOUNT_LIMIT);
    }

    public static Boolean isDeleteArchivedSourceDocsEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_ENABLE_DELETE_ARCHIVED_SOURCE_DOCS);
    }

    public static Boolean isPaymentServiceEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_PAYMENT_SERVICES_ENABLED);
    }

    public static Integer getAPACHLimit() {
        return FeatureManagement.checkPackageIntegerValue(FP_AP_ACH_LIMIT);
    }

    public static Integer getAPCheckLimit() {
        return FeatureManagement.checkPackageIntegerValue(FP_AP_CHECK_LIMIT);
    }

    public static Boolean isProductCostingEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_PRODUCT_COSTING_ENABLED);
    }

    public static Boolean isConsolidationsEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_CONSOLIDATION_ENABLED);
    }

    public static Integer getLedgerLimit() {
        return FeatureManagement.checkPackageIntegerValue(FP_LEDGER_LIMIT);
    }

    public static Boolean isMultiCurrencyEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_MULTI_CURRENCY_ENABLED);
    }

    public static Boolean isLineLevelPostEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_LINE_LEVEL_POST_ENABLED);
    }

    public static Boolean isAverageCostEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_AVERAGE_COST_ENABLED);
    }

    public static Boolean isFAnalyticsEnabled() {
        return FeatureManagement.checkPackageBooleanValue(FP_ENABLE_F_ANALYTICS);
    }

    public static Boolean isLargeDataVolumeModeEnabled() {
        return FeatureManagement.checkPackageBooleanValue(LARGE_DATA_VOLUME_MODE);
    }

}