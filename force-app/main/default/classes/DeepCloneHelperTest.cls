@IsTest
public with sharing class DeepCloneHelperTest {
    @TestSetup
    static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetDeepCloneInfoForRecurringBilling() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        Date currentDate = Date.today();
        String objectName = 'AcctSeed__Recurring_Billing__c';
        System.runAs(testData.users.get(1)){
            Recurring_Billing__c testRecurringBillingObject = testData.createRecurringBilling().recurringBillings[0];
            Id recurringBillingId = testRecurringBillingObject.Id;
            Test.startTest();
            DeepCloneHelper.DeepCloneInfo dci = DeepCloneHelper.getDeepCloneInfo(recurringBillingId);
            Test.stopTest();
            System.assertEquals(currentDate, dci.currentDate, 'Actual and Expected Current Date is not matching');
            System.assertEquals(objectName, dci.currentObjectName, 'Actual and Expected Current Object Name is not matching');
        }
    }

    @IsTest
    private static void testGetDeepCloneInfoForRecurringAccountPayable() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        Date currentDate = Date.today();
        String objectName = 'AcctSeed__Recurring_Account_Payable__c';
        System.runAs(testData.users.get(1)){
            Recurring_Account_Payable__c testRecurringAccountPayableObject = testData.createRecurringAccountPayables().recurringPayables[0];
            Id recurringAccountPayableId = testRecurringAccountPayableObject.Id;
            Test.startTest();
            DeepCloneHelper.DeepCloneInfo dci = DeepCloneHelper.getDeepCloneInfo(recurringAccountPayableId);
            Test.stopTest();
            System.assertEquals(currentDate, dci.currentDate, 'Actual and Expected Current Date is not matching');
            System.assertEquals(objectName, dci.currentObjectName, 'Actual and Expected Current Object Name is not matching');
        }
    }

    @IsTest
    private static void testGetDeepCloneInfoForRecurringJournalEntry() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Boolean isMultiCurrencyEnabled = MultiCurrencyHandler.isMultiCurrencyEnabled;
        Date currentDate = Date.today();
        String objectName = 'AcctSeed__Recurring_Journal_Entry__c';
        System.runAs(testData.users.get(1)){
            Recurring_Journal_Entry__c testRecurringJournalEntryObject = testData.createRecurringJournalEntry().recurringJournalEntries[0];
            Id recurringJournalEntryId = testRecurringJournalEntryObject.Id;
            Test.startTest();
            DeepCloneHelper.DeepCloneInfo dci = DeepCloneHelper.getDeepCloneInfo(recurringJournalEntryId);
            Test.stopTest();
            System.assertEquals(currentDate, dci.currentDate, 'Actual and Expected Current Date is not matching');
            System.assertEquals(objectName, dci.currentObjectName, 'Actual and Expected Current Object Name is not matching');
        }
    }

    @IsTest
    private static void testCloneObjectAndLinesForRecurringBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();
        System.runAs(testData.users.get(1)){
            Recurring_Billing__c testRecurringBillingObject = testData.recurringBillings[0];
            Id recurringBillingId = testRecurringBillingObject.Id;
            Recurring_Billing__c template = new Recurring_Billing__c(
                Next_Billing_Date__c = Date.newInstance(1992,1,1)
            );
            String recordString = JSON.serialize(template);
            Test.startTest();
            Id recId = DeepCloneHelper.cloneObjectAndLines(recurringBillingId, recordString);
            Test.stopTest();
            System.assertEquals(1, [SELECT Id FROM Recurring_Billing__c WHERE Id = :recId].size(), 'Actual and Expected Created Object is not matching');
        }
    }

    @IsTest
    private static void testCloneObjectAndLinesForRecurringAccountPayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)){
            Recurring_Account_Payable__c testRecurringAccountPayableObject = testData.recurringPayables[0];
            Id recurringAccountPayableId = testRecurringAccountPayableObject.Id;
            Recurring_Account_Payable__c template = new Recurring_Account_Payable__c(Next_Account_Payable_Date__c = Date.newInstance(1992,1,1));
            String recordString = JSON.serialize(template);
            Test.startTest();
            Id recId = DeepCloneHelper.cloneObjectAndLines(recurringAccountPayableId, recordString);
            Test.stopTest();
            System.assertEquals(1, [SELECT Id FROM Recurring_Account_Payable__c WHERE Id = :recId].size(), 'Actual and Expected Created Object is not matching');
        }
    }

    @IsTest
    private static void testCloneObjectAndLinesForRecurringJournalEntry() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();
        System.runAs(testData.users.get(1)){
            Recurring_Journal_Entry__c testRecurringJournalEntryObject = testData.recurringJournalEntries[0];
            Id recurringJournalEntryId = testRecurringJournalEntryObject.Id;
            Recurring_Journal_Entry__c template = new Recurring_Journal_Entry__c(Next_Journal_Entry_Date__c = Date.newInstance(1992,1,1));
            String recordString = JSON.serialize(template);
            Test.startTest();
            Id recId = DeepCloneHelper.cloneObjectAndLines(recurringJournalEntryId, recordString);
            Test.stopTest();
            System.assertEquals(1, [SELECT Id FROM Recurring_Journal_Entry__c WHERE Id = :recId].size(), 'Actual and Expected Created Object is not matching');
        }
    }
    
    @IsTest
    private static void testCloneObjectAndLinesForSoftARCloseRecurringBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();
        System.runAs(testData.users.get(1)){
            try{
                Accounting_Period__c actPeriod = [Select id, Close_AR__c from Accounting_Period__c WHERE Start_Date__c =: Date.newInstance(1991, 11, 1)];
                actPeriod.Close_AR__c = true;
                UPDATE actPeriod;

                Recurring_Billing__c testRecurringBillingObject = testData.recurringBillings[0];
                    Recurring_Billing__c template = new Recurring_Billing__c(
                    Next_Billing_Date__c = Date.newInstance(1991, 11, 1)
                );

                Id recurringBillingId = testRecurringBillingObject.Id;
                String recordString = JSON.serialize(template);

                Test.startTest();
                Id recId = DeepCloneHelper.cloneObjectAndLines(recurringBillingId, recordString);
                Test.stopTest();
            }
            catch(Exception error){
               System.assertEquals(TRUE, error.getMessage().contains('Script-thrown'), 'No accounting period exist for selected range');
            }
        }
    }

    @IsTest
    private static void testCloneObjectAndLinesForSoftAPCloseRecurringAccountPayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
            System.runAs(testData.users.get(1)){
                try{
                    Accounting_Period__c actPeriod = [Select id, Close_AP__c from Accounting_Period__c WHERE Start_Date__c =: Date.newInstance(1991, 11, 1)];
                    actPeriod.Close_AP__c = true;
                    UPDATE actPeriod;

                    Recurring_Account_Payable__c testRecurringAccountPayableObject = testData.recurringPayables[0];
                    Id recurringAccountPayableId = testRecurringAccountPayableObject.Id;
                    Recurring_Account_Payable__c template = new Recurring_Account_Payable__c(Next_Account_Payable_Date__c = Date.newInstance(1991, 11, 1));
                    String recordString = JSON.serialize(template);
                    Test.startTest();
                    Id recId = DeepCloneHelper.cloneObjectAndLines(recurringAccountPayableId, recordString);
                    Test.stopTest();
                }
                catch(Exception error){
                    System.assertEquals(TRUE, error.getMessage().contains('Script-thrown'), 'No accounting period exist for selected range');
                }
        }
    }

}