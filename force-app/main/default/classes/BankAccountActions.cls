public with sharing class BankAccountActions {

    private static final String REQUIRED_FIELD_ERROR_FOR_PAYMENT_SERVICES = Label.ERR_REQUIRED_FIELDS_FOR_BANK_ACCOUNT;
    private static final String ERROR_LEDGER_NOT_ENROLLED = Label.ERROR_LEDGER_NOT_ENROLLED;
    private static final String PAYMENT_SERVICE_ENROLLED_STATUS= 'Enrolled';
    
    //Method to check required fields if Payment Services are enabled
    public static void checkRequiredField(List<Bank_Account__c> bankAccountList) {
        Set<Id> setOfLedgerIds = new Set<Id>();
        //Go through all bank accounts
        for(Bank_Account__c bankAccount : bankAccountList) {

            //Check all required fields if Payment Services are enabled
            if(bankAccount.Enable_for_Payment_Services__c == true) {
                if(bankAccount.Name == null) {
                    bankAccount.Name.addError(REQUIRED_FIELD_ERROR_FOR_PAYMENT_SERVICES);
                }
                if(bankAccount.Routing_Number__c == null) {
                    bankAccount.Routing_Number__c.addError(REQUIRED_FIELD_ERROR_FOR_PAYMENT_SERVICES);
                }
                if(bankAccount.Account_Number__c == null) {
                    bankAccount.Account_Number__c.addError(REQUIRED_FIELD_ERROR_FOR_PAYMENT_SERVICES);
                }
                if(bankAccount.Ledger__c != NULL) {
                    setOfLedgerIds.add(bankAccount.Ledger__c);
                }
            }
        }

        //Check if related Ledger has Payment Service assigned Company Code if Payment Services are enabled
        if(!setOfLedgerIds.isEmpty()){
            Map<Id, Ledger__c> ledgerMap = new Map<Id, Ledger__c>(DomainUtils.getLedgersById(setOfLedgerIds));
            for (Bank_Account__c bankAccount : bankAccountList) {
                if(bankAccount.Enable_for_Payment_Services__c == true && bankAccount.Ledger__c != NULL && (String.isBlank(ledgerMap.get(bankAccount.Ledger__c).Payment_Services_Company_Code__c))) {
                    bankAccount.Ledger__c.addError(String.format(ERROR_LEDGER_NOT_ENROLLED, new List<String>{String.valueOf(ledgerMap.get(bankAccount.Ledger__c).Name)}));
                }
            }
        }
    }

    //Method to post message to CSI
    public static void apAutomationPostMessage(List<Bank_Account__c> bankAccountList, Map<Id,Bank_Account__c> oldBankAccountMap) {
        List<Id> bankAccountIdToCreate = new List<Id>();
        List<Id> bankAccountIdToUpdate = new List<Id>();

        //Iterate to get all payment service enabled ids
        for(Bank_Account__c bankAcc : bankAccountList) {
            /*for insert case we are checking if Enable_for_Payment_Services__c true then for that bank account record we 
              need to post CREATE_BANK_ACCOUNT Message
            */
            if(Trigger.isInsert) {
                if(bankAcc.Enable_for_Payment_Services__c == true) {
                    bankAccountIdToCreate.add(bankAcc.Id);
                }   
            }
            // for handle update scenario
            else {
                /* initilaizing the "updateControlService" class to check set of bank account field mentioned in "APAutomationUpdateControl"
                   class that got updated or not
                */   
                UpdateControlService updateService = new UpdateControlService(new APAutomationUpdateControl(), Bank_Account__c.SObjectType);
                /* if current updated bank account record has enable payment service is true and old value of this field is false
                   then we are going to post CREATE_BANK_ACCOUNT message and in this case we are not worried about group of payement
                   feature fields changed or not.
                */
                if(bankAcc.Enable_for_Payment_Services__c == true && oldBankAccountMap.get(bankAcc.Id).Enable_for_Payment_Services__c == false) {
                    bankAccountIdToCreate.add(bankAcc.Id);
                }
                /* if current updated bank account record has enable payment service is true and old value of this field is also true
                   then we need to check the group of payment feature set of fields that got changed or not if that fields were 
                   changed then we need to post UPDATE_BANK_ACCOUNT message to SQS.
                */
                else if(bankAcc.Enable_for_Payment_Services__c == true && oldBankAccountMap.get(bankAcc.Id).Enable_for_Payment_Services__c == true
                        && updateService.checkUpdateFieldChanges())
                {
                    bankAccountIdToUpdate.add(bankAcc.Id);
                }
            }
        }

        // if list of account id is empty then do not call SQS service class to post CREATE_BANK_ACCOUNT message
        if(!bankAccountIdToCreate.isEmpty()) {
            APAutomationService.postMessage(bankAccountIdToCreate, APAutomationService.APAutomationActions.CREATE_BANK_ACCOUNT.name());
        }
        // if list of account id is empty then do not call SQS service class to post UPDATE_BANK_ACCOUNT message
        if(!bankAccountIdToUpdate.isEmpty()) {
            APAutomationService.postMessage(bankAccountIdToUpdate, APAutomationService.APAutomationActions.UPDATE_BANK_ACCOUNT.name());
        }
    }

    public static void setAndPreventEnablePaymentService(List<Bank_Account__c> bankAccounts,Map<Id,Bank_Account__c> oldBankAccountMap) {
        
        for(Bank_Account__c bankAcc : bankAccounts) {      
            Schema.DescribeFieldResult describeRes = Bank_Account__c.Enable_For_Payment_Services__c.getDescribe();
            Schema.sObjectField token = describeRes.getSObjectField();

            if(oldBankAccountMap.get(bankAcc.Id).Enable_For_Payment_Services__c && bankAcc.Enable_For_Payment_Services__c == false
                && (bankAcc.Payment_Services_Enrollment_Status__c == 'Processing' ||
                bankAcc.Payment_Services_Enrollment_Status__c == 'Enrolled')){
                    bankAcc.addError(
                        String.format(
                            Label.ERROR_PAYMENT_SERVICE_UNCHECKED,
                            new List<String> {token.getDescribe().getLabel()}
                        )
                    );
            }

            if(oldBankAccountMap.get(bankAcc.Id).Enable_For_Payment_Services__c && (oldBankAccountMap.get(bankAcc.Id).Payment_Services_Enrollment_Status__c != 'Removed' && bankAcc.Payment_Services_Enrollment_Status__c == 'Removed') ||
                (oldBankAccountMap.get(bankAcc.Id).Payment_Services_Enrollment_Status__c != 'Denied' && bankAcc.Payment_Services_Enrollment_Status__c == 'Denied')||
                (oldBankAccountMap.get(bankAcc.Id).Payment_Services_Enrollment_Status__c != null && bankAcc.Payment_Services_Enrollment_Status__c == null)){
                    bankAcc.Enable_For_Payment_Services__c = false;
            }
        }
    }

    public static void updatePaymentServiceEnrollmentStatus(List<Bank_Account__c> bankAccounts,Map<Id,Bank_Account__c> oldBankAccountMap) {
        for(Bank_Account__c bankAcc : bankAccounts) {      
            if(String.IsBlank(oldBankAccountMap.get(bankAcc.Id).Payment_Services_Bank_Account_ID__c) && String.IsNotBlank(bankAcc.Payment_Services_Bank_Account_ID__c) ){
                bankAcc.Payment_Services_Enrollment_Status__c = PAYMENT_SERVICE_ENROLLED_STATUS;
            }
        }
    }

    public static void checkInsertFieldGrantsForPaymentServices(AccessControlService controlService){
        controlService.checkInsertFieldGrants();
    }

    public static void checkUpdateFieldGrantsForPaymentServices(){
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), AcctSeed__Bank_Account__c.SObjectType);
        controlService.checkUpdateFieldGrants();
    }

    public static void populatePaymentServicesEnrollmentStatus(List<Bank_Account__c> newList,AccessControlService controlService){
        if(controlService.hasAccess){
            for(Bank_Account__c bankAccount : newList){
                if(bankAccount.Enable_for_Payment_Services__c && String.isBlank(bankAccount.Payment_Services_Enrollment_Status__c)){
                    bankAccount.Payment_Services_Enrollment_Status__c = 'Not Enrolled';
                }
            }
        }
    }

}