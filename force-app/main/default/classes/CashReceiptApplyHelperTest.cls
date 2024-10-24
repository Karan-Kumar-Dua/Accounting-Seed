@IsTest
public with sharing class CashReceiptApplyHelperTest {

    private static void createCurrentAccountingPeriod(TestDataSuite testData){
        testData.acctPeriods.add(new Accounting_Period__c(
            Name = '1992-05',
            Start_Date__c = Date.newInstance(1992, 5, 1),
            End_Date__c = Date.today(),
            Status__c = AccountingPeriodActions.OPEN_STATUS
        ));
        insert testData.acctPeriods[testData.acctPeriods.size()-1];
    }

//------------------------------Get Cash Receipt Tests------------------------------------------//
    @IsTest
    public static void testCashReceipt() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            CashReceiptApplyHelper.cashReceiptWrapper wrapper = CashReceiptApplyHelper.getCashReceipt(testData.cashReceipts[0].Id);
            
            system.assertNotEquals(Null, wrapper.cashReceipt);
            system.assertEquals(testData.cashReceipts[0].Amount__c, wrapper.cashReceipt.Amount__c);
            system.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, wrapper.isMultiCurrencyEnabled);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCashReceiptFakeId() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        CashReceiptApplyHelper.cashReceiptWrapper wrapper;

        AuraHandledException expectedEx;

        System.runAs(testData.users[1]) {
            Test.startTest();
            try {
                wrapper = CashReceiptApplyHelper.getCashReceipt('abc123');
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }

        System.assertNotEquals(null, expectedEx);
    }
    
//------------------------------Filtering Tests-------------------------------------------------//
    @IsTest
    public static void testGetApplicableInvoices() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testSoftCloseApplicableInvoices() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            
            Accounting_Period__c period = [Select id, Status__c, Close_AR__c from Accounting_Period__c
                                           WHERE Start_date__c =: Date.newInstance(1992, 5, 1)];
            period.Close_AR__c = true;
            UPDATE period;
            
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                Assert.isTrue(result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            Assert.areEqual(2, response.billingWrapper.size());
            Assert.isTrue(response.billingWrapper[0].isClosed);
            Test.stopTest();
        }
    }


    @IsTest
    public static void testGetApplicableInvoicesWithoutCurrentPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        System.runAs(testData.users[1]) {
            Test.startTest();
            
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetApplicableInvoicesLimitResults() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 1;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(1, response.billingWrapper.size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetApplicableInvoicesExistingBCRs() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            bcr.Applied_Amount__c = 150.00;
            bcr.Adjustment_Amount__c = 100.00;
            insert bcr;

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());
            system.assertEquals(150.00, response.billingWrapper[0].appliedAmount);
            system.assertEquals(100.00, response.billingWrapper[0].adjustmentAmount);
            system.assertEquals(testData.acctPeriods[1].Start_Date__c, response.billingWrapper[0].appliedDate);
            Test.stopTest();

        }
    }

    @IsTest
    public static void testGetApplicableInvoicesOnlyPosted() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'Posted',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(1, response.billingWrapper.size());
            system.assertEquals(testData.billings[0].Customer__c, response.billingWrapper[0].customerId);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetApplicableInvoicesOnlyApproved() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'Approved',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(1, response.billingWrapper.size());
            system.assertEquals(testData.billings[1].Customer__c, response.billingWrapper[0].customerId);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetApplicableInvoicesAllCustomers() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            testData.billings[1].Customer__c = testData.accounts[1].Id;
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            NULL,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetApplicableInvoicesBillingNumber() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            testData.billings[1].Proprietary_Billing_Number__c = 'Test Billing 1 Filter';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            'Filter',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(1, response.billingWrapper.size());
            system.assertEquals(testData.billings[1].Customer__c, response.billingWrapper[0].customerId);
            Test.stopTest();
        }
    }
