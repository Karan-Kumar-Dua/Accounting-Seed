public with sharing class APDisbursementVoidBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final String JOB_NAME = 'AP Disbursement Void Job';

    private final Cash_Disbursement__c cashDisbursement;
    private final Cash_Disbursement__c cashDisbursementVoidRec;

    private final Map<Id, Account_Payable__c> accountPayableRecsByIds = new Map<Id, Account_Payable__c>();

    private final List<Map<Key, String>> errors = new List<Map<Key, String>>();
    private final Set<Id> newAPDIds = new Set<Id>();
    private Integer processedCount = 0;

    public APDisbursementVoidBatch(Cash_Disbursement__c cashDisbursement, Cash_Disbursement__c cashDisbursementVoid) {
        this.cashDisbursement = cashDisbursement;
        this.cashDisbursementVoidRec = cashDisbursementVoid;
    }

    public List<AP_Disbursement__c> start(Database.BatchableContext bc) {
        return CashDisbursementVoid.fetchAPDisbursements(this.cashDisbursement.Id);
    }

    public void execute(Database.BatchableContext context, List<AP_Disbursement__c> apDisbursements) {
        processedCount += apDisbursements.size();
        if (errors.isEmpty()) {
            try {
                CashDisbursementVoid.OppositeAPDsWrapper wrapper = CashDisbursementVoid.prepareOppositeAPDs(apDisbursements, this.cashDisbursementVoidRec.Accounting_Period__c);
                accountPayableRecsByIds.putAll(wrapper.accountPayableRecsByIds);
                MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext = true;
                List<AP_Disbursement__c> newAPDs = wrapper.apDisbIdsByNewAPDisbursements.values();
                SFDCSecurityUtils.insertCheckCRUDAndFLS(newAPDs, new List<String>{
                        'Paid_Amount__c'
                });
                MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext = false;
                newAPDIds.addAll(new Map<Id, AP_Disbursement__c>(newAPDs).keySet());
            } catch (Exception e) {
                errors.add(new Map<Key, String>{Key.MSG => e.getMessage()});
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (this.errors.isEmpty()) {
            Savepoint sPoint = Database.setSavepoint();
            try {
                Set<Schema.SObjectField> fieldsToUnlock = new Set<SObjectField>{
                        Cash_Disbursement__c.Payment_Status__c,
                        Cash_Disbursement__c.Void_Date__c,
                        Account_Payable__c.Closed_Accounting_Period__c
                };

                TriggerObserver.getInstance().unlockFields(fieldsToUnlock);

                SFDCSecurityUtils.updateCheckCRUDAndFLS(
                        new Cash_Disbursement__c(
                                Id = cashDisbursement.Id,
                                Payment_Status__c = CashDisbursementActions.STATUS_VOID,
                                Void_Description__c = cashDisbursementVoidRec.Void_Description__c,
                                Void_Date__c = cashDisbursementVoidRec.Disbursement_Date__c
                        ),
                        new List<String>{
                                'Payment_Status__c',
                                'Void_Date__c',
                                'Void_Description__c'
                        }
                );

                MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext = true;
                SFDCSecurityUtils.updateCheckCRUDAndFLS(accountPayableRecsByIds.values(), new List<String>{
                        'Closed_Accounting_Period__c',
                        'Payment_Status__c'
                });
                MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext = false;

                //create new Transactions that counter the existed Transactions for the Cash Disbursement and related AP Disbursements
                List<Transaction__c> transactions = new List<Transaction__c>();
                for (Transaction__c trans : CashDisbursementVoid.queryTransactions(cashDisbursement.Id)) {
                    transactions.add(CashDisbursementVoid.createCounterTransaction(trans, cashDisbursement, cashDisbursementVoidRec));
                }

                CubeBuilder.isEnabledCashFlowStatement = AccountingSettingsHandler.getAccountingSettings().Enable_Cash_Flow_Statement__c;
                TransactionActions.createTransactions(transactions);
                CubeBuilder.isEnabledCashFlowStatement = false;
                TriggerObserver.reset();
            } catch (Exception e) {
                Database.rollback(sPoint);
                errors.add(new Map<Key, String>{Key.MSG => e.getMessage()});
                deleteNewAPDs();
            }
        } else {
            deleteNewAPDs();
        }

        AutomatedJobResultsHandler.setJobType(JOB_NAME);
        AutomatedJobResultsHandler.addProcessed(this.processedCount);
        String formatObjName =  AP_Disbursement__c.getSObjectType().getDescribe().labelPlural;
        AutomatedJobResultsHandler.addSucceeded(this.newAPDIds.size());
        AutomatedJobResultsHandler.addFailed(this.processedCount - this.newAPDIds.size());

        AutomatedJobResultsHandler.setError(String.format(Label.ERR_AUTOMATED_JOB_RESULT_PROCESSED, new List<Object>{formatObjName, this.processedCount}));
        AutomatedJobResultsHandler.setError(String.format(Label.ERR_AUTOMATED_JOB_RESULT_FAILED, new List<Object>{formatObjName, this.processedCount - this.newAPDIds.size()}));
        for (Map<Key, String> error : errors) {
            AutomatedJobResultsHandler.setError(error.get(Key.MSG));
        }
        AutomatedJobResultsHandler.saveAutomatedJobResults();
    }

    private void deleteNewAPDs() {
        try {
            SFDCSecurityUtils.deleteProxy(new List<Id>(newAPDIds));
        } catch (Exception e) {}
    }

    public enum Key {
        MSG
    }
}