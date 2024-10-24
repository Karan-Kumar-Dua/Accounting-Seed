public with sharing class OpportunityLineItemActions {
    
    public static void associateDefaultProductFields(OpportunityLineItem[] oppLines) {
        Map<Id, Product2> productMap = new Map<Id, Product2>();
        Map<Id, Account> oppIdToAccount = new Map<Id, Account>();
        
        for (OpportunityLineItem oli : oppLines) { 
            if (oli.Product2Id != NULL) {
                productMap.put(oli.Product2Id, NULL);
            }

            if (oli.OpportunityId != NULL) {
                oppIdToAccount.put(oli.OpportunityId, NULL);
            }
        }
 
        for (Product2 prod : DomainUtils.getProductsById(productMap.keySet())) {
            productMap.put(prod.Id, prod);
        }

        for (Opportunity opp : DomainUtils.getOpportunityById(oppIdToAccount.keySet())) {

            Account tempAccount = new Account(
                Id = opp.AccountId,
                GL_Account_Variable_1__c = opp.Account.GL_Account_Variable_1__c,
                GL_Account_Variable_2__c = opp.Account.GL_Account_Variable_2__c,
                GL_Account_Variable_3__c = opp.Account.GL_Account_Variable_3__c,
                GL_Account_Variable_4__c = opp.Account.GL_Account_Variable_4__c
            );

            if (tempAccount.Id != NULL) {
                oppIdToAccount.put(opp.Id, tempAccount);
            }

        }
                
        for (OpportunityLineItem oli : oppLines) {
            
            if (oli.GL_Account_Variable_1__c == NULL) {
                if (canTakeDefaultGLAVFromAccount(oli, 1, oppIdToAccount)) {
                    oli.GL_Account_Variable_1__c = oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_1__c;
                }
                else if (canTakeDefaultGLAVFromProduct(oli, 1, productMap)) {
                    oli.GL_Account_Variable_1__c = productMap.get(oli.Product2Id).GL_Account_Variable_1__c;
                }
            }

            if (oli.GL_Account_Variable_2__c == NULL) {
                if (canTakeDefaultGLAVFromAccount(oli, 2, oppIdToAccount)) {
                    oli.GL_Account_Variable_2__c = oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_2__c;
                }
                else if (canTakeDefaultGLAVFromProduct(oli, 2, productMap)) {
                    oli.GL_Account_Variable_2__c = productMap.get(oli.Product2Id).GL_Account_Variable_2__c;
                }
            }

            if (oli.GL_Account_Variable_3__c == NULL) {
                if (canTakeDefaultGLAVFromAccount(oli, 3, oppIdToAccount)) {
                    oli.GL_Account_Variable_3__c = oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_3__c;
                }
                else if (canTakeDefaultGLAVFromProduct(oli, 3, productMap)) {
                    oli.GL_Account_Variable_3__c = productMap.get(oli.Product2Id).GL_Account_Variable_3__c;
                }
            }

            if (oli.GL_Account_Variable_4__c == NULL) {
                if (canTakeDefaultGLAVFromAccount(oli, 4, oppIdToAccount)) {
                    oli.GL_Account_Variable_4__c = oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_4__c;
                }
                else if (canTakeDefaultGLAVFromProduct(oli, 4, productMap)) {
                    oli.GL_Account_Variable_4__c = productMap.get(oli.Product2Id).GL_Account_Variable_4__c;
                }
            }           
            
        }

    }


    private static Boolean canTakeDefaultGLAVFromProduct(OpportunityLineItem oli, Integer glavNumber, Map<Id, Product2> productMap) {
        Boolean result = false;
        if (glavNumber == 1) {
            result = oli.Product2Id != NULL 
                && productMap.containsKey(oli.Product2Id) 
                && productMap.get(oli.Product2Id).GL_Account_Variable_1__c != NULL;
        }
        if (glavNumber == 2) {
            result = oli.Product2Id != NULL 
                && productMap.containsKey(oli.Product2Id) 
                && productMap.get(oli.Product2Id).GL_Account_Variable_2__c != NULL;
        }
        if (glavNumber == 3) {
            result = oli.Product2Id != NULL 
                && productMap.containsKey(oli.Product2Id) 
                && productMap.get(oli.Product2Id).GL_Account_Variable_3__c != NULL;
        }
        if (glavNumber == 4) {
            result = oli.Product2Id != NULL 
                && productMap.containsKey(oli.Product2Id) 
                && productMap.get(oli.Product2Id).GL_Account_Variable_4__c != NULL;
        }
        return result;
    }

    private static Boolean canTakeDefaultGLAVFromAccount(OpportunityLineItem oli, Integer glavNumber, Map<Id, Account> oppIdToAccount) {
        Boolean result = false;
        if (glavNumber == 1) {
            result = oppIdToAccount.containsKey(oli.OpportunityId)
                && oppIdToAccount.get(oli.OpportunityId) != NULL
                && oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_1__c != NULL;
        }
        if (glavNumber == 2) {
            result = oppIdToAccount.containsKey(oli.OpportunityId)
                && oppIdToAccount.get(oli.OpportunityId) != NULL
                && oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_2__c != NULL;
        }
        if (glavNumber == 3) {
            result = oppIdToAccount.containsKey(oli.OpportunityId)
                && oppIdToAccount.get(oli.OpportunityId) != NULL 
                && oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_3__c != NULL;
        }
        if (glavNumber == 4) {
            result = oppIdToAccount.containsKey(oli.OpportunityId)
                && oppIdToAccount.get(oli.OpportunityId) != NULL
                && oppIdToAccount.get(oli.OpportunityId).GL_Account_Variable_4__c != NULL;
        }
        return result;
    }

}