public with sharing class FinancialCubesConsolidator {

    private Id consolidationLedgerId;
    private Id shadowConsolidationLedgerId;
    private Id accountingPeriodId;
    private Map<String, ConsolidatedResult> consolidatedResults = new Map<String, ConsolidatedResult>();

    public FinancialCubesConsolidator(Id consolidationLedgerId, Id accountingPeriodId) {
        this.consolidationLedgerId = consolidationLedgerId;
        this.accountingPeriodId = accountingPeriodId;

        this.shadowConsolidationLedgerId = LedgerHandler.getLedgerAccountingMethod(consolidationLedgerId) == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH
                ? LedgerHandler.getShadowLedger(consolidationLedgerId)?.Id
                : null;
    }

    public void addCube(Financial_Cube__c fCube) {
        String key = getKey(fCube);
        if (consolidatedResults.containsKey(key)) {
            consolidatedResults.get(key).addToBalance(fCube);
        }
        else {
            consolidatedResults.put(key, new ConsolidatedResult(fCube));
        }
    }

    public Set<String> getAggregationKeys() {
        return consolidatedResults.keySet();
    }

    public ConsolidatedResult getConsolidatedResultByKey(String key) {
        return consolidatedResults.get(key);
    }

    public List<Financial_Cube__c> getConsolidationCubes() {
        List<Financial_Cube__c> result = new List<Financial_Cube__c>();
        for (String key : consolidatedResults.keySet()) {
            Financial_Cube__c newFinCube = createFinCube(consolidatedResults.get(key));
            result.add(newFinCube);
        }
        return result;
    }

    public Financial_Cube__c getConsolidationCubeByKey(String key) {
        Financial_Cube__c newFinCube = createFinCube(consolidatedResults.get(key));
        return newFinCube;
    }

    private Financial_Cube__c createFinCube(ConsolidatedResult cResult) {
        Financial_Cube__c cube = new Financial_Cube__c(
            Ledger__c = cResult.accountingMethod == LedgerActions.ACCOUNTING_METHOD_CASH && String.isNotBlank(this.shadowConsolidationLedgerId)
                    ? this.shadowConsolidationLedgerId
                    : this.consolidationLedgerId,
            Accounting_Period__c = this.accountingPeriodId,
            GL_Account__c = cResult.glAccount,
            GL_Account_Variable_1__c = cResult.glav1,
            GL_Account_Variable_2__c = cResult.glav2,
            GL_Account_Variable_3__c = cResult.glav3,
            GL_Account_Variable_4__c = cResult.glav4,
            Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS,
            Amount__c = cResult.currentPeriod,
            Opening_Balance__c = cResult.openingBalance
        );
        //Key and KeyGroup fields will be set by trigger
        return cube;
    }

    private String getKey(Financial_Cube__c fCube) {
        String ledger = fCube.Ledger__r.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH && String.isNotBlank(this.shadowConsolidationLedgerId)
                ? this.shadowConsolidationLedgerId
                : (String.isNotBlank(this.consolidationLedgerId) ? this.consolidationLedgerId : 'null');
        String acctPeriod = this.accountingPeriodId != NULL ? this.accountingPeriodId : 'null';
        String glAccount = fCube.GL_Account__c != NULL ? String.valueOf(fCube.GL_Account__c) : 'null';
        String acctVar1 = fCube.GL_Account_Variable_1__c != NULL ? String.valueOf(fCube.GL_Account_Variable_1__c) : 'null';
        String acctVar2 = fCube.GL_Account_Variable_2__c != NULL ? String.valueOf(fCube.GL_Account_Variable_2__c) : 'null';
        String acctVar3 = fCube.GL_Account_Variable_3__c != NULL ? String.valueOf(fCube.GL_Account_Variable_3__c) : 'null';
        String acctVar4 = fCube.GL_Account_Variable_4__c != NULL ? String.valueOf(fCube.GL_Account_Variable_4__c) : 'null';

        String key =
            String.join(new List<String>{
                acctPeriod,
                ledger,
                FinancialCubeActions.FINANCIAL_CUBE_CONSOLIDATIONS,
                glAccount,
                acctVar1,
                acctVar2,
                acctVar3,
                acctVar4
            }, '');

        return key;
    }

    public with sharing class ConsolidatedResult {
        public Decimal currentPeriod;
        public Decimal openingBalance;
        public Id glAccount;
        public Id glav1;
        public Id glav2;
        public Id glav3;
        public Id glav4;
        public String accountingMethod;

        public ConsolidatedResult(Financial_Cube__c fCube) {
            this.openingBalance = (fCube.Opening_Balance__c != null) ? fCube.Opening_Balance__c : 0;
            this.currentPeriod = (fCube.Current_Period__c != null) ? fCube.Current_Period__c : 0;
            this.glAccount = fCube.GL_Account__c;
            this.glav1 = fCube.GL_Account_Variable_1__c;
            this.glav2 = fCube.GL_Account_Variable_2__c;
            this.glav3 = fCube.GL_Account_Variable_3__c;
            this.glav4 = fCube.GL_Account_Variable_4__c;
            this.accountingMethod = fCube.Ledger__r?.Accounting_Method__c;
        }

        public void addToBalance(Financial_Cube__c fCube) {
            this.openingBalance += ((fCube.Opening_Balance__c != null) ? fCube.Opening_Balance__c : 0);
            this.currentPeriod += ((fCube.Current_Period__c != null) ? fCube.Current_Period__c : 0);
        }
    }
}