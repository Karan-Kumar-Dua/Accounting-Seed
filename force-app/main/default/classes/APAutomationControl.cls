public with sharing class APAutomationControl implements AccessControlInterface{ 
 
    public Boolean isFeatureEnabled(){ 
        return FeatureManagementHandler.isPaymentServiceEnabled(); 
    } 
 
    public Set<SObjectType> getSObjectsGrants(){ 
 
        return new Set<Schema.SObjectType>{ 
            Payment_Proposal__c.SObjectType, 
            Bank_Account__c.SObjectType,
            Bank_Disbursement__c.SObjectType
        };
    } 
 
    public Map<Schema.SobjectType, List<Schema.SObjectField>> getFieldGrants() { 
        return new Map<Schema.SObjectType, List<Schema.SObjectField>>{ 
            Account.SObjectType => getAccountFields(), 
            Account_Payable__c.SObjectType => getPayableFields(), 
            Ledger__c.SObjectType => getLedgerFields(),
            Cash_Disbursement__c.sObjectType => getCashDisbursementFields(),
            AcctSeed__Bank_Account__c.SObjectType => getBankAccountFields()
        };
    } 
    
    public String getFieldLabels(List<Schema.SObjectField> fields) {
        String fldLabel = '';
        for (Schema.SObjectField fld : fields !=null ? fields : new List<Schema.SObjectField>()) { 
            Schema.DescribeFieldResult dfr = fld.getDescribe();
            fldLabel += dfr.getLabel() + ', ';
        }
        return fldLabel.removeEnd(', ');
    }
 
    private List<Schema.SObjectField> getAccountFields(){ 
        return new List<Schema.SObjectField>{ 
                Account.Payment_Services_Enrollment_Status__c,
                Account.Payment_Services_Vendor_ID__c,
                Account.Last_Payment_Services_Sync_Date__c,
                Account.Enable_Payment_Services__c 
        }; 
    } 
 
 
    private List<Schema.SObjectField> getPayableFields(){ 
        return new List<Schema.SObjectField>{ 
            Account_Payable__c.Payment_Services_Eligible__c,
            Account_Payable__c.AS_Pay_Type__c 
        }; 
    } 
 
    private List<Schema.SObjectField> getLedgerFields(){ 
        return new List<Schema.SObjectField>{ 
            Ledger__c.Enrolled_In_Payment_Services__c, 
            Ledger__c.Payment_Services_Company_Code__c,
            Ledger__c.Payment_Notifications_Email__c, 
            Ledger__c.Payment_Withdrawal_Method__c
        }; 
    }

    private List<Schema.SObjectField> getCashDisbursementFields(){
        return new List<Schema.SObjectField>{ 
            Cash_Disbursement__c.Payment_Service_Status__c, 
            Cash_Disbursement__c.Payment_Service_Status_Note__c,
            Cash_Disbursement__c.AS_Pay_Type__c
        }; 
    }

    private List<Schema.SObjectField> getBankAccountFields(){
        return new List<Schema.SObjectField>{
                AcctSeed__Bank_Account__c.AcctSeed__Enable_for_Payment_Services__c,
                AcctSeed__Bank_Account__c.AcctSeed__Payment_Services_Bank_Account_ID__c,
                AcctSeed__Bank_Account__c.AcctSeed__Payment_Services_Enrollment_Status__c
        };
    }
}