public class RerunPaymentProcessingJEHelper {
    // this will run the batch job from lwc component 
    @AuraEnabled
    public static void runBatchJob(){
        RerunPaymentProcessingJEHelper.runCreateJRJob();
    }
    private static void runCreateJRJob(){
        try {
            //salesforce limit 
            //a test menthod can not have more than one bach chaining
            //not executing bacth when called in test context
            if(!Test.isRunningTest()){
                AutomatedJobsHelper.run(Label.JOB_JOURNAL_ENTRIES,null);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}