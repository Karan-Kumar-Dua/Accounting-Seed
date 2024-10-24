public with sharing class BankRecCompletedStatusChangeQueueable implements Queueable {

    private Step currentStep;
    private Set<Id> bankRecIds;

    public BankRecCompletedStatusChangeQueueable(Step currentStep, Set<Id> bankRecIds) {
        this.currentStep = currentStep;
        this.bankRecIds = bankRecIds;
    }

    public void execute(QueueableContext context) {
        switch on currentStep {
            when UPDATE_UNCLEARED_VALUES {
                updateUnclearedValues();
                goToNextStep(BankRecCompletedStatusChangeQueueable.Step.CREATE_UBRLS);
            }
            when CREATE_UBRLS {
                createUnclearedBankReconciliationLines();
                goToNextStep(BankRecCompletedStatusChangeQueueable.Step.UPDATE_GL_ENDING_BALANCES);
            }
            when UPDATE_GL_ENDING_BALANCES {
                updateGLEndingBalances();
            }
            when else {
                //For Test Context: Execute all steps together b/c Queueable jobs chaining is not allowed
                updateUnclearedValues();
                createUnclearedBankReconciliationLines();
                updateGLEndingBalances();
            }
        }
    }

    private void goToNextStep(Step nextStep) {
        System.enqueueJob(new BankRecCompletedStatusChangeQueueable(nextStep, this.bankRecIds));
    }

    private void updateUnclearedValues() {
        for (Id recId : bankRecIds) {
            try {
                ServiceResult sr = BankReconciliation.calculateUnclearedDepositsAndPayments(recId);
                if (!sr.isSuccess) {
                    BankRecUpdatedActions.logErrorToBankRec(recId, String.join(sr.errors, ','));
                }
            } catch (DMLException dmlEx) {
                BankRecUpdatedActions.logErrorToBankRec(recId, dmlEx.getDMLMessage(0));
            } catch (Exception ex) {
                BankRecUpdatedActions.logErrorToBankRec(recId, ex.getMessage());
            }
        }
    }

    private void createUnclearedBankReconciliationLines() {
        for (Id recId : bankRecIds) {
            try {
                ServiceResult sr = BankReconciliation.createUnclearedBankReconciliationLines(recId);
                if (!sr.isSuccess) {
                    BankRecUpdatedActions.logErrorToBankRec(recId, String.join(sr.errors, ','));
                }
            } catch (DMLException dmlEx) {
                BankRecUpdatedActions.logErrorToBankRec(recId, dmlEx.getDMLMessage(0));
            } catch (Exception ex) {
                BankRecUpdatedActions.logErrorToBankRec(recId, ex.getMessage());
            }
        }
    }

    private void updateGLEndingBalances() {
        Map<Id, String> errors = new Map<Id, String>();
        for (Bank_Reconciliation2__c brec : DomainUtils.getBankRecsById(bankRecIds)) {
            try {
                GLAccountBalanceOption options = new GLAccountBalanceOption();
                options.inquiryDate = brec.End_Date__c;
                options.requestId = brec.Id;
                options.ledgerId = brec.Ledger__c;
                options.glAccountId = brec.Bank_Account__c;
                options.glVariable1Id = brec.GL_Account_Variable_1__c;
                options.glVariable2Id = brec.GL_Account_Variable_2__c;
                options.glVariable3Id = brec.GL_Account_Variable_3__c;
                options.glVariable4Id = brec.GL_Account_Variable_4__c;

                String ledgerCurrency = LedgerHandler.getLedgerCurrency(brec.Ledger__c);
                // if b-rec currency == b-rec ledger currency, then calculate GL ending balance
                if (MultiCurrencyHandler.isSameCurrency(ledgerCurrency, brec)) {
                    ServiceResult result = GLAccount.retrieveBalance(options);
                    if (!result.isSuccess) {
                        errors.put(brec.Id, BankRecUpdatedActions.getErrorMessage(result));
                    }
                }
                // else b-rec currency != ledger currency, skip calculation, fire event
                else {
                    GLAccountBalance.publishBalance(options, 0);
                }
            } catch (Exception ex) {
                errors.put(brec.Id, ex.getMessage());
            }
        }
        if (!errors.isEmpty()) {
            BankRecUpdatedActions.logErrorsToBankRecs(errors);
        }
    }

    public enum Step {UPDATE_UNCLEARED_VALUES, CREATE_UBRLS, UPDATE_GL_ENDING_BALANCES}
}