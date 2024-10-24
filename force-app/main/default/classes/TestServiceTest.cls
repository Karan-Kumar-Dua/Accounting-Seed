@IsTest
public with sharing class TestServiceTest {
    
    @IsTest
    public static void testSetupTestDataWithBaseInit() {
        Test.startTest();
        ServiceResult result = TestService.setupTestData();
        System.assertEquals(true, result.isSuccess);
        System.assertEquals(1, [SELECT COUNT() FROM Accounting_Settings__c]);
        Map<String, List<SObject>> data = (Map<String, List<SObject>>) JSON.deserializeStrict(result.data, Map<String, List<SObject>>.class);
        System.assertNotEquals(true, data.get('accountingPeriods').isEmpty());
        System.assertNotEquals(true, data.get('glAccounts').isEmpty());
        System.assertNotEquals(true, data.get('billingFormats').isEmpty());
        System.assertNotEquals(true, data.get('ledgers').isEmpty());
        System.assertNotEquals(true, data.get('accountingSettings').isEmpty());
    }

    @IsTest
    public static void testSetupTestDataWithoutBaseInit() {
        Test.startTest();
        ServiceResult result = TestService.setupTestData(false, false, false);
        System.assertEquals(true, result.isSuccess);
        System.assertEquals(1, [SELECT COUNT() FROM Accounting_Settings__c]);
        Map<String, List<SObject>> data = (Map<String, List<SObject>>) JSON.deserializeStrict(result.data, Map<String, List<SObject>>.class);
        System.assertNotEquals(true, data.get('accountingPeriods').isEmpty());
        System.assertNotEquals(true, data.get('glAccounts').isEmpty());
        System.assertNotEquals(true, data.get('billingFormats').isEmpty());
        System.assertNotEquals(true, data.get('ledgers').isEmpty());
        System.assertNotEquals(true, data.get('accountingSettings').isEmpty());
    }

    @IsTest
    public static void testSetupTestDataWithStandardObjectData() {
        Test.startTest();
        ServiceResult result = TestService.setupTestData(true, true, false);
        System.assertEquals(true, result.isSuccess);
        System.assertEquals(1, [SELECT COUNT() FROM Accounting_Settings__c]);
        Map<String, List<SObject>> data = (Map<String, List<SObject>>) JSON.deserializeStrict(result.data, Map<String, List<SObject>>.class);
        System.assertNotEquals(true, data.get('accountingPeriods').isEmpty());
        System.assertNotEquals(true, data.get('glAccounts').isEmpty());
        System.assertNotEquals(true, data.get('billingFormats').isEmpty());
        System.assertNotEquals(true, data.get('ledgers').isEmpty());
        System.assertNotEquals(true, data.get('accountingSettings').isEmpty());
    }

    @IsTest
    public static void testSetupTestDataWithStandardFieldPermissions() {
        Test.startTest();
        ServiceResult result = TestService.setupTestData(true, false, true);
        System.assertEquals(true, result.isSuccess);
        System.assertEquals(1, [SELECT COUNT() FROM Accounting_Settings__c]);
        Map<String, List<SObject>> data = (Map<String, List<SObject>>) JSON.deserializeStrict(result.data, Map<String, List<SObject>>.class);
        System.assertNotEquals(true, data.get('accountingPeriods').isEmpty());
        System.assertNotEquals(true, data.get('glAccounts').isEmpty());
        System.assertNotEquals(true, data.get('billingFormats').isEmpty());
        System.assertNotEquals(true, data.get('ledgers').isEmpty());
        System.assertNotEquals(true, data.get('accountingSettings').isEmpty());
    }

    @IsTest
    public static void testSetupTestDataWithStandardObjects() {
        Test.startTest();
        ServiceResult result = TestService.setupTestData(true, true, false);
        System.assertEquals(true, result.isSuccess);
        System.assertEquals(1, [SELECT COUNT() FROM Accounting_Settings__c]);
        Map<String, List<SObject>> data = (Map<String, List<SObject>>) JSON.deserializeStrict(result.data, Map<String, List<SObject>>.class);
        System.assertNotEquals(true, data.get('accounts').isEmpty());
        System.assertNotEquals(true, data.get('contacts').isEmpty());
        System.assertNotEquals(true, data.get('opportunities').isEmpty());
    }

    @IsTest
    public static void testSetupTestDataWithStandardObjectDataAndStandardFieldPermissions() {
        Test.startTest();
        ServiceResult result = TestService.setupTestData(true, true, true);
        System.assertEquals(true, result.isSuccess);
        System.assertEquals(1, [SELECT COUNT() FROM Accounting_Settings__c]);
        Map<String, List<SObject>> data = (Map<String, List<SObject>>) JSON.deserializeStrict(result.data, Map<String, List<SObject>>.class);
        System.assertNotEquals(true, data.get('accountingPeriods').isEmpty());
        System.assertNotEquals(true, data.get('glAccounts').isEmpty());
        System.assertNotEquals(true, data.get('billingFormats').isEmpty());
        System.assertNotEquals(true, data.get('ledgers').isEmpty());
        System.assertNotEquals(true, data.get('accountingSettings').isEmpty());
    }

    @IsTest
    public static void testGetTestData() {
        Test.startTest();
        TestService.setupTestData();

        ServiceResult result = TestService.getTestData();
        Map<String, List<SObject>> data = (Map<String, List<SObject>>) JSON.deserializeStrict(result.data, Map<String, List<SObject>>.class);
        System.assertNotEquals(0, ((List<Accounting_Period__c>) data.get('accountingPeriods')).size());
        System.assertNotEquals(0, ((List<GL_Account__c>) data.get('glAccounts')).size());
        System.assertNotEquals(0, ((List<Billing_Format__c>) data.get('billingFormats')).size());
        System.assertNotEquals(0, ((List<Ledger__c>) data.get('ledgers')).size());
        System.assertNotEquals(0, ((List<Accounting_Settings__c>) data.get('accountingSettings')).size());
    }

    @IsTest
    public static void testGetUserActiveLedgerId() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.getUserActiveLedgerId();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(testData.ledgers[0].Id, (Id) result.data);
        }
    }

    @IsTest
    public static void testSetUserActiveLedgerId() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.setUserActiveLedgerId(testData.ledgers[2].Id);
            System.assertEquals(true, result.isSuccess);
            result = TestService.getUserActiveLedgerId();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(testData.ledgers[2].Id, (Id) result.data);
        }
    }

    @IsTest
    public static void testGetOrgDefaultLedgerId() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.getOrgDefaultLedgerId();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(testData.ledgers[0].Id, (Id) result.data);
        }
    }

    @IsTest
    public static void testSetOrgDefaultLedgerId() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.setOrgDefaultLedgerId(testData.ledgers[2].Id);
            System.assertEquals(true, result.isSuccess);
            result = TestService.getOrgDefaultLedgerId();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(testData.ledgers[2].Id, (Id) result.data);
        }
    }

    @IsTest
    public static void testGetLedgerLimit() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            Integer result = TestService.getLedgerLimit();
            System.assertEquals(
                AccountingLimitHandler.getInstance().getLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT),
                result
            );
        }
    }

    @IsTest
    public static void testSetLedgerLimit() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            ServiceResult setResult = TestService.setLedgerLimit(20);
            System.assertEquals(true, setResult.isSuccess);
            Integer getResult = TestService.getLedgerLimit();
            System.assertEquals(20, getResult);
        }
    }

    @IsTest
    public static void testGetInventoryValuationMethod() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.getInventoryValuation();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals('Average Cost', (String) result.data);
        }
    }

    @IsTest
    public static void testSetInventoryValuationMethodStandardCost() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.setInventoryValuationStandardCost();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(true, AccountingSettingsHandler.isInventoryValuationStandardCost());
            System.assertEquals('Standard Cost', TestService.getInventoryValuation().data);
        }
    }

    @IsTest
    public static void testSetInventoryValuationMethodAverageCost() {
        TestDataSuite testData = TestDataSuite.getInstance(true, true)
            .setInventoryValuationStandardCost();

        System.runAs(testData.users.get(1)) {
            System.assertEquals(false, AccountingSettingsHandler.isInventoryValuationAverageCost());
            ServiceResult result = TestService.setInventoryValuationAverageCost();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(true, AccountingSettingsHandler.isInventoryValuationAverageCost());
            System.assertEquals('Average Cost', TestService.getInventoryValuation().data);
        }
    }

    @IsTest
    public static void testSetMultiCurrencyEnabledException() {
        if (TestService.isMultiCurrencyOrg) {
            TestDataSuite testData = TestDataSuite.getInstance(true, true);
            System.runAs(testData.users.get(1)) {
                ServiceResult result = TestService.enableMultiCurrency();
                System.assertEquals(true, result.isSuccess);
                System.assertEquals(true, AccountingSettingsHandler.getAccountingSettings().Enable_Multi_Currency__c);
                System.assertEquals(true, TestService.isMultiCurrencyEnabled());
                System.assertEquals(true, MultiCurrencyHandler.isMultiCurrencyEnabled);
            }
        }
    }

    @IsTest
    public static void testIsMultiCurrencyEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance(true,true);
        System.runAs(testData.users.get(1)) {
            Boolean isMCEnabled = TestService.isMultiCurrencyEnabled();
            System.assertEquals(AccountingSettingsHandler.getAccountingSettings().Enable_Multi_Currency__c, isMCEnabled);
        }
    }

    @IsTest
    public static void testSetupTestDataNotExecutedError() {
        ServiceResult result = TestService.setInventoryValuationStandardCost();
        System.assertEquals(false, result.isSuccess);
        System.assertEquals(TestService.StatusCode.SETUP_TEST_DATA_NOT_EXECUTED.name(), result.errors[0].code);
        System.assertEquals(TestService.SETUP_TEST_DATA_NOT_EXECUTED_ERROR, result.errors[0].detail);
    }

    @IsTest
    public static void testEnableAvalaraVATReporting() {
        TestDataSuite testData = TestDataSuite.getInstance(true,true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.enableAvalaraVATReporting();
            System.assertEquals(true, AccountingSettingsHandler.isAvaVATReportingEnabled());
            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    public static void testIsAvalaraVATReportingEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance(true,true);
        System.runAs(testData.users.get(1)) {
            ServiceResult result = TestService.enableAvalaraVATReporting();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(true, AccountingSettingsHandler.isAvaVATReportingEnabled());

            Boolean isEnabled = TestService.isAvalaraVATReportingEnabled();
            System.assertEquals(true, isEnabled);
        }
    }

    @IsTest
    public static void testSetupTestDataWithERP() {
        AccountingSettingsHandler.isERPEnabled = true;
        ServiceResult res = TestService.setupTestData();
        System.assert(res.isSuccess);
    }

}