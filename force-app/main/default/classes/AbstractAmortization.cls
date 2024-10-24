global with sharing abstract class AbstractAmortization {

    private final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    private final Map<SObjectType, SObjectField> accountType = new Map<SObjectType, SObjectField>{
            Billing__c.SObjectType => Billing__c.Customer__c,
            Account_Payable__c.SObjectType => Account_Payable__c.Vendor__c
    };

    private  Map<String, GL_Account_Default__c> defaultsBySpecDevNames;
    private AmortizationOptions abstractOption;

    global abstract AmortizationResult amortize(AmortizationOptions options, SObject sourceDocument);

    protected Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
    protected List<Accounting_Period__c> acctPeriods;

    global protected Scheduled_Revenue_Expense__c getBaseAmortizationEntry(AmortizationOptions option, SObject sourceDocument) {
        Scheduled_Revenue_Expense__c ae = new Scheduled_Revenue_Expense__c();
        ae.Name = (String) sourceDocument.get('Name');
        ae.Ledger__c = (Id) sourceDocument.get(PACKAGE_QUALIFIER +'Ledger__c');
        ae.Account2__c = sourceDocument.getSObjectType() == Fixed_Asset__c.SObjectType ? null : (Id) sourceDocument.get(accountType.get(option.sourceDocument.getSObjectType()));
        ae.Account_Payable__c = sourceDocument.getSObjectType() == Account_Payable__c.SObjectType ? option.sourceDocument : null;
        ae.Billing__c = sourceDocument.getSObjectType() == Billing__c.SObjectType ? option.sourceDocument : null;
        ae.Fixed_Asset__c = sourceDocument.getSObjectType() == Fixed_Asset__c.SObjectType ? option.sourceDocument : null;
        ae.Debit_GL_Account__c = option.debitGlAccount;
        ae.Credit_GL_Account__c = option.creditGlAccount;
        ae.GL_Account_Variable_1__c = option.glVariable1;
        ae.GL_Account_Variable_2__c = option.glVariable2;
        ae.GL_Account_Variable_3__c = option.glVariable3;
        ae.GL_Account_Variable_4__c = option.glVariable4;
        ae.Accrual_and_or_Cash__c = option.accrualCash;
        ae.Description__c = option.description;
        ae.Product__c = option.product;
        ae.Project__c = option.project;
        ae.Project_Task__c = option.projectTask;
        return ae;
    }

    public virtual void validateAmortizationOptions(AmortizationOptions options, SObject sourceDocument) {
        Amortization.validateAccountMethod(options, sourceDocument);
        Amortization.validateStartDate(options.startDate);
    }

    protected void setPeriodList(Date startDate, Date endDate) {
        acctPeriods = AccountingPeriodHandler.getInstance()
            .getAccountingPeriodsByDateRangeAndStatus(startDate, endDate, AccountingPeriodActions.OPEN_STATUS);
        acctPeriods.sort();
    }

    protected void setPeriodList(Date startDate, Integer numberOfPeriods) {
        AccountingPeriodHandler apHandler = AccountingPeriodHandler.getInstance();
        acctPeriods = apHandler.getAccountingPeriodsFromRange(apHandler.getAccountingPeriodByDate(startDate), numberOfPeriods);
        acctPeriods.sort();
    }

    protected Date calculateTransactionDate(Accounting_Period__c period, AmortizationOptions options) {
        Integer startDateOffset = acctPeriods[0].Start_Date__c.daysBetween(options.startDate);
        Date result = period.Start_Date__c.addDays(startDateOffset);
        if (period.End_Date__c < result) {
            result = period.End_Date__c;
        }
        if (result > options.endDate) {
            result = options.endDate;
        }
        return result;
    }

    //method used to set options in abstract class to further use in whole abstract
    public void setOptions(AmortizationOptions options) {
        abstractOption = options;
    }

    global protected Decimal getSobjectTotal(SObject sourceDocument) {
        return sourceDocument.getSObjectType() == Fixed_Asset__c.SObjectType ? (Decimal) sourceDocument.get(Fixed_Asset__c.Value__c) : getSobjectTotalAmount(sourceDocument);
    }

    private Decimal getSobjectTotalAmount(SObject sourceDocument) {
        return abstractOption.amortizeDefaultRevenuePrepaidExpense ? getDefaultGLPrepaidSubTotal(sourceDocument) : getSubTotalAmount(sourceDocument);
    }

    private Decimal getSubTotalAmount(SObject sourceDocument) {
        return isMultiCurrencyEnabled
            ? ((Decimal) sourceDocument.get(PACKAGE_QUALIFIER +'Sub_Total__c')
                / (Decimal) sourceDocument.get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c')).setScale(2, System.RoundingMode.HALF_UP)
            : (Decimal) sourceDocument.get(PACKAGE_QUALIFIER + 'Sub_Total__c');
    }

    /**
     * Description - method used to get the sum of subtotal of lines that post to default prepaid GL accounts
     */
    protected Decimal getDefaultGLPrepaidSubTotal(SObject sourceDocument) {
        Decimal lineSubTotal = 0.00;
        Boolean isRevenue = sourceDocument.getSObjectType() != Account_Payable__c.SObjectType;

        defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId((Id) sourceDocument.get(PACKAGE_QUALIFIER + 'Ledger__c'));
        Id defaultGLAccount =  isRevenue ? defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE)?.GL_Account__c
            : defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE)?.GL_Account__c;

        List<Sobject> lines = isRevenue ? (List<Sobject>) DomainUtils.getBillingLinesByMasterId(new Set<Id> {abstractOption.sourceDocument}).values()
            : (List<Sobject>) DomainUtils.getAccountPayableLinesByMasterId(new Set<Id> {abstractOption.sourceDocument}).values();

        for (Sobject line : lines) {
            if (AccountingSettingsHandler.isHeaderLevelPost()
                || (AccountingSettingsHandler.isLineLevelPost() && !(Boolean) line.get(PACKAGE_QUALIFIER + 'Tax_Line__c'))) {
                if((isRevenue && line.get(PACKAGE_QUALIFIER + 'Revenue_GL_Account__c') == defaultGLAccount)
                    || (!isRevenue && line.get(PACKAGE_QUALIFIER + 'Expense_GL_Account__c') == defaultGLAccount)) {
                    lineSubTotal = lineSubTotal + (isMultiCurrencyEnabled
                        ? ((Decimal) line.get(PACKAGE_QUALIFIER + 'Sub_Total__c')
                            / (Decimal) sourceDocument.get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c')).setScale(2, System.RoundingMode.HALF_UP)
                        : (Decimal) line.get(PACKAGE_QUALIFIER + 'Sub_Total__c'));
                }
            }
        }

        return lineSubTotal;
    }

}