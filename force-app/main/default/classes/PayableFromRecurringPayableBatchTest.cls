@IsTest
public with sharing class PayableFromRecurringPayableBatchTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Database.executeBatch(new PayableFromRecurringPayableBatch(new Set<Id>{testData.recurringPayables[0].Id},false));
            Test.stopTest();

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Account_Payable__c
                    WHERE Recurring_Account_Payable__c = :testData.recurringPayables[0].Id
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Account_Payable_Line__c
                    WHERE Recurring_Account_Payable_Line__c IN :testData.recurringPayableLines
                ]
            );
            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction_Group__c
                    WHERE Recurring_Account_Payable__c = :testData.recurringPayables[0].Id
                ]
            );
        }
    }
    @IsTest
    public static void testFail() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Transaction_Group__c txnGrp = getTransactionGroup(testData.recurringPayables[0].Id,NULL,TRUE,testData.ledgers[0].Id);
            INSERT txnGrp;

            Test.startTest();
            Database.executeBatch(new PayableFromRecurringPayableBatch(new Set<Id>{testData.recurringPayables[0].Id},false));
            Test.stopTest();

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Account_Payable__c
                    WHERE Recurring_Account_Payable__c = :testData.recurringPayables[0].Id
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Account_Payable_Line__c
                    WHERE Recurring_Account_Payable_Line__c IN :testData.recurringPayableLines
                ]
            );
            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction_Group__c
                    WHERE Recurring_Account_Payable__c = :testData.recurringPayables[0].Id AND Status__c = 'Failed'
                ]
            );
        }
    }
    @IsTest
    public static void testPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Database.executeBatch(new PayableFromRecurringPayableBatch(new Set<Id>{testData.recurringPayables[0].Id},true));
            Test.stopTest();

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Account_Payable__c
                    WHERE Recurring_Account_Payable__c = :testData.recurringPayables[0].Id AND Status__c = 'Posted'
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Account_Payable_Line__c
                    WHERE Recurring_Account_Payable_Line__c IN :testData.recurringPayableLines
                ]
            );
            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction_Group__c
                    WHERE Recurring_Account_Payable__c = :testData.recurringPayables[0].Id
                ]
            );
        }
    }
    private static Transaction_Group__c getTransactionGroup(Id recurPayableId, Id payableId, Boolean isSuccess, Id ledgerId){
        Transaction_Group__c result = new Transaction_Group__c();
        result.Line_Count__c = 0;
        result.Lines_Processed__c = 0;
        result.Batch_Id__c = '123455';
        result.Recurring_Account_Payable__c = recurPayableId;
        result.Account_Payable__c = payableId;
        result.Status__c = isSuccess == true ? 'Completed' : 'Failed';
        result.Ledger__c = ledgerId;
        return result; 
    }
}