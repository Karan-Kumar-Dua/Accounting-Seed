public with sharing class SourceDocumentCloneQueue implements Queueable {

    private SourceDocumentCloneBatch cloneBatch;

    public SourceDocumentCloneQueue(SourceDocumentCloneBatch cloneBatch) {
        this.cloneBatch = cloneBatch;
    }
    public void execute(QueueableContext context) {
        Database.executeBatch(cloneBatch, 200);
    }
}