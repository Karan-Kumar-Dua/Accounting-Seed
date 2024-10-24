public with sharing class BalanceBuilder {

    private Map<String, Decimal> periodBal = new Map<String, Decimal>();
    private Map<String, Decimal> yearToDateBal = new Map<String, Decimal>();
    private Map<String, Decimal> openingBal = new Map<String, Decimal>();

    private Boolean calculateOpeningBalance;

    //empty constructor used in Financial Report Generator
    //Opening Balance in this case will be taken as YTD Balance of previous period
    public BalanceBuilder() {
        calculateOpeningBalance = false;
    }
    //Use this constructor to get Opening Balance directly calculated using OBal field on FC for given period
    public BalanceBuilder(Boolean withOpeningBalance) {
        calculateOpeningBalance = withOpeningBalance;
    }

    public void addCube(Financial_Cube__c fCube) {
        String ledger = fCube.Ledger__c;
        String gla = fCube.GL_Account__c;
        String av1 = fCube.GL_Account_Variable_1__c;
        String av2 = fCube.GL_Account_Variable_2__c;
        String av3 = fCube.GL_Account_Variable_3__c;
        String av4 = fCube.GL_Account_Variable_4__c;

        for (String avHash : generateAVHashes(ledger, gla, av1, av2, av3, av4)) {

            String periodHash = fCube.Accounting_Period__r.Name;
            if (periodBal.containsKey(periodHash + avHash)) {
                Decimal bal = periodBal.get(periodHash + avHash);
                bal = bal + fCube.Current_Period__c;
                periodBal.put(periodHash + avHash, bal);
            }
            else {
                periodBal.put(periodhash + avHash, fCube.Current_Period__c);
            }

            if (yearToDateBal.containsKey(periodHash + avHash)) {
                Decimal bal = yearToDateBal.get(periodHash + avHash);
                bal = bal + fCube.Year_To_Date__c;
                yearToDateBal.put(periodHash + avHash, bal);
            }
            else {
                yearToDateBal.put(periodhash + avHash, fCube.Year_To_Date__c);
            }

            //used for Ledger Inquiry & Trial Balance (FCT scenario) reports =========
            if (calculateOpeningBalance) {
                if (openingBal.containsKey(periodHash + avHash)) {
                    Decimal bal = openingBal.get(periodHash + avHash);
                    bal = bal + fCube.Opening_Balance__c;
                    openingBal.put(periodHash + avHash, bal);
                }
                else {
                    openingBal.put(periodHash + avHash, fCube.Opening_Balance__c);
                }
            }
            //=======================================================================
        }
    }

    private Decimal getTransactionAmount(Financial_Cube__c fCube) {
        Decimal result = 0;
        if (fCube.Cube_Type__c == 'Current Year Earnings' || fCube.Cube_Type__c == 'Retained Earnings') {
            return result;
        }
        else {
            if (fCube.Transaction_Amount__c == 0 && fCube.Amount__c != 0) {
                result = fCube.Amount__c;
            }
            else {
                result = fCube.Transaction_Amount__c;
            }
        }
        return result;
    }

    public void clear() {
        periodBal.clear();
        yearToDateBal.clear();
        openingBal.clear();
    }

    public Set<String> generateAVHashes(String ledger, String gla, String av1, String av2, String av3, String av4) {

        Set<String> avHashes = new Set<String>();

        avHashes.add(ledger + gla + 'nullnullnullnull');

        avHashes.add(ledger + gla + av1 + 'nullnullnull');
        avHashes.add(ledger + gla + av1 + av2 + 'nullnull');
        avHashes.add(ledger + gla + av1 + av2 + av3 + + 'null');
        avHashes.add(ledger + gla + av1 + av2 + av3 + av4);

        avHashes.add(ledger + gla + av1 + 'nullnull' + av4);
        avHashes.add(ledger + gla + av1 + 'null' + av3 + 'null');
        avHashes.add(ledger + gla + av1 + 'null' + av3 + av4);

        avHashes.add(ledger + gla + 'null' + av2 + 'nullnull');
        avHashes.add(ledger + gla  + 'null' + av2 + av3  + 'null');
        avHashes.add(ledger + gla  + 'null' + av2 + av3 + av4);
        avHashes.add(ledger + gla  + 'null' + av2  + 'null' + av4);

        avHashes.add(ledger + gla + 'nullnull' + av3 + 'null');
        avHashes.add(ledger + gla + 'nullnull' + av3 + av4);

        avHashes.add(ledger + gla + 'nullnullnull' + av4);

        return avHashes;
    }

    public Decimal getPeriodBalance(String period, String ledger, String gla, String av1, String av2, String av3, String av4) {

        String avHash = ledger + gla + av1 + av2 + av3 + av4;

        if (periodBal.containsKey(period + avHash)) {
            return periodBal.get(period + avHash);
        }
        else {
            return 0;
        }
    }

    public Decimal getPeriodBalanceForGroup(String period, String ledger, List<String> glas, String av1, String av2, String av3, String av4) {

        Decimal value = 0;

        for (String gla : glas) {
            value = value + getPeriodBalance(period, ledger, gla, av1, av2, av3, av4);
        }

        return value;

    }

    public Decimal getYTDBalance(String period, String ledger, String gla, String av1, String av2, String av3, String av4) {

        String avHash = ledger + gla + av1 + av2 + av3 + av4;

        if (yearToDateBal.containsKey(period + avHash)) {
            return yearToDateBal.get(period + avHash);
        }
        else {
            return 0;
        }

    }

    public Decimal getOpeningBalance(String period, String ledger, String gla, String av1, String av2, String av3, String av4) {

        String avHash = ledger + gla + av1 + av2 + av3 + av4;

        if (openingBal.containsKey(period + avHash)) {
            return openingBal.get(period + avHash);
        }
        else {
            return 0;
        }

    }

    public Decimal getYTDBalanceForGroup(String period, String ledger, List<String> glas, String av1, String av2, String av3, String av4) {

        Decimal value = 0;

        for (String gla : glas) {
            value = value + getYTDBalance(period, ledger, gla, av1, av2, av3, av4);
        }

        return value;

    }
}