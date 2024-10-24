public with sharing class CashDisbursement {
   
    public static final Integer CASH_DISBURSEMENT_ITEM_LIMIT = 200;

    public static final String NO_INPUT_DATA = Label.ERR_NO_INPUT_DATA;
    public static final String VOIDED_CD_ERROR = Label.COMMON_VOIDED_CD_ERROR;
    @TestVisible
    private static final String INVALID_RECORD_OR_ID = Label.ERR_INVALID_RECORD_OR_ID;
    @TestVisible
    private static final String CASH_DISBURSEMENT_BALANCE_LESS_THAN_ZERO = Label.ERR_CASH_DISBURSEMENT_BALANCE_LESS_THAN_ZERO;
    @TestVisible
    private static final String APPLIED_AMOUNT_LESS_THAN_ZERO = Label.ERR_APPLIED_AMOUNT_LESS_THAN_ZERO;
    @TestVisible
    private static final String PAYABLE_BALANCE_LESS_THAN_ZERO = Label.ERR_PAYABLE_BALANCE_LESS_THAN_ZERO;
    @TestVisible
    private static final String BATCH_JOB_IS_RUNNING = Label.INF_JOB_IS_RUNNING;
    @TestVisible
    private static final String MISSING_APPLIED_DATE = Label.ERR_INVALID_PERIOD;
    @TestVisible
    private static final String MISSING_ACCOUNTING_PERIOD = Label.ERR_PERIOD_INVALID_APPLIED_DATE;
    @TestVisible
    private static final String APPLIED_DATE_INVALID = Label.ERR_COMMON_INVALID_APPLIED_DATE;
    @TestVisible
    private static final String ACCOUNTING_PERIOD_CLOSED = Label.ERR_ACCOUNTING_PERIOD_CLOSED;
    @TestVisible
    private static final String ACCOUNTING_PERIOD_BEFORE_PAYABLE_ACCOUNTING_PERIOD = Label.ERR_PERIOD_BEFORE_PAYABLE_PERIOD;
    @TestVisible
    private static final String ACCOUNTING_PERIOD_BEFORE_CASH_DISBURSEMENT_ACCOUNTING_PERIOD = Label.ERR_PAYABLE_BEFORE_CD_PERIOD;
    @TestVisible 
    private static final String OVER_CASH_DISBURSEMENT_ITEM_LIMIT = Label.ERR_OVER_RECONCILIATION_ITEM_LIMIT;
    @TestVisible 
    private static final String CASH_DISBURSEMENT_CURRENCY_MISMATCH = Label.ERR_CASH_DISBURSEMENT_CURRENCY_MISMATCH;
    @TestVisible 
    private static final String CASH_DISBURSEMENT_LEDGER_MISMATCH = Label.ERR_CASH_DISBURSEMENT_LEDGER_MISMATCH;
    @TestVisible 
    private static final String CASH_DISBURSEMENT_PAYEE_MISMATCH = Label.ERR_CASH_DISBURSEMENT_PAYEE_MISMATCH;
    @TestVisible 
    private static final String PAYABLE_TYPE_MISMATCH = Label.ERR_PAYABLE_TYPE_MISMATCH;
    @TestVisible
    private static final String APPLIED_DATE_DOES_NOT_MATCH_ACCOUNTING_PERIOD = Label.ERR_APPLIED_DATE_DOES_NOT_MATCH_PERIOD;


    @TestVisible
    private APIServiceContext.APIServiceEntry serviceEntry;
    private Id cashDisbursementId;
    private Cash_Disbursement__c cashDisbursement;
    private List<Account_Payable__c> payables;
    private CashDisbursementApplyModel cdam;
    private ServiceResult serviceResult;

    public enum StatusCode {NO_INPUT_DATA, 
                            INVALID_RECORD_OR_ID, 
                            CASH_DISBURSEMENT_BALANCE_LESS_THAN_ZERO, 
                            APPLIED_AMOUNT_LESS_THAN_ZERO, 
                            PAYABLE_BALANCE_LESS_THAN_ZERO, 
                            MISSING_APPLIED_DATE,
                            MISSING_ACCOUNTING_PERIOD, 
                            ACCOUNTING_PERIOD_CLOSED,
                            ACCOUNTING_PERIOD_BEFORE_PAYABLE_ACCOUNTING_PERIOD,
                            ACCOUNTING_PERIOD_BEFORE_CASH_DISBURSEMENT_ACCOUNTING_PERIOD,
                            OVER_CASH_DISBURSEMENT_ITEM_LIMIT,
                            CASH_DISBURSEMENT_CURRENCY_MISMATCH,
                            CASH_DISBURSEMENT_LEDGER_MISMATCH,
                            CASH_DISBURSEMENT_PAYEE_MISMATCH,
                            PAYABLE_TYPE_MISMATCH,
                            APPLIED_DATE_DOES_NOT_MATCH_ACCOUNTING_PERIOD,
                            VOIDED_CD_ERROR,
                            DEBIT_GL_ACCOUNT_VALIDATION_ERROR_MESSAGE,
                            POSTING_IN_PROGRESS}

    public class CashDisbursementException extends Exception {}

    //========================================================================================
    //================= CLASS CONSTRUCTORS ===================+===============================
    //========================================================================================

    public CashDisbursement() {
        this.serviceEntry = new APIServiceContext.APIServiceEntry(); 
        this.cdam = new CashDisbursementApplyModel();       
    }

    public CashDisbursement(Id cashDisbursementId) {
        this();
        if (FinancialSuiteUtils.isValidId(cashDisbursementId, Cash_Disbursement__c.SObjectType)) {
            this.cashDisbursementId = cashDisbursementId;        
            this.cashDisbursement = getCashDisbursementById(new Set<Id>{cashDisbursementId})[0];
        }
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
    public static CashDisbursementApplyModel retrieveAppliedDisbursements(Id cashDisbursementId) {
        CashDisbursementApplyModel cdam;
        try {
            CashDisbursement cdServiceController = new CashDisbursement(cashDisbursementId);
            ServiceResult sr = APIServiceContext.validateServiceContext(cdServiceController.serviceEntry);
            if (sr.isSuccess) {
                cdam = cdServiceController.retrieveAppliedDisbursementsImpl();
            }
        }
        catch (Exception ex) {
            cdam = new CashDisbursementApplyModel();
        }

        return cdam;
    } 
    
    public static ServiceResult unapply(Id cashDisbursementId, List<CashApplication> cashApplications) {
        ServiceResult sr;
        try {
            CashDisbursement cdServiceController = new CashDisbursement(cashDisbursementId);
            sr = APIServiceContext.validateServiceContext(cdServiceController.serviceEntry);

            if (sr.isSuccess) {
                sr = cdServiceController.unapplyImpl(cashApplications);
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(null, ex.getTypeName(), ex.getMessage());
        }
        return sr;
    }

    public static ServiceResult apply(Id cashDisbursementId, List<CashApplication> cashApplications) {
        ServiceResult sr;
        try {
            if (FinancialSuiteUtils.isValidId(cashDisbursementId, Cash_Disbursement__c.SObjectType)) {
                CashDisbursement cdServiceController = new CashDisbursement(cashDisbursementId);
                sr = APIServiceContext.validateServiceContext(cdServiceController.serviceEntry);

                if (sr.isSuccess) {
                    sr = cdServiceController.applyImpl(cashApplications);
                }
            } else {
                sr = new ServiceResult (cashDisbursementId, statusCode.INVALID_RECORD_OR_ID.name(), INVALID_RECORD_OR_ID);
            }
        }
        catch (Exception ex) {
            sr = new ServiceResult(null, ex.getTypeName(), ex.getMessage());
        }
        return sr;
    }

    //========================================================================================
    //================= IMPLEMENTATION INSTANCE METHODS ======================================
    //========================================================================================

    private CashDisbursementApplyModel retrieveAppliedDisbursementsImpl() {
        try {
            if (FinancialSuiteUtils.isValidId(this.cashDisbursementId, Cash_Disbursement__c.SObjectType)) {                
                for (Cash_Disbursement__c cd : getCashDisbursementByIdWithAllAPDs(new Set<Id> {this.cashDisbursementId})) {
                    this.cdam.cashDisbursement = cd;
                    for (AP_Disbursement__c apd : cd.Account_Payable_Cash_Disbursements__r) {
                        CashApplication ca = new CashApplication();
                            ca.appliedItemId = apd.Account_Payable__c;
                            ca.amount = apd.Paid_Amount__c;
                            if (apd.Applied_Date__c == null) {
                                apd.Applied_Date__c = apd.Accounting_Period__r.Start_Date__c;
                            }
                            ca.appliedDate = apd.Applied_Date__c;
                            ca.accountingPeriodId = apd.Accounting_Period__c;
                            this.cdam.cashApplications.add(ca);
                    }
                }                
            }
        }
        catch (Exception ex) {
            throw ex;
        }

        return this.cdam;
    }

    private ServiceResult unapplyImpl(List<CashApplication> cashApplications) {
        List<ServiceResult> cdServiceResults = new List<ServiceResult>();
        Savepoint sp = Database.setSavepoint();
        try {
            ServiceResult srValidCD = validateCashDisbursement();
            if (srValidCD.isSuccess) {
                ServiceResult srValidInput = validateRecordCount(cashApplications);
                if (srValidInput.isSuccess) {
                    Set<Id> payableIds = new Set<Id>();
                    for (CashApplication ca : cashApplications) {
                        ServiceResult sr = validateCashApplication(ca);
                        if (sr.isSuccess) {
                            payableIds.add(ca.appliedItemId);
                        }
                        else {
                            cdServiceResults.add(sr);
                        }
                    }
                    deleteApds(getAPDsByPayable(payableIds).values(), cdServiceResults);               
                } else {
                    cdServiceResults.add(srValidInput);
                }
            } else {
                cdServiceResults.add(srValidCD);
            }
            this.serviceResult = processCDServiceResults(cdServiceResults);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            this.serviceResult = new ServiceResult(NULL, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});
        }
        return this.serviceResult;
    }

    private ServiceResult applyImpl(List<CashApplication> cashApplications) {
        List<ServiceResult> cdServiceResults = new List<ServiceResult>();
        Savepoint sp = Database.setSavepoint();
        try {
            ServiceResult srValidCD = validateCashDisbursement();
            if (srValidCD.isSuccess) {
                ServiceResult srValidInput = validateRecordCount(cashApplications);
                if (srValidInput.isSuccess) {    
                    Set<Id> payableIds = new Set<Id>();
                    for (CashApplication ca : cashApplications) {
                        ServiceResult sr = validateCashApplication(ca);
                        if (sr.isSuccess) {
                            payableIds.add(ca.appliedItemId);
                        }
                        else {
                            cdServiceResults.add(sr);
                        }
                    }
                    if (cdServiceResults.size() == 0) {                
                        Map<Id, AP_Disbursement__c> newAPDsMap = getNewAPDs(cashApplications);                
                        Map<Id, AP_Disbursement__c> existingAPDsMap = getAPDsByPayable(payableIds);
                        this.payables = getAccountPayablesById(payableIds, MultiCurrencyHandler.isMultiCurrencyEnabled);
                        
                        //validate the new APDs to see if there are any issues
                        ServiceResult srValidate = validate(existingAPDsMap, newAPDsMap);
                        if (srValidate.isSuccess) {
                            //unapply any existing apds for the passed in CashApplications
                            List<ServiceResult> deleteResults = new List<ServiceResult>();
                            ServiceResult srUnapply = deleteApds(existingAPDsMap.values(), deleteResults);
                            if (srUnapply.isSuccess) {
                                List<String> fieldsForSave = new List<String> {
                                    'Cash_Disbursement__c',
                                    'Paid_Amount__c',
                                    'Applied_Date__c',
                                    'Accounting_Period__c'
                                };
                                if (newAPDsMap.values().size() > 0) {
                                    for (Database.SaveResult saveResult : SFDCSecurityUtils.insertCheckCRUDAndFLS(newAPDsMap.values(), fieldsForSave, false)) {
                                        if (saveResult.isSuccess()) {
                                            cdServiceResults.add(new ServiceResult(saveResult.getId(), true));
                                        }
                                        else {
                                            List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                                            for (Database.Error dbError : saveResult.getErrors()) {
                                                ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                                                errors.add(err);
                                            }
                                            cdServiceResults.add(new ServiceResult(null, false, errors));
                                        }
                                    }
                                } else {
                                    cdServiceResults.add(new ServiceResult(null, true));
                                }
                            } else {
                                Database.rollback(sp);
                                cdServiceResults.add(processCDServiceResults(deleteResults));
                            }
                        } else {
                            Database.rollback(sp);
                            cdServiceResults.add(srValidate);
                        }
                    }
                } else {
                    cdServiceResults.add(srValidInput);
                }
            } else {
                cdServiceResults.add(srValidCD);
            }
            this.serviceResult = processCDServiceResults(cdServiceResults);
        }
        catch (Exception ex) {
            Database.rollback(sp);
            this.serviceResult = new ServiceResult(null, false, new List<ServiceResult.Error>{new ServiceResult.Error(ex.getMessage())});
        }
        return this.serviceResult;
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
            'Source__c',
            'Debit_GL_Account__c',
            'Payment_Status__c',
            'Ledger__c', 
            'Payee__c',
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

    private static List<Cash_Disbursement__c> getCashDisbursementByIdWithAllAPDs(Set<Id> ids) {
        List<Cash_Disbursement__c> result;
        List<String> queryFields = new List<String>{
            'Id', 
            'Name', 
            'Debit_GL_Account__c'
        };

        String subQueryRelationshipName = GlobalVariables.PACKAGE_QUALIFIER  + 'Account_Payable_Cash_Disbursements__r';
        List<String> subQueryFields = new List<String>{
            'Id', 
            'Account_Payable__c', 
            'Paid_Amount__c', 
            'Applied_Date__c', 
            'Accounting_Period__c'
        };

        String queryCondition = 'Id IN :ids';
        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, true)
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(subQueryFields);
        
        result = (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
        return result;
    }

    private static List<AP_Disbursement__c> getApDisbursementsByAccountPayableId(Set<Id> payableIds) {
        List<AP_Disbursement__c> result;
        List<String> queryFields = new List<String>{
            'Id', 
            'Name', 
            'Cash_Disbursement__c', 
            'Account_Payable__c', 
            'Paid_Amount__c',
            'Accounting_Period__c',
            'Status__c'
        };

        String queryCondition = 'Account_Payable__c IN :payableIds';
        SOQLBuilder theQuery = new SOQLBuilder(AP_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        
        result = (List<AP_Disbursement__c>) Database.query(theQuery.toSOQL());
        return result;
    }

    private static List<Account_Payable__c> getAccountPayablesById(Set<Id> ids, Boolean isMultiCurrencyEnabled) {
        List<Account_Payable__c> result;
        List<String> queryFields = new List<String>{
            'Id', 
            'Name', 
            'Ledger__c', 
            'Accounting_Period__c', 
            'Type__c', 
            'Payee__c',
            'Payee_Id__c',
            'LastModifieddate', 
            'Balance_Minus_Discount__c',
            'Proprietary_Payable_Number__c'
        };

        if (isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id IN :ids';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()    
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        result = (List<Account_Payable__c>) Database.query(theQuery.toSOQL());
        return result;
    }

    //======================================================================================
    //======================= UTILITY METHODS ==============================================
    //======================================================================================

    private ServiceResult processCDServiceResults(List<ServiceResult> sResults) {
        ServiceResult processedServiceResult;
        List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
        Boolean isSuccess = true;
        List<ServiceResult> processedResults = new List<ServiceResult>();
        Set<Id> processedIds = new Set<Id>();
        for (ServiceResult sr : sResults) {
            processedResults.add(sr); 
            if (!sr.isSuccess) {
                isSuccess = false;
                errors.addAll(sr.errors);
            }           
        }

        if (processedResults.size() == 1) {
            processedServiceResult = processedResults[0];
        }
        else if (processedResults.size() > 1) {
            processedServiceResult = new ServiceResult(NULL, isSuccess, errors, processedResults);
        }
        return processedServiceResult;
    }

    private Map<Id, AP_Disbursement__c> getAPDsByPayable(Set<Id> payableIds) {
        Map<Id, AP_Disbursement__c> apdsByPayable = new Map<Id, AP_Disbursement__c>();
        for (AP_Disbursement__c apd : getApDisbursementsByAccountPayableId(payableIds)) {
            if (apd.Cash_Disbursement__c == this.cashDisbursementId) {
                apdsByPayable.put(apd.Account_Payable__c, apd);
            }
        }
        return apdsByPayable;
    }

    private ServiceResult deleteApds(List<AP_Disbursement__c> apdsToDelete, List<ServiceResult> cdServiceResults) {
        ServiceResult sr = new ServiceResult(NULL, true);
        if (!apdsToDelete.isEmpty() && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            try {
                APDisbursementActions.preventIfExistAPDInFutureAccountingPeriod(new Map<Id, AP_Disbursement__c> (apdsToDelete));
                List<Id> apdIds = new List<Id>();
                for (AP_Disbursement__c apd : apdsToDelete) {
                    apdIds.add(apd.Id);
                    cdServiceResults.add(new ServiceResult(apd.Id, true));
                }

                Set<Id> postedRecordsIds = PostProcessor.filterByStatus(
                        AP_Disbursement__c.SObjectType,
                        apdIds,
                        AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
                );

                if (!postedRecordsIds.isEmpty()) {
                    new PostProcessor().unpost(new List<Id> (postedRecordsIds));
                }

                Set<Id> approvedRecordsIds = new Set<Id>(apdIds);
                approvedRecordsIds.removeAll(postedRecordsIds);
                if (!approvedRecordsIds.isEmpty()) {
                    sr = processDeleteResults(SFDCSecurityUtils.deleteCheckCRUDAndFLS(new List<Id>(approvedRecordsIds), false), cdServiceResults);
                }
            } catch (Exception ex) {
                List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                ServiceResult.Error err = new ServiceResult.Error(ex.getTypeName(), ex.getMessage());
                errors.add(err);
                for (AP_Disbursement__c apd : apdsToDelete) {
                    cdServiceResults.add(new ServiceResult(apd.Id, false, errors));
                }
                sr = new ServiceResult(NULL, false, errors);
            }
        } else {
            sr = processDeleteResults(SFDCSecurityUtils.deleteCheckCRUDAndFLS(apdsToDelete, false), cdServiceResults);
        }
        return sr;
    }

    private ServiceResult processDeleteResults(List<Database.DeleteResult> deleteResults, List<ServiceResult> cdServiceResults) {
        ServiceResult sr = new ServiceResult(NULL, true);
        for (Database.DeleteResult deleteResult : deleteResults) {
            if (deleteResult.isSuccess()) {
                cdServiceResults.add(new ServiceResult(deleteResult.getId(), true));
            }
            else {
                List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
                for (Database.Error dbError : deleteResult.getErrors()) {
                    ServiceResult.Error err = new ServiceResult.Error(dbError.getStatusCode().name(), dbError.getMessage());
                    errors.add(err);
                }
                cdServiceResults.add(new ServiceResult(NULL, false, errors));
                sr = new ServiceResult(NULL, false, errors);
            }
        }

        return sr;
    }

    private Map<Id, AP_Disbursement__c> getNewAPDs(List<CashApplication> cashApplications) {
        Map<Id, AP_Disbursement__c> newAPDsMap = new Map<Id, AP_Disbursement__c>();
        for (CashApplication ca : cashApplications) {
            if (ca.amount != 0) {
                ca.appliedDate = ca.appliedDate == null && ca.accountingPeriodId != null ?
                    AccountingPeriodHandler.getInstance().getAccountingPeriodById(ca.accountingPeriodId).Start_Date__c : 
                    ca.appliedDate;
                AP_Disbursement__c apd = new AP_Disbursement__c (
                    Cash_Disbursement__c = this.cashDisbursementId,
                    Account_Payable__c = ca.appliedItemId,
                    Paid_Amount__c = ca.amount,
                    Applied_Date__c = ca.appliedDate,
                    Accounting_Period__c = ca.accountingPeriodId
                );
                if (apd.Accounting_Period__c == null && apd.Applied_Date__c != null) {
                    SObjectActions.setAccountingPeriod(new List<AP_Disbursement__c>{apd}, AP_Disbursement__c.Applied_Date__c);
                }
                newAPDsMap.put(ca.appliedItemId, apd);
            }
        }
        return newAPDsMap;
    }

    private Decimal getAppliedAmount(AP_Disbursement__c apd) {
        return (apd == null || apd.Paid_Amount__c == null) ? 0 : apd.Paid_Amount__c;
    }

    private ServiceResult validateRecordCount(List<CashApplication> cashApplications) {
        ServiceResult.Error error = new ServiceResult.Error(); 
        if (cashApplications == NULL 
            || cashApplications.size() == 0
            || this.cashDisbursementId == NULL) {
            error.detail = NO_INPUT_DATA;
            error.code = StatusCode.NO_INPUT_DATA.name();
        } else if (cashApplications != NULL && cashApplications.size() > CASH_DISBURSEMENT_ITEM_LIMIT) {
            error.detail = String.format(OVER_CASH_DISBURSEMENT_ITEM_LIMIT, new String[]{String.valueOf(CASH_DISBURSEMENT_ITEM_LIMIT)});
            error.code = StatusCode.OVER_CASH_DISBURSEMENT_ITEM_LIMIT.name();
        }

        if (error.detail != NULL) {
            serviceResult = new ServiceResult(
                NULL,
                false,
                new ServiceResult.Error[]{error}
            );
        } else {
            serviceResult = new ServiceResult(this.cashDisbursementId, true);
        }
        return serviceResult;
    }

    private ServiceResult validateCashDisbursement() {
        ServiceResult sr = new ServiceResult(null, true);
        ServiceResult.Error error = new ServiceResult.Error();
        if (!FinancialSuiteUtils.isValidId(this.cashDisbursementId, Cash_Disbursement__c.SObjectType)) {
            error.detail = INVALID_RECORD_OR_ID;
            error.code = StatusCode.INVALID_RECORD_OR_ID.name();
        } 
        if (this.cashDisbursement.Payment_Status__c == 'Void') {
            error.detail = VOIDED_CD_ERROR;
            error.code = StatusCode.VOIDED_CD_ERROR.name();
        }
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(this.cashDisbursement.Ledger__c);
        if (this.cashDisbursement.Debit_GL_Account__c == null || this.cashDisbursement.Debit_GL_Account__c ==
            defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c) {
            error.detail = APDisbursementPostHandler.DEBIT_GL_ACCOUNT_VALIDATION_ON_INSERT_ERROR_MESSAGE;
            error.code = StatusCode.DEBIT_GL_ACCOUNT_VALIDATION_ERROR_MESSAGE.name(); 
        }
        if (error.detail != null) {
            sr = new ServiceResult(null, false, new List<ServiceResult.Error>{error});
        }
        return sr;
    }

    private ServiceResult validateCashApplication(CashApplication model) {
        ServiceResult sr = new ServiceResult(null, true);
        ServiceResult.Error error = new ServiceResult.Error();
        if (!FinancialSuiteUtils.isValidId(model.appliedItemId, Account_Payable__c.SObjectType)) {
            error.detail = INVALID_RECORD_OR_ID;
            error.code = StatusCode.INVALID_RECORD_OR_ID.name();
        }
        if(model.accountingPeriodId != null && !FinancialSuiteUtils.isValidId(model.accountingPeriodId, Accounting_Period__c.SObjectType)) {
            error.detail = INVALID_RECORD_OR_ID;
            error.code = StatusCode.INVALID_RECORD_OR_ID.Name();
        }
        if (model.appliedDate != null && model.accountingPeriodId != null) {
            AccountingPeriodHandler handler = AccountingPeriodHandler.getInstance();
            Accounting_Period__c acctPeriod = handler.getAccountingPeriodByDate(model.appliedDate);
            if (acctPeriod == null || (acctPeriod != null && acctPeriod.Id != model.accountingPeriodId)) {
                error.detail = APPLIED_DATE_DOES_NOT_MATCH_ACCOUNTING_PERIOD;
                error.code = StatusCode.APPLIED_DATE_DOES_NOT_MATCH_ACCOUNTING_PERIOD.name();
            }
        }
        if (error.detail != null) {
            sr = new ServiceResult(null, false, new List<ServiceResult.Error>{error});
        }
        return sr;
    }

    private ServiceResult validate(Map<Id, AP_Disbursement__c> oldAPDs, Map<Id, AP_Disbursement__c> newAPDs) {
        ServiceResult sr = new ServiceResult(null, true);
        List<ServiceResult.Error> errors = new List<ServiceResult.Error>();
        AP_Disbursement__c oldAPD, newAPD;
        Decimal oldAPDAppliedAmount, newAPDAppliedAmount;
        Decimal cashDisbursementBalance = this.cashDisbursement.Balance__c;
        Id cashDisbursementLedger = this.cashDisbursement.Ledger__c;
        String cashDisbursementPayee = this.cashDisbursement.Payee_Id__c;
        
        for (Account_Payable__c payable : this.payables) {
            if (payable.Type__c != 'Invoice') {
                ServiceResult.Error err = new ServiceResult.Error(
                    payable.Id,
                    StatusCode.PAYABLE_TYPE_MISMATCH.name(),
                    PAYABLE_TYPE_MISMATCH
                );
                errors.add(err);
            }
            
            if (payable.Ledger__c != cashDisbursementLedger) {
                ServiceResult.Error err = new ServiceResult.Error(
                    payable.Id,
                    StatusCode.CASH_DISBURSEMENT_LEDGER_MISMATCH.name(),
                    CASH_DISBURSEMENT_LEDGER_MISMATCH
                );
                errors.add(err);
            }

            if (payable.Payee_Id__c != cashDisbursementPayee) {
                ServiceResult.Error err = new ServiceResult.Error(
                    payable.Id,
                    StatusCode.CASH_DISBURSEMENT_PAYEE_MISMATCH.name(),
                    CASH_DISBURSEMENT_PAYEE_MISMATCH
                );
                errors.add(err);
            }

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                if (payable.get('CurrencyIsoCode') != this.cashDisbursement.get('CurrencyIsoCode')) {
                    ServiceResult.Error err = new ServiceResult.Error(
                        payable.Id,
                        StatusCode.CASH_DISBURSEMENT_CURRENCY_MISMATCH.name(),
                        CASH_DISBURSEMENT_CURRENCY_MISMATCH
                    );
                    errors.add(err);
                }
            }

            oldAPD = oldAPDs.get(payable.Id);
            newAPD = newAPDs.get(payable.Id);

            oldAPDAppliedAmount = getAppliedAmount(oldAPD);
            newAPDAppliedAmount = getAppliedAmount(newAPD);

            cashDisbursementBalance = (cashDisbursementBalance + oldAPDAppliedAmount) - newAPDAppliedAmount;

            if (cashDisbursementBalance < 0) {
                ServiceResult.Error err = new ServiceResult.Error(
                    payable.Id,
                    StatusCode.CASH_DISBURSEMENT_BALANCE_LESS_THAN_ZERO.name(),
                    CASH_DISBURSEMENT_BALANCE_LESS_THAN_ZERO
                );
                errors.add(err);
            }

            if (newAPDAppliedAmount < 0) {
                ServiceResult.Error err = new ServiceResult.Error(
                    payable.Id,
                    StatusCode.APPLIED_AMOUNT_LESS_THAN_ZERO.name(),
                    APPLIED_AMOUNT_LESS_THAN_ZERO
                );
                errors.add(err);
            }

            if (oldAPD != null &&
                    FeatureManagementHandler.isLargeDataVolumeModeEnabled() &&
                    !AbstractPostHandler.validatePostingStatus(oldAPD.Status__c)
            ) {

                ServiceResult.Error err = new ServiceResult.Error(
                    payable.Id,
                    StatusCode.POSTING_IN_PROGRESS.name(),
                    BATCH_JOB_IS_RUNNING
                );
                errors.add(err);
            }

            if ((payable.Balance_Minus_Discount__c + oldAPDAppliedAmount) - newAPDAppliedAmount < 0) {
                ServiceResult.Error err = new ServiceResult.Error(
                    payable.Id,
                    StatusCode.PAYABLE_BALANCE_LESS_THAN_ZERO.name(),
                    PAYABLE_BALANCE_LESS_THAN_ZERO
                );
                errors.add(err);
            }
            if (newAPD != null) {
                if (newAPD.Applied_Date__c == null) {
                    ServiceResult.Error err = new ServiceResult.Error(
                        payable.Id,
                        StatusCode.MISSING_APPLIED_DATE.name(),
                        MISSING_APPLIED_DATE
                    );
                    errors.add(err);
                }

                if (newAPD.Accounting_Period__c == null) {
                    ServiceResult.Error err = new ServiceResult.Error(
                        payable.Id,
                        StatusCode.MISSING_ACCOUNTING_PERIOD.name(),
                        MISSING_ACCOUNTING_PERIOD
                    );
                    errors.add(err);
                }

                // APD has valid accounting period
                // new period not closed
                // new period >= (the greater of payable period or cash disbursement period)
                ServiceResult.Error err = validAPDPeriod(payable, newAPD);
                if (err != null) {
                    errors.add(err);
                }
            }
        }

        if (!errors.isEmpty()) {
            sr = new ServiceResult(null, false, errors);
        }
        return sr;
    }
    
    private ServiceResult.Error validAPDPeriod(Account_Payable__c payable, AP_Disbursement__c apd) {
        AccountingPeriodHandler handler = AccountingPeriodHandler.getInstance();
        // APD period closed?
        if (handler.isConsideredClosed(apd.Accounting_Period__c, AP_Disbursement__c.SObjectType)) {
            String derivedName =  payable.Proprietary_Payable_Number__c != null ? payable.Proprietary_Payable_Number__c : payable.Name;
            return new ServiceResult.Error(
                payable.Id,
                StatusCode.ACCOUNTING_PERIOD_CLOSED.name(),
                String.format(APPLIED_DATE_INVALID, new String[] { derivedName })
            );
        // APD period >= payable period
        } else if (handler.compareAccountingPeriods(this.cashDisbursement.Accounting_Period__c, payable.Accounting_Period__c) < 0) {
            Boolean isValid = handler.compareAccountingPeriods(apd.Accounting_Period__c, payable.Accounting_Period__c) >= 0;
            if(!isValid) {
                return new ServiceResult.Error(
                    payable.Id,
                    StatusCode.ACCOUNTING_PERIOD_BEFORE_PAYABLE_ACCOUNTING_PERIOD.name(),
                    ACCOUNTING_PERIOD_BEFORE_PAYABLE_ACCOUNTING_PERIOD
                );
            }
        // APD period >= cash disbursement period
        } else {
            Boolean isValid = handler.compareAccountingPeriods(apd.Accounting_Period__c, this.cashDisbursement.Accounting_Period__c) >= 0;
            if (!isValid) {
                return new ServiceResult.Error(
                    payable.Id,
                    StatusCode.ACCOUNTING_PERIOD_BEFORE_CASH_DISBURSEMENT_ACCOUNTING_PERIOD.name(),
                    ACCOUNTING_PERIOD_BEFORE_CASH_DISBURSEMENT_ACCOUNTING_PERIOD
                );
            }
        }
        return null;
    }
}