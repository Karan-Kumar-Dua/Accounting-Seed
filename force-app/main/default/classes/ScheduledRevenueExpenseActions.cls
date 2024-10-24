public with sharing class ScheduledRevenueExpenseActions {

    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String TRANSACTION_CHECK_ERROR = Label.ERR_TRANSACTION_CHECK;

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Scheduled_Revenue_Expense__c.Amount__c => 2,
        Scheduled_Revenue_Expense__c.Quantity__c => 6
    };

    public static final String MULTIPLE_SOURCE_ERROR =
        Label.INF_ONLY_ONE_SOURCE_RECORD;
    public static final String SAME_SOURCE_LEDGER_ERROR =
            Label.INF_LEDGERS_AMORTIZATION_SAME;
    public static Boolean isFirstRun = true;

    public static void requireFields(List<Scheduled_Revenue_Expense__c> sreList) {
        for (Scheduled_Revenue_Expense__c sre : sreList) {
            if (sre.Ledger__c == NULL) {
                sre.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (sre.Debit_GL_Account__c == NULL) {
                sre.Debit_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (sre.Credit_GL_Account__c == NULL) {
                sre.Credit_GL_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            Ledger__c ledger = LedgerHandler.getInstanceWithoutSharing().getLedgerById(sre.Ledger__c);
            if (String.isBlank(sre.Accrual_and_or_Cash__c)
                    && ledger?.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                sre.Accrual_and_or_Cash__c.addError(Label.ERR_ACCRUAL_CASH_IS_REQUIRED_WHEN_ACCRUAL_CASH);
            }
            if (ledger?.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_CASH
                    && String.isNotBlank(sre.Accrual_and_or_Cash__c)
                    && sre.Accrual_and_or_Cash__c != LedgerActions.ACCOUNTING_METHOD_CASH) {
                sre.Accrual_and_or_Cash__c.addError(Label.ERR_ACCRUAL_LEDGER_DOES_NOT_EXIST);
            }
            if (ledger?.Accounting_Method__c == LedgerActions.ACCOUNTING_METHOD_ACCRUAL
                    && String.isNotBlank(sre.Accrual_and_or_Cash__c)
                    && sre.Accrual_and_or_Cash__c != LedgerActions.ACCOUNTING_METHOD_ACCRUAL) {
                sre.Accrual_and_or_Cash__c.addError(Label.ERR_CASH_LEDGER_DOES_NOT_EXIST);
            }
        }
    }

    public static void validateSourceField(List<Scheduled_Revenue_Expense__c> newAmortizationEntries) {
        for (Scheduled_Revenue_Expense__c amortEntry : newAmortizationEntries) {
            if ((amortEntry.Billing__c != NULL && (amortEntry.Account_Payable__c != NULL || amortEntry.Fixed_Asset__c != NULL))
                    || (amortEntry.Account_Payable__c != NULL && (amortEntry.Billing__c != NULL || amortEntry.Fixed_Asset__c != NULL))
                    || (amortEntry.Fixed_Asset__c != NULL && (amortEntry.Billing__c != NULL || amortEntry.Account_Payable__c != NULL))) {

                amortEntry.addError(MULTIPLE_SOURCE_ERROR);
            }
        }
    }

    public static void setDefaultAcctMethod(List<Scheduled_Revenue_Expense__c> scheduledRevenueExpenses) {
        for (Scheduled_Revenue_Expense__c scheduledRevenueExpense : scheduledRevenueExpenses) {
            if (String.isBlank(scheduledRevenueExpense.Accrual_and_or_Cash__c)
                    && String.isNotBlank(scheduledRevenueExpense.Ledger__c)
                    && LedgerHandler.getInstanceWithoutSharing().getLedgerById(scheduledRevenueExpense.Ledger__c)?.Accounting_Method__c != LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH) {
                scheduledRevenueExpense.Accrual_and_or_Cash__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(scheduledRevenueExpense.Ledger__c)?.Accounting_Method__c;
            }
        }
    }

    public static void setDefaultFields(List<Scheduled_Revenue_Expense__c> sreList) {
        String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(Scheduled_Revenue_Expense__c.Status__c);
        Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();
        for (Scheduled_Revenue_Expense__c sre : sreList) {
            sre.Status__c = (String.isBlank(sre.Status__c) || SObjectActions.isPostedStatus(sre)) ? defaultValue : sre.Status__c;
            SObjectActions.populateLedgerField(sre, defaultLedgerId);
            MulticurrencyHandler.setCurrencyIsoCodeByLedger(sre);
            if (String.isBlank(sre.Accrual_and_or_Cash__c) && String.isNotBlank(sre.Ledger__c)) {
                sre.Accrual_and_or_Cash__c = LedgerHandler.getInstanceWithoutSharing().getLedgerById(sre.Ledger__c)?.Accounting_Method__c;
            }
        }
    }

    public static void populateGLAVsFromAccountOrProduct(List<Scheduled_Revenue_Expense__c> newAmortizationEntries) {

        Map<Id, Product2> productMap = new Map<Id, Product2>();
        Map<Id, Account> accountMap = new Map<Id, Account>();

        for (Scheduled_Revenue_Expense__c amortEntry : newAmortizationEntries) {
            if (amortEntry.Fixed_Asset__c == null) {
                continue;
            }

            if (amortEntry.Product__c != NULL) {
                productMap.put(amortEntry.Product__c, NULL);
            }

            if (amortEntry.Account2__c != NULL) {
                accountMap.put(amortEntry.Account2__c, NULL);
            }
        }

        for (Product2 prod : DomainUtils.getProductsById(productMap.keySet())) {
            productMap.put(prod.Id, prod);
        }

        for (Account eachAccount : DomainUtils.getAccountsById(accountMap.keySet())) {
            accountMap.put(eachAccount.Id, eachAccount);
        }

        for (Scheduled_Revenue_Expense__c amortEntry : newAmortizationEntries) {
            if (amortEntry.Fixed_Asset__c == null) {
                continue;
            }

            if (amortEntry.GL_Account_Variable_1__c == NULL) {
                if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Account2__c, accountMap, 1)) {
                    amortEntry.GL_Account_Variable_1__c = accountMap.get(amortEntry.Account2__c).GL_Account_Variable_1__c;
                }
                else if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Product__c, productMap, 1)) {
                    amortEntry.GL_Account_Variable_1__c = productMap.get(amortEntry.Product__c).GL_Account_Variable_1__c;
                }
            }

            if (amortEntry.GL_Account_Variable_2__c == NULL) {
                if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Account2__c, accountMap, 2)) {
                    amortEntry.GL_Account_Variable_2__c = accountMap.get(amortEntry.Account2__c).GL_Account_Variable_2__c;
                }
                else if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Product__c, productMap, 2)) {
                    amortEntry.GL_Account_Variable_2__c = productMap.get(amortEntry.Product__c).GL_Account_Variable_2__c;
                }
            }

            if (amortEntry.GL_Account_Variable_3__c == NULL) {
                if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Account2__c, accountMap, 3)) {
                    amortEntry.GL_Account_Variable_3__c = accountMap.get(amortEntry.Account2__c).GL_Account_Variable_3__c;
                }
                else if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Product__c, productMap, 3)) {
                    amortEntry.GL_Account_Variable_3__c = productMap.get(amortEntry.Product__c).GL_Account_Variable_3__c;
                }
            }

            if (amortEntry.GL_Account_Variable_4__c == NULL) {
                if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Account2__c, accountMap, 4)) {
                    amortEntry.GL_Account_Variable_4__c = accountMap.get(amortEntry.Account2__c).GL_Account_Variable_4__c;
                }
                else if (SObjectActions.canTakeDefaultGLAVFromSource(amortEntry.Product__c, productMap, 4)) {
                    amortEntry.GL_Account_Variable_4__c = productMap.get(amortEntry.Product__c).GL_Account_Variable_4__c;
                }
            }
        }
    }

    public static void post(List<Scheduled_Revenue_Expense__c> newRecords) {
        if (AccountingSettingsHandler.isAutoPostAmortizationEntriesEnabled()) {
            AbstractPostHandler postHandler = new ScheduledRevenueExpensePostHandler();
            isFirstRun = false;//to bypass GLAccountValidator after Posting Status change
            List<PostResult> postResults = postHandler.post(newRecords);

            //Check posting results
            List<Task> postErrorActivities = new List<Task>();
            Set<Id> postedRecordIds = new Set<Id>();
            for (PostResult result : postResults) {
                if (!result.isSuccess) {
                    postErrorActivities.add(
                        FinancialSuiteUtils.setTask(
                            result.id,
                            Label.COMMON_ERR_CANNOT_POST_RECORD,
                            !result.errors.isEmpty() ? result.errors.get(0).message : NULL
                        )
                    );
                }
                else {
                    postedRecordIds.add(result.id);
                }
            }

            if (!postErrorActivities.isEmpty()) {
                SFDCSecurityUtils.insertProxy(postErrorActivities);
            }

            if (!postedRecordIds.isEmpty()) {
                //count Transactions existed for records passed post handler execution
                Set<Id> newRecordWithTransactions = new Set<Id>();
                for (AggregateResult aggregateResult : DomainUtils.countTransactionsByAmortizationEntry(postedRecordIds)) {
                    newRecordWithTransactions.add((Id) aggregateResult.get('sourceDoc'));
                }
                //check if Transactions were created for all new and successfully posted records
                for (Scheduled_Revenue_Expense__c amortizationEntry : newRecords) {
                    if (postedRecordIds.contains(amortizationEntry.Id) && !newRecordWithTransactions.contains(amortizationEntry.Id)) {
                        amortizationEntry.addError(TRANSACTION_CHECK_ERROR);
                    }
                }
            }
        }

    }

    public static void setAndValidateSameLedgerFromSourceRecord(List<Scheduled_Revenue_Expense__c> newAmortizationEntries) {
        Set<Id> billIds = new Set<Id>();
        Set<Id> payIds = new Set<Id>();
        Set<Id> assetIds = new Set<Id>();
        Map<Id, Billing__c> billMap = new Map<Id, Billing__c>();
        Map<Id, Account_Payable__c> payMap = new Map<Id, Account_Payable__c>();
        Map<Id, Fixed_Asset__c> assetMap = new Map<Id, Fixed_Asset__c>();
        for (Scheduled_Revenue_Expense__c amortEntry : newAmortizationEntries) {
            if (amortEntry.Billing__c != NULL ) {
                billIds.add(amortEntry.Billing__c);
            }
            if (amortEntry.Account_Payable__c != NULL ) {
                payIds.add(amortEntry.Account_Payable__c);
            }
            if (amortEntry.Fixed_Asset__c != NULL) {
                assetIds.add(amortEntry.Fixed_Asset__c);
            }
        }

        if (!billIds.isEmpty()) {
            billMap = new Map<Id, Billing__c>(DomainUtils.getBillingsById(billIds));
        }
        if (!payIds.isEmpty()) {
            payMap = new Map<Id, Account_Payable__c>(DomainUtils.getAccountPayablesById(payIds));
        }
        if (!assetIds.isEmpty()) {
            assetMap = new Map<Id, Fixed_Asset__c>(DomainUtils.getFixedAssetsById(assetIds));
        }

        if (!billMap.isEmpty() || !payMap.isEmpty() || !assetMap.isEmpty()) {
            for (Scheduled_Revenue_Expense__c amortEntry : newAmortizationEntries) {
                if (amortEntry.Billing__c != NULL
                    && billMap.containsKey(amortEntry.Billing__c)
                    && billMap.get(amortEntry.Billing__c).Ledger__c == NULL) {
                    billMap.get(amortEntry.Billing__c).Ledger__c = LedgerHandler.getLegacyDefaultLedgerId();
                }
                if (amortEntry.Billing__c != NULL
                        && billMap.containsKey(amortEntry.Billing__c)
                        && amortEntry.Ledger__c == NULL) {
                    amortEntry.Ledger__c = billMap.get(amortEntry.Billing__c).Ledger__c;
                }
                else if (amortEntry.Billing__c != NULL
                        && billMap.containsKey(amortEntry.Billing__c)
                        && amortEntry.Ledger__c != billMap.get(amortEntry.Billing__c).Ledger__c){
                    amortEntry.addError(
                            String.format(
                                    SAME_SOURCE_LEDGER_ERROR,
                                    new List<String> {SObjectType.Billing__c.getLabel()}));
                }

                if (amortEntry.Account_Payable__c != NULL
                    && payMap.containsKey(amortEntry.Account_Payable__c)
                    && payMap.get(amortEntry.Account_Payable__c).Ledger__c == NULL) {
                    payMap.get(amortEntry.Account_Payable__c).Ledger__c = LedgerHandler.getLegacyDefaultLedgerId();
                }
                if (amortEntry.Account_Payable__c != NULL
                        && payMap.containsKey(amortEntry.Account_Payable__c)
                        && amortEntry.Ledger__c == NULL) {
                    amortEntry.Ledger__c = payMap.get(amortEntry.Account_Payable__c).Ledger__c;
                }
                else if (amortEntry.Account_Payable__c != NULL
                        && payMap.containsKey(amortEntry.Account_Payable__c)
                        && amortEntry.Ledger__c != payMap.get(amortEntry.Account_Payable__c).Ledger__c){
                    amortEntry.addError(
                            String.format(
                                    SAME_SOURCE_LEDGER_ERROR,
                                    new List<String> {SObjectType.Account_Payable__c.getLabel()}));
                }

                if (amortEntry.Fixed_Asset__c != NULL
                    && assetMap.containsKey(amortEntry.Fixed_Asset__c)
                    && assetMap.get(amortEntry.Fixed_Asset__c).Ledger__c == NULL ) {
                    assetMap.get(amortEntry.Fixed_Asset__c).Ledger__c = LedgerHandler.getLegacyDefaultLedgerId();
                }
                if (amortEntry.Fixed_Asset__c != NULL
                        && assetMap.containsKey(amortEntry.Fixed_Asset__c)
                        && amortEntry.Ledger__c == NULL) {
                    amortEntry.Ledger__c = assetMap.get(amortEntry.Fixed_Asset__c).Ledger__c;
                }
                else if (amortEntry.Fixed_Asset__c != NULL
                        && assetMap.containsKey(amortEntry.Fixed_Asset__c)
                        && amortEntry.Ledger__c != assetMap.get(amortEntry.Fixed_Asset__c).Ledger__c){
                    amortEntry.addError(
                            String.format(
                                    SAME_SOURCE_LEDGER_ERROR,
                                    new List<String> {SObjectType.Fixed_Asset__c.getLabel()}));
                }

            }
        }

    }

}