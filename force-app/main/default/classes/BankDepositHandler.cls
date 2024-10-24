public with sharing class BankDepositHandler {
    
    public final static String SUCCESS_MESSAGE = Label.COMMON_RECORD_ASSOCIATION_UNASSOCIATION_SUCCESS;
    private Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    private Id bankDepositId;

    public BankDepositHandler(Id bankDepositId) {
        this.bankDepositId = bankDepositId;
    }

    public String associateObjectsAndCalculate(List<SObject> sObjects) {
        return process(sObjects, true, true);
    }

    public String associateObjects(List<SObject> sObjects) {
        return process(sObjects, true, false);
    }

    public String unAssociateObjects(List<SObject> sObjects) {
        return process(sObjects, false, false);
    }

    public String unAssociateObjectsAndCalculate(List<SObject> sObjects) {
        return process(sObjects, false, true);
    }

    public BankManagerHelper.Money calculateTotalAmount() {
        return calculateTotalAmountForBankDeposit();
    }


    private String process(List<SObject> sObjectList,
                            Boolean associationMode,
                            Boolean needCalculate) {

        Savepoint sp = Database.setSavepoint();
        try {
            for (SObject obj : sObjectList) {
                obj.put('Bank_Deposit__c', (associationMode) ? bankDepositId : NULL);
            }

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Journal_Entry_Line__c.Bank_Deposit__c
                }
            );
            SFDCSecurityUtils.BYPASS_INTERNAL_FLS_AND_CRUD = true;
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sObjectList, new List<String>{'Bank_Deposit__c'});
            SFDCSecurityUtils.BYPASS_INTERNAL_FLS_AND_CRUD = false;
            TriggerObserver.reset();

            if (needCalculate) {
                calculateTotalAmountForBankDeposit();
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }

        return String.format(
            SUCCESS_MESSAGE,
            new List<String> {associationMode ? 'Associated' : 'Unassociated'}
        );
    }


    private BankManagerHelper.Money calculateTotalAmountForBankDeposit() {
        BankManagerHelper.Money result;
        try {
            Bank_Deposit__c thisBankDeposit;
            List<String> queryFields = new List<String>{
                'Id',
                'Amount__c',
                'Ledger_Amount__c',
                'Ledger__c'
            };

            if (isMultiCurrencyEnabled) {
                queryFields.add('CurrencyIsoCode');
            }

            String queryCondition = 'Id = :bankDepositId LIMIT 1';

            SOQLBuilder theQuery = new SOQLBuilder(Bank_Deposit__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            thisBankDeposit = (Bank_Deposit__c) Database.query(theQuery.toSOQL());

            String bankDepositCurrency = MultiCurrencyHandler.CORPORATE_CURRENCY;
            String ledgerCurrency = MultiCurrencyHandler.CORPORATE_CURRENCY;
            Decimal totalAmount = 0;
            Decimal totalLedgerAmount = 0;

            if (isMultiCurrencyEnabled) {
                bankDepositCurrency = (String) thisBankDeposit.get('CurrencyIsoCode');
                ledgerCurrency = LedgerHandler.getLedgerCurrency(thisBankDeposit.Ledger__c);
            }

            //==================================================================================================
            // CRUD and FLS are handled and checked in the BankDepositManager class
            // Performing CRUD and FLS would be a redundant check for aggregate query
            //==================================================================================================

            //Cash Receipts Amounts aggregation =============
            AggregateResult crAggregateResult =
                DomainUtils.getCashReceiptsAmountSumAndLedgerAmountSum(bankDepositId, Cash_Receipt__c.Bank_Deposit__c)[0];
            if (crAggregateResult.get('amountSum') != NULL) {
                totalAmount += (Decimal) crAggregateResult.get('amountSum');
            }
            if (crAggregateResult.get('ledgerAmountSum') != NULL) {
                totalLedgerAmount += (Decimal) crAggregateResult.get('ledgerAmountSum');
            }
            //Debit Journal Entry Lines Amounts aggregation =============
            AggregateResult debitJELAggregateResult =
                DomainUtils.getDebitJEAmountSumAndLedgerAmountSum(bankDepositId, Journal_Entry_Line__c.Bank_Deposit__c)[0];
            if (debitJELAggregateResult.get('amountSum') != NULL) {
                totalAmount += (Decimal) debitJELAggregateResult.get('amountSum');
            }
            if (debitJELAggregateResult.get('ledgerAmountSum') != NULL) {
                totalLedgerAmount += (Decimal) debitJELAggregateResult.get('ledgerAmountSum');
            }
            //Create Journal Entry Lines Amounts aggregation =============
            AggregateResult creditJELAggregateResult =
                DomainUtils.getCreditJEAmountSumAndLedgerAmountSum(bankDepositId, Journal_Entry_Line__c.Bank_Deposit__c)[0];
            if (creditJELAggregateResult.get('amountSum') != NULL) {
                totalAmount -= (Decimal) creditJELAggregateResult.get('amountSum');
            }
            if (creditJELAggregateResult.get('ledgerAmountSum') != NULL) {
                totalLedgerAmount -= (Decimal) creditJELAggregateResult.get('ledgerAmountSum');
            }

            //FS-5511: If the Bank Deposit’s Currency IS THE SAME AS its Ledger Currency,
            //then in this case (and this case only) populate the Bank Deposit’s Amount field
            //with the amount in the Bank Deposit’s Ledger Amount field
            if (bankDepositCurrency.equals(ledgerCurrency)) {
                totalAmount = totalLedgerAmount;
            }
            thisBankDeposit.Amount__c = totalAmount.setScale(2, System.RoundingMode.HALF_UP);
            thisBankDeposit.Ledger_Amount__c = totalLedgerAmount.setScale(2, System.RoundingMode.HALF_UP);

            //Update Bank Deposit record to populate Amount and Ledger Amount fields =========================
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c}
            );
            SFDCSecurityUtils.updateCheckCRUDAndFLS(thisBankDeposit, new List<String>{'Amount__c', 'Ledger_Amount__c'});
            TriggerObserver.purgeUnlockedFields(
                new Set<SObjectField>{Bank_Deposit__c.Amount__c, Bank_Deposit__c.Ledger_Amount__c}
            );
            //=================================================================================================
            result = new BankManagerHelper.Money(totalAmount, bankDepositCurrency, totalLedgerAmount, ledgerCurrency);
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

}