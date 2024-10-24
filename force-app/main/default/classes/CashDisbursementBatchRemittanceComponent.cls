public with sharing class CashDisbursementBatchRemittanceComponent {
    public CashDisbursementWrapper cCashDisbursement{get; set;}
    public List<CashDisbursementWrapper> cCashDisbursements {get{
        if (offsetsByCashDisbursement != null) {
            return cCashDisbursements;
        } 
        else {
            if (cCashDisbursements == null) {
                cCashDisbursements = new List<CashDisbursementWrapper>();
                if (cCashDisbursement != null) {
                    cCashDisbursements.add(cCashDisbursement);
                }
            }
            offsetsByCashDisbursement = createOffsets(cCashDisbursements);
        }
        return cCashDisbursements;
    } set;}
    public Map<Id, List<Integer>> offsetsByCashDisbursement {get; set;}
    
    public Boolean cShowRemittances {get; set;}
    public Integer cLimitRemittances {get; set;}
    public Integer cPerPageRemittances {get; set;}
    
    private Map<Id, List<Integer>> createOffsets(List<CashDisbursementWrapper> cashDisbursements) {
        Map<Id, List<Integer>> result = new Map<Id, List<Integer>>();
        for (CashDisbursementWrapper cb: cashDisbursements) {
            if (!result.containsKey(cb.cashDisbursement.Id)) {
                List<Integer> offsets = new List<Integer>();
                Integer totalRemittances = cb.remittances.size();
                Integer limitRemittances = (cLimitRemittances < totalRemittances) 
                    ? cLimitRemittances : totalRemittances;
                offsets.add(0); //First offset must always exist
                if (cShowRemittances != null && cPerPageRemittances != null && cShowRemittances) {
                    for (Integer i = cPerPageRemittances; i < limitRemittances; i+=cPerPageRemittances) {
                        offsets.add(i);
                    }
                }
                result.put(cb.cashDisbursement.Id, offsets);
            }
        }
        return result;
    }
}