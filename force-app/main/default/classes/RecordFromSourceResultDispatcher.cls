public with sharing class RecordFromSourceResultDispatcher {

    private Map<String, RecordFromSourceResult> theResultsMap;

    public RecordFromSourceResultDispatcher() {
        this.theResultsMap = new Map<String, RecordFromSourceResult>();
    }

    /*
    * Id parameter can contain SF Record Id
     */
    public void addError(String id, RecordFromSourceResult.RecordFromSourceResultError theErrorResult) {
        if (theResultsMap.containsKey(id)) {
            theResultsMap
                .get(id)
                .errors
                .add(theErrorResult);
        }
        else {
            theResultsMap.put(
                id,
                new RecordFromSourceResult(
                    false,
                    id,
                    new List<RecordFromSourceResult.RecordFromSourceResultError>{
                        theErrorResult
                    }
                )
            );
        }
    }

    public void addResult(String id, RecordFromSourceResult newResult) {
        this.theResultsMap.put(id, newResult);
    }

    public List<RecordFromSourceResult> getResults() {
        return theResultsMap.values();
    }

    public Map<String, RecordFromSourceResult> getResultsMap() {
        return theResultsMap;
    }

    public void clearResultsMap() {
        theResultsMap.clear();
    }

}