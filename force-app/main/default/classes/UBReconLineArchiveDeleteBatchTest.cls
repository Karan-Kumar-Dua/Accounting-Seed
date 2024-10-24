@IsTest
private class UBReconLineArchiveDeleteBatchTest {
        
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    private static void testUBReconLineJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();
        //Create Bank Reconciliation record
        Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
            Bank_Account__c = testData.glAccounts.get(0).Id,
            Beginning_Balance__c = 0,
            Ending_Balance__c = 1000,
            End_Date__c = testData.acctPeriods[0].Start_Date__c,
            Type__c = BankReconciliation.BANK_TYPE
        );
        
       
        insert bankRec;
        //Create Uncleared Bank Reconciliation Line record
        Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
            Bank_Reconciliation__c = bankRec.Id,
            Amount__c = 100,
            Related_Source_Document__c = 'some text',
            Date__c = Date.today(),
            Type__c = BankReconciliation.DEPOSIT_TYPE,
            Cash_Receipt__c = testData.cashReceipts[0].Id
        );

        UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
        insert ubrecLine;
            System.runAs(testData.users[1]) {
            //Check total UnclearedBankReconciliationLine Records
            System.assertEquals(
                1, [
                    SELECT Id FROM Uncleared_Bank_Reconciliation_Line__c
                ].size() 
            );
            
            Test.startTest();
            //Run batch job to delete UnclearedBankReconciliationLine Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
             
        }
    }
}