public with sharing class BillingLDVCloneBatch extends SourceDocumentCloneBatch {
    private final Id acctPeriodId;
    private final Date billingDate;
    private final String currencyCode;
    private final Boolean isMultiCurrencyEnabled;
    private final Boolean makeCreditMemo;
    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public BillingLDVCloneBatch(Set<Id> sourceIds, Id acctPeriodId, Date billingDate, String currencyCode, Boolean makeCreditMemo) {
            super(sourceIds);
            this.acctPeriodId = acctPeriodId;
            this.billingDate = billingDate;
            this.currencyCode = currencyCode != null ? currencyCode : MultiCurrencyHandler.CORPORATE_CURRENCY;
            this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.makeCreditMemo = makeCreditMemo;
    }

    public override Database.QueryLocator start(Database.BatchableContext ctx) {
        Set<String> billingLineFields = DeepCloneFieldSetService.getCloneableFields(String.valueOf(Billing_Line__c.SObjectType),PACKAGE_QUALIFIER + 'Billing_Line_fields_to_Clone');
        billingLineFields.add(PACKAGE_QUALIFIER + 'Rate__c');
        billingLineFields.add(PACKAGE_QUALIFIER + 'Hours_Units__c');
        return DomainUtils.billingLinesByHeaderIdsQuery(billingLineFields, this.clonedSourceIdsBySourceIds.keySet());
    }

    public override Id sourceIdByLineRecord(SObject line) {
        return (Id)line.get(GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c');
    }
    
    public override Map<Id, Id> cloneSources(Set<Id> ids) {
        Map<Id, Id> clonedIdsByOriginalIds = new Map<Id, Id>();

        if (!ids.isEmpty()) {
            Map<Id, Billing__c> clonedBillingsByds = new Map<Id, Billing__c>();
            Set<String> billingFields = DeepCloneFieldSetService.getCloneableFields(String.valueOf(Billing__c.SObjectType),PACKAGE_QUALIFIER + 'Billing_fields_to_Clone');
            billingFields.add(PACKAGE_QUALIFIER + 'Customer__c');
            for (Billing__c Billing : DomainUtils.getBillingsById(billingFields, ids)) {
                if (acctPeriodId != null) {
                    Billing__c cloneBilling = Billing.clone(false);
                    cloneBilling.Customer__c = Billing.Customer__c;
                    cloneBilling.Date__c = billingDate;
                    cloneBilling.Accounting_Period__c = acctPeriodId;
                    cloneBilling.Currency_Conversion_Rate__c = null;
                    if (isMultiCurrencyEnabled) {
                        cloneBilling.put('CurrencyIsoCode', currencyCode);
                    }
                    clonedBillingsByds.put(Billing.Id, cloneBilling);
                }
            }
            if (!clonedBillingsByds.isEmpty()) {
                clonedIdsByOriginalIds.putAll(
                    this.processCloneSourcesResult(
                        SFDCSecurityUtils.insertCheckCRUDAndFLS(
                            clonedBillingsByds.values(),
                            new List<String>{'Date__c', 'Accounting_Period__c'},
                            false
                        ),
                    new List<Id>(clonedBillingsByds.keySet())
                ));
            }
        }

        return clonedIdsByOriginalIds;
    }

    public override void cloneLines(List<SObject> lines) {
        List<Billing_Line__c> filteredLines = (List<Billing_Line__c>) lines;
        Set<Id> clonedSourceIds = new Set<Id>();
        for (Billing_Line__c billingLine : filteredLines) {
            clonedSourceIds.add(this.clonedSourceIdsBySourceIds.get(billingLine.Billing__c));
        }

        List<Billing_Line__c> clonedbillingLines = new List<Billing_Line__c>();
        for (Billing_Line__c billingLine : filteredLines) {
            Id clonedSourceId = clonedSourceIdsBySourceIds.get(billingLine.Billing__c);
            Billing_Line__c newBillLine = billingLine.clone(false);
            newBillLine.Date__c = billingDate;
            newBillLine.Billing__c = clonedSourceId;
            newBillLine.Rate__c = getAmount(billingLine);
            newBillLine.Hours_Units__c = getQuantity(billingLine);
            clonedbillingLines.add(newBillLine);
        }

        if (!clonedbillingLines.isEmpty()) {
            this.processCloneSourceLinesResult(
                SFDCSecurityUtils.insertCheckCRUDAndFLS(
                    clonedbillingLines,
                    new List<String>{'Hours_Units__c', 'Rate__c', 'Date__c'}
                ),
                clonedbillingLines
            );
        }
    } 

    private Decimal getAmount(Billing_Line__c bl) {
        return makeCreditMemo && AccountingSettingsHandler.isCreditMemoDefaultAmount() ? bl.Rate__c * -1 : bl.Rate__c;
    }

    private Decimal getQuantity(Billing_Line__c bl) {
        return makeCreditMemo && AccountingSettingsHandler.isCreditMemoDefaultQuantity() ? bl.Hours_Units__c * -1 : bl.Hours_Units__c;
    }
}