public with sharing class UUID {
    public static String getUUID() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        String uuid = h.substring(0, 8) + '-' + h.substring(8, 12) + '-' + h.substring(12, 16) + '-' + h.substring(16, 20) + '-' + h.substring(20);
        return uuid;
    }

    public static List<SObject> generateUUID(List<SObject> newList, String fieldName) {
        Set<String> existingUUIDs = new Set<String>();
        Boolean isRunningBeforeInsert = isRunningInInsertTriggerContext();
        if(isRunningBeforeInsert || Test.isRunningTest()){
            String ExtId;
            Schema.SObjectType sObjectType;
            Set<String> objExtIds = new Set<String>();

            if (!newList.isEmpty()) {
                sObjectType = newList[0].getSObjectType();
            }
            for(SObject obj:newList){
                ExtId = String.valueOf(obj.get(fieldName));
                if (String.isNotBlank(ExtId)) {
                    objExtIds.add(ExtId);
            	}
            }
            for(SObject obj :queryData(sObjectType, fieldName, objExtIds)){
                existingUUIDs.add(String.valueOf(obj.get(fieldName)));
            }
        }
        for (SObject record : newList) {
            String ExtId = String.valueOf(record.get(fieldName));
            if (String.isBlank(ExtId)
                    || (isRunningBeforeInsert && existingUUIDs.contains(ExtId))) {
                record.put(fieldName, getUUID());
            }
        }
        return newList;
    }

    public static Boolean isRunningInInsertTriggerContext(){
        return (Trigger.isExecuting && Trigger.isInsert && Trigger.isBefore);
    }

    private static List<SObject> queryData(Schema.SObjectType objectType, String fieldName, Set<String> objExtIds) {
        String queryCondition = fieldName +' IN :objExtIds';
        SOQLBuilder theQuery = new SOQLBuilder(objectType);
        theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(new List<String>{fieldName})
                .setCondition(queryCondition);

        return (List<SObject>) Database.query(theQuery.toSOQL());
    }
}