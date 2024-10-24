public with sharing class JournalEntryLDVCloneBatch extends SourceDocumentCloneBatch {

    private final Boolean isReverseClone;
    private final Id acctPeriodId;
    private final Date jeDate;
    private final String currencyCode;
    private final Boolean isMultiCurrencyEnabled;

    public JournalEntryLDVCloneBatch(Set<Id> sourceIds, Id acctPeriodId, Date jeDate, String currencyCode, Boolean isReverseClone) {
        super(sourceIds);
        this.isReverseClone = isReverseClone;
        this.acctPeriodId = acctPeriodId;
        this.jeDate = jeDate;
        this.currencyCode = currencyCode != null ? currencyCode : MultiCurrencyHandler.CORPORATE_CURRENCY;
        this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
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
            Map<Id, Journal_Entry__c> clonedJournalEntriesByJEIds = new Map<Id, Journal_Entry__c>();
            for (Journal_Entry__c journalEntry : DomainUtils.journalEntriesById(ids)) {
                if (acctPeriodId != null) {
                    Journal_Entry__c cloneJournalEntry = journalEntry.clone(false);
                    cloneJournalEntry.Name = journalEntry.Name + (isReverseClone ? '-Reversal' : '');
                    cloneJournalEntry.Journal_Date__c = jeDate;
                    cloneJournalEntry.Accounting_Period__c = acctPeriodId;
                    cloneJournalEntry.Currency_Conversion_Rate__c = null;
                    cloneJournalEntry.Auto_Reverse__c = false;
                    cloneJournalEntry.Auto_Reversal_JE__c = null;
                    cloneJournalEntry.Reverse_Accounting_Period__c = null;
                    if (isMultiCurrencyEnabled) {
                        cloneJournalEntry.put('CurrencyIsoCode', currencyCode);
                    }
                    clonedJournalEntriesByJEIds.put(journalEntry.Id, cloneJournalEntry);
                }
            }
            if (!clonedJournalEntriesByJEIds.isEmpty()) {
                clonedIdsByOriginalIds.putAll(
                    this.processCloneSourcesResult(
                        SFDCSecurityUtils.insertCheckCRUDAndFLS(
                            clonedJournalEntriesByJEIds.values(),
                            new List<String>{'Journal_Date__c', 'Accounting_Period__c'},
                            false
                        ),
                    new List<Id>(clonedJournalEntriesByJEIds.keySet())
                ));
            }
        }

        return clonedIdsByOriginalIds;
    }

    public override void cloneLines(List<SObject> lines) {
        List<Journal_Entry_Line__c> filteredLines = (List<Journal_Entry_Line__c>) lines;
        Set<Id> clonedSourceIds = new Set<Id>();
        for (Journal_Entry_Line__c journalEntryLine : filteredLines) {
            clonedSourceIds.add(this.clonedSourceIdsBySourceIds.get(journalEntryLine.Journal_Entry__c));
        }
        Map<Id, Journal_Entry__c> clonedJEsByIds = !clonedSourceIds.isEmpty()
            ? new Map<Id, Journal_Entry__c>(DomainUtils.journalEntriesById(clonedSourceIds))
            : new Map<Id, Journal_Entry__c>();

        List<Journal_Entry_Line__c> clonedJournalEntryLines = new List<Journal_Entry_Line__c>();
        for (Journal_Entry_Line__c jeLine : filteredLines) {
            Id clonedSourceId = clonedSourceIdsBySourceIds.get(jeLine.Journal_Entry__c);
            Journal_Entry_Line__c clonedJELine = jeLine.clone(false);
            clonedJELine.Credit__c = isReverseClone ? jeLine.Debit__c : jeLine.Credit__c;
            clonedJELine.Debit__c = isReverseClone ? jeLine.Credit__c : jeLine.Debit__c;
            clonedJELine.Journal_Entry__c = clonedSourceId;
            clonedJELine.Date__c = clonedJEsByIds.get(clonedSourceId)?.Journal_Date__c;
            clonedJournalEntryLines.add(clonedJELine);
        }

        if (!clonedJournalEntryLines.isEmpty()) {
            this.processCloneSourceLinesResult(
                SFDCSecurityUtils.insertCheckCRUDAndFLS(
                    clonedJournalEntryLines,
                    new List<String>{'Credit__c', 'Debit__c', 'Date__c'}
                ),
                clonedJournalEntryLines
            );
        }
    }

}