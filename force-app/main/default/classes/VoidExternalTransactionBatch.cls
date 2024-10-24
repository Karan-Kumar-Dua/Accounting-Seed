public with sharing class VoidExternalTransactionBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String JOB_NAME = 'Cash Receipt Void';
    private static final String REPORT_NAME = 'Cash Receipt Void Job';
    //void data mapped with related cashreceipt 
    private Map<Id,CashReceiptVoidHelper.VoidData> crWithVoidData;
    //all failed cash receipt ids
    private Set<Id> failedCrIds;
    private String query;
    private AJRLogger logger; 

    //constructor
    public VoidExternalTransactionBatch(Map<Id,CashReceiptVoidHelper.VoidData> crWithVoidData) {
        this.crWithVoidData = crWithVoidData;
        this.failedCrIds = new Set<Id>();
        this.logger = getLogger();
        //prepare query to fetch cash receipts
        this.query = 'SELECT Id ' + 
                    'FROM ' + PACKAGE_QUALIFIER + 'Cash_Receipt__c ' +
                    'WHERE Id IN  :genericIdSet';
    }
    /**
     * Create an fresh instance of AJRLooger with specific data sets
     * Return : AJRLogger
     */
    public static AJRLogger getLogger() {
        AJRLogger.TaskOptions taskOpts = new AJRLogger.TaskOptions();
        taskOpts.subject = Label.ERR_CASH_RECEIPT_CANT_BE_VOIDED;
        AJRLogger.Config config = new AJRLogger.Config();
        config.jobName = JOB_NAME;
        config.reportName = REPORT_NAME;
        config.taskOptions = taskOpts;
        return new AJRLogger(config);
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query, crWithVoidData.keySet());
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        try{
            //make a callout to cardknox to void the transaction
            for(Cash_Receipt__c cr : (List<Cash_Receipt__c>)scope){
                new CashReceiptVoid()
                    .initializeVoidData(crWithVoidData.get(cr.Id))
                    .fetchPaymentActivity()
                    .voidTransactionInExternalSystem();
            }
        }catch(Exception e){
            //if anything fails put the cr in failed crIds
            for(Cash_Receipt__c cashReceipt : (List<Cash_Receipt__c>) scope){
                failedCrIds.add(cashReceipt.Id);
                logger.logError(cashReceipt.Id,e.getMessage());
            }
        }
    }
    public void finish (Database.BatchableContext BC) {
        logger.save();
        Map<Id,CashReceiptVoidHelper.VoidData> successCrWithVoidData = new Map<Id,CashReceiptVoidHelper.VoidData>();
        
        //filter bcrs to delete them in the next batch
        for(Id crId : crWithVoidData.keySet()){
            if(!failedCrIds.contains(crId)){
                successCrWithVoidData.put(crId,crWithVoidData.get(crId));
            }
        }
        
        if(!successCrWithVoidData.isEmpty() && successCrWithVoidData.values().size() != 0){
            //run next batch to create bcr
            Database.executeBatch(new CashReceiptVoidBCRBatch(successCrWithVoidData,logger));
        }
    }
}