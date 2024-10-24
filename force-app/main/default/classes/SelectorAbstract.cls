public abstract with sharing class SelectorAbstract {
    public static final String SOQL_TEMPLATE = 'SELECT {0} FROM {1} {2}';

    private Set<Id> headerIds;
    protected SourceDocumentBatchOptions.ExecutionContext context;
    protected Schema.SObjectType sObjectType;
    protected SourceDocumentBatchHelper helper = new SourceDocumentBatchHelper();

    public String postingStatusField = 'Status__c';

    public SelectorAbstract(Schema.SObjectType sObjectType) {
        this.sObjectType = sObjectType;
    }

    public abstract List<Schema.SObjectField> getFields();
    protected virtual List<String> getAdditionalFieldPaths(){
        return new List<String>();
    }
    protected virtual List<String> getAdditionalCondition(){
        return new List<String>();
    }

    public String getBaseQuery(SourceDocumentBatchOptions options){
        List<String> conditions = getAdditionalCondition();
        if (headerIds != null && !headerIds.isEmpty()) {
            conditions.add(SourceDocumentBatchHelper.mChildRelationship.get(this.sObjectType).getDescribe().getName() + ' IN :genericIdSet');
        } else if (options != null
                && options.processInProgressStatuses != null
                && !options.processInProgressStatuses.isEmpty()) {
            conditions.add(postingStatusField + ' = \'' + (new List<String>(options.processInProgressStatuses))[0] + '\'');
        } else {
            conditions.add(postingStatusField + ' = \''
                + (
                    context == SourceDocumentBatchOptions.ExecutionContext.POST
                    ? AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
                    : AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                )
                    + '\'');
        }

        return String.format(SOQL_TEMPLATE, new List<String>{
                String.join(fields(), ','),
                this.sObjectType.getDescribe().getName(),
                (!conditions.isEmpty() ? ' WHERE ' + String.join(conditions, ' AND ') : '')
                    + ' ORDER BY ' + SourceDocumentBatchHelper.mChildRelationship.get(this.sObjectType).getDescribe().getName()
        });
    }

    public String getDeleteQuery(){
        List<String> conditions = new List<String>{
                SourceDocumentBatchHelper.mChildRelationship.get(this.sObjectType).getDescribe().getName() + ' IN (SELECT '
                        + helper.transactionGroupRelationship.get(this.sObjectType).getDescribe().getName()
                        + ' FROM Transaction_Group__c WHERE Batch_Id__c IN :genericIdSet)'
        };

        DescribeFieldResult refToParentFieldResult = SourceDocumentBatchHelper.mChildRelationship.get(this.sObjectType)?.getDescribe();
        if (String.isNotBlank(refToParentFieldResult.getRelationshipName()) && !refToParentFieldResult.getReferenceTo().isEmpty()) {
            SObjectField statusField = SourceDocumentBatchHelper.statusFieldBySobjectType.get(refToParentFieldResult.getReferenceTo()[0]);
            String parentStatusField = String.join(new List<String>{
                    refToParentFieldResult.getRelationshipName(),
                    String.valueOf(statusField)
            }, '.');
            conditions.add(parentStatusField + ' = \'' + AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED + '\'');
        }

        return String.format(SOQL_TEMPLATE, new List<String>{
                String.join(fields(), ','),
                this.sObjectType.getDescribe().getName(),
                !conditions.isEmpty() ? (' WHERE ' + String.join(conditions, ' AND ')) : ''
        });
    }

    public void setHeaderIds(Set<Id> headerIds) {
        this.headerIds = headerIds;
    }

    public void setContext(SourceDocumentBatchOptions.ExecutionContext context) {
        this.context = context;
    }

    private List<String> fields() {
        Set<String> fields = new Set<String>();
        for(Schema.SObjectField field : this.getFields()){
            fields.add(field.getDescribe().getName().toLowerCase());
        }
        for(String field : this.getAdditionalFieldPaths()){
            fields.add(field?.toLowerCase());
        }
        fields.remove(null);
        return new List<String>(fields);
    }

    private String getFieldsQuery() {
        String soql = 'SELECT ';
        soql += String.join(fields(), ',');
        return soql;
    }
}