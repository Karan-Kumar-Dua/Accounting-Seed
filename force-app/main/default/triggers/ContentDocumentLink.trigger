trigger ContentDocumentLink on ContentDocumentLink (after insert) {
    if(Trigger.isAfter && Trigger.isInsert){
        ContentDocumentLinkActions.afterInsertHandler(Trigger.new);
    }
}