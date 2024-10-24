public with sharing class UpdateDefault1099InfoCntrlExt {
    public Boolean isMyDomainEnabled {get;private set;}
    public List<SObject> selectedRecords;
    public String recordIds{get;set;}

    // Constructor
    public UpdateDefault1099InfoCntrlExt(ApexPages.StandardSetController cntlr){
        selectedRecords = cntlr.getSelected(); //get selected records from list view
        recordIds = '';          
        for(SObject record : selectedRecords){
            recordIds += record.Id + ','; 
        }
        recordIds = recordIds.removeEnd(','); 
        isMyDomainEnabled = GlobalVariables.isMyDomainEnabled;
    } 

}