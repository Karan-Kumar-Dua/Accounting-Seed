@IsTest
public class BillingPostTransactionTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBillingPostNotApprovedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        Billing__c billing = testData.billings[0];
        billing.Status__c = 'In Process';
        update billing;

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Test is not approved error message
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c
                FROM Billing__c
                WHERE Id = :billing.Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();
            Test.stopTest();

            System.assertEquals(AbstractPostHandler.NOT_APPROVED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }  

    @IsTest
    public static void testBillingPostIsPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Test is posted error message
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();
            System.assertEquals(
                'Posted', [
                    SELECT Id, Status__c, Accounting_Period__r.Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c);


            cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            pbt = new BillingPostTransaction(cont);
            pbt.post();
            System.assertEquals(AbstractPostHandler.POSTED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    } 
    
    @IsTest
    public static void testBillingPostIsAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Test accounting period is closed error
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            BillingPostTransaction pbt = new BillingPostTransaction(cont);

            pbt.post();
            System.assertEquals(
                AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }   
        
    @IsTest
    public static void testBillingPostIsNoControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Test control account is not setup error
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);

            pbt.post();
            List<ApexPages.Message> msgs = ApexPages.getMessages();
            Boolean result = false;
            for(ApexPages.Message msg : msgs){
                if (msg.getDetail().contains(BillingPostHandler.NO_CONTROL_ACCOUNT_MESSAGE)) {
                    result = true;
                }
            }
            System.assert(result);
        }

    }

    @IsTest
    public static void testBillingPostIsNoBillingLinesError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            delete testData.billingLines;

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();
            System.assertEquals(BillingPostHandler.NO_BILL_LINES_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }  
    
    @IsTest
    public static void testBillingPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c
            );
            System.assertEquals(
                4,
                [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]
            );
            System.assertEquals(
                0, [
                    SELECT sum(Amount__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
        }

    }  
    
    @IsTest
    public static void testBillingUnpostNotPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);

            pbt.unpost();

            System.assertEquals(
                testData.billings[0].Status__c,
                [
                    SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c
            );
        }

    }
    
    @IsTest
    public static void testBillingUnpostIsAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            // Test accounting period is closed error
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            pbt = new BillingPostTransaction(cont);
            pbt.unpost();

            System.assertEquals(
                AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getSummary()
            );
        }

    }

    @IsTest
    public static void testBillingUnpostBillingCashReceipts() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createCashReceipts()
            .createBillings(true);

        System.runAs(testData.users[1]) {
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[2].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcr.Applied_Amount__c = 2;
            insert bcr;

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.unpost();

            System.assert(ApexPages.getMessages().isEmpty());
        }

    }
    
    @IsTest
    public static void testBillingUnpostBillingInvoiceCreditMemos() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();

            System.assertEquals(AccountingPeriodActions.OPEN_STATUS, [SELECT Id, Accounting_Period__r.Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Accounting_Period__r.Status__c);
            System.assertEquals(AccountingPeriodActions.OPEN_STATUS, [SELECT Id, Accounting_Period__r.Status__c FROM Billing__c WHERE Id = :testData.billings[3].Id].Accounting_Period__r.Status__c);

            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[0].Id]);
            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[3].Id]);

            ApexPages.StandardSetController contSet = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id OR Id = :testData.billings[3].Id
            ]);

            contSet.setSelected(contSet.getRecords());
            BillingPostTransaction pbt = new BillingPostTransaction(contSet);

            pbt.post();

            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[3].Id].Status__c);

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            // Test unpost billing invoice
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            pbt = new BillingPostTransaction(cont);
            pbt.unpost();

            System.assertNotEquals(
                ApexPages.Severity.ERROR,
                ApexPages.getMessages()[0].getSeverity()
            );
        }

    }
   
    @IsTest
    public static void testBillingUnpostBillingCreditMemoCreditMemos() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS, [
                    SELECT Id, Accounting_Period__r.Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id
                ].Accounting_Period__r.Status__c
            );
            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS, [
                    SELECT Id, Accounting_Period__r.Status__c FROM Billing__c WHERE Id = :testData.billings[3].Id
                ].Accounting_Period__r.Status__c
            );
            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[0].Id]);
            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[3].Id]);

            ApexPages.StandardSetController contSet = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id OR Id = :testData.billings[3].Id
            ]);

            contSet.setSelected(contSet.getRecords());
            BillingPostTransaction pbt = new BillingPostTransaction(contSet);
            pbt.post();

            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[3].Id].Status__c);

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            // Test unpost billing credit memo
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[3].Id
            ]);
            pbt = new BillingPostTransaction(cont);
            pbt.unpost();

            System.assertNotEquals(
                ApexPages.Severity.ERROR,
                ApexPages.getMessages()[0].getSeverity()
            );
        }

    }

    @IsTest
    public static void testBillingUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);

            pbt.post();
            cont = new ApexPages.StandardController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            pbt = new BillingPostTransaction(cont);
            pbt.unpost();

            System.assertNotEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]);
        }

    }

    @IsTest
    public static void testBillingPostBatchIsNoControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            // Test control account is not setup error
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Billing__c>{testBilling}
            );
            setController.setSelected(setController.getRecords());

            BillingPostTransaction controller = new BillingPostTransaction(setController);
            controller.validateBeforePost();

            System.assertEquals(1, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testBilling.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(
                String.valueOf(testBilling.Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.NO_CONTROL_AR_ACCOUNT_DEFINED.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }

    @IsTest
    public static void testBillingPostBatchSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            setController.setSelected(setController.getRecords());
            BillingPostTransaction pbt = new BillingPostTransaction(setController);
            pbt.post();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c
            );

            System.assertEquals(
                4, [
                    SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id
                ]
            );

            System.assertEquals(
                0, [
                    SELECT sum(Amount__c) sum FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id GROUP BY Billing_Line__r.Billing__c
                ][0].get('sum')
            );
        }

    }
    
    @IsTest
    public static void testBillingUnpostBatchIsNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id]);

            BillingPostTransaction pbt = new BillingPostTransaction(setController);
            pbt.unpost();

            System.assertEquals(BillingPostHandler.NO_SELECTION_UNPOSTED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest    
    public static void testBillingUnpostBatchSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .setLineLevelPost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            setController.setSelected(setController.getRecords());
            BillingPostTransaction pbt = new BillingPostTransaction(setController);
            pbt.post();

            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]);

            setController = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            setController.setSelected(setController.getRecords());
            pbt = new BillingPostTransaction(setController);

            pbt.unpost();

            System.assertEquals('Approved', [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Line__r.Billing__c = :testData.billings[0].Id]);
        }

    }

    @IsTest
    public static void testBillingPostInterimPageWhenCollectionSizeLimitReached() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.setInventoryValuationStandardCost()
            .setLineLevelPost()
            .setERPEnabled()
            .createProducts()
            .createProductParts()
            .createBillings();

        System.runAs(testData.users[1]) {
            Product2 testProduct = testData.products[2];
            List<Product_Part__c> productParts = testData.productParts;//2 product parts
            //add three more
            productParts.add(testData.productParts[1].clone(false, true));
            productParts.add(testData.productParts[1].clone(false, true));
            productParts.add(testData.productParts[1].clone(false, true));
            upsert productParts;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );
            insert testBilling;

            //create 100 Billing Lines
            List<Billing_Line__c> newBillingLines = new List<Billing_Line__c>();
            for (Integer i = 0; i < 100; i++) {
                Billing_Line__c billingLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 5,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Product__c = testProduct.Id
                );
                newBillingLines.add(billingLine);
            }
            insert newBillingLines;

            System.assertEquals(true, AccountingSettingsHandler.isLineLevelPost());

            ApexPages.StandardController cont = new ApexPages.StandardController(testBilling);
            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.validateBeforePost();

            //total number of forecasted records
            System.assertEquals(1200, pbt.forecastedTransactionsCollectionSize);
            //trimmed amount of forecasted records
            System.assertEquals(1000, pbt.forecastedTransactions.size());
            //warning message is shown up
            System.assertEquals(
                String.format(
                    AbstractSourceDocumentPost.POST_COLLECTION_LIMIT_WARNING_MESSAGE,
                    new List<String>{String.valueOf(pbt.forecastedTransactionsCollectionSize)}
                ),
                ApexPages.getMessages()[1].getSummary()
            );
        }
    }

    @IsTest
    public static void testBillingUnpostInterimPageWhenCollectionSizeLimitReached() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.setInventoryValuationStandardCost()
            .setLineLevelPost()
            .setERPEnabled()
            .createProducts()
            .createProductParts()
            .createBillings();

        System.runAs(testData.users[1]) {
            
            Product2 testProduct = testData.products[2];
            List<Product_Part__c> productParts = testData.productParts;//2 product parts
            //add three more
            productParts.add(testData.productParts[1].clone(false, true));
            productParts.add(testData.productParts[1].clone(false, true));
            productParts.add(testData.productParts[1].clone(false, true));

            upsert productParts;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30
            );

            insert testBilling;

            //create 100 Billing Lines
            List<Billing_Line__c> newBillingLines = new List<Billing_Line__c>();
            for (Integer i = 0; i < 100; i++) {
                Billing_Line__c billingLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 5,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id,
                    Product__c = testProduct.Id
                );

                newBillingLines.add(billingLine);
            }

            insert newBillingLines;

            System.assertEquals(true, AccountingSettingsHandler.isLineLevelPost());

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> billingPostResults = postHandler.post(new List<Billing__c>{testBilling});
            System.assertEquals(true, billingPostResults[0].isSuccess);

            ApexPages.StandardController cont = new ApexPages.StandardController(testBilling);
            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.validateBeforeUnpost();

            //total number of forecasted records
            System.assertEquals(1200, pbt.forecastedTransactionsCollectionSize);
            //trimmed amount of forecasted records
            System.assertEquals(1000, pbt.forecastedTransactions.size());
            //warning message is shown up
            System.assertEquals(
                String.format(
                    AbstractSourceDocumentPost.UNPOST_COLLECTION_LIMIT_WARNING_MESSAGE,
                    new List<String>{String.valueOf(pbt.forecastedTransactionsCollectionSize)}
                ),
                ApexPages.getMessages()[1].getSummary()
            );
        }
    }

    @IsTest
    public static void testBillingPostSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBillings()
                .setLineLevelPost();

            System.runAs(testData.users[1]) {
                Test.startTest();
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrency)) {
                    return;
                }

                Billing__c testBilling = testData.billings[0];
                testBilling.put('CurrencyIsoCode', newCurrency);
                testBilling.put('Currency_Conversion_Rate__c', 1);

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update testBilling;

                ApexPages.StandardController cont = new ApexPages.StandardController(testBilling);
                BillingPostTransaction pbt = new BillingPostTransaction(cont);
                pbt.post();

                //Check results
                List<Transaction__c> newTransactions = [
                    SELECT Id, Foreign_Amount__c, Foreign_Currency__c, Currency_Conversion_Rate__c, Amount__c
                    FROM Transaction__c
                    WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    AND Foreign_Amount__c != NULL
                    AND Foreign_Currency__c != NULL
                    AND Currency_Conversion_Rate__c != NULL
                ];
                System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);
                System.assertEquals(4, newTransactions.size());
                System.assertEquals(
                    0, [
                        SELECT sum(Amount__c) sum
                        FROM Transaction__c
                        WHERE Billing_Line__r.Billing__c = :testBilling.Id
                        GROUP BY Billing_Line__r.Billing__c
                    ][0].get('sum')
                );
                System.assertEquals(
                    newCurrency, [
                        SELECT Foreign_Currency__c
                        FROM Transaction__c
                        WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    ][0].Foreign_Currency__c
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testBillingPostBatchSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBillings()
                .setLineLevelPost();

            System.runAs(testData.users[1]) {
                Test.startTest();

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrency)) {
                    return;
                }

                Billing__c testBilling = testData.billings[0];
                testBilling.put('CurrencyIsoCode', newCurrency);
                testBilling.put('Currency_Conversion_Rate__c', 1);

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update testBilling;

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(new List<Billing__c>{testBilling});
                setController.setSelected(setController.getRecords());
                BillingPostTransaction pbt = new BillingPostTransaction(setController);

                pbt.post();

                System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);
                System.assertEquals(
                    0, [
                        SELECT sum(Amount__c) sum
                        FROM Transaction__c
                        WHERE Billing_Line__r.Billing__c = :testBilling.Id
                        GROUP BY Billing_Line__r.Billing__c
                    ][0].get('sum')
                );
                System.assertEquals(
                    newCurrency, [
                        SELECT Foreign_Currency__c
                        FROM Transaction__c
                        WHERE Billing_Line__r.Billing__c = :testBilling.Id
                    ][0].Foreign_Currency__c
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testBillingLDVPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enableLDVMode()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            setController.setSelected(setController.getRecords());
            BillingPostTransaction pbt = new BillingPostTransaction(setController);
            pbt.validateBeforePost();

            if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                System.assertEquals(Label.INF_LDV_BEFORE_POST, ApexPages.getMessages()[0].getSummary());

                pbt.post();
                System.assertEquals(Label.INF_LDV_POST_IN_PROGRESS, ApexPages.getMessages()[2].getSummary());
            }
        }

    }

    @IsTest
    public static void testBillingLDVUnpostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true)
            .enableLDVMode();

        System.runAs(testData.users[1]) {
            Test.startTest();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Status__c, Accounting_Period__r.Status__c, Billing_Cash_Receipt_Count__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            setController.setSelected(setController.getRecords());
            BillingPostTransaction pbt = new BillingPostTransaction(setController);
            pbt.validateBeforeUnpost();

            if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
                System.assertEquals(Label.INF_LDV_BEFORE_UNPOST, ApexPages.getMessages()[0].getSummary());

                pbt.unpost();
                System.assertEquals(Label.INF_LDV_UNPOST_IN_PROGRESS, ApexPages.getMessages()[2].getSummary());
            }
        }

    }

}