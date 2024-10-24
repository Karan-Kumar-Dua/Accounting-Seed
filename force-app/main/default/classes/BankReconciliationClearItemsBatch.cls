public with sharing class BankReconciliationClearItemsBatch implements Database.Batchable<sObject>, Database.Stateful {
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private Id bankRecId;
    private Date bankRecEndDate;

    public BankReconciliationClearItemsBatch(Id brId) {
        this.bankRecId = brId;
    }

    public List<sObject> start(Database.BatchableContext bc) {
        List<sObject> objs;
        try {
            BankReconciliationModel model = BankReconciliation.retrieve(this.bankRecId, false, true);
            objs = model.items;
            this.bankRecEndDate = (Date) model.record.get(PACKAGE_QUALIFIER + 'End_Date__c');  
        }
        catch (Exception ex) {
            // Must catch unexpected exceptions.
            // Otherwise, the user could be stuck with bank rec in working status,
            // unable to delete bank rec or create new bank recs. 
            // Finish method must be called in order to fire platform event
            // transitioning bank rec from working to in-progress.
            objs = new List<sObject>();
        } 
        return objs;
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        System.Savepoint sp = Database.setSavepoint();
        try {
            List<Id> itemIdsToClear = new List<Id>();
            for (sObject item : scope) {
                if (item.get(PACKAGE_QUALIFIER + 'Cleared_Date__c') != NULL 
                    && (Date) item.get(PACKAGE_QUALIFIER + 'Cleared_Date__c') <= this.bankRecEndDate
                    && item.get(PACKAGE_QUALIFIER + 'Bank_Reconciliation__c') == NULL) {
                    itemIdsToClear.add(item.Id);        
                }
            }
            BankReconciliation.bypassItemLimit = true;
            ServiceResult sr = BankReconciliation.clear(this.bankRecId, itemIdsToClear);
        }
        catch (Exception ex) {
            Database.rollback(sp);
        }
    }

    public void finish(Database.BatchableContext bc) {
        Publishable event = EventPubSub.createEvent(
            EventPubSub.PublishDelay.IMMEDIATE, 
            EventRegistry.RegisteredEvent.BANK_RECONCILIATION_CLEAR_ITEMS, 
            bankRecId, 
            null
        );
        EventPubSub.publish(event);
    }
}