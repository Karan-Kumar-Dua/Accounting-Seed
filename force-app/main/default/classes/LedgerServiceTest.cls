@IsTest
private class LedgerServiceTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testSetTestUserActiveLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Ledger_Custom_Settings__c test = Ledger_Custom_Settings__c.getInstance();

        System.assertEquals(testData.ledgers[0].Id, test.Ledger_Id__c);

        LedgerService.setTestUserActiveLedger(testData.ledgers[2].Id);
        test = Ledger_Custom_Settings__c.getInstance();

        System.assertEquals(testData.ledgers[2].Id, test.Ledger_Id__c);
    }

    @IsTest
    public static void testSetTestOrgDefaultLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Ledger_Custom_Settings__c test = Ledger_Custom_Settings__c.getOrgDefaults();

        System.assertEquals(testData.ledgers[0].Id, test.Ledger_Id__c);

        LedgerService.setTestOrgDefaultLedger(testData.ledgers[2].Id);
        test = Ledger_Custom_Settings__c.getOrgDefaults();

        System.assertEquals(testData.ledgers[2].Id, test.Ledger_Id__c);
    }

    @IsTest
    public static void testSetTestLedgerException() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Ledger_Custom_Settings__c test = Ledger_Custom_Settings__c.getOrgDefaults();

        System.assertEquals(testData.ledgers[0].Id, test.Ledger_Id__c);

        Exception ledgerEx;

        try {
            LedgerService.setTestOrgDefaultLedger(testData.settings.Id);
        } catch (Exception ex) {
            ledgerEx = ex;
        }

        System.assertEquals(LedgerService.LEDGER_ENVIRONMENT_ERROR, ledgerEx.getMessage());

        Exception ledgerEx2;

        try {
            LedgerService.setTestOrgDefaultLedger(testData.ledgers[1].Id);
        } catch (Exception ex) {
            ledgerEx2 = ex;
        }

        System.assertEquals(LedgerService.LEDGER_ENVIRONMENT_ERROR, ledgerEx2.getMessage());
    }

}