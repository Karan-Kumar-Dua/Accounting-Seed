public with sharing class FieldSetHelper {
    
    @AuraEnabled(cacheable = true)
    public static FieldSetHandler.FieldSetResponse getColumns(String request){
        FieldSetHandler.FieldSetRequest fsRequest = (FieldSetHandler.FieldSetRequest)JSON.deserialize(request, FieldSetHandler.FieldSetRequest.class);
        FieldSetHandler fsh = new FieldSetHandler(fsRequest);
        return fsh.response;
    }

    @AuraEnabled(cacheable = true)
    public static String getQueryString(String request) {
        FieldSetHandler.FieldSetRequest fsRequest = (FieldSetHandler.FieldSetRequest)JSON.deserialize(request, FieldSetHandler.FieldSetRequest.class);
        FieldSetHandler fsh = new FieldSetHandler(fsRequest);
        return fsh.createQueryString(fsRequest);
    }    
    @AuraEnabled(cacheable = true)
    public static String getCountQueryString(String request) {
        FieldSetHandler.FieldSetRequest fsRequest = (FieldSetHandler.FieldSetRequest)JSON.deserialize(request, FieldSetHandler.FieldSetRequest.class);
        FieldSetHandler fsh = new FieldSetHandler(fsRequest);
        return fsh.getCountQueryString(fsRequest);
    }  
}