global abstract class AbstractBDCConnector {
    abstract global List<HttpResponse> getTransactions(BDCServiceOptions options);
    abstract global List<HttpResponse> getFinancialInstitutionIdentities();
    abstract global List<HttpResponse> getFinancialInstitutions(List<BDCFinancialInstitutionIdentity> finInstIdens);
    abstract global List<HttpResponse> getFinancialInstitution(string FinInstID);
    abstract global List<HttpResponse> deleteFinancialInstitutionIdentity(BDCFinancialInstitutionIdentity finInstIden);
    abstract global List<HttpResponse> getAccounts(list<string> BDCAccountIds);
    abstract global List<HttpResponse> getAccountsFromFinancialInstitutionIdentities(List<BDCFinancialInstitutionIdentity> finInstIdens);
    abstract global List<HttpResponse> getCategories();


    abstract global Integer maxTransactionRecordsPerCallout();
}