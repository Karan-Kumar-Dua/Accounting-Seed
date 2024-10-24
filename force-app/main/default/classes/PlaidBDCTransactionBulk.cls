public class PlaidBDCTransactionBulk extends AbstractBDCTransactionBulk {

    //constant parameters for controlling how records are pulled
    private static final Integer DEFAULT_START_DATE_OFFSET_IN_DAYS = 90;
    private static final String PLAID_SOURCE_STRING = 'Plaid';

    //The variable below defines how far back from the last refreshed date should be pulled.
    //Makes sure that pending transactions that have not been set to posted still get pulled.
    private final Integer defaultTransactionOverlapDays = 14;

    public Boolean byPassEarliestRefrshDateLogic = false;
 
    public override BDCServiceResult startTransactionProcess(List<GL_Account_Mapping__c> glams) {
        BDCServiceResult serviceResult = new BDCServiceResult();
        try {
            //construct maps for quickly accessing information later
            //finInstIdentityToGlam will be used twice
            //--to extract the earliest refresh date for the institution across its GLAMS
            //--to pass the associated glams to the transaction retrieval queueables to populate each transactions's GLAM lookup field
            //the other map is simply used to pass the glams with their associated id
            Map<String, List<GL_Account_Mapping__c>> finInstIdentityToGlam = new Map<String, List<GL_Account_Mapping__c>>();
            Map<String, BDCFinancialInstitutionIdentity> finInstIdentityToIdentityObject = new Map<String, BDCFinancialInstitutionIdentity>();
            for (GL_Account_Mapping__c aGlam : glams) {
                if (finInstIdentityToGlam.get(aGlam.Financial_Institution_Id__c) == null) {
                    finInstIdentityToGlam.put(aGlam.Financial_Institution_Id__c, new List<GL_Account_Mapping__c>());

                }
                if (finInstIdentityToIdentityObject.get(aGlam.Financial_Institution_Id__c) == null) {
                    BDCFinancialInstitutionIdentity newIden = new BDCFinancialInstitutionIdentity();
                    newIden.Id = aGlam.Financial_Institution_Id__c;
                    newIden.FinancialInstitutionId = aGlam.Financial_Institution_Id_Actual__c;
                    newIden.source = PLAID_SOURCE_STRING;
                    finInstIdentityToIdentityObject.put(aGlam.Financial_Institution_Id__c, newIden);
                }
                finInstIdentityToGlam.get(aGlam.Financial_Institution_Id__c).add(aGlam);
            }

            //get the earliest last refreshed date for a set of glams that belong to an insitution identity
            Map<String, Date> finInstIdentityToEarliestLastRefresh = new Map<String,Date>();
            for (String finInstIden : finInstIdentityToGlam.keySet()) {
                for (GL_Account_Mapping__c aGlam : finInstIdentityToGlam.get(finInstIden)) {
                    Date earliestRefresh = finInstIdentityToEarliestLastRefresh.get(finInstIden);
                    
                    //glamDate will be either the earliest refresh for the glam or its initial start date if it exists
                    Date glamDate;
                    /*if to make sure that we need always intial start date to pull the transaction because now it will
                      pull transactions specific to selected glam from intial date to today and in this case there will be
                      always onl one glam to process in queueable also.
                    */
                    if(!byPassEarliestRefrshDateLogic){

                        if (aGlam.Last_Refreshed__c != null) {
                            glamDate = aGlam.Last_Refreshed__c.date();
                        } else if (aGlam.Initial_Start_Date__c != null) {
                            glamDate = aGlam.Initial_Start_Date__c;
                        }
                    }
                    else{
                        glamDate = aGlam.Initial_Start_Date__c;
                    }
                    //As written, all accounts will be pulled according to the earliest date across all of them.
                    //Pulling by each account separately would decrease transactions, but increase the number of calls.
                    if ((earliestRefresh != null  && glamDate != null && glamDate < earliestRefresh)
                        || (earliestRefresh == null  && glamDate != null)) {
                        finInstIdentityToEarliestLastRefresh.put(finInstIden, glamDate);
                    } else if (earliestRefresh == null  && glamDate == null) {
                        finInstIdentityToEarliestLastRefresh.put(finInstIden, Date.Today().addDays(-DEFAULT_START_DATE_OFFSET_IN_DAYS + defaultTransactionOverlapDays));
                    }
                }
                //Now add an offset to the date or pick the default if no dates were found
                Date fromDateNoOffset = finInstIdentityToEarliestLastRefresh.get(finInstIden);
                finInstIdentityToEarliestLastRefresh.put(finInstIden, fromDateNoOffset.addDays(-defaultTransactionOverlapDays));
            }

            /*
            Potential upgrade: Originally I was thinking this would save time in each asynch call by getting all access tokens early
            However, if we want to support this, we need to overload the getTransactions function to include access tokens
            //query for access tokens using the GLAMs' financial institution identity
            List<BDC_Access_Tokens__c> accessTokens = [SELECT Id, Financial_Institution_Identity_Id__c, Token__c FROM BDC_Access_Tokens__c WHERE Financial_Institution_Identity_Id__c IN :finInstIdentityToGlam.keySet()];
            Map<String, BDC_Access_Tokens__c> finInstIdentityToAccessToken = new List<String, BDC_Access_Tokens__c>();
            for (BDC_Access_Tokens__c accToken : accessTokens) {
                finInstIdentityToAccessToken.put(accToken.Financial_Institution_Identity_Id__c, accToken);
            }
            */

            PlaidBDCConnector connector = new PlaidBDCConnector();

            //launch a queueable for each institution identity, passing the information accumulated above. 
            //begin with offset 0. Queueables will call instances of themselves and apply offset of iteration * maxRecords if necessary
            Date toDate = Date.today();
            publishTransactionsStartPlatformEvent();
            for (String finInstIden : finInstIdentityToGlam.keySet()) {
                if (finInstIdentityToGlam.get(finInstIden).size()==0) {continue;}
                System.enqueueJob(new PlaidTransactionsDownloadQueueable(
                    finInstIdentityToEarliestLastRefresh.get(finInstIden),
                    toDate,
                    0,
                    connector.maxTransactionRecordsPerCallout(),
                    finInstIdentityToIdentityObject.get(finInstIden),
                    finInstIdentityToGlam.get(finInstIden)
                ));
            }
        }
        catch (Exception ex) {
            throw new BDCService.BDCException(ex.getMessage());
        }

        return serviceResult;
    }
}