global with sharing class LedgerService {
    public class ServiceAuthorizationException extends Exception {}
    public class LedgerServiceException extends Exception {}
    public static final String AUTHORIZATION_ERROR = Label.ERR_AUTHORIZATION;
    public static final String TEST_ENVIRONMENT_ERROR = Label.ERR_TEST_ENVIRONMENT;
    public static final String LEDGER_ENVIRONMENT_ERROR = Label.ERR_LEDGER_ENVIRONMENT;

    global static Id getActiveLedgerId() {
        return LedgerHandler.getLedgerId();
    }

    global static Id getDefaultLedgerId() {
        return LedgerHandler.getOrgDefaultLedgerId();
    }

    global static Id getLegacyLedgerId() {
        return LedgerHandler.getLegacyDefaultLedgerId();
    }

    global static Integer getLedgerLimit() {
        return AccountingLimitHandler.getInstance().getLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT);
    }

    global static Integer getTransactionalLedgerCount() {
        return DomainUtils.getTransactionalLedgerCount();
    }

    global static void setLedgerLimit(Integer ledgerLimit, String authKey) {
        if (EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))) != authKey) {
            throw new ServiceAuthorizationException(AUTHORIZATION_ERROR);
        }

        Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
        main.Ledger_Limit__c = ledgerLimit;
        AccountingSettingsActions.isPreventUpdateOverride = true;
        SFDCSecurityUtils.updateProxy(main);
        AccountingSettingsActions.isPreventUpdateOverride = false;
        AccountingLimitHandler.getInstance().setLimit(AccountingLimitHandler.LimitType.LEDGER_LIMIT,ledgerLimit);
    }

    global static void setLegacyLedgerId(String ledgerId, String authKey) {
        if (EncodingUtil.base64Encode(Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))) != authKey) {
            throw new ServiceAuthorizationException(AUTHORIZATION_ERROR);
        }

        Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
        main.Legacy_Default_Ledger__c = ledgerId;
        AccountingSettingsActions.isPreventUpdateOverride = true;
        SFDCSecurityUtils.updateProxy(main);
        AccountingSettingsActions.isPreventUpdateOverride = false;
    }

    global static void setTestUserActiveLedger(Id ledgerId) {
        if (!Test.isRunningTest()) {
            throw new LedgerServiceException(TEST_ENVIRONMENT_ERROR);
        }

        Ledger__c selectedLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
        if (selectedLedger != NULL && selectedLedger.Type__c == 'Transactional') {
            LedgerManagerController.setSelectedLedger(ledgerId);
        } 
        else {
            throw new LedgerServiceException(LEDGER_ENVIRONMENT_ERROR);
        }
    }

    global static void setTestOrgDefaultLedger(Id ledgerId) {
        if (!Test.isRunningTest()) {
            throw new LedgerServiceException(TEST_ENVIRONMENT_ERROR);
        }

        Ledger__c selectedLedger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(ledgerId);
        if (selectedLedger != NULL && selectedLedger.Type__c == 'Transactional') {
            Ledger_Custom_Settings__c lcs = Ledger_Custom_Settings__c.getOrgDefaults();
            lcs.Ledger_Id__c = ledgerId;
            SFDCSecurityUtils.upsertProxy(lcs);
        } 
        else {
            throw new LedgerServiceException(LEDGER_ENVIRONMENT_ERROR);
        }
    }

}