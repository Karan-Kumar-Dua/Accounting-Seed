public with sharing class FixedAssetActions {
    public static final String LEDGER_SHADOW_ERROR = Label.ERR_LEDGER_SHADOW;
    public static final String LEDGER_ACTIVE_ERROR = Label.ERR_LEDGER_ACTIVE;

    public static void requireFields(List<Fixed_Asset__c> fixedAssetList) {
        for (Fixed_Asset__c fixedAsset : fixedAssetList) {
            if (fixedAsset.Ledger__c == null) {
                fixedAsset.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (fixedAsset.Ledger__c != null && LedgerHandler.getInstanceWithoutSharing().isShadowLedger(fixedAsset.Ledger__c)) {
                fixedAsset.addError(LEDGER_SHADOW_ERROR);
            }
            if (fixedAsset.Ledger__c != null && !LedgerHandler.getInstanceWithoutSharing().isActiveLedger(fixedAsset.Ledger__c)) {
                fixedAsset.addError(LEDGER_ACTIVE_ERROR);
            }
        }
    }

}