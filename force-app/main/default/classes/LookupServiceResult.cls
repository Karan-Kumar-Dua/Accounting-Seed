public class LookupServiceResult {
    
    public Map<String,Object> records;

    public LookupServiceResult(Map<String,Object> records){
        this.records = records;
    }
    public String getValue(String key){
        Map<String,Object> result = (Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(records.get(key)));
        return String.valueOf(result.get('value'));
    }
    public static LookupServiceResult parse(Map<String,Object> response) {
        return new LookupServiceResult((Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(response.get('fields'))));
    }
}