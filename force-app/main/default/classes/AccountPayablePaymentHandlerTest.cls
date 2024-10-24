@isTest
private class AccountPayablePaymentHandlerTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testBatchPayAndPost_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                    .enableMultiCurrency(); //will throw an exception in case of non-MC org
			Accounting_Settings__c settings = testData.settings;
            settings.Cash_Disbursement_Source__c = 'Payable';
            update settings;
            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                //create 200 Payable records
                List<Account_Payable__c> newPayables = new List<Account_Payable__c>();
                for (Integer i = 0; i < 50; i++) {
                    Account_Payable__c tempPayable = new Account_Payable__c(
                        Payee_Reference__c = 'ref' + i,
                        Status__c = 'Approved',
                        Payment_Status__c = 'Unpaid',
                        Date__c = testData.acctPeriods.get(0).Start_Date__c,
                        Due_Date__c = testData.acctPeriods.get(0).End_Date__c,
                        Vendor__c = testData.accounts.get(0).Id,
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Currency_Conversion_Rate__c = 1 + getRandomDecimal(2)
                    );
                    tempPayable.put('CurrencyIsoCode', newCurrencyIsoCode);
                    newPayables.add(tempPayable);
                }
                insert newPayables;

                //create Payable Line for each Payable created above
                List<Account_Payable_Line__c> newPayableLines = new List<Account_Payable_Line__c>();

                Decimal totalLinesAmount = 0;
                for (Account_Payable__c payable : newPayables) {
                    Account_Payable_Line__c tempLine = new Account_Payable_Line__c(
                        Account_Payable__c = payable.Id,
                        Amount__c = getRandomDecimal(2) * 100 + getRandomDecimal(5) + 10,//amount template
                        Date__c = testData.acctPeriods.get(0).Start_Date__c,
                        Expense_GL_Account__c = testData.glAccounts.get(16).Id
                    );
                    totalLinesAmount += (tempLine.Amount__c).setScale(2, System.RoundingMode.HALF_UP);
                    newPayableLines.add(tempLine);
                }
                insert newPayableLines;
                //Post Payables
                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(newPayables);
                System.assertEquals(true, postResults.get(0).isSuccess);

                AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
                List<PaymentResult> paymentResults = paymentHandler.init(newPayables, true, true);
                System.assertEquals(true, paymentResults.get(0).isSuccess);

                paymentHandler.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
                paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;

                paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
                paymentHandler.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
                paymentHandler.wrappedCDs.get(0).cashDisbursement.Currency_Conversion_Rate__c = 1 + getRandomDecimal(2);

                paymentHandler.paymentResultDispatcher.clearResultsMap();
                paymentResults = paymentHandler.pay(true);
                Test.stopTest();

                System.assertEquals(true, paymentResults.get(0).isSuccess);
                Cash_Disbursement__c newCD = [
                    SELECT Id, Amount__c
                    FROM Cash_Disbursement__c
                    WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id
                    LIMIT 1
                ];
                System.assertEquals(totalLinesAmount, newCD.Amount__c);
                System.assertEquals(true, paymentHandler.isDefaultCDApproved);

            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @isTest
    private static void testBatchPayAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance();
		Accounting_Settings__c settings = testData.settings;
        settings.Cash_Disbursement_Source__c = 'Payable';
        update settings;
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //create 200 Payable records
            List<Account_Payable__c> newPayables = new List<Account_Payable__c>();
            for (Integer i = 0; i < 50; i++) {
                Account_Payable__c tempPayable = new Account_Payable__c(
                    Payee_Reference__c = 'ref' + i,
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Due_Date__c = testData.acctPeriods.get(0).End_Date__c,
                    Vendor__c = testData.accounts.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                );
                newPayables.add(tempPayable);
            }
            insert newPayables;
           
            //create Payable Line for each Payable created above
            List<Account_Payable_Line__c> newPayableLines = new List<Account_Payable_Line__c>();
            Decimal totalLinesAmount = 0;
            for (Account_Payable__c payable : newPayables) {
                Account_Payable_Line__c tempLine = new Account_Payable_Line__c(
                    Account_Payable__c = payable.Id,
                    Amount__c = getRandomDecimal(2) * 100 + getRandomDecimal(5) + 10,//amount template
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts.get(16).Id
                );
                totalLinesAmount += (tempLine.Amount__c).setScale(2, System.RoundingMode.HALF_UP);
                newPayableLines.add(tempLine);
            }
            AccountPayableLineActions.isBypassGLAccountValidations = true;
            insert newPayableLines;
            AccountPayableLineActions.isBypassGLAccountValidations = false;
            //Post Payables
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(newPayables);
            System.assertEquals(50, postResults.size());
            System.assertEquals(true, postResults.get(0).isSuccess, 'Error: ' + postResults.get(0).errors);

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> paymentResults = paymentHandler.init(newPayables, true, true);
            System.assertEquals(50, paymentResults.size());
            System.assertEquals(true, paymentResults.get(0).isSuccess, 'Payment Result Error: ' + paymentResults.get(0).errors);

            paymentHandler.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
            paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
            paymentHandler.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            paymentHandler.paymentResultDispatcher.clearResultsMap();
            paymentResults = paymentHandler.pay(true);

            Test.stopTest();
            System.assertEquals(true, paymentResults.get(0).isSuccess);
            Cash_Disbursement__c newCD = [
                SELECT Id, Amount__c, Status__c
                FROM Cash_Disbursement__c
                WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id
                LIMIT 1
            ];
            System.assertEquals(totalLinesAmount, newCD.Amount__c);
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, newCD.Status__c);
        }
    }

    @isTest
    private static void testBatchPayAndPost_NotAggregatedByPayee() {
        TestDataSuite testData = TestDataSuite.getInstance();

        Decimal totalLinesAmount = 0;
		Accounting_Settings__c settings = testData.settings;
        settings.Cash_Disbursement_Source__c = 'Payable';
        update settings;
        System.runAs(testData.users.get(0)) {
            Test.startTest();
            //create 200 Payable records
            List<Account_Payable__c> newPayables = new List<Account_Payable__c>();
            for (Integer i = 0; i < 50; i++) {
                Account_Payable__c tempPayable = new Account_Payable__c(
                    Payee_Reference__c = 'ref' + i,
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Due_Date__c = testData.acctPeriods.get(0).End_Date__c,
                    Vendor__c = testData.accounts.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                );
                newPayables.add(tempPayable);
            }
            insert newPayables;

            //create Payable Line for each Payable created above
            List<Account_Payable_Line__c> newPayableLines = new List<Account_Payable_Line__c>();

            for (Account_Payable__c payable : newPayables) {
                Account_Payable_Line__c tempLine = new Account_Payable_Line__c(
                    Account_Payable__c = payable.Id,
                    Amount__c = getRandomDecimal(2) * 100 + getRandomDecimal(5) + 10,//amount template
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts.get(16).Id
                );
                totalLinesAmount += (tempLine.Amount__c).setScale(2, System.RoundingMode.HALF_UP);
                newPayableLines.add(tempLine);
            }

            AccountPayableLineActions.isBypassGLAccountValidations = true;
            insert newPayableLines;
            AccountPayableLineActions.isBypassGLAccountValidations = false;
        }

        System.runAs(testData.users.get(1)) {
            
            List<Account_Payable__c> newPayables = [SELECT Id FROM Account_Payable__c];
            //Post Payables
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(newPayables);
            System.assertEquals(50, postResults.size());
            System.assertEquals(true, postResults.get(0).isSuccess, 'Post Result Error: ' + postResults.get(0).errors);

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> paymentResults = paymentHandler.init(newPayables, true, false);

            System.assertEquals(50, paymentResults.size());

            paymentHandler.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
            paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;

            for (CashDisbursementWrapper cdw : paymentHandler.wrappedCDs) {
                cdw.cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
                cdw.cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            }

            paymentHandler.paymentResultDispatcher.clearResultsMap();
            paymentResults = paymentHandler.pay(true);

            Test.stopTest();
            List<Cash_Disbursement__c> newCDs = [
                SELECT Id, Amount__c, Cash_Disbursement_Batch__c, Status__c
                FROM Cash_Disbursement__c
                WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id
            ];
            System.assertEquals(50, newCDs.size());
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, newCDs.get(0).Status__c);

            Cash_Disbursement_Batch__c cdBatch = [
                SELECT Id, Batch_Amount__c
                FROM Cash_Disbursement_Batch__c
                WHERE Id = :newCDs[0].Cash_Disbursement_Batch__c
                LIMIT 1
            ];
            System.assertEquals(totalLinesAmount, cdBatch.Batch_Amount__c);
        }
    }

    private static Decimal getRandomDecimal(Integer scaleTo) {
        Decimal randomDecimal = (Decimal) Math.random();
        return randomDecimal.setScale(scaleTo, System.RoundingMode.HALF_UP);
    }

    @isTest
    private static void testInitWithNotPostedRecordsInList() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c testAP = testData.payables.get(0);
            testAP.Status__c = 'Approved';
            update testAP;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP})) {
                System.assertEquals(true, result.isSuccess);
            }

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> results = paymentHandler.init(testData.payables, true, true);

            Test.stopTest();

            System.assertEquals(false, paymentHandler.paymentResultDispatcher.isGeneralErrorExists());

            Integer successCounter = 0;
            for (PaymentResult pr : results) {
                if (pr.isSuccess) {
                    successCounter++;
                }
            }
            System.assertEquals(1, successCounter);
        }
    }

    @isTest
    private static void testPayWithoutProjectTaskInRelatedProject() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createProjects()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c testAP = testData.payables.get(0);

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP})) {
                System.assertEquals(true, result.isSuccess);
            }

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> results = paymentHandler.init(new List<Account_Payable__c>{testAP}, true, true);
            System.assertEquals(false, paymentHandler.paymentResultDispatcher.isGeneralErrorExists());

            paymentHandler.wrappedCDs.get(0).cashDisbursement.Project__c = testData.projects.get(0).Id;
            paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);

            List<PaymentResult> payResults = paymentHandler.pay(false);

            Test.stopTest();

            System.assertEquals(null, paymentHandler.wrappedCDs.get(0).cashDisbursement.Project_Task__c);
            System.assertEquals(true, paymentHandler.paymentResultDispatcher.isGeneralErrorExists());

            System.assertEquals(
                PaymentResult.StatusCode.SYSTEM_EXCEPTION,
                payResults.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testAccountPayablePayBatchNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Account_Payable__c> testAccountPayables = new List<Account_Payable__c>{
                testData.payables.get(0),
                testData.payables.get(1),
                testData.payables.get(2)
            };

            for (PostResult result : AccountPayablePostService.postAccountPayables(testAccountPayables)) {
                System.assertEquals(true, result.isSuccess);
            }

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController([
                SELECT Id, Total__c, Payment_Status__c, Contact__c, Vendor__c, Employee__c
                FROM Account_Payable__c
                WHERE Id IN :testData.payables
            ]);

            AccountPayablePayBatch apb = new AccountPayablePayBatch(setController);

            Test.stopTest();

            System.assert(true, apb.isError);
        }
    }

    @isTest
    private static void testPayBatchDiscountAmountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
		Accounting_Settings__c settings = testData.settings;
        settings.Cash_Disbursement_Source__c = 'Payable';
        update settings;
        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c testAP = testData.payables.get(0);
            testAP.Status__c = 'Approved';
            testAP.Discount_Amount__c = 10;
            update testAP;

            PostResult postResult = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP}).get(0);

            System.assertEquals(true, postResult.isSuccess);

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();

            List<PaymentResult> paymentResults = paymentHandler.init(new List<Account_Payable__c>{testAP}, true, true);

            System.assertEquals(true, paymentResults.get(0).isSuccess);

            paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            paymentHandler.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;

            paymentHandler.paymentResultDispatcher.clearResultsMap();
            paymentResults = paymentHandler.pay(false);

            Test.stopTest();

            System.assertEquals(true, paymentResults.get(0).isSuccess);

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id]
            );

            System.assertEquals(
                paymentHandler.accountPayables.get(0).Total__c - paymentHandler.accountPayables.get(0).Discount_Amount__c,
                [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id].Amount__c
            );
        }
    }

    @isTest
    private static void testPayBatchDiscountAmountAfterCMAppliedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c testAcctPeriod = new Accounting_Period__c(
                Name = '2021-01',
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(28),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            insert testAcctPeriod;

            Account testAccount = testData.accounts[0];
            testAccount.Discount_Percent__c = 10;
            testAccount.Discount_Days_Due__c = 100;
            update testAccount;

            Account_Payable__c testAP = [SELECT Type__c, Paid_Amount__c, Vendor__c, Accounting_Period__c, Date__c, Due_Date__c, 
                                                Vendor__r.Discount_Percent__c, Vendor__r.Discount_Days_Due__c
                                        FROM Account_Payable__c 
                                        WHERE Id = :testData.payables.get(0).Id 
                                        LIMIT 1];
            testAP.Accounting_Period__c = testAcctPeriod.Id;
            testAP.Date__c = Date.today();
            testAP.Due_Date__c = Date.today().addDays(1);
            update testAP;

            PostResult postResult = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP}).get(0);
            System.assertEquals(true, postResult.isSuccess);

            AP_Credit_Memo__c creditMemo = new AP_Credit_Memo__c();
            creditMemo.Account_Payable_Invoice__c = testData.payables[0].Id;
            creditMemo.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            creditMemo.Accounting_Period__c = testAcctPeriod.Id;
            creditMemo.Amount__c = -20;

            insert creditMemo;
  
            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            System.assertEquals(true, paymentHandler.isVendorDiscountApplicable(testAP));

            List<PaymentResult> paymentResults = paymentHandler.init(new List<Account_Payable__c>{testAP}, true, true);
            System.assertEquals(true, paymentResults.get(0).isSuccess);
            System.assertEquals(14.50, paymentHandler.accountPayables.get(0).Discount_Amount__c);

            paymentResults = paymentHandler.pay(false);

            Test.stopTest();

            System.assertEquals(true, paymentResults.get(0).isSuccess);
           
        }
    }

    @isTest
    private static void testPayBatch1099VendorSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account acct = testData.accounts[0];
            acct.X1099_Vendor__c = true;
            Id formTypeId = [SELECT Id, Effective_Year__c FROM Form_Type__mdt WHERE Effective_Year__c <= :Date.today().Year() ORDER BY Effective_Year__c DESC LIMIT 1].Id;
            acct.Default_Form_Category_Id__c = [SELECT Id from Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;
            update acct;

            Account_Payable__c testAP = testData.payables.get(0);

            PostResult postResult = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP}).get(0);

            System.assertEquals(true, postResult.isSuccess);

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();

            List<PaymentResult> paymentResults = paymentHandler.init(new List<Account_Payable__c>{testAP}, true, true);

            System.assertEquals(true, paymentResults.get(0).isSuccess);

            paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            paymentHandler.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;

            paymentHandler.paymentResultDispatcher.clearResultsMap();
            paymentResults = paymentHandler.pay(false);

            Test.stopTest();

            System.assertEquals(true, paymentResults.get(0).isSuccess);

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id]
            );

            System.assertEquals(
                acct.Default_Form_Category_Id__c,
                [SELECT Id, Form_Category_Id__c FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id].Form_Category_Id__c
            );
        }
    }

    @isTest
    private static void testPayBatch1099ContactSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Contact cont = testData.contacts[0];
            cont.X1099_Vendor__c = true;
            Id formTypeId = [SELECT Id, Effective_Year__c FROM Form_Type__mdt WHERE Effective_Year__c <= :Date.today().Year() ORDER BY Effective_Year__c DESC LIMIT 1].Id;
            cont.Default_Form_Category_Id__c = [SELECT Id from Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;
            update cont;

            Account_Payable__c testAP = testData.payables.get(1);

            PostResult postResult = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP}).get(0);

            System.assertEquals(
                true,
                postResult.isSuccess
            );

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();

            List<PaymentResult> paymentResults = paymentHandler.init(new List<Account_Payable__c>{testAP}, true, true);

            System.assertEquals(
                true,
                paymentResults.get(0).isSuccess
            );

            paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).Start_Date__c.addDays(3);
            paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;
            paymentHandler.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;

            paymentHandler.paymentResultDispatcher.clearResultsMap();
            paymentResults = paymentHandler.pay(false);

            Test.stopTest();

            System.assertEquals(
                true,
                paymentResults.get(0).isSuccess
            );

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id]
            );

            System.assertEquals(
                cont.Default_Form_Category_Id__c,
                [SELECT Id, Form_Category_Id__c FROM Cash_Disbursement__c WHERE Cash_Disbursement_Batch__c = :paymentHandler.cashDisbursementBatchToInsert.Id].Form_Category_Id__c
            );
        }
    }

    @isTest
    private static void testInitForAlreadyPaidRecord() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        Test.startTest();
        Accounting_Settings__c settings = testData.settings;
        settings.Cash_Disbursement_Source__c = 'Payable';
        update settings;
        
        testData.createPayables(true);
        testData.createCashDisbursementBatches();
        testData.createCashDisbursements();
        testData.createApDisbursements();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c testAP = [
                SELECT Id, Status__c, Net_Amount__c, Payment_Status__c, Balance__c, Paid_Amount__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(7).Id LIMIT 1
            ];
            
            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> results = paymentHandler.init(new List<Account_Payable__c>{testAP}, true, true);

            System.assertEquals(
                true,
                paymentHandler.paymentResultDispatcher.isGeneralErrorExists()
            );
            System.assertEquals(
                PaymentResult.StatusCode.ALREADY_PAID,
                results.get(0).errors.get(0).statusCode
            );
        }
        Test.stopTest();
    }

    @isTest
    private static void testPayBatchWithDifferentLedgersSelect() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<Account_Payable__c> testAPs = new List<Account_Payable__c>();

            Account_Payable__c testPayable1 = testData.payables.get(2);
            testAPs.add(testPayable1);
            Account_Payable__c testPayable2 = testData.payables.get(3);
            testAPs.add(testPayable2);

            List<PostResult> postResult = AccountPayablePostService.postAccountPayables(testAPs);

            System.assertEquals(true, postResult.get(0).isSuccess);

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> paymentResults = paymentHandler.init(testAPs, true, true);

            System.assertEquals(true, paymentResults.get(0).isSuccess);

            paymentHandler.paymentResultDispatcher.clearResultsMap();
            System.assertEquals(1, paymentHandler.wrappedCDs.size());

            testPayable1 = [SELECT Id, Status__c, Ledger__c FROM Account_Payable__c WHERE Id = :testPayable1.Id];
            testPayable2 = [SELECT Id, Status__c, Ledger__c FROM Account_Payable__c WHERE Id = :testPayable2.Id];

            testPayable1.Ledger__c = testData.ledgers.get(0).Id;
            testPayable2.Ledger__c = testData.ledgers.get(2).Id;

            List<Account_Payable__c> testAP2 = new List<Account_Payable__c>{
                testPayable1, testPayable2
            };

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{Account_Payable__c.Ledger__c}
            );
            update testAP2;

            AccountPayablePaymentHandler paymentHandler2 = new AccountPayablePaymentHandler();
            List<PaymentResult> paymentResults2 = paymentHandler2.init(testAP2, true, true);

            Test.stopTest();

            System.assertEquals(
                true,
                paymentHandler2.paymentResultDispatcher.isGeneralErrorExists()
            );

            System.assertEquals(
                PaymentResult.StatusCode.NOT_SAME_LEDGER,
                paymentResults2.get(0).errors.get(0).statusCode
            );
        }
    }

    @isTest
    private static void testGetGLAccounts() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            Map<Id, GL_Account__c> glAccountsMap = new Map<Id, GL_Account__c>(DomainUtils.getBankGlAccounts());
            for (SelectOption glAcct : paymentHandler.getGLAccounts()) {
                System.assertEquals(true, glAccountsMap.containsKey(glAcct.getValue()));
            }
            Test.stopTest();
        }
    }

    @isTest
    private static void testGetForm1099Types() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Account_Payable__c> testAPs = new List<Account_Payable__c>();

            Account_Payable__c testPayable1 = testData.payables.get(2);
            testAPs.add(testPayable1);
            Account_Payable__c testPayable2 = testData.payables.get(3);
            testAPs.add(testPayable2);

            List<PostResult> postResult = AccountPayablePostService.postAccountPayables(testAPs);

            System.assertEquals(true, postResult.get(0).isSuccess);

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> paymentResults = paymentHandler.init(testAPs, true, true);

            System.assertEquals(true, paymentResults.get(0).isSuccess);

            paymentHandler.paymentResultDispatcher.clearResultsMap();
            System.assertEquals(1, paymentHandler.wrappedCDs.size());

            Map<Id, Form_Type__mdt> formTypesMap = new Map<Id, Form_Type__mdt>([SELECT Id FROM Form_Type__mdt]);
            List<SelectOption> formTypes = paymentHandler.getForm1099Types();
            System.assertEquals('--'+ Label.COMMON_NONE +'--', formTypes[0].getLabel());
            for (Integer i = 1; i < formTypes.size(); i++) {
                System.assertEquals(true, formTypesMap.containsKey(formTypes[i].getValue()));
            }
            Test.stopTest();
        }
    }

    @isTest
    private static void testGetForm1099Boxes() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Account_Payable__c> testAPs = new List<Account_Payable__c>();

            Account_Payable__c testPayable1 = testData.payables.get(2);
            testAPs.add(testPayable1);
            Account_Payable__c testPayable2 = testData.payables.get(3);
            testAPs.add(testPayable2);

            List<PostResult> postResult = AccountPayablePostService.postAccountPayables(testAPs);

            System.assertEquals(true, postResult.get(0).isSuccess);

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> paymentResults = paymentHandler.init(testAPs, true, true);

            System.assertEquals(true, paymentResults.get(0).isSuccess);

            paymentHandler.paymentResultDispatcher.clearResultsMap();
            System.assertEquals(1, paymentHandler.wrappedCDs.size());
            String formTypeId = [SELECT Id from Form_Type__mdt LIMIT 1].Id;
            Map<Id, Form_Category__mdt> formBoxesMap = new Map<Id, Form_Category__mdt>([SELECT Id FROM Form_Category__mdt WHERE Form_Type__c = :formTypeId]);
            paymentHandler.uiCashDisbursement.Form_Category_Id__c = formTypeId;
            
            List<SelectOption> formBoxes = paymentHandler.getForm1099Boxes();
            System.assertEquals('--'+ Label.COMMON_NONE +'--', formBoxes[0].getLabel());
            for (Integer i = 1; i < formBoxes.size(); i++) {
                System.assertEquals(true, formBoxesMap.containsKey(formBoxes[i].getValue()));
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetForm1099TypesPersonAccount() {
        if (TestDataSuite.isPersonAccountsEnabled()) {
            TestDataSuite testData = TestDataSuite.getInstance().createPersonAccounts().createPayables();

            System.runAs(testData.users[1]) {
                String accountId = testData.personAccounts[0].Id;
                Account acct = DataBase.query('SELECT Id, PersonContactId FROM Account WHERE Id = :accountId LIMIT 1');

                testData.payables.get(2).Employee__c = null;
                testData.payables.get(2).Contact__c = (Id) acct.get('PersonContactId');
                testData.payables.get(3).Employee__c = null;
                testData.payables.get(3).Contact__c = (Id) acct.get('PersonContactId');
                update testData.payables;

                Test.startTest();
                List<Account_Payable__c> testAPs = new List<Account_Payable__c>();

                Account_Payable__c testPayable1 = testData.payables.get(2);
                testAPs.add(testPayable1);
                Account_Payable__c testPayable2 = testData.payables.get(3);
                testAPs.add(testPayable2);

                List<PostResult> postResult = AccountPayablePostService.postAccountPayables(testAPs);

                System.assertEquals(true, postResult.get(0).isSuccess);

                AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
                List<PaymentResult> paymentResults = paymentHandler.init(testAPs, true, true);

                System.assertEquals(true, paymentResults.get(0).isSuccess);

                paymentHandler.paymentResultDispatcher.clearResultsMap();
                System.assertEquals(1, paymentHandler.wrappedCDs.size());

                Map<Id, Form_Type__mdt> formTypesMap = new Map<Id, Form_Type__mdt>([SELECT Id FROM Form_Type__mdt]);
                List<SelectOption> formTypes = paymentHandler.getForm1099Types();
                System.assertEquals('--'+ Label.COMMON_NONE +'--', formTypes[0].getLabel());
                for (Integer i = 1; i < formTypes.size(); i++) {
                    System.assertEquals(true, formTypesMap.containsKey(formTypes[i].getValue()));
                }
                Test.stopTest();
                System.assert(!ApexPages.hasMessages(ApexPages.SEVERITY.ERROR));
            }
        }
    }

    @IsTest
    private static void testGetForm1099BoxesPersonAccount() {
        if (TestDataSuite.isPersonAccountsEnabled()) {
            TestDataSuite testData = TestDataSuite.getInstance().createPersonAccounts().createPayables();

            System.runAs(testData.users[1]) {
                String accountId = testData.personAccounts[0].Id;
                Account acct = DataBase.query('SELECT Id, PersonContactId FROM Account WHERE Id = :accountId LIMIT 1');

                testData.payables.get(2).Employee__c = null;
                testData.payables.get(2).Contact__c = (Id) acct.get('PersonContactId');
                testData.payables.get(3).Employee__c = null;
                testData.payables.get(3).Contact__c = (Id) acct.get('PersonContactId');
                update testData.payables;

                Test.startTest();
                List<Account_Payable__c> testAPs = new List<Account_Payable__c>();

                Account_Payable__c testPayable1 = testData.payables.get(2);
                testAPs.add(testPayable1);
                Account_Payable__c testPayable2 = testData.payables.get(3);
                testAPs.add(testPayable2);

                List<PostResult> postResult = AccountPayablePostService.postAccountPayables(testAPs);

                System.assertEquals(true, postResult.get(0).isSuccess);

                AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
                List<PaymentResult> paymentResults = paymentHandler.init(testAPs, true, true);

                System.assertEquals(true, paymentResults.get(0).isSuccess);

                paymentHandler.paymentResultDispatcher.clearResultsMap();
                System.assertEquals(1, paymentHandler.wrappedCDs.size());
                String formTypeId = [SELECT Id from Form_Type__mdt LIMIT 1].Id;
                Map<Id, Form_Category__mdt> formBoxesMap = new Map<Id, Form_Category__mdt>([SELECT Id FROM Form_Category__mdt WHERE Form_Type__c = :formTypeId]);
                paymentHandler.uiCashDisbursement.Form_Category_Id__c = formTypeId;

                List<SelectOption> formBoxes = paymentHandler.getForm1099Boxes();
                System.assertEquals('--'+ Label.COMMON_NONE +'--', formBoxes[0].getLabel());
                for (Integer i = 1; i < formBoxes.size(); i++) {
                    System.assertEquals(true, formBoxesMap.containsKey(formBoxes[i].getValue()));
                }
                Test.stopTest();
            }
        }
    }

    @isTest
    private static void testPayWithSoftClose() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c testAP = testData.payables.get(0);
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            
            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testAP})) {
                System.assertEquals(true, result.isSuccess);
            }

            AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
            List<PaymentResult> results = paymentHandler.init(new List<Account_Payable__c>{testAP}, true, true);
            System.assertEquals(false, paymentHandler.paymentResultDispatcher.isGeneralErrorExists());

            paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testAccountingPeriod.Start_Date__c.addDays(3);

            
            testAccountingPeriod.Close_AP__c = true;
            update testAccountingPeriod;

            List<PaymentResult> payResults = paymentHandler.pay(false);

            Test.stopTest();

            System.assertEquals(true, paymentHandler.paymentResultDispatcher.isGeneralErrorExists());

            System.assertEquals(
                PaymentResult.StatusCode.NON_VALID_ACCOUNTING_PERIOD,
                paymentHandler.paymentResultDispatcher.getPaymentResults().get(0).errors.get(0).statusCode
            );
        }
    }

	@isTest 
    private static void testSourceFieldForManualAccountingSetting() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        Accounting_Settings__c settings = testData.settings;
        settings.Cash_Disbursement_Source__c = 'Manual';
        update settings;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
                List<Account_Payable__c> newPayables = new List<Account_Payable__c>();
                for (Integer i = 0; i < 2; i++) {
                    Account_Payable__c tempPayable = new Account_Payable__c(
                        Payee_Reference__c = 'ref' + i,
                        Status__c = 'Approved',
                        Payment_Status__c = 'Unpaid',
                        Date__c = testData.acctPeriods.get(0).Start_Date__c,
                        Due_Date__c = testData.acctPeriods.get(0).End_Date__c,
                        Vendor__c = testData.accounts.get(0).Id,
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Currency_Conversion_Rate__c = 1 + getRandomDecimal(2),
                        Ledger__c = testData.ledgers[0].Id
                    );
                    newPayables.add(tempPayable);
                }
                insert newPayables;

                List<Account_Payable_Line__c> newPayableLines = new List<Account_Payable_Line__c>();

                Decimal totalLinesAmount = 0;
                for (Account_Payable__c payable : newPayables) {
                    Account_Payable_Line__c tempLine = new Account_Payable_Line__c(
                        Account_Payable__c = payable.Id,
                        Amount__c = getRandomDecimal(2) * 100 + getRandomDecimal(5) + 10,//amount template
                        Date__c = testData.acctPeriods.get(0).Start_Date__c,
                        Expense_GL_Account__c = testData.glAccounts.get(16).Id
                    );
                    newPayableLines.add(tempLine);
                }
                insert newPayableLines;

                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(newPayables);
                System.assertEquals(true, postResults.get(0).isSuccess);

                AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
                List<PaymentResult> paymentResults = paymentHandler.init(newPayables, true, true);
                paymentHandler.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
                paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;

                paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
                paymentHandler.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
                paymentHandler.wrappedCDs.get(0).cashDisbursement.Currency_Conversion_Rate__c = 1 + getRandomDecimal(2);

                paymentHandler.paymentResultDispatcher.clearResultsMap();
                paymentResults = paymentHandler.pay(true);

                Cash_Disbursement__c newCD = [SELECT Id, Amount__c,Source__c FROM Cash_Disbursement__c LIMIT 1];

                System.assertEquals('Manual', newCD.Source__c);

            Test.stopTest();
        }
    }

    @isTest 
    private static void testSourceFieldForPayableAccountingSetting() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        Accounting_Settings__c settings = testData.settings;
        settings.Cash_Disbursement_Source__c = 'Payable';
        update settings;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
                List<Account_Payable__c> newPayables = new List<Account_Payable__c>();
                for (Integer i = 0; i < 2; i++) {
                    Account_Payable__c tempPayable = new Account_Payable__c(
                        Payee_Reference__c = 'ref' + i,
                        Status__c = 'Approved',
                        Payment_Status__c = 'Unpaid',
                        Date__c = testData.acctPeriods.get(0).Start_Date__c,
                        Due_Date__c = testData.acctPeriods.get(0).End_Date__c,
                        Vendor__c = testData.accounts.get(0).Id,
                        Accounting_Period__c = testData.acctPeriods.get(0).Id,
                        Currency_Conversion_Rate__c = 1 + getRandomDecimal(2),
                        Ledger__c = testData.ledgers[0].Id
                    );
                    newPayables.add(tempPayable);
                }
                insert newPayables;

                List<Account_Payable_Line__c> newPayableLines = new List<Account_Payable_Line__c>();

                Decimal totalLinesAmount = 0;
                for (Account_Payable__c payable : newPayables) {
                    Account_Payable_Line__c tempLine = new Account_Payable_Line__c(
                        Account_Payable__c = payable.Id,
                        Amount__c = getRandomDecimal(2) * 100 + getRandomDecimal(5) + 10,//amount template
                        Date__c = testData.acctPeriods.get(0).Start_Date__c,
                        Expense_GL_Account__c = testData.glAccounts.get(16).Id
                    );
                    newPayableLines.add(tempLine);
                }
                insert newPayableLines;

                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(newPayables);
                System.assertEquals(true, postResults.get(0).isSuccess);

                AccountPayablePaymentHandler paymentHandler = new AccountPayablePaymentHandler();
                List<PaymentResult> paymentResults = paymentHandler.init(newPayables, true, true);
                paymentHandler.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
                paymentHandler.uiCashDisbursement.Bank_Account__c = testData.glAccounts.get(0).Id;

                paymentHandler.wrappedCDs.get(0).cashDisbursement.Disbursement_Date__c = testData.acctPeriods.get(0).End_Date__c;
                paymentHandler.wrappedCDs.get(0).cashDisbursement.Accounting_Period__c = testData.acctPeriods.get(0).Id;
                paymentHandler.wrappedCDs.get(0).cashDisbursement.Currency_Conversion_Rate__c = 1 + getRandomDecimal(2);

                paymentHandler.paymentResultDispatcher.clearResultsMap();
                paymentResults = paymentHandler.pay(true);

                Cash_Disbursement__c newCD = [SELECT Id, Amount__c,Source__c FROM Cash_Disbursement__c LIMIT 1];

                System.assertEquals('Payable', newCD.Source__c);

            Test.stopTest();
        }
    }
}