public with sharing class JournalEntryActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String SOURCE_IMPORT = 'Import';
    public static final String SOURCE_RJE = 'Recurring Journal Entry';
    public static final String SOURCE_BDC = 'Bank Direct Connect';
    public static final String BDC = 'BDC';

    public static void requireFields(List<Journal_Entry__c> journalEntryList) {
        for (Journal_Entry__c je : journalEntryList) {
            if (je.Accounting_Period__c == NULL) {
                je.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            if (je.Ledger__c == NULL) {
                je.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
            Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(je.Ledger__c);
            if (String.isBlank(je.Accrual_and_or_Cash__c)
                    && ledger?.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                je.Accrual_and_or_Cash__c.addError(Label.ERR_ACCRUAL_CASH_IS_REQUIRED_WHEN_ACCRUAL_CASH);
            }
            if (ledger?.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH
                    && String.isNotBlank(je.Accrual_and_or_Cash__c)
                    && je.Accrual_and_or_Cash__c != LedgerActions.ACCOUNTING_METHOD_CASH) {
                je.Accrual_and_or_Cash__c.addError(Label.ERR_ACCRUAL_LEDGER_DOES_NOT_EXIST);
            }
            if (ledger?.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL
                    && String.isNotBlank(je.Accrual_and_or_Cash__c)
                    && je.Accrual_and_or_Cash__c != LedgerActions.ACCOUNTING_METHOD_ACCRUAL) {
                je.Accrual_and_or_Cash__c.addError(Label.ERR_CASH_LEDGER_DOES_NOT_EXIST);
            }
        }
    }

    public static void setReverseAccountingPeriod(List<Journal_Entry__c> journalEntries) {
        setReverseAccountingPeriod(journalEntries, null);
    }
    public static void setReverseAccountingPeriod(List<Journal_Entry__c> journalEntries, Map<Id, Journal_Entry__c> oldJournalEntriesByIds) {
        for (Journal_Entry__c je : journalEntries) {
            Journal_Entry__c oldJE = oldJournalEntriesByIds?.get(je.Id);
            if (String.isNotBlank(je.Accounting_Period__c)
                    && String.isBlank(je.Reverse_Accounting_Period__c)
                    && je.Auto_Reverse__c
                    && (oldJE == null || !oldJE.Auto_Reverse__c)) {
                je.Reverse_Accounting_Period__c = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(je.Accounting_Period__c)?.Id;
            }
        }
    }

    public static void setDefaultFields(List<Journal_Entry__c> journalEntryList) {
        try {
            String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(Journal_Entry__c.Status__c);

            Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();

            for (Journal_Entry__c je : journalEntryList) {
                je.Status__c = (je.Status__c == NULL || SObjectActions.isPostedStatus(je) ? defaultValue : je.Status__c);
                SObjectActions.populateLedgerField(je,defaultLedgerId);
                MultiCurrencyHandler.setCurrencyIsoCodeToUserCurrency(je);
                if (String.isBlank(je.Accrual_and_or_Cash__c) && String.isNotBlank(je.Ledger__c)) {
                    je.Accrual_and_or_Cash__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(je.Ledger__c)?.Accounting_Method__c;
                }
            }
        }
        catch (Exception ex) {
            for (Journal_Entry__c je : journalEntryList) {
                je.addError(ex.getMessage(), false);
            }
        }
    }

    public static void updateBankTransactionStatus(Map<Id, Journal_Entry__c> journalEntriesMap) {
        try {
            Set<Id> bankTransactionIds = new Set<Id>();
            for (Journal_Entry_Line__c jel : DomainUtils.getJournalEntryLineLinkedWithBankTransactionByHeaderId(journalEntriesMap.keySet())) {
                bankTransactionIds.add(jel.Bank_Transaction__c);
            }

            if (!bankTransactionIds.isEmpty()) {
                BankTransactionsHelper.updateBankTransactionsStatus(
                    DomainUtils.getBankTransactionsById(bankTransactionIds),
                    BankTransactionsHelper.BT_UNMATCHED_STATUS
                );
            }
        }
        catch (Exception ex) {
            for (Journal_Entry__c je : journalEntriesMap.values()) {
                je.addError(ex.getMessage(), false);
            }
        }
    }

    public static void reverseJournalEntries(Map<Id, Journal_Entry__c> journalEntriesByIds, Map<Id, Journal_Entry__c> oldJournalEntriesByIds) {
        List<Journal_Entry__c> journalEntries2Reverse = new List<Journal_Entry__c>();
        for (Journal_Entry__c journalEntry : journalEntriesByIds.values()) {
            Journal_Entry__c oldJournalEntry = oldJournalEntriesByIds?.get(journalEntry.Id);
            if (oldJournalEntry != null
                    && String.isBlank(journalEntry.Auto_Reversal_JE__c)
                    && String.isNotBlank(journalEntry.Accounting_Period__c)
                    && journalEntry.Auto_Reverse__c
                    && journalEntry.Status__c == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                    && (journalEntry.Status__c != oldJournalEntry.Status__c || journalEntry.Auto_Reverse__c != oldJournalEntry.Auto_Reverse__c)) {

                journalEntries2Reverse.add(journalEntry);
            }
        }

        if (!journalEntries2Reverse.isEmpty()) {
            if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                Set<Id> ids = new Map<Id, Journal_Entry__c>(journalEntries2Reverse).keySet();
                if (System.isBatch()) {
                    System.enqueueJob(new SourceDocumentCloneQueue(new JournalEntryLDVAutoReverseBatch(ids)));
                } else {
                    Database.executeBatch(new JournalEntryLDVAutoReverseBatch(ids), 200);
                }
                return;
            }

            Map<Id, Journal_Entry__c> reversedJournalEntriesByJEIds = new Map<Id, Journal_Entry__c>();
            for (Journal_Entry__c journalEntry : journalEntries2Reverse) {
                Accounting_Period__c reverseAccountingPeriod = String.isNotBlank(journalEntry.Reverse_Accounting_Period__c)
                        ? AccountingPeriodHandler.getInstance().getAccountingPeriodById(journalEntry.Reverse_Accounting_Period__c)
                        : AccountingPeriodHandler.getInstance().getNextAccountingPeriod(journalEntry.Accounting_Period__c);

                if (reverseAccountingPeriod != null) {
                    Journal_Entry__c reversedJournalEntry = journalEntry.clone(false);
                    reversedJournalEntry.Auto_Reverse__c = false;
                    reversedJournalEntry.Accounting_Period__c = reverseAccountingPeriod.Id;
                    reversedJournalEntry.Journal_Date__c = reverseAccountingPeriod.Start_Date__c;
                    reversedJournalEntry.Reverse_Accounting_Period__c = null;
                    reversedJournalEntry.Name = String.join(new List<String>{journalEntry.Name, Label.AUTO_REVERSAL_JE_NAME_POSTFIX}, '-').left(80);
                    reversedJournalEntriesByJEIds.put(journalEntry.Id, reversedJournalEntry);
                }
            }

            Savepoint saveP0int = Database.setSavepoint();
            try {
                if (!reversedJournalEntriesByJEIds.isEmpty()) {
                    SFDCSecurityUtils.insertCheckCRUDAndFLS(reversedJournalEntriesByJEIds.values(), new List<String>{
                            'Journal_Date__c',
                            'Accounting_Period__c'
                    });

                    List<Journal_Entry_Line__c> reversedJournalEntryLines = new List<Journal_Entry_Line__c>();
                    for (Journal_Entry_Line__c jeLine : DomainUtils.journalEntryLinesByHeaderIds(reversedJournalEntriesByJEIds.keySet())) {
                        Journal_Entry_Line__c clonedJELine = jeLine.clone(false);
                        clonedJELine.Credit__c = jeLine.Debit__c;
                        clonedJELine.Debit__c = jeLine.Credit__c;
                        clonedJELine.Journal_Entry__c = reversedJournalEntriesByJEIds.get(clonedJELine.Journal_Entry__c)?.Id;
                        clonedJELine.Date__c = reversedJournalEntriesByJEIds.get(clonedJELine.Journal_Entry__c)?.Journal_Date__c;
                        reversedJournalEntryLines.add(clonedJELine);
                    }

                    if (!reversedJournalEntryLines.isEmpty()) {
                        SFDCSecurityUtils.insertCheckCRUDAndFLS(reversedJournalEntryLines, new List<String>{
                                'Credit__c',
                                'Debit__c',
                                'Date__c'
                        });
                    }

                    for (Id journalEntryId : reversedJournalEntriesByJEIds.keySet()) {
                        journalEntriesByIds.get(journalEntryId).Auto_Reversal_JE__c = reversedJournalEntriesByJEIds.get(journalEntryId).Id;
                    }
                }
            } catch (Exception e) {
                Database.rollback(saveP0int);
            }
        }
    }

}