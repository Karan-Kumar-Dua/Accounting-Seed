@IsTest
private with sharing class BankDepositHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testAssociateUnassociateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankDeposits();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            System.assertEquals(0, [SELECT count() FROM Cash_Receipt__c WHERE Bank_Deposit__c = :testData.bankDeposits[0].Id]);

            //to have actual Status value for each record
            testData.cashReceipts = [
                SELECT Id, Status__c, Cleared_Date__c, Bank_Deposit__c
                FROM Cash_Receipt__c
                WHERE Id IN :testData.cashReceipts
            ];

            BankDepositHandler bdh = new BankDepositHandler(testData.bankDeposits[0].Id);
            bdh.associateObjects(testData.cashReceipts);

            System.assertEquals(3, [SELECT count() FROM Cash_Receipt__c WHERE Bank_Deposit__c = :testData.bankDeposits[0].Id]);

            bdh.unAssociateObjects(
            [
                SELECT Id, Bank_Deposit__c
                FROM Cash_Receipt__c
                WHERE Bank_Deposit__c = :testData.bankDeposits[0].Id
            ]
            );
            System.assertEquals(0, [SELECT count() FROM Cash_Receipt__c WHERE Bank_Deposit__c = :testData.bankDeposits[0].Id]);
        }
    }

    @IsTest
    private static void testCalculateTotalAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
                                .createCashReceipts()
                                .createBankDeposits()
                                .createProjects()
                                .createProjectTasks()
                                .createJournalEntries(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.bankDeposits[0].Deposit_Date__c = Date.today();
            update testData.bankDeposits[0];

            //to have actual Status value for each record
            testData.cashReceipts = [
                SELECT Id, Status__c, Cleared_Date__c, Bank_Deposit__c, Amount__c
                FROM Cash_Receipt__c
                WHERE Id IN :testData.cashReceipts
            ];

            //Update Journal Entry date to set value before Bank Deposit date
            for (Journal_Entry__c testJE : testData.journalEntries) {
                testJE.Journal_Date__c = testData.bankDeposits[0].Deposit_Date__c.addDays(-1);
            }
            update testData.journalEntries;

            for (Journal_Entry_Line__c testLine : testData.journalEntryLines) {
                testLine.Date__c = testData.bankDeposits[0].Deposit_Date__c.addDays(-1);
            }
            update testData.journalEntryLines;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            postHandler.post(new List<Journal_Entry__c>(testData.journalEntries));

            testData.journalEntryLines = [
                SELECT Id, Date__c, Journal_Entry__r.Status__c, GL_Account__c, Cleared_Date__c, Bank_Deposit__c, Amount__c
                FROM Journal_Entry_Line__c
                WHERE Id IN :testData.journalEntryLines
            ];

            BankDepositHandler bdh = new BankDepositHandler(testData.bankDeposits[0].Id);
            bdh.associateObjects(testData.cashReceipts);
            bdh.associateObjects(new List<Journal_Entry_Line__c>{testData.journalEntryLines[1], testData.journalEntryLines[2]});
            System.assertEquals(0, [SELECT Id, Amount__c FROM Bank_Deposit__c WHERE Id = :testData.bankDeposits[0].Id].Amount__c);

            bdh.calculateTotalAmount();

            Decimal depositAmount =
                (Decimal) ([SELECT SUM(Amount__c) sum FROM Cash_Receipt__c WHERE Bank_Deposit__c = :testData.bankDeposits[0].Id])[0].get('sum')
                    + (Decimal) ([SELECT SUM(Amount__c) sum FROM Journal_Entry_Line__c WHERE Debit__c != NULL AND Bank_Deposit__c = :testData.bankDeposits[0].Id])[0].get('sum')
                    - (Decimal) ([SELECT SUM(Amount__c) sum FROM Journal_Entry_Line__c WHERE Credit__c != NULL AND Bank_Deposit__c = :testData.bankDeposits[0].Id])[0].get('sum');

            System.assertEquals(depositAmount, [SELECT Id, Amount__c FROM Bank_Deposit__c WHERE Id = :testData.bankDeposits[0].Id].Amount__c);
        }
    }

}