public with sharing class ActivityStatementsManagerController extends AbstractStatementManager {

    public static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER.replaceAll('_', '');
    public static final String NO_SENDER_EMAIL_ERROR = Label.ERR_NO_BILLING_CONTACT_SENDER_EMAIL;

    private List<Account> selectedCustomers;
    public AbstractStatementManager.StatementSet activityStatementManager {get; set;}

    public List<CustomerWrapper> wrappedCustomers {get; private set;}
    public AcctSeed__Billing__c activityBill {get; set;}
    public Boolean isNoSelectedCustomers {get; private set;}
    public Boolean isMissContact {get; private set;}
    public Boolean isAllMiss {get; private set;}
    public Boolean isAltPayorIncluded {get; set;}

    private ApexPages.StandardSetController setController;

    public ActivityStatementsManagerController(ApexPages.StandardSetController setController) {
        try {
            this.setController = setController;
            isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
            this.activityBill = new AcctSeed__Billing__c(AcctSeed__Date__c = System.today() - 60, AcctSeed__Due_Date2__c = System.today());
            this.isAltPayorIncluded = true;
            initCustomers();
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
        }
    }

    public PageReference savePDFs() {
        return callingBatch(false);
    }

    public PageReference emailPDFs() {
        return callingBatch(true);
    }

    private PageReference callingBatch(Boolean isMailing) {
        List<Id> selectedIds = new List<Id>();
        Map<Id, Id> accountIdToLedgerId = new Map<Id, Id>();
        Map<Id, String> accountIdToCurrencyIsoCode = new Map<Id, String>();
        String resultMessage;

        for (CustomerWrapper wrappedCustomer : wrappedCustomers) {
            if (!isMailing
                    || (isMailing
                            && wrappedCustomer.customer.Billing_Contact__c != NULL
                            && wrappedCustomer.customer.Billing_Contact__r.Email != NULL)) {

                selectedIds.add(wrappedCustomer.customer.Id);
                accountIdToLedgerId.put(wrappedCustomer.customer.Id, wrappedCustomer.selectedLedgerId);
                accountIdToCurrencyIsoCode.put(wrappedCustomer.customer.Id, wrappedCustomer.selectedCurrency);
            }
        }

        if (isMailing) {
            try {
                Messaging.reserveSingleEmailCapacity(selectedIds.size());
            }
            catch (Exception ex) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, EMAIL_LIMIT_ERROR));
                return NULL;
            }
            resultMessage = String.format(MAIL_SUCCESS_MESSAGE_FOR_ACCOUNTS, new List<String>{'Activity'});
        }
        else {
            resultMessage = String.format(ATTACH_SUCCESS_MESSAGE_FOR_ACCOUNTS, new List<String>{'Activity'});
        }

        StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(selectedIds, accountIdToLedgerId, 
                                                accountIdToCurrencyIsoCode, isMailing,
                                                FinancialSuiteUtils.currentRequestBaseUrl(),
                                                StatementBase.CUSTOMER, statementType.ACTIVITY).setCustomUrlParams(new Map<String, String>{
                                                    'startDate' => getActivityDate(activityBill.Date__c),
                                                    'endDate' => getActivityDate(activityBill.Due_Date2__c),
                                                    'includeAltPayor' => String.valueOf(this.isAltPayorIncluded)
                                                });
        Database.executeBatch(pdfBatch, BATCH_CHUNK_SIZE);
        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.CONFIRM, resultMessage));

    
        return NULL;
    
    }


    public String getActivityDate(Date dateItem) {
        return String.valueOf(dateItem.year()) +
                '-' +
                FinancialSuiteUtils.leftPad(String.valueOf(dateItem.month()), 1) +
                '-' +
                FinancialSuiteUtils.leftPad(String.valueOf(dateItem.day()), 1);
    }

    private void initCustomers() {
        isNoSelectedCustomers = false;
        this.selectedCustomers = DomainUtils.getAccountsBySelectedAccounts((List<Account>) setController.getSelected());
       
        if (this.selectedCustomers.isEmpty()) {
            isNoSelectedCustomers = true;
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.SEVERITY.ERROR,
                    NO_RECORDS_SELECTED_ERROR
                )
            );
        }
        else {
            isMissContact = false;
            isAllMiss = true;
            for (Account account : this.selectedCustomers) {
                if (!isMissContact && (account.Billing_Contact__c == NULL || account.Billing_Contact__r.Email == NULL)) {
                    isMissContact = true;
                }
                if (isAllMiss && (account.Billing_Contact__c != NULL && account.Billing_Contact__r.Email != NULL)) {
                    isAllMiss = false;
                }
            }
            if (isMissContact) {
                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.SEVERITY.WARNING,
                        NO_SENDER_EMAIL_ERROR
                    )
                );
            }

            //wrap selected Accounts
            wrappedCustomers = new List<ActivityStatementsManagerController.CustomerWrapper>();
            for (Account account : this.selectedCustomers) {
                CustomerWrapper wrappedCustomer = new CustomerWrapper(account);
                wrappedCustomers.add(wrappedCustomer);
            }
        }
    }
    public PageReference changeLedger() {
        for(CustomerWrapper wrappedCustomer : wrappedCustomers){
            if (isMultiCurrencyEnabled) {
                wrappedCustomer.selectedCurrency = (String) LedgerHandler.getInstanceWithoutSharing().getLedgerById(wrappedCustomer.selectedLedgerId).get('CurrencyIsoCode');
            }
        }
        return NULL;
    }
    public with sharing class CustomerWrapper {
        public Account customer {get; set;}
        public List<SelectOption> availableLedgers {get; set;}
        public List<SelectOption> availableCurrencies {get; set;}
        public String selectedLedgerId {get; set;}
        public String selectedCurrency {get; set;}

        public CustomerWrapper(Account a) {
            this.customer = a;
            this.availableLedgers = LedgerHandler.getInstanceWithSharing().getTransactionalLedgerSelectOptions();
            selectedLedgerId = LedgerHandler.getLedgerId();
            if (MultiCurrencyHandler.isMultiCurrencyEnabled) {
                this.availableCurrencies = MultiCurrencyHandler.getAllCurrenciesSelectOptions();
                selectedCurrency = a.Outstanding_Statement_Format__c != NULL ?
                    (String) a.get('CurrencyIsoCode') : LedgerHandler.getLedgerCurrency(selectedLedgerId);
            }
        }
    }
}