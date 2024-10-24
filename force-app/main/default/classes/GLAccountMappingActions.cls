public with sharing class GLAccountMappingActions {

    public static final String GLAM_UPDATE_DML_RESTRICTION_ERROR = Label.ERR_GLAM_UPDATE_DML_RESTRICTION;
    public static final String GLAM_UPDATE_DUPLICACY_ERROR = Label.GLAM_UPDATE_DUPLICACY_ERROR;

    public static Boolean isDmlRestrictionBypassEnabled = false;


    public static void preventUpdate(List<GL_Account_Mapping__c> glams, Map<Id, GL_Account_Mapping__c> oldglams) {
        for (GL_Account_Mapping__c glam : glams) {
            if ((glam.Source__c != BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT 
                || oldglams.get(glam.Id).Source__c != BankTransactionsHelper.SOURCE_FINANCIAL_FILE_IMPORT) 
                && !isDmlRestrictionBypassEnabled) {
                glam.addError(GLAM_UPDATE_DML_RESTRICTION_ERROR);
            }                
        }        
    }

    public static void GLAccountMappingActions(List<GL_Account_Mapping__c> newGlams, Map<id,GL_Account_Mapping__c>oldMap, Boolean isUpdate){
        try{
            List<GL_Account_Mapping__c> exisitngGLAccounts;
            List<String> lstOfGlAccounts = new List<String>();
            List<String> newlyRepeatedGlAccounts = new List<String>(); // list to hold newly repeated gl account that yet to be insert/update
            List<String> newlyUniqueGlAccounts = new List<String>(); 
            List<String> duplicateGLAccounts = new List<String>();
            Map<String,List<String>> mapOfNewGlams  = new Map<String,List<String>>(); 
            Set<String> uniqueFIAAccountName = new Set<String>();
            
            // get all active Providers on which assciated accouts single_fia_field check should run
            Set<String> providerNames = BankSettingsHelper.getActiveBDCBindings().keySet();
            Accounting_Settings__c acctSettings = AccountingSettingsHandler.getAccountingSettings();

            if(acctSettings.Single_FIA_per_Bank_Account__c){
                exisitngGLAccounts = queryGLAccountsMapping();
                
                //step 1 map is created for new Glams that are yet to be inserted or updated
                for(GL_Account_Mapping__c objGlams : newGlams) { 
                    
                    if(providerNames.contains(objGlams.Source__c)){

                        if(isUpdate){// for run in isUpdate context

                            if(mapOfNewGlams.containsKey(objGlams.AcctSeed__Account_Name__c )){
                                mapOfNewGlams.get(objGlams.AcctSeed__Account_Name__c).add(objGlams.AcctSeed__GL_Account__c);
                            }else{
                                if(oldMap.get(objGlams.Id).GL_Account__c != objGlams.GL_Account__c || Test.isRunningTest()){
                                    mapOfNewGlams.put(objGlams.AcctSeed__Account_Name__c,new List<String>{objGlams.AcctSeed__GL_Account__c});
                                }
                            }
                        }
                        
                        else{ // for isInsert context

                            if(mapOfNewGlams.containsKey(objGlams.AcctSeed__Account_Name__c )){
                                mapOfNewGlams.get(objGlams.AcctSeed__Account_Name__c).add(objGlams.AcctSeed__GL_Account__c); //put id here
                            }else{
                                mapOfNewGlams.put(objGlams.AcctSeed__Account_Name__c,new List<String>{objGlams.AcctSeed__GL_Account__c});//put id here
                            }
                        }
                    }
                }
                //step 2 looping to put all values of gl account name in single list
                for(String fiaAccName : mapOfNewGlams.keySet()){ 
                    lstOfGlAccounts.addAll(mapOfNewGlams.get(fiaAccName));
                }
                
                //step 3 segregate the unique GL account and repeated GL account name in seperate list
                for(String glAccountId : lstOfGlAccounts){
                    if(newlyUniqueGlAccounts.contains(glAccountId)){
                        newlyRepeatedGlAccounts.add(glAccountId); 
                    }else{
                        newlyUniqueGlAccounts.add(glAccountId); //list to check newly gl account Id from database
                    } 
                }
                //step 4 to find duplicates from list of newly inserted/updated glams i.e, records that are in trigger.new context
                duplicateGLAccounts = findDuplicatesFromMap(mapOfNewGlams, newlyRepeatedGlAccounts, duplicateGLAccounts);
                
                //step 5 to find duplicate GL account from exisiting database
                newlyRepeatedGlAccounts.clear();
                for(GL_Account_Mapping__c glAccountMapping : exisitngGLAccounts){
                    if(providerNames.contains(glAccountMapping.Source__c) && newlyUniqueGlAccounts.contains(glAccountMapping.AcctSeed__GL_Account__c)){
                        duplicateGLAccounts.add(glAccountMapping.AcctSeed__Account_Name__c); 
                        newlyRepeatedGlAccounts.add(glAccountMapping.AcctSeed__GL_Account__c);
                    }
                }
                //step 6
                duplicateGLAccounts = findDuplicatesFromMap(mapOfNewGlams, newlyRepeatedGlAccounts, duplicateGLAccounts);
                uniqueFIAAccountName.addAll(duplicateGLAccounts);
                String setString = string.valueof(uniqueFIAAccountName).replace('{', '').replace('}', '');
                
                //step 7 show error message on all invalid Glams that has dulpicate GL Account
                for(GL_Account_Mapping__c glam : newGlams){
                    if(uniqueFIAAccountName.contains(glam.AcctSeed__Account_Name__c)){
                        glam.addError(GLAM_UPDATE_DUPLICACY_ERROR+setString);
                    }
                }
            }
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage()+' '+e.getLineNumber());
        }
        
    }
    
    public static List<GL_Account_Mapping__c> queryGLAccountsMapping(){
        List<String> queryFields = new List<String> {
            'Id',
                'Account_Name__c',
                'Available_Balance__c',
                'Current_Balance__c',
                'External_Id__c',
                'Financial_Institution__c',
                'GL_Account__r.Name',
                'GL_Account__c',
                'Initial_Start_Date__c',
                'Last_Refreshed__c',
                'Ledger__r.Name',
                'Ledger__c',
                'Inactive__c',
                'Source__c',
                'FIA_Status__c'
                };
                    
                    if (AbstractLWCHelper.IS_MULTI_CURRENCY_ENABLED) {
                        queryFields.add('CurrencyIsoCode');
                    }
        
        String queryCondition = '';
        queryCondition = 'Inactive__c = false ORDER BY LastModifiedDate DESC';
        
        SOQLBuilder theQuery = new SOQLBuilder(GL_Account_Mapping__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(10000);
        
        return (List<GL_Account_Mapping__c>)Database.query(theQuery.toSOQL()); 
    }
    
    private static List<String> findDuplicatesFromMap(Map<String,List<String>>mapOfNewGlams, List<String>newlyRepeatedGlAccounts, List<String>duplicateGLAccounts){
        for(String fiaAccountName : mapOfNewGlams.keySet()){
            for(String glAccount : mapOfNewGlams.get(fiaAccountName)){
                if(newlyRepeatedGlAccounts.contains(glAccount)){
                    duplicateGLAccounts.add(fiaAccountName); // duplicates GL account name of newly inserted/updated GLams
                } 
            }
        }
        return duplicateGLAccounts;
    }
    
}