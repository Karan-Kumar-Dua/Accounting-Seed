/*
* All options required for a an api call to a banking direct service. Used as an input to the BDCService class
*/
global with sharing class BDCServiceOptions{
    @invocableVariable (label='Specifies the Banking Connect Service that provides the transactions.')
    global BDC_Binding__c bdcBinding;
    @invocableVariable
    global List<String> bdcAccountIds;
    @invocableVariable
    global List<String> bdcFinancialInstitutionIds;
    @invocableVariable
    global List<BDCFinancialInstitutionIdentity> bdcFinancialInstitutionIdentities;
    @invocableVariable
    global Date toDate;
    @invocableVariable
    global Date fromDate;
    @invocableVariable (label='the number of transactions to skip. Used for pagination or large volumes.')
    global Integer offset;
    @invocableVariable (label='The total number of records to retrieve (Yodlee and Plaid both max 500)')
    global Integer maxRecords;
}