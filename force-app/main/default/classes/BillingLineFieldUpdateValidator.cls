public with sharing class BillingLineFieldUpdateValidator extends SourceDocumentUpdateFieldValidator {

    public Map<Id, Billing__c> parentBillingsMap = new Map<Id, Billing__c>();

    public Set<SObjectField> lockedUpdateFieldsLockedAvataxBilling = new Set<SObjectField> {
        Billing_Line__c.Product__c,
        Billing_Line__c.Hours_Units__c,
        Billing_Line__c.Rate__c,
        Billing_Line__c.Tax_Amount2__c
    };

    public Set<SObjectField> lockedUpdateFieldsAppliedBillingLine {
        get {
            lockedUpdateFieldsAppliedBillingLine = new Set<SObjectField> {
                Billing_Line__c.Product__c,
                Billing_Line__c.Hours_Units__c,
                Billing_Line__c.Rate__c,
                Billing_Line__c.Tax_Amount2__c
            };
            return lockedUpdateFieldsAppliedBillingLine;
        }
        private set;
    }

    public Set<SObjectField> lockedUpdateFieldsPostedBillingLine = new Set<SObjectField> {
        Billing_Line__c.Date__c,
        Billing_Line__c.Hours_Units__c,
        Billing_Line__c.Rate__c,
        Billing_Line__c.Revenue_GL_Account__c,
        Billing_Line__c.Expense_GL_Account__c,
        Billing_Line__c.Inventory_GL_Account__c,
        Billing_Line__c.Employee__c,
        Billing_Line__c.Project__c,
        Billing_Line__c.Project_Task__c,
        Billing_Line__c.Product__c,
        Billing_Line__c.Product_Unit_Cost__c,
        Billing_Line__c.Time_Card_Variable_1__c,
        Billing_Line__c.Time_Card_Variable_2__c,
        Billing_Line__c.GL_Account_Variable_1__c,
        Billing_Line__c.GL_Account_Variable_2__c,
        Billing_Line__c.GL_Account_Variable_3__c,
        Billing_Line__c.GL_Account_Variable_4__c,
        Billing_Line__c.Tax_Amount2__c,
        Billing_Line__c.Tax_Group__c,
        Billing_Line__c.Line_Destination_Address_Override__c,
        Billing_Line__c.Line_Origin_Address_Override__c
    };

    public SObjectField statusFieldName = Billing_Line__c.Parent_Status__c;
    public SObjectField taxLineFieldName = Billing_Line__c.Tax_Line__c;

    public BillingLineFieldUpdateValidator() {
        statusField = statusFieldName;
        taxLineField = taxLineFieldName;
        lockedUpdateFieldsPosted = lockedUpdateFieldsPostedBillingLine;
        lockedUpdateFieldsApplied = lockedUpdateFieldsAppliedBillingLine;
        lockedUpdateFieldsCustomSet = lockedUpdateFieldsLockedAvataxBilling;
        customValidationErrorMsg = Label.ERR_UPDATE_AVATAX_LOCKED;
        skipDeleteValidationFlags = new List<Boolean> {
            AccountingPeriodActions.isDelarcInProgress,
            (BillingLineActions.isLDVSourceBatchInProgress && FeatureManagementHandler.isLargeDataVolumeModeEnabled() && AccountingSettingsHandler.isLineLevelPost())
        };
    }

    public override void setValidationRules() {
        preventUpdateActionPosted();
        preventUpdateActionApplied();
        preventUpdateCustomAction();
        preventInsertActionPosted();
        preventDeleteActionPosted();
        if (!isTaxCalculationTransaction()) {
            preventInsertActionApplied();
            preventDeleteActionApplied();
        }
    }

    public override void setJunctionSObjectIds(Map<Id, SObject> oldObjectMap, Map<Id, SObject> newObjectMap) {
        Map<Id, SObject> tempMap = newObjectMap != NULL && !newObjectMap.isEmpty() ? newObjectMap : oldObjectMap;
        for (Billing_Line__c billLine : (List<Billing_Line__c>) tempMap.values()) {
            junctionSObjectIds.add(billLine.Billing__c);
        }
        parentBillingsMap = new Map<Id, Billing__c>(DomainUtils.getBillingsById(junctionSObjectIds));
    }

    public override Id getJunctionObjectId(SObject obj) {
        return ((Billing_Line__c) obj).Billing__c;
    }

    public override Boolean customValidationRules() {
        Boolean result = false;
        if (parentBillingsMap.containsKey(getJunctionObjectId(newObj)) && parentBillingsMap.get(getJunctionObjectId(newObj)).Locked_In_AvaTax__c) {
            result = true;
        }
        return result;
    }

    public override Boolean skipPostingStatusValidation(SObjectField field) {
        Boolean isSkip = false;
        if (!AccountingSettingsHandler.isHeaderLevelPost()
            && field == Billing_Line__c.Parent_Status__c
            && (String) newObj.get(Billing_Line__c.Parent_Status__c) == AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS) {
            isSkip = true;
        }
        return isSkip;
    }

}