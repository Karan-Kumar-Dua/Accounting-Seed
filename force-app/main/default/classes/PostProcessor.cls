public with sharing class PostProcessor {
    public static final Map<SObjectType, Map<SourceDocumentBatchOptions.AccountingMethod, String>> POST_HANDLERS_BY_SOBJECT_TYPES = new Map<SObjectType, Map<SourceDocumentBatchOptions.AccountingMethod, String>>{
        Billing__c.getSObjectType() => new Map<SourceDocumentBatchOptions.AccountingMethod, String>{
            SourceDocumentBatchOptions.AccountingMethod.ACCRUAL => 'BillingPostHandler',
            SourceDocumentBatchOptions.AccountingMethod.CASH => 'BillingPostHandlerCash'
        },
        Account_Payable__c.getSObjectType() => new Map<SourceDocumentBatchOptions.AccountingMethod, String>{
            SourceDocumentBatchOptions.AccountingMethod.ACCRUAL => 'AccountPayablePostHandler',
            SourceDocumentBatchOptions.AccountingMethod.CASH => 'AccountPayablePostHandlerCash'
        },
        Cash_Receipt__c.getSObjectType() => new Map<SourceDocumentBatchOptions.AccountingMethod, String>{
            SourceDocumentBatchOptions.AccountingMethod.ACCRUAL => 'CashReceiptPostHandler',
            SourceDocumentBatchOptions.AccountingMethod.CASH => 'CashReceiptPostHandler'
        },
        Journal_Entry__c.getSObjectType() => new Map<SourceDocumentBatchOptions.AccountingMethod, String>{
            SourceDocumentBatchOptions.AccountingMethod.ACCRUAL => 'JournalEntryPostHandler',
            SourceDocumentBatchOptions.AccountingMethod.CASH => 'JournalEntryPostHandler'
        },
        Billing_Cash_Receipt__c.getSObjectType() => new Map<SourceDocumentBatchOptions.AccountingMethod, String>{
            SourceDocumentBatchOptions.AccountingMethod.ACCRUAL => 'BillingCashReceiptPostHandler',
            SourceDocumentBatchOptions.AccountingMethod.CASH => 'BillingCashReceiptPostHandler'
        },
        Cash_Disbursement__c.getSObjectType() => new Map<SourceDocumentBatchOptions.AccountingMethod, String>{
            SourceDocumentBatchOptions.AccountingMethod.ACCRUAL => 'CashDisbursementPostHandler',
            SourceDocumentBatchOptions.AccountingMethod.CASH => 'CashDisbursementPostHandler'
        },
        AP_Disbursement__c.getSObjectType() => new Map<SourceDocumentBatchOptions.AccountingMethod, String>{
            SourceDocumentBatchOptions.AccountingMethod.ACCRUAL => 'APDisbursementPostHandler',
            SourceDocumentBatchOptions.AccountingMethod.CASH => 'APDisbursementPostHandler'
        }
    };

    public static final Map<SObjectType, Map<SourceDocumentBatchOptions.ExecutionContext, String>> BATCHES_BY_SOBJECT_TYPES = new Map<SObjectType, Map<SourceDocumentBatchOptions.ExecutionContext, String>>{
        Billing__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
            SourceDocumentBatchOptions.ExecutionContext.POST => 'BillingLDVPostBatch',
            SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'BillingLDVUnpostBatch'
        },
        Account_Payable__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
            SourceDocumentBatchOptions.ExecutionContext.POST => 'AccountPayableLDVPostBatch',
            SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'AccountPayableLDVUnpostBatch'
        },
        Cash_Receipt__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
            SourceDocumentBatchOptions.ExecutionContext.POST => 'CashReceiptLDVPostBatch',
            SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'CashReceiptLDVUnpostBatch'
        },
        Journal_Entry__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
            SourceDocumentBatchOptions.ExecutionContext.POST => 'JournalEntryLDVPostBatch',
            SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'JournalEntryLDVUnpostBatch'
        },
        Billing_Cash_Receipt__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
            SourceDocumentBatchOptions.ExecutionContext.POST => 'BillingCashReceiptLDVPostBatch',
            SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'BillingCashReceiptLDVUnpostBatch'
        },
        Cash_Disbursement__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
            SourceDocumentBatchOptions.ExecutionContext.POST => 'CashDisbursementLDVPostBatch',
            SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'CashDisbursementLDVUnpostBatch'
        },
        AP_Disbursement__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
            SourceDocumentBatchOptions.ExecutionContext.POST => 'APDisbursementLDVPostBatch',
            SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'APDisbursementLDVUnpostBatch'
        }
    };

    private SourceDocumentBatchOptions.AccountingMethod accountingMethod = SourceDocumentBatchOptions.AccountingMethod.ACCRUAL;
    private Boolean isLDVMode = FeatureManagementHandler.isLargeDataVolumeModeEnabled();
    private Schema.SObjectType sourceSObjectType;
    public static final Integer BATCH_CHUNK_SIZE_WITH_API_CALLOUT = 90;
    public static final Integer BATCH_CHUNK_SIZE = 200;
    public static final Map<Schema.SObjectType, Map<SourceDocumentBatchOptions.ExecutionContext, String>> batchClassesBySobjectType =
        new Map<Schema.SObjectType, Map<SourceDocumentBatchOptions.ExecutionContext, String>>{
            Billing__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
                SourceDocumentBatchOptions.ExecutionContext.POST => 'BillingLDVPostBatch',
                SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'BillingLDVUnpostBatch'
            },
            Account_Payable__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
                SourceDocumentBatchOptions.ExecutionContext.POST => 'AccountPayableLDVPostBatch',
                SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'AccountPayableLDVUnpostBatch'
            },
            Cash_Receipt__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
                SourceDocumentBatchOptions.ExecutionContext.POST => 'CashReceiptLDVPostBatch',
                SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'CashReceiptLDVUnpostBatch'
            },
            Journal_Entry__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
                SourceDocumentBatchOptions.ExecutionContext.POST => 'JournalEntryLDVPostBatch',
                SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'JournalEntryLDVUnpostBatch'
            },
            Billing_Cash_Receipt__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
                SourceDocumentBatchOptions.ExecutionContext.POST => 'BillingCashReceiptLDVPostBatch',
                SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'BillingCashReceiptLDVUnpostBatch'
            },
            Cash_Disbursement__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
                SourceDocumentBatchOptions.ExecutionContext.POST => 'CashDisbursementLDVPostBatch',
                SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'CashDisbursementLDVUnpostBatch'
            },
            AP_Disbursement__c.getSObjectType() => new Map<SourceDocumentBatchOptions.ExecutionContext, String>{
                SourceDocumentBatchOptions.ExecutionContext.POST => 'APDisbursementLDVPostBatch',
                SourceDocumentBatchOptions.ExecutionContext.UNPOST => 'APDisbursementLDVUnpostBatch'
            }
        };

    public final static Set<SObjectType> ONLY_ONE_BY_ONE = new Set<SObjectType>{
            Billing__c.getSObjectType(),
            Account_Payable__c.getSObjectType(),
            Journal_Entry__c.getSObjectType()
    };

    public final static Set<SObjectType> ONLY_POST_OR_UNPOST = new Set<SObjectType>{
        Billing_Cash_Receipt__c.getSObjectType(),
        AP_Disbursement__c.getSObjectType()
    };

    public List<PostResult> post(List<Id> processedRecordsIds) {
        List<PostResult> postResults = new List<PostResult>();
        if (!processedRecordsIds.isEmpty()) {
            sourceSObjectType = processedRecordsIds[0].getSobjectType();
            if (isLDVMode) {
                setPostingStatusInProgress(processedRecordsIds, AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS, AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED);
            }
            if (!(isLDVMode && isJobInProgress(sourceSObjectType, SourceDocumentBatchOptions.ExecutionContext.POST))) {
                postResults = runAppropriatePostHandler(processedRecordsIds);
            }
        }
        return postResults;
    }

    public List<PostResult> unpost(List<Id> processedRecordsIds) {
        List<PostResult> postResults = new List<PostResult>();
        if (!processedRecordsIds.isEmpty()) {
            sourceSObjectType = processedRecordsIds[0].getSobjectType();
            if (isLDVMode) {
                setPostingStatusInProgress(processedRecordsIds, AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS, AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED);
            }
            if (!(isLDVMode && isJobInProgress(sourceSObjectType, SourceDocumentBatchOptions.ExecutionContext.UNPOST))) {
                postResults = runAppropriateUnpostHandler(processedRecordsIds);
            }
        }
        return postResults;
    }

    public PostProcessor accountingMethod(SourceDocumentBatchOptions.AccountingMethod accountingMethod) {
        this.accountingMethod = accountingMethod;
        return this;
    }

    public void postOutstandingSourceRecords(Schema.SObjectType headerSObjectType, SourceDocumentBatchOptions.ExecutionContext context) {
        if (isLDVMode) {
            List<Id> sourceIds = getOutstandingSourceRecords(headerSObjectType, context);
            if (!sourceIds.isEmpty()) {
                if (context == SourceDocumentBatchOptions.ExecutionContext.POST) {
                    runAppropriatePostHandler(sourceIds);
                } else {
                    runAppropriateUnpostHandler(sourceIds);
                }
            }
        }
    }

    private Boolean isJobInProgress(Schema.SObjectType headerSObjectType, SourceDocumentBatchOptions.ExecutionContext context) {
        Set<String> apexClassNames = new Set<String>{ batchClassesBySobjectType.get(headerSObjectType).get(context) };
        if (PostProcessor.ONLY_ONE_BY_ONE.contains(headerSObjectType)) {
            for (SObjectType sObjType : ONLY_ONE_BY_ONE) {
                for (SourceDocumentBatchOptions.ExecutionContext tempContext : SourceDocumentBatchOptions.ExecutionContext.values()) {
                    apexClassNames.add(batchClassesBySobjectType.get(sObjType).get(tempContext));
                }
            }
        }
        if (PostProcessor.ONLY_POST_OR_UNPOST.contains(headerSObjectType)) {
            for (SourceDocumentBatchOptions.ExecutionContext tempContext : SourceDocumentBatchOptions.ExecutionContext.values()) {
                apexClassNames.add(batchClassesBySobjectType.get(headerSObjectType).get(tempContext));
            }
        }
        List<AsyncApexJob> asyncApexJobs = DomainUtils.getAsyncApexJobByApexClassNameAndStatus(
            apexClassNames,
            GlobalVariables.APEX_JOB_STATUSES
        );

        return !asyncApexJobs.isEmpty();
    }

    public void setPostingStatusInProgress(List<Id> processedRecordsIds, String status, String availableStatus) {
        sourceSObjectType = processedRecordsIds[0].getSobjectType();
        List<SObject> objs = querySObject(processedRecordsIds, null);
        for (SObject obj : objs) {
            String currentStatus = (String) obj.get(SourceDocumentBatchHelper.statusFieldBySobjectType.get(this.sourceSObjectType));
            if (currentStatus == availableStatus) {
                obj.put(SourceDocumentBatchHelper.statusFieldBySobjectType.get(this.sourceSObjectType), status);
            }
        }

        TriggerObserver.getInstance().unlockField(SourceDocumentBatchHelper.statusFieldBySobjectType.get(this.sourceSObjectType));
        SFDCSecurityUtils.updateCheckCRUDAndFLS(objs, new List<String>{
            'Status__c'
        });
        TriggerObserver.purgeUnlockedFields(SourceDocumentBatchHelper.statusFieldBySobjectType.get(this.sourceSObjectType));

    }

    private List<Id> getOutstandingSourceRecords(Schema.SObjectType headerSObjectType, SourceDocumentBatchOptions.ExecutionContext context) {
        this.sourceSObjectType = headerSObjectType;
        String status = context == SourceDocumentBatchOptions.ExecutionContext.POST ?
            AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS : AbstractPostHandler.DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS;
        return new List<Id>(new Map<Id, SObject> (querySObject(new List<Id>(), status)).keySet());
    }

    private List<PostResult> runAppropriatePostHandler(List<Id> processedRecordsIds) {
        return process(processedRecordsIds, SourceDocumentBatchOptions.ExecutionContext.POST);
    }

    private List<PostResult> runAppropriateUnpostHandler(List<Id> processedRecordsIds) {
        return process(processedRecordsIds, SourceDocumentBatchOptions.ExecutionContext.UNPOST);
    }

    private List<PostResult> process(List<Id> processedRecordsIds, SourceDocumentBatchOptions.ExecutionContext executionContext) {
        List<PostResult> postResults = new List<PostResult>();
        if (isLDVMode) {
            String batchName = BATCHES_BY_SOBJECT_TYPES.get(this.sourceSObjectType)?.get(executionContext);
            SourceDocumentBatchBase batchBase = String.isNotBlank(batchName)
                ? (SourceDocumentBatchBase) Type.forName(batchName)?.newInstance()
                : null;
            if (batchBase != null) {
                SourceDocumentBatchOptions options = new SourceDocumentBatchOptions(new Set<Id>(processedRecordsIds));
                options.setCurrentContext(executionContext);
                Integer chunkSize = this.sourceSObjectType == Billing__c.getSObjectType() ? BATCH_CHUNK_SIZE_WITH_API_CALLOUT : BATCH_CHUNK_SIZE;
                if (System.isBatch()) {
                    System.enqueueJob(new RunBatchQueueable(batchBase.options(options), chunkSize));
                } else {
                    Database.executeBatch(batchBase.options(options), chunkSize);
                }
            }
        } else {
            String postHandlerName = POST_HANDLERS_BY_SOBJECT_TYPES.get(this.sourceSObjectType)?.get(accountingMethod);
            AbstractPostHandler postHandler = String.isNotBlank(postHandlerName)
                ? (AbstractPostHandler) Type.forName(postHandlerName)?.newInstance()
                : null;
            if (postHandler != null) {
                postResults = executionContext == SourceDocumentBatchOptions.ExecutionContext.POST
                    ? postHandler.post(processedRecordsIds)
                    : postHandler.unpost(processedRecordsIds);
            }
        }

        return postResults;
    }

    private List<SObject> querySObject(List<Id> sourceIds, String status) {
        List<String> fieldsToQuery = new List<String>{
            'Id',
            'Status__c'
        };
        String queryCondition = '';
        if (!sourceIds.isEmpty()) {
            queryCondition += 'Id IN :sourceIds';
        }
        if (String.isNotBlank(status)) {
            queryCondition += 'Status__c = :status';
        }
        if (this.sourceSObjectType == Billing__c.getSObjectType() || this.sourceSObjectType == Account_Payable__c.getSObjectType()) {
            fieldsToQuery.add('Line_Count__c');
            queryCondition += ' AND Line_Count__c > 0';
        }
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            null,
            this.sourceSObjectType,
            queryCondition,
            false,
            false
        );
        return (List<SObject>) Database.query(dynamicSOQL);
    }

    public static Set<Id> filterByStatus(SObjectType sObjType, List<Id> recordIds, String excludeStatus) {
        List<String> conditions = new List<String>{
                'Id =: arg0',
                String.valueOf(SourceDocumentBatchHelper.statusFieldBySobjectType.get(sObjType)) + ' !=: arg1'
        };
        return new Map<Id, SObject>(DomainUtils.recordsByConditions(
                sObjType,
                new List<String>{
                        'Id',
                        'Name',
                        String.valueOf(SourceDocumentBatchHelper.statusFieldBySobjectType.get(sObjType))
                },
                String.join(conditions, ' AND '),
                new List<Object>{recordIds, excludeStatus}
        )).keySet();
    }

    public class RunBatchQueueable implements Queueable, Database.AllowsCallouts {
        SourceDocumentBatchBase batchBaseClass;
        Integer batchChunkSize;

        public RunBatchQueueable(SourceDocumentBatchBase batchBaseClass, Integer batchChunkSize) {
            this.batchBaseClass = batchBaseClass;
            this.batchChunkSize = batchChunkSize;
        }
        public void execute(QueueableContext qc) {
            Database.executeBatch(batchBaseClass, batchChunkSize);
        }
    }

}