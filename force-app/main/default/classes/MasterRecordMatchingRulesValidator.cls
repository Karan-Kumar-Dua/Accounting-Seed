public with sharing class MasterRecordMatchingRulesValidator {
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final Map<Schema.SObjectType, String> DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR_MAP = new Map<Schema.SObjectType, String> {
        Billing_Cash_Receipt__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_BILLING,Label.COMMON_CASH_RECEIPT}),
        Billing_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_BILLING_INVOICE,Label.COMMON_CREDIT_MEMO}),
        AP_Disbursement__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_PAYABLE,Label.COMMON_CASH_DISBURSEMENT}),
        AP_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_PAYABLE_INVOICE,Label.COMMON_CREDIT_MEMO})
    };

    public static final Map<Schema.SObjectType, String> DIFFERENT_CCR_FOR_MASTER_RECORDS_ERROR_MAP = new Map<Schema.SObjectType, String> {
        Billing_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_CCR_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_BILLING_INVOICE,Label.COMMON_BILLING_CREDIT_MEMO}),
        AP_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_CCR_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_PAYABLE_INVOICE,Label.COMMON_PAYABLE_CREDIT_MEMO})
    };

    public static final Map<Schema.SObjectType, String> INAPPROPRIATE_CURRENCY_FOR_JUNCTION_RECORDS_ERROR_MAP = new Map<Schema.SObjectType, String> {
        Billing_Cash_Receipt__c.getSObjectType() => String.format(Label.ERR_INAPPROPRIATE_CURRENCY_FOR_JUNCTION_RECORDS_ERROR,new List<String>{Label.COMMON_BILLING_CASH_RECEIPT,Label.COMMON_BILLING,Label.COMMON_CASH_RECEIPT}),
        Billing_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_INAPPROPRIATE_CURRENCY_FOR_JUNCTION_RECORDS_ERROR,new List<String>{Label.COMMON_BILLING_CREDIT_MEMO,Label.COMMON_BILLING_INVOICE,Label.COMMON_CREDIT_MEMO}),
        AP_Disbursement__c.getSObjectType() => String.format(Label.ERR_INAPPROPRIATE_CURRENCY_FOR_JUNCTION_RECORDS_ERROR,new List<String>{Label.INF_AP_DISBURSEMENT,Label.COMMON_PAYABLE,Label.COMMON_CASH_DISBURSEMENT}),
        AP_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_INAPPROPRIATE_CURRENCY_FOR_JUNCTION_RECORDS_ERROR ,new List<String>{Label.COMMON_PAYABLE_CREDIT_MEMO,Label.COMMON_PAYABLE_INVOICE,Label.COMMON_CREDIT_MEMO})
    };

    public static final Map<Schema.SObjectType, String> DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR_MAP = new Map<Schema.SObjectType, String> {
        Billing_Cash_Receipt__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_BILLING,Label.COMMON_CASH_RECEIPT}),
        Billing_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_BILLING_INVOICE,Label.COMMON_CREDIT_MEMO}),
        AP_Disbursement__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_PAYABLE,Label.COMMON_CASH_DISBURSEMENT}),
        AP_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_PAYABLE_INVOICE,Label.COMMON_CREDIT_MEMO})
    };

    public static final Map<Schema.SObjectType, String> DIFFERENT_PAYEE_ON_MASTER_RECORDS_ERROR = new Map<Schema.SObjectType, String> {
        AP_Disbursement__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_PAYEE_ON_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_PAYABLE,Label.COMMON_CASH_DISBURSEMENT}),
        AP_Credit_Memo__c.getSObjectType() => String.format(Label.ERR_DIFFERENT_PAYEE_ON_MASTER_RECORDS_ERROR,new List<String>{Label.COMMON_INVOICE,Label.COMMON_CREDIT_MEMO})
    };

    public static final String OPEN_ACCOUNTING_PERIOD_ERROR = Label.ERR_OPEN_ACCOUNTING_PERIOD;
    public static final String RECENT_PERIOD_MEMO_ERROR = Label.ERR_RECENT_PERIOD_MEMO;
    public static final String NEGATIVE_APPLY_ERROR = Label.ERR_NEGATIVE_APPLY;

    public static Boolean isVoidCashDisbursementContext = false;

    private SObject newObj;
    private Map<Id, SObject> firstMasterMap;
    private Map<Id, SObject> secondMasterMap;
    private SObjectType sObjectType;
    private Set<Id> firstMasterIds;
    private Set<Id> secondMasterIds;
    private SObjectField firstMasterName;
    private SObjectField secondMasterName;
    private Boolean isError;

    private Map<SObjectType, List<SObjectField>> masterFieldName = new Map<SObjectType, List<SObjectField>> {
        Billing_Cash_Receipt__c.SObjectType => new List<SObjectField> {
            Billing_Cash_Receipt__c.Billing__c,
            Billing_Cash_Receipt__c.Cash_Receipt__c
        },
        Billing_Credit_Memo__c.SObjectType => new List<SObjectField> {
            Billing_Credit_Memo__c.Billing_Invoice__c,
            Billing_Credit_Memo__c.Billing_Credit_Memo__c
        },
        AP_Disbursement__c.SObjectType => new List<SObjectField> {
            AP_Disbursement__c.Account_Payable__c,
            AP_Disbursement__c.Cash_Disbursement__c
        },
        AP_Credit_Memo__c.SObjectType => new List<SObjectField> {
            AP_Credit_Memo__c.Account_Payable_Invoice__c,
            AP_Credit_Memo__c.Account_Payable_Credit_Memo__c
        }
    };

    private List<SObjectField> accountPayableFields = new List<SObjectField> {
        Account_Payable__c.Name,
        Account_Payable__c.Ledger__c,
        Account_Payable__c.Vendor__c,
        Account_Payable__c.Contact__c,
        Account_Payable__c.Employee__c,
        Account_Payable__c.Currency_Conversion_Rate__c,
        Account_Payable__c.Status__c,
        Account_Payable__c.Accounting_Period__c,
        Account_Payable__c.Balance__c,
        Account_Payable__c.Total__c
    };

    private List<SObjectField> billingFields = new List<SObjectField> {
        Billing__c.Name,
        Billing__c.Ledger__c,
        Billing__c.Currency_Conversion_Rate__c,
        Billing__c.Status__c,
        Billing__c.Accounting_Period__c,
        Billing__c.Balance__c,
        Billing__c.Total__c
    };

    private Map<SObjectType, Map<SObjectType, List<SObjectField>>> queryFields = new Map<SObjectType, Map<SObjectType, List<SObjectField>>> {
        Billing_Cash_Receipt__c.SObjectType => new Map<SObjectType, List<SObjectField>> {
            Billing__c.SObjectType => billingFields,
            Cash_Receipt__c.SObjectType => new List<SObjectField> {
                Cash_Receipt__c.Name,
                Cash_Receipt__c.Ledger__c,
                Cash_Receipt__c.Currency_Conversion_Rate__c,
                Cash_Receipt__c.Status__c,
                Cash_Receipt__c.Accounting_Period__c,
                Cash_Receipt__c.Balance__c
            }
        },
        Billing_Credit_Memo__c.SObjectType => new Map<SObjectType, List<SObjectField>> {
            Billing__c.SObjectType => billingFields
        },
        AP_Disbursement__c.SObjectType => new Map<SObjectType, List<SObjectField>> {
            Account_Payable__c.SObjectType => accountPayableFields,
            Cash_Disbursement__c.SObjectType => new List<SObjectField> {
                Cash_Disbursement__c.Name,
                Cash_Disbursement__c.Ledger__c,
                Cash_Disbursement__c.Currency_Conversion_Rate__c,
                Cash_Disbursement__c.Status__c,
                Cash_Disbursement__c.Vendor__c,
                Cash_Disbursement__c.Contact__c,
                Cash_Disbursement__c.Employee__c,
                Cash_Disbursement__c.Accounting_Period__c,
                Cash_Disbursement__c.Balance__c,
                Cash_Disbursement__c.Payment_Status__c
            }
        },
        AP_Credit_Memo__c.SObjectType => new Map<SObjectType, List<SObjectField>> {
            Account_Payable__c.SObjectType => accountPayableFields
        }
    };

    public MasterRecordMatchingRulesValidator(SObjectType sObjectType) {
        this.sObjectType = sObjectType;
        firstMasterMap = new Map<Id, SObject>();
        secondMasterMap = new Map<Id, SObject>();
        firstMasterIds = new Set<Id>();
        secondMasterIds = new Set<Id>();
        firstMasterName = (SObjectField) masterFieldName.get(this.sObjectType).get(0);
        secondMasterName = (SObjectField) masterFieldName.get(this.sObjectType).get(1);
        isError = false;
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            addMultiCurrencyFields();
        }
    }

    public static void validate(Map<Id, SObject> newObjectMap) {
        SObjectType sobjectTypeValue = getSObjectTypeByObjectMap(newObjectMap);
        MasterRecordMatchingRulesValidator validator = new MasterRecordMatchingRulesValidator(getSObjectTypeByObjectMap(newObjectMap));

        validator.sObjectType = sobjectTypeValue;
        validator.getMasterRecordsId(newObjectMap);
        validator.queryMasterRecords();

        for (SObject newObj : newObjectMap.values()) {
            validator.newObj = newObj;
            validator.validateMatchingRules();
        }
    }

    private static SObjectType getSObjectTypeByObjectMap(Map<Id, SObject> newObjectMap) {
        return newObjectMap != NULL && !newObjectMap.isEmpty() ? newObjectMap.values()[0].getSObjectType() : NULL;
    }

    private void getMasterRecordsId (Map<Id, SObject> newObjectMap) {
        for (SObject newObj : newObjectMap.values()) {
            firstMasterIds.add((Id) newObj.get(firstMasterName));
            secondMasterIds.add((Id) newObj.get(secondMasterName));
        }
    }

    private void addMultiCurrencyFields () {
        for (SObjectType objType : queryFields.get(sObjectType).keySet()) {
            queryFields.get(sObjectType).get(objType).add(objType.getDescribe().fields.getMap().get('CurrencyIsoCode'));
        }
    }

    private void queryMasterRecords () {
        SObjectType firstObjectType;
        SObjectType secondObjectType;
        for (SObjectType objType : queryFields.get(sObjectType).keySet()) {
            if (firstObjectType == NULL) {
                firstObjectType = objType;
            }
            else {
                secondObjectType = objType;
            }
        }

        firstMasterMap = queryMasterRecord(
            firstObjectType,
            (List<SObjectField>) queryFields.get(sObjectType).values()[0],
            firstMasterIds
        );
        secondMasterMap = queryMasterRecord(
            secondObjectType != NULL ? secondObjectType : firstObjectType,
            (List<SObjectField>) (queryFields.get(sObjectType).values().size() > 1 ? queryFields.get(sObjectType).values()[1] : queryFields.get(sObjectType).values()[0]),
            secondMasterIds
        );
    }

    private void validateMatchingRules() {
        SObject firstMasterRecord = firstMasterMap.get((Id) newObj.get(firstMasterName));
        SObject secondMasterRecord = secondMasterMap.get((Id) newObj.get(secondMasterName));

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            validateSameCurrency(firstMasterRecord, secondMasterRecord);
            if (isCreditMemoRecord()) {
                validateSameCCR(firstMasterRecord, secondMasterRecord);
            }
        }
        if (isAPRecord()) {
            validateSamePayee(firstMasterRecord, secondMasterRecord);
        }
        if (isAPDRecord()) {
            validateCDIsNotVoid(secondMasterRecord);
        }
        validateSameLedger(firstMasterRecord, secondMasterRecord);
        validateOpenAccountingPeriod();
        validateRecentAccountingPeriod(firstMasterRecord, secondMasterRecord);
        if (isCreditMemoRecord()){
            validateApplyToNegative(firstMasterRecord);
        }
    }

    private Boolean isCreditMemoRecord() {
        return sObjectType == Billing_Credit_Memo__c.getSObjectType() || sObjectType == AP_Credit_Memo__c.getSObjectType();
    }

    private Boolean isAPRecord() {
        return sObjectType == AP_Disbursement__c.getSObjectType();
    }

    private Boolean isAPDRecord() {
        return sObjectType == AP_Disbursement__c.getSObjectType();
    }

    private static Map<Id, SObject> queryMasterRecord(SObjectType sObjType, List<SObjectField> objectFields, Set<Id> ids) {
        return new Map<Id, SObject>(DomainUtils.getSObjectBySObjectTypeAndFields(sObjType, objectFields, ids));
    }

    private void validateSameCurrency(SObject firstMasterRecord, SObject secondMasterRecord) {
        if (!isError) {
            String firstMasterCurrency = (String) firstMasterRecord.get('CurrencyIsoCode');
            String secondMasterCurrency = (String) secondMasterRecord.get('CurrencyIsoCode');
            //Check Master records
            if (firstMasterCurrency != secondMasterCurrency) {
                newObj.addError(DIFFERENT_CURRENCY_FOR_MASTER_RECORDS_ERROR_MAP.get(sObjectType));
                isError = true;
            }
            //Check Junction record
            if (newObj.get('CurrencyIsoCode') != NULL && newObj.get('CurrencyIsoCode') != firstMasterCurrency && !isError) {
                newObj.addError(INAPPROPRIATE_CURRENCY_FOR_JUNCTION_RECORDS_ERROR_MAP.get(sObjectType));
                isError = true;
            }
        }
    }

    private void validateSameCCR(SObject firstMasterRecord, SObject secondMasterRecord) {
        if (!isError) {
            Decimal firstMasterCCR = (Decimal) firstMasterRecord.get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c');
            Decimal secondMasterCCR = (Decimal) secondMasterRecord.get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c');
            if (firstMasterCCR != secondMasterCCR) {
                newObj.addError(DIFFERENT_CCR_FOR_MASTER_RECORDS_ERROR_MAP.get(sObjectType));
                isError = true;
            }
        }
    }

    private void validateSamePayee(SObject firstMasterRecord, SObject secondMasterRecord) {
        if (!isError) {
            List<String> payeeList = new List<String>{
                PACKAGE_QUALIFIER + 'Vendor__c',
                PACKAGE_QUALIFIER + 'Contact__c',
                PACKAGE_QUALIFIER + 'Employee__c'
            };

            Id firstMasterRecordPayeeId;
            Id secondMasterRecordPayeeId;

            for (String payee : payeeList) {
                if (firstMasterRecord.get(payee) != NULL) {
                    firstMasterRecordPayeeId = (Id) firstMasterRecord.get(payee);
                }

                if (secondMasterRecord.get(payee) != NULL) {
                    secondMasterRecordPayeeId = (Id) secondMasterRecord.get(payee);
                }

                if (firstMasterRecordPayeeId != NULL && secondMasterRecordPayeeId != NULL) {
                    break;
                }
            }

            if (firstMasterRecordPayeeId != secondMasterRecordPayeeId) {
                newObj.addError(DIFFERENT_PAYEE_ON_MASTER_RECORDS_ERROR.get(sObjectType));
                isError = true;
            }
        }
    }

    private void validateCDIsNotVoid(SObject cd) {
        if (!isError && !isVoidCashDisbursementContext) {
            if (((Cash_Disbursement__c) cd).Payment_Status__c == 'Void') {
                newObj.addError(CashDisbursement.VOIDED_CD_ERROR);
                isError = true;
            }
        }
    }

    private void validateSameLedger(SObject firstMasterRecord, SObject secondMasterRecord) {
        if (!isError) {
            Id firstMasterLedgerId = (Id) firstMasterRecord.get(PACKAGE_QUALIFIER + 'Ledger__c');
            Id secondMasterLedgerId = (Id) secondMasterRecord.get(PACKAGE_QUALIFIER + 'Ledger__c');
            firstMasterLedgerId = firstMasterLedgerId == NULL ? LedgerHandler.getLegacyDefaultLedgerId() : firstMasterLedgerId;
            secondMasterLedgerId = secondMasterLedgerId == NULL ? LedgerHandler.getLegacyDefaultLedgerId() : secondMasterLedgerId;
            if (firstMasterLedgerId != secondMasterLedgerId) {
                newObj.addError(DIFFERENT_LEDGER_FOR_MASTER_RECORDS_ERROR_MAP.get(sObjectType));
                isError = true;
            }
        }
    }

    private void validateOpenAccountingPeriod() {
        if (!isError) {
            if (!AccountingPeriodHandler.getInstance().isConsideredOpen((Id) newObj.get(PACKAGE_QUALIFIER + 'Accounting_Period__c'),sObjectType)) {
                newObj.addError(
                    String.format(
                        OPEN_ACCOUNTING_PERIOD_ERROR,
                        new List<String>{sObjectType.getDescribe().getLabel()}
                    )
                );
                isError = true;
            }
        }
    }

    private void validateRecentAccountingPeriod(SObject firstMasterRecord, SObject secondMasterRecord) {
        if (!isError) {
            Accounting_Period__c recentRelatedPeriod =
                AccountingPeriodHandler.getInstance().getMostRecentAccountingPeriodFromCollection(
                    new Set<Id>{
                        (Id) newObj.get(PACKAGE_QUALIFIER + 'Accounting_Period__c'),
                        (Id) firstMasterRecord.get(PACKAGE_QUALIFIER + 'Accounting_Period__c'),
                        (Id) secondMasterRecord.get(PACKAGE_QUALIFIER + 'Accounting_Period__c')
                    }
                );

            if ((Id) newObj.get(PACKAGE_QUALIFIER + 'Accounting_Period__c') != recentRelatedPeriod.Id) {
                newObj.addError(
                    String.format(
                        RECENT_PERIOD_MEMO_ERROR,
                        new List<String>{sObjectType.getDescribe().getLabel(), recentRelatedPeriod.Name}
                    )
                );
                isError = true;
            }
        }
    }

    private void validateApplyToNegative(SObject firstMasterRecord) {
        if (!isError) {
            if ((Decimal) firstMasterRecord.get(PACKAGE_QUALIFIER + 'Total__c') < 0) {
                newObj.addError(
                    String.format(
                        NEGATIVE_APPLY_ERROR,
                        new List<String>{sObjectType.getDescribe().getLabel()}
                    )
                );
                isError = true;
            }
        }
    }
}