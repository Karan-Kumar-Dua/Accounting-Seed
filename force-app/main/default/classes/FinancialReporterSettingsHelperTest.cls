@IsTest
private class FinancialReporterSettingsHelperTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetSettingsAtFirstTime() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            FinancialReporterSettingsHandler.FinancialReporterSettings result = FinancialReporterSettingsHelper.getSettings(null);
            List<Financial_Reporter_Settings__c> newSettings = [SELECT Id FROM Financial_Reporter_Settings__c];
            System.assertEquals(false, newSettings.isEmpty());
            System.assertEquals(result.settings.Id, newSettings.get(0).Id);
            System.assertEquals(null, result.companyLogoId);
            System.assertEquals(LedgerHandler.getLedgerIdWithSharing(), result.ledgerId);
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(LedgerHandler.getLedgerIdWithSharing());
            System.assertEquals(result.settings.Id, selectedLedger.Financial_Reporter_Settings__c);
        }
    }

    @IsTest
    private static void testGetSettingsWhenSettingsRecordExist() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //create FRS record
            Financial_Reporter_Settings__c newSetting = FinancialReporterSettingsHandler.getNewSettings();
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            insert newSetting;
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;
            //update Ledger to populate the settings record
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(LedgerHandler.getLedgerIdWithSharing());
            selectedLedger.Financial_Reporter_Settings__c = newSetting.Id;
            update selectedLedger;
            //create company logo
            ContentVersion xContentVersion = new ContentVersion(
                Title = 'CompanyLogo',
                PathOnClient = 'Logo.png',
                VersionData = Blob.valueOf('Image Content'),
                IsMajorVersion = true
            );
            insert xContentVersion;
            //receive ContentDocumentId
            xContentVersion = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :xContentVersion.Id LIMIT 1];
            //create ContentDocumentLink  record
            ContentDocumentLink cdLink = new ContentDocumentLink();
            cdLink.LinkedEntityId = newSetting.Id;
            cdLink.ContentDocumentId = xContentVersion.ContentDocumentId;
            cdLink.shareType = 'I';
            cdLink.Visibility = 'AllUsers';
            insert cdLink;

            Test.startTest();
            FinancialReporterSettingsHandler.FinancialReporterSettings result = FinancialReporterSettingsHelper.getSettings(null);
            List<Financial_Reporter_Settings__c> newSettings = [SELECT Id FROM Financial_Reporter_Settings__c];
            System.assertEquals(false, newSettings.isEmpty());
            System.assertEquals(1, newSettings.size());
            System.assertEquals(result.settings.Id, newSettings.get(0).Id);
            System.assertEquals(xContentVersion.Id, result.companyLogoId);
            System.assertEquals(LedgerHandler.getLedgerIdWithSharing(), result.ledgerId);
            System.assertEquals(result.settings.Id, selectedLedger.Financial_Reporter_Settings__c);
        }
    }

    @IsTest
    private static void testSaveSettingsAtFirstTime() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            FinancialReporterSettingsHandler.FinancialReporterSettings result = FinancialReporterSettingsHelper.getSettings(null);
            List<Financial_Reporter_Settings__c> newSettings = [SELECT Id FROM Financial_Reporter_Settings__c];
            System.assertEquals(false, newSettings.isEmpty());
            System.assertEquals(result.settings.Id, newSettings.get(0).Id);
            System.assertEquals(null, result.companyLogoId);
            System.assertEquals(LedgerHandler.getLedgerIdWithSharing(), result.ledgerId);
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(LedgerHandler.getLedgerIdWithSharing());
            System.assertEquals(result.settings.Id, selectedLedger.Financial_Reporter_Settings__c);

            //create company logo
            ContentVersion xContentVersion = new ContentVersion(
                Title = 'CompanyLogo',
                PathOnClient = 'Logo.png',
                VersionData = Blob.valueOf('Image Content'),
                IsMajorVersion = true
            );
            insert xContentVersion;
            //receive ContentDocumentId
            xContentVersion = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :xContentVersion.Id LIMIT 1];
            //create ContentDocumentLink  record
            ContentDocumentLink cdLink = new ContentDocumentLink();
            cdLink.LinkedEntityId = newSettings.get(0).Id;
            cdLink.ContentDocumentId = xContentVersion.ContentDocumentId;
            cdLink.ShareType = 'I';
            cdLink.Visibility = 'AllUsers';
            insert cdLink;

            //update DTO and serialize it
            result.companyLogoId = xContentVersion.Id;
            result.settings.Company_Name__c = 'Updated Company Name';
            result.settings.Column_Header_Variant__c = FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_PERIOD_END_DATE;
            result.settings.Expand_Report_Rows__c = true;
            String serializedFRS = JSON.serialize(result);
            //call saveSettings method
            FinancialReporterSettingsHelper.saveSettings(serializedFRS, true, true, true);
            //check all settings have the same values
            List<Financial_Reporter_Settings__c> allSettings = [
                SELECT Id, Company_Name__c, Column_Header_Variant__c, Expand_Report_Rows__c
                FROM Financial_Reporter_Settings__c
            ];
            for (Financial_Reporter_Settings__c setting : allSettings) {
                System.assertEquals('Updated Company Name', setting.Company_Name__c);
                System.assertEquals(FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_PERIOD_END_DATE, setting.Column_Header_Variant__c);
                System.assert(setting.Expand_Report_Rows__c);
            }
        }
    }

    @IsTest
    private static void testSaveSettingsAndTransmitNameAndLogo() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            FinancialReporterSettingsHandler.FinancialReporterSettings result = FinancialReporterSettingsHelper.getSettings(null);
            List<Financial_Reporter_Settings__c> newSettings = [SELECT Id FROM Financial_Reporter_Settings__c];
            System.assertEquals(false, newSettings.isEmpty());
            System.assertEquals(result.settings.Id, newSettings.get(0).Id);
            System.assertEquals(null, result.companyLogoId);
            System.assertEquals(LedgerHandler.getLedgerIdWithSharing(), result.ledgerId);
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(LedgerHandler.getLedgerIdWithSharing());
            System.assertEquals(result.settings.Id, selectedLedger.Financial_Reporter_Settings__c);

            //create company logo
            ContentVersion xContentVersion = new ContentVersion(
                Title = 'CompanyLogo',
                PathOnClient = 'Logo.png',
                VersionData = Blob.valueOf('Image Content'),
                IsMajorVersion = true
            );
            insert xContentVersion;
            //receive ContentDocumentId
            xContentVersion = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :xContentVersion.Id LIMIT 1];
            //create ContentDocumentLink  record
            ContentDocumentLink cdLink = new ContentDocumentLink();
            cdLink.LinkedEntityId = newSettings.get(0).Id;
            cdLink.ContentDocumentId = xContentVersion.ContentDocumentId;
            cdLink.ShareType = 'I';
            cdLink.Visibility = 'AllUsers';
            insert cdLink;

            //update DTO and serialize it
            result.companyLogoId = xContentVersion.Id;
            result.settings.Company_Name__c = 'Updated Company Name';
            result.settings.Column_Header_Variant__c = FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_PERIOD_END_DATE;
            result.settings.Expand_Report_Rows__c = false;
            String serializedFRS = JSON.serialize(result);
            //call saveSettings method
            FinancialReporterSettingsHelper.saveSettings(serializedFRS, true, true, false);
            //check all settings have the same values
            List<Financial_Reporter_Settings__c> allSettings = [
                SELECT Id, Company_Name__c, Column_Header_Variant__c, Expand_Report_Rows__c
                FROM Financial_Reporter_Settings__c
            ];
            for (Financial_Reporter_Settings__c setting : allSettings) {
                System.assertEquals('Updated Company Name', setting.Company_Name__c);
                System.assertEquals(FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_PERIOD_END_DATE, setting.Column_Header_Variant__c);
                System.assert(!setting.Expand_Report_Rows__c);
            }
            //call saveSettings method one more time to check scenario when the Logo is already linked with settings record
            FinancialReporterSettingsHelper.saveSettings(serializedFRS, true, false, true);
            allSettings = [
                SELECT Id, Company_Name__c, Column_Header_Variant__c, Expand_Report_Rows__c
                FROM Financial_Reporter_Settings__c
            ];
            Set<Id> settingsIds = new Map<Id, Financial_Reporter_Settings__c>(allSettings).keySet();
            List<ContentDocumentLink> links = DomainUtils.getContentDocumentLinksByLinkedEntityId(
                settingsIds, new Set<Id>{xContentVersion.ContentDocumentId}
            );
            //Expected: each settings record still has only one related file
            System.assertEquals(allSettings.size(), links.size());
        }
    }
}