public with sharing class PurgeDataHelper {  

    @TestVisible
    private static final String MESSAGE_BATCH_RUNNING_SUCCESS = Label.INF_BATCH_RUNNING_SUCCESS;
    @TestVisible
    private static final String MESSAGE_JOB_IS_RUNNING = Label.INF_JOB_IS_RUNNING;
    @TestVisible
    private static final String MESSAGE_REQUIRED_INPUT = Label.INF_REQUIRED_INPUT;
    @TestVisible
    private static final String MESSAGE_ERP_REQUIRED = Label.INF_ERP_REQUIRED;
    @TestVisible
    private static final String INVENTORY_BALANCE_HISTORY_SOBJECT_NAME = GlobalVariables.ERPPACKAGE_QUALIFIER + 'Inventory_Balance_History__c';
    private static final Integer BATCH_CHUNK_SIZE = 10;

    @TestVisible
    private static final Set<String> processingStatuses = new Set<String>{
        'Holding',
        'Queued',
        'Preparing',
        'Processing'
    };

    public with sharing class PurgeDataHelperException extends Exception {}

    @AuraEnabled
    public static String purgeAPAgingHistory(Id period){
        try {
            if (period == null) {
                throw new PurgeDataHelperException(
                    String.format(MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_PERIOD }));
            }
            if (isJobRunning(PurgeAPAgingHistoryBatch.class)) {
                throw new PurgeDataHelperException(MESSAGE_JOB_IS_RUNNING);
            }

            PurgeAPAgingHistoryBatch batch = new PurgeAPAgingHistoryBatch(period);
            Database.executeBatch(batch);

            return getSuccessMessage(AP_Aging_History__c.getsObjectType());
        }
        catch (PurgeDataHelperException e) {
            throw e;
        }
        catch (Exception e) {
            throw new PurgeDataHelperException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String purgeBillingAgingHistory(Id period){
        try {
            if (period == null) {
                throw new PurgeDataHelperException(
                    String.format(MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_PERIOD }));
            }
            if (isJobRunning(PurgeBillingAgingHistoryBatch.class)) {
                throw new PurgeDataHelperException(MESSAGE_JOB_IS_RUNNING);
            }

            PurgeBillingAgingHistoryBatch batch = new PurgeBillingAgingHistoryBatch(period);
            Database.executeBatch(batch);

            return getSuccessMessage(Billing_Aging_History__c.getsObjectType());
        }
        catch (PurgeDataHelperException e) {
            throw e;
        }
        catch (Exception e) {
            throw new PurgeDataHelperException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String purgeFinancialReportResults(){
        try {
            if (isJobRunning(PurgeFinancialReportResultBatch.class)) {
                throw new PurgeDataHelperException(MESSAGE_JOB_IS_RUNNING);
            }

            PurgeFinancialReportResultBatch batch = new PurgeFinancialReportResultBatch();
            Database.executeBatch(batch, BATCH_CHUNK_SIZE);

            return getSuccessMessage(Financial_Report_Result__c.getsObjectType());
        }
        catch (PurgeDataHelperException e) {
            throw e;
        }
        catch (Exception e) {
            throw new PurgeDataHelperException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String purgeZeroBalanceFinancialCubes(){
        try {
            if (isJobRunning(PurgeZeroBalanceFinancialCubesBatch.class)) {
                throw new PurgeDataHelperException(MESSAGE_JOB_IS_RUNNING);
            }
            
            PurgeZeroBalanceFinancialCubesBatch batch = new PurgeZeroBalanceFinancialCubesBatch();
            Database.executeBatch(batch);

            return getSuccessMessage(Financial_Cube__c.getsObjectType());
        }
        catch (PurgeDataHelperException e) {
            throw e;
        }
        catch (Exception e) {
            throw new PurgeDataHelperException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String purgeSourceDocumentsInInterimPostingStatus() {
        try {
            if (isJobRunning(PurgeSourceDocumentsLDVBatch.class)) {
                throw new PurgeDataHelperException(MESSAGE_JOB_IS_RUNNING);
            }

            PurgeSourceDocumentsLDVBatch batch = new PurgeSourceDocumentsLDVBatch();
            Database.executeBatch(batch);

            return String.format(Label.INF_RESET_LDO_SD_BATCH_RUNNING_SUCCESS, new String[]{ UserInfo.getUserEmail() });
        }
        catch (PurgeDataHelperException e) {
            throw e;
        }
        catch (Exception e) {
            throw new PurgeDataHelperException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String purgeAutomatedJobResults(Date before){
        try {
            if (before == null) {
                throw new PurgeDataHelperException(
                        String.format(MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_BEFORE }));
            }
            if (isJobRunning(PurgeAutomatedJodResultsBatch.class)) {
                throw new PurgeDataHelperException(MESSAGE_JOB_IS_RUNNING);
            }
    
            PurgeAutomatedJodResultsBatch batch = new PurgeAutomatedJodResultsBatch(before);
            Database.executeBatch(batch);
    
            return getSuccessMessage(Automated_Job_Results__c.getsObjectType());
        }
        catch (PurgeDataHelperException e) {
            throw e;
        }
        catch (Exception e) {
            throw new PurgeDataHelperException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String purgeInventoryBalanceHistory(Date before){
        try {
            if (!AccountingSettingsHandler.isERPEnabled()) {
                throw new PurgeDataHelperException(MESSAGE_ERP_REQUIRED);
            }
            if (before == null) {
                throw new PurgeDataHelperException(
                        String.format(MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_BEFORE }));
            }
            if (isJobRunning(PurgeInventoryBalanceHistoryBatch.class)) {
                throw new PurgeDataHelperException(MESSAGE_JOB_IS_RUNNING);
            }
    
            PurgeInventoryBalanceHistoryBatch batch = new PurgeInventoryBalanceHistoryBatch(before);
            Database.executeBatch(batch);

            SObjectType sObjType = ((SObject) Type.forName(INVENTORY_BALANCE_HISTORY_SOBJECT_NAME).newInstance()).getSObjectType();
            return getSuccessMessage(sObjType);
        }
        catch (PurgeDataHelperException e) {
            throw e;
        }
        catch (Exception e) {
            //throw new PurgeDataHelperException(e.getMessage());
            throw new PurgeDataHelperException(e.getStackTraceString());
        }
    }

    private static String getSuccessMessage(Schema.SObjectType purgedObjectType) {
        String label = purgedObjectType.getDescribe().getLabel();
        return getSuccessMessage(label);
    }

    private static String getSuccessMessage(String customMsg) {
        String userEmail = UserInfo.getUserEmail();
        return String.format(MESSAGE_BATCH_RUNNING_SUCCESS, new String[]{ customMsg, userEmail });
    }

    // Gets the non-namespaced classname for the given type.
    private static String getClassName(Type t) {
        // 'namespace.classnamne'
        String fullyQualifiedName = t.getName();
        // ['namespace', 'classname']
        List<String> nameParts = fullyQualifiedName.split('\\.');
        // 'classname'
        return nameParts[nameParts.size() - 1];
    }

    // retrieves the ApexClass Id for the given type.
    private static Set<Id> getApexClassId(Type t) {
        Set<String> classNames = new Set<String>{ getClassName(t) };
        Map<Id, ApexClass> apexClasses = new Map<Id, ApexClass>(
            DomainUtils.getApexClassesByName(classNames)
        );
        return apexClasses.keySet();
    }

    // true if an async apex job of the given type is in process
    public static Boolean isJobRunning(Type t) {
        Set<Id> apexClassIds = getApexClassId(t);
        List<AsyncApexJob> asyncApexJobs = 
            DomainUtils.getAsyncApexJobByApexClassIdAndStatus(apexClassIds, processingStatuses);
        return asyncApexJobs != null && !asyncApexJobs.isEmpty();
    }

}