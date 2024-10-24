public with sharing class PaymentProposalLineActions {

    private static final String ERROR_VENDOR_PPL = Label.ERROR_VENDOR_PPL;
    private static final String ERROR_PAYABLE_ON_HOLD_PPL = Label.ERROR_PAYABLE_ON_HOLD_PPL;
    private static final String ERROR_AMOUNT_PPL = Label.ERR_PPL_AMOUNT_FIELD;
    private static final String ERROR_PPL_CREDIT_MEMO = Label.ERROR_PPL_CREDIT_MEMO;
    private static final String COMMON_CREDIT_MEMO = Label.COMMON_CREDIT_MEMO;
    private static final String ERROR_INVALID_CURRENCYISOCODE_PAYABLE = Label.ERROR_INVALID_CURRENCYISOCODE_PAYABLE;
    private static final String ERR_PPL_DISCOUNT_AMOUNT_NOT_MORE_THAN_CURRENT_BALANCE = Label.ERR_PPL_DISCOUNT_AMOUNT_NOT_MORE_THAN_CURRENT_BALANCE;
    private static final String ERR_PPL_DISCOUNT_AMOUNT_LESS_THAN_ZERO = Label.ERR_PPL_DISCOUNT_AMOUNT_LESS_THAN_ZERO;
    private static final String ERROR_CANNOT_ADD_PAYABLE_WITH_0_BALANCE = Label.ERROR_CANNOT_ADD_PAYABLE_WITH_0_BALANCE;

    public static void validate(List<Payment_Proposal_Line__c> PPLs, Map<Id, Payment_Proposal_Line__c> oldPPLs){
        Set<Id> payableIds = new Set<Id>();
        Set<Id> paymentProposalIds = new Set<Id>();
        for (Payment_Proposal_Line__c ppl : PPLs) {
            paymentProposalIds.add(ppl.Payment_Proposal__c);
            if(ppl.Payable__c != null) {
                payableIds.add(ppl.Payable__c);
            }
        }
        //get related records for validation
        Map<Id, Account_Payable__c> accountPayableMap = new Map<Id, Account_Payable__c>(DomainUtils.getAccountPayablesById(payableIds));
        Map<Id, Payment_Proposal__c> paymentProposalMap = new Map<Id, Payment_Proposal__c>(DomainUtils.getPaymentProposalsById(paymentProposalIds));

        Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        for (Payment_Proposal_Line__c ppl : PPLs){
            if (isMultiCurrencyEnabled) {
                validateCurrencyIsoCode(ppl, accountPayableMap, paymentProposalMap);
            }
            //if changing to Paid or Error then bypass validation
            if((ppl.Status__c == 'Paid' && oldPPLs.get(ppl.Id).Status__c != 'Paid') || (ppl.Status__c == 'Error' &&  oldPPLs.get(ppl.Id).Status__c != 'Error')){
                continue;
            }
            if(accountPayableMap.containsKey(ppl.Payable__c)) {
                validateVendor(ppl, accountPayableMap);
                validatePayable(ppl, accountPayableMap);
            }
            validateAmount(ppl);
            validatePayableBalance(ppl, accountPayableMap);
            validatePayableCreditMemo(ppl, accountPayableMap, paymentProposalMap);
        }
    }

    private static void validatePayableBalance( Payment_Proposal_Line__c ppl , Map<Id, Account_Payable__c> accountPayableMap ){
        if( accountPayableMap.containsKey(ppl.Payable__c) && accountPayableMap.get(ppl.Payable__c).Balance__c != null && accountPayableMap.get(ppl.Payable__c).Balance__c == 0 ){
            ppl.addError(ERROR_CANNOT_ADD_PAYABLE_WITH_0_BALANCE);
        }
    }

    private static void validateCurrencyIsoCode(Payment_Proposal_Line__c ppl, Map<Id, Account_Payable__c> accountPayableMap, Map<Id, Payment_Proposal__c> paymentProposalMap) {
        if (ppl.Payable__c != null && ppl.Payment_Proposal__c != null
                && accountPayableMap.containsKey(ppl.Payable__c) && paymentProposalMap.containsKey(ppl.Payment_Proposal__c)
                && accountPayableMap.get(ppl.Payable__c).get('currencyisocode') != paymentProposalMap.get(ppl.Payment_Proposal__c).get('currencyisocode')) {
            ppl.addError(ERROR_INVALID_CURRENCYISOCODE_PAYABLE);
        } else if (accountPayableMap.containsKey(ppl.Payable__c)) {
            ppl.put('currencyisocode', String.valueOf(accountPayableMap.get(ppl.Payable__c).get('currencyisocode')));
        } else if (ppl.Payable__c == null){
            ppl.put('currencyisocode', String.valueOf(paymentProposalMap.get(ppl.Payment_Proposal__c).get('currencyisocode')));
        }
    }

    private static void validateVendor(Payment_Proposal_Line__c ppl, Map<Id, Account_Payable__c> accountPayableMap){
        if (ppl.Vendor__c != null && ppl.Payable__c != null && ppl.Vendor__c != accountPayableMap.get(ppl.Payable__c).Vendor__c) {
            ppl.addError(ERROR_VENDOR_PPL);
        }
    }

    private static void validatePayable(Payment_Proposal_Line__c ppl, Map<Id, Account_Payable__c> accountPayableMap)
    {
        if (ppl.Payable__c != null
            && accountPayableMap.get(ppl.Payable__c).On_Hold__c == true) {
                ppl.addError(ERROR_PAYABLE_ON_HOLD_PPL);
        }
    }

    private static void validateAmount(Payment_Proposal_Line__c ppl){
        if (ppl.Amount__c != null && Integer.valueOf(ppl.Amount__c) != 0 && ppl.Payable__c != null  
            && ((ppl.Is_Credit__c && ppl.Amount__c < ppl.Current_Balance__c) || (!ppl.Is_Credit__c && ppl.Amount__c > ppl.Current_Balance__c))){
            ppl.addError(ERROR_AMOUNT_PPL);
        }

        if (ppl.Discount_Amount__c < 0) {
            ppl.addError(ERR_PPL_DISCOUNT_AMOUNT_LESS_THAN_ZERO);
        }

        if (ppl.Discount_Amount__c > ppl.Current_Balance__c) {
            ppl.addError(ERR_PPL_DISCOUNT_AMOUNT_NOT_MORE_THAN_CURRENT_BALANCE);
        }
        
    }
    private static void validatePayableCreditMemo(Payment_Proposal_Line__c ppl, Map<Id, Account_Payable__c> accountPayableMap, Map<Id, Payment_Proposal__c> paymentProposalMap ){
        if(ppl.Payable__c != null && paymentProposalMap.get(ppl.Payment_Proposal__c).Aggregate_by_Payee__c == false && accountPayableMap.get(ppl.Payable__c).Type__c == COMMON_CREDIT_MEMO) {
            ppl.addError(ERROR_PPL_CREDIT_MEMO);
        }
    }

    public static void setPayableAndDefaultAmount(List<Payment_Proposal_Line__c> PPLs, Map<Id, Payment_Proposal_Line__c> oldPPLs){
        Set<Id> payableIds = new Set<Id>();
        for (Payment_Proposal_Line__c ppl : PPLs) {
            if(ppl.Payable__c != null) {
                payableIds.add(ppl.Payable__c);
                ppl.Is_Parent__c = false;
            }else{
                ppl.Is_Parent__c = true;
            }
        }
        //get related records for validation
        Map<Id, Account_Payable__c> accountPayableMap = new Map<Id, Account_Payable__c>(DomainUtils.getAccountPayablesById(payableIds));

        if (MultiCurrencyHandler.isMultiCurrencyEnabled){
            //recalculate formauls so we can use current balance formula to default Amt to Pay
            Formula.recalculateFormulas(PPLs);
        }

        for(Payment_Proposal_Line__c ppl : PPLs){
            if(ppl.Payable__c != null ){
                Account_Payable__c ap = accountPayableMap.get(ppl.Payable__c);
                               
                decimal discAmt = 0;
                decimal amtToPay = 0;
                boolean isCredit = ap.Balance__c >= 0 ? false : true;
                //if payable has discount then use that otherwise use disc from vendor
                if(!isCredit && ap.Discount_Amount__c != null && ap.Discount_Amount__c != 0){
                    discAmt = ap.Discount_Amount__c.setScale(2, System.RoundingMode.HALF_UP);
                    amtToPay = ap.Balance__c.setScale(2, System.RoundingMode.HALF_UP);
                }else if(!isCredit && (ap.Discount_Amount__c == null || ap.Discount_Amount__c == 0) && ap.Vendor__r.Discount_Percent__c != null && ppl.Payment_Date__c <= ppl.Early_Pay_Date__c ){
                    discAmt = (ap.Balance__c * (ap.Vendor__r.Discount_Percent__c/100)).setScale(2, System.RoundingMode.HALF_UP);
                    amtToPay = (ppl.Current_Balance__c - discAmt).setScale(2, System.RoundingMode.HALF_UP);
                }else{
                    amtToPay = ppl.Current_Balance__c.setScale(2, System.RoundingMode.HALF_UP);
                }
                //default these values if they are null
                ppl.Vendor__c = ppl.Vendor__c == null ? ap.Vendor__c : ppl.Vendor__c;
                ppl.Discount_Amount__c = ppl.Discount_Amount__c == null ? discAmt : ppl.Discount_Amount__c;
                ppl.Amount__c =  (ppl.Amount__c == null || Integer.valueOf(ppl.Amount__c) == 0)  ? amtToPay : ppl.Amount__c;
            } 
        }
    }

    public static void setParentPPLTotal(List<Payment_Proposal_Line__c> PPLs){
        Map<Id, Payment_Proposal_Line__c> pplsToUpdate = new Map<Id, Payment_Proposal_Line__c>();
        //get all parent IDs
        List<Id> parentIds = new List<Id>();

        Map<Id,Decimal> pplParentTotal = new Map<Id, Decimal>();
        Map<Id,Decimal> pplParentCreditTotal = new Map<Id, Decimal>();
        Map<Id,Decimal> pplParentBalanceTotal = new Map<Id, Decimal>();

        for (Payment_Proposal_Line__c ppl : PPLs) {
            if(ppl.Parent__c != null){
                parentIds.add(ppl.Parent__c);
                //initialize Credit Amt and Agg Balance to 0.  In the event there are no lines left the filtered agg queries will not return a result
                pplsToUpdate.put(ppl.Parent__c, new Payment_Proposal_Line__c(Id = ppl.Parent__c,
                                                    Amount__c = 0, Credit_Amount__c = 0, Aggregate_Balance__c = 0));
            }
        }
        
        //sum amount from children to parent Total__c
        if(parentIds != null && parentIds.size() > 0){
            for (Payment_Proposal_Line__c line : DomainUtils.getPaymentProposalLinesByParentId(parentIds)) {
                if (line.Amount__c != null) {
                    if (pplParentTotal.containsKey(line.Parent__c)) {
                        pplParentTotal.put(line.Parent__c, pplParentTotal.get(line.Parent__c) + line.Amount__c);
                    }else {
                        pplParentTotal.put(line.Parent__c, line.Amount__c);
                    }
                }
                if (line.Amount__c != null && line.Is_Credit__c) {
                    if (pplParentCreditTotal.containsKey(line.Parent__c)) {
                        pplParentCreditTotal.put(line.Parent__c, pplParentCreditTotal.get(line.Parent__c) + line.Amount__c);
                    }else {
                        pplParentCreditTotal.put(line.Parent__c, line.Amount__c);
                    }
                }
                if (line.Current_Balance__c != null && !line.Is_Credit__c) {
                    if (pplParentBalanceTotal.containsKey(line.Parent__c)) {
                        pplParentBalanceTotal.put(line.Parent__c, pplParentBalanceTotal.get(line.Parent__c) + line.Current_Balance__c);
                    }else {
                        pplParentBalanceTotal.put(line.Parent__c, line.Amount__c);
                    }
                }
            }

            for (Payment_Proposal_Line__c line : pplsToUpdate.values()) {
                if (pplParentTotal.containsKey(line.Id)) {
                    line.Amount__c = pplParentTotal.get(line.Id);
                }
                if (pplParentCreditTotal.containsKey(line.Id)) {
                    line.Credit_Amount__c = pplParentCreditTotal.get(line.Id);
                }
                if (pplParentBalanceTotal.containsKey(line.Id)) {
                    line.Aggregate_Balance__c = pplParentBalanceTotal.get(line.Id);
                }
            }

            if(pplsToUpdate.size() > 0){
                List<Database.SaveResult> saveResult = SFDCSecurityUtils.updateCheckCRUDAndFLS(pplsToUpdate.values(), new List<String>{'Amount__c', 'Credit_Amount__c', 'Aggregate_Balance__c'}, false);
            }
        }
    }

}