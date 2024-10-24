public with sharing class ExpenseLineActions {

    @TestVisible
    private static Set<Id> billExpenseLineIds;
    @TestVisible
    private static Set<Id> payableExpenseLineIds;
    public static final String CREDIT_CARD_VENDOR_ERROR = Label.ERR_CREDIT_CARD_VENDOR;
    public static final String EMPLOYEE_CREDIT_CARD_VENDOR_ERROR = Label.ERR_EMPLOYEE_CREDIT_CARD_VENDOR;
    public static final String MILEAGE_RATE_ERROR = Label.ERR_MILEAGE_RATE;

    public static void requireFields(List<Expense_Line__c> expenseLines) {
        for (Expense_Line__c expLine : expenseLines) {
            if (expLine.Expense_GL_Account__c == NULL) {
                expLine.Expense_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void calculateMileage(List<Expense_Line__c> expenses) {
        Map<Id,GL_Account__c> mileageGLAccountMap = new Map<Id,GL_Account__c>();
        for (Expense_Line__c exp : expenses) {
            if (exp.Miles__c != NULL) {
                mileageGLAccountMap.put(exp.Expense_GL_Account__c, NULL);
            }
        }

        mileageGLAccountMap = new Map<Id,GL_Account__c>(DomainUtils.getGlAccountMileageById(mileageGLAccountMap.keySet()));
        for (Expense_Line__c exp : expenses) {
            if (exp.Miles__c != NULL && mileageGLAccountMap.containsKey(exp.Expense_GL_Account__c)) {
                GL_Account__c glAccount = mileageGLAccountMap.get(exp.Expense_GL_Account__c);
                if (glAccount.Mileage_Rate__c == NULL) {
                    exp.addError(MILEAGE_RATE_ERROR);
                }
                else {
                    exp.Amount__c = (exp.Miles__c * glAccount.Mileage_Rate__c).setScale(2, System.RoundingMode.HALF_UP);
                }
            }
        }
    }

    public static void validateCreditCardVendor(List<Expense_Line__c> expenses) {
        Set<Id> vendorsIds = new Set<Id>();

        for (Expense_Line__c exp : expenses) {
            if (exp.Credit_Card_Vendor__c != NULL) {
                vendorsIds.add(exp.Credit_Card_Vendor__c);
            }
        }

        Map<Id, Account> accountMap = new Map<Id, Account>(DomainUtils.getAccountsById(vendorsIds));

        for (Expense_Line__c exp : expenses) {
            if (exp.Credit_Card_Vendor__c != NULL && accountMap.get(exp.Credit_Card_Vendor__c).Credit_Card_Vendor__c != true) {
                exp.Credit_Card_Vendor__c.addError(CREDIT_CARD_VENDOR_ERROR);
            }
        }
    }

    public static void populateCCVendorPayableField(List<Expense_Line__c> newExpenseLines) {
        for (Expense_Line__c newLine : newExpenseLines) {
            if (newLine.Credit_Card_Vendor__c != NULL) {
                newLine.Credit_Card_Vendor_Payable__c = true;
            }
            else {
                newLine.Credit_Card_Vendor_Payable__c = false;
            }
        }
    }

    public static void validateCCVendorField(List<Expense_Line__c> newExpenseLines) {
        for (Expense_Line__c newLine : newExpenseLines) {
            if (newLine.Employee_Reimburse__c && newLine.Credit_Card_Vendor__c != NULL) {
                newLine.Credit_Card_Vendor__c.addError(EMPLOYEE_CREDIT_CARD_VENDOR_ERROR);
            }
        }
    }

    public static void validateMandatoryMileageRate(Map<Id, Expense_Line__c> newExpenseLines) {
        Map<Id, Expense_Line__c> expMap = new Map<Id, Expense_Line__c>(DomainUtils.getExpenseLinesById(newExpenseLines.keySet()));

        for (Expense_Line__c newLine : newExpenseLines.values()) {
            if (expMap.get(newLine.Id).Expense_GL_Account__r.Mileage_Account__c && expMap.get(newLine.Id).Miles__c == NULL) {
                newLine.Credit_Card_Vendor__c.addError(MILEAGE_RATE_ERROR);
            }
        }
    }

    public static void setExpenseLinesFromBillings(Map<Id,Billing__c> billingMap) {
        setExpenseLinesFromBillingLines(DomainUtils.getBillingLinesByMasterId(billingMap.keySet()));
    }

    public static void setExpenseLinesFromBillingLines(Map<Id,Billing_Line__c> billLineMap) {
        billExpenseLineIds = new Set<Id>(DomainUtils.getExpenseLinesByBillingIds(billLineMap.keySet()));
    }

    public static void setExpenseLinesFromAccountPayables(Map<Id,Account_Payable__c> acctPayables) {
        setExpenseLinesFromAccountPayableLines(DomainUtils.getAccountPayableLinesByMasterId(acctPayables.keySet()));
    }

    public static void setExpenseLinesFromAccountPayableLines(Map<Id,Account_Payable_Line__c> acctPayableLines) {
        payableExpenseLineIds = new Set<Id>(DomainUtils.getExpenseLineIdsByAccountPayableLineIds(acctPayableLines.keySet()));
    }

    public static void setExpenseLineNonBilled() {
        List<Expense_Line__c> expenseLines = new List<Expense_Line__c>();
        for (Expense_Line__c el : DomainUtils.getExpenseLinesById(billExpenseLineIds)) {
            el.Billed__c = false;
            expenseLines.add(el);
        }

        SFDCSecurityUtils.updateProxy(expenseLines);
    }

    public static void setExpenseLineUnpaid() {
        List<Expense_Line__c> expenseLines = new List<Expense_Line__c>();
        for (Expense_Line__c el : DomainUtils.getExpenseLinesById(payableExpenseLineIds)) {
            el.Vendor_Employee_Paid__c = false;
            expenseLines.add(el);
        }

        SFDCSecurityUtils.updateProxy(expenseLines);
    }
}