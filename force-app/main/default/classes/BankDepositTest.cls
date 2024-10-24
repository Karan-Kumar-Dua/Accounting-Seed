@IsTest
private class BankDepositTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testNoDataProvidedNullInputError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            BankDepositModel dto = new BankDepositModel();

            Bank_Deposit__c bankDep = testData.bankDeposits[0];

            dto.record = bankDep;
            
            Test.startTest();
            ServiceResult result = BankDeposit.associate(NULL,NULL);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals('NO_INPUT_DATA', result.errors[0].code);
        }
    }

    @IsTest
    static void testBankDepositWith1GlavMatchingToCRAssociates() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createBankDeposits();
        System.runAs(testData.users.get(1)) {

            Accounting_Variable__c av1 = [SELECT Id FROM Accounting_Variable__c WHERE Type__c = 'GL Account Variable 1' LIMIT 1];

            Bank_Deposit__c bd = testData.bankDeposits[0];
            bd.GL_Account_Variable_1__c = av1.Id;

            Cash_Receipt__c cr = new Cash_Receipt__c(
                GL_Account_Variable_1__c = av1.Id,
                GL_Account_Variable_2__c = [SELECT Id FROM Accounting_Variable__c WHERE Type__c = 'GL Account Variable 2' LIMIT 1].Id
            );

            Test.startTest();
            ServiceResult result = BankDeposit.associate(bd.Id,new List<Id>{cr.Id});
            Test.stopTest();

            System.assertEquals(true, result.isSuccess);
        }
    }
    
    @IsTest
    static void testNoDataProvidedNullArgsError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult result = BankDeposit.associate(NULL,NULL);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(BankDeposit.StatusCode.NO_INPUT_DATA.name(), result.errors[0].code);
        }
    }
    
    @IsTest
    static void testNoBankDepositItemsError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {

            Id bankDepostId = testData.bankDeposits[0].Id;

            Test.startTest();
            ServiceResult result = BankDeposit.associate(bankDepostId, NULL);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(BankDeposit.StatusCode.NO_BANK_DEPOSIT_ITEMS.name(), result.errors[0].code);
        }
    }

    @IsTest
    static void testBankDepositItemsOverLimitError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            List<Id> itemIds = new List<Id>();
            Id bankDepositId = testData.bankDeposits[0].Id;

            Test.startTest();
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();

            for (Integer i=0; i<195; i++) {
                cashReceipts.add(testData.cashReceipts[0].clone(false,true));
            }

            insert cashReceipts;

            for (Cash_Receipt__c cr : cashReceipts) {
                itemIds.add(cr.Id);
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            ServiceResult result = BankDeposit.associate(bankDepositId, itemIds);
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(BankDeposit.StatusCode.OVER_BANK_DEPOSIT_ITEM_LIMIT.name(), result.errors[0].code);
        }
    }
    
    @IsTest
    static void testInvalidBankDepositItemAssociateRecordTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            Id bankDepositId = testData.bankDeposits[0].Id;

            Test.startTest();
            ServiceResult result = BankDeposit.associate(bankDepositId, new Id[]{testData.projects[0].Id});
            Test.stopTest();

            System.assertEquals(false, result.results[0].isSuccess);
            System.assertEquals(BankDeposit.StatusCode.INVALID_RECORD_OR_ID.name(), result.results[0].errors[0].code);
        }
    }
    
    @IsTest
    static void testInvalidAssociateRecordCriteriaError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(false);

        System.runAs(testData.users.get(1)) {
            List<Id> itemIds = new List<Id>();
            Id bankDepositId = testData.bankDeposits[0].Id;

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            Test.startTest();
            ServiceResult result = BankDeposit.associate(bankDepositId, itemIds);
            Test.stopTest();

            System.assertEquals(false, result.results[0].isSuccess);
            System.assertEquals(BankDeposit.StatusCode.INVALID_ASSOCIATION_RECORD.name(), result.results[0].errors[0].code);
        }
    }
    
    @IsTest
    static void testAssociateRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            List<Id> itemIds = new List<Id>();
            Bank_Deposit__c testBD = testData.bankDeposits[0];
            testBD.Deposit_Date__c = Date.today();
            update testBD;

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            Test.startTest();
            ServiceResult result = BankDeposit.associate(testBD.Id, itemIds);
            Test.stopTest();

            System.assertEquals(true, result.isSuccess);
        }
    }

    @IsTest
    static void testInvalidBankDepositItemUnassociateRecordTypeError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            List<Id> itemIds = new List<Id>();
            Id bankDepositId = testData.bankDeposits[0].Id;

            itemIds.add(testData.projects[0].Id);

            Test.startTest();
            ServiceResult result = BankDeposit.unassociate(bankDepositId, itemIds);
            Test.stopTest();

            System.assertEquals(false, result.results[0].isSuccess);
            System.assertEquals(BankDeposit.StatusCode.INVALID_RECORD_OR_ID.name(), result.results[0].errors[0].code);
        }
    }
    
    @IsTest
    static void testInvalidUnassociateRecordCriteriaError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(false);

        System.runAs(testData.users.get(1)) {
            List<Id> itemIds = new List<Id>();
            Id bankDepositId = testData.bankDeposits[0].Id;

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            Test.startTest();
            ServiceResult result = BankDeposit.unassociate(bankDepositId, itemIds);
            Test.stopTest();

            System.assertEquals(false, result.results[0].isSuccess);
            System.assertEquals(BankDeposit.StatusCode.INVALID_UNASSOCIATION_RECORD.name(), result.results[0].errors[0].code);
        }
    }
    
    @IsTest
    static void testUnassociateRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            List<Id> itemIds = new List<Id>();
            Bank_Deposit__c testBD = testData.bankDeposits[0];
            testBD.Deposit_Date__c = Date.today();
            update testBD;

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            Test.startTest();
            ServiceResult result = BankDeposit.associate(testBD.Id, itemIds);
            System.assertEquals(true, result.isSuccess);

            result = BankDeposit.unassociate(testBD.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(0, [SELECT Id, Amount__c FROM Bank_Deposit__c WHERE Id = :testBD.Id].Amount__c);
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testRetrieveRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            List<Id> itemIds = new List<Id>();
            Id bankDepositId = testData.bankDeposits[0].Id;
            Bank_Deposit__c testBD = testData.bankDeposits[0];
            testBD.Deposit_Date__c = Date.today();
            update testBD;

            for (Cash_Receipt__c cr : testData.cashReceipts) {
                itemIds.add(cr.Id);
            }

            for (Journal_Entry_Line__c jeLine : testData.journalEntryLines) {
                itemIds.add(jeLine.Id);
            }

            Test.startTest();
            ServiceResult result = BankDeposit.associate(testBD.Id, itemIds);
            System.assertEquals(true, result.isSuccess);
            //Test retrieve method
            BankDepositModel resultBankModel = BankDeposit.retrieve(testBD.Id);

            Integer recCount = 0;
            Map<Id, Cash_Receipt__c> cashReceiptMap = new Map<Id, Cash_Receipt__c>(testData.cashReceipts);
            Map<Id, Journal_Entry_Line__c> journalEntryLinesMap = new Map<Id, Journal_Entry_Line__c>(testData.journalEntryLines);

            for (SObject obj : resultBankModel.items) {
                switch on obj {
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

            System.assertEquals(recCount, resultBankModel.items.size());
        }
    }
    @IsTest
    static void testNoBankDepositItemsErrorWhenAVoidCrAssociated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits()
            .createCashFlowCategories(false);

        System.runAs(testData.users.get(1)) {
            Id bankDepostId = testData.bankDeposits[0].Id;

            Test.startTest();
            Cash_Receipt__c cReceipt = testData.cashReceipts[0];
            cReceipt.Status__c = 'Posted';
            cReceipt.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Status__c,
                    Cash_Receipt__c.Cash_Flow_Category__c,
                    Cash_Receipt__c.Payment_Processor__c
                }
            );
            update cReceipt;     
            
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date();
            testAccountingPeriod.End_Date__c = System.now().date();
            
            UPDATE testAccountingPeriod;

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = cReceipt.Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.cashFlowCategory = testData.cashFlowCategories[0].Id;
            voidData.paymentId = cReceipt.Payment_Reference__c;

            List<Transaction__c> controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :cReceipt.Id
            ];

            new CashReceiptVoid().voidCashReceipt(voidData);
            //make sure the cash receipt is voided
            Assert.isTrue([SELECT Void__c FROM Cash_Receipt__c WHERE Id = :cReceipt.Id].Void__c);

            ServiceResult result = BankDeposit.associate(bankDepostId, new List<Id> {cReceipt.Id});
            Test.stopTest();

            Assert.areEqual(false, result.results[0].isSuccess);
            Assert.areEqual(BankDeposit.StatusCode.INVALID_ASSOCIATION_RECORD.name(), result.results[0].errors[0].code);
            Assert.areEqual(BankDeposit.INVALID_ASSOCIATION_RECORD, result.results[0].errors[0].detail);
        }
    }
}