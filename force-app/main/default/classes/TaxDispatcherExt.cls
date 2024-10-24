public with sharing class TaxDispatcherExt {

    @TestVisible
    private static final PageReference FS_BILLING_SALES_TAX_PAGE = Page.BillingSalesTax;
    @TestVisible
    private static final PageReference FS_OPPORTUNITY_SALES_TAX_PAGE = Page.OpportunitySalesTax;
    @TestVisible
    private static final PageReference AVALARA_BILLING_SALES_TAX_PAGE = Page.BillingSalesAvaTax;
    @TestVisible
    private static final PageReference AVALARA_OPPORTUNITY_SALES_TAX_PAGE = Page.OpportunitySalesTax;
    private Schema.SObjectType contextSObjectType;
    private final ApexPages.StandardController controller;


    public TaxDispatcherExt(ApexPages.StandardController con) {
        this.controller = con;
        this.contextSObjectType = ((Id) con.getId()).getSobjectType();
        if (!Test.isRunningTest() && this.contextSObjectType === Billing__c.getSObjectType()) {
            this.controller.addFields(new List<String>{Billing__c.Ledger__c.getDescribe().getName()});
        }
    }

    public PageReference redirectTo() {
        PageReference targetReference;
        TaxService.sobjectByLedgerId = new Map<SObject, Id>{
                this.controller.getRecord() =>
                    this.contextSObjectType === Billing__c.getSObjectType()
                        ? ((Billing__c) this.controller.getRecord()).Ledger__c : LedgerHandler.getLedgerId()
        };
        Boolean isAvalaraTaxCalculationEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(this.controller.getRecord());
        if (isAvalaraTaxCalculationEnabled) {
            if (contextSObjectType == Billing__c.SObjectType) {
                targetReference = initTargetReference(AVALARA_BILLING_SALES_TAX_PAGE);
            }
            else if (contextSObjectType == Opportunity.SObjectType) {
                targetReference = initTargetReference(AVALARA_OPPORTUNITY_SALES_TAX_PAGE);
            }
        }
        else {
            if (contextSObjectType == Billing__c.SObjectType) {
                targetReference = initTargetReference(FS_BILLING_SALES_TAX_PAGE);
            }
            else if (contextSObjectType == Opportunity.SObjectType) {
                targetReference = initTargetReference(FS_OPPORTUNITY_SALES_TAX_PAGE);
            }
        }

        return targetReference;
    }

    private PageReference initTargetReference(PageReference targetReference) {
        targetReference.getParameters().put('id', controller.getId());
        return targetReference;
    }

}