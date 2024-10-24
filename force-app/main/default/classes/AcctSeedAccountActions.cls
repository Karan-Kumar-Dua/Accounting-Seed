public with sharing class AcctSeedAccountActions {
    private static final String ERROR_LEDGER_NOT_ENROLLED = Label.ERROR_LEDGER_NOT_ENROLLED;

    public static void setAccountingActive(List<Account> accounts) {
        try {
            for (Account acc : accounts) {
                if (acc.Accounting_Type__c != NULL) {
                    acc.Accounting_Active__c = true;
                }
                else if (acc.Accounting_Type__c == NULL) {
                    acc.Accounting_Active__c = false;
                }
            }
        }
        catch (Exception ex) {
            //exception should be caught and suppressed
        }

    }

    public static void checkFeatureParameterFieldLevelAccessInsert() {
        
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), Account.SObjectType);
        controlService.checkInsertFieldGrants();
    }

    public static void checkFeatureParameterFieldLevelAccessUpdate() {
        
        AccessControlService controlService =  new AccessControlService(new APAutomationControl(), Account.SObjectType);
        controlService.checkUpdateFieldGrants();
    }

    //Method to post message to CSI
    public static void  apAutomationPostMessage(List<Account> accounts,Map<Id,Account> oldAccountMap) {
        List<Id> accountIdsToCreateVendor = new List<Id>();
        List<Id> accountIdsToUpdateVendor = new List<Id>();

        //Iterate to get all payment service enabled ids
        for(Account acc : accounts) {
            /*for insert case we are checking if enable payment setvice is true then for that account record we 
              need to post create_bank account Message
            */
            if(Trigger.isInsert) {
                if(acc.Enable_Payment_Services__c == true) {
                    accountIdsToCreateVendor.add(acc.Id);
                }   
            }
            // for handle update scenario
            else {
                /* initilaizing the "updateControlService" class to check set of account field mentioned in "APAutomationUpdateControl"
                   class that got updated or not
                */   
                UpdateControlService updateService = new UpdateControlService(new APAutomationUpdateControl(), Account.SObjectType);
                /* if current updated account record has enable payment service is true and old value of this field is false
                   then we are going to post CREATE_VENDOR message and in this case we are not worried about group of payement
                   feature fields changed or not.
                */
                if(acc.Enable_Payment_Services__c == true && oldAccountMap.get(acc.Id).Enable_Payment_Services__c == false) {
                    accountIdsToCreateVendor.add(acc.Id);
                }
                /* if current updated account record has enable payment service is true and old value of this field is also true
                   then we need to check the group of payment feature set of fields that got changed or not if that fields were 
                   changed then we need to post UPDATE_VENDOR message to SQS.
                */
                else if(acc.Enable_Payment_Services__c == true && oldAccountMap.get(acc.Id).Enable_Payment_Services__c == true
                        && String.IsNotBlank(acc.Payment_Services_Vendor_ID__c) && updateService.checkUpdateFieldChanges())
                {
                    accountIdsToUpdateVendor.add(acc.Id);
                }
            }
        }

        // if list of account id is empty then do not call SQS service class to post CREATE_VENDOR message
        if(!accountIdsToCreateVendor.isEmpty()) {
            APAutomationService.postMessage(accountIdsToCreateVendor, APAutomationService.APAutomationActions.CREATE_VENDOR.name());
        }
        // if list of account id is empty then do not call SQS service class to post UPDATE_VENDOR message
        if(!accountIdsToUpdateVendor.isEmpty()) {
            APAutomationService.postMessage(accountIdsToUpdateVendor, APAutomationService.APAutomationActions.UPDATE_VENDOR.name());
        }
    }

    public static void setAndPreventEnablePaymentService(List<Account> accounts,Map<Id,Account> oldAccountMap) {
        Set<Id> setOfLedgerIds = new Set<Id>();
        Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
        for(Account acc : accounts) {      
            Schema.DescribeFieldResult describeRes = Account.Enable_Payment_Services__c.getDescribe();
            Schema.sObjectField token = describeRes.getSObjectField();

            if(oldAccountMap != NULL){
                if(oldAccountMap.get(acc.Id).Enable_Payment_Services__c && acc.Enable_Payment_Services__c == false
                    && (acc.Payment_Services_Enrollment_Status__c == 'Processing' ||
                    acc.Payment_Services_Enrollment_Status__c == 'Enrolled')){
                        acc.addError(
                            String.format(
                                Label.ERROR_PAYMENT_SERVICE_UNCHECKED,
                                new List<String> {token.getDescribe().getLabel()}
                            )
                        );
                }

                if(oldAccountMap.get(acc.Id).Enable_Payment_Services__c && (oldAccountMap.get(acc.Id).Payment_Services_Enrollment_Status__c != 'Removed' && acc.Payment_Services_Enrollment_Status__c == 'Removed') ||
                    (oldAccountMap.get(acc.Id).Payment_Services_Enrollment_Status__c != 'Denied' && acc.Payment_Services_Enrollment_Status__c == 'Denied')||
                    (oldAccountMap.get(acc.Id).Payment_Services_Enrollment_Status__c != null && acc.Payment_Services_Enrollment_Status__c == null)){
                        acc.Enable_Payment_Services__c = false;
                }
            }

            if(acc.Enable_Payment_Services__c == true && settings.AcctSeed__Default_Payment_Services_Ledger__c != NULL) {
                setOfLedgerIds.add(settings.Default_Payment_Services_Ledger__c);
            }
        }

        if(!setOfLedgerIds.isEmpty()){
            List<Ledger__c> ledgerList = new List<Ledger__c>(DomainUtils.getLedgersById(setOfLedgerIds));
            for (Account acc : accounts) {
                if(acc.Enable_Payment_Services__c == true && (String.isBlank(ledgerList[0].Payment_Services_Company_Code__c))) {
                    acc.addError(String.format(ERROR_LEDGER_NOT_ENROLLED, new List<String>{ledgerList[0].Name}));
                }
            }
        }
    }
}