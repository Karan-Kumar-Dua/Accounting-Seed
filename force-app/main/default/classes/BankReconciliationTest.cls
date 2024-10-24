@IsTest
private class BankReconciliationTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testClearRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            List<Id> itemIds = new List<Id>();
            Map<Id, Date> itemIdToClearedDate = new Map<Id, Date>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
                itemIdToClearedDate.put(cr.Id, Date.today().addDays(-1));
            }

            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                itemIds.add(cd.Id);
                itemIdToClearedDate.put(cd.Id, Date.today().addDays(-1));
            }

            for (Bank_Deposit__c bd : testData.bankDeposits) {
                itemIds.add(bd.Id);
                itemIdToClearedDate.put(bd.Id, Date.today().addDays(-1));
            }

            for (Bank_Disbursement__c bankDisb : testData.bankDisbursements) {
                itemIds.add(bankDisb.Id);
                itemIdToClearedDate.put(bankDisb.Id, Date.today().addDays(-1));
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
                itemIdToClearedDate.put(jeLine.Id, Date.today().addDays(-1));
            }

            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds, itemIdToClearedDate);
            System.assertEquals(true, result.isSuccess);

            for (Cash_Receipt__c cr : [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts]) {
                System.assertEquals(bankRec.Id, cr.Bank_Reconciliation__c);
            }
            
            Integer recCount = 0;
            Map<Id, Cash_Receipt__c> cashReceiptMap = new Map<Id, Cash_Receipt__c>(testData.cashReceipts);
            Map<Id, Journal_Entry_Line__c> journalEntryLinesMap = new Map<Id, Journal_Entry_Line__c>(testData.journalEntryLines);

            List<Cash_Receipt__c> crs = [SELECT Id, Cleared_Date__c FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts];
            List<Cash_Disbursement__c> cds = [SELECT Id, Cleared_Date__c FROM Cash_Disbursement__c WHERE Id IN :testData.cashDisbursements];
            List<Journal_Entry_Line__c> jels = [SELECT Id, Cleared_Date__c FROM Journal_Entry_Line__c WHERE Id IN :testData.journalEntryLines];
            List<Bank_Deposit__c> bds = [SELECT Id, Cleared_Date__c FROM Bank_Deposit__c WHERE Id IN :testData.bankDeposits];
            List<Bank_Disbursement__c> bankDisbs = [SELECT Id, Cleared_Date__c FROM Bank_Disbursement__c WHERE Id IN :testData.bankDisbursements];

            List<SObject> allProcessedRecs = new List<SObject>();
            allProcessedRecs.addAll(crs);
            allProcessedRecs.addAll(cds);
            allProcessedRecs.addAll(jels);
            allProcessedRecs.addAll(bds);
            allProcessedRecs.addAll(bankDisbs);

            for (SObject eachRecord : allProcessedRecs) {
                System.assertEquals(Date.today().addDays(-1), (Date) eachRecord.get('Cleared_Date__c'));
            }
        }
    }

    @IsTest
    static void testClearItemsPreventsVoidCD() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            Cash_Disbursement__c cd = testData.cashDisbursements[0];

            Test.startTest();
            // void the CD
            ApexPages.StandardController stdController = new ApexPages.StandardController(cd);
            CashDisbursementVoid voidController = new CashDisbursementVoid(stdController);
            voidController.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].End_Date__c;
            voidController.voidCashDisbursement();

            // clear the voided CD
            ServiceResult result = BankReconciliation.clear(bankRec.Id, new List<Id>{cd.Id});

            // the voided CD should not be cleared
            Assert.isFalse(result.results[0].isSuccess, 'Expected a void CD is prevented from being cleared.');
            Assert.areEqual(BankReconciliation.StatusCode.INVALID_CLEAR_RECORD.name(), result.results[0].errors[0].code, 'Expected error message for voided CD.');
            Test.stopTest();
        }
    }

    @IsTest
    static void testClearItemsPreventsVoidCR() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            // void the CR
            Cash_Receipt__c cr = testData.cashReceipts[0];
            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = cr.Id;
            voidData.voidReceiptDate = cr.Receipt_Date__c.addDays(1);
            new CashReceiptVoid().voidCashReceipt(voidData);

            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            // clear the voided cr
            ServiceResult result = BankReconciliation.clear(bankRec.Id, new List<Id>{cr.Id});
            // the voided cr should not be cleared
            Assert.isFalse(result.results[0].isSuccess, 'Expected a void CR is prevented from being cleared.');
            Assert.areEqual(BankReconciliation.StatusCode.INVALID_CLEAR_RECORD.name(), result.results[0].errors[0].code, 'Expected error message for voided CR.');
            Test.stopTest();
        }
    }

    @IsTest
    static void testClearItemsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            List<Id> itemIds = new List<Id>();
            Map<Id, Date> itemIdToClearedDate = new Map<Id, Date>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
                itemIdToClearedDate.put(cr.Id, Date.today().addDays(-1));
            }

            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                itemIds.add(cd.Id);
                itemIdToClearedDate.put(cd.Id, Date.today().addDays(-1));
            }

            for (Bank_Deposit__c bd : testData.bankDeposits) {
                itemIds.add(bd.Id);
                itemIdToClearedDate.put(bd.Id, Date.today().addDays(-1));
            }

            for (Bank_Disbursement__c bankDisb : testData.bankDisbursements) {
                itemIds.add(bankDisb.Id);
                itemIdToClearedDate.put(bankDisb.Id, Date.today().addDays(-1));
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
                itemIdToClearedDate.put(jeLine.Id, Date.today().addDays(-1));
            }

            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);

            for (Cash_Receipt__c cr : [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts]) {
                System.assertEquals(bankRec.Id, cr.Bank_Reconciliation__c);
            }

            for (Cash_Disbursement__c cd : [SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id IN :testData.cashDisbursements]) {
                System.assertEquals(bankRec.Id, cd.Bank_Reconciliation__c);
            }

            for (Journal_Entry_Line__c jel : [SELECT Id, Bank_Reconciliation__c FROM Journal_Entry_Line__c WHERE Id IN :testData.journalEntryLines]) {
                System.assertEquals(bankRec.Id, jel.Bank_Reconciliation__c);
            }

            for (Bank_Deposit__c bd : [SELECT Id, Bank_Reconciliation__c FROM Bank_Deposit__c WHERE Id IN :testData.bankDeposits]) {
                System.assertEquals(bankRec.Id, bd.Bank_Reconciliation__c);
            }

            for (Bank_Disbursement__c bd : [SELECT Id, Bank_Reconciliation__c FROM Bank_Disbursement__c WHERE Id IN :testData.bankDisbursements]) {
                System.assertEquals(bankRec.Id, bd.Bank_Reconciliation__c);
            }
        }
    }

    @IsTest
    static void testSetStatusAutoClearRunning() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            Test.startTest();
            ServiceResult result = BankReconciliation.setStatus(bankRec.Id, BankReconciliation.Status.AUTO_CLEAR_RUNNING);
            Test.stopTest();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(BankReconciliation.AUTO_CLEAR_RUNNING, [
                SELECT Id, Status__c
                FROM Bank_Reconciliation2__c
                WHERE Id = :bankRec.Id LIMIT 1].Status__c);
        }
    }

    @IsTest
    static void testClearItemsLegacyBRSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[7];

            List<Id> itemIds = new List<Id>();
            Map<Id, Date> itemIdToClearedDate = new Map<Id, Date>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
                itemIdToClearedDate.put(cr.Id, Date.today().addDays(-1));
            }

            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                itemIds.add(cd.Id);
                itemIdToClearedDate.put(cd.Id, Date.today().addDays(-1));
            }

            for (Bank_Deposit__c bd : testData.bankDeposits) {
                itemIds.add(bd.Id);
                itemIdToClearedDate.put(bd.Id, Date.today().addDays(-1));
            }

            for (Bank_Disbursement__c bankDisb : testData.bankDisbursements) {
                itemIds.add(bankDisb.Id);
                itemIdToClearedDate.put(bankDisb.Id, Date.today().addDays(-1));
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
                itemIdToClearedDate.put(jeLine.Id, Date.today().addDays(-1));
            }

            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);

            for (Cash_Receipt__c cr : [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts]) {
                System.assertEquals(bankRec.Id, cr.Bank_Reconciliation__c);
            }

            for (Cash_Disbursement__c cd : [SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id IN :testData.cashDisbursements]) {
                System.assertEquals(bankRec.Id, cd.Bank_Reconciliation__c);
            }

            for (Journal_Entry_Line__c jel : [SELECT Id, Bank_Reconciliation__c FROM Journal_Entry_Line__c WHERE Id IN :testData.journalEntryLines]) {
                System.assertEquals(bankRec.Id, jel.Bank_Reconciliation__c);
            }

            for (Bank_Deposit__c bd : [SELECT Id, Bank_Reconciliation__c FROM Bank_Deposit__c WHERE Id IN :testData.bankDeposits]) {
                System.assertEquals(bankRec.Id, bd.Bank_Reconciliation__c);
            }

            for (Bank_Disbursement__c bd : [SELECT Id, Bank_Reconciliation__c FROM Bank_Disbursement__c WHERE Id IN :testData.bankDisbursements]) {
                System.assertEquals(bankRec.Id, bd.Bank_Reconciliation__c);
            }
        }
    }

    @IsTest
    static void testClearItemsLegacyBRError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BankReconciliationActions.bypassDefaultStatusWorking = true;

            Bank_Reconciliation2__c bankRecLegacy = testData.bankReconciliations[7].clone();
            bankRecLegacy.End_Date__c = testData.acctPeriods[0].Start_Date__c + 29;

            delete testData.bankReconciliations[7];
            insert bankRecLegacy;

            Bank_Reconciliation2__c brec = [
                SELECT
                    Id, Uncleared_Amount__c, End_Date__c
                FROM Bank_Reconciliation2__c
                WHERE Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];

            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }

            update brec;

            BankReconciliationActions.bypassDefaultStatusWorking = true;
            BankReconciliation.complete(brec.Id);

            List<Id> itemIds = new List<Id>();
            Map<Id, Date> itemIdToClearedDate = new Map<Id, Date>();

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
                itemIdToClearedDate.put(cr.Id, Date.today().addDays(-1));
            }

            ServiceResult result = BankReconciliation.clear(bankRecLegacy.Id, itemIds);
            System.assertEquals(false, result.isSuccess);
            String errorMsg = String.format(BankReconciliation.INVALID_CLEAR_UNCLEAR_LEGACY, new List<String>{Label.COMMON_SMALL_CLEAR});
            System.assertEquals(errorMsg, result.errors[0].detail);

            for (Cash_Receipt__c cr : [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts]) {
                System.assertEquals(NULL, cr.Bank_Reconciliation__c);
            }
        }
    }

    @IsTest
    static void testClearWith1GlavMatching() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createAccountingVariables()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cr = testData.cashReceipts[0];
            CashReceiptPostService.unpostCashReceipts(new List<Cash_Receipt__c>{cr});
            cr.GL_Account_Variable_1__c= testData.accountingVariables1[0].id;
            cr.GL_Account_Variable_2__c= testData.accountingVariables2[0].id;
            update cr;

            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            List<Id> itemIds = new List<Id>{cr.Id};

            Test.startTest();
            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
        }
    }
    
    @IsTest
    static void testUnClearCashReceiptsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            List<Id> itemIds = new List<Id>();
            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
            }

            Test.startTest();
            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);

            result = BankReconciliation.unclear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    static void testUnClearCashDisbursementsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            List<Id> itemIds = new List<Id>();
            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                itemIds.add(cd.Id);
            }

            Test.startTest();
            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
            result = BankReconciliation.unclear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    static void testUnClearBankDepositSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            List<Id> itemIds = new List<Id>();
            for (Bank_Deposit__c bd : testData.bankDeposits) {
                itemIds.add(bd.Id);
            }

            Test.startTest();
            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
            result = BankReconciliation.unclear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    static void testUnClearBankDisbursementSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDisbursements()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            List<Id> itemIds = new List<Id>();
            for (Bank_Disbursement__c bd : testData.bankDisbursements) {
                itemIds.add(bd.Id);
            }

            Test.startTest();
            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
            result = BankReconciliation.unclear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    static void testUnClearJournalEntryLinesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            List<Id> itemIds = new List<Id>();
            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            Test.startTest();
            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
            result = BankReconciliation.unclear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    static void testRetrieveRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            List<Id> itemIds = new List<Id>();
            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id);
            Integer recCount = 0;
            Map<Id, Cash_Receipt__c> cashReceiptMap = new Map<Id, Cash_Receipt__c>(testData.cashReceipts);
            Map<Id, Journal_Entry_Line__c> journalEntryLinesMap = new Map<Id, Journal_Entry_Line__c>(testData.journalEntryLines);

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cashReceipt {
                        System.assertEquals(true, cashReceiptMap.containsKey(cashReceipt.Id));
                        recCount++;
                    }
                    when Journal_Entry_Line__c journalEntryLine {
                        System.assertEquals(true, journalEntryLinesMap.containsKey(journalEntryLine.Id));
                        recCount++;
                    }
                }
            }

            System.assertEquals(recCount, retrieveResult.items.size());
        }
    }

    @IsTest
    static void testRetrieveAllRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            Integer crRecCount = 0;
            Integer cdRecCount = 0;
            Integer jelRecCount = 0;
            Integer bdRecCount = 0;
            Integer bankDisbRecCount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crRecCount++;
                    }
                    when Cash_Disbursement__c cd {
                        cdRecCount++;
                    }
                    when Journal_Entry_Line__c jel {
                        jelRecCount++;
                    }
                    when Bank_Deposit__c bd {
                        bdRecCount++;
                    }
                    when Bank_Disbursement__c bankDisb{
                        bankDisbRecCount++;
                    }
                }
            }

            System.assertEquals(testData.cashReceipts.size(), crRecCount);
            System.assertEquals(testData.cashDisbursements.size(), cdRecCount);
            System.assertEquals(testData.journalEntryLines.size(), jelRecCount);
            System.assertEquals(testData.bankDeposits.size(), bdRecCount);
            System.assertEquals(testData.bankDisbursements.size(), bankDisbRecCount);
        }
    }

    @IsTest
    static void testRetrieveAllRecordsWithDifferentLedger() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

            Test.startTest();
                System.runAs(testData.users.get(1)) {
                    Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
                    bankRec.End_Date__c = System.today().addDays(30);
                    bankRec.Ledger__c = testData.ledgers[2].Id;
                    insert bankRec;            

                    testData.cashReceipts[0].Ledger__c = testData.ledgers[2].Id;
                    testData.cashDisbursements[0].Ledger__c = testData.ledgers[2].Id;
                    testData.journalEntries[0].Ledger__c = testData.ledgers[2].Id;
                    testData.bankDeposits[0].Ledger__c = testData.ledgers[2].Id;
                    testData.bankDisbursements[0].Ledger__c = testData.ledgers[2].Id;

                    update testData.cashReceipts[0];
                    update testData.cashDisbursements[0];
                    update testData.journalEntries[0];
                    update testData.bankDeposits[0];
                    update testData.bankDisbursements[0];

                
                    postAllSourceRecords();

                    BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

                    Integer crRecCount = 0;
                    Integer cdRecCount = 0;
                    Integer jelRecCount = 0;
                    Integer bdRecCount = 0;
                    Integer bankDisbRecCount = 0;

                    for (SObject item : retrieveResult.items) {
                        switch on item {
                            when Cash_Receipt__c cr {
                                crRecCount++;
                            }
                            when Cash_Disbursement__c cd {
                                cdRecCount++;
                            }
                            when Journal_Entry_Line__c jel {
                                jelRecCount++;
                            }
                            when Bank_Deposit__c bd {
                                bdRecCount++;
                            }
                            when Bank_Disbursement__c bankDisb{
                                bankDisbRecCount++;
                            }
                        }
                    }

                    System.assertEquals(1, crRecCount);
                    System.assertEquals(1, cdRecCount);
                    System.assertEquals(2, jelRecCount);
                    System.assertEquals(1, bdRecCount);
                    System.assertEquals(1, bankDisbRecCount);
                }
            Test.stopTest();
    }

    @IsTest
    static void testRetrieveAllRecordsWithDifferentGLAVs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createAccountingVariables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            bankRec.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            insert bankRec;

            testData.cashReceipts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.cashDisbursements[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.journalEntryLines[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.bankDeposits[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.bankDisbursements[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;

            update testData.cashReceipts[0];
            update testData.cashDisbursements[0];
            update testData.journalEntryLines[0];
            update testData.bankDeposits[0];
            update testData.bankDisbursements[0];

            postAllSourceRecords();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            Integer crRecCount = 0;
            Integer cdRecCount = 0;
            Integer jelRecCount = 0;
            Integer bdRecCount = 0;
            Integer bankDisbRecCount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crRecCount++;
                    }
                    when Cash_Disbursement__c cd {
                        cdRecCount++;
                    }
                    when Journal_Entry_Line__c jel {
                        jelRecCount++;
                    }
                    when Bank_Deposit__c bd {
                        bdRecCount++;
                    }
                    when Bank_Disbursement__c bankDisb{
                        bankDisbRecCount++;
                    }
                }
            }

            System.assertEquals(1, crRecCount);
            System.assertEquals(1, cdRecCount);
            System.assertEquals(1, jelRecCount);
            System.assertEquals(1, bdRecCount);
            System.assertEquals(1, bankDisbRecCount);
        }
    }

    @IsTest
    static void testRetrieveAllRecordsWithDifferentDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(2);
            insert bankRec;

            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                cd.Disbursement_Date__c = testData.acctPeriods.get(1).Start_Date__c;
            }
            testData.cashDisbursements[0].Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c;
            testData.journalEntries[0].Journal_Date__c = testData.acctPeriods.get(0).Start_Date__c;
            testData.bankDeposits[0].Deposit_Date__c = testData.acctPeriods.get(0).Start_Date__c;
            testData.bankDisbursements[0].Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c;

            update testData.cashDisbursements;
            update testData.journalEntries[0];
            update testData.bankDeposits[0];
            update testData.bankDisbursements[0];

            Test.startTest();
            postAllSourceRecords();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            Integer crRecCount = 0;
            Integer cdRecCount = 0;
            Integer jelRecCount = 0;
            Integer bdRecCount = 0;
            Integer bankDisbRecCount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crRecCount++;
                    }
                    when Cash_Disbursement__c cd {
                        cdRecCount++;
                    }
                    when Journal_Entry_Line__c jel {
                        jelRecCount++;
                    }
                    when Bank_Deposit__c bd {
                        bdRecCount++;
                    }
                    when Bank_Disbursement__c bankDisb{
                        bankDisbRecCount++;
                    }
                }
            }

            System.assertEquals(1, crRecCount);
            System.assertEquals(1, cdRecCount);
            System.assertEquals(2, jelRecCount);
            System.assertEquals(1, bdRecCount);
            System.assertEquals(1, bankDisbRecCount);
        }
    }

    @IsTest
    static void testRetrieveAllRecordsWithAssociatedBD() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec; 
            
            Bank_Deposit__c deposit = testData.bankDeposits[0];
            deposit.Deposit_Date__c = System.today();
            update deposit;

            BankDepositHandler bdhCR = new BankDepositHandler(testData.bankDeposits[0].Id);
            bdhCR.associateObjects(new List<SObject> {testData.cashReceipts[0]});

            BankDepositHandler bdhJEL = new BankDepositHandler(testData.bankDeposits[0].Id);
            bdhJEL.associateObjects(new List<SObject> {testData.journalEntryLines[0]});

            Test.startTest();

            postAllSourceRecords();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            Integer crRecCount = 0;
            Integer cdRecCount = 0;
            Integer jelRecCount = 0;
            Integer bdRecCount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crRecCount++;
                    }
                    when Cash_Disbursement__c cd {
                        cdRecCount++;
                    }
                    when Journal_Entry_Line__c jel {
                        jelRecCount++;
                    }
                    when Bank_Deposit__c bd {
                        bdRecCount++;
                    }
                }
            }

            System.assertEquals(testData.cashReceipts.size()-1, crRecCount);
            System.assertEquals(testData.cashDisbursements.size(), cdRecCount);
            System.assertEquals(testData.journalEntryLines.size()-1, jelRecCount);
            System.assertEquals(testData.bankDeposits.size(), bdRecCount);
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveAllRecordsWithAssociatedBankDisb() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {

            Test.startTest();
            
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec; 
            
            Bank_Disbursement__c disb = testData.bankDisbursements[0];
            disb.Disbursement_Date__c = System.today();
            update disb;

            Cash_Disbursement__c cdToUpdate = testData.cashDisbursements[0];
            cdToUpdate.Bank_Disbursement__c = disb.id;
            update cdToUpdate;

            Journal_Entry_Line__c jelToUpdate = testData.journalEntryLines[0];
            jelToUpdate.Bank_Disbursement__c = disb.id;
            update jelToUpdate;


            postAllSourceRecords();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            Integer crRecCount = 0;
            Integer cdRecCount = 0;
            Integer jelRecCount = 0;
            Integer bdRecCount = 0;
            Integer bankDisbRecCount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crRecCount++;
                    }
                    when Cash_Disbursement__c cd {
                        cdRecCount++;
                    }
                    when Journal_Entry_Line__c jel {
                        jelRecCount++;
                    }
                    when Bank_Deposit__c bd {
                        bdRecCount++;
                    }
                    when Bank_Disbursement__c bd {
                        bankDisbRecCount++;
                    }
                }
            }

            System.assertEquals(testData.cashReceipts.size(), crRecCount);
            System.assertEquals(testData.cashDisbursements.size()-1, cdRecCount);
            System.assertEquals(testData.journalEntryLines.size()-1, jelRecCount);
            System.assertEquals(testData.bankDeposits.size(), bdRecCount);
            System.assertEquals(testData.bankDisbursements.size(), bankDisbRecCount);
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveAllRecordsCDVoided() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = testData.acctPeriods[1].End_Date__c.addDays(2);
            insert bankRec;

            List<Cash_Disbursement__c> cdList = new List<Cash_Disbursement__c>();
            Cash_Disbursement__c cd1 = testData.cashDisbursements[0].clone(false, true);
            cd1.Bank_Reconciliation__c = bankRec.Id;
            cdList.add(cd1);

            Cash_Disbursement__c cd2 = testData.cashDisbursements[0].clone(false, true);
            cd2.Bank_Reconciliation__c = bankRec.Id;
            cdList.add(cd2);

            insert cdList;
            Test.startTest();
            CashDisbursementPostService.postCashDisbursements(new List<Cash_Disbursement__c>{cd1, cd2});

            ApexPages.StandardController stdController = new ApexPages.StandardController(cd1);
            CashDisbursementVoid voidController = new CashDisbursementVoid(stdController);
            voidController.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].End_Date__c;
            voidController.voidCashDisbursement();

            ApexPages.StandardController stdController2 = new ApexPages.StandardController(cd2);
            CashDisbursementVoid voidController2 = new CashDisbursementVoid(stdController2);
            voidController2.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].End_Date__c.addDays(7);
            voidController2.voidCashDisbursement();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            Integer cdRecCount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Disbursement__c cd {
                        cdRecCount++;
                    }
                }
            }

            System.assertEquals(testData.cashDisbursements.size() + 1, cdRecCount);
        }
    }

    @IsTest
    static void testRetrieveAllRecordsQueryLimits() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            BankReconciliation.QUERY_LIMIT_PER_SRC_DOC = 2;

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            Integer crRecCount = 0;
            Integer cdRecCount = 0;
            Integer jelRecCount = 0;
            Integer bdRecCount = 0;
            Integer bankDisbRecCount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crRecCount++;
                    }
                    when Cash_Disbursement__c cd {
                        cdRecCount++;
                    }
                    when Journal_Entry_Line__c jel {
                        jelRecCount++;
                    }
                    when Bank_Deposit__c bd {
                        bdRecCount++;
                    }
                    when Bank_Disbursement__c bankDisb{
                        bankDisbRecCount++;
                    }
                }
            }

            System.assertEquals(
                BankReconciliation.QUERY_LIMIT_PER_SRC_DOC,
                crRecCount + cdRecCount + jelRecCount + bdRecCount + bankDisbRecCount
            );
        }
    }

    private static void postAllSourceRecords() {
        TestDataSuite testData = TestDataSuite.getInstance();

        AbstractPostHandler postHandlerCR = new CashReceiptPostHandler();
        List<PostResult> postResultsCR = postHandlerCR.post(testData.cashReceipts);
        System.assertEquals(true, postResultsCR[0].isSuccess);

        AbstractPostHandler postHandlerCD = new CashDisbursementPostHandler();
        List<PostResult> postResultsCD = postHandlerCD.post(testData.cashDisbursements);
        System.assertEquals(true, postResultsCD[0].isSuccess);

        AbstractPostHandler postHandlerJE = new JournalEntryPostHandler();
        List<PostResult> postResultsJE = postHandlerJE.post(testData.journalEntries);
        System.assertEquals(true, postResultsJE[0].isSuccess);
    }

    @IsTest
    static void testCalculateUnclearedDepositsAndPaymentsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.End_Date__c = System.today().addDays(30);
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.End_Date__c});
            update bankRec;

            ServiceResult sr = BankReconciliation.calculateUnclearedDepositsAndPayments(bankRec.Id);

            Test.stopTest();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, false, true);

            Double crAmount = 0;
            Double cdAmount = 0;
            Double jelCreditAmount = 0;
            Double jelDebitAmount = 0;
            Double bdAmount = 0;
            Double bankDisbAmount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crAmount += (Double)cr.get('Amount__c');
                    }
                    when Cash_Disbursement__c cd {
                        cdAmount += (Double)cd.get('Amount__c');
                    }
                    when Journal_Entry_Line__c jel {
                        if (jel.get('Credit__c') != NULL) {
                            jelCreditAmount += (Double)jel.get('Credit__c');
                        } else if (jel.get('Debit__c') != NULL) {
                            jelDebitAmount += (Double)jel.get('Debit__c');
                        }
                    }
                    when Bank_Deposit__c bd {
                        bdAmount += (Double)bd.get('Amount__c');
                    }
                    when Bank_Disbursement__c bankDisb{
                        bankDisbAmount += (Double)bankDisb.get('Amount__c');
                    }
                }
            }
            System.assertEquals(true, sr.isSuccess);
            List<Bank_Reconciliation2__c> recs = [SELECT Id, UnCleared_Deposits__c, UnCleared_Payments__c FROM Bank_Reconciliation2__c WHERE Id = :bankRec.Id];
            System.assertEquals(1, recs.size());
            System.assertEquals(crAmount + bdAmount + jelDebitAmount, recs[0].UnCleared_Deposits__c);
            System.assertEquals(cdAmount + jelCreditAmount + bankDisbAmount, recs[0].UnCleared_Payments__c);
        }
    }

 
    @IsTest
    static void testRetrieveItemCount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.End_Date__c = System.today().addDays(30);
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.End_Date__c});
            update bankRec;

            BankReconciliationModel retrieveItemCountResult = BankReconciliation.retrieveItemCount(bankRec.Id);
            Test.stopTest();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, true, true);            
            System.assertEquals(retrieveItemCountResult.recordCount, retrieveResult.recordCount);            
        }
    }

    @IsTest
    static void testRetrieveItemCountWithQueryLimit() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.End_Date__c = System.today().addDays(30);
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.End_Date__c});
            update bankRec;

            BankReconciliation.QUERY_LIMIT_PER_SRC_DOC = 1;

            BankReconciliationModel retrieveItemCountResult = BankReconciliation.retrieveItemCount(bankRec.Id);
            Test.stopTest();
          
            BankReconciliation.QUERY_LIMIT_PER_SRC_DOC = 1000;
            BankReconciliationModel retrieveItemsResult = BankReconciliation.retrieve(bankRec.Id, true, true);

            System.assertEquals(retrieveItemsResult.recordCount, retrieveItemCountResult.recordCount);            
        }
    }

    @IsTest
    static void testCreateUnclearedBankReconciliationLinesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            ServiceResult result = BankReconciliation.createUnclearedBankReconciliationLines(bankRec.Id);
            System.assertEquals(true, result.isSuccess);
            Test.stopTest();

            BankReconciliationModel model = BankReconciliation.retrieve(bankRec.Id, false, true);
            System.assertEquals(model.recordCount, [SELECT Id FROM Uncleared_Bank_Reconciliation_Line__c].size());

        }
    }

    @IsTest
    static void testDeleteUnclearedBankReconciliationLinesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankDeposits()
            .createBankDisbursements()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            ServiceResult result = BankReconciliation.createUnclearedBankReconciliationLines(bankRec.Id);
            System.assertEquals(true, result.isSuccess);
            Integer recordCount = [SELECT Id FROM Uncleared_Bank_Reconciliation_Line__c].size();
            System.assertNotEquals(0, recordCount);

            ServiceResult resultDelete = BankReconciliation.deleteUnclearedBankReconciliationLines(bankRec.Id);
            System.assertEquals(true, resultDelete.isSuccess);
            Test.stopTest();

            System.assertEquals(0, [SELECT Id FROM Uncleared_Bank_Reconciliation_Line__c].size());

        }
    }

    @IsTest
    static void testClearRecordsSuccessWithSameCurrencyAsLedger_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashReceipts()
                .createCashDisbursementBatches()
                .createCashDisbursements()
                .createBankDeposits()
                .createBankDisbursements()
                .createProjects()
                .createProjectTasks();
            Test.startTest();
            testData.createJournalEntries(true)
                .createBankReconciliations();

            System.runAs(testData.users.get(1)) {
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }

                Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

                List<Id> itemIds = new List<Id>();

                for (Cash_Receipt__c cr : testData.cashReceipts) {
                    itemIds.add(cr.Id);
                }

                Cash_Disbursement_Batch__c cdb = testData.cashDisbursementBatch[0].clone();
                cdb.put('CurrencyIsoCode', newCurrency);
                insert cdb;

                List<Cash_Disbursement__c> cdList = new List<Cash_Disbursement__c>();
                for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                    Cash_Disbursement__c newCd = cd.clone();
                    newCd.Cash_Disbursement_Batch__c = cdb.Id;
                    newCd.put('CurrencyIsoCode', newCurrency);
                    cdList.add(newCd);
                }
                insert cdList;

                for (Cash_Disbursement__c cd : cdList) {
                    itemIds.add(cd.Id);
                }

                AbstractPostHandler postHandler = new CashDisbursementPostHandler();
                List<PostResult> postResults = postHandler.post(cdList);

                System.assertEquals(true, postResults[0].isSuccess);

                for (Bank_Deposit__c bd : testData.bankDeposits) {
                    itemIds.add(bd.Id);
                }

                for (Bank_Disbursement__c bd : testData.bankDisbursements) {
                    itemIds.add(bd.Id);
                }

                for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                    itemIds.add(jeLine.Id);
                }

                ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
                System.assertEquals(true, result.isSuccess);

                List<Cash_Receipt__c> crs = [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts];
                List<Cash_Disbursement__c> cds = [SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id IN :cdList];
                List<Journal_Entry_Line__c> jels = [SELECT Id, Bank_Reconciliation__c FROM Journal_Entry_Line__c WHERE Id IN :testData.journalEntryLines];
                List<Bank_Deposit__c> bds = [SELECT Id, Bank_Reconciliation__c FROM Bank_Deposit__c WHERE Id IN :testData.bankDeposits];
                List<Bank_Disbursement__c> bankDisbs = [SELECT Id, Bank_Reconciliation__c FROM Bank_Disbursement__c WHERE Id IN :testData.bankDisbursements];

                List<SObject> allProcessedRecs = new List<SObject>();
                allProcessedRecs.addAll(crs);
                allProcessedRecs.addAll(cds);
                allProcessedRecs.addAll(jels);
                allProcessedRecs.addAll(bds);
                allProcessedRecs.addAll(bankDisbs);

                for (SObject eachRecord : allProcessedRecs) {
                    System.assertEquals(bankRec.Id, (Id) eachRecord.get('Bank_Reconciliation__c'));
                }
            }

        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    static void testClearRecordsSuccessWithDifferentCurrencyAsLedger_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashReceipts()
                .createCashDisbursementBatches()
                .createCashDisbursements()
                .createBankDeposits()
                .createBankDisbursements()
                .createProjects()
                .createProjectTasks();
            Test.startTest();
            testData.createJournalEntries(true)
                .createBankReconciliations();

            System.runAs(testData.users.get(1)) {
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }

                Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
                bankRec.put('CurrencyIsoCode', newCurrency);
                insert bankRec;

                List<Id> itemIds = new List<Id>();
                Map<Id, Date> itemIdToClearedDate = new Map<Id, Date>();

                for (Cash_Receipt__c cr : testData.cashReceipts) {
                    itemIds.add(cr.Id);
                }

                Cash_Disbursement_Batch__c cdb = testData.cashDisbursementBatch[0].clone();
                cdb.put('CurrencyIsoCode', newCurrency);
                insert cdb;

                List<Cash_Disbursement__c> cdList = new List<Cash_Disbursement__c>();
                for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                    Cash_Disbursement__c newCd = cd.clone();
                    newCd.Cash_Disbursement_Batch__c = cdb.Id;
                    newCd.put('CurrencyIsoCode', newCurrency);
                    cdList.add(newCd);
                }
                insert cdList;

                for (Cash_Disbursement__c cd : cdList) {
                    itemIds.add(cd.Id);
                }

                AbstractPostHandler postHandler = new CashDisbursementPostHandler();
                List<PostResult> postResults = postHandler.post(cdList);

                System.assertEquals(true, postResults[0].isSuccess);

                for (Bank_Deposit__c bd : testData.bankDeposits) {
                    itemIds.add(bd.Id);
                }

                for (Bank_Disbursement__c bd : testData.bankDisbursements) {
                    itemIds.add(bd.Id);
                }

                for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                    itemIds.add(jeLine.Id);
                }

                ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
                System.assertEquals(true, result.isSuccess);

                List<Cash_Receipt__c> crs = [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id IN :testData.cashReceipts];
                List<Cash_Disbursement__c> cds = [SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id IN :cdList];
                List<Journal_Entry_Line__c> jels = [SELECT Id, Bank_Reconciliation__c FROM Journal_Entry_Line__c WHERE Id IN :testData.journalEntryLines];
                List<Bank_Deposit__c> bds = [SELECT Id, Bank_Reconciliation__c FROM Bank_Deposit__c WHERE Id IN :testData.bankDeposits];
                List<Bank_Disbursement__c> bankDisbs = [SELECT Id, Bank_Reconciliation__c FROM Bank_Disbursement__c WHERE Id IN :testData.bankDisbursements];

                List<SObject> allProcessedRecs = new List<SObject>();
                allProcessedRecs.addAll(crs);
                allProcessedRecs.addAll(cds);
                allProcessedRecs.addAll(jels);
                allProcessedRecs.addAll(bds);
                allProcessedRecs.addAll(bankDisbs);

                for (Cash_Receipt__c eachRecord : crs) {
                    System.assertEquals(NULL, eachRecord.Bank_Reconciliation__c);
                }
                for (Cash_Disbursement__c eachRecord : cds) {
                    System.assertEquals(bankRec.Id, (Id) eachRecord.get('Bank_Reconciliation__c'));
                }
                for (Journal_Entry_Line__c eachRecord : jels) {
                    System.assertEquals(NULL, eachRecord.Bank_Reconciliation__c);
                }
                for (Bank_Deposit__c eachRecord : bds) {
                    System.assertEquals(NULL, eachRecord.Bank_Reconciliation__c);
                }
                for (Bank_Disbursement__c eachRecord : bankDisbs) {
                    System.assertEquals(NULL, eachRecord.Bank_Reconciliation__c);
                }
            }

        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }
  
    @IsTest
    static void testClearRecordsSkipVoidedCDSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];

            List<Id> itemIds = new List<Id>();

            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                itemIds.add(cd.Id);
            }

            ApexPages.StandardController stdController = new ApexPages.StandardController([
                SELECT  Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__r.Status__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[0].Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(stdController);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.cashDisbursementVoid.Disbursement_Date__c = cdv.cashDisbursement.Disbursement_Date__c;
            cdv.voidCashDisbursement();

            Test.startTest();
            ServiceResult result = BankReconciliation.clear(bankRec.Id, itemIds);
            System.assertEquals(true, result.isSuccess);

            List<Cash_Disbursement__c> cds = [SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id IN :testData.cashDisbursements];

            List<Cash_Disbursement__c> clearedRecs = new List<Cash_Disbursement__c>();

            for (Cash_Disbursement__c eachRecord : cds) {
                if (eachRecord.Bank_Reconciliation__c != NULL) {
                    clearedRecs.add(eachRecord);
                }
            }

            System.assertEquals(cds.size() - 1, clearedRecs.size());
        }
    }

    @IsTest
    static void testComplete() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();
        Test.startTest();
        testData.createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cr = testData.cashReceipts[2].clone(false,true,false,false);
            insert cr;

            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.Beginning_Balance__c = 0;
            bankRec.Ending_Balance__c = cr.Amount__c;
            update bankRec;

            BankReconciliation.clear(bankRec.Id, new Id[] { cr.Id });

            ServiceResult result = BankReconciliation.complete(bankRec.Id);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();

            System.assert(result.isSuccess);
            Bank_Reconciliation2__c bankRecResult = [
                SELECT GL_Ending_Balance__c, Status__c
                FROM Bank_Reconciliation2__c 
                WHERE Id = :bankRec.Id 
                LIMIT 1
            ];
            System.assertEquals(BankReconciliation.COMPLETED, bankRecResult.Status__c);
            System.assertEquals(cr.Amount__c + testData.cashReceipts[2].Amount__c, bankRecResult.GL_Ending_Balance__c);

            Integer ubrlCount = [
                SELECT COUNT() 
                FROM Uncleared_Bank_Reconciliation_Line__c 
                WHERE Bank_Reconciliation__c = :bankRec.Id
            ];
            System.assertEquals(1, ubrlCount);
        }
    }

    @IsTest
    static void testCompleteOverLimit() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cr = testData.cashReceipts[2].clone(false,true,false,false);
            insert cr;

            Test.startTest();
            BankReconciliation.MAX_CLEARABLE_RECORDS_PER_BANK_REC = 1;
            ServiceResult result = BankReconciliation.complete(testData.bankReconciliations[0].Id);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();

            System.assert(!result.isSuccess);
            System.assert(!result.errors.isEmpty());
            System.assertEquals(BankReconciliation.StatusCode.CLEARABLE_ITEM_LIMIT.name(), result.errors[0].code);
            System.assertEquals(
                String.format(BankReconciliation.RECORD_COUNT_OVER_LIMIT_UPDATE, new String[] { String.valueOf(BankReconciliation.MAX_CLEARABLE_RECORDS_PER_BANK_REC), '2' }), 
                result.errors[0].detail
            );
        }
    }

    @IsTest
    static void testCompleteAlreadyWorking() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.Beginning_Balance__c = 0;
            bankRec.Ending_Balance__c = 0;
            update bankRec;            

            Test.startTest();
            BankReconciliation.complete(bankRec.Id);
            ServiceResult result = BankReconciliation.complete(bankRec.Id);
            Test.stopTest();

            System.assert(!result.isSuccess);
            System.assert(!result.errors.isEmpty());
            System.assertEquals(BankReconciliation.StatusCode.INVALID_STATUS_CHANGE.name(), result.errors[0].code);
            System.assertEquals(BankReconciliation.WORKING_STATUS_CHANGE, result.errors[0].detail);
        }
    }

    @IsTest
    static void testCompleteAlreadyCompleted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.Beginning_Balance__c = 0;
            bankRec.Ending_Balance__c = 0;
            update bankRec;        

            Test.startTest();
            BankReconciliation.complete(bankRec.Id);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();

            ServiceResult result = BankReconciliation.complete(bankRec.Id);

            System.assert(!result.isSuccess);
            System.assert(!result.errors.isEmpty());
            System.assertEquals(BankReconciliation.StatusCode.INVALID_STATUS_CHANGE.name(), result.errors[0].code);
            System.assertEquals(
                String.format(BankReconciliation.NO_STATUS_CHANGE, new String[] { BankReconciliation.COMPLETED }), 
                result.errors[0].detail
            );
        }
    }

    @IsTest
    static void testUndoComplete() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Cash_Receipt__c cr = testData.cashReceipts[2];
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.Beginning_Balance__c = 0;
            bankRec.Ending_Balance__c = 0;
            update bankRec;

            Test.startTest();
            BankReconciliation.complete(bankRec.Id);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();

            ServiceResult result = BankReconciliation.undoComplete(bankRec.Id);
            EventBusTestUtils.deliverAllEvents();

            System.assert(result.isSuccess);
            
            Bank_Reconciliation2__c bankRecResult = [
                SELECT GL_Ending_Balance__c, Status__c
                FROM Bank_Reconciliation2__c 
                WHERE Id = :bankRec.Id 
                LIMIT 1
            ];
            System.assertEquals(BankReconciliation.IN_PROGRESS, bankRecResult.Status__c);

            Integer ubrlCount = [
                SELECT COUNT() 
                FROM Uncleared_Bank_Reconciliation_Line__c 
                WHERE Bank_Reconciliation__c = :bankRec.Id
            ];
            System.assertEquals(0, ubrlCount);
        }
    }

    @IsTest
    static void testUndoCompleteAlreadyInProgress() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];       

            Test.startTest();
            ServiceResult result = BankReconciliation.undoComplete(bankRec.Id);
            Test.stopTest();

            System.assert(!result.isSuccess);
            System.assert(!result.errors.isEmpty());
            System.assertEquals(BankReconciliation.StatusCode.INVALID_STATUS_CHANGE.name(), result.errors[0].code);
            System.assertEquals(
                String.format(BankReconciliation.NO_STATUS_CHANGE, new String[] { BankReconciliation.IN_PROGRESS }), 
                result.errors[0].detail
            );
        }
    }

    @IsTest
    static void testCalculateUnclearedDepositsWithBDInFutureSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Deposit__c newBD = new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[2].Start_Date__c,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1'
            );

            insert newBD;

            List<Cash_Receipt__c> newCRList = new List<Cash_Receipt__c>();

            Cash_Receipt__c newCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 221,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(5),
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            newCRList.add(newCR);

            Cash_Receipt__c newCR2 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 229,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(5),
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            newCRList.add(newCR2);

            insert newCRList;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            newCR.Bank_Deposit__c = newBD.Id;
            newCR2.Bank_Deposit__c = newBD.Id;
            update newCRList;

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> postResults = postHandler.post(newCRList);
            System.assertEquals(true, postResults[0].isSuccess);

            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.Beginning_Balance__c = 0;
            bankRec.Ending_Balance__c = 0;
            update bankRec;

            ServiceResult sr1 = BankReconciliation.complete(testData.bankReconciliations[0].Id);

            ServiceResult sr = BankReconciliation.calculateUnclearedDepositsAndPayments(testData.bankReconciliations[0].Id);

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(testData.bankReconciliations[0].Id, false, true);

            Double crAmount = 0;

            Boolean isPastIncluded = false;
            Boolean isFutureIncluded = false;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crAmount += (Decimal)cr.get('Amount__c');
                        if ((Decimal)cr.get('Amount__c') == 221) {
                            isPastIncluded = true;
                        }
                        if ((Decimal)cr.get('Amount__c') == 229) {
                            isFutureIncluded = true;
                        }
                    }
                }
            }
            System.assertEquals(true, sr.isSuccess);
            System.assertEquals(crAmount, [SELECT Id, UnCleared_Deposits__c FROM Bank_Reconciliation2__c WHERE Id = :testData.bankReconciliations[0].Id].UnCleared_Deposits__c);
            System.assert(isPastIncluded);
            System.assert(!isFutureIncluded);
        }
    }

    @IsTest
    static void testCompleteWithBDInFuture() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Deposit__c newBD = new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[2].Start_Date__c,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1'
            );

            insert newBD;

            List<Cash_Receipt__c> newCRList = new List<Cash_Receipt__c>();

            Cash_Receipt__c newCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 221,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(5),
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            newCRList.add(newCR);

            Cash_Receipt__c newCR2 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 229,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(5),
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            newCRList.add(newCR2);

            insert newCRList;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            newCR.Bank_Deposit__c = newBD.Id;
            newCR2.Bank_Deposit__c = newBD.Id;
            update newCRList;

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> postResults = postHandler.post(newCRList);
            System.assertEquals(true, postResults[0].isSuccess);

            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.Beginning_Balance__c = 0;
            bankRec.Ending_Balance__c = 0;
            update bankRec;

            Test.startTest();
            ServiceResult sr = BankReconciliation.complete(testData.bankReconciliations[0].Id);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess);

            Bank_Reconciliation2__c bankRecResult = [
                SELECT GL_Ending_Balance__c, Status__c
                FROM Bank_Reconciliation2__c
                WHERE Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];
            System.assertEquals(BankReconciliation.COMPLETED, bankRecResult.Status__c);

            Integer ubrlCount = [
                SELECT COUNT()
                FROM Uncleared_Bank_Reconciliation_Line__c
                WHERE Bank_Reconciliation__c = :testData.bankReconciliations[0].Id
            ];
            System.assertEquals(2, ubrlCount);
        }
    }

    @IsTest
    static void testCompleteWithBankDisbInFuture() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createCashDisbursementBatches()
        .createCashDisbursements()
        .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Disbursement__c newBD = new Bank_Disbursement__c(
                Disbursement_Date__c = testData.acctPeriods[2].Start_Date__c,
                Bank_GL_Account__c = testData.glAccounts[0].Id,
                Disbursement_Reference__c = 'the reference 1'
            );

            Test.startTest();

            insert newBD;

            List<Cash_Disbursement__c> newCDList = new List<Cash_Disbursement__c>();

            Cash_Disbursement__c newCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Vendor__c = testData.accounts.get(0).Id,
                Amount__c = 221,
                Reference__c = '0000000001',
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(5),
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Debit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            newCDList.add(newCD);

            Cash_Disbursement__c newCD2 = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Vendor__c = testData.accounts.get(0).Id,
                Amount__c = 229,
                Reference__c = '0000000002',
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(5),
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Debit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            newCDList.add(newCD2);

            insert newCDList;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Disbursement__c.Bank_Disbursement__c,
                    Cash_Disbursement__c.Status__c
                }
            );
            newCD.Bank_Disbursement__c = newBD.Id;
            newCD2.Bank_Disbursement__c = newBD.Id;
            update newCDList;

            for( Cash_Disbursement__c cd: [SELECT Id, Bank_Disbursement__c FROM Cash_Disbursement__c WHERE Id IN :newCDList]){
                Assert.areEqual(newBD.Id, cd.Bank_Disbursement__c);
            }

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(newCDList);
            System.assertEquals(true, postResults[0].isSuccess);

            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.Beginning_Balance__c = 0;
            bankRec.Ending_Balance__c = 0;
            update bankRec;

            
            ServiceResult sr = BankReconciliation.complete(testData.bankReconciliations[0].Id);
            EventBusTestUtils.deliverAllEvents();
            Test.stopTest();

            System.assertEquals(true, sr.isSuccess);

            Bank_Reconciliation2__c bankRecResult = [
                SELECT GL_Ending_Balance__c, Status__c
                FROM Bank_Reconciliation2__c
                WHERE Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];
            System.assertEquals(BankReconciliation.COMPLETED, bankRecResult.Status__c);

            Integer ubrlCount = [
                SELECT COUNT()
                FROM Uncleared_Bank_Reconciliation_Line__c
                WHERE Bank_Reconciliation__c = :testData.bankReconciliations[0].Id
            ];
            System.assertEquals(1, ubrlCount);
        }
    }

    @IsTest
    static void testCalculateUnclearedDepositsAndPaymentsForNegCRSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {

             //insert negative CR and relate to Bank Deposit
             Cash_Receipt__c tempCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = -500,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods.get(1).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Bank_Deposit__c = testData.bankDeposits.get(0).Id);
        
            insert tempCR;

            Test.startTest();
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0];
            bankRec.End_Date__c = System.today().addDays(30);
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Bank_Reconciliation2__c.End_Date__c});
            update bankRec;

            ServiceResult sr = BankReconciliation.calculateUnclearedDepositsAndPayments(bankRec.Id);

            Test.stopTest();

            BankReconciliationModel retrieveResult = BankReconciliation.retrieve(bankRec.Id, false, true);

            Double crAmount = 0;

            for (SObject item : retrieveResult.items) {
                switch on item {
                    when Cash_Receipt__c cr {
                        crAmount += (Double)cr.get('Amount__c');
                    }
                }
            }
            System.assertEquals(true, sr.isSuccess);
            List<Bank_Reconciliation2__c> recs = [SELECT Id, UnCleared_Deposits__c, UnCleared_Payments__c FROM Bank_Reconciliation2__c WHERE Id = :bankRec.Id];
            System.assertEquals(1, recs.size());
            System.assertEquals(Math.abs(crAmount), recs[0].UnCleared_Payments__c);
            System.assertEquals(500, recs[0].UnCleared_Payments__c);
        }
    }

}