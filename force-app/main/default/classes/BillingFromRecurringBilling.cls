/*
This class is used as page controller for BillingFromRecurringBilling and BillingsFromRecurringBillings pages
It can handle the single record conversion as well as the mass records conversion
*/

public with sharing class BillingFromRecurringBilling extends AbstractSourceFromRecurring {

    private static final Integer SYNC_DML_LIMIT = 500;

    private Boolean isOpportunityAvailable;
    private Boolean isProductAvailable;
    private Set<Id> recurringBillingIds;
    
    public List<BillingWrapper> billList {
        get {
            return (List<BillingWrapper>) objList;
        }
        set;
    }
    public Boolean isAvalaraTaxCalcEnabled {get; set;}
    
    public String dmlLimitErrorMsg {
        get {
            if (dmlLimitErrorMsg == null) {
                dmlLimitErrorMsg = dmlLimitError;
                if (isAvalaraTaxCalcEnabled && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                    dmlLimitErrorMsg += ' ' + Label.INF_CREATE_BILLING_LDO_LIMIT_WORKAROUND;
                }
            }
            return dmlLimitErrorMsg;
        }
        set;
    }

    //common constructor executed in any context
    public BillingFromRecurringBilling() {
        isAvalaraTaxCalcEnabled = false;
        isOpportunityAvailable = Schema.SObjectType.Opportunity.isAccessible();
        isProductAvailable = isProductAccessible() && Recurring_Billing_Line__c.SObjectType.fields.Product__c.getDescribe().isAccessible();
        isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        isHeaderLevelPostEnabled = AccountingSettingsHandler.isHeaderLevelPost();
        isError = false;
        isNeedToPost = false;
        isLDOAsyncProcessingEnabled = false;

        //used for batch for create all possible billings until multipleRecordsEndDate
        resultStatusMap = new Map<Id, RecurringRecordResult>();
        populateDescribeInfo();
        populateCheckListOfFields();
    }

    //constructor for single record conversion
    public BillingFromRecurringBilling(ApexPages.StandardController controller) {
        this();
        try {
            rSObjectList = queryRecurringBillings(new List<Recurring_Billing__c>{(Recurring_Billing__c) controller.getRecord()}, false);
            
            isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(rSObjectList);
            // avalara tax calculation requires all lines to be loaded in the view state.
            // because of this, this page is not available in LDO mode when avalara tax calculation is enabled.
            isLDOAsyncProcessingEnabled = !isAvalaraTaxCalcEnabled && FeatureManagementHandler.isLargeDataVolumeModeEnabled();
            DML_LIMIT = isLDOAsyncProcessingEnabled ? DML_LIMIT : SYNC_DML_LIMIT;
            
            rSObjectLinesMap = getLinesMap(queryRecurringBillingLines(), Recurring_Billing_Line__c.Recurring_Billing__c);

            validateDmlLimitCount();
            if (isDmlLimitError) {
                return;
            }

            if (isMultiCurrencyEnabled) {
                currencyIsoCode = (String) controller.getRecord().get('CurrencyIsoCode');
            }

            init();
            isInActiveError = ((List<Recurring_Billing__c>) rSObjectList)[0].Status__c == 'Inactive' ? true : false;

            if (isAvalaraTaxCalcEnabled) {
                handleAvalaraTaxLines(new Map<Id, SObject> (AvaTaxHelper.avalaraTaxCalculationList(rSObjectList)).keySet());
            }
        }
        catch (Exception ex) {
            isError = true;
            ApexPages.addMessages(ex);
        }
    }

    //constructor for multiple records conversion
    public BillingFromRecurringBilling(ApexPages.StandardSetController setController) {
        this((List<Recurring_Billing__c>) setController.getSelected());
        this.stdSetController = setController;
    }

    //constructor for batch class
    public BillingFromRecurringBilling(List<Recurring_Billing__c> selectedRecurringBillings) {
        this();
        try {
            rSObjectList = queryRecurringBillings(selectedRecurringBillings, true);
            
            isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled((List<SObject>)rSObjectList);
            // avalara tax calculation requires all lines to be loaded in the view state.
            // because of this, this page is not available in LDO mode when avalara tax calculation is enabled.
            isLDOAsyncProcessingEnabled = !isAvalaraTaxCalcEnabled && FeatureManagementHandler.isLargeDataVolumeModeEnabled();
            DML_LIMIT = isLDOAsyncProcessingEnabled ? DML_LIMIT : SYNC_DML_LIMIT;
           
            rSObjectLinesMap = getLinesMap(queryRecurringBillingLines(), Recurring_Billing_Line__c.Recurring_Billing__c);

            validateDmlLimitCount();
            if (!isDmlLimitError) {
                if (isMultiCurrencyEnabled) {
                    if (!rSObjectList.isEmpty()) {
                        currencyIsoCode = (String) rSObjectList[0].get('CurrencyIsoCode');
                    }
                }

                if (isAvalaraTaxCalcEnabled && rSObjectList.size() > AvaTaxHelper.AVALARA_SELECTED_RECORDS_LIMIT) {
                    throw new AvaTaxService.AvaTaxException(AvaTaxHelper.AVALARA_SELECTED_RECORDS_LIMIT_EXCEEDED_ERROR_MESSAGE);
                }

                isNoSelectionError = rSObjectList.isEmpty() ? true : false;

                if (!isNoSelectionError) {
                    init();
                    if (isAvalaraTaxCalcEnabled && !isBatchContext) {
                        handleAvalaraTaxLines(new Map<Id, SObject> (AvaTaxHelper.avalaraTaxCalculationList(rSObjectList)).keySet());
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
        this.targetHeaderRecordType = Billing__c.getSObjectType();
        this.targetLineRecordType = Billing_Line__c.getSObjectType();
        this.lineToHeaderRelationshipField = Billing_Line__c.Billing__c.getDescribe().getSobjectField();
        this.sourceRecurringRecordType = Recurring_Billing__c.getSObjectType();
    }

    private void populateCheckListOfFields() {
        this.checkFieldsOnTargetHeaderRecord = new List<String>{
            'Customer__c',
            'Date__c',
            'Recurring_Billing__c',
            'Ledger__c'
        };
        if (isOpportunityAvailable) {
            this.checkFieldsOnTargetHeaderRecord.add('Opportunity__c');
        }
        this.checkFieldsOnTargetLineRecord = new List<String>{};
        this.checkFieldsOnSourceRecurringRecord = new List<String>{
            'Next_Billing_Date__c',
            'Last_Billing_Date__c',
            'Billing_Frequency__c'
        };
    }

    public String getListViewId() {
        return stdSetController.getFilterId();
    }

    public String getSObjectApiName() {
        return Recurring_Billing__c.SObjectType.getDescribe().getName();
    }

    private List<Recurring_Billing__c> queryRecurringBillings(List<Recurring_Billing__c> selectedRecords, Boolean onlyActive) {
        //Select main query fields
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Status__c',
            'Next_Billing_Date__c',
            'Last_Billing_Date__c',
            'Billing_Frequency__c',
            'Ledger__c',
            'Sub_Total__c',
            'Sales_Tax__c',
            'Customer__c',
            'Billing_Contact__c',
            'PO_Number__c',
            'Line_Count__c',
            'Total__c',
            'Comment__c',
            'Customer__r.ShippingStreet',
            'Customer__r.ShippingCity',
            'Customer__r.ShippingState',
            'Customer__r.ShippingCountry',
            'Customer__r.ShippingPostalCode',
            'Customer__r.VAT_Business_Identification_Number__c',
            'Customer__r.Entity_Use_Code__c',
            'Customer__r.Exemption_Number__c'
        };
        //Add Opportunity field
        if (isOpportunityAvailable) {
            queryFields.add('Opportunity__c');
        }
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

        SOQLBuilder theQuery = new SOQLBuilder(Recurring_Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Recurring_Billing__c>) Database.query(theQuery.toSOQL());
    }

    private List<Recurring_Billing_Line__c> queryRecurringBillingLines() {
        List<Recurring_Billing__c> selectedRecords;
        // for ldo any billings with more than 1 line will have their lines processed async.
        // in ldo mode we can't bring all lines into the view state.
        if (isLDOAsyncProcessingEnabled) {
            selectedRecords = new List<Recurring_Billing__c>();
            for (Recurring_Billing__c rBill : (List<Recurring_Billing__c>) rSObjectList) {
                if (rBill.Line_Count__c == 1) {
                    selectedRecords.add(rBill);
                }
            }
        } else {
            selectedRecords = rSObjectList;
        }

        List<String> queryFields = new List<String>{
            'Id',
            'Recurring_Billing__c',
            'Recurring_Billing__r.Id',
            'Revenue_GL_Account__c',
            'Opportunity_Product_Id__c',
            'List_Price__c',
            'Rate__c',
            'Quantity__c',
            'Project__c',
            'Project_Task__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Comment__c',
            'Sub_Total__c',
            'Total__c',
            'Tax_Group__c',
            'Tax_Group__r.Combined_Tax_Rate__c',
            'Tax_Amount__c',
            'Tax_Inclusive__c'
        };

        if (isProductAvailable) {
            queryFields.addAll(new List<String>{
                'Product__c',
                'Product__r.Name',
                'Product__r.ProductCode',
                'Product__r.Tax_Code__c',
                'Product__r.Description'
            });
        }

        String queryCondition = 'Recurring_Billing__c IN :selectedRecords ';

        SOQLBuilder.Ordering ordering = new SOQLBuilder.Ordering('Recurring_Billing_Line__c', 'Name', SOQLBuilder.SortOrder.ASCENDING);

        SOQLBuilder theQuery = new SOQLBuilder(Recurring_Billing_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .addOrdering(ordering);

        return (List<Recurring_Billing_Line__c>) Database.query(theQuery.toSOQL());
    }

    private void init() {
        try {
            objList = new List<BillingWrapper>();
            Set<Date> billingDates = new Set<Date>();

            for (Recurring_Billing__c rBill : (List<Recurring_Billing__c>) rSObjectList) {
                resultStatusMap.put(rBill.Id, new RecurringRecordResult('Billing', rBill.Id));
                billingDates.add(Date.newInstance(rBill.Next_Billing_Date__c.year(), rBill.Next_Billing_Date__c.month(), 1));
            }
            Map<Date, Accounting_Period__c> periodsMap = new Map<Date, Accounting_Period__c>();
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            for (Date billingDate : billingDates) {
                Accounting_Period__c period = acctPeriodHandler.getAccountingPeriodByStartDate(billingDate);
                if (period != NULL) {
                    periodsMap.put(period.Start_Date__c, period);
                }
            }
            for (Recurring_Billing__c rBill : (List<Recurring_Billing__c>) rSObjectList) {
                Billing__c bill = getBillingFromRecBilling(rBill);
                Date periodStartDate = Date.newInstance(rBill.Next_Billing_Date__c.year(), rBill.Next_Billing_Date__c.month(), 1);
                bill.Accounting_Period__c = periodsMap.containsKey(periodStartDate) ? periodsMap.get(periodStartDate).Id : NULL;
                BillingWrapper bw = new BillingWrapper(rBill, bill);
                bw.recurringLineCount = 0;
                bw.combinedTaxRate = 0;
                bw.salesTaxAmount = rBill.Sales_Tax__c;
                bw.subTotal = rBill.Sub_Total__c;
                // when async processing is enabled and the billing has more than 1 line
                // we need to set some values based on the header. In this scenario
                // the billing lines will not have been queried to avoid hitting limits
                // in ldo mode.
                if (isLDOAsyncProcessingEnabled && !rSObjectLinesMap.containsKey(rBill.Id)) {
                    bw.recurringLineCount = Integer.valueOf(rBill.Line_Count__c);
                    bw.total = rBill.Total__c;
                }
                if (rSObjectLinesMap.containsKey(rBill.Id)) {
                    bw.recurringLineCount = rSObjectLinesMap.get(rBill.Id).size();
                    bw.combinedTaxRate = getCombinedTaxRate(rSObjectLinesMap.get(rBill.Id));
                    for (Recurring_Billing_Line__c rBillLine : (List<Recurring_Billing_Line__c>) rSObjectLinesMap.get(rBill.Id)) {
                        bw.total += rBillLine.Total__c;
                        bw.objLines.add(getBillingLineFromRecBillingLine(bill, rBillLine));
                    }
                }
                resultStatusMap.get(rBill.Id).totalRecords += 1;
                objList.add(bw);
            }
        }
        catch (Exception ex) {
            if (!isBatchContext) {
                ApexPages.addMessages(ex);
            }
        }

    }

    private Decimal getCombinedTaxRate(List<Recurring_Billing_Line__c> rBillLinesList ) {
        Decimal taxRate = 0;
        if (!rBillLinesList.isEmpty() && rBillLinesList[0].Tax_Group__c != NULL) {
            taxRate = rBillLinesList[0].Tax_Group__r.Combined_Tax_Rate__c;
        }
        return taxRate;
    }

    private Billing__c getBillingFromRecBilling(Recurring_Billing__c rBill) {
        Billing__c bill = new Billing__c();
        bill.Customer__c = rBill.Customer__c;
        bill.Customer__r = rBill.Customer__r;
        bill.Opportunity__c = isOpportunityAvailable ? rBill.Opportunity__c : NULL;
        bill.Date__c = rBill.Next_Billing_Date__c;
        bill.Recurring_Billing__c = rBill.Id;
        bill.Ledger__c = (rBill.Ledger__c == NULL) ? LedgerHandler.getLegacyDefaultLedgerId() : rBill.Ledger__c;
        bill.Accounting_Period__c = NULL;
        bill.Billing_Contact__c = rBill.Billing_Contact__c;
        bill.PO_Number__c = rBill.PO_Number__c;
        bill.Billing_Comment__c = rBill.Comment__c;

        if (isMultiCurrencyEnabled) {
            bill.put('CurrencyIsoCode', rBill.get('currencyIsoCode'));
        }
        return bill;
    }

    private Billing_Line__c getBillingLineFromRecBillingLine(Billing__c bill, Recurring_Billing_Line__c rBillLine) {
        Billing_Line__c billLine = new Billing_Line__c();
        billLine.Recurring_Billing_Line__c = rBillLine.Id;
        billLine.Revenue_GL_Account__c = rBillLine.Revenue_GL_Account__c;
        billLine.Opportunity_Product_Id__c = rBillLine.Opportunity_Product_Id__c;
        billLine.List_Price__c = rBillLine.List_Price__c;
        billLine.Date__c = bill.Date__c;
        billLine.Rate__c = rBillLine.Rate__c;
        billLine.Hours_Units__c = rBillLine.Quantity__c;
        billLine.Tax_Amount2__c = rBillLine.Tax_Amount__c;
        billLine.Tax_Group__c = rBillLine.Tax_Group__c;
        billLine.Project__c = rBillLine.Project__c;
        billLine.Project_Task__c = rBillLine.Project_Task__c;
        billLine.Comment__c = rBillLine.Comment__c;
        billLine.GL_Account_Variable_1__c = rBillLine.GL_Account_Variable_1__c;
        billLine.GL_Account_Variable_2__c = rBillLine.GL_Account_Variable_2__c;
        billLine.GL_Account_Variable_3__c = rBillLine.GL_Account_Variable_3__c;
        billLine.GL_Account_Variable_4__c = rBillLine.GL_Account_Variable_4__c;
        billLine.Tax_Inclusive__c = rBillLine.Tax_Inclusive__c;
        billLine.Combined_Tax_Rate__c = rBillLine.Tax_Group__r.Combined_Tax_Rate__c;
        if (isProductAvailable) {
            billLine.Product__c = rBillLine.Product__c;
            billLine.Product__r = rBillLine.Product__r;
        }
        return billLine;
    }

    private Boolean validateAndSetAccountingPeriod() {
        Boolean result = true;
        for (BillingWrapper bw : (List<BillingWrapper>) objList) {
            Accounting_Period__c currentAccountingPeriod =
                AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(((Billing__c) bw.obj).Date__c);

            if (currentAccountingPeriod == NULL) {
                result = false;
                resultStatusMap.get(bw.rObj.Id).errors.add(
                    new RecurringRecordErrorResult(
                        StatusCode.ACCOUNTING_PERIOD_ERROR,
                        NO_PERIOD_ERROR_MESSAGE
                    )
                );

                ((Billing__c) bw.obj).Date__c.addError(
                    String.format(
                        NO_PERIOD_ERROR_MESSAGE,
                        new List<String>{
                            String.valueOf((((Billing__c) bw.obj).Date__c).format())
                        }
                    )
                );
            } else {
                ((Billing__c) bw.obj).Accounting_Period__c = currentAccountingPeriod.Id;
            }
        }

        return result;
    }

    public void updateLinesDates() {
        if (billList != null) {
            for (BillingWrapper billWrap : billList) {
                Date billingDate = (Date) billWrap.obj.get(PACKAGE_QUALIFIER + 'Date__c');
                if (billWrap.objLines != null && !billWrap.objLines.isEmpty() &&
                        billingDate != (Date)billWrap.objLines[0].get(PACKAGE_QUALIFIER + 'Date__c')) {
                    for (SObject line : billWrap.objLines) {
                        line.put(PACKAGE_QUALIFIER + 'Date__c', billingDate);
                    }
                }
            }
        }
    }

    public PageReference createBillingAndPost() {
        isNeedToPost = true;
        return createBilling();
    }

    public PageReference createBilling() {
        clearResultErrors();
        List<SObject> validRecords = new List<SObject>();
        //separate try-catch block because of callout inside
        //and we can't do it after Database.setSavepoint() call
        for (BillingWrapper bw : (List<BillingWrapper>) objList) {
            validRecords.add(bw.rObj);
        }

        try {
            if (isAvalaraTaxCalcEnabled) {
                handleAvalaraTaxLines(new Map<Id, SObject> (AvaTaxHelper.avalaraTaxCalculationList(validRecords)).keySet());
            }
        }
        catch (Exception ex) {
            //silently catch all possible unhandled exceptions
        }

        //Recalculate Total value (wrapper's property) for each line in wrapper to render it after form re-render (if submit error etc)
        if (!isBatchContext) {
            for (BillingWrapper bw : (List<BillingWrapper>) objList) {
                bw.setTotal();
            }
        }

        SavePoint sp = (Test.isRunningTest() && isAvalaraTaxCalcEnabled) ? NULL : Database.setSavepoint();
        try {
            if (validateAndSetAccountingPeriod() || isBatchContext) {
                setFieldsOnRecurringRecords(
                    PACKAGE_QUALIFIER + 'Last_Billing_Date__c',
                    PACKAGE_QUALIFIER + 'Next_Billing_Date__c',
                    PACKAGE_QUALIFIER + 'Billing_Frequency__c'
                );

                doDMLs();
                if (objList.size() == 1
                        && resultStatusMap.get(objList[0].rObj.Id) != null
                        && !resultStatusMap.get(objList[0].rObj.Id).errors.isEmpty()) {
                    return null;
                }
                populateSuccessResults();

                // get billings where both header and lines were created synchrolnously
                List<SObject> billings = getHeaderAndLineRecordsExistedInDB();
                if (isNeedToPost && !billings.isEmpty()) {
                    if (isAvalaraTaxCalcEnabled && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                        // if avalara + ldo, we need to post the billings using a different method
                        // which takes ldo into account. Even though this page doesn't have ldo support
                        // for avalara the posting should still run in ldo mode.
                        List<Id> billingIds = new List<Id>((new Map<Id,SObject>(billings)).keySet());
                        PostProcessor processor = new PostProcessor();
                        processor.post(billingIds);
                    } else {
                        AbstractPostHandler postHandler = new BillingPostHandler();
                        AsyncPostHandlersExecutor asyncPHExecutor = new AsyncPostHandlersExecutor(billings, postHandler);
                        System.enqueueJob(asyncPHExecutor);
                    }
                    if (!isBatchContext) {
                        ApexPages.addMessage(
                            new ApexPages.Message(ApexPages.Severity.CONFIRM,
                                String.format(CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE, new List<String>{'billings'})));
                    }
                }
                else {//if Not Posted Billings were created
                    //===================================================================
                    //Make call to the Avalara side to create "Saved"("Uncommitted") Tax transactions
                    if (!Test.isRunningTest() && isAvalaraTaxCalcEnabled) {
                        AvaTaxHelper.asyncCreateTransaction(billings, false);
                    }
                    //==================================================================
                    if (!isBatchContext && synchronousRecordsCount > 0) {
                        String objName = synchronousRecordsCount > 1 ? SObjectType.Billing__c.getLabelPlural().toLowerCase() : SObjectType.Billing__c.getLabel().toLowerCase();
                        if (isLDOAsyncProcessingEnabled) {
                            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(CREATE_SOURCE_SUCCESS_MESSAGE, 
                                new List<String>{String.valueOf(synchronousRecordsCount), objName})));
                        } else {
                            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(CREATE_SUCCESS_MESSAGE, new List<String>{objName})));
                        }
                    }
                }

                recordsCreated = true;

                // if a single billing and lines were processed synchronously
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
            if (!(Test.isRunningTest() && isAvalaraTaxCalcEnabled)) {
                Database.rollback(sp);
            }
            handleExternalExceptionAndRollBack(ex);
            if (!isBatchContext) {
                ApexPages.addMessages(ex);
            }
        }

        isNeedToPost = false;
        return NULL;
    }

    /**
     * handle createing billings from reucrring billings asynchronously
     */
    private Integer processAsyncRecords() { 
        // recurring billings to process asynchronously
        Set<Id> recurringBillingIds = new Set<Id>();
        // transaction groups which will be picked up by the async job.
        // these are created for billing headers which were created synchronously,
        // but have lines which will be processed asynchronously.
        List<Transaction_Group__c> txnGroups = new List<Transaction_Group__c>();
        // a UUID used to track transaction groups throughout a process
        String correlationId = System.UUID.randomUUID().toString();

        // collect data which requires further processing
        for (RecordWrapper rw : objList) {
            if (!rw.isHeaderRecordSavedInDB() && getHeaderProcessingMode(rw) == ProcessingMode.ASYNC && getLineProcessingMode(rw) == ProcessingMode.ASYNC) {
                recurringBillingIds.add(rw.rObj.Id);
            // header was created synchronously, but lines will be processed asynchronously
            } else if (rw.isHeaderRecordSavedInDB() && getHeaderProcessingMode(rw) == ProcessingMode.SYNC && getLineProcessingMode(rw) == ProcessingMode.ASYNC) {
                recurringBillingIds.add(rw.rObj.Id);
                // this will be picked up by the async job
                txnGroups.add(new Transaction_Group__c(
                    Recurring_Billing__c = rw.rObj.Id,
                    Billing__c = rw.obj.Id,
                    Status__c = TransactionGroupActions.STATUS_PROCESSING,
                    Batch_Id__c = correlationId,
                    Job_Type__c = BillingFromRecurringBillingBatch.class.getName(),
                    Line_Count__c = rw.recurringLineCount,
                    Lines_Processed__c = 0,
                    Ledger__c = ((Billing__c) rw.obj).Ledger__c
                ));
            }
        }

        // insert the transaction groups so the job can pick them up
        if (!txnGroups.isEmpty()) {
            SFDCSecurityUtils.insertProxy(txnGroups);
        }

        if (!recurringBillingIds.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, String.format(RECORDS_WILL_BE_PROCESSED_ASYNCHRONOUSLY, 
                new List<String>{String.valueOf(recurringBillingIds.size()), (recurringBillingIds.size() > 1 ? COMMON_RECORDS : COMMON_RECORD)})));
        }

        // start async processing
        if (!recurringBillingIds.isEmpty() && !Test.isRunningTest()) {
            Database.executeBatch(new BillingFromRecurringBillingBatch(recurringBillingIds, isNeedToPost, correlationId));
        }

        // number of recurring billing records which will be processed asynchronously
        return recurringBillingIds.size();
    }


    private void populateCurrencyConversionRate(Set<Id> avaTaxObjIds) {
        if (isMultiCurrencyEnabled) {
           List<Billing__c> billList = new List<Billing__c>();
            for (BillingWrapper billWrapper: (List<BillingWrapper>) objList) {
                Billing__c bill = (Billing__c) billWrapper.obj;
                if (avaTaxObjIds.contains(billWrapper.rObj.Id) && LedgerHandler.isUSDLedger(bill.Ledger__c)) {
                    billList.add(bill);
                }
            }

            MultiCurrencyHandler.setCurrencyConversionRateBySourceDocumentAndLedger(NULL, billList, 'Date__c');

            for (BillingWrapper billWrapper : (List<BillingWrapper>) objList) {
                Billing__c bill = (Billing__c) billWrapper.obj;
                if (avaTaxObjIds.contains(billWrapper.rObj.Id) && LedgerHandler.isUSDLedger(bill.Ledger__c)) {
                    billWrapper.setCurrencyConversionRate(
                        bill.Currency_Conversion_Rate__c
                    );
                }
            }
        }
    }

    private void handleAvalaraTaxLines(Set<Id> avaTaxObjIds) {
        try {
            populateCurrencyConversionRate(avaTaxObjIds);
        }
        catch (Exception ex) {
            throw ex;
        }

        for (BillingWrapper billWrapper : (List<BillingWrapper>) objList) {
            if (avaTaxObjIds.contains(billWrapper.rObj.Id)) {
                try {
                    Boolean isTaxableByCurrency =
                        isMultiCurrencyEnabled
                            ? LedgerHandler.isUSDLedger(((Billing__c) billWrapper.obj).Ledger__c)
                            : true;

                    //Line Level Post mode -> remove existed Sales Tax Line
                    if (!isHeaderLevelPostEnabled && (!isTaxableByCurrency || !billWrapper.taxableLineExists((Billing__c) billWrapper.obj))) {
                        billWrapper.removeOldSalesTaxLine(billWrapper.obj);
                    }
                    //If record is taxable calculate Taxes depending on current Post Settings mode (LLP or HLP)
                    if (isTaxableByCurrency && billWrapper.taxableLineExists((Billing__c) billWrapper.obj)) {
                        AvaTaxService.CreateTransactionModel request = billWrapper.getCreateTransactionModel();
                        AvaTaxHelper.sourceRecord = (Billing__c) billWrapper.obj;
                        AvaTaxService.TransactionModel response = AvaTaxHelper.calcTax(request);
                        if (isHeaderLevelPostEnabled) {
                            billWrapper.updateTaxAmount(response);
                        }
                        else {
                            billWrapper.upsertSalesTaxLine(response, billWrapper.obj);
                        }
                        billWrapper.setTotal();
                    }
                }
                catch (Exception ex) {
                    if (isBatchContext) {
                        resultStatusMap.get(billWrapper.rObj.Id).errors.add(
                            new RecurringRecordErrorResult(StatusCode.EXTERNAL_ERROR, ex.getMessage())
                        );
                    }
                    else {
                        throw ex;
                    }
                }
            }
        }
    }

    //===============================================================================================================
    //===============================================================================================================
    //===============================================================================================================

    public with sharing class BillingWrapper extends RecordWrapper {
        private Decimal combinedTaxRate;
        private Decimal currencyConversionRate;
        @TestVisible
        private Map<String, Billing_Line__c> billingLineMappedByRecBillLineId = new Map<String, Billing_Line__c>();
        private Boolean isHlpMode = AccountingSettingsHandler.isHeaderLevelPost();
        private Boolean isAvalaraTaxCalcEnabled = false;

        public Decimal taxRate {
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

        public Boolean taxInclusive {
            get {
                if (recurringLineCount == 1  && !objLines.isEmpty()) {
                    return ((Billing_Line__c)objLines[0]).Tax_Inclusive__c;
                }
                return false;
            }
            set;
        }

        public BillingWrapper(Recurring_Billing__c rBill, Billing__c bill) {
            super(rBill, bill, 0);
            this.currencyConversionRate = 1.0;//default value, must be updated before Billing creation
            isAvalaraTaxCalcEnabled = AvaTaxHelper.isAvalaraTaxCalculationEnabled(rObj);
        }

        public void setCurrencyConversionRate(Decimal value) {
            this.currencyConversionRate = value;
        }

        public Decimal getCurrencyConversionRate() {
            return currencyConversionRate;
        }

        public Boolean taxableLineExists(Billing__c bill) {
            for (Billing_Line__c billLine : (List<Billing_Line__c>) objLines) {
                if (AvaTaxHelper.validateBillingLineIsTaxable(billLine, bill)) {
                    return true;
                }
            }
            return false;
        }

        private Decimal calcSubTotalOfBillingLine(Billing_Line__c billLine) {
            return billLine.Rate__c * billLine.Hours_Units__c;
        }

        private Decimal calcTaxAmountOfBillingLine(Billing_Line__c billLine) {
            Decimal result = 0;
            if (isAvalaraTaxCalcEnabled) {
                result = ((billLine.Tax_Amount2__c != NULL) ? billLine.Tax_Amount2__c : 0);
            } 
            else if (taxInclusive) {
                Decimal total = calcSubTotalOfBillingLine(billLine);
                result = total - (total / (1 + taxRate));
            }
            else {
                result = calcSubTotalOfBillingLine(billLine) * taxRate;
            }
            return result;
        }

        public void setTotal() {
            if (isHlpMode) {
                if (!isAvalaraTaxCalcEnabled && recurringLineCount == 1 && !objLines.isEmpty()) {
                    Billing_Line__c billLine = (Billing_Line__c) objLines[0];
                    total = calcSubTotalOfBillingLine(billLine) + calcTaxAmountOfBillingLine(billLine);
                }
                else if (isAvalaraTaxCalcEnabled && !objLines.isEmpty()) {
                    total = 0;
                    for (Billing_Line__c billLine : (List<Billing_Line__c>) objLines) {
                        total += (calcSubTotalOfBillingLine(billLine) + calcTaxAmountOfBillingLine(billLine));
                    }
                }
            }
            else {
                total = 0;
                for (Billing_Line__c billLine : (List<Billing_Line__c>) objLines) {
                    total += calcSubTotalOfBillingLine(billLine);
                }
            }
        }

        public Decimal salesTaxAmount {
            get {
                if (isHlpMode) {
                    if (!isAvalaraTaxCalcEnabled && recurringLineCount == 1 && !objLines.isEmpty()) {
                        Billing_Line__c billLine = (Billing_Line__c) objLines[0];
                        billLine.Tax_Amount2__c = calcTaxAmountOfBillingLine(billLine);
                        salesTaxAmount = billLine.Tax_Amount2__c;
                    }
                    else if (isAvalaraTaxCalcEnabled && !objLines.isEmpty()) {
                        salesTaxAmount = 0;
                        for (Billing_Line__c billLine : (List<Billing_Line__c>) objLines) {
                            salesTaxAmount += (billLine.Tax_Amount2__c != NULL) ? billLine.Tax_Amount2__c : 0;
                        }
                    }
                }
                else {
                    for (Billing_Line__c billLine : (List<Billing_Line__c>) objLines) {
                        if (billLine.Product__c != NULL && billLine.Product__c == AvaTaxHelper.getSalesTaxProductId(rObj)) {
                            salesTaxAmount = billLine.Rate__c;
                        }
                    }
                }
                return salesTaxAmount;
            }
            set;
        }

        public Decimal subTotal {
            get {
                if (recurringLineCount == 1 && !objLines.isEmpty()) {
                    Billing_Line__c line = (Billing_Line__c) objLines[0];
                    if (taxInclusive) {
                        Decimal total = calcSubTotalOfBillingLine(line);
                        subTotal = total / (1 + taxRate);
                    } else {
                        subTotal = line.Rate__c * line.Hours_Units__c;
                    }
                }
                return subTotal;
            }
            set;
        }

        public Billing_Line__c removeOldSalesTaxLine(SObject obj) {
            List<Billing_Line__c> newLineCollection = new List<Billing_Line__c>();
            Billing_Line__c result;
            for (Billing_Line__c billLine : (List<Billing_Line__c>) objLines) {
                if (billLine.Product__c != AvaTaxHelper.getSalesTaxProductId(obj)) {
                    newLineCollection.add(billLine);
                }
                else {
                    result = billLine;
                }
            }

            objLines = newLineCollection;
            return result;
        }

        public void upsertSalesTaxLine(AvaTaxService.TransactionModel avaTaxTransaction, SObject obj) {
            Billing_Line__c oldSalesTaxLine = removeOldSalesTaxLine(obj);

            Billing_Line__c newSalesTaxLine = new Billing_Line__c();
            newSalesTaxLine.Date__c = avaTaxTransaction.avaTaxDate;
            newSalesTaxLine.Revenue_GL_Account__c = AvaTaxHelper.getAvaTaxGLAccount(obj);
            newSalesTaxLine.Product__c = AvaTaxHelper.getSalesTaxProductId(obj);
            newSalesTaxLine.Hours_Units__c = 1;
            newSalesTaxLine.Rate__c = avaTaxTransaction.totalTax * getCurrencyConversionRate();
            newSalesTaxLine.List_Price__c = 0;

            if (oldSalesTaxLine != NULL) {
                newSalesTaxLine.Project__c = oldSalesTaxLine.Project__c;
                newSalesTaxLine.Project_Task__c = oldSalesTaxLine.Project_Task__c;
                newSalesTaxLine.GL_Account_Variable_1__c = oldSalesTaxLine.GL_Account_Variable_1__c;
                newSalesTaxLine.GL_Account_Variable_2__c = oldSalesTaxLine.GL_Account_Variable_2__c;
                newSalesTaxLine.GL_Account_Variable_3__c = oldSalesTaxLine.GL_Account_Variable_3__c;
                newSalesTaxLine.GL_Account_Variable_4__c = oldSalesTaxLine.GL_Account_Variable_4__c;
            }

            objLines.add(newSalesTaxLine);
        }

        public void updateTaxAmount(AvaTaxService.TransactionModel avaTaxTransaction) {
            AvaTaxHelper.populateTaxAmountOnVirtualLines(avaTaxTransaction, billingLineMappedByRecBillLineId, getCurrencyConversionRate());
            objLines = billingLineMappedByRecBillLineId.values();
        }

        public AvaTaxService.CreateTransactionModel getCreateTransactionModel() {
            billingLineMappedByRecBillLineId.clear();
            AvaTaxService.CreateTransactionModel result = new AvaTaxService.CreateTransactionModel();
            result.companyCode = AvaTaxHelper.getCompanyCode(rObj);
            result.type = AvaTaxService.DocumentType.SalesOrder;
            result.avaTaxDate = ((Billing__c) obj).Date__c;
            result.customerCode = ((Billing__c) obj).Customer__c;
            result.businessIdentificationNo = ((Recurring_Billing__c) rObj).Customer__r.VAT_Business_Identification_Number__c;
            result.entityUseCode = ((Recurring_Billing__c) rObj).Customer__r.Entity_Use_Code__c;
            result.exemptionNo = ((Recurring_Billing__c) rObj).Customer__r.Exemption_Number__c;
            result.addresses = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(rObj), AvaTaxHelper.getDestinationAddressInfo(rObj), rObj);
            result.currencyCode = 'USD';//currently we support only USD

            result.lines = getLines(rObj);

            result.doCommit = false;

            return result;
        }

        private List<AvaTaxService.LineItemModel> getLines(SObject parentObj) {
            List<AvaTaxService.LineItemModel> result = new List<AvaTaxService.LineItemModel>();
            for (Billing_Line__c billLine : (List<Billing_Line__c>) objLines) {
                //map all Billing Lines by source Recurring Billing Line b/c they do not have ID yet
                String uniqKey = billLine.Recurring_Billing_Line__c;
                billingLineMappedByRecBillLineId.put(uniqKey, billLine);
                //include only Taxable Line into request data
                if (AvaTaxHelper.validateBillingLineIsTaxable(billLine, parentObj)) {
                    AvaTaxService.LineItemModel tempLine = new AvaTaxService.LineItemModel();
                    tempLine.avaTaxNumber = uniqKey;
                    tempLine.amount = (billLine.Hours_Units__c * billLine.Rate__c) / getCurrencyConversionRate();
                    tempLine.quantity = Math.abs(billLine.Hours_Units__c);
                    AvaTaxHelper.putItemCodeOnLine(tempLine, billLine.Product__r);
                    tempLine.description = billLine.Product__r.Description;
                    result.add(tempLine);
                }
            }
            return result;
        }

        public override Boolean isHeaderDirty() {
            Billing__c bill = (Billing__c) obj;
            Recurring_Billing__c rBill = (Recurring_Billing__c) rObj;
            return bill.Date__c != rBill.Next_Billing_Date__c;
        }
    }

}