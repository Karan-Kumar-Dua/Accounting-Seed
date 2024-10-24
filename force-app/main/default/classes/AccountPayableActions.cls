public with sharing class AccountPayableActions {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String PAYMENT_STATUS_UNPAID = 'Unpaid';
    public static final String PAYMENT_STATUS_PARTIALLY_PAID = 'Partially Paid';
    public static final String PAYMENT_STATUS_PAID = 'Paid';
    public static final String TYPE_INVOICE = 'Invoice';
    public static final String TYPE_CREDIT_MEMO = 'Credit Memo';
    public static final String STATUS_DRAFT = 'Draft';
    public static final String STATUS_IN_PROCESS = 'In Process';


    public static final String DUPLICATE_PAYEE_REFERENCE_ERROR = Label.ERR_DUPLICATE_PAYEE_REFERENCE;
    public static final String REQUIRED_PAYEEE_ERROR = Label.ERR_REQUIRED_PAYEEE;
    public static final String MULTIPLE_PAYEEE_ERROR = Label.ERR_MULTIPLE_PAYEEE;
    public static final String DISCOUNT_AMOUNT_ERROR = Label.ERR_DISCOUNT_AMOUNT_MODIFY;
    public static final String NEGATIVE_DISCOUNT_AMOUNT_ERROR = Label.ERR_NEGATIVE_DISCOUNT_AMOUNT;
    public static final String PAYABLE_CANT_BE_HOLD_IF_BALANCE_ZERO_ERROR = Label.PAYABLE_CANT_BE_HOLD_IF_BALANCE_ZERO_ERROR;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Account_Payable__c.Currency_Conversion_Rate__c => 6,
        Account_Payable__c.Discount_Amount__c => 2,
        Account_Payable__c.Credit_Memo_Applied_Amount__c => 2
    };

    public static void preventOverAppliedPayables(List<Account_Payable__c> newPayables) {
        for (Account_Payable__c newPayable : newPayables) {
            Boolean isInvoice = (newPayable.Total__c < 0) ? false : true;

            Decimal totalApplied = (
                newPayable.Paid_Amount__c +
                newPayable.Credit_Memo_Applied_Amount__c).setScale(2, System.RoundingMode.HALF_UP);

            Decimal netAmount = newPayable.Net_Amount__c.setScale(2, System.RoundingMode.HALF_UP);
            //Over Application condition depends on Payables's Type
            if ((isInvoice && netAmount < totalApplied) || (!isInvoice && netAmount > totalApplied)) {
                newPayable.addError(
                    String.format(
                        SObjectActions.OVER_APPLIED_ERROR,
                        new List<String> {Account_Payable__c.getSObjectType().getDescribe().getLabel()}
                    )
                );
            }
        }
    }

    public static void requireFields(List<Account_Payable__c> acctPayables) {
        for (Account_Payable__c ap : acctPayables) {
            if (ap.Accounting_Period__c == NULL) {
                ap.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (ap.Due_Date__c == NULL) {
                ap.Due_Date__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (ap.Discount_Amount__c != NULL && ap.Discount_Amount__c < 0) {
                ap.Discount_Amount__c.addError(NEGATIVE_DISCOUNT_AMOUNT_ERROR);
            }

            if (ap.Ledger__c == NULL) {
                ap.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void calculateCreditMemoAppliedAmountAndPaymentStatus(Map<Id, Account_Payable__c> acctPayableMap) {

        Map<Id, AggregateResult> apCreditMemoMemoMap = new Map<Id, AggregateResult>(DomainUtils.getAPCreditMemoSumByPayable(acctPayableMap.keySet()));
        Map<Id, AggregateResult> apCreditMemoInvoiceMap = new Map<Id, AggregateResult>(DomainUtils.getAPInvoiceSumByPayable(acctPayableMap.keySet()));

        for (Account_Payable__c ap : acctPayableMap.values()) {
            ap.Credit_Memo_Applied_Amount__c = 0;
            ap.Discount_Amount__c = (ap.Discount_Amount__c == NULL && ap.Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED ? 0 : ap.Discount_Amount__c);

            if (apCreditMemoMemoMap.containsKey(ap.Id)) {
                ap.Credit_Memo_Applied_Amount__c += (Decimal) apCreditMemoMemoMap.get(ap.Id).get('sum');
            }

            if (apCreditMemoInvoiceMap.containsKey(ap.Id)) {
                ap.Credit_Memo_Applied_Amount__c -= (Decimal) apCreditMemoInvoiceMap.get(ap.Id).get('sum');
            }

            Decimal taxAmount = (ap.Reverse_Charge__c && ap.Purchase_Tax3__c != NULL) ? ap.Purchase_Tax3__c : 0;
            //to prevent null-reference when clean up Discount field on Posted record
            Decimal discount = (ap.Discount_Amount__c != NULL) ? ap.Discount_Amount__c : 0;
            Decimal balance = ap.Total__c - discount - taxAmount - ap.Credit_Memo_Applied_Amount__c - ap.Paid_Amount__c;
            ap.Payment_Status__c = PAYMENT_STATUS_UNPAID;

            if (hasNonZeroApplication(ap)
                    && ((isInvoice(ap) && equalOrLessThanZero(balance)) || (isCreditMemo(ap) && equalOrGreaterThanZero(balance)))
                    && ap.Total__c.setScale(2) != 0) {

                ap.Payment_Status__c = PAYMENT_STATUS_PAID;
            }
            else if (hasNonZeroApplication(ap)
                        && ((isInvoice(ap) && lessThanNetAmount(balance, ap)) || (isCreditMemo(ap) && greaterThanNetAmount(balance, ap)))
                        && ap.Total__c.setScale(2) != 0) {

                ap.Payment_Status__c = PAYMENT_STATUS_PARTIALLY_PAID;
            }
        }
    }

    private static Boolean hasNonZeroApplication(Account_Payable__c ap) {
        return !(ap.Credit_Memo_Applied_Amount__c == 0 && ap.Paid_Amount__c == 0);
    }

    private static Boolean isInvoice(Account_Payable__c ap) {
        return ap.Type__c == TYPE_INVOICE;
    }

    private static Boolean isCreditMemo(Account_Payable__c ap) {
        return ap.Type__c == TYPE_CREDIT_MEMO;
    }

    private static Boolean equalOrLessThanZero(Decimal amount) {
        return amount.setScale(2) <= 0;
    }

    private static Boolean equalOrGreaterThanZero(Decimal amount) {
        return amount.setScale(2) >= 0;
    }

    private static Boolean lessThanNetAmount(Decimal amount, Account_Payable__c ap) {
        return amount.setScale(2) < ap.Net_Amount__c.setScale(2);
    }

    private static Boolean greaterThanNetAmount(Decimal amount, Account_Payable__c ap) {
        return amount.setScale(2) > ap.Net_Amount__c.setScale(2);
    }

    public static void associateAccountFields(List<Account_Payable__c> acctPayables) {
        Map<Id, Account> accountMap = new Map<Id, Account>();
        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        Map<Id, User> employeeUserMap = new Map<Id, User>();

        for (Account_Payable__c ap : acctPayables) {
            if (ap.Vendor__c != NULL) {
                accountMap.put(ap.Vendor__c, NULL);
            }
            if (ap.Contact__c != NULL) {
                contactMap.put(ap.Contact__c, NULL);
            }
            if (ap.Employee__c != NULL) {
                employeeUserMap.put(ap.Employee__c, NULL);
            }
        }

        if (!accountMap.isEmpty()) {
            accountMap = new Map<Id, Account>(DomainUtils.getAccountsById(accountMap.keySet()));
        }

        if (!contactMap.isEmpty()) {
            contactMap = new Map<Id, Contact>(DomainUtils.getContactById(contactMap.keySet()));
        }

        if (!employeeUserMap.isEmpty()) {
            employeeUserMap = new Map<Id, User>(DomainUtils.getUserById(employeeUserMap.keySet()));
        }

        for (Account_Payable__c ap : acctPayables) {
            if (ap.Date__c == NULL) {
                ap.Date__c = System.today();
            }
            if (ap.Due_Date__c == NULL
                && ap.Vendor__c != NULL
                && accountMap.get(ap.Vendor__c) != NULL
                && accountMap.get(ap.Vendor__c).Account_Payable_Terms__c != NULL) {
                ap.Due_Date__c = ap.Date__c + accountMap.get(ap.Vendor__c).Account_Payable_Terms__c.intValue();
            }
            else if (ap.Due_Date__c == NULL
                && ap.Contact__c != NULL
                && contactMap.get(ap.Contact__c) != NULL
                && contactMap.get(ap.Contact__c).Payable_Days_Due__c != NULL) {
                ap.Due_Date__c = ap.Date__c + contactMap.get(ap.Contact__c).Payable_Days_Due__c.intValue();
            }
            else if (ap.Due_Date__c == NULL
                && ap.Employee__c != NULL
                && employeeUserMap.get(ap.Employee__c) != NULL
                && employeeUserMap.get(ap.Employee__c).Payable_Days_Due__c != NULL) {
                ap.Due_Date__c = ap.Date__c + employeeUserMap.get(ap.Employee__c).Payable_Days_Due__c.intValue();
            }
            else if (ap.Due_Date__c == NULL) {
                ap.Due_Date__c = ap.Date__c;
            }
        }
    }

    // Prevent duplicated payee reference field
    public static void preventDuplicatePayeeReference(Map<Id, Account_Payable__c> oldAccountPayableMap, List<Account_Payable__c> newAccountPayableList) {
        PayableDuplicatePayeeReferenceChecker prf = new PayableDuplicatePayeeReferenceChecker(oldAccountPayableMap, newAccountPayableList);
        prf.dedupBatch();
        prf.dedupDatabase();
    }

    public static void validateVendorContactEmployee(List<Account_Payable__c> acctPayables) {
        for (Account_Payable__c ap : acctPayables) {
            if (ap.Vendor__c == NULL && ap.Contact__c == NULL && ap.Employee__c == NULL && ap.Status__c != STATUS_DRAFT) {
                ap.Vendor__c.addError(REQUIRED_PAYEEE_ERROR);
                ap.Contact__c.addError(REQUIRED_PAYEEE_ERROR);
                ap.Employee__c.addError(REQUIRED_PAYEEE_ERROR);
            }
            else if ((ap.Vendor__c != NULL && (ap.Contact__c != NULL || ap.Employee__c != NULL))
                    || (ap.Contact__c != NULL && (ap.Vendor__c != NULL || ap.Employee__c != NULL))
                    || (ap.Employee__c != NULL && (ap.Vendor__c != NULL || ap.Contact__c != NULL))) {

                ap.addError(MULTIPLE_PAYEEE_ERROR);
            }
        }
    }

    public static void setDefaultFields(List<Account_Payable__c> acctPayables) {
        try {
            String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(Account_Payable__c.Status__c);

            Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();

            for (Account_Payable__c ap : acctPayables) {
                ap.Status__c = (ap.Status__c == NULL || SObjectActions.isPostedStatus(ap) ? defaultValue : ap.Status__c);
                ap.Payment_Status__c = PAYMENT_STATUS_UNPAID;
                ap.Closed_Accounting_Period__c = NULL;
                ap.Credit_Memo_Applied_Amount__c = 0;
                ap.Discount_Amount__c = (ap.Discount_Amount__c == NULL ? 0 : ap.Discount_Amount__c);
                SObjectActions.populateLedgerField(ap,defaultLedgerId);
                MultiCurrencyHandler.setCurrencyIsoCodeToUserCurrency(ap);
            }
        }
        catch (Exception ex) {
            for (Account_Payable__c ap : acctPayables) {
                ap.addError(ex.getMessage(), false);
            }
        }
    }

    public static void setDiscountToZeroIfEmpty(List<Account_Payable__c> acctPayables, Map<Id, Account_Payable__c> oldRecordsMap) {
        for (Account_Payable__c ap : acctPayables) {
            if (ap.Discount_Amount__c == NULL
                    && oldRecordsMap.get(ap.Id).Payment_Status__c != PAYMENT_STATUS_PAID
                    && oldRecordsMap.get(ap.Id).Payment_Status__c != PAYMENT_STATUS_PARTIALLY_PAID) {

                ap.Discount_Amount__c = 0;
            }
        }
    }

    public static void preventUpdateDiscountAmountForPaidRecords(List<Account_Payable__c> newRecords, Map<Id, Account_Payable__c> oldRecordsMap) {
        for (Account_Payable__c newRecord : newRecords) {
            Account_Payable__c oldRecord = oldRecordsMap.get(newRecord.Id);
            if (isDiscountValueChanged(newRecord, oldRecord)
                    && isPaymentStatusPaid(oldRecord)
                    && !isEmptyDiscountValueSetToZero(newRecord, oldRecord)
                    && newRecord.Paid_Amount__c > 0) {

                newRecord.Discount_Amount__c.addError(DISCOUNT_AMOUNT_ERROR);
            }
        }
    }

    private static Boolean isDiscountValueChanged(Account_Payable__c newRecord, Account_Payable__c oldRecord) {
        return newRecord.Discount_Amount__c != oldRecord.Discount_Amount__c;
    }

    private static Boolean isEmptyDiscountValueSetToZero(Account_Payable__c newRecord, Account_Payable__c oldRecord) {
        return newRecord.Discount_Amount__c == 0 && oldRecord.Discount_Amount__c == null;
    }

    private static Boolean isPaymentStatusPaid(Account_Payable__c oldRecord) {
        return oldRecord.Payment_Status__c == PAYMENT_STATUS_PAID || oldRecord.Payment_Status__c == PAYMENT_STATUS_PARTIALLY_PAID;
    }
    
    public class PayableDuplicatePayeeReferenceChecker {
        private Map<Id, Account_Payable__c> oldAccountPayableMap;
        private List<Account_Payable__c> newAccountPayableList;
        private Map<String, Account_Payable__c> payableMap;
        private Set<String> payeeRefs;
        private Set<Id> vendorIds;
        private Set<Id> contactIds;
        private Set<Id> employeeIds;
        private Boolean isInsertContext;

        public PayableDuplicatePayeeReferenceChecker(Map<Id, Account_Payable__c> oldAccountPayableMap, List<Account_Payable__c> newAccountPayableList) {
            this.oldAccountPayableMap = oldAccountPayableMap;
            this.newAccountPayableList = newAccountPayableList;
            isInsertContext = (oldAccountPayableMap == NULL ?  true : false);
            payableMap = new Map<String, Account_Payable__c>();
            payeeRefs = new Set<String>();
            vendorIds = new Set<Id>();
            contactIds = new Set<Id>();
            employeeIds = new Set<Id>();
        }

        public void dedupBatch() {
            for (Account_Payable__c newAp : newAccountPayableList) {
                Account_Payable__c oldAp = (!isInsertContext ? oldAccountPayableMap.get(newAp.Id) : NULL);

                Id payeeId = getPayeeId(newAp);
                if (newAp.Payee_Reference__c != NULL && payeeId != NULL) {
                    
                    if (isInsertContext || isPayeeReferenceChanged(oldAp, newAp) || isPayeeChanged(oldAp,newAp)) {
                        String payeeDupKey = payeeId + getUnifiedReference(newAp.Payee_Reference__c);

                        if (payableMap.containsKey(payeeDupKey)) {
                            newAp.addError(DUPLICATE_PAYEE_REFERENCE_ERROR, false);
                        }
                        else {
                            payableMap.put(payeeDupKey, newAp);
                        }

                        if (newAp.Vendor__c != NULL) {
                            vendorIds.add(newAp.Vendor__c);
                        }
                        else if (newAp.Contact__c != NULL) {
                            contactIds.add(newAp.Contact__c);
                        }
                        else if (newAp.Employee__c != NULL) {
                            employeeIds.add(newAp.Employee__c);
                        }

                        payeeRefs.add(newAp.Payee_Reference__c);
                    }
                }
            }
        }

        public void dedupDatabase() {
            if (!vendorIds.isEmpty() || !contactIds.isEmpty() || !employeeIds.isEmpty()) {
                for (AggregateResult ar : DomainUtils.getAccountPayablesByPayeeAndPayeeReferenceCount(vendorIds, contactIds, employeeIds, payeeRefs)) {
                    String payRef = getUnifiedReference((String) ar.get('payRef'));
                    String vendorDupKey = !vendorIds.isEmpty() && (Id) ar.get('vendor') != NULL ? (Id) ar.get('vendor') + payRef : NULL;
                    String contactDupKey = !contactIds.isEmpty() && (Id) ar.get('contact') != NULL ? (Id) ar.get('contact') + payRef : NULL;
                    String employeeDupKey = !employeeIds.isEmpty() && (Id) ar.get('employee') != NULL ? (Id) ar.get('employee') + payRef : NULL;

                    if (vendorDupKey != NULL && payableMap.containsKey(vendorDupKey)) {
                        payableMap.get(vendorDupKey).addError(DUPLICATE_PAYEE_REFERENCE_ERROR, false);
                    }
                    else if (contactDupKey != NULL && payableMap.containsKey(contactDupKey)) {
                        payableMap.get(contactDupKey).addError(DUPLICATE_PAYEE_REFERENCE_ERROR, false);
                    }
                    else if (employeeDupKey != NULL && payableMap.containsKey(employeeDupKey)) {
                        payableMap.get(employeeDupKey).addError(DUPLICATE_PAYEE_REFERENCE_ERROR, false);
                    }
                }   
            }     
        }

        private Boolean isPayeeReferenceChanged(Account_Payable__c oldAp, Account_Payable__c newAp) {
            return oldAp.Payee_Reference__c != newAp.Payee_Reference__c;
        }

        private Boolean isPayeeChanged(Account_Payable__c oldAp, Account_Payable__c newAp) {
            return (oldAp.Vendor__c != newAp.Vendor__c || oldAp.Contact__c != newAp.Contact__c || oldAp.Employee__c != newAp.Employee__c);
        }

        private Id getPayeeId(Account_Payable__c payable) {
            Id payeeId;

            if (payable.Vendor__c != NULL) {
                payeeId = payable.Vendor__c;
            }
            else if (payable.Contact__c != NULL) {
                payeeId = payable.Contact__c;
            }
            else if (payable.Employee__c != NULL) {
                payeeId = payable.Employee__c;
            }

            return payeeId;
        }

        private String getUnifiedReference(String ref) {
            if (String.isBlank(ref)) {
                return '';
            }
            else {
                return ref.toLowerCase();
            }
        }
    }

    public static void requiredPayeeRefOnStatusDraft(List<Account_Payable__c> payables) {

        for(Account_Payable__c payable : payables) {
            if(payable.Status__c != STATUS_DRAFT && String.isBlank(payable.Payee_Reference__c)) {
                payable.Payee_Reference__c.addError(Label.COMMON_ERR_COMPLETE_THIS_FIELD);
            }
        }

    }

    public static void updateStatusToInProcess(List<Account_Payable__c> payables) {
        for (Account_Payable__c ap : payables) {
            if (ap.Status__c == STATUS_DRAFT
                    && ap.Payee__c != null
                    && ap.Payee_Reference__c != null
                    && ap.Date__c != null
                    && ap.Total__c > 0) {
                ap.Status__c = STATUS_IN_PROCESS;
            }
        }
    }

    public static void preventUpdatingOnHoldstatus(List<Account_Payable__c> payables){
        for (Account_Payable__c ap : payables) {
            if (ap.Balance__c <= 0 && ap.On_Hold__c == true) {
                ap.addError(PAYABLE_CANT_BE_HOLD_IF_BALANCE_ZERO_ERROR);
            }
        }
    }
}