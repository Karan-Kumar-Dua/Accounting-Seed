/*
* Represents a financial instition retrieved from a banking service such as Yodlee or Plaid
*/
global with sharing class BDCFinancialInstitution {
    global String id {get; set;}
    global String name {get; set;}
    global String source {get; set;}
}