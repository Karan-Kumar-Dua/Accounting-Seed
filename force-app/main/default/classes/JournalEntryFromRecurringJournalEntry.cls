public with sharing class JournalEntryFromRecurringJournalEntry extends AbstractSourceFromRecurring {

    public static final String NO_RECORDS_SELECTED_ERROR = Label.ERR_NO_RECORDS_SELECTED_JE;
    public static final String INACTIVE_ERROR = Label.ERR_INACTIVE;
    public static final String OUT_OF_BALANCE_ERROR = Label.ERR_OUT_OF_BALANCE;
    private static final Integer SYNC_DML_LIMIT = 1000;

    @TestVisible
    private Boolean isInActiveError;
    @TestVisible
    private Boolean isOutOfBalanceError;
    private Boolean isProductAvailable;
    private Set<Id> recurringJEIds;

    public List<JournalEntryWrapper> jEList {
        get {
            return (List<JournalEntryWrapper>) objList;
        }
        set;
    }
    public Journal_Entry__c proxyEntry {get; set;}

    //common constructor which will be executed in any context
    public JournalEntryFromRecurringJournalEntry() {
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        isProductAvailable = isProductAccessible() && Recurring_Journal_Entry_Line__c.SObjectType.fields.Product__c.getDescribe().isAccessible();
        proxyEntry = new Journal_Entry__c();
        isError = false;
        isNeedToPost = false;
        isSuccess = false;
        isLDOAsyncProcessingEnabled = FeatureManagementHandler.isLargeDataVolumeModeEnabled();
        DML_LIMIT = isLDOAsyncProcessingEnabled ? DML_LIMIT : SYNC_DML_LIMIT;
        resultStatusMap = new Map<Id, RecurringRecordResult>();
        populateDescribeInfo();
        populateCheckListOfFields();
    }

    //constructor for single record conversion
    public JournalEntryFromRecurringJournalEntry(ApexPages.StandardController controller) {
        this();

        if (isMultiCurrencyEnabled && !Test.isRunningTest()) {
            controller.addFields(new List<String>{'CurrencyIsoCode'});
            currencyIsoCode = (String) controller.getRecord().get('CurrencyIsoCode');
        }

        try {
            rSObjectList = queryRecurringJournalEntries(new List<Recurring_Journal_Entry__c>{(Recurring_Journal_Entry__c) controller.getRecord()}, false);
            rSObjectLinesMap = getLinesMap(queryRecurringJournalEntryLines(), Recurring_Journal_Entry_Line__c.Recurring_Journal_Entry__c);
            isInActiveError = ((List<Recurring_Journal_Entry__c>) rSObjectList)[0].Status__c == 'Inactive' ? true : false;
            isOutOfBalanceError = ((List<Recurring_Journal_Entry__c>) rSObjectList)[0].Out_of_Balance__c != 0 ? true : false;
            if (!isInActiveError && !isOutOfBalanceError) {
                init();
            }
            else {
                isError = true;
                if (isInActiveError) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, INACTIVE_ERROR));
                }
                if (isOutOfBalanceError) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, OUT_OF_BALANCE_ERROR));
                }
            }
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
        }
    }

    //constructor for multiple records conversion
    public JournalEntryFromRecurringJournalEntry(ApexPages.StandardSetController setController) {
        this((List<Recurring_Journal_Entry__c>) setController.getSelected());
        this.stdSetController = setController;
    }

    //constructor for batch class
    public JournalEntryFromRecurringJournalEntry(List<Recurring_Journal_Entry__c> selectedRecurringJE) {
        this();

        try {
            //only JEs where Status__c = 'Active' AND Out_of_Balance__c = 0 will be queried
            rSObjectList = queryRecurringJournalEntries(selectedRecurringJE, true);
            rSObjectLinesMap = getLinesMap(queryRecurringJournalEntryLines(), Recurring_Journal_Entry_Line__c.Recurring_Journal_Entry__c);

            validateDmlLimitCount();
            if (!isDmlLimitError) {
                isNoSelectionError = rSObjectList.isEmpty() ? true : false;
                if (!isNoSelectionError) {
                    init();
                }
                else {
                    isError = true;
                    if (!isBatchContext) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, NO_RECORDS_SELECTED_ERROR));
                    }
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
        this.targetHeaderRecordType = Journal_Entry__c.getSObjectType();
        this.targetLineRecordType = Journal_Entry_Line__c.getSObjectType();
        this.lineToHeaderRelationshipField = Journal_Entry_Line__c.Journal_Entry__c.getDescribe().getSobjectField();
        this.sourceRecurringRecordType = Recurring_Journal_Entry__c.getSObjectType();
    }

    private void populateCheckListOfFields() {
        this.checkFieldsOnTargetHeaderRecord = new List<String>{
            'Journal_Date__c',
            'Recurring_Journal_Entry__c',
            'Ledger__c'
        };
        this.checkFieldsOnTargetLineRecord = new List<String>{};
        this.checkFieldsOnSourceRecurringRecord = new List<String>{
            'Next_Journal_Entry_Date__c',
            'Last_Journal_Entry_Date__c',
            'Journal_Entry_Frequency__c'
        };
    }

    private List<Recurring_Journal_Entry__c> queryRecurringJournalEntries(List<Recurring_Journal_Entry__c> selectedRecords, Boolean onlyValid) {
        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Auto_Reverse__c',
            'Status__c',
            'Next_Journal_Entry_Date__c',
            'Last_Journal_Entry_Date__c',
            'Journal_Entry_Frequency__c',
            'Ledger__c',
            'Out_of_Balance__c',
            'Total_Credits__c',
            'Total_Debits__c',
            'Reference__c',
            'Type__c',
            'Accrual_and_or_Cash__c',
            'Line_Count__c'
        };
        //Add Currency field
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }

        //Add main query condition
        String queryCondition = 'Id IN :selectedRecords ';
        if (onlyValid) {
            queryCondition += 'AND Status__c = \'Active\' AND Out_of_Balance__c = 0';
            if (!this.isBatchContext) {
                queryCondition += ' AND Ledger__r.Active__c = true';
            }
        }

        SOQLBuilder theQuery = new SOQLBuilder(Recurring_Journal_Entry__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Recurring_Journal_Entry__c>) Database.query(theQuery.toSOQL());
    }

    private List<Recurring_Journal_Entry_Line__c> queryRecurringJournalEntryLines() {
        // Lines are not queried in LDO mode
        if (isLDOAsyncProcessingEnabled) {
            return new List<Recurring_Journal_Entry_Line__c>();
        }

        List<Recurring_Journal_Entry__c> selectedRecords = rSObjectList;
        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Account__c',
            'Contact__c',
            'Employee__c',
            'Recurring_Journal_Entry__c',
            'Recurring_Journal_Entry__r.Id',
            'GL_Account__c',
            'Cash_Flow_Category__c',
            'Quantity__c',
            'Project__c',
            'Project_Task__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Reference__c',
            'Debit__c',
            'Credit__c',
            'Description__c'
        };
        //Add Currency field
        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        if (isProductAvailable) {
            queryFields.add('Product__c');
        }

        //Add main query condition
        String queryCondition = 'Recurring_Journal_Entry__c IN :selectedRecords ';

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Recurring_Journal_Entry_Line__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Recurring_Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering);

        return (List<Recurring_Journal_Entry_Line__c>) Database.query(theQuery.toSOQL());
    }

    private void init() {

        try {
            objList = new List<JournalEntryWrapper>();

            Set<Date> jEDates = new Set<Date>();

            for (Recurring_Journal_Entry__c rJE : (List<Recurring_Journal_Entry__c>) rSObjectList) {
                resultStatusMap.put(rJE.Id, new RecurringRecordResult('Journal Entry', rJE.Id));
                jEDates.add(Date.newInstance(rJE.Next_Journal_Entry_Date__c.year(), rJE.Next_Journal_Entry_Date__c.month(), 1));
            }

            Map<Date, Accounting_Period__c> periodsMap = new Map<Date, Accounting_Period__c>();
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            for (Date jEDate : jEDates) {
                Accounting_Period__c period = acctPeriodHandler.getAccountingPeriodByStartDate(jEDate);
                if (period != NULL) {
                    periodsMap.put(period.Start_Date__c, period);
                }
            }

            for (Recurring_Journal_Entry__c rJE : (List<Recurring_Journal_Entry__c>) rSObjectList) {
                Journal_Entry__c jE = getJournalEntryFromRecJournalEntry(rJE);
                Date periodStartDate = Date.newInstance(rJE.Next_Journal_Entry_Date__c.year(), rJE.Next_Journal_Entry_Date__c.month(), 1);
                jE.Accounting_Period__c = periodsMap.containsKey(periodStartDate) ? periodsMap.get(periodStartDate).Id : NULL;

                JournalEntryWrapper jew = new JournalEntryWrapper(rJE, jE);
                jew.recurringLineCount = Integer.valueOf(rJE.Line_Count__c);
                if (rSObjectLinesMap.containsKey(rJE.Id)) {
                    for (Recurring_Journal_Entry_Line__c rJELine : (List<Recurring_Journal_Entry_Line__c>) rSObjectLinesMap.get(rJE.Id)) {
                        jew.objLines.add(getJournalEntryLineFromRecJournalEntryLine(rJELine));
                    }
                }
                resultStatusMap.get(rJE.Id).totalRecords += 1;
                objList.add(jew);


            }
        }
        catch (Exception ex) {
            if (!isBatchContext) {
                ApexPages.addMessages(ex);
            }
        }

    }

    private Journal_Entry__c getJournalEntryFromRecJournalEntry(Recurring_Journal_Entry__c rJE) {
        Journal_Entry__c jE = new Journal_Entry__c();
        jE.Name = rJE.Name;
        jE.Journal_Date__c = rJE.Next_Journal_Entry_Date__c;
        jE.Recurring_Journal_Entry__c = rJE.Id;
        jE.Auto_Reverse__c = rJE.Auto_Reverse__c;
        jE.Accrual_and_or_Cash__c = rJE.Accrual_and_or_Cash__c;
        jE.Ledger__c = rJE.Ledger__c;
        jE.Reference__c = rJE.Reference__c;
        jE.Type__c = rJE.Type__c;
        jE.Source__c = JournalEntryActions.SOURCE_RJE;
        if (isMultiCurrencyEnabled) {
            jE.put('CurrencyIsoCode', rJE.get('CurrencyIsoCode'));
        }
        return jE;
    }

    private Journal_Entry_Line__c getJournalEntryLineFromRecJournalEntryLine(Recurring_Journal_Entry_Line__c rJELine) {
        Journal_Entry_Line__c jELine = new Journal_Entry_Line__c();
        jELine.Recurring_Journal_Entry_Line__c = rJELine.Id;
        jELine.Cash_Flow_Category__c = rJELine.Cash_Flow_Category__c;
        jELine.GL_Account__c = rJELine.GL_Account__c;
        jELine.Units__c = rJELine.Quantity__c;
        jELine.Project__c = rJELine.Project__c;
        jELine.Project_Task__c = rJELine.Project_Task__c;
        jELine.Reference__c = rJELine.Reference__c;
        jELine.GL_Account_Variable_1__c = rJELine.GL_Account_Variable_1__c;
        jELine.GL_Account_Variable_2__c = rJELine.GL_Account_Variable_2__c;
        jELine.GL_Account_Variable_3__c = rJELine.GL_Account_Variable_3__c;
        jELine.GL_Account_Variable_4__c = rJELine.GL_Account_Variable_4__c;
        jELine.Credit__c = rJELine.Credit__c;
        jELine.Debit__c = rJELine.Debit__c;
        jELine.Account__c = rJELine.Account__c;
        jELine.Contact__c = rJELine.Contact__c;
        jELine.Employee__c = rJELine.Employee__c;
        jELine.Description__c = rJELine.Description__c;
        if (isProductAvailable) {
            jELine.Product__c = rJELine.Product__c;
        }
        return jELine;
    }

    private Boolean validateAndSetAccountingPeriod() {
        Boolean result = true;
        for (JournalEntryWrapper jew : (List<JournalEntryWrapper>) objList) {
            Accounting_Period__c currentAccountingPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(((Journal_Entry__c) jew.obj).Journal_Date__c);
            jew.hasError = false;

            if (currentAccountingPeriod == NULL) {
                result = false;
                resultStatusMap.get(jew.rObj.Id).errors.add(
                    new RecurringRecordErrorResult(
                        StatusCode.ACCOUNTING_PERIOD_ERROR,
                        NO_PERIOD_ERROR_MESSAGE
                    )
                );

                ((Journal_Entry__c) jew.obj).Journal_Date__c.addError(
                    String.format(
                        NO_PERIOD_ERROR_MESSAGE,
                        new List<String>{
                            String.valueOf((((Journal_Entry__c) jew.obj).Journal_Date__c).format())
                        }
                    )
                );
            } else {
                ((Journal_Entry__c) jew.obj).Accounting_Period__c = currentAccountingPeriod.Id;
                if (((Journal_Entry__c) jew.obj).Auto_Reverse__c) {
                    Accounting_Period__c nextAccountingPeriod =
                            AccountingPeriodHandler.getInstance().getNextAccountingPeriod(currentAccountingPeriod.Id);
                    if (nextAccountingPeriod == null || String.isBlank(nextAccountingPeriod.Id)) {
                        result = false;
                        resultStatusMap.get(jew.rObj.Id).errors.add(
                                new RecurringRecordErrorResult(
                                        StatusCode.ACCOUNTING_PERIOD_ERROR,
                                        Label.ERR_REVERSAL_ACCOUNTING_PERIOD_DOES_NOT_EXIST_BATCH_CONTEXT
                                )
                        );

                        ((Journal_Entry__c) jew.obj).Journal_Date__c.addError(Label.ERR_REVERSAL_ACCOUNTING_PERIOD_DOES_NOT_EXIST);

                        jew.hasError = true;
                    } else {
                        ((Journal_Entry__c) jew.obj).Reverse_Accounting_Period__c = nextAccountingPeriod.Id;
                    }
                }
            }
        }

        return result;
    }

    public PageReference createJEAndPost() {
        isNeedToPost = true;
        return createJE();
    }

    public PageReference createJE() {
        clearResultErrors();
        SavePoint sp = Database.setSavepoint();
        try {
            if (validateAndSetAccountingPeriod() || isBatchContext) {

                setFieldsOnRecurringRecords(
                    PACKAGE_QUALIFIER + 'Last_Journal_Entry_Date__c',
                    PACKAGE_QUALIFIER + 'Next_Journal_Entry_Date__c',
                    PACKAGE_QUALIFIER + 'Journal_Entry_Frequency__c'
                );

                doDMLs(true, true);
                if (objList.size() == 1
                        && resultStatusMap.get(objList[0].rObj.Id) != null
                        && !resultStatusMap.get(objList[0].rObj.Id).errors.isEmpty()) {
                    return null;
                }
                populateSuccessResults();

                if (isNeedToPost && !isLDOAsyncProcessingEnabled) {
                    AbstractPostHandler postHandler = new JournalEntryPostHandler();
                    AsyncPostHandlersExecutor asyncPHExecutor = new AsyncPostHandlersExecutor(getHeaderAndLineRecordsExistedInDB(), postHandler);
                    System.enqueueJob(asyncPHExecutor);
                    if (!isBatchContext) {
                        ApexPages.addMessage(
                            new ApexPages.Message(ApexPages.Severity.CONFIRM,
                                String.format(CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE, new List<String>{SObjectType.Journal_Entry__c.getLabelPlural().toLowerCase()})));
                    }
                }
                else if (!isBatchContext && synchronousRecordsCount > 0) {
                    String objName = synchronousRecordsCount > 1 ? SObjectType.Journal_Entry__c.getLabelPlural().toLowerCase() : SObjectType.Journal_Entry__c.getLabel().toLowerCase();
                    if (isLDOAsyncProcessingEnabled) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(CREATE_SOURCE_SUCCESS_MESSAGE, 
                            new List<String>{String.valueOf(synchronousRecordsCount), objName})));
                    } else {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(CREATE_SUCCESS_MESSAGE, new List<String>{objName})));
                    }
                }
                recordsCreated = true;
                isSuccess = true;

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
     * handle createing JEs from reucrring JEs asynchronously
     */
    private Integer processAsyncRecords() { 
        // recurring JEs to process asynchronously
        Set<Id> recurringJournalIds = new Set<Id>();
        // transaction groups which will be picked up by the async job.
        // these are created for JE headers which were created synchronously,
        // but have lines which will be processed asynchronously.
        List<Transaction_Group__c> txnGroups = new List<Transaction_Group__c>();
        // a UUID used to track transaction groups throughout a process
        String correlationId = System.UUID.randomUUID().toString();

        // collect data which requires further processing
        for (RecordWrapper rw : objList) {
            if (!rw.isHeaderRecordSavedInDB() && getHeaderProcessingMode(rw) == ProcessingMode.ASYNC && getLineProcessingMode(rw) == ProcessingMode.ASYNC) {
                recurringJournalIds.add(rw.rObj.Id);
            // header was created synchronously, but lines will be processed asynchronously
            } else if (rw.isHeaderRecordSavedInDB() && getHeaderProcessingMode(rw) == ProcessingMode.SYNC && getLineProcessingMode(rw) == ProcessingMode.ASYNC) {
                recurringJournalIds.add(rw.rObj.Id);
                // this will be picked up by the async job
                txnGroups.add(new Transaction_Group__c(
                    Recurring_Journal_Entry__c = rw.rObj.Id,
                    Journal_Entry__c = rw.obj.Id,
                    Status__c = TransactionGroupActions.STATUS_PROCESSING,
                    Batch_Id__c = correlationId,
                    Job_Type__c = JEFromRecurringJEBatch.class.getName(),
                    Line_Count__c = rw.recurringLineCount,
                    Lines_Processed__c = 0,
                    Ledger__c = ((Journal_Entry__c) rw.obj).Ledger__c
                ));
            }
        }

        // insert the transaction groups so the job can pick them up
        if (!txnGroups.isEmpty()) {
            SFDCSecurityUtils.insertProxy(txnGroups);
        }

        if (!recurringJournalIds.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(RECORDS_WILL_BE_PROCESSED_ASYNCHRONOUSLY, 
                new List<String>{String.valueOf(recurringJournalIds.size()), (recurringJournalIds.size() > 1 ? COMMON_RECORDS : COMMON_RECORD)})));
        }

        // start async processing
        if (!recurringJournalIds.isEmpty() && !Test.isRunningTest()) {
            Database.executeBatch(new JEFromRecurringJEBatch(recurringJournalIds, isNeedToPost, correlationId));
        }

        // number of recurring JE records which will be processed asynchronously
        return recurringJournalIds.size();
    }


    public class JournalEntryWrapper extends RecordWrapper {
        public String currencyIsoCode {get; set;}

        public JournalEntryWrapper(Recurring_Journal_Entry__c rJournalEntry, Journal_Entry__c journalEntry) {
            super(rJournalEntry, journalEntry, 0);
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                currencyIsoCode = (String) rJournalEntry.get('CurrencyIsoCode');
            }
        }

        public override Boolean isHeaderDirty() {
            Journal_Entry__c je = (Journal_Entry__c) obj;
            Recurring_Journal_Entry__c rJe = (Recurring_Journal_Entry__c) rObj;
            return je.Journal_Date__c != rJe.Next_Journal_Entry_Date__c || je.Name != rJe.Name;
        }

    }

}