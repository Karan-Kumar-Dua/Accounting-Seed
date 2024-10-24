public with sharing class RemittanceWrapper implements Comparable {
    public Account_Payable__c accountPayable {get; set;}
    public Decimal amount {get; private set;}
    public Decimal fullAmount {get; private set;}
    public Decimal discount {get; private set;}
    public Decimal netAmount {get; private set;}

    public RemittanceWrapper(Account_Payable__c accountPayable, Decimal amount) {
        this.accountPayable = accountPayable;
        if (this.accountPayable.Discount_Amount__c == null) {
            this.accountPayable.Discount_Amount__c = 0.0;
        }
        if (this.accountPayable.Credit_Memo_Applied_Amount__c == null) {
            this.accountPayable.Credit_Memo_Applied_Amount__c = 0.0;
        }
        this.amount = amount;
        calculateParams();
    }
    
    public void calculateParams() {
        fullAmount = 0;
        if (accountPayable != null && amount!=null) {
            fullAmount = amount + accountPayable.Discount_Amount__c;
        }
        if (accountPayable != null && accountPayable.Type__c=='Invoice') {
            fullAmount += accountPayable.Credit_Memo_Applied_Amount__c;
        }
        
        discount = 0;
        if (accountPayable != null) {
            discount = accountPayable.Discount_Amount__c;
        }
        
        netAmount = 0;
        if (accountPayable != null && amount!=null && accountPayable.Type__c=='Invoice') {
            netAmount = amount + accountPayable.Credit_Memo_Applied_Amount__c;
        } 
        else if (accountPayable != null && amount!=null && accountPayable.Type__c=='Credit Memo') {
            netAmount = amount + accountPayable.Discount_Amount__c;
        }
    }
    
    public void aggregateWith(RemittanceWrapper rw) {
        this.amount += rw.amount;
        this.fullAmount += rw.fullAmount;
        this.discount += rw.discount;
        this.netAmount += rw.netAmount;
    }
    
    public Integer compareTo(Object compareTo) {
        RemittanceWrapper compareToRW = (RemittanceWrapper)compareTo;
        Date compareDate;
        
        if (compareToRW.accountPayable.Date__c != null) {
            compareDate = compareToRW.accountPayable.Date__c;
        }
                
        if (accountPayable.Date__c == compareDate) return 0;
        if (accountPayable.Date__c > compareDate) return 1;
        return -1;        
    }
}