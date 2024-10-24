public with sharing class CashReceiptApplyHelper {
    private static final Integer SOQL_RECORD_LIMIT = 10000;
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    private static final String OPEN_STATUS = 'Open';
    private static final String VOIDED_CR_ERROR = Label.COMMON_VOIDED_CR_ERROR;

    private static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    public static List<Id> childAccountsIds {get;set;}
    private static Map<Id, Billing_Cash_Receipt__c> billCashMap {get;set;}
    private static Set<Id> appliedBillingIds {get;set;}

    private static List<String> fieldNames {get;set;}

    private static GL_Account__c glAdjustmentGLAccount {get;set;}

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
        public String billingId;
        public String derivedName;
        public String period;
        public Date appliedDate;
        public Decimal appliedAmount;
        public Decimal adjustmentAmount;
        public String glAccount;
    }

    public class SaveResponse {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public List<String> errors;
        @AuraEnabled
        public Cash_Receipt__c cashReceipt;

        public SaveResponse(List<String> errors, Cash_Receipt__c cashReceipt) {
            this.isSuccess = errors == null || errors.size() == 0;
            this.errors = errors;
            this.cashReceipt = cashReceipt;
        }
    }

    public class cashReceiptWrapper {
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled;
        @AuraEnabled
        public Cash_Receipt__c cashReceipt;  
        @AuraEnabled
        public Id cashReceiptId;
        @AuraEnabled
        public Boolean isValid;
        @AuraEnabled
        public String validationErrors;
    }

    public class ExtraColumnsWrapper {
        @AuraEnabled
        public List<String> extraColumns;

        public ExtraColumnsWrapper() {
            cols = new List<String>();
            List<String> ignoredFields = new List<String>{
                'Name',
                PACKAGE_QUALIFIER + 'Customer__c'
            };
            FieldSetUtils.DataTableResponse fieldSetDataTable = FieldSetUtils.getColumnsFromFieldSet(
                PACKAGE_QUALIFIER + 'Billing__c',
                PACKAGE_QUALIFIER + 'CashReceiptApply',
                ignoredFields
            );
            fieldNames = fieldSetDataTable.fieldNames;

            for (FieldSetUtils.DataTableColumns dtc : fieldSetDataTable.dataTableColumns) {
                cols.add(JSON.serialize(dtc, true));
            }

            this.extraColumns = cols;
        }
    }
    //new wrapper to keep track the adjustment and applied amounts 
    public class ResponseWrapper{
        @AuraEnabled
        public Decimal totalAppliedAmount;
        @AuraEnabled
        public List<BillingWrapper> billingWrapper;   
    }
    public class BillingWrapper {
        @AuraEnabled
        public Boolean isClosed;
        @AuraEnabled
        public String URL;
        @AuraEnabled
        public String customerName;
        @AuraEnabled
        public Id customerId;
        @AuraEnabled
        public String customerURL;
        @AuraEnabled
        public Date billingDate;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String proprietaryName;
        @AuraEnabled
        public String billingId;
        @AuraEnabled
        public Decimal total;
        @AuraEnabled
        public Decimal applied;
        @AuraEnabled
        public Decimal balance;
        @AuraEnabled
        public Decimal adjustmentAmount;
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
        public Id glAccount;
        @AuraEnabled
        public String glAccountName;
        @AuraEnabled
        public String invoicePeriod;
        @AuraEnabled
        public String invoicePeriodName;
        @AuraEnabled
        public Date discountDueDate;
        @AuraEnabled
        public Decimal cashApplicationAdjustmentAmount;
        @AuraEnabled
        public Decimal creditMemoAppliedAmount;
        @AuraEnabled
        public Decimal receivedAmount;
        @AuraEnabled
        public Decimal discountAmount;
        @AuraEnabled
        public Decimal totalApplied;
        @AuraEnabled
        public Decimal initialAdjustmentAmount;
        @AuraEnabled
        public Boolean isDirty;
        @AuraEnabled
        public Date invoicePeriodStart;
        @AuraEnabled
        public Map<String, Object> extraFields;

        public BillingWrapper(Billing__c invoice, Billing_Cash_Receipt__c billingCashReceipt, String periodName, Boolean isPeriodClosed, Cash_Receipt__c cashReceipt) {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();

            this.isClosed = isPeriodClosed;
            this.billingDate = invoice.Date__c;
            this.name = invoice.Name;
            this.proprietaryName = invoice.Proprietary_Billing_Number__c;
            this.billingId = invoice.Id;
            this.period = billingCashReceipt.Accounting_Period__c;
            this.appliedDate = billingCashReceipt.Applied_Date__c;
            this.periodName = periodName;
            this.invoicePeriod = invoice.Accounting_Period__c;
            
            this.earliestAppliedDate = invoice.Accounting_Period__r.Start_Date__c > cashReceipt.Accounting_Period__r.Start_Date__c ? 
                invoice.Accounting_Period__r.Start_Date__c :
                cashReceipt.Accounting_Period__r.Start_Date__c;
            
            List<Accounting_Period__c> nextPeriods = new List<Accounting_Period__c>();
            Accounting_Period__c periodByAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(this.earliestAppliedDate);
            if (!AccountingPeriod.isPeriodOpen(periodByAppliedDate, Billing__c.sObjectType)) {
                nextPeriods = acctPeriodHandler.getNextAccountingPeriods(periodByAppliedDate, new Set<String>{OPEN_STATUS}, Billing__c.sObjectType);
                
                // if to make sure that if next accounting is open then only process further
                if(nextPeriods.size() > 0){
                    periodByAppliedDate = nextPeriods[0];
                    this.earliestAppliedDate = periodByAppliedDate.Start_Date__c;
                }
            }
            
            this.customerName = invoice.Customer__r.Name;
            this.customerId = invoice.Customer__c;
            this.cashApplicationAdjustmentAmount = convertNullToZero(invoice.Cash_Application_Adjustment_Amount__c);
            this.creditMemoAppliedAmount = convertNullToZero(invoice.Credit_Memo_Applied_Amount__c);
            this.receivedAmount = convertNullToZero(invoice.Received_Amount__c);
            this.customerURL = '/lightning/r/' + this.customerId + '/view';
            this.glAccount = billingCashReceipt.Adjustment_GL_Account__c == NULL ? 
                            getGLAdjustmentGLAccount(invoice.Ledger__c) != NULL ? glAdjustmentGLAccount.Id : NULL  :
                            billingCashReceipt.Adjustment_GL_Account__c;
            this.glAccountName = billingCashReceipt.Adjustment_GL_Account__r.Name == NULL ? 
                            getGLAdjustmentGLAccount(invoice.Ledger__c) != NULL ? glAdjustmentGLAccount.Name : '' :
                            billingCashReceipt.Adjustment_GL_Account__r.Name;
            this.invoicePeriodName = invoice.Accounting_Period__r.Name;
            this.invoicePeriodStart = invoice.Accounting_Period__r.Start_Date__c;
            this.discountDueDate = invoice.Discount_Due_Date__c;
            
            this.discountAmount =
                this.discountDueDate != NULL && this.discountDueDate >= cashReceipt.Receipt_Date__c
                    ? scaleHalfUp(convertNullToZero(invoice.Discount_Amount__c))
                    : 0;
            
            if (convertNullToZero(billingCashReceipt.Adjustment_Amount__c) != 0) {
                this.adjustmentAmount = convertNullToZero(billingCashReceipt.Adjustment_Amount__c);
                this.balance = scaleHalfUp(convertNullToZero(invoice.Balance__c));
                this.isDirty = false;
            } else {
                this.adjustmentAmount = 0;
                this.balance = scaleHalfUp(convertNullToZero(invoice.Balance__c));
                this.isDirty = false;
            }   

            this.initialAdjustmentAmount = this.adjustmentAmount;                                
            
            this.appliedAmount = scaleHalfUp(convertNullToZero(billingCashReceipt.Applied_Amount__c));            

            this.total = scaleHalfUp(convertNullToZero(invoice.Total__c));
            
            //totalApplied is the initial value from the invoice whereas applied can be manipulated
            this.totalApplied = scaleHalfUp(this.cashApplicationAdjustmentAmount + 
                                this.creditMemoAppliedAmount + 
                                this.receivedAmount);
            
            this.applied = this.totalApplied;
            
            this.extraFields = FieldSetUtils.getFieldSetData(fieldNames, invoice);
            this.URL = '/lightning/r/' + invoice.Id + '/view';
        }
    }

    public class ExceptionData {
        public String code;
        public String message;
    }

    @AuraEnabled
    public static SaveResponse save(Id cashReceiptId, Datetime cashReceiptLastModifiedDate, List<String> updates) {
        List<String> errors = new List<String>();
        Cash_Receipt__c cashReceipt = new Cash_Receipt__c();
        try {
            if (modifiedSince(cashReceiptId, cashReceiptLastModifiedDate)) {
                errors.add('cash_receipt_modified');
            }
            else {
                List<SaveItem> saveItems = new List<SaveItem>();
                for (String jsonData : updates) {
                    SaveItem item = (SaveItem) JSON.deserialize(jsonData, SaveItem.class);
                    Accounting_Period__c periodByAppliedDate =
                        AccountingPeriodHandler.getInstance().
                            getAccountingPeriodByDateAndStatus(
                                item.appliedDate,
                                new Set<String>{OPEN_STATUS},
                                Billing__c.SObjectType
                            );

                    if (periodByAppliedDate == null) { 
                        errors.add(String.format(Label.ERR_BILLING_APPLIED_DATE_INVALID, new String[]{item.derivedName}));
                    }
                    else {
                        item.period = periodByAppliedDate.Id;
                        item.adjustmentAmount = item.glAccount == null && item.adjustmentAmount == 0 ? null : item.adjustmentAmount;
                        saveItems.add(item);
                    }
                }
                
                cashReceipt = queryThisCashReceipt(cashReceiptId);
                List<Billing__c> invoices = getInvoices(saveItems);
                Map<Id, Billing_Cash_Receipt__c> invoiceToOldBCRs = getOldBCRs(cashReceipt, saveItems);
                Map<Id, Billing_Cash_Receipt__c> invoiceToNewBCRs = createNewBCRs(cashReceipt, invoiceToOldBCRs, saveItems);

                if (valid(cashReceipt, invoices, invoiceToOldBCRs, invoiceToNewBCRs, errors)) {
                    atomicSave(invoiceToOldBCRs, invoiceToNewBCRs, errors);
                    //requery the cash receipt after save to get the changes
                    cashReceipt = queryThisCashReceipt(cashReceiptId);
                }
                else {
                    if (!errors.contains(Label.INF_JOB_IS_RUNNING)) {
                        errors.add(Label.ERR_VALIDATION_FAILURE);
                    }
                }
            }
        }
        catch (Exception ex) {
            errors.add(Label.ERR_SAVE_FAILURE);
        }
        return new SaveResponse(errors, cashReceipt);
    }

    @AuraEnabled
    public static cashReceiptWrapper getCashReceipt(String cashReceiptId) {
        cashReceiptWrapper wrapper = new cashReceiptWrapper();
        try {
            wrapper.isMultiCurrencyEnabled = IS_MULTI_CURRENCY_ENABLED;
            wrapper.cashReceipt = queryThisCashReceipt(cashReceiptId);  
            wrapper.cashReceiptId = wrapper.cashReceipt.Id;     
            if (wrapper.cashReceipt.Void__c) {
                wrapper.isValid = false;
                wrapper.validationErrors = VOIDED_CR_ERROR;
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
        extraColumnsWrapper wrapper = new extraColumnsWrapper();
        return wrapper;
    }

    @AuraEnabled
    public static ResponseWrapper getApplicableInvoices(String cashReceiptId, 
                                                            Integer maxInvoices,
                                                            String customerId, 
                                                            String postingStatus, 
                                                            String billingNumber,
                                                            Date billingDateStart,
                                                            Date billingDateEnd,
                                                            Date dueDateStart,
                                                            Date dueDateEnd,
                                                            Decimal billingAmountStart,
                                                            Decimal billingAmountEnd) {
        ResponseWrapper result = new ResponseWrapper();
        getExtraColumns();
        try {
            Cash_Receipt__c cashReceipt = queryThisCashReceipt(cashReceiptId);
            
            cashReceipt.Ledger__c = cashReceipt.Ledger__c != NULL ? cashReceipt.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
            if (!String.isEmpty(customerId)) {
                childAccountsIds = new List<Id>(getRecordMapFromRecordList( (List<SObject>) queryChildAccounts(String.valueOf(customerId)) ).keySet());
            }

            billCashMap = queryExistedBillingCashReceipts(cashReceiptId);
            for(Billing_Cash_Receipt__c bcr : billCashMap.values()) {
                if (bcr.Applied_Date__c == null) {
                    bcr.Applied_Date__c = bcr.Accounting_Period__r.Start_Date__c;
                }
            }
            appliedBillingIds = billCashMap.keySet();

            List<Billing__c> billings = getBillings(cashReceipt, 
                                                    childAccountsIds, 
                                                    appliedBillingIds,
                                                    maxInvoices,  
                                                    customerId, 
                                                    postingStatus, 
                                                    billingNumber,
                                                    billingDateStart,
                                                    billingDateEnd,
                                                    dueDateStart,
                                                    dueDateEnd,
                                                    billingAmountStart,
                                                    billingAmountEnd);
            
            // gather and return display info
            result = calculateAdjustmentAmounts(result,billCashMap);
            result.billingWrapper = createBillingWrappers(cashReceipt, billings, billCashMap);
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        }
        catch (Exception ex) {
            result.billingWrapper = new List<BillingWrapper>();
        }
        return result;
    }
    //this will calculate the applied and the both adjustment amounts from the BCRs
    private static ResponseWrapper calculateAdjustmentAmounts(ResponseWrapper response,Map<Id,Billing_Cash_Receipt__c> billCashReciepts){
        Decimal totalAppliedAmount = 0;
        for(Billing_Cash_Receipt__c bcr : billCashReciepts.values()) {
            //the total applied amount
            totalAppliedAmount+=bcr.Applied_Amount__c;
        }
        response.totalAppliedAmount = totalAppliedAmount;
        return response;
    }
    public static Decimal convertNullToZero(Decimal value) {
            return value != null ? value : 0;
    }

    public static Decimal scaleHalfUp(Decimal value) {
        return value.setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Boolean modifiedSince(String cashReceiptId, DateTime timestamp) {
        DateTime lastWrite = DomainUtils.getCashReceiptByIdForUpdate(new Set<Id>{cashReceiptId})[0].LastModifiedDate;
        return lastWrite != timestamp;
    }

    public static GL_Account__c getGLAdjustmentGLAccount(Id ledgerId) {
        Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(ledgerId);
        if (glAdjustmentGLAccount == NULL && defaultsBySpecDevNames.containsKey(GLAccountDefaultsHandler.CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT)) {
            glAdjustmentGLAccount = getGLAccountById(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.CUSTOMER_PAYMENT_ADJUSTMENT_GL_ACCOUNT)?.GL_Account__c);
        }

        return glAdjustmentGLAccount;
    }

    private static GL_Account__c getGLAccountById(Id glAccountId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name'
        };

        String queryCondition = 'Id = :glAccountId';
        SOQLBuilder theQuery = new SOQLBuilder(GL_Account__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        return (GL_Account__c) Database.query(theQuery.toSOQL());
    }

    private static List<Billing__c> getInvoices(List<SaveItem> updates) {
        Set<Id> billingIds = new Set<Id>(); 
        for (SaveItem item : updates) {
            billingIds.add(item.billingId);
        }

        List<String> queryFields = new List<String> {
            'Id',
            'Total__c',
            'Credit_Memo_Applied_Amount__c',
            'Balance__c',
            'Accounting_Period__c'
        };

        String queryCondition = 
            'Id IN :billingIds ' + 
            'LIMIT :SOQL_RECORD_LIMIT';

        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Billing__c>) Database.query(theQuery.toSOQL());
    }

    private static Map<Id,Billing_Cash_Receipt__c> getOldBCRs(Cash_Receipt__c cashReceipt, List<SaveItem> updates) {
        Set<Id> billingIds = new Set<Id>(); 
        for (SaveItem item : updates) {
            billingIds.add(item.billingId);
        }

        List<String> queryFields = new List<String> {
            'Id',
            'Adjustment_Amount__c',
            'Applied_Amount__c',
            'Billing__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.End_Date__c',
            'Adjustment_GL_Account__c',
            'Applied_Date__c',
            'Cash_Receipt__c',
            'Status__c'
        };

        String cashReceiptId = cashReceipt.Id;
        String queryCondition = 
            'Billing__c IN :billingIds ' + 
            'AND Cash_Receipt__c = :cashReceiptId ' + 
            'LIMIT :SOQL_RECORD_LIMIT';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        List<Billing_Cash_Receipt__c> bcrs = (List<Billing_Cash_Receipt__c>) Database.query(theQuery.toSOQL());

        Map<Id,Billing_Cash_Receipt__c> results = new Map<Id,Billing_Cash_Receipt__c>(); 
        for (Billing_Cash_Receipt__c bcr : bcrs) {
            results.put(bcr.Billing__c, bcr);
        }

        return results;
    }

    private static Map<Id,Billing_Cash_Receipt__c> createNewBCRs(Cash_Receipt__c cashReceipt, Map<Id,Billing_Cash_Receipt__c> oldBCRs, List<SaveItem> updates) {
        Map<Id,Billing_Cash_Receipt__c> results = new Map<Id,Billing_Cash_Receipt__c>();
        
        Billing_Cash_Receipt__c oldBCR;
        for (SaveItem item : updates) {
            Billing_Cash_Receipt__c newBCR;
            oldBCR = oldBCRs.get(item.billingId);
            if (oldBCR == null) {
                newBCR = new Billing_Cash_Receipt__c(
                    Applied_Amount__c = scaleHalfUp(convertNullToZero(item.appliedAmount)),
                    Adjustment_Amount__c = item.adjustmentAmount, 
                    Adjustment_GL_Account__c = item.glAccount,
                    Accounting_Period__c = item.period,
                    Applied_Date__c = item.appliedDate,
                    Billing__c = item.billingId,
                    Cash_Receipt__c = cashReceipt.Id
                ); 
            } else {
                newBCR = oldBCR.clone(false, true);
                newBCR.Accounting_Period__c = item.period;
                newBCR.Applied_Date__c = item.appliedDate;
                newBCR.Applied_Amount__c = scaleHalfUp(convertNullToZero(item.appliedAmount));
                newBCR.Adjustment_Amount__c = item.adjustmentAmount;
                newBCR.Adjustment_GL_Account__c = item.glAccount;
            }
            results.put(newBCR.Billing__c, newBCR);
        }

        return results;
    }

    private static Decimal getAdjustmentAmount(Billing_Cash_Receipt__c bcr) {
            return (bcr == null || bcr.Adjustment_Amount__c == null) ? 0 : bcr.Adjustment_Amount__c;
    }

    private static Decimal getAppliedAmount(Billing_Cash_Receipt__c bcr) {
            return (bcr == null || bcr.Applied_Amount__c == null) ? 0 : bcr.Applied_Amount__c;
    }

    private static Date getAppliedDate(Billing_Cash_Receipt__c bcr) {
        return bcr == null 
        ? 
            Date.parse('1/1/1900') 
        : 
            bcr.Applied_Date__c == null 
            ?
                bcr.Accounting_Period__r.Start_Date__c
            :
                bcr.Applied_Date__c;
    }

    private static Boolean validBCRPeriod(Cash_Receipt__c cashReceipt, Billing__c invoice, Billing_Cash_Receipt__c bcr) {
        Boolean isValid;
        AccountingPeriodHandler handler = AccountingPeriodHandler.getInstance();

        // BCR period closed?
        if (handler.isConsideredClosed(bcR.Accounting_Period__c, Billing_Cash_Receipt__c.sObjectType)) {
            isValid = false;
        // BCR period >= invoice period
        } else if (handler.compareAccountingPeriods(cashReceipt.Accounting_Period__c, invoice.Accounting_Period__c) < 0) {
            isValid = handler.compareAccountingPeriods(bcr.Accounting_Period__c, invoice.Accounting_Period__c) >= 0;
        // BCR period >= cash receipt period
        } else {
            isValid = handler.compareAccountingPeriods(bcr.Accounting_Period__c, cashReceipt.Accounting_Period__c) >= 0;
        }
        
        return isValid;
    }

    private static Boolean valid(
            Cash_Receipt__c cashReceipt, 
            List<Billing__c> invoices, 
            Map<Id,Billing_Cash_Receipt__c> oldBCRs, 
            Map<Id,Billing_Cash_Receipt__c> newBCRs,
            List<String> errors
    ) {

        Boolean isValid = true;
        Billing_Cash_Receipt__c oldBCR, newBCR;
        Decimal oldBCRAdjustmentAmount, newBCRAdjustmentAmount, oldBCRAppliedAmount, newBCRAppliedAmount;
        Decimal cashReceiptBalance = cashReceipt.Balance__c;
 
        for (Billing__c invoice : invoices) {
            newBCR = newBCRs.get(invoice.Id); 
            newBCRAppliedAmount = getAppliedAmount(newBCR);
            cashReceiptBalance += newBCRAppliedAmount;
        }

        for (Billing__c invoice : invoices) {
            oldBCR = oldBCRs.get(invoice.Id);
            newBCR = newBCRs.get(invoice.Id); 
            
            oldBCRAdjustmentAmount = getAdjustmentAmount(oldBCR);
            newBCRAdjustmentAmount = getAdjustmentAmount(newBCR);

            oldBCRAppliedAmount = getAppliedAmount(oldBCR);
            newBCRAppliedAmount = getAppliedAmount(newBCR);

            cashReceiptBalance = cashReceiptBalance - newBCRAppliedAmount;

            if (cashReceiptBalance  < 0) {
                isValid = false;
            }

            if (newBCRAppliedAmount < 0) {
                isValid = false;
            }

            if ((invoice.Balance__c + oldBCRAppliedAmount + oldBCRAdjustmentAmount) - newBCRAppliedAmount - newBCRAdjustmentAmount < 0) {
                isValid = false;
            }

            // BCR has accounting period
            if (newBCR.Accounting_Period__c == null) {
                isValid = false;
            }

            if (newBCR.Applied_Date__c == null) {
                isValid = false;
            }

            if (FeatureManagementHandler.isLargeDataVolumeModeEnabled() &&
                    oldBCR != null &&
                    !AbstractPostHandler.validatePostingStatus(oldBCR.Status__c)) {

                isValid = false;
                errors.add(Label.INF_JOB_IS_RUNNING);
            }

            // BCR has valid accounting period
                // new period not closed
                // new period >= (the greater of billing invoice period or cash receipt period)
            if (!validBCRPeriod(cashReceipt, invoice, newBCR)) {
                isValid = false;
            }

            if (newBCR.Adjustment_GL_Account__c == null && newBCRAdjustmentAmount > 0) {
                isValid = false;
            }

        }
        return isValid;
    }

    private static void atomicSave(Map<Id,Billing_Cash_Receipt__c> oldBCRs, Map<Id,Billing_Cash_Receipt__c> newBCRs, List<String> errors) {
        List<Billing_Cash_Receipt__c> inserts = new List<Billing_Cash_Receipt__c>();
        List<Billing_Cash_Receipt__c> deletes = new List<Billing_Cash_Receipt__c>();
        // determine inserts + deletes
        Billing_Cash_Receipt__c oldBCR, newBCR;
        for (Id key : newBCRs.keySet()) {
            oldBCR = oldBCRs.get(key);
            newBCR = newBCRs.get(key);

            // remove existing BCR
            if (oldBCR != null && newBCR != null
                    && (getAppliedAmount(newBCR) <= 0 && getAdjustmentAmount(newBCR) <= 0)) { 
                deletes.add(oldBCR); 
            }
            // update existing BCR 
            else if (oldBCR != null && newBCR != null 
                    && (getAppliedAmount(oldBCR) != getAppliedAmount(newBCR)
                    || getAdjustmentAmount(oldBCR) != getAdjustmentAmount(newBCR)
                    || oldBCR.Accounting_Period__c != newBCR.Accounting_Period__c
                    || getAppliedDate(oldBCR) != getApplieddate(newBCR)
                    || oldBCR.Adjustment_GL_Account__c != newBCR.Adjustment_GL_Account__c)) {
                inserts.add(newBCR);
                deletes.add(oldBCR);
            }
            // new BCR 
            else if (oldBCR == null && newBCR != null
                    && (getAdjustmentAmount(newBCR) > 0 
                        || getAppliedAmount(newBCR) > 0)
                    && newBCR.Accounting_Period__c != null
                    && newBCR.Applied_Date__c != null) {
                inserts.add(newBCR);
            }
        }
        
        Savepoint sp = Database.setSavepoint();
        try {
            if (!deletes.isEmpty() && FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                BillingCashReceiptActions.preventIfExistBCRInFutureAccountingPeriod(new Map<Id, Billing_Cash_Receipt__c> (deletes));
                List<Id> bcrIds = new List<Id>();
                for (Billing_Cash_Receipt__c bcr : deletes) {
                    bcrIds.add(bcr.Id);
                }
                Set<Id> postedRecordsIds = PostProcessor.filterByStatus(
                        Billing_Cash_Receipt__c.SObjectType,
                        bcrIds,
                        AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED
                );

                if (!postedRecordsIds.isEmpty()) {
                    new PostProcessor().unpost(new List<Id> (postedRecordsIds));
                }

                Set<Id> approvedRecordsIds = new Set<Id>(bcrIds);
                approvedRecordsIds.removeAll(postedRecordsIds);
                if (!approvedRecordsIds.isEmpty()) {
                    SFDCSecurityUtils.deleteProxy(new List<Id>(approvedRecordsIds));
                }
            } else {
                SFDCSecurityUtils.deleteProxy(deletes);
            }
            SFDCSecurityUtils.insertCheckCRUDAndFLS(inserts, new List<String>{
                'Adjustment_Amount__c',
                'Applied_Amount__c',
                'Cash_Receipt__c',
                'Billing__c',
                'Accounting_Period__c',
                'Applied_Date__c',
                'Adjustment_GL_Account__c'
            });
        } catch (Exception ex) {
            String errMsg = ex.getMessage();
            if (errMsg.contains('EXCEPTION,')) {
                errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('EXCEPTION,') - 10);
            }
            if (errMsg.contains('>')) {
                errMsg = errMsg.right(errMsg.length() - errMsg.indexOf('>') - 1);
                errMsg = errMsg.left(errMsg.indexOf('<'));
            }
            else if (errMsg.contains(': [')) {
                errMsg = errMsg.left(errMsg.indexOf(': ['));
            }
            errors.add(errMsg);
            Database.rollback(sp);
        }
    }

    private static Cash_Receipt__c queryThisCashReceipt(String cashReceiptId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Purpose__c',
            'Account__r.Name',
            'Status__c',
            'Purpose__c',
            'Payment_Reference__c',
            'Receipt_Date__c',
            'Amount__c',
            'Account__c',
            'Applied_Amount__c',
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
            'LastModifiedDate',
            'Convenience_Fees_Charged__c',
            'Void__c'
        };
        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }
        String queryCondition = 'Id = :cashReceiptId LIMIT 1';
        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);        
        //Call DML operation
        List<Cash_Receipt__c> results = (List<Cash_Receipt__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }

    private static List<Account> queryChildAccounts(String parentAccountId) {
        List<String> queryFields = new List<String>{
            'Id',
            'Name'
        };

        String queryCondition = 'ParentId = :parentAccountId';
        SOQLBuilder theQuery = new SOQLBuilder(Account.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return (List<Account>) Database.query(theQuery.toSOQL());
    }

    private static Map<Id, Billing_Cash_Receipt__c> queryExistedBillingCashReceipts(String crId) {
        Map<Id, Billing_Cash_Receipt__c> resultMap = new Map<Id, Billing_Cash_Receipt__c>();
        if (!String.isBlank(crId)) {
            List<String> queryFields = new List<String>{
                'Id',
                'Applied_Amount__c',
                'Billing__c',
                'Billing__r.Customer__c',
                'Billing__r.Proprietary_Billing_Number__c',
                'Billing__r.Type__c',
                'Billing__r.Total__c',
                'Billing__r.Received_Amount__c',
                'Billing__r.Balance__c',
                'Billing__r.Credit_Memo_Applied_Amount__c',
                'Billing__r.Accounting_Period__c',
                'Billing__r.Customer__c',
                'Billing__r.Customer__r.Name',
                'Accounting_Period__r.Name',
                'Accounting_Period__r.Close_AR__c',
                'Accounting_Period__r.Close_AP__c',
                'Accounting_Period__r.Status__c',
                'Accounting_Period__r.End_Date__c',
                'Accounting_Period__r.Start_Date__c',
                'Applied_Date__c',
                'Adjustment_Amount__c',
                'Billing__r.Cash_Application_Adjustment_Amount__c',
                'Adjustment_GL_Account__c',
                'Adjustment_GL_Account__r.Name',
                'Billing__r.Discount_Percent__c',
                'Billing__r.Ledger__c',
                'Billing__r.Currency_Conversion_Rate__c'
            };

            if (!fieldNames.isEmpty()){
                for (String fieldName : fieldNames){
                    queryFields.add('Billing__r.' + fieldName);
                }
            }   

            //Add query condition
            String queryCondition = 'Cash_Receipt__c = :crId ORDER BY Billing__r.Name';

            SOQLBuilder theQuery = new SOQLBuilder(Billing_Cash_Receipt__c.SObjectType);
            theQuery
                .assertIsAccessible()
                .setEnforceFLS(true)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            for (Billing_Cash_Receipt__c billCash : (List<Billing_Cash_Receipt__c>) Database.query(theQuery.toSOQL())) {
                resultMap.put(billCash.Billing__c, billCash);
            }
        }

        return resultMap;
    }

    private static Map<Id, sObject> getRecordMapFromRecordList(List<sObject> records) {
        Map<Id, sObject> result = new Map<Id, sObject>();
        for (sObject eachRec : records) {
            result.put((Id)eachRec.get('Id'), eachRec);
        }
        return result;
    }

    private static List<Billing__c> getBillings(Cash_Receipt__c cashReceipt, 
                                                List<Id> childAccountIds, 
                                                Set<Id> appliedBillingIds,
                                                Integer maxResults, 
                                                String customerId, 
                                                String postingStatus, 
                                                String billingNumber,
                                                Date billingDateStart,
                                                Date billingDateEnd,
                                                Date dueDateStart,
                                                Date dueDateEnd,
                                                Decimal billingAmountStart,
                                                Decimal billingAmountEnd) {
        String billingNumberValue = '%' + billingNumber + '%';        
        String ledgerId = cashReceipt.Ledger__c;
        Boolean isEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(ledgerId);
        String currencyIsoCode;
        if (IS_MULTI_CURRENCY_ENABLED) {
            currencyIsoCode = (String) cashReceipt.get('CurrencyIsoCode');
        }

        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Proprietary_Billing_Number__c',
            'Name',
            'Date__c',
            'Type__c',
            'Status__c',
            'Total__c',
            'Balance__c',
            'Ledger__c',
            'Discount_Percent__c',
            'Cash_Application_Adjustment_Amount__c',
            'Credit_Memo_Applied_Amount__c',
            'Received_Amount__c',
            'Customer__c',
            'Customer__r.Name',
            'Accounting_Period__c',
            'Accounting_Period__r.Status__c',
            'Accounting_Period__r.Name', 
            'Accounting_Period__r.Close_AR__c', 
            'Accounting_Period__r.Close_AP__c', 
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.End_Date__c',
            'Currency_Conversion_Rate__c',
            'Discount_Due_Date__c',
            'Discount_Amount__c'
        };

        if (!fieldNames.isEmpty()){
            for (String fieldName : fieldNames){
                queryFields.add(fieldName);
            }
        }

        //set query condition
        String queryCondition =
            'Type__c = \'Invoice\' ' +
                'AND (Balance__c > 0 OR Id IN :appliedBillingIds) ' +
                (
                    (IS_MULTI_CURRENCY_ENABLED == true)
                        ?
                        ' AND CurrencyIsoCode = :currencyIsoCode '                            
                        :
                        ' '
                ) +
                'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
                (isEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
                (!isEqualLegacyLedger ? ') ' : ' ');
        if (!string.isEmpty(customerId)) {
            queryCondition += ' AND (Customer__c = :customerId OR Customer__c IN :childAccountIds)';
        }
        if (postingStatus != 'All') {
            queryCondition += ' AND Status__c = :postingStatus';
        }
        if (!string.isEmpty(billingNumber)) {
            queryCondition += ' AND (' + PACKAGE_QUALIFIER + 'Proprietary_Billing_Number__c like :billingNumberValue OR Name like :billingNumberValue)'; 
        }
        if (billingDateStart != NULL) {
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c >= :billingDateStart';
        }
        if (billingDateEnd != NULL) {
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c <= :billingDateEnd';
        }
        if (dueDateStart != NULL) {
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Due_Date2__c >= :dueDateStart';
        }
        if (dueDateEnd != NULL) {
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Due_Date2__c <= :dueDateEnd';
        }
        if (billingAmountStart != NULL) {
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Total__c >= :billingAmountStart';
        }
        if (billingAmountEnd != NULL) {
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Total__c <= :billingAmountEnd';
        }
        queryCondition += ' LIMIT :maxResults';
        
        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);
        return Database.query(theQuery.toSOQL());
    }

    private static List<BillingWrapper> createBillingWrappers(Cash_Receipt__c cashReceipt, List<Billing__c> billings, Map<Id, Billing_Cash_Receipt__c> relatedCashReceipts) {
        List<BillingWrapper> billingLines = new List<BillingWrapper>();
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();

        for (Billing__c billing : billings) {
            BillingWrapper billingLine;

            Date earliestAppliedDate = billing.Accounting_Period__r.Start_Date__c > cashReceipt.Accounting_Period__r.Start_Date__c ? 
                billing.Accounting_Period__r.Start_Date__c :
                cashReceipt.Accounting_Period__r.Start_Date__c;
            Date appliedDate = Date.today() < earliestAppliedDate ?
                earliestAppliedDate :
                Date.today();
            
            List<Accounting_Period__c> nextPeriods = new List<Accounting_Period__c>();     
            Accounting_Period__c periodByAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(appliedDate);
            if (periodByAppliedDate == null) {
                periodByAppliedDate = acctPeriodHandler.getFirstOpenedPeriod(Billing__c.sObjectType);
            }
            if (!AccountingPeriod.isPeriodOpen(periodByAppliedDate, Billing__c.sObjectType)) {
                nextPeriods = acctPeriodHandler.getNextAccountingPeriods(periodByAppliedDate, new Set<String>{OPEN_STATUS}, Billing__c.sObjectType);
                
                // if to make sure that if next accounting is open then only process further
                if(nextPeriods.size() > 0){
                    periodByAppliedDate = nextPeriods[0];
                    appliedDate = periodByAppliedDate.Start_Date__c;
                }
            }
            
            if (!relatedCashReceipts.containsKey(billing.Id)) {
                Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = cashReceipt.Id,
                    Billing__c = billing.Id
                );
                bcr.Applied_Date__c = appliedDate;                
                bcr.Accounting_Period__c = periodByAppliedDate.Id;                
                billingLine = new BillingWrapper(billing, bcr, periodByAppliedDate.Name, (!(AccountingPeriod.isPeriodOpen(periodByAppliedDate, Billing_Cash_Receipt__c.sObjectType))), cashReceipt);
            } else {
                Billing_Cash_Receipt__c bcr = relatedCashReceipts.get(billing.Id);
                billingLine = new BillingWrapper(billing, bcr, bcr.Accounting_Period__r.Name, (!(AccountingPeriod.isPeriodOpen(bcr.Accounting_Period__r, Billing_Cash_Receipt__c.sObjectType))), cashReceipt);
            }

            billingLines.add(billingLine);
        }

        return billingLines;
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