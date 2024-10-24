public with sharing class BillingApplyCreditMemoHelper {

    private static final Integer SOQL_RECORD_LIMIT = 10000;
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    @TestVisible
    private static final String CREDIT_MEMO_MODIFIED_ERROR = Label.ERR_BILLING_CREDIT_MEMO_MODIFIED;
    @TestVisible
    private static final String APPLIED_DATE_INVALID = Label.ERR_BILLING_APPLIED_DATE;
    private static final String POSTED_STATUS = 'Posted';
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
        public Billing__c creditMemo;
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
        public Decimal variableCredit;
        @AuraEnabled
        public Boolean isMultiCurrencyEnabled;
        @AuraEnabled
        public Map<String, Object> extraFields;

        public InvoiceWrapper(Billing__c invoice, Billing_Credit_Memo__c billingCreditMemo, Date earliestAppliedDate, Boolean isPeriodClosed) {
            this.appliedDate = billingCreditMemo.Applied_Date__c;
            this.earliestAppliedDate = earliestAppliedDate;
            this.isClosed = isPeriodClosed;
            this.billingDate = invoice.Date__c;
            this.name = invoice.Name;
            this.proprietaryName = invoice.Proprietary_Billing_Number__c;
            this.billingId = invoice.Id;
            this.customerName = invoice.Customer__r.Name;
            this.customerId = invoice.Customer__c;
            this.customerURL = '/lightning/r/' + this.customerId + '/view';
            // the credit from `billingCreditMemo` already applied to `billing` which the user can edit
            this.variableCredit = convertNullToZero(billingCreditMemo.Amount__c) * -1;
            this.total = scaleHalfUp(convertNullToZero(invoice.Total__c));
            this.balance = scaleHalfUp(convertNullToZero(invoice.Balance__c));
            this.applied = scaleHalfUp(
                      convertNullToZero(invoice.Cash_Application_Adjustment_Amount__c)
                    + convertNullToZero(invoice.Credit_Memo_Applied_Amount__c)
                    + convertNullToZero(invoice.Received_Amount__c)
            );

            this.extraFields = FieldSetUtils.getFieldSetData(fieldSetData, invoice);           
        }
    }

    public class SaveItem {
        public String billingId;
        public String derivedName;
        public Date appliedDate;
        public Decimal variableCredit;
    }

    public class InvoiceFilter {
        public String customerId;
        public String postingStatus;
        public String billingNumber;
        public Date billingDateStart;
        public Date billingDateEnd;
        public Date dueDateStart;
        public Date dueDateEnd;
        public Decimal billingAmountStart;
        public Decimal billingAmountEnd;
    }

    public class ExceptionData {
        public String code;
        public String message;
    }

    @AuraEnabled
    public static CombinedInfoWrapper getCombinedInfo(String forBillingId, Integer maxInvoices, String filterBy) {
        CombinedInfoWrapper wrapper = new CombinedInfoWrapper();
        try {
            wrapper.isMultiCurrencyEnabled = IS_MULTI_CURRENCY_ENABLED;
            wrapper.creditMemo = getCreditMemo(forBillingId);
            wrapper.columns = getExtraColumnsHelper();
            if  (String.isEmpty(filterBy)) {
                InvoiceFilter filter = new InvoiceFilter();
                filter.customerId = wrapper.creditMemo.Customer__r.Id;
                filter.postingStatus = POSTED_STATUS;
                wrapper.invoices = getApplicableInvoicesHelper(forBillingId, maxInvoices, filter);
            } else {
                wrapper.invoices = getApplicableInvoices(forBillingId, maxInvoices, filterBy);
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
    public static List<InvoiceWrapper> getApplicableInvoices(String forBillingId, Integer maxInvoices, String filterBy) {
        List<InvoiceWrapper> results;
        try {
            InvoiceFilter filter = (InvoiceFilter) deserialize(filterBy, InvoiceFilter.class);
            results = getApplicableInvoicesHelper(forBillingId, maxInvoices, filter);
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
            Map<Id,Billing_Credit_Memo__c> invoiceToOldBCMs = getOldBCMs(creditMemoId, saveItems);
            Map<Id,Billing_Credit_Memo__c> invoiceToNewBCMs = createNewBCMs(creditMemoId, invoiceToOldBCMs, saveItems);

            saveHelper(invoiceToOldBCMs, invoiceToNewBCMs);
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

    private static List<InvoiceWrapper> getApplicableInvoicesHelper(String forBillingId, Integer maxInvoices, InvoiceFilter filter) {
        getExtraColumnsHelper();

        // get Billing__c (credit memo)
        Billing__c creditMemo = getBilling(forBillingId);
        creditMemo.Ledger__c = creditMemo.Ledger__c != NULL ? creditMemo.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();

        // get child accounts for customer
        List<Id> childAccountIds;
        if (String.isNotEmpty(filter.customerId)) {
            childAccountIds = getChildAccounts(filter.customerId);
        } 

        // get existing Billing_Credit_Memo__c that are related to the Billing__c (credit memo)
        Map<Id, Billing_Credit_Memo__c> relatedCreditMemos = getBillingCreditMemos(creditMemo.Id);

        // get applicable Billing__c to credit
        List<Billing__c> billings = getBillings(creditMemo, childAccountIds, relatedCreditMemos.keySet(), maxInvoices, filter);

        // gather and return display info
        return createInvoiceWrappers(creditMemo, billings, relatedCreditMemos);
    }

    private static void initFieldSetData() {
        List<String> ignoredFields = new List<String>{ 
            'Name'
        };
        
        fieldSetData = FieldSetUtils.getColumnsFromFieldSet(
            PACKAGE_QUALIFIER + 'Billing__c', 
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

    private static Object deserialize(String jsonStr, Type t) {
        String s = String.isBlank(jsonStr) ? '{}' : jsonStr;
        return JSON.deserialize(s, t);
    }

    private static void saveHelper(Map<Id,Billing_Credit_Memo__c> oldBCMs, Map<Id,Billing_Credit_Memo__c> newBCMs) {
        List<Billing_Credit_Memo__c> inserts = new List<Billing_Credit_Memo__c>();
        List<Billing_Credit_Memo__c> deletes = new List<Billing_Credit_Memo__c>();

        // determine inserts + deletes
        Billing_Credit_Memo__c oldBCM, newBCM;
        for (Id key : newBCMs.keySet()) {
            oldBCM = oldBCMs.get(key);
            newBCM = newBCMs.get(key);

            if (isDelete(oldBCM, newBCM)) { 
                deletes.add(oldBCM); 
            } else if (isUpdate(oldBCM, newBCM)) {
                inserts.add(newBCM);
                deletes.add(oldBCM); 
            } else if (isInsert(oldBCM, newBCM)) {
                inserts.add(newBCM);
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            SFDCSecurityUtils.deleteProxy(deletes);
            SFDCSecurityUtils.insertCheckCRUDAndFLS(inserts, new List<String>{
                    'Amount__c',
                    'Billing_Credit_Memo__c',
                    'Billing_Invoice__c',
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

    private static Boolean isInsert(Billing_Credit_Memo__c oldBCM, Billing_Credit_Memo__c newBCM) {
        return ( oldBCM == null && newBCM != null && getCreditAmount(newBCM) != 0 );
    }

    private static Boolean isUpdate(Billing_Credit_Memo__c oldBCM, Billing_Credit_Memo__c newBCM) {
        return (
            oldBCM != null 
            && ( 
                getCreditAmount(oldBCM) != getCreditAmount(newBCM)
                || oldBCM.Applied_Date__c != newBCM.Applied_Date__c 
            )
        );
    }

    private static Boolean isDelete(Billing_Credit_Memo__c oldBCM, Billing_Credit_Memo__c newBCM) {
        return ( oldBCM != null && getCreditAmount(newBCM) == 0 );
    }

    private static void validateLastModifiedDate(Id creditMemoId, DateTime creditMemoLastModifiedDate) {
        Billing__c creditMemo = DomainUtils.getBillingsById(new Set<Id> { creditMemoId })[0];
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

    private static Decimal getCreditAmount(Billing_Credit_Memo__c bcm) {
            return (bcm == null || bcm.Amount__c == null) ? 0 : bcm.Amount__c;
    }

   private static Map<Id,Billing_Credit_Memo__c> getOldBCMs(Id creditMemoId, List<SaveItem> updates) {
        Set<Id> invoiceIds = new Set<Id>(); 
        for (SaveItem item : updates) {
            invoiceIds.add(item.billingId);
        }

        List<String> queryFields = new List<String> {
            'Id',
            'Amount__c',
            'Billing_Invoice__c',
            'Accounting_Period__c',
            'Applied_Date__c'
        };

        String queryCondition = 
            'Billing_Invoice__c IN :invoiceIds ' + 
            'AND Billing_Credit_Memo__c = :creditMemoId ' + 
            'LIMIT :SOQL_RECORD_LIMIT';

        SOQLBuilder theQuery = new SOQLBuilder(Billing_Credit_Memo__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        List<Billing_Credit_Memo__c> bcms = (List<Billing_Credit_Memo__c>) Database.query(theQuery.toSOQL());

        Map<Id,Billing_Credit_Memo__c> results = new Map<Id,Billing_Credit_Memo__c>(); 
        for (Billing_Credit_Memo__c bcm : bcms) {
            results.put(bcm.Billing_Invoice__c, bcm);
        }

        return results;
    }

    private static Map<Id,Billing_Credit_Memo__c> createNewBCMs(Id creditMemoId, Map<Id,Billing_Credit_Memo__c> oldBCMs, List<SaveItem> updates) {
        Map<Id,Billing_Credit_Memo__c> results = new Map<Id,Billing_Credit_Memo__c>();
        
        Billing_Credit_Memo__c oldBCM;
        for (SaveItem item : updates) {
            Id period = getAccountingPeriod(item);
            Billing_Credit_Memo__c newBCM;
            oldBCM = oldBCMs.get(item.billingId);
            if (oldBCM == null) {
                newBCM = new Billing_Credit_Memo__c(
                    Amount__c = scaleHalfUp(convertNullToZero(item.variableCredit)) * -1,
                    Applied_Date__c = item.appliedDate,
                    Accounting_Period__c = period,
                    Billing_Invoice__c = item.billingId,
                    Billing_Credit_Memo__c = creditMemoId
                ); 
            } else {
                newBCM = oldBCM.clone(false, true);
                newBCM.Billing_Credit_Memo__c = creditMemoId;
                newBCM.Applied_Date__c = item.appliedDate;
                newBCM.Accounting_Period__c = period;
                newBCM.Amount__c = scaleHalfUp(convertNullToZero(item.variableCredit)) * -1;
            }
            results.put(newBCM.Billing_Invoice__c, newBCM);
        }

        return results;
    }

   private static Id getAccountingPeriod(SaveItem item) {
        Accounting_Period__c period = AccountingPeriodHandler.getInstance()
            .getAccountingPeriodByDateAndStatus(item.appliedDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Billing__c.sObjectType);
        if (period == null) {
                String msg = String.format(APPLIED_DATE_INVALID, new String[] { item.derivedName });
                throw buildException(ExceptionCode.VALIDATION, msg);
        }
        return period.Id;
   }

    @TestVisible
    private static List<InvoiceWrapper> createInvoiceWrappers(
            Billing__c creditMemo, 
            List<Billing__c> invoices, 
            Map<Id, Billing_Credit_Memo__c> relatedCreditMemos) {
        
        List<InvoiceWrapper> billingLines = new List<InvoiceWrapper>();
        AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();

        for (Billing__c invoice : invoices) {
            InvoiceWrapper billingLine;

            Date earliestAppliedDate = invoice.Accounting_Period__r.Start_Date__c > creditMemo.Accounting_Period__r.Start_Date__c 
                ? invoice.Accounting_Period__r.Start_Date__c 
                : creditMemo.Accounting_Period__r.Start_Date__c;

            Accounting_Period__c periodByEarliestAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(earliestAppliedDate);
            if (periodByEarliestAppliedDate == null) {
                periodByEarliestAppliedDate = acctPeriodHandler.getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(new Set<Id> {
                    invoice.Accounting_Period__c,
                    creditMemo.Accounting_Period__c
                });
                earliestAppliedDate = periodByEarliestAppliedDate.Start_Date__c;
            }
            if (!AccountingPeriod.isPeriodOpen(periodByEarliestAppliedDate, Billing__c.sObjectType)) {
                periodByEarliestAppliedDate = acctPeriodHandler.getNextAccountingPeriods(periodByEarliestAppliedDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Billing__c.sObjectType)[0];
                earliestAppliedDate = periodByEarliestAppliedDate.Start_Date__c;
            }

            // if a bcm already exists
            if (relatedCreditMemos.containsKey(invoice.Id)) {
                Billing_Credit_Memo__c bcm = relatedCreditMemos.get(invoice.Id);
                if (bcm.Applied_Date__c == null) {
                    bcm.Applied_Date__c = bcm.Accounting_Period__r.Start_Date__c;
                }
                billingLine = new InvoiceWrapper(
                    invoice, 
                    bcm, 
                    earliestAppliedDate,
                    (!AccountingPeriod.isPeriodOpen(bcm.Accounting_Period__r, Billing_Credit_Memo__c.sObjectType)));
            // if a bcm does not already exist
            } else {
                Date defaultAppliedDate = Date.today() < earliestAppliedDate
                ? earliestAppliedDate
                : Date.today();

                Accounting_Period__c periodByDefaultAppliedDate = acctPeriodHandler.getAccountingPeriodByDate(defaultAppliedDate);
                if (periodByDefaultAppliedDate == null) {
                    periodByDefaultAppliedDate = acctPeriodHandler.getMostRecentOpenAccPeriodFromCollectionOrFirstOpen(new Set<Id> {
                        invoice.Accounting_Period__c,
                        creditMemo.Accounting_Period__c
                    });
                    defaultAppliedDate = periodByDefaultAppliedDate.Start_Date__c;
                }
                if (!AccountingPeriod.isPeriodOpen(periodByDefaultAppliedDate, Billing__c.sObjectType)) {
                    periodByDefaultAppliedDate = acctPeriodHandler.getNextAccountingPeriods(periodByDefaultAppliedDate, new Set<String>{AccountingPeriodActions.OPEN_STATUS}, Billing__c.sObjectType)[0];
                    defaultAppliedDate = periodByDefaultAppliedDate.Start_Date__c;
                }

                Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                    Billing_Credit_Memo__c = creditMemo.Id,
                    Billing_Invoice__c = invoice.Id
                );
                bcm.Applied_Date__c = defaultAppliedDate;
                bcm.Accounting_Period__c = periodByDefaultAppliedDate.Id;
                billingLine = new InvoiceWrapper(
                    invoice, 
                    bcm, 
                    earliestAppliedDate,
                    (!AccountingPeriod.isPeriodOpen(periodByDefaultAppliedDate, Billing__c.sObjectType)));
            }
            billingLines.add(billingLine);
        }
        return billingLines;
    }

    private static List<Id> getChildAccounts(String customerId) {
        Map<Id, Account> childAccountsMap = new Map<Id, Account>(
            DomainUtils.getChildAccountsForGivenParent(customerId)
        );
        return new List<Id>(childAccountsMap.keySet());
    }

    private static Billing__c getCreditMemo(String billingId) {
        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'LastModifiedDate',
            'Type__c',
            'Status__c',
            'Total__c',
            'Credit_Memo_Applied_Amount__c',
            'Customer__r.Name',
            'Ledger__r.Name',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Close_AR__c',
            'Accounting_Period__r.Close_AP__c',
            'Proprietary_Billing_Number__c',
            'Date__c'
        };

        //add MC field
        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        //set query condition
        String queryCondition = 'Id = :billingId';

        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //Call DML operation
        List<Billing__c> results = (List<Billing__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }

    private static Billing__c  getBilling(String billingId) {
        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'Proprietary_Billing_Number__c',
            'Customer__c',
            'Customer__r.Name',
            'Total__c',
            'Credit_Memo_Applied_Amount__c',
            'Balance__c',
            'Currency_Conversion_Rate__c',
            'LastModifiedDate',
            'Ledger__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Start_Date__c',
            'Date__c'
        };

        //add MC field
        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        //set query condition
        String queryCondition = 'Id = :billingId';

        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Billing__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        //Call DML operation
        List<Billing__c> results = (List<Billing__c>) Database.query(theQuery.toSOQL());
        return (results.isEmpty()) ? NULL : results[0];
    }

    private static Map<Id, Billing_Credit_Memo__c> getBillingCreditMemos(String relatedToBillingId) {
        Map<Id, Billing_Credit_Memo__c> results = new Map<Id, Billing_Credit_Memo__c>();
        if (!String.isBlank(relatedToBillingId)) {
            //define fields to query
            List<String> queryFields = new List<String>{
                'Id',
                'Amount__c',
                'Applied_Date__c',
                'Billing_Invoice__c',
                'Billing_Invoice__r.Name',
                'Accounting_Period__c',
                'Accounting_Period__r.Name',
                'Accounting_Period__r.Start_Date__c',
                'Accounting_Period__r.End_Date__c',
                'Accounting_Period__r.Close_AR__c',
                'Accounting_Period__r.Close_AP__c',
                'Accounting_Period__r.Status__c'
            };

            //set query condition
            String queryCondition = 'Billing_Credit_Memo__c = :relatedToBillingId';
            SOQLBuilder theQuery = new SOQLBuilder(Billing_Credit_Memo__c.SObjectType);
            theQuery
                    .assertIsAccessible()
                    .setEnforceFLS(true)
                    .selectFields(queryFields)
                    .setCondition(queryCondition);
            for (Billing_Credit_Memo__c bcmLine : (List<Billing_Credit_Memo__c>) Database.query(theQuery.toSOQL())) {
                bcmLine.Amount__c = bcmLine.Amount__c;
                results.put(bcmLine.Billing_Invoice__c, bcmLine);
            }
        }
        return results;
    }

    private static List<Billing__c> getBillings(
            Billing__c creditMemo, 
            List<Id> childAccountIds, 
            set<Id> appliedBillingIds,
            Integer maxResults,
            InvoiceFilter filter) {
        String ledgerId = creditMemo.Ledger__c;
        Double currencyConversionRate = creditMemo.Currency_Conversion_Rate__c;
        Boolean isEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(ledgerId);
        String currencyIsoCode;
        if (IS_MULTI_CURRENCY_ENABLED) {
            currencyIsoCode = (String) creditMemo.get('CurrencyIsoCode');
        }

        //define fields to query
        List<String> queryFields = new List<String> {
            'Id',
            'Name',
            'Customer__c',
            'Customer__r.Name',
            'Proprietary_Billing_Number__c',
            'Type__c',
            'Date__c',
            'Total__c',
            'Received_Amount__c',
            'Balance__c',
            'Cash_Application_Adjustment_Amount__c',
            'Credit_Memo_Applied_Amount__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Start_Date__c',
            'Accounting_Period__r.Status__c'
        };

        list<string> fieldsetFieldList = new list<string>(getFieldSetFields(fieldSetData));
        if(fieldsetFieldList != null){
            queryFields.addAll(getFieldSetFields(fieldSetData));
        } 
        //set query condition
        String queryCondition =
            'Type__c = \'Invoice\' ' +
                'AND (Balance__c > 0 OR Id IN :appliedBillingIds) ' +
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

        if (String.isNotEmpty(filter.customerId)) {
            String customerId = filter.customerId;
            queryCondition += ' AND (Customer__c = :customerId OR Customer__c IN :childAccountIds)';
        }
        if (String.isNotEmpty(filter.postingStatus) && filter.postingStatus != 'All') {
            String postingStatus = filter.postingStatus;
            queryCondition += ' AND Status__c = :postingStatus';
        }
        if (String.isNotEmpty(filter.billingNumber)) {
            String billingNumber = '%' + filter.billingNumber + '%'; 
            queryCondition += ' AND (' + PACKAGE_QUALIFIER + 'Proprietary_Billing_Number__c like :billingNumber OR Name like :billingNumber)'; 
        }
        if (filter.billingDateStart != null) {
            Date billingDateStart = filter.billingDateStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c >= :billingDateStart';
        }
        if (filter.billingDateEnd != null) {
            Date billingDateEnd = filter.billingDateEnd;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Date__c <= :billingDateEnd';
        }
        if (filter.dueDateStart != null) {
            Date dueDateStart = filter.dueDateStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Due_Date2__c >= :dueDateStart';
        }
        if (filter.dueDateEnd != null) {
            Date dueDateEnd = filter.dueDateEnd;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Due_Date2__c <= :dueDateEnd';
        }
        if (filter.billingAmountStart != null) {
            Decimal billingAmountStart = filter.billingAmountStart;
            queryCondition += ' AND ' + PACKAGE_QUALIFIER + 'Total__c >= :billingAmountStart';
        }
        if (filter.billingAmountEnd != null) {
            Decimal billingAmountEnd = filter.billingAmountEnd;
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

}