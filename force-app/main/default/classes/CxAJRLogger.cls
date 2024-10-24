public with sharing class CxAJRLogger {

    private static final String JOB_NAME_FOR_REPORT_LOOKUP = 'Merchant Download Job';
    private Automated_Job_Results__c ajr;
    private Set<Id> successfulWhatIds;
    private Map<Id,Id> taskIdsByWhatId;
    private Map<Id,Task> insertsByWhatId = new Map<Id,Task>();
    private Map<Id,Task> updatesByWhatId = new Map<Id,Task>();

    public with sharing class Config {
        public Id ajr;
        public Set<Id> successfulWhatIds;
        public Map<Id,Id> taskIdsByWhatId;
    }

    public CxAJRLogger() {
        this.ajr = new Automated_Job_Results__c(
            Processed__c=0,
            Failed__c=0,
            Succeeded__c=0,
            Schedule_Job_Type__c=Label.JOB_JOURNAL_ENTRIES,
            Notes__c = AutomatedJobResultsHandler.getReportLink(JOB_NAME_FOR_REPORT_LOOKUP)
        );
        this.taskIdsByWhatId = new Map<Id,Id>();
        this.successfulWhatIds = new Set<Id>();
    }

    // restore logger state using previously exported config.
    public CxAJRLogger(Config conf) {
        if (conf == null) {
            this();
        } else {
            this.ajr = DomainUtils.getAutomatedJobResultsById(conf.ajr);
            this.taskIdsByWhatId = conf.taskIdsByWhatId;
            this.successfulWhatIds = conf.successfulWhatIds;
        }
    }

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
            insertsByWhatId.put(whatId, new Task(WhatId = whatId, Subject = Label.ERR_MERCHANT_DOWNLOAD_TASK_SUBJECT, Description = message));
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
                updatesByWhatId.put(whatId, new Task(Id = taskIdsByWhatId.get(whatId), Subject = Label.ERR_MERCHANT_DOWNLOAD_TASK_SUBJECT, Description = message));
                trimDescription(updatesByWhatId.get(whatId)); // trim here rather than in write method to avoid building large strings in memory
            }
        }
    }

    public void logSuccess(Id whatId) {
        if (!taskIdsByWhatId.containsKey(whatId) && !successfulWhatIds.contains(whatId)) { 
            // Increment AJR counts, no double counting
            ajr.Processed__c++;
            ajr.Succeeded__c++;
            successfulWhatIds.add(whatId);
        }
    }

    public void write() {
        // save AJR
        SFDCSecurityUtils.upsertProxy(ajr);

        // insert tasks
        if (!insertsByWhatId.isEmpty()) {
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

    public void sendEmail() {
        if (!AccountingSettingsHandler.isEmailConfirmationsDisabled() && !Test.isRunningTest() && FinancialSuiteUtils.canSendEmail()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>{UserInfo.getUserEmail()};
            mail.setToAddresses(toAddresses);
            mail.setSenderDisplayName(Label.ACCOUNTING_SEED_COMPANY_NAME);
            mail.setSubject(Label.INF_CS_SETTLER_JOB_SUBJECT);
            mail.setPlainTextBody(String.format(Label.INF_CS_SETTLER_JOB_BODY, new List<String>{'\n', String.valueOf(ajr.Processed__c), String.valueOf(ajr.Succeeded__c), String.valueOf(ajr.Failed__c)}));
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        }
    }

    public Config getConfig() {
        Config conf = new Config();
        conf.ajr = ajr.Id;
        conf.successfulWhatIds = successfulWhatIds;
        conf.taskIdsByWhatId = new Map<Id,Id>();
        for (Id whatId : taskIdsByWhatId.keySet() ) {
            if (taskIdsByWhatId.get(whatId) != null) {
                conf.taskIdsByWhatId.put(whatId, taskIdsByWhatId.get(whatId));
            }
        }
        return conf;
    }

    // trim task description to fit within 32k character limit
    private void trimDescription(Task t) {
        if (t.Description != null && t.Description.length() > 32000) {
            t.Description = t.Description.substring(0, 32000);
        }
    }
}