//------------------------------Filter Ranges-----------------------------------------------//
    @IsTest
    public static void testGetApplicableInvoicesBillingDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            testData.acctPeriods[0].Start_Date__c,
            testData.acctPeriods[0].End_Date__c,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            testData.acctPeriods[1].Start_Date__c,
            testData.acctPeriods[1].End_Date__c,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(0, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            testData.acctPeriods[1].End_Date__c,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            testData.acctPeriods[0].Start_Date__c,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetApplicableInvoicesDueDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            System.today(),
            System.today() + 30,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            System.today() + 60,
            System.today() + 90,
            NULL,
            NULL
            );
            system.assertEquals(0, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            System.today() + 30,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            System.today(),  
            NULL,
            NULL,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testGetApplicableInvoicesBillingAmount() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            //set the billing amounts to 2000 and 4000 respectively
            testData.billingLines[0].Hours_Units__c = 100;
            testData.billingLines[0].Rate__c = 10;
            testData.billingLines[1].Hours_Units__c = 100;
            testData.billingLines[1].Rate__c = 10;
            testData.billingLines[2].Hours_Units__c = 200;
            testData.billingLines[2].Rate__c = 10;
            testData.billingLines[3].Hours_Units__c = 200;
            testData.billingLines[3].Rate__c = 10;
            update testData.billingLines;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            2000.00,
            4000.00
            );
            system.assertEquals(2, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            5000.00,
            6000.00
            );
            system.assertEquals(0, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            4000.00
            );
            system.assertEquals(2, response.billingWrapper.size());

            response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            2000.00,
            NULL
            );
            system.assertEquals(2, response.billingWrapper.size());
            Test.stopTest();
        }
    }

