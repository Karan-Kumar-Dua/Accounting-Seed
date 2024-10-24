public with sharing class AutomatedJobResultsHandler {

    private static AutomatedJobResultsHandler instance;
    private static Map<String, Id> reportIdsByJobName;
    @TestVisible
    private static Map<String, List<String>> reportsName;
    private AutomatedJobResultsWrapper jobResultObject;

    public static Map<String, String> jobsName = new Map<String, String> {
        'Recurring Billing Job' => 'Recurring Billing',
        'Recurring Payable Job' => 'Recurring Payable',
        'Recurring Journal Entry Job' => 'Recurring Journal Entry',
        'Automated Email Billing Job' => 'Automated Email Billing',
        'Scheduled Post Job' => 'Scheduled Post',
        'Async Post or Unpost Job' => 'Async Post or Unpost',
        'Recurring Period Task Job' => 'Recurring Period Task',
        'Consolidation Routine Job' => 'Consolidation Routine',
        'Delete Source Documents Job' => 'Delete Source Documents',
        'Merchant Download Job' => Label.JOB_JOURNAL_ENTRIES,
        'AP Disbursement Void Job' => 'AP Disbursement Void',
        'Large Data Volume Post Job' => 'Large Data Optimizer Post',
        'Large Data Volume Unpost Job' => 'Large Data Optimizer Unpost',
        'Cash Receipt Void Job' => 'Cash Receipt Void'
    };

    public static AutomatedJobResultsHandler getInstance() {
        if (instance == NULL) {
            instance = new AutomatedJobResultsHandler();
        }
        return instance;
    }

    public static void presetJobResultRecord(Id jobResultId) {
        getInstance().jobResultObject.resultObj = DomainUtils.getAutomatedJobResultsById(jobResultId);
        if (getInstance().jobResultObject.resultObj != null
                && String.isBlank(getInstance().jobResultObject.resultObj.Notes__c)) {
            getInstance().jobResultObject.resultObj.Notes__c = '';
        }
    }

    private AutomatedJobResultsHandler() {
        jobResultObject = new AutomatedJobResultsWrapper();
        initReportsNameMap();
        initReports();

    }

    private void initReports() {
        if (reportIdsByJobName == NULL) {
            reportIdsByJobName = new Map<String, Id>();
            List<Report> reports = DomainUtils.getReportsByDeveloperNames(reportsName.keySet());
            for (Report report : reports) {
                for (String jobName : reportsName.get(report.DeveloperName)) {
                    reportIdsByJobName.put(jobName, report.Id);
                }
            }
            if (Test.isRunningTest()) {
                reportIdsByJobName.put('test report job', '00000000000xxxxAAA');
            }
        }
    }

    private void initReportsNameMap() {
        if (reportsName == NULL) {
            reportsName = new Map<String, List<String>> {
                'Exceptions_Recurring_Billing_Job' => new List<String> {'Recurring Billing Job'},
                'Exceptions_Recurring_Payable_Job' => new List<String> {'Recurring Payable Job'},
                'Exceptions_Recurring_Journal_Entry_Job' => new List<String> {'Recurring Journal Entry Job'},
                'Exceptions_Automated_Email_Billing_Job' => new List<String> {'Automated Email Billing Job'},
                'Exceptions_AP_Recurring_Tasks' => new List<String> {'Recurring Period Task Job'},
                'Exceptions_Billings_Job' => new List<String> {
                    'Scheduled Post Job' + Billing__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Sched_Post_Job_CR' => new List<String> {
                    'Scheduled Post Job' + Cash_Receipt__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Sched_Post_Job_BCR' => new List<String> {
                    'Scheduled Post Job' + Billing_Cash_Receipt__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Scheduled_Post_Job_Payables' => new List<String> {
                    'Scheduled Post Job' + Account_Payable__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Sched_Post_Job_CD' => new List<String> {
                    'Scheduled Post Job' + Cash_Disbursement__c.getSObjectType().getDescribe().getLabelPlural(),
                    'Async Post or Unpost Job' + Cash_Disbursement__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Sched_Post_Job_APD' => new List<String> {
                    'Scheduled Post Job' + AP_Disbursement__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Sched_Post_Job_Time_Cards' => new List<String> {
                    'Scheduled Post Job' + Time_Card__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Sched_Post_Job_JE' => new List<String> {
                    'Scheduled Post Job' + Journal_Entry__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Sched_Post_Job_Amortization' => new List<String> {
                    'Scheduled Post Job' + Scheduled_Revenue_Expense__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_LDO_Post_Job_Billings' => new List<String> {
                    'Large Data Volume Post Job' + Billing__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_LDO_Post_Job_Payables' => new List<String> {
                    'Large Data Volume Post Job' + Account_Payable__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_LDO_Post_Job_JE' => new List<String> {
                    'Large Data Volume Post Job' + Journal_Entry__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_LDO_Unpost_Job_Billings' => new List<String> {
                    'Large Data Volume Unpost Job' + Billing__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_LDO_Unpost_Job_Payables' => new List<String> {
                    'Large Data Volume Unpost Job' + Account_Payable__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_LDO_Unpost_Job_JE' => new List<String> {
                    'Large Data Volume Unpost Job' + Journal_Entry__c.getSObjectType().getDescribe().getLabelPlural()
                },
                'Exceptions_Consolidations_Routine' => new List<String> {'Consolidation Routine Job'},
                'Exceptions_Uncleared_Bank_Rec_Line_Deletion_Job' => new List<String> {'Uncleared Bank Rec Deletion'},
                'Exceptions_Bank_Rec_Deletion_Job' => new List<String> {'Bank Rec Deletion Job'},
                'Exceptions_Bank_Deposit_Deletion_Job' => new List<String> {'Bank Deposits Deletion Job'},
                'Exceptions_BCR_Deletion_Job' => new List<String> {'BCR Deletion Job'},
                'Exceptions_AP_Disbursements_Deletion_Job' => new List<String> {'AP Disbursements Deletion'},
                'Exceptions_Billing_Credit_Memos_Deletion_Job' => new List<String> {'Billing Credit Memos Del Job'},
                'Exceptions_Cash_Receipts_Deletion_Job' => new List<String> {'Cash Receipts\' Deletion Job'},
                'Exceptions_AP_Credit_Memos_Deletion_Job' => new List<String> {'AP Credit Memos Deletion Job'},
                'Exceptions_Cash_Disbursements_Deletion_Job' => new List<String> {'Cash Disbursements Deletion'},
                'Exceptions_Amort_Entries_Deletion_Job' => new List<String> {'Amort Entries Deletion Job'},
                'Exceptions_Billing_Lines_Deletion_Job' => new List<String> {'Billing Lines Deletion Job'},
                'Exceptions_Billing_Aging_History_Deletion_Job' => new List<String> {'Billing AH Del Job'},
                'Exceptions_Billings_Deletion_Job' => new List<String> {'Billings Deletion Job'},
                'Exceptions_Payables_Lines_Deletion_Job' => new List<String> {'Payable Lines Deletion Job'},
                'Exceptions_AP_Aging_History_Deletion_Job' => new List<String> {'AP Aging History Delete Job'},
                'Exceptions_Payables_Deletion_Job' => new List<String> {'Payables Deletion Job'},
                'Exceptions_JE_Line_Deletion_Job' => new List<String> {'JE Line Deletion Job'},
                'Exceptions_JE_Deletion_Job' => new List<String> {'Journal Entries Deletion Job'},
                'Exceptions_Bank_Transactions_Deletion_Job' => new List<String> {'Bank Transactions Delete Job'},
                'Exceptions_Merchant_Download_Job' => new List<String> {'Merchant Download Job'},
                'Exceptions_Cash_Receipts_Void_Job' => new List<String> {'Cash Receipt Void Job'}
            };
            if (AccountingSettingsHandler.isERPEnabled()) {
                reportsName.put(
                    'Exceptions_Sched_Post_Job_IIM',
                    new List<String> {'Scheduled Post Job' + Schema.getGlobalDescribe()
                        .get(GlobalVariables.ERPPACKAGE_QUALIFIER + 'Inbound_Inventory_Movement__c')
                        .newSObject().getSObjectType().getDescribe().getLabelPlural()}
                );
                reportsName.put(
                    'Exceptions_Sched_Post_Job_MIM',
                    new List<String> {'Scheduled Post Job' + Schema.getGlobalDescribe()
                        .get(GlobalVariables.ERPPACKAGE_QUALIFIER + 'Manufacturing_Inventory_Movement__c')
                        .newSObject().getSObjectType().getDescribe().getLabelPlural()}
                );
                reportsName.put(
                    'Exceptions_Sched_Post_Job_OIM',
                    new List<String> {'Scheduled Post Job' + Schema.getGlobalDescribe()
                        .get(GlobalVariables.ERPPACKAGE_QUALIFIER + 'Outbound_Inventory_Movement__c')
                        .newSObject().getSObjectType().getDescribe().getLabelPlural()}
                );
                reportsName.put(
                    'Exceptions_Sched_Post_Job_POIM',
                    new List<String> {'Scheduled Post Job' + Schema.getGlobalDescribe()
                        .get(GlobalVariables.ERPPACKAGE_QUALIFIER + 'Purchase_Order_Inventory_Movement__c')
                        .newSObject().getSObjectType().getDescribe().getLabelPlural()}
                );
                reportsName.put(
                    'Exceptions_Sched_Post_Job_SOIM',
                    new List<String> {'Scheduled Post Job' + Schema.getGlobalDescribe()
                        .get(GlobalVariables.ERPPACKAGE_QUALIFIER + 'Sales_Order_Inventory_Movement__c')
                        .newSObject().getSObjectType().getDescribe().getLabelPlural()}
                );
            }
        }
    }

    public static void setJobType(String jobName) {
        getInstance().jobResultObject.setJobType(jobName);
    }

    public static String saveAutomatedJobResults() {
        return getInstance().jobResultObject.saveResult();
    }

    public static void updateAutomatedJobResults() {
        getInstance().jobResultObject.updateResult();
    }

    public static void setProcessed(Integer count) {
        getInstance().jobResultObject.resultObj.Processed__c = count;
    }

    public static void addProcessed(Integer count) {
        getInstance().jobResultObject.resultObj.Processed__c += count;
    }

    public static void setSucceeded(Integer count) {
        getInstance().jobResultObject.resultObj.Succeeded__c = count;
    }

    public static void addSucceeded(Integer count) {
        getInstance().jobResultObject.resultObj.Succeeded__c += count;
    }

    public static void setFailed(Integer count) {
        getInstance().jobResultObject.resultObj.Failed__c = count;
    }

    public static void addFailed(Integer count) {
        getInstance().jobResultObject.resultObj.Failed__c += count;
    }

    public static void setError(String errorValue) {
        getInstance().jobResultObject.resultObj.Notes__c += errorValue + '\n';
    }

    public static void addNote(String noteValue) {
        setError(noteValue);
    }

    public static String getReportLink(String jobName) {
        getInstance();
        Id exceptionReportId;
        if (reportIdsByJobName.keySet().contains(jobName)) {
            exceptionReportId = reportIdsByJobName.get(jobName);
        }
        String idLink = exceptionReportId != NULL ? '/' + exceptionReportId : '';

        return URL.getOrgDomainUrl().toExternalForm() + idLink;
    }

    public static Boolean isReportExist(String jobName) {
        return reportIdsByJobName.keySet().contains(jobName);
    }

    public with sharing class AutomatedJobResultsWrapper {
        public Automated_Job_Results__c resultObj = new Automated_Job_Results__c();

        public AutomatedJobResultsWrapper() {
            resultObj.Processed__c = 0;
            resultObj.Succeeded__c = 0;
            resultObj.Failed__c = 0;
            resultObj.Notes__c = '';
        }

        public void setJobType(String jobName) {
            if (jobsName.keySet().contains(jobName)) {
                resultObj.Schedule_Job_Type__c = jobsName.get(jobName);
            }
        }

        public String saveResult() {
            if (resultObj.Schedule_Job_Type__c != NULL
                    && resultObj.Processed__c != NULL
                    && resultObj.Succeeded__c != NULL
                    && resultObj.Failed__c != NULL) {

                SFDCSecurityUtils.insertProxy(resultObj);
            }
            return resultObj.Id;
        }

        public void updateResult() {
            SFDCSecurityUtils.updateProxy(resultObj);
        }
    }

}