@IsTest
private class BankReconciliationArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testDeleteBankReconciliationJob() {
        
        TestDataSuite testData = TestDataSuite.getInstance().createBankReconciliations();
        List<Bank_Reconciliation2__c> bankReconciliations = new List<Bank_Reconciliation2__c>();
        
        bankReconciliations.add(
            new Bank_Reconciliation2__c(
                End_Date__c = testData.acctPeriods[0].Start_Date__c+5,
                Bank_Account__c = testData.glAccounts[0].Id,
                Beginning_Balance__c = 20000,
                Ending_Balance__c = 30000,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Type__c = BankReconciliation.BANK_TYPE
            )
        );
        
        bankReconciliations.add(
            new Bank_Reconciliation2__c(
                End_Date__c = testData.acctPeriods[0].Start_Date__c+4,
                Bank_Account__c = testData.glAccounts[0].Id,
                Beginning_Balance__c = 20000,
                Ending_Balance__c = 30000,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Type__c = BankReconciliation.BANK_TYPE
            )
        );
        
        //bank rec 2 is first in chain of bank recs for status testing
        bankReconciliations.add(
            new Bank_Reconciliation2__c(
                End_Date__c = testData.acctPeriods[0].Start_Date__c+3,
                Bank_Account__c = testData.glAccounts[29].Id,
                Beginning_Balance__c = 20000,
                Ending_Balance__c = 30000,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Type__c = BankReconciliation.BANK_TYPE
            )
        );
        
        //bank rec 3 is second in chain of bank recs for status testing
        bankReconciliations.add(
            new Bank_Reconciliation2__c(
                End_Date__c = testData.acctPeriods[0].Start_Date__c+2,
                Bank_Account__c = testData.glAccounts[29].Id,
                Beginning_Balance__c = 20000,
                Ending_Balance__c = 30000,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Type__c = BankReconciliation.BANK_TYPE
            )
        );
        
        BankReconciliationActions.bypassDefaultStatusWorking = true;
        insert bankReconciliations;
        BankReconciliationActions.bypassDefaultStatusWorking = false;
        
        System.runAs(testData.users[1]) {
            //Check total bankReconciliations Records
            System.assertEquals(
                12, [
                    SELECT Id FROM Bank_Reconciliation2__c
                ].size() 
            );
            
            //Check bankReconciliations Records having end date is
            // between the related Period StartDate and End Date
            System.assertEquals(
                4, [
                    SELECT Id FROM Bank_Reconciliation2__c WHERE End_Date__c > :testData.acctPeriods[0].Start_Date__c
                    AND End_Date__c < :testData.acctPeriods[0].End_Date__c 
                ].size() 
            );
            
            Test.startTest();
            //Run batch job to delete Reconciliation Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure bankReconciliations Records deleted.
            System.assertEquals(
                6, [
                    SELECT Id FROM Bank_Reconciliation2__c
                ].size() 
            );
        }
    }
}