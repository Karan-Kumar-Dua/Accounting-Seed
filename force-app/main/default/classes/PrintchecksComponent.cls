public with sharing class PrintchecksComponent {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private List<Cash_Disbursement__c> cashDisbursements;
    public List<CashDisbursementWrapper> cashDisbursementWrapperList {get; private set;}
    public Id cashDisbursementBatchId;
    public Id cashDisbursementId;
    private Accounting_Settings__c accountingSetting;
    @TestVisible private static final Double DATE_TOP_POSITION = 114;
    @TestVisible private static final Double DATE_RIGHT_POSITION = 48;

    @TestVisible private static final Double AMOUNT_TOP_POSITION = 114;
    @TestVisible private static final Double AMOUNT_RIGHT_POSITION = 2;

    @TestVisible private static final Double AMOUNT_WORDS_TOP_POSITION = 128;
    @TestVisible private static final Double AMOUNT_WORDS_LEFT_POSITION = 2;

    @TestVisible private static final Double PAYEE_TOP_POSITION = 136;
    @TestVisible private static final Double PAYEE_LEFT_POSITION = 8;

    @TestVisible private static final Double PAYEE_ADDRESS_TOP_POSITION = 140.5;
    @TestVisible private static final Double PAYEE_ADDRESS_LEFT_POSITION = 8;

    @TestVisible private static final Double MEMO_TOP_POSITION = 147;
    @TestVisible private static final Double MEMO_LEFT_POSITION = 8;

    public Id getCashDisbursementBatchId() {
        return cashDisbursementBatchId;
    }

    public void setCashDisbursementBatchId(Id cashDisbursementBatchId) {
        this.cashDisbursementBatchId = cashDisbursementBatchId;
        init();
    }

    public Id getCashDisbursementId() {
        return cashDisbursementId;
    }

    public void setCashDisbursementId(Id cashDisbursementId) {
        this.cashDisbursementId = cashDisbursementId;
        init();
    }

    public with sharing class CashDisbursementWrapper  {
        public Cash_Disbursement__c cashDisbursement {get; private set;}
        public List<RemittanceWrapper> remittances {get; private set;}

        public CashDisbursementWrapper(Cash_Disbursement__c cashDisbursement, List<RemittanceWrapper> remittances) {
            this.cashDisbursement = cashDisbursement;
            this.remittances = remittances;
        }
    }

    public with sharing class RemittanceWrapper implements Comparable {
        public Account_Payable__c accountPayable {get; set;}
        public Decimal amount {get; set;}
        public String remiteanceType {get; set;}

        public RemittanceWrapper(Account_Payable__c accountPayable, Decimal amount) {
            this.accountPayable = accountPayable;
            this.amount = amount;
        }

        public Integer compareTo(Object compareTo) {
            RemittanceWrapper compareToRw = (RemittanceWrapper)compareTo;
            if (accountPayable.Date__c == compareToRw.accountPayable.Date__c) return 0;
            if (accountPayable.Date__c > compareToRw.accountPayable.Date__c) return 1;
            return -1;
        }
    }

    private List<Cash_Disbursement__c> queryCashDisbursements() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Payee__c',
            'Payee_Street__c',
            'Payee_City_State_Zip__c',
            'Payee_Country__c',
            'Check_Number__c',
            'Type__c',
            'Amount__c',
            'Amount_In_Words__c',
            'Disbursement_Date__c',
            'Bank_Account__c',
            'Memo__c'
        };

        String queryCondition =
            (cashDisbursementBatchId != NULL)
                ? 'Cash_Disbursement_Batch__c = :cashDisbursementBatchId'
                : 'Id = :cashDisbursementId';
        SOQLBuilder.Ordering queryOrdering = new SOQLBuilder.Ordering('Cash_Disbursement__c', 'Check_Number__c', SOQLBuilder.SortOrder.ASCENDING);

        List<String> subQueryFields = new List<String>{
            'Id',
            'Name',
            'Account_Payable__c',
            'Account_Payable_Date__c',
            'Payable_Amount__c',
            'Net_Amount__c',
            'Discount_Amount__c',
            'Account_Payable__r.Payee_Reference__c',
            'Account_Payable__r.Type__c',
            'Account_Payable__r.Name',
            'Account_Payable__r.Vendor__c',
            'Account_Payable__r.Date__c',
            'Account_Payable__r.Discount_Amount__c',
            'Account_Payable__r.Credit_Memo_Applied_Amount__c',
            'Account_Payable__r.Net_Amount__c',
            'Account_Payable__r.Proprietary_Payable_Number__c',
            'Paid_Amount__c'
        };

        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Account_Payable_Cash_Disbursements__r';
        SOQLBuilder.Ordering subqueryOrdering = new SOQLBuilder.Ordering('AP_Disbursement__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(queryOrdering)
            .subselectQuery(subQueryRelationshipName, true)
            .setEnforceFLS(true)
            .selectFields(subQueryFields)
            .addOrdering(subqueryOrdering);

        return (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
    }

    private List<AP_Credit_Memo__c> queryAPCreditMemos(Set<Id> accountPayableIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'Amount__c',
            'Account_Payable_Invoice__c',
            'Account_Payable_Credit_Memo__r.Name',
            'Account_Payable_Credit_Memo__r.Type__c',
            'Account_Payable_Credit_Memo__r.Discount_Amount__c',
            'Account_Payable_Credit_Memo__r.Payee_Reference__c',
            'Account_Payable_Credit_Memo__r.Credit_Memo_Applied_Amount__c',
            'Account_Payable_Credit_Memo__r.Net_Amount__c',
            'Account_Payable_Credit_Memo__r.Proprietary_Payable_Number__c',
            'Account_Payable_Credit_Memo__r.Date__c'
        };

        String queryCondition = 'Account_Payable_Invoice__c IN :accountPayableIds';
        SOQLBuilder theQuery = new SOQLBuilder(AP_Credit_Memo__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<AP_Credit_Memo__c>) Database.query(theQuery.toSOQL());
    }

    private void init() {
        cashDisbursements = new List<Cash_Disbursement__c>();
        cashDisbursementWrapperList = new List<CashDisbursementWrapper>();

        if (cashDisbursementBatchId != NULL || cashDisbursementId != NULL) {
            cashDisbursements = queryCashDisbursements();
        }

        Map<Id, List<Cash_Disbursement__c>> cdMap = new Map<Id, List<Cash_Disbursement__c>>();
        Map<Id, List<AP_Credit_Memo__c>> creditMemoMap = new Map<Id, List<AP_Credit_Memo__c>>();

        for (Cash_Disbursement__c cd : cashDisbursements) {
            for (AP_Disbursement__c apd : cd.Account_Payable_Cash_Disbursements__r) {
                if (!cdMap.containsKey(apd.Account_Payable__c)) {
                    cdMap.put(apd.Account_Payable__c, new Cash_Disbursement__c[]{cd});
                }
                else {
                    cdMap.get(apd.Account_Payable__c).add(cd);
                }
            }
        }

        for (AP_Credit_Memo__c apm : queryAPCreditMemos(cdMap.keySet())) {
            for (Cash_Disbursement__c cd : cdMap.get(apm.Account_Payable_Invoice__c)) {
                if (!creditMemoMap.containsKey(cd.Id)) {
                    creditMemoMap.put(cd.Id, new AP_Credit_Memo__c[]{apm});
                }
                else {
                    creditMemoMap.get(cd.Id).add(apm);
                }
            }
        }

        for (Cash_Disbursement__c cd : cashDisbursements) {
            Map<Id, RemittanceWrapper> rwMap = new Map<Id, RemittanceWrapper>();
            for (AP_Disbursement__c apd : cd.Account_Payable_Cash_Disbursements__r) {
                rwMap.put(apd.Id, new RemittanceWrapper(apd.Account_Payable__r, apd.Paid_Amount__c));
            }

            if (creditMemoMap.containsKey(cd.Id)) {
                for (AP_Credit_Memo__c apm : creditMemoMap.get(cd.Id)) {
                    if (!rwMap.containsKey(apm.Account_Payable_Credit_Memo__c)) {
                        rwMap.put(apm.Account_Payable_Credit_Memo__c, new RemittanceWrapper(apm.Account_Payable_Credit_Memo__r, apm.Amount__c));
                    }
                    else {
                        rwMap.get(apm.Account_Payable_Credit_Memo__c).amount += apm.Amount__c;
                    }
                }
            }

            List<RemittanceWrapper> rwList = new List<RemittanceWrapper>();
            rwList = rwMap.values();
            rwList.sort();
            cashDisbursementWrapperList.add(new CashDisbursementWrapper(cd, rwList));
        }

        accountingSetting = AccountingSettingsHandler.getAccountingSettings();
    }

    public Double getDateTopOffset() {
        return DATE_TOP_POSITION + (accountingSetting != NULL && accountingSetting.Date_Top_Offset__c != NULL ? accountingSetting.Date_Top_Offset__c : 0);
    }

    public Double getDateRightOffset() {
        return DATE_RIGHT_POSITION + (accountingSetting != NULL && accountingSetting.Date_Right_Offset__c != NULL ? accountingSetting.Date_Right_Offset__c : 0);
    }

    public Double getAmountTopOffset() {
        return AMOUNT_TOP_POSITION + (accountingSetting != NULL && accountingSetting.Amount_Top_Offset__c != NULL ? accountingSetting.Amount_Top_Offset__c : 0);
    }

    public Double getAmountRightOffset() {
        return AMOUNT_RIGHT_POSITION + (accountingSetting != NULL && accountingSetting.Amount_Right_Offset__c != NULL ? accountingSetting.Amount_Right_Offset__c : 0);
    }

    public Double getAmountWordsTopOffset() {
        return AMOUNT_WORDS_TOP_POSITION + (accountingSetting != NULL && accountingSetting.Amount_Words_Top_Offset__c != NULL ? accountingSetting.Amount_Words_Top_Offset__c : 0);
    }

    public Double getAmountWordsLeftOffset() {
        return AMOUNT_WORDS_LEFT_POSITION + (accountingSetting != NULL && accountingSetting.Amount_Words_Left_Offset__c != NULL ? accountingSetting.Amount_Words_Left_Offset__c : 0);
    }

    public Double getPayeeTopOffset() {
        return PAYEE_TOP_POSITION + (accountingSetting != NULL && accountingSetting.Payee_Top_Offset__c != NULL ? accountingSetting.Payee_Top_Offset__c : 0);
    }

    public Double getPayeeLeftOffset() {
        return PAYEE_LEFT_POSITION + (accountingSetting != NULL && accountingSetting.Payee_Left_Offset__c != NULL ? accountingSetting.Payee_Left_Offset__c : 0);
    }

    public Double getPayeeAddressTopOffset() {
        return PAYEE_ADDRESS_TOP_POSITION + (accountingSetting != NULL && accountingSetting.Payee_Address_Top_Offset__c != NULL ? accountingSetting.Payee_Address_Top_Offset__c : 0);
    }

    public Double getPayeeAddressLeftOffset() {
        return PAYEE_ADDRESS_LEFT_POSITION + (accountingSetting != NULL && accountingSetting.Payee_Address_Left_Offset__c != NULL ? accountingSetting.Payee_Address_Left_Offset__c : 0);
    }

    public Double getMemoTopOffset() {
        return MEMO_TOP_POSITION + (accountingSetting != NULL && accountingSetting.Memo_Top_Offset__c != NULL ? accountingSetting.Memo_Top_Offset__c : 0);
    }

    public Double getMemoLeftOffset() {
        return MEMO_LEFT_POSITION + (accountingSetting != NULL && accountingSetting.Memo_Left_Offset__c != NULL ? accountingSetting.Memo_Left_Offset__c : 0);
    }

}