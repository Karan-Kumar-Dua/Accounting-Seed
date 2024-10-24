public with sharing class AccountingLimitHandler {
    public enum LimitType {LEDGER_LIMIT, ARCHIVE_PERIOD_OFFSET}
    private static AccountingLimitHandler instance;
    private Map<String,Integer> limitMap;
    private static final Integer ARCHIVE_PERIOD_OFFSET_DEFAULT = 15;
    private static final Integer DEFAULT_LEDGER_LIMIT = 1;

    public class AccountingLimitHandlerException extends Exception {}

    private AccountingLimitHandler() {
         limitMap = new Map<String,Integer>();
    }

    public static AccountingLimitHandler getInstance() {
        if (instance == NULL) {
            instance = new AccountingLimitHandler();
        }

        return instance;
    }
    
    public void setLimit(LimitType aLimitType, Integer limitValue) {
        limitMap.put(aLimitType.name(),limitValue);
    }
    
    public Integer getLimit(LimitType aLimitType) {
        try {
            if (!limitMap.containsKey(aLimitType.name()) && LimitType.LEDGER_LIMIT == aLimitType) {
                limitMap.put(aLimitType.name(),getLedgerLimit());
            }
            
            if (!limitMap.containsKey(aLimitType.name()) && LimitType.ARCHIVE_PERIOD_OFFSET == aLimitType) {
                limitMap.put(aLimitType.name(),getArchiveMonthOffset());
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return limitMap.get(aLimitType.name());
    }

    private Integer getArchiveMonthOffset() {
        return AccountingSettingsHandler.getAccountingSettings().Archive_Month_Offset__c == NULL ? ARCHIVE_PERIOD_OFFSET_DEFAULT : AccountingSettingsHandler.getAccountingSettings().Archive_Month_Offset__c.intValue();
    }

    private Integer getLedgerLimit() {
        return AccountingSettingsHandler.getAccountingSettings().Ledger_Limit__c == NULL ? DEFAULT_LEDGER_LIMIT : AccountingSettingsHandler.getAccountingSettings().Ledger_Limit__c.intValue();
    }
}