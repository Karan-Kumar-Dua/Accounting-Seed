@IsTest
public class AccountingSettingsHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testInitializeAccountingSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            System.assertEquals(acctSettings, AccountingSettingsHandler.acctSeedSettings);
        }
    }

    @IsTest
    private static void testQueryAccountingSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();
            System.assertEquals([SELECT Id FROM Accounting_Settings__c LIMIT 1].Id, acctSettings.Id);
        }
    }

    @IsTest
    private static void testResetAccountingSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);

            AccountingSettingsHandler.resetAccountingSettings();
            System.assertEquals(NULL, AccountingSettingsHandler.acctSeedSettings);
        }
    }

    @IsTest
    private static void testSetInventoryValuationStandardCost() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);

            AccountingSettingsHandler.setInventoryValuationStandardCost();
            System.assertEquals(
                'Standard Cost', [
                    SELECT Id, Inventory_Valuation_Method__c
                    FROM Accounting_Settings__c
                    WHERE Id = :AccountingSettingsHandler.acctSeedSettings.Id
                ].Inventory_Valuation_Method__c
            );
        }
    }

    @IsTest
    private static void testSetInventoryValuationAverageCost() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);

            AccountingSettingsHandler.setInventoryValuationAverageCost();
            System.assertEquals(
                'Average Cost', [
                    SELECT Id, Inventory_Valuation_Method__c
                    FROM Accounting_Settings__c
                    WHERE Id = :AccountingSettingsHandler.acctSeedSettings.Id
                ].Inventory_Valuation_Method__c
            );
        }
    }
    @IsTest
    private static void testIsInventoryValuationStandardCost() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);

            AccountingSettingsHandler.setInventoryValuationStandardCost();
            System.assertEquals(true, AccountingSettingsHandler.isInventoryValuationStandardCost());
        }
    }

    @IsTest
    private static void testIsInventoryValuationAverageCost() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);

            AccountingSettingsHandler.setInventoryValuationAverageCost();
            System.assertEquals(true, AccountingSettingsHandler.isInventoryValuationAverageCost());
        }
    }

    @IsTest
    private static void testAutoPostAmortizationEntries() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);
            System.assertEquals(true, AccountingSettingsHandler.fetchAccountingSettingsValue(Accounting_Settings__c.Auto_Post_Amortization_Entries__c));

            AccountingSettingsHandler.setAutoPostSourceDocuments(Accounting_Settings__c.Auto_Post_Amortization_Entries__c, false);
            System.assertEquals(false, AccountingSettingsHandler.fetchAccountingSettingsValue(Accounting_Settings__c.Auto_Post_Amortization_Entries__c));
        }
    }

    @IsTest
    private static void testPostSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);
            System.assertEquals(true, AccountingSettingsHandler.isHeaderLevelPost());

            testData.setLineLevelPost();
            System.assertEquals(false, AccountingSettingsHandler.isHeaderLevelPost());
            testData.setHeaderLevelPost();
            System.assertEquals(true, AccountingSettingsHandler.isHeaderLevelPost());
        }
    }

    @IsTest
    private static void testIsAvaVATReportingEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertEquals(false, AccountingSettingsHandler.isAvaVATReportingEnabled());

            AccountingSettingsHandler.setIsAvaVATInstalled(true);
            System.assertEquals(false, AccountingSettingsHandler.isAvaVATReportingEnabled());

            AccountingSettingsHandler.setIsAvaVATReportingEnabled(true);
            System.assertEquals(true, AccountingSettingsHandler.isAvaVATReportingEnabled());
        }
    }

    @IsTest
    private static void testIsFSLExtensionInstalled() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.assertEquals(false, AccountingSettingsHandler.isFSLExtensionInstalled());
            AccountingSettingsHandler.setIsFSLExtensionInstalled(true);
            System.assertEquals(true, AccountingSettingsHandler.isFSLExtensionInstalled());
        }
    }

    @IsTest
    private static void testIsFSLExtensionEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.assertEquals(false, AccountingSettingsHandler.isFSLExtensionEnabled());
            AccountingSettingsHandler.setIsWOEnabled(true);
            System.assertEquals(false, AccountingSettingsHandler.isFSLExtensionEnabled());
            AccountingSettingsHandler.setIsFSLExtensionInstalled(true);
            System.assertEquals(true, AccountingSettingsHandler.isFSLExtensionEnabled());
            AccountingSettingsHandler.setIsWOEnabled(false);
            System.assertEquals(false, AccountingSettingsHandler.isFSLExtensionEnabled());
        }
    }

    @IsTest
    private static void testEmailConfirmationsDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            AccountingSettingsHandler.getAccountingSettings();
            System.assertNotEquals(NULL, AccountingSettingsHandler.acctSeedSettings);
            System.assertEquals(false, AccountingSettingsHandler.isEmailConfirmationsDisabled());

            AccountingSettingsHandler.setEmailConfirmationsDisabled(true);
            System.assertEquals(true, AccountingSettingsHandler.isEmailConfirmationsDisabled());
        }
    }


}