global abstract class AbstractBDCConverter {
    abstract global BDCServiceResult convertTransactions(List<HttpResponse> responses);
    abstract global BDCServiceResult convertAccounts(List<HttpResponse> responses);
    abstract global BDCServiceResult convertFinancialInstitutions(List<HttpResponse> responses);
    abstract global BDCServiceResult convertFinancialInstitutionIdentities(List<HttpResponse> responses);
    abstract global BDCServiceResult convertCategories(List<HttpResponse> responses); 
    abstract global BDCServiceResult convertDeleteFinancialInstitutionIdentity(List<HttpResponse> responses, BDCFinancialInstitutionIdentity finInstIden);

}