public with sharing class CashDisbursementRemittanceComponent {
    public CashDisbursementWrapper cCashDisbursement {get{
        if (cCashDisbursement == null) {
            cCashDisbursement = new CashDisbursementWrapper();
        }
        return cCashDisbursement;
    } set;}
}