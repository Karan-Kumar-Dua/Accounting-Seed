public with sharing class BankDisbursementActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final List<String> NON_UPDATE_FIELDS_IF_RECORDS_ASSOCIATED = new List<String>{
        PACKAGE_QUALIFIER + 'Bank_GL_Account__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c'
    };

    public static final String ERR_PREVENT_FIELDS_UPDATE_IF_RECORDS_ASSOCIATD_ON_BD = Label.ERR_PREVENT_FIELDS_UPDATE_IF_RECORDS_ASSOCIATD_ON_BD;
    public static final String ERR_DELETE_BANKDIS_IF_CHILD_RECORDS = Label.ERR_DELETE_BANKDIS_IF_CHILD_RECORDS;

    public static void requireFields(List<Bank_Disbursement__c> bankDisbursementsList) {
        for (Bank_Disbursement__c bankDisbRec : bankDisbursementsList) {
            if (bankDisbRec.Ledger__c == NULL) {
                bankDisbRec.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
        }
    }

    public static void setDefaultFields(List<Bank_Disbursement__c> bankDisbursementsList) {
        Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();
        for (Bank_Disbursement__c bankDisbRec : bankDisbursementsList) {
            bankDisbRec.Bank_Reconciliation__c = NULL;
            bankDisbRec.Bank_Transaction__c = NULL;
            bankDisbRec.Bank_Transaction_Date__c = NULL;
            bankDisbRec.Amount__c = 0;
            bankDisbRec.Ledger_Amount__c = 0;
            SObjectActions.populateLedgerField(bankDisbRec,defaultLedgerId);
        }
    }

    public static void preventUpdateActionIfChildRecords(Map<Id, Bank_Disbursement__c> oldBankDisbursementMap, Map<Id, Bank_Disbursement__c> newBankDisbursementMap) {
        Map<Id, Bank_Disbursement__c> bankDisbursementCRMap = new Map<Id, Bank_Disbursement__c>(
            DomainUtils.getBankDisbursementById(newBankDisbursementMap.keySet())
        );

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Bank_Disbursement__c.fields.getMap();
        for (Bank_Disbursement__c newBankDisbursement : newBankDisbursementMap.values()) {
            Bank_Disbursement__c oldBankDisbursement = oldBankDisbursementMap.get(newBankDisbursement.Id);
            for (String field : NON_UPDATE_FIELDS_IF_RECORDS_ASSOCIATED) {
                if ((!bankDisbursementCRMap.get(newBankDisbursement.Id).AcctSeed__Cash_Disbursements__r.isEmpty() || !bankDisbursementCRMap.get(newBankDisbursement.Id).AcctSeed__Journal_Entry_Lines__r.isEmpty())
                        && oldBankDisbursement.get(field) != newBankDisbursement.get(field)
                        && !TriggerObserver.getInstance().isUnlockedField(fieldMap.get(field))) {
                            newBankDisbursement.addError(ERR_PREVENT_FIELDS_UPDATE_IF_RECORDS_ASSOCIATD_ON_BD);
                }
            }
        }
    } 

    public static void preventDeleteAction(Map<Id, Bank_Disbursement__c> oldBankDisbursementMap){
        Map<Id, Bank_Disbursement__c> bankDisbursementCDMap = new Map<Id, Bank_Disbursement__c>(
            DomainUtils.getBankDisbursementById(oldBankDisbursementMap.keySet())
        );

        for (Bank_Disbursement__c oldBankDisbursement : oldBankDisbursementMap.values()) {
            if (!bankDisbursementCDMap.get(oldBankDisbursement.Id).AcctSeed__Cash_Disbursements__r.isEmpty() || !bankDisbursementCDMap.get(oldBankDisbursement.Id).AcctSeed__Journal_Entry_Lines__r.isEmpty()) {
                oldBankDisbursement.addError(ERR_DELETE_BANKDIS_IF_CHILD_RECORDS);
            }
        }
    }
}