public with sharing class PlaidTransactionsDownloadQueueable implements Queueable, Database.AllowsCallouts {

    private Date fromDate;
    private Date toDate;
    private Integer offset;
    private Integer maxRecords;
    private Map<String, BDCCategory> categoryById;
    private BDCFinancialInstitutionIdentity financialInstitutionIdentity;
    private External_Settings__mdt plaidAuthInfo;
    private List<GL_Account_Mapping__c> glams;
    private Integer jobsCount = 1;
    private Integer jobsTime = 0;

    @TestVisible
    private static final String TRANSACTIONS_RETRIEVED_FOR_BANK = Label.TRANSACTIONS_RETRIEVED_FOR_BANK;
    private static final Integer MAX_PLAID_CALL_PER_MIN = 30;


    //initial call
    public PlaidTransactionsDownloadQueueable(
        Date fromDate,
        Date toDate,
        Integer recordOffset,
        Integer maxRecords,
        BDCFinancialInstitutionIdentity targetFinancialInstitutionIdentity,
        List<GL_Account_Mapping__c> relatedGlams

    ) {
        this.fromDate = fromDate;
        this.toDate = toDate;
        this.offset = recordOffset;
        this.maxRecords = maxRecords;
        this.financialInstitutionIdentity = targetFinancialInstitutionIdentity;
        this.glams = relatedGlams;
    }

    public PlaidTransactionsDownloadQueueable(
        Date fromDate,
        Date toDate,
        Integer recordOffset,
        Integer maxRecords,
        BDCFinancialInstitutionIdentity targetFinancialInstitutionIdentity,
        Map<String, BDCcategory> categoryMap,
        List<GL_Account_Mapping__c> relatedGlams,
        Integer jobsCount,
        Integer jobsTime

    ) {
        this.fromDate = fromDate;
        this.toDate = toDate;
        this.offset = recordOffset;
        this.maxRecords = maxRecords;
        this.financialInstitutionIdentity = targetFinancialInstitutionIdentity;
        this.categoryById = categoryMap;
        this.glams = relatedGlams;
        this.jobsCount += jobsCount;
        this.jobsTime = jobsTime;
    }

    /*
    * Populates up to three category fields on the given BDCTransaction using a full category map
    */
    private void populateCategoryFields(BDCTransaction aTransaction, Map<String, BDCCategory> categoryIdToObject) {
        //determine the category depth by tracing its parents until none remain
        //a depth of 0 means the transaction has no parent
        //the maximum depth supported is 2
        Integer categoryDepth = 0;
        String currentCategoryId = aTransaction.categoryId;
        //if the transaction has no category. Just return the original transaction
        if (currentCategoryId == null) {
            return;
        }
        while (categoryIdToObject.get(currentCategoryId).parentCategoryId != null) {
            categoryDepth++;
            //set the current category to the parent to check if it also has a parent
            currentCategoryId = categoryIdToObject.get(currentCategoryId).parentCategoryId;
        }


        //Now populate fields according to this depth
        //if somehow the category depth is greater than 2, the closest 3 categories will be populated (including the transaction's actual category)
        if (categoryDepth == 0) {
            aTransaction.categoryLevel1Id = aTransaction.categoryId;
        }
        if (categoryDepth == 1) {
            aTransaction.categoryLevel1Id = categoryIdToObject.get(aTransaction.categoryId).parentCategoryId;
            aTransaction.categoryLevel2Id = aTransaction.categoryId;
        }
        if (categoryDepth >= 2) {
            aTransaction.categoryLevel1Id = categoryIdToObject.get(categoryIdToObject.get(aTransaction.categoryId).parentCategoryId).parentCategoryId;
            aTransaction.categoryLevel2Id = categoryIdToObject.get(aTransaction.categoryId).parentCategoryId;
            aTransaction.categoryLevel3Id = aTransaction.categoryId;
        }
        return;
        
    }
    

    public void execute(QueueableContext context) {
        try {
            PlaidBDCConnector connector = new PlaidBDCConnector();
            PlaidBDCConverter converter = new PlaidBDCConverter();
            BDCServiceOptions transactionsOptions = new BDCServiceOptions();
            transactionsOptions.toDate = this.toDate;
            transactionsOptions.fromDate = this.fromDate;
            transactionsOptions.offset = this.offset;
            transactionsOptions.maxRecords = this.maxRecords;

            List<BDCFinancialInstitutionIdentity> bdcIdentities = new List<BDCFinancialInstitutionIdentity>();
            bdcIdentities.add(this.financialInstitutionIdentity);
            transactionsOptions.bdcFinancialInstitutionIdentities = bdcIdentities;
            List<HttpResponse> connectorResponses = connector.getTransactions(transactionsOptions);
            BDCServiceResult transactionResult = converter.convertTransactions(connectorResponses);

            List<BDCTransaction> convertedTransactions = (List<BDCTransaction>) transactionResult.data.bdcTransactions;
            Integer total_transactions = (Integer) transactionResult.data.totalTransactions;

            //get the category map once to save time retrieving it later
            if (categoryById == NULL) {
                //Execute callout to get categories
                BDCServiceResult categoryResult= converter.convertCategories(connector.getCategories());
                // create { category_id => category_name } mapping for adding category info to transactions
                if (categoryResult.isSuccess) {
                    categoryById = categoryResult.data.bdcCategories;
                }
            }

            //Add the correct glam to each transaction
            //Create a map from the account id to the glam
            Map<String, GL_Account_Mapping__c> accountIdToGlam = new Map<String, GL_Account_Mapping__c>();
            for (GL_Account_Mapping__c aGlam : glams) {
                accountIdToGlam.put(aGlam.External_Id__c, aGlam);
            }

            List<BDCTransaction> transactionsWithGlams = new List<BDCTransaction>();
            for (BDCTransaction conTran : convertedTransactions) {
                if (accountIdToGlam.get(conTran.accountId) != null) {
                    conTran.GLAccountMappingId = accountIdToGlam.get(conTran.accountId).Id;
                    transactionsWithGlams.add(conTran);
                }
            }
            //Add the High level categories to each transaction
            for (BDCTransaction aTransaction :transactionsWithGlams) {
                populateCategoryFields(aTransaction, categoryById);
            }

            PlaidBDCTransactionBulk.convertBDCTransactionToBankTransactions(transactionsWithGlams, this.categoryById, PlaidBDCConverter.sourceString);

            /*potential upgrade: it may be worth writing a custom converter function that returns the total records and compares it to the 
              total size. We make an extra call in the case where the total records are exactly equal to the number returned || substract the
              processed transactions from all transactions and check remaining is greater than 0 or not.
            */
            if (total_transactions - (this.offset + connector.maxTransactionRecordsPerCallout()) > 0) {
                jobsTime += Limits.getCpuTime();
                System.enqueueJob(new PlaidTransactionsDownloadQueueable(
                    this.fromDate,
                    this.toDate,
                    this.offset + connector.maxTransactionRecordsPerCallout(),
                    connector.maxTransactionRecordsPerCallout(),
                    this.financialInstitutionIdentity,
                    this.categoryById,
                    glams,
                    this.jobsCount,
                    this.jobsTime
                ), getJobDelay());
            } else {
                //perform actions to indicate the transaction retrieval process has completed
                List<BDCFinancialInstitutionIdentity> identityList = new List<BDCFinancialInstitutionIdentity>();
                identityList.add(this.financialInstitutionIdentity);
                PlaidBDCTransactionBulk.updateGLAMS(transactionResult.data.bdcAccounts, identityList);
                String institutionName = glams[0].Financial_Institution__c;
                PlaidBDCTransactionBulk.publishTransactionsFinishPlatformEvent(TRANSACTIONS_RETRIEVED_FOR_BANK.replace('xxxx',institutionName));

            }


        }
        catch (Exception ex) {
            throw new BDCService.BDCException(ex.getMessage());
        }
    }

    private Integer getJobDelay() {
        if (jobsCount >= MAX_PLAID_CALL_PER_MIN && jobsTime < 60000) {
            jobsCount = 1;
            jobsTime = 0;
            return 1;
        }
        return 0;
    }

}