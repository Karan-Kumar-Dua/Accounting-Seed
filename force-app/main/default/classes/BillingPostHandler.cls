public with sharing class BillingPostHandler extends AbstractPostHandler {

    @TestVisible
    private static final String BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE = Label.ERR_PAYABLE_LINE_COUNT_LIMIT_EXCEEDED;
    @TestVisible
    private static final String NO_CONTROL_ACCOUNT_MESSAGE = Label.ERR_BILLING_NO_CONTROL_ACCOUNT;
    @TestVisible
    private static final String NO_BILL_LINES_ERROR_MESSAGE = Label.ERR_NO_BILLING_LINES_POST;

    public static final String NO_SELECTION_UNPOSTED_ERROR_MESSAGE = Label.ERR_NO_RECORDS_SELECTED;
    public static final Integer BILLING_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT = 500;
    public static final Integer BILLING_LINE_COUNT_PRODUCT_COSTING_LIMIT = 250;
    public static final Integer BILLING_LINE_COUNT_PRODUCT_COSTING_AND_KITTING_LIMIT =
        AccountingSettingsHandler.isStandardCostProductCostingEnabled() ? 100 : BILLING_LINE_COUNT_PRODUCT_COSTING_LIMIT;
    public static final Integer UNPOST_BILLING_LINE_COUNT_LIMIT = 1000;

    private Set<Id> outOfScopeLineIds = new Set<Id>();
    private Boolean IS_AVATAX_CALC_ENABLED = false;
    private List<Billing__c> billingsToUncommitOnAvalaraSide = new List<Billing__c>();
    private static AbstractTaxService service = AccountingSettingsHandler.isHeaderLevelPost()
        ? (AbstractTaxService) new NativeTaxHeaderLevel() : (AbstractTaxService) new NativeTaxLineLevel();

    // =========== LDV Support ===========================
    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        List<Billing_Line__c> processedLines = new List<Billing_Line__c>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            processedLines.addAll((List<Billing_Line__c>)item.lines);
            sourceMap.put(item.id, item);
        }

        Map<Id, PostResult> postResults = new Map<Id, PostResult>();

        this.processedRecordIds = new List<Id>(sourceMap.keySet());
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        queryBillings();
        this.sourceRecords = filterRecordsByAcctMethods(
                this.sourceRecords,
                new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_ACCRUAL}
        );
        getGLAccountDefaults();

        if (validateARControlGLAccount()) {
            validateNotPosted(true);
            validateAccountingPeriodIsOpen(true);
            validateLedgerType(true, true);
            validateLedgerTaxSetting(true);
            validateNoQualifyingPostedRecords();
            if (!sourceRecords.isEmpty()) {
                sourceRecordLines = processedLines;
                IS_AVATAX_CALC_ENABLED = AvaTaxHelper.isAvalaraTaxCalculationEnabled(sourceRecords);
                //AvaTax Calculation (Finalized variant: Committed AvaTax Transactions & Updated Billing Lines)
                if (IS_AVATAX_CALC_ENABLED
                    && validateBillingsCountLimitForLDVAvaTaxCalc(
                    AccountingSettingsHandler.isHeaderLevelPost()
                        ? AbstractPostHandler.LDV_AVALARA_SELECTED_RECORDS_LIMIT
                        : AbstractPostHandler.LDV_AVALARA_SELECTED_RECORDS_LIMIT + 1)
                    && validateBillingsCountLimitForAvaTaxCalc(true)
                    && validateMultipleAvalaraLicense()
                    && !AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords).isEmpty()) {
                    Boolean doCommit = true;
                    setAvalaraSource(AvaTaxService.DocumentType.SalesInvoice, doCommit);

                    AvaTaxHelper.isLDVBatchContext = true;
                    List<TaxServiceResult> avaTaxCalcResults =
                        TaxService.calcTaxes(AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords));
                    processAvaTaxCalcResult(true, avaTaxCalcResults[0].avaTaxCalcResult, doCommit);
                    if (!IS_HEADER_LEVEL_POST && doCommit) {
                        //re-query lines to get
                        queryBillingLines();
                    }
                }
                Map<Id, Billing_Line__c> processedLinesMap;
                if (!IS_HEADER_LEVEL_POST) {
                    processedLinesMap = new Map<Id, Billing_Line__c>((List<Billing_Line__c>) sourceRecordLines);
                }
                for (Transaction__c tr : buildTransactions()) {
                    Id billId = IS_HEADER_LEVEL_POST ? tr.Billing__c : processedLinesMap.get(tr.Billing_Line__c).Billing__c;
                    if (!postResults.containsKey(billId)) {
                        PostResult res = new PostResult(true, billId, '', sourceMap.get(billId).transactionGroup);
                        res.transactions.add(tr);
                        postResults.put(billId, res);
                    }
                    else {
                        postResults.get(billId).transactions.add(tr);
                    }

                }
            }
            processPostResult();
            ldvValidatePostResultMap(postResults);
        }

        return postResults.values();
    }

    public override List<PostResult> unpost(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        List<Billing_Line__c> processedLines = new List<Billing_Line__c>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();

        for (LDVPostInput item : sourceItems) {
            sourceMap.put(item.id, item);
            processedLines.addAll((List<Billing_Line__c>)item.lines);
        }

        Map<Id, PostResult> postResults = new Map<Id, PostResult>();
        this.processedRecordIds = new List<Id>(sourceMap.keySet());
        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);

                queryBillings();
                this.sourceRecords = filterRecordsByAcctMethods(
                        this.sourceRecords,
                        new Set<String>{LedgerActions.ACCOUNTING_METHOD_ACCRUAL_CASH, LedgerActions.ACCOUNTING_METHOD_ACCRUAL}
                );
                IS_AVATAX_CALC_ENABLED = AvaTaxHelper.isAvalaraTaxCalculationEnabled(sourceRecords);
                //weed out the unsuitable billings
                validateIsPostedByApproval(true);
                validateAccountingPeriodIsOpen(true);
                validateLedgerTaxSetting(true);
                //no need to proceed further if there is no valid Billings after all validations above
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOSTED_ERROR_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    sourceRecordLines = processedLines;
                    processPostResult();
                }
                dispatcher.isPreCheck = false;
            }
            catch (System.DmlException dmlEx) {
                processDmlExceptions(dmlEx);
            }
            catch (Exception ex) {
                processSystemExceptions(ex);
            }

            ldvGetPostResultMap(postResults, sourceMap);
        }
        return postResults.values();
    }

    public void processLDVPostBillingsTransaction(List<PostResult> processedResults) {

        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }

        try {
            List<Transaction__c> transList = new List<Transaction__c>();
            Map<Id, Billing__c> needUpdateStatus = new Map<Id, Billing__c>();
            Set<String> transactionKeys = new Set<String>();

            for (PostResult item : processedResults) {
                for (Transaction__c tr : item.transactions) {
                    TransactionKey tk = new TransactionKey(tr);
                    transactionKeys.add(tk.hashCode());
                    transList.add(tr);
                }
                if (item.transactionGroup.Line_Count__c == item.transactionGroup.Lines_Processed__c) {
                    needUpdateStatus.put(item.id, null);
                }
            }

            if (IS_HEADER_LEVEL_POST) {
                List<Transaction__c> existedTransactions = getExistedTransactionByKeys(transactionKeys);

                Map<String, Transaction__c> existedTransactionMap = new Map<String, Transaction__c>();
                for (Transaction__c tr : existedTransactions) {
                    existedTransactionMap.put(getTransactionKey(tr, false), tr);
                }

                for (Transaction__c tr : transList) {
                    if (existedTransactionMap.containsKey(getTransactionKey(tr, false))) {
                        consolidateTransaction(existedTransactionMap.get(getTransactionKey(tr, false)), tr);
                    }
                }

                TransactionActions.deleteTransactions(existedTransactions);
            }

            for (Billing__c billing : (List<Billing__c>) sourceRecords) {
                if (needUpdateStatus.containsKey(billing.Id)) {
                    billing.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                    needUpdateStatus.put(billing.Id, billing);
                }
            }

            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(needUpdateStatus.values(), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            sourceRecords = DomainUtils.getBillingsByIdForUpdate(needUpdateStatus.keySet());
            validatePostStatusSet();

            TransactionActions.createTransactions(transList);
            if (!Test.isRunningTest() && IS_AVATAX_CALC_ENABLED && !billingsToUncommitOnAvalaraSide.isEmpty()) {
                asyncAvalaraUncommit(billingsToUncommitOnAvalaraSide);
            }
        }
        catch (Exception ex) {
            //moving rollback before the asyncAvalaraUncommit method because the enqueueJob gets rolled back otherwise
            Database.rollback(sp);
            
            if (!Test.isRunningTest() && IS_AVATAX_CALC_ENABLED) {
                asyncAvalaraUncommit(AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords));
            }
            
            throw ex;
        }
    }

    public void processLDVUnpostBillingsTransactions(List<PostResult> processedResults) {
        if (IS_AVATAX_CALC_ENABLED) {
            List<Billing__c> selectedBills = (List<Billing__c>) AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords);
            if (!selectedBills.isEmpty()) {
                AvaTaxService.FetchResultTransactionModel avalaraTrans = AvaTaxHelper.getAvalaraTransactions(selectedBills);
                processAvaTaxResult(avalaraTrans, selectedBills);
            }
            AvaTaxHelper.uncommitTransactions(AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords));
        }

        Map<Id, Billing__c> needUpdateStatus = new Map<Id, Billing__c>();
        for (PostResult item : processedResults) {
            if (item.transactionGroup.Line_Count__c == item.transactionGroup.Lines_Processed__c) {
                needUpdateStatus.put(item.id, null);
            }
        }

        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }
        try {
            if (IS_HEADER_LEVEL_POST) {
                List<Billing_Line__c> linesForDeleteTaxTransaction = new List<Billing_Line__c>();
                Map<Id, Billing__c> processedBillingMap = new Map<Id, Billing__c>((List<Billing__c>) sourceRecords);

                Set<String> transactionKeys = new Set<String>();
                for (Billing_Line__c line : (List<Billing_Line__c>) sourceRecordLines) {
                    TransactionKey tk = new TransactionKey(processedBillingMap.get(line.Billing__c), line);
                    transactionKeys.add(tk.hashCode());
                    if (needUpdateStatus.containsKey(line.Billing__c)) {
                        linesForDeleteTaxTransaction.add(line);
                    }
                }

                TransactionActions.deleteTransactions(getExistedTransactionByKeys(transactionKeys));
                if (!linesForDeleteTaxTransaction.isEmpty()) {
                    TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                        linesForDeleteTaxTransaction, true
                    ));
                }
            } else {
                TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                    sourceRecordLines, false
                ));
            }

            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Billing__c.Status__c);
            for (Billing__c bill : (List<Billing__c>) this.sourceRecords) {
                if (needUpdateStatus.containsKey(bill.Id)) {
                    bill.Status__c = defaultPostingStatus;
                    if (bill.Due_Date2__c == NULL && bill.Date__c != NULL) {
                        bill.Due_Date2__c = bill.Date__c;
                    }
                    needUpdateStatus.put(bill.Id, bill);
                }
            }

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField> {Billing__c.Status__c, Billing__c.Locked_In_AvaTax__c});
            SFDCSecurityUtils.updateCheckCRUDAndFLS(needUpdateStatus.values(), new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField> {Billing__c.Status__c, Billing__c.Locked_In_AvaTax__c});

            if (IS_AVATAX_CALC_ENABLED) {
                List<Billing_Line__c> deleteList = getOldAvalaraTaxLineList();
                if (!deleteList.isEmpty()) {
                    SFDCSecurityUtils.deleteProxy(deleteList);
                }
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }
    //====================================================

    //Post method implementation for Billings ====================================================
    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Billing__c> billingsMap = new Map<Id, Billing__c>((List<Billing__c>) processedRecords);
        return post(new List<Id>(billingsMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for billings
                queryBillings();
                getGLAccountDefaults();
                if (validateARControlGLAccount()) {
                    //weed out the unsuitable billings
                    validateNotPosted(false);
                    validateStatusApproved(false);
                    validateAccountingPeriodIsOpen(false);
                    validateLedgerType(false, false);
                    validateLedgerTaxSetting(false);
                    //validate all billings have billing lines
                    validateBillingLinesExist(false);

                    //no need to proceed further if there is no valid Billings after all validations above
                    validateNoQualifyingPostedRecords();

                    if (!sourceRecords.isEmpty()) {
                        IS_AVATAX_CALC_ENABLED = AvaTaxHelper.isAvalaraTaxCalculationEnabled(sourceRecords);
                        //it's time to query Billing Lines
                        queryBillingLines();
                        //AvaTax Calculation (Finalized variant: Committed AvaTax Transactions & Updated Billing Lines)
                        if (IS_AVATAX_CALC_ENABLED
                            && validateBillingsCountLimitForAvaTaxCalc(false)
                            && validateMultipleAvalaraLicense()
                            && !AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords).isEmpty()) {
                            Boolean doCommit = true;
                            setAvalaraSource(AvaTaxService.DocumentType.SalesInvoice, doCommit);

                            List<TaxServiceResult> avaTaxCalcResults =
                                TaxService.calcTaxes(AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords));
                            processAvaTaxCalcResult(false, avaTaxCalcResults[0].avaTaxCalcResult, doCommit);
                        }
                        //validate line count and if everything is OK => execute Posting business logic
                        if (validateBillingPostLineLimit() && validateMultipleAvalaraLicense()) {
                            processPostBillings();
                            processPostResult();
                        }
                    }
                }
                else {
                    processPostResult();
                }
                dispatcher.isPreCheck = false;
            }
            catch (DmlException dmlEx) {
                processDmlExceptions(dmlEx);
            }
            catch (Exception ex) {
                processSystemExceptions(ex);
            }
        } 

        submitSuccessfulResultsToAvaVAT(); 
        return dispatcher.getPostResults();
    }

    //===========================================================================================
    //UnPost method implementation for Billings =================================================
    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Billing__c> billingsMap = new Map<Id, Billing__c>((List<Billing__c>) processedRecords);
        return unpost(new List<Id>(billingsMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for billings
                queryBillings();
                IS_AVATAX_CALC_ENABLED = AvaTaxHelper.isAvalaraTaxCalculationEnabled(sourceRecords);
                //weed out the unsuitable billings
                validateIsPosted(false);
                validateAccountingPeriodIsOpen(false);
                validateLedgerTaxSetting(false);
                //no need to proceed further if there is no valid Billings after all validations above
                validateNoQualifyingUnpostedRecords(NO_SELECTION_UNPOSTED_ERROR_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    //it's time to query Billing Lines
                    queryBillingLines();
                    //validate line count and if everything is OK => execute UnPosting business logic
                    if (validateUnpostLineLimit()) {
                        processUnpostBillings();
                        processPostResult();
                    }
                }
                dispatcher.isPreCheck = false;
            }
            catch (System.DmlException dmlEx) {
                processDmlExceptions(dmlEx);
            }
            catch (Exception ex) {
                processSystemExceptions(ex);
            }
        }

        submitSuccessfulResultsToAvaVAT();
        return dispatcher.getPostResults();
    }
    //===========================================================================================
    private void queryBillings() {
        sourceRecords = queryBillings(this.processedRecordIds);
    }
    public static List<SObject> queryBillings(List<Id> processedRecordIds) {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String>{
            'Id',
            'Name',
            'Status__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Status__c',
            'Date__c',
            'Due_Date2__c',
            'Billing_Cash_Receipt_Count__c',
            'Credit_Memo_Applied_Amount__c',
            'Proprietary_Billing_Number__c',
            'Type__c',
            'Line_Count__c',
            'Customer__c',
            'Locked_In_AvaTax__c',
            'Ledger__c',
            'Ledger__r.Type__c',
            'Ledger__r.Tax_Settings__c',
            'Ledger__r.Accounting_Method__c',
            'Ledger__r.Name'
        };
        //Add Multicurrency related fields
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            fieldsToQuery.addAll(new List<String>{'CurrencyIsoCode', 'Currency_Conversion_Rate__c'});
        }
        //Add subqueries
        List<String> subQueryRelationshipNames = new List<String>{
            GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Credit_Memos__r',
            GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Credit_Memos1__r'
        };
        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';

        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            subQueryRelationshipNames,
            Billing__c.SObjectType,
            queryCondition,
            true,
            false
        );

        return Database.query(dynamicSOQL);
    }

    private void queryBillingLines() {
        List<String> fieldsToQuery = new List<String>{
            'Id',
            'Name',
            'Time_Card_Variable_2__c',
            'Time_Card_Variable_1__c',
            'Rate__c',
            'Project_Task__c',
            'Revenue_GL_Account__c',
            'Employee__c',
            'Billing__c',
            'Product__c',
            'Hours_Units__c',
            'Total__c',
            'Sub_Total__c',
            'Date__c',
            'Tax_Group__c',
            'Tax_Amount2__c',
            'Tax_Line__c',
            'Ledger__c',
            'Product_Unit_Cost__c',
            'Inventory_GL_Account__c',
            'Expense_GL_Account__c',
            'Billing__r.Customer__c',
            'Billing__r.Status__c',
            'Billing__r.Ledger__c',
            'Billing__r.Proprietary_Billing_Number__c',
            'Billing__r.Name',
            'Billing__r.Type__c',
            'Billing__r.Date__c',
            'Billing__r.Accounting_Period__c',
            'Billing__r.Ledger__c',
            'Project__c',
            'Project_Task__r.Project__c',
            'Project_Task__r.GL_Account_Variable_1__c',
            'Project_Task__r.GL_Account_Variable_2__c',
            'Project_Task__r.GL_Account_Variable_3__c',
            'Project_Task__r.GL_Account_Variable_4__c',
            'Product__r.Inventory_Product__c',
            'Product__r.Inventory_Type__c',
            'Product__r.Unit_Cost__c',
            'Product__r.GL_Account_Variable_1__c',
            'Product__r.GL_Account_Variable_2__c',
            'Product__r.GL_Account_Variable_3__c',
            'Product__r.GL_Account_Variable_4__c',
            'Product__r.Expense_GL_Account__c',
            'Product__r.Inventory_GL_Account__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Tax_Inclusive__c',
            'Combined_Tax_Rate__c'
        };

        if (IS_AVATAX_CALC_ENABLED) {
            fieldsToQuery.addAll(new List<String>{
                'Product__c',
                'Product__r.Name',
                'Product__r.ProductCode',
                'Product__r.Tax_Code__c',
                'Product__r.Description',
                'Opportunity_Product_Id__c',
                'Recurring_Billing_Line__c',
                'Billing__r.Shipping_Street__c',
                'Billing__r.Shipping_City__c',
                'Billing__r.Shipping_State__c',
                'Billing__r.Shipping_PostalCode__c',
                'Billing__r.Shipping_Country__c',
                'Billing__r.Destination_Address_Override__c',
                'Billing__r.Destination_Address_Override__r.Street__c',
                'Billing__r.Destination_Address_Override__r.City__c',
                'Billing__r.Destination_Address_Override__r.State_Province__c',
                'Billing__r.Destination_Address_Override__r.Postal_Code__c',
                'Billing__r.Destination_Address_Override__r.Country_Code__c',
                'Line_Destination_Address_Override__r.City__c',
                'Line_Destination_Address_Override__r.Country_Code__c',
                'Line_Destination_Address_Override__r.Postal_Code__c',
                'Line_Destination_Address_Override__r.State_Province__c',
                'Line_Destination_Address_Override__r.Street__c',
                'Line_Origin_Address_Override__r.City__c',
                'Line_Origin_Address_Override__r.Country_Code__c',
                'Line_Origin_Address_Override__r.Postal_Code__c',
                'Line_Origin_Address_Override__r.State_Province__c',
                'Line_Origin_Address_Override__r.Street__c'
            });
        }

        String queryCondition = '';
        if (isLDVBatchContext && !IS_HEADER_LEVEL_POST) {
            queryCondition += 'Id IN :sourceRecordLines AND ';
        }
        queryCondition += 'Billing__c IN :sourceRecords LIMIT 1001 FOR UPDATE';

        String dynamicSOQL = SOQLBuilder.buildDynamicSoqlQuery(
            fieldsToQuery,
            NULL,
            Billing_Line__c.SObjectType,
            queryCondition,
            true,
            false
        );

        sourceRecordLines = Database.query(dynamicSOQL);
    }

    public void validateBeforePost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        Map<Id, Billing__c> billingsMap = new Map<Id, Billing__c>((List<Billing__c>) processedRecords);
        this.processedRecordIds = new List<Id>(billingsMap.keySet());

        //Initial query for billings
        queryBillings();
        getGLAccountDefaults();
        validateARControlGLAccount();
        //weed out the unsuitable billings
        validateNotPosted(fullStatistics);
        validateStatusApproved(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        validateLedgerType(fullStatistics, false);
        validateLedgerTaxSetting(fullStatistics);
        //validate all billings have billing lines
        validateBillingLinesExist(fullStatistics);
        if (!sourceRecords.isEmpty()) {
            IS_AVATAX_CALC_ENABLED = AvaTaxHelper.isAvalaraTaxCalculationEnabled(sourceRecords);
        }

        if (this.isLDVBatchContext) {
            validateBillingsCountLimitForLDVAvaTaxCalc(AbstractPostHandler.LDV_AVALARA_SELECTED_RECORDS_LIMIT);
        }

        if (!this.isLDVBatchContext && !sourceRecords.isEmpty()) {
            //it's time to query Billing Lines
            queryBillingLines();
            //validate line count
            validateBillingPostLineLimit();
            //AvaTax Calculation (Estimated)
            if (IS_AVATAX_CALC_ENABLED
                && validateBillingsCountLimitForAvaTaxCalc(fullStatistics)
                && validateMultipleAvalaraLicense()
                && !AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords).isEmpty()) {
                Boolean doCommit = false;
                setAvalaraSource(AvaTaxService.DocumentType.SalesOrder, doCommit);

                List<TaxServiceResult> avaTaxCalcResults =
                    TaxService.calcTaxes(AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords));
                processAvaTaxCalcResult(false, avaTaxCalcResults[0].avaTaxCalcResult, doCommit);
            }
        }
        //add positive results
        processPostResult();
    }

    public void validateBeforeUnpost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        Map<Id, Billing__c> billingsMap = new Map<Id, Billing__c>((List<Billing__c>) processedRecords);
        this.processedRecordIds = new List<Id>(billingsMap.keySet());
        //Initial query for billings
        queryBillings();
        IS_AVATAX_CALC_ENABLED = AvaTaxHelper.isAvalaraTaxCalculationEnabled(sourceRecords);
        //weed out the unsuitable billings
        validateIsPosted(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        validateLedgerTaxSetting(fullStatistics);
        if (!this.isLDVBatchContext) {
            validateBillingsCountLimitForAvaTaxCalc(fullStatistics);
        }
        if (!this.isLDVBatchContext && !sourceRecords.isEmpty()) {
            //it's time to query Billing Lines
            queryBillingLines();
            //validate line count
            validateUnpostLineLimit();
        }
        //add positive results
        processPostResult();
    }

    private Boolean validateARControlGLAccount() {
        return validateARControlGLAccount(this.sourceRecords, this.glAccountDefaults, this.dispatcher);
    }
    public static Boolean validateARControlGLAccount(List<SObject> sourceRecords, Map<Id, Map<String, GL_Account_Default__c>> glAccountDefaults, PostResultDispatcher dispatcher) {
        Boolean isValid = true;
        for (Billing__c bill : (List<Billing__c>) sourceRecords) {
            if (!glAccountDefaults.containsKey(bill.Ledger__c) ||
                (glAccountDefaults.containsKey(bill.Ledger__c)
                    && !glAccountDefaults.get(bill.Ledger__c).containsKey(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT))) {
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.NO_CONTROL_AR_ACCOUNT_DEFINED,
                        NO_CONTROL_ACCOUNT_MESSAGE
                    )
                );
                isValid = false;
            }
        }
        return isValid;
    }

    private Boolean validateMultipleAvalaraLicense() {
        if (IS_AVATAX_CALC_ENABLED && AvaTaxHelper.isMultipleAvaTaxLicenseExist(sourceRecords)) {
            for (Billing__c bill : (List<Billing__c>) sourceRecords) {
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.AVATAX_SERVICE_ERROR,
                        Label.MULTIPLE_AVALARA_LICENSE_ERROR
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }

    private void validateBillingLinesExist(Boolean fullStatistics) {
        this.sourceRecords = validateBillingLinesExist(this.sourceRecords, this.dispatcher, fullStatistics);
    }

    public static List<SObject> validateBillingLinesExist(List<SObject> sourceRecords, PostResultDispatcher dispatcher, Boolean fullStatistics) {
        Map<Id, Billing__c> preSelectedBillings = new Map<Id, Billing__c>((List<Billing__c>) sourceRecords);

        //CRUD and FLS already has been checked at this point. No need to check again;
        Set<Id> parentIdsWithLines = DomainUtils.parentIdsWithLines(
                String.valueOf(Billing_Line__c.getSObjectType()),
                String.valueOf(Billing_Line__c.Billing__c),
                preSelectedBillings.keySet()
        );
        for (Billing__c bill : new List<Billing__c>(preSelectedBillings.values())) {
            if (!parentIdsWithLines.contains(bill.Id)) {
                preSelectedBillings.remove(bill.Id);
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.NO_LINES,
                        NO_BILL_LINES_ERROR_MESSAGE
                    )
                );
            }
        }
        //the rest of Billings will have all fields selected in the initial SOQL query
        if (!fullStatistics) {
            sourceRecords = preSelectedBillings.values();
        }

        return sourceRecords;
    }

    private void setAvalaraSource(AvaTaxService.DocumentType docType, Boolean doCommit) {
        if (IS_HEADER_LEVEL_POST) {
            AvaTaxHeaderLevel.documentType = docType;
            AvaTaxHeaderLevel.sourceRecordLines = sourceRecordLines;
            AvaTaxHeaderLevel.doCommit = doCommit;
        }
        else {
            AvaTaxLineLevel.documentType = docType;
            AvaTaxLineLevel.sourceRecordLines = sourceRecordLines;
            AvaTaxLineLevel.doCommit = doCommit;
        }
    }

    private void processAvaTaxCalcResult(Boolean fullStatistics, AvaTaxHelper.AvaTaxCalculationResult avaTaxCalcResult, Boolean doCommit) {
        Map<Id, Billing__c> validRecordsMap = new Map<Id, Billing__c>((List<Billing__c>) sourceRecords);
        this.billingsToUncommitOnAvalaraSide = new List<SObject>();
        if (isLDVBatchContext) {
            Map<Id, SObject> sourceRecordLinesByIds = new Map<Id, SObject>(sourceRecordLines);
            for (Id billingId : avaTaxCalcResult.reportMap.keySet()) {
                AvaTaxHelper.AvaTaxCalculationReport avaTaxCalcReport = avaTaxCalcResult.reportMap.get(billingId);
                if (avaTaxCalcReport.isSuccess) {
                    for (SObject line : avaTaxCalcReport.lines) {
                        if (!sourceRecordLinesByIds.containsKey(line.Id)) {
                            outOfScopeLineIds.add(line.Id);
                        }
                        sourceRecordLinesByIds.put(line.Id, line);
                    }
                }
            }
            sourceRecordLines = sourceRecordLinesByIds.values();
        }

        for (Id billingId : avaTaxCalcResult.reportMap.keySet()) {
            //Extract AvaTax Calculation Report for the Billing record
            AvaTaxHelper.AvaTaxCalculationReport avaTaxCalcReport = avaTaxCalcResult.reportMap.get(billingId);
            //Tax Amount can be safely populated on each affected line if tax calc result is successful
            if (avaTaxCalcReport.isSuccess) {
                AvaTaxHelper.populateUpdatedTaxes(avaTaxCalcReport, sourceRecordLines);
            }
            else {//There was some issue with Tax Calculation
                //If it was "over apply" or any of potential "AvaTax Service Callout" issue
                // - exclude the Billing record from processed list and put error into dispatcher
                if (avaTaxCalcReport.isErrorExists(AvaTaxHelper.AvaTaxCalculationErrorStatusCode.OVER_APPLY_ERROR)
                        || avaTaxCalcReport.isErrorExists(AvaTaxHelper.AvaTaxCalculationErrorStatusCode.AVATAX_SERVICE_ERROR)) {

                    Billing__c notValidBilling = validRecordsMap.get(billingId);
                    dispatcher.addPostErrorResult(
                        notValidBilling,
                        new PostResult.PostErrorResult(
                            notValidBilling,
                            PostResult.StatusCode.AVATAX_SERVICE_ERROR,
                            avaTaxCalcResult.reportMap.get(billingId).error.errorMsg
                        )
                    );
                    validRecordsMap.remove(notValidBilling.Id);
                    if (doCommit && avaTaxCalcReport.error.code == AvaTaxHelper.AvaTaxCalculationErrorStatusCode.OVER_APPLY_ERROR) {
                        //Since "Over Application" validation is proceeded after successful callout to the AvaTax service -
                        //we have related transaction on Avalara side with "Committed" status at this point
                        //and therefore we have to store the Billing record
                        //to make async "Uncommit" AvaTax callout at the end of the posting routine
                        billingsToUncommitOnAvalaraSide.add(notValidBilling);
                    }
                }
                //any errors/exceptions not equal to OVER_APPLY_ERROR and AVATAX_SERVICE_ERROR will not have any impact on the posting flow
                //we will just not populate new/updated Tax Amounts for such records
            }
        }

        if (!fullStatistics) {
            sourceRecords = validRecordsMap.values();
            sourceRecordLines = filterOutValidOnlyLines();
            if (!IS_HEADER_LEVEL_POST && doCommit) {
                //re-query lines to get
                queryBillingLines();
            }
        }
    }

    private List<Billing_Line__c> filterOutValidOnlyLines() {
        List<Billing_Line__c> result = new List<Billing_Line__c>();
        Set<Id> validBillingIds = new Map<Id, SObject>(sourceRecords).keySet();
        for (Billing_Line__c line : (List<Billing_Line__c>) sourceRecordLines) {
            if (validBillingIds.contains(line.Billing__c)) {
                result.add(line);
            }
        }
        return result;
    }

    private Boolean validateBillingsCountLimitForAvaTaxCalc(Boolean fullStatistics) {
        if (!IS_AVATAX_CALC_ENABLED) {
            return true;
        }
        Integer billingCount = 0;
        //count only records passed preceded validations:
        //in case if all initially selected billings are still in the main collection
        if (fullStatistics) {
            for (Billing__c bill : (List<Billing__c>) AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords)) {
                PostResult billPostResult = dispatcher.getPostResultsMap().get(bill.Id);
                if (billPostResult == NULL || billPostResult.isSuccess) {
                    billingCount++;
                }
            }
        }//in case if there are only valid(filtered out) billings left in the main collection
        else {
            billingCount = AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords).size();
        }

        //add error PostResult if limit exceeded
        if (billingCount > AvaTaxHelper.AVALARA_SELECTED_RECORDS_LIMIT) {
            for (Billing__c bill : (List<Billing__c>) sourceRecords) {
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.AVATAX_SERVICE_ERROR,
                        AbstractPostHandler.TAX_RECORD_COUNT_LIMIT_EXCEEDED_HELP_TEXT
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }

    private Boolean validateBillingsCountLimitForLDVAvaTaxCalc(Integer ldvLimit) {
        if (!IS_AVATAX_CALC_ENABLED) {
            return true;
        }
        Boolean isLessLimit = true;
        for (Billing__c bill : (List<Billing__c>) sourceRecords) {
            if (bill.Line_Count__c > ldvLimit) {
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.AVATAX_SERVICE_ERROR,
                        AbstractPostHandler.LDV_TAX_RECORD_COUNT_LIMIT_EXCEEDED_HELP_TEXT
                    )
                );
                isLessLimit = false;
            }
        }
        return isLessLimit;
    }

    private Boolean validateBillingPostLineLimit() {
        //check for maximum line number for the next use cases
        //1. Billing with no product costing
        //2. Billing with product costing
        //3. Billing with product costing and kitting
        Integer lineWithPC = 0;
        Integer lineWithPCAndKitting = 0;

        for (Billing_Line__c billLine : (List<Billing_Line__c>) sourceRecordLines) {
            if (billLine.Product__c != NULL) {
                if (billLine.Product__r.Inventory_Type__c == 'Kit') {
                    lineWithPCAndKitting++;
                }
                else {
                    lineWithPC++;
                }
            }
        }

        Integer currentLineLimit =
            (lineWithPCAndKitting > 0)
                ? BILLING_LINE_COUNT_PRODUCT_COSTING_AND_KITTING_LIMIT
                : (lineWithPC > 0)
                    ? BILLING_LINE_COUNT_PRODUCT_COSTING_LIMIT
                    : BILLING_LINE_COUNT_NO_PRODUCT_COSTING_LIMIT;

        Integer lineCount = sourceRecordLines.size();

        if (lineCount > currentLineLimit) {
            for (SObject bill : sourceRecords) {
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        String.format(
                            BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                            new List<String>{String.valueOf(currentLineLimit)}
                        )
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }

    private Boolean validateUnpostLineLimit() {
        if (this.sourceRecordLines.size() > UNPOST_BILLING_LINE_COUNT_LIMIT) {
            for (SObject bill : sourceRecords) {
                dispatcher.addPostErrorResult(
                    bill,
                    new PostResult.PostErrorResult(
                        bill,
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        String.format(
                            BILLING_LINE_COUNT_LIMIT_EXCEEDED_ERROR_MESSAGE,
                            new List<String>{
                                String.valueOf(UNPOST_BILLING_LINE_COUNT_LIMIT)
                            }
                        )
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }

    private void processPostBillings() {

        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }

        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                sourceRecordLines, IS_HEADER_LEVEL_POST
            ));
            //=========================================================================================

            List<Transaction__c> transList = buildTransactions();

            for (Billing__c billing : (List<Billing__c>) sourceRecords) {
                billing.Status__c = DEFAULT_POSTING_STATUS_POSTED;
            }

            //convert generic collection to the collection with specific SObjectType
            List<Billing__c> sourceRecordsToUpdate = new List<Billing__c>((List<Billing__c>) sourceRecords);

            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsToUpdate, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            sourceRecords = DomainUtils.getBillingsByIdForUpdate(new Map<Id, SObject>(sourceRecords).keySet());
            validatePostStatusSet();

            TransactionActions.createTransactions(transList);
            if (!Test.isRunningTest() && IS_AVATAX_CALC_ENABLED && !billingsToUncommitOnAvalaraSide.isEmpty()) {
                asyncAvalaraUncommit(billingsToUncommitOnAvalaraSide);
            }
        }
        catch (Exception ex) {
            //moving rollback before the asyncAvalaraUncommit method because the enqueueJob gets rolled back otherwise
            Database.rollback(sp);

            if (!Test.isRunningTest() && IS_AVATAX_CALC_ENABLED) {
                asyncAvalaraUncommit(AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords));
            }
            
            throw ex;
        }
    }

    private void asyncAvalaraUncommit(List<SObject> sourceToUncommit) {
        AvaTaxAsyncTransactionHandler asyncTransactionHandler = new AvaTaxAsyncTransactionHandler(
            AvaTaxAsyncTransactionHandler.AvaTaxContext.UNCOMMIT,
            sourceToUncommit
        );
        System.enqueueJob(asyncTransactionHandler);
    }

    private void processUnpostBillings() {
        if (IS_AVATAX_CALC_ENABLED) {
            List<Billing__c> selectedBills = (List<Billing__c>) AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords);
            if (!selectedBills.isEmpty()) {
                AvaTaxService.FetchResultTransactionModel avalaraTrans = AvaTaxHelper.getAvalaraTransactions(selectedBills);
                processAvaTaxResult(avalaraTrans, selectedBills);
            }
            List<SObject> sourceToUncommit = AvaTaxHelper.avalaraTaxCalculationBillingList((List<Billing__c>) sourceRecords);

            if (!Test.isRunningTest() && !System.isBatch() && sourceToUncommit.size() > (Limits.getLimitCallouts() - Limits.getCallouts())) {
                asyncAvalaraUncommit(sourceToUncommit);
            }
            else {
                AvaTaxHelper.uncommitTransactions(sourceToUncommit);
            }
        }

        List<Billing__c> updateBillings = new List<Billing__c>();
        Savepoint sp;
        if(!Test.isRunningTest()) {
            sp = Database.setSavepoint();
        }
        try {
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(
                sourceRecordLines, true
            ));

            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Billing__c.Status__c);

            for (Billing__c bill : (List<Billing__c>) this.sourceRecords) {
                if (bill.Status__c == DEFAULT_POSTING_STATUS_POSTED) {
                    bill.Status__c = defaultPostingStatus;
                    updateBillings.add(bill);
                }

                // Legacy update to the due date field to allow for unposting the record
                if (bill.Due_Date2__c == NULL && bill.Date__c != NULL) {
                    bill.Due_Date2__c = bill.Date__c;
                    updateBillings.add(bill);
                }
            }

            TriggerObserver.getInstance().unlockFields(new Set<SObjectField> {Billing__c.Status__c, Billing__c.Locked_In_AvaTax__c});
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateBillings, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(new Set<SObjectField> {Billing__c.Status__c, Billing__c.Locked_In_AvaTax__c});

            if (IS_AVATAX_CALC_ENABLED) {
                List<Billing_Line__c> deleteList = getOldAvalaraTaxLineList();
                if (!deleteList.isEmpty()) {
                    SFDCSecurityUtils.deleteProxy(deleteList);
                }
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private List<Billing__c> processAvaTaxResult(AvaTaxService.FetchResultTransactionModel results, List<Billing__c> bills) {
        List<Billing__c> billingForUpdate = new List<Billing__c>();
        Map<String, AvaTaxService.TransactionModel> avaTaxTransactionMap = results.getTransactionMap();

        for (Billing__c bill : bills) {
            AvaTaxService.TransactionModel avalaraTransaction = avaTaxTransactionMap.get(bill.Name);
            if (avalaraTransaction != null && avalaraTransaction.locked) {
                bill.Locked_In_AvaTax__c = true;
                billingForUpdate.add(bill);
            }
        }
        return billingForUpdate;
    }

    private List<Billing_Line__c> getOldAvalaraTaxLineList() {
        List<Billing_Line__c> result = new List<Billing_Line__c>();
        Map<Id, Boolean> billingsHavingAppliedRecords = SourceDocumentUpdateFieldValidator.hasAppliedRecords(
            new Map<Id, SObject>((List<Billing__c>) AvaTaxHelper.avalaraTaxCalculationList(sourceRecords))
        );
        for (Billing_Line__c billLine : (List<Billing_Line__c>) this.sourceRecordLines) {
            Boolean billingHasAppliedRecords = billingsHavingAppliedRecords.get(billLine.Billing__c);
            if (billLine.Tax_Line__c && !billingHasAppliedRecords) {
                result.add(billLine);
            }
        }
        return result;
    }

    private List<Transaction__c> buildTransactions() {
        List<Transaction__c> result = new List<Transaction__c>();
        if (IS_HEADER_LEVEL_POST) {
            result = createTransactionsInHLPMode();
        }
        else {
            result = createTransactionsInLLPMode();
        }
        return result;
    }

    private List<Transaction__c> createTransactionsInHLPMode() {
        //If MC is enabled ==================
        getCurrencyInformation();
        //===================================
        List<Transaction__c> transList = new List<Transaction__c>();
        Map<Id, Transaction__c> billingIdToDebitTransaction = new Map<Id, Transaction__c>();
        Map<String, Transaction__c> creditTransactionsByKey = new Map<String, Transaction__c>();
        Map<String, Transaction__c> taxTransactionsByKey = new Map<String, Transaction__c>();

        Map<Id, Tax_Group__c> taxGroupMap = TaxGroupHandler.getTaxGroupsBySObject(sourceRecordLines);

        for (Billing_Line__c billingLine : (List<Billing_Line__c>) sourceRecordLines) {
            if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(billingLine.Billing__r.Ledger__c)) {
                continue;
            }
            //===========================================================
            //============= CREDIT LINE (Consolidated by Key) ===========
            //===========================================================
            if (!isLDVBatchContext || outOfScopeLineIds == null || !outOfScopeLineIds.contains(billingLine.Id)) {
                Transaction__c pt = createTransaction(billingLine);
                pt.GL_Account__c = billingLine.Revenue_GL_Account__c;
                processCreditTransactionAmount(billingLine, pt);

                pt.Units__c = billingLine.Hours_Units__c * -1;
                pt.Time_Card_Variable_1__c = billingLine.Time_Card_Variable_1__c;
                pt.Time_Card_Variable_2__c = billingLine.Time_Card_Variable_2__c;

                populateTransactionMap(pt, creditTransactionsByKey, false);
            }
            //==================================================================================================
            //========== DEBIT LINE (Only one Transaction to the AR Control GL Account) ========================
            //==================================================================================================

            if (!isLDVBatchContext || outOfScopeLineIds == null || !outOfScopeLineIds.contains(billingLine.Id)) {
                if (!billingIdToDebitTransaction.containsKey(billingLine.Billing__c)) {
                    Transaction__c debitTransaction = updateDebitTransaction(createTransaction(billingLine), billingLine);
                    processDebitTransactionAmount(billingLine, debitTransaction);
                    billingIdToDebitTransaction.put(billingLine.Billing__c, debitTransaction);
                }
                else {
                    Transaction__c debitTransaction = billingIdToDebitTransaction.get(billingLine.Billing__c);
                    processDebitTransactionAmount(billingLine, debitTransaction);
                }
            }

            //create Tax Transactions for Native Tac Calc mode
            if (!AvaTaxHelper.isAvalaraTaxCalculationEnabled(billingLine.Billing__r) && billingLine.Tax_Group__c != NULL && taxGroupMap.containsKey(billingLine.Tax_Group__c)) {
                processTaxTransaction(billingLine, taxTransactionsByKey, billingIdToDebitTransaction, taxGroupMap.get(billingLine.Tax_Group__c));
            }
            else if (isNeedCreateAvalaraTaxTransaction(billingLine)) {
                processAvalaraTaxTransaction(billingLine, taxTransactionsByKey, billingIdToDebitTransaction);
            }

        }
        transList.addAll(billingIdToDebitTransaction.values());
        transList.addAll(creditTransactionsByKey.values());
        transList.addAll(taxTransactionsByKey.values());

        return transList;
    }

    private List<Transaction__c> createTransactionsInLLPMode() {
        //If MC is enabled ==================
        getCurrencyInformation();
        //===================================

        List<Transaction__c> transList = new List<Transaction__c>();
        List<InventoryTransactionHandler.InventoryTransactionSource> inventoryCostLines = new List<InventoryTransactionHandler.InventoryTransactionSource>();
        Map<Id, Billing__c> selectedBillings = new Map<Id, Billing__c>((List<Billing__c>) sourceRecords);

        for (Billing_Line__c billingLine : (List<Billing_Line__c>) sourceRecordLines) {
            if (isInventoryCostLine(billingLine)) {
                InventoryTransactionHandler.InventoryTransactionSource pci = inventoryCostItemFromBillingLine(billingLine);
                inventoryCostLines.add(pci);
            }
            if (billingLine.Id == NULL) {
                setRelatedObjectForVirtualLine(billingLine, selectedBillings.get(billingLine.Billing__c).Ledger__c);
            }
            if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(billingLine.Billing__r.Ledger__c)) {
                continue;
            }
            //===========================================================
            //==================== DEBIT LINE ===========================
            //===========================================================
            Transaction__c pt = createTransaction(billingLine);
            pt.GL_Account__c = glAccountDefaults.get(billingLine.Billing__r.Ledger__c).get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT).GL_Account__c;
            pt.Units__c = billingLine.Hours_Units__c;
            //MC part ===========================================================================================
            processDebitTransactionAmount(billingLine, pt);
            //===================================================================================================
            pt.Time_Card_Variable_1__c = billingLine.Time_Card_Variable_1__c;
            pt.Time_Card_Variable_2__c = billingLine.Time_Card_Variable_2__c;

            transList.add(pt);
            //===========================================================
            //==================== CREDIT LINE ===========================
            //===========================================================
            pt = createTransaction(billingLine);
            pt.Units__c = billingLine.Hours_Units__c * -1;
            pt.GL_Account__c = billingLine.Revenue_GL_Account__c;
            //MC part ===========================================================================================
            processCreditTransactionAmount(billingLine, pt);
            //===================================================================================================
            pt.Time_Card_Variable_1__c = billingLine.Time_Card_Variable_1__c;
            pt.Time_Card_Variable_2__c = billingLine.Time_Card_Variable_2__c;

            transList.add(pt);
        }

        // Create additional transactions where inventory valuation method is standard cost
        transList.addAll(InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(inventoryCostLines));
        // =======================================================================================================

        return transList;
    }

    private void setRelatedObjectForVirtualLine(Billing_line__c line, Id ledgerId) {
        line.putSObject(
            PACKAGE_QUALIFIER + 'Billing__r',
            new Billing__c(Id = line.Billing__c, Ledger__c = ledgerId));
    }

    private Boolean isNeedCreateAvalaraTaxTransaction(Billing_Line__c billingLine) {
        return
            AvaTaxHelper.isAvalaraTaxCalculationEnabled(billingLine.Billing__r)
                && AvaTaxHelper.validateBillingLineIsTaxable(billingLine, billingLine.Billing__r)
                && AvaTaxHelper.isLedgerCurrencySupportedByAvaTaxCalculation(billingLine.Billing__r.Ledger__c)
                && (AvaTaxHelper.validateShippingAddress(billingLine.Billing__r) || AvaTaxHelper.validateDestinationAddress(billingLine.Billing__r));
    }

    private Transaction__c getCreditAvalaraTaxTransaction(Billing_Line__c billingLine) {
        Transaction__c creditTax = updateAvalaraTaxTransaction(createTransaction(billingLine), billingLine.Billing__r);
        creditTax.Time_Card_Variable_1__c = billingLine.Time_Card_Variable_1__c;
        creditTax.Time_Card_Variable_2__c = billingLine.Time_Card_Variable_2__c;
        Decimal amount = (billingLine.Tax_Amount2__c != NULL) ? billingLine.Tax_Amount2__c * -1 : 0;

        if (isLDVBatchContext && AvaTaxHelper.oldTaxAmountsByLineIds.containsKey(billingLine.Id) && outOfScopeLineIds.contains(billingLine.Id)) {
            amount = amount + AvaTaxHelper.oldTaxAmountsByLineIds.get(billingLine.Id);
        }
        processTransactionAmount(billingLine, creditTax, amount);
        return creditTax;
    }

    private void processDebitTransactionAmount(Billing_Line__c billingLine, Transaction__c pt) {
        processTransactionAmount(billingLine, pt, getSubtotal(billingLine));
    }

    private void processCreditTransactionAmount(Billing_Line__c billingLine, Transaction__c pt) {
        processTransactionAmount(billingLine, pt, getSubtotal(billingLine) * -1);
    }

    private Decimal getSubtotal(Billing_Line__c billingLine) {
        Decimal subtotal = (billingLine.Hours_Units__c * billingLine.Rate__c).setScale(2, RoundingMode.HALF_UP);
        if (billingLine.Tax_Inclusive__c && billingLine.Combined_Tax_Rate__c != null) {
            Decimal taxRate = billingLine.Combined_Tax_Rate__c/100;
            subtotal = (subtotal / (1 + taxRate)).setScale(2, RoundingMode.HALF_UP);
        }
        return subtotal;
    }

    private void processTaxTransactionAmount(Billing_Line__c billingLine, Transaction__c pt, Tax_Rate__c rate) {
        Decimal normalRate = rate.Tax_Rate__c/100;
        Decimal subTotal = getSubtotal(billingLine);
        Decimal tax = subTotal * normalRate;
        processTransactionAmount(billingLine, pt, tax * -1);
    }

    private void processTransactionAmount(Billing_Line__c billingLine, Transaction__c pt, Decimal amount) {
        if (isMultiCurrencyAndDifferentCurrency(billingLine.Billing__c, pt.Ledger__c)) {
            pt.Foreign_Amount__c = sumDecimalResult(pt.Foreign_Amount__c, amount, 2);
            pt.Foreign_Currency__c = sourceIdToCurrencyCode.get(billingLine.Billing__c);
            pt.Currency_Conversion_Rate__c = sourceIdToCurrencyConversionRate.get(billingLine.Billing__c);
            pt.Amount__c = sumDecimalResult(pt.Amount__c, (amount/sourceIdToCurrencyConversionRate.get(billingLine.Billing__c)), 2);
        }
        else {
            pt.Amount__c = sumDecimalResult(pt.Amount__c, amount, 2);
        }
    }

    private void processTaxTransaction( Billing_Line__c billingLine,
                                        Map<String, Transaction__c> taxTransMap,
                                        Map<Id, Transaction__c> billingIdToDebitTransaction,
                                        Tax_Group__c taxGroup) {

        Transaction__c debitTransaction = billingIdToDebitTransaction.get(billingLine.Billing__c);
        Map<Id, Decimal> rateAdjustment = getTaxRateAdjustment(billingLine, taxGroup.Tax_Rates__r);
        Map<Id, Decimal> foreignRateAdjustment;
        if (isMultiCurrencyAndDifferentCurrency(billingLine.Billing__c, debitTransaction.Ledger__c)) {
            foreignRateAdjustment = getForeignTaxRateAdjustment(billingLine, taxGroup.Tax_Rates__r);
        }

        for (Tax_Rate__c rate : taxGroup.Tax_Rates__r) {
            Transaction__c creditTaxTR = updateTaxTransaction(createTransaction(billingLine), rate);
            creditTaxTR.Time_Card_Variable_1__c = billingLine.Time_Card_Variable_1__c;
            creditTaxTR.Time_Card_Variable_2__c = billingLine.Time_Card_Variable_2__c;
            processTaxTransactionAmount(billingLine, creditTaxTR, rate);

            debitTransaction.Amount__c = sumDecimalResult(debitTransaction.Amount__c, creditTaxTR.Amount__c * -1, 2);
            if (isMultiCurrencyAndDifferentCurrency(billingLine.Billing__c, debitTransaction.Ledger__c)) {
                debitTransaction.Foreign_Amount__c = sumDecimalResult(debitTransaction.Foreign_Amount__c, creditTaxTR.Foreign_Amount__c * -1, 2);
            }

            if (isMultiCurrencyAndDifferentCurrency(billingLine.Billing__c, debitTransaction.Ledger__c)) {
                if (rateAdjustment.containsKey(rate.Id) && service.getTaxRoundingThreshold(billingLine.Billing__r) >= rateAdjustment.get(rate.Id).abs())  {
                    debitTransaction.Foreign_Amount__c += rateAdjustment.get(rate.Id);
                    creditTaxTR.Foreign_Amount__c += rateAdjustment.get(rate.Id) * -1;
                }
                if (foreignRateAdjustment.containsKey(rate.Id) && service.getTaxRoundingThreshold(billingLine.Billing__r) >= foreignRateAdjustment.get(rate.Id).abs())  {
                    debitTransaction.Amount__c += foreignRateAdjustment.get(rate.Id);
                    creditTaxTR.Amount__c += foreignRateAdjustment.get(rate.Id) * -1;
                }
            }
            else if (rateAdjustment.containsKey(rate.Id) && service.getTaxRoundingThreshold(billingLine.Billing__r) >= rateAdjustment.get(rate.Id).abs()) {
                debitTransaction.Amount__c += rateAdjustment.get(rate.Id);
                creditTaxTR.Amount__c += rateAdjustment.get(rate.Id) * -1;
            }
            populateTransactionMap(creditTaxTR, taxTransMap, true);
        }
    }

    private Map<Id, Decimal> getForeignTaxRateAdjustment (Billing_Line__c billingLine, List<Tax_Rate__c> rates) {
        if (billingLine.Tax_Inclusive__c) {
            Decimal conversionRate = sourceIdToCurrencyConversionRate.get(billingLine.Billing__c);
            Decimal total = (billingLine.Hours_Units__c * billingLine.Rate__c).setScale(2, RoundingMode.HALF_UP);
            Decimal taxRate = billingLine.Combined_Tax_Rate__c/100;
            Decimal subtotal = ((total / (1 + taxRate)).setScale(2, RoundingMode.HALF_UP) / conversionRate).setScale(2, RoundingMode.HALF_UP);
            Decimal combinedTaxAmount = (billingLine.Tax_Amount2__c / conversionRate).setScale(2, RoundingMode.HALF_UP);
            return AbstractTaxService.getTaxRateAdjustmentByAmount(subtotal, rates, combinedTaxAmount);
        }
        return AbstractTaxService.getTaxRateAdjustmentByAmount(
            ((billingLine.Rate__c * billingLine.Hours_Units__c) / sourceIdToCurrencyConversionRate.get(billingLine.Billing__c))
                .setScale(2, RoundingMode.HALF_UP), rates
        );
    }

    private Map<Id, Decimal> getTaxRateAdjustment (Billing_Line__c billingLine, List<Tax_Rate__c> rates) {
        if (billingLine.Tax_Inclusive__c) {
            return AbstractTaxService.getTaxRateAdjustmentByAmount(getSubtotal(billingLine), rates, billingLine.Tax_Amount2__c);
        }
        return AbstractTaxService.getTaxRateAdjustmentByAmount((billingLine.Rate__c * billingLine.Hours_Units__c).setScale(2, RoundingMode.HALF_UP), rates);
    }

    private void processAvalaraTaxTransaction(  Billing_Line__c billingLine,
                                                Map<String, Transaction__c> taxTransMap,
                                                Map<Id, Transaction__c> billingIdToDebitTransaction) {

        Transaction__c debitTransaction = billingIdToDebitTransaction.get(billingLine.Billing__c);
        Transaction__c creditTaxTR = getCreditAvalaraTaxTransaction(billingLine);
        populateTransactionMap(creditTaxTR, taxTransMap, true);
        debitTransaction.Amount__c = sumDecimalResult(debitTransaction.Amount__c, creditTaxTR.Amount__c * -1, 2);
        if (isMultiCurrencyAndDifferentCurrency(billingLine.Billing__c, debitTransaction.Ledger__c)) {
            debitTransaction.Foreign_Amount__c = sumDecimalResult(debitTransaction.Foreign_Amount__c, creditTaxTR.Foreign_Amount__c * -1, 2);
        }
    }

    public override String getTransactionKey(Transaction__c pt, Boolean isTaxTransaction) {
        String result = '';
        result += String.valueOf(pt.Billing__c);
        result += String.valueOf(pt.GL_Account_Variable_1__c);
        result += String.valueOf(pt.GL_Account_Variable_2__c);
        result += String.valueOf(pt.GL_Account_Variable_3__c);
        result += String.valueOf(pt.GL_Account_Variable_4__c);
        result += String.valueOf(pt.GL_Account__c);
        result += String.valueOf(pt.Time_Card_Variable_1__c);
        result += String.valueOf(pt.Time_Card_Variable_2__c);
        if (!isTaxTransaction) {
            result += String.valueOf(pt.Project__c);
            result += String.valueOf(pt.Project_Task__c);
            result += String.valueOf(pt.Product__c);
        }
        return result;
    }

    private Transaction__c updateDebitTransaction(Transaction__c pt, SObject obj) {
        pt.GL_Account__c = glAccountDefaults.get(((Billing_Line__c) obj).Billing__r.Ledger__c).get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT).GL_Account__c;
        pt.Billing_Line__c = NULL;
        pt.Project_Task__c = NULL;
        pt.Project__c = NULL;
        pt.Employee__c = NULL;
        pt.GL_Account_Variable_1__c = NULL;
        pt.GL_Account_Variable_2__c = NULL;
        pt.GL_Account_Variable_3__c = NULL;
        pt.GL_Account_Variable_4__c = NULL;
        pt.Product__c = NULL;

        return pt;
    }

    private Transaction__c updateTaxTransaction(Transaction__c pt, Tax_Rate__c rate) {
        pt.GL_Account__c = rate.Sales_Tax_Liability_GL_Account__c;
        pt.Billing_Line__c = NULL;
        pt.Project_Task__c = NULL;
        pt.Project__c = NULL;
        pt.Product__c = NULL;
        pt.Amount__c = NULL;
        pt.Foreign_Amount__c = NULL;

        return pt;
    }

    private Transaction__c updateAvalaraTaxTransaction(Transaction__c pt, SObject ledgerSobject) {
        pt.GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(ledgerSobject);
        pt.Billing_Line__c = NULL;
        pt.Project_Task__c = NULL;
        pt.Project__c = NULL;
        pt.Product__c = NULL;
        pt.Amount__c = NULL;
        pt.Foreign_Amount__c = NULL;

        return pt;
    }

    private Boolean isInventoryCostLine(Billing_Line__c billLine) {
        return (AccountingSettingsHandler.isStandardCostProductCostingEnabled()
                    && billLine.Product__c != NULL && billLine.Billing__r.Type__c == 'Invoice'
                    && billLine.Product__r.Inventory_Product__c
                    && (billLine.Product__r.Inventory_Type__c == 'Purchased'
                            || billLine.Product__r.Inventory_Type__c == 'Manufactured'
                            || billLine.Product__r.Inventory_Type__c == 'Kit'));
    }

    public InventoryTransactionHandler.InventoryTransactionSource inventoryCostItemFromBillingLine(Billing_Line__c billingLine) {
        InventoryTransactionHandler.InventoryTransactionSource pci = new InventoryTransactionHandler.InventoryTransactionSource();
        pci.inventoryType = billingLine.Product__r.Inventory_Type__c;
        pci.sourceId = billingLine.Id;
        pci.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
        pci.quantity = billingLine.Hours_Units__c;
        pci.unitCost = billingLine.Product_Unit_Cost__c;
        pci.ledgerId = billingLine.Billing__r.Ledger__c;
        pci.accountingPeriodId = billingLine.Billing__r.Accounting_Period__c;
        pci.debitGLAccountId = billingLine.Expense_GL_Account__c != NULL ? billingLine.Expense_GL_Account__c : billingLine.Product__r.Expense_GL_Account__c;
        pci.creditGLAccountId = billingLine.Inventory_GL_Account__c != NULL ? billingLine.Inventory_GL_Account__c : billingLine.Product__r.Inventory_GL_Account__c;
        pci.sourceDate = billingLine.Billing__r.Date__c;
        pci.productId = billingLine.Product__c;
        pci.projectId = billingLine.Project__c;
        pci.projectTaskId = billingLine.Project_Task__c;
        pci.accountId = billingLine.Billing__r.Customer__c;
        pci.employeeId = billingLine.Employee__c;
        pci.note = (billingLine.Billing__r.Proprietary_Billing_Number__c == NULL ? billingLine.Billing__r.Name : billingLine.Billing__r.Proprietary_Billing_Number__c);
        pci.description = (billingLine.Billing__r.Proprietary_Billing_Number__c == NULL ? billingLine.Billing__r.Name : billingLine.Billing__r.Proprietary_Billing_Number__c);
        pci.glVariable1 = billingLine.GL_Account_Variable_1__c != NULL ? billingLine.GL_Account_Variable_1__c : billingLine.Product__r.GL_Account_Variable_1__c;
        pci.glVariable2 = billingLine.GL_Account_Variable_2__c != NULL ? billingLine.GL_Account_Variable_2__c : billingLine.Product__r.GL_Account_Variable_2__c;
        pci.glVariable3 = billingLine.GL_Account_Variable_3__c != NULL ? billingLine.GL_Account_Variable_3__c : billingLine.Product__r.GL_Account_Variable_3__c;
        pci.glVariable4 = billingLine.GL_Account_Variable_4__c != NULL ? billingLine.GL_Account_Variable_4__c : billingLine.Product__r.GL_Account_Variable_4__c;
        return pci;
    }

    private Transaction__c createTransaction(SObject obj) {
        Billing_Line__c billingLine = (Billing_Line__c) obj;

        Transaction__c pt = new Transaction__c();

        pt.Billing__c = IS_HEADER_LEVEL_POST ? billingLine.Billing__c : NULL;
        pt.Billing_Line__c = IS_HEADER_LEVEL_POST ? NULL : billingLine.Id;
        pt.Ledger__c = billingLine.Billing__r.Ledger__c != NULL ? billingLine.Billing__r.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        pt.Accounting_Period__c = billingLine.Billing__r.Accounting_Period__c;
        pt.Date__c = billingLine.Billing__r.Date__c;
        pt.Project_Task__c = billingLine.Project_Task__c;
        pt.Project__c = billingLine.Project__c;
        pt.Employee__c = billingLine.Employee__c;
        pt.Account__c = billingLine.Billing__r.Customer__c;
        pt.Note__c = (billingLine.Billing__r.Proprietary_Billing_Number__c == NULL ? billingLine.Billing__r.Name : billingLine.Billing__r.Proprietary_Billing_Number__c);
        pt.Product__c = billingLine.Product__c;

        pt.GL_Account_Variable_1__c = billingLine.GL_Account_Variable_1__c;
        pt.GL_Account_Variable_2__c = billingLine.GL_Account_Variable_2__c;
        pt.GL_Account_Variable_3__c = billingLine.GL_Account_Variable_3__c;
        pt.GL_Account_Variable_4__c = billingLine.GL_Account_Variable_4__c;
        return pt;
    }

    //Accessible and FLS checks are performed in Visualforce page for the records retrieved from this method.
    public List<Transaction__c> getForecastedTransactions() {

        if (dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.POST) {
            List<Transaction__c> transactionsList = buildTransactions();
            if (IS_MULTI_CURRENCY_ENABLED) {
                transactionsList = setLedgerIsoCodeToTransactions(transactionsList);
            }
            return transactionsList;
        }
        else {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Ledger__c',
                'GL_Account__c',
                'Amount__c',
                'Product__c',
                'Project__c',
                'Project_Task__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c'
            };

            if (IS_MULTI_CURRENCY_ENABLED) {
                queryFields.add('Foreign_Amount__c');
                queryFields.add('Foreign_Currency__c');
                queryFields.add('Currency_Conversion_Rate__c');
            }

            String queryCondition;

            if (IS_HEADER_LEVEL_POST) {
                Set<String> headerIds = getHeaderLevelIds(Billing_Line__c.Billing__c);
                queryCondition = 'Billing__c IN :headerIds AND ' + Billing_Cash_Receipt__c.getSObjectType() + ' = null';
            }
            else {
                queryCondition = 'Billing_Line__c IN :sourceRecordLines AND '+ Billing_Cash_Receipt__c.getSObjectType() + ' = null';
            }

            SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            return (List<Transaction__c>) Database.query(theQuery.toSOQL());
        }

    }

    private void submitSuccessfulResultsToAvaVAT() {
        try {
            FinancialSuiteService.submitBillingsToAvaVAT(dispatcher.getIdsFromSuccessfulResultsAsList(), dispatcher.getExecutionContext());
        } catch (Exception ex) {
            // Ignore Avalara VAT Reporting submission failures
        }
    }

}