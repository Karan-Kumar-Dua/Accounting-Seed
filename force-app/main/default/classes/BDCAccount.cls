/*
* Represents an account retrieved from a banking service such as Yodlee or Plaid
*/
global with sharing class BDCAccount {
    global String Id {get; set;}
    global String financialInstitutionIdentity {get; set;}
    global String financialInstitutionId {get; set;}
    global String name {get; set;}
    global String nickname {get; set;}
    global String accountType {get; set;}
    global String accountNumber {get; set;}
    global String maskedAccountNumber {get; set;}
    global String status {get; set;}
    global String ledgerId {get; set;}
    global String glAccountId {get; set;}
    global String source {get; set;}
    global DateTime lastRefreshDate {get; set;}
    global DateTime initialStartDate {get; set;}
    global Decimal balance {get; set;}
    global Decimal currentBalance {get; set;}
    global Decimal availableBalance {get; set;}
    global String bdcCurrencyISOCode {get; set;}
    global DateTime lastUpdated {get; set;}
    
}