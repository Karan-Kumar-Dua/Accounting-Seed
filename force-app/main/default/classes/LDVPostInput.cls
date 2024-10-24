public with sharing class LDVPostInput {

    public String id {get; set;}
    public List<SObject> lines {get; set;}
    public Transaction_Group__c transactionGroup {get; private set;}
    public List<SObject> relatedObjects {get; set;}

    public LDVPostInput() {
        lines = new List<SObject>();
        relatedObjects = new List<SObject>();
    }

    public LDVPostInput(Transaction_Group__c transactionGroup) {
        this();
        this.transactionGroup = transactionGroup;
    }

}