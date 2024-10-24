@IsTest
public with sharing class BillingsFromRecurringBillingsHelperTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringBillingIds = new Set<Id>{ testData.recurringBillings[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringBillingLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Billing_Line__c> lines = selector.selectLinesByHeaderId(recurringBillingIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            BillingsFromRecurringBillingsHelper helper = new BillingsFromRecurringBillingsHelper(lines, batchId, logger);
            helper.createSourceRecords();

            //varify logs
            Assert.areEqual(1, logger.getProcessedCount());
            Assert.areEqual(0, logger.getFailureCount());
            Assert.areEqual(1, logger.getSuccessCount());

            // verify the results
            List<Transaction_Group__c> txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Billing__c, Billing__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Transaction_Group__c txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Billing__c);
            Assert.isTrue(recurringBillingIds.contains(txnGroup.Recurring_Billing__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(lines.size(), txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_COMPLETED, txnGroup.Status__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupUpdated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringBillingIds = new Set<Id>{ testData.recurringBillings[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringBillingLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Billing_Line__c> lines = selector.selectLinesByHeaderId(recurringBillingIds);
            Assert.areEqual(2, lines.size());

            // create the source records for the first line
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            BillingsFromRecurringBillingsHelper helper = new BillingsFromRecurringBillingsHelper(new List<Recurring_Billing_Line__c>{lines[0]}, batchId, logger);
            helper.createSourceRecords();

            //varify aggregate result
            Assert.areEqual(1, logger.getProcessedCount());
            Assert.areEqual(0, logger.getFailureCount());
            Assert.areEqual(1, logger.getSuccessCount());

            // verify first run results
            List<Transaction_Group__c> txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Billing__c, Billing__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Transaction_Group__c txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Billing__c);
            Assert.isTrue(recurringBillingIds.contains(txnGroup.Recurring_Billing__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(1, txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_PROCESSING, txnGroup.Status__c);

            // create the source records for the second line
            helper = new BillingsFromRecurringBillingsHelper(new List<Recurring_Billing_Line__c>{lines[1]}, batchId, logger);
            helper.createSourceRecords();

            // verify second run results
            txnGroups = [SELECT Id, Batch_Id__c, Status__c, Recurring_Billing__c, Billing__c, Line_Count__c, Lines_Processed__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            txnGroup = txnGroups[0];
            Assert.areEqual(batchId, txnGroup.Batch_Id__c);
            Assert.isNotNull(txnGroup.Billing__c);
            Assert.isTrue(recurringBillingIds.contains(txnGroup.Recurring_Billing__c));
            Assert.areEqual(lines.size(), txnGroup.Line_Count__c);
            Assert.areEqual(lines.size(), txnGroup.Lines_Processed__c);
            Assert.areEqual(TransactionGroupActions.STATUS_COMPLETED, txnGroup.Status__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateSourceRecordsRecurringScheduleUpdated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringBillingIds = new Set<Id>{ testData.recurringBillings[0].Id };
            
            List<Recurring_Billing__c> recurBefore = [SELECT Next_Billing_Date__c FROM Recurring_Billing__c WHERE Id IN :recurringBillingIds];

            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringBillingLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Billing_Line__c> lines = selector.selectLinesByHeaderId(recurringBillingIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            BillingsFromRecurringBillingsHelper helper = new BillingsFromRecurringBillingsHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            List<Recurring_Billing__c> recurAfter = [SELECT Next_Billing_Date__c, Last_Billing_Date__c FROM Recurring_Billing__c WHERE Id IN :recurringBillingIds];
            Assert.areEqual(recurBefore[0].Next_Billing_Date__c.addMonths(1), recurAfter[0].Next_Billing_Date__c);
            Assert.areEqual(recurBefore[0].Next_Billing_Date__c, recurAfter[0].Last_Billing_Date__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateSourceRecordsBillingCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringBillingIds = new Set<Id>{ testData.recurringBillings[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringBillingLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Billing_Line__c> lines = selector.selectLinesByHeaderId(recurringBillingIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            BillingsFromRecurringBillingsHelper helper = new BillingsFromRecurringBillingsHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            // get the billing record
            List<Billing__c> billings = [
                SELECT 
                    Customer__c,
                    Ledger__c,
                    Line_Count__c,
                    Opportunity__c,
                    PO_Number__c,
                    Recurring_Billing__c,
                    Sales_Tax2__c,
                    Sales_Tax3__c,
                    Sub_Total__c,
                    Total__c
                FROM Billing__c 
                WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
            ];
            Assert.isNotNull(billings);
            Assert.areEqual(1, billings.size());
            Billing__c billing = billings[0];

            // get the recurring billing record
            Recurring_Billing__c recur = [
                SELECT 
                    Customer__c,
                    Ledger__c,
                    Line_Count__c,
                    Opportunity__c,
                    PO_Number__c,
                    Sales_Tax__c,
                    Sub_Total__c,
                    Total__c
                FROM Recurring_Billing__c 
                WHERE Id = :lines[0].Recurring_Billing__c
            ];
            
            Assert.areEqual(recur.Customer__c, billing.Customer__c);
            Assert.areEqual(recur.Ledger__c, billing.Ledger__c);
            Assert.areEqual(recur.Line_Count__c, billing.Line_Count__c);
            Assert.areEqual(recur.Opportunity__c, billing.Opportunity__c);
            Assert.areEqual(recur.PO_Number__c, billing.PO_Number__c);
            Assert.areEqual(recur.Sales_Tax__c, billing.Sales_Tax3__c);
            Assert.areEqual(recur.Sub_Total__c, billing.Sub_Total__c);
            Assert.areEqual(recur.Total__c, billing.Total__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateSourceRecordsBillingLinesCreated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringBillingIds = new Set<Id>{ testData.recurringBillings[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringBillingLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Billing_Line__c> lines = selector.selectLinesByHeaderId(recurringBillingIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            BillingsFromRecurringBillingsHelper helper = new BillingsFromRecurringBillingsHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            // get the recurring billing line records
            List<Recurring_Billing_Line__c> recurLines = [
                SELECT 
                    Id,
                    Combined_Tax_Rate__c,
                    Comment__c,
                    Discount_Amount__c,
                    Discount_Percent__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Ledger__c,
                    Line_Order__c,
                    List_Price__c,
                    Opportunity_Product_Id__c,
                    Product__c,
                    Project__c,
                    Project_Task__c,
                    Quantity__c,
                    Rate__c,
                    Recurring_Billing__c,
                    Revenue_GL_Account__c,
                    Sub_Total__c,
                    Tax_Amount__c,
                    Tax_Group__c,
                    Tax_Inclusive__c,
                    Tax_Rate__c,
                    Total__c
                FROM Recurring_Billing_Line__c 
                WHERE Recurring_Billing__c = :lines[0].Recurring_Billing__c
            ];
            Assert.isNotNull(recurLines);
            Assert.areEqual(2, recurLines.size());
            Map<Id, Recurring_Billing_Line__c> recurLinesMap = new Map<Id, Recurring_Billing_Line__c>(recurLines);

            // get the billing line records
            List<Billing_Line__c> billingLines = [
                SELECT 
                    Id,
                    Combined_Tax_Rate__c,
                    Comment__c,
                    Discount_Amt__c,
                    Discount_Pct__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Hours_Units__c,
                    Ledger__c,
                    List_Price__c,
                    Opportunity_Product_Id__c,
                    Product__c,
                    Project__c,
                    Project_Task__c,
                    Rate__c,
                    Recurring_Billing_Line__c,
                    Revenue_GL_Account__c,
                    Sub_Total__c,
                    Tax_Amount2__c,
                    Tax_Group__c,
                    Tax_Inclusive__c,
                    Tax_Rate__c,
                    Total__c 
                FROM Billing_Line__c 
                WHERE Recurring_Billing_Line__c = :recurLinesMap.keySet()
            ];
            Assert.isNotNull(recurLines);
            Assert.areEqual(2, recurLines.size());

            for (Billing_Line__c line : billingLines) {
                Recurring_Billing_Line__c recurLine = recurLinesMap.get(line.Recurring_Billing_Line__c);
                Assert.isNotNull(recurLine);
                Assert.areEqual(recurLine.Combined_Tax_Rate__c, line.Combined_Tax_Rate__c);
                Assert.areEqual(recurLine.Comment__c, line.Comment__c);
                Assert.areEqual(recurLine.Discount_Amount__c, line.Discount_Amt__c ?? 0);
                Assert.areEqual(recurLine.Discount_Percent__c, line.Discount_Pct__c ?? 0);
                Assert.areEqual(recurLine.GL_Account_Variable_1__c, line.GL_Account_Variable_1__c);
                Assert.areEqual(recurLine.GL_Account_Variable_2__c, line.GL_Account_Variable_2__c);
                Assert.areEqual(recurLine.GL_Account_Variable_3__c, line.GL_Account_Variable_3__c);
                Assert.areEqual(recurLine.GL_Account_Variable_4__c, line.GL_Account_Variable_4__c);
                Assert.areEqual(recurLine.Ledger__c, line.Ledger__c);
                Assert.areEqual(recurLine.List_Price__c, line.List_Price__c);
                Assert.areEqual(recurLine.Opportunity_Product_Id__c, line.Opportunity_Product_Id__c);
                Assert.areEqual(recurLine.Product__c, line.Product__c);
                Assert.areEqual(recurLine.Project__c, line.Project__c);
                Assert.areEqual(recurLine.Project_Task__c, line.Project_Task__c);
                Assert.areEqual(recurLine.Quantity__c, line.Hours_Units__c);
                Assert.areEqual(recurLine.Rate__c, line.Rate__c);
                Assert.areEqual(recurLine.Revenue_GL_Account__c, line.Revenue_GL_Account__c);
                Assert.areEqual(recurLine.Sub_Total__c, line.Sub_Total__c);
                Assert.areEqual(recurLine.Tax_Amount__c, line.Tax_Amount2__c);
                Assert.areEqual(recurLine.Tax_Group__c, line.Tax_Group__c);
                Assert.areEqual(recurLine.Tax_Inclusive__c, line.Tax_Inclusive__c);
                Assert.areEqual(recurLine.Tax_Rate__c, line.Tax_Rate__c);
                Assert.areEqual(recurLine.Total__c, line.Total__c);
            }
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateSourceRecordsTransactionGroupFailed() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // force error
            delete [SELECT Id FROM Accounting_Period__c];

            // get the lines to process
            Set<Id> recurringBillingIds = new Set<Id>{ testData.recurringBillings[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringBillingLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Billing_Line__c> lines = selector.selectLinesByHeaderId(recurringBillingIds);

            // create the source records
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            BillingsFromRecurringBillingsHelper helper = new BillingsFromRecurringBillingsHelper(lines, batchId, logger);
            helper.createSourceRecords();

            // verify the results
            List<Transaction_Group__c> txnGroups = [SELECT Status__c FROM Transaction_Group__c];
            Assert.isNotNull(txnGroups);
            Assert.areEqual(1, txnGroups.size());
            Assert.areEqual(TransactionGroupActions.STATUS_FAILED, txnGroups[0].Status__c);
            Test.stopTest();
        }
        
    }

    @IsTest
    public static void testCreateSourceRecordsNoDuplicateBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // get the lines to process
            Set<Id> recurringBillingIds = new Set<Id>{ testData.recurringBillings[0].Id };
            // using the selector will ensure we have selected all the fields the helper needs
            RecurringLineSelector selector = new RecurringBillingLineSelector(System.AccessLevel.SYSTEM_MODE, SObjectSelector.SharingMode.WITHOUT_SHARING);
            List<Recurring_Billing_Line__c> lines = selector.selectLinesByHeaderId(recurringBillingIds);
            Assert.areEqual(2, lines.size());

            // create the source records for the first line
            AJRLogger logger = AJRLoggerTest.getTestLogger();
            String batchId = 'batch_id_123';
            BillingsFromRecurringBillingsHelper helper = new BillingsFromRecurringBillingsHelper(new List<Recurring_Billing_Line__c>{lines[0]}, batchId, logger);
            helper.createSourceRecords();

            // verify first run results
            Integer txnGroupCnt = [SELECT COUNT() FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroupCnt);

            Integer billingCnt = [SELECT COUNT() FROM Billing__c];
            Assert.areEqual(1, billingCnt);

            Integer lineCnt = [SELECT COUNT() FROM Billing_Line__c];
            Assert.areEqual(1, lineCnt);

            // create the source records for the second line
            helper = new BillingsFromRecurringBillingsHelper(new List<Recurring_Billing_Line__c>{lines[1]}, batchId, logger);
            helper.createSourceRecords();

            // verify second run results
            txnGroupCnt = [SELECT COUNT() FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroupCnt);

            billingCnt = [SELECT COUNT() FROM Billing__c];
            Assert.areEqual(1, billingCnt);

            lineCnt = [SELECT COUNT() FROM Billing_Line__c];
            Assert.areEqual(2, lineCnt);
            Test.stopTest();
        }
    }
}