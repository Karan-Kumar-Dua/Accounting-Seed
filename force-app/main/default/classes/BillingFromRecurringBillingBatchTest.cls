@IsTest
public with sharing class BillingFromRecurringBillingBatchTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateBillingsFromRecurringBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Database.executeBatch(new BillingFromRecurringBillingBatch(new Set<Id>{testData.recurringBillings[0].Id},false));
            Test.stopTest();

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
            );
            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction_Group__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
        }
    }
    @IsTest
    public static void testCreateBillingsFromRecurringBillingFailesTransactionGroup() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Transaction_Group__c txnGrp = getTransactionGroup(testData.recurringBillings[0].Id,NULL,TRUE,testData.recurringBillings[0].Ledger__c);
            INSERT txnGrp;

            Test.startTest();
            Database.executeBatch(new BillingFromRecurringBillingBatch(new Set<Id>{testData.recurringBillings[0].Id},false));
            Test.stopTest();

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
            );
            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction_Group__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id AND Status__c = 'Failed'
                ]
            );
        }
    }
    @IsTest
    public static void testCreateBillingsFromRecurringBillingPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Database.executeBatch(new BillingFromRecurringBillingBatch(new Set<Id>{testData.recurringBillings[0].Id},true));
            Test.stopTest();

            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id AND Status__c = 'Posted'
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
            );
            System.assertEquals(
                0, [
                    SELECT count()
                    FROM Transaction_Group__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
        }
    }
    private static Transaction_Group__c getTransactionGroup(Id recBillingId, Id billingId, Boolean isSuccess, Id ledgerId){
        Transaction_Group__c result = new Transaction_Group__c();
        result.Line_Count__c = 0;
        result.Lines_Processed__c = 0;
        result.Batch_Id__c = '123455';
        result.Recurring_Billing__c = recBillingId;
        result.Billing__c = billingId;
        result.Status__c = isSuccess == true ? 'Completed' : 'Failed';
        result.Ledger__c = ledgerId;
        return result; 
    }

}