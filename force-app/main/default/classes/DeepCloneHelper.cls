public with sharing class DeepCloneHelper{
        
    @AuraEnabled(cacheable = true)
    public static DeepCloneInfo getDeepCloneInfo(Id recId){
        try{
            DeepCloneInfo dci = new DeepCloneInfo(recId);
            return dci;
        } catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id cloneObjectAndLines(Id recId, String record){
        try{
            SObject sObj = (SObject)JSON.deserialize(record, SObject.class);
            Map<String,Object> fieldMap = sObj.getPopulatedFieldsAsMap();
            DeepCloneInfo dci = new DeepCloneInfo(recId, fieldMap);
            return dci.clonedObjectId;
        } catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    public with sharing class DeepCloneInfo{
        @AuraEnabled
        public Date currentDate;
        @AuraEnabled
        public String currentObjectName;
        @AuraEnabled
        public List<String> fieldNames;
        public Id clonedObjectId;
        
        public DeepCloneInfo(Id recId){
            currentObjectName = recId.getSObjectType().getDescribe().getName();
            fieldNames = AbstractDeepClone.getInstance(recId).getFields();
            currentDate = Date.today();
        }

        public DeepCloneInfo(Id recId, Map<String, Object> fieldMap){
            AbstractDeepClone dci = AbstractDeepClone.getInstance(recId);
            clonedObjectId = dci.clone(recId, fieldMap);
        }        
    }
}