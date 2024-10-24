@IsTest
private class CashDisbursementVoidTest {

    @IsTest
    private static void testCashDisbursementVoidWithContactMapping() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createCashDisbursementBatches();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            Account testAccount = testData.accounts[0];
            Accounting_Period__c testAcctPeriod = currentPeriod;
            Contact testContact = testData.contacts[0];
            GL_Account__c testBankGlAccount = [SELECT Id FROM GL_Account__c WHERE Bank__c = true LIMIT 1];
            Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[0];

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testCDB.Id,
                Disbursement_Date__c = testAcctPeriod.Start_Date__c,
                Type__c = 'Check',
                Amount__c = 12,
                Source__c = 'Payable',
                Bank_Account__c = testBankGlAccount.Id,
                Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                Contact__c = testContact.Id,
                Accounting_Period__c = testAcctPeriod.Id,
                Status__c = 'Approved',
                Reference__c = 'the-ref-xxx',
                Cash_Flow_Category__c = testData.cashFlowCategories[1].Id
            );

            CashDisbursementActions.isSourcedFromPayables = true;
            insert testCD;
            CashDisbursementActions.isSourcedFromPayables = false;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(true, postResults[0].isSuccess);

            List<Transaction__c> controlledTrans = [
                SELECT Id, Contact__c
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testCD.Id
            ];

            System.assertEquals(false, controlledTrans.isEmpty());
            System.assertEquals(testCD.Contact__c, controlledTrans[0].Contact__c);

            ApexPages.StandardController stdController = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(stdController);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.voidCashDisbursement();

            List<Transaction__c> voidedTrans = [
                SELECT Id, Contact__c
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Id NOT IN :controlledTrans
            ];

            System.assertEquals(2, voidedTrans.size());
        }
    }

    @IsTest
    private static void testCashDisbursementVoidIsNotPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users[1]) {
            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[5].Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.voidCashDisbursement();

            System.assertEquals(CashDisbursementVoid.POSTED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    private static void testDeleteCashDisbursementVoidUpdateAPStatus() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            Account_Payable__c testAccountPayable = testData.payables[5];
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;
            
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            System.assertEquals(
                'Paid', [
                    SELECT Payment_Status__c
                    FROM Account_Payable__c
                    WHERE Id = :testAccountPayable.Id
                ].Payment_Status__c
            );
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);// +1 Discount line
            //Query AP Disbursement record created after Payable pay process
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.cashDisbursementVoid.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            cdv.voidCashDisbursement();

            System.assertEquals(
                'Unpaid', [
                    SELECT Payment_Status__c
                    FROM Account_Payable__c
                    WHERE Id = :testAccountPayable.Id].Payment_Status__c
            );
        }
    }

    @IsTest
    private static void testCashDisbursementIsVoidError() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        Test.startTest();
        testData.createCashFlowCategories(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Account_Payable__c testAccountPayable = testData.payables[5];

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true, false, false);
            testCD.Disbursement_Date__c = currentPeriod.Start_Date__c;
            testCD.Accounting_Period__c = currentPeriod.Id;
            testCD.Cash_Flow_Category__c = testData.cashFlowCategories[1].Id;
            insert testCD;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, postResults[0].isSuccess);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.voidCashDisbursement();

            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            cdv = new CashDisbursementVoid(controller);
            System.assertEquals(CashDisbursementVoid.VOIDED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }
        Test.stopTest();
    }

    @IsTest
    private static void testCashDisbursementVoidClosedAccountingPeriodSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        Test.startTest();
        testData.createCashFlowCategories(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true, false, false);
            testCD.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
            testCD.Accounting_Period__c = testData.acctPeriods[1].Id;
            testCD.Cash_Flow_Category__c = testData.cashFlowCategories[1].Id;
            insert testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController([
                    SELECT  Id,
                            Status__c,
                            Disbursement_Date__c,
                            Payment_Status__c,
                            Accounting_Period__c,
                            Type__c,
                            Bank_Account__c,
                            Amount__c,
                            Vendor__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testCD.Id
            ]);

            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(3);
            cdv.voidCashDisbursement();

            System.assertEquals(
                4, [
                    SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id
                ]
            );

            System.assertEquals(
                'Void', [
                    SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id
                ].Payment_Status__c
            );

            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );

            Test.stopTest();
        }

    }

    @IsTest
    private static void testCashDisbursementVoidToEarlyVoidedDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        Test.startTest();
        testData.createCashFlowCategories(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true, false, false);
            testCD.Disbursement_Date__c = testData.acctPeriods[2].Start_Date__c.addDays(10);
            testCD.Accounting_Period__c = testData.acctPeriods[2].Id;
            testCD.Cash_Flow_Category__c = testData.cashFlowCategories[1].Id;
            insert testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT  Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, postResults[0].isSuccess);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(5);
            cdv.voidCashDisbursement();

            System.assertEquals(
                String.format(CashDisbursementVoid.TOO_EARLY_VOIDED_DATE, new List<String>{testData.acctPeriods[2].Start_Date__c.format()}),
                ApexPages.getMessages()[0].getSummary()
            );
        }
        Test.stopTest();
    }

    @IsTest
    private static void testCashDisbursementVoidToNoExistedAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        Test.startTest();
        testData.createCashFlowCategories(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true, false, false);
            testCD.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
            testCD.Accounting_Period__c = testData.acctPeriods[1].Id;
            testCD.Cash_Flow_Category__c = testData.cashFlowCategories[1].Id;
            insert testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT  Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, postResults[0].isSuccess);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Disbursement_Date__c = System.today().addDays(356);
            cdv.voidCashDisbursement();

            System.assertEquals(
                CashDisbursementVoid.NO_PERIOD_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getSummary()
            );
        }
        Test.stopTest();
    }

    @IsTest
    private static void testCashDisbursementVoidBankReconciliationClearedError() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankReconciliations();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Cash_Disbursement__c testCD = testData.cashDisbursements[5];
            testCD.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            testCD.Cleared_Date__c = System.today();
            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Reconciliation__c);
            update testCD;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, postResults[0].isSuccess);

            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.voidCashDisbursement();

            System.assertEquals(CashDisbursementVoid.CLEARED_ERROR_MESSAGE, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    private static void testCashDisbursementVoidMatchedWithBankTransactionError() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            //update CDs to have applicable amounts
            List<Cash_Disbursement__c> testCDs = [
                SELECT Id, Amount__c
                FROM Cash_Disbursement__c
                WHERE Bank_Account__c = :testData.glAccounts.get(0).Id
            ];
            for (Cash_Disbursement__c cd : testCDs) {
                cd.Amount__c = testData.bankTransactions.get(1).Amount__c;
            }
            update testCDs;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(testCDs);
            System.assertEquals(true, postResults[0].isSuccess);

            Test.startTest();
            //match CDs
            BankTransactionsMatcher matcher = new BankTransactionsMatcher(
                testData.bankTransactions,
                BankTransactionsMatcher.ExecutionContext.APEX_JOB
            );
            matcher.searchMatchingRecords();
            System.assertEquals(true, matcher.hasMatchingRecords(testData.bankTransactions.get(1).Id));
            System.assertEquals(5, matcher.getMatchingRecords(testData.bankTransactions.get(1).Id).size());
            //Accept matching records
            Map<Id, SObject> btIdToSourceDocRecord = new Map<Id, SObject>{
                testData.bankTransactions.get(1).Id => matcher.getMatchingRecords(testData.bankTransactions.get(1).Id).get(0)
            };
            Map<Id, Bank_Transaction__c> allBTs = new Map<Id, Bank_Transaction__c>{
                testData.bankTransactions.get(1).Id => testData.bankTransactions.get(1)
            };

            List<ServiceResult> results = BankTransactionsHelper.acceptMatchingRecord(btIdToSourceDocRecord, allBTs);
            System.assertEquals(true, results[0].isSuccess);

            Bank_Transaction__c bt = [SELECT Id, Name FROM Bank_Transaction__c WHERE Id = :testData.bankTransactions.get(1).Id];
            Cash_Disbursement__c cd = [SELECT Id FROM Cash_Disbursement__c WHERE Bank_Transaction__c = :bt.Id];
            //Test initial load of the page
            ApexPages.StandardController controller = new ApexPages.StandardController(cd);
            //Invoke page's constructor
            new CashDisbursementVoid(controller);
            //Check error message on the page load
            System.assertEquals(
                String.format(
                    CashDisbursementVoid.ASSOCIATED_WITH_BANK_TRANSACTION_ERROR_MESSAGE,
                    new List<String>{bt.Name}
                ),
                ApexPages.getMessages()[0].getSummary()
            );
        }
    }

    @IsTest
    private static void testClearAPsClosedAccountingPeriodAfterCDVoid() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable__c testAccountPayable = testData.payables[5];
            
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
                        
            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            System.assertEquals(
                'Paid',
                [SELECT Payment_Status__c FROM Account_Payable__c WHERE Id = :testAccountPayable.Id].Payment_Status__c
            );
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            //Query AP Disbursement record created after Payable pay process
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.cashDisbursementVoid.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            cdv.voidCashDisbursement();

            Account_Payable__c checkedAP = [
                SELECT Id, Closed_Accounting_Period__c, Payment_Status__c
                FROM Account_Payable__c
                WHERE Id = :testAccountPayable.Id
            ];

            System.assertEquals('Unpaid', checkedAP.Payment_Status__c);
            System.assertEquals(NULL, checkedAP.Closed_Accounting_Period__c);
        }
    }

    @IsTest
    private static void testCashDisbursementVoidCashFlowStatementNoCashFlowCategory() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(false)
            .createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable__c testAccountPayable = testData.payables[5];
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            
            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);// + 1 discount line

            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c,
                        Cash_Flow_Category__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            System.assertEquals(NULL, controller.getRecord().get('Cash_Flow_Category__c'));

            testData.settings.Enable_Cash_Flow_Statement__c = true;
            update testData.settings;

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            cdv.voidCashDisbursement();

            System.assertEquals(
                3, [
                SELECT count()
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Cash_Flow_Category__c = :testData.cashFlowCategories[0].Id
            ]);
        }
    }

    @IsTest
    private static void testCashDisbursementVoidCashFlowStatementCashFlowCategory() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();

            Account_Payable__c testAccountPayable = testData.payables[5];
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();

            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);//+ 1 Discount line

            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c,
                        Cash_Flow_Category__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            System.assertNotEquals(NULL, controller.getRecord().get('Cash_Flow_Category__c'));

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Cash_Flow_Category__c = testData.cashFlowCategories[1].Id;
            cdv.voidCashDisbursement();

            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id AND Cash_Flow_Category__c != NULL]);
        }
    }

    @IsTest
    private static void testCashDisbursementVoidSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createPayables(false);

        Accounting_Settings__c settings = testData.settings;
        settings.Cash_Disbursement_Source__c = 'Payable';
        update settings;

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable__c testAccountPayable = testData.payables[5];
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            
            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);// +1 discount line
            //Query AP Disbursement record created after Payable pay process
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.voidCashDisbursement();

            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            System.assertEquals(
                'Void',
                [SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Payment_Status__c
            );
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );
            System.assertEquals(
                'Void Reason', [
                    SELECT Void_Description__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testCD.Id
                ].Void_Description__c
            );

            apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];

            System.assertEquals(2, apDisbursements.size());
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE AP_Disbursement__c IN :apDisbursements]);
        }
    }

    @IsTest
    private static void testCashDisbursementVoidDiscountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable__c testAccountPayable = testData.payables[5];
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            
            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            //Query AP Disbursement record created after Payable pay process
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.cashDisbursementVoid.Cash_Flow_Category__c = testData.cashFlowCategories[0].Id;
            cdv.voidCashDisbursement();

            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            System.assertEquals('Void', [SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Payment_Status__c);
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );
            System.assertEquals(
                'Void Reason', [
                    SELECT Void_Description__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testCD.Id
                ].Void_Description__c
            );

            apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];

            System.assertEquals(2, apDisbursements.size());
        }
    }

    @IsTest
    private static void testCashDisbursementVoidPeriodGapSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        testData.createCashFlowCategories(true)
            .createPayables(true);
        Test.startTest();

        System.runAs(testData.users[1]) {
            Account_Payable__c testAccountPayable = testData.payables[1];
            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            //pay it in the next period
            payController.uiCashDisbursement.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            //Query AP Disbursement record created after Payable pay process
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            //void it in period 3
            cdv.cashDisbursementVoid.Disbursement_Date__c = testData.acctPeriods[3].Start_Date__c;
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.voidCashDisbursement();

            //set the 4 periods to closed to kick off the AP Aging History records
            List<Accounting_Period__c> periodsToClose = new List<Accounting_Period__c>();
            for (Integer i = 0; i < 4; i++) {
                testData.acctPeriods[i].Status__c = AccountingPeriodActions.CLOSED_STATUS;
                periodsToClose.add(testData.acctPeriods[i]);
            }
            update periodsToClose;

            Test.stopTest();

            Account_Payable__c payable = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testAccountPayable.Id LIMIT 1];
            List<AP_Aging_History__c> agingHistories = [
                SELECT Id, Amount__c, Account_Payable__c, Accounting_Period__c
                FROM AP_Aging_History__c
                WHERE Account_Payable__c = :payable.Id
                ORDER BY Accounting_Period__r.Name ASC
            ];
            System.assertEquals(3, agingHistories.size());
            // period 0
            System.assertEquals(payable.Total__c, agingHistories[0].Amount__c);
            System.assertEquals(testData.acctPeriods[0].Id, agingHistories[0].Accounting_Period__c);
            // period 1 - paid disbursement
            System.assertEquals(testData.acctPeriods[1].Id, agingHistories[1].Accounting_Period__c);
            System.assertEquals(0, agingHistories[1].Amount__c);
            // period 2 - Gap period as payable is fully paid and no history record created
            
            // period 3 - cash disb voided in this period and payable is not paid
            System.assertEquals(testData.acctPeriods[3].Id, agingHistories[2].Accounting_Period__c);
            System.assertEquals(payable.Total__c, agingHistories[2].Amount__c);
        }
    }

    @IsTest
    private static void testCashDisbursementWrongCashFlowType() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        Test.startTest();
        testData.createCashFlowCategories(true)
            .createPayables(true)
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users[1]) {
            Account_Payable__c testAccountPayable = testData.payables[5];

            Cash_Disbursement__c testCD = testData.cashDisbursements[5].clone(false, true, false, false);
            testCD.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
            testCD.Accounting_Period__c = testData.acctPeriods[1].Id;
            insert testCD;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});
            System.assertEquals(true, postResults[0].isSuccess);

            testCD = [SELECT  Id, Cash_Flow_Category__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id];
            testCD.Cash_Flow_Category__c = NULL;
            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Cash_Flow_Category__c);
            update testCD;

            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Cash_Flow_Category__c = testData.glAccounts[2].Id;
            cdv.voidCashDisbursement();

            System.assertEquals(CashDisbursementVoid.CASH_FLOW_ERROR, ApexPages.getMessages()[0].getSummary());
        }
        Test.stopTest();
    }

    @IsTest
    private static void testCashDisbursementVoidWhenPartiallyPaidSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createPayables(false);

            Accounting_Settings__c settings = testData.settings;
            settings.Cash_Disbursement_Source__c = 'Payable';
            update settings;

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable__c testPayableCreditMemo = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :testData.payables[4].Id];
            Account_Payable__c testPayableInvoice = testData.payables[5];
            testPayableInvoice.Discount_Amount__c = 2;
            update testPayableInvoice;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            //Partially apply Credit Memo to Invoice
            AP_Credit_Memo__c apCreditMemo = new AP_Credit_Memo__c(
                Accounting_Period__c = currentPeriod.Id,
                Account_Payable_Credit_Memo__c = testPayableCreditMemo.Id,
                Account_Payable_Invoice__c = testPayableInvoice.Id,
                Amount__c = testPayableCreditMemo.Total__c
            );
            insert apCreditMemo;

            //Check that Credit Memo was applied to Invoice as expected
            testPayableInvoice = [SELECT Id, Total__c, Credit_Memo_Applied_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables[5].Id];
            System.assertEquals(Math.abs(testPayableCreditMemo.Total__c), testPayableInvoice.Credit_Memo_Applied_Amount__c);

            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testPayableInvoice)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);// +1 discount line
            //Query AP Disbursement record created after Payable pay process
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testPayableInvoice.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.voidCashDisbursement();

            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            System.assertEquals(
                'Void',
                [SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Payment_Status__c
            );
            System.assertEquals(
                0, [
                    SELECT SUM(Amount__c) sum
                    FROM Transaction__c
                    WHERE Cash_Disbursement__c = :testCD.Id
                    GROUP BY Cash_Disbursement__c
                ][0].get('sum')
            );
            System.assertEquals(
                'Void Reason', [
                    SELECT Void_Description__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testCD.Id
                ].Void_Description__c
            );

            apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testPayableInvoice.Id
            ];

            System.assertEquals(2, apDisbursements.size());
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE AP_Disbursement__c IN :apDisbursements]);
        }
    }

    @IsTest
    private static void testCashDisbursementVoidSuccessVoidedDate() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable__c testAccountPayable = testData.payables[5];
            testAccountPayable.Discount_Amount__c = 2;
            update testAccountPayable;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(testData.payables);
            System.assertEquals(true, postResults[0].isSuccess);

            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            
            //Pay this Payable
            AccountPayablePayPartial payController = new AccountPayablePayPartial(
                new ApexPages.StandardController(testAccountPayable)
            );
            payController.uiCashDisbursement.Disbursement_Date__c = currentPeriod.Start_Date__c;
            payController.payPartial();
            //Query new CD created after Payable pay process
            Cash_Disbursement__c testCD = [SELECT Id FROM Cash_Disbursement__c LIMIT 1];
            //Post this CD
            ApexPages.StandardController controller = new ApexPages.StandardController(testCD);
            CashDisbursementPost cdp = new CashDisbursementPost(controller);
            cdp.validateBeforePost();
            cdp.post();
            System.assertEquals(3, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);// +1 discount line
            //Query AP Disbursement record created after Payable pay process
            List<AP_Disbursement__c> apDisbursements = [
                SELECT Id
                FROM AP_Disbursement__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Account_Payable__c = :testAccountPayable.Id
            ];
            System.assertEquals(1, apDisbursements.size());

            //Void the CD
            controller = new ApexPages.StandardController([
                SELECT  Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__r.Status__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c,
                    Void_Date__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.voidCashDisbursement();

            System.assertEquals(6, [SELECT count() FROM Transaction__c WHERE Cash_Disbursement__c = :testCD.Id]);
            System.assertEquals(
                'Void',
                [SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Payment_Status__c
            );
            System.assertEquals(
                Date.today(), [
                    SELECT Void_Date__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testCD.Id
                ].Void_Date__c
            );
        }
    }

    @IsTest
    private static void testCashDisbursementVoidWithSoftCloseAR() {
        TestDataSuite testData = TestDataSuite.getInstance(true)
            .createCashFlowCategories(true)
            .createCashDisbursementBatches();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account testAccount = testData.accounts[0];
            
            Date newDate = Date.newInstance(1991, 10, 16);
            Accounting_Period__c testAcctPeriod = [SELECT Id, Close_AP__c, Start_Date__c FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS AND Start_Date__c < :newDate AND End_Date__c > :newDate];
           

            Contact testContact = testData.contacts[0];
            GL_Account__c testBankGlAccount = [SELECT Id FROM GL_Account__c WHERE Bank__c = true LIMIT 1];
            Cash_Disbursement_Batch__c testCDB = testData.cashDisbursementBatch[0];
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testCDB.Id,
                Disbursement_Date__c = testAcctPeriod.Start_Date__c,
                Type__c = 'Check',
                Amount__c = 12,
                Source__c = 'Payable',
                Bank_Account__c = testBankGlAccount.Id,
                Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
                Contact__c = testContact.Id,
                Accounting_Period__c = testAcctPeriod.Id,
                Status__c = 'Approved',
                Reference__c = 'the-ref-xxx',
                Cash_Flow_Category__c = testData.cashFlowCategories[1].Id
            );

            CashDisbursementActions.isSourcedFromPayables = true;
            insert testCD;
            CashDisbursementActions.isSourcedFromPayables = false;

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testCD});

            System.assertEquals(true, postResults[0].isSuccess);

            List<Transaction__c> controlledTrans = [
                SELECT Id, Contact__c
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testCD.Id
            ];

            System.assertEquals(false, controlledTrans.isEmpty());
            System.assertEquals(testCD.Contact__c, controlledTrans[0].Contact__c);

            //soft close the period after setup is complete
            testAcctPeriod.Close_AP__c = true;
            update testAcctPeriod;

            ApexPages.StandardController stdController = new ApexPages.StandardController([
                SELECT  Id,
                        Status__c,
                        Disbursement_Date__c,
                        Payment_Status__c,
                        Accounting_Period__r.Status__c,
                        Type__c,
                        Bank_Account__c,
                        Amount__c,
                        Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :testCD.Id
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(stdController);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.cashDisbursementVoid.Void_Date__c = Date.newInstance(1991, 10, 10);
            
            cdv.voidCashDisbursement();

            List<Transaction__c> voidedTrans = [
                SELECT Id, Contact__c
                FROM Transaction__c
                WHERE Cash_Disbursement__c = :testCD.Id
                AND Id NOT IN :controlledTrans
            ];

            System.assert(ApexPages.hasMessages(ApexPages.SEVERITY.ERROR));
            System.assertEquals(0, voidedTrans.size());
         
        }
    }


}