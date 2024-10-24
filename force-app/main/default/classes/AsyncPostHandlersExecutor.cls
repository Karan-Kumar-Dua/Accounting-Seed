public with sharing class AsyncPostHandlersExecutor implements Queueable, Database.AllowsCallouts {

    private AbstractPostHandler postHandler;
    private List<SObject> sourceRecords;

    public AsyncPostHandlersExecutor(List<SObject> sourceRecords, AbstractPostHandler postHandler) {
        this.sourceRecords = sourceRecords;
        this.postHandler = postHandler;
    }

    public void execute(QueueableContext context) {
        try {
            //execute post handler
            List<PostResult> postResults = postHandler.post(sourceRecords);
            //Check posting results and build activities for all failed results
            List<Task> postErrorActivities = new List<Task>();
            for (PostResult result : postResults) {
                if (!result.isSuccess) {
                    postErrorActivities.add(
                        FinancialSuiteUtils.setTask(
                            result.id,
                            Label.COMMON_ERR_CANNOT_POST_RECORD,
                            !result.errors.isEmpty() ? result.errors.get(0).message : NULL
                        )
                    );
                }
            }
            //insert Activities
            if (!postErrorActivities.isEmpty()) {
                SFDCSecurityUtils.insertProxy(postErrorActivities);
            }
        }
        catch (Exception ex) {
            //silently catch all possible unhandled exceptions
        }
    }

}