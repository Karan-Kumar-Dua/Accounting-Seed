@IsTest
private class SourceDocumentBatchOptionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidateContextAndMethods() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentBatchOptions sbo = new SourceDocumentBatchOptions(SourceDocumentBatchOptions.ExecutionContext.POST, Billing__c.getSObjectType());

            System.assertEquals(SourceDocumentBatchOptions.ExecutionContext.POST, sbo.currentContext());
            System.assertEquals(SourceDocumentBatchOptions.AccountingMethod.ACCRUAL, sbo.currentAccountingMethod());
            System.assertEquals(false, sbo.hasNext());
        }
    }
}