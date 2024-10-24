public with sharing class AgingHandler {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String INVOICE_TYPE = 'Invoice';
    public static final String CREDIT_MEMO_TYPE = 'Credit Memo';

    public static final Map<SObjectType, SObjectField> creditMemoAppliedFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => Account_Payable__c.Credit_Memo_Applied_Amount__c,
        Billing__c.SObjectType => Billing__c.Credit_Memo_Applied_Amount__c
    };

    public static final Map<SObjectType, SObjectField> appliedCountFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => Account_Payable__c.AP_Disbursement_Count__c,
        Billing__c.SObjectType => Billing__c.Billing_Cash_Receipt_Count__c
    };

    public static final Map<SObjectType, List<SObjectField>> creditMemoFieldNames = new Map<SObjectType, List<SObjectField>> {
        Account_Payable__c.SObjectType => new List<SObjectField> {
            AP_Credit_Memo__c.Account_Payable_Credit_Memo__c,
            AP_Credit_Memo__c.Account_Payable_Invoice__c
        },
        Billing__c.SObjectType => new List<SObjectField> {
            Billing_Credit_Memo__c.Billing_Credit_Memo__c,
            Billing_Credit_Memo__c.Billing_Invoice__c
        }
    };

    public static final Map<SObjectType, SObjectField> appliedFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => AP_Disbursement__c.Account_Payable__c,
        Billing__c.SObjectType => Billing_Cash_Receipt__c.Billing__c
    };

    public static final Map<SObjectType, SObjectField> closedAccountingPeriodFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => Account_Payable__c.Closed_Accounting_Period__c,
        Billing__c.SObjectType => Billing__c.Closed_Accounting_Period__c
    };

    public static final Map<SObjectType, SObjectField> typeFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => Account_Payable__c.Type__c,
        Billing__c.SObjectType => Billing__c.Type__c
    };

    public static final Map<SObjectType, SObjectField> creditMemoAmountFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => AP_Credit_Memo__c.Amount__c,
        Billing__c.SObjectType => Billing_Credit_Memo__c.Amount__c
    };

    public static final Map<SObjectType, SObjectField> ccrFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => Account_Payable__c.Currency_Conversion_Rate__c,
        Billing__c.SObjectType => Billing__c.Currency_Conversion_Rate__c
    };

    public static final Map<SObjectType, SObjectField> balanceFieldNames = new Map<SObjectType, SObjectField> {
        Account_Payable__c.SObjectType => Account_Payable__c.Balance__c,
        Billing__c.SObjectType => Billing__c.Balance__c
    };

    public static Map<Id, List<SObject>> appliedObjectsByIds;
    public static Map<Id, List<SObject>> creditMemoObjectsByIds;
    public static Map<Id, List<SObject>> creditMemoInvoiceObjectsByIds;
    private static Map<Id, AggregateResult> appliedObjectsByIdsAR;
    private static Map<Id, AggregateResult> creditMemoObjectsByIdsAR;
    private static Map<Id, AggregateResult> creditMemoInvoiceObjectsByIdsAR;

    public static Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

    public class SourceDocumentAgingDecorator {
        private SObject oldObj;
        private SObject newObj;
        private SObjectType sobjectTypeValue;
        private SObjectField creditMemoAppliedFieldName;
        private SObjectField creditMemoAmountFieldName;
        private SObjectField appliedCountFieldName;
        private SObjectField closedAccountingPeriodFieldName;
        private SObjectField ccrFieldName;
        private SObjectField typeFieldName;
        private SObjectField balanceFieldName;
        private List<SObject> creditMemoObjects;
        private List<SObject> creditMemoInvoiceObjects;
        private List<SObject> appliedObjects;
        private AggregateResult creditMemoObjectsAR;
        private AggregateResult creditMemoInvoiceObjectsAR;
        private AggregateResult appliedObjectsAR;
        private String mostRecentPeriodName;

        public SourceDocumentAgingDecorator(SObject newObj) {
            this.newObj = newObj;
            sobjectTypeValue = newObj.getSObjectType();
            creditMemoAppliedFieldName = creditMemoAppliedFieldNames.get(sobjectTypeValue);
            creditMemoAmountFieldName = creditMemoAmountFieldNames.get(sobjectTypeValue);
            appliedCountFieldName = appliedCountFieldNames.get(sobjectTypeValue);
            closedAccountingPeriodFieldName = closedAccountingPeriodFieldNames.get(sobjectTypeValue);
            ccrFieldName = ccrFieldNames.get(sobjectTypeValue);
            typeFieldName = typeFieldNames.get(sobjectTypeValue);
            balanceFieldName = balanceFieldNames.get(sobjectTypeValue);
            creditMemoObjects = new List<SObject>();
            creditMemoInvoiceObjects = new List<SObject>();
            appliedObjects = new List<SObject>();
            mostRecentPeriodName = '';
        }

        public SourceDocumentAgingDecorator(SObject oldObj, SObject newObj) {
            this(newObj);
            this.oldObj = oldObj;
        }

        public Id getObjectId() {
            return newObj.Id;
        }

        public SObject getNewObject() {
            return newObj;
        }

        public Id getClosedAccountingPeriodValue() {
            return (Id) newObj.get(closedAccountingPeriodFieldName);
        }

        public void setClosedAccountingPeriodCurrentPeriod() {
            newObj.put(closedAccountingPeriodFieldName, currentPeriod.Id);
        }

        public void setClosedAccountingPeriodByPeriodId(Id periodId) {
            newObj.put(closedAccountingPeriodFieldName, periodId);
        }

        public void setCreditMemoObjects(List<SObject> sObjects) {
            if (sObjects != NULL && !sObjects.isEmpty()) {
                creditMemoObjects = sObjects;
            }
        }

        public void setCreditMemoInvoiceObjects(List<SObject> sObjects) {
            if (sObjects != NULL && !sObjects.isEmpty()) {
                creditMemoInvoiceObjects = sObjects;
            }
        }

        public void setAppliedObjects(List<SObject> sObjects) {
            if (sObjects != NULL && !sObjects.isEmpty()) {
                appliedObjects = sObjects;
            }
        }

        public void setCreditMemoObjectsAR(AggregateResult arObj) {
            creditMemoObjectsAR = arObj;
        }

        public void setCreditMemoInvoiceObjectsAR(AggregateResult arObj) {
            creditMemoInvoiceObjectsAR = arObj;
        }

        public void setAppliedObjectsAR(AggregateResult arObj) {
            appliedObjectsAR = arObj;
        }

        public Boolean isNeedValidate() {
            return isObjectBalanceZero() || isFieldsUpdated();
        }

        public Boolean isRefundAppliedObjectsExist() {
            Boolean result = false;
            switch on newObj {
                when Billing__c objRecord  {
                    for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) appliedObjects) {
                        if (bcr.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND) {
                            result = true;
                            break;
                        }
                    }
                }
            }
            return result;
        }

        public void processAgingStatus() {
            unlockClosedAccountingPeriodField();
            setClosedAccountingPeriodNull();
            if (isObjectBalanceZero() && getAppliedOrCreditMemoRecentPeriod() != NULL) {
                setClosedAccountingPeriodByPeriodId(getAppliedOrCreditMemoRecentPeriod());
            }
        }

        public Boolean isZeroBalance() {
            return isZeroBalanceByObjectType(getAmountBalance());
        }

        public Decimal getAmountBalance() {
            mostRecentPeriodName = '';
            Decimal balance = MultiCurrencyHandler.getRecordBaseAmount(newObj);
            if (isReverseCharge()) {
                balance = balance - getPurchaseTaxAmount();
            }
            balance = getAppliedBalance(balance);
            balance = getCreditMemoBalance(balance);
            balance = getCreditMemoInvoiceBalance(balance);

            return balance.setScale(2, System.RoundingMode.HALF_UP);
        }

        public Id getAppliedOrCreditMemoRecentPeriod() {
            String periodName = '';
            if (creditMemoObjectsAR != NULL) {
                periodName = (String) creditMemoObjectsAR.get('max');
            }
            if (creditMemoInvoiceObjectsAR != NULL && (String) creditMemoInvoiceObjectsAR.get('max') > periodName) {
                periodName = (String) creditMemoInvoiceObjectsAR.get('max');
            }
            if (appliedObjectsAR != NULL && (String) appliedObjectsAR.get('max') > periodName) {
                periodName = (String) appliedObjectsAR.get('max');
            }
            return !String.isBlank(periodName) ?
                AccountingPeriodHandler.getInstance().getAccountingPeriodByName(periodName).Id : NULL;
        }

        public Boolean isMostRecentPeriodSourceExist() {
            Boolean result = false;
            switch on newObj {
                when Account_Payable__c objRecord {
                    for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) appliedObjects) {
                        if (apd.Accounting_Period__r.Name >= currentPeriod.Name) {
                            result = true;
                            break;
                        }
                    }
                }
            }
            return result || mostRecentPeriodName >= currentPeriod.Name;
        }

        public void unlockClosedAccountingPeriodField() {
            switch on newObj {
                when Account_Payable__c objRecord {
                    TriggerObserver.getInstance().unlockField(Account_Payable__c.Closed_Accounting_Period__c);
                }
                when Billing__c objRecord  {
                    TriggerObserver.getInstance().unlockField(Billing__c.Closed_Accounting_Period__c);
                }
            }
        }

        private Decimal getPurchaseTaxAmount() {
            Decimal result = 0;
            switch on newObj {
                when Account_Payable__c objRecord {
                    result = MultiCurrencyHandler.getAmountInBaseCurrency(objRecord.Purchase_Tax3__c, objRecord.Currency_Conversion_Rate__c);
                }
            }
            return result;
        }

        private Decimal getAppliedBalance(Decimal balance) {
            switch on newObj {
                when Account_Payable__c objRecord {
                    for (AP_Disbursement__c apd : (List<AP_Disbursement__c>) appliedObjects) {
                        balance -= MultiCurrencyHandler.getAmountInBaseCurrency(apd.Paid_Amount__c, objRecord.Currency_Conversion_Rate__c);
                        if (getPeriodNameByAPD(apd) > mostRecentPeriodName) {
                            balance -= MultiCurrencyHandler.getAmountInBaseCurrency(apd.Discount_Amount__c, objRecord.Currency_Conversion_Rate__c);
                            mostRecentPeriodName = getPeriodNameByAPD(apd);
                        }
                    }
                }
                when Billing__c objRecord {
                    for (Billing_Cash_Receipt__c bcr : (List<Billing_Cash_Receipt__c>) appliedObjects) {
                        balance -= MultiCurrencyHandler.getAmountInBaseCurrency(bcr.Applied_Amount__c, objRecord.Currency_Conversion_Rate__c);
                        if (bcr.Adjustment_Amount__c != NULL) {
                            balance -= MultiCurrencyHandler.getAmountInBaseCurrency(bcr.Adjustment_Amount__c, objRecord.Currency_Conversion_Rate__c);
                        }
                        checkMostRecentPeriod(getRelatedAccountingPeriodName(bcr));
                    }
                }
            }
            return balance;
        }

        private Decimal getCreditMemoBalance(Decimal balance) {
            for (SObject acm : creditMemoObjects) {
                balance -= getAmountInBaseCurrency(acm);
                checkMostRecentPeriod(getRelatedAccountingPeriodName(acm));
            }
            return balance;
        }

        private Decimal getCreditMemoInvoiceBalance(Decimal balance) {
            for (SObject acm : creditMemoInvoiceObjects) {
                balance += getAmountInBaseCurrency(acm);
                checkMostRecentPeriod(getRelatedAccountingPeriodName(acm));
            }
            return balance;
        }

        private Boolean isZeroBalanceByObjectType(Decimal balance) {
            Boolean result = false;
            if (isInvoiceType() && balance.setScale(2, System.RoundingMode.HALF_UP) <= 0) {
                result = true;
            }
            else if (isCreditMemoType() && balance.setScale(2, System.RoundingMode.HALF_UP) >= 0) {
                result = true;
            }
            return result;
        }

        private String getRelatedAccountingPeriodName(SObject obj) {
            return (String) obj.getSObject(PACKAGE_QUALIFIER + 'Accounting_Period__r').get('Name');
        }

        private void checkMostRecentPeriod(String periodName) {
            if (periodName > mostRecentPeriodName) {
                mostRecentPeriodName = periodName;
            }
        }

        private Decimal getCCR() {
            return (Decimal) newObj.get(ccrFieldName);
        }

        private Decimal getAmountInBaseCurrency(SObject obj) {
            return MultiCurrencyHandler.getAmountInBaseCurrency((Decimal) obj.get(creditMemoAmountFieldName), getCCR());
        }

        public void setClosedAccountingPeriodNull() {
            newObj.put(closedAccountingPeriodFieldName, NULL);
        }

        private Boolean isReverseCharge() {
            return newObj.getSObjectType() == Account_Payable__c.getSObjectType() && newObj.get(PACKAGE_QUALIFIER + 'Reverse_Charge__c') == true;
        }

        private Boolean isInvoiceType() {
            return (String) newObj.get(typeFieldName) == INVOICE_TYPE;
        }

        public Boolean isCreditMemoType() {
            return (String) newObj.get(typeFieldName) == CREDIT_MEMO_TYPE;
        }

        private Boolean isFieldsUpdated() {
            return isCreditMemoChanged() || isRelatedCountChanged();
        }

        private Boolean isCreditMemoChanged() {
            return newObj.get(creditMemoAppliedFieldName) != oldObj.get(creditMemoAppliedFieldName);
        }

        private Boolean isRelatedCountChanged() {
            return newObj.get(appliedCountFieldName) != oldObj.get(appliedCountFieldName);
        }

        public Boolean isObjectBalanceZero() {
            return getBalanceValue().setScale(2, System.RoundingMode.HALF_UP) == 0;
        }

        public Decimal getBalanceValue() {
            Decimal result;
            switch on newObj {
                when Account_Payable__c objRecord {
                    result = objRecord.Net_Amount__c - objRecord.Paid_Amount__c - objRecord.Credit_Memo_Applied_Amount__c;
                }
                when Billing__c objRecord  {
                    result = objRecord.Total__c - objRecord.Received_Amount__c - objRecord.Cash_Application_Adjustment_Amount__c - objRecord.Credit_Memo_Applied_Amount__c ;
                }
            }
            return result;
        }

        private String getPeriodNameByAPD(AP_Disbursement__c apd) {
            String result;
            if (apd.Accounting_Period__c != NULL && apd.Cash_Disbursement__r.Debit_GL_Account__c != NULL) {
                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(apd.Cash_Disbursement__r.Ledger__c);
                if (apd.Cash_Disbursement__r.Payment_Status__c == 'Void') {
                    if (apd.Accounting_Period__r.Name > apd.Cash_Disbursement__r.Accounting_Period__r.Name) {
                        result = apd.Accounting_Period__r.Name;
                    }
                    else {
                        result = apd.Cash_Disbursement__r.Accounting_Period__r.Name;
                    }
                }
                else if (apd.Cash_Disbursement__r.Debit_GL_Account__c != defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c) {
                    result = apd.Accounting_Period__r.Name;
                }
                else {
                    result = apd.Cash_Disbursement__r.Accounting_Period__r.Name;
                }
            }
            else {
                result = apd.Cash_Disbursement__r.Accounting_Period__r.Name;
            }
            return result;
        }

    }

    public static void setClosedAccountingPeriod(List<SObject> newLines, Map<Id, SObject> oldLines) {
        List<SourceDocumentAgingDecorator> sddList = new List<SourceDocumentAgingDecorator>();
        Set<Id> headerRecordIds = new Set<Id>();

        for (SObject newLine : newLines) {
            SObject oldLine = oldLines != NULL ? oldLines.get(newLine.Id) : NULL;
            SourceDocumentAgingDecorator sdd = new SourceDocumentAgingDecorator(oldLine, newLine);
            if (sdd.isNeedValidate()) {
                headerRecordIds.add(sdd.getObjectId());
                sddList.add(sdd);
            }
            else if (!sdd.isObjectBalanceZero()) {
                sdd.unlockClosedAccountingPeriodField();
                sdd.setClosedAccountingPeriodNull();
            }
        }

        if (!sddList.isEmpty()) {
            setRelatedChildObjectsAggregateResults(sddList[0].getNewObject(), headerRecordIds);

            for (SourceDocumentAgingDecorator sdd : sddList) {
                sdd.setCreditMemoObjectsAR(creditMemoObjectsByIdsAR.get(sdd.getObjectId()));
                sdd.setCreditMemoInvoiceObjectsAR(creditMemoInvoiceObjectsByIdsAR.get(sdd.getObjectId()));
                sdd.setAppliedObjectsAR(appliedObjectsByIdsAR.get(sdd.getObjectId()));
                sdd.processAgingStatus();
            }

        }

    }

    public static void setRelatedChildObjectsAggregateResults(SObject newObj, Set<Id> headerRecordIds) {
        appliedObjectsByIdsAR = new Map<Id, AggregateResult>();
        creditMemoObjectsByIdsAR = new Map<Id, AggregateResult>();
        creditMemoInvoiceObjectsByIdsAR = new Map<Id, AggregateResult>();

        appliedObjectsByIdsAR = queryAggregationAppliedObjects(newObj, headerRecordIds);
        creditMemoObjectsByIdsAR = queryAggregationCreditMemoObjects(newObj, headerRecordIds);
        creditMemoInvoiceObjectsByIdsAR = queryAggregationCreditMemoInvoiceObjects(newObj, headerRecordIds);
    }

    public static void setRelatedChildObjects(SObject newObj, Set<Id> headerRecordIds) {
        appliedObjectsByIds = new Map<Id, List<SObject>>();
        creditMemoObjectsByIds = new Map<Id, List<SObject>>();
        creditMemoInvoiceObjectsByIds = new Map<Id, List<SObject>>();
        SObjectType sobjectTypeValue = newObj.getSObjectType();

        for (SObject obj : queryCreditMemoObjects(newObj, headerRecordIds)) {
            if (obj.get(creditMemoFieldNames.get(sobjectTypeValue)[0]) != NULL) {
                populateMap((Id) obj.get(creditMemoFieldNames.get(sobjectTypeValue)[0]), obj, creditMemoObjectsByIds);
            }
            if (obj.get(creditMemoFieldNames.get(sobjectTypeValue)[1]) != NULL) {
                populateMap((Id) obj.get(creditMemoFieldNames.get(sobjectTypeValue)[1]), obj, creditMemoInvoiceObjectsByIds);
            }
        }

        for (SObject obj : queryAppliedObjects(newObj, headerRecordIds)) {
            if (obj.get(appliedFieldNames.get(sobjectTypeValue)) != NULL) {
                populateMap((Id) obj.get(appliedFieldNames.get(sobjectTypeValue)), obj, appliedObjectsByIds);
            }
        }
    }

    private static void populateMap(Id headerId, SObject obj , Map<Id, List<SObject>> objMap) {
        if (!objMap.containsKey(headerId)) {
            objMap.put(headerId, new List<SObject> {obj});
        }
        else {
            objMap.get(headerId).add(obj);
        }
    }


    private static List<SObject> queryCreditMemoObjects(SObject obj, Set<Id> headerRecordIds) {
        List<SObject> result = new List<SObject>();
        switch on obj {
            when Account_Payable__c objRecord {
                result = DomainUtils.getApCreditMemosByMasterRecordId(headerRecordIds, currentPeriod.Name);
            }
            when Billing__c objRecord {
                result = DomainUtils.getBillingCreditMemosByMasterRecordId(headerRecordIds , currentPeriod.Name);
            }
        }
        return result;
    }

    private static List<SObject> queryAppliedObjects(SObject obj, Set<Id> headerRecordIds) {
        List<SObject> result = new List<SObject>();
        switch on obj {
            when Account_Payable__c objRecord {
                result = DomainUtils.getAPDisbursementByRelatedPayableIdAndCDStatus(headerRecordIds, currentPeriod.Name);
            }
            when Billing__c objRecord {
                result = DomainUtils.getBillingCashReceiptsByRelatedBillingId(headerRecordIds, currentPeriod.Name);
            }
        }
        return result;
    }

    private static Map<Id, AggregateResult> queryAggregationCreditMemoObjects(SObject obj, Set<Id> headerRecordIds) {
        Map<Id, AggregateResult> result = new Map<Id, AggregateResult>();
        switch on obj {
            when Account_Payable__c objRecord {
                result = DomainUtils.getAPCreditMemoMaxPeriodByPayable(headerRecordIds);
            }
            when Billing__c objRecord {
                result = DomainUtils.getBillingCreditMemoMaxPeriodByBilling(headerRecordIds);
            }
        }
        return result;
    }

    private static Map<Id, AggregateResult> queryAggregationCreditMemoInvoiceObjects(SObject obj, Set<Id> headerRecordIds) {
        Map<Id, AggregateResult> result = new Map<Id, AggregateResult>();
        switch on obj {
            when Account_Payable__c objRecord {
                result = DomainUtils.getAPInvoiceMaxPeriodByPayable(headerRecordIds);
            }
            when Billing__c objRecord {
                result = DomainUtils.getBillingCreditMemoInvoiceMaxPeriodByBilling(headerRecordIds);
            }
        }
        return result;
    }

    private static Map<Id, AggregateResult> queryAggregationAppliedObjects(SObject obj, Set<Id> headerRecordIds) {
        Map<Id, AggregateResult> result = new  Map<Id, AggregateResult>();
        switch on obj {
            when Account_Payable__c objRecord {
                result = DomainUtils.getApDisbursementsMaxPeriodByAP(headerRecordIds);
            }
            when Billing__c objRecord {
                result = DomainUtils.getBillingCashReceiptsMaxPeriodByBilling(headerRecordIds);
            }
        }
        return result;
    }

}