public with sharing class ALMPayableRowTemplate implements ALMRowCreateHandler, ALMRowChangeHandler {
    /**
     * a interface method which requires a ALMRowCreateEvent as a argument to get records as per user's business requirements
     */
    public List<SObject> createRow(ALMRowCreateEvent eventState){
        return getPayableLines(eventState);
    }
    /**
     * method to set some defaults from parent account payable to their child account payable lines
     */
    private List<SObject> getPayableLines(ALMRowCreateEvent eventState) {
        List<Account_Payable__c> payable = DomainUtils.getAccountPayablesById(new Set<Id>{
            (Id) eventState.headerId
        });
        return getPayableLines(payable[0], eventState);
    }
    /**
     * prepare account payable lines with some default values in from the fetched Account payable
     */
    private List<SObject> getPayableLines(Account_Payable__c payable, ALMRowCreateEvent eventState) {
        List<Account_Payable_Line__c> payableLines = new List<Account_Payable_Line__c>();
        for (Integer index = 1; index <= eventState.createRowsCount; index++) {
            payableLines.add(new Account_Payable_Line__c(
                Date__c = payable.Date__c,
                Expense_GL_Account__c = payable.Vendor__r.Default_Expense_GL_Account__c,
                GL_Account_Variable_1__c = payable.Vendor__r.GL_Account_Variable_1__c,
                GL_Account_Variable_2__c = payable.Vendor__r.GL_Account_Variable_2__c,
                GL_Account_Variable_3__c = payable.Vendor__r.GL_Account_Variable_3__c,
                GL_Account_Variable_4__c = payable.Vendor__r.GL_Account_Variable_4__c
            ));
        }
        return payableLines;
    }
    /**
     * ALMRowChangeHandler interface methhod to make additional changes into the row
     * input - ALMRowChangeEvent - wrapper with old and updated row data
     * return - sObject - the updated record after additional changes
     */
    public SObject updateRow(ALMRowChangeEvent event) {
        try {
            return updateALMRow(event);
        } catch(Exception e) {
            return event.updatedRow;
        }
    }

    private SObject updateALMRow(ALMRowChangeEvent event) {
        Account_Payable_Line__c oldPayableLine = (Account_Payable_Line__c) event.oldRow;
        Account_Payable_Line__c payableLine = (Account_Payable_Line__c) event.updatedRow;

        if (oldPayableLine.Product__c == payableLine.Product__c) {
            return payableLine;
        }
        //fetch Account payables that matches the Id
        Map<Id, Account_Payable__c> acctPayableMap =
            new Map<Id, Account_Payable__c>(DomainUtils.getAccountPayablesById(new Set<Id>{
                payableLine.Account_Payable__c
            }));
        //get product that matches the product Id on payable line
        Map<Id, Product2> productMap = getProductsById(new Set<Id>{
            payableLine.Product__c
        });
        //payables by ledger Ids
        Map<Id, Id> paysByLedgers = SObjectActions.ledgerIdBySourceId(acctPayableMap.values());
        //the defaults gl accounts by ledgers
        Map<Id, Map<String, GL_Account_Default__c>> defaults = GLAccount.glAccountDefaultsMapByLedgerId(new Set<Id> (paysByLedgers.values()));

        //if product has inventory product checkbox checked 
        //populate the Expense GL Account field on the payable line with the default GL Account set on that ledger’s Vouchers Payable GL Account.
        //else populate the Expense GL Account field on the payable line with the Expense GL Account value set on that Product
        //if Expense GL Account has not been taken from either Accounting Settings or Product
        //get it from Vendor if possible
        if (payableLine.Product__c != null
            && productMap.get(payableLine.Product__c).Inventory_Product__c
            && defaults.containsKey(paysByLedgers.get(payableLine.Account_Payable__c))
            && defaults.get(paysByLedgers.get(payableLine.Account_Payable__c)).containsKey(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)) {
            payableLine.Expense_GL_Account__c =
                defaults.get(paysByLedgers.get(payableLine.Account_Payable__c)).get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT).GL_Account__c;
            payableLine.Expense_GL_Account__r.Name =
                defaults.get(paysByLedgers.get(payableLine.Account_Payable__c)).get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT).GL_Account__r.Name;
        } else if (payableLine.Product__c != null
            && !productMap.get(payableLine.Product__c).Inventory_Product__c
            && productMap.containsKey(payableLine.Product__c)) {
            String glName = productMap.get(payableLine.Product__c).Expense_GL_Account__c != null ?
                productMap.get(payableLine.Product__c).Expense_GL_Account__r.Name :
                payableLine.Expense_GL_Account__r?.Name;
            payableLine.Expense_GL_Account__c = productMap.get(payableLine.Product__c)?.Expense_GL_Account__c;
            payableLine.Expense_GL_Account__r.Name = glName;
        } else if (payableLine.Product__c == null && payableLine.Expense_GL_Account__c != null
            && acctPayableMap.get(payableLine.Account_Payable__c).Vendor__r.Default_Expense_GL_Account__c != NULL) {
            payableLine.Expense_GL_Account__c = acctPayableMap.get(payableLine.Account_Payable__c).Vendor__r.Default_Expense_GL_Account__c;
            payableLine.Expense_GL_Account__r.Name = acctPayableMap.get(payableLine.Account_Payable__c).Vendor__r.Default_Expense_GL_Account__r.Name;
        }
        return payableLine;
    }
    /**
     * this will fetch the products that matches the record Ids
     * input - set<Id> - productIds
     * return - Map<Id,Product2> - map of products 
     */
    private static Map<Id, Product2> getProductsById(Set<Id> ids) {
        List<String> queryFields = new List<String>{
            'Inventory_Product__c',
            'Expense_GL_Account__c',
            'Expense_GL_Account__r.Name'
        };
        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Product2.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        Map<Id, Product2> results = new Map<Id, Product2>((List<Product2>) Database.query(theQuery.toSOQL()));

        return results;
    }

    public class ReferenceWrapper {
        @AuraEnabled
        public String Id;
        @AuraEnabled
        public String Name;
        public ReferenceWrapper(String id, String name) {
            this.Id = id;
            this.Name = name;
        }
    }
}