public with sharing class PayableApplyCreditMemoHelper {

    private static final Integer SOQL_RECORD_LIMIT = 100;
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    @TestVisible
    private static final String CREDIT_MEMO_MODIFIED_ERROR = Label.ERR_CREDIT_MEMO_MODIFIED;
    @TestVisible
    private static final String APPLIED_DATE_INVALID = Label.ERR_APPLIED_DATE_INVALID;
    private static final String POSTED_STATUS = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
    private static final Map<ExceptionCode,String> codeTranslations = new Map<ExceptionCode,String> {
        ExceptionCode.DML => 'DML',
        ExceptionCode.CRUD_FLS_WRITE => 'CRUD_FLS_WRITE',
        ExceptionCode.CRUD_FLS_READ => 'CRUD_FLS_READ',
        ExceptionCode.WRITE_CONFLICT => 'WRITE_CONFLICT',
        ExceptionCode.VALIDATION => 'VALIDATION',
        ExceptionCode.UNKNOWN => 'UNKNOWN'
    };
    private enum ExceptionCode { DML, CRUD_FLS_WRITE, CRUD_FLS_READ, WRITE_CONFLICT, VALIDATION, UNKNOWN }

    private static Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    private static FieldSetUtils.DataTableResponse fieldSetData;

    public class CombinedInfoWrapper {
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled;
        @AuraEnabled
        public Account_Payable__c creditMemo;
        @AuraEnabled
        public List<InvoiceWrapper> invoices;
        @AuraEnabled
        public ExtraColumnsWrapper columns;
    }

    public class ExtraColumnsWrapper {
        @AuraEnabled
        public List<String> extraColumns;

        public ExtraColumnsWrapper() {
            this.extraColumns = serializeFieldSetCols(fieldSetData);            
        }
    }

    public class InvoiceWrapper {
        @AuraEnabled
        public Date appliedDate;
        @AuraEnabled
        public String payeeReference;
        @AuraEnabled
        public Date earliestAppliedDate;
        @AuraEnabled
        public String customerName;
        @AuraEnabled
        public Id customerId;
        @AuraEnabled
        public String customerURL;
        @AuraEnabled
        public Boolean isClosed;
        @AuraEnabled
        public Date payableDate;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String proprietaryName;
        @AuraEnabled
        public String payableId;
        @AuraEnabled
        public Boolean onHold;
        @AuraEnabled
        public Decimal total;
        @AuraEnabled
        public Decimal applied;
        @AuraEnabled
        public Decimal balance;
        @AuraEnabled
        public Decimal variableCredit;
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled;
        @AuraEnabled
        public Map<String, Object> extraFields;

        public InvoiceWrapper(Account_Payable__c invoice, AP_Credit_Memo__c payableCreditMemo, Date earliestAppliedDate, Boolean isPeriodClosed) {
            this.appliedDate = payableCreditMemo.Applied_Date__c;
            this.earliestAppliedDate = earliestAppliedDate;
            this.isClosed = isPeriodClosed;
            this.payableDate = invoice.Date__c;
            this.name = invoice.Name;
            this.payeeReference = invoice.Payee_Reference__c;
            this.proprietaryName = invoice.Proprietary_payable_Number__c;
            this.payableId = invoice.Id;
            this.OnHold = invoice.On_Hold__c;
            this.customerName = invoice.Vendor__r.Name;
            this.customerId = invoice.Vendor__c;
            this.customerURL = '/lightning/r/' + this.customerId + '/view';
            // the credit from `payableCreditMemo` already applied to `payable` which the user can edit
            this.variableCredit = convertNullToZero(payableCreditMemo.Amount__c) * -1;
            this.total = scaleHalfUp(convertNullToZero(invoice.Total__c));
            this.balance = scaleHalfUp(convertNullToZero(invoice.Balance__c));
            this.applied = scaleHalfUp(
                      convertNullToZero(invoice.Paid_Amount__c)
                    + convertNullToZero(invoice.Credit_Memo_Applied_Amount__c)
            );

            // field set data
            this.extraFields = getFieldSetFields(fieldSetData, invoice);            
        }
    }

    public class SaveItem {
        public String payableId;
        public String derivedName;
        public Date appliedDate;
        public Decimal variableCredit;
    }

    public class InvoiceFilter {
        public String vendorId;
        public String contactId;
        public String userId;
        public String postingStatus;
        public String payableNumber;
        public String payeeReference;
        public Date issueDateStart;
        public Date issueDateEnd;
        public Date dueDateStart;
        public Date dueDateEnd;
        public Decimal payableAmountStart;
        public Decimal payableAmountEnd;
    }

    public class ExceptionData {
        public String code;
        public String message;
    }

    @AuraEnabled
    public static CombinedInfoWrapper getCombinedInfo(String forpayableId, Integer maxInvoices, String filterBy) {
        CombinedInfoWrapper wrapper = new CombinedInfoWrapper();
        try {
            wrapper.isMultiCurrencyEnabled = IS_MULTI_CURRENCY_ENABLED;
            wrapper.creditMemo = getCreditMemo(forpayableId);
            wrapper.columns = getExtraColumnsHelper();
            Id vendorId = wrapper.creditMemo.Vendor__c;
            Id contactId = wrapper.creditMemo.Contact__c;
            Id employeeId = wrapper.creditMemo.Employee__c;
            if  (String.isEmpty(filterBy)) {
                InvoiceFilter filter = new InvoiceFilter();
                filter.vendorId = vendorId;
                filter.contactId = contactId;
                filter.userId = employeeId;
                filter.postingStatus = POSTED_STATUS;
                wrapper.invoices = getApplicableInvoicesHelper(forpayableId, maxInvoices, filter);
            } else {
                wrapper.invoices = getApplicableInvoices(forpayableId, maxInvoices, filterBy);
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
    public static List<InvoiceWrapper> getApplicableInvoices(String forPayableId, Integer maxInvoices, String filterBy) {
        List<InvoiceWrapper> results;
        try {
            InvoiceFilter filter = (InvoiceFilter) deserialize(filterBy, InvoiceFilter.class);
            results = getApplicableInvoicesHelper(forPayableId, maxInvoices, filter);
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_READ, ex.getMessage());
        } catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
        return results;
    }

   @AuraEnabled
    public static void save(Id creditMemoId, DateTime creditMemoLastModifiedDate, List<String> updates) {
        try {
            validateLastModifiedDate(creditMemoId, creditMemoLastModifiedDate);
           
            List<SaveItem> saveItems = deserializeSaveItems(updates);
            Map<Id,AP_Credit_Memo__c> invoiceToOldPCMs = getOldPCMs(creditMemoId, saveItems);
            Map<Id,AP_Credit_Memo__c> invoiceToNewPCMs = createNewPCMs(creditMemoId, invoiceToOldPCMs, saveItems);

            saveHelper(invoiceToOldPCMs, invoiceToNewPCMs);
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_WRITE, ex.getMessage());
        } catch (Exception ex) {
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        }
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

    private static ExtraColumnsWrapper getExtraColumnsHelper() {
        initFieldSetData();
        return new ExtraColumnsWrapper();
    }

    private static List<InvoiceWrapper> getApplicableInvoicesHelper(String forPayableId, Integer maxInvoices, InvoiceFilter filter) {
        getExtraColumnsHelper();

        // get payable__c (credit memo)
        Account_Payable__c creditMemo = getPayable(forPayableId);
        creditMemo.Ledger__c = creditMemo.Ledger__c != NULL ? creditMemo.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();

        // get existing AP_Credit_Memo__c that are related to the payable__c (credit memo)
        Map<Id, AP_Credit_Memo__c> relatedCreditMemos = getPayableCreditMemos(creditMemo.Id);

        // get applicable payable__c to credit
        List<Account_Payable__c> payables = getPayables(creditMemo, relatedCreditMemos.keySet(), maxInvoices, filter);

        // gather and return display info
        return createInvoiceWrappers(creditMemo, payables, relatedCreditMemos);
    }

    private static void initFieldSetData() {
        List<String> ignoredFields = new List<String>{ 
            'Name'
        };
        
        fieldSetData = FieldSetUtils.getColumnsFromFieldSet(
            PACKAGE_QUALIFIER + 'Account_Payable__c', 
            PACKAGE_QUALIFIER + 'CreditMemoApply', 
            ignoredFields
        );
    }

    private static List<String> getFieldSetFields(FieldSetUtils.DataTableResponse fieldSet) {
        List<String> fields = new List<String>();
        if (fieldSetData != null && !fieldSetData.fieldNames.isEmpty()){
            fields.addAll(fieldSetData.fieldNames);
        }
        return fields;
    }

    private static List<String> serializeFieldSetCols(FieldSetUtils.DataTableResponse fieldSet) {
        List<String> cols = new List<String>();
        if (fieldSet != null) {
            for (FieldSetUtils.DataTableColumns dtc : fieldSet.dataTableColumns) {
                cols.add(JSON.serialize(dtc, true));
            }
        }
        return cols;
    }

    private static Map<String, Object> getFieldSetFields(FieldSetUtils.DataTableResponse fieldSet, Account_Payable__c invoice) {
        Map<String, Object> extraFields = new Map<String, Object>();
        if (fieldSet != null && !fieldSet.fieldNames.isEmpty()) {
            List<String> referencedFields = new List<String>();            
            for(String fieldName : fieldSet.fieldNames){                
                if (fieldName.contains('__r')) {
                    if (invoice.getSobject(fieldName.left(fieldName.indexOf('__r')+3)) != null) {
                        extraFields.put(fieldName, (String)invoice.getSobject(fieldName.left(fieldName.indexOf('__r')+3)).get('Name'));  
                        referencedFields.add(fieldName.left(fieldName.indexOf('__r')+3).replaceAll('__r$', '__c'));
                    }                                                    
                }
                else if (fieldName.contains('.')) {
                    if (invoice.getSobject(fieldName.left(fieldName.indexOf('.'))) != NULL) {
                        extraFields.put(fieldName, (String)invoice.getSobject(fieldName.left(fieldName.indexOf('.'))).get('Name'));  
                        referencedFields.add(fieldName.left(fieldName.indexOf('.'))+ 'Id');                                                    
                    }
                }
                else {
                    extraFields.put(fieldName, invoice.get(fieldName));                
                }
            }
            for (String fieldName : extraFields.keySet()) {
                if (referencedFields.contains(fieldName)) {
                    extraFields.put(fieldName, '/lightning/r/' + extraFields.get(fieldName) + '/view');
                }
            }
        }
        return extraFields;
    }

    private static Object deserialize(String jsonStr, Type t) {
        String s = String.isBlank(jsonStr) ? '{}' : jsonStr;
        return JSON.deserialize(s, t);
    }

    private static void saveHelper(Map<Id,AP_Credit_Memo__c> oldPCMs, Map<Id,AP_Credit_Memo__c> newPCMs) {
        List<AP_Credit_Memo__c> inserts = new List<AP_Credit_Memo__c>();
        List<AP_Credit_Memo__c> deletes = new List<AP_Credit_Memo__c>();

        // determine inserts + deletes
        AP_Credit_Memo__c oldPCM, newPCM;
        for (Id key : newPCMs.keySet()) {
            oldPCM = oldPCMs.get(key);
            newPCM = newPCMs.get(key);

            if (isDelete(oldPCM, newPCM)) {
                deletes.add(oldPCM);
            } else if (isUpdate(oldPCM, newPCM)) {
                inserts.add(newPCM);
                deletes.add(oldPCM);
            } else if (isInsert(oldPCM, newPCM)) {
                inserts.add(newPCM);
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            SFDCSecurityUtils.deleteProxy(deletes);
            SFDCSecurityUtils.insertCheckCRUDAndFLS(inserts, new List<String>{
                    'Amount__c',
                    'Account_Payable_Credit_Memo__c',
                    'Account_Payable_Invoice__c',
                    'Accounting_Period__c'
            });
        } catch (DMLException ex) {
            Database.rollback(sp);
            throw buildException(ExceptionCode.DML, getDMLExceptionMessages(ex));
        } catch (SFDCSecurityUtils.SecurityException ex) {
            throw buildException(ExceptionCode.CRUD_FLS_WRITE, ex.getMessage());
        } catch (Exception ex) {
            Database.rollback(sp);
            throw buildException(ExceptionCode.UNKNOWN, ex.getMessage());
        } 
    }

    private static String getDMLExceptionMessages(DMLException ex) {
        String msg = '';
        Integer numErrors = ex.getNumDml();
        for(Integer i=0; i<numErrors; i++) {
            if (i + 1 < numErrors) {
                msg += '\n';
            }
            msg += ex.getDmlMessage(i);
        }
        return msg;
    }

    private static Boolean isInsert(AP_Credit_Memo__c oldPCM, AP_Credit_Memo__c newPCM) {
        return ( oldPCM == null && newPCM != null && getCreditAmount(newPCM) != 0 );
    }

    private static Boolean isUpdate(AP_Credit_Memo__c oldPCM, AP_Credit_Memo__c newPCM) {
        return (
            oldPCM != null
            && ( 
                getCreditAmount(oldPCM) != getCreditAmount(newPCM)
                || oldPCM.Applied_Date__c != newPCM.Applied_Date__c
            )
        );
    }

    private static Boolean isDelete(AP_Credit_Memo__c oldPCM, AP_Credit_Memo__c newPCM) {
        return ( oldPCM != null && getCreditAmount(newPCM) == 0 );
    }

    private static void validateLastModifiedDate(Id creditMemoId, DateTime creditMemoLastModifiedDate) {
        Account_Payable__c creditMemo = DomainUtils.getAccountPayablesById(new Set<Id> { creditMemoId })[0];
        if (creditMemo.LastModifiedDate != creditMemoLastModifiedDate) {
            throw buildException(ExceptionCode.WRITE_CONFLICT, CREDIT_MEMO_MODIFIED_ERROR);
        }
    }

    private static List<SaveItem> deserializeSaveItems(List<String> serializedSaveItems) {
        List<SaveItem> saveItems = new List<SaveItem>();
        for (String jsonData : serializedSaveItems) {
            SaveItem item = (SaveItem) JSON.deserialize(jsonData, SaveItem.class);
            saveItems.add(item);
        }
        return saveItems;
    }

    public static Decimal convertNullToZero(Decimal value) {
        return value != null ? value : 0;
    }

    public static Decimal scaleHalfUp(Decimal value) {
        return value.setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Decimal getCreditAmount(AP_Credit_Memo__c pcm) {
            return (pcm == null || pcm.Amount__c == null) ? 0 : pcm.Amount__c;
    }

   private static Map<Id,AP_Credit_Memo__c> getOldPCMs(Id creditMemoId, List<SaveItem> updates) {
        Set<Id> invoiceIds = new Set<Id>(); 
        for (SaveItem item : updates) {
            invoiceIds.add(item.payableId);
}

        List<String> queryFields = new List<String> {
            'Id',
            'Amount__c',
            'Account_Payable_Invoice__c',
            'Accounting_Period__c',
            'Applied_Date__c'
        };

        String queryCondition = 
            'Account_Payable_Invoice__c IN :invoiceIds ' + 
            'AND Account_Payable_Credit_Memo__c = :creditMemoId ' +
            'LIMIT :SOQL_RECORD_LIMIT';

        SOQLBuilder theQuery = new SOQLBuilder(AP_Credit_Memo__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        List<AP_Credit_Memo__c> pcms = (List<AP_Credit_Memo__c>) Database.query(theQuery.toSOQL());
        Map<Id,AP_Credit_Memo__c> results = new Map<Id,AP_Credit_Memo__c>(); 
        for (AP_Credit_Memo__c pcm : pcms) {
            results.put(pcm.Account_Payable_Invoice__c, pcm);
        }

        return results;
    }

    private static Map<Id,AP_Credit_Memo__c> createNewPCMs(Id creditMemoId, Map<Id,AP_Credit_Memo__c> oldPCMs, List<SaveItem> updates) {
        Map<Id,AP_Credit_Memo__c> results = new Map<Id,AP_Credit_Memo__c>();
        
        AP_Credit_Memo__c oldPCM;
        for (SaveItem item : updates) {
            AP_Credit_Memo__c newPCM;
            oldPCM = oldPCMs.get(item.payableId);
            if (oldPCM == null) {
                newPCM = new AP_Credit_Memo__c(
                    Amount__c = scaleHalfUp(convertNullToZero(item.variableCredit)) * -1,
                    Applied_Date__c = item.appliedDate,
                    Accounting_Period__c = getAccountingPeriod(item),
                    Account_Payable_Invoice__c = item.payableId,
                    Account_Payable_Credit_Memo__c = creditMemoId
                ); 
            } else {
                newPCM = oldPCM.clone(false, true);
                newPCM.Account_Payable_Credit_Memo__c = creditMemoId;
                newPCM.Applied_Date__c = item.appliedDate;
                newPCM.Accounting_Period__c = getAccountingPeriod(item);
                newPCM.Amount__c = scaleHalfUp(convertNullToZero(item.variableCredit)) * -1;
            }
            results.put(newPCM.Account_Payable_Invoice__c, newPCM);
        }

        return results;
    }

   private static Id getAccountingPeriod(SaveItem item) {
        Accounting_Period__c period = AccountingPeriodHandler.getInstance()
            .getAccountingPeriodByDateAndStatus(item.appliedDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, AP_Credit_Memo__c.sObjectType);
        if (period == null) {
                String msg = String.format(APPLIED_DATE_INVALID, new String[] { item.derivedName });
                throw buildException(ExceptionCode.VALIDATION, msg);
        }
        return period.Id;
   }

    @TestVisible
    private static List<InvoiceWrapper> createInvoiceWrappers(
        Account_Payable__c creditMemo, 
            List<Account_Payable__c> invoices, 
            Map<Id, AP_Credit_Memo__c> relatedCreditMemos) {
        List<InvoiceWrapper> payableLines = new List<InvoiceWrapper>();
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();

        for (Account_Payable__c invoice : invoices) {
            InvoiceWrapper payableLine;
            Date earliestAppliedDate = invoice.Accounting_Period__r.Start_Date__c > creditMemo.Accounting_Period__r.Start_Date__c 
                ? invoice.Accounting_Period__r.Start_Date__c 
                : creditMemo.Accounting_Period__r.Start_Date__c;

            List<Accounting_Period__c> nextPeriods = new List<Accounting_Period__c>();
            Accounting_Period__c periodByEarliestAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(earliestAppliedDate);
            if (periodByEarliestAppliedDate == null) {
                periodByEarliestAppliedDate = acctPeriodHandler.getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(new Set<Id> {
                    invoice.Accounting_Period__c,
                    creditMemo.Accounting_Period__c
                }, 
                Account_Payable__c.sObjectType);
                earliestAppliedDate = periodByEarliestAppliedDate.Start_Date__c;
            }
            if (!AccountingPeriod.isPeriodOpen(periodByEarliestAppliedDate, Account_Payable__c.sObjectType)) {
                nextPeriods = acctPeriodHandler.getNextAccountingPeriods(periodByEarliestAppliedDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Account_Payable__c.sObjectType);
               
                //if to make sure if there is next accounting periods which are open then only process further
                if(nextPeriods.size() > 0){
                    periodByEarliestAppliedDate = nextPeriods[0];
                    earliestAppliedDate = periodByEarliestAppliedDate.Start_Date__c;
                }  
            }
            // if a pcm already exists
            if (relatedCreditMemos.containsKey(invoice.Id)) {
                AP_Credit_Memo__c pcm = relatedCreditMemos.get(invoice.Id);
                if (pcm.Applied_Date__c == null) {
                    pcm.Applied_Date__c = pcm.Accounting_Period__r.Start_Date__c;
                }
                payableLine = new InvoiceWrapper(
                    invoice, 
                    pcm, 
                    earliestAppliedDate,
                    (!AccountingPeriodHandler.getInstance().isConsideredOpen(pcm.Accounting_Period__c, AP_Credit_Memo__c.sObjectType)));
            // if a pcm does not already exist
            } else {
                Date defaultAppliedDate = Date.today() < earliestAppliedDate
                ? earliestAppliedDate
                : Date.today();

                Accounting_Period__c periodByDefaultAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(defaultAppliedDate);
                if (periodByDefaultAppliedDate == null) {
                    periodByDefaultAppliedDate = acctPeriodHandler.getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(new Set<Id> {
                        invoice.Accounting_Period__c,
                        creditMemo.Accounting_Period__c
                    },
                    Account_Payable__c.sObjectType);
                    defaultAppliedDate = periodByDefaultAppliedDate.Start_Date__c;
                }
                if (!AccountingPeriod.isPeriodOpen(periodByDefaultAppliedDate, Account_Payable__c.sObjectType)) {
                    nextPeriods = acctPeriodHandler.getNextAccountingPeriods(periodByDefaultAppliedDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Account_Payable__c.sObjectType);
                    
                    //if to make sure if there is next accounting periods which are open then only process further
                    if(nextPeriods.size() > 0){
                        periodByDefaultAppliedDate = nextPeriods[0];
                        defaultAppliedDate = periodByDefaultAppliedDate.Start_Date__c;
                    } 
                }

                AP_Credit_Memo__c pcm = new AP_Credit_Memo__c(
                    Account_Payable_Credit_Memo__c = creditMemo.Id,
                    Account_Payable_Invoice__c = invoice.Id
                );
                pcm.Applied_Date__c = defaultAppliedDate;
                pcm.Accounting_Period__c = periodByDefaultAppliedDate.Id;
                payableLine = new InvoiceWrapper(
                    invoice, 
                    pcm, 
                    earliestAppliedDate,
                    (!AccountingPeriodHandler.getInstance().isConsideredOpen(pcm.Accounting_Period__c, AP_Credit_Memo__c.sObjectType)));
            }
            payableLines.add(payableLine);
        }
        return payableLines;
    }

    private static Account_Payable__c getCreditMemo(String payableId) {
        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'LastModifiedDate',
            'Type__c',
            'Status__c',
            'Total__c',
            'Payee_Reference__c',
            'Credit_Memo_Applied_Amount__c',
            'Vendor__r.Name',
            'Contact__r.Name',
            'Employee__r.Name',
            'Ledger__r.Name',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.Name',
            'Proprietary_payable_Number__c',
            'Date__c',
            'On_Hold__c'
        };

        //add MC field
        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        //set query condition
        String queryCondition = 'Id = :payableId';

        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //Call DML operation
        List<Account_Payable__c> results = (List<Account_Payable__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }

    private static Account_Payable__c getPayable(String payableId) {
        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'Proprietary_Payable_Number__c',
            'Payee_Reference__c',
            'Vendor__c',
            'Vendor__r.Name',
            'Contact__r.Name',
            'Employee__r.Name',
            'Total__c',
            'Net_Amount__c',
            'Credit_Memo_Applied_Amount__c',
            'Balance__c',
            'Currency_Conversion_Rate__c',
            'LastModifiedDate',
            'Ledger__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Start_Date__c',
            'Date__c',
            'On_Hold__c'
        };

        //add MC field
        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        //set query condition
        String queryCondition = 'Id = :payableId';

        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //Call DML operation
        List<Account_Payable__c> results = (List<Account_Payable__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }

    private static Map<Id, AP_Credit_Memo__c> getPayableCreditMemos(String relatedToPayableId) {
        Map<Id, AP_Credit_Memo__c> results = new Map<Id, AP_Credit_Memo__c>();
        if (!String.isBlank(relatedToPayableId)) {
            //define fields to query
            List<String> queryFields = new List<String>{
                'Id',
                'Amount__c',
                'Applied_Date__c',
                'Account_Payable_Invoice__c',
                'Account_Payable_Invoice__r.Name',
                'Account_Payable_Invoice__r.Payee_Reference__c',
                'Accounting_Period__c',
                'Accounting_Period__r.Name',
                'Accounting_Period__r.Start_Date__c',
                'Accounting_Period__r.End_Date__c',
                'Accounting_Period__r.Status__c'
            };

            //set query condition
            String queryCondition = 'Account_Payable_Credit_Memo__c = :relatedToPayableId';

            SOQLBuilder theQuery = new SOQLBuilder(AP_Credit_Memo__c.SObjectType);
            theQuery
                    .assertIsAccessible()
                    .setEnforceFLS(true)
                    .selectFields(queryFields)
                    .setCondition(queryCondition);

            for (AP_Credit_Memo__c pcmLine : (List<AP_Credit_Memo__c>) Database.query(theQuery.toSOQL())) {
                pcmLine.Amount__c = pcmLine.Amount__c;
                results.put(pcmLine.Account_Payable_Invoice__c, pcmLine);
            }
        }
        return results;
    }

    private static List<Account_Payable__c> getPayables(
            Account_Payable__c creditMemo, 
            set<Id> appliedPayableIds,
            Integer maxResults,
            InvoiceFilter filter) {
        String ledgerId = creditMemo.Ledger__c;
        Double currencyConversionRate = creditMemo.Currency_Conversion_Rate__c;
        Boolean isEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(ledgerId);
        String currencyIsoCode;
        String vendorID = creditMemo.Vendor__c;
        String contactId = creditMemo.Contact__c;
        String userId = creditMemo.Employee__c;

        if (IS_MULTI_CURRENCY_ENABLED) {
            currencyIsoCode = (String) creditMemo.get('CurrencyIsoCode');
        }

        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'Vendor__c',
            'Vendor__r.Name',
            'Proprietary_payable_Number__c',
            'Payee_Reference__c',
            'Type__c',
            'Date__c',
            'Total__c',
            'Paid_Amount__c',
            'Balance__c',
            'Credit_Memo_Applied_Amount__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.Status__c',
            'On_Hold__c'
        };

        queryFields.addAll(getFieldSetFields(fieldSetData));

        //set query condition
        String queryCondition =
            'Type__c = \'Invoice\' ' +
                'AND ((Balance__c > 0 AND (' +
                    (String.isNotEmpty(creditMemo.Vendor__c) ? ' Vendor__c = :vendorID' :
                    (String.isNotEmpty(creditMemo.Contact__c) ? ' (Contact__c = :contactId)' :
                    (String.isNotEmpty(creditMemo.Employee__c) ? ' (Employee__c = :userId)' : ''))) +
                ')) OR Id IN :appliedPayableIds) ' +
                ((IS_MULTI_CURRENCY_ENABLED == true)
                    ? ' AND CurrencyIsoCode = :currencyIsoCode ' +
                        ((currencyConversionRate != NULL)
                            ? ' AND ' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c = :currencyConversionRate '
                            //means that is legacy Credit Memo record and should be considered as a record with Base Currency and CCR = 1
                            : ' AND (' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c = :currencyConversionRate OR ' + PACKAGE_QUALIFIER + 'Currency_Conversion_Rate__c = 1) '
                        )
                    : ' '
                ) +
                'AND (' + PACKAGE_QUALIFIER + 'Ledger__c = :ledgerId' +
                (isEqualLegacyLedger ? ' OR ' + PACKAGE_QUALIFIER + 'Ledger__c = NULL) ' : ' ') +
                (!isEqualLegacyLedger ? ') ' : ' ');

        if (String.isNotEmpty(filter.postingStatus) && filter.postingStatus != 'All') {
            String postingStatus = filter.postingStatus;
            queryCondition += ' AND Status__c = :postingStatus';
        }
        if (String.isNotEmpty(filter.payableNumber)) {
            String payableNumber = '%' + filter.payableNumber + '%'; 
            queryCondition += ' AND (' + PACKAGE_QUALIFIER + 'Proprietary_payable_Number__c like :payableNumber OR Name like :payableNumber)'; 
        }
        if (String.isNotEmpty(filter.payeeReference)) {
            String payeeReference = '%' + filter.payeeReference + '%';
            queryCondition += ' AND (' + PACKAGE_QUALIFIER + 'Payee_Reference__c like :payeeReference)';
        }
        if (filter.issueDateStart != null) {
            Date issueDateStart = filter.issueDateStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c >= :issueDateStart';
        }
        if (filter.issueDateEnd != null) {
            Date issueDateEnd = filter.issueDateEnd;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c <= :issueDateEnd';
        }
        if (filter.dueDateStart != null) {
            Date dueDateStart = filter.dueDateStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Due_Date__c >= :dueDateStart';
        }
        if (filter.dueDateEnd != null) {
            Date dueDateEnd = filter.dueDateEnd;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Due_Date__c <= :dueDateEnd';
        }
        if (filter.payableAmountStart != null) {
            Decimal payableAmountStart = filter.payableAmountStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Total__c >= :payableAmountStart';
        }
        if (filter.payableAmountEnd != null) {
            Decimal payableAmountEnd = filter.payableAmountEnd;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Total__c <= :payableAmountEnd';
        }
        queryCondition += ' LIMIT :maxResults';

        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }
}