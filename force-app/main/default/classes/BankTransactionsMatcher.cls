public with sharing class BankTransactionsMatcher {

    private static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    //For CR, BD, Debit JEL
    public static final Integer CASH_IN_DEFAULT_MATCHING_SETTING =
        (AccountingSettingsHandler.getCashInDefaultMatchingSetting() != NULL)
            ? (Integer) AccountingSettingsHandler.getCashInDefaultMatchingSetting() : 5;
    //For CD, Credit JEL
    public static final Integer CASH_OUT_DEFAULT_MATCHING_SETTING =
        (AccountingSettingsHandler.getCashOutDefaultMatchingSetting() != NULL)
            ? (Integer) AccountingSettingsHandler.getCashOutDefaultMatchingSetting() : 60;

    private FinancialSuiteUtils.DateRange btsDateRange;
    private FinancialSuiteUtils.DateRange cashInDateRange;
    private FinancialSuiteUtils.DateRange cashOutDateRange;
    private Set<Decimal> amountValues;
    private List<Bank_Deposit__c> bankDeposits;
    private List<Cash_Disbursement__c> cashDisbursements;
    private List<Cash_Receipt__c> cashReceipts;
    private List<Journal_Entry_Line__c> debitJournalEntryLines;
    private List<Journal_Entry_Line__c> creditJournalEntryLines;
    private List<Bank_Transaction__c> bankTransactions;
    private Map<Id, List<SObject>> bankTransactionIdToMatchingRecords;
    private Map<Id, List<Bank_Transaction__c>> sourceDocIdToMatchingBTs;
    private Map<String, Id> extAccountIdToBankGLAccountId;
    private Map<String, Id> extAccountIdToLedgerId;
    private ExecutionContext context;

    public enum ExecutionContext {UI, APEX_JOB}
    public enum JournalEntryLineSide {DEBIT, CREDIT}
    public class BankTransactionsMatcherException extends Exception {}

    public BankTransactionsMatcher(Set<Id> bankTransactionIds, ExecutionContext exContext) {
        try {
            this.context = exContext;
            this.extAccountIdToBankGLAccountId = new Map<String, Id>();
            this.extAccountIdToLedgerId = new Map<String, Id>();
            this.bankTransactions = DomainUtils.getBankTransactionsById(bankTransactionIds);
            this.btsDateRange = FinancialSuiteUtils.getDateRange(this.bankTransactions, Bank_Transaction__c.Date__c);
            this.cashInDateRange =
                new FinancialSuiteUtils.DateRange(
                    btsDateRange.startDate.addDays(-CASH_IN_DEFAULT_MATCHING_SETTING),
                    btsDateRange.endDate.addDays(CASH_IN_DEFAULT_MATCHING_SETTING)
                );
            this.cashOutDateRange =
                new FinancialSuiteUtils.DateRange(
                    btsDateRange.startDate.addDays(-CASH_OUT_DEFAULT_MATCHING_SETTING),
                    btsDateRange.endDate.addDays(CASH_OUT_DEFAULT_MATCHING_SETTING)
                );
            extractDataFromBankTransactions();
            querySourceDocuments();
        }
        catch (Exception ex) {
            throw new BankTransactionsMatcherException(ex.getMessage());
        }
    }

    public BankTransactionsMatcher(List<Bank_Transaction__c> bts, ExecutionContext exContext) {
        this(new Map<Id, Bank_Transaction__c>(bts).keySet(), exContext);
    }

    private void extractDataFromBankTransactions() {
        this.amountValues = new Set<Decimal>();
        for (Bank_Transaction__c bt : bankTransactions) {
            this.amountValues.add(bt.Amount__c);
            if (bt.Amount__c > 0) {
                this.amountValues.add(bt.Amount__c * -1);
            }
            this.extAccountIdToLedgerId.put(bt.GL_Account_Mapping__r.External_Id__c, bt.GL_Account_Mapping__r.Ledger__c);
            this.extAccountIdToBankGLAccountId.put(bt.GL_Account_Mapping__r.External_Id__c, bt.GL_Account_Mapping__r.GL_Account__c);
        }
    }

    private void querySourceDocuments() {
        Queryable queryExecutor;
        switch on this.context {
            when UI {
                queryExecutor = new QueryWrapper(this);
            }
            when APEX_JOB {
                queryExecutor = new QueryWrapperInWithoutSharingContext(this);
            }
        }
        this.cashReceipts = queryExecutor.queryCashReceipts();
        this.cashDisbursements = queryExecutor.queryCashDisbursements();
        this.debitJournalEntryLines = queryExecutor.queryJournalEntryLines(JournalEntryLineSide.DEBIT);
        this.creditJournalEntryLines = queryExecutor.queryJournalEntryLines(JournalEntryLineSide.CREDIT);
        this.bankDeposits = queryExecutor.queryBankDeposits();
    }

    public void searchMatchingRecords() {
        this.bankTransactionIdToMatchingRecords = new Map<Id, List<SObject>>();
        this.sourceDocIdToMatchingBTs = new Map<Id, List<Bank_Transaction__c>>();

        for (Bank_Transaction__c bt : this.bankTransactions) {
            if (bt.Base_Type__c == 'Credit') {
                searchInCashReceipts(bt);
                searchInBankDeposits(bt);
                searchInDebitJournalEntryLines(bt);
            }
            if (bt.Base_Type__c == 'Debit') {
                searchInCashDisbursements(bt);
                searchInCreditJournalEntryLines(bt);
                searchInCashReceipts(bt);
            }
        }
    }

    public List<SObject> getMatchingRecords(Id bankTransactionId) {
        return this.bankTransactionIdToMatchingRecords.get(bankTransactionId);
    }

    public Boolean hasMatchingRecords(Id bankTransactionId) {
        return this.bankTransactionIdToMatchingRecords.get(bankTransactionId) != NULL
                && !this.bankTransactionIdToMatchingRecords.get(bankTransactionId).isEmpty();
    }

    public List<Bank_Transaction__c> getBankTransactionsByMatchingRecord(Id sourceDocId) {
        return this.sourceDocIdToMatchingBTs.get(sourceDocId);
    }

    private FinancialSuiteUtils.DateRange getCashInDateRangeByBankTransaction(Bank_Transaction__c bt) {
        FinancialSuiteUtils.DateRange result =
            FinancialSuiteUtils.getDateRange(new List<Bank_Transaction__c>{bt}, Bank_Transaction__c.Date__c);
        result.startDate = result.startDate.addDays(- CASH_IN_DEFAULT_MATCHING_SETTING);
        result.endDate = result.endDate.addDays(CASH_IN_DEFAULT_MATCHING_SETTING);
        return result;
    }

    private FinancialSuiteUtils.DateRange getCashOutDateRangeByBankTransaction(Bank_Transaction__c bt) {
        FinancialSuiteUtils.DateRange result =
            FinancialSuiteUtils.getDateRange(new List<Bank_Transaction__c>{bt}, Bank_Transaction__c.Date__c);
        result.startDate = result.startDate.addDays(- CASH_OUT_DEFAULT_MATCHING_SETTING);
        result.endDate = result.endDate.addDays(CASH_OUT_DEFAULT_MATCHING_SETTING);
        return result;
    }

    private void searchInCashReceipts(Bank_Transaction__c bt) {
        if (this.cashReceipts != NULL && !this.cashReceipts.isEmpty()) {
            String btCurrency = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? (String) bt.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            Id ledgerId = extAccountIdToLedgerId.get(bt.Account_Id__c);
            Id bankGLAccountId = extAccountIdToBankGLAccountId.get(bt.Account_Id__c);
            Date startDate = bt.Base_Type__c == 'Debit' ? getCashOutDateRangeByBankTransaction(bt).startDate : getCashInDateRangeByBankTransaction(bt).startDate;
            Date endDate = bt.Base_Type__c == 'Debit' ? getCashOutDateRangeByBankTransaction(bt).endDate : getCashInDateRangeByBankTransaction(bt).endDate;

            for (Cash_Receipt__c cr : this.cashReceipts) {
                if (cr.Amount__c == (bt.Base_Type__c == 'Debit' ? bt.Amount__c * -1 : bt.Amount__c)
                        && cr.Ledger__c == ledgerId
                        && cr.Bank_Account__c == bankGLAccountId
                        && MultiCurrencyHandler.isSameCurrency(btCurrency, cr)
                        && cr.Receipt_Date__c >= startDate
                        && cr.Receipt_Date__c <= endDate) {

                    storeInMaps(bt, cr);
                }
            }
        }
    }

    private void searchInCashDisbursements(Bank_Transaction__c bt) {
        if (this.cashDisbursements != NULL && !this.cashDisbursements.isEmpty()) {
            String btCurrency = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? (String) bt.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            Id ledgerId = extAccountIdToLedgerId.get(bt.Account_Id__c);
            Id bankGLAccountId = extAccountIdToBankGLAccountId.get(bt.Account_Id__c);
            Date startDate = getCashOutDateRangeByBankTransaction(bt).startDate;
            Date endDate = getCashOutDateRangeByBankTransaction(bt).endDate;

            for (Cash_Disbursement__c cd : this.cashDisbursements) {
                if (cd.Amount__c == bt.Amount__c
                        && cd.Ledger__c == ledgerId
                        && cd.Bank_Account__c == bankGLAccountId
                        && MultiCurrencyHandler.isSameCurrency(btCurrency, cd)
                        && cd.Disbursement_Date__c >= startDate
                        && cd.Disbursement_Date__c <= endDate) {

                    storeInMaps(bt, cd);
                }
            }
        }
    }

    private void searchInBankDeposits(Bank_Transaction__c bt) {
        if (this.bankDeposits != NULL && !this.bankDeposits.isEmpty()) {
            String btCurrency = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? (String) bt.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            Id ledgerId = extAccountIdToLedgerId.get(bt.Account_Id__c);
            Id bankGLAccountId = extAccountIdToBankGLAccountId.get(bt.Account_Id__c);
            Date startDate = getCashInDateRangeByBankTransaction(bt).startDate;
            Date endDate = getCashInDateRangeByBankTransaction(bt).endDate;

            for (Bank_Deposit__c bd : this.bankDeposits) {
                if (bd.Amount__c == bt.Amount__c
                        && bd.Ledger__c == ledgerId
                        && bd.Bank_Account__c == bankGLAccountId
                        && MultiCurrencyHandler.isSameCurrency(btCurrency, bd)
                        && bd.Deposit_Date__c >= startDate
                        && bd.Deposit_Date__c <= endDate) {

                    storeInMaps(bt, bd);
                }
            }
        }
    }

    private void searchInDebitJournalEntryLines(Bank_Transaction__c bt) {
        if (this.debitJournalEntryLines != NULL && !this.debitJournalEntryLines.isEmpty()) {
            String btCurrency = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? (String) bt.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            Id ledgerId = bt.GL_Account_Mapping__r.Ledger__c;
            Id bankGLAccountId = bt.GL_Account_Mapping__r.GL_Account__c;
            Date startDate = getCashInDateRangeByBankTransaction(bt).startDate;
            Date endDate = getCashInDateRangeByBankTransaction(bt).endDate;

            for (Journal_Entry_Line__c jel : this.debitJournalEntryLines) {
                if (MultiCurrencyHandler.isSameCurrency(btCurrency, jel)
                        && jel.Journal_Entry__r.Ledger__c == ledgerId
                        && jel.GL_Account__c == bankGLAccountId
                        && jel.Debit__c == bt.Amount__c
                        && jel.Date__c >= startDate
                        && jel.Date__c <= endDate) {

                    storeInMaps(bt, jel);
                }
            }
        }
    }

    private void searchInCreditJournalEntryLines(Bank_Transaction__c bt) {
        if (this.creditJournalEntryLines != NULL && !this.creditJournalEntryLines.isEmpty()) {
            String btCurrency = (MultiCurrencyHandler.isMultiCurrencyEnabled) ? (String) bt.get('CurrencyIsoCode') : MultiCurrencyHandler.CORPORATE_CURRENCY;
            Id ledgerId = bt.GL_Account_Mapping__r.Ledger__c;
            Id bankGLAccountId = bt.GL_Account_Mapping__r.GL_Account__c;
            Date startDate = getCashOutDateRangeByBankTransaction(bt).startDate;
            Date endDate = getCashOutDateRangeByBankTransaction(bt).endDate;

            for (Journal_Entry_Line__c jel : this.creditJournalEntryLines) {
                if (MultiCurrencyHandler.isSameCurrency(btCurrency, jel)
                        && jel.Journal_Entry__r.Ledger__c == ledgerId
                        && jel.GL_Account__c == bankGLAccountId
                        && jel.Credit__c == bt.Amount__c
                        && jel.Date__c >= startDate
                        && jel.Date__c <= endDate) {

                    storeInMaps(bt, jel);
                }
            }
        }
    }

    private void storeInMaps(Bank_Transaction__c bt, SObject sourceDoc) {
        if (this.bankTransactionIdToMatchingRecords.containsKey(bt.Id)) {
            this.bankTransactionIdToMatchingRecords.get(bt.Id).add(sourceDoc);
        }
        else {
            this.bankTransactionIdToMatchingRecords.put(bt.Id, new List<SObject>{sourceDoc});
        }
        if (this.sourceDocIdToMatchingBTs.containsKey(sourceDoc.Id)) {
            this.sourceDocIdToMatchingBTs.get(sourceDoc.Id).add(bt);
        }
        else {
            this.sourceDocIdToMatchingBTs.put(sourceDoc.Id, new List<Bank_Transaction__c>{bt});
        }
    }

    private interface Queryable {
        List<Bank_Deposit__c> queryBankDeposits();
        List<Cash_Disbursement__c> queryCashDisbursements();
        List<Cash_Receipt__c> queryCashReceipts();
        List<Journal_Entry_Line__c> queryJournalEntryLines(JournalEntryLineSide side);
    }

    private without sharing class QueryWrapperInWithoutSharingContext implements Queryable {
        private QueryWrapper qWrapper;
        private QueryWrapperInWithoutSharingContext(BankTransactionsMatcher matcher) {
            this.qWrapper = new QueryWrapper(matcher);
        }

        public List<Bank_Deposit__c> queryBankDeposits() {
            return qWrapper.queryBankDeposits();
        }
        public List<Cash_Disbursement__c> queryCashDisbursements() {
            return qWrapper.queryCashDisbursements();
        }
        public List<Cash_Receipt__c> queryCashReceipts() {
            return qWrapper.queryCashReceipts();
        }
        public List<Journal_Entry_Line__c> queryJournalEntryLines(JournalEntryLineSide side) {
            return qWrapper.queryJournalEntryLines(side);
        }
    }

    private inherited sharing class QueryWrapper implements Queryable {
        private BankTransactionsMatcher matcher;

        private QueryWrapper(BankTransactionsMatcher matcher) {
            this.matcher = matcher;
        }
        //==================== SOQL Queries for possible matching records  ===============================
        public List<Bank_Deposit__c> queryBankDeposits() {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Bank_Transaction__c',
                'Deposit_Date__c',
                'Bank_Account__c',
                'Deposit_Reference__c',
                'Amount__c',
                'Ledger__c'
            };

            if (IS_MULTI_CURRENCY_ENABLED) {
                queryFields.add('CurrencyIsoCode');
            }

            Date startDate = matcher.cashInDateRange.startDate;
            Date endDate = matcher.cashInDateRange.endDate;
            Set<Decimal> amountValues = matcher.amountValues;
            List<Id> bankGlAccountIds = matcher.extAccountIdToBankGLAccountId.values();
            List<Id> ledgerIds = matcher.extAccountIdToLedgerId.values();

            String queryCondition =
                'Bank_Id__c = NULL AND Bank_Transaction__c = NULL ' +
                    'AND Deposit_Date__c >= :startDate ' +
                    'AND Deposit_Date__c <= :endDate ' +
                    'AND Amount__c IN :amountValues ' +
                    'AND Bank_Account__c IN :bankGlAccountIds ' +
                    'AND Ledger__c IN :ledgerIds';

            SOQLBuilder theQuery = new SOQLBuilder(Bank_Deposit__c.SObjectType);
            if (matcher.context == BankTransactionsMatcher.ExecutionContext.UI) {
                theQuery.assertIsAccessible().setEnforceFLS(true);
            }
            theQuery
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(calculateAvailableQueryRowsLimit());

            return (List<Bank_Deposit__c>) Database.query(theQuery.toSOQL());
        }

        public List<Cash_Disbursement__c> queryCashDisbursements() {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Bank_Transaction__c',
                'Disbursement_Date__c',
                'Bank_Account__c',
                'Amount__c',
                'Ledger__c',
                'Vendor__c',
                'Contact__c',
                'Employee__c',
                'Debit_GL_Account__c',
                'Reference__c',
                'Description__c'
            };

            if (IS_MULTI_CURRENCY_ENABLED) {
                queryFields.add('CurrencyIsoCode');
            }

            Date startDate = matcher.cashOutDateRange.startDate;
            Date endDate = matcher.cashOutDateRange.endDate;
            Set<Decimal> amountValues = matcher.amountValues;
            List<Id> bankGlAccountIds = matcher.extAccountIdToBankGLAccountId.values();
            List<Id> ledgerIds = matcher.extAccountIdToLedgerId.values();

            String queryCondition =
                'Bank_Id__c = NULL AND Bank_Transaction__c = NULL AND Payment_Status__c != \'Void\' ' +
                    'AND Disbursement_Date__c >= :startDate ' +
                    'AND Disbursement_Date__c <= :endDate ' +
                    'AND Amount__c IN :amountValues ' +
                    'AND Bank_Account__c IN :bankGlAccountIds ' +
                    'AND Ledger__c IN :ledgerIds';

            SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
            if (matcher.context == BankTransactionsMatcher.ExecutionContext.UI) {
                theQuery.assertIsAccessible().setEnforceFLS(true);
            }
            theQuery
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(calculateAvailableQueryRowsLimit());

            return (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
        }

        public List<Cash_Receipt__c> queryCashReceipts() {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'Bank_Transaction__c',
                'Receipt_Date__c',
                'Bank_Account__c',
                'Ledger__c',
                'Amount__c',
                'Account__c',
                'Credit_GL_Account__c',
                'Description__c',
                'Void__c'
            };

            if (IS_MULTI_CURRENCY_ENABLED) {
                queryFields.add('CurrencyIsoCode');
            }

            Date startDate = CASH_IN_DEFAULT_MATCHING_SETTING >= CASH_OUT_DEFAULT_MATCHING_SETTING ? matcher.cashInDateRange.startDate : matcher.cashOutDateRange.startDate;
            Date endDate = CASH_IN_DEFAULT_MATCHING_SETTING >= CASH_OUT_DEFAULT_MATCHING_SETTING ? matcher.cashInDateRange.endDate :  matcher.cashOutDateRange.endDate;
            Set<Decimal> amountValues = matcher.amountValues;
            List<Id> bankGlAccountIds = matcher.extAccountIdToBankGLAccountId.values();
            List<Id> ledgerIds = matcher.extAccountIdToLedgerId.values();

            String queryCondition =
                'Bank_Id__c = NULL AND Bank_Transaction__c = NULL ' +
                    'AND Bank_Deposit__c = NULL ' +
                    'AND Receipt_Date__c >= :startDate ' +
                    'AND Receipt_Date__c <= :endDate ' +
                    'AND Amount__c IN :amountValues ' +
                    'AND Bank_Account__c IN :bankGlAccountIds ' +
                    'AND Ledger__c IN :ledgerIds ' +
                    'AND Void__c = false';

            SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
            if (matcher.context == BankTransactionsMatcher.ExecutionContext.UI) {
                theQuery.assertIsAccessible().setEnforceFLS(true);
            }
            theQuery
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(calculateAvailableQueryRowsLimit());

            return (List<Cash_Receipt__c>) Database.query(theQuery.toSOQL());
        }

        public List<Journal_Entry_Line__c> queryJournalEntryLines(JournalEntryLineSide side) {
            List<String> queryFields = new List<String>{
                'Id',
                'Name',
                'GL_Account__c',
                'Amount__c',
                'Debit__c',
                'Credit__c',
                'Bank_Transaction__c',
                'Journal_Entry__r.Journal_Date__c',
                'Journal_Entry__r.Ledger__c',
                'Account__c',
                'Contact__c',
                'Employee__c',
                'Reference__c',
                'Date__c',
                'Description__c'
            };

            if (IS_MULTI_CURRENCY_ENABLED) {
                queryFields.add('CurrencyIsoCode');
            }

            Date cashInStartDate = matcher.cashInDateRange.startDate;
            Date cashInEndDate = matcher.cashInDateRange.endDate;
            Date cashOutStartDate = matcher.cashOutDateRange.startDate;
            Date cashOutEndDate = matcher.cashOutDateRange.endDate;
            Set<Decimal> amountValues = matcher.amountValues;
            List<Id> bankGlAccountIds = matcher.extAccountIdToBankGLAccountId.values();
            List<Id> ledgerIds = matcher.extAccountIdToLedgerId.values();

            String debitCreditSideConditions = '';
            if (side == NULL) {
                debitCreditSideConditions =
                    '(' +
                        '(Credit__c != NULL AND (Date__c >= :cashOutStartDate AND Date__c <= :cashOutEndDate))' +
                        ' OR ' +
                        '(Debit__c != NULL AND (Date__c >= :cashInStartDate AND Date__c <= :cashInEndDate))' +
                    ') ';
            }
            else if (side == JournalEntryLineSide.DEBIT) {
                debitCreditSideConditions =
                    '(Debit__c != NULL AND (Date__c >= :cashInStartDate AND Date__c <= :cashInEndDate)) ';
            }
            else if (side == JournalEntryLineSide.CREDIT) {
                debitCreditSideConditions =
                    '(Credit__c != NULL AND (Date__c >= :cashOutStartDate AND Date__c <= :cashOutEndDate)) ';
            }

            String queryCondition =
                'Bank_Id__c = NULL AND Bank_Transaction__c = NULL ' +
                    'AND Bank_Deposit__c = NULL ' +
                    'AND ' + debitCreditSideConditions +
                    'AND Amount__c IN :amountValues ' +
                    'AND GL_Account__c IN :bankGlAccountIds ' +
                    'AND Journal_Entry__r.Ledger__c IN :ledgerIds';

            SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
            if (matcher.context == BankTransactionsMatcher.ExecutionContext.UI) {
                theQuery.assertIsAccessible().setEnforceFLS(true);
            }
            theQuery
                .selectFields(queryFields)
                .setCondition(queryCondition)
                .setLimit(calculateAvailableQueryRowsLimit());

            return (List<Journal_Entry_Line__c>) Database.query(theQuery.toSOQL());
        }

        private Integer calculateAvailableQueryRowsLimit() {
            return Limits.getLimitQueryRows() - Limits.getQueryRows();
        }
        //=============================================================================================================
    }

}