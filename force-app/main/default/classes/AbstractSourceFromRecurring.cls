public with sharing abstract class AbstractSourceFromRecurring {
    
    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String NO_PERIOD_ERROR_MESSAGE = Label.ERR_NO_ACCOUNTING_PERIOD;
    public static final String INVALID_PERIOD_ERROR_MESSAGE = Label.ERR_INVALID_OFFSET_ACCOUNTING_PERIOD;
    public static final String INVALID_ASSIGNEE_ERROR_MESSAGE = Label.ERR_INVALID_ASSIGNEE;
    public static final String CREATE_AND_POST_SUCCESS_MESSAGE = Label.INF_CREATE_AND_POST_SUCCESS;
    public static final String CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE = Label.INF_CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS;
    public static final String CREATE_SUCCESS_MESSAGE = Label.INF_CREATE_SUCCESS_MESSAGE;
    public static final String DML_LIMIT_ERROR = Label.ERR_DML_LIMIT;
    public static final String RECORDS_WILL_BE_PROCESSED_ASYNCHRONOUSLY = Label.INF_RECORDS_WILL_BE_PROCESSED_ASYNCHRONOUSLY;
    public static final String COMMON_RECORD = Label.INF_COMMON_RECORD;
    public static final String COMMON_RECORDS = Label.INF_COMMON_RECORDS;
    public static final String CREATE_SOURCE_SUCCESS_MESSAGE = Label.INF_CREATE_SOURCE_SUCCESS_MESSAGE;

    public static Integer DML_LIMIT = 1000;

    protected Integer synchronousRecordsCount = 0;
    protected final ApexPages.StandardSetController stdSetController;
    protected Boolean isNeedToPost;
    protected Boolean isBatchContext = System.isBatch();

    transient protected List<SObject> rSObjectList;
    transient protected Map<Id, List<SObject>> rSObjectLinesMap;
    protected List<String> checkFieldsOnTargetHeaderRecord;
    protected List<String> checkFieldsOnTargetLineRecord;
    protected List<String> checkFieldsOnSourceRecurringRecord;
    protected SObjectType targetHeaderRecordType;
    protected SObjectType targetLineRecordType;
    protected SObjectType sourceRecurringRecordType;
    protected SObjectField lineToHeaderRelationshipField;

    public Map<Id, RecurringRecordResult> resultStatusMap;
    public List<RecordWrapper> objList {get; set;}
    public Boolean isLDOAsyncProcessingEnabled;
    public Boolean isDmlLimitError {get; set;}
    public Boolean isError {get; set;}
    public Boolean isInActiveError {get; set;}
    public Boolean isNoSelectionError {get; set;}
    public Boolean isSuccess {get; set;}
    public Boolean recordsCreated {
        get {
            if (recordsCreated == NULL) {
                return false;
            }
            else {
                return recordsCreated;
            }
        }
        set;
    }

    public String dmlLimitError {
        get {
            if (dmlLimitError == NULL) {
                dmlLimitError = String.format(DML_LIMIT_ERROR, new List<String> {String.valueOf(DML_LIMIT)});
            }
            return dmlLimitError;
        }
        set;
    }

    //several properties used if SF multi currency feature is enabled in the Org
    public Boolean isMultiCurrencyEnabled {get ;set;}
    public String currencyIsoCode {get; set;}
    public Boolean isHeaderLevelPostEnabled {get; set;}
    private Integer rSObjectLinesCount = 0;

    protected Boolean isProductAccessible() {
        return Product2.SObjectType.getDescribe().isAccessible();
    }

    protected void validateDmlLimitCount() {
        isDmlLimitError = false;
        if ((rSObjectList.size() + rSObjectLinesCount) > DML_LIMIT + 1) {
            isDmlLimitError = true;
        }
    }

    //1. Insert Target Header Records
    private void insertHeaderRecords(boolean wrapperErrorHandling) {
        Map<Integer, RecordWrapper> indexToRecWrapper = new Map<Integer, RecordWrapper>();
        List<SObject> targetHeaderRecords = new List<SObject>();

        Integer indexOne = 0;
        for (RecordWrapper rw : objList) {
            if((!wrapperErrorHandling || (wrapperErrorHandling && !rw.hasError)) && getHeaderProcessingMode(rw) == ProcessingMode.SYNC){
                indexToRecWrapper.put(indexOne, rw);
                targetHeaderRecords.add(rw.obj);    
            }
            indexOne++;
        }

        List<SObject> targetHeaderRecordsToInsert = (List<SObject>) Type.forName(
            'List<' + targetHeaderRecordType + '>'
        ).newInstance();
        targetHeaderRecordsToInsert.addAll(targetHeaderRecords);

        Integer indexTwo = 0;
        for (Database.SaveResult saveResult : SFDCSecurityUtils.insertCheckCRUDAndFLS(targetHeaderRecordsToInsert, checkFieldsOnTargetHeaderRecord, false)) {
            if (!saveResult.isSuccess()) {
                Id recurringRecordId = indexToRecWrapper.get(indexTwo).rObj.Id;
                resultStatusMap.get(recurringRecordId).errors.add(
                    new RecurringRecordErrorResult(StatusCode.EXTERNAL_ERROR, saveResult.getErrors())
                );
            }
            indexTwo++;
        }
    }

    //2. Insert Target Line Records
    private Map<Id, List<Database.Error>> insertLines() {
        List<SObject> targetLineRecords = new List<SObject>();
        for (RecordWrapper rw : objList) {
            if (rw.isHeaderRecordSavedInDB() && getLineProcessingMode(rw) == ProcessingMode.SYNC) {
                rw.bindLinesWithHeader(lineToHeaderRelationshipField);
                targetLineRecords.addAll(rw.objLines);
            }
        }

        List<SObject> targetLineRecordsToInsert = (List<SObject>) Type.forName(
            'List<' + targetLineRecordType + '>'
        ).newInstance();
        targetLineRecordsToInsert.addAll(targetLineRecords);

        Map<Id, List<Database.Error>> headerIdToErrorsOnLine = new Map<Id, List<Database.Error>>();
        Map<Integer, List<Database.Error>> lineIndexToErrors = new Map<Integer, List<Database.Error>>();
        Integer saveLineIndex = 0;
        for (Database.SaveResult saveResult : SFDCSecurityUtils.insertCheckCRUDAndFLS(targetLineRecordsToInsert, checkFieldsOnTargetLineRecord, false)) {
            if (!saveResult.isSuccess()) {
                lineIndexToErrors.put(saveLineIndex, saveResult.getErrors());
            }
            saveLineIndex++;
        }

        if (!lineIndexToErrors.isEmpty()) {
            saveLineIndex = 0;
            for (SObject lineToInsert : targetLineRecordsToInsert) {
                if (lineToInsert.Id == NULL) {//has not been saved
                    //get Id of header record
                    Id headerId = (Id) lineToInsert.get(lineToHeaderRelationshipField);
                    //build mapping between header Id and line's DML errors
                    if (headerIdToErrorsOnLine.containsKey(headerId)) {
                        headerIdToErrorsOnLine.get(headerId).addAll(lineIndexToErrors.get(saveLineIndex));
                    }
                    else {
                        headerIdToErrorsOnLine.put(headerId, lineIndexToErrors.get(saveLineIndex));
                    }
                }
                saveLineIndex++;
            }
        }

        return headerIdToErrorsOnLine;
    }

    //2.1 Roll back Header Records if not all related lines have been saved successfully
    private void rollbackIfLineInsertFailed(Map<Id, List<Database.Error>> headerIdToErrorsOnLine) {
        List<SObject> headerRecordsToDelete = new List<SObject>();
        Set<Id> headerIdsToDelete = new Set<Id>();
        for (RecordWrapper rw : objList) {
            if (rw.isHeaderRecordSavedInDB() && headerIdToErrorsOnLine.containsKey(rw.obj.Id)) {
                //put error statistics for final report
                resultStatusMap.get(rw.rObj.Id).errors.add(
                    new RecurringRecordErrorResult(StatusCode.EXTERNAL_ERROR, headerIdToErrorsOnLine.get(rw.obj.Id))
                );
                //prepare list of Headers to delete them
                headerRecordsToDelete.add(rw.obj);
                headerIdsToDelete.add(rw.obj.Id);
            }
        }
        //remove all Headers whose line(s) failed during DML
        SFDCSecurityUtils.deleteProxy(headerRecordsToDelete);
        //clear wrapped header record
        for (RecordWrapper rw : objList) {
            if (headerIdsToDelete.contains(rw.obj.Id)) {
                rw.resetHeaderId();
            }
        }
    }

    //3. Update Source Recurring Records
    private Set<Id> updateRecurringRecords() {
        List<SObject> recurringRecords = new List<SObject>();
        for (RecordWrapper rw : objList) {
            // headers and lines were both saved synchronously.
            // it is possible a header can be saved in DB but lines will be processed asynchronously later.
            // in that case the recurring record will be updated asynchronously as well.
            if (rw.isHeaderRecordSavedInDB() && getLineProcessingMode(rw) == ProcessingMode.SYNC) {
                recurringRecords.add(rw.rObj);
            }
        }

        List<SObject> recurringRecordsToUpdate = (List<SObject>) Type.forName(
            'List<' + sourceRecurringRecordType + '>'
        ).newInstance();
        recurringRecordsToUpdate.addAll(recurringRecords);

        Set<Id> failedRecurringIds = new Set<Id>();
        for (Database.SaveResult saveResult : SFDCSecurityUtils.updateCheckCRUDAndFLS(recurringRecordsToUpdate, checkFieldsOnSourceRecurringRecord, false)) {
            if (!saveResult.isSuccess()) {
                failedRecurringIds.add(saveResult.getId());
                resultStatusMap.get(saveResult.getId()).errors.add(
                    new RecurringRecordErrorResult(StatusCode.EXTERNAL_ERROR, saveResult.getErrors())
                );
            }
        }

        return failedRecurringIds;
    }

    //3.1 If Recurring record(s) failed during update DML we must remove all created records
    private void rollbackIfRecurringUpdateFailed(Set<Id> failedRecurringIds) {
        List<SObject> headerRecordsToDelete = new List<SObject>();
        for (RecordWrapper rw : objList) {
            if (failedRecurringIds.contains(rw.rObj.Id) && rw.isHeaderRecordSavedInDB()) {
                headerRecordsToDelete.add(rw.obj);
                rw.unbindLinesFromHeader(lineToHeaderRelationshipField);
            }
        }
        //remove all Headers sourced from Recurring record(s) failed during update DML
        SFDCSecurityUtils.deleteProxy(headerRecordsToDelete);
    }

    protected void clearResultErrors() {
        for (RecurringRecordResult result : resultStatusMap.values()) {
            result.errors = new List<AbstractSourceFromRecurring.RecurringRecordErrorResult>();
        }
    }

    protected void doDMLs() {
        doDMLs(true, false);
    }

    protected void doDMLs(boolean hasLines, boolean wrapperErrorHandling) {
        try {
             insertHeaderRecords(wrapperErrorHandling);
   
            if(hasLines){
                Map<Id, List<Database.Error>> headerIdToErrorsOnLine = insertLines();
                if (!headerIdToErrorsOnLine.isEmpty()) {
                    rollbackIfLineInsertFailed(headerIdToErrorsOnLine);
                }
            }
           
            Set<Id> failedRecurringIds = updateRecurringRecords();
            if (!failedRecurringIds.isEmpty()) {
                rollbackIfRecurringUpdateFailed(failedRecurringIds);
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    @TestVisible
    protected Date setNextDateByFrequency(String frequency, Date oldDate) {
        Date result;
        if (frequency == 'Weekly') {
            result = getNextSourceDate(oldDate, 7);
        }
        if (frequency == 'Bi-weekly') {
            result = getNextSourceDate(oldDate, 14);
        }
        if (frequency == 'Monthly') {
            result = getNextSourceDate(oldDate, 1);
        }
        else if (frequency == 'Quarterly') {
            result = getNextSourceDate(oldDate, 3);
        }
        else if (frequency == 'Semi-annual') {
            result = getNextSourceDate(oldDate, 6);
        }
        else if (frequency == 'Annual') {
            result = getNextSourceDate(oldDate, 12);
        }
        return result;
    }

    @TestVisible
    protected Date setNextDateByFrequencyAndInteger(string frequency, Date oldDate, Integer frequencyNum){
        Date result;
        //Days, Weeks, Months, Years
        if (frequency == 'Days') {
            result = oldDate.addDays(frequencyNum); 
        }
        if (frequency == 'Weeks') {
            result = oldDate.addDays(frequencyNum * 7);
        }
        if (frequency == 'Months') {
            result = oldDate.addMonths(frequencyNum);
        }
        else if (frequency == 'Years') {
            result = oldDate.addYears(frequencyNum);
        }

        return result;
    }

    @TestVisible
    private Date getNextSourceDate(Date theDate, Integer frequency) {
        Integer year = theDate.year();
        Integer month = theDate.month();
        Integer day = theDate.day();
        Date retDate;

        switch on frequency {
            when 7 {
                retDate = theDate.addDays(frequency);
            }
            when 14 {
                retDate = theDate.addDays(frequency);
            }
            when else {
                if ((month == 1 || month == 3 || month == 5 || month == 7 || month == 10 || month == 12) && day == 31) {
                    retDate = getLastDayOfMonth(theDate.addMonths(frequency));
                }
                else if ((month == 2 && day == 28) || (month == 2 && Date.isLeapYear(year) && day == 29)) {
                    retDate = getLastDayOfMonth(theDate.addMonths(frequency));
                }
                else if ((month == 4 || month == 6 || month == 8 || month == 9 || month == 11) && day == 30) {
                    retDate = getLastDayOfMonth(theDate.addMonths(frequency));
                }
                else {
                    retDate = theDate.addMonths(frequency);
                }
            }
        }

        return retDate;
    }

    private Date getLastDayOfMonth(Date theDate) {
        return Date.newInstance(theDate.year(), theDate.month(), Date.daysInMonth(theDate.year(), theDate.month()));
    }

    protected Map<Date, Accounting_Period__c> getPeriodsByDates(Set<Date> dates) {
        Map<Date, Accounting_Period__c> periodsMap = new Map<Date, Accounting_Period__c>();
        //Query for accounting periods
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
        for (Date payableDate : dates) {
            Accounting_Period__c period = acctPeriodHandler.getAccountingPeriodByStartDate(payableDate);
            if (period != NULL) {
                periodsMap.put(period.Start_Date__c, period);
            }
        }
        return periodsMap;
    }

    protected void setFieldsOnRecurringRecords(String lastDate, String nextDate, String frequency) {
        for (RecordWrapper rw : objList) {
            // skip updates for records that are being processed asynchronously
            if (getLineProcessingMode(rw) == ProcessingMode.ASYNC) {
                continue;
            }
            rw.rObj.put(lastDate, (Date) rw.rObj.get(nextDate));

            if (rw.rObj.get(frequency) == NULL) {
                rw.rObj.put(frequency, 'Monthly');
            }

            rw.rObj.put(nextDate, setNextDateByFrequency(
                (String) rw.rObj.get(frequency),
                (Date) rw.rObj.get(nextDate)
            ));
        }
    }

    //Called from new recurring methods that include a frequency integer and Occurrences
    protected void setFieldsOnRecurringRecords(RecurringRecordSchedulingWrapper schedulingFields){
        try {
            for (RecordWrapper rw : objList) {
                if (rw.rObj.get(schedulingFields.frequency) == NULL) {
                    rw.rObj.put(schedulingFields.frequency, 'Monthly');
                }

                Date lastDate = (Date)rw.rObj.get(schedulingFields.nextCreateDate);
                rw.rObj.put(schedulingFields.previousCreateDate, lastDate);
                rw.rObj.put(schedulingFields.previousDueDate, (Date)rw.rObj.get(schedulingFields.nextDueDate));

                Date nextDate = setNextDateByFrequencyAndInteger(
                    (String) rw.rObj.get(schedulingFields.frequency),
                    (Date) rw.rObj.get(schedulingFields.nextCreateDate),
                    (Integer) Integer.valueOf(rw.rObj.get(schedulingFields.frequencyNum)));
                rw.rObj.put(schedulingFields.nextCreateDate, nextDate);

                if (rw.rObj.get(schedulingFields.originalCreateDate) != NULL && rw.rObj.get(schedulingFields.originalDueDate) != NULL) {
                    Date createDate = (Date)rw.rObj.get(schedulingFields.originalCreateDate);
                    Date dueDate = (Date)rw.rObj.get(schedulingFields.originalDueDate);
                    rw.rObj.put(schedulingFields.nextDueDate, nextDate.addDays(createDate.daysBetween(dueDate)));
                    
                    if(rw.rObj.get(schedulingFields.previousDueDate) == null){
                        rw.rObj.put(schedulingFields.previousDueDate, lastDate.addDays(createDate.daysBetween(dueDate)));
                    }
                }        

                if (rw.rObj.get(schedulingFields.occurrence) == NULL) {
                    rw.rObj.put(schedulingFields.occurrence, 1);
                }else{
                    rw.rObj.put(schedulingFields.occurrence, (Integer)Integer.valueOf(rw.rObj.get(schedulingFields.occurrence)) + 1);
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }
    }

    protected List<SObject> getHeaderAndLineRecordsExistedInDB() {
        List<SObject> result = new List<SObject>();
        for (RecordWrapper rw : objList) {
            // filter out 
            //      - any headers which were not created
            //      - any headers which were created synchronously, but are still pending async line processing
            if (rw.isHeaderRecordSavedInDB() && getLineProcessingMode(rw) == ProcessingMode.SYNC) {
                result.add(rw.obj);
            }
        }
        return result;
    }

    protected List<SObject> getHeaderRecordsExistedInDB() {
        List<SObject> result = new List<SObject>();
        for (RecordWrapper rw : objList) {
            if (rw.isHeaderRecordSavedInDB()) {
                result.add(rw.obj);
            }
        }
        return result;
    }

    protected void populateSuccessResults() {
        synchronousRecordsCount = 0;
        for (RecordWrapper rw : objList) {
            // add success messages only for headers and lines that were saved synchronously.
            // the rest will be handled asynchronously and reported via AJR
            if (rw.isHeaderRecordSavedInDB() && getLineProcessingMode(rw) == ProcessingMode.SYNC) {
                synchronousRecordsCount++;
                resultStatusMap.get(rw.rObj.Id).errors.add(
                    new RecurringRecordErrorResult(
                        StatusCode.CREATED,
                        String.format(
                            CREATE_SUCCESS_MESSAGE,
                            new List<String>{resultStatusMap.get(rw.rObj.Id).objectName}
                        )
                    )
                );
            }
        }
    }

    protected void handleExternalExceptionAndRollBack(Exception ex) {
        for (RecordWrapper rw : objList) {
            resultStatusMap.get(rw.rObj.Id).errors.add(
                new RecurringRecordErrorResult(StatusCode.EXTERNAL_ERROR, ex.getMessage())
            );

            rw.obj.Id = NULL;
            rw.unbindLinesFromHeader(lineToHeaderRelationshipField);
        }
    }

    protected Map<Id, List<SObject>> getLinesMap(List<SObject> rObjLineList, SObjectField sourceField) {
        rSObjectLinesCount = rObjLineList.size();
        Map<Id, List<SObject>> result = new Map<Id, List<SObject>>();
        for (SObject line : rObjLineList) {
            if (!result.containsKey((Id) line.get(sourceField))) {
                result.put((Id) line.get(sourceField), new List<SObject> {line});
            }
            else {
                result.get((Id) line.get(sourceField)).add(line);
            }
        }
        return result;
    }

    public enum StatusCode {
        ACCOUNTING_PERIOD_ERROR,
        CREATED,
        EXTERNAL_ERROR,
        POST_ERROR,
        USER_ERROR
    }

    public with sharing class RecurringRecordResult {
        public String objectName {get; private set;}
        public String recurringRecordId {get; private set;}
        public List<RecurringRecordErrorResult> errors {get; set;}
        public Integer totalRecords {get; set;}

        public RecurringRecordResult(String objectName, String recurringRecordId) {
            this.objectName = objectName;
            this.recurringRecordId = recurringRecordId;
            this.errors = new List<RecurringRecordErrorResult>();
            totalRecords = 0;
        }

        public Integer getSuccessRecordsCount() {
            Integer result = 0;
            for (RecurringRecordErrorResult err : errors) {
                if (err.statusCode == StatusCode.CREATED) {
                    result += 1;
                }
            }
            return result;
        }

        public Integer getPostedRecordsCount() {
            Integer result = getSuccessRecordsCount();
            for (RecurringRecordErrorResult err : errors) {
                if (err.statusCode == StatusCode.POST_ERROR) {
                    result -= 1;
                }
            }
            return result;
        }

        public Integer getFailedRecordsCount() {
            return totalRecords - getSuccessRecordsCount();
        }

        public List<RecurringRecordErrorResult> getFailedRecords() {
            List<RecurringRecordErrorResult> result = new List<RecurringRecordErrorResult>();
            for (RecurringRecordErrorResult err : errors) {
                if (err.statusCode != AbstractSourceFromRecurring.StatusCode.CREATED
                        && err.statusCode != AbstractSourceFromRecurring.StatusCode.POST_ERROR) {

                    result.add(err);
                }
            }
            return result;
        }

    }

    public with sharing class RecurringRecordErrorResult {
        public StatusCode statusCode {get; private set;}
        public String message {get; private set;}

        public RecurringRecordErrorResult(StatusCode statusCode, String message) {
            this.statusCode = statusCode;
            this.message = message;
        }

        public RecurringRecordErrorResult(StatusCode statusCode, List<Database.Error> errors) {
            this.statusCode = statusCode;
            this.message = '';
            Integer numberOfMessage = 1;
            for (Database.Error error : errors) {
                this.message += errors.size() > 1 ? String.valueOf(numberOfMessage) + '. ' + error.getMessage() + '   ' : error.getMessage();
                numberOfMessage++;
            }
        }
    }

    public enum ProcessingMode { SYNC, ASYNC }

    /**
     * determines how to process the header record - sync/async
     */
    protected ProcessingMode getHeaderProcessingMode(RecordWrapper rw) {
        if (isLDOAsyncProcessingEnabled) {
            // the header record has been modified so that it
            // diffres from the source recurring record
            if (rw.isHeaderDirty()) {
                return ProcessingMode.SYNC;
            // only one line is present
            } else if (rw.recurringLineCount == 1) {
                return ProcessingMode.SYNC;
            // the header record has not been modified
            } else {
                return ProcessingMode.ASYNC;
            }
        }
        return ProcessingMode.SYNC;
    }

    /**
     * determines how to process the line records - sync/async
     */
    protected ProcessingMode getLineProcessingMode(RecordWrapper rw) {
        if (isLDOAsyncProcessingEnabled) {
            // there is only one line
            if (rw.recurringLineCount == 1) {
                return ProcessingMode.SYNC;
            // there is more or less than one line
            } else {
                return ProcessingMode.ASYNC;
            }
        }
        return ProcessingMode.SYNC;
    }

    public with sharing abstract class RecordWrapper {
        public SObject rObj {get; set;}
        public SObject obj {get; set;}
        public Decimal total {get; set;}
        public Integer recurringLineCount {get; set;}
        public List<SObject> objLines {get; set;}
        public Boolean hasError {get; set;}
        public String errorMsg {get; set;}


        public RecordWrapper(SObject rObj, SObject obj, Decimal total) {
            this.rObj = rObj;
            this.obj = obj;
            this.total = total;
            this.objLines = new List<SObject>();
        }

        public abstract Boolean isHeaderDirty();

        public Boolean isHeaderRecordSavedInDB() {
            return obj.Id != NULL;
        }

        public void resetHeaderId() {
            this.obj.Id = NULL;
        }

        public void bindLinesWithHeader(SObjectField masterDetailRelationshipField) {
            if (isHeaderRecordSavedInDB()) {
                for (SObject line : objLines) {
                    line.put(masterDetailRelationshipField, obj.Id);
                }
            }
        }

        public void unbindLinesFromHeader(SObjectField masterDetailRelationshipField) {
            for (SObject line : objLines) {
                line.put(masterDetailRelationshipField, NULL);
            }
        }
    }

    public with sharing class RecurringRecordSchedulingWrapper{
        public String originalCreateDate;
        public String previousCreateDate;
        public String nextCreateDate;

        public String originalDueDate;
        public String previousDueDate;
        public String nextDueDate;
        
        public String frequency;
        public String frequencyNum;
        public String occurrence;
        
    }

}