/*
**  Created By    : AccountingSeed
**  Created For    : Deepclone for Billing and Billing Lines. 
**  Created Date    : July 07, 2011
*/

public with sharing class BillingDeepClone {

    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private ApexPages.StandardController controller {get; set;}
    @TestVisible
    private Billing__c cloneBilling;
    @TestVisible
    private List<Billing_Line__c> newBillLines;
    private Set<String> billingFields;
    private Set<String> billingLineFields;
    @TestVisible

    public Billing__c tempBilling {get; set;}
    public Id billId {get; set;}
    public Id theNewBillingId {get; set;}
    public Boolean isError {get; set;}
    public Boolean isMultiCurrencyEnabled {get ;set;}
    public Boolean isCreditMemo {get; set;}
    public Boolean makeCreditMemo {get; set;}
    public Boolean disableCloneButton {get; set;}
    
    public static final String NO_OPEN_PERIOD_ERROR_MESSAGE = Label.ERR_NO_OPEN_ACCOUNTING_PERIOD;


    // initialize the controller
    public BillingDeepClone(ApexPages.StandardController controller) {
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        if (isMultiCurrencyEnabled && !Test.isRunningTest()) {
            controller.addFields(new List<String>{'CurrencyIsoCode'});
        }
        this.controller = controller;
        tempBilling = new Billing__c();
        tempBilling.Date__c = System.today();
        billId = controller.getRecord().Id;
        theNewBillingId = billId;
        isError = false;
        makeCreditMemo = false;
        disableCloneButton = false;
        isCreditMemo = [SELECT ID, Type__c FROM Billing__c WHERE ID=:billId].Type__c == 'Invoice' ? false : true;
        if (isMultiCurrencyEnabled) {
            tempBilling.put('CurrencyIsoCode', controller.getRecord().get('CurrencyIsoCode'));
        }

        //get Billing Fields that are added to the billing fields to clone fieldset
        billingFields = DeepCloneFieldSetService.getCloneableFields(String.valueOf(Billing__c.SObjectType),PACKAGE_QUALIFIER + 'Billing_fields_to_Clone');
        billingLineFields = DeepCloneFieldSetService.getCloneableFields(String.valueOf(Billing_Line__c.SObjectType),PACKAGE_QUALIFIER + 'Billing_Line_fields_to_Clone');
    }

    public PageReference cloneWithlines() {
        isError = false;

        //Query for current accounting period
        Accounting_Period__c acctPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(tempBilling.Date__c, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Billing__c.SObjectType);

        if (acctPeriod == NULL) {
            isError = true;
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.SEVERITY.ERROR,
                String.format(NO_OPEN_PERIOD_ERROR_MESSAGE, new List<String>{(tempBilling.Date__c).format()})
            ));
            return NULL;
        }


       //Continue in async context if LDV is enabled
       if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            Set<Id> sourceIds = new Set<Id>{billId};
            BillingLDVCloneBatch batchInstance = new BillingLDVCloneBatch(
                sourceIds,
                acctPeriod.Id,
                tempBilling.Date__c,
                isMultiCurrencyEnabled ? (String) tempBilling.get('CurrencyIsoCode') : null,
                makeCreditMemo
            );

            Database.executeBatch(batchInstance);
            disableCloneButton = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, Label.INF_LDV_CLONE_W_LINES));
            return null;
        }

        else{
            // setup the save point for rollback
            Savepoint sp = Database.setSavepoint();

            try {
                Billing__c bill = queryBilling();

                cloneBilling = bill.clone(false);
                cloneBilling.Date__c = tempBilling.Date__c;
                cloneBilling.Accounting_Period__c = acctPeriod.Id;

                if (isMultiCurrencyEnabled) {
                    cloneBilling.put('CurrencyIsoCode', tempBilling.get('CurrencyIsoCode'));
                }

                //Insert the new Billing record
                SFDCSecurityUtils.insertCheckCRUDAndFLS(
                    cloneBilling,
                    new List<String>(billingFields)
                );
                
                newBillLines = new List<Billing_Line__c>();

                for (Billing_Line__c bl : queryBillingLines()) {
                    Billing_Line__c newBillLine = bl.clone(false);
                    newBillLine.Date__c = tempBilling.Date__c;
                    newBillLine.Billing__c = cloneBilling.Id;
                    newBillLine.Rate__c = getAmount(bl);
                    newBillLine.Hours_Units__c = getQuantity(bl);
                    newBillLines.add(newBillLine);
                }

                //Insert the new Billing Line records
                SFDCSecurityUtils.insertCheckCRUDAndFLS(
                    newBillLines,
                    new List<String>(billingLineFields)
                );

                theNewBillingId = cloneBilling.Id;
            }
            catch (Exception e) {
                isError = true;
                Database.rollback(sp);
                ApexPages.addMessages(e);
                return NULL;
            }

            return new PageReference(FinancialSuiteUtils.getRedirectToSObjectURL(theNewBillingId, Billing__c.SObjectType, true));

        }
        
    }

    private Decimal getAmount(Billing_Line__c bl) {
        return makeCreditMemo && AccountingSettingsHandler.isCreditMemoDefaultAmount() ? bl.Rate__c * -1 : bl.Rate__c;
    }

    private Decimal getQuantity(Billing_Line__c bl) {
        return makeCreditMemo && AccountingSettingsHandler.isCreditMemoDefaultQuantity() ? bl.Hours_Units__c * -1 : bl.Hours_Units__c;
    }

    private Billing__c queryBilling() {
        //=== Build SOQL query with CRUD checks ===

        //add required fields to the list regardless of what is included in fieldset
        billingFields.add(PACKAGE_QUALIFIER + 'Customer__c');

        //Add query condition
        String queryCondition = 'Id = :billId LIMIT 1';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(new List<String>(billingFields))
            .setCondition(queryCondition);

        return (Billing__c) Database.query(theQuery.toSOQL());
    }

    private List<Billing_Line__c> queryBillingLines() {
        //=== Build SOQL query with CRUD checks ===

        //add required fields forcefully in case user doesn't include them in fieldset
        billingLineFields.add(PACKAGE_QUALIFIER + 'Rate__c');
        billingLineFields.add(PACKAGE_QUALIFIER + 'Hours_Units__c');

        //Add query condition
        String queryCondition = 'Billing__c = :billId ORDER BY Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(new List<String>(billingLineFields))
            .setCondition(queryCondition);

        return (List<Billing_Line__c>) Database.query(theQuery.toSOQL());
    }

}