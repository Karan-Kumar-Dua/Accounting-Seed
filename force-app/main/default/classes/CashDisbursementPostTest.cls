@IsTest
public class CashDisbursementPostTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCashDisbursementPostWhenThereIsCashFlowNonConformity() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashFlowCategories(false)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            //populate Cash Flow Category
            Cash_Disbursement__c testCD = testData.cashDisbursements[1];
            testCD.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            update testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(AbstractPostHandler.CASH_FLOW_NON_CONFORMITY_HELP_TEXT, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testPostCashDisbursementsControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursements[0]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(CashDisbursementPostHandler.NO_CONTROL_ACCOUNT_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    public static void testPostCashDisbursementsAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursements[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
            System.assertEquals(
                2, [
                SELECT COUNT() FROM Transaction__c WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id
            ]);
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );

            cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(AbstractPostHandler.POSTED_ERROR_MESSAGE, ApexPages.getMessages()[1].getSummary());
        }
    } 

    @IsTest
    public static void testCashDisbursementNoDiscountPaymentAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = testData.payables[3];
            testPayable.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            testPayable.Discount_Amount__c = 10;
            testPayable.Accounting_Period__c = testData.acctPeriods[0].Id;
            update testPayable;

            List<PostResult> postResults = AccountPayablePostService.postAccountPayables(
                new List<Account_Payable__c>{testPayable}
            );
            System.assertEquals(true, postResults[0].isSuccess);

            ApexPages.StandardController apStdController = new ApexPages.StandardController([
                SELECT Id
                FROM Account_Payable__c
                WHERE Id = :testPayable.Id
            ]);

            AccountPayablePayPartial apb = new AccountPayablePayPartial(apStdController);
            apb.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            apb.uiCashDisbursement.Accounting_Period__c = testData.acctPeriods[0].Id;
            apb.uiCashDisbursement.Bank_Account__c = testData.glAccounts[0].Id;
            apb.uiCashDisbursement.Type__c = 'Electronic';
            apb.uiCashDisbursement.Amount__c = [
                SELECT Id, Net_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testPayable.Id
            ].Net_Amount__c;

            apb.payPartial();

            System.assertEquals(
                [SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testPayable.Id].Net_Amount__c,
                [SELECT Id, Paid_Amount__c FROM AP_Disbursement__c WHERE Account_Payable__c = :testPayable.Id].Paid_Amount__c
            );

            System.assertEquals([
                    SELECT Id, Net_Amount__c FROM Account_Payable__c WHERE Id = :testPayable.Id
                ].Net_Amount__c, [
                    SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c
                    FROM AP_Disbursement__c
                    WHERE Account_Payable__c = :testPayable.Id
                ].Cash_Disbursement__r.Amount__c
            );

            System.assertEquals(
                'Paid', [
                    SELECT Id, Paid_Amount__c, Account_Payable__r.Payment_Status__c
                    FROM AP_Disbursement__c
                    WHERE Account_Payable__c = :testPayable.Id
                ].Account_Payable__r.Payment_Status__c
            );

            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            Id cdId = [
                SELECT Id, Paid_Amount__c, Cash_Disbursement__r.Amount__c
                FROM AP_Disbursement__c
                WHERE Account_Payable__c = :testPayable.Id
            ].Cash_Disbursement__r.Id;

            Cash_Disbursement__c cd = [SELECT Id FROM Cash_Disbursement__c WHERE Id = :cdId];

            ApexPages.StandardController cdStdController = new ApexPages.StandardController(cd);
            CashDisbursementPost cdp = new CashDisbursementPost(cdStdController);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(false, cdp.results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_DISCOUNT_PAYMENT_ACCOUNT, cdp.results[0].errors[0].statusCode);
        }

    }
    
    @IsTest
    public static void testCashDisbursementPostAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0];

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCD);
            CashDisbursementPost controller = new CashDisbursementPost(stdController);
            controller.validateBeforePost();

            System.assertEquals(false, controller.showActionButton);
            System.assertEquals(false, controller.showForecastSection);
            System.assertEquals(false, controller.results[0].isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD, controller.results[0].errors[0].statusCode);
        }

    }  

    @IsTest
    public static void testCashDisbursementUnpostAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT Status__c, Accounting_Period__r.Status__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[0].Id
            ]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            cdp = new CashDisbursementPost(controller);
            cdp.validateBeforeUnpost();
            cdp.unpost();
            System.assertEquals(
                AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE,
                ApexPages.getMessages()[1].getSummary()
            );
        }

    } 
        
    @IsTest
    public static void testCashDisbursementPostDiscountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c testPayable = testData.payables[0];
            testPayable.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            testPayable.Discount_Amount__c = 20;
            update testPayable;

            testData.cashDisbursements[0].Amount__c = 145;
            update testData.cashDisbursements[0];

            List<PostResult> postResults = AccountPayablePostService.postAccountPayables(
                new List<Account_Payable__c>{testPayable}
            );
            System.assertEquals(true, postResults[0].isSuccess);

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                Paid_Amount__c = testData.cashDisbursements[0].Amount__c
            );

            insert apd;

            ApexPages.StandardController controller = new ApexPages.StandardController(
                testData.cashDisbursements[0]
            );
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            Test.stopTest();
            Cash_Disbursement__c testCD = [
                SELECT Id, Amount__c, Status__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[0].Id
                LIMIT 1
            ];
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
            Id paymentDiscountId = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PAYMENT_DISCOUNT_GL_ACCOUNT)?.GL_Account__c;
            System.assertEquals(
                testData.payables[0].Discount_Amount__c,
                math.abs([
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testData.cashDisbursements[0].Id
                    AND GL_Account__c = :paymentDiscountId
                ].Amount__c)
            );

            System.assertEquals(
                testCD.Amount__c,
                math.abs(
                    [
                        SELECT Amount__c
                        FROM Transaction__c
                        WHERE Cash_Disbursement__c = :testData.cashDisbursements[0].Id
                        AND GL_Account__c = :testData.ledgers[0].Default_Bank_Account__c
                    ].Amount__c
                )
            );

            Id apControlId = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
            System.assertEquals(
                testData.payables[0].Discount_Amount__c + testCD.Amount__c,
                [
                    SELECT Amount__c
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testData.cashDisbursements[0].Id
                    AND GL_Account__c = :apControlId
                ].Amount__c
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id
                ].Status__c
            );
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );
        }
    }

    @IsTest
    public static void testCashDisbursementUnpostPostedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursements[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforeUnpost();
            cdp.unpost();
            System.assertEquals(
                testData.cashDisbursements[1].Status__c,
                [SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
        }

    }
    
    @IsTest
    public static void testCashDisbursementVoidPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            CashDisbursementVoid cdv = new CashDisbursementVoid(
                new ApexPages.StandardController([
                    SELECT Id, Status__c, Payment_Status__c, Accounting_Period__c, Disbursement_Date__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[5].Id
                ])
            );
            cdv.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10);
            cdv.voidCashDisbursement();

            System.assertEquals(
                'Void', [
                    SELECT Id, Payment_Status__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[5].Id
                ].Payment_Status__c
            );

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Cash_Disbursement__c>{testData.cashDisbursements[5]});
            System.assertEquals(true, postResults[0].isSuccess);

            CashDisbursementPost cdp = new CashDisbursementPost(new ApexPages.StandardController([
                SELECT Id, Status__c, Payment_Status__c, Accounting_Period__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[5].Id
            ]));
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(
                CashDisbursementPostHandler.POSTED_VOID_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getSummary()
            );
        }
    }

    @IsTest
    public static void testCashDisbursementBankReconciliationUnpostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            testData.cashDisbursements[1].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
            update testData.cashDisbursements[1];

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursements[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            cdp = new CashDisbursementPost(new ApexPages.StandardController([
                SELECT Id, Status__c, Payment_Status__c, Accounting_Period__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[1].Id
            ]));

            cdp.validateBeforeUnpost();
            cdp.unpost();

            System.assertEquals(
                CashDisbursementPostHandler.UNPOST_CLEARED_ERROR_MESSAGE,
                ApexPages.getMessages()[1].getSummary()
            );
        }
    }
                
    @IsTest
    public static void testCashDisbursementPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursements[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(
                2,
                [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id]
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );

            // Test unpost functionality
            controller = new ApexPages.StandardController(testData.cashDisbursements[1]);
            cdp = new CashDisbursementPost(controller);
            cdp.validateBeforeUnpost();
            cdp.unpost();
            System.assertEquals(
                0,
                [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id]
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
        }
    }

    @IsTest
    public static void testCashDisbursementPostNoAPSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursements[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(
                2, [
                SELECT count()
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id
            ]);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Status__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[1].Id
                ].Status__c
            );
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );
            // Test unpost functionality
            controller = new ApexPages.StandardController(testData.cashDisbursements[1]);
            cdp = new CashDisbursementPost(controller);
            cdp.validateBeforeUnpost();
            cdp.unpost();
            System.assertEquals(
                0, [
                SELECT count()
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testData.cashDisbursements[1].Id
            ]);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Status__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[1].Id
                ].Status__c
            );
        }
    }
        
    @IsTest
    public static void testCashDisbursementBatchPostNoSelectionAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Cash_Disbursement_Batch__c testCDB = new Cash_Disbursement_Batch__c(
                Starting_Check_Number__c = 10,
                Name = 'Test Batch 3'
            );
            insert testCDB;

            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Cash_Disbursement_Batch__c = testCDB.Id;
            insert testCD;

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            ApexPages.StandardController stdController =
                new ApexPages.StandardController(testCDB);
            CashDisbursementPost controller = new CashDisbursementPost(stdController);
            controller.validateBeforePost();

            System.assertEquals(1, controller.errorStatisticsLines.size());
            System.assertEquals(String.valueOf(testCD.Id), controller.errorStatisticsLines[0].sourceObjectId);
            System.assertEquals(
                String.valueOf(testData.acctPeriods[0].Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }

    }
    
    @IsTest
    public static void testCashDisbursementBatchPostAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        System.runAs(testData.users.get(1)) {
            Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[0];
            Cash_Disbursement__c testCD1 = testData.cashDisbursements[0];
            Cash_Disbursement__c testCD2 = testData.cashDisbursements[1];
            Cash_Disbursement__c testCD3 = testData.cashDisbursements[2];

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD1, testCD2, testCD3});
            System.assertEquals(
                6, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Cash_Disbursement__r.Cash_Disbursement_Batch__c = :testCDB.Id
                ]
            );

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testCD1.Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testCD2.Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testCD3.Id].Status__c
            );

            ApexPages.StandardController stdController = new ApexPages.StandardController(testCDB);
            CashDisbursementPost controller = new CashDisbursementPost(stdController);
            controller.validateBeforePost();

            System.assertEquals(3, controller.errorStatisticsLines.size());
            System.assertEquals(false, controller.showActionButton);
        }
        Test.stopTest();
    }    
        
    @IsTest
    public static void testCashDisbursementBatchUnpostAccountingPeriodClosedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        System.runAs(testData.users.get(1)) {
            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{
                testData.cashDisbursements[0],
                testData.cashDisbursements[1],
                testData.cashDisbursements[2]
            });
            
            System.assertEquals(
                6, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Cash_Disbursement__r.Cash_Disbursement_Batch__c = :testData.cashDisbursementBatch[0].Id
                ]
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[2].Id].Status__c
            );

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            ApexPages.StandardController stdController = new ApexPages.StandardController(
                testData.cashDisbursementBatch[0]
            );
            CashDisbursementPost controller = new CashDisbursementPost(stdController);

            controller.validateBeforeUnpost();

            System.assertEquals(3, controller.errorStatisticsLines.size());
            System.assertEquals(
                String.valueOf(testData.acctPeriods[0].Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD.name()).id
            );
            System.assertEquals(false, controller.showActionButton);
        }
        Test.stopTest();
    }

    @IsTest
    public static void testCashDisbursementBatchUnpostNoSelectionBankReconciliationError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations()
            .createPayables(true);
        Test.startTest();
        testData
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();

        System.runAs(testData.users.get(1)) {
            List<Cash_Disbursement__c> disbursements = new List<Cash_Disbursement__c>();
            testData.cashDisbursements[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            testData.cashDisbursements[1].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            testData.cashDisbursements[2].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            disbursements.add(testData.cashDisbursements[0]);
            disbursements.add(testData.cashDisbursements[1]);
            disbursements.add(testData.cashDisbursements[2]);

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
            update disbursements;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(
                new List<Cash_Disbursement__c>(disbursements)
            );

            System.assertEquals(true, postResults[0].isSuccess);
            System.assertEquals(true, postResults[1].isSuccess);
            System.assertEquals(true, postResults[2].isSuccess);

            System.assertEquals(
                6, [
                    SELECT count()
                    FROM Transaction__c
                    WHERE Cash_Disbursement__r.Cash_Disbursement_Batch__c = :testData.cashDisbursementBatch[0].Id
                ]
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[2].Id].Status__c
            );

            ApexPages.StandardController stdController =
                new ApexPages.StandardController(testData.cashDisbursementBatch[0]);
            CashDisbursementPost controller = new CashDisbursementPost(stdController);
            controller.validateBeforeUnpost();
            
            System.assertEquals(3, controller.errorStatisticsLines.size());
            System.assertEquals(
                String.valueOf(testData.bankReconciliations[0].Id),
                controller.errorStatisticsLines[0].lineCells.get(PostResult.StatusCode.CLEARED_BANK_RECONCILIATION.name()).id
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCashDisbursementBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursementBatch[0]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(6, [Select count() From Transaction__c Where Cash_Disbursement__r.Cash_Disbursement_Batch__c = :testData.cashDisbursementBatch[0].Id]);
            System.assertEquals(0, [Select Sum(Amount__c) sum From Transaction__c Where Cash_Disbursement__c = :testData.cashDisbursements[0].Id Group By Cash_Disbursement__c][0].get('sum'));
            System.assertEquals(0, [Select Sum(Amount__c) sum From Transaction__c Where Cash_Disbursement__c = :testData.cashDisbursements[1].Id Group By Cash_Disbursement__c][0].get('sum'));
            System.assertEquals(0, [Select Sum(Amount__c) sum From Transaction__c Where Cash_Disbursement__c = :testData.cashDisbursements[2].Id Group By Cash_Disbursement__c][0].get('sum'));

            System.assertEquals('Posted', [Select Status__c From Cash_Disbursement__c Where Id = :testData.cashDisbursements[0].Id].Status__c);
            System.assertEquals('Posted', [Select Status__c From Cash_Disbursement__c Where Id = :testData.cashDisbursements[1].Id].Status__c);
            System.assertEquals('Posted', [Select Status__c From Cash_Disbursement__c Where Id = :testData.cashDisbursements[2].Id].Status__c);

            // Test unpost functionality
            cdp.unpost();

            System.assertEquals(0, [Select count() From Transaction__c Where Cash_Disbursement__r.Cash_Disbursement_Batch__c = :testData.cashDisbursementBatch[0].Id]);
            System.assertEquals('Approved', [Select Status__c From Cash_Disbursement__c Where Id = :testData.cashDisbursements[0].Id].Status__c);
            System.assertEquals('Approved', [Select Status__c From Cash_Disbursement__c Where Id = :testData.cashDisbursements[1].Id].Status__c);
            System.assertEquals('Approved', [Select Status__c From Cash_Disbursement__c Where Id = :testData.cashDisbursements[2].Id].Status__c);
        }

    }

    //=============================================================================
    //===== Group of test methods related to the Multi Currency functionality =====
    //=============================================================================

    @IsTest
    public static void testCashDisbursementPostSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashDisbursementBatches()
                .createCashDisbursements();

            System.runAs(testData.users.get(1)) {
                AccountingSettingsHandler.acctSeedSettings = NULL;//To refresh Account Setting for the current APEX transaction

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                testData.cashDisbursementBatch[0].put('CurrencyIsoCode', newCurrencyIsoCode);
                CashDisbursementBatchActions.isPreventUpdateOverride = true;
                update testData.cashDisbursementBatch[0];

                Cash_Disbursement__c testCD = testData.cashDisbursements[0];

                List<SObject> recordsToChangeCurrency = new List<SObject>();
                recordsToChangeCurrency.add(testCD);

                for (SObject obj : recordsToChangeCurrency) {
                    obj.put('CurrencyIsoCode', newCurrencyIsoCode);
                }

                TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
                update recordsToChangeCurrency;

                ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
                CashDisbursementPost cdp = new CashDisbursementPost(controller);
                cdp.post();
                System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
                System.assertEquals('Posted', [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Status__c);

                System.assertEquals(
                    0, [
                        SELECT sum(Amount__c) sum
                        FROM Transaction__c
                        WHERE Cash_Disbursement__c = :testCD.Id
                        GROUP BY Cash_Disbursement__c
                    ][0].get('sum')
                );
            }
        }
        catch (Exception ex) {

        }

    }

    @IsTest
    public static void testCashDisbursementPostDifferentCCRsSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables(true);
            Test.startTest();
            testData
                .createCashDisbursementBatches()
                .createCashDisbursements()
                .createApDisbursements();

            System.runAs(testData.users.get(1)) {
                AccountingSettingsHandler.acctSeedSettings = NULL;//To refresh Account Setting for the current APEX transaction

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                testData.cashDisbursementBatch[0].put('CurrencyIsoCode', newCurrencyIsoCode);
                CashDisbursementBatchActions.isPreventUpdateOverride = true;
                update testData.cashDisbursementBatch[0];

                Account_Payable__c testAP = testData.payables[0];
                Cash_Disbursement__c testCD = testData.cashDisbursements[0];
                AP_Disbursement__c testAPD = testData.apDisbursements[0];

                List<SObject> recordsToChangeCurrency = new List<SObject>();
                recordsToChangeCurrency.add(testAP);
                recordsToChangeCurrency.add(testCD);
                recordsToChangeCurrency.add(testAPD);

                for (SObject obj : recordsToChangeCurrency) {
                    obj.put('CurrencyIsoCode', newCurrencyIsoCode);
                }

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{Schema.SObjectType.Account_Payable__c.fields.getMap().get('CurrencyIsoCode')}
                );
                update recordsToChangeCurrency;
                TriggerObserver.reset();

                testAP.Currency_Conversion_Rate__c = 1;
                testCD.Currency_Conversion_Rate__c = 1.2;

                update new List<SObject> {testAP, testCD};

                String apDisbursementCurrencyISOCode = (String) Database.query(
                    'SELECT CurrencyIsoCode ' +
                    'FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'AP_Disbursement__c ' +
                    'WHERE ' + GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable__c = \'' + String.escapeSingleQuotes(testAP.Id) + '\' ' +
                    'AND ' + GlobalVariables.PACKAGE_QUALIFIER + 'Cash_Disbursement__c = \'' + String.escapeSingleQuotes(testCD.Id) + '\' '
                )[0].get('CurrencyIsoCode');
                System.assertEquals(newCurrencyIsoCode, apDisbursementCurrencyISOCode);

                ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
                CashDisbursementPost cdp = new CashDisbursementPost(controller);
                cdp.post();
                System.assertEquals(4, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
                System.assertEquals('Posted', [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Status__c);

                System.assertEquals(
                    0, [
                        SELECT sum(Amount__c) sum
                        FROM Transaction__c
                        WHERE Cash_Disbursement__c = :testCD.Id
                        GROUP BY Cash_Disbursement__c
                    ][0].get('sum')
                );
                System.assertEquals(
                    2, [
                        SELECT count()
                        FROM Transaction__c
                        WHERE Cash_Disbursement__c = :testCD.Id
                        AND Currency_Conversion_Rate__c = :testCD.Currency_Conversion_Rate__c
                    ]
                );
            }
        }
        catch (Exception ex) {

        }

    }

    @IsTest
    public static void testAsyncPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            List<Cash_Disbursement__c> clonedCD = new List<Cash_Disbursement__c>();

            Cash_Disbursement__c cashDisbursement = testData.cashDisbursements[5];
            for (Integer i = 0; i < 155; i++) {
                Cash_Disbursement__c cloneD = cashDisbursement.clone(false);
                clonedCD.add(cloneD);
            }
            insert clonedCD;

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursementBatch[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();

            Test.startTest();
            cdp.post();
            Test.stopTest();
            System.assertEquals(
                String.format(
                    CashDisbursementPost.ASYNC_BATCH_POST_IN_PROGRESS,
                    new List<String>{String.valueOf(161), 'posting'}
                ),
                ApexPages.getMessages()[1].getSummary()
            );
        }
    }

    @IsTest
    public static void testAsyncUnPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        List<Cash_Disbursement__c> clonedCD = new List<Cash_Disbursement__c>();

        System.runAs(testData.users.get(1)) {
            Cash_Disbursement__c cashDisbursement = testData.cashDisbursements[5];
            for (Integer i = 0; i < 155; i++) {
                Cash_Disbursement__c cloneD = cashDisbursement.clone(false);
                clonedCD.add(cloneD);
            }
            insert clonedCD;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(clonedCD);
            System.assertEquals(true, postResults[0].isSuccess);

            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.cashDisbursementBatch[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforeUnpost();

            Integer nmbOfCDValidForPosting = [
                SELECT count()
                FROM Cash_Disbursement__c
                WHERE Cash_Disbursement_Batch__c = :testData.cashDisbursementBatch[1].Id
                AND Status__c = :AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
            ];

            cdp.unpost();
            Test.stopTest();
            System.assertEquals(
                String.format(
                    CashDisbursementPost.ASYNC_BATCH_POST_IN_PROGRESS,
                    new List<String>{String.valueOf(nmbOfCDValidForPosting), 'unposting'}
                ),
                ApexPages.getMessages()[1].getSummary()
            );
        }

    }

    @IsTest
    public static void testStandardSetControllerPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            List<Cash_Disbursement__c> records = new List<Cash_Disbursement__c>{
                testData.cashDisbursements[0], testData.cashDisbursements[1]
            };

            ApexPages.StandardSetController controller = new ApexPages.StandardSetController(records);
            controller.setSelected(records);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(
                4,
                [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c IN :records]
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c IN :records
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );

            // Test unpost functionality
            controller = new ApexPages.StandardSetController(records);
            controller.setSelected(records);
            cdp = new CashDisbursementPost(controller);
            cdp.validateBeforeUnpost();
            cdp.unpost();
            System.assertEquals(
                0,
                [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c IN :records]
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id].Status__c
            );
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [SELECT Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[1].Id].Status__c
            );
        }
    }

    @IsTest
    public static void testCountRecordsValidForPosting() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            List<Cash_Disbursement__c> clonedCD = new List<Cash_Disbursement__c>();

            Cash_Disbursement__c cashDisbursement = testData.cashDisbursements[5];
            for (Integer i = 0; i < 155; i++) {
                Cash_Disbursement__c cloneD = cashDisbursement.clone(false);
                clonedCD.add(cloneD);
            }
            insert clonedCD;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<SObject>{clonedCD[0]});
            System.assertEquals(true, postResults[0].isSuccess);

            ApexPages.StandardController controller =
                new ApexPages.StandardController(testData.cashDisbursementBatch[1]);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();

            Test.startTest();
            Integer nmbOfCDValidForPosting = [
                SELECT count()
                FROM Cash_Disbursement__c
                WHERE Cash_Disbursement_Batch__c = :testData.cashDisbursementBatch[1].Id
                AND Status__c != :AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
            ];

            cdp.post();

            System.assertEquals(
                String.format(
                    CashDisbursementPost.ASYNC_BATCH_POST_IN_PROGRESS,
                    new List<String>{String.valueOf(nmbOfCDValidForPosting), 'posting'}
                ),
                ApexPages.getMessages()[1].getSummary()
            );
        }
    }

}