public with sharing class AccountPayablePayPartial extends AccountPayablePaymentHandler {

    public Boolean isError {get; set;}
    public Boolean isDiscountAllowed {get; set;}
    public Account_Payable__c acctPayable {get; set;}
    public Account_Payable__c proxyObjectTotal {get; set;}
    public Account_Payable__c proxyObjectPaidAmount {get; set;}      
    private ApexPages.StandardController localController;
    public AccountPayablePayPartial(ApexPages.StandardController controller) {
        localController = controller;
        isError = false;
        isVendorDiscountWarning = false;
        isDiscountAllowed = false;
        results = init(new List<Account_Payable__c>{(Account_Payable__c) localController.getRecord()}, false, true);
        if (!processPaymentResults()) {
            isError = true;
        }
        else {
            acctPayable = accountPayables[0];
            if((acctPayable.Payment_Status__c == 'Unpaid') || 
                (acctPayable.Credit_Memo_Applied_Amount__c > 0 && acctPayable.Balance__c > 0 && acctPayable.Paid_Amount__c == 0)){
                    isDiscountAllowed = true;
            }
            proxyObjectTotal = new Account_Payable__c(Discount_Amount__c = acctPayable.Total__c);
            proxyObjectPaidAmount = new Account_Payable__c(Discount_Amount__c = acctPayable.Paid_Amount__c);            
        }
    } 

    public PageReference payPartial() {
        if (validateAndApplyDataFromUI()) {
            if (validate1099Type()) {
                results = pay(false);
                if (processPaymentResults()) {
                    return new PageReference('/' + cashDisbursementBatchToInsert.Id);
                } else {
                    return NULL;
                }
            } else {
                return NULL;
            }            
        } else {
            return NULL;
        }
    }
    public PageReference payPartialAndPost() {
        if (validateAndApplyDataFromUI()) {
            if (validate1099Type()) {
                results = pay(true);
                if (processPaymentResults()) {
                    return new PageReference('/' + cashDisbursementBatchToInsert.Id);
                } else {
                    return NULL;
                }
            } else {
                return NULL;
            }            
        } else {
            return NULL;
        }
    }
    private Boolean validateAndApplyDataFromUI() {
        Boolean isValidUserInput = true;
        Decimal discountAmount = acctPayable.Discount_Amount__c == NULL ? 0 : acctPayable.Discount_Amount__c;
        Decimal creditMemoAppliedAmount = (acctPayable.Credit_Memo_Applied_Amount__c != NULL ? acctPayable.Credit_Memo_Applied_Amount__c : 0);
        Decimal balance = (acctPayable.Total__c - discountAmount - acctPayable.Paid_Amount__c - creditMemoAppliedAmount).setScale(2, System.RoundingMode.HALF_UP);

        if (uiCashDisbursement.Amount__c.setScale(2) < 0) {
            uiCashDisbursement.Amount__c.addError(NEGATIVE_AMOUNT_ERROR_MESSAGE);
            isValidUserInput = false;
        }

        if (uiCashDisbursement.Amount__c.setScale(2) > balance && isValidUserInput) {
            uiCashDisbursement.Amount__c.addError(AMOUNT_MORE_THAN_BALANCE_ERROR_MESSAGE);
            isValidUserInput = false;
        }

        if (acctPayable.Discount_Amount__c != NULL && acctPayable.Discount_Amount__c < 0 && isValidUserInput) {
            acctPayable.Discount_Amount__c.addError(NEGATIVE_DISCOUNT_ERROR_MESSAGE);
            isValidUserInput = false;
        }

        //set Reverse-Charge Tax if applicable
        Decimal taxAmount = (acctPayable.Reverse_Charge__c && acctPayable.Purchase_Tax3__c != NULL) ? acctPayable.Purchase_Tax3__c : 0;

        if (acctPayable.Discount_Amount__c != NULL
                && acctPayable.Discount_Amount__c.setScale(2) != 0
                && acctPayable.Paid_Amount__c.setScale(2) == 0
                && (acctPayable.Total__c.setScale(2) != (acctPayable.Discount_Amount__c + taxAmount + uiCashDisbursement.Amount__c + creditMemoAppliedAmount).setScale(2))
                && isValidUserInput) {

            ApexPages.addMessage(
                new ApexPages.MESSAGE(
                    ApexPages.SEVERITY.ERROR,
                    DISCOUNTED_AMOUNT_MUST_PAY_IN_FULL_ERROR_MESSAGE
                )
            );

            isValidUserInput = false;
        }

        if ( AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(uiCashDisbursement.Disbursement_Date__c) == NULL
                && isValidUserInput) {
            acctPayable.Accounting_Period__c.addError(NO_ACCOUNTING_RANGE_ERROR);
            isValidUserInput = false;
        }

        if (isValidUserInput) {//Apply data from UI
            for (CashDisbursementWrapper wrappedCD : wrappedCDs) {
                wrappedCD.cashDisbursement.Amount__c = uiCashDisbursement.Amount__c;
                wrappedCD.cashDisbursement.Disbursement_Date__c = uiCashDisbursement.Disbursement_Date__c;
                wrappedCD.cashDisbursement.Accounting_Period__c =
                    AccountingPeriodHandler.getInstance()
                        .getAccountingPeriodByDate(uiCashDisbursement.Disbursement_Date__c).Id;
                wrappedCD.discountAmount = acctPayable.Discount_Amount__c == NULL ? 0 : acctPayable.Discount_Amount__c;
                wrappedCD.creditMemoAmount =
                    acctPayable.Credit_Memo_Applied_Amount__c != NULL ? acctPayable.Credit_Memo_Applied_Amount__c : 0;
                wrappedCD.cashDisbursement.GL_Account_Variable_1__c = uiCashDisbursement.GL_Account_Variable_1__c;
                wrappedCD.cashDisbursement.GL_Account_Variable_2__c = uiCashDisbursement.GL_Account_Variable_2__c;
                wrappedCD.cashDisbursement.GL_Account_Variable_3__c = uiCashDisbursement.GL_Account_Variable_3__c;
                wrappedCD.cashDisbursement.GL_Account_Variable_4__c = uiCashDisbursement.GL_Account_Variable_4__c;
                wrappedCD.cashDisbursement.Project__c = uiCashDisbursement.Project__c;
                wrappedCD.cashDisbursement.Project_Task__c = uiCashDisbursement.Project_Task__c;
                wrappedCD.cashDisbursement.Currency_Conversion_Rate__c = uiCashDisbursement.Currency_Conversion_Rate__c;
                wrappedCD.cashDisbursement.Cash_Flow_Category__c = uiCashDisbursement.Cash_Flow_Category__c;

                for (Account_Payable__c payment : wrappedCD.payments) {
                    payment.Discount_Amount__c = acctPayable.Discount_Amount__c;
                }
            }
        }

        return isValidUserInput;
    }

}