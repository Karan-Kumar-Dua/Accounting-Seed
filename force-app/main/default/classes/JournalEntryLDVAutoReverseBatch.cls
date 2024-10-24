public with sharing class JournalEntryLDVAutoReverseBatch extends SourceDocumentCloneBatch {
    public JournalEntryLDVAutoReverseBatch(Set<Id> sourceIds) {
        super(sourceIds);
    }

    public override Database.QueryLocator start(Database.BatchableContext ctx) {
        return DomainUtils.getQueryLocator(DomainUtils.journalEntryLinesByHeaderIdsQuery(), this.clonedSourceIdsBySourceIds.keySet());
    }

    public override Id sourceIdByLineRecord(SObject line) {
        return (Id)line.get(GlobalVariables.PACKAGE_QUALIFIER + 'Journal_Entry__c');
    }

    public override Map<Id, Id> cloneSources(Set<Id> ids) {
        Map<Id, Id> clonedIdsByOriginalIds = new Map<Id, Id>();

        if (!ids.isEmpty()) {
            Map<Id, Journal_Entry__c> reversedJournalEntriesByJEIds = new Map<Id, Journal_Entry__c>();
            for (Journal_Entry__c journalEntry : DomainUtils.journalEntriesById(ids)) {
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
            if (!reversedJournalEntriesByJEIds.isEmpty()) {
                clonedIdsByOriginalIds.putAll(this.processCloneSourcesResult(
                        SFDCSecurityUtils.insertCheckCRUDAndFLS(
                                reversedJournalEntriesByJEIds.values(),
                                new List<String>{
                                        'Journal_Date__c',
                                        'Accounting_Period__c'
                                },
                                false
                        ),
                        new List<Id>(reversedJournalEntriesByJEIds.keySet())
                ));
                List<Journal_Entry__c> originalJournalEntries = new List<Journal_Entry__c>();
                for (Id sourceId : clonedIdsByOriginalIds.keySet()) {
                    if (String.isNotBlank(clonedIdsByOriginalIds.get(sourceId))) {
                        originalJournalEntries.add(new Journal_Entry__c(Id = sourceId, Auto_Reversal_JE__c = clonedIdsByOriginalIds.get(sourceId)));
                    }
                }
                if (!originalJournalEntries.isEmpty()) {
                    TriggerObserver.getInstance().unlockField(Journal_Entry__c.Auto_Reversal_JE__c);
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(
                            originalJournalEntries,
                            new List<String>{
                                    'Auto_Reversal_JE__c'
                            },
                            false
                    );
                    TriggerObserver.purgeUnlockedFields(Journal_Entry__c.Auto_Reversal_JE__c);
                }
            }
        }

        return clonedIdsByOriginalIds;
    }

    public override void cloneLines(List<SObject> lines) {
        List<Journal_Entry_Line__c> filteredLines = (List<Journal_Entry_Line__c>)lines;
        Set<Id> clonedSourceIds = new Set<Id>();
        for (Journal_Entry_Line__c journalEntryLine : filteredLines) {
            clonedSourceIds.add(this.clonedSourceIdsBySourceIds.get(journalEntryLine.Journal_Entry__c));
        }
        Map<Id, Journal_Entry__c> reversedJEsByIds = !clonedSourceIds.isEmpty()
                ? new Map<Id, Journal_Entry__c>(DomainUtils.journalEntriesById(clonedSourceIds))
                : new Map<Id, Journal_Entry__c>();

        List<Journal_Entry_Line__c> reversedJournalEntryLines = new List<Journal_Entry_Line__c>();
        for (Journal_Entry_Line__c jeLine : filteredLines) {
            Id clonedSourceId = clonedSourceIdsBySourceIds.get(jeLine.Journal_Entry__c);
            Journal_Entry_Line__c clonedJELine = jeLine.clone(false);
            clonedJELine.Credit__c = jeLine.Debit__c;
            clonedJELine.Debit__c = jeLine.Credit__c;
            clonedJELine.Journal_Entry__c = clonedSourceId;
            clonedJELine.Date__c = reversedJEsByIds.get(clonedSourceId)?.Journal_Date__c;
            reversedJournalEntryLines.add(clonedJELine);
        }

        if (!reversedJournalEntryLines.isEmpty()) {
            this.processCloneSourceLinesResult(
                SFDCSecurityUtils.insertCheckCRUDAndFLS(reversedJournalEntryLines, new List<String>{
                    'Credit__c',
                    'Debit__c',
                    'Date__c'
                }),
                reversedJournalEntryLines
            );
        }
    }
}