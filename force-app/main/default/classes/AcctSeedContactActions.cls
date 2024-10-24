public with sharing class AcctSeedContactActions {
    public static void  apAutomationPostMessage(Map<Id,Contact> newContactsMap, Map<Id,Contact> oldContactsMap) {
        if(FeatureManagementHandler.isPaymentServiceEnabled()){
            List<Id> contactIdsToCreateVendor = new List<Id>();
            List<Id> contactIdsToUpdateVendor = new List<Id>();
            List<Contact> contactsRecords = new List<Contact>();
            
            contactsRecords = queryContacts(newContactsMap.keySet());

            for(Contact con : contactsRecords){
                if(Trigger.isInsert && con.Account.Enable_Payment_Services__c ) {
                        contactIdsToCreateVendor.add(con.AccountId);
                    }   
                    else if(Trigger.isUpdate){ 
                        UpdateControlService updateService = new UpdateControlService(new APAutomationUpdateControl(), Contact.SObjectType);
                        if(((con.Account.Enable_Payment_Services__c && updateService.checkUpdateFieldChanges()))){
                            contactIdsToUpdateVendor.add(con.AccountId);
                        }
                    }
                }

            if(!contactIdsToCreateVendor.isEmpty()) {
                APAutomationService.postMessage(contactIdsToCreateVendor, APAutomationService.APAutomationActions.CREATE_VENDOR.name());
            }

            if(!contactIdsToUpdateVendor.isEmpty()) {
                APAutomationService.postMessage(contactIdsToUpdateVendor, APAutomationService.APAutomationActions.UPDATE_VENDOR.name());
            }
        }
    }

    private static List<Contact> queryContacts(Set<Id> contactIds) {
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Account.AcctSeed__Enable_Payment_Services__c',
            'Email'
        };
        //Add query condition
        String queryCondition = 'Id IN: contactIds AND Email != NULL ' ;
    
        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Contact.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }

}