public with sharing class BatchJobUtils {
    private static final String STATUS_APEX_JOB_HOLDING = 'Holding';
    private static final String STATUS_APEX_JOB_QUEUED = 'Queued';
    private static final String STATUS_APEX_JOB_PREPARING = 'Preparing';
    private static final String STATUS_APEX_JOB_PROCESSING = 'Processing';
    
    private static final Set<String> processingStatuses = new Set<String>{
        STATUS_APEX_JOB_HOLDING,
        STATUS_APEX_JOB_QUEUED,
        STATUS_APEX_JOB_PREPARING,
        STATUS_APEX_JOB_PROCESSING
    };


    public static Boolean checkJobRunning(Set<String> jobNames) {
        //=============================================================
        // This is a system object. No need to check user access to it.
        //=============================================================
        Boolean jobRunning = false;
        Map<Id, ApexClass> apexClasses = new Map<Id, ApexClass>(
            DomainUtils.getApexClassesByName(jobNames)
        );

        List<AsyncApexJob> asyncApexJobs = DomainUtils.getAsyncApexJobByApexClassIdAndStatus(
            apexClasses.keySet(), processingStatuses
        );

        if (asyncApexJobs != NULL && !asyncApexJobs.isEmpty()) {
            jobRunning = true;
        } else {
            jobRunning = false;
        }
        return jobRunning;
    }
}