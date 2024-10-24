global with sharing class TaxServiceResultInvocable {
    @InvocableVariable(label='Calc Tax Success' description='Calc Tax Success' )
    global Boolean isSuccess;

    @InvocableVariable(label='Results' description='Results' )
    global List<TaxServiceResultLineType> results;

    @InvocableVariable(label='xDeprecated' description='xDeprecated' )
    global List<TaxServiceResultLine> sourceDocs;

    public TaxServiceResultInvocable(TaxServiceResult res) {
        this.isSuccess = res.isSuccess;
        this.results = (List<TaxServiceResultLineType>)JSON.deserialize(JSON.serialize(res.sourceDocs),List<TaxServiceResultLineType>.class);
        for(TaxServiceResultLineType line : results){
            line.sourceRecordId = line.sourceObj.Id;
        }
    }

    public TaxServiceResultInvocable(Boolean isSuccess, List<TaxServiceResultLineType> results) {
        this.isSuccess = isSuccess;
        this.results = (List<TaxServiceResultLineType>)JSON.deserialize(JSON.serialize(results),List<TaxServiceResultLineType>.class);
    }

    //Deprecated inner classes
    global with sharing class TaxServiceResultLine{
        @InvocableVariable(label='xDeprecated' description='xDeprecated' )
        global Boolean isSuccess;
        @InvocableVariable(label='xDeprecated' description='xDeprecated' )
        global TaxServiceResultLineErrors errors;
        @InvocableVariable(label='xDeprecated' description='xDeprecated' )
        global SObject sourceObj;
        @InvocableVariable(label='xDeprecated' description='xDeprecated' )
        global List<SObject> sourceObjLines;
    } 
    global with sharing class TaxServiceResultLineErrors{
        @InvocableVariable(label='xDeprecated' description='xDeprecated' )
        global List<TaxServiceResultLineErrorItem> items;
    }
    global with sharing class TaxServiceResultLineErrorItem{
        @InvocableVariable(label='xDeprecated' description='xDeprecated' )
        global String message;
        @InvocableVariable(label='xDeprecated' description='xDeprecated' )
        global String code;
    }
    
    
}