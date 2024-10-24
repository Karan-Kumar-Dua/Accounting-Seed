public abstract with sharing class SourceDocumentCloneBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final Map<SObjectType, SObjectField> refParentFieldsByLineSObjectTypes = new Map<SObjectType, SObjectField>{
            Journal_Entry_Line__c.getSObjectType() => Journal_Entry_Line__c.Journal_Entry__c,
            Billing_Line__c.getSObjectType() => Billing_Line__c.Billing__c
    };

    public Map<Id, Id> clonedSourceIdsBySourceIds;
    public Set<Id> failedSourceIds;
    public Set<Id> failedClonedSourceIds;

    public Map<Id, CloneResult> resultsByFailedSourceIds;

    public Map<Id, Map<LineCounterKey, Integer>> countsBySourceIds;

    public SourceDocumentCloneBatch(Set<Id> sourceIds) {
        this.failedSourceIds = new Set<Id>();
        this.failedClonedSourceIds = new Set<Id>();
        this.resultsByFailedSourceIds = new Map<Id, SourceDocumentCloneBatch.CloneResult>();
        this.countsBySourceIds = new Map<Id, Map<LineCounterKey, Integer>>();

        this.clonedSourceIdsBySourceIds = new Map<Id, Id>();
        if (sourceIds != null) {
            for (Id sourceId : sourceIds) {
                this.clonedSourceIdsBySourceIds.put(sourceId, null);
            }
        }
    }

    public abstract Database.QueryLocator start(Database.BatchableContext ctx);

    public void execute(Database.BatchableContext ctx, List<SObject> scope) {
        Set<Id> cloneThisSources = new Set<Id>();
        for (SObject line : scope) {
            Id sourceId = sourceIdByLineRecord(line);
            if (String.isNotBlank(sourceId)
                    && !failedSourceIds.contains(sourceId)
                    && String.isBlank(clonedSourceIdsBySourceIds.get(sourceId))) {

                cloneThisSources.add(sourceId);
            }
        }

        if (!cloneThisSources.isEmpty()) {
            this.clonedSourceIdsBySourceIds.putAll(
                cloneSources(cloneThisSources)
            );
        }

        List<SObject> filteredLines = filterValidLines(scope);
        this.countsBySourceIds.putAll(presetCountsBySourceIds(filteredLines));
        if (!filteredLines.isEmpty()) {
            cloneLines(filteredLines);
        }

        this.commitCloneResults();
        this.resultsByFailedSourceIds.clear();
    }

    public void finish(Database.BatchableContext ctx) {
        if (!this.failedClonedSourceIds.isEmpty()) {
//            ToDo: remove failed cloned sources here if necessary
        }
    }

    public abstract Id sourceIdByLineRecord(SObject record);
    public abstract Map<Id, Id> cloneSources(Set<Id> cloneThisSources);
    public abstract void cloneLines(List<SObject> lines);

    public void commitCloneResults() {
        for (Id sourceId : this.countsBySourceIds.keySet()) {
            Map<LineCounterKey, Integer> countsByKeys = this.countsBySourceIds.get(sourceId);
            if (countsByKeys.get(LineCounterKey.COMMON_LINES) <= countsByKeys.get(LineCounterKey.PROCESSED)) {
//                ToDo: create a completion message here if necessary
            }
        }
        if (!resultsByFailedSourceIds.isEmpty()) {
//            ToDo: save CloneResults here if necessary
        }
    }

    public Map<Id, Id> processCloneSourcesResult(List<Database.SaveResult> saveResults, List<Id> sourceIds) {
        Map<Id, Id> clonedIdsByOriginalIds = new Map<Id, Id>();
        for (Integer index = 0; index < saveResults.size(); index++) {
            Database.SaveResult sResult = saveResults[index];
            if (sResult.success) {
                clonedIdsByOriginalIds.put(sourceIds[index], sResult.id);
            } else {
                Id sourceId = sourceIds[index];
                CloneResult cloneResultItem = new CloneResult(new List<CloneResultError>{new CloneResultError(sResult.errors[0].message)});
                this.failedSourceIds.add(sourceId);
                this.resultsByFailedSourceIds.put(sourceId, cloneResultItem);
            }
        }
        return clonedIdsByOriginalIds;
    }

    public Map<Id, Id> processCloneSourceLinesResult(List<Database.SaveResult> saveResults, List<SObject> clonedLines) {
        Map<Id, Id> clonedIdsByOriginalIds = new Map<Id, Id>();
        for (Integer index = 0; index < saveResults.size(); index++) {
            Database.SaveResult sResult = saveResults[index];
            if (!sResult.success) {
                Id clonedSourceId = sourceIdByLineRecord(clonedLines[index]);
                CloneResult cloneResultItem = new CloneResult(new List<CloneResultError>{new CloneResultError(sResult.errors[0].message)});
                this.failedClonedSourceIds.add(clonedSourceId);
                this.resultsByFailedSourceIds.put(clonedSourceId, cloneResultItem);
            }
        }
        return clonedIdsByOriginalIds;
    }

    protected List<SObject> filterValidLines(List<SObject> lines) {
        List<SObject> filteredLines = new List<SObject>();
        for (SObject line : lines) {
            Id sourceId = sourceIdByLineRecord(line);
            if (!this.failedSourceIds.contains(sourceId)
                    && String.isNotBlank(this.clonedSourceIdsBySourceIds.get(sourceId))
                    && !this.failedClonedSourceIds.contains(this.clonedSourceIdsBySourceIds.get(sourceId))) {
                filteredLines.add(line);
            }
        }

        return filteredLines;
    }

    protected Map<Id, Map<LineCounterKey, Integer>> presetCountsBySourceIds(List<SObject> lines) {
        Map<Id, Map<LineCounterKey, Integer>> countsBySourceIds = new Map<Id, Map<SourceDocumentCloneBatch.LineCounterKey, Integer>>();
        for (SObject line : lines) {
            Id sourceId = sourceIdByLineRecord(line);
            if (!this.countsBySourceIds.containsKey(sourceId)) {
                countsBySourceIds.put(sourceId, null);
            }
        }
        if (!countsBySourceIds.isEmpty()) {
            SObjectType sourceSObjectType = !lines.isEmpty() ? lines[0].Id.getSObjectType() : null;
            SObjectField refToParent = refParentFieldsByLineSObjectTypes.get(sourceSObjectType);
            List<AggregateResult> results = DomainUtils.countLinesByParentIds(String.valueOf(sourceSObjectType), String.valueOf(refToParent), countsBySourceIds.keySet());
            Map<Id, Integer> countLinesByParentIds = new Map<Id, Integer>();
            for (AggregateResult result : results) {
                countLinesByParentIds.put((Id)result.get('refToParent'), (Integer)result.get('c0unt'));
            }

            for (Id sourceId : countsBySourceIds.keySet()) {
                countsBySourceIds.put(sourceId, new Map<SourceDocumentCloneBatch.LineCounterKey, Integer>{
                        LineCounterKey.COMMON_LINES => countLinesByParentIds.get(sourceId) != null
                            ? countLinesByParentIds.get(sourceId)
                            : 0,
                        LineCounterKey.PROCESSED => 0
                });
            }
        }
        for (SObject line : lines) {
            Id sourceId = sourceIdByLineRecord(line);
            if (this.countsBySourceIds.containsKey(sourceId)) {
                Map<LineCounterKey, Integer> countsByKeys = this.countsBySourceIds.get(sourceId);
                countsByKeys.put(LineCounterKey.PROCESSED, countsByKeys.get(LineCounterKey.PROCESSED) + 1);
                this.countsBySourceIds.put(sourceId, countsByKeys);
            }
        }
        return countsBySourceIds;
    }

    public class CloneResult {
        public List<CloneResultError> errors;

        public CloneResult() {
            this.errors = new List<SourceDocumentCloneBatch.CloneResultError>();
        }

        public CloneResult(List<CloneResultError> errors) {
            this();
            this.errors.addAll(errors);
        }

        public CloneResult add(CloneResultError resultError) {
            this.errors.add(resultError);
            return this;
        }
    }

    public class CloneResultError {
        public String message;

        public CloneResultError(String message) {
            this.message = message;
        }
    }

    public enum LineCounterKey {
        COMMON_LINES, PROCESSED
    }
}