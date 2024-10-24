public with sharing class BankDepositActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final List<String> nonUpdateFieldsChildRecords = new List<String>{
        PACKAGE_QUALIFIER + 'Bank_Account__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
        PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c'
    };

    public static final String UPDATE_ERROR = String.format(Label.ERR_BANK_DEPOSIT_UPDATE, new List<String>{ '<FIELDS>'});
    public static final String DELETE_ERROR = Label.ERR_BANK_DEPOSIT_DELETE;
    public static final String LEDGER_UPDATE_ERROR = Label.ERR_BANK_DEPOSIT_LEDGER_UPDATE;
    public static Boolean isPreventInsertDefaultFieldOverride = false;
    
    public static void setDefaultFields(List<Bank_Deposit__c> bankDepositsList) {
        if(isPreventInsertDefaultFieldOverride){
            return;
        }
        for (Bank_Deposit__c bankDeposit : bankDepositsList) {
            bankDeposit.Bank_Reconciliation__c = NULL;
            bankDeposit.Amount__c = 0;
        }
    }

    public static void preventUpdateActionChildRecords(Map<Id, Bank_Deposit__c> oldBankDepositMap, Map<Id, Bank_Deposit__c> newBankDepositMap) {
        Map<Id, Bank_Deposit__c> bankDepositCRMap = new Map<Id, Bank_Deposit__c>(
            DomainUtils.getBankDepositsById(newBankDepositMap.keySet())
        );

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Bank_Deposit__c.fields.getMap();

        for (Bank_Deposit__c newBankDeposit : newBankDepositMap.values()) {
            Bank_Deposit__c oldBankDeposit = oldBankDepositMap.get(newBankDeposit.Id);
            for (String field : nonUpdateFieldsChildRecords) {
                if ((!bankDepositCRMap.get(newBankDeposit.Id).Cash_Receipts__r.isEmpty() || !bankDepositCRMap.get(newBankDeposit.Id).Journal_Entry_Lines__r.isEmpty())
                        && oldBankDeposit.get(field) != newBankDeposit.get(field)
                        && !TriggerObserver.getInstance().isUnlockedField(fieldMap.get(field))) {

                    newBankDeposit.addError(
                        UPDATE_ERROR.replace(
                            '<FIELDS>',
                            FinancialSuiteUtils.formatFieldStrings(
                                Bank_Deposit__c.getSObjectType(),
                                nonUpdateFieldsChildRecords
                            )
                        ),
                        false
                    );
                }
            }
        }
    }

    public static void preventUpdateLedgerOnClearedBD(Map<Id, Bank_Deposit__c> oldBankDepositMap, Map<Id, Bank_Deposit__c> newBankDepositMap) {
        Boolean isSystemLedgerUpdated;
        for (Bank_Deposit__c newBankDeposit : newBankDepositMap.values()) {
            Bank_Deposit__c oldBankDeposit = oldBankDepositMap.get(newBankDeposit.Id);
            isSystemLedgerUpdated = false;
            if (oldBankDeposit.Ledger__c == NULL && newBankDeposit.Ledger__c == LedgerHandler.getLegacyDefaultLedgerId()) {
                isSystemLedgerUpdated = true;
            }
            if ((newBankDeposit.Ledger__c != oldBankDeposit.Ledger__c) && !isSystemLedgerUpdated && newBankDeposit.Cleared_Date__c != NULL) {
                newBankDeposit.addError(LEDGER_UPDATE_ERROR, false);
            }
        }
    }

    public static void preventDeleteAction(Bank_Deposit__c[] bankDepositsList) {
        for (Bank_Deposit__c bankDeposit : bankDepositsList) {
            if (bankDeposit.Bank_Reconciliation__c != NULL) {
                bankDeposit.addError(DELETE_ERROR, false);
            }
        }
    }


    public static void setLedgerAmount(List<Bank_Deposit__c> bankDepositsList, Map<Id, Bank_Deposit__c> oldBankDepositMap) {
        Map<Id, Bank_Deposit__c> bankDepositsUpdateLedgerAmount = new Map<Id, Bank_Deposit__c>();
        for (Bank_Deposit__c bankDeposit : bankDepositsList) {
            if(!MultiCurrencyHandler.isMultiCurrencyEnabled && bankDeposit.Ledger_Amount__c == null && oldBankDepositMap.get(bankDeposit.Id).Ledger_Amount__c == null){
                TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Ledger_Amount__c});
                bankDeposit.Ledger_Amount__c = bankDeposit.Amount__c;
            } else if(MultiCurrencyHandler.isMultiCurrencyEnabled && bankDeposit.Ledger_Amount__c == null && oldBankDepositMap.get(bankDeposit.Id).Ledger_Amount__c == null){
                bankDepositsUpdateLedgerAmount.put(bankDeposit.Id, bankDeposit);
            }  
        }

        if(!bankDepositsUpdateLedgerAmount.isEmpty()){
            Map<Id,Decimal> crLedgerAmountByBD = DomainUtils.getCRLedgerAmountSumByBankDep(bankDepositsUpdateLedgerAmount.keySet());
            Map<Id,Decimal> debitJELedgerAmountByBD = DomainUtils.getDebitJELedgerAmountSumByBankDep(bankDepositsUpdateLedgerAmount.keySet());
            Map<Id,Decimal> creditJELedgerAmountByBD = DomainUtils.getCreditJELedgerAmountSumByBankDep(bankDepositsUpdateLedgerAmount.keySet());
    
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Ledger_Amount__c});
            
            for(Bank_Deposit__c bankDeposit : bankDepositsUpdateLedgerAmount.values()){
                bankDeposit.Ledger_Amount__c = 0;
                bankDeposit.Ledger_Amount__c += crLedgerAmountByBD.get(bankDeposit.Id) != null ? (Decimal)crLedgerAmountByBD.get(bankDeposit.Id): 0;
                bankDeposit.Ledger_Amount__c += debitJELedgerAmountByBD.get(bankDeposit.Id) != null ?(Decimal)debitJELedgerAmountByBD.get(bankDeposit.Id): 0;
                bankDeposit.Ledger_Amount__c -= creditJELedgerAmountByBD.get(bankDeposit.Id) != null ?(Decimal)creditJELedgerAmountByBD.get(bankDeposit.Id): 0;
            }
        }
       

    }

}