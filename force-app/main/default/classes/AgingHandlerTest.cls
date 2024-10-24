@IsTest
private class AgingHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    //========================AP tests============================
    @IsTest
    private static void testSetClosedAccountingPeriodSuccessAP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);
        Test.startTest();
        testData.createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            System.assertEquals(
                NULL,
                [SELECT Id, Closed_Accounting_Period__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Closed_Accounting_Period__c
            );

            Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements.get(5);
            testCashDisbursement.Status__c = 'Approved';
            testCashDisbursement.Amount__c = 200;
            update testCashDisbursement;

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCashDisbursement});

            System.assertEquals(
                true,
                cdPostResults.get(0).isSuccess
            );

            Accounting_Period__c period = testData.acctPeriods.get(3);

            AP_Disbursement__c newAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Cash_Disbursement__c = testCashDisbursement.Id,
                Paid_Amount__c = 165,
                Accounting_Period__c = period.Id
            );
            insert newAPD;

            System.assertEquals(
                0,
                [SELECT Balance__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id LIMIT 1].Balance__c
            );

            System.assertEquals(
                period.Id,
            [SELECT Id, Closed_Accounting_Period__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Closed_Accounting_Period__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testZeroBalanceSetClosedAccountingPeriodSuccessAP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);
        Test.startTest();
        testData.createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            System.assertEquals(
                NULL,
                [SELECT Id, Closed_Accounting_Period__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Closed_Accounting_Period__c
            );

            Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements.get(5);
            testCashDisbursement.Status__c = 'Approved';
            testCashDisbursement.Amount__c = 200;
            update testCashDisbursement;

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCashDisbursement});

            System.assertEquals(
                true,
                cdPostResults.get(0).isSuccess
            );

            Accounting_Period__c period = testData.acctPeriods.get(3);

            AP_Disbursement__c newAPD1 = new AP_Disbursement__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Cash_Disbursement__c = testCashDisbursement.Id,
                Paid_Amount__c = 160,
                Accounting_Period__c = period.Id
            );
            insert newAPD1;

            System.assertEquals(
                5,
                [SELECT Balance__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id LIMIT 1].Balance__c
            );

            System.assertEquals(
                NULL,
                [SELECT Id, Closed_Accounting_Period__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Closed_Accounting_Period__c
            );

            period = testData.acctPeriods.get(4);

            AP_Disbursement__c newAPD2 = new AP_Disbursement__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Cash_Disbursement__c = testCashDisbursement.Id,
                Paid_Amount__c = 5,
                Accounting_Period__c = period.Id
            );
            insert newAPD2;

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Closed_Accounting_Period__c
            );
        }
    }

    @IsTest
    private static void testUpdateSetClosedAccountingPeriodAP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            System.assertEquals(
                NULL, [
                    SELECT Id, Closed_Accounting_Period__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables.get(0).Id
                ].Closed_Accounting_Period__c
            );

            Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements.get(5);
            testCashDisbursement.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            testCashDisbursement.Amount__c = 200;
            update testCashDisbursement;

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCashDisbursement});
            System.assertEquals(true, cdPostResults.get(0).isSuccess);

            testData.payables.get(0).Closed_Accounting_Period__c = testData.acctPeriods.get(2).Id;
            update testData.payables.get(0);

            Accounting_Period__c period = testData.acctPeriods.get(3);

            AP_Disbursement__c newAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Cash_Disbursement__c = testCashDisbursement.Id,
                Paid_Amount__c = 165,
                Accounting_Period__c = period.Id
            );
            insert newAPD;

            System.assertEquals(
                0, [
                    SELECT Balance__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables.get(0).Id LIMIT 1
                ].Balance__c
            );

            System.assertEquals(
                period.Id, [
                    SELECT Id, Closed_Accounting_Period__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables.get(0).Id
                ].Closed_Accounting_Period__c
            );

            testData.payables.get(0).Closed_Accounting_Period__c = testData.acctPeriods.get(2).Id;
            update testData.payables.get(0);

            System.assertEquals(
                period.Id, [
                    SELECT Id, Closed_Accounting_Period__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables.get(0).Id
                ].Closed_Accounting_Period__c
            );
        }
    }

    //========================Billing tests=======================

    @IsTest
    private static void testSetClosedAccountingPeriodSuccessBilling() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users.get(1)) {
            System.assertEquals(
                NULL,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );
            Accounting_Period__c period = testData.acctPeriods.get(3);
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings.get(0).Id,
                Cash_Receipt__c = testData.cashReceipts.get(1).Id,
                Applied_Amount__c = 450,
                Accounting_Period__c = period.Id
            );
            insert bcr;

            System.assertEquals(
                0,
                [SELECT Balance__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id LIMIT 1].Balance__c
            );

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testCloseAccountingPeriodBillingAgingHistoryWhenNegativeAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create Billing
            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c.addDays(3),
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = testData.acctPeriods[0].Start_Date__c + 30
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 500,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //Post Billing
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            //Create Cash Receipt
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 500,
                Payment_Reference__c = '0000000432',
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id
            );
            insert testCR;

            //Apply the Cash Receipt with negative adjustment amount
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testBilling.Id,
                Cash_Receipt__c = testCR.Id,
                Applied_Amount__c = 300,
                Adjustment_Amount__c = -150,
                Adjustment_GL_Account__c = testData.glAccounts[21].Id,//4900-Customer Payment Discounts
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcr;

            //Close Accounting Period
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);
            Test.stopTest();

            //Validate Billing Aging History record
            List<Billing_Aging_History__c> billAgingHistories = [
                SELECT Id, Amount__c
                FROM Billing_Aging_History__c
                WHERE Billing__c = :testBilling.Id
            ];

            System.assertEquals(false, billAgingHistories.isEmpty());
            System.assertEquals(500 - 300 - (-150), billAgingHistories[0].Amount__c);
        }
    }

    @IsTest
    private static void testCloseAccountingPeriodAPAgingHistoryWhenDiscountCDVoided() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables(true)
                .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            AP_Disbursement__c apd = new AP_Disbursement__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                    Applied_Date__c = testData.acctPeriods[1].Start_Date__c+1,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Paid_Amount__c = [SELECT Id, Balance__c FROM Account_Payable__c WHERE Id =: testData.payables[0].Id].Balance__c // amount is 165
            );
            insert apd;

            //Close Accounting Periods 0,1,2
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            testData.acctPeriods.get(1).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(1);

            testData.acctPeriods.get(2).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(2);
            Test.stopTest();

            //Validate AP Aging History record
            List<AP_Aging_History__c> apAgingHistories = [
                    SELECT Id, Accounting_Period__r.Name, Amount__c
                    FROM AP_Aging_History__c
                    WHERE Account_Payable__c =: testData.payables[0].Id
                    ORDER BY Accounting_Period__r.Name ASC
            ];

            System.assertEquals(false, apAgingHistories.isEmpty());
            System.assertEquals(165, apAgingHistories[0].Amount__c);
        }
    }

    @IsTest
    private static void testZeroBalanceSetClosedAccountingPeriodSuccessBilling() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users.get(1)) {
            System.assertEquals(
                NULL,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );
            Accounting_Period__c period = testData.acctPeriods.get(3);
            Billing_Cash_Receipt__c bcr1 = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings.get(0).Id,
                Cash_Receipt__c = testData.cashReceipts.get(1).Id,
                Applied_Amount__c = 400,
                Accounting_Period__c = period.Id
            );
            insert bcr1;

            System.assertEquals(
                50,
                [SELECT Balance__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id LIMIT 1].Balance__c
            );

            System.assertEquals(
                NULL,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );
            period = testData.acctPeriods.get(4);

            Billing_Cash_Receipt__c bcr2 = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings.get(0).Id,
                Cash_Receipt__c = testData.cashReceipts.get(1).Id,
                Applied_Amount__c = 50,
                Accounting_Period__c = period.Id
            );
            insert bcr2;

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );
        }
    }

    @IsTest
    private static void testUpdateSetClosedAccountingPeriodBilling() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            System.assertEquals(
                NULL,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );

            testData.billings.get(0).Closed_Accounting_Period__c = testData.acctPeriods.get(2).Id;
            update testData.billings.get(0);

            Accounting_Period__c period = testData.acctPeriods.get(3);
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings.get(0).Id,
                Cash_Receipt__c = testData.cashReceipts.get(1).Id,
                Applied_Amount__c = 450,
                Accounting_Period__c = period.Id
            );
            insert bcr;

            System.assertEquals(
                0,
                [SELECT Balance__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id LIMIT 1].Balance__c
            );

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );

            testData.billings.get(0).Closed_Accounting_Period__c = testData.acctPeriods.get(2).Id;
            update testData.billings.get(0);

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :testData.billings.get(0).Id].Closed_Accounting_Period__c
            );
        }
    }
}