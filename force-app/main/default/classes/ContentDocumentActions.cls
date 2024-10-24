public with sharing class ContentDocumentActions {

    private static List<ContentVersion> queryContentVersions(Set<Id> contentDocumentIds) {
        List<String> queryFields = new List<String>{
            'Id',
            'ExtId__c'
        };

        String queryCondition = 'ContentDocumentId IN :contentDocumentIds';

        SOQLBuilder theQuery = new SOQLBuilder(ContentVersion.SObjectType);
        theQuery
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<ContentVersion>) Database.query(theQuery.toSOQL());
    }

    public static void beforeDeleteHandler(Map<Id,ContentDocument> oldMap){

        List<String> listOfCvExternalIds = new List<String>();
        List<Bank_Account__c> listOfBankAccountsToUpdate = new List<Bank_Account__c>();
        
        List<ContentVersion> contentVersions = queryContentVersions(oldMap.keySet());
        
        for(ContentVersion cvRec : contentVersions){
            listOfCvExternalIds.add(cvRec.ExtId__c);
        }

        if(!listOfCvExternalIds.isEmpty()){
            List<String> queryFields = new List<String>{
                'Id',
                'Signature_Block__c',
                'Signature_Block_2__c'
            };
    
            String queryCondition = 'Signature_Block__c IN : listOfCvExternalIds OR Signature_Block_2__c IN : listOfCvExternalIds';
    
            SOQLBuilder theQuery = new SOQLBuilder(Bank_Account__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);
    
            List<Bank_Account__c> listOfBankAccounts = (List<Bank_Account__c>) Database.query(theQuery.toSOQL());

            if(!listOfBankAccounts.isEmpty()){
                for(Bank_Account__c bankAccount : listOfBankAccounts){
                    if(listOfCvExternalIds.contains(bankAccount.Signature_Block__c)){
                        bankAccount.Signature_Block__c = NULL;
                    }
                    if(listOfCvExternalIds.contains(bankAccount.Signature_Block_2__c)){
                        bankAccount.Signature_Block_2__c = NULL;
                    }
                    listOfBankAccountsToUpdate.add(bankAccount);
                }
        
                SFDCSecurityUtils.updateCheckCRUDAndFLS(listOfBankAccountsToUpdate, new List<String>{'Signature_Block__c', 'Signature_Block_2__c'});
            }
        } 
    }
}