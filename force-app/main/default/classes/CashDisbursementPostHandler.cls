public with sharing class CashDisbursementPostHandler extends AbstractPostHandler {
   
    @TestVisible
    private static final String POSTED_VOID_ERROR_MESSAGE = Label.ERR_CD_POSTED_VOID;
    @TestVisible
    private static final String NO_CONTROL_ACCOUNT_MESSAGE = Label.ERR_CD_NO_CONTROL_ACCOUNT;
    @TestVisible
    private static final String NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_ACCOUNT_MESSAGE = Label.ERR_CD_NO_UNAPPLIED_EXPENSE_GL_ACCOUNT;
    @TestVisible
    private static final String NO_DISCOUNT_PAYMENT_ACCOUNT_MESSAGE = Label.INF_NO_DISCOUNT_PAYMENT_ACCOUNT_HELP_TEXT;
    @TestVisible
    private static final String UNPOST_CLEARED_ERROR_MESSAGE = Label.ERR_UNPOSTED_CLEARED_BANK_RECONCILIATION;
    @TestVisible
    private static final String UNPOST_APPLIED_ERROR_MESSAGE = Label.ERR_CD_APPLIED_PAYABLE_UNPOST;
    @TestVisible
    private static final String PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_ERROR_MESSAGE = Label.INF_PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_HELP_TEXT;

    public static final String NO_SELECTION_POSTED_ERROR_MESSAGE = Label.ERR_CD_NO_SELECTION_POSTED;
    public static final String NO_SELECTION_UNPOSTED_ERROR_MESSAGE = Label.ERR_CD_NO_SELECTION_UNPOSTED;

    public static final Integer CASH_DISBURSEMENTS_COUNT_LIMIT = 1000;
    public static final String CASH_DISBURSEMENTS_COUNT_LIMIT_ERROR_MESSAGE = Label.ERR_CD_COUNT_LIMIT;
    public static final String DEBIT_GL_ACCOUNT_ERROR_MESSAGE = Label.ERR_CD_NO_GL_ACCOUNT;
    public static final String POSTING_STATUS_NOT_APPROVED_ERROR_MSG = Label.POSTING_STATUS_NOT_APPROVED_ERR;
    private static final String AS_PAY_TYPE = 'AS Pay';
    public static final String POSTED_STATUS= Label.COMMON_POSTED;
    private Boolean isLinkedWithAP = true;

    //============================================================================================
    //Post method implementation for Cash Disbursements ====================================================

    public override List<PostResult> post(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();
        for (LDVPostInput item : sourceItems) {
            sourceMap.put(item.id, item);
        }
        return post(new List<Id>(sourceMap.keySet()));
    }

    public override List<PostResult> post(List<SObject> processedRecords) {
        Map<Id, Cash_Disbursement__c> cashDisbursementsMap =
            new Map<Id, Cash_Disbursement__c>((List<Cash_Disbursement__c>) processedRecords);
        return post(new List<Id>(cashDisbursementsMap.keySet()));
    }

    public override List<PostResult> post(List<String> processedRecordsIds) {
        this.processedRecordIds = processedRecordsIds;

        if (!this.processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
                //Initial query for Cash Disbursements
                main = getAccountingSettings();
                queryCashDisbursements();
                getGLAccountDefaults();
                validateAPControlGLAccount(false);
                //weed out the unsuitable Cash Disbursements
                validateNotPosted(false);
                validateNotVoid(false);
                validatePaidAmountSumEqualsCashDisbursementAmount(false);
                validateAccountingPeriodIsOpen(false);
                validateLedgerType(false, false);
                validateDebitGLAccount(false);
                validateCashFlowCategoryIsDefined(false);
                validateCashFlowStatementConformity(false);
                validatePaymentDiscountGLAccount(false);
                if (!isLDVBatchContext) {
                    validatePostingStatus(false);
                }

                sourceRecords = CashDisbursementPaymentServiceValidator.validatePaymentServiceFields(false,sourceRecords,dispatcher);
                
                //no need to proceed further if there is no valid Cash Disbursements after all validations above
                validateNoQualifyingPostedRecords(CashDisbursementPostHandler.NO_SELECTION_POSTED_ERROR_MESSAGE);
                if (!sourceRecords.isEmpty()) {
                    if (validateRecordsLimit()) {
                        processPostCashDisbursements();
                        processPostResult();
                    }
                }
                dispatcher.isPreCheck = false;
            }
            catch (System.DmlException dmlEx) {
                processDmlExceptions(dmlEx);
            }
            catch (Exception ex) {
                processSystemExceptions(ex);
            }
        }

        return dispatcher.getPostResults();
    }

    //==============================================================================================
    //Unpost method implementation ====================================================

    public override List<PostResult> unpost(List<LDVPostInput> sourceItems) {
        isLDVBatchContext = true;
        Map<Id, PostResult> postResults = new Map<Id, PostResult>();
        Map<Id, LDVPostInput> sourceMap = new Map<Id, LDVPostInput>();
        for (LDVPostInput item : sourceItems) {
            sourceMap.put(item.id, item);
        }
        for (PostResult res : unpost(new List<Id>(sourceMap.keySet()))) {
            postResults.put(res.id, res);
        }
        ldvGetPostResultMap(postResults, sourceMap);
        return postResults.values();
    }

    public override List<PostResult> unpost(List<SObject> processedRecords) {
        Map<Id, Cash_Disbursement__c> cashDisbursementsMap =
            new Map<Id, Cash_Disbursement__c>((List<Cash_Disbursement__c>) processedRecords);
        return unpost(new List<Id>(cashDisbursementsMap.keySet()));
    }

    public override List<PostResult> unpost(List<String> processedRecordsIds) {
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        this.processedRecordIds = processedRecordsIds;

        if (!processedRecordIds.isEmpty()) {
            try {
                dispatcher.clearResultsMap();
                dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
                //Initial query for Cash Disbursements
                queryCashDisbursements();
                //weed out the unsuitable Cash Disbursements
                if (isLDVBatchContext) {
                    validateIsPostedByApproval(true);
                }
                else {
                    validateIsPosted(false);
                }
                validateAccountingPeriodIsOpen(false);
                validateNotCleared(false);
                validateNotApplied(false);
                //no need to proceed further if there is no valid Cash Disbursements after all validations above
                validateNoQualifyingUnpostedRecords(CashDisbursementPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE);

                if (!sourceRecords.isEmpty()) {
                    processUnpostCashDisbursements();
                    processPostResult();
                }
                dispatcher.isPreCheck = false;
            }
            catch (System.DmlException dmlEx) {
                processDmlExceptions(dmlEx);
            }
            catch (Exception ex) {
                processSystemExceptions(ex);
            }
        }

        return dispatcher.getPostResults();
    }

    //===================================================================================
    //====== Payable Post/Unpost specific utility and validation methods ================

    private void queryCashDisbursements() {
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Ledger__c',
            'Ledger__r.Name',
            'Ledger__r.Type__c',
            'Ledger__r.Accounting_Method__c',
            'Ledger__r.Tax_Settings__c',
            'Status__c',
            'Accounting_Period__c',
            'Accounting_Period__r.Name',
            'Accounting_Period__r.Status__c',
            'Amount__c',
            'AP_Voucher_Count__c',
            'Disbursement_Date__c',
            'Debit_GL_Account__c',
            'Bank_Account__c',
            'Cash_Flow_Category__c',
            'Vendor__c',
            'Employee__c',
            'Contact__c',
            'Check_Number__c',
            'Payment_Services_Reference__c',
            'Payment_Service_Status__c',
            'Reference__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Project__c',
            'Project_Task__c',
            'Payment_Status__c',
            'Bank_Reconciliation__c',
            'Bank_Reconciliation__r.Name',
            'Product__c',
            'Source__c',
            'Type__c',
            'AcctSeed__Vendor__r.AcctSeed__Billing_Contact__c',
            'AcctSeed__Vendor__r.Name',
            'AcctSeed__Bank_Account__r.AcctSeed__Bank_Account__r.AcctSeed__Enable_for_Payment_Services__c',
            'AcctSeed__Bank_Account__r.AcctSeed__Bank_Account__r.AcctSeed__Payment_Services_Enrollment_Status__c',
            'AcctSeed__Bank_Account__r.Name',
            'Ledger__r.Enrolled_in_Payment_Services__c',
            'Ledger__r.Payment_Services_Company_Code__c',
            'AcctSeed__Vendor__r.AP_Remittance_Email__c',
            'AcctSeed__Vendor__r.BillingStreet',
            'AcctSeed__Vendor__r.BillingCity',
            'AcctSeed__Vendor__r.BillingPostalCode',
            'AcctSeed__Vendor__r.BillingState',
            'AcctSeed__Vendor__r.BillingCountry',
            'AcctSeed__Vendor__r.AS_Pay_Type__c',
            'AS_Pay_Type__c',
            'Balance__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            fieldsToQuery.add('CurrencyIsoCode');
            fieldsToQuery.add('Currency_Conversion_Rate__c');
        }
        //Add query condition
        String queryCondition = 'Id IN :processedRecordIds FOR UPDATE';
        //Sub-query
        String subQueryRelationshipName = PACKAGE_QUALIFIER + 'Account_Payable_Cash_Disbursements__r';
        List<String> subQueryFields = new List<String>{
            'Cash_Disbursement__c',
            'Discount_Amount__c',
            'Net_Amount__c',
            'Paid_Amount__c'
        };
        if (IS_MULTI_CURRENCY_ENABLED) {
            subQueryFields.add('CurrencyIsoCode');
            subQueryFields.add('Account_Payable__r.Currency_Conversion_Rate__c');
        }
        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition)
            .subselectQuery(subQueryRelationshipName, false)
            .setEnforceFLS(false)
            .selectFields(subQueryFields);

        String dynamicSOQL = theQuery.toSOQL();
        //Call DML operation
        sourceRecords = Database.query(dynamicSOQL);
    }

    public void validateBeforePost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.POST);
        Map<Id, Cash_Disbursement__c> cashDisbursementsMap =
            new Map<Id, Cash_Disbursement__c>((List<Cash_Disbursement__c>) processedRecords);
        this.processedRecordIds = new List<Id>(cashDisbursementsMap.keySet());
        //Initial query for Cash Disbursements
        main = getAccountingSettings();
        queryCashDisbursements();
        getGLAccountDefaults();
        validateAPControlGLAccount(fullStatistics);
        //weed out the unsuitable Cash Disbursements
        validateNotPosted(fullStatistics);
        validateNotVoid(fullStatistics);
        validatePaidAmountSumEqualsCashDisbursementAmount(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        validateLedgerType(fullStatistics, false);
        validateDebitGLAccount(fullStatistics);
        validateCashFlowCategoryIsDefined(fullStatistics);
        validateCashFlowStatementConformity(fullStatistics);
        validatePaymentDiscountGLAccount(fullStatistics);
        validatePostingStatus(fullStatistics);

        sourceRecords = CashDisbursementPaymentServiceValidator.validatePaymentServiceFields(fullStatistics,sourceRecords,dispatcher);

        validateRecordsLimit();
        //add positive results
        processPostResult();
    }

    public void validateBeforeUnpost(List<SObject> processedRecords, Boolean fullStatistics) {
        dispatcher.clearResultsMap();
        dispatcher.setExecutionContext(PostResultDispatcher.ExecutionContext.UNPOST);
        Map<Id, Cash_Disbursement__c> cashDisbursementsMap =
            new Map<Id, Cash_Disbursement__c>((List<Cash_Disbursement__c>) processedRecords);
        this.processedRecordIds = new List<Id>(cashDisbursementsMap.keySet());
        //Initial query for Cash Disbursements
        queryCashDisbursements();
        //weed out the unsuitable Cash Disbursements
        validateIsPosted(fullStatistics);
        validateAccountingPeriodIsOpen(fullStatistics);
        validateNotCleared(fullStatistics);
        validateNotApplied(fullStatistics);
        //add positive results
        processPostResult();
    }

    private void validateAPControlGLAccount(Boolean fullStatistics) {
        List<SObject> validRecords = new List<SObject>();
        for (Cash_Disbursement__c cd : (List<Cash_Disbursement__c>) sourceRecords) {
            Boolean isValid = true;
            if ((LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cd.Ledger__c)
                || LedgerHandler.getInstanceWithoutSharing().isAccrualLedger(cd.Ledger__c))
                && (!glAccountDefaults.containsKey(cd.Ledger__c) ||
                (glAccountDefaults.containsKey(cd.Ledger__c)
                    && !glAccountDefaults.get(cd.Ledger__c).containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)))) {
                dispatcher.addPostErrorResult(
                    cd,
                    new PostResult.PostErrorResult(
                        cd,
                        PostResult.StatusCode.NO_CONTROL_AP_ACCOUNT_DEFINED,
                        NO_CONTROL_ACCOUNT_MESSAGE
                    )
                );
                isValid = false;
            }
            if ((LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cd.Ledger__c)
                && noUnappliedGLAccountForLedger(LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cd.Ledger__c).Id))
                || (LedgerHandler.getInstanceWithoutSharing().isCashLedger(cd.Ledger__c) && cd.Debit_GL_Account__c == null
                && noUnappliedGLAccountForLedger(cd.Ledger__c))) {
                dispatcher.addPostErrorResult(
                    cd,
                    new PostResult.PostErrorResult(
                        cd,
                        PostResult.StatusCode.NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_DEFINED,
                        NO_UNAPPLIED_EXPENSE_GL_ACCOUNT_ACCOUNT_MESSAGE
                    )
                );
                isValid = false;
            }
            if (isValid) {
                validRecords.add(cd);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validRecords;
        }
    }

    private Boolean noUnappliedGLAccountForLedger(Id ledgerId) {
        return (!glAccountDefaults.containsKey(ledgerId) ||
            (glAccountDefaults.containsKey(ledgerId)
                && !glAccountDefaults.get(ledgerId).containsKey(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)));
    }

    @TestVisible
    private void validateDebitGLAccount(Boolean fullStatistics) {
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();
        for (Cash_Disbursement__c cd : (List<Cash_Disbursement__c>) sourceRecords) {
            if (cd.Debit_GL_Account__c == NULL && cd.AP_Voucher_Count__c == 0) {
                dispatcher.addPostErrorResult(
                    cd,
                    new PostResult.PostErrorResult(
                        cd,
                        PostResult.StatusCode.NO_DEBIT_GL_ACCOUNT,
                        DEBIT_GL_ACCOUNT_ERROR_MESSAGE
                    )
                );
            }
            else {
                validCashDisbursements.add(cd);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashDisbursements;
        }
    }

    private void validateNotVoid(Boolean fullStatistics) {
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();
        for (Cash_Disbursement__c cd : (List<Cash_Disbursement__c>) sourceRecords) {
            if (cd.Payment_Status__c == 'Void') {
                dispatcher.addPostErrorResult(
                    cd,
                    new PostResult.PostErrorResult(
                        cd,
                        PostResult.StatusCode.PAYMENT_STATUS_VOID,
                        CashDisbursementPostHandler.POSTED_VOID_ERROR_MESSAGE
                    )
                );
            }
            else {
                validCashDisbursements.add(cd);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashDisbursements;
        }
    }

    private void validateNotCleared(Boolean fullStatistics) {
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();
        for (Cash_Disbursement__c cd : (List<Cash_Disbursement__c>) sourceRecords) {
            if (cd.Bank_Reconciliation__c != NULL) {
                dispatcher.addPostErrorResult(
                    cd,
                    new PostResult.PostErrorResult(
                        cd.Bank_Reconciliation__r,
                        PostResult.StatusCode.CLEARED_BANK_RECONCILIATION,
                        UNPOST_CLEARED_ERROR_MESSAGE
                    )
                );
            }
            else {
                validCashDisbursements.add(cd);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashDisbursements;
        }
    }
    @TestVisible
    private void validatePaidAmountSumEqualsCashDisbursementAmount(Boolean fullStatistics) {
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();
        for (Cash_Disbursement__c cd : (List<Cash_Disbursement__c>) sourceRecords) {
            if (!cd.Account_Payable_Cash_Disbursements__r.isEmpty() && cd.Source__c != 'Manual') {
                Decimal paidAmount = 0;
                Decimal cdAmount = ((cd.Amount__c != NULL) ? cd.Amount__c : 0).setScale(2, System.RoundingMode.HALF_UP);

                for (AP_Disbursement__c apd : cd.Account_Payable_Cash_Disbursements__r) {
                    paidAmount += ((apd.Paid_Amount__c != NULL) ? apd.Paid_Amount__c : 0);
                }

                paidAmount = paidAmount.setScale(2, System.RoundingMode.HALF_UP);

                if (paidAmount != cdAmount) {
                    dispatcher.addPostErrorResult(
                        cd,
                        new PostResult.PostErrorResult(
                            cd,
                            PostResult.StatusCode.INCORRECT_APD_AMOUNT,
                            PAID_AMOUNT_NOT_EQUAL_CD_AMOUNT_ERROR_MESSAGE
                        )
                    );
                }
                else {
                    validCashDisbursements.add(cd);
                }
            }
            else {
                validCashDisbursements.add(cd);
            }
        }
        if (!fullStatistics) {
            sourceRecords = validCashDisbursements;
        }
    }

    //================================================================================================
    //  Validate the cash disbursement is not applied to account payable records in a prepaid scenario.
    //================================================================================================
    private void validateNotApplied(Boolean fullStatistics) {
        List<AP_Disbursement__c> apDisbursements = new List<AP_Disbursement__c>();
        Map<Id, Cash_Disbursement__c> validCashDisbursementsMap =
            new Map<Id, Cash_Disbursement__c>((List<Cash_Disbursement__c>) sourceRecords);

        for (Cash_Disbursement__c cd : (List<Cash_Disbursement__c>) sourceRecords) {
            apDisbursements.addAll(cd.Account_Payable_Cash_Disbursements__r);
        }

        //CRUD & FLS for the AP_Disbursement__c object are already checked before this point
        //Transactions must be accessible regardless of the user permission
        //to determine existence of at least one of them for each AP_Disbursement record
        Set<Id> apDisbIds = new Map<Id, AP_Disbursement__c>(apDisbursements).keySet();
        for (AP_Disbursement__c apd : DomainUtils.getApDisbursementsById(apDisbIds)) {
            if (apd.Transactions__r != NULL
                    && apd.Transactions__r.size() > 0
                    && validCashDisbursementsMap.containsKey(apd.Cash_Disbursement__c)) {

                Cash_Disbursement__c cd = validCashDisbursementsMap.remove(apd.Cash_Disbursement__c);
                dispatcher.addPostErrorResult(
                    cd,
                    new PostResult.PostErrorResult(
                        cd,
                        PostResult.StatusCode.APPLIED_TO_PAYABLE,
                        CashDisbursementPostHandler.UNPOST_APPLIED_ERROR_MESSAGE
                    )
                );
            }
        }

        if (!fullStatistics) {
            sourceRecords = validCashDisbursementsMap.values();
        }

    }

    private Boolean validateRecordsLimit() {
        Integer lineCount = sourceRecords.size();

        if (lineCount > CASH_DISBURSEMENTS_COUNT_LIMIT) {
            for (SObject cd : sourceRecords) {
                dispatcher.addPostErrorResult(
                    cd,
                    new PostResult.PostErrorResult(
                        cd,
                        PostResult.StatusCode.LINE_COUNT_LIMIT_EXCEEDED,
                        String.format(CASH_DISBURSEMENTS_COUNT_LIMIT_ERROR_MESSAGE, new List<String>{String.valueOf(CASH_DISBURSEMENTS_COUNT_LIMIT)})
                    )
                );
            }
            return false;
        }
        else {
            return true;
        }
    }

    private void validatePaymentDiscountGLAccount(Boolean fullStatistics) {
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();
        //check if there is dicount
        for (Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords) {
            Decimal discount = 0;

            for (AP_Disbursement__c apd : cashDisbursement.Account_Payable_Cash_Disbursements__r) {
                discount += apd.Discount_Amount__c == NULL ? 0 : apd.Discount_Amount__c;
            }

            if (discount > 0 && (!glAccountDefaults.containsKey(cashDisbursement.Ledger__c) ||
                (glAccountDefaults.containsKey(cashDisbursement.Ledger__c)
                    && !glAccountDefaults.get(cashDisbursement.Ledger__c).containsKey(GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT)))) {
                dispatcher.addPostErrorResult(
                    cashDisbursement,
                    new PostResult.PostErrorResult(
                        cashDisbursement,
                        PostResult.StatusCode.NO_DISCOUNT_PAYMENT_ACCOUNT,
                        NO_DISCOUNT_PAYMENT_ACCOUNT_MESSAGE
                    )
                );
            }
            else {
                validCashDisbursements.add(cashDisbursement);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validCashDisbursements;
        }
    }

    private void processPostCashDisbursements() {
        main = getAccountingSettings();
        List<Id> CDsForPaymentServices = new List<Id>();
        Savepoint sp = Database.setSavepoint();
        try {
            // delete any and all transactions associated with the source document
            // before another set of transactions are created and the status is changed
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));
            //=========================================================================================

            for (Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords) {
                cashDisbursement.Status__c = DEFAULT_POSTING_STATUS_POSTED;
                cashDisbursement.Debit_GL_Account__c =
                    (cashDisbursement.Debit_GL_Account__c == NULL && cashDisbursement.AP_Voucher_Count__c > 0)
                        ?  glAccountDefaults.get(cashDisbursement.Ledger__c).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c
                        : cashDisbursement.Debit_GL_Account__c;
                //set ref field and add CDs to collection for API message if they have not already been sent
                if(cashDisbursement.Type__c == AS_PAY_TYPE 
                    && cashDisbursement.Status__c == DEFAULT_POSTING_STATUS_POSTED
                    && (cashDisbursement.Payment_Service_Status__c == NULL || String.isEmpty(cashDisbursement.Payment_Service_Status__c))) 
                {
                    cashDisbursement.Payment_Services_Reference__c = cashDisbursement.Check_Number__c != NULL ? String.valueOf(cashDisbursement.Check_Number__c) : cashDisbursement.Name.split('-')[1];
                    CDsForPaymentServices.add(cashDisbursement.Id); 
                }  
            }

            List<Transaction__c> transList = createTransactions();

            //convert generic collection to the collection with specific SObjectType
            List<Cash_Disbursement__c> sourceRecordsToUpdate = new List<Cash_Disbursement__c>(
                (List<Cash_Disbursement__c>) sourceRecords
            );

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(sourceRecordsToUpdate, new List<String>{'Status__c'});
            TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Status__c);

            sourceRecords = DomainUtils.getCashDisbursementByIdForUpdate(
                new Map<Id, SObject>(sourceRecords).keySet() 
            );
            validatePostStatusSet();

            CubeBuilder.isEnabledCashFlowStatement = main.Enable_Cash_Flow_Statement__c;
            TransactionActions.createTransactions(transList);
            CubeBuilder.isEnabledCashFlowStatement = false;
            if(!CDsForPaymentServices.isEmpty()) {
                apAutomationPostMessage(CDsForPaymentServices);
            }
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private Decimal getAPLineAmount(List<AP_Disbursement__c> apDisbursements) {
        Decimal result = 0;

        for (AP_Disbursement__c eachApDisbursement : apDisbursements) {

            result += (eachApDisbursement.Paid_Amount__c == NULL)
                ? (eachApDisbursement.Net_Amount__c / ((eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c != NULL && eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c > 0)
                    ? eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c
                    : 1)).setScale(2, System.RoundingMode.HALF_UP)
                : (eachApDisbursement.Paid_Amount__c / ((eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c != NULL && eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c > 0)
                    ? eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c
                    : 1)).setScale(2, System.RoundingMode.HALF_UP);
        }

        return result;
    }

    private Decimal getDiscountAmount(List<AP_Disbursement__c> apDisbursements) {
        Decimal result = 0;
        for (AP_Disbursement__c eachApDisbursement : apDisbursements) {
            result += (eachApDisbursement.Discount_Amount__c == NULL)
                ? 0
                : (eachApDisbursement.Discount_Amount__c / ((eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c != NULL && eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c > 0)
                    ? eachApDisbursement.Account_Payable__r.Currency_Conversion_Rate__c
                    : 1)).setScale(2, System.RoundingMode.HALF_UP);
        }
        return result;
    }

    public void processUnpostCashDisbursements() {
        main = getAccountingSettings();
        Savepoint sp = Database.setSavepoint();
        try {
            TransactionActions.deleteTransactions(TransactionActions.queryTransactions(sourceRecords));

            String defaultPostingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Cash_Disbursement__c.Status__c);
            List<Cash_Disbursement__c> updateCashDisbursements = new List<Cash_Disbursement__c>();

            for (Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords) {
                if ((isLDVBatchContext && (cashDisbursement.Status__c == DEFAULT_POSTING_STATUS_UNPOSTING_IN_PROGRESS
                    || cashDisbursement.Status__c == DEFAULT_POSTING_STATUS_POSTED))
                    || (!isLDVBatchContext && cashDisbursement.Status__c == DEFAULT_POSTING_STATUS_POSTED)) {
                    cashDisbursement.Status__c = defaultPostingStatus;
                    cashDisbursement.Debit_GL_Account__c =
                        (cashDisbursement.Debit_GL_Account__c == NULL && cashDisbursement.AP_Voucher_Count__c > 0)
                            ? glAccountDefaults.get(cashDisbursement.Ledger__c).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c
                            : cashDisbursement.Debit_GL_Account__c;
                    updateCashDisbursements.add(cashDisbursement);
                }
            }

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(updateCashDisbursements, new List<String>{'Status__c'});
            TriggerObserver.reset();
        }
        catch (Exception ex) {
            Database.rollback(sp);
            throw ex;
        }
    }

    private List<Transaction__c> createTransactions() {
        //If MC is enabled ==================
        getCurrencyInformation();
        //===================================

        List<Transaction__c> transList = new List<Transaction__c>();

        for (Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords) {
            Decimal discount = 0;
            Decimal amount = cashDisbursement.Amount__c;

            for (AP_Disbursement__c apd : cashDisbursement.Account_Payable_Cash_Disbursements__r) {
                discount += apd.Discount_Amount__c == NULL ? 0 : apd.Discount_Amount__c;
            }

            if (cashDisbursement.Account_Payable_Cash_Disbursements__r == NULL
                    || cashDisbursement.Account_Payable_Cash_Disbursements__r.isEmpty()) {
                isLinkedWithAP = false;
            }

            //================================================
            //========== AP LINE (Debit) ===========================
            //================================================
            Transaction__c trans = createTransaction(cashDisbursement);
            //MC part ================================================================================================
            if (isMultiCurrencyAndDifferentCurrency(cashDisbursement.Id, trans.Ledger__c)) {
                trans.Foreign_Amount__c = amount + discount;
                trans.Foreign_Currency__c = String.valueOf(cashDisbursement.get('CurrencyIsoCode'));
                //if the CD is manual and diff currency then do not use values from APD record
                trans.Amount__c =
                    (isLinkedWithAP && cashDisbursement.Source__c != 'Manual')
                        ? (getAPLineAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r)
                                + getDiscountAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r))
                        : ((cashDisbursement.Amount__c / cashDisbursement.Currency_Conversion_Rate__c)
                                + discount/*discount always equals to zero here*/).setScale(2, System.RoundingMode.HALF_UP);
                //in some circumstances trans.Amount__c can be equal to zero
                //so to prevent "Divide by 0" exception in the row below - let's add proxy variable to store appropriate divider
                Decimal transactionAmountSafeForDivision = (trans.Amount__c.abs() != 0) ? trans.Amount__c : 1;
                trans.Currency_Conversion_Rate__c =
                    (isLinkedWithAP && cashDisbursement.Source__c != 'Manual')
                        ? (trans.Foreign_Amount__c / transactionAmountSafeForDivision).setScale(6, System.RoundingMode.HALF_UP)
                        : cashDisbursement.Currency_Conversion_Rate__c;
            }
            else {
                trans.Amount__c = amount + discount;
            }
            //========================================================================================================

            trans.GL_Account__c = getDebitGLAccount(cashDisbursement);
            transList.add(trans);

            //================================================
            //========== CASH LINE (Credit) ===========================
            //================================================
            trans = createTransaction(cashDisbursement);

            //MC part ================================================================================================
            if (isMultiCurrencyAndDifferentCurrency(cashDisbursement.Id, trans.Ledger__c)) {
                trans.Foreign_Amount__c = amount * -1;
                trans.Foreign_Currency__c = String.valueOf(cashDisbursement.get('CurrencyIsoCode'));
                trans.Currency_Conversion_Rate__c = cashDisbursement.Currency_Conversion_Rate__c;
                trans.Amount__c =
                    (cashDisbursement.Amount__c / trans.Currency_Conversion_Rate__c)
                        .setScale(2, System.RoundingMode.HALF_UP) * -1;
            }
            else {
                trans.Amount__c = amount * -1;
            }
            //========================================================================================================

            trans.GL_Account__c = cashDisbursement.Bank_Account__c;
            transList.add(trans);

            //================================================
            //========== PAYMENT DISCOUNT LINE ===============
            //================================================
            if (discount != 0) {
                trans = createPaymentDiscountTransaction(cashDisbursement, discount);
                transList.add(trans);
            }

            //=======================================================================
            //CREATE FOREIGN EXCHANGE GAIN/LOSS TRANSACTION LINE 
            //Do no create gain/loss transaction when multicurrency and CD is manual
            //=======================================================================
            
            if (isMultiCurrencyAndDifferentCurrency(cashDisbursement.Id, trans.Ledger__c) && cashDisbursement.Source__c != 'Manual'){
                    trans = createForeignExchangeTransaction(cashDisbursement,discount);
                    transList.add(trans);
            }

            if (cashDisbursement.Ledger__r.Accounting_Method__c != null && LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cashDisbursement.Ledger__c)) {
                transList.addAll(getShadowLedgerTransaction(cashDisbursement, amount, discount));
            }
        }
        return transList;
    }

    private Id getDebitGLAccount(Cash_Disbursement__c cashDisbursement) {
        Id glAccountId;
        if (cashDisbursement.Ledger__r.Accounting_Method__c == null
            || LedgerHandler.getInstanceWithoutSharing().isAccrualLedger(cashDisbursement.Ledger__c)
            || LedgerHandler.getInstanceWithoutSharing().isAccrualAndCashLedger(cashDisbursement.Ledger__c)) {
            glAccountId = cashDisbursement.Debit_GL_Account__c;
        } else if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(cashDisbursement.Ledger__c)) {
            if (String.isBlank(cashDisbursement.Debit_GL_Account__c)
                    && String.isBlank(glAccountDefaults.get(cashDisbursement.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c)) {
                throw new PostHandlerException(Label.ERR_UNAPPLIED_EXPENSE_DEFAULT_GL_ACCOUNT_REQUIRED);
            }
            glAccountId = cashDisbursement.Debit_GL_Account__c != null
                    ? cashDisbursement.Debit_GL_Account__c
                    : glAccountDefaults.get(cashDisbursement.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
        }

        return glAccountId;
    }

    private List<Transaction__c> getShadowLedgerTransaction(Cash_Disbursement__c cashDisbursement, Decimal amount, Decimal discount) {
        List<Transaction__c> shadowTrans = new List<Transaction__c>();
        Transaction__c trans = createTransaction(cashDisbursement);
        trans.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cashDisbursement.Ledger__c).Id;
        if (isMultiCurrencyAndDifferentCurrency(cashDisbursement.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = amount + discount;
            trans.Foreign_Currency__c = String.valueOf(cashDisbursement.get('CurrencyIsoCode'));
            //if the CD is manual and diff currency then do not use values from APD record
            trans.Amount__c =
                (isLinkedWithAP && cashDisbursement.Source__c != 'Manual')
                    ? (getAPLineAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r)
                    + getDiscountAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r))
                    : ((cashDisbursement.Amount__c / cashDisbursement.Currency_Conversion_Rate__c)
                    + discount/*discount always equals to zero here*/).setScale(2, System.RoundingMode.HALF_UP);
            //in some circumstances trans.Amount__c can be equal to zero
            //so to prevent "Divide by 0" exception in the row below - let's add proxy variable to store appropriate divider
            Decimal transactionAmountSafeForDivision = (trans.Amount__c.abs() != 0) ? trans.Amount__c : 1;
            trans.Currency_Conversion_Rate__c =
                (isLinkedWithAP && cashDisbursement.Source__c != 'Manual')
                    ? (trans.Foreign_Amount__c / transactionAmountSafeForDivision).setScale(6, System.RoundingMode.HALF_UP)
                    : cashDisbursement.Currency_Conversion_Rate__c;
        }
        else {
            trans.Amount__c = amount + discount;
        }

        if (String.isBlank(glAccountDefaults.get(trans.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c)) {
            throw new PostHandlerException(Label.ERR_UNAPPLIED_EXPENSE_DEFAULT_GL_ACCOUNT_REQUIRED);
        }
        trans.GL_Account__c = glAccountDefaults.get(trans.Ledger__c)?.get(GLAccountDefaultsHandler.UNAPPLIED_EXPENSE_GL_ACCOUNT)?.GL_Account__c;
        shadowTrans.add(trans);

        trans = createTransaction(cashDisbursement);
        trans.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cashDisbursement.Ledger__c).Id;

        if (isMultiCurrencyAndDifferentCurrency(cashDisbursement.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = amount * -1;
            trans.Foreign_Currency__c = String.valueOf(cashDisbursement.get('CurrencyIsoCode'));
            trans.Currency_Conversion_Rate__c = cashDisbursement.Currency_Conversion_Rate__c;
            trans.Amount__c =
                (cashDisbursement.Amount__c / trans.Currency_Conversion_Rate__c)
                    .setScale(2, System.RoundingMode.HALF_UP) * -1;
        }
        else {
            trans.Amount__c = amount * -1;
        }

        trans.GL_Account__c = cashDisbursement.Bank_Account__c;
        shadowTrans.add(trans);

        if (discount != 0) {
            trans = createTransaction(cashDisbursement);
            trans.Ledger__c = LedgerHandler.getInstanceWithoutSharing().getShadowLedgerByParent(cashDisbursement.Ledger__c).Id;
            if (isMultiCurrencyAndDifferentCurrency(cashDisbursement.Id, trans.Ledger__c)) {
                trans.Foreign_Amount__c = discount * -1;
                trans.Foreign_Currency__c = String.valueOf(cashDisbursement.get('CurrencyIsoCode'));
                trans.Currency_Conversion_Rate__c = cashDisbursement.Currency_Conversion_Rate__c;
                trans.Amount__c = getDiscountAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r) * -1;
            }
            else {
                trans.Amount__c = discount * -1;
            }

            trans.GL_Account__c = glAccountDefaults.get(trans.Ledger__c).containsKey(GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT) ?
                glAccountDefaults.get(trans.Ledger__c).get(GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT).GL_Account__c : null;
            shadowTrans.add(trans);
        }
        return shadowTrans;
    }

    private Transaction__c createTransaction(SObject obj) {
        Cash_Disbursement__c cashDisbursement = (Cash_Disbursement__c) obj;
        Transaction__c trans = new Transaction__c();
        trans.Cash_Disbursement__c = cashDisbursement.Id;
        trans.Ledger__c = cashDisbursement.Ledger__c != NULL ? cashDisbursement.Ledger__c : LedgerHandler.getLegacyDefaultLedgerId();
        trans.Accounting_Period__c = cashDisbursement.Accounting_Period__c;
        trans.Date__c = cashDisbursement.Disbursement_Date__c;
        trans.Account__c = cashDisbursement.Vendor__c;
        trans.Employee__c = cashDisbursement.Employee__c;
        trans.Contact__c = cashDisbursement.Contact__c;
        trans.GL_Account_Variable_1__c = cashDisbursement.GL_Account_Variable_1__c;
        trans.GL_Account_Variable_2__c = cashDisbursement.GL_Account_Variable_2__c;
        trans.GL_Account_Variable_3__c = cashDisbursement.GL_Account_Variable_3__c;
        trans.GL_Account_Variable_4__c = cashDisbursement.GL_Account_Variable_4__c;
        trans.Project__c = cashDisbursement.Project__c;
        trans.Project_Task__c = cashDisbursement.Project_Task__c;
        trans.Note__c = (cashDisbursement.Check_Number__c == NULL ? cashDisbursement.Reference__c : String.valueOf(cashDisbursement.Check_Number__c));
        trans.Check_Number__c = cashDisbursement.Check_Number__c;
        trans.Cash_Flow_Category__c = cashDisbursement.Cash_Flow_Category__c;
        trans.Product__c = cashDisbursement.Product__c;
        
        return trans;
    }

    private Transaction__c createForeignExchangeTransaction(SObject obj, Decimal discount) {
        Cash_Disbursement__c cashDisbursement = (Cash_Disbursement__c) obj;
        Transaction__c trans = createTransaction(cashDisbursement);

        Decimal apLineAmount =
            (isLinkedWithAP)
                ? getAPLineAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r) + getDiscountAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r)
                : cashDisbursement.Amount__c / cashDisbursement.Currency_Conversion_Rate__c;

        Decimal cashLineAmount = ((cashDisbursement.Amount__c / cashDisbursement.Currency_Conversion_Rate__c) * -1);

        Decimal discountLineAmount =
            (isLinkedWithAP)
                ? (getDiscountAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r) * -1)
                : discount/*discount always equals to zero here*/;

        trans.Amount__c = ((apLineAmount.setScale(2, System.RoundingMode.HALF_UP) + cashLineAmount.setScale(2, System.RoundingMode.HALF_UP) + discountLineAmount) * -1);
        trans.GL_Account__c = glAccountDefaults.get(cashDisbursement.Ledger__c).get(GLAccountDefaultsHandler.CURRENCY_GAIN_LOSS_GL_ACCOUNT).GL_Account__c;

        return trans;
    }

    private Transaction__c createPaymentDiscountTransaction(Sobject obj, Decimal discount) {
        Cash_Disbursement__c cashDisbursement = (Cash_Disbursement__c) obj;
        Transaction__c trans = createTransaction(cashDisbursement);

        //MC part ========================================================================================================
        if (isMultiCurrencyAndDifferentCurrency(cashDisbursement.Id, trans.Ledger__c)) {
            trans.Foreign_Amount__c = discount * -1;
            trans.Foreign_Currency__c = String.valueOf(cashDisbursement.get('CurrencyIsoCode'));
            trans.Currency_Conversion_Rate__c = cashDisbursement.Currency_Conversion_Rate__c;
            trans.Amount__c = getDiscountAmount(cashDisbursement.Account_Payable_Cash_Disbursements__r) * -1;
        }
        else {
            trans.Amount__c = discount * -1;
        }
        //==================================================================================================================

        trans.GL_Account__c = glAccountDefaults.get(cashDisbursement.Ledger__c).containsKey(GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT) ?
            glAccountDefaults.get(cashDisbursement.Ledger__c).get(GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT).GL_Account__c : NULL;
        return trans;
    }

    //Accessible and FLS checks are performed in Visualforce page for the records retrieved from this method.
    public List<Transaction__c> getForecastedTransactions() {
        Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
        List<Transaction__c> transList = new List<Transaction__c>();

        if (dispatcher.getExecutionContext() == PostResultDispatcher.ExecutionContext.POST) {
            transList = createTransactions();
            if (IS_MULTI_CURRENCY_ENABLED) {
                transList = setLedgerIsoCodeToTransactions(transList);
            }
        }
        else {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Ledger__c',
                'GL_Account__c',
                'Amount__c',
                'Product__c',
                'Project__c',
                'Project_Task__c',
                'GL_Account_Variable_1__c',
                'GL_Account_Variable_2__c',
                'GL_Account_Variable_3__c',
                'GL_Account_Variable_4__c'
            };

            if (IS_MULTI_CURRENCY_ENABLED) {
                queryFields.add('Foreign_Amount__c');
                queryFields.add('Foreign_Currency__c');
                queryFields.add('Currency_Conversion_Rate__c');
            }

            String queryCondition = 'Cash_Disbursement__c IN :sourceRecords';

            SOQLBuilder theQuery = new SOQLBuilder(Transaction__c.SObjectType);
            theQuery
                .setEnforceFLS(false)
                .selectFields(queryFields)
                .setCondition(queryCondition);

            transList = (List<Transaction__c>) Database.query(theQuery.toSOQL());
        }

        // In case the GL Account is NULL, set to the value of the AP Control GL Account
        for (Transaction__c trans : transList) {
            if (trans.GL_Account__c == NULL && glAccountDefaults.get(trans.Ledger__c).containsKey(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)) {
                trans.GL_Account__c = glAccountDefaults.get(trans.Ledger__c).get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT).GL_Account__c;
            }
        }

        return transList;

    }
    //Method to post message to CSI
    @TestVisible
    private void apAutomationPostMessage(List<Id> cashDisbursementIdsToPost) {
            APAutomationService.PostMessageQueueable postMessageQueueable = new APAutomationService.PostMessageQueueable(cashDisbursementIdsToPost, APAutomationService.APAutomationActions.CREATE_PAYMENTS.name());
            System.enqueueJob(postMessageQueueable);
    }

    //Method to validate if posting Status is Approved or not
    private void validatePostingStatus(Boolean fullStatistics) {
        List<Cash_Disbursement__c> validCashDisbursements = new List<Cash_Disbursement__c>();
        for (Cash_Disbursement__c cashDisbursement : (List<Cash_Disbursement__c>) sourceRecords) {
            if(cashDisbursement.AcctSeed__Status__c != 'Approved' && cashDisbursement.AcctSeed__Status__c != POSTED_STATUS){
                dispatcher.addPostErrorResult(
                    cashDisbursement,
                    new PostResult.PostErrorResult(
                        cashDisbursement,
                        PostResult.StatusCode.STATUS_NOT_APPROVED,
                        POSTING_STATUS_NOT_APPROVED_ERROR_MSG
                    )
                );
            }else{
                validCashDisbursements.add(cashDisbursement);
            }
        }

        if (!fullStatistics) {
            sourceRecords = validCashDisbursements;
        }
    }
}