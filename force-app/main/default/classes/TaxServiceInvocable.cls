global with sharing class TaxServiceInvocable {

    private static final String ERROR_HIGH_LEVEL_POST = Label.TAX_SERVICE_HLP_ERROR_INVOCABLE;
    private static final String TAX_SERVICE_AVALARA_ERROR_INVOCABLE = Label.TAX_SERVICE_AVALARA_ERROR_INVOCABLE;

    global class TaxServiceInvocableException extends Exception{}

    /* 
    * Currently this invocable only supports Line Level Posting
    */
    @InvocableMethod(callout=true label='Calculate Tax: Source Documents' description='Calculate taxes for source documents. For example, Billings.' )
    global static List<TaxServiceResultInvocable> calcTax(List<List<SObject>> sourceDocs){
        List<TaxServiceResultInvocable> results = new List<TaxServiceResultInvocable>();
        //check for line level posting
        if (!AccountingSettingsHandler.isLineLevelPost()) {
            throw new TaxServiceInvocableException(ERROR_HIGH_LEVEL_POST);
        }

        List<SObject> nativeSourceDocs = new List<SObject>();
        List<SObject> avalaraSourceDocs = new List<SObject>();
        
        for(sObject sourceDoc : sourceDocs[0]){
          switch on sourceDoc {
            when Billing__c b {
              if(b.Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED){
                if(!AvaTaxHelper.isAvalaraTaxCalculationEnabled(b)) {
                  nativeSourceDocs.add(b);
                }
                else {
                  avalaraSourceDocs.add(b);
                }
              }
            }
          }
        }


        try {
            for(TaxServiceResult taxResult : TaxService.calcTaxes(nativeSourceDocs)){
                results.add(new TaxServiceResultInvocable(taxResult));
            }
            for(SObject avaRec : avalaraSourceDocs){

                  TaxServiceResultLineType resultLine = new TaxServiceResultLineType();
                  resultLine.isSuccess = false;
                  resultLine.sourceObj = avaRec;
                  resultLine.sourceRecordId = avaRec.Id;
                  results.add(new TaxServiceResultInvocable(true,new List<TaxServiceResultLineType>{resultLine}));
            }
        }
        catch (Exception ex) {throw new TaxServiceInvocableException(ex.getMessage()); }
        return results;
    }
}