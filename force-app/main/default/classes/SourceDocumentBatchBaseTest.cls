@IsTest
private class SourceDocumentBatchBaseTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testCreateAutomatedJobResult() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Database.executeBatch(new BillingLDVPostBatch(), 200);
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Post', ajr[0].Schedule_Job_Type__c);
            System.assertEquals(5, ajr[0].Processed__c);
            System.assertEquals(5, ajr[0].Succeeded__c);
            System.assertEquals(0, ajr[0].Failed__c);
        }
    }

    @IsTest
    private static void testValidateScopeState() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentBatchBase billBatch = new BillingLDVPostBatch(new Map<Id, Billing__c> (testData.billings).keySet());

            System.assertEquals(Billing__c.getSObjectType(), billBatch.scopeState.headerSObjectType);
            System.assertEquals('AcctSeed__Billing__c', billBatch.scopeState.parentRelationshipField);

            System.assertEquals(SourceDocumentBatchOptions.ExecutionContext.POST, billBatch.options.context);
            System.assertEquals(SourceDocumentBatchOptions.AccountingMethod.ACCRUAL, billBatch.options.currentMethod);

            Database.executeBatch(billBatch, 200);
            Test.stopTest();

            List<Automated_Job_Results__c> ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals(1, ajr.size());
            System.assertEquals('Large Data Optimizer Post', ajr[0].Schedule_Job_Type__c);
        }
    }
}