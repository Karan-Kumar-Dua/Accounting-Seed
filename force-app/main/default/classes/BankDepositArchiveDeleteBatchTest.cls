@IsTest
private class BankDepositArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testDeleteBankDepositJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits();
        List<Bank_Deposit__c> bankDeposits = new List<Bank_Deposit__c>();
        
        bankDeposits.add(
            new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[1].Start_Date__c + 2,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1'
            )
        );
        
        bankDeposits.add(
            new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[1].Start_Date__c + 2,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 2'
            )
        );
        insert bankDeposits;
        
        System.runAs(testData.users[1]) {
            //Check total bankDeposit Records
            System.assertEquals(
                4, [
                    SELECT Id from Bank_Deposit__c
                ].size() 
            );
            
            //Check bankDeposit Records having end date is
            // between the related Period StartDate and End Date
            System.assertEquals(
                2, [
                    SELECT Id from Bank_Deposit__c WHERE Deposit_Date__c > :testData.acctPeriods[1].Start_Date__c 
                    AND Deposit_Date__c < :testData.acctPeriods[1].End_Date__c 
                ].size() 
            );
            
            Test.startTest();
            //Run batch job to delete bankDeposit Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[1].Id), null);
            Test.stopTest();
            
            //Make sure bankDeposit Records deleted.
            System.assertEquals(
                0, [
                    SELECT Id FROM Bank_Deposit__c
                ].size() 
            );
        }
    }

    @IsTest
    static void testDeleteBankDepositJobSkipAssociatedWithBREC() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits().createBankReconciliations();
        List<Bank_Deposit__c> bankDeposits = new List<Bank_Deposit__c>();

        bankDeposits.add(
            new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[1].Start_Date__c + 2,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1'
            )
        );

        bankDeposits.add(
            new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[1].Start_Date__c + 2,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 2'
            )
        );
        insert bankDeposits;

        Bank_Deposit__c bd = [SELECT Id, Deposit_Reference__c FROM Bank_Deposit__c WHERE Deposit_Reference__c = 'the reference 2' LIMIT 1];
        bd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
        TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Deposit__c.Bank_Reconciliation__c});
        update bd;
        TriggerObserver.reset();

        System.runAs(testData.users[1]) {
            //Check total bankDeposit Records
            System.assertEquals(
                4, [
                    SELECT Id from Bank_Deposit__c
                ].size()
            );

            //Check bankDeposit Records having end date is
            // between the related Period StartDate and End Date
            System.assertEquals(
                2, [
                    SELECT Id from Bank_Deposit__c WHERE Deposit_Date__c > :testData.acctPeriods[1].Start_Date__c
                    AND Deposit_Date__c < :testData.acctPeriods[1].End_Date__c
                ].size()
            );

            Test.startTest();
            //Run batch job to delete bankDeposit Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[1].Id), null);
            Test.stopTest();

            //Make sure bankDeposit Records deleted.
            System.assertEquals(
                1, [
                    SELECT Id FROM Bank_Deposit__c
                ].size()
            );
        }
    }
}