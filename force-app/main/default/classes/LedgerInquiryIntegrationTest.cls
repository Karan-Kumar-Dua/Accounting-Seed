@IsTest
private with sharing class LedgerInquiryIntegrationTest {
    
    @TestSetup
    private static void createTestData() {
        //products are getting created as part of creating ledgers now, so removing the call to createProducts()
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .disableAutoPostSourceDocuments()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            // add second bank gl account
            GL_Account__c bank2 = testData.glAccounts[0].clone(false, true, false, false);
            bank2.Name = '1010-Cash';
            insert bank2;
            testData.glAccounts.add(bank2);

            // Update + Post CRs
            testData.cashReceipts[0].Project__c = testData.projects[0].Id;
            testData.cashReceipts[0].Project_Task__c = testData.projectTasks[0].Id;
            testData.cashReceipts[0].Receipt_Date__c = testData.acctPeriods[0].Start_Date__c;
            testData.cashReceipts[0].Accounting_Period__c = testData.acctPeriods[0].Id;

            testData.cashReceipts[1].Product__c = testData.products[0].Id;
            testData.cashReceipts[1].Receipt_Date__c = testData.acctPeriods[0].Start_Date__c;
            testData.cashReceipts[1].Accounting_Period__c = testData.acctPeriods[0].Id;

            testData.cashReceipts[2].Bank_Account__c = bank2.Id;

            List<Cash_Receipt__c> crs = new List<Cash_Receipt__c>{
                testData.cashReceipts[0],
                testData.cashReceipts[1],
                testData.cashReceipts[2]
            };
            update crs;

            AbstractPostHandler postHandler = new CashReceiptPostHandler();
            List<PostResult> postResults = postHandler.post(crs);
            System.assertEquals(true, postResults[0].isSuccess, 'Test setup failed. CRs failed to post.');

            // Update + Post CDs
            testData.cashDisbursements[0].Vendor__c = testData.accounts[2].Id;
            testData.cashDisbursements[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;

            testData.cashDisbursements[1].Disbursement_Date__c = testData.acctPeriods[5].Start_Date__c;
            testData.cashDisbursements[1].Accounting_Period__c = testData.acctPeriods[5].Id;

            testData.cashDisbursements[2].Ledger__c = testData.ledgers[2].Id;

            List<Cash_Disbursement__c> cds = new List<Cash_Disbursement__c>{
                testData.cashDisbursements[0],
                testData.cashDisbursements[1],
                testData.cashDisbursements[2]
            };
            update cds;

            postHandler = new CashDisbursementPostHandler();
            postResults = postHandler.post(cds);
            System.assertEquals(true, postResults[0].isSuccess, 'Test setup failed. CDs failed to post.');
        }   
    }

    @IsTest
    private static void testLedgerInquiryByLedger() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id ledgerUsed = testData.ledgers[2].Id;

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.ledger = ledgerUsed;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [ 
                SELECT Id, Amount__c
                FROM Transaction__c 
                WHERE Ledger__c = :ledgerUsed
            ];
            
            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryByGLAccount() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id glAccountUsed = testData.glAccounts[testData.glAccounts.size() - 1].Id;

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.glAccount = glAccountUsed;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [ 
                SELECT Id 
                FROM Transaction__c 
                WHERE GL_Account__c = :glAccountUsed
            ];

            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryByAccountingPeriod() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id periodUsed = testData.acctPeriods[0].Id;

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.startingAccountingPeriod = periodUsed;
            options.endingAccountingPeriod = periodUsed;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [ 
                SELECT Id 
                FROM Transaction__c 
                WHERE Accounting_Period__c = :periodUsed
                AND Ledger__c = :testData.ledgers[0].Id
            ];

            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryByProduct() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id productUsed = [SELECT Id FROM Product2 WHERE Name = 'Test Prod 1' LIMIT 1].Id;

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.product = productUsed;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [
                SELECT Id
                FROM Transaction__c
                WHERE Product__c = :productUsed
            ];

            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryByProject() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id projectUsed = [SELECT Id FROM Project__c WHERE Name = 'Test Project'].Id;
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.project = projectUsed;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [ 
                SELECT Id 
                FROM Transaction__c 
                WHERE Project__c = :projectUsed
            ];

            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryByAccount() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id accountUsed = testData.accounts[2].Id;

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.account = accountUsed;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [ 
                SELECT Id 
                FROM Transaction__c 
                WHERE Account__c = :accountUsed
            ];

            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryBySource() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.source = new String[]{'cr'};
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [ 
                SELECT Id 
                FROM Transaction__c 
                WHERE Cash_Receipt__c <> NULL
            ];

            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryByGLAV() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id glavUsed = [ SELECT Id FROM Accounting_Variable__c WHERE Name = 'Sales' AND Type__c = 'GL Account Variable 1'].Id;

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.glVariable1 = glavUsed;
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);

            List<Transaction__c> txs = [ 
                SELECT Id 
                FROM Transaction__c 
                WHERE GL_Account_Variable_1__c = :glavUsed
            ];

            System.assertNotEquals(0, response.recordCount);
            System.assertEquals(txs.size(), response.recordCount);
        }
    }

    @IsTest
    private static void testLedgerInquiryAggregated() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Id glavUsed = [ SELECT Id FROM Accounting_Variable__c WHERE Name = 'Sales' AND Type__c = 'GL Account Variable 1'].Id;

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.aggregatedBy = 'glav1';
            LedgerInquiryFinancialReport.LedgerInquiryResponse response = LedgerInquiryFinancialReport.runReport(options);
            Test.stopTest();

            FinancialReportTransactionDetail.TransactionWrapper aggregatedLine;
            for (FinancialReportTransactionDetail.TransactionWrapper line : response.lines) {
                if (line.glav1 <> null && line.glav1.id == glavUsed) {
                    aggregatedLine = line;
                    break;
                }
            }
            System.assertNotEquals(null, aggregatedLine);
        }
    }

}