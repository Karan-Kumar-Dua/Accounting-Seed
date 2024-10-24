public with sharing class AvaTaxAsyncTransactionHandler implements Queueable, Database.AllowsCallouts {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;

    private Set<Id> sourceRecordIds;
    private Boolean doCommit;
    private AvaTaxContext exContext;

    public enum AvaTaxContext {CREATE, UNCOMMIT}

    public AvaTaxAsyncTransactionHandler(AvaTaxContext context, Set<Id> sourceRecordIds, Boolean doCommit) {
        this.exContext = context;
        this.sourceRecordIds = sourceRecordIds;
        this.doCommit = doCommit;
    }

    public AvaTaxAsyncTransactionHandler(AvaTaxContext context, List<SObject> sourceRecords) {
        this.exContext = context;
        this.sourceRecordIds = new Map<Id, SObject>(sourceRecords).keySet();
        this.doCommit = false;
    }

    public void execute(QueueableContext qContext) {
        if (sourceRecordIds == NULL || sourceRecordIds.isEmpty()) {
            return;
        }

        switch on exContext {
            when CREATE {
                createOrAdjustAvaTaxTransaction();
            }
            when UNCOMMIT {
                uncommitAvaTaxTransactions();
            }
        }

    }

    private void createOrAdjustAvaTaxTransaction() {
        AvaTaxService.DocumentType docType;
        Map<Id, SObject> sourceRecordMap = new Map<Id, SObject>();
        Map<Id, List<SObject>> masterToDetailsMap = new Map<Id, List<SObject>>();

        docType = AvaTaxService.DocumentType.SalesInvoice;
        if (isMultiCurrencyEnabled) {
            for (Billing__c billFromDB : AvaTaxHelper.queryBillingById(sourceRecordIds, doCommit)) {
                if (AvaTaxHelper.isLedgerCurrencySupportedByAvaTaxCalculation((Id) billFromDB.get(PACKAGE_QUALIFIER + 'Ledger__c'))) {
                    sourceRecordMap.put(billFromDB.Id, billFromDB);
                }
            }
        }
        else {
            sourceRecordMap = new Map<Id, SObject>(AvaTaxHelper.queryBillingById(sourceRecordIds, doCommit));
        }

        AvaTaxHelper.sourceRecordMap = sourceRecordMap;
        for (SObject line : AvaTaxHelper.queryTaxableBillingLinesByBillingId(sourceRecordMap.keySet())) {
            if (masterToDetailsMap.containsKey((Id) line.get(PACKAGE_QUALIFIER + 'Billing__c'))) {
                masterToDetailsMap.get((Id) line.get(PACKAGE_QUALIFIER + 'Billing__c')).add(line);
            }
            else {
                masterToDetailsMap.put((Id) line.get(PACKAGE_QUALIFIER + 'Billing__c'), new List<SObject>{line});
            }
        }

        for (SObject sourceRecord : sourceRecordMap.values()) {
            if (masterToDetailsMap.containsKey(sourceRecord.Id)) {
                try {
                    AvaTaxHelper.calcTax(sourceRecord, masterToDetailsMap.get(sourceRecord.Id), docType, doCommit);
                }
                catch (AvaTaxService.AvaTaxException avaTaxException) {

                }
            }
        }
    }

    private void uncommitAvaTaxTransactions() {
        AvaTaxHelper.uncommitTransactions(sourceRecordIds);
    }

}