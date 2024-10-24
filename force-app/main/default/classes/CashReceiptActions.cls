public with sharing class CashReceiptActions {
   
    public static String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public static final String BILLING_CASH_RECEPT_ERROR = Label.ERR_BILLING_CASH_RECEPT_DELETE;
    public static final String TRANSACTION_CHECK_ERROR = Label.ERR_CASH_RECEIPT_TRANSACTION_CHECK;
    public static final String PAYMENT_TYPE_ELECTRONIC = 'Electronic';
    public static final String STATUS_APPROVED = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
    public static final String STATUS_POSTED = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;


    public static final String[] nonUpdateFields = new String[]{
            PACKAGE_QUALIFIER + 'Bank_Reconciliation__c',
            PACKAGE_QUALIFIER + 'Bank_Deposit__c'
    };

    public static final Map<SObjectField, Integer> currencyAndNumberFields = new Map<SObjectField, Integer> {
        Cash_Receipt__c.Amount__c => 2,
        Cash_Receipt__c.Currency_Conversion_Rate__c => 6,
        Cash_Receipt__c.Convenience_Fees_Charged__c => 2
    };

    private static final String PAYMENT_TYPE_CHECK = 'Check';

    public static Boolean isFirstRun = true;
    public static Boolean isSkipAutoGLAVsFromAccount = false;

    public static void populateCreditGLAccount(List<Cash_Receipt__c> receiptList) {
        for (Cash_Receipt__c cr : receiptList) {
            if (cr.Status__c != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED && cr.Credit_GL_Account__c == null) {
                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(cr.Ledger__c);
                if (!LedgerHandler.getInstanceWithoutSharing().isCashLedger(cr.Ledger__c)
                        && defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)?.GL_Account__c != null) {

                    cr.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)?.GL_Account__c;

                } else if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(cr.Ledger__c)
                        && defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT)?.GL_Account__c != null) {

                    cr.Credit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.UNAPPLIED_REVENUE_GL_ACCOUNT)?.GL_Account__c;

                } else {
                    if (LedgerHandler.getInstanceWithoutSharing().isCashLedger(cr.Ledger__c)) {
                        cr.addError(Label.ERR_CR_NO_UNAPPLIED_REVENUE_GL_ACCOUNT);
                    } else {
                        cr.addError(
                            String.format(Label.ERR_DEFAULT_GL_ACCOUNT_REQUIRED, new List<String>{
                                Label.COMMON_CASH_RECEIPT
                            })
                        );
                    }
                }
            }
        }
    }

    public static void setDefaultBankAccountAndCheckControlAccount(List<Cash_Receipt__c> receiptList) {
        Accounting_Settings__c main = AccountingSettingsHandler.getAccountingSettings();
        Set<Id> ledgerIds = new Set<Id>();
        for (Cash_Receipt__c receipt : receiptList) {
            if (receipt.Ledger__c != NULL) {
                ledgerIds.add(receipt.Ledger__c);
            }
        }
        Map<Id, Ledger__c> transactionalLedgersMap = new Map<Id, Ledger__c>(
            LedgerHandler.getInstanceWithoutSharing().getTransactionalLedgersById(ledgerIds)
        );

        for (Cash_Receipt__c receipt : receiptList) {
            if (receipt.Ledger__c != NULL && receipt.Bank_Account__c == NULL) {
                receipt.Bank_Account__c = transactionalLedgersMap.get(receipt.Ledger__c)?.Default_Bank_Account__c;
            }
        }

        for (Cash_Receipt__c cashReceipt : receiptList) {
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(cashReceipt.Ledger__c);
            if (defaultsBySpecDevNames?.get(GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT) == null) {
                cashReceipt.addError(CashReceiptPostHandler.NO_UNAPPLIED_CASH_GL_ACCOUNT_MESSAGE, false);
            }
        }
    }
    
    public static void preventDeleteBillingCashReceipts(List<Cash_Receipt__c> receiptList) {
        for (Cash_Receipt__c cashReceipt : receiptList) {
            if (cashReceipt.Number_of_Billing_Cash_Receipts__c > 0) {
               cashReceipt.addError(BILLING_CASH_RECEPT_ERROR, false);
            }
        }
    }
    
    public static void setDefaultFields(List<Cash_Receipt__c> receiptList) {
        try {
            String defaultValue = FinancialSuiteUtils.getDefaultPostingStatus(Cash_Receipt__c.Status__c);
            Id defaultLedgerId = LedgerHandler.getLedgerIdWithSharing();
            for (Cash_Receipt__c cashReceipt : receiptList) {
                cashReceipt.Status__c = (String.isBlank(cashReceipt.Status__c) || SObjectActions.isPostedStatus(cashReceipt)) ? defaultValue : cashReceipt.Status__c;
                cashReceipt.Void_Date__c = NULL;
                cashReceipt.Void__c = false;
                cashReceipt.Bank_Deposit__c = NULL;
                if (cashReceipt.isClone()) {
                    cashReceipt.Cleared_Date__c = NULL;
                }
                cashReceipt.Bank_Reconciliation__c = NULL;
                cashReceipt.Void__c = false;
                cashReceipt.Void_Date__c = null;
                cashReceipt.Void_Description__c = '';
                SObjectActions.populateLedgerField(cashReceipt, defaultLedgerId);
                MultiCurrencyHandler.setCurrencyIsoCodeToUserCurrency(cashReceipt);
            }
        }
        catch (Exception ex) {
            for (Cash_Receipt__c cashReceipt : receiptList) {
                cashReceipt.addError(ex.getMessage(), false);
            }
        }
    }

    public static void requireAndValidateFields(List<Cash_Receipt__c> receiptList) {
        for (Cash_Receipt__c cashReceipt : receiptList) {
            if (cashReceipt.Accounting_Period__c == NULL) {
                cashReceipt.Accounting_Period__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
                        
            if (cashReceipt.Bank_Account__c == NULL) {
                cashReceipt.Bank_Account__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }
    
            if (cashReceipt.Ledger__c == NULL) {
                cashReceipt.Ledger__c.addError(SObjectActions.REQUIRED_FIELD_ERROR);
            }

            if (cashReceipt.Check_Number__c != null && cashReceipt.Amount__c > 0) {
                cashReceipt.Check_Number__c.addError(Label.ERR_CR_CHECK_NUMBER_POS_AMOUNT);
            }            
        }       
    }

    public static void associateWithCashFlowCategory(List<Cash_Receipt__c> newCashReceipts) {
        for (Cash_Receipt__c cr : newCashReceipts) {
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(cr.Ledger__c);
            cr.Cash_Flow_Category__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.DEFAULT_CASH_RECEIPT_CATEGORY)?.GL_Account__c;
        }
    }

    public static void post(List<Cash_Receipt__c> newRecords) {
        if (AccountingSettingsHandler.isAutoPostCashReceiptsEnabled()) {
            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            isFirstRun = false;//to bypass GLAccountValidator after Posting Status change
            List<PostResult> postResults = postHandler.post(newRecords);

            //Check posting results
            List<Task> postErrorActivities = new List<Task>();
            Set<Id> postedRecordIds = new Set<Id>();
            for (PostResult result : postResults) {
                if (!result.isSuccess) {
                    postErrorActivities.add(
                        FinancialSuiteUtils.setTask(
                            result.id,
                            Label.COMMON_ERR_CANNOT_POST_RECORD,
                            !result.errors.isEmpty() ? result.errors.get(0).message : NULL
                        )
                    );
                }
                else {
                    postedRecordIds.add(result.id);
                }
            }

            if (!postErrorActivities.isEmpty()) {
                SFDCSecurityUtils.insertProxy(postErrorActivities);
            }

            if (!postedRecordIds.isEmpty()) {
                //count Transactions existed for records passed post handler execution
                Set<Id> newRecordWithTransactions = new Set<Id>();
                for (AggregateResult aggregateResult : DomainUtils.countTransactionsByCashReceipt(postedRecordIds)) {
                    newRecordWithTransactions.add((Id) aggregateResult.get('sourceDoc'));
                }
                //check if Transactions were created for all new and successfully posted records
                for (Cash_Receipt__c cr : newRecords) {
                    if (postedRecordIds.contains(cr.Id) && !newRecordWithTransactions.contains(cr.Id)) {
                        cr.addError(TRANSACTION_CHECK_ERROR);
                    }
                }
            }
        }
    }


    public static void amountToWords(List<Cash_Receipt__c> cashReceipts) {
        for (Cash_Receipt__c cr : cashReceipts) {
            if (cr.Payment_Type__c == PAYMENT_TYPE_CHECK) {
                cr.Amount_In_Words__c = CheckUtils.toWords(cr.Amount__c);
            }
        }
    }

    public static void setCheckNumber(List<Cash_Receipt__c> cashReceipts) {
        for (Cash_Receipt__c cr : cashReceipts) {
            if (cr.Payment_Type__c == PAYMENT_TYPE_CHECK && cr.Amount__c <= 0 && cr.Check_Number__c == null) {
                cr.Check_Number__c = CheckUtils.getNextCheckNumber(cr.Bank_Account__c);
            }
        }
    }

    public static void postApprovedCashReceipts(List<Cash_Receipt__c> cashReceipts, Map<Id,Cash_Receipt__c> oldCashReceipts){
        List<Cash_Receipt__c> approvedCr = new List<Cash_Receipt__c>();
        for(Cash_Receipt__c cr : cashReceipts){
            if(oldCashReceipts.get(cr.Id).Status__c != STATUS_APPROVED && oldCashReceipts.get(cr.Id).Status__c != STATUS_POSTED && cr.Status__c == STATUS_APPROVED){
                approvedCr.add(cr);
            }
        }
        if(!approvedCr.isEmpty()){
            post(approvedCr);
        }
    }

    public static void postApprovedCashReceipts(List<Cash_Receipt__c> cashReceipts){
        List<Cash_Receipt__c> approvedCr = new List<Cash_Receipt__c>();
        for(Cash_Receipt__c cr : cashReceipts){
            if(cr.Status__c == STATUS_APPROVED){
                approvedCr.add(cr);
            }
        }
        if(!approvedCr.isEmpty()){
            post(approvedCr);
        }
    }
}