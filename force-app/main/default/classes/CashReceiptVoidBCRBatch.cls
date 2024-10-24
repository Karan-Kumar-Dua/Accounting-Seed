public with sharing class CashReceiptVoidBCRBatch implements Database.Batchable<sObject>, Database.Stateful {
    //next batch size
    private static final Integer BATCH_SIZE = 1;
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    //void data mapped with related cashreceipt 
    private Map<Id,CashReceiptVoidHelper.VoidData> crWithVoidData;
    //all sucessfully created billing cash receipts with cash receipts
    private Map<Id,Set<Id>> bcrsWithCrId;
    //all failed cash receipt ids
    private Set<Id> failedCrIds;
    private String query;
    private AJRLogger logger; 

    //constructor
    public CashReceiptVoidBCRBatch(Map<Id,CashReceiptVoidHelper.VoidData> crWithVoidData,AJRLogger logger ) {
        this.crWithVoidData = crWithVoidData;
        this.failedCrIds = new Set<Id>();
        this.bcrsWithCrId = new Map<Id,Set<Id>>();
        this.logger = logger;
        //prepare query
        this.query = 'SELECT Id, ' +
                            PACKAGE_QUALIFIER + 'Cash_Receipt__c, ' +
                            PACKAGE_QUALIFIER + 'Cash_Receipt__r.Status__c, ' +
                            PACKAGE_QUALIFIER + 'Cash_Receipt__r.Void__c, ' +
                            PACKAGE_QUALIFIER + 'Cash_Receipt__r.Bank_Reconciliation__c, ' +
                            PACKAGE_QUALIFIER + 'Cash_Receipt__r.Receipt_Date__c, ' +
                            PACKAGE_QUALIFIER + 'Cash_Receipt__r.Cash_Flow_Category__c, ' +
                            PACKAGE_QUALIFIER + 'Accounting_Period__c, ' +
                            PACKAGE_QUALIFIER + 'Adjustment_Amount__c, ' +
                            PACKAGE_QUALIFIER + 'Adjustment_GL_Account__c, ' +
                            PACKAGE_QUALIFIER + 'Applied_Amount__c, ' +
                            (isMultiCurrencyEnabled ? 'CurrencyIsoCode, ' : '') +
                            PACKAGE_QUALIFIER + 'Billing__c '+
                    'FROM ' + PACKAGE_QUALIFIER + 'Billing_Cash_Receipt__c ' +
                    'WHERE ' + PACKAGE_QUALIFIER + 'Cash_Receipt__c IN  :genericIdSet';
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocator(query, crWithVoidData.keySet());
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Billing_Cash_Receipt__c> counterBcrs = new List<Billing_Cash_Receipt__c>();

        for(Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>)scope){
            //only process those bcr whose cash receipt is not in failed cash receipt set
            if(!failedCrIds.contains(bcr.Cash_Receipt__c)){
                CashReceiptVoid.ValidationResult validationResult = CashReceiptVoid.validateCashReceipt(bcr, crWithVoidData.get(bcr.Cash_Receipt__c));
                if (validationResult.ok) {
                    //create counter bcr for the source bcrs
                    counterBcrs.add(new CashReceiptVoid().initializeVoidData(crWithVoidData.get(bcr.Cash_Receipt__c)).createCounterBCR(bcr));
                } else {
                    failedCrIds.add(bcr.Cash_Receipt__c);
                    // log error
                }
            }
        }

        if(!counterBcrs.isEmpty()){
            //insert the counter BCR
            List<Database.SaveResult> results = SFDCSecurityUtils.insertCheckCRUDAndFLS(counterBcrs, new List<String>());

            //loop through the results
            for(Integer i = 0 ; i < results.size() ; i++){
                //if record failed put it in failed set
                //if passed store in collection of map 
                if(!results[i].isSuccess()){
                    failedCrIds.add(counterBcrs[i].Cash_Receipt__c);
                    for (Database.Error dbError : results[i].getErrors()) {
                        logger.logError(counterBcrs[i].Cash_Receipt__c,dbError.getMessage());
                    }
                }else{
                    if(bcrsWithCrId.get(counterBcrs[i].Cash_Receipt__c)?.add(results[i].getId()) == null){
                        bcrsWithCrId.put(counterBcrs[i].Cash_Receipt__c, new Set<Id>{results[i].getId()});
                    }
                }
            }
        }
    }

    public void finish (Database.BatchableContext BC) {
        logger.save();
        Map<Id,CashReceiptVoidHelper.VoidData> passedCrWithVoidData = new Map<Id,CashReceiptVoidHelper.VoidData>();

        //filter only those cr records whose bcr are successfully created
        for(Id crId : crWithVoidData.keySet()){
            if(!failedCrIds.contains(crId)){
                passedCrWithVoidData.put(crId,crWithVoidData.get(crId));
            }
        }
        //execute next batch
        Database.executeBatch(new VoidTransactionUpdateCashReceiptsBatch(passedCrWithVoidData,failedCrIds,bcrsWithCrId,logger),BATCH_SIZE);
    }
}