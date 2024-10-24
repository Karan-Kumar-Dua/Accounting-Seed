public with sharing class ALMRowTemplateHelper {
    private static final String DEFAULT_TEMPLATE = 'ALMRowTemplateDefault';
    private class ALMRowTemplateHelperException extends Exception {}

    /**
     * this will check wether we have a Row Change template defined for the current Object
     * Input - objectApiName - current object api name
     * return - Boolean
     *          TRUE - this will tell that we have a default row change implementation available
     *          FALSE - we do not have any implementation for the current object 
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasRowChangeTemplate(String objectApiName){
        if(objectApiName == SobjectType.Account_Payable__c.getName()){
            return true;
        }
        return false;
    }
    /**
     * method to create rows when user disable the caching
     * which will results in same speed in every subsequent calls
     */
    @AuraEnabled(cacheable=false)
    public static List<SObject> createRowCacheDisabled(String stateJson, String templateName){
        try{
            return createRow(stateJson,templateName);
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * method to create rows when user enable the caching
     * which will results in fast subsequent calls as compared to previous
      */
    @AuraEnabled(cacheable=true)
    public static List<SObject> createRowCacheEnabled(String stateJson, String templateName){
        try{
            return createRow(stateJson,templateName);
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    //create ALM Rows
    @TestVisible
    private static List<SObject> createRow(String eventJson, String templateName){
        //convert JSON into the ALM event
        ALMRowCreateEvent eventState = (ALMRowCreateEvent)JSON.deserialize(eventJson, ALMRowCreateEvent.class);
        //if template name is not set by user then pick any one based on object(custom)
        if(String.isBlank(templateName)){
            templateName = getAlmCreateHandler(eventState.headerObjectApiName);
        }
        //convert the handler name to the handler instance
        ALMRowCreateHandler handler = ALMRowTemplateFactory.createTemplate(templateName);

        if(handler == null){
            throw new ALMRowTemplateHelperException(Label.ERR_INVALID_TEMPLATE);
        }
        //call create row to get the response as a list<sObject>
        List<SObject> lines = handler.createRow(eventState);
        //relate parent and child object with relationship name
        for(Sobject line : lines){
            line.put(eventState.parentRelationshipApiName,eventState.headerId);
        }
        return lines;
    }
    //we may have many custom defaults for different objects and those can be added further
    private static String getAlmCreateHandler(String objectApiName){
        if(objectApiName == SobjectType.Account_Payable__c.getName()){
            return 'ALMPayableRowTemplate';
        }else{
            return DEFAULT_TEMPLATE;
        }
    }

    @AuraEnabled(cacheable=true)
    public static SObject updateALMRow(String rowChangeJson, String templateName){
        try{
            return updateRow(rowChangeJson,templateName);
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    //update ALM Row
    @TestVisible
    private static sObject updateRow(String rowChangeJson, String templateName){
        //convert JSON into the ALM event
        ALMRowChangeEvent event = (ALMRowChangeEvent)JSON.deserialize(rowChangeJson, ALMRowChangeEvent.class);

        if(String.isBlank(templateName)){
            templateName = getALMRowChangeHandler(event.headerObjectApiName);
        }
        //convert the handler name to the handler instance
        ALMRowChangeHandler handler = ALMRowTemplateFactory.createRowChangeTemplate(templateName);

        if(handler == null){
            throw new ALMRowTemplateHelperException(Label.ERR_INVALID_TEMPLATE);
        }
        //call update row to get the updated row
        SObject row = handler.updateRow(event);
        
        return row;
    }
    private static String getALMRowChangeHandler(String objectApiName){
        if(objectApiName == SobjectType.Account_Payable__c.getName()){
            return 'ALMPayableRowTemplate';
        }else{
            return '';
        }
    }
}