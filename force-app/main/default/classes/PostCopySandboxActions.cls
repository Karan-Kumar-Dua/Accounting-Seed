public with sharing class PostCopySandboxActions implements SandboxPostCopy {

    public void runApexClass(SandboxContext context) {
        updateCustomSetting();
    }

    private void updateCustomSetting() {
        try {
            List<Ledger_Custom_Settings__c> oldLedgerCustomSettings = DomainUtils.getAllLedgerCustomSettings();
            SFDCSecurityUtils.deleteProxy(oldLedgerCustomSettings);

            Ledger_Custom_Settings__c ledgerCustomSettings = Ledger_Custom_Settings__c.getOrgDefaults();
            ledgerCustomSettings.Ledger_Id__c = AccountingSettingsHandler.getAccountingSettings().Default_Ledger__c;
            SFDCSecurityUtils.upsertProxy(ledgerCustomSettings);
        }
        catch (Exception ex) {
        }
    }


}