public with sharing class FinancialReporterSettingsHandler {

    public static final String COLUMN_HEADER_VARIANT_ACCOUNTING_PERIOD = 'Accounting Period';
    public static final String COLUMN_HEADER_VARIANT_PERIOD_END_DATE = 'Period End Date';
    public static final String COLUMN_HEADER_VARIANT_MM_YY = 'MM/YY';
    public static final String ROUNDING_NO_ROUNDING = 'No Rounding';
    public static final String ROUNDING_WHOLE_AMOUNTS = 'Whole Amounts';
    public static final String ROUNDING_TO_1000 = 'Round to 1000s';

    private static FinancialReporterSettingsHandler instance;

    private Map<Id, FinancialReporterSettingsHandler.FinancialReporterSettings> finRepSettingsStore;

    public static FinancialReporterSettingsHandler getInstance() {
        if (instance == NULL) {
            instance = new FinancialReporterSettingsHandler();
        }
        return instance;
    }

    private FinancialReporterSettingsHandler() {
        finRepSettingsStore = new Map<Id, FinancialReporterSettingsHandler.FinancialReporterSettings>();
    }

    public FinancialReporterSettingsHandler.FinancialReporterSettings getSettings(Id ledgerId) {
        try {
            if (!finRepSettingsStore.containsKey(ledgerId)) {
                allocateSettings(ledgerId);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return finRepSettingsStore.get(ledgerId);
    }

    private void allocateSettings(Id ledgerId) {
        FinancialReporterSettings wrappedSettings;
        Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(ledgerId);
        if (selectedLedger.Financial_Reporter_Settings__c != NULL) {
            wrappedSettings = new FinancialReporterSettings(
                DomainUtils.getFinancialReporterSettingsById(
                    new Set<Id>{
                        selectedLedger.Financial_Reporter_Settings__c
                    }
                ).get(0),
                selectedLedger.Id
            );
        } else {//create new settings record for the ledger
            Financial_Reporter_Settings__c newSettingsRecord = FinancialReporterSettingsHandler.getNewSettings();
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            SFDCSecurityUtils.insertProxy(newSettingsRecord);
            FinancialReporterSettingsActions.isDmlRestrictionBypassEnabled = true;
            //link the settings record with the ledger
            selectedLedger.Financial_Reporter_Settings__c = newSettingsRecord.Id;
            TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Ledger__c.Financial_Reporter_Settings__c}
            );
            SFDCSecurityUtils.updateProxy(selectedLedger);
            TriggerObserver.reset();

            wrappedSettings = new FinancialReporterSettings(newSettingsRecord, selectedLedger.Id);
        }

        this.finRepSettingsStore.put(ledgerId, wrappedSettings);
    }

    public static Financial_Reporter_Settings__c getNewSettings() {
        Financial_Reporter_Settings__c newSettings = new Financial_Reporter_Settings__c(
            Company_Name__c = UserInfo.getOrganizationName(),
            Column_Header_Variant__c = COLUMN_HEADER_VARIANT_ACCOUNTING_PERIOD,
            Rounding__c = ROUNDING_NO_ROUNDING,
            Expand_Report_Rows__c = false
        );
        return newSettings;
    }

    public static void reset() {
        instance = NULL;
    }

    public class FinancialReporterSettingsException extends Exception {}

    public with sharing class FinancialReporterSettings {
        @AuraEnabled
        public Financial_Reporter_Settings__c settings;
        @AuraEnabled
        public Id companyLogoId;/*ContentVersionId*/
        @AuraEnabled
        public String companyLogoFileName;
        @AuraEnabled
        public Id ledgerId;
        @AuraEnabled
        public String ledgerCurrency;
        @AuraEnabled
        public List<AbstractLWCHelper.CustomSelectOption> columnHeaderVariantOptions;

        public FinancialReporterSettings(Financial_Reporter_Settings__c settings, Id ledgerId) {
            this.settings = settings;
            getLogoFileInfo();
            this.ledgerId = ledgerId;
            this.ledgerCurrency = LedgerHandler.getLedgerCurrency(ledgerId);
            this.columnHeaderVariantOptions = getColumnHeaderVariantCustomOptions();
        }

        private void getLogoFileInfo() {
            Set<Id> contentDocIds = new Set<Id>();
            for (ContentDocumentLink docLink : DomainUtils.getContentDocumentLinksByLinkedEntityIdAndFileExt(
                this.settings.Id, new Set<String>{'png', 'jpg', 'jpeg', 'gif'}
            )) {

                contentDocIds.add(docLink.ContentDocumentId);
            }
            if (!contentDocIds.isEmpty()) {
                List<ContentVersion> files = DomainUtils.getFilesByContentDocumentId(contentDocIds);
                if (!files.isEmpty()) {
                    //take latest by Date
                    this.companyLogoId = files[0].Id;
                    this.companyLogoFileName = files[0].Title + '.' + files[0].FileExtension;
                }
            }
        }

        private List<AbstractLWCHelper.CustomSelectOption> getColumnHeaderVariantCustomOptions() {
            List<AbstractLWCHelper.CustomSelectOption> result = new List<AbstractLWCHelper.CustomSelectOption>();
            for (Schema.PicklistEntry ple : Financial_Reporter_Settings__c.Column_Header_Variant__c.getDescribe().getPicklistValues()) {
                result.add(
                    new AbstractLWCHelper.CustomSelectOption(
                        ple.getValue(),
                        getCustomLabelForColumnHeaderVariant(ple.getValue(), ple.getLabel())
                    )
                );
            }
            return result;
        }

        private String getCustomLabelForColumnHeaderVariant(String picklistValue, String picklistLabel) {
            String result = '';
            if (picklistValue == FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_ACCOUNTING_PERIOD) {
                result =
                    FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_ACCOUNTING_PERIOD + ' - Ex. '
                        + AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today())?.Name;
            }
            else if (picklistValue == FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_PERIOD_END_DATE) {
                Date d = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today())?.End_Date__c;
                d = d == null ? Date.today() : d;
                result = 
                    FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_PERIOD_END_DATE + ' - Ex. '
                        + FinancialSuiteUtils.padDayAndMonth(d.format());
            }
            else if (picklistValue == FinancialReporterSettingsHandler.COLUMN_HEADER_VARIANT_MM_YY) {
                String dateFormat = 'MM/YYYY';
                String formattedDate = Datetime.now().format(dateFormat);
                result = picklistLabel + ' - Ex. ' + formattedDate;
            }
            return result;
        }
    }

}