public with sharing class APAutomationUpdateControl implements AccessControlInterface{
    
    public Boolean isFeatureEnabled(){ 
        return FeatureManagementHandler.isPaymentServiceEnabled(); 
    } 
 
    public Set<SObjectType> getSObjectsGrants(){ 
 
        return null;
    } 
 
    public Map<Schema.SobjectType, List<Schema.SObjectField>> getFieldGrants() { 
        return new Map<Schema.SObjectType, List<Schema.SObjectField>>{
            Account.SObjectType => getAccountFields(),  
            Ledger__c.SObjectType => getLedgerFields(),
            Bank_Account__c.SobjectType => getBankAccountFields(),
            Contact.SobjectType => getContactFields(),
            Payment_Method__c.SobjectType => getPaymentMethodFields()
        };
    }

    public String getFieldLabels(List<Schema.SObjectField> fields) {
        return new APAutomationControl().getFieldLabels(fields);
    }

    private List<Schema.SObjectField> getAccountFields(){ 
        return new List<Schema.SObjectField>{ 
                Account.Taxpayer_Identification_Number__c,
                Account.Industry,
                Account.Sic,
                Account.AS_Pay_Type__c,
                Account.Fax,
                Account.Enable_Payment_Services__c,
                Account.Description,
                Account.Name,
                Account.Billing_Contact__c,
                Account.AP_Vendor_Email__c,
                Account.BillingStreet,
                Account.BillingCity,
                Account.BillingState,
                Account.BillingCountry,
                Account.BillingPostalCode,
                Account.Individual__c
            }; 
    }
    
    private List<Schema.SObjectField> getLedgerFields(){ 
        return new List<Schema.SObjectField>{ 
            Ledger__c.TIN__c, 
            Ledger__c.Payment_Services_Company_Code__c,
            Ledger__c.Payment_Notifications_Email__c,
            Ledger__c.Address__c,
            Ledger__c.Name,
            Ledger__c.Sales_Tax_Company_Code__c,
            Ledger__c.Payment_Withdrawal_Method__c,
            Ledger__c.Logo__c,
            Ledger__c.Enrolled_in_Payment_Services__c,
            Ledger__c.Default_Payment_Processor__c        
        }; 
    }

    private List<Schema.SObjectField> getBankAccountFields(){ 
        return new List<Schema.SObjectField>{ 
            Bank_Account__c.Account_Type__c, 
            Bank_Account__c.Name,
            Bank_Account__c.Routing_Number__c, 
            Bank_Account__c.Payor_Email__c,
            Bank_Account__c.Account_Number__c,
            Bank_Account__c.Signature_Block__c,
            Bank_Account__c.Bank_Fraction__c,
            Bank_Account__c.Enable_for_Payment_Services__c,
            Bank_Account__c.Payor_Email__c,
            Bank_Account__c.Payor_Name__c,
            Bank_Account__c.Payment_Services_Bank_Account_ID__c
        };
    }

    private List<Schema.SObjectField> getContactFields(){ 
        return new List<Schema.SObjectField>{ 
            Contact.Email,
            Contact.AccountId
        };
    }

    private List<Schema.SObjectField> getPaymentMethodFields(){ 
        return new List<Schema.SObjectField>{ 
            Payment_Method__c.Account_Number__c,
            Payment_Method__c.Default__c,
            Payment_Method__c.Routing_Number__c
        };
    }

}