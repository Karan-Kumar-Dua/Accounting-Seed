/*
This class is used as page controller for AccountPayableFromRecrAccountPayable and AccountsPayableFromRecrAccountsPayable pages
It can handle the single record conversion as well as the mass records conversion
 */
public with sharing class AccountPayableFromRecrAccountPayable extends AbstractSourceFromRecurring {
    private static final Integer SYNC_DML_LIMIT = 500;

    private Boolean isProductAvailable;
    private Set<Id> recurringAccPayableIds;
    public List<AccountPayableWrapper> payableList {
        get {
            return (List<AccountPayableWrapper>) objList;
        }
        set;
    }

    //common constructor which will be executed in any context
    public AccountPayableFromRecrAccountPayable() {
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
        isProductAvailable = isProductAccessible() && Recurring_Account_Payable_Line__c.SObjectType.fields.Product__c.getDescribe().isAccessible();
        isError = false;
        isDmlLimitError = false;
        isNeedToPost = false;
        isLDOAsyncProcessingEnabled = FeatureManagementHandler.isLargeDataVolumeModeEnabled();
        DML_LIMIT = isLDOAsyncProcessingEnabled ? DML_LIMIT : SYNC_DML_LIMIT;
        
        //used for batch for create all possible billings until multipleRecordsEndDate
        resultStatusMap = new Map<Id, RecurringRecordResult>();
        populateDescribeInfo();
        populateCheckListOfFields();
    }

    //constructor for single record conversion
    public AccountPayableFromRecrAccountPayable (ApexPages.StandardController controller) {
        this();
        if (isMultiCurrencyEnabled && !Test.isRunningTest()) {
            controller.addFields(new List<String>{'CurrencyIsoCode'});
            currencyIsoCode = (String) controller.getRecord().get('CurrencyIsoCode');
        }

        try {
            rSObjectList = getRecurringAccountPayables(
                new List<Recurring_Account_Payable__c>{
                    (Recurring_Account_Payable__c) controller.getRecord()
                },
                false
            );
            rSObjectLinesMap = getLinesMap(getRecurringAccountPayableLines(), Recurring_Account_Payable_Line__c.Recurring_Account_Payable__c);
            init();
            isInActiveError = ((List<Recurring_Account_Payable__c>) rSObjectList)[0].Status__c == 'Inactive' ? true : false;
            if (!isInActiveError) {
                initTaxGroup();
            }
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
        }
    }

    //constructor for multiple records conversion
    public AccountPayableFromRecrAccountPayable(ApexPages.StandardSetController setController) {
        this((List<Recurring_Account_Payable__c>) setController.getSelected());
    }

    //constructor for batch class
    public AccountPayableFromRecrAccountPayable (List<Recurring_Account_Payable__c> selectedRecurringPayables) {
        this();

        try {
            rSObjectList = getRecurringAccountPayables(selectedRecurringPayables, true);
            rSObjectLinesMap = getLinesMap(getRecurringAccountPayableLines(), Recurring_Account_Payable_Line__c.Recurring_Account_Payable__c);

            validateDmlLimitCount();
            if (!isDmlLimitError) {
                if (isMultiCurrencyEnabled) {
                    if (!rSObjectList.isEmpty()) {
                        currencyIsoCode = (String) rSObjectList[0].get('CurrencyIsoCode');
                    }
                }

                isNoSelectionError = rSObjectList.isEmpty() ? true : false;

                if (!isNoSelectionError) {
                    init();
                    initTaxGroup();
                }
            }
        }
        catch (Exception ex) {
            isError = true;
            if (!isBatchContext) {
                ApexPages.addMessages(ex);
            }
        }

    }

    private void populateDescribeInfo() {
        this.targetHeaderRecordType = Account_Payable__c.getSObjectType();
        this.targetLineRecordType = Account_Payable_Line__c.getSObjectType();
        this.lineToHeaderRelationshipField = Account_Payable_Line__c.Account_Payable__c.getDescribe().getSobjectField();
        this.sourceRecurringRecordType = Recurring_Account_Payable__c.getSObjectType();
    }

    private void populateCheckListOfFields() {
        this.checkFieldsOnTargetHeaderRecord = new List<String>{
            'Date__c',
            'Payee_Reference__c',
            'Vendor__c',
            'Contact__c',
            'Employee__c',
            'Recurring_Account_Payable__c',
            'Accounting_Period__c',
            'Ledger__c'
        };
        this.checkFieldsOnTargetLineRecord = new List<String>{};
        this.checkFieldsOnSourceRecurringRecord = new List<String>{
            'Next_Account_Payable_Date__c',
            'Last_Account_Payable_Date__c',
            'Account_Payable_Frequency__c'
        };
    }

    private List<Recurring_Account_Payable__c> getRecurringAccountPayables(List<Recurring_Account_Payable__c> selectedRecords, Boolean onlyActive) {
        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Vendor__c',
            'Contact__c',
            'Employee__c',
            'Status__c',
            'Next_Account_Payable_Date__c',
            'Last_Account_Payable_Date__c',
            'Account_Payable_Frequency__c',
            'Ledger__c',
            'Purchase_Tax__c',
            'Sub_Total__c',
            'Line_Count__c',
            'Total2__c'
        };
        //Add Currency field
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        //Add main query condition
        String queryCondition = 'Id IN :selectedRecords ';
        if (onlyActive) {
            queryCondition += 'AND Status__c = \'Active\'';
            if (!this.isBatchContext) {
                queryCondition += ' AND Ledger__r.Active__c = true';
            }
        }


        SOQLBuilder theQuery = new SOQLBuilder(Recurring_Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Recurring_Account_Payable__c>) Database.query(theQuery.toSOQL());
    }

    private List<Recurring_Account_Payable_Line__c> getRecurringAccountPayableLines() {
        List<Recurring_Account_Payable__c> selectedRecords;
        // for ldo any payables with more than 1 line will have their lines processed async.
        // in ldo mode we can't bring all lines into the view state.
        if (isLDOAsyncProcessingEnabled) {
            selectedRecords = new List<Recurring_Account_Payable__c>();
            for (Recurring_Account_Payable__c rPay : (List<Recurring_Account_Payable__c>) rSObjectList) {
                if (rPay.Line_Count__c == 1) {
                    selectedRecords.add(rPay);
                }
            }
        } else {
            selectedRecords = rSObjectList;
        }

        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Recurring_Account_Payable__c',
            'Recurring_Account_Payable__r.Id',
            'Expense_GL_Account__c',
            'Amount2__c',
            'Unit_Cost__c',
            'Tax_Group__c',
            'Tax_Group__r.Combined_Tax_Rate__c',
            'Tax_Amount__c',
            'Quantity__c',
            'Project__c',
            'Project_Task__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Internal_Comment__c',
            'Tax_Inclusive__c'
        };

        if (isProductAvailable) {
            queryFields.add('Product__c');
        }

        //Add main query condition
        String queryCondition = 'Recurring_Account_Payable__c IN :selectedRecords ';

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Recurring_Account_Payable_Line__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Recurring_Account_Payable_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering);

        return (List<Recurring_Account_Payable_Line__c>) Database.query(theQuery.toSOQL());
    }

    private void init() {
        try {
            objList = new List<AccountPayableWrapper>();
            Set<Date> payableDates = new Set<Date>();
            for (Recurring_Account_Payable__c rPayable : (List<Recurring_Account_Payable__c>) rSObjectList) {
                resultStatusMap.put(rPayable.Id, new RecurringRecordResult('Payable', rPayable.Id));
                payableDates.add(Date.newInstance(rPayable.Next_Account_Payable_Date__c.year(), rPayable.Next_Account_Payable_Date__c.month(), 1));
            }

            Map<Date, Accounting_Period__c> periodsMap = getPeriodsByDates(payableDates);
            Integer rPayableCount = 0;
            for (Recurring_Account_Payable__c rPayable : (List<Recurring_Account_Payable__c>) rSObjectList) {
                Account_Payable__c payable = getPayableFromRecPayable(rPayable);
                payable.Payee_Reference__c += ' ' + String.valueOf(rPayableCount++);
                Date periodStartDate = Date.newInstance(rPayable.Next_Account_Payable_Date__c.year(), rPayable.Next_Account_Payable_Date__c.month(), 1);
                payable.Accounting_Period__c = periodsMap.containsKey(periodStartDate) ? periodsMap.get(periodStartDate).Id : NULL;

                AccountPayableWrapper aw = new AccountPayableWrapper(rPayable, Payable);
                aw.recurringLineCount = 0;
                aw.combinedTaxRate = 0;
                aw.taxAmount = rPayable.Purchase_Tax__c;
                aw.subTotalAmount = rPayable.Sub_Total__c;
                // when async processing is enabled and the payable has more than 1 line
                // we need to set some values based on the header. In this scenario
                // the payable lines will not have been queried to avoid hitting limits
                // in ldo mode.
                if (isLDOAsyncProcessingEnabled && !rSObjectLinesMap.containsKey(rPayable.Id)) {
                    aw.recurringLineCount = Integer.valueOf(rPayable.Line_Count__c);
                    aw.total = rPayable.Total2__c;
                }
                if (rSObjectLinesMap.containsKey(rPayable.Id)) {
                    aw.recurringLineCount = rSObjectLinesMap.get(rPayable.Id).size();
                    aw.combinedTaxRate = getCombinedTaxRate(rSObjectLinesMap.get(rPayable.Id));
                    for (Recurring_Account_Payable_Line__c rPayableLine : (List<Recurring_Account_Payable_Line__c>) rSObjectLinesMap.get(rPayable.Id)) {
                        Account_Payable_Line__c payableLine = getPayableLineFromRecPayableLine(payable, rPayableLine);
                        aw.total += rPayableLine.Amount2__c;
                        aw.objLines.add(payableLine);
                    }
                }
                resultStatusMap.get(rPayable.Id).totalRecords += 1;
                objList.add(aw);
            }
        }
        catch (Exception ex) {
            if (!isBatchContext) {
                ApexPages.addMessages(ex);
            }
        }
    }

    private Decimal getCombinedTaxRate(List<Recurring_Account_Payable_Line__c> rPayableList ) {
        Decimal taxRate = 0;
        if (!rPayableList.isEmpty() && rPayableList[0].Tax_Group__c != NULL) {
            taxRate = rPayableList[0].Tax_Group__r.Combined_Tax_Rate__c;
        }
        return taxRate;
    }

    private Account_Payable__c getPayableFromRecPayable(Recurring_Account_Payable__c rPayable) {
        Account_Payable__c payable = new Account_Payable__c();
        payable.Date__c = rPayable.Next_Account_Payable_Date__c;
        payable.Payee_Reference__c = rPayable.Name + ' ' + System.now().formatLong();
        payable.Vendor__c = rPayable.Vendor__c;
        payable.Contact__c = rPayable.Contact__c;
        payable.Employee__c = rPayable.Employee__c;
        payable.Recurring_Account_Payable__c = rPayable.Id;
        payable.Ledger__c = (rPayable.Ledger__c == NULL) ? LedgerHandler.getLegacyDefaultLedgerId() : rPayable.Ledger__c;

        if (isMultiCurrencyEnabled) {
            payable.put('CurrencyIsoCode', rPayable.get('currencyIsoCode'));
        }

        return payable;
    }

    private Account_Payable_Line__c getPayableLineFromRecPayableLine(Account_Payable__c payable, Recurring_Account_Payable_Line__c rPayableLine) {
        Account_Payable_Line__c payableLine = new Account_Payable_Line__c();
        payableLine.Recurring_Account_Payable_Line__c = rPayableLine.Id;
        payableLine.Expense_GL_Account__c = rPayableLine.Expense_GL_Account__c;
        payableLine.Quantity__c = rPayableLine.Quantity__c != NULL ? rPayableLine.Quantity__c : 1;
        payableLine.Date__c = payable.Date__c;
        payableLine.Project__c = rPayableLine.Project__c;
        payableLine.Project_Task__c = rPayableLine.Project_Task__c;
        payableLine.Tax_Group__c = rPayableLine.Tax_Group__c;
        payableLine.Tax_Amount__c = rPayableLine.Tax_Amount__c;
        payableLine.Unit_Cost__c = rPayableLine.Unit_Cost__c != NULL ? rPayableLine.Unit_Cost__c : rPayableLine.Amount2__c;
        payableLine.GL_Account_Variable_1__c = rPayableLine.GL_Account_Variable_1__c;
        payableLine.GL_Account_Variable_2__c = rPayableLine.GL_Account_Variable_2__c;
        payableLine.GL_Account_Variable_3__c = rPayableLine.GL_Account_Variable_3__c;
        payableLine.GL_Account_Variable_4__c = rPayableLine.GL_Account_Variable_4__c;
        payableLine.Internal_Comment__c = rPayableLine.Internal_Comment__c;
        payableLine.Tax_Inclusive__c = rPayableLine.Tax_Inclusive__c;
        payableLine.Combined_Tax_Rate__c = rPayableLine.Tax_Group__r.Combined_Tax_Rate__c;
        if (isProductAvailable) {
            payableLine.Product__c = rPayableLine.Product__c;
        }
        return payableLine;
    }

    public with sharing class AccountPayableWrapper extends RecordWrapper {
        private Decimal combinedTaxRate;
        
        public Boolean taxInclusive {
            get {
                if (recurringLineCount == 1  && !objLines.isEmpty()) {
                    return ((Account_Payable_Line__c)objLines[0]).Tax_Inclusive__c;
                }
                return false;
            }
            set;
        }

        public Decimal taxRate{
            get {
                if (recurringLineCount == 1) {
                    return combinedTaxRate / 100;
                }
                else {
                    return taxRate;
                }
            }
            set;
        }

        public Decimal taxAmount {
            get {
                if (recurringLineCount == 1 && !objLines.isEmpty()) {
                    Account_Payable_Line__c line = (Account_Payable_Line__c) objLines[0];
                    if (taxInclusive) {
                        Decimal total = line.Unit_Cost__c * line.Quantity__c;
                        line.Tax_Amount__c = total - (total / (1 + taxRate));
                    } else {
                        line.Tax_Amount__c = line.Unit_Cost__c * line.Quantity__c * taxRate;
                    }
                    taxAmount = line.Tax_Amount__c;
                }
                return taxAmount;
            }
            set;
        }

        public Decimal subTotalAmount {
            get {
                if (recurringLineCount == 1 && !objLines.isEmpty()) {
                    Account_Payable_Line__c line = (Account_Payable_Line__c) objLines[0];
                    if (taxInclusive) {
                        subTotalAmount = (line.Unit_Cost__c * line.Quantity__c) / (1 + taxRate);
                    } else {
                        subTotalAmount = line.Unit_Cost__c * line.Quantity__c;
                    }
                }
                return subTotalAmount;
            }
            set;
        }

        public AccountPayableWrapper(Recurring_Account_Payable__c rPayable , Account_Payable__c payable) {
            super(rPayable, payable, 0);
        }

        public void setTotalAmount() {
            if (recurringLineCount == 1 && !objLines.isEmpty()) {
                Account_Payable_Line__c line = (Account_Payable_Line__c) objLines[0];
                if (taxInclusive) {
                    total = line.Unit_Cost__c * line.Quantity__c;
                } else {
                    total = (line.Unit_Cost__c * line.Quantity__c) + (line.Unit_Cost__c * line.Quantity__c * taxRate);
                }
            }
        }

        public override Boolean isHeaderDirty() {
            Account_Payable__c pay = (Account_Payable__c) obj;
            Recurring_Account_Payable__c rPay = (Recurring_Account_Payable__c) rObj;
            return pay.Date__c != rPay.Next_Account_Payable_Date__c;
        }
    }

    private void initTaxGroup() {
        Set<Id> taxGroupIds = new Set<Id>();
        if (objList != NULL) {
            for (RecordWrapper rw : objList) {
                if (!rw.objLines.isEmpty() && rw.objLines[0].get('Tax_Group__c') != NULL) {
                    taxGroupIds.add((Id) rw.objLines[0].get('Tax_Group__c'));
                }
            }
        }
        if (!taxGroupIds.isEmpty()) {
            TaxGroupHandler.getInstance().setTaxGroupsByTaxGroupIds(taxGroupIds);
        }
    }

    private Boolean validateAndSetAccountingPeriod() {
        Boolean result = true;
        for (AccountPayableWrapper aw : (List<AccountPayableWrapper>) objList) {
            Accounting_Period__c currentAccountingPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(((Account_Payable__c) aw.obj).Date__c);

            if (currentAccountingPeriod == NULL) {
                result = false;
                resultStatusMap.get(aw.rObj.Id).errors.add(
                    new RecurringRecordErrorResult(
                        StatusCode.ACCOUNTING_PERIOD_ERROR,
                        NO_PERIOD_ERROR_MESSAGE
                    )
                );

                ((Account_Payable__c) aw.obj).Date__c.addError(
                    String.format(
                        NO_PERIOD_ERROR_MESSAGE,
                        new List<String>{
                            String.valueOf((((Account_Payable__c) aw.obj).Date__c).format())
                        }
                    )
                );
            } else {
                ((Account_Payable__c) aw.obj).Accounting_Period__c = currentAccountingPeriod.Id;
            }
        }

        return result;
    }

    public void updateLinesDates() {
        if (payableList != null) {
            for (AccountPayableWrapper payableWrap : payableList) {
                Date payableDate = (Date) payableWrap.obj.get(PACKAGE_QUALIFIER + 'Date__c');
                if (payableWrap.objLines != null && !payableWrap.objLines.isEmpty() &&
                        payableDate != (Date)payableWrap.objLines[0].get(PACKAGE_QUALIFIER + 'Date__c')) {
                    for (SObject line : payableWrap.objLines) {
                        line.put(PACKAGE_QUALIFIER + 'Date__c', payableDate);
                    }
                }
            }
        }
    }

    public PageReference createPayableAndPost() {
        isNeedToPost = true;
        return createPayable();
    }

    public PageReference createPayable() {
        clearResultErrors();
        SavePoint sp = Database.setSavepoint();

        //Recalculate Total value (wrapper's property) for each line in wrapper to render it after form re-render (if submit error etc)
        if (!isBatchContext) {
            for (AccountPayableWrapper aw : (List<AccountPayableWrapper>) objList) {
                aw.setTotalAmount();
            }
        }

        try {
            if (validateAndSetAccountingPeriod() || isBatchContext) {

                setFieldsOnRecurringRecords(
                    PACKAGE_QUALIFIER + 'Last_Account_Payable_Date__c',
                    PACKAGE_QUALIFIER + 'Next_Account_Payable_Date__c',
                    PACKAGE_QUALIFIER + 'Account_Payable_Frequency__c'
                );

                doDMLs();
                if (objList.size() == 1
                        && resultStatusMap.get(objList[0].rObj.Id) != null
                        && !resultStatusMap.get(objList[0].rObj.Id).errors.isEmpty()) {
                    return null;
                }
                populateSuccessResults();

                if (isNeedToPost && synchronousRecordsCount > 0) {
                    AbstractPostHandler postHandler = new AccountPayablePostHandler();
                    AsyncPostHandlersExecutor asyncPHExecutor = new AsyncPostHandlersExecutor(getHeaderAndLineRecordsExistedInDB(), postHandler);
                    System.enqueueJob(asyncPHExecutor);
                    if (!isBatchContext) {
                        ApexPages.addMessage(
                            new ApexPages.Message(ApexPages.Severity.CONFIRM,
                                String.format(CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE, new List<String>{'payable records'})));
                    }
                }
                else if (!isBatchContext && synchronousRecordsCount > 0) {
                    String objName = synchronousRecordsCount > 1 ? SObjectType.Account_Payable__c.getLabelPlural().toLowerCase() : SObjectType.Account_Payable__c.getLabel().toLowerCase();
                    if (isLDOAsyncProcessingEnabled) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(CREATE_SOURCE_SUCCESS_MESSAGE, 
                            new List<String>{String.valueOf(synchronousRecordsCount), objName})));
                    } else {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(CREATE_SUCCESS_MESSAGE, new List<String>{objName})));
                    }
                }
                recordsCreated = true;

                // if a single payable and lines were processed synchronously
                if (objList.size() == 1 && objList[0].isHeaderRecordSavedInDB() && getLineProcessingMode(objList[0]) == ProcessingMode.SYNC) {
                    return new PageReference('/' + objList[0].obj.Id);
                }

                // handle async processing
                if (isLDOAsyncProcessingEnabled) {
                    processAsyncRecords();
                }
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            handleExternalExceptionAndRollBack(ex);
            if (!isBatchContext) {
                ApexPages.addMessages(ex);
            }
        }
        return NULL;
    }

    /**
     * handle createing payables from reucrring payables asynchronously
     */
    private Integer processAsyncRecords() {
        // recurring payables to process asynchronously
        Set<Id> recurringPayableIds = new Set<Id>();
        // transaction groups which will be picked up by the async job.
        // these are created for payable headers which were created synchronously,
        // but have lines which will be processed asynchronously.
        List<Transaction_Group__c> txnGroups = new List<Transaction_Group__c>();
        // a UUID used to track transaction groups throughout a process
        String correlationId = System.UUID.randomUUID().toString();

        // collect data which requires further processing
        for (RecordWrapper rw : objList) {
            if (!rw.isHeaderRecordSavedInDB() && getHeaderProcessingMode(rw) == ProcessingMode.ASYNC && getLineProcessingMode(rw) == ProcessingMode.ASYNC) {
                recurringPayableIds.add(rw.rObj.Id);
            // header was created synchronously, but lines will be processed asynchronously
            } else if (rw.isHeaderRecordSavedInDB() && getHeaderProcessingMode(rw) == ProcessingMode.SYNC && getLineProcessingMode(rw) == ProcessingMode.ASYNC) {
                recurringPayableIds.add(rw.rObj.Id);
                // this will be picked up by the async job
                txnGroups.add(new Transaction_Group__c(
                    Recurring_Account_Payable__c = rw.rObj.Id,
                    Account_Payable__c = rw.obj.Id,
                    Status__c = TransactionGroupActions.STATUS_PROCESSING,
                    Batch_Id__c = correlationId,
                    Job_Type__c = PayableFromRecurringPayableBatch.class.getName(),
                    Line_Count__c = rw.recurringLineCount,
                    Lines_Processed__c = 0,
                    Ledger__c = ((Account_Payable__c) rw.obj).Ledger__c
                ));
            }
        }

        // insert the transaction groups so the job can pick them up
        if (!txnGroups.isEmpty()) {
            SFDCSecurityUtils.insertProxy(txnGroups);
        }

        if (!recurringPayableIds.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(RECORDS_WILL_BE_PROCESSED_ASYNCHRONOUSLY, 
                new List<String>{String.valueOf(recurringPayableIds.size()), (recurringPayableIds.size() > 1 ? COMMON_RECORDS : COMMON_RECORD)})));
        }

        // start async processing
        if (!recurringPayableIds.isEmpty() && !Test.isRunningTest()) {
            Database.executeBatch(new PayableFromRecurringPayableBatch(recurringPayableIds, isNeedToPost, correlationId));
        }

        // number of recurring billing records which will be processed asynchronously
        return recurringPayableIds.size();
    }

}