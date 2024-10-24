@IsTest
private with sharing class ConsolidationsIntegrationTest {

    @TestSetup
    private static void createTestData() {
        LedgerActions.isPreventUpdateOverride = true;
        AccountingPeriodActions.isPreventUpdateOverride = true;
        GLAccountActions.isPreventUpdateOverride = true;
        IntegrationTestDataFactory.getInstance(true);
    }

    @IsTest
    private static void testConsolidation_PnL_Period_1() {
        IntegrationTestDataFactory intTestData = IntegrationTestDataFactory.getInstance()
            .createLedgerHierarchies();

        System.runAs(intTestData.users[1]) {
            Test.startTest();
            //create elimination JEs for this test
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();
            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = intTestData.acctPeriodMap.get('2021-08').Id,
                    Journal_Date__c = intTestData.acctPeriodMap.get('2021-08').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = intTestData.ledgersMap.get('Acme Consolidation - EL').Id
                )
            );
            insert journalEntries;

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('4000-Product Revenue').Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('1200-Accounts Receivable').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('2000-Accounts Payable').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('6000-Marketing Expense').Id
                )
            );
            insert journalEntryLines;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);

            //close periods
            AccountingPeriodActions.isFirstRun = false;
            List<Accounting_Period__c> acctPeriods = intTestData.acctPeriods;
            for (Accounting_Period__c ap : acctPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update acctPeriods;

            //run consolidation
            AbstractLWCHelper.SaveResponse srConsolidation =
                ConsolidationsHelper.runConsolidation(
                    intTestData.ledgerHierarchies[0].Id,
                    intTestData.acctPeriodMap.get('2021-08').Id,
                    true
                );
            System.assertEquals(true, srConsolidation.isSuccess);

            //Validate Consolidation Cube Data
            for (Financial_Cube__c cube : [
                SELECT
                    Amount__c,
                    GL_Account__r.Name
                FROM Financial_Cube__c
                WHERE Accounting_Period__c = :intTestData.acctPeriodMap.get('2021-08').Id
                AND Ledger__c = :intTestData.ledgersMap.get('Acme Consolidation').Id
            ]) {

                switch on cube.GL_Account__r.Name {
                    when '1200-Accounts Receivable' {
                        System.assertEquals(32258.50, cube.Amount__c);
                    }
                    when '2000-Accounts Payable' {
                        System.assertEquals(-18799.05, cube.Amount__c);
                    }
                    when '4000-Product Revenue' {
                        System.assertEquals(-25000.45, cube.Amount__c);
                    }
                    when '4010-Services Revenue' {
                        System.assertEquals(-7258.05, cube.Amount__c);
                    }
                    when '6000-Marketing Expense' {
                        System.assertEquals(18258.05, cube.Amount__c);
                    }
                    when '7000-Facilities Expense' {
                        System.assertEquals(541, cube.Amount__c);
                    }
                }
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void testConsolidation_PnL_Period_2() {
        IntegrationTestDataFactory intTestData = IntegrationTestDataFactory.getInstance()
            .createLedgerHierarchies();


        System.runAs(intTestData.users[1]) {
            Test.startTest();
            //create elimination JEs for this test
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();
            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = intTestData.acctPeriodMap.get('2021-09').Id,
                    Journal_Date__c = intTestData.acctPeriodMap.get('2021-09').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = intTestData.ledgersMap.get('Acme Consolidation - EL').Id
                )
            );
            insert journalEntries;

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('4000-Product Revenue').Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('1200-Accounts Receivable').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('2000-Accounts Payable').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('6000-Marketing Expense').Id
                )
            );
            insert journalEntryLines;

            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);

            //close periods
            AccountingPeriodActions.isFirstRun = false;
            List<Accounting_Period__c> acctPeriods = intTestData.acctPeriods;
            for (Accounting_Period__c ap : acctPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update acctPeriods;

            //run consolidation
            AbstractLWCHelper.SaveResponse sr =
                ConsolidationsHelper.runConsolidation(
                    intTestData.ledgerHierarchies[0].Id,
                    intTestData.acctPeriodMap.get('2021-09').Id,
                    false
                );
            System.assertEquals(true, sr.isSuccess);

            //Test Cube Data
            for (Financial_Cube__c cube : [
                SELECT
                    Amount__c,
                    GL_Account__r.Name
                FROM Financial_Cube__c
                WHERE Accounting_Period__c = :intTestData.acctPeriodMap.get('2021-09').Id
                AND Ledger__c = :intTestData.ledgersMap.get('Acme Consolidation').Id
            ]) {

                switch on cube.GL_Account__r.Name {
                    when '1200-Accounts Receivable' {
                        System.assertEquals(1605.51, cube.Amount__c);
                    }
                    when '2000-Accounts Payable' {
                        System.assertEquals(-12868.15, cube.Amount__c);
                    }
                    when '4000-Product Revenue' {
                        System.assertEquals(-1020.78, cube.Amount__c);
                    }
                    when '4010-Services Revenue' {
                        System.assertEquals(-584.73, cube.Amount__c);
                    }
                    when '6000-Marketing Expense' {
                        System.assertEquals(7608.98, cube.Amount__c);
                    }
                    when '7000-Facilities Expense' {
                        System.assertEquals(5259.17, cube.Amount__c);
                    }
                }
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void testConsolidation_BS_TB_Period_1() {
        IntegrationTestDataFactory intTestData = IntegrationTestDataFactory.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);
        Test.startTest();
        intTestData.createCashReceipts();

        System.runAs(intTestData.users[1]) {
            intTestData.createLedgerHierarchies();

            //create elimination JEs for this test
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = intTestData.acctPeriodMap.get('2021-08').Id,
                    Journal_Date__c = intTestData.acctPeriodMap.get('2021-08').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = intTestData.ledgersMap.get('Acme Consolidation - EL').Id
                )
            );

            insert journalEntries;

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('1205-Unapplied A/R').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('2020-Accrued Expenses').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            insert journalEntryLines;
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);

            //close periods
            AccountingPeriodActions.isFirstRun = false;
            list<Accounting_Period__c> acctPeriods = intTestData.acctPeriods;
            for (Accounting_Period__c ap : acctPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update acctPeriods;

            //run consolidation
            AbstractLWCHelper.SaveResponse sr = ConsolidationsHelper.runConsolidation(intTestData.ledgerHierarchies[0].Id, intTestData.acctPeriodMap.get('2021-08').Id, true);
            System.assertEquals(true, sr.isSuccess);

            Test.stopTest();

            //Test Cube Data
            for(Financial_Cube__c cube : [SELECT Amount__c,
                GL_Account__r.Name
            FROM Financial_Cube__c
            WHERE Accounting_Period__c = :intTestData.acctPeriodMap.get('2021-08').Id
            AND Ledger__c = :intTestData.ledgersMap.get('Acme Consolidation').Id ]){

                switch on cube.GL_Account__r.Name {
                    when '1000-Cash' {
                        system.assertEquals(13459.45, cube.Amount__c);
                    }
                    when '1205-Unapplied A/R' {
                        system.assertEquals(-15000.45, cube.Amount__c);
                    }
                    when '2020-Accrued Expenses' {
                        system.assertEquals(541, cube.Amount__c);
                    }
                    when '2030-Accrued Payroll' {
                        system.assertEquals(10000, cube.Amount__c);
                    }
                    when '3000-Owners Equity' {
                        system.assertEquals(-10000, cube.Amount__c);
                    }
                    when '4000-Product Revenue' {
                        system.assertEquals(1000, cube.Amount__c);
                    }
                }
            }
        }
    }

    @IsTest
    private static void testConsolidation_BS_TB_Period_2() {
        IntegrationTestDataFactory intTestData = IntegrationTestDataFactory.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);
        Test.startTest();
        intTestData.createCashReceipts();


        System.runAs(intTestData.users[1]) {
            //create elimination JEs for this test
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = intTestData.acctPeriodMap.get('2021-09').Id,
                    Journal_Date__c = intTestData.acctPeriodMap.get('2021-09').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = intTestData.ledgersMap.get('Acme Consolidation - EL').Id
                )
            );

            insert journalEntries;

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('2030-Accrued Payroll').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 8058.69,
                    GL_Account__c = intTestData.glAccountsMap.get('3000-Owners Equity').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            insert journalEntryLines;
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);


            //close periods
            AccountingPeriodActions.isFirstRun = false;
            list<Accounting_Period__c> acctPeriods = intTestData.acctPeriods;
            for (Accounting_Period__c ap : acctPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update acctPeriods;


            intTestData.createLedgerHierarchies();
            //run consolidation
            AbstractLWCHelper.SaveResponse sr = ConsolidationsHelper.runConsolidation(intTestData.ledgerHierarchies[0].Id, intTestData.acctPeriodMap.get('2021-09').Id, true);
            System.assertEquals(true, sr.isSuccess);

            Test.stopTest();

            //Test Cube Data
            for(Financial_Cube__c cube : [SELECT Amount__c,
                GL_Account__r.Name
            FROM Financial_Cube__c
            WHERE Accounting_Period__c = :intTestData.acctPeriodMap.get('2021-09').Id
            AND Ledger__c = :intTestData.ledgersMap.get('Acme Consolidation').Id ]){

                switch on cube.GL_Account__r.Name {
                    when '1000-Cash' {
                        system.assertEquals(-11262.64, cube.Amount__c);
                    }
                    when '1205-Unapplied A/R' {
                        system.assertEquals(-1020.78, cube.Amount__c);
                    }
                    when '2020-Accrued Expenses' {
                        system.assertEquals(7114.06, cube.Amount__c);
                    }
                    when '2030-Accrued Payroll' {
                        system.assertEquals(0, cube.Amount__c);
                    }
                    when '3000-Owners Equity' {
                        system.assertEquals(0, cube.Amount__c);
                    }
                    when '4000-Product Revenue' {
                        system.assertEquals(5169.36, cube.Amount__c);
                    }
                }
            }
        }
    }


    @IsTest
    private static void testConsolidation_CF_Period_1(){
        Test.startTest();
        IntegrationTestDataFactory intTestData = IntegrationTestDataFactory.getInstance()
            .createJournalEntries(true);
        Test.stopTest();

        System.runAs(intTestData.users[1]) {

            intTestData.createLedgerHierarchies();

            //create elimination JEs for this test
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = intTestData.acctPeriodMap.get('2021-08').Id,
                    Journal_Date__c = intTestData.acctPeriodMap.get('2021-08').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = intTestData.ledgersMap.get('Acme Consolidation - EL').Id
                )
            );

            insert journalEntries;

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Account__c = intTestData.testData.accounts[0].Id

                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id,
                    Cash_Flow_Category__c = intTestData.testData.cashFlowCategories[1].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id,
                    Cash_Flow_Category__c = intTestData.testData.cashFlowCategories[7].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 4161.56,
                    GL_Account__c = intTestData.glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            insert journalEntryLines;
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);



            //close periods
            AccountingPeriodActions.isFirstRun = false;
            list<Accounting_Period__c> acctPeriods = intTestData.acctPeriods;
            for (Accounting_Period__c ap : acctPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update acctPeriods;

            //run consolidation
            AbstractLWCHelper.SaveResponse sr = ConsolidationsHelper.runConsolidation(intTestData.ledgerHierarchies[0].Id, intTestData.acctPeriodMap.get('2021-08').Id, true);
            System.assertEquals(true, sr.isSuccess);

            //Test Cube Data
            for(Financial_Cube__c cube : [SELECT Amount__c,
                GL_Account__r.Name
            FROM Financial_Cube__c
            WHERE Accounting_Period__c = :intTestData.acctPeriodMap.get('2021-08').Id
            AND Ledger__c = :intTestData.ledgersMap.get('Acme Consolidation').Id ]){

                switch on cube.GL_Account__r.Name {
                    when 'Payments to suppliers' {
                        system.assertEquals(8515.36, cube.Amount__c);
                    }
                    when 'Receipts from customers' {
                        system.assertEquals(150811.43, cube.Amount__c);
                    }
                    when 'Payment for fixed assets' {
                        system.assertEquals(9173.62, cube.Amount__c);
                    }
                    when 'Proceeds from sale of fixed assets' {
                        system.assertEquals(8471.68, cube.Amount__c);
                    }
                    when 'Proceeds from issuance of debt' {
                        system.assertEquals(7455.41, cube.Amount__c);
                    }
                    when 'Repayment of debt' {
                        system.assertEquals(-153361.16, cube.Amount__c);
                    }
                }
            }

        }
    }

    @IsTest
    private static void testConsolidation_CF_Period_2(){
        Test.startTest();
        IntegrationTestDataFactory intTestData = IntegrationTestDataFactory.getInstance()
            .createJournalEntries(true);
        Test.stopTest();

        System.runAs(intTestData.users[1]) {
            intTestData.createLedgerHierarchies();

            //create elimination JEs for this test
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();

            journalEntries.add(
                new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = intTestData.acctPeriodMap.get('2021-09').Id,
                    Journal_Date__c = intTestData.acctPeriodMap.get('2021-09').Start_Date__c,
                    Status__c = 'Approved',
                    Ledger__c = intTestData.ledgersMap.get('Acme Consolidation - EL').Id
                )
            );

            insert journalEntries;

            List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 209.15,
                    GL_Account__c = intTestData.glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 209.15,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id,
                    Cash_Flow_Category__c = intTestData.testData.cashFlowCategories[0].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Debit__c = 209.15,
                    GL_Account__c = intTestData.glAccountsMap.get('1000-Cash').Id,
                    Cash_Flow_Category__c = intTestData.testData.cashFlowCategories[11].Id
                )
            );
            journalEntryLines.add(
                new Journal_Entry_Line__c(
                    Journal_Entry__c = journalEntries[0].Id,
                    Credit__c = 209.15,
                    GL_Account__c = intTestData.glAccountsMap.get('5000-Cost of Goods Sold').Id,
                    Account__c = intTestData.testData.accounts[0].Id
                )
            );
            insert journalEntryLines;
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(journalEntries);
            System.assertEquals(true, postResults[0].isSuccess);

            //close periods
            AccountingPeriodActions.isFirstRun = false;
            list<Accounting_Period__c> acctPeriods = intTestData.acctPeriods;
            for (Accounting_Period__c ap : acctPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update acctPeriods;

            //run consolidation
            AbstractLWCHelper.SaveResponse sr = ConsolidationsHelper.runConsolidation(intTestData.ledgerHierarchies[0].Id, intTestData.acctPeriodMap.get('2021-09').Id, true);
            System.assertEquals(true, sr.isSuccess);

            //Test Cube Data
            for(Financial_Cube__c cube : [SELECT Amount__c,
                GL_Account__r.Name
            FROM Financial_Cube__c
            WHERE Accounting_Period__c = :intTestData.acctPeriodMap.get('2021-09').Id
            AND Ledger__c = :intTestData.ledgersMap.get('Acme Consolidation').Id ]){

                switch on cube.GL_Account__r.Name {
                    when 'Payments to suppliers' {
                        system.assertEquals(-1046.37, cube.Amount__c);
                    }
                    when 'Receipts from customers' {
                        system.assertEquals(907.95, cube.Amount__c);
                    }
                    when 'Payment for fixed assets' {
                        system.assertEquals(466.55, cube.Amount__c);
                    }
                    when 'Proceeds from sale of fixed assets' {
                        system.assertEquals(1087.6, cube.Amount__c);
                    }
                    when 'Proceeds from issuance of debt' {
                        system.assertEquals(-213.26, cube.Amount__c);
                    }
                    when 'Repayment of debt' {
                        system.assertEquals(506.42, cube.Amount__c);
                    }
                }
            }

        }

    }

}