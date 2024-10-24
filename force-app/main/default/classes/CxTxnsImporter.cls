/**
 * Fetches transactions from cardknox for the specified payment processor.
 * Transactions are fetched and converted into sObjects.
 */
public with sharing class CxTxnsImporter {
    //constants
    public static final String NOT_STARTED = Label.COMMON_TASK_NOT_STARTED;  
    public static final String ERR_COULD_NOT_IMPORT_TRANSACTION = Label.ERR_COULD_NOT_IMPORT_TRANSACTION;
    public static final String TRANSACTION_FAILED_COMMENT = Label.TRANSACTION_FAILED_COMMENT;
    @TestVisible
    private static final String VOID_STATUS_CARDKNOX_VALUE = '1';
    // the maximum number of transactions to fetch from cardknox in a single call
    public static final Integer MAX_PAGE_SIZE = 1000;

    // the maximum number of days of data to fetch from cardknox in a single call
    public static final Integer MAX_REPORTING_DAYS = 99;

    // using CxClient allows mocking of static callouts in CardknoxService class
    private CxClient srvc;
    // transactions will be imported for this processor only
    private Payment_Processor__c processor;
    // logger to capture errors on an AJR
    private CxAJRLogger logger;

    public with sharing class CxTxnsImporterException extends Exception {}

    /**
     * processor - will import transactions for this processor only
     */
    public CxTxnsImporter(Payment_Processor__c processor, CxAJRLogger logger) {
        this.processor = processor;
        this.srvc = new CxClient();
        this.logger = logger;
    }

    /**
     * srvc - will use this service to fetch transactions, 
     *      useful for injecting mock service during testing
     * processor - will import transactions for this processor only
     */
    public CxTxnsImporter(CxClient srvc, Payment_Processor__c processor, CxAJRLogger logger) {
        this.processor = processor;
        this.srvc = srvc;
        this.logger = logger;
    }

    // holds source documents and related data for an imported transaction
    private with sharing class SrcDocs {
        public CardknoxService.ReportData txn;
        public Payment_Activity__c paymentActivity;
        public Payment_Method__c paymentMethod;
        public Cash_Receipt__c cashReceipt;
        public Billing_Cash_Receipt__c billingCashReceipt;
        public Transaction_Import_Error__c transactionImportError;
        public Billing__c invoice;
        public Id customerId;
        public Id ledgerId;

        public SrcDocs(CardknoxService.ReportData txn) {
            this.txn = txn;
        }
    }

    /**
     * Fetch the specified number of transactions from cardknox ignoring any
     * transactions previously imported. If any requried data is missing
     * error records will be created for those transactions. Otherwise
     * create source documents for each transaction. Save all source docs
     * (all or nothing mode).
     * 
     * The creation of error records does not constitue a true failure,
     * and the import will process what can returning the sync'd to datetime
     * as normal.
     * 
     * pageSize - number of transactions to fetch from cardknox.
     *      if null or invalid, will use MAX_PAGE_SIZE
     * startDate - fetch transactions from and including this date and time.
     * endDate - fetch transactions up until and including this date and time.
     * 
     * return Datetime - date transactions are sync'd until. If more txns exist 
     *     the datetime is less than the endDate, there are more pages of data 
     *     to import; re-run using the returned Datetime as the new startDate.
     */
    public Datetime import(Integer pageSize, Datetime startDate, Datetime endDate) {
        // check valid page size
        if (pageSize == null || pageSize < 1 || pageSize > MAX_PAGE_SIZE) {
            // default to max page size if invalid
            pageSize = MAX_PAGE_SIZE;
        }
        // check valid date range
        if (startdate == null || endDate == null || startDate > endDate || startDate.date().daysBetween(endDate.date()) > MAX_REPORTING_DAYS) {
            logger.logError(processor.Id, Label.ERR_PMT_IMPORT_JOB_INVALID_DATE_RANGE);
            throw new CxTxnsImporterException(Label.ERR_PMT_IMPORT_JOB_INVALID_DATE_RANGE);
        }

        // transaction ref# => transaction data
        Map<String,CardknoxService.ReportData> txns;
        // transactions with supporting data, these will be used to create source docs
        List<SrcDocs> docs;
        // transactions missing customer data, these will be converted to error objects
        List<SrcDocs> docsWithoutCustomer = new List<SrcDocs>();

        // fetch transactions from cardknox
        CardknoxService.Report report = srvc.getTransactions(startDate, endDate, pageSize, this.processor);

        if (!CardknoxService.RESP_SUCCESS_CODE.equalsIgnoreCase(report.xResult)) {
            logger.logError(processor.Id, Label.ERR_PMT_IMPORT_JOB_CALLOUT + ' ' + report.xError);
            throw new CxTxnsImporterException(Label.ERR_PMT_IMPORT_JOB_CALLOUT + ' ' + report.xError);
        }

        // convert report to SrcDocs
        docs = reportToDocs(report);
        if (docs != null && !docs.isEmpty()) {
            
            // get supporting data
            addTxnImportErrors(docs);
            addInvoices(docs);
            addCustomers(docs);
            addLedgers(docs);
            removeDocsWithInvalidCurrency(docs);
            docsWithoutCustomer = removeDocsWithoutCustomer(docs);
            
            // create source docs
            addPaymentActivities(docs);
            addPaymentMethods(docs);
            addCashReceipts(docs);
            addBillingCashReceipts(docs);

            // save the source docs which were created
            saveSrcDocs(docs);

            //create error records if no customer found
            createTransactionImportErrors(docsWithoutCustomer);

            //delete resolved transaction import error records
            deleteTransactionImportError(docs);
        }

        // number transactions fetched from cardknox
        Integer numTxns = Integer.valueOf(report.xRecordsReturned);
        // return the date transactions were sync'd until
        return numTxns >= pageSize ? report.xReportData.get(numTxns - 1).xEnteredDateUTC() : endDate;
    }

    private List<SrcDocs> reportToDocs(CardknoxService.Report report) {
        Map<String,SrcDocs> docs = new Map<String,SrcDocs>();

        // organize transactions data
        for (CardknoxService.ReportData txn : report.xReportData) {
            if (txn.xCommand == CardknoxService.COMMAND_CC_SALE || txn.xCommand == CardknoxService.COMMAND_CHECK_SALE) {
                // this is a sale made with a credit card or ach
                // other forms of payment are not supported
                // other actions are not supported, ie. void, refund, etc.
                docs.put(txn.xRefNum, new SrcDocs(txn));
            }
        }
        // remove transactions previously imported
        deDuplicate(docs);

        return docs.values();
    }

    // to avoid duplicates remove transactions previously imported or created in salesforce
    private void deDuplicate(Map<String,SrcDocs> docs) {
        List<Payment_Activity__c> dups = DomainUtils.getPaymentActivitiesByCardknoxRefNum(docs.keySet());
        for (Payment_Activity__c dup : dups) {
            docs.remove(dup.Merchant_Reference__c);
        }
    }

    private void addTxnImportErrors(List<SrcDocs> docs) {
        Set<String> refNumbers = new Set<String>();
        for (SrcDocs doc : docs) {
            refNumbers.add(doc.txn.xRefNum);
        }
        Map<String,Transaction_Import_Error__c> transactionErrorWithRefNum = getTransactionWithRefNum(
            DomainUtils.getTransactionImportErrorByRefNum(refNumbers)
        );
        for (SrcDocs doc : docs) {
            if (transactionErrorWithRefNum.containsKey(doc.txn.xRefNum)) {
                doc.transactionImportError = transactionErrorWithRefNum.get(doc.txn.xRefNum);
            }
        }
    }

    // add invoice data to each transaction
    private void addInvoices(List<SrcDocs> docs) {
        // collect invoice ids
        Set<Id> invoiceIds = new Set<Id>();
        for (SrcDocs doc : docs) {
            // record invoice number
            if (doc.transactionImportError?.Billing__c != null) {
                invoiceIds.add(doc.transactionImportError.Billing__c);
            } else if (String.isNotEmpty(doc.txn.xCustom19)) {
                try {
                    invoiceIds.add(doc.txn.xCustom19);
                } catch (StringException ex) {
                   // not a salesforce id
                }
            }
        }

        // get the invoices
        Map<Id,Billing__c> billings = new Map<Id,Billing__c>(DomainUtils.getBillingsWithCurrencyById(invoiceIds));
        
        // add invoice data to the correct transactions
        List<String> stringifiedIds = (List<String>)new List<Id>(invoiceIds); // avoid exception when using .contains(non_salesforce_id)
        String invoiceId;
        for (SrcDocs doc : docs) {
            invoiceId = doc.transactionImportError?.Billing__c == null ? doc.txn.xCustom19 : doc.transactionImportError.Billing__c;
            if (String.isNotEmpty(invoiceId) && stringifiedIds.contains(invoiceId) && billings.containsKey(invoiceId)) {
                doc.invoice = billings.get(invoiceId);
            }
        }
    }

    // add customer data to each transaction
    private void addCustomers(List<SrcDocs> docs) {
        // cx customer ids (not salesforce account ids)
        Set<String> cxCustomerIds = new Set<String>();

        for (SrcDocs doc : docs) {
            if (doc.invoice?.Customer__c != null) {
                // can pull customer from invoice
                doc.customerId = doc.invoice.Customer__c;
            } else if (doc.transactionImportError?.Customer__c != null) {
                // can take customer from resolved transaction import error
                doc.customerId = doc.transactionImportError.Customer__c;
            } else if (String.isNotBlank(doc.txn.xCustomerID)) {
                // customer exists in cx, lets see if we can find it in salesforce
                cxCustomerIds.add(doc.txn.xCustomerID);
            }
        }

        // check if cx customers can be found in salesforce
        if (!cxCustomerIds.isEmpty()) {
            for (Payment_Processor_Customer__c cust : DomainUtils.getPaymentProcessorCustomersByExternalId(this.processor.Id, cxCustomerIds)) {
                for (SrcDocs doc : docs) {
                    if (doc.txn.xCustomerID == cust.External_Id__c) {
                        doc.customerId = cust.Account__c;
                    }
                }
            }
        }
    }

    // add ledger data to each transaction
    private void addLedgers(List<SrcDocs> docs) {
        for (SrcDocs doc : docs) {
            if (doc.invoice?.Ledger__c != null) {
                // can pull ledger from invoice
                doc.ledgerId = doc.invoice.Ledger__c;
            } else {
                // there is no ledger information then pick from payment processor
                doc.ledgerId = this.processor.Default_Ledger__c;
            }
        }
    }

    // remove transactions which are missing customer data from the input list
    // and return the removed transactions
    private List<SrcDocs> removeDocsWithoutCustomer(List<SrcDocs> docs) {
        List<SrcDocs> docsWithoutCustomer = new List<SrcDocs>();
        List<SrcDocs> docsWithCustomer = new List<SrcDocs>();
        for (SrcDocs doc : docs) {
            if (String.isBlank(doc.CustomerId)) {
                docsWithoutCustomer.add(doc);
            } else {
                docsWithCustomer.add(doc);
            }
        }

        // memory address for docs can't be changed to point at new list so we have to clear and add to existing list
        docs.clear();
        docs.addAll(docsWithCustomer);

        return docsWithoutCustomer;
    }

    // throw out transaction where the currency does not match the ledger currency
    private List<SrcDocs> removeDocsWithInvalidCurrency(List<SrcDocs> docs) {
        List<SrcDocs> docsWithInvalidCurrency = new List<SrcDocs>();
        List<SrcDocs> docsWithValidCurrency = new List<SrcDocs>();
        for (SrcDocs doc : docs) {
            if (isValidCurrency(doc)) {
                docsWithValidCurrency.add(doc);
            } else {
                docsWithInvalidCurrency.add(doc);
            }
        }

        // memory address for docs can't be changed to point at new list so we have to clear and add to existing list
        docs.clear();
        docs.addAll(docsWithValidCurrency);

        return docsWithInvalidCurrency;
    }

    // txn currency matches ledger currency
    private Boolean isValidCurrency(SrcDocs doc) {
        String ledgerCurrency = LedgerHandler.getLedgerCurrency(doc.ledgerId);
        return ledgerCurrency.equalsIgnoreCase(doc.txn.xCurrency);
    }

    // add payment activities to each transaction
    private void addPaymentActivities(List<SrcDocs> docs) {
        for (SrcDocs doc : docs) {
            // create payment_activity
            doc.paymentActivity = new Payment_Activity__c(
                // Payment_Method__c = ???, NO ID YET!!! It is set later
                // Cash_Receipt__c = ???, NO ID YET!!! It is set later
                Amount__c = doc.txn.xAmount,
                Error_Message__c = String.isEmpty(doc.txn.xResponseError) ? null : doc.txn.xResponseError,
                Error_Type__c = String.isEmpty(doc.txn.xErrorCode) ? null : doc.txn.xErrorCode,
                Type__c = PaymentActivityHelper.PAYMENT_TYPE,
                Fee__c = doc.txn.xProcessingFee.setScale(2, System.RoundingMode.HALF_UP),
                Merchant_Reference__c = doc.txn.xRefNum,
                Merchant_Batch_Id__c = String.isEmpty(doc.txn.xResponseBatch) ? null : doc.txn.xResponseBatch,
                Status__c = getPaymentActivityStatus(doc.txn),
                Payment_Date__c = doc.txn.xEnteredDateUTC()
            );
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                doc.paymentActivity.put('CurrencyIsoCode', doc.txn.xCurrency);
            }
            if (this.processor.Enable_Convenience_Fees__c) {
                String fee = doc.txn.getCustomField(this.processor.Convenience_Fee_Mapping__c);
                String original = doc.txn.getCustomField(this.processor.Original_Amount_Mapping__c);
                doc.paymentActivity.Convenience_Fee__c = FinancialSuiteUtils.stringToDecimal(fee);
                doc.paymentActivity.Original_Amount__c = FinancialSuiteUtils.stringToDecimal(original);
            }
        }
    }

    // add payment methods to each transaction
    private void addPaymentMethods(List<SrcDocs> docs) {
        // get customers' existing payment methods
        Set<Id> customerIds = new Set<Id>();
        for (SrcDocs doc : docs) {
            customerIds.add(doc.customerId);
        }
        List<Account> accts =  new List<Account>();
        accts = DomainUtils.getCustomerPlaceholderPaymentMethods(customerIds);
        Map<Id,Account> acctsById = new Map<Id,Account>(accts);

        // add payment method to each transaction
        Id custId;
        for (SrcDocs doc : docs) {
            custId = doc.customerId;

            if (acctsById.get(custId)?.Payment_Methods__r != null 
                    && acctsById.get(custId).Payment_Methods__r.size() > 0) {
                // payment method exists for this customer, use it
                for (Payment_Method__c paymentMethod : acctsById.get(custId).Payment_Methods__r) {
                    if (isPaymentMethodMatch(doc, paymentMethod)) {
                        doc.paymentMethod = paymentMethod;
                    }
                }
            }

            // no existing placeholder found
            if (doc.paymentMethod == null) {
                // new placeholder payment methnod because none is on file
                // doesn't matter if duplicated here. only unique payment methods will be saved
                Payment_Method__c paymentMethod = new Payment_Method__c(
                    Customer__c = custId,
                    External_Use_Only__c = true,
                    Payment_Processor__c = this.processor.Id,
                    Last_Four_Digits__c = PaymentMethodActions.PLACEHOLDER_LAST_FOUR
                );

                if (doc.txn.xCommand.equalsIgnoreCase(CardknoxService.COMMAND_CC_SALE)) {
                    paymentMethod.External_Id__c = PaymentMethodActions.PLACEHOLDER_CARD_EXTERNAL_ID 
                        + '_' + paymentMethod.Payment_Processor__c 
                        + '_' + paymentMethod.Customer__c; // + processor + custId because uniqueness constraint
                    paymentMethod.Payment_Method_Type__c = PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE;
                    paymentMethod.Type__c = PaymentMethodActions.PLACEHOLDER_TYPE;
                    paymentMethod.Expiration_Month__c = PaymentMethodActions.PLACEHOLDER_EXPIRATION_MONTH;
                    paymentMethod.Expiration_Year__c = PaymentMethodActions.PLACEHOLDER_EXPIRATION_YEAR;
                } else if (doc.txn.xCommand.equalsIgnoreCase(CardknoxService.COMMAND_CHECK_SALE)) {
                    paymentMethod.External_Id__c = PaymentMethodActions.PLACEHOLDER_ACH_EXTERNAL_ID
                        + '_' + paymentMethod.Payment_Processor__c 
                        + '_' + paymentMethod.Customer__c; // + processor + custId because uniqueness constraint
                    paymentMethod.Payment_Method_Type__c = PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE;
                    paymentMethod.Routing_Number__c = PaymentMethodActions.PLACEHOLDER_ROUTING_NUMBER;
                    paymentMethod.Bank_Account_Type__c = PaymentMethodActions.PLACEHOLDER_BANK_ACCOUNT_TYPE;
                    paymentMethod.Bank_Name__c = PaymentMethodActions.PLACEHOLDER_BANK_NAME;
                }

                doc.paymentMethod = paymentMethod;
            }
        }
    }

    // add cash receipts to each transaction
    private void addCashReceipts(List<SrcDocs> docs) { 
        for (SrcDocs doc : docs) {
            // don't create CRs for errors / declined / void payments
            if (doc.paymentActivity.Status__c == PaymentActivityHelper.SUCCESS_STATUS 
                    || doc.paymentActivity.Status__c == PaymentActivityHelper.PENDING_STATUS) {
                doc.cashReceipt = new Cash_Receipt__c(
                    Amount__c = doc.txn.xAmount,
                    Account__c = doc.customerId,
                    Receipt_Date__c = doc.txn.xEnteredDateUTC().date(),
                    Payment_Type__c = CashReceiptActions.PAYMENT_TYPE_ELECTRONIC,
                    Payment_Reference__c = doc.txn.xRefNum,
                    Payment_Processor__c = this.processor.Id,
                    Ledger__c = doc.ledgerId,
                    Bank_Account__c = this.processor.Merchant_GL_Account__c
                );
                if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                    doc.cashReceipt.put('CurrencyIsoCode', doc.txn.xCurrency);
                }
                
                if (this.processor.Enable_Convenience_Fees__c) {
                    String fee = doc.txn.getCustomField(this.processor.Convenience_Fee_Mapping__c);
                    doc.cashReceipt.Convenience_Fees_Charged__c = FinancialSuiteUtils.stringToDecimal(fee);
                }
            }
        }
    }

    // add billing cash receipts to each transaction
    private void addBillingCashReceipts(List<SrcDocs> docs) {
        // billing id => balance
        // tracking this way because multiple CRs can be applied to single billing and
        // balance field is not writable, so must be tracked separately from billing obj
        Map<Id,Decimal> runningBalance = new Map<Id,Decimal>();

        Date today = Date.today();
        AccountingPeriodHandler accountingPeriods = AccountingPeriodHandler.getInstance();
        Accounting_Period__c currentPeriod = accountingPeriods.getAccountingPeriodByDate(today);

        for (SrcDocs doc : docs) {          
            if (doc.invoice == null || doc.cashReceipt == null) {
                // transaction not tied to billing or cash receipt
                continue;
            }

            if (!runningBalance.containsKey(doc.invoice.Id)) {
                // first time encountering this billing
                runningBalance.put(doc.invoice.Id, doc.invoice.Balance__c);
            }

            if (runningBalance.get(doc.invoice.Id) <= 0) {
                // no balance left on this billing
                continue;
            }

            if (MultiCurrencyHandler.isMultiCurrencyEnabled 
                    && doc.invoice.get('CurrencyIsoCode') != doc.cashReceipt.get('CurrencyIsoCode')) {
                // currency mismatch
                continue;
            }

            //do not create billing cash receipt if the payment activity is not in the success or pending state
            //it should ignore creating the bcr for void, declined, and error activities
            if (doc.paymentActivity.Status__c != PaymentActivityHelper.SUCCESS_STATUS 
                    && doc.paymentActivity.Status__c != PaymentActivityHelper.PENDING_STATUS) {
                //status not qualified
                continue;
            }
            // determine the BCR accounting period
            Accounting_Period__c bcrAccountingPeriod;
            Accounting_Period__c invoicePeirod = accountingPeriods.getAccountingPeriodById(doc.invoice.Accounting_Period__c);
            if (invoicePeirod != null && currentPeriod == null) {
                // no current period, but invoice has a period
                bcrAccountingPeriod = invoicePeirod;
            } else if (currentPeriod != null && invoicePeirod == null) {
                // no invoice period, but current period exists
                bcrAccountingPeriod = currentPeriod;
            } else if (invoicePeirod != null && currentPeriod != null) {
                // both invoice period and current period exist
                if (currentPeriod.Start_Date__c > invoicePeirod.Start_Date__c) {
                    // current period is later than invoice period
                    bcrAccountingPeriod = currentPeriod;
                } else {
                    // invoice period is later than current period
                    bcrAccountingPeriod = invoicePeirod;
                }
            }
            
            if (!accountingPeriods.isConsideredOpen(bcrAccountingPeriod)) {
                // no valid period found, skip this BCR
                continue;
            }

            // determine the BCR applied date
            Date appliedDate = doc.invoice.Date__c > today ? doc.invoice.Date__c : today;
            if (doc.invoice.Date__c > today) {
                // billing is for a future date, so use the billing date
                appliedDate = doc.invoice.Date__c;
            } else if (today >= bcrAccountingPeriod.Start_Date__c && today <= bcrAccountingPeriod.End_Date__c) {
                // today is within the BCR accounting period, so use today
                appliedDate = today;
            } else {
                // fall back to invoice date
                appliedDate = doc.invoice.Date__c;
            }

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Accounting_Period__c = bcrAccountingPeriod.Id,    
                Applied_Date__c = appliedDate,
                Billing__c = doc.invoice.Id
                // Cash_Receipt__c = ???, NO ID YET!!! It is set later
            );

            // add application amount
            Decimal cashReceiptBalance = doc.cashReceipt.Convenience_Fees_Charged__c == null 
            ? doc.cashReceipt.Amount__c 
            : doc.cashReceipt.Amount__c - doc.cashReceipt.Convenience_Fees_Charged__c;
            
            if (cashReceiptBalance <= runningBalance.get(doc.invoice.Id)) {
                // entire CR amount can be applied to the billing
                bcr.Applied_Amount__c = cashReceiptBalance;
            } else {
                // CR amount is greater than the balance on the billing
                // only apply up to the balance of the billing
                bcr.Applied_Amount__c = runningBalance.get(doc.invoice.Id);
            }

            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                bcr.put('CurrencyIsoCode', doc.txn.xCurrency);
            }

            doc.billingCashReceipt = bcr;

            runningBalance.put(doc.invoice.Id, runningBalance.get(doc.invoice.Id) - bcr.Applied_Amount__c);
        }
    }

    //create transaction import error for those transaction whose customer does not exist\
    private void createTransactionImportErrors(List<SrcDocs> docsWithoutCustomer){
        try{
            List<Transaction_Import_Error__c> transactionImportErrors = new List<Transaction_Import_Error__c>();
            Set<String> refNumbers = new Set<String>();
            for(SrcDocs doc : docsWithoutCustomer){
                refNumbers.add(doc.txn.xRefNum);
            }

            Map<String,Transaction_Import_Error__c> existedTransactionErrors = getTransactionWithRefNum(DomainUtils.getTransactionImportErrorByRefNum(refNumbers));

            for(SrcDocs doc : docsWithoutCustomer){
                if(!existedTransactionErrors.containsKey(doc.txn.xRefNum)){
                    transactionImportErrors.add(createErrorRecord(doc));
                }
            }

            if(transactionImportErrors.size() > 0 ){
                SfdcSecurityUtils.insertProxy(transactionImportErrors);
                logOnActivity(transactionImportErrors);
            }
        }catch(Exception ex){
            logger.logError(processor.Id, ex.getMessage());
        }
    } 

    /**
     * create tasks for all the transaction import error records
     */
    private void logOnActivity(List<Transaction_Import_Error__c> transactionImportErrors) {
        List<Task> tasks = new List<Task>();
        //create tasks for each failed transaction
        for (Transaction_Import_Error__c transactionError : transactionImportErrors) {
            tasks.add(FinancialSuiteUtils.setTask(
                        transactionError.Id,
                        NOT_STARTED,
                        NULL,
                        ERR_COULD_NOT_IMPORT_TRANSACTION,
                        TRANSACTION_FAILED_COMMENT,
                        NULL
                    ));

        }
        //insert tasks
        if (!tasks.isEmpty()) {
            SFDCSecurityUtils.insertProxy(tasks);
        }
        // log to AJR
        logger.logError(processor.Id, TRANSACTION_FAILED_COMMENT);
    }

    //delete the reolved transation import error records and it will delete the related tasks
    private void deleteTransactionImportError(List<SrcDocs> docs){
        List<Transaction_Import_Error__c> transactionImportErrors = new List<Transaction_Import_Error__c>();

        for(SrcDocs doc : docs){
            if(doc.transactionImportError != null){
                transactionImportErrors.add(doc.transactionImportError);
            }
        }
        //delete records
        if(transactionImportErrors.size() > 0){
            logMessages(SFDCSecurityUtils.deleteProxyDatabase(transactionImportErrors, false));
        }
    }

    //get transaction import error with reference number
    private Map<String,Transaction_Import_Error__c> getTransactionWithRefNum(List<Transaction_Import_Error__c> txnImportErrors){
        Map<String,Transaction_Import_Error__c> txnImportErrorsMapped = new Map<String,Transaction_Import_Error__c>();
        for(Transaction_Import_Error__c txnImportError : txnImportErrors){
            txnImportErrorsMapped.put(txnImportError.Merchant_Reference__c,txnImportError);
        }
        return txnImportErrorsMapped;
    }

    //create transaction error record
    private Transaction_Import_Error__c createErrorRecord(SrcDocs doc){
        Transaction_Import_Error__c transactionImportError = new Transaction_Import_Error__c();
        transactionImportError.Payment_Processor__c = this.processor.Id;
        transactionImportError.Merchant_Reference__c = doc.txn.xRefNum;
        transactionImportError.Amount__c = doc.txn.xAmount;
        transactionImportError.Fee__c = doc.txn.xProcessingFee;
        transactionImportError.Type__c  = doc.txn.xCommand;
        transactionImportError.Date__c  = doc.txn.xEnteredDateUTC();
        transactionImportError.Billing_Name__c  = String.isEmpty(doc.txn.xBillCompany) ? doc.txn.xBillFirstName + doc.txn.xBillLastName : doc.txn.xBillCompany;
        transactionImportError.Billing_Street__c  = doc.txn.xBillStreet;
        transactionImportError.Billing_City__c  = doc.txn.xBillCity;
        transactionImportError.Billing_State__c  = doc.txn.xBillState;
        transactionImportError.Billing_Postal_Code__c  = doc.txn.xBillZip;
        transactionImportError.Billing_Country__c  = doc.txn.xBillCountry;
        transactionImportError.Error__c = Label.ERR_CARDKNOX_MISSING_CUSTOMER_INFO;
        return transactionImportError;
    }

    // save payment activities, cash receipts, billing cash receipts, and payment methods. All or nothing.
    private void saveSrcDocs(List<SrcDocs> docs) {
        Savepoint state = Database.setSavepoint();
        try {
            // insert payment methods
            // use map to avoid duplicates
            Map<String,Payment_Method__c> paymentMethods = new Map<String,Payment_Method__c>();
            for (SrcDocs doc : docs) {
                if (doc.paymentMethod.Id == null) {
                    // only insert new payment methods
                    // can have a new cc and ach payment method for the same customer, so we use a compound key
                    paymentMethods.put(doc.customerId + doc.paymentMethod.Payment_Method_Type__c, doc.paymentMethod);
                }
            }

           SfdcSecurityUtils.insertProxy(paymentMethods.values());

            // insert cash receipts
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            for (SrcDocs doc : docs) {
                if (doc.cashReceipt != null) {
                    cashReceipts.add(doc.cashReceipt);
                }
            }
            
            SfdcSecurityUtils.insertProxy(cashReceipts);

            // add IDs and insert payment activities
            List<Payment_Activity__c> paymentActivities = new List<Payment_Activity__c>();
            for (SrcDocs doc : docs) {
                if (doc.paymentActivity != null) {
                    doc.paymentActivity.Payment_Method__c = doc.paymentMethod.Id == null 
                            ? paymentMethods.get(doc.customerId + doc.paymentMethod.Payment_Method_Type__c).Id // newly inserted payment method
                            : doc.paymentMethod.Id; // existing payment method
                    doc.paymentActivity.Cash_Receipt__c = doc.cashReceipt?.Id;
                    paymentActivities.add(doc.paymentActivity);
                }
            }
            
            SfdcSecurityUtils.insertProxy(paymentActivities);

            // add IDs and insert billing cash receipts
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            for (SrcDocs doc : docs) {
                if (doc.billingCashReceipt != null) {
                    doc.billingCashReceipt.Cash_Receipt__c = doc.cashReceipt?.Id;
                    billingCashReceipts.add(doc.billingCashReceipt);
                }
            }
            
            SfdcSecurityUtils.insertProxy(billingCashReceipts);

        } catch (DmlException e) {
            Database.rollback(state);
            for (Integer i=0; i<e.getNumDml(); i++) {
                logger.logError(processor.Id, e.getDmlMessage(i));
            }
            throw new CxTxnsImporterException(ERR_COULD_NOT_IMPORT_TRANSACTION);
        } catch (Exception ex) {
            Database.rollback(state);
            logger.logError(processor.Id, ex.getMessage() + '\n' + ex.getStackTraceString());
            throw new CxTxnsImporterException(ERR_COULD_NOT_IMPORT_TRANSACTION);
        }
    }

    private void logMessages(List<Database.DeleteResult> result) {
        for (Database.DeleteResult res : result) {
            if (!res.isSuccess()) {
                logger.logError(processor.Id, res.getErrors()[0].getMessage());
            }
        }
    }

    // translates a transaction status into a payment activity status
    private static String getPaymentActivityStatus(CardknoxService.ReportData txn) {
        // xResponseResult is the Gateway status. Approved, Declined, Error
        // xStatus is the ACH Status. 0 = pending, 6 = awaiting response, 14 = chargeback, 16 = settled
        // xCommand = transaction type. ie. sale, auth, void, capture, refund, credit
        if (isSuccessStatus(txn)) {
            return PaymentActivityHelper.SUCCESS_STATUS;
        } else if (isErrorStatus(txn)) {
            return PaymentActivityHelper.ERROR_STATUS;
        }else if (isDeclinedStatus(txn)) {
            return PaymentActivityHelper.DECLINED_STATUS;
        } else if (isPendingStatus(txn)) {
            return PaymentActivityHelper.PENDING_STATUS;
        } else if (isVoidStatus(txn)) {
            return PaymentActivityHelper.VOID_STATUS;
        }
        return PaymentActivityHelper.ERROR_STATUS;
    }

    private static Boolean isSuccessStatus(CardknoxService.ReportData txn) {
        return (((CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
                && CardknoxService.COMMAND_CC_SALE.equalsIgnoreCase(txn.xCommand))
            || (CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
                && CardknoxService.COMMAND_CHECK_SALE.equalsIgnoreCase(txn.xCommand)
                && CardknoxService.STATUS_SETTLED == txn.xStatus)) 
            && txn.xVoid != VOID_STATUS_CARDKNOX_VALUE);
    }

    private static Boolean isErrorStatus(CardknoxService.ReportData txn) {
        return CardknoxService.RESP_RESULT_ERROR.equalsIgnoreCase(txn.xResponseResult)                
            || (CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
                && CardknoxService.COMMAND_CHECK_SALE.equalsIgnoreCase(txn.xCommand)
                && CardknoxService.STATUS_CHARGEBACK == txn.xStatus);
    }

    private static Boolean isDeclinedStatus(CardknoxService.ReportData txn) {
        return CardknoxService.RESP_RESULT_DECLINED.equalsIgnoreCase(txn.xResponseResult);
    }

    private static Boolean isPendingStatus(CardknoxService.ReportData txn) {
        return (CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
            && CardknoxService.COMMAND_CHECK_SALE.equalsIgnoreCase(txn.xCommand)
            && (CardknoxService.STATUS_PENDING == txn.xStatus 
                || CardknoxService.STATUS_AWAITING_RESPONSE == txn.xStatus)
            && txn.xVoid != VOID_STATUS_CARDKNOX_VALUE);
    }
    private static Boolean isVoidStatus(CardknoxService.ReportData txn) {
        return (CardknoxService.RESP_RESULT_APPROVED.equalsIgnoreCase(txn.xResponseResult)
                && txn.xVoid == VOID_STATUS_CARDKNOX_VALUE);
    }

    private Boolean isPaymentMethodMatch(SrcDocs doc, Payment_Method__c paymentMethod) {
        Boolean processorMatch = paymentMethod.Payment_Processor__c == this.processor.Id;
        Boolean cardMatch = paymentMethod.Payment_Method_Type__c == PaymentMethodActions.CREDIT_CARD_PAYMENT_METHOD_TYPE && doc.txn.xCommand.equalsIgnoreCase(CardknoxService.COMMAND_CC_SALE);
        Boolean bankMatch = paymentMethod.Payment_Method_Type__c == PaymentMethodActions.BANK_PAYMENT_METHOD_TYPE && doc.txn.xCommand.equalsIgnoreCase(CardknoxService.COMMAND_CHECK_SALE);
        
        return processorMatch && (cardMatch || bankMatch);
    }
    
}