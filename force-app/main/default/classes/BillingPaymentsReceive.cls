public with sharing class BillingPaymentsReceive {
    public String recordIds {get; set;}

    public BillingPaymentsReceive(ApexPages.StandardSetController setController) {
        List<Id> recordIds = new List<Id>();
        for(SObject record : setController.getSelected()){
            recordIds.add(record.Id);
        }
        this.recordIds = JSON.serialize(recordIds);
    }

    public PageReference urlRedirection() {

        string url = '/lightning/cmp/AcctSeed__PaymentsReceiveNavProxy?AcctSeed__recordIds=' + this.recordIds;

        PageReference page = new PageReference(url);
        page.setRedirect(true);
        return page;
    }
}