public with sharing class SourceDocumentBatchHelper {
    public static final Map<Schema.SObjectType, Schema.SObjectField> statusFieldBySobjectType = new Map<Schema.SObjectType, Schema.SObjectField>{
        Billing__c.getSObjectType() => Billing__c.Status__c,
        Cash_Receipt__c.getSObjectType() => Cash_Receipt__c.Status__c,
        Account_Payable__c.getSObjectType() => Account_Payable__c.Status__c,
        Journal_Entry__c.getSObjectType() => Journal_Entry__c.Status__c,
        Billing_Cash_Receipt__c.getSObjectType() => Billing_Cash_Receipt__c.Status__c,
        Cash_Disbursement__c.getSObjectType() => Cash_Disbursement__c.Status__c,
        AP_Disbursement__c.getSObjectType() => AP_Disbursement__c.Status__c
    };

    public static final Map<Schema.SObjectType, List<Schema.SObjectField>> ledgerFieldBySobjectType = new Map<Schema.SObjectType, List<Schema.SObjectField>>{
        Billing__c.getSObjectType() => new List<Schema.SObjectField>{ Billing_Line__c.Ledger__c },
        Cash_Receipt__c.getSObjectType() => new List<Schema.SObjectField>{ Cash_Receipt__c.Ledger__c },
        Account_Payable__c.getSObjectType() => new List<Schema.SObjectField>{ Account_Payable_Line__c.Ledger__c },
        Journal_Entry__c.getSObjectType() => new List<Schema.SObjectField>{ Journal_Entry_Line__c.Ledger__c },
        Billing_Cash_Receipt__c.getSObjectType() => new List<Schema.SObjectField>{ Billing_Cash_Receipt__c.Billing__c, Billing__c.Ledger__c },
        Cash_Disbursement__c.getSObjectType() => new List<Schema.SObjectField>{ Cash_Disbursement__c.Ledger__c },
        AP_Disbursement__c.getSObjectType() => new List<Schema.SObjectField>{ AP_Disbursement__c.Account_Payable__c, Account_Payable__c.Ledger__c }
    };

    public Map<Schema.SObjectType, Type> mSelectors = new Map<Schema.SObjectType, Type>{
            Billing__c.getSObjectType() => BillingSelector.class,
            Billing_Line__c.getSObjectType() => BillingLineSelector.class,
            Account_Payable__c.getSObjectType() => PayableSelector.class,
            Account_Payable_Line__c.getSObjectType() => PayableLineSelector.class,
            Cash_Receipt__c.getSObjectType() => CashReceiptSelector.class,
            Journal_Entry__c.getSObjectType() => JournalEntrySelector.class,
            Journal_Entry_Line__c.getSObjectType() => JournalEntryLineSelector.class,
            Billing_Cash_Receipt__c.getSObjectType() => BillingCashReceiptSelector.class,
            Cash_Disbursement__c.getSObjectType() => CashDisbursementSelector.class,
            AP_Disbursement__c.getSObjectType() => APDisbursementSelector.class
    };

    public Map<Schema.SObjectType, Schema.SObjectType> mParentToChild = new Map<Schema.SObjectType, Schema.SObjectType>{
            Billing__c.getSObjectType() => Billing_Line__c.getSObjectType(),
            Account_Payable__c.getSObjectType() => Account_Payable_Line__c.getSObjectType(),
            Cash_Receipt__c.getSObjectType() => Cash_Receipt__c.getSObjectType(),
            Journal_Entry__c.getSObjectType() => Journal_Entry_Line__c.getSObjectType(),
            Billing_Cash_Receipt__c.getSObjectType() => Billing_Line__c.getSObjectType(),
            Cash_Disbursement__c.getSObjectType() => Cash_Disbursement__c.getSObjectType(),
            AP_Disbursement__c.getSObjectType() => Account_Payable_Line__c.getSObjectType()
    };

    public static final Map<Schema.SObjectType, Schema.SObjectField> mChildRelationship = new Map<Schema.SObjectType, Schema.SObjectField>{
            Billing_Line__c.getSObjectType() => Billing_Line__c.Billing__c,
            Account_Payable_Line__c.getSObjectType() => Account_Payable_Line__c.Account_Payable__c,
            Cash_Receipt__c.getSObjectType() => Cash_Receipt__c.Id,
            Journal_Entry_Line__c.getSObjectType() => Journal_Entry_Line__c.Journal_Entry__c,
            Billing_Cash_Receipt__c.getSObjectType() => Billing_Cash_Receipt__c.Id,
            Cash_Disbursement__c.getSObjectType() => Cash_Disbursement__c.Id,
            AP_Disbursement__c.getSObjectType() => AP_Disbursement__c.Id
    };

    public Map<Schema.SObjectType, Schema.SObjectField> transactionGroupRelationship = new Map<Schema.SObjectType, Schema.SObjectField>{
        Billing_Line__c.getSObjectType() => Billing_Line__c.Billing__c,
        Account_Payable_Line__c.getSObjectType() => Account_Payable_Line__c.Account_Payable__c,
        Cash_Receipt__c.getSObjectType() => Transaction_Group__c.Cash_Receipt__c,
        Journal_Entry_Line__c.getSObjectType() => Journal_Entry_Line__c.Journal_Entry__c,
        Billing_Cash_Receipt__c.getSObjectType() => Transaction_Group__c.Billing_Cash_Receipt__c,
        Cash_Disbursement__c.getSObjectType() => Transaction_Group__c.Cash_Disbursement__c,
        AP_Disbursement__c.getSObjectType() => Transaction_Group__c.AP_Disbursement__c
    };

    public Map<Id, Transaction_Group__c> getCurrentGroupMap(Set<Id> inboundIds, Id batchId) {
        Map<Id, Transaction_Group__c> currentGroupMap = new Map<Id, Transaction_Group__c>();
        if (!inboundIds.isEmpty()) {
            Schema.SObjectType sObjectType = new List<Id> (inboundIds)[0].getSobjectType();
            for (Transaction_Group__c tg : queryTransactionGroup(null, batchId)) {
                currentGroupMap.put((Id)tg.get(String.valueOf(sObjectType)), tg);
            }
        }
        return currentGroupMap;
    }

    public void upsertCurrentGroupMap(Map<Id, Transaction_Group__c> currentGroupMap) {
        SFDCSecurityUtils.upsertProxy(currentGroupMap.values());
    }

    public void deleteOutboundTransactionGroup(Set<Id> outboundIds, Id batchId) {
        SFDCSecurityUtils.deleteProxy(queryTransactionGroup(new List<Id> (outboundIds), batchId));
    }

    public void setPostingStatus(List<Id> processedRecordsIds, String status, Schema.SObjectType sourceSObjectType) {
        setPostingStatus(processedRecordsIds, status, sourceSObjectType, new Set<String>());
    }

    public void setPostingStatus(List<Id> processedRecordsIds, String status, Schema.SObjectType sourceSObjectType, Set<String> skipStatuses) {
        List<SObject> objs = querySObject(processedRecordsIds, sourceSObjectType);
        for (SObject obj : objs) {
            if (!skipStatuses.contains((String)obj.get('Status__c'))) {
                obj.put(statusFieldBySobjectType.get(sourceSObjectType), status);
            }
        }

        TriggerObserver.getInstance().unlockField(statusFieldBySobjectType.get(sourceSObjectType));
        SFDCSecurityUtils.updateCheckCRUDAndFLS(objs, new List<String>{'Status__c'});
        TriggerObserver.purgeUnlockedFields(statusFieldBySobjectType.get(sourceSObjectType));
    }

    private List<Transaction_Group__c> queryTransactionGroup(List<Id> sourceIds, Id batchId) {
        List<String> conditions = new List<String>{'Batch_Id__c = :batchId'};
        if (sourceIds != null && !sourceIds.isEmpty()) {
            conditions.add(sourceIds[0].getSObjectType() + ' IN :sourceIds');
        }
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Amortization_Entry__c',
            'AP_Disbursement__c',
            'Batch_Id__c',
            'Billing__c',
            'Billing_Cash_Receipt__c',
            'Cash_Disbursement__c',
            'Cash_Receipt__c',
            'Journal_Entry__c',
            'Ledger__c',
            'Line_Count__c',
            'Lines_Processed__c',
            'Account_Payable__c',
            'Time_Card__c'
        };
        String queryCondition = String.join(conditions, ' AND ');
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            null,
            Transaction_Group__c.SObjectType,
            queryCondition,
            false,
            false
        );
        return (List<Transaction_Group__c>) Database.query(dynamicSOQL);
    }

    private List<SObject> querySObject(List<Id> sourceIds, Schema.SObjectType sourceSObjectType) {
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Status__c'
        };
        String queryCondition = '';
        if (!sourceIds.isEmpty()) {
            queryCondition += 'Id IN :sourceIds';
        }
        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            null,
            sourceSObjectType,
            queryCondition,
            false,
            false
        );
        return (List<SObject>) Database.query(dynamicSOQL);
    }


    public static Object fetchRecordValue(SObject record, List<SObjectField> fields) {
        Object value = null;
        for (Integer index = 0; index < fields.size(); index++) {
            SObjectField field = fields[index];
            if (index < fields.size() - 1) {
                record = record.getSObject(field);
            } else {
                value = record.get(field);
            }
        }

        return value;
    }
}