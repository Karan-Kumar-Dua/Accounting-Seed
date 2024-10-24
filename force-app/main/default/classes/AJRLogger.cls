/**
 * Common AJR logging functionality.
 * AJRs and tasks are created by most batch jobs and scheduled 
 * processes. Historically each batch job has implemented its own
 * logging functionality. This class provides a common logger based
 * on the patterns found in existing batch jobs.
 */
public with sharing class AJRLogger {
    
    private static final String DEFAULT_TASK_PRIORITY = 'Normal';
    private static final String DEFAULT_TASK_STATUS = 'Completed';

    private Config config;
    private Automated_Job_Results__c ajr;
    private Set<Id> successfulWhatIds;
    private Map<Id,Id> taskIdsByWhatId;
    private Map<Id,Task> insertsByWhatId = new Map<Id,Task>();
    private Map<Id,Task> updatesByWhatId = new Map<Id,Task>();

    /**
     * Configuration options for the logger.
     * jobName: required - the name of the job being logged. 
     *          this will show up in the email subject and AJR Job Type field.
     * reportName: required - the name of the report to link to in the AJR.
     * taskOptions: optional - customization of the tasks created for errors.
     */
    public with sharing class Config {
        public String jobName;
        public String reportName;
        public TaskOptions taskOptions;
    }

    /**
     * Options for customizing the tasks created by the logger
     * to record any errors.
     */
    public with sharing class TaskOptions {
        public Id ownerId;
        public String status;
        public String priority;
        public String subject;
    }

    public with sharing class AJRLoggerException extends Exception {}

    /**
     * allows passing additional configuration options to override the default task and email builders
     */
    public AJRLogger(Config config) {
        // validate input
        if (config == null) {
            throw new AJRLoggerException(String.format(Label.ERR_REQUIRED_INPUT_EXCEPTION, new List<String>{'config'}));
        }
        if (String.isEmpty(config.jobName)) {
            throw new AJRLoggerException(String.format(Label.ERR_REQUIRED_INPUT_EXCEPTION, new List<String>{'config.jobName'}));
        }
        if (String.isEmpty(config.reportName)) {
            throw new AJRLoggerException(String.format(Label.ERR_REQUIRED_INPUT_EXCEPTION, new List<String>{'config.reportName'}));
        }

        // intialize the logger
        this.ajr = new Automated_Job_Results__c(
            Processed__c = 0,
            Failed__c = 0,
            Succeeded__c = 0,
            Schedule_Job_Type__c = config.jobName,
            Notes__c = AutomatedJobResultsHandler.getReportLink(config.reportName)
        );
        this.taskIdsByWhatId = new Map<Id,Id>();
        this.successfulWhatIds = new Set<Id>();
        config.taskOptions = getTaskOptionDefaults(config.taskOptions);
        this.config = config;
    }

    /**
     * Get the number of logged successes.
     */
    public Integer getSuccessCount() {
        return Integer.valueOf(ajr.Succeeded__c);
    }

    /**
     * Get the number logged failures.
     */
    public Integer getFailureCount() {
        return Integer.valueOf(ajr.Failed__c);
    }

    /**
     * Get the number of logged events.
     */
    public Integer getProcessedCount() {
        return Integer.valueOf(ajr.Processed__c);
    }

    /**
     * Log a success message for the given whatId.
     * This will not be saved in the DB until the `save()` method is called.
     */
    public void logSuccess(Id whatId) {
        if (!taskIdsByWhatId.containsKey(whatId) && !successfulWhatIds.contains(whatId)) { 
            // Increment AJR counts, no double counting
            ajr.Processed__c++;
            ajr.Succeeded__c++;
            successfulWhatIds.add(whatId);
        }
    }

    /**
     * Log an error message for the given whatId.
     * This will not be saved in the DB until the `save()` method is called.
     */
    public void logError(Id whatId, String message) {
        if (!taskIdsByWhatId.containsKey(whatId)) {
            // no task created yet for this whatId
            // increment AJR counts
            if (successfulWhatIds.contains(whatId)) {
                // previously marked as succeeded, convert to failed
                ajr.Processed__c--; // decrement processed count to cancel out increment below
                ajr.Succeeded__c--; // decrement succeeded count
                successfulWhatIds.remove(whatId);
            }
            ajr.Processed__c++;
            ajr.Failed__c++;
            // create new task
            insertsByWhatId.put(whatId, getTask(whatId, message));
            trimDescription(insertsByWhatId.get(whatId)); // trim here rather than in write method to avoid building large strings in memory
            // record task created
            taskIdsByWhatId.put(whatId, null);
        } else {
            // AJR counts already incremented for this task, just append the error message to the task
            if (insertsByWhatId.containsKey(whatId)) {
                // task found in inserts map
                insertsByWhatId.get(whatId).Description += '\n' + message;
                trimDescription(insertsByWhatId.get(whatId)); // trim here rather than in write method to avoid building large strings in memory
            } else if (updatesByWhatId.containsKey(whatId)) {
                // task found in updates map
                updatesByWhatId.get(whatId).Description += '\n' + message;
                trimDescription(updatesByWhatId.get(whatId)); // trim here rather than in write method to avoid building large strings in memory
            } else {
                // task needs to be added to updates map
                updatesByWhatId.put(whatId, new Task(Id = taskIdsByWhatId.get(whatId), Description = message));
                trimDescription(updatesByWhatId.get(whatId)); // trim here rather than in write method to avoid building large strings in memory
            }
        }
    }

    /**
     * Save the Automated Job Result record and any tasks that have been created.
     */
    public void save() {
        // save AJR
        SFDCSecurityUtils.upsertProxy(ajr);

        // insert tasks
        if (!insertsByWhatId.isEmpty()) {
            // update task ajr lookup
            for (Task t : insertsByWhatId.values()) {
                t.Automated_Job_Result__c = ajr.Id;
            }
            // save
            SFDCSecurityUtils.insertProxy(insertsByWhatId.values());
            // update taskIdsByWhatId with new task ids
            for (Task t : insertsByWhatId.values()) {
                taskIdsByWhatId.put(t.WhatId, t.Id);
            }
            insertsByWhatId = new Map<Id,Task>();
        }

        // update tasks
        if (!updatesByWhatId.isEmpty()) {
            // collect task ids
            Set<Id> taskIds = new Set<Id>();
            for (Task t : updatesByWhatId.values()) {
                taskIds.add(t.Id);
            }
            // query existing tasks
            for (Task t : DomainUtils.getTasksByIds(taskIds)) {
                // update task comment
                updatesByWhatId.get(t.WhatId).Description = t.Description + '\n' + updatesByWhatId.get(t.WhatId).Description;
            } 
            // save
            SFDCSecurityUtils.updateProxy(updatesByWhatId.values());
            updatesByWhatId = new Map<Id,Task>();
        }
    }

    /**
     * Send default email.
     * If email confirmations are disabled, no emails will be sent.
     */
    public Messaging.SendEmailResult[] sendEmail() {
        return sendEmail(new List<String>{ UserInfo.getUserEmail() });
    }

    /**
     * Send default email to specified address.
     * If email confirmations are disabled, no emails will be sent.
     */
    public Messaging.SendEmailResult[] sendEmail(String[] toAddresses) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName(Label.ACCOUNTING_SEED_COMPANY_NAME);
        mail.setSubject(String.format(Label.INF_AJR_LOGGER_EMAIL_SUBJECT, new List<String>{config.jobName}));
        mail.setPlainTextBody(String.format(Label.INF_AJR_LOGGER_EMAIL_BODY, new List<String>{'\n', config.jobName, String.valueOf(ajr.Processed__c), String.valueOf(ajr.Succeeded__c), String.valueOf(ajr.Failed__c)}));
        return sendEmail(new List<Messaging.Email>{ mail });
    }

    /**
     * Send the provided email.
     * If email confirmations are disabled, no emails will be sent.
     */
    public Messaging.SendEmailResult[] sendEmail(Messaging.Email[] mail) {
        if (AccountingSettingsHandler.isEmailConfirmationsDisabled() || !FinancialSuiteUtils.canSendEmail() || Test.isRunningTest()) {
            return new Messaging.SendEmailResult[]{};
        }
        return Messaging.sendEmail(mail, false);
    }

    // trim task description to fit within 32k character limit
    private void trimDescription(Task t) {
        if (t.Description != null && t.Description.length() > 32000) {
            t.Description = t.Description.substring(0, 32000);
        }
    }

    // creates a new task with the given whatId and description
    private Task getTask(Id whatId, String description) {
        return new Task(
            ActivityDate = System.today(),
            WhatId = whatId, 
            Description = description,
            OwnerId = config.taskOptions.ownerId, 
            Status = config.taskOptions.status,
            Priority = config.taskOptions.priority,
            Subject = config.taskOptions.subject
        );
    }

    // the default task options if none are provided in the constructor
    private static TaskOptions getTaskOptionDefaults(TaskOptions opts) {
        opts = opts ?? new TaskOptions();
        opts.ownerId = opts.ownerId ?? UserInfo.getUserId();
        opts.status = opts.status ?? DEFAULT_TASK_STATUS;
        opts.priority = opts.priority ?? DEFAULT_TASK_PRIORITY;
        opts.subject = opts.subject ?? Label.COMMON_ERROR_TEXT;
        return opts;
    }

}