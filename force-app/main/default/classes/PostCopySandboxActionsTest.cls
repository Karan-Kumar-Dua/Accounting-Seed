@IsTest
private class PostCopySandboxActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    static void testSandboxPostCopyScript() {

        TestDataSuite testData = TestDataSuite.getInstance();
        Ledger_Custom_Settings__c oldValue = Ledger_Custom_Settings__c.getOrgDefaults();

        Ledger_Custom_Settings__c lcs = Ledger_Custom_Settings__c.getInstance();
        lcs.Ledger_Id__c = testData.ledgers[0].Id;
        upsert lcs;

        System.assertEquals(testData.ledgers[0].Id, oldValue.Ledger_Id__c);
        System.assertNotEquals(1, DomainUtils.getAllLedgerCustomSettings().size());

        testData.settings.Default_Ledger__c = testData.ledgers[2].Id;
        update testData.settings;

        Test.startTest();

        Test.testSandboxPostCopyScript(
            new PostCopySandboxActions(),
            UserInfo.getOrganizationId(),
            UserInfo.getOrganizationId(),
            'TestSandboxName'
        );

        Ledger_Custom_Settings__c newValue = Ledger_Custom_Settings__c.getOrgDefaults();

        System.assertEquals(testData.ledgers[2].Id, newValue.Ledger_Id__c);
        System.assertEquals(1, DomainUtils.getAllLedgerCustomSettings().size());
        Test.stopTest();

    }
}