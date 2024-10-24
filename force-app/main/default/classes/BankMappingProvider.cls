public with sharing class BankMappingProvider {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    //group of properties which reflects current mapping state ==================
    //between GL Account (type "Bank") and Bank Sub Account (on the Yodlee side)=
    public static List<GL_Account__c> bankGLAccounts {
        get {
            if (bankGLAccounts == NULL) {
                getAllBankGLAccounts();
            }
            return bankGLAccounts;
        }
        set;
    }

    public static Map<String, BankToGLAccountMapping> mappingStateMap {
        get {
            if (mappingStateMap == NULL) {
                setMappingState();
            }
            return mappingStateMap;
        }
        set;
    }

    //===========================================================================

    private static void getAllBankGLAccounts() {
        //Query GL Account records with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id', 'Name'
        };

        String queryCondition = 'Bank__c = true';
        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'GL_Account_Mappings__r';
        List<String> subQueryFields = new List<String>{
            'Id', 'External_Id__c', 'GL_Account__c', 'Ledger__c'
        };

        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(1000)
            .subselectQuery(subQueryRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(subQueryFields);


        bankGLAccounts = (List<GL_Account__c>) Database.query(theQuery.toSOQL());
    }

    public static void setMappingState() {
        Map<String, BankToGLAccountMapping> bankSubAccountIdToGLAccountId = new Map<String, BankToGLAccountMapping>();
        for (GL_Account__c eachGLAccount : bankGLAccounts) {
            for (GL_Account_Mapping__c mappingEntry : eachGLAccount.GL_Account_Mappings__r) {
                bankSubAccountIdToGLAccountId.put(mappingEntry.External_Id__c, new BankToGLAccountMapping(mappingEntry));
            }
        }
        mappingStateMap = bankSubAccountIdToGLAccountId;
    }

    public static void refreshMappingState() {
        getAllBankGLAccounts();
        setMappingState();
    }

    public static List<SelectOption> getBankGLAccountSelectOptions() {
        List<SelectOption> result = new List<SelectOption>();
        result.add(new SelectOption('', '--' + Label.COMMON_NONE + '--'));
        for (GL_Account__c glAcct : bankGLAccounts) {
            result.add(new SelectOption(glAcct.Id, glAcct.Name));
        }
        return result;
    }

    public class BankToGLAccountMapping {
        public String externalId;
        public String glAccountId;
        public String ledgerId;
        public Boolean isAccessibleByLedger;
        public Boolean isLegacy;

        public BankToGLAccountMapping(String externalId, String glAccountId, String ledgerId) {
            this.externalId = externalId;
            this.glAccountId = glAccountId;
            this.ledgerId = ledgerId;
            this.isLegacy = String.isBlank(this.ledgerId);
            this.isAccessibleByLedger = checkIsAccessibleByLedger();
        }

        public BankToGLAccountMapping(GL_Account_Mapping__c glAccountMapping) {
            this(glAccountMapping.External_Id__c, glAccountMapping.GL_Account__c, glAccountMapping.Ledger__c);
        }

        private Boolean checkIsAccessibleByLedger() {
            return (this.isLegacy || !LedgerHandler.getInstanceWithSharing().getLedgerById(new Set<Id>{this.ledgerId}).isEmpty());
        }
    }

}