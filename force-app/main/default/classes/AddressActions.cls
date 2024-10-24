public with sharing class AddressActions {
    
    //Method to post message to CSI
    public static void  apAutomationPostMessage(List<Address__c> addresses, Map<Id,Address__c> oldAddressMap) {
        Map<String,List<Id>> addressIds = new Map<String,List<Id>>();
        
        List<Schema.SObjectField> bankAccountToAddressFields = new List<Schema.SObjectField>{
            Address__c.City__c,
            Address__c.State_Province__c,
            Address__c.Street__c,
            Address__c.Postal_Code__c
        };
        List<Schema.SObjectField> ledgerToAddressFields = new List<Schema.SObjectField>{
            Address__c.Country_Code__c,
            Address__c.State_Province__c,
            Address__c.Street__c,
            Address__c.Postal_Code__c,
            Address__c.AcctSeed__City__c
        };

        for(Address__c addrs : addresses) {
            if(bankAndLedgerToAddressFieldChanges(bankAccountToAddressFields)){
                if(addressIds.containsKey('bankAccount')){
                    addressIds.get('bankAccount').add(addrs.Id);
                }else{
                    addressIds.put('bankAccount', new List<Id>{addrs.Id});
                }
            }

            if(bankAndLedgerToAddressFieldChanges(ledgerToAddressFields)){
                if(addressIds.containsKey('ledger')){
                    addressIds.get('ledger').add(addrs.Id);
                }else{
                    addressIds.put('ledger', new List<Id>{addrs.Id});
                }
            }
        }

        PostMsgToRespectiveQueues(addressIds);
    }

    private static Boolean bankAndLedgerToAddressFieldChanges(List<Schema.SObjectField> fieldSet) {
        AccessControlService accessControl = new AccessControlService(fieldSet);                                                       
        return accessControl.isUpdateFieldsChanged();
    }

    private static void PostMsgToRespectiveQueues(Map<String,List<Id>> bankAndLedgerToAddressIds){
         
        if(bankAndLedgerToAddressIds.get('bankAccount') != null && !bankAndLedgerToAddressIds.get('bankAccount').isEmpty()){
            List<Id> bankToAddrssId = bankAndLedgerToAddressIds.get('bankAccount');
            List<String> queryFields = new List<String>{'Id'};
            List<String> subQueryFields = new List<String>{'Id'};

            String subQueryRelationshipName = 'AcctSeed__Bank_Accounts__r';
            String subQueryCondition = 'Enable_for_Payment_Services__c=true';

            SOQLBuilder theQuery = new SOQLBuilder(Address__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition('ID IN:bankToAddrssId')
                .subselectQuery(subQueryRelationshipName, true)
                .setEnforceFLS(true)
                .selectFields(subQueryFields)
                .setCondition(subQueryCondition);

            List<Bank_Account__c> bankAccounts = new List<Bank_Account__c>();
            List<Id> bankAccountIds = new List<Id>();

            //There can be a chances when specific ledger has a more than 50,000 records then we need to process it asynchronously
            for(Address__c addr: (List<Address__c>) Database.query(theQuery.toSOQL()))
            {
                bankAccounts.addAll(addr.Bank_Accounts__r); 

            }

            for(Bank_Account__c bankAcc: bankAccounts){
                bankAccountIds.add(bankAcc.Id);
            }
            
            // if list of bank Account id is empty then do not call SQS service class to post UPDATE_Bank_Account message
            if(!bankAccountIds.isEmpty()) {
                APAutomationService.postMessage(bankAccountIds, APAutomationService.APAutomationActions.UPDATE_BANK_ACCOUNT.name());
            }
        }

        if(bankAndLedgerToAddressIds.get('ledger') != null && !bankAndLedgerToAddressIds.get('ledger').isEmpty()){
            List<Id> ledgerIdss = bankAndLedgerToAddressIds.get('ledger');
            List<String> queryFields = new List<String>{'Id'};
            List<String> subQueryFields = new List<String>{'Id'};

            String subQueryRelationshipName = 'AcctSeed__Ledgers__r';
            String subQueryCondition = 'Enrolled_in_Payment_Services__c=true AND Payment_Services_Company_Code__c != NULL';

            SOQLBuilder theQuery = new SOQLBuilder(Address__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition('ID IN:ledgerIdss')
                .subselectQuery(subQueryRelationshipName, true)
                .setEnforceFLS(true)
                .selectFields(subQueryFields)
                .setCondition(subQueryCondition);

            List<Ledger__c> ledgers = new List<Ledger__c>();
            List<Id> ledgerIds = new List<Id>();

            //There can be a chances when specific ledger has a more than 50,000 records then we need to process it asynchronously
            for(Address__c adds: (List<Address__c>) Database.query(theQuery.toSOQL()))
            {
                ledgers.addAll(adds.Ledgers__r); 

            }

            for(Ledger__c ldg: ledgers){
                ledgerIds.add(ldg.Id);
            }
            
            // if list of bank Account id is empty then do not call SQS service class to post UPDATE_Bank_Account message
            if(!ledgerIds.isEmpty()) {
                APAutomationService.postMessage(ledgerIds, APAutomationService.APAutomationActions.UPDATE_COMPANY.name());
            }
        }

    }

}