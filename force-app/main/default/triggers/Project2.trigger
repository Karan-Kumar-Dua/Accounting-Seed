trigger Project2 on Project__c (before delete) {

    if (Trigger.isBefore && Trigger.isDelete) {
        Project2Actions.preventDeleteIfRelatedRecordsExist(Trigger.oldMap);
    }

}