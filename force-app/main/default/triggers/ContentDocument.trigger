trigger ContentDocument on ContentDocument (before delete) {
    if(Trigger.isBefore && Trigger.isDelete){
        ContentDocumentActions.beforeDeleteHandler(Trigger.oldMap);
    }
}