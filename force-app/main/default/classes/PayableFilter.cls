public with sharing class PayableFilter {
    public String payeeId; 
    public String postingStatus; 
    public String payableNumber;
    public String payeeReference;
    public Date issueDateStart;
    public Date issueDateEnd;
    public Date dueDateStart;
    public Date dueDateEnd;
    public Decimal payableAmountStart;
    public Decimal payableAmountEnd;
    public Id cashDisbursementId; 
    public Boolean includePaidPayables;       
}