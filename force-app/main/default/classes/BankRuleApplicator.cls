public with sharing class BankRuleApplicator {

    private static BankRuleApplicator instance;

    @TestVisible
    private List<BankRuleComposite> cashInRules;
    @TestVisible
    private List<BankRuleComposite> cashOutRules;

    private Bank_Transaction__c bt;
    private BankRuleComposite applicableBankRule;

    private BankRuleApplicator() {
        init();
    }

    public static BankRuleApplicator getInstance() {
        if (instance == NULL) {
            instance = new BankRuleApplicator();
        }
        return instance;
    }

    private void init() {
        initCashInRules();
        initCashOutRules();
    }

    private void initCashInRules() {
        cashInRules = new List<BankRuleComposite>();
        for (Bank_Rule__c br : DomainUtils.getBankRulesComposed('Cash_In', true)) {
            BankRuleComposite bankRuleComp = new BankRuleComposite(
                br, br.Bank_Rule_Conditions__r, br.Bank_Rule_Actions__r, br.Bank_Rule_GLAMs__r
            );
            cashInRules.add(bankRuleComp);
        }
    }

    private void initCashOutRules() {
        cashOutRules = new List<BankRuleComposite>();
        for (Bank_Rule__c br : DomainUtils.getBankRulesComposed('Cash_Out', true)) {
            BankRuleComposite bankRuleComp = new BankRuleComposite(
                br, br.Bank_Rule_Conditions__r, br.Bank_Rule_Actions__r, br.Bank_Rule_GLAMs__r
            );
            cashOutRules.add(bankRuleComp);
        }
    }

    /*
    * Used for the BDC Drawer (BDC UI) functionality.
    * 1. Search an applicable Bank Rule in Cash-In or Cash-Out collections filtered by given SObjectType
    * 2. Take all actions defined for Bank Rule to pre-populate fields on new source document
    */
    public BankRuleComposite apply(Bank_Transaction__c bt, SObject sourceDoc) {
        this.bt = bt;
        this.applicableBankRule = findApplicableRule(sourceDoc.getSObjectType());
        if (applicableBankRule != NULL) {
            takeBankRuleActions(sourceDoc, false);
        }
        return this.applicableBankRule;
    }

    /*
    * Used for the Automated Add functionality.
    * 1. Search an applicable Bank Rule in Cash-In or Cash-Out collections
    * 2. Create source document based on applicable Bank Rule if found.
    * 3. Take all actions defined for Bank Rule to pre-populate fields on new source document
    */
    public BDCSourceDocumentsFactory.BDCSourceDocumentUnit apply(Bank_Transaction__c bt) {
        BDCSourceDocumentsFactory.BDCSourceDocumentUnit unit;
        this.bt = bt;
        this.applicableBankRule = findApplicableRule(NULL);

        if (applicableBankRule != NULL) {
            unit = new BDCSourceDocumentsFactory.BDCSourceDocumentUnit(
                this.bt, this.applicableBankRule.getSObjectTypeForFutureSourceDocument()
            );

            if (unit.isCashReceiptType()) {
                takeBankRuleActions(unit.cashReceipt.getRecord(), false);
            }
            else if (unit.isCashDisbursementType()) {
                takeBankRuleActions(unit.cashDisbursement.getRecord(), false);
            }
            else if (unit.isJournalEntryType()) {
                takeBankRuleActions(unit.journalEntry.getMainLine(), true);
                takeBankRuleActions(unit.journalEntry.getOppositeLine(), false);
            }
        }

        return unit;
    }

    private BankRuleComposite findApplicableRule(SObjectType sObjectTypeCondition) {
        BankRuleComposite result;
        if (bt.Base_Type__c == 'Credit') {
            result = searchCashInRule(sObjectTypeCondition);
        }
        else if (bt.Base_Type__c == 'Debit') {
            result = searchCashOutRule(sObjectTypeCondition);
        }
        return result;
    }

    private BankRuleComposite searchCashInRule(SObjectType sObjectTypeCondition) {
        return searchRule(cashInRules, sObjectTypeCondition);
    }

    private BankRuleComposite searchCashOutRule(SObjectType sObjectTypeCondition) {
        return searchRule(cashOutRules, sObjectTypeCondition);
    }

    private BankRuleComposite searchRule(List<BankRuleComposite> bankRules, SObjectType sObjectTypeCondition) {
        BankRuleComposite result;
        for (BankRuleComposite bankRule : bankRules) {
            if (bankRule.isApplicableFor(bt, sObjectTypeCondition)) {
                result = bankRule;
                break;
            }
        }
        return result;
    }

    private void takeBankRuleActions(SObject sourceDocument, Boolean lockGLAccount) {
        if (sourceDocument != NULL && this.applicableBankRule != NULL) {
            applicableBankRule.takeActions(sourceDocument, lockGLAccount);
        }
    }

}