public with sharing class AmortizationHelper extends AbstractLWCHelper {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static Map<String, GL_Account_Default__c> defaultsBySpecDevNames;

    @AuraEnabled
    public static Map<String, Object> createEntries(Map<String, Object> params) {
        Map<String, Object> response;
        try {
            AmortizationResult result = amortize(params);
            if (result.isSuccess) {
                if (MultiCurrencyHandler.isMultiCurrencyEnabled && params.get('ledgerId') != null) {
                    String currencyIsoCode = LedgerHandler.getLedgerCurrency(Id.valueOf((String)params.get('ledgerId')));
                    for (Scheduled_Revenue_Expense__c ae : result.amortizationEntries) {
                        ae.put('CurrencyIsoCode', currencyIsoCode);
                    }
                }
                List<String> accessFields = new List<String>{
                    PACKAGE_QUALIFIER + 'Ledger__c',
                    PACKAGE_QUALIFIER + 'Account2__c',
                    PACKAGE_QUALIFIER + 'Account_Payable__c',
                    PACKAGE_QUALIFIER + 'Billing__c',
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c',
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c',
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c',
                    PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c',
                    PACKAGE_QUALIFIER + 'Description__c',
                    PACKAGE_QUALIFIER + 'Project__c',
                    PACKAGE_QUALIFIER + 'Project_Task__c',
                    PACKAGE_QUALIFIER + 'Accounting_Period__c',
                    PACKAGE_QUALIFIER + 'Amount__c'
                };

                if (isProductAccessible()) {
                    accessFields.add(PACKAGE_QUALIFIER + 'Product__c');
                }

                SFDCSecurityUtils.insertCheckCRUDAndFLS(result.amortizationEntries, accessFields);
            }
            response = new Map<String, Object>{
                    'isSuccess' => result.isSuccess,
                    'errors' => result.errors
            };
        } catch (DmlException ex) {
            throw new AuraHandledException(ex.getDmlMessage(0));
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return response;
    }

    private static Boolean isProductAccessible() {
        return Product2.SObjectType.getDescribe().isAccessible() && Scheduled_Revenue_Expense__c.SObjectType.fields.Product__c.getDescribe().isAccessible();
    }

    @AuraEnabled
    public static Map<String, Object> fetchCalculations(Map<String, Object> params) {
        Map<String, Object> response;
        try {
            AmortizationResult result = amortize(params);

            List<Map<String, Object>> rows;
            if (result.isSuccess) {
                rows = new List<Map<String, Object>>();
                for (Scheduled_Revenue_Expense__c expense : result.amortizationEntries) {
                    List<String> nameParts = String.isNotBlank(expense.Name) ? expense.Name.split('-') : new List<String>();
                    rows.add(new Map<String, Object>{
                        'period' => nameParts.size() > 1 ? String.join(new List<String>{
                                nameParts[nameParts.size() - 2], nameParts[nameParts.size() - 1]
                        }, '-') : null,
                        'amount' => expense.Amount__c
                    });
                }
            }
            response = new Map<String, Object>{
                'isSuccess' => result.isSuccess,
                'errors' => result.errors,
                'rows' => rows,
                'isMultiCurrencyEnabled' => MultiCurrencyHandler.isMultiCurrencyEnabled,
                'currencyCode' => MultiCurrencyHandler.isMultiCurrencyEnabled && params.get('ledgerId') != null ?
                    LedgerHandler.getLedgerCurrency(Id.valueOf((String)params.get('ledgerId'))) : UserInfo.getDefaultCurrency()
            };
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return response;
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> fetchSettings(Id recordId) {
        List<AggregateResult> amountSumResults = DomainUtils.getScheduledRevenueExpensesAmountSum(recordId);
        return new Map<String, Object>{
                'isAutoPostEnabled' => AccountingSettingsHandler.isAutoPostAmortizationEntriesEnabled(),
                'existingAmountsSum' => !amountSumResults.isEmpty() ? amountSumResults[0].get('amountSum') : null,
                'methodOptions' => amortizationMethods()
        };
    }

    private static final String MONTHLY_DEV_NAME = 'MonthlyAmortization';
    private static final String STRAIGHT_LINE_DEV_NAME = 'StraightLineAmortization';
    private static final String DAILY_DEV_NAME = 'DailyAmortization';

    //this mapping is required to set a label that is more than 40 characters
    private static final Map<String, String> overridingLabelsByDevNames = new Map<String, String>{
    };

    private static List<Map<String, String>> amortizationMethods() {
        List<String> methodNamesWithOrder = new List<String>{STRAIGHT_LINE_DEV_NAME, MONTHLY_DEV_NAME, DAILY_DEV_NAME};
        Map<String, Binding__mdt> mAmortizationMethodTypesByLabels = (new AmortizationMethodFactory()).mAmortizationMethodTypes;
        Map<String, Binding__mdt> mAmortizationMethodTypesByDevNames = new Map<String, Binding__mdt>();
        for (Binding__mdt binding : mAmortizationMethodTypesByLabels.values()) {
            mAmortizationMethodTypesByDevNames.put(binding.DeveloperName, binding);
        }

        List<Map<String, String>> amortizationMethods = new List<Map<String, String>>();
        for (String methodDevName : methodNamesWithOrder) {
            Binding__mdt binding = mAmortizationMethodTypesByDevNames.get(methodDevName);
            if (binding != null) {
                String labelKey = AmortizationMethodFactory.normalizeTypeName(binding.Label);
                amortizationMethods.add(new Map<String, String>{
                    'label' => String.isNotBlank(overridingLabelsByDevNames.get(binding.DeveloperName)) ?
                        overridingLabelsByDevNames.get(binding.DeveloperName) : binding.Label,
                    'value' => labelKey
                });
                mAmortizationMethodTypesByLabels.remove(labelKey);
            }
        }
        for (String labelKey : mAmortizationMethodTypesByLabels.keySet()) {
            Binding__mdt binding = mAmortizationMethodTypesByLabels.get(labelKey);
            if (binding != null) {
                amortizationMethods.add(new Map<String, String>{
                    'label' => binding.Label,
                    'value' => labelKey
                });
            }
        }
        return amortizationMethods;
    }

    private static AmortizationResult amortize(Map<String, Object> params) {
        AmortizationOptions options = getOptions(params);
        options.amortizationMethod = String.valueOf(params.get('selectedMethod'));
        options.sourceDocument = params.get('sourceDocumentId') != null ?
                Id.valueOf((String)params.get('sourceDocumentId')) : null;

        return (new Amortization()).amortize(options);
    }

    private static AmortizationOptions getOptions(Map<String, Object> params) {
        AmortizationOptions options = new AmortizationOptions();

        options.amount = params.get(PACKAGE_QUALIFIER + 'Amount__c') != null ?
                Decimal.valueOf((String)params.get(PACKAGE_QUALIFIER + 'Amount__c')) : null;
        options.startDate = castToDateType(params.get('startDate'));
        options.endDate = castToDateType(params.get('endDate'));
        options.accrualCash = String.valueOf(params.get('accrualCash'));
        options.numberOfPeriods= castToIntegerType(params.get('accountingPeriodsNumber'));
        options.debitGlAccount = castToIdType(params.get(PACKAGE_QUALIFIER + 'Debit_GL_Account__c'));
        options.creditGlAccount = castToIdType(params.get(PACKAGE_QUALIFIER + 'Credit_GL_Account__c'));
        options.product = castToIdType(params.get(PACKAGE_QUALIFIER + 'Product__c'));
        options.project = castToIdType(params.get(PACKAGE_QUALIFIER + 'Project__c'));
        options.projectTask = castToIdType(params.get(PACKAGE_QUALIFIER + 'Project_Task__c'));
        options.glVariable1 = castToIdType(params.get(PACKAGE_QUALIFIER + 'GL_Account_Variable_1__c'));
        options.glVariable2 = castToIdType(params.get(PACKAGE_QUALIFIER + 'GL_Account_Variable_2__c'));
        options.glVariable3 = castToIdType(params.get(PACKAGE_QUALIFIER + 'GL_Account_Variable_3__c'));
        options.glVariable4 = castToIdType(params.get(PACKAGE_QUALIFIER + 'GL_Account_Variable_4__c'));
        options.description = params.get(PACKAGE_QUALIFIER + 'Description__c') != null ?
                (String)params.get(PACKAGE_QUALIFIER + 'Description__c') : null;
        options.amortizeDefaultRevenuePrepaidExpense =  (Boolean)params.get('amortizeDefaultRevenuePrepaidExpense');

        return options;
    }

    private static Id castToIdType(Object value) {
        return value != null ? Id.valueOf((String)value) : null;
    }

    private static Date castToDateType(Object value) {
        String formattedDate = value != null ? (String)value : null;
        return String.isNotBlank(formattedDate) ? Date.valueOf(formattedDate) : null;
    }

    private static Integer castToIntegerType(Object value) {
        String formattedInteger = value != null ? (String)value : null;
        return String.isNotBlank(formattedInteger) ? Integer.valueOf(formattedInteger) : null;
    }

    @AuraEnabled(Cacheable=true)
    public static AccountingInfoWrapper getAccountingInfo(Id recordId) {
        List<Sobject> lines = getSobjectLinesByRecordId(recordId);
        Sobject obj = getSobjectByRecordId(recordId);
        AccountingInfoWrapper aiw = setUniqValuesFromLines(lines);
        setInitialAmount(aiw, obj);
        setEmptyGlavValuesFromAccount(aiw, obj);
        setGlAccounts(aiw, obj);
        return aiw;
    }

    private static List<Sobject> getSobjectLinesByRecordId(Id recordId) {
        List<Sobject> res;
        switch on recordId.getSobjectType().newSobject() {
            when Billing__c objRecord {
                res = (List<Sobject>) getBillingLines(recordId);
            }
            when Account_Payable__c objRecord {
                res = (List<Sobject>) getPayableLines(recordId);
            }
            when Fixed_Asset__c objRecord {
                res = new List<SObject>();
            }
        }
        return res;
    }

    private static Sobject getSobjectByRecordId(Id recordId) {
        Sobject res;
        switch on recordId.getSobjectType().newSobject() {
            when Billing__c objRecord {
                res = ((List<Sobject>) getBilling(recordId))[0];
            }
            when Account_Payable__c objRecord {
                res = ((List<Sobject>) getPayable(recordId))[0];
            }
            when Fixed_Asset__c objRecord {
                res = ((List<Sobject>) getFixedAsset(recordId))[0];
            }
        }
        return res;
    }

    private static void setInitialAmount(AccountingInfoWrapper wrapper, SObject obj) {
        wrapper.initialAmount  = obj.getSObjectType() == Fixed_Asset__c.SObjectType
            ? (Decimal) obj.get(Fixed_Asset__c.Value__c)
            : (MultiCurrencyHandler.isMultiCurrencyEnabled
                ? ((Decimal) obj.get(PACKAGE_QUALIFIER +'Sub_Total__c')
                    / (Decimal) obj.get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c')).setScale(2, System.RoundingMode.HALF_UP)
                : (Decimal) obj.get(PACKAGE_QUALIFIER + 'Sub_Total__c'));
    }

    private static void setGlAccounts(AccountingInfoWrapper wrapper, SObject obj) {
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId((Id) obj.get(PACKAGE_QUALIFIER + 'Ledger__c'));
        Boolean isRevenue = obj.getSobjectType() == Billing__c.getSObjectType() || obj.getSobjectType() == Fixed_Asset__c.getSObjectType();
        wrapper.debitGlAccount = isRevenue ?
            defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE)?.GL_Account__c :
            getAccountPayeeExpenseGlAccount(obj, defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_EXPENSE)?.GL_Account__c);

        wrapper.creditGlAccount = isRevenue ?
            defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_REVENUE)?.GL_Account__c :
            defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE)?.GL_Account__c;

    }

    private static Id getAccountPayeeExpenseGlAccount(SObject obj, Id defaultDebitExpenseId) {
        return (Id) obj.get(Account_Payable__c.Vendor__c) != null
            && obj.getSObject(PACKAGE_QUALIFIER + 'Vendor__r').get(PACKAGE_QUALIFIER + 'Default_Expense_GL_Account__c') != null
            ? (Id) obj.getSObject(PACKAGE_QUALIFIER + 'Vendor__r').get(PACKAGE_QUALIFIER + 'Default_Expense_GL_Account__c')
            : defaultDebitExpenseId;
    }

    private static AccountingInfoWrapper setUniqValuesFromLines(List<Sobject> lines) {
        AccountingInfoWrapper wrapper = new AccountingInfoWrapper();
        Id productId;
        Boolean isProductIdUniq = true;
        Id projectId;
        Boolean isProjectIdUniq = true;
        Id projectTaskId;
        Boolean isProjectTaskIdUniq = true;
        Id glVariable1Id;
        Boolean isGlVariable1IdUniq = true;
        Id glVariable2Id;
        Boolean isGlVariable2IdUniq = true;
        Id glVariable3Id;
        Boolean isGlVariable3IdUniq = true;
        Id glVariable4Id;
        Boolean isGlVariable4IdUniq = true;
        Decimal lineSubTotal = 0.00;

        if (!lines.isEmpty()) {
            Boolean isRevenue = lines[0].getSObjectType() != Account_Payable_Line__c.SObjectType;
            Decimal ccr = lines[0].getSObjectType() == Account_Payable_Line__c.SObjectType
                ? (Decimal) lines[0].getSObject(PACKAGE_QUALIFIER + 'Account_Payable__r').get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c')
                : (Decimal) lines[0].getSObject(PACKAGE_QUALIFIER + 'Billing__r').get(PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c');

            defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId((Id) lines[0].get(PACKAGE_QUALIFIER + 'Ledger__c'));
            Id defaultGLAccount =  isRevenue ? defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_DEBIT_GL_ACCOUNT_REVENUE)?.GL_Account__c
                : defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CREDIT_GL_ACCOUNT_EXPENSE)?.GL_Account__c;

            for (Sobject line : lines) {
                productId = setTempId(productId, line, 'Product__c');
                isProductIdUniq = setUniqueness(productId, line, 'Product__c');
                projectId = setTempId(projectId, line, 'Project__c');
                isProjectIdUniq = setUniqueness(projectId, line, 'Project__c');
                projectTaskId = setTempId(projectTaskId, line, 'Project_Task__c');
                isProjectTaskIdUniq = setUniqueness(projectTaskId, line, 'Project_Task__c');
                glVariable1Id = setTempId(glVariable1Id, line, 'GL_Account_Variable_1__c');
                isGlVariable1IdUniq = setUniqueness(glVariable1Id, line, 'GL_Account_Variable_1__c');
                glVariable2Id = setTempId(glVariable2Id, line, 'GL_Account_Variable_2__c');
                isGlVariable2IdUniq = setUniqueness(glVariable2Id, line, 'GL_Account_Variable_2__c');
                glVariable3Id = setTempId(glVariable3Id, line, 'GL_Account_Variable_3__c');
                isGlVariable3IdUniq = setUniqueness(glVariable3Id, line, 'GL_Account_Variable_3__c');
                glVariable4Id = setTempId(glVariable4Id, line, 'GL_Account_Variable_4__c');
                isGlVariable4IdUniq = setUniqueness(glVariable4Id, line, 'GL_Account_Variable_4__c');

                if (AccountingSettingsHandler.isHeaderLevelPost()
                    || (AccountingSettingsHandler.isLineLevelPost() && !(Boolean) line.get(PACKAGE_QUALIFIER + 'Tax_Line__c'))) {
                    if((isRevenue && line.get(PACKAGE_QUALIFIER + 'Revenue_GL_Account__c') == defaultGLAccount)
                        || (!isRevenue && line.get(PACKAGE_QUALIFIER + 'Expense_GL_Account__c') == defaultGLAccount)) {
                        lineSubTotal = lineSubTotal + (MultiCurrencyHandler.isMultiCurrencyEnabled
                            ? ((Decimal) line.get(PACKAGE_QUALIFIER + 'Sub_Total__c') / ccr).setScale(2, System.RoundingMode.HALF_UP)
                            : (Decimal) line.get(PACKAGE_QUALIFIER + 'Sub_Total__c'));
                    }
                }
            }
        }

        wrapper.product = isProductIdUniq ? productId : null;
        wrapper.project = isProjectIdUniq ? projectId : null;
        wrapper.projectTask = isProjectTaskIdUniq ? projectTaskId : null;
        wrapper.glVariable1 = isGlVariable1IdUniq ? glVariable1Id : null;
        wrapper.glVariable2 = isGlVariable2IdUniq ? glVariable2Id : null;
        wrapper.glVariable3 = isGlVariable3IdUniq ? glVariable3Id : null;
        wrapper.glVariable4 = isGlVariable4IdUniq ? glVariable4Id : null;
        wrapper.lineSubTotal = lineSubTotal;

        return wrapper;
    }

    private static Id setTempId(Id tempId, SObject line, String field) {
        return line.get(PACKAGE_QUALIFIER + field) != null && tempId == null ? (Id) line.get(PACKAGE_QUALIFIER + field) : tempId;
    }

    private static Boolean setUniqueness(Id tempId, SObject line, String field) {
        return !(line.get(PACKAGE_QUALIFIER + field) != null && tempId != null && line.get(PACKAGE_QUALIFIER + field) != tempId);
    }

    private static void setEmptyGlavValuesFromAccount(AccountingInfoWrapper wrapper, SObject obj) {
        if (isAccountPopulated(obj) &&
            (wrapper.glVariable1 == null || wrapper.glVariable2 == null || wrapper.glVariable3 == null || wrapper.glVariable4 == null)) {

            String accountFieldName = obj.getSobjectType() == Billing__c.getSObjectType() ? 'Customer__r' : 'Vendor__r';
            wrapper.glVariable1 = wrapper.glVariable1 == null
                ? getGlavId(obj, 'GL_Account_Variable_1__c', accountFieldName) : wrapper.glVariable1;
            wrapper.glVariable2 = wrapper.glVariable2 == null
                ? getGlavId(obj, 'GL_Account_Variable_2__c', accountFieldName) : wrapper.glVariable2;
            wrapper.glVariable3 = wrapper.glVariable3 == null
                ? getGlavId(obj, 'GL_Account_Variable_3__c', accountFieldName) : wrapper.glVariable3;
            wrapper.glVariable4 = wrapper.glVariable4 == null
                ? getGlavId(obj, 'GL_Account_Variable_4__c', accountFieldName) : wrapper.glVariable4;
        }
    }

    private static Boolean isAccountPopulated(SObject obj) {
        Boolean res = false;
        switch on obj {
            when Billing__c objRecord {
                res = objRecord.Customer__c != null;
            }
            when Account_Payable__c objRecord {
                res = objRecord.Vendor__c != null;
            }
        }
        return res;
    }

    private static Id getGlavId(SObject obj, String field, String accountFieldName) {
        return obj.getSObject(PACKAGE_QUALIFIER + accountFieldName).get(PACKAGE_QUALIFIER + field) != null
            ? (Id) obj.getSObject(PACKAGE_QUALIFIER + accountFieldName).get(PACKAGE_QUALIFIER + field) : null;
    }

    private static List<Billing_Line__c> getBillingLines(Id recordId) {
        return DomainUtils.getBillingLinesByMasterId(new Set<Id> {recordId}).values();
    }

    private static List<Account_Payable_Line__c> getPayableLines(Id recordId) {
        return DomainUtils.getAccountPayableLinesByMasterId(new Set<Id> {recordId}).values();
    }

    private static List<Billing__c> getBilling(Id recordId) {
        return DomainUtils.getBillingsById(new Set<Id> {recordId});
    }

    private static List<Account_Payable__c> getPayable(Id recordId) {
        return DomainUtils.getAccountPayablesById(new Set<Id> {recordId});
    }

    private static List<Fixed_Asset__c> getFixedAsset(Id recordId) {
        return DomainUtils.getFixedAssetsById(new Set<Id> {recordId});
    }

    @AuraEnabled
    public static AccountingPeriodsWrapper isAccountingPeriodsValid(String periodInfo) {
        AccountingPeriodsWrapper periodInfoWrapper = (AccountingPeriodsWrapper) JSON.deserialize(periodInfo, AccountingPeriodsWrapper.class);

        AccountingPeriodsWrapper result = periodInfoWrapper == null ? new AccountingPeriodsWrapper() : periodInfoWrapper;

        try {
            Accounting_Period__c startPeriod;
            Accounting_Period__c endPeriod;
            if (result.startDate != null) {
                startPeriod = AccountingPeriodHandler.getInstance()
                    .getAccountingPeriodByDateAndStatus(result.startDate, AccountingPeriodActions.OPEN_STATUS);
            }

            if (startPeriod == null) {
                throw new Amortization.AmortizationException();
            }

            if (result.startDate != null && result.periodNumber != null) {
                endPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(startPeriod, result.periodNumber - 1);

                if (endPeriod == null || endPeriod.Id == null) {
                    throw new Amortization.AmortizationException();
                }

                if (endPeriod.Start_Date__c.addDays((startPeriod.Start_Date__c.daysBetween(result.startDate))) > endPeriod.End_Date__c) {
                    result.endDate = endPeriod.End_Date__c;
                }
                else {
                    result.endDate = endPeriod.Start_Date__c.addDays((startPeriod.Start_Date__c.daysBetween(result.startDate)));
                }
            }

            if (result.startDate != null && result.endDate != null && validateDateRange(result.startDate, result.endDate)) {
                throw new Amortization.AmortizationException();
            }

            if (result.startDate != null && result.endDate != null) {
                result.periodNumber = AccountingPeriodHandler.getInstance()
                    .getAccountingPeriodsByDateRangeAndStatus(result.startDate, result.endDate, AccountingPeriodActions.OPEN_STATUS).size();
            }

            result.isError = validateDateRange(result.startDate, result.endDate);
        }
        catch (Exception e) {
            result.isError = true;
        }

        return result;
    }

    private static Boolean validateDateRange(Date startDate, Date endDate) {
        List<Accounting_Period__c> acctPeriods = AccountingPeriodHandler.getInstance()
            .getAccountingPeriodsByDateRangeAndStatus(startDate, endDate, AccountingPeriodActions.OPEN_STATUS);
        if (acctPeriods == null || acctPeriods.isEmpty()
            || acctPeriods[0].Start_Date__c > startDate || acctPeriods[acctPeriods.size() - 1].End_Date__c < endDate) {
            return true;
        }
        return false;
    }

    public with sharing class AccountingPeriodsWrapper {
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
        @AuraEnabled
        public Integer periodNumber;
        @AuraEnabled
        public Boolean isError = false;

    }

    public with sharing class AccountingInfoWrapper {
        @AuraEnabled
        public Id product;
        @AuraEnabled
        public Id project;
        @AuraEnabled
        public Id projectTask;
        @AuraEnabled
        public Id glVariable1;
        @AuraEnabled
        public Id glVariable2;
        @AuraEnabled
        public Id glVariable3;
        @AuraEnabled
        public Id glVariable4;
        @AuraEnabled
        public Id debitGlAccount;
        @AuraEnabled
        public Id creditGlAccount;
        @AuraEnabled
        public Decimal lineSubTotal;
        @AuraEnabled
        public Decimal initialAmount;
    }

}