//------------------------------Save Tests--------------------------------//

    @IsTest
    public static void testSave() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());
            system.assertEquals(testData.cashReceipts[0].Id, response.cashReceipt.Id);
            Test.stopTest();

            List<Billing_Cash_Receipt__c> receipts = [SELECT Id, Applied_Amount__c, Applied_Date__c, Adjustment_Amount__c, Adjustment_GL_Account__c, Billing__c FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :response.cashReceipt.Id];
            List<Billing__c> billing = [SELECT Id, Received_Amount__c, Balance__c, Cash_Application_Adjustment_Amount__c FROM Billing__c WHERE Id = :receipts[0].Billing__c];
            system.assertEquals(1, receipts.size());
            system.assertEquals(100.00, receipts[0].Applied_Amount__c);
            system.assertEquals(50.00, receipts[0].Adjustment_Amount__c);
            system.assertEquals(testData.acctPeriods[1].Start_Date__c, receipts[0].Applied_Date__c);
            system.assertEquals(testData.glAccounts[0].Id, receipts[0].Adjustment_GL_Account__c);
            
            system.assertEquals(50.00, billing[0].Cash_Application_Adjustment_Amount__c);
            system.assertEquals(100.00, billing[0].Received_Amount__c);
            system.assertEquals(300.00, billing[0].Balance__c);

            system.assertEquals(300.00, response.cashReceipt.Balance__c);
            system.assertEquals(100.00, response.cashReceipt.Applied_Amount__c);
        }
    }

    @IsTest
    public static void testSaveSoftClose() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c period = [Select Id, Close_AR__c, Close_AP__c, Status__c From Accounting_Period__c
                                           WHERE Start_Date__c =: Date.newInstance(1991, 11, 1)];
            Period.Close_AR__c = True;
            UPDATE period;

            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            Assert.isFalse(response.isSuccess);
            Assert.areNotEqual(0, response.errors.size());
            Assert.areEqual(testData.cashReceipts[0].Id, response.cashReceipt.Id);
            Assert.areEqual(400.00, response.cashReceipt.Balance__c);
            Assert.areEqual(0.00, response.cashReceipt.Applied_Amount__c);
            Test.stopTest();

            List<Billing_Cash_Receipt__c> receipts = [SELECT Id, Applied_Amount__c, Applied_Date__c, Adjustment_Amount__c, Adjustment_GL_Account__c, Billing__c FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :response.cashReceipt.Id];
           
            Assert.areEqual(0, receipts.size());
        }
    }

    @IsTest
    public static void testSaveCashReceiptModified() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate.addDays(2), items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals('cash_receipt_modified', response.errors[0]);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testSaveBadAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = system.today().addYears(20);
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(true, response.errors[0].contains('is for a closed or invalid accounting period.'));
            Test.stopTest();            
        }
    }

    @IsTest
    public static void testSaveMissingAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(true, response.errors[0].contains('is for a closed or invalid accounting period.'));
            Test.stopTest();            
        }
    }

    @IsTest
    public static void testSaveTooEarlyAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[0].Start_Date__c;
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals('validation_failure', response.errors[0]);
            Test.stopTest();            
        }
    }

    @IsTest
    public static void testSaveBadAppliedAmount() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = -100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals('validation_failure', response.errors[0]);
            Test.stopTest();            
        }
    }

    @IsTest
    public static void testSaveNegativeAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            item.adjustmentAmount = -50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());
            system.assertEquals(testData.cashReceipts[0].Id, response.cashReceipt.Id);
            Test.stopTest();            
        }
    }

    @IsTest
    public static void testSaveMissingGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals('validation_failure', response.errors[0]);
            Test.stopTest();            
        }
    }

    @IsTest
    public static void testSaveUpdateExistingBCRAppliedAmountAndAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            bcr.Applied_Amount__c = 150.00;
            bcr.Adjustment_Amount__c = 100.00;
            insert bcr;


            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            item.adjustmentAmount = 50;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());
            
            Test.stopTest();        
            List<Billing_Cash_Receipt__c> receipts = [SELECT Id, Applied_Amount__c, Applied_Date__c, Adjustment_Amount__c, Adjustment_GL_Account__c, Billing__c FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :response.cashReceipt.Id];
            List<Billing__c> billing = [SELECT Id, Received_Amount__c, Balance__c, Cash_Application_Adjustment_Amount__c FROM Billing__c WHERE Id = :receipts[0].Billing__c];
            system.assertEquals(1, receipts.size());
            system.assertEquals(100.00, receipts[0].Applied_Amount__c);
            system.assertEquals(50.00, receipts[0].Adjustment_Amount__c);
            system.assertEquals(testData.acctPeriods[1].Start_Date__c, receipts[0].Applied_Date__c);
            system.assertEquals(testData.glAccounts[0].Id, receipts[0].Adjustment_GL_Account__c);
            
            system.assertEquals(50.00, billing[0].Cash_Application_Adjustment_Amount__c);
            system.assertEquals(100.00, billing[0].Received_Amount__c);
            system.assertEquals(300.00, billing[0].Balance__c);

            system.assertEquals(300.00, response.cashReceipt.Balance__c);
            system.assertEquals(100.00, response.cashReceipt.Applied_Amount__c);
        }
    }

    @IsTest
    public static void testSaveTooMuchAdjusted() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            bcr.Applied_Amount__c = 150.00;
            bcr.Adjustment_Amount__c = 100.00;
            insert bcr;


            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 150.00;
            item.adjustmentAmount = 450.00;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals('validation_failure', response.errors[0]);
            
            Test.stopTest();        
            
        }
    }

    @IsTest
    public static void testSaveTooMuchApplied() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            bcr.Applied_Amount__c = 150.00;
            bcr.Adjustment_Amount__c = 100.00;
            insert bcr;


            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 500.00;
            item.adjustmentAmount = 100.00;            
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals('validation_failure', response.errors[0]);
            
            Test.stopTest();        
            
        }
    }

    @IsTest
    public static void testSaveUnapplyAndApplyOverApplyFailure() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 400.00;
        
            items.add(JSON.serialize(item));
            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);

            system.assertEquals(true, response.isSuccess);
            
            List<String> itemsUpdated = new List<String>();
            CashReceiptApplyHelper.SaveItem item1 = new CashReceiptApplyHelper.SaveItem();
            item1.billingId = testData.billings[0].Id;
            item1.derivedName = testData.billings[0].Name;
            item1.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item1.appliedAmount = 0;
        
            itemsUpdated.add(JSON.serialize(item1));

            CashReceiptApplyHelper.SaveItem item2 = new CashReceiptApplyHelper.SaveItem();
            item2.billingId = testData.billings[1].Id;
            item2.derivedName = testData.billings[1].Name;
            item2.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item2.appliedAmount = 500;

            itemsUpdated.add(JSON.serialize(item2));
    
            Cash_Receipt__c receiptUpdated = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            CashReceiptApplyHelper.SaveResponse responseUnapplyApply = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receiptUpdated.LastModifiedDate, itemsUpdated);
            system.assertEquals(false, responseUnapplyApply.isSuccess);
            system.assertEquals(1, responseUnapplyApply.errors.size());
            system.assertEquals('validation_failure', responseUnapplyApply.errors[0]);
            
            Test.stopTest();        
            
        }
    }

    @IsTest
    public static void testSaveUnapplyAndApplySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 400.00;
        
            items.add(JSON.serialize(item));
            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);

            system.assertEquals(true, response.isSuccess);
            
            List<String> itemsUpdated = new List<String>();
            CashReceiptApplyHelper.SaveItem item1 = new CashReceiptApplyHelper.SaveItem();
            item1.billingId = testData.billings[0].Id;
            item1.derivedName = testData.billings[0].Name;
            item1.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item1.appliedAmount = 0;
        
            itemsUpdated.add(JSON.serialize(item1));

            CashReceiptApplyHelper.SaveItem item2 = new CashReceiptApplyHelper.SaveItem();
            item2.billingId = testData.billings[1].Id;
            item2.derivedName = testData.billings[1].Name;
            item2.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item2.appliedAmount = 400;

            itemsUpdated.add(JSON.serialize(item2));
            
            Cash_Receipt__c receiptUpdated = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            CashReceiptApplyHelper.SaveResponse responseUnapplyApply = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receiptUpdated.LastModifiedDate, itemsUpdated);
            system.assertEquals(true, responseUnapplyApply.isSuccess);           
            Test.stopTest();        
            
        }
    }

    @IsTest
    public static void testSaveChangeAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            bcr.Applied_Amount__c = 150.00;
            bcr.Adjustment_Amount__c = 100.00;
            insert bcr;


            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[2].Start_Date__c;
            item.appliedAmount = 150.00;
            item.adjustmentAmount = 100.00;  
            item.glAccount = testData.glAccounts[0].Id;          
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            
            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);
            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());            
            
            Test.stopTest();        
            List<Billing_Cash_Receipt__c> receipts = [SELECT Id, Applied_Date__c, Accounting_Period__c FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :response.cashReceipt.Id];
            
            system.assertEquals(1, receipts.size());
            system.assertEquals(testData.acctPeriods[2].Start_Date__c, receipts[0].Applied_Date__c);
            system.assertEquals(testData.acctPeriods[2].Id, receipts[0].Accounting_Period__c);
            
        }
    }

    @IsTest
    public static void testSaveRoundingIssue() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .disableAutoPostSourceDocuments()
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billingLines[0].Hours_Units__c = 1;
            testData.billingLines[1].Hours_Units__c = 1;
            testData.billingLines[0].Rate__c = 240000;
            testData.billingLines[1].Rate__c = 0;

            testData.billingLines[2].Hours_Units__c = 1;
            testData.billingLines[3].Hours_Units__c = 1;
            testData.billingLines[2].Rate__c = 6909;
            testData.billingLines[3].Rate__c = 0;
            update testData.billingLines;

            testData.billings[0].Status__c = 'Approved';
            testData.billings[1].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0], testData.billings[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            List<String> items = new List<String>();
            CashReceiptApplyHelper.SaveItem item = new CashReceiptApplyHelper.SaveItem();
            item.billingId = testData.billings[0].Id;
            item.derivedName = testData.billings[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 15596.19;
            item.adjustmentAmount = 0;
            item.glAccount = testData.glAccounts[0].Id;
            items.add(JSON.serialize(item));

            Cash_Receipt__c receipt = [SELECT Id, LastModifiedDate, Amount__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];
            receipt.Amount__c = 16602.22;
            update receipt;

            receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];

            CashReceiptApplyHelper.SaveResponse response = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items);

            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());
            system.assertEquals(testData.cashReceipts[0].Id, response.cashReceipt.Id);

            List<String> items2 = new List<String>();
            CashReceiptApplyHelper.SaveItem item2 = new CashReceiptApplyHelper.SaveItem();
            item2.billingId = testData.billings[1].Id;
            item2.derivedName = testData.billings[1].Name;
            item2.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item2.appliedAmount = 1006.0300000000007;
            item2.adjustmentAmount = 0;
            item2.glAccount = testData.glAccounts[0].Id;
            items2.add(JSON.serialize(item2));

            receipt = [SELECT Id, LastModifiedDate FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];

            CashReceiptApplyHelper.SaveResponse response2 = CashReceiptApplyHelper.save(testData.cashReceipts[0].Id, receipt.LastModifiedDate, items2);

            system.assertEquals(true, response2.isSuccess);
            system.assertEquals(0, response2.errors.size());
            system.assertEquals(testData.cashReceipts[0].Id, response2.cashReceipt.Id);

            Test.stopTest();

            List<Billing_Cash_Receipt__c> receipts = [SELECT Id, Applied_Amount__c, Applied_Date__c, Adjustment_Amount__c, Adjustment_GL_Account__c, Billing__c FROM Billing_Cash_Receipt__c WHERE Cash_Receipt__c = :response.cashReceipt.Id];

            system.assertEquals(2, receipts.size());
            system.assertEquals(15596.19, receipts[0].Applied_Amount__c);
            system.assertEquals(1006.03, receipts[1].Applied_Amount__c);

            system.assertEquals(testData.acctPeriods[1].Start_Date__c, receipts[0].Applied_Date__c);
            system.assertEquals(testData.glAccounts[0].Id, receipts[0].Adjustment_GL_Account__c);

            system.assertEquals(testData.acctPeriods[1].Start_Date__c, receipts[1].Applied_Date__c);
            system.assertEquals(testData.glAccounts[0].Id, receipts[1].Adjustment_GL_Account__c);

        }
    }
    @IsTest
    public static void testGetApplicableInvoicesExistingBCRsWithTotalAmounts() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createBillings()
            .createCashReceipts();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings;

            for (PostResult result : BillingPostService.postBillings(new List<Billing__c>{testData.billings[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Adjustment_GL_Account__c = testData.glAccounts[0].Id;
            bcr.Applied_Amount__c = 150.00;
            bcr.Adjustment_Amount__c = 100.00;
            insert bcr;

            Integer maxResults = 10;

            CashReceiptApplyHelper.ResponseWrapper response = CashReceiptApplyHelper.getApplicableInvoices(
            testData.cashReceipts[0].Id,
            maxResults,
            testData.cashReceipts[0].Account__c,
            'All',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
            );
            
            system.assertEquals(2, response.billingWrapper.size());
            system.assertEquals(150.00, response.billingWrapper[0].appliedAmount);
            system.assertEquals(100.00, response.billingWrapper[0].adjustmentAmount);
            system.assertEquals(testData.acctPeriods[1].Start_Date__c, response.billingWrapper[0].appliedDate);
            system.assertEquals(150.00, response.totalAppliedAmount);
            Test.stopTest();

        }
    }
    @IsTest
    public static void testVoidedCRCannotBeApplied() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
                    .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = System.now().date();
            testAccountingPeriod.End_Date__c = System.now().date();

            UPDATE testAccountingPeriod;

            CashReceiptVoidHelper.VoidData voidData = new CashReceiptVoidHelper.VoidData();
            voidData.cashReceiptId = testData.cashReceipts[0].Id;
            voidData.voidReceiptDate = System.today();
            voidData.description = 'Test Description';
            voidData.paymentId = testData.cashReceipts[0].Payment_Reference__c;


            List<Transaction__c> controlledTrans = [
                SELECT Id, Cash_Receipt__c, Amount__c
                FROM Transaction__c
                WHERE Cash_Receipt__c = :testData.cashReceipts[0].Id
            ];

            //initially there should be only 2 transactions
            Assert.areEqual(2, controlledTrans.size());
            
            new CashReceiptVoid().voidCashReceipt(voidData);

            Cash_Receipt__c cr = [SELECT Id,Void__c, Void_Date__c, Void_Description__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id][0];

            // make sure the cash receipt is updated
            Assert.areEqual(true, cr.Void__c);
            Assert.areEqual(System.now().date(), cr.Void_Date__c);
            Assert.areEqual( voidData.description, cr.Void_Description__c);

            CashReceiptApplyHelper.cashReceiptWrapper wrapper = CashReceiptApplyHelper.getCashReceipt(cr.Id);
            Assert.areEqual(false, wrapper.isValid);
            Assert.areEqual(Label.COMMON_VOIDED_CR_ERROR, wrapper.validationErrors);
            Test.stopTest();
        }
    }
}