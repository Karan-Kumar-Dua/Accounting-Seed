@IsTest
private class DeleteSourceDocumentsHelperTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testChangeDeletePeriodFormFalseToTrue() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            System.assert(![SELECT Source_Docs_Deleted__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods.get(0).Id LIMIT 1].Source_Docs_Deleted__c);

            DeleteSourceDocumentsHelper.startDeleteSourceDocumentsJob(testData.acctPeriods.get(0).Id);

            System.assert([SELECT Source_Docs_Deleted__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods.get(0).Id LIMIT 1].Source_Docs_Deleted__c);
        }

    }

    @isTest
    private static void testValidateDeleteSourceDocumentsArchivePeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            AuraHandledException expectedEx;
            try {
                DeleteSourceDocumentsHelper.validateDeleteSourceDocuments(testData.acctPeriods.get(0).Id);
            }
            catch(AuraHandledException ex) {
                expectedEx = ex;
            }

            System.assertNotEquals(Label.ERR_PERIOD_NOT_ARCHIVED, expectedEx.getMessage());

        }

    }

    @IsTest
    static void testValidateDeleteSourceDocumentsArchivePeriodAndDisabledFeature() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_ENABLE_DELETE_ARCHIVED_SOURCE_DOCS, false);
            Test.startTest();
            AuraHandledException expectedEx;
            try {
                DeleteSourceDocumentsHelper.validateDeleteSourceDocuments(testData.acctPeriods.get(0).Id);
            }
            catch(AuraHandledException ex) {
                expectedEx = ex;
            }

            System.assertNotEquals(Label.ERR_FEATURE_NOT_ENABLED + '{ERR}' + Label.ERR_PERIOD_NOT_ARCHIVED, expectedEx.getMessage());
        }
    }
}