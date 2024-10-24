public with sharing class PurgeZeroBalanceFinancialCubesBatch extends PurgeBaseBatch {

    public PurgeZeroBalanceFinancialCubesBatch() {
        this.objectLabel = Financial_Cube__c.getSObjectType().getDescribe().getLabel();
    }
    
    public override Database.QueryLocator start(Database.BatchableContext bc) {
        return DomainUtils.getQueryLocatorForPurgeZeroBalanceFinancialCubesBatch();
    }

    public override void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Financial_Cube__c> fCubesForDelete = findFCubesWithoutFCubesTransactions((List<Financial_Cube__c>) scope);
        if (!fCubesForDelete.isEmpty()) {
            FinancialCubeActions.isPreventOverride = true;
            SFDCSecurityUtils.deleteProxy(fCubesForDelete);
            FinancialCubeActions.isPreventOverride = false;
            Database.emptyRecycleBin(fCubesForDelete);
        }
    }

    private List<Financial_Cube__c> findFCubesWithoutFCubesTransactions(List<Financial_Cube__c> sourceList) {
        List<Financial_Cube__c> fCubesWithoutFCubesTransactions = new List<Financial_Cube__c>();
        for (Financial_Cube__c eachFCube : sourceList) {
            if (eachFCube.Financial_Cube_Transactions__r.isEmpty()) {
                fCubesWithoutFCubesTransactions.add(eachFCube);
            }
        }
        return fCubesWithoutFCubesTransactions;
    }
    
}