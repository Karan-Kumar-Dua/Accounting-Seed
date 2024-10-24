public with sharing class FinancialReporterSettingsHelper extends AbstractLWCHelper {

    public static final String NO_LEDGER_ERROR = Label.ERR_REPORT_DISPLAY_NO_LEDGER;
    public static final String NO_SETTING_LEDGER_ERROR = Label.ERR_NO_SETTING_LEDGER;

    @AuraEnabled
    public static CustomSelectOption getContentVersionInfo(Id contentDocumentId) {
        CustomSelectOption contentVersionInfo;
        try {
            List<ContentVersion> files = DomainUtils.getFilesByContentDocumentId(new Set<Id>{contentDocumentId});
            if (!files.isEmpty()) {
                contentVersionInfo = new CustomSelectOption(
                    files[0].Id, files[0].Title + '.' + files[0].FileExtension
                );
            }
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return contentVersionInfo;
    }

    @AuraEnabled
    public static FinancialReporterSettingsHandler.FinancialReporterSettings getSettings(Id ledgerId) {
        FinancialReporterSettingsHandler.FinancialReporterSettings result;
        try {
            if (ledgerId == NULL) {
                ledgerId = LedgerHandler.getLedgerIdWithSharing();
            }
            if (ledgerId != NULL) {
                result = FinancialReporterSettingsHandler.getInstance().getSettings(ledgerId);
            }
            else {
                throw new FinancialReporterSettingsHandler.FinancialReporterSettingsException(NO_SETTING_LEDGER_ERROR);
            }
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static FinancialReporterSettingsHandler.FinancialReporterSettings getSettingsByFinReportResult(Id finReportResultId) {
        FinancialReporterSettingsHandler.FinancialReporterSettings result;
        try {
            List<Financial_Report_Result__c> frResults = DomainUtils.getFinancialReportResultsById(new Set<Id>{finReportResultId});
            if (!frResults.isEmpty()
                && frResults.get(0).Ledger__c != NULL
                && LedgerHandler.getInstanceWithSharing().getLedgerById(frResults.get(0).Ledger__c) != NULL) {

                Id ledgerId = frResults.get(0).Ledger__c;
                result = FinancialReporterSettingsHandler.getInstance().getSettings(ledgerId);
            }
            else {
                throw new FinancialReporterSettingsHandler.FinancialReporterSettingsException(NO_LEDGER_ERROR);
            }
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static FinancialReporterSettingsHandler.FinancialReporterSettings saveSettings(
        String serializedFRS,
        Boolean transmitNameAndLogoToAll,
        Boolean transmitColumnHeaderToAll,
        Boolean transmitExpandReportRowsToAll
    ) {
        FinancialReporterSettingsHandler.FinancialReporterSettings result;
        try {
            FinancialReporterSettingsHandler.FinancialReporterSettings wrappedSettings =
                (FinancialReporterSettingsHandler.FinancialReporterSettings) JSON.deserialize(
                    serializedFRS, FinancialReporterSettingsHandler.FinancialReporterSettings.class
                );
            //Update settings for current ledger
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            SFDCSecurityUtils.updateProxy(wrappedSettings.settings);
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;

            if (transmitNameAndLogoToAll || transmitColumnHeaderToAll || transmitExpandReportRowsToAll) {
                upsertAllSettings(wrappedSettings, transmitNameAndLogoToAll, transmitColumnHeaderToAll, transmitExpandReportRowsToAll);
            }

            result = FinancialReporterSettingsHandler.getInstance().getSettings(wrappedSettings.ledgerId);
        }
        catch (AuraHandledException ex) {
            throw ex;
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return result;
    }

    private static void upsertAllSettings(
        FinancialReporterSettingsHandler.FinancialReporterSettings sample,
        Boolean transmitNameAndLogoToAll,
        Boolean transmitColumnHeaderToAll,
        Boolean transmitExpandReportRowsToAll
    ) {

        Map<Id, Financial_Reporter_Settings__c> ledgerIdToSettings = new Map<Id, Financial_Reporter_Settings__c>();
        Set<Id> ledgerIdsToLinkWithNewSettings = new Set<Id>();
        Set<Id> ledgerIdsToTransmitLogo = new Set<Id>();
        Map<Id, Ledger__c> allLedgersMap = new Map<Id, Ledger__c>(LedgerHandler.getInstanceWithSharing(true).getAllTransactionalTypeLedgers());
        //remove selected ledger from the collection of processed ledgers
        allLedgersMap.remove(sample.ledgerId);

        for (Ledger__c ledger : allLedgersMap.values()) {
            if (LedgerHandler.getInstanceWithSharing(true).isShadowLedger(ledger.Id)) {
                continue;
            }
            Financial_Reporter_Settings__c newSettings = new Financial_Reporter_Settings__c();
            newSettings.Id = ledger.Financial_Reporter_Settings__c;
            if (newSettings.Id == NULL) {
                newSettings = FinancialReporterSettingsHandler.getNewSettings();
                ledgerIdsToLinkWithNewSettings.add(ledger.Id);
            }
            if (transmitNameAndLogoToAll) {
                newSettings.Company_Name__c = sample.settings.Company_Name__c;
                ledgerIdsToTransmitLogo.add(ledger.Id);
            }
            if (transmitColumnHeaderToAll) {
                newSettings.Column_Header_Variant__c = sample.settings.Column_Header_Variant__c;
            }
            if (transmitExpandReportRowsToAll) {
                newSettings.Expand_Report_Rows__c = sample.settings.Expand_Report_Rows__c;
            }
            ledgerIdToSettings.put(ledger.Id, newSettings);
        }
        //Insert new settings records or update existed
        FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
        SFDCSecurityUtils.upsertProxy(ledgerIdToSettings.values());
        FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = false;
        //Link ledgers with new settings records
        if (!ledgerIdsToLinkWithNewSettings.isEmpty()) {
            List<Ledger__c> ledgersToUpdate = new List<Ledger__c>();
            for (Id ledgerId : ledgerIdsToLinkWithNewSettings) {
                Ledger__c ledger = allLedgersMap.get(ledgerId);
                ledger.Financial_Reporter_Settings__c = ledgerIdToSettings.get(ledgerId).Id;
                ledgersToUpdate.add(ledger);
            }
            TriggerObserver.getInstance().unlockField(Ledger__c.Financial_Reporter_Settings__c);
            SFDCSecurityUtils.updateProxy(ledgersToUpdate);
            TriggerObserver.purgeUnlockedFields(Ledger__c.Financial_Reporter_Settings__c);
        }
        //Transmit company logo if needed
        if (!ledgerIdsToTransmitLogo.isEmpty() && sample.companyLogoId != NULL) {
            List<Financial_Reporter_Settings__c> settingsToTransmitLogo = new List<Financial_Reporter_Settings__c>();
            for (Id ledgerId : ledgerIdsToTransmitLogo) {
                settingsToTransmitLogo.add(ledgerIdToSettings.get(ledgerId));
            }
            createContentDocumentLinkForSettings(sample.companyLogoId, settingsToTransmitLogo);
        }
    }

    private static void createContentDocumentLinkForSettings(Id contentVersionId, List<Financial_Reporter_Settings__c> settings) {
        //Get ContentDocument Id by ContentVersion Id
        Id contentDocumentId = DomainUtils.getFilesById(new Set<Id>{contentVersionId}).get(0).ContentDocumentId;
        Set<Id> docIds = new Set<Id>{contentDocumentId};
        //Check if this ContentDocument is already linked with FR Settings records
        Set<Id> settingsIds = new Map<Id, Financial_Reporter_Settings__c>(settings).keySet();
        Set<Id> alreadyLinkedSettingsIds = new Set<Id>();
        for (ContentDocumentLink cdLink : DomainUtils.getContentDocumentLinksByLinkedEntityId(settingsIds, docIds)) {
            alreadyLinkedSettingsIds.add(cdLink.LinkedEntityId);
        }
        //Create new ContentDocumentLink records only if this ContentDocument was not linked with FRS record previously
        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for (Financial_Reporter_Settings__c setting : settings) {
            if (!alreadyLinkedSettingsIds.contains(setting.Id)) {
                ContentDocumentLink tempLink = new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = setting.Id,
                    ShareType = 'I',
                    Visibility = 'AllUsers'
                );
                newLinks.add(tempLink);
            }
        }
        SFDCSecurityUtils.insertProxy(newLinks);
    }

}