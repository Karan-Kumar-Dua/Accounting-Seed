global with sharing class CashDisbursementWrapper implements Comparable {

    public Cash_Disbursement__c cashDisbursement {get; set;}
    public Boolean isDiscountAmountEditable {
        get {
            return isDiscountAmountEditable != null && isDiscountAmountEditable;
        }
        set;
    }
    public Boolean isDiscountAmountReady4Edit {
        get {
            return !payments.isEmpty() && (
                payments[0].Account_Payable_Cash_Disbursements__r.isEmpty() ||
                (payments[0].Credit_Memo_Applied_Amount__c > 0 && payments[0].Balance__c > 0 && payments[0].Paid_Amount__c == 0)
            );
        }
        set;
    }
    public Decimal discountAmount {get; set;}
    public Decimal taxAmount {get; set;}
    public Decimal creditMemoAmount {get; set;}
    public Decimal paidAmount {get; set;}
    public Boolean isSelected {get; set;}
    public List<Account_Payable__c> payments {get; set;}
    public String payee {get; set;}
    public List<RemittanceWrapper> remittances {get; set;}
    public Boolean is1099Vendor {get; set;}
    public List<SelectOption> formCategories {get; set;}

    public Boolean isPersonAccountPayee = false;

    public Double getTotalAmount() {
        return cashDisbursement.Amount__c + paidAmount + discountAmount + taxAmount + creditMemoAmount;
    }
    
    public CashDisbursementWrapper() {
        cashDisbursement = new Cash_Disbursement__c();
        remittances = new List<RemittanceWrapper>();
    }
    
    public CashDisbursementWrapper( Cash_Disbursement__c cashDisbursement,
                                    List<RemittanceWrapper> remittances,
                                    Boolean isAggregate) {

        this.cashDisbursement = cashDisbursement;
        this.remittances = (isAggregate) ? aggregateRemittances(remittances) : remittances;
    }
    
    public static List<RemittanceWrapper> aggregateRemittances(List<RemittanceWrapper> rs) {
        Map<Id, Integer> indexRemittanceByAPId = new Map<Id, Integer>();

        for (Integer i = 0; i < rs.size(); i++) {
            Id apId = rs.get(i).accountPayable.Id;
            if (!indexRemittanceByAPId.containsKey(apId)) {
                indexRemittanceByAPId.put(apId, i);
            } 
            else {
                Integer indexRemittance = indexRemittanceByAPId.get(apId);
                rs.get(indexRemittance).aggregateWith(rs.get(i));
                rs.remove(i);
                i--;
            }
        }
        return rs;
    }
    
    public CashDisbursementWrapper( Cash_Disbursement__c cashDisbursement,
                                    String payee,
                                    Decimal discountAmount,
                                    Decimal taxAmount,
                                    Decimal creditMemoAmount,
                                    Decimal paidAmount,
                                    List<Account_Payable__c> payments) {

        this.cashDisbursement = cashDisbursement;
        this.payments = payments;
        this.payee = payee;
        this.discountAmount = discountAmount;
        this.taxAmount = taxAmount;
        this.creditMemoAmount = creditMemoAmount;
        this.paidAmount = paidAmount;
        isSelected = true;
        this.is1099Vendor = false;
        if (payments[0].Vendor__c != NULL) {
            this.is1099Vendor = payments[0].Vendor__r.X1099_Vendor__c;
        }
        if (payments[0].Contact__c != NULL) {
            this.is1099Vendor = payments[0].Contact__r.X1099_Vendor__c;
        }
        if (GlobalVariables.isPersonAccountEnabled && payments[0].Contact__c != null && payments[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('IsPersonAccount') == true) {
            isPersonAccountPayee = true;
        }
    }
    
    global Integer compareTo(Object compareTo) {
        CashDisbursementWrapper compareToCd = (CashDisbursementWrapper) compareTo;
        String comparePayee;
        
        if (compareToCd.cashDisbursement.Vendor__c != NULL) {
            comparePayee = compareToCd.payments[0].Vendor__r.Name;
        }
        else if (compareToCd.cashDisbursement.Contact__c != NULL) {
            comparePayee = compareToCd.payments[0].Contact__r.Name;
        }
        else {
            comparePayee = compareToCd.payments[0].Employee__r.Name;
        }
                
        if (payee == comparePayee) return 0;
        if (payee > comparePayee) return 1;
        return -1;        
    }
    
    public Accounting_Period__c getMostRecentAccountingPeriod() {
        Accounting_Period__c period = new Accounting_Period__c(Name = '1970-03');
        Date startDate;
        if (!payments.isEmpty()) {
            for (Account_Payable__c payment : payments) {
                if (startDate == NULL) {
                    startDate = payment.Accounting_Period__r.Start_Date__c;
                    period = payment.Accounting_Period__r;
                }
                else if (payment.Accounting_Period__r.Start_Date__c > startDate) {
                    startDate = payment.Accounting_Period__r.Start_Date__c;
                    period = payment.Accounting_Period__r;
                }
            }
        }
        
        return period;
    }

    public Id getPersonAccountId () {
        return isPersonAccountPayee ? (Id) payments[0].getSobject(GlobalVariables.PACKAGE_QUALIFIER + 'Contact__r').get('AccountId') : null;
    }

}