public with sharing class FinancialTxAccountMatchRule {

    private static final String DISABLED_MSG = 'Disabled by AcctSeed__Accounting_Settings__c.AcctSeed__Pre_Populate_Account_Info__c';
    private static final String DEBIT_TYPE = 'Debit';
    private static final Integer ACCOUNT_SEARCH_LIMIT = 40000;

    private static FinancialTxAccountMatchRule instance;

    private List<Account> accounts;

    public class ActionDisabledException extends Exception {}

    private FinancialTxAccountMatchRule() {
        if (!isEnabled()) {
            throw new ActionDisabledException(DISABLED_MSG);
        }
        initAccounts();
    }

    public static Boolean isEnabled() {
        return AccountingSettingsHandler.getAccountingSettings().Pre_Populate_Account_Info__c;
    }

    public static FinancialTxAccountMatchRule getInstance() {
        if (instance == null) {
            instance = new FinancialTxAccountMatchRule();
        }
        return instance;
    }

    private void initAccounts() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'File_Import_Match_Name__c',
            'Default_Expense_GL_Account__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };

        String queryCondition =
            'Accounting_Active__c = true ' +
            'AND Accounting_Type__c IN (\'Vendor\',\'Customer and Vendor\')';

            SOQLBuilder.Ordering orderingMatchName = new SOQLBuilder.Ordering(Account.File_Import_Match_Name__c, SOQLBuilder.SortOrder.ASCENDING, true);
            SOQLBuilder.Ordering orderingAccountName = new SOQLBuilder.Ordering(Account.Name, SOQLBuilder.SortOrder.ASCENDING, true);

        SOQLBuilder theQuery = new SOQLBuilder(Account.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(orderingMatchName)
            .addOrdering(orderingAccountName)
            .setLimit(calculateAvailableQueryRowsLimit());

        accounts = (List<Account>) Database.query(theQuery.toSOQL());
    }

    private Integer calculateAvailableQueryRowsLimit() {
        return Limits.getLimitQueryRows() - Limits.getQueryRows() > ACCOUNT_SEARCH_LIMIT ? ACCOUNT_SEARCH_LIMIT : Limits.getLimitQueryRows() - Limits.getQueryRows();
    }

    private Account match(Bank_Transaction__c tx) {
        String matchName;
        String description;

        for(Integer i = 0; i < accounts.size(); i++) {
            matchName = accounts[i].File_Import_Match_Name__c != NULL ? accounts[i].File_Import_Match_Name__c : accounts[i].Name;
            description = tx.Description__c;
            if (String.isNotBlank(description) && description.containsIgnoreCase(matchName)) {
                return accounts[i];
            }
        }
        return null;
    }

    private void cpGLVars(Account source, SObject target) {
        if (target.get('GL_Account_Variable_1__c') == null) {
            target.put('GL_Account_Variable_1__c', source.GL_Account_Variable_1__c);
        }
        if (target.get('GL_Account_Variable_2__c') == null) {
            target.put('GL_Account_Variable_2__c', source.GL_Account_Variable_2__c);
        }
        if (target.get('GL_Account_Variable_3__c') == null) {
            target.put('GL_Account_Variable_3__c', source.GL_Account_Variable_3__c);
        }
        if (target.get('GL_Account_Variable_4__c') == null) {
            target.put('GL_Account_Variable_4__c', source.GL_Account_Variable_4__c);
        }
    }

    public void transferAccountData(Bank_Transaction__c tx, SObject src) {
        switch on src {
            when Cash_Disbursement__c obj {
                transferAccountData(tx, obj);
            }
            when Cash_Receipt__c obj {
                transferAccountData(tx, obj);
            }
            when Journal_Entry_Line__c obj {
                transferAccountData(tx, obj);
            }
        }
    }

    public void transferAccountData(Bank_Transaction__c tx, Cash_Receipt__c src) {
        if (tx == null || src == null || src.Account__c != null) {
            return;
        }

        Account match = match(tx);
        if (match == null) {
            return;
        }

        src.Account__c = match.Id;
        cpGLVars(match, src);
    }

    public void transferAccountData(Bank_Transaction__c tx, Cash_Disbursement__c src) {
        if (tx == null || src == null || src.Vendor__c != null) {
            return;
        }

        Account match = match(tx);
        if (match == null) {
            return;
        }

        src.Vendor__c = match.Id;
        if (src.Debit_GL_Account__c == null && DEBIT_TYPE.equalsIgnoreCase(tx.Base_Type__c)) {
            src.Debit_GL_Account__c = match.Default_Expense_GL_Account__c;
        }
        cpGLVars(match, src);
    }

    public void transferAccountData(Bank_Transaction__c tx, Journal_Entry_Line__c src) {
        if (tx == null || src == null || src.Account__c != null) {
            return;
        }

        Account match = match(tx);
        if (match == null) {
            return;
        }

        src.Account__c = match.Id;
        if (src.GL_Account__c == null && DEBIT_TYPE.equalsIgnoreCase(tx.Base_Type__c)) {
            src.GL_Account__c = match.Default_Expense_GL_Account__c;
        }
        cpGLVars(match, src);
    }

    public void transferAccountData(
        Bank_Transaction__c tx, 
        Journal_Entry_Line__c credit, 
        Journal_Entry_Line__c debit
    ) {
        if (tx == null 
            || credit == null 
            || debit == null 
            || credit.Account__c != null 
            || debit.Account__c != null) {
            return;
        }

        Account match = match(tx);
        if (match == null) {
            return;
        }

        credit.Account__c = match.Id;
        debit.Account__c = match.Id;

        if (debit.GL_Account__c == null && DEBIT_TYPE.equalsIgnoreCase(tx.Base_Type__c)) {
            debit.GL_Account__c = match.Default_Expense_GL_Account__c;
        }
        cpGLVars(match, debit);
        cpGLVars(match, credit);
    }
}