public with sharing class FinancialTransactionMatchingProvider {

    private static final Boolean IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;

    //For CR, BD, Debit JEL
    @TestVisible
    private static final Integer CREDIT_PLUS_MINUS_OFFSET_IN_DAYS = 5;
    //For CD, Credit JEL
    @TestVisible
    private static final Integer DEBIT_PLUS_MINUS_OFFSET_IN_DAYS = 60;

    private Date startDate;
    private Date endDate;
    private Map<Id, Bank_Deposit__c> availableBankDeposits;
    private Map<Id, Cash_Disbursement__c> availableCashDisbursements;
    private Map<Id, Cash_Receipt__c> availableCashReceipts;
    private Map<Id, Journal_Entry_Line__c> availableJournalEntryLines;
    private Map<Id, Account> availableVendors;
    private Set<Id> alreadyMatchedIds;
    private Set<Id> legacyRecordsIds;
    private Set<Decimal> amountValues;
    private Date creditStartDateFilterValue;
    private Date creditEndDateFilterValue;
    private Date debitStartDateFilterValue;
    private Date debitEndDateFilterValue;
    private Id defaultVendorId;
    private Boolean isLedgerEqualLegacyLedger;
    private Id ledgerId;
    private Id bankAccount;


    public FinancialTransactionMatchingProvider(Date startDate,
                                                Date endDate,
                                                Set<Id> legacyRecordsIds,
                                                Set<Decimal> amountValues,
                                                Id ledgerId,
                                                Id bankAccount) {
        this.startDate = startDate;
        this.endDate = endDate;
        this.legacyRecordsIds = legacyRecordsIds;
        this.amountValues = amountValues;
        this.ledgerId = ledgerId;
        this.bankAccount = bankAccount;
        this.alreadyMatchedIds = new Set<Id>();
        this.creditStartDateFilterValue = startDate.addDays(- CREDIT_PLUS_MINUS_OFFSET_IN_DAYS);
        this.creditEndDateFilterValue = endDate.addDays(CREDIT_PLUS_MINUS_OFFSET_IN_DAYS);
        this.debitStartDateFilterValue = startDate.addDays(- DEBIT_PLUS_MINUS_OFFSET_IN_DAYS);
        this.debitEndDateFilterValue = endDate.addDays(DEBIT_PLUS_MINUS_OFFSET_IN_DAYS);
        this.defaultVendorId = AccountingSettingsHandler.getAccountingSettings().Default_Vendor__c;
        this.isLedgerEqualLegacyLedger = LedgerHandler.isLedgerEqualLegacyLedger(this.ledgerId);
        queryAvailableRecords();
    }

    private void queryAvailableRecords() {
        availableBankDeposits = new Map<Id, Bank_Deposit__c>(queryAvailableBankDeposits());
        availableCashDisbursements = new Map<Id, Cash_Disbursement__c>(queryAvailableCashDisbursements());
        availableCashReceipts = new Map<Id, Cash_Receipt__c>(queryAvailableCashReceipts());
        availableJournalEntryLines = new Map<Id, Journal_Entry_Line__c>(queryAvailableJournalEntryLines());
        availableVendors = new Map<Id, Account>(queryAvailableVendors());
    }

    public List<MatchingRecordWrapper> getMatchingRecords(FinancialImportLineWrapper bankTransactionLine) {
        List<MatchingRecordWrapper> result = new List<MatchingRecordWrapper>();
        //Extract info from the wrapped line
        Decimal recAmount = (Decimal) bankTransactionLine.obj.get('Amount__c');
        FinancialImportLineWrapper.TransactionType transactionType = bankTransactionLine.tranType;
        Date recDate = bankTransactionLine.getDate();
        String externalId = bankTransactionLine.extId;
        String currencyCode = bankTransactionLine.currencyCode;

        Date dateBeforeThis;
        Date dateAfterThis;

        if (transactionType == FinancialImportLineWrapper.TransactionType.DEBIT) {

            dateBeforeThis = recDate.addDays(- DEBIT_PLUS_MINUS_OFFSET_IN_DAYS);
            dateAfterThis = recDate.addDays(DEBIT_PLUS_MINUS_OFFSET_IN_DAYS);

            for (Cash_Disbursement__c cd : availableCashDisbursements.values()) {
                if (cd.Amount__c == recAmount
                        && MultiCurrencyHandler.isSameCurrency(currencyCode, cd)
                        && cd.Disbursement_Date__c >= dateBeforeThis
                        && cd.Disbursement_Date__c <= dateAfterThis) {

                    if (!alreadyMatchedIds.contains(cd.Id)) {
                        result.add(new MatchingRecordWrapper(cd, externalId));
                        alreadyMatchedIds.add(cd.Id);
                    }
                }
            }

            for (Journal_Entry_Line__c jeLine : availableJournalEntryLines.values()) {
                if (jeLine.Credit__c != NULL
                        && jeLine.Credit__c == recAmount
                        && MultiCurrencyHandler.isSameCurrency(currencyCode, jeLine)
                        && jeLine.Date__c >= dateBeforeThis
                        && jeLine.Date__c <= dateAfterThis) {

                    if (!alreadyMatchedIds.contains(jeLine.Id)) {
                        result.add(new MatchingRecordWrapper(jeLine, externalId));
                        alreadyMatchedIds.add(jeLine.Id);
                    }
                }
            }
        }

        if (transactionType == FinancialImportLineWrapper.TransactionType.CREDIT) {

            dateBeforeThis = recDate.addDays(- CREDIT_PLUS_MINUS_OFFSET_IN_DAYS);
            dateAfterThis = recDate.addDays(CREDIT_PLUS_MINUS_OFFSET_IN_DAYS);

            for (Cash_Receipt__c cr : availableCashReceipts.values()) {
                if (cr.Amount__c == recAmount
                        && MultiCurrencyHandler.isSameCurrency(currencyCode, cr)
                        && cr.Receipt_Date__c >= dateBeforeThis
                        && cr.Receipt_Date__c <= dateAfterThis) {

                    if (!alreadyMatchedIds.contains(cr.Id)) {
                        result.add(new MatchingRecordWrapper(cr, externalId));
                        alreadyMatchedIds.add(cr.Id);
                    }

                }
            }

            for (Bank_Deposit__c bankDeposit : availableBankDeposits.values()) {
                if (bankDeposit.Amount__c == recAmount
                        && MultiCurrencyHandler.isSameCurrency(currencyCode, bankDeposit)
                        && bankDeposit.Deposit_Date__c >= dateBeforeThis
                        && bankDeposit.Deposit_Date__c <= dateAfterThis) {

                    if (!alreadyMatchedIds.contains(bankDeposit.Id)) {
                        result.add(new MatchingRecordWrapper(bankDeposit, externalId));
                        alreadyMatchedIds.add(bankDeposit.Id);
                    }

                }
            }

            for (Journal_Entry_Line__c jeLine : availableJournalEntryLines.values()) {
                if (jeLine.Debit__c != NULL
                        && jeLine.Debit__c == recAmount
                        && MultiCurrencyHandler.isSameCurrency(currencyCode, jeLine)
                        && jeLine.Date__c >= dateBeforeThis
                        && jeLine.Date__c <= dateAfterThis) {

                    if (!alreadyMatchedIds.contains(jeLine.Id)) {
                        result.add(new MatchingRecordWrapper(jeLine, externalId));
                        alreadyMatchedIds.add(jeLine.Id);
                    }
                }
            }
        }

        return result;
    }

    public Id getMatchingVendorId(String bankTransactionVendorName) {
        Id result;
        for (Account eachAccount : availableVendors.values()) {
            if (!String.isBlank(bankTransactionVendorName)
                    && bankTransactionVendorName.containsIgnoreCase(eachAccount.Name)) {

                result = eachAccount.Id;
                break;
            }
        }

        if (result == NULL) {
            result = this.defaultVendorId;//from Accounting Settings
        }

        return result;
    }

    private Integer calculateAvailableQueryRowsLimit() {
        return Limits.getLimitQueryRows() - Limits.getQueryRows();
    }

    private List<Bank_Deposit__c> queryAvailableBankDeposits() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Bank_Id__c',
            'Deposit_Date__c',
            'Bank_Account__c',
            'Amount__c',
            'Ledger__c',
            'Cleared_Date__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition =
            'Bank_Id__c = NULL ' +
                ((legacyRecordsIds != NULL && !legacyRecordsIds.isEmpty()) ? 'AND Id NOT IN :legacyRecordsIds ' : '') +
            'AND Deposit_Date__c >= :creditStartDateFilterValue ' +
            'AND Deposit_Date__c <= :creditEndDateFilterValue ' +
            'AND Amount__c IN :amountValues ' +
            'AND (Ledger__c = :ledgerId' +
            (isLedgerEqualLegacyLedger ? ' OR Ledger__c = NULL)' : ' ') +
            (!isLedgerEqualLegacyLedger ? ') ' : ' ') +
            'AND Bank_Account__c = :bankAccount';

        SOQLBuilder theQuery = new SOQLBuilder(Bank_Deposit__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(calculateAvailableQueryRowsLimit());

        return (List<Bank_Deposit__c>) Database.query(theQuery.toSOQL());
    }

    private List<Cash_Disbursement__c> queryAvailableCashDisbursements() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Disbursement_Date__c',
            'Amount__c',
            'Accounting_Period__c',
            'Vendor__c',
            'Project__c',
            'Project_Task__c',
            'Ledger__c',
            'Cleared_Date__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Debit_GL_Account__c',
            'Bank_Id__c',
            'Cash_Flow_Category__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition =
            'Bank_Id__c = NULL ' +
                ((legacyRecordsIds != NULL && !legacyRecordsIds.isEmpty()) ? 'AND Id NOT IN :legacyRecordsIds ' : '') +
            'AND Disbursement_Date__c >= :debitStartDateFilterValue ' +
            'AND Disbursement_Date__c <= :debitEndDateFilterValue ' +
            'AND Amount__c IN :amountValues ' +
            'AND (Ledger__c = :ledgerId' +
            (isLedgerEqualLegacyLedger ? ' OR Ledger__c = NULL)' : ' ') +
            (!isLedgerEqualLegacyLedger ? ') ' : ' ') +
            'AND Bank_Account__c = :bankAccount';

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Disbursement__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(calculateAvailableQueryRowsLimit());

        return (List<Cash_Disbursement__c>) Database.query(theQuery.toSOQL());
    }

    private List<Cash_Receipt__c> queryAvailableCashReceipts() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Receipt_Date__c',
            'Accounting_Period__c',
            'Amount__c',
            'Account__c',
            'Credit_GL_Account__c',
            'Project__c',
            'Project_Task__c',
            'Ledger__c',
            'Cleared_Date__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Bank_Id__c',
            'Bank_Deposit__c',
            'Cash_Flow_Category__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String queryCondition =
            'Bank_Id__c = NULL ' +
            'AND Bank_Deposit__c = NULL ' +
                ((legacyRecordsIds != NULL && !legacyRecordsIds.isEmpty()) ? 'AND Id NOT IN :legacyRecordsIds ' : '') +
            'AND Receipt_Date__c >= :creditStartDateFilterValue ' +
            'AND Receipt_Date__c <= :creditEndDateFilterValue ' +
            'AND Amount__c IN :amountValues ' +
            'AND (Ledger__c = :ledgerId' +
            (isLedgerEqualLegacyLedger ? ' OR Ledger__c = NULL)' : ' ') +
            (!isLedgerEqualLegacyLedger ? ') ' : ' ') +
            'AND Bank_Account__c = :bankAccount';

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(calculateAvailableQueryRowsLimit());

        return (List<Cash_Receipt__c>) Database.query(theQuery.toSOQL());
    }

    private List<Journal_Entry_Line__c> queryAvailableJournalEntryLines() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Bank_Id__c',
            'Bank_Deposit__c',
            'Journal_Entry__c',
            'Journal_Entry__r.Accounting_Period__c',
            'Journal_Entry__r.Journal_Date__c',
            'Journal_Entry__r.Ledger__c',
            'GL_Account__c',
            'Account__c',
            'Date__c',
            'Credit__c',
            'Debit__c',
            'Amount__c',
            'Project__c',
            'Project_Task__c',
            'Cleared_Date__c',
            'GL_Account_Variable_1__c',
            'GL_Account_Variable_2__c',
            'GL_Account_Variable_3__c',
            'GL_Account_Variable_4__c',
            'Cash_Flow_Category__c'
        };

        if (IS_MULTI_CURRENCY_ENABLED) {
            queryFields.add('CurrencyIsoCode');
        }

        String ledgerCondition = ' AND (Journal_Entry__r.Ledger__c = :ledgerId' +
            (isLedgerEqualLegacyLedger ? ' OR Journal_Entry__r.Ledger__c = NULL)' : ' ') +
            (!isLedgerEqualLegacyLedger ? ') ' : ' ');

        String queryCondition =
            'Bank_Id__c = NULL ' +
            'AND Bank_Deposit__c = NULL ' +
                ((legacyRecordsIds != NULL && !legacyRecordsIds.isEmpty()) ? 'AND Id NOT IN :legacyRecordsIds ' : '') +
                ledgerCondition +
            'AND (' +
                    '(Credit__c != NULL AND (Date__c >= :debitStartDateFilterValue AND Date__c <= :debitEndDateFilterValue))' +
                    ' OR ' +
                    '(Debit__c != NULL AND (Date__c >= :creditStartDateFilterValue AND Date__c <= :creditEndDateFilterValue))' +
            ') ' +
            'AND Amount__c IN :amountValues ' +
            'AND GL_Account__c = :bankAccount';

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(calculateAvailableQueryRowsLimit());

        return (List<Journal_Entry_Line__c>) Database.query(theQuery.toSOQL());
    }

    private List<Account> queryAvailableVendors() {
        List<String> queryFields = new List<String>{
            'Id',
            'Name'
        };

        String queryCondition =
            'Accounting_Active__c = true ' +
            'AND Accounting_Type__c IN (\'Vendor\',\'Customer and Vendor\')';

        SOQLBuilder theQuery = new SOQLBuilder(Account.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(calculateAvailableQueryRowsLimit());

        return (List<Account>) Database.query(theQuery.toSOQL());
    }


    public with sharing class MatchingRecordWrapper {
        public SObject obj {get; set;}
        public Boolean selected {get; set;}
        public String tranTypeName {get; set;}
        public String extId {get; set;}

        public MatchingRecordWrapper(SObject aObject, String extId) {
            this.obj = aObject;
            this.selected = false;
            this.tranTypeName = getTransactionTypeName();
            this.extId = extId;
        }

        private String getTransactionTypeName() {
            String result;
            if (obj.getSObjectType() == Cash_Receipt__c.SObjectType) {
                result = FinancialImportLineWrapper.RECEIPT_LABEL;
            }
            else if (obj.getSObjectType() == Cash_Disbursement__c.SObjectType) {
                result = FinancialImportLineWrapper.DISBURSEMENT_LABEL;
            }
            else if (obj.getSObjectType() == Journal_Entry_Line__c.SObjectType) {
                result = (obj.get('Credit__c') != NULL) ? FinancialImportLineWrapper.CREDIT_JOURNAL_LABEL : FinancialImportLineWrapper.DEBIT_JOURNAL_LABEL;
            }
            else if (obj.getSObjectType() == Bank_Deposit__c.SObjectType) {
                result = FinancialImportLineWrapper.DEPOSIT_LABEL;
            }
            return result;
        }

        public String getAmountFieldApiName() {
            String amountFieldApiName = 'Amount__c';
            switch on obj {
                when Journal_Entry_Line__c je {
                    if (je.Debit__c != NULL) {
                        amountFieldApiName = 'Debit__c';
                    }
                    else {
                        amountFieldApiName = 'Credit__c';
                    }
                }
                when else {
                    amountFieldApiName = 'Amount__c';
                }
            }
            return amountFieldApiName;
        }

    }

}