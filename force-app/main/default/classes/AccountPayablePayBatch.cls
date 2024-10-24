public with sharing class AccountPayablePayBatch extends AccountPayablePaymentHandler {

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private ApexPages.StandardSetController stdSetController;
    private static List<String> fieldsToIgnore = new List<String>{PACKAGE_QUALIFIER + 'Cash_Flow_Category__c'};

    public Boolean isError {get; set;}
    public Boolean aggregateByPayee {get;set;}

    public AccountPayablePayBatch(ApexPages.StandardSetController setController) {
        this.stdSetController = setController;
        isError = false;
        aggregateByPayee = true;
        results = init((List<Account_Payable__c>) stdSetController.getSelected(), true, aggregateByPayee);
        if (!processPaymentResults()) {
            isError = true;
        }
    }

    public void updateDiscountAmountEditable() {
        if (wrappedCDs != null) {
            for (CashDisbursementWrapper item : wrappedCDs) {
                item.isDiscountAmountEditable = !this.aggregateByPayee && item.isDiscountAmountReady4Edit;
            }
        }
    }

    public List<Schema.FieldSetMember> getFieldSetFields() {
        List<Schema.FieldSetMember> fieldSetMembers = Schema.getGlobalDescribe()
                .get(PACKAGE_QUALIFIER + 'Cash_Disbursement__c')
                .getDescribe()
                .fieldSets
                .getMap()
                .get(PACKAGE_QUALIFIER + 'Pay_Batch_Screen')
                .getFields();

        for(Integer index = 0; index < fieldSetMembers.size(); index++){
            if(isCashFlowStatementEnabled && fieldsToIgnore.contains(fieldSetMembers[index].fieldPath)){
                fieldSetMembers.remove(index);
            }
        }
        return fieldSetMembers;
    }

    public String getListViewId() {
        return stdSetController.getFilterId();
    }

    public String getSObjectApiName() {
        return Account_Payable__c.SObjectType.getDescribe().getName();
    }

    public PageReference payBatch() {
        if (validateAccountingPeriod()) {
            if (validate1099TypeBatch()) {
                if (aggregateByPayee || validateAndUpdateDiscountAmount()) {
                    uiCashDisbursement.Form_1099_Box__c = NULL;
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
        } else {
            return NULL;
        }
    }

    public PageReference payBatchAndPost() {
        if (validateAccountingPeriod()) {
            if (validate1099TypeBatch()) {
                if (aggregateByPayee || validateAndUpdateDiscountAmount()) {
                    uiCashDisbursement.Form_1099_Box__c = NULL;
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
        } else {
            return NULL;
        }
    }

    private Boolean validateAndUpdateDiscountAmount() {
        Boolean isValid = true;
        List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
        Map<Id, Account_Payable__c> payablesByIds = new Map<Id, Account_Payable__c>();
        for (CashDisbursementWrapper wrappedCD : wrappedCDs) {
            if (!wrappedCD.payments.isEmpty() && wrappedCD.discountAmount != wrappedCD.payments[0].Discount_Amount__c) {
                if (wrappedCD.cashDisbursement.Amount__c - wrappedCD.creditMemoAmount - wrappedCD.payments[0].Discount_Amount__c >= 0) {
                    wrappedCD.cashDisbursement.Amount__c = wrappedCD.cashDisbursement.Amount__c - wrappedCD.creditMemoAmount - wrappedCD.payments[0].Discount_Amount__c;
                    wrappedCD.discountAmount = wrappedCD.payments[0].Discount_Amount__c;
                }
                accountPayables.add(new Account_Payable__c(
                        Id = wrappedCD.payments[0].Id,
                        Discount_Amount__c = wrappedCD.payments[0].Discount_Amount__c
                ));
                payablesByIds.put(wrappedCD.payments[0].Id, wrappedCD.payments[0]);
            }
        }
        if (!accountPayables.isEmpty()) {
            try {
                Set<SObjectField> lockedFieldsToUpdate = new Set<SObjectField>{
                        Account_Payable__c.Discount_Amount__c
                };

                TriggerObserver.getInstance().unlockFields(lockedFieldsToUpdate);
                SFDCSecurityUtils.updateCheckCRUDAndFLS(accountPayables, new List<String>{'Discount_Amount__c'});
                TriggerObserver.purgeUnlockedFields(lockedFieldsToUpdate);
            } catch (DmlException ex) {
                for (Integer index = 0; index < ex.getNumDml(); index++) {
                    isValid = false;
                    Account_Payable__c payable = payablesByIds.get(ex.getDmlId(index));
                    if (payable != null) {
                        payable.Discount_Amount__c.addError(ex.getDmlMessage(index));
                    }
                }
            }
        }

        return isValid;
    }

    private Boolean validateAccountingPeriod() {
        Boolean isValidUserInput = true;

        for (CashDisbursementWrapper wrappedCD : wrappedCDs) {
            if (wrappedCD.isSelected && AccountingPeriodHandler.getInstance()
                    .getAccountingPeriodByDate(wrappedCD.cashDisbursement.Disbursement_Date__c) == NULL) {
                wrappedCD.cashDisbursement.Disbursement_Date__c.addError(NO_ACCOUNTING_RANGE_ERROR);
                isValidUserInput = false;
            }
        }
        return isValidUserInput;
    }

    
    public PageReference updateAggregateByPayee(){
        isError = false;
        results = init((List<Account_Payable__c>) stdSetController.getSelected(), true, aggregateByPayee);
        if (!processPaymentResults()) {
            isError = true;
        }
        updateDiscountAmountEditable();
        return NULL;
    }
}