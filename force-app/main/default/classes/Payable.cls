public with sharing class Payable {
    private static final Integer SOQL_RECORD_LIMIT = 10000;
    public static final String NO_INPUT_DATA = Label.ERR_NO_INPUT_DATA;
    
    @TestVisible
    private static final String INVALID_RECORD_OR_ID = Label.ERR_INVALID_RECORD_OR_ID;

    @TestVisible
    private static final String INVALID_QUERY_FIELD = Label.ERR_INVALID_QUERY_FIELD;

    @TestVisible
    private APIServiceContext.APIServiceEntry serviceEntry;
    private List<PayableModel> payableModels;
    private List<CashApplication> cashApplications;
    private List<Id> payableIds;
    private ServiceResult serviceResult;
    private Integer maxRows;

    public enum StatusCode {NO_INPUT_DATA, INVALID_RECORD_OR_ID}

    public class PayableException extends Exception {}

    //========================================================================================
    //================= CLASS CONSTRUCTORS ===================================================
    //========================================================================================

    public Payable() {
        this.serviceEntry = new APIServiceContext.APIServiceEntry();
        this.payableModels = new List<PayableModel>();
        this.cashApplications = new List<CashApplication>();        
    }

    public Payable(Integer maxRows) {
        this();
        this.maxRows = maxRows;
    }

    public Payable(List<PayableModel> models) {
        this();
        this.payableModels = models;
        if (this.payableModels.isEmpty()) {
            throw new PayableException(NO_INPUT_DATA);
        }
    }

    public Payable(PayableModel model) {
        this();
        if (model != NULL) {
            this.payableModels = new List<PayableModel>{model};
        }
        if (this.payableModels.isEmpty()) {
            throw new PayableException(NO_INPUT_DATA);
        }
    }

    public Payable(List<Id> payableIds) {
        this();
        this.payableIds = payableIds;
    }

    public Payable(Id payableId) {
        this(new List<Id>{payableId});
    }

    public void setServiceEntry(APIServiceContext.APIServiceEntry value) {
        this.serviceEntry = value;
    }

    public APIServiceContext.APIServiceEntry getServiceEntry() {
        return this.serviceEntry;
    }

    //========================================================================================
    //================= GLOBAL ENTRY POINTS ==================================================
    //========================================================================================
    public static ServiceResult create(PayableModel model) {
        ServiceResult sr;
        try {
            Payable payableServiceController = new Payable(model);
            sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);

            if (sr.isSuccess) {
                sr = payableServiceController.createImpl();
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }

        return sr;
    }

    public static ServiceResult create(List<PayableModel> models) {
        ServiceResult sr;
        try {
            Payable payableServiceController = new Payable(models);
            sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);

            if (sr.isSuccess) {
                sr = payableServiceController.createImpl();
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(NULL, ex.getTypeName(), ex.getMessage());
        }
        return sr;
    }

    public static ServiceResult post(Id payableId) {
        ServiceResult sr;
        try {
            Payable payableServiceController = new Payable(payableId);
            sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);

            if (sr.isSuccess) {
                List<ServiceResult> postServiceResults = payableServiceController.postImpl();
                sr = (!postServiceResults.isEmpty()) ? postServiceResults.get(0) : new ServiceResult(payableId, false);
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(payableId, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});            
        }

        return sr;
    }

    public static List<ServiceResult> post(List<Id> payableIds) {
        List<ServiceResult> postServiceResults;
        try {
            Payable payableServiceController = new Payable(payableIds);
            ServiceResult sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);

            if (sr.isSuccess) {
                postServiceResults = payableServiceController.postImpl();
            }
        }
        catch (Exception ex) {
            postServiceResults = new List<ServiceResult>();
            for (Id payableId : payableIds) {
                postServiceResults.add(
                    new ServiceResult(
                        payableId,
                        false,
                        new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())}
                    )
                );
            }
        }
        return postServiceResults;
    }

    public static ServiceResult unpost(Id payableId) {
        ServiceResult sr;
        try {
            Payable payableServiceController = new Payable(payableId);
            sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);

            if (sr.isSuccess) {
                List<ServiceResult> postServiceResults = payableServiceController.unpostImpl();
                sr = (!postServiceResults.isEmpty()) ? postServiceResults.get(0) : new ServiceResult(payableId, false);
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(payableId, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});
        }

        return sr;
    }

    public static List<ServiceResult> unpost(List<Id> payableIds) {
        List<ServiceResult> unpostServiceResults;
        try {
            Payable payableServiceController = new Payable(payableIds);
            ServiceResult sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);

            if (sr.isSuccess) {
                unpostServiceResults = payableServiceController.unpostImpl();
            }
        }
        catch (Exception ex) {
            unpostServiceResults = new List<ServiceResult>();
            for (Id payableId : payableIds) {
                unpostServiceResults.add(
                    new ServiceResult(
                        payableId,
                        false,
                        new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())}
                    )
                );
            }
        }

        return unpostServiceResults;
    }

    public static PayableModel retrieve(Id payableId) {
        PayableModel pm;
        try {
            Payable payableServiceController = new Payable(payableId);
            ServiceResult sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);
            if (sr.isSuccess) {
                pm = payableServiceController.retrieveImpl();
            }
        }
        catch (Exception ex) {
            pm = new PayableModel();
        }

        return pm;
    }

    public static List<PayableModel> retrieve(PayableFilter filter, List<String> fieldsToReturn) {
        return retrieve(filter, fieldsToReturn, SOQL_RECORD_LIMIT);
    }

    public static List<PayableModel> retrieve(PayableFilter filter, List<String> fieldsToReturn, Integer maxRows) {
        List<PayableModel> pms;
        try {
            Payable payableServiceController = new Payable(maxRows);
            ServiceResult sr = APIServiceContext.validateServiceContext(payableServiceController.serviceEntry);
            if (sr.isSuccess) {
                pms = payableServiceController.retrieveImpl(filter, fieldsToReturn);                
            }
        }
        catch (SOQLBuilder.InvalidFieldException exBadField) {
            throw new PayableException(exBadField.getMessage());
        }
        catch (PayableException payEx) {
            throw new PayableException(payEx.getMessage());
        }
        catch (Exception ex) {
            pms = new List<PayableModel>();            
        }

        return pms;
    }

    //========================================================================================
    //================= IMPLEMENTATION INSTANCE METHODS ======================================
    //========================================================================================
    private ServiceResult createImpl() {
        List<ServiceResult> payableServiceResults = new List<ServiceResult>();
        Savepoint sp = Database.setSavepoint();
        try {
            if (!this.payableModels.isEmpty()) {
                //insert Payables first
                List<Account_Payable__c> PayablesToInsert = new List<Account_Payable__c>();
                for (PayableModel payableModel : this.payableModels) {
                    ServiceResult sr = validatePayableModel(payableModel);
                    if (sr.isSuccess) {
                        payablesToInsert.add(payableModel.payable);
                    }
                    else {
                        payableServiceResults.add(sr);
                    }
                }

                for (Database.SaveResult saveResult : SFDCSecurityUtils.insertCheckCRUDAndFLS(payablesToInsert, new List<String>(), false)) {
                    if (saveResult.isSuccess()) {
                        payableServiceResults.add(new ServiceResult(saveResult.getId(), true));
                    }
                    else {
                        List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                        for (Database.Error dbError : saveResult.getErrors()) {
                            ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                            errors.add(err);
                        }
                        payableServiceResults.add(new ServiceResult(NULL, false, errors));
                    }
                }
                //populate Payable Id on related Payable Lines and save them
                List<Account_Payable_Line__c> linesToInsert = new List<Account_Payable_Line__c>();
                for (PayableModel payableModel : this.payableModels) {
                    if (isSavedInDataBase(payableModel.payable) && isNotNullAndNotEmpty(payableModel.payableLines)) {
                        for (Account_Payable_Line__c line : payableModel.payableLines) {
                            line.Account_Payable__c = payableModel.payable.Id;
                            linesToInsert.add(line);
                        }
                    }
                }
                //save Payable Lines
                SFDCSecurityUtils.insertCheckCRUDAndFLS(linesToInsert, new List<String>());
                this.serviceResult = processCreatePayableSuccessResults(payableServiceResults);
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            this.serviceResult = new ServiceResult(NULL, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});
        }
        return this.serviceResult;
    }

    private List<ServiceResult> postImpl() {
        AbstractPostHandler postHandler = new AccountPayablePostHandler();
        List<PostResult> postResults = postHandler.post(this.payableIds);
        return transformPostResults(postResults);        
    }

    private List<ServiceResult> unpostImpl() {
        AbstractPostHandler postHandler = new AccountPayablePostHandler();
        List<PostResult> postResults = postHandler.unpost(this.payableIds);
        return transformPostResults(postResults);
    }

    private PayableModel retrieveImpl() {
        this.payableModels.add(new PayableModel());
        try {
            if (!this.payableIds.isEmpty() && FinancialSuiteUtils.isValidId(this.payableIds[0], Account_Payable__c.SObjectType)) {
                this.payableModels[0].payableLines = new List<Account_Payable_Line__c>();
                for (Account_Payable__c payable : getAccountPayablesByIdWithLines(new Set<Id> {this.payableIds[0]})) {
                    this.payableModels[0].payable = payable;
                    if (payable.Project_Account_Payable_Lines__r != NULL) {
                        this.payableModels[0].payableLines = payable.Project_Account_Payable_Lines__r;
                    }
                }
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return this.payableModels[0];
    }


    private List<PayableModel> retrieveImpl(PayableFilter filter, List<String> fieldsToReturn) {
        Cash_Disbursement__c cd;
        map<Id, CashApplication> cashApplicationMap = new Map<Id, CashApplication>();
        try {
            if (filter.cashDisbursementId != NULL) {
                if (FinancialSuiteUtils.isValidId(filter.cashDisbursementId, Cash_Disbursement__c.SObjectType)) {
                    cd = getCashDisbursementById(new Set<Id>{filter.cashDisbursementId})[0];         
                    for (CashApplication ca : CashDisbursement.retrieveAppliedDisbursements(filter.cashDisbursementId).cashApplications) {
                        cashApplicationMap.put(ca.appliedItemId, ca);
                    }
                }
            }

            //define fields to query
            List<String> queryFields = new List<String>{'Id', 'Name'};
            if (fieldsToReturn != NULL) {
                for (String field : fieldsToReturn) {
                    if (field != NULL && field != '') {                        
                        queryFields.add(field);                        
                    } else {
                        throw new PayableException(INVALID_QUERY_FIELD);
                    }
                }
            }

            for (Account_Payable__c payable : getAccountPayablesByFilterCriteria(cd, this.maxRows, filter, queryFields, cashApplicationMap.keySet())) {
                PayableModel pm = new PayableModel();
                pm.payable = payable;
                if (payable.Project_Account_Payable_Lines__r != NULL) {
                    pm.payableLines = payable.Project_Account_Payable_Lines__r;
                }
                this.payableModels.add(pm);                                
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return this.payableModels;
    }

    //======================================================================================
    //======================= DATABASE METHODS =============================================
    //======================================================================================

    private static List<Cash_Disbursement__c> getCashDisbursementById(Set<Id> ids) {
        List<Cash_Disbursement__c> result;
        List<String> queryFields = new List<String>{
            'Id', 
            'Name', 
            'balance__c', 
            'Accounting_Period__c', 
            'Ledger__c', 
            'Payee_Id__c'
        };
        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        result = (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
        return result;
    }

    private static List<Account_Payable__c> getAccountPayablesByIdWithLines(Set<Id> ids) {
        List<Account_Payable__c> result;
        List<String> queryFields = new List<String>{
            'Id'
        };

        String subQueryRelationshipName =  GlobalVariables.PACKAGE_QUALIFIER + 'Project_Account_Payable_Lines__r';
        List<String> subQueryFields = new List<String>{
            'Id'
        };

        String queryCondition = 'Id IN :ids';
        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, true)
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(subQueryFields);
        
        result = (List<Account_Payable__c>) Database.query(theQuery.toSOQL());
        return result;
    }

    private static List<Account_Payable__c> getAccountPayablesByFilterCriteria(Cash_Disbursement__c cashDisbursement, 
                                                Integer maxResults, 
                                                PayableFilter filter,
                                                List<string> queryFields,
                                                Set<Id> appliedPayableIds) {
        
        String payableNumberValue = '%' + filter.payableNumber + '%';        
        String payeeReferenceValue = '%' + filter.payeeReference + '%';        
        String currencyIsoCode;
        String ledgerId;
        Boolean isEqualLegacyLedger;
        if (cashDisbursement != NULL) {
           ledgerId = cashDisbursement.Ledger__c;
           isEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(ledgerId);
            
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                currencyIsoCode = (String) cashDisbursement.get('CurrencyIsoCode');
            }
        }
        
        //set query condition
        String queryCondition =
            'Type__c = \'Invoice\' ' +                
                (
                    (MultiCurrencyHandler.isMultiCurrencyEnabled == true)
                        ?
                        ' AND CurrencyIsoCode = :currencyIsoCode '                            
                        :
                        ' '
                );
        if (!string.isEmpty(ledgerId)) {
            queryCondition += 'AND (Ledger__c = :ledgerId' +
            (isEqualLegacyLedger ? ' OR Ledger__c = NULL) ' : ' ') +
            (!isEqualLegacyLedger ? ') ' : ' ');
        }
        if (!string.isEmpty(filter.payeeId)) {
            String payeeId = filter.payeeId;
            queryCondition += ' AND (Vendor__c = :payeeId OR Employee__c = :payeeId OR Contact__c = :payeeId)';

        }        
        if (filter.postingStatus != 'All') {
            String postingStatus = filter.postingStatus;
            queryCondition += ' AND Status__c = :postingStatus';
        }
        if (!string.isEmpty(filter.payableNumber)) {
            queryCondition += ' AND (Proprietary_payable_Number__c like :payableNumberValue OR Name like :payableNumberValue)'; 
        }
        if (!string.isEmpty(filter.payeeReference)) {
            queryCondition += ' AND Payee_Reference__c like :payeeReferenceValue'; 
        }
        if (filter.issueDateStart != NULL) {
            Date issueDateStart = filter.issueDateStart;
            queryCondition += ' AND Date__c >= :issueDateStart';
        }
        if (filter.issueDateEnd != NULL) {
            Date issueDateEnd = filter.issueDateEnd;
            queryCondition += ' AND Date__c <= :issueDateEnd';
        }
        if (filter.dueDateStart != NULL) {
            Date dueDateStart = filter.dueDateStart;
            queryCondition += ' AND Due_Date__c >= :dueDateStart';
        }
        if (filter.dueDateEnd != NULL) {
            Date dueDateEnd = filter.dueDateEnd;
            queryCondition += ' AND Due_Date__c <= :dueDateEnd';
        }
        if (filter.payableAmountStart != NULL) {
            Decimal payableAmountStart = filter.payableAmountStart;
            queryCondition += ' AND Total__c >= :payableAmountStart';
        }
        if (filter.payableAmountEnd != NULL) {
            Decimal payableAmountEnd = filter.payableAmountEnd;
            queryCondition += ' AND Total__c <= :payableAmountEnd';
        }
        if (filter.includePaidPayables != NULL && !filter.includePaidPayables) {
            queryCondition += ' AND ((Payment_Status__c != \'Paid\' AND Balance_Minus_Discount__c > 0) OR Id IN :appliedPayableIds)';
        }
        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(maxResults);
        return Database.query(theQuery.toSOQL());
    }

    //======================================================================================
    //======================= UTILITY METHODS ==============================================
    //======================================================================================

    private ServiceResult processCreatePayableSuccessResults(List<ServiceResult> sResults) {
        ServiceResult processedServiceResult;
        List<ServiceResult> payableResults = new List<ServiceResult>();
        Set<Id> createdPayableIds = new Set<Id>();
        for (ServiceResult sr : sResults) {
            if (sr.data != NULL) {
                createdPayableIds.add(sr.data);
            }
            else {
                payableResults.add(sr);
            }
        }

        if (!createdPayableIds.isEmpty()) {
            for (Account_Payable__c createdPayable : getAccountPayablesByIdWithLines(createdPayableIds)) {
                List<ServiceResult> payableLineResults = new List<ServiceResult>();
                for (Account_Payable_Line__c payableLine : createdPayable.Project_Account_Payable_Lines__r) {
                    payableLineResults.add(new ServiceResult(payableLine.Id, true));
                }
                payableResults.add(new ServiceResult(createdPayable.Id, true, NULL, payableLineResults));
            }
        }
        if (payableResults.size() == 1) {
            processedServiceResult = payableResults[0];
        }
        else if (payableResults.size() > 1) {
            processedServiceResult = new ServiceResult(NULL, true, NULL, payableResults);
        }
        return processedServiceResult;
    }

    private Boolean isNotNullAndNotEmpty(List<SObject> collection) {
        return collection != NULL && !collection.isEmpty();
    }

    private Boolean isSavedInDataBase(SObject record) {
        return record != NULL && record.Id != NULL;
    }

    private ServiceResult validatePayableModel(PayableModel model) {
        ServiceResult sr = new ServiceResult(NULL, true);
        ServiceResult.Error error = new ServiceResult.Error();
        if (model.payable == NULL) {
            error.detail = INVALID_RECORD_OR_ID;
            error.code = StatusCode.INVALID_RECORD_OR_ID.name();
        }
        if (error.detail != NULL) {
            sr = new ServiceResult(NULL, false, new List<ServiceResult.Error>{error});
        }
        return sr;
    }

    private List<ServiceResult> transformPostResults(List<PostResult> postResults) {
        List<ServiceResult> results = new List<ServiceResult>();
        for (PostResult pr : postResults) {
            results.add(transformPostResult(pr));
        }
        return results;
    }

    private ServiceResult transformPostResult(PostResult pr) {
        ServiceResult sr = new ServiceResult();
        sr.isSuccess = pr.isSuccess;
        sr.data = pr.id;
        if (pr.errors != NULL) {
            sr.errors = transformPostErrorResults(pr.errors);
        }
        return sr;
    }

    private List<ServiceResult.Error> transformPostErrorResults(List<PostResult.PostErrorResult> postErrResults) {
        List<ServiceResult.Error> srErrors = new List<ServiceResult.Error>();
        for (PostResult.PostErrorResult postErrResult : postErrResults) {
            srErrors.add(transformPostErrorResult(postErrResult));
        }
        return srErrors;
    }

    private ServiceResult.Error transformPostErrorResult(PostResult.PostErrorResult postErrResult) {
        ServiceResult.Error srError = new ServiceResult.Error();
        srError.id = (postErrResult.errorSource != NULL) ? postErrResult.errorSource.Id : NULL;
        srError.code = postErrResult.statusCode.name();
        srError.detail = postErrResult.message;
        return srError;
    }
}