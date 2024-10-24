global with sharing abstract class FinancialReportOptions {
    //===== GLOBAL class members ============
    global enum FinancialReportType {
        PROFIT_AND_LOSS, PROFIT_AND_LOSS_VS_BUDGET, BALANCE_SHEET, TRIAL_BALANCE, CASH_FLOW, LEDGER_INQUIRY, CUSTOM
    }

    global enum FinancialReportRoundingMode {
        NO_ROUNDING, WHOLE_AMOUNTS, ROUND_TO_1000
    }

    @AuraEnabled
    global Id ledger;
    @AuraEnabled
    global Id glVariable1;
    @AuraEnabled
    global Id glVariable2;
    @AuraEnabled
    global Id glVariable3;
    @AuraEnabled
    global Id glVariable4;
    @AuraEnabled
    global Id startingAccountingPeriod;
    @AuraEnabled
    global Id endingAccountingPeriod;
    @AuraEnabled
    global String subtitle;
    @AuraEnabled
    global Boolean includeSubType1;
    @AuraEnabled
    global Boolean includeSubType2;
    @AuraEnabled
    global Boolean suppressZeroAmountRows;
    @AuraEnabled
    global String currencyISO;
    @AuraEnabled
    global Boolean suppressOpeningBalanceAndPeriodColumns;
    @AuraEnabled
    public Map<String, String> currenciesByLedgerIds;

    global abstract List<String> getListOfPeriodNames();
    global abstract List<Accounting_Period__c> getAllPeriodsInReportingRange();
    global abstract List<Id> getLedgerIds();

    global FinancialReportOptions() {
        this.ledger = LedgerHandler.getInstanceWithSharing().getLedgerById(LedgerHandler.getLedgerId())?.Id;
        this.includeSubType1 = false;
        this.includeSubType2 = false;
        this.suppressZeroAmountRows = true;
        this.isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        this.currencyISO = LedgerHandler.getLedgerCurrency(this.ledger);
        this.isHLP = AccountingSettingsHandler.isHeaderLevelPost();
        setRoundingMode(FinancialReportRoundingMode.NO_ROUNDING);

        this.currenciesByLedgerIds = new Map<String, String>();
        if (this.isMultiCurrencyEnabled) {
            for (Ledger__c ledger : LedgerHandler.getInstanceWithSharing().getAllLedgers()) {
                currenciesByLedgerIds.put(ledger.Id, (String)ledger.get('CurrencyIsoCode'));
            }
        }
    }

    global void setRoundingMode(FinancialReportRoundingMode r) {
        this.currentRoundingMode = financialReportRoundingModeToString(r);
    }

    //======= NOT GLOBAL class members ===============
    private static final Map<FinancialReportType, String> reportNames = new Map<FinancialReportType, String> {
        FinancialReportType.PROFIT_AND_LOSS => 'Profit & Loss',
        FinancialReportType.PROFIT_AND_LOSS_VS_BUDGET => 'Profit & Loss Versus Budget',
        FinancialReportType.BALANCE_SHEET => 'Balance Sheet',
        FinancialReportType.TRIAL_BALANCE => 'Trial Balance',
        FinancialReportType.CASH_FLOW => 'Cash Flow Statement',
        FinancialReportType.LEDGER_INQUIRY => 'Ledger Inquiry',
        FinancialReportType.CUSTOM => 'Custom Report'
    };

    public static final Integer ACCOUNTING_PERIOD_RANGE_LIMIT = 12;
    public FinancialReportType reportType;
    @AuraEnabled
    public String currentRoundingMode;
    public List<GL_Account__c> glAccounts;
    @AuraEnabled
    public Boolean isMultiCurrencyEnabled;
    @AuraEnabled
    public Boolean isHLP;

    public String getStartPeriodName() {
        return AccountingPeriodHandler.getInstance().getAccountingPeriodById(startingAccountingPeriod)?.Name;
    }

    public String getReportTypeName() {
        return reportNames.get(reportType);
    }

    public static String getReportTypeName(FinancialReportType reportType) {
        return reportNames.get(reportType);
    }

    public String getReportSubtitle() {
        return subtitle;
    }

    private String financialReportRoundingModeToString(FinancialReportRoundingMode rmEnum) {
        String result;
        switch on rmEnum {
            when NO_ROUNDING {
                result = 'No Rounding';
            }
            when WHOLE_AMOUNTS {
                result = 'Whole Amounts';
            }
            when ROUND_TO_1000 {
                result = 'Round to 1000s';
            }
        }
        return result;
    }

    public FinancialReportRoundingMode getFinancialReportRoundingMode() {
        //For Custom report type - always return NO_ROUNDING
        if (this.reportType == FinancialReportType.CUSTOM) {
            return FinancialReportRoundingMode.NO_ROUNDING;
        }
        //For the rest of report types - return Rounding Mode based on current string value
        FinancialReportRoundingMode result;
        switch on currentRoundingMode {
            when 'No Rounding' {
                result = FinancialReportRoundingMode.NO_ROUNDING;
            }
            when 'Whole Amounts' {
                result = FinancialReportRoundingMode.WHOLE_AMOUNTS;
            }
            when 'Round to 1000s' {
                result = FinancialReportRoundingMode.ROUND_TO_1000;
            }
        }
        return result;
    }

    public Boolean isTrialBalanceForTranslatedBase() {
        Boolean result = false;
        if (this.reportType == FinancialReportType.TRIAL_BALANCE
                && this.isMultiCurrencyEnabled
                && this.currencyISO != LedgerHandler.getLedgerCurrency(this.ledger)) {

            result = true;
        }
        return result;
    }

}