/*
* Represents a category retrieved from a banking service such as Yodlee or Plaid
*/
global with sharing class BDCCategory{
    global String Id {get; set;}
    global String name {get; set;}
    global String source {get; set;}
    global String parentCategoryId {get; set;}
}