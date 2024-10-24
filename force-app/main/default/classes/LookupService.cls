public with sharing class LookupService {

    private String sessionId;

    public class LookupServiceException extends Exception{}

    public LookupService(){
        this(UserInfo.getSessionId());
    }

    public LookupService(String sessionId){
        this.sessionId = String.isNotEmpty(sessionId) ? sessionId.trim() : sessionId;
    }

    private final string lookupResource = '/services/data/v54.0/ui-api/lookups/';

    public List<LookupServiceResult> search(Schema.SObjectType sobjType, Schema.SObjectField sobjField,String searchTerm, String rowData){

        Schema.DescribeFieldResult dfr = sobjField.getDescribe();
        Schema.DescribeSObjectResult dor = sobjType.getDescribe();
        String qualifiedName = dfr.getName() + '.' + dor.getName();

        rowData = String.isEmpty(rowData) ? rowData : rowData.replace('\\"','');
        String resp = this.search(dor.getName(),dfr.getName(),searchTerm,rowData);

        List<String> res = resp.split('"' +dfr.getReferenceTo()+'":', 2);
        Map<String,Object> response = (Map<String,Object>)JSON.deserializeUntyped((res[1].substringBeforeLast('}}')));
        
        List<Object> records = (List<Object>)JSON.deserializeUntyped(JSON.serialize(response.get('records')));
        List<LookupServiceResult> data = new List<LookupServiceResult>();
        for(Object obj : records){
            Map<String,Object> fields = (Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(obj));
            data.add(LookupServiceResult.parse(fields));    
        }
        return data;
    }
    
    public String search(String objName,String fieldName,String searchTerm, String rowData){
        searchTerm = searchTerm == null ? '' : searchTerm;
        rowData = String.isEmpty(rowData) ? '' : rowData.replaceAll(' ', '+');
        rowData = rowData.startsWith('&') ? rowData.substringAfter('&') : 'dependentFieldBindings=' + rowData;
        String endpoint = this.lookupResource + objName + '/' + fieldName + '?'+
            rowData + '&pageSize=5&q='+EncodingUtil.urlEncode(searchTerm, 'UTF-8');
        HttpRequest req = this.getRequest(endpoint);
        Http http = new Http();
        HttpResponse resp = http.send(req);
        
        // expect 200 OK for GET request
        if (resp.getStatusCode() != 200) {
            Integer code = resp.getStatusCode();
            String status = resp.getStatus();
            String body = resp.getBody();
            throw new LookupServiceException(Label.ERR_LOOKUP_CALLOUT_NOT_OK + ' ' + code + ' ' + status + ' ' + body);
        }

        return resp.getBody();
    }

    private HttpRequest getRequest(string endpoint){
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization', 'Bearer ' + this.sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + endpoint);
        req.setMethod('GET');
        return req;
    }
}