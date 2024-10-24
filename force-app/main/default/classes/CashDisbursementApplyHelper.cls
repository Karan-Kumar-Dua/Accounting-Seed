public with sharing class CashDisbursementApplyHelper {
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String OPEN_STATUS = AccountingPeriodActions.OPEN_STATUS;
    public static final String VOIDED_CD_ERROR = Label.COMMON_VOIDED_CD_ERROR;

    private static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
    private static List<String> fieldNames {get;set;}
    private static List<String> cols {get;set;}

    private static final Map<ExceptionCode,String> codeTranslations = new Map<ExceptionCode,String> {
        ExceptionCode.DML => 'DML',
        ExceptionCode.CRUD_FLS_WRITE => 'CRUD_FLS_WRITE',
        ExceptionCode.CRUD_FLS_READ => 'CRUD_FLS_READ',
        ExceptionCode.WRITE_CONFLICT => 'WRITE_CONFLICT',
        ExceptionCode.VALIDATION => 'VALIDATION',
        ExceptionCode.UNKNOWN => 'UNKNOWN'
    };
    private enum ExceptionCode { DML, CRUD_FLS_WRITE, CRUD_FLS_READ, WRITE_CONFLICT, VALIDATION, UNKNOWN }

    public class SaveItem {
        public String payableId;
        public String payableNumber;
        public String period;
        public Date appliedDate;
        public Decimal appliedAmount;
    }

    public class SaveResponse {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public List<String> errors;
        @AuraEnabled
        public Cash_Disbursement__c cashDisbursement;

        public SaveResponse(List<String> errors, Cash_Disbursement__c cashDisbursement) {
            this.isSuccess = errors == null || errors.size() == 0;
            this.errors = errors;
            this.cashDisbursement = cashDisbursement;
        }
    }

    public class cashDisbursementWrapper {
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled;
        @AuraEnabled
        public Cash_Disbursement__c cashDisbursement;  
        @AuraEnabled
        public Id cashDisbursementId;
        @AuraEnabled
        public Boolean isValid;
        @AuraEnabled
        public String validationErrors;
    }

    public class extraColumnsWrapper {
        @AuraEnabled
        public List<String> extraColumns;

        public extraColumnsWrapper() {
            cols = new List<String>();
            List<String> ignoredFields = new List<String>{
                'Name'
            };
            FieldSetUtils.DataTableResponse fieldSetDataTable = FieldSetUtils.getColumnsFromFieldSet(
                PACKAGE_QUALIFIER + 'Account_Payable__c',
                PACKAGE_QUALIFIER + 'CashDisbursementApply',
                ignoredFields
            );
            fieldNames = fieldSetDataTable.fieldNames;

            for (FieldSetUtils.DataTableColumns dtc : fieldSetDataTable.dataTableColumns) {
                cols.add(JSON.serialize(dtc, true));
            }
            this.extraColumns = cols;
        }
    }

    private class PayableWrapperParams {
        private Account_Payable__c payable;
        private AP_Disbursement__c apDisbursement;
        private String periodName;
        private Boolean isPeriodClosed;
        private Cash_Disbursement__c cashDisbursement;
    }

    public class PayableWrapper {
        @AuraEnabled
        public Boolean isClosed;
        @AuraEnabled
        public String URL;
        @AuraEnabled
        public Date issueDate;
        @AuraEnabled
        public String payableNumber;
        @AuraEnabled
        public String proprietaryName;
        @AuraEnabled
        public String payeeReference;
        @AuraEnabled
        public String payableId;
        @AuraEnabled
        public Decimal total;
        @AuraEnabled
        public Decimal applied;
        @AuraEnabled
        public Decimal balance;
        @AuraEnabled
        public Decimal appliedAmount;
        @AuraEnabled
        public String period;
        @AuraEnabled
        public Date appliedDate;
        @AuraEnabled
        public Date earliestAppliedDate;
        @AuraEnabled
        public String periodName;
        @AuraEnabled
        public String payablePeriod;
        @AuraEnabled
        public String payablePeriodName;
        @AuraEnabled
        public Date DueDate;
        @AuraEnabled
        public Decimal receivedAmount;
        @AuraEnabled
        public Decimal totalApplied;
        @AuraEnabled
        public Decimal creditMemoApplied;
        @AuraEnabled
        public Boolean isDirty;
        @AuraEnabled
        public Date payablePeriodStart;
        @AuraEnabled
        public Boolean onHold;
        @AuraEnabled
        public Map<String, Object> extraFields;

        public PayableWrapper(PayableWrapperParams params) {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();

            this.isClosed = params.isPeriodClosed;
            this.issueDate = params.payable.Date__c;
            this.payableNumber = params.payable.Name;
            this.proprietaryName = params.payable.Proprietary_Payable_Number__c;
            this.payeeReference = params.payable.Payee_Reference__c;
            this.payableId = params.payable.Id;
            this.period = params.apDisbursement.Accounting_Period__c;
            this.appliedDate = params.apDisbursement.Applied_Date__c;
            this.periodName = params.periodName;
            this.payablePeriod = params.payable.Accounting_Period__c;
            this.onHold = params.payable.On_Hold__c;
            
            this.earliestAppliedDate = params.payable.Accounting_Period__r.Start_Date__c > params.cashDisbursement.Accounting_Period__r.Start_Date__c ? 
                params.payable.Accounting_Period__r.Start_Date__c :
                params.cashDisbursement.Accounting_Period__r.Start_Date__c;
            
            Accounting_Period__c periodByAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(this.earliestAppliedDate);
            List<Accounting_Period__c> nextPeriods = new List<Accounting_Period__c>();

            if (!AccountingPeriod.isPeriodOpen(periodByAppliedDate, Account_Payable__c.sObjectType)) {
                nextPeriods = acctPeriodHandler.getNextAccountingPeriods(periodByAppliedDate, new Set<String>{OPEN_STATUS}, Account_Payable__c.sObjectType);
                
                //if to make sure if there is next accounting periods which are open then only process further
                if(nextPeriods.size() > 0){
                   periodByAppliedDate = nextPeriods[0]; 
                   this.earliestAppliedDate = periodByAppliedDate.Start_Date__c;
                }
            }
            
            this.receivedAmount = convertNullToZero(params.payable.Paid_Amount__c);
            this.creditMemoApplied = convertNullToZero(params.payable.Credit_Memo_Applied_Amount__c);
            this.payablePeriodName = params.payable.Accounting_Period__r.Name;
            this.payablePeriodStart = params.payable.Accounting_Period__r.Start_Date__c;
            this.DueDate = params.payable.Due_Date__c;

            this.balance = scaleHalfUp(convertNullToZero(params.payable.Balance_Minus_Discount__c));
            
            this.appliedAmount = scaleHalfUp(convertNullToZero(params.apDisbursement.Paid_Amount__c));            

            this.total = scaleHalfUp(convertNullToZero(params.payable.Total__c));
            
            //totalApplied is the initial value from the applied whereas applied can be manipulated
            this.totalApplied = this.receivedAmount + this.creditMemoApplied;
            
            this.applied = this.totalApplied;            
            
            this.extraFields = FieldSetUtils.getFieldSetData(fieldNames, params.payable);

            this.URL = '/lightning/r/' + params.payable.Id + '/view';
        }
    }

    public class ExceptionData {
        public String code;
        public String message;
    }

    @AuraEnabled
    public static SaveResponse save(Id cashDisbursementId, Datetime cashDisbursementLastModifiedDate, List<String> updates) {
        List<String> errors = new List<String>();
        Cash_Disbursement__c cd = new Cash_Disbursement__c();
        if (!updates.isEmpty()) {
            try {
                if (modifiedSince(cashDisbursementId, cashDisbursementLastModifiedDate)) {
                    errors.add('cash_disbursement_modified');
                }
                else {
                    List<CashApplication> cashApplications = new List<CashApplication>();
                    for (String jsonData : updates) {
                        SaveItem item = (SaveItem) JSON.deserialize(jsonData, SaveItem.class);
                        CashApplication ca = new CashApplication();
                        ca.appliedItemId = item.payableId;
                        ca.amount = item.appliedAmount;
                        ca.appliedDate = item.appliedDate;
                        cashApplications.add(ca);
                    }
                    ServiceResult sr = CashDisbursement.apply(cashDisbursementId, cashApplications);
                    if (!sr.isSuccess) {
                        Set<String> errs = new Set<String>();
                        for (ServiceResult.Error err : sr.errors) {
                            errs.add(err.detail);
                        }
                        errors.add(String.join(new List<String>(errs), ', '));
                    }
                }
            }
            catch (Exception ex) {
                errors.add(Label.ERR_SAVE_FAILURE);
            }
        }
        cd = queryThisCashDisbursement(cashDisbursementId); 
        return new SaveResponse(errors, cd);
    }

    @AuraEnabled
    public static cashDisbursementWrapper getCashDisbursement(String cashDisbursementId) {
        cashDisbursementWrapper wrapper = new cashDisbursementWrapper();
        try {
            wrapper.isMultiCurrencyEnabled = IS_MULTI_CURRENCY_ENABLED;
            wrapper.cashDisbursement = queryThisCashDisbursement(cashDisbursementId);              
            wrapper.cashDisbursementId = wrapper.cashDisbursement.Id; 
            if (wrapper.cashDisbursement.Payment_Status__c == 'Void') {
                wrapper.isValid = false;
                wrapper.validationErrors = VOIDED_CD_ERROR;
            }
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(wrapper.cashDisbursement.Ledger__c);
            if (wrapper.cashDisbursement.Debit_GL_Account__c == NULL || wrapper.cashDisbursement.Debit_GL_Account__c ==
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c) {
                wrapper.isValid = false;
                wrapper.validationErrors = APDisbursementPostHandler.DEBIT_GL_ACCOUNT_VALIDATION_ON_INSERT_ERROR_MESSAGE;
            }
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        } catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return wrapper;
    }

    @AuraEnabled
    public static extraColumnsWrapper getExtraColumns() {
        return new extraColumnsWrapper();
    }

    @AuraEnabled
    public static List<PayableWrapper> getApplicablePayables(String cashDisbursementId, 
                                                            Integer maxPayables,
                                                            String payeeId, 
                                                            String postingStatus, 
                                                            String payableNumber,
                                                            String payeeReference,
                                                            Date issueDateStart,
                                                            Date issueDateEnd,
                                                            Date dueDateStart,
                                                            Date dueDateEnd,
                                                            Decimal payableAmountStart,
                                                            Decimal payableAmountEnd,
                                                            Boolean onHold) {
        List<PayableWrapper> results;
        getExtraColumns();
        try {
            Cash_Disbursement__c cd = queryThisCashDisbursement(cashDisbursementId);
            
            map<Id, CashApplication> cashApplicationMap = new Map<Id, CashApplication>();
            for (CashApplication ca : CashDisbursement.retrieveAppliedDisbursements(cashDisbursementId).cashApplications) {
                cashApplicationMap.put(ca.appliedItemId, ca);
            }

            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = cashDisbursementId;
            filter.payeeId = payeeId;
            filter.postingStatus = postingStatus;
            filter.payableNumber = payableNumber;
            filter.payeeReference = payeeReference;
            filter.issueDateStart = issueDateStart;
            filter.issueDateEnd = issueDateEnd;
            filter.dueDateStart = dueDateStart;
            filter.dueDateEnd = dueDateEnd;
            filter.payableAmountStart = payableAmountStart;
            filter.payableAmountEnd = payableAmountEnd;
            filter.includePaidPayables = false;
            
            List<String> fieldsToReturn = new List<String>{
                'Id',
                'Payee_Reference__c',
                'Name',
                'Proprietary_Payable_Number__c',
                'Date__c',
                'Type__c',
                'Status__c',
                'Total__c',
                'Balance_Minus_Discount__c',
                'Credit_Memo_Applied_Amount__c',
                'Paid_Amount__c',
                'Payee__c',
                'Payee_Id__c',
                'Accounting_Period__c',
                'Accounting_Period__r.Status__c',
                'Accounting_Period__r.Name', 
                'Accounting_Period__r.Start_Date__c',
                'Accounting_Period__r.End_Date__c',
                'Currency_Conversion_Rate__c',
                'Due_Date__c',
                'On_Hold__c'
            };
    
            if (!fieldNames.isEmpty()){
                for (String fieldName : fieldNames){
                    fieldsToReturn.add(fieldName);
                }
            }    
                                                            
            List<Account_Payable__c> payables = new List<Account_Payable__c>();
            for (PayableModel pm : Payable.retrieve(filter, fieldsToReturn, maxPayables)) {
                payables.add(pm.payable);
            }            
            // gather and return display info
            results = createPayableWrappers(cd, payables, cashApplicationMap);
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            results = new List<PayableWrapper> ();
        }
        return results;
    }

    public static Decimal convertNullToZero(Decimal value) {
            return value != null ? value : 0;
    }

    public static Decimal scaleHalfUp(Decimal value) {
        return value.setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Boolean modifiedSince(String cashDisbursementId, Datetime timestamp) {
        Datetime lastWrite = DomainUtils.getCashDisbursementByIdForUpdate(new Set<Id>{cashDisbursementId})[0].LastModifiedDate;
        return lastWrite != timestamp;
    }

    private static Cash_Disbursement__c queryThisCashDisbursement(String cashDisbursementId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Status__c',
            'Reference__c',
            'Source__c',
            'Payment_Status__c',
            'Debit_GL_Account__c',
            'Payee__c',
            'Payee_Id__c',
            'Type__c',
            'Disbursement_Date__c',
            'Applied_Amount__c',
            'Amount__c',
            'Balance__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.End_Date__c',
            'Accounting_Period__r.Status__c',
            'LastModifiedDate',
            'Ledger__c',
            'Ledger__r.Name',
            'Currency_Conversion_Rate__c',
            'LastModifiedDate'
        };
        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id = :cashDisbursementId';
        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(1);        
        //Call DML operation
        List<Cash_Disbursement__c> results = (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }

    private static List<PayableWrapper> createPayableWrappers(Cash_Disbursement__c cashDisbursement, List<Account_Payable__c> payables, Map<Id, CashApplication> relatedCashApplications) {
        List<PayableWrapper> payableLines = new List<PayableWrapper>();
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
        for (Account_Payable__c payable : payables) {
            PayableWrapper payableLine;

            Date earliestAppliedDate = payable.Accounting_Period__r.Start_Date__c > cashDisbursement.Accounting_Period__r.Start_Date__c ? 
                payable.Accounting_Period__r.Start_Date__c :
                cashDisbursement.Accounting_Period__r.Start_Date__c;
            Date appliedDate = Date.today() < earliestAppliedDate ?
                earliestAppliedDate :
                Date.today();     
                      
            Accounting_Period__c periodByAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(appliedDate);
            List<Accounting_Period__c> nextPeriods = new List<Accounting_Period__c>();
            if (periodByAppliedDate == null) {
                periodByAppliedDate = acctPeriodHandler.getFirstOpenedPeriod(Account_Payable__c.sObjectType);
            }
            if (!(AccountingPeriod.isPeriodOpen(periodByAppliedDate, Account_Payable__c.sObjectType))) {
                nextPeriods = acctPeriodHandler.getNextAccountingPeriods(periodByAppliedDate, new Set<String>{OPEN_STATUS}, Account_Payable__c.sObjectType);
                
                //if to make sure if there is next accounting periods which are open then only process further
                if(nextPeriods.size() > 0){
                    periodByAppliedDate = nextPeriods[0];
                    appliedDate = periodByAppliedDate.Start_Date__c;
                } 
            }

            if (!relatedCashApplications.containsKey(payable.Id)) {
                AP_Disbursement__c apd = new AP_Disbursement__c(
                    Cash_Disbursement__c = cashDisbursement.Id,
                    Account_Payable__c = payable.Id
                );
                apd.Applied_Date__c = appliedDate;                
                apd.Accounting_Period__c = periodByAppliedDate.Id;   
                
                PayableWrapperParams params = new PayableWrapperParams();
                params.payable = payable;
                params.cashDisbursement = cashDisbursement;
                params.apDisbursement = apd;
                params.periodName = periodByAppliedDate.Name;
                params.isPeriodClosed = (!(AccountingPeriod.isPeriodOpen(periodByAppliedDate, Account_Payable__c.sObjectType)));             
                payableLine = new PayableWrapper(params);
            } else {
                CashApplication ca = relatedCashApplications.get(payable.Id);
                AP_Disbursement__c apd = new AP_Disbursement__c(
                    Cash_Disbursement__c = cashDisbursement.Id,
                    Account_Payable__c = payable.Id,
                    Paid_Amount__c = ca.amount
                );
                if (ca.accountingPeriodId != NULL) {
                    apd.Accounting_Period__c = ca.accountingPeriodId;                    
                    apd.Accounting_Period__r = acctPeriodHandler.getAccountingPeriodById(apd.Accounting_Period__c);
                }
                if (ca.appliedDate != NULL) {
                    apd.Applied_Date__c = ca.appliedDate;
                }

                if (apd.Accounting_Period__c == NULL) {
                    Accounting_Period__c ap = acctPeriodHandler.getAccountingPeriodByDate(apd.Applied_Date__c);
                    apd.Accounting_Period__c = ap.Id;
                    apd.Accounting_Period__r = ap;
                }

                if (apd.Applied_Date__c == NULL) {
                    apd.Applied_Date__c = apd.Accounting_Period__r.Start_Date__c; 
                }
                PayableWrapperParams params = new PayableWrapperParams();
                params.payable = payable;
                params.apDisbursement = apd;
                params.cashDisbursement = cashDisbursement;
                params.periodName = apd.Accounting_Period__r.Name;
                params.isPeriodClosed = (!(acctPeriodHandler.isConsideredOpen(apd.Accounting_Period__c, AP_Disbursement__c.sObjectType)));
                payableLine = new PayableWrapper(params);
            }

            payableLines.add(payableLine);
        }

        return payableLines;
    }

    private static AuraHandledException buildException(ExceptionCode code, String msg) {
        ExceptionData data = new ExceptionData();
        data.code = codeTranslations.get(code);
        data.message = msg;
        String jsonData = JSON.serialize(data);
        AuraHandledException ex = new AuraHandledException(jsonData);
        ex.setMessage(jsonData);
        return ex;
    }
}