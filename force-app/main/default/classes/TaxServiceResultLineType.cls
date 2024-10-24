global with sharing class TaxServiceResultLineType{
    @AuraEnabled
    global Boolean isSuccess;

    @AuraEnabled
    global Id sourceRecordId;

    //sObject is not supported from Flow so they are not @AuraEnabled
    global SObject sourceObj;
    global List<SObject> sourceObjLines;
}