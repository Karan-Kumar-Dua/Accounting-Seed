global with sharing class AccountingPeriod {
    global class AccountingPeriodException extends Exception{}
    public enum SubLedgerType {AP, AR, INVENTORY}
    private static APIServiceContext.APIServiceEntry serviceEntry;

    public static Set<SObjectType> arSubLedgerTypes = new Set<SObjectType>{
        Billing__c.sObjectType, 
        Billing_Line__c.sObjectType, 
        Billing_Cash_Receipt__c.sObjectType, 
        Billing_Credit_Memo__c.sObjectType, 
        Cash_Receipt__c.sObjectType, 
        Recurring_Billing__c.sObjectType, 
        Recurring_Billing_Line__c.sObjectType
    };

    public static Set<SObjectType> apSubLedgerTypes = new Set<SObjectType>{
        Account_Payable__c.sObjectType, 
        Account_Payable_Line__c.sObjectType, 
        Recurring_Account_Payable__c.sObjectType, 
        Recurring_Account_Payable_Line__c.sObjectType, 
        AP_Credit_Memo__c.sObjectType, 
        Cash_Disbursement__c.sObjectType, 
        AP_Disbursement__c.sObjectType
    };

    global static Boolean isPeriodOpen(Accounting_Period__c period, sObjectType objType){
        AccountingPeriod.serviceEntry = new APIServiceContext.APIServiceEntry();
        ServiceResult validationResult = APIServiceContext.validateServiceContext(AccountingPeriod.serviceEntry);
        if (!validationResult.isSuccess) {
            throw new AccountingPeriodException(String.join(validationResult.errors, ','));
        }
        return AccountingPeriod.isAccountingPeriodOpen(period, objType);
    }

    global static Boolean isPeriodClosed(Accounting_Period__c period, sObjectType objType){
        AccountingPeriod.serviceEntry = new APIServiceContext.APIServiceEntry();
        ServiceResult validationResult = APIServiceContext.validateServiceContext(AccountingPeriod.serviceEntry);
        if (!validationResult.isSuccess) {
            throw new AccountingPeriodException(String.join(validationResult.errors, ','));
        }
        return AccountingPeriod.isAccountingPeriodClosed(period, objType);
    }

    // method is used to check the period is closed or open
    public static Boolean checkPeriodBySubLedger(Accounting_Period__c period, SubLedgerType sLT){
        switch on sLT {
            when AP {
                return period.Close_AP__c ? false : true;
            }
            when AR {
                return period.Close_AR__c ? false : true;
            }
            when INVENTORY {
                if(AccountingSettingsHandler.isERPEnabled()){
                    return period.get('AcctSeedERP__Close_Inventory__c') == true ? false : true;
                }
                return false;
            }
            when else{
                return false;
            }
         }
    }

    private static Boolean isAccountingPeriodOpen(Accounting_Period__c period, sObjectType objType){
        Boolean isOpen = false;
        
        // do not process any further operations if period null then return directly to avoid time processing.
        if(period == null){
           return isOpen; 
        } 
        //determine sub ledger type
        SubLedgerType sLT = getSubLedgerType(objType);
 
        //check based on status, subledger type, and Soft Close field status
        if(period != NULL && period.Status__c == AccountingPeriodActions.OPEN_STATUS){
            isOpen = checkPeriodBySubLedger(period, sLT);
        }
        return isOpen;
    }

    private static Boolean isAccountingPeriodClosed(Accounting_Period__c period, sObjectType objType){
        Boolean isClosed = true;

        // do not process any further operations if period null then return directly to avoid time processing.
        if(period == null){
            return isClosed; 
         } 
        //determine sub ledger type
        SubLedgerType sLT = getSubLedgerType(objType);

        //check based on status, subledger type, and Soft Close field status
        if(period != NULL && period.Status__c == AccountingPeriodActions.CLOSED_STATUS || period.Status__c == AccountingPeriodActions.CLOSE_INTERIM_STATUS){
            isClosed = true;
        } else {
            isClosed = !(checkPeriodBySubLedger(period, sLT));
        }

        return isClosed;
    }

    private static SubLedgerType getSubLedgerType(sObjectType sObjType){
        SubLedgerType sLT;

        if(sObjType == NULL){

            //TODO:  create label
            throw new AccountingPeriodException('sObjectType not provided');
        }

        //AP 
        if(AccountingPeriod.arSubLedgerTypes.contains(sObjType)){
            sLT = SubLedgerType.AR;
        } 
        //AR
        else if(AccountingPeriod.apSubLedgerTypes.contains(sObjType)){
            sLT = SubLedgerType.AP;
        }
        else{
            //TODO:  create label
            throw new AccountingPeriodException('sObjectType not supported');
        }

        return sLT;
    }

}