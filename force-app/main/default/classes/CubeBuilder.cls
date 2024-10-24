public with sharing class CubeBuilder {

    //this flag can be set to true by xxxPostHandler class
    public static Boolean isEnabledCashFlowStatement = false;

    public static void handleAfterInsert(List<Transaction__c> transactions) {
        Map<String, Financial_Cube__c> periodCubeMap = new Map<String, Financial_Cube__c>();
        Map<String, Financial_Cube__c> cashFlowCubeMap = new Map<String, Financial_Cube__c>();

        try {
            Map<Id, GL_Account__c> glAccountMap;

            if (isEnabledCashFlowStatement) {
                //query for GL Accounts so we can get Cash GL Accounts (Bank__c == true)
                glAccountMap = getGLAccountByTransactions(transactions);
            }

            Set<String> keySet = new Set<String>();
            Set<Id> ledgerIds = new Set<Id>();
            // Initialize transaction sets to query
            for (Transaction__c t : transactions) {

                String ledger = t.Ledger__c != NULL ? String.valueOf(t.Ledger__c) : 'null';
                String acctPeriod = t.Accounting_Period__c != NULL ? String.valueOf(t.Accounting_Period__c) : 'null';
                String glAccount = t.GL_Account__c != NULL ? String.valueOf(t.GL_Account__c) : 'null';
                String acctVar1 = t.GL_Account_Variable_1__c != NULL ? String.valueOf(t.GL_Account_Variable_1__c) : 'null';
                String acctVar2 = t.GL_Account_Variable_2__c != NULL ? String.valueOf(t.GL_Account_Variable_2__c) : 'null';
                String acctVar3 = t.GL_Account_Variable_3__c != NULL ? String.valueOf(t.GL_Account_Variable_3__c) : 'null';
                String acctVar4 = t.GL_Account_Variable_4__c != NULL ? String.valueOf(t.GL_Account_Variable_4__c) : 'null';

                keySet.add(
                    String.join(
                        new List<String>{
                            acctPeriod,
                            ledger,
                            'Period',
                            glAccount,
                            acctVar1,
                            acctVar2,
                            acctVar3,
                            acctVar4
                        }, ''
                    )
                );
                ledgerIds.add(t.Ledger__c);

                if (isEnabledCashFlowStatement) {
                    String cashFlowCategory = t.Cash_Flow_Category__c != NULL ? String.valueOf(t.Cash_Flow_Category__c) : 'null';
                    keySet.add(
                        String.join(
                            new List<String>{
                                acctPeriod,
                                ledger,
                                'CashFlow',
                                cashFlowCategory,
                                acctVar1,
                                acctVar2,
                                acctVar3,
                                acctVar4
                            }, ''
                        )
                    );
                }
            }

            for (Financial_Cube__c fCube : DomainUtils.getFinancialCubesByKeyByLedgerIdByCubeType(keySet, ledgerIds, new Set<String>{'Period', 'Cash Flow'})) {
                String keyString = getPeriodKeyFromCube(fCube);
                if (fCube.Cube_Type__c == FinancialCubeActions.FINANCIAL_CUBE_PERIOD) {
                    periodCubeMap.put(keyString, fCube);
                }
                else if (fCube.Cube_Type__c == FinancialCubeActions.FINANCIAL_CUBE_CASH_FLOW) {
                    cashFlowCubeMap.put(keyString, fCube);
                }
            }

            List<Financial_Cube_Transaction__c> fctList = new List<Financial_Cube_Transaction__c>();
            Map<String, Financial_Cube__c> newPeriodCubeMap = new Map<String, Financial_Cube__c>();
            Map<String, Financial_Cube__c> newCashFlowCubeMap = new Map<String, Financial_Cube__c>();

            for (Transaction__c t : transactions) {
                //Generate the keys
                String periodKey = getPeriodKeyFromTransaction(t);
                String cashFlowKey = getCashFlowKeyFromTransaction(t);

                if (!periodCubeMap.containsKey(periodKey)) {
                    Financial_Cube__c periodCube = newPeriodCube(t);
                    newPeriodCubeMap.put(periodKey, periodCube);
                }

                if (isEnabledCashFlowStatement
                        && !cashFlowCubeMap.containsKey(cashFlowKey)
                        && t.Cash_Flow_Category__c != NULL
                        && glAccountMap.get(t.GL_Account__c).Bank__c) {

                    Financial_Cube__c cashFlowCube = newCashFlowCube(t);
                    newCashFlowCubeMap.put(cashFlowKey, cashFlowCube);
                }
            }

            FinancialCubeActions.isPreventOverride = true;
            List<Financial_Cube__c> finCubesForInsert = new List<Financial_Cube__c>();
            finCubesForInsert.addAll(newPeriodCubeMap.values());
            finCubesForInsert.addAll(newCashFlowCubeMap.values());
            SFDCSecurityUtils.insertProxy(finCubesForInsert);
            FinancialCubeActions.isPreventOverride = false;

            periodCubeMap.putAll(newPeriodCubeMap);
            cashFlowCubeMap.putAll(newCashFlowCubeMap);

            for (Transaction__c t : transactions) {
                String periodKey = getPeriodKeyFromTransaction(t);
                Financial_Cube_Transaction__c fct = new Financial_Cube_Transaction__c();
                fct.Transaction__c = t.Id;
                fct.Financial_Cube__c = periodCubeMap.get(periodKey).Id;
                fct.Amount__c = t.Amount__c;
                fctList.add(fct);

                if (isEnabledCashFlowStatement
                        && glAccountMap.get(t.GL_Account__c).Bank__c
                        && t.Cash_Flow_Category__c != NULL) {

                    String cashFlowKey = getCashFlowKeyFromTransaction(t);
                    Financial_Cube_Transaction__c fctCF = new Financial_Cube_Transaction__c();
                    fctCF.Transaction__c = t.Id;
                    fctCF.Financial_Cube__c = cashFlowCubeMap.get(cashFlowKey).Id;
                    fctCF.Amount__c = t.Amount__c;
                    fctList.add(fctCF);
                }
            }
            FinancialCubeTransactionActions.isPreventOverride = true;
            SFDCSecurityUtils.insertProxy(fctList);
            FinancialCubeTransactionActions.isPreventOverride = false;

        }
        catch (Exception ex) {
            for (Transaction__c trans : transactions) {
                trans.addError(ex);
            }
        }
    }

    public static void handleAfterDelete(List<Transaction__c> transactions) {
        List<Transaction__c> transactionList = new  List<Transaction__c>();
        for (Transaction__c trans : transactions) {
            transactionList.add(trans);

            if (transactionList.size() == 200) {
                Database.emptyRecycleBin(transactionList);
                transactionList.clear();
            }
        }

        if (transactionList.size() > 0) {
            Database.emptyRecycleBin(transactionList);
        }
    }

    private static Map<Id, GL_Account__c> getGLAccountByTransactions(List<Transaction__c> transactions) {
        Set<Id> glAccountIds = new Set<Id>();
        for (Transaction__c t : transactions) {
            glAccountIds.add(t.GL_Account__c);
        }
        return new Map<Id, GL_Account__c>(DomainUtils.getGlAccountsById(glAccountIds));
    }

    private static String getPeriodKeyFromCube(Financial_Cube__c fCube) {
        String acctPeriod = fCube.Accounting_Period__c != null ? String.valueOf(fCube.Accounting_Period__c) : 'null';
        String ledger = fCube.Ledger__c != null ? String.valueOf(fCube.Ledger__c) : 'null';
        String glAccount = fCube.GL_Account__c != null ? String.valueOf(fCube.GL_Account__c) : 'null';
        String glav1 = fCube.GL_Account_Variable_1__c != null ? String.valueOf(fCube.GL_Account_Variable_1__c) : 'null';
        String glav2 = fCube.GL_Account_Variable_2__c != null ? String.valueOf(fCube.GL_Account_Variable_2__c) : 'null';
        String glav3 = fCube.GL_Account_Variable_3__c != null ? String.valueOf(fCube.GL_Account_Variable_3__c) : 'null';
        String glav4 = fCube.GL_Account_Variable_4__c != null ? String.valueOf(fCube.GL_Account_Variable_4__c) : 'null';

        return String.join(
            new List<String>{
                acctPeriod,
                ledger,
                fCube.Cube_Type__c.remove(' '),
                glAccount,
                glav1,
                glav2,
                glav3,
                glav4
            }, ''
        );
    }

    private static String getPeriodKeyFromTransaction(Transaction__c t) {
        return String.valueOf(t.Accounting_Period__c) + getPeriodKeyGroupFromTransaction(t);
    }

    private static String getPeriodKeyGroupFromTransaction(Transaction__c t) {
        String ledger = t.Ledger__c != null ? String.valueOf(t.Ledger__c) : 'null';
        String glAccount = t.GL_Account__c != null ? String.valueOf(t.GL_Account__c) : 'null';
        String glav1 = t.GL_Account_Variable_1__c != null ? String.valueOf(t.GL_Account_Variable_1__c) : 'null';
        String glav2 = t.GL_Account_Variable_2__c != null ? String.valueOf(t.GL_Account_Variable_2__c) : 'null';
        String glav3 = t.GL_Account_Variable_3__c != null ? String.valueOf(t.GL_Account_Variable_3__c) : 'null';
        String glav4 = t.GL_Account_Variable_4__c != null ? String.valueOf(t.GL_Account_Variable_4__c) : 'null';

        return String.join(
            new List<String>{
                ledger,
                'Period',
                glAccount,
                glav1,
                glav2,
                glav3,
                glav4
            }, ''
        );
    }

    private static String getCashFlowKeyFromTransaction(Transaction__c t) {
        return String.valueOf(t.Accounting_Period__c) + getCashFlowKeyGroupFromTransaction(t);
    }

    private static String getCashFlowKeyGroupFromTransaction(Transaction__c t) {
        String ledger = t.Ledger__c != null ? String.valueOf(t.Ledger__c) : 'null';
        String cashFlowCategory = t.Cash_Flow_Category__c != null ? String.valueOf(t.Cash_Flow_Category__c) : 'null';
        String glav1 = t.GL_Account_Variable_1__c != null ? String.valueOf(t.GL_Account_Variable_1__c) : 'null';
        String glav2 = t.GL_Account_Variable_2__c != null ? String.valueOf(t.GL_Account_Variable_2__c) : 'null';
        String glav3 = t.GL_Account_Variable_3__c != null ? String.valueOf(t.GL_Account_Variable_3__c) : 'null';
        String glav4 = t.GL_Account_Variable_4__c != null ? String.valueOf(t.GL_Account_Variable_4__c) : 'null';

        return String.join(
            new List<String>{
                ledger,
                'CashFlow',
                cashFlowCategory,
                glav1,
                glav2,
                glav3,
                glav4
            }, ''
        );
    }

    private static Financial_Cube__c newPeriodCube(Transaction__c trans) {
        Financial_Cube__c newCube = newFinancialCube(trans);
        newCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_PERIOD;
        newCube.GL_Account__c = trans.GL_Account__c;
        newCube.Key__c = getPeriodKeyFromTransaction(trans);
        newCube.Key_Group__c = getPeriodKeyGroupFromTransaction(trans);
        return newCube;
    }

    private static Financial_Cube__c newCashFlowCube(Transaction__c trans) {
        Financial_Cube__c newCube = newFinancialCube(trans);
        newCube.Cube_Type__c = FinancialCubeActions.FINANCIAL_CUBE_CASH_FLOW;
        newCube.GL_Account__c = trans.Cash_Flow_Category__c;
        newCube.Key__c = getCashFlowKeyFromTransaction(trans);
        newCube.Key_Group__c = getCashFlowKeyGroupFromTransaction(trans);
        return newCube;
    }

    private static Financial_Cube__c newFinancialCube(Transaction__c trans) {
        Financial_Cube__c newCube = new Financial_Cube__c();
        newCube.Ledger__c = trans.Ledger__c;
        newCube.Accounting_Period__c = trans.Accounting_Period__c;
        newCube.Opening_Balance__c = 0;
        newCube.GL_Account_Variable_1__c = trans.GL_Account_Variable_1__c;
        newCube.GL_Account_Variable_2__c = trans.GL_Account_Variable_2__c;
        newCube.GL_Account_Variable_3__c = trans.GL_Account_Variable_3__c;
        newCube.GL_Account_Variable_4__c = trans.GL_Account_Variable_4__c;

        return newCube;
    }
}