/**
 * Created by christopherjohnson on 12/8/17.
 */

public with sharing class LedgerManagerController {

    @AuraEnabled
    public static List<Ledger__c> getLedgers() {
        List<Ledger__c> ledgerList = new List<Ledger__c>();

        try {
            for (Ledger__c ledger : LedgerHandler.getInstanceWithSharing(true).getPrimaryTransactionalLedgers()) {
                if (ledger.Active__c) {
                    ledgerList.add(ledger);
                }
            }
        }
        catch (Exception ex) {
           throw new AuraHandledException(ex.getMessage());
        }

        return ledgerList;
    }

    @AuraEnabled
    public static String getSelectedLedger() {
        Ledger_Custom_Settings__c lcs;
        try {
            lcs = Ledger_Custom_Settings__c.getInstance();
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return lcs.Ledger_Id__c;
    }

    @AuraEnabled
    public static void setSelectedLedger(Id ledgerId) {
        try {
            Ledger_Custom_Settings__c lcs = Ledger_Custom_Settings__c.getInstance();
            lcs.Ledger_Id__c = ledgerId;
            SFDCSecurityUtils.upsertProxy(lcs);
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}