public with sharing class ALMRowTemplateDefault implements ALMRowCreateHandler {
    /**
     * a interface method which requires a ALMRowCreateEvent as a argument to get records as per user's business requirements
     */
    public List<SObject> createRow(ALMRowCreateEvent eventState){
        return getDefaultRecords(eventState);
    }
    /**
     * user may add their custom implementation to get their desired records
     * this method will be used when user wants the data from default implementations
     */
    private List<SObject> getDefaultRecords(ALMRowCreateEvent eventState){
        List<SObject> linesRecord = new List<SObject>();
        for(Integer index = 1; index <= eventState.createRowsCount; index++){
            SObject line = Schema.getGlobalDescribe().get(eventState.linesObjectApiName).newSObject();
            linesRecord.add(line);
        }
        return linesRecord;
    }
}