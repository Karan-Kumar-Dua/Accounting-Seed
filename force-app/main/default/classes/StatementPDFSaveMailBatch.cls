public with sharing class StatementPDFSaveMailBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    @TestVisible
    private List<Id> sourceRecordIds;
    @TestVisible
    private Boolean isMailing;
    @TestVisible
    private Map<Id, AbstractStatementManager.StatementResult> statementResults;
    @TestVisible
    private Integer sourceRecordSize;
    @TestVisible
    private String reportMessage;
    @TestVisible
    private AbstractStatementManager.StatementBase stBase;
    @TestVisible
    private String baseUrl;
    @TestVisible
    private Map<Id, Id> sourceRecordIdToLedgerId;
    @TestVisible
    private Map<Id, String> sourceRecordIdToCurrencyIsoCode;
    private static String billingJobName = 'Automated Email Billing Job';
    @TestVisible
    private Map<String, String> customUrlParams;
    @TestVisible
    private AbstractStatementManager.StatementType statementType;


    public StatementPDFSaveMailBatch(   List<Id> sourceRecordIds,
                                        Boolean isMailPDFs,
                                        String baseUrl,
                                        AbstractStatementManager.StatementBase stBase) {

        this(sourceRecordIds, NULL, NULL, isMailPDFs, baseUrl, stBase, NULL);
    }

    public StatementPDFSaveMailBatch( List<Id> sourceRecordIds,
                                      Map<Id, Id> sourceRecordIdToLedgerId,
                                      Map<Id, String> sourceRecordIdToCurrencyIsoCode,
                                      Boolean isMailPDFs,
                                      String baseUrl,
                                      AbstractStatementManager.StatementBase stBase,
                                      AbstractStatementManager.StatementType statementType ) {

        this.sourceRecordIds = sourceRecordIds;
        this.sourceRecordIdToLedgerId = sourceRecordIdToLedgerId;
        this.sourceRecordIdToCurrencyIsoCode = sourceRecordIdToCurrencyIsoCode;
        this.isMailing = isMailPDFs;
        this.stBase = stBase;
        this.baseUrl = baseUrl;
        this.customUrlParams = customUrlParams;
        this.statementType = statementType;
    }

    public StatementPDFSaveMailBatch setCustomUrlParams(Map<String, String> customUrlParams) {
        this.customUrlParams = customUrlParams;
        return this;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        sourceRecordSize = 0;
        statementResults = new Map<Id, AbstractStatementManager.StatementResult>();

        String query;
        if (stBase == AbstractStatementManager.StatementBase.CUSTOMER) {
            query = 'SELECT Id, Name, ' +
                            PACKAGE_QUALIFIER + 'Statement_Needed__c, ' +
                            PACKAGE_QUALIFIER + 'Last_Statement_Sent__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__r.FirstName, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__r.LastName, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__r.Email, ' +
                            PACKAGE_QUALIFIER + 'Outstanding_Statement_Format__c, ' +
                            PACKAGE_QUALIFIER + 'Outstanding_Statement_Format__r.Visualforce_PDF_Page__c, ' +
                            PACKAGE_QUALIFIER + 'Outstanding_Statement_Format__r.ReplyTo_Email__c, ' +
                            PACKAGE_QUALIFIER + 'Outstanding_Statement_Format__r.Default_Email_Template__c, ' +
                            PACKAGE_QUALIFIER + 'Outstanding_Statement_Format__r.Org_Wide_Email_Address__c, ' +
                            PACKAGE_QUALIFIER + 'Activity_Statement_Format__c, ' +
                            PACKAGE_QUALIFIER + 'Activity_Statement_Format__r.Visualforce_PDF_Page__c, ' +
                            PACKAGE_QUALIFIER + 'Activity_Statement_Format__r.ReplyTo_Email__c, ' +
                            PACKAGE_QUALIFIER + 'Activity_Statement_Format__r.Default_Email_Template__c, ' +
                            PACKAGE_QUALIFIER + 'Activity_Statement_Format__r.Org_Wide_Email_Address__c ' +
                    'FROM Account ' +
                    'WHERE Id IN :genericIdSet ' +
                    'LIMIT 10000';
        }
        else if (stBase == AbstractStatementManager.StatementBase.BILLING) {
            query = 'SELECT Id, Name, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__r.FirstName, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__r.LastName, ' +
                            PACKAGE_QUALIFIER + 'Billing_Contact__r.Email, ' +
                            PACKAGE_QUALIFIER + 'Billing_Format__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Format__r.' + PACKAGE_QUALIFIER + 'Default_Email_Template__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Format__r.' + PACKAGE_QUALIFIER + 'ReplyTo_Email__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Format__r.' + PACKAGE_QUALIFIER + 'Visualforce_PDF_Page__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Format__r.' + PACKAGE_QUALIFIER + 'Org_Wide_Email_Address__c, ' +
                            PACKAGE_QUALIFIER + 'Billing_Format__r.' + PACKAGE_QUALIFIER + 'Sort_Field__c, ' +
                            PACKAGE_QUALIFIER + 'Date__c, ' +
                            PACKAGE_QUALIFIER + 'Customer__c, ' +
                            PACKAGE_QUALIFIER + 'Customer__r.Name, ' +
                            PACKAGE_QUALIFIER + 'Proprietary_Billing_Number__c ' +
                    'FROM ' + PACKAGE_QUALIFIER + 'Billing__c ' +
                    'WHERE Id IN :genericIdSet';
        }

        return DomainUtils.getQueryLocator(query, new Set<Id>(sourceRecordIds));
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        AbstractStatementManager.StatementSet statementHandler;
        if (stBase == AbstractStatementManager.StatementBase.CUSTOMER) {
            statementHandler = new AbstractStatementManager.StatementSet(
                (List<Account>) scope,
                sourceRecordIdToLedgerId,
                sourceRecordIdToCurrencyIsoCode,
                statementType,
                baseUrl,
                this.customUrlParams
            );
        }
        else if (stBase == AbstractStatementManager.StatementBase.BILLING) {
            statementHandler = new AbstractStatementManager.StatementSet(
                (List<Billing__c>) scope,
                AbstractStatementManager.StatementType.BILLING,
                baseUrl
            );
        }
        //set CC addresses
        setCCAddresses(statementHandler);
        sourceRecordSize += scope.size();
        statementResults.putAll(statementHandler.savePDFs(isMailing));
    }

    public void finish(Database.BatchableContext BC) {
        AutomatedJobResultsHandler.setJobType(billingJobName);
        AutomatedJobResultsHandler.setProcessed(sourceRecordSize);

        //Report formation
        Integer countUnsentRecords = 0;
        for (AbstractStatementManager.StatementResult stResult : statementResults.values()) {
            if (!stResult.isSuccess) {
                countUnsentRecords++;
            }
        }

        Integer countSentRecords = sourceRecordSize - countUnsentRecords;
        AutomatedJobResultsHandler.setSucceeded(countSentRecords);
        AutomatedJobResultsHandler.setFailed(countUnsentRecords);
        reportMessage = AbstractStatementManager.REPORT_TEMPLATE
            .replace(
                AbstractStatementManager.REPORT_NMB_SUBM,
                String.valueOf(sourceRecordSize)
            )
            .replace(
                AbstractStatementManager.REPORT_NMB_SENT,
                String.valueOf(countSentRecords)
            )
            .replace(
                AbstractStatementManager.REPORT_NMB_UNSENT,
                String.valueOf(countUnsentRecords)
        );

        //if this is for Billings, use the Billings report template instead
        if (stBase == AbstractStatementManager.StatementBase.BILLING) {
            reportMessage = AbstractStatementManager.BILLINGS_REPORT_TEMPLATE
                .replace(
                    AbstractStatementManager.REPORT_NMB_SUBM,
                    String.valueOf(sourceRecordSize)
                )
                .replace(
                    AbstractStatementManager.REPORT_NMB_SENT,
                    String.valueOf(countSentRecords)
                )
                .replace(
                    AbstractStatementManager.REPORT_NMB_UNSENT,
                    String.valueOf(countUnsentRecords)
            );

            if (AutomatedJobResultsHandler.isReportExist(billingJobName) && countUnsentRecords > 0){
                reportMessage += '\r\n' + AutomatedJobResultsHandler.getReportLink(billingJobName);
            }
            AutomatedJobResultsHandler.setError(AutomatedJobResultsHandler.getReportLink(billingJobName));
        }

        if (countUnsentRecords > 0) {
            Set<Id> recordsIds = new Set<Id>();
            for (AbstractStatementManager.StatementResult statementResult: statementResults.values()) {
                recordsIds.add(statementResult.sourceId);
            }

            Map<Id, SObject> objectsByIds = new Map<Id, SObject>();

            if (stBase == AbstractStatementManager.StatementBase.BILLING) {
                objectsByIds = new Map<Id, Billing__c>(DomainUtils.getBillingsById(recordsIds));
            }
            else {
                objectsByIds = new Map<Id, Account>(DomainUtils.getAccountsById(recordsIds));
            }

            List<Task> tasks = new List<Task>();
            for (Id curId : statementResults.keySet()) {
                AbstractStatementManager.StatementResult stResult = statementResults.get(curId);
                if (!stResult.isSuccess) {
                    if (objectsByIds.containsKey(stResult.sourceId)) {
                        tasks.add(createTask(stResult, objectsByIds));
                    }
                }
            }
            SFDCSecurityUtils.insertProxy(tasks);
        }
        AutomatedJobResultsHandler.saveAutomatedJobResults();

        if (isMailing) {
            if (!AccountingSettingsHandler.isEmailConfirmationsDisabled()) {
                //Get info about Async Job
                AsyncApexJob job = DomainUtils.getAsyncApexJobById(new Set<Id>{bc.getJobId()})[0];

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(job.CreatedById);
                mail.setSaveAsActivity(false);
                mail.setSubject(getSubject());
                mail.setPlainTextBody(reportMessage);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            }
        }
    }

    @TestVisible
    private String getSubject() {
        String baseType = stBase == AbstractStatementManager.StatementBase.BILLING ? AbstractStatementManager.BILLINGS : AbstractStatementManager.STATEMENTS;
        return String.format(AbstractStatementManager.REPORT_SUBJECT, new List<String> {baseType});
    }

    private Task createTask(AbstractStatementManager.StatementResult stResult, Map<Id, SObject> objectsByIds) {
        Task task = new Task();
        task.WhatId = stResult.sourceId;
        task.WhoId = (String) objectsByIds.get(stResult.sourceId).get(PACKAGE_QUALIFIER + 'Billing_Contact__c');
        task.OwnerId = UserInfo.getUserId();
        task.ActivityDate = System.today();
        task.Status = 'Completed';
        task.Priority = 'Normal';
        task.Subject = Label.ERR_COULD_NOT_SEND_EMAIL + ' ' + objectsByIds.get(stResult.sourceId).get('Name');
        task.Description = getTaskDescription(stResult);
        return task;
    }

    private String getTaskDescription(AbstractStatementManager.StatementResult stResult) {
        return stBase == AbstractStatementManager.StatementBase.BILLING ?
            BillingsPDFManager.REPORT_LOG_TEMPLATE_LINE
                .replace(AbstractStatementManager.REPORT_LOG_SOURCE_DESC, stResult.messages.get(0))
                .replace(AbstractStatementManager.REPORT_LOG_SOURCE_NMB, stResult.sourceName) :
            BillingsPDFManager.REPORT_LOG_TEMPLATE_LINE
                .replace(AbstractStatementManager.REPORT_LOG_SOURCE_DESC, stResult.messages.get(0))
                .replace(AbstractStatementManager.REPORT_LOG_SOURCE_NMB, stResult.sourceName)
                .replace('Billing Number: ', Label.COMMON_ACCOUNT_VALUE);
    }

    private void setCCAddresses(AbstractStatementManager.StatementSet statementHandler) {
        Set<Id> accountIds = new Set<Id>();
        for (AbstractStatementManager.Statement st : statementHandler.statements) {
            accountIds.add(st.customerId);
        }

        Map<Id, Set<String>> accountIdToEmails = FinancialSuiteUtils.getEmailAddressesFromAccountContact(
            accountIds, new Set<String>{'Billing Contact'}
        );

        for (AbstractStatementManager.Statement st : statementHandler.statements) {
            st.ccAddressesList = new List<String>(accountIdToEmails.get(st.customerId));
        }
    }

}