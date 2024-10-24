@isTest
public class BankReconciliationClearItemsBatchTest {
    private static final String WORKING = BankReconciliation.WORKING;
    private static final String COMPLETED = BankReconciliation.COMPLETED;
    private static final String IN_PROGRESS = BankReconciliation.IN_PROGRESS;

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testBatchExecute() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankReconciliations();
            

        System.runAs(testData.users[1]) {
            
            testData.cashDisbursements[6].Cleared_Date__c = System.today().addDays(5);               
            update testData.cashDisbursements[6];
            
            
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c> {testData.cashDisbursements[6]});
            System.assertEquals(true, postResults[0].isSuccess);

            Bank_Reconciliation2__c brec = testData.bankReconciliations[0];
            TriggerObserver.getInstance().unlockField(Bank_Reconciliation2__c.End_Date__c);
            brec.End_Date__c = System.today().addDays(30);
            brec.Ending_Balance__c = 19790.00;
            update brec;
            TriggerObserver.reset();

            Test.startTest();            
            Database.executeBatch(new BankReconciliationClearItemsBatch(brec.Id));            
            Test.stopTest();            
            
            System.assertEquals(IN_PROGRESS, [SELECT Status__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Status__c);
            System.assertEquals(brec.Id, [SELECT Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[6].Id].Bank_Reconciliation__c);
            System.assertEquals(210.00, [SELECT Cleared_Disbursements__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Cleared_Disbursements__c);
            System.assertEquals(0.00, [SELECT Cleared_Deposits__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Cleared_Deposits__c);
            System.assertEquals(0, [SELECT Uncleared_Amount__c FROM Bank_Reconciliation2__c WHERE Id = :brec.Id].Uncleared_Amount__c);

        }
    }
}