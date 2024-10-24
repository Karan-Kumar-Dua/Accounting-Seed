public with sharing class PurgeInventoryBalanceHistoryBatch extends PurgeBaseBatch {

    private static final String BATCH_SOBJECT_NAME = GlobalVariables.ERPPACKAGE_QUALIFIER + 'Inventory_Balance_History__c';

    private static final String BATCH_SOBJECT_LABEL =
        (AccountingSettingsHandler.isERPEnabled())
            ? Schema.getGlobalDescribe().get(BATCH_SOBJECT_NAME.toLowerCase()).getDescribe().getLabel()
            : Label.COMMON_NOT_EXISTING_OBJECT;

    private static final String BATCH_SOBJECT_FIELD = GlobalVariables.ERPPACKAGE_QUALIFIER + 'Date__c';
    private static final String SELECT_QUERY = 'SELECT Id FROM {0} WHERE {1} < {2}';

    private final Date toDate;

    public PurgeInventoryBalanceHistoryBatch(Date valueToDate) {
        this.objectLabel = BATCH_SOBJECT_LABEL;
        this.toDate = valueToDate;
    }

    public override Database.QueryLocator start(Database.BatchableContext BC){
       return Database.getQueryLocator(
           String.format(SELECT_QUERY, new String[]{
               BATCH_SOBJECT_NAME,
               String.escapeSingleQuotes(BATCH_SOBJECT_FIELD),
               String.escapeSingleQuotes(String.valueOf(toDate))
           })
       );
    }

}