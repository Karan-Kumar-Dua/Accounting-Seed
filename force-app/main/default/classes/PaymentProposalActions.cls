public with sharing class PaymentProposalActions {

    private static final String ERROR_PPL_CREDIT_MEMO_ON_PP = Label.ERROR_PPL_CREDIT_MEMO_ON_PP;
    private static final String COMMON_CREDIT_MEMO = Label.COMMON_CREDIT_MEMO;
    private static final String ERROR_INVALID_CURRENCYISOCODE_PAYMENTPROPOSAL = Label.ERROR_INVALID_CURRENCYISOCODE_PAYMENTPROPOSAL;
    private static final String AS_PAY_TYPE = 'AS Pay';
    private static final String PAYMENT_SERVICE_ENROLLED_STATUS = 'Enrolled';

    
    public static void checkFeatureParameterObjectLevelAccess(){
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), Payment_Proposal__c.SObjectType);
        controlService.checkObjectGrant();
    }

    public static void validateCurrencyISOCode(List<Payment_Proposal__c> paymentProposals, Map<Id, Payment_Proposal__c> oldMapPaymentProposals){
        Boolean multiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        for (Payment_Proposal__c paymentProposal : paymentProposals){
            if (paymentProposal.Type__c == 'AS Pay' && ((multiCurrencyEnabled && paymentProposal.get('CurrencyISOCode') != 'USD') || (!multiCurrencyEnabled && UserInfo.getDefaultCurrency() != 'USD'))){
                paymentProposal.addError(ERROR_INVALID_CURRENCYISOCODE_PAYMENTPROPOSAL);
            }
        }
    }

    public static void validateValueForDateTypeField(List<Payment_Proposal__c> paymentProposals){
        for(Payment_Proposal__c ppRecord : paymentProposals){
            if(ppRecord.Relative_Due_Date_Number_n__c == NULL && ppRecord.Relative_Due_Date__c != null && ppRecord.Relative_Due_Date__c.contains(' n ')){
                ppRecord.Relative_Due_Date_Number_n__c.addError(Label.INVALID_RELATIVE_DUE_DATE_NUMBER);
            }else if(ppRecord.Relative_Early_Pay_Date_Number_n__c == NULL && ppRecord.Relative_Early_Pay_Date__c != null && ppRecord.Relative_Early_Pay_Date__c.contains(' n ')){
                ppRecord.Relative_Early_Pay_Date_Number_n__c.addError(Label.INVALID_RELATIVE_EARLY_PAY_DATE_NUMBER);
            }else if(ppRecord.Relative_Issue_Date_Number_n__c == NULL && ppRecord.Relative_Issue_Date__c != null && ppRecord.Relative_Issue_Date__c.contains(' n ')){
                ppRecord.Relative_Issue_Date_Number_n__c.addError(Label.INVALID_RELATIVE_ISSUE_PAY_DATE_NUMBER);
            }else if(ppRecord.Payment_Proposal_Date__c == NULL && (ppRecord.Relative_Due_Date__c != null || ppRecord.Relative_Early_Pay_Date__c != null || ppRecord.Relative_Issue_Date__c != null)){
                ppRecord.Payment_Proposal_Date__c.addError(Label.ERR_PP_DATE_IS_REQUIRED);
            }
        }
    }

    //Method to insert  or delete parent PPL and update PPL with Parent
    public static void insertOrDeleteParentPPL(List<Payment_Proposal__c> paymentProposals, Map<Id, Payment_Proposal__c> oldMapPaymentProposals){
        
        Set<Id> ppIdsForUnCheckedAP = new Set<Id>();
        Set<Id> ppIdsForCheckedAP = new Set<Id>();
        Map<Id, Payment_Proposal_Line__c> pplToDelete = new Map<Id, Payment_Proposal_Line__c>();
        List<Payment_Proposal_Line__c> pplToUpdate = new List<Payment_Proposal_Line__c>();
        Map<Id,Payment_Proposal_Line__c> mapOfvendorIdWithPPL = new Map<Id,Payment_Proposal_Line__c>();
        
        //Check or Uncheck aggregate by payee
        for(Payment_Proposal__c pp : paymentProposals) {
            if(pp.Aggregate_by_Payee__c == false && oldMapPaymentProposals.get(pp.Id).Aggregate_by_Payee__c == true) {
                ppIdsForUnCheckedAP.add(pp.Id);
            }
            if(pp.Aggregate_by_Payee__c == true && oldMapPaymentProposals.get(pp.Id).Aggregate_by_Payee__c == false) {
                ppIdsForCheckedAP.add(pp.Id);
            }
        }

        // If payment proposal (aggregate by payee is unchecked)
        if(!ppIdsForUnCheckedAP.isEmpty()) {
            
            Map<Id, Payment_Proposal_Line__c> mapOfppls = new Map<Id, Payment_Proposal_Line__c>(queryPaymentProposalLines(ppIdsForUnCheckedAP));
            for(Id pplId : mapOfppls.keySet()) {
                
                //Map to accomodate all parent PPL's
                if(!pplToDelete.containsKey(mapOfppls.get(pplId).Parent__c) && mapOfppls.get(pplId).Parent__c != NULL) {
                    pplToDelete.put(mapOfppls.get(pplId).Parent__c,mapOfppls.get(mapOfppls.get(pplId).Parent__c));
                }

                //List to update PPL's parent to null
                if(!pplToDelete.containsKey(pplId) && mapOfppls.get(pplId).Parent__c != NULL) {
                    pplToUpdate.add(new Payment_Proposal_Line__c(
                        Id = pplId,
                        Parent__c = null
                    ));
                }
            }
        }

        // If payment proposal (aggregate by payee is checked)
        if(!ppIdsForCheckedAP.isEmpty()) {

            List<Payment_Proposal_Line__c> pplLines = queryPaymentProposalLines(ppIdsForCheckedAP);
            
            //create all parent PPL's
            for(Payment_Proposal_Line__c pplLine : pplLines) {
                if(!mapOfvendorIdWithPPL.containsKey(pplLine.Vendor__c)) {

                    mapOfvendorIdWithPPL.put(pplLine.Vendor__c,new Payment_Proposal_Line__c(
                        Vendor__c = pplLine.Vendor__c,
                        Payment_Proposal__c = pplLine.Payment_Proposal__c
                    ));
                }
            }

             //insert parent PPL's and update PPl's with parent field
            if(!mapOfvendorIdWithPPL.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(mapOfvendorIdWithPPL.values(), new List<String>{'Vendor__c', 'Payment_Proposal__c'});
    
                for(Payment_Proposal_Line__c pplLine : pplLines) {
                    pplToUpdate.add(new Payment_Proposal_Line__c(
                        Id = pplLine.Id,
                        Parent__c = mapOfvendorIdWithPPL.get(pplLine.Vendor__c).Id
                    ));
                }
            }
        }

        //update PPl's with parent field
        if(!pplToUpdate.isEmpty()) {
            SFDCSecurityUtils.updateCheckCRUDAndFLS(pplToUpdate, new List<String>{'Parent__c'});
        }

        //delete parent PPl's 
        if(!pplToDelete.isEmpty()) {
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(pplToDelete.values());
        }
    }

    private static List<Payment_Proposal_Line__c> queryPaymentProposalLines(Set<Id> paymentProposalIds) {

        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Parent__c',
            'Vendor__c',
            'Payment_Proposal__c',
            'Payable__r.Type__c'
        };

     
        //Add query condition
        String queryCondition = 'Payment_Proposal__c = :paymentProposalIds';
       
        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Payment_Proposal_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        //Call DML operation
        return Database.query(theQuery.toSOQL());

    }

    //Method to prevent Payable Credit Memos on a Payment Proposal where Aggregate By Payee = FALSE
    public static void validatePayableCreditMemo(List<Payment_Proposal__c> paymentProposals,Map<Id, Payment_Proposal__c> oldMapPaymentProposals) {
        
        Set<Id> ppIds = new Set<Id>();

        //If aggregate By payee change
        for(Payment_Proposal__c pp : paymentProposals) {
            if(pp.Aggregate_by_Payee__c == false && oldMapPaymentProposals.get(pp.Id).Aggregate_by_Payee__c == true) {
                ppIds.add(pp.Id);
            }
        }

        if(!ppIds.isEmpty()) {
            Set<Id> ppIdHavingPPLWithCreditMemo = new Set<Id>();
            for(Payment_Proposal_Line__c ppl : queryPaymentProposalLines(ppIds)) {
                if(ppl.Payable__r.Type__c == COMMON_CREDIT_MEMO && !ppIdHavingPPLWithCreditMemo.contains(ppl.Payment_Proposal__c)) {
                    ppIdHavingPPLWithCreditMemo.add(ppl.Payment_Proposal__c);
                }
            }

            //Prevent record creation if PP is having credit memo PPL
            if(!ppIdHavingPPLWithCreditMemo.isEmpty()) {
                for(Payment_Proposal__c pp : paymentProposals) {
                    if(pp.Aggregate_by_Payee__c == false && oldMapPaymentProposals.get(pp.Id).Aggregate_by_Payee__c == true && ppIdHavingPPLWithCreditMemo.contains(pp.Id)) {
                        pp.addError(ERROR_PPL_CREDIT_MEMO_ON_PP);
                    }
                }
            }
        }     
    }
    
    public static void validateCurrencyCodeUpdate(List<Payment_Proposal__c> paymentProposals, Map<Id, Payment_Proposal__c> oldMapPaymentProposals){
        if(MultiCurrencyHandler.isMultiCurrencyEnabled){
            for(Payment_Proposal__c pp : paymentProposals) {
                if(pp.Payment_Proposal_Line_Count__c > 0 && (pp.get('CurrencyIsoCode') != (oldMapPaymentProposals.get(pp.Id)).get('CurrencyIsoCode'))) {
                    pp.addError(Label.ERR_PP_CANNOT_UPDATE_CURRENCY_PPL_EXIST);
                }
            }
        }
    } 

    
    public static void validatePPBankAccountEnrollmentStatus(List<Payment_Proposal__c> paymentProposals){
        Set<Id> setOfRelatedGLAccountIds = new Set<Id>();
        for(Payment_Proposal__c pp : paymentProposals) {
            if(pp.Type__c == AS_PAY_TYPE) {
                setOfRelatedGLAccountIds.add(pp.Bank_GL_Account__c);
            }
        }

        if(!setOfRelatedGLAccountIds.isEmpty()){
            Map<Id,GL_Account__c> mapOfIdAndGLAccount= new Map<Id,GL_Account__c>(queryBankGLAccounts(setOfRelatedGLAccountIds));
            for(Payment_Proposal__c pp : paymentProposals) {
                if(pp.Type__c == AS_PAY_TYPE && mapOfIdAndGLAccount.containsKey(pp.Bank_GL_Account__c) && 
                    (mapOfIdAndGLAccount.get(pp.Bank_GL_Account__c).Bank_Account__c == NULL || 
                     mapOfIdAndGLAccount.get(pp.Bank_GL_Account__c).Bank_Account__r.Payment_Services_Enrollment_Status__c != PAYMENT_SERVICE_ENROLLED_STATUS ||
                     mapOfIdAndGLAccount.get(pp.Bank_GL_Account__c).Bank_Account__r.AcctSeed__Enable_for_Payment_Services__c == false)){
                        pp.addError(String.format(Label.ERR_REQUIRED_APPROVED_BANK_ACC_ON_GLACCOUNT_OF_CD, 
                                    new List<String>{String.valueOf(mapOfIdAndGLAccount.get(pp.Bank_GL_Account__c).Bank_Account__r.Name)}));
                }
            }
        }
    }

    private static List<GL_Account__c> queryBankGLAccounts(Set<Id> setOfGLAccountIds) {

        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Bank_Account__c',
            'Bank_Account__r.Name',
            'Bank_Account__r.Payment_Services_Enrollment_Status__c',
            'Bank_Account__r.AcctSeed__Enable_for_Payment_Services__c'
        };

        String queryCondition = 'Id IN :setOfGLAccountIds';
       
        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());

    }

    public static void updateDefaultLedgerOnPaymentProposal(List<Payment_Proposal__c> paymentProposals){
        Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
        for(Payment_Proposal__c ppRec : paymentProposals){
            if(ppRec.Ledger__c == NULL && settings.Default_Ledger__c != NULL){
                ppRec.Ledger__c = settings.Default_Ledger__c;
            }
        }
    }
}