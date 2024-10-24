/*
* Represents a transaction retrieved from a banking service such as Yodlee or Plaid
*/
global with sharing class BDCTransaction {
    global String id {get; set;}
    global String accountId {get; set;}
    global String categoryId {get; set;}
    global Decimal amount {get; set;}
    global Date transactionDate {get; set;}
    global Date postDate {get; set;}
    global String description {get; set;}
    global String shortDescription {get; set;}
    global String checkNumber {get; set;}
    global Decimal runningBalance {get; set;}
    global String currencyIsoCode {get; set;}
    global String merchantName {get; set;}
    global String merchantType {get; set;}
    global String merchantCategory {get; set;}
    global String merchantId {get; set;}
    global String type {get; set;}
    global String memo {get; set;}
    global String status {get; set;}
    global String GLAccountMappingId {get; set;}
    global String source {get; set;}
    global String baseType {get; set;}
    global String container {get; set;}
    global String categoryType {get; set;}
    global String categoryLevel1Id {get; set;}
    global String categoryLevel2Id {get; set;}
    global String categoryLevel3Id {get; set;}
    global String categoryCustomId {get; set;}



    public BDCTransaction(){}

     //Used during Financial File parsing
     public BDCTransaction(
        String id,
        Date transactionDate,
        Decimal amount,
        String currencyIsoCode,
        String baseType,
        String accountId,
        String accountType,
        String description,
        String memo,
        String checkNumber
    ) {
        this.id = id;
        this.transactionDate = transactionDate;
        this.amount = amount;
        this.currencyIsoCode = currencyIsoCode;
        this.baseType = baseType;
        this.accountId = accountId;
        this.container = accountType;
        //this.description = new TransactionDescription(description);
        this.description = description;
        this.memo = memo;
        this.checkNumber = checkNumber;
    }
}