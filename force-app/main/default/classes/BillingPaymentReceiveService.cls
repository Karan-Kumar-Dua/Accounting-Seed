public with sharing class BillingPaymentReceiveService {
    
    public static Billing__c getFullBillings(String billingId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Customer__c',
            'Balance__c',
            'Total__c',
            'Type__c',
            'Received_Amount__c',
            'Discount_Due_Date__c',
            'Discount_Amount__c',
            'Customer__r.Stripe_Customer_Id__c',
            'Customer__r.Name',
            'Customer__r.GL_Account_Variable_1__c',
            'Customer__r.GL_Account_Variable_2__c',
            'Customer__r.GL_Account_Variable_3__c',
            'Customer__r.GL_Account_Variable_4__c',
            'Accounting_Period__c',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Default_Bank_Account__c',
            'Payment_Processor__r.CC_Flat_Fee__c', 
            'Payment_Processor__r.CC_Percent__c', 
            'Payment_Processor__r.Enable_Convenience_Fees__c', 
            'Payment_Processor__r.Credit_Card_Convenience_Fee_Type__c',
            'Payment_Processor__r.Convenience_Fees_GL_Account__c',
            'Sales_Tax3__c',
            'Sales_Tax2__c',
            'Sub_Total__c',
            'Payment_Processor__r.ACH_Flat_Fee__c',
            'Payment_Processor__r.ACH_Percent__c',
            'Payment_Processor__r.ACH_Convenience_Fee_Type__c'
        };

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition = 'Id = :billingId ';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true) 
            .selectFields(queryFields)
            .setCondition(queryCondition);

        List<Billing__c> results = (List<Billing__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }
    public static List<GL_Account__c> getAdjustMentGlAccounts() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Type__c',
            'Bank__c',
            'Sub_Type_1__c',
            'Sub_Type_2__c'
        };
        String queryCondition = 'Bank__c = true ORDER BY Name ASC';

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(5000);

        return (List<GL_Account__c>) Database.query(theQuery.toSOQL());
    }
}