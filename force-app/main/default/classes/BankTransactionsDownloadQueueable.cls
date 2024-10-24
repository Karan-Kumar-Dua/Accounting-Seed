public with sharing class BankTransactionsDownloadQueueable implements Queueable, Database.AllowsCallouts {

    private static final String TRANSACTIONS_RETRIEVED_FOR_YODLEE = Label.TRANSACTIONS_RETRIEVED_FOR_YODLEE;

    private List<String> accountIds;
    private Integer totalNmbOfPages;
    private Integer currentPageNmb;
    private Date fromDate;
    private Date toDate;
    private Integer offset;
    private Integer maxRecords;
    private Map<String, BDCCategory> categoryById;
    private List<BDCAccount> accounts;
    private List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities;

    //initial call
    public BankTransactionsDownloadQueueable(
        List<String> accountIds,
        Integer currentPageNmb,
        Date fromDate,
        Date toDate,
        Integer maxTransactionRecordsPerCallout

    ) {
        this.accountIds = accountIds;
        this.currentPageNmb = currentPageNmb;
        this.fromDate = fromDate;
        this.toDate = toDate;
        this.offset = currentPageNmb * maxTransactionRecordsPerCallout;
        this.maxRecords = maxTransactionRecordsPerCallout;
    }

    //called from itself to enqueue job for specific pages
    public BankTransactionsDownloadQueueable(
        List<String> accountIds,
        Integer currentPageNmb,
        Date fromDate,
        Date toDate,
        Integer maxTransactionRecordsPerCallout,
        Map<String, BDCCategory> categoryById,
        List<BDCAccount> accounts,
        List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities
    ) {
        this(accountIds, currentPageNmb, fromDate, toDate, maxTransactionRecordsPerCallout);
        this.categoryById = categoryById;
        this.accounts = accounts;
    }

    private void filterOutNotExistedAccountIds() {
        List<String> existedAccountIds = new List<String>();
        if (accounts != NULL) {
            for (BDCAccount account : accounts) {
                existedAccountIds.add(account.id);
            }
        }
        accountIds = existedAccountIds;
    }

    public void execute(QueueableContext context) {
        try {
            BDCService service = new bdcService();
            BDC_Binding__c bdcBinding =   service.getBDCBinding('Yodlee');
            BDCServiceOptions options = new BDCServiceOptions();
            options.fromDate = fromDate;
            options.toDate = toDate;
            options.bdcAccountIds = accountIds;

            //Get all financialInstitutionIdentities to check providerAccount status. This executes during the first job in the chain only.
            if (financialInstitutionIdentities == NULL) {
                options.bdcBinding = bdcBinding;

                BDCServiceResult resultFinInstIdentities = service.getFinancialInstitutionIdentities(options);
                financialInstitutionIdentities = resultFinInstIdentities.data.bdcFinancialInstitutionIdentities;

            }

            // During the first job in chain execution only:
            // Get all Accounts by accountIds provided and filter out any accountIds not existed on BDC side
            if (accounts == NULL) {
                BDCServiceResult resultAccounts = service.getAccounts(options);

                if (resultAccounts.isSuccess) {
                    accounts = resultAccounts.data.bdcAccounts;
                    filterOutNotExistedAccountIds();
                }
                else {
                    throw new BDCService.BDCException(Label.INF_GET_ACCOUNTS_REQUEST + ': ' + resultAccounts.errors[0].detail);
                }
            }

            YodleeBDCConnector connector = new YodleeBDCConnector();
            YodleeBDCConverter converter = new YodleeBDCConverter();
            Integer transactionCount = converter.convertTransactionCount(connector.getTransactionsCount(fromDate, toDate, accountIds));
                        
            if (transactionCount != NULL && transactionCount > 0) {
                totalNmbOfPages = (Integer) Math.ceil(Double.valueOf(transactionCount)/Double.valueOf(maxRecords));
                //if this does not have category information
                if (categoryById == NULL) {
                    //Execute callout to get categories
                    BDCServiceResult resultCategories = service.getCategories(options);
                    // create { category_id => category_name } mapping for adding category info to transactions
                    if (resultCategories.isSuccess) {
                        categoryById = resultCategories.data.bdcCategories;
                    }
                }

                options.offset = offset;
                options.maxRecords = maxRecords;
                BDCServiceResult resultTransactions = service.getTransactions(options);

                //set next page number
                currentPageNmb++;
                //if there is next page of transactions on BDC side - save transactions and start next async job
                if (totalNmbOfPages > currentPageNmb) {
                    //Create Bank Transaction records if not exist on SF side yet
                    if (resultTransactions.isSuccess && !resultTransactions.data.bdcTransactions.isEmpty()) {

                        YodleeBDCTransactionBulk.convertBDCTransactionToBankTransactions(
                            resultTransactions.data.bdcTransactions,
                            categoryById,
                            bdcBinding.Name
                        );

                    }
                    //If get transactions callout is complete with an error
                    if (!resultTransactions.isSuccess) {
                        BankTransactionsHelper.logOnActivity(accountIds, Label.INF_GET_TRANSACTIONS_REQUEST + ': ' + resultTransactions.errors[0].detail
                        );
                    }
                    //enqueue download of the next transactions page
                    System.enqueueJob(new BankTransactionsDownloadQueueable(
                        accountIds, currentPageNmb, fromDate, toDate, maxRecords, categoryById, accounts, financialInstitutionIdentities
                    ));
                }
                else {//Last page of transactions processing
                    //Create Bank Transaction records if not exist on SF side yet
                    if (resultTransactions.isSuccess && !resultTransactions.data.bdcTransactions.isEmpty()) {

                        YodleeBDCTransactionBulk.convertBDCTransactionToBankTransactions(
                            resultTransactions.data.bdcTransactions,
                            categoryById,
                            bdcBinding.Name
                        );

                    }
                    //If get transactions callout is complete with an error
                    if (!resultTransactions.isSuccess) {
                        BankTransactionsHelper.logOnActivity(accountIds, resultTransactions.errors[0].detail);
                    }

                    //Update each GL Account Mapping record
                    YodleeBDCTransactionBulk.updateGLAMS(accounts, financialInstitutionIdentities);

                }
            }

            //Update each GL Account Mapping record
            YodleeBDCTransactionBulk.updateGLAMS(accounts, financialInstitutionIdentities);
            YodleeBDCTransactionBulk.publishTransactionsFinishPlatformEvent(BankTransactionsDownloadQueueable.TRANSACTIONS_RETRIEVED_FOR_YODLEE);
        }
        catch (Exception ex) {
            BankTransactionsHelper.logOnActivity(accountIds, ex.getMessage());
        }
    }

}