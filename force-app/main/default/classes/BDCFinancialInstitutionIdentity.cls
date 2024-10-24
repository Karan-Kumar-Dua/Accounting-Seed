/*
* Represents an online login for a financial institution
*/
global with sharing class BDCFinancialInstitutionIdentity {
    @AuraEnabled global String id {get; set;}
    @AuraEnabled global String financialInstitutionId {get; set;}
    @AuraEnabled global String identityName {get; set;}
    @AuraEnabled global String status {get; set;}
    @AuraEnabled global String source {get; set;}
    @AuraEnabled global List<String> additionalStatus {get; set;}
}