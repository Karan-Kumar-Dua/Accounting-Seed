@IsTest
public class CubeBuilderTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testHandleAfterInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createCashFlowCategories(true);
        Test.startTest();
        testData.createPayables(true);

        System.runAs(testData.users[1]) {
            testData.createBillings(true).createCashReceipts();

            String hashCode =
                String.valueOf(testData.payables[0].Accounting_Period__c) +
                    testData.settings.Default_Ledger__c +
                    'Period' +
                    String.valueOf(testData.payableLines[0].Expense_GL_Account__c) +
                    'nullnullnullnull';

            System.assertEquals(1, [SELECT COUNT() FROM Financial_Cube__c WHERE Key__c = :hashCode]);
            System.assertNotEquals(0, [SELECT COUNT() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode]);
        }
    }

    @IsTest
    public static void testHandleAfterDelete() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users[1]) {

            Test.startTest();

            testData.journalEntries[0].Status__c = 'Approved';
            update testData.journalEntries[0];

            String hashCode =
                String.valueOf(testData.acctPeriods[1].Id) +
                    String.valueOf(testData.journalEntryLines[0].GL_Account__c) +
                    'nullnullnullnull';

            System.assertEquals(0, [SELECT COUNT() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode]);

            JournalEntryPost jep = new JournalEntryPost(new ApexPages.StandardController(testData.journalEntries[0]));
            jep.post();

            System.assertEquals('Posted', [SELECT Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Status__c);
            System.assertNotEquals(0, [SELECT COUNT() FROM Transaction__c WHERE Journal_Entry_Line__c = :testData.journalEntryLines[0].Id]);

            jep = new JournalEntryPost(new ApexPages.StandardController(testData.journalEntries[0]));
            jep.unpost();

            DMLException dmlEx;

            try {
                Database.undelete([SELECT Id FROM Transaction__c WHERE Journal_Entry_Line__r.Journal_Entry__c = :testData.journalEntries[0].Id ALL ROWS]);
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(StatusCode.UNDELETE_FAILED, dmlEx.getDmlType(0));
        }
    }

    @IsTest
    public static void delete200Trxns() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Billing__c> billings = new List<Billing__c>();
            Account act = testData.accounts[0];
            Accounting_Period__c accountingPeriod = testData.acctPeriods[0];

            for (Integer i = 0; i < 60; i++) {
                Billing__c bill = new Billing__c();
                bill.Proprietary_Billing_Number__c = 'i';
                bill.Customer__c = act.Id;
                bill.Accounting_Period__c = accountingPeriod.Id;
                billings.add(bill);
            }
            insert billings;

            List<Billing_Line__c> bLines = new List<Billing_Line__c>();
            for (Billing__c bill : billings) {
                Billing_Line__c objBillingLine = new Billing_Line__c();
                objBillingLine.Billing__c = bill.Id;
                objBillingLine.Rate__c = 25;
                objBillingLine.Hours_Units__c = 1;
                bLines.add(objBillingLine);

                objBillingLine = new Billing_Line__c();
                objBillingLine.Billing__c = bill.Id;
                objBillingLine.Rate__c = 25;
                objBillingLine.Hours_Units__c = 2;
                bLines.add(objBillingLine);
            }
            insert bLines;
            Test.stopTest();

            BillingPostService.postBillings(billings);
            BillingPostService.unpostBillings(billings);

            System.assertEquals(0, [SELECT count() FROM Transaction__c]);
        }
    }

}