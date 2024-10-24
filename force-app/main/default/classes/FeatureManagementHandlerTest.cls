@IsTest
private class FeatureManagementHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGetCurrentAccountingPeriodTransactionLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_ACCOUNTING_PERIOD_TRANSACTION_LIMIT, 100);
            Test.startTest();
                System.assertEquals(100, FeatureManagementHandler.getCurrentAccountingPeriodTransactionLimit());
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetCurrentGLAVsLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_GLAV_LIMIT, 100);
            Test.startTest();
                System.assertEquals(100, FeatureManagementHandler.getCurrentGLAVsLimit());
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetCurrentGlAccountLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_GL_ACCOUNT_LIMIT, 100);
            Test.startTest();
                System.assertEquals(100, FeatureManagementHandler.getCurrentGlAccountLimit());
            Test.stopTest();
        }
    }

    @IsTest
    static void testIsDeleteArchivedSourceDocsEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_ENABLE_DELETE_ARCHIVED_SOURCE_DOCS, currentParameterValue);
            Test.startTest();
                System.assertEquals(currentParameterValue, FeatureManagementHandler.isDeleteArchivedSourceDocsEnabled());
            Test.stopTest();
        }
    }

    @IsTest
    static void testIsDeleteArchivedSourceDocsEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_ENABLE_DELETE_ARCHIVED_SOURCE_DOCS, currentParameterValue);
            Test.startTest();
                System.assertEquals(currentParameterValue, FeatureManagementHandler.isDeleteArchivedSourceDocsEnabled());
            Test.stopTest();
        }
    }

    @IsTest
    static void testIsPaymentServiceEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, currentParameterValue);
            Test.startTest();
                System.assertEquals(currentParameterValue, FeatureManagementHandler.isPaymentServiceEnabled());
            Test.stopTest();
        }
    }

    @IsTest
    static void testIsPaymentServiceEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, currentParameterValue);
            Test.startTest();
                System.assertEquals(currentParameterValue, FeatureManagementHandler.isPaymentServiceEnabled());
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetAPACHLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_AP_ACH_LIMIT, 100);
            Test.startTest();
                System.assertEquals(100, FeatureManagementHandler.getAPACHLimit());
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetAPCheckLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_AP_CHECK_LIMIT, 100);
            Test.startTest();
                System.assertEquals(100, FeatureManagementHandler.getAPCheckLimit());
            Test.stopTest();
        }
    }

    @IsTest
    static void testIsProductCostingEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PRODUCT_COSTING_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isProductCostingEnabled());
        }
    }

    @IsTest
    static void testIsProductCostingEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PRODUCT_COSTING_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isProductCostingEnabled());
        }
    }

    @IsTest
    static void testIsConsolidationsEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_CONSOLIDATION_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isConsolidationsEnabled());
        }
    }

    @IsTest
    static void testIsConsolidationsEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_CONSOLIDATION_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isConsolidationsEnabled());
        }
    }

    @IsTest
    static void testGetLedgerLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_LEDGER_LIMIT, 100);
            Test.startTest();
            System.assertEquals(100, FeatureManagementHandler.getLedgerLimit());
        }
    }

    @IsTest
    static void testIsMultiCurrencyEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_MULTI_CURRENCY_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isMultiCurrencyEnabled());
        }
    }

    @IsTest
    static void testIsMultiCurrencyEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_MULTI_CURRENCY_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isMultiCurrencyEnabled());
        }
    }

    @IsTest
    static void testIsLineLevelPostEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_LINE_LEVEL_POST_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isLineLevelPostEnabled());
        }
    }

    @IsTest
    static void testIsLineLevelPostEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_LINE_LEVEL_POST_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isLineLevelPostEnabled());
        }
    }

    @IsTest
    static void testIsAverageCostEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_AVERAGE_COST_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isAverageCostEnabled());
        }
    }

    @IsTest
    static void testIsAverageCostEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_AVERAGE_COST_ENABLED, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isAverageCostEnabled());
        }
    }

    @IsTest
    static void testIsFAnalyticsEnabledSetToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = true;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_ENABLE_F_ANALYTICS, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isFAnalyticsEnabled());
        }
    }

    @IsTest
    static void testIsFAnalyticsEnabledSetToFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Boolean currentParameterValue = false;
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_ENABLE_F_ANALYTICS, currentParameterValue);
            Test.startTest();
            System.assertEquals(currentParameterValue, FeatureManagementHandler.isFAnalyticsEnabled());
        }
    }

}