public with sharing class RemittanceController {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public List<CashDisbursementWrapper> cashDisbursements {get; private set;}
    
    public RemittanceController(ApexPages.StandardController std) {
        try {
            Id objId = std.getRecord().Id;
            if (objId != NULL) {
                Schema.DescribeSObjectResult objDesc = objId.getSObjectType().getDescribe();
                if (objDesc.getName() == Cash_Disbursement__c.getSObjectType().getDescribe().getName()) {
                    cashDisbursements = getCashDisbursementWrappers(getCashDisbursements(objId, false));
                }
                else if (objDesc.getName() == Cash_Disbursement_Batch__c.getSObjectType().getDescribe().getName()) {
                    cashDisbursements = getCashDisbursementWrappers(getCashDisbursements(objId, true));
                }
                else {
                    cashDisbursements = new List<CashDisbursementWrapper>();
                }
            }
            else {
                cashDisbursements = new List<CashDisbursementWrapper>();
            }
        }
        catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));
        }
    }
    
    private List<Cash_Disbursement__c> getCashDisbursements(Id objId, Boolean isBatch) {
        List<Cash_Disbursement__c> result;
        try {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Payee__c',
                'Payee_Street__c',
                'Payee_City_State_Zip__c',
                'Payee_Country__c',
                'Check_Number__c',
                'Type__c',
                'Amount__c',
                'Amount_In_Words__c',
                'Disbursement_Date__c',
                'Bank_Account__c'
            };

            String queryCondition = (isBatch) ? 'Cash_Disbursement_Batch__c = :objId' : 'Id = :objId';
            SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Cash_Disbursement__c', 'Check_Number__c', SOQLBuilder.SortOrder.ASCENDING);

            List<String> subQueryFields = new List<String>{
                'Id',
                'Name',
                'Account_Payable__c',
                'Account_Payable_Date__c',
                'Payable_Amount__c',
                'Net_Amount__c',
                'Discount_Amount__c',
                'Account_Payable__r.Payee_Reference__c',
                'Account_Payable__r.Type__c',
                'Account_Payable__r.Name',
                'Account_Payable__r.Vendor__c',
                'Account_Payable__r.Date__c',
                'Account_Payable__r.Discount_Amount__c',
                'Account_Payable__r.Credit_Memo_Applied_Amount__c',
                'Account_Payable__r.Net_Amount__c',
                'Account_Payable__r.Proprietary_Payable_Number__c',
                'Paid_Amount__c'
            };

            String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Account_Payable_Cash_Disbursements__r';

            SOQLBuilder.Ordering subQueryOrdering = new SOQLBuilder.Ordering(
                'AP_Disbursement__c',
                'Account_Payable_Date__c',
                SOQLBuilder.SortOrder.ASCENDING
            );

            SOQLBuilder.Ordering subQueryOrdering2 = new SOQLBuilder.Ordering(
                'AP_Disbursement__c',
                'Name',
                SOQLBuilder.SortOrder.ASCENDING
            );

            SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .addOrdering(ordering)
                .subselectQuery(subQueryRelationshipName, true)
                .setEnforceFLS(true)
                .selectFields(subQueryFields)
                .addOrdering(subQueryOrdering)
                .addOrdering(subQueryOrdering2);

            result = (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
        }
        catch (Exception ex) {
            throw ex;
        }

        return result;
    }
    
    private Map<Id,List<Cash_Disbursement__c>> getCashDisbursementByAccountPayable(List<Cash_Disbursement__c> cashDisbursements) {
        Map<Id,List<Cash_Disbursement__c>> cdMap = new Map<Id,List<Cash_Disbursement__c>>();
        for (Cash_Disbursement__c cd : cashDisbursements) {
            for (AP_Disbursement__c apd : cd.Account_Payable_Cash_Disbursements__r) {
                if (!cdMap.containsKey(apd.Account_Payable__c)) {
                    cdMap.put(apd.Account_Payable__c,new Cash_Disbursement__c[]{cd});
                } 
                else {
                    cdMap.get(apd.Account_Payable__c).add(cd);
                }
            }
        }
        return cdMap;
    }
    
    private Map<Id, List<AP_Credit_Memo__c>> getCreditMemoByCashDisbursement(Map<Id, List<Cash_Disbursement__c>> cdMap) {
        Map<Id, List<AP_Credit_Memo__c>> creditMemoMap = new Map<Id, List<AP_Credit_Memo__c>>();
        Set<Id> accountPayableIds = cdMap.keySet();

        List<String> queryFields = new List<String>{
            'Id',
            'Amount__c',
            'Account_Payable_Invoice__c',
            'Account_Payable_Credit_Memo__r.Name',
            'Account_Payable_Credit_Memo__r.Type__c',
            'Account_Payable_Credit_Memo__r.Discount_Amount__c',
            'Account_Payable_Credit_Memo__r.Payee_Reference__c',
            'Account_Payable_Credit_Memo__r.Credit_Memo_Applied_Amount__c',
            'Account_Payable_Credit_Memo__r.Net_Amount__c',
            'Account_Payable_Credit_Memo__r.Proprietary_Payable_Number__c',
            'Account_Payable_Credit_Memo__r.Date__c'
        };
        String queryCondition = 'Account_Payable_Invoice__c IN :accountPayableIds';
        SOQLBuilder theQuery = new SOQLBuilder(AP_Credit_Memo__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        
        for (AP_Credit_Memo__c apm : (List<AP_Credit_Memo__c>) Database.query(theQuery.toSOQL())) {
            for (Cash_Disbursement__c cd : cdMap.get(apm.Account_Payable_Invoice__c)) {
                if (!creditMemoMap.containsKey(cd.Id)) {
                    creditMemoMap.put(cd.Id, new List<AP_Credit_Memo__c>{apm});
                } 
                else {
                    creditMemoMap.get(cd.Id).add(apm);
                }
            }
        }
        
        return creditMemoMap;
    }
    
    private List<CashDisbursementWrapper> getCashDisbursementWrappers(List<Cash_Disbursement__c> cashDisbursements) {
        List<CashDisbursementWrapper> result = new List<CashDisbursementWrapper>();
        Map<Id,List<Cash_Disbursement__c>> cdMap = getCashDisbursementByAccountPayable(cashDisbursements);
        Map<Id,List<AP_Credit_Memo__c>> creditMemoMap = getCreditMemoByCashDisbursement(cdMap);

        for (Cash_Disbursement__c cd : cashDisbursements) {
            List<RemittanceWrapper> remittances = new List<RemittanceWrapper>();
            for (AP_Disbursement__c apd : cd.Account_Payable_Cash_Disbursements__r) {
                remittances.add(new RemittanceWrapper(apd.Account_Payable__r, apd.Paid_Amount__c));
            }
            
            if (creditMemoMap.containsKey(cd.Id)) {
                for (AP_Credit_Memo__c apm : creditMemoMap.get(cd.Id)) {
                    remittances.add(new RemittanceWrapper(apm.Account_Payable_Credit_Memo__r, apm.Amount__c));
                }
            }
            remittances.sort();
            result.add(new CashDisbursementWrapper(cd, remittances, /* isAggregate */ true));
        }
        return result;
    }
}