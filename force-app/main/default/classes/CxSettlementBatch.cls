/**
When a Cardknox Batch is complete, and a Bank Deposit has been created in Salesforce, 
a Journal Entry must be created in Accounting Seed to record the fees and movement of money. 

For each Bank Deposit (form job above),  
- Create a Journal Entry record and Journal Entry Lines.  
    - Journal Entry Line 1:   
        - GL_Account__c = Any Cash Receipt associated with the Bank Deposit -> Cash_Receipt__c.Payment_Processor__r.Merchant_GL_Account__c  
        - Credit__c= Total of all Cash_Receipt__c.Ledger_Amount__c associated with the Bank Deposit 
    - Journal Entry Line 2:  
        - GL_Account__c = Any Cash Receipt associated with the Bank Deposit -> Cash_Receipt__c.Payment_Processor__r.Bank_GL_Account__c  
        - Debit__c  = Total of all Cash_Receipt__c.Ledger_Amount__c associated with the Bank Deposit 
    - Journal Entry Line 3: 
        - GL_Account__c = Any Cash Receipt associated with the Bank Deposit -> Cash_Receipt__c.Payment_Processor__r.Bank_GL_Account__c 
        - Credit__c =  Total of all Payment_Activity__c.Fee__c associated with the Bank Deposit 
    - Journal Entry Line 4: 
        - GL_Account__c = Any Cash Receipt associated with the Bank Deposit -> Cash_Receipt__c. Merchant_Fees_GL_Account__c 
        - Debit__c = Total of all Payment_Activity__c.Fee__c associated with the Bank Deposit 
 */
public with sharing class CxSettlementBatch implements Database.Batchable<SObject>, Database.Stateful{
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private Integer currentExecutionSucceed = 0;
    private Integer currentExecutionFailed = 0;
    // wrapper instace to holds success and failed items
    CxTxnsUpdater.ProcessedBankDeposits processedBds;
    private String jobName = 'Merchant Download Job';
    public Datetime endDate;
    public Set<Id> bankDepIds = new Set<Id>();
    public Set<Id> ppIds = new Set<Id>();
    public CxAJRLogger logger = new CxAJRLogger(); 

    public CxSettlementBatch(CxTxnsUpdater.ProcessedBankDeposits processedBds, DateTime endDate, CxAJRLogger logger){
        this.endDate = endDate;
        this.processedBds = processedBds;
        this.logger = logger;
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return DomainUtils.getQueryLocatorForCxSettlementBatch(this.processedBds.successfulBDIds,this.processedBds.failedMerchantBatchId);
    }

    public void execute(Database.BatchableContext ctx, List<SObject> scope) {
        try {
            CxSettler cx = new CxSettler();
            CxSettler.SettlerWrapper rw = cx.createJournalEntryWithLines(scope, ppIds, logger);
            currentExecutionFailed = currentExecutionFailed + rw.failedRecords;
            currentExecutionSucceed = currentExecutionSucceed + rw.succeedRecords;
            this.ppIds = rw.ppLastSyncUpdate;
        } catch(Exception e) {
            Set<Id> loggedProcessors = new Set<Id>();
            for (Bank_Deposit__c deposit : (List<Bank_Deposit__c>)scope) {
                if (deposit.Cash_Receipts__r != null && !deposit.Cash_Receipts__r.isEmpty()) {
                    Id processorId = deposit.Cash_Receipts__r.get(0).Payment_Processor__c;
                    if (!loggedProcessors.contains(processorId)) {
                        loggedProcessors.add(processorId);
                        logger.logError(processorId, e.getMessage() + '\n' + e.getStackTraceString());
                    }
                }
            }
        }
        logger.write();
    }

    public void finish(Database.BatchableContext ctx) {
        for(Id ppId : this.ppIds){
            if(!this.processedBds.failedBdProcessorIds.contains(ppId)){
                logger.logSuccess(ppId);
            }
        }
        logger.write();
        logger.sendEmail();
    }

}