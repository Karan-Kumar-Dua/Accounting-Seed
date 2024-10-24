@IsTest
public with sharing class PayableFromRecurPayableHelperTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringPayableIds = new Set<Id>{ testData.recurringPayables[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringAccountPayableLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Account_Payable_Line__c> lines = selector.selectLinesByHeaderId(recurringPayableIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            AccountPayableFromRecrAccPayableHelper helper = new AccountPayableFromRecrAccPayableHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            List<Transaction_Group__c> txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Account_Payable__c, Account_Payable__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Transaction_Group__c txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Account_Payable__c);
            Assert.isTrue(recurringPayableIds.contains(txnGroup.Recurring_Account_Payable__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(lines.size(), txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_COMPLETED, txnGroup.Status__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupUpdated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringPayableIds = new Set<Id>{ testData.recurringPayables[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringAccountPayableLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Account_Payable_Line__c> lines = selector.selectLinesByHeaderId(recurringPayableIds);
            Assert.areEqual(2, lines.size());

            // create the source records for the first line
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            AccountPayableFromRecrAccPayableHelper helper = new AccountPayableFromRecrAccPayableHelper(new List<Recurring_Account_Payable_Line__c>{lines[0]}, batchId, logger);
            helper.createSourceRecords();

            // verify first run results
            List<Transaction_Group__c> txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Account_Payable__c, Account_Payable__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Transaction_Group__c txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Account_Payable__c);
            Assert.isTrue(recurringPayableIds.contains(txnGroup.Recurring_Account_Payable__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(1, txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_PROCESSING, txnGroup.Status__c);

            // create the source records for the second line
            helper = new AccountPayableFromRecrAccPayableHelper(new List<Recurring_Account_Payable_Line__c>{lines[1]}, batchId, logger);
            helper.createSourceRecords();

            // verify second run results
            txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Account_Payable__c, Account_Payable__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Account_Payable__c);
            Assert.isTrue(recurringPayableIds.contains(txnGroup.Recurring_Account_Payable__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(lines.size(), txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_COMPLETED, txnGroup.Status__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsRecurringScheduleUpdated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringPayableIds = new Set<Id>{ testData.recurringPayables[0].Id };
            
            List<Recurring_Account_Payable__c> recurBefore = [SELECT Next_Account_Payable_Date__c FROM Recurring_Account_Payable__c WHERE Id IN :recurringPayableIds];

            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringAccountPayableLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Account_Payable_Line__c> lines = selector.selectLinesByHeaderId(recurringPayableIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            AccountPayableFromRecrAccPayableHelper helper = new AccountPayableFromRecrAccPayableHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            List<Recurring_Account_Payable__c> recurAfter = [SELECT Next_Account_Payable_Date__c, Last_Account_Payable_Date__c FROM Recurring_Account_Payable__c WHERE Id IN :recurringPayableIds];
            Assert.areEqual(recurBefore[0].Next_Account_Payable_Date__c.addMonths(1), recurAfter[0].Next_Account_Payable_Date__c);
            Assert.areEqual(recurBefore[0].Next_Account_Payable_Date__c, recurAfter[0].Last_Account_Payable_Date__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsPayableCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringPayableIds = new Set<Id>{ testData.recurringPayables[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringAccountPayableLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Account_Payable_Line__c> lines = selector.selectLinesByHeaderId(recurringPayableIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            AccountPayableFromRecrAccPayableHelper helper = new AccountPayableFromRecrAccPayableHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            // get the Account Payable record
            List<Account_Payable__c> payables = [
                SELECT 
                    Date__c,
                    Payee_Reference__c,
                    Vendor__c,
                    Contact__c,
                    Employee__c,
                    Recurring_Account_Payable__c,
                    Ledger__c
                FROM Account_Payable__c 
                WHERE Recurring_Account_Payable__c = :testData.recurringpayables[0].Id
            ];
            Assert.isNotNull(payables);
            Assert.areEqual(1, payables.size());
            Account_Payable__c payable = payables[0];

            // get the recurring account payable record
            Recurring_Account_Payable__c recur = [
                SELECT 
                    Next_Account_Payable_Date__c,
                    Name,
                    Id,
                    Contact__c,
                    Vendor__c,
                    Employee__c,
                    Ledger__c
                FROM Recurring_Account_Payable__c 
                WHERE Id = :lines[0].Recurring_Account_Payable__c
            ];
            
            Assert.areEqual(recur.Ledger__c, payable.Ledger__c);
            Assert.areEqual(recur.Vendor__c, payable.Vendor__c);
            Assert.areEqual(recur.Contact__c, payable.Contact__c);
            Assert.areEqual(recur.Employee__c, payable.Employee__c);
            Assert.areEqual(recur.Id, payable.Recurring_Account_Payable__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsPayableLinesCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
             .createRecurringAccountPayables()
             .createRecurringAccountPayableLines();


        System.runAs(testData.users[1]) {
            // get the lines to process
            Set<Id> recurringPayableIds = new Set<Id>{ testData.recurringPayables[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringAccountPayableLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Account_Payable_Line__c> lines = selector.selectLinesByHeaderId(recurringPayableIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            AccountPayableFromRecrAccPayableHelper helper = new AccountPayableFromRecrAccPayableHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            // get the recurring Payable Line line records
            List<Recurring_Account_Payable_Line__c> recurLines = [
                SELECT 
                    Id,
                    Expense_GL_Account__c,
                    Quantity__c,
                    Project__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Ledger__c,
                    Project_Task__c,
                    Tax_Group__c,
                    Tax_Amount__c,
                    Unit_Cost__c,
                    Internal_Comment__c
                FROM Recurring_Account_Payable_Line__c 
                WHERE Recurring_Account_Payable__c = :lines[0].Recurring_Account_Payable__c
            ];
            Assert.isNotNull(recurLines);
            Assert.areEqual(2, recurLines.size());
            Map<Id, Recurring_Account_Payable_Line__c> recurLinesMap = new Map<Id, Recurring_Account_Payable_Line__c>(recurLines);

            // get the billing line records
            List<Account_Payable_Line__c> billingLines = [
                SELECT 
                    Id,
                    Recurring_Account_Payable_Line__c,
                    Expense_GL_Account__c,
                    Quantity__c,
                    Date__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Project__c,
                    Project_Task__c,
                    Tax_Group__c,
                    Tax_Amount__c,
                    Unit_Cost__c,
                    Internal_Comment__c
                FROM Account_Payable_Line__c 
                WHERE Recurring_Account_Payable_Line__c = :recurLinesMap.keySet()
            ];
            Assert.isNotNull(recurLines);
            Assert.areEqual(2, recurLines.size());

            for (Account_Payable_Line__c line : billingLines) {
                Recurring_Account_Payable_Line__c recurLine = recurLinesMap.get(line.Recurring_Account_Payable_Line__c);
                Assert.isNotNull(recurLine);
                Assert.areEqual(recurLine.Expense_GL_Account__c, line.Expense_GL_Account__c);
                Assert.areEqual(recurLine.GL_Account_Variable_1__c, line.GL_Account_Variable_1__c);
                Assert.areEqual(recurLine.GL_Account_Variable_2__c, line.GL_Account_Variable_2__c);
                Assert.areEqual(recurLine.GL_Account_Variable_3__c, line.GL_Account_Variable_3__c);
                Assert.areEqual(recurLine.GL_Account_Variable_4__c, line.GL_Account_Variable_4__c);
                Assert.areEqual(recurLine.Project__c, line.Project__c);
                Assert.areEqual(recurLine.Project_Task__c, line.Project_Task__c);
                Assert.areEqual(recurLine.Tax_Group__c, line.Tax_Group__c);
                Assert.areEqual(recurLine.Unit_Cost__c, line.Unit_Cost__c);
                Assert.areEqual(recurLine.Tax_Amount__c, line.Tax_Amount__c);
                Assert.areEqual(recurLine.Internal_Comment__c, line.Internal_Comment__c);
                Assert.areEqual(recurLine.Quantity__c, line.Quantity__c);
                Assert.areEqual(testData.recurringPayables[0].Next_Account_Payable_Date__c, line.Date__c);
            }
        }
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupFailed() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            // force error
            delete [SELECT Id FROM Accounting_Period__c];

            // get the lines to process
            Set<Id> recurringPayableIds = new Set<Id>{ testData.recurringPayables[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringAccountPayableLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Account_Payable_Line__c> lines = selector.selectLinesByHeaderId(recurringPayableIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            AccountPayableFromRecrAccPayableHelper helper = new AccountPayableFromRecrAccPayableHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            List<Transaction_Group__c> txnGroups = [SELECT Status__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Assert.areEqual(TransactionGroupActions.STATUS_FAILED, txnGroups[0].Status__c);
        }
    }

    @IsTest
    public static void testCreateSourceRecordsNoDuplicateBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringPayableIds = new Set<Id>{ testData.recurringPayables[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringAccountPayableLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Account_Payable_Line__c> lines = selector.selectLinesByHeaderId(recurringPayableIds);
            Assert.areEqual(2, lines.size());

            // create the source records for the first line
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            AccountPayableFromRecrAccPayableHelper helper = new AccountPayableFromRecrAccPayableHelper(new List<Recurring_Account_Payable_Line__c>{lines[0]}, batchId, logger);
            helper.createSourceRecords();

            // verify first run results
            Integer txnGroupCnt = [SELECT COUNT() FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroupCnt);

            Integer payablesCnt = [SELECT COUNT() FROM Account_Payable__c];
            Assert.areEqual(1, payablesCnt);

            Integer lineCnt = [SELECT COUNT() FROM Account_Payable_Line__c];
            Assert.areEqual(1, lineCnt);

            // create the source records for the second line
            helper = new AccountPayableFromRecrAccPayableHelper(new List<Recurring_Account_Payable_Line__c>{lines[1]}, batchId, logger);
            helper.createSourceRecords();

            // verify second run results
            txnGroupCnt = [SELECT COUNT() FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroupCnt);

            payablesCnt = [SELECT COUNT() FROM Account_Payable__c];
            Assert.areEqual(1, payablesCnt);

            lineCnt = [SELECT COUNT() FROM Account_Payable_Line__c];
            Assert.areEqual(2, lineCnt);
            Test.stopTest();
        }
    }

}