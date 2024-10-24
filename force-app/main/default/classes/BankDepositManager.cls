public with sharing class BankDepositManager {

    public static String PACKAGE_QUALIFIER {
        get {
            return GlobalVariables.PACKAGE_QUALIFIER;
        }
        private set;
    }

    @TestVisible
    private static final String CASH_RECEIPT_TYPE = 'Cash Receipt';
    @TestVisible
    private static final String CASH_RECEIPT_TYPE_LABEL = Label.COMMON_CASH_RECEIPT;
    @TestVisible
    private static final String JOURNAL_ENTRY_LINE_TYPE = 'Journal Entry Line';
    @TestVisible
    private static final String JOURNAL_ENTRY_LINE_TYPE_LABEL = Label.COMMON_JOURNAL_ENTRY_LINE;
    @TestVisible
    private static final String DEBIT_JOURNAL_ENTRY_LINE_TYPE = 'Debit Journal';
    @TestVisible
    private static final String CREDIT_JOURNAL_ENTRY_LINE_TYPE = 'Credit Journal';
    @TestVisible
    private static final String ANY_TYPE = 'All';
    @TestVisible
    private static final String ANY_TYPE_LABEL = Label.COMMON_ALL;

    public Bank_Deposit__c bankDeposit {get; set;}
    public Bank_Deposit__c searchStartDate {get; set;}
    public Bank_Deposit__c searchEndDate {get; set;}
    public Boolean isError {get; private set;}
    public String selectedUnassociatedType {get; set;}
    public Boolean IS_MULTI_CURRENCY_ENABLED {get; private set;}
    public String currencyIsoCode {get; private set;}
    public Boolean isMatchedBD {get; private set;}

    public BankDepositManager(ApexPages.StandardController controller) {
        try {
            IS_MULTI_CURRENCY_ENABLED = MultiCurrencyHandler.isMultiCurrencyEnabled;
            bankDeposit = (Bank_Deposit__c) controller.getRecord();

            SFDCSecurityUtils.checkRead(
                Bank_Deposit__c.getSObjectType(),
                new List<String>{Bank_Deposit__c.Bank_Reconciliation__c.getDescribe().getName()}
            );

            searchStartDate = new Bank_Deposit__c(Deposit_Date__c = bankDeposit.Deposit_Date__c - 30);
            searchEndDate = new Bank_Deposit__c(Deposit_Date__c = bankDeposit.Deposit_Date__c);
            isError = false;
            selectedUnassociatedType = ANY_TYPE;
            isMatchedBD = bankDeposit.Bank_Transaction__c != NULL;

            if (IS_MULTI_CURRENCY_ENABLED) {
                this.currencyIsoCode = (String) bankDeposit.get('CurrencyIsoCode');
            }

            if (bankDeposit.Bank_Reconciliation__c != NULL) {
                isError = true;
                String bankDepositWithBankReconciliationError = String.format(Label.ERR_BANK_DEPOSIT_ASSOCIATED_BR_FIRST_UNCLEAR_BD, new List<Object>{bankDeposit.Bank_Reconciliation__c, bankDeposit.Bank_Reconciliation__r.Name});
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.ERROR,
                        bankDepositWithBankReconciliationError
                    )
                );
            }
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            isError = true;
        }
    }

    public with sharing class AssociableRecordWrapper implements Comparable {
        public SObject obj {get; private set;}
        public Boolean selected {get; set;}
        public String name {get; set;}
        public String customerName {get; set;}
        public String objDate {get; set;}
        public BankManagerHelper.Money money;
        public String reference {get; set;}
        public BankManagerHelper.SourceObject sourceObj {get; set;}
        public Id ledgerId {get; set;}

        public AssociableRecordWrapper(SObject sObj, Id  ) {
            this.obj = sObj;
            this.ledgerId = ledgerId;
            this.selected = false;
            this.name = (String) obj.get('Name');
            this.sourceObj = new BankManagerHelper.SourceObject(this.obj.Id, this.name, getSourceType());
            this.customerName =
                (obj.getSObject('Account__r') != NULL) ? (String) obj.getSObject('Account__r').get('Name') : '';

            Date objDateSource = getAssociableRecordDate(this.obj);
            this.objDate = (objDateSource != NULL) ? objDateSource.format() : '';
            this.money = getMoney();
            this.reference = getAssociableRecordReference(this.obj);
        }

        private BankManagerHelper.Money getMoney() {
            Decimal recordAmount = (Decimal) obj.get('Amount__c');
            Decimal ledgerAmount = (Decimal) obj.get('Ledger_Amount__c');
            String recordCurrency = (MultiCurrencyHandler.isMultiCurrencyEnabled)
                ? (String) this.obj.get('CurrencyIsoCode')
                : MultiCurrencyHandler.CORPORATE_CURRENCY;
            String ledgerCurrency = LedgerHandler.getLedgerCurrency(this.ledgerId);
            if (this.sourceObj.sourceType == CREDIT_JOURNAL_ENTRY_LINE_TYPE) {
                recordAmount = recordAmount * -1;
                ledgerAmount = ledgerAmount * -1;
            }
            return new BankManagerHelper.Money(recordAmount, recordCurrency, ledgerAmount, ledgerCurrency);
        }

        public Integer compareTo(Object compareTo) {
            AssociableRecordWrapper comparedRecord = (AssociableRecordWrapper)compareTo;
            if (getAssociableRecordDate(this.obj) == getAssociableRecordDate(comparedRecord.obj)) return 0;
            if (getAssociableRecordDate(this.obj) > getAssociableRecordDate(comparedRecord.obj)) return 1;
            return -1;
        }

        private Date getAssociableRecordDate(SObject wrappedSObject) {
            Date resultDate;

            switch on wrappedSObject {
                when Cash_Receipt__c objRecord {
                    resultDate = (Date) objRecord.get('Receipt_Date__c');
                }
                when Journal_Entry_Line__c objRecord {
                    resultDate =
                        (objRecord.get('Date__c') != NULL)
                            ? (Date) objRecord.get('Date__c')
                            : (Date) objRecord.getSObject('Journal_Entry__r').get('Journal_Date__c');
                }
            }

            return resultDate;
        }

        private String getAssociableRecordReference(SObject sourceObject) {
            String result;
            switch on sourceObject {
                when Cash_Receipt__c objRecord {
                    result = (String) sourceObject.get('Payment_Reference__c');
                }
                when Journal_Entry_Line__c objRecord {
                    result = (String) sourceObject.get('Reference__c');
                }
            }
            return (result != NULL) ? result : '';
        }

        private String getSourceType() {
            String source = '';
            switch on obj {
                when Cash_Receipt__c objRecord {
                    source = CASH_RECEIPT_TYPE;
                }
                when Journal_Entry_Line__c objRecord {
                    if (objRecord.get('Debit__c') != NULL) {
                        source = DEBIT_JOURNAL_ENTRY_LINE_TYPE;
                    }
                    else if (objRecord.get('Credit__c') != NULL) {
                        source = CREDIT_JOURNAL_ENTRY_LINE_TYPE;
                    }
                }
            }

            return source;
        }

    }

    public SelectOption[] getType() {
        SelectOption[] options = new List<SelectOption>();
        options.add(new SelectOption(ANY_TYPE, ANY_TYPE_LABEL));
        options.add(new SelectOption(CASH_RECEIPT_TYPE, CASH_RECEIPT_TYPE_LABEL));
        options.add(new SelectOption(JOURNAL_ENTRY_LINE_TYPE, JOURNAL_ENTRY_LINE_TYPE_LABEL));
        return options;
    }

    @RemoteAction
    public static BankManagerHelper.Money getTotalAssociation(String bankDepositId) {
        BankManagerHelper.Money result;
        try {
            BankDepositHandler bdh = new BankDepositHandler(bankDepositId);
            result = bdh.calculateTotalAmount();
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    @RemoteAction
    public static BankManagerHelper.Money processAssociation(
        List<AssociableRecordWrapper> wrappedRowsToAssociation,
        String bankDepositId,
        Boolean associationMode
    ) {

        BankManagerHelper.Money result;
        try {
            BankDepositHandler bdh = new BankDepositHandler(bankDepositId);
            List<SObject> recListForUpdate = new List<SObject>();

            for (AssociableRecordWrapper arw : wrappedRowsToAssociation) {
                recListForUpdate.add(arw.obj);
            }
            if (associationMode) {
                bdh.associateObjects(recListForUpdate);
            }
            else {
                bdh.unAssociateObjects(recListForUpdate);
            }

            result = bdh.calculateTotalAmount();
            setBankTransactionStatus(bankDepositId);
        }
        catch (DmlException dmlEx) {
            if (!ApexPages.getMessages().isEmpty()) {
                String message = ' ';
                for (ApexPages.Message msg : ApexPages.getMessages()) {
                    message += msg.getDetail() + ' ';
                }
                throw new DmlException(message);
            }
            else {
                throw new DmlException(dmlEx.getDmlMessage(0));
            }
        }
        catch (Exception ex) {
            throw ex;
        }
        return result;
    }

    private static void setBankTransactionStatus(String bankDepositId) {
        List<Bank_Deposit__c> thisBankDeposit = DomainUtils.getBankDepositsById(new Set<Id> {bankDepositId});

        if (!thisBankDeposit.isEmpty() && thisBankDeposit[0].Bank_Transaction__c != NULL) {
            BankTransactionsHelper.updateBankTransactionsStatus(
                DomainUtils.getBankTransactionsById(new Set<Id> {thisBankDeposit[0].Bank_Transaction__c}),
                BankTransactionsHelper.BT_UNMATCHED_STATUS
            );
            thisBankDeposit[0].Cleared_Date__c = NULL;
            thisBankDeposit[0].Bank_Transaction__c = NULL;

            TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Bank_Transaction__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(
                thisBankDeposit, new List<String>{'Cleared_Date__c', 'Bank_Transaction__c'}
            );
            TriggerObserver.purgeUnlockedFields(Bank_Deposit__c.Bank_Transaction__c);
        }
    }

    @RemoteAction
    public static List<AssociableRecordWrapper> getUnassociatedRecords( String selectedUnassociatedType,
                                                                        String startDate,
                                                                        String endDate,
                                                                        String bankAccount,
                                                                        String glavVar1,
                                                                        String glavVar2,
                                                                        String glavVar3,
                                                                        String glavVar4,
                                                                        Integer count,
                                                                        String currencyIsoCode,
                                                                        String ledgerId) {

        List<AssociableRecordWrapper> results = new List<AssociableRecordWrapper>();

        try {
            Integer queryCount = count;
            List<SObject> unAssociatedRecords = new List<SObject>();
            if (String.isBlank(selectedUnassociatedType) || selectedUnassociatedType == ANY_TYPE) {
                unAssociatedRecords.addAll(
                    queryUnassociatedCashReceipts(
                        startDate, endDate, bankAccount, glavVar1, glavVar2, glavVar3, glavVar4, queryCount, currencyIsoCode, ledgerId
                    )
                );
                //update query limit after first results
                queryCount = (count - unAssociatedRecords.size()) > 0 ? (count - unAssociatedRecords.size()) : 0;

                unAssociatedRecords.addAll(
                    queryUnassociatedJournalEntryLines(
                        startDate, endDate, bankAccount, glavVar1, glavVar2, glavVar3, glavVar4, queryCount, currencyIsoCode, ledgerId
                    )
                );
            }
            else if (selectedUnassociatedType == CASH_RECEIPT_TYPE) {
                unAssociatedRecords.addAll(
                    queryUnassociatedCashReceipts(
                        startDate, endDate, bankAccount, glavVar1, glavVar2, glavVar3, glavVar4, queryCount, currencyIsoCode, ledgerId
                    )
                );
            }
            else if (selectedUnassociatedType == JOURNAL_ENTRY_LINE_TYPE) {
                unAssociatedRecords.addAll(
                    queryUnassociatedJournalEntryLines(
                        startDate, endDate, bankAccount, glavVar1, glavVar2, glavVar3, glavVar4, queryCount, currencyIsoCode, ledgerId
                    )
                );
            }
            for (SObject unAssociatedRecord : unAssociatedRecords) {
                results.add(new AssociableRecordWrapper(unAssociatedRecord, ledgerId));
            }

            results.sort();
        }
        catch (Exception ex) {
            throw ex;
        }

        return results;
    }

    private static List<SObject> queryUnassociatedCashReceipts( String startDate,
                                                                String endDate,
                                                                String bankAccount,
                                                                String glavVar1,
                                                                String glavVar2,
                                                                String glavVar3,
                                                                String glavVar4,
                                                                Integer queryCount,
                                                                String currencyIsoCode,
                                                                String ledgerId) {

        String ledgerCondition = BankManagerHelper.getLedgerCondition(ledgerId, 'Ledger__c');

        Date parsedStartDate = Date.parse(startDate);
        Date parsedEndDate = Date.parse(endDate);

        //Query Cash Receipt records with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Receipt_Date__c',
            'Amount__c',
            'Amount_Number__c',
            'Payment_Reference__c',
            'Account__c',
            'Account__r.Name',
            'Ledger_Amount__c',
            'Void__c'
        };

        String queryCondition =
            'Receipt_Date__c >= :parsedStartDate ' +
            'AND Receipt_Date__c <= :parsedEndDate ' +
            'AND Bank_Account__c = :bankAccount ' +
            'AND Bank_Deposit__c = NULL ' +
            'AND Bank_Reconciliation__c = NULL ' +
            'AND Status__c = \'Posted\' ' + 
            'AND Void__c = false ' + 
            ledgerCondition +
            BankManagerHelper.getGlavVariablePredicate(glavVar1, glavVar2, glavVar3, glavVar4);

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
            queryCondition += BankManagerHelper.getCurrencyCondition(ledgerId, currencyIsoCode);
        }

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(queryCount);

        return Database.query(theQuery.toSOQL());
    }

    private static List<SObject> queryUnassociatedJournalEntryLines(String startDate,
                                                                    String endDate,
                                                                    String bankAccount,
                                                                    String glavVar1,
                                                                    String glavVar2,
                                                                    String glavVar3,
                                                                    String glavVar4,
                                                                    Integer queryCount,
                                                                    String currencyIsoCode,
                                                                    String ledgerId) {

        String ledgerCondition = BankManagerHelper.getLedgerCondition(ledgerId, 'Journal_Entry__r.Ledger__c');

        Date parsedStartDate = Date.parse(startDate);
        Date parsedEndDate = Date.parse(endDate);

        //Query Journal Entry Lines with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Date__c',
            'Amount__c',
            'Amount_Number__c',
            'Reference__c',
            'Debit__c',
            'Credit__c',
            'Account__c',
            'Account__r.Name',
            'Ledger_Amount__c'
        };

        String queryCondition =
            'Date__c >= :parsedStartDate ' +
            'AND Date__c <= :parsedEndDate ' +
            'AND Bank_Deposit__c = NULL ' +
            'AND Bank_Reconciliation__c = NULL ' +
            'AND GL_Account__c = :bankAccount ' +
            'AND Journal_Entry__r.Status__c = \'Posted\' ' +
            'AND Bank_Disbursement__c = NULL '+
            ledgerCondition +
            BankManagerHelper.getGlavVariablePredicate(glavVar1, glavVar2, glavVar3, glavVar4);

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
            queryCondition += BankManagerHelper.getCurrencyCondition(ledgerId, currencyIsoCode);
        }

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition)
            .setLimit(queryCount);

        return Database.query(theQuery.toSOQL());
    }

    @RemoteAction
    public static List<AssociableRecordWrapper> getAssociatedRecords(String bankDepositId, String currencyIsoCode, String ledgerId) {
        List<AssociableRecordWrapper> results = new List<AssociableRecordWrapper>();
        try {
            List<SObject> associatedRecords = new List<SObject>();
            associatedRecords.addAll(queryAssociatedCashReceipts(bankDepositId, currencyIsoCode, ledgerId));
            associatedRecords.addAll(queryAssociatedJournalEntryLines(bankDepositId, currencyIsoCode, ledgerId));

            for (SObject associatedRecord : associatedRecords) {
                results.add(new AssociableRecordWrapper(associatedRecord, ledgerId));
            }

            results.sort();
        }
        catch (Exception ex) {
            throw ex;
        }
        return results;
    }

    private static List<SObject> queryAssociatedCashReceipts(String bankDepositId, String currencyIsoCode, String ledgerId) {
        String ledgerCondition = BankManagerHelper.getLedgerCondition(ledgerId, 'Ledger__c');
        //Query Cash Receipts with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Receipt_Date__c',
            'Amount__c',
            'Amount_Number__c',
            'Payment_Reference__c',
            'Account__c',
            'Account__r.Name',
            'Ledger_Amount__c',
            'Void__c'
        };

        String queryCondition =
            'Bank_Deposit__c = :bankDepositId ' +
            'AND Bank_Reconciliation__c = NULL ' +
            'AND Void__c = false ' +
            ledgerCondition;

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
            queryCondition += BankManagerHelper.getCurrencyCondition(ledgerId, currencyIsoCode);
        }

        SOQLBuilder theQuery = new SOQLBuilder(Cash_Receipt__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }

    private static List<SObject> queryAssociatedJournalEntryLines(String bankDepositId, String currencyIsoCode, String ledgerId) {
        String ledgerCondition = BankManagerHelper.getLedgerCondition(ledgerId, 'Journal_Entry__r.Ledger__c');

        //Query Journal Entry Lines with CRUD and FLS checks
        List<String> queryFields = new List<String>{
            'Id',
            'Name',
            'Date__c',
            'Amount__c',
            'Amount_Number__c',
            'Reference__c',
            'Debit__c',
            'Credit__c',
            'Ledger_Amount__c',
            'Journal_Entry__r.Ledger__c',
            'Account__c',
            'Account__r.Name'
        };

        String queryCondition =
            'Bank_Deposit__c = :bankDepositId ' +
            'AND Bank_Reconciliation__c = NULL ' +
            ledgerCondition;

        if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
            queryFields.add('CurrencyIsoCode');
            queryCondition += BankManagerHelper.getCurrencyCondition(ledgerId, currencyIsoCode);
        }

        SOQLBuilder theQuery = new SOQLBuilder(Journal_Entry_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(queryFields)
            .setCondition(queryCondition);

        return Database.query(theQuery.toSOQL());
    }

}