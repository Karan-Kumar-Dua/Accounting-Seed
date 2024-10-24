@IsTest
private class BankTransactionArchiveDeleteBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @IsTest
    static void testBankTransactionJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankTransactions();   
        List<Bank_Transaction__c> bankTransactions = new List<Bank_Transaction__c>();
            //0
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-10',
                    Bank_Transaction_Id__c = '00101010',
                    Container__c = 'bank',
                    Key__c = 'bank' + '11110111',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c + 2,
                    Base_Type__c = 'Credit',
                    Amount__c = 390,
                    Description__c = 'Description 9',
                    GL_Account_Mapping__c = testData.glams[0].Id
                )
            );
            //1
            bankTransactions.add(
                new Bank_Transaction__c(
                    Account_Id__c = 'yodleeAccount-9',
                    Bank_Transaction_Id__c = '101010101',
                    Container__c = 'creditCard',
                    Key__c = 'creditCard' + '22292222',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c  + 2,
                    Transaction_Date__c = testData.acctPeriods.get(0).Start_Date__c  + 2,
                    Base_Type__c = 'Debit',
                    Amount__c = 180,
                    Description__c = 'Description 10',
                    GL_Account_Mapping__c = testData.glams[0].Id
                )
            );
            
            insert bankTransactions;
            System.runAs(testData.users[1]) {
            //Check total BankTransaction Records
            System.assertEquals(
                testData.bankTransactions.size() + 2, [
                    SELECT Id FROM Bank_Transaction__c
                ].size() 
            );
            
                //Check total BankTransaction Records Where batch Condition met.
            System.assertEquals(
                1, [
                    SELECT Id FROM Bank_Transaction__c WHERE Transaction_Date__c > :testData.acctPeriods[0].Start_Date__c
                                                        AND Transaction_Date__c < :testData.acctPeriods[0].End_Date__c
                ].size() 
            );
            

            Test.startTest();
            //Run batch job to delete BankTransaction Records.
            AbstractArchiveDeleteBatch.executeBatchChain(new AbstractArchiveDeleteBatch.ArchiveDeleteChainController(testData.acctPeriods[0].Id), null);
            Test.stopTest();
            
            //Make sure BankTransaction Records deleted.
            System.assertEquals(
                testData.bankTransactions.size() + 1, [
                    SELECT Id FROM Bank_Transaction__c 
                ].size() 
            );      
        }
    }
}