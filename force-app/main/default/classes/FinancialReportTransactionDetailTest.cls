@IsTest
private class FinancialReportTransactionDetailTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testPageLoad() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            GL_Account__c testGlAccount = testData.glAccounts[0];
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[1];

            PageReference testPage = Page.FinancialReportTransactionDetail;
            Test.setCurrentPage(testPage);
            ApexPages.currentPage().getParameters().put('glAccountId', (String)testGlAccount.Id);
            ApexPages.currentPage().getParameters().put('acctPeriodId', (String)testAccountingPeriod.Id);
            ApexPages.currentPage().getParameters().put('ledgerId', (String) testData.ledgers[0].Id);

            Test.startTest();
            FinancialReportTransactionDetail controller = new FinancialReportTransactionDetail();

            System.assertEquals(900, controller.theTransaction.Amount__c);

            List<FinancialReportTransactionDetail.TransactionWrapper> resultList = FinancialReportTransactionDetail.getTransactions(
                (String)testGlAccount.Id,
                (String)testAccountingPeriod.Id,
                (String) testData.ledgers[0].Id,
                '', '', '', '',
                false
            );

            System.assertEquals(2, resultList.size());
        }

    }

    @IsTest
    private static void testPageLoadWithoutGLAVsFilter() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];

            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<SObject>{testBilling});

            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testBilling.Id]);

            GL_Account__c testGlAccount = testData.glAccounts[10];
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];

            PageReference testPage = Page.FinancialReportTransactionDetail;
            Test.setCurrentPage(testPage);
            ApexPages.currentPage().getParameters().put('glAccountId', (String) testGlAccount.Id);
            ApexPages.currentPage().getParameters().put('acctPeriodId', (String) testAccountingPeriod.Id);
            ApexPages.currentPage().getParameters().put('ledgerId', (String) testData.ledgers[0].Id);

            FinancialReportTransactionDetail controller = new FinancialReportTransactionDetail();
            //Expected (-200) + (-250) here
            System.assertEquals(-450, controller.theTransaction.Amount__c);
        }

    }

    @IsTest
    private static void testPageLoadWithGLAVsFilter() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createAccountingVariables()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];

            testData.billingLines[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            update testData.billingLines[0];

            AbstractPostHandler postHandler = new BillingPostHandler();
            postHandler.post(new List<SObject>{testBilling});

            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testBilling.Id]);

            GL_Account__c testGlAccount = testData.glAccounts[10];
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];

            PageReference testPage = Page.FinancialReportTransactionDetail;
            Test.setCurrentPage(testPage);
            ApexPages.currentPage().getParameters().put('glAccountId', (String) testGlAccount.Id);
            ApexPages.currentPage().getParameters().put('acctPeriodId', (String) testAccountingPeriod.Id);
            ApexPages.currentPage().getParameters().put('ledgerId', (String) testData.ledgers[0].Id);
            ApexPages.currentPage().getParameters().put('glav1', (String) testData.accountingVariables1[0].Id);

            FinancialReportTransactionDetail controller = new FinancialReportTransactionDetail();
            //Total amount here is -450, but filtered result should be -200
            System.assertEquals(-200, controller.theTransaction.Amount__c);
        }

    }

    @IsTest
    private static void testPageWithAPDisbursementSource() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            GL_Account__c testGlAccount = testData.glAccounts[23];
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];

            AP_Disbursement__c testAPDisb = testData.apDisbursements[3];
            AbstractPostHandler postHandler = new APDisbursementPostHandler();
            postHandler.post(new List<SObject>{testAPDisb});
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE AP_Disbursement__r.ID = :testAPDisb.Id]);


            PageReference testPage = Page.FinancialReportTransactionDetail;
            Test.setCurrentPage(testPage);
            ApexPages.currentPage().getParameters().put('glAccountId', (String) testGlAccount.Id);
            ApexPages.currentPage().getParameters().put('acctPeriodId', (String) testAccountingPeriod.Id);
            ApexPages.currentPage().getParameters().put('ledgerId', (String) testData.ledgers[0].Id);

            FinancialReportTransactionDetail controller = new FinancialReportTransactionDetail();
            System.assertEquals(-145, controller.theTransaction.Amount__c);
        }
    }

}