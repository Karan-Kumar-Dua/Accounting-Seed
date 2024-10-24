@IsTest
private class GLAccountCurrentBalanceControllerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {

            delete testData.acctPeriods;

            Date acctDate = System.today().addMonths(-5);//five months before today
            acctDate = Date.newInstance(acctDate.year(), acctDate.month(), 1);//set as first day of month
            List<Accounting_Period__c> newPeriods = new List<Accounting_Period__c>();

            for (Integer i = 0; i < 10; i++) {

                newPeriods.add(
                    new Accounting_Period__c(
                        Name =
                            String.valueOf(acctDate.year()) +
                                '-' +
                                (acctDate.month() > 9
                                    ? String.valueOf(acctDate.month())
                                    : '0' + String.valueOf(acctDate.month())),
                        Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                        End_Date__c = Date.newInstance(
                            acctDate.year(),
                            acctDate.month(),
                            Date.daysInMonth(acctDate.year(), acctDate.month())
                        ),
                        Status__c = AccountingPeriodActions.OPEN_STATUS
                    )
                );

                if (acctDate.month() == 12) {
                    acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
                }
                else {
                    acctDate = acctDate.addMonths(1);
                }
            }

            insert newPeriods;

            System.assertEquals(10, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS LIMIT 100]);
        }
    }

    @IsTest
    static void testGetCurrentBalance() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today());
            System.assertNotEquals(NULL, currentPeriod);
            System.assertNotEquals(NULL, currentPeriod.Id);

            //create Cash Receipt to have Financial Cubes created
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 500,
                Payment_Reference__c = '0000000999',
                Receipt_Date__c = currentPeriod.Start_Date__c,
                Accounting_Period__c = currentPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id
            );
            insert testCR;

            Test.startTest();
            GLAccountCurrentBalanceController.GLAccountCurrentBalanceSettings glAccountBalanceSettings =
                GLAccountCurrentBalanceController.getSettings(testData.glAccounts.get(0).Id);
            System.assertEquals(true, glAccountBalanceSettings.isFeatureAvailable);
            System.assertNotEquals(true, glAccountBalanceSettings.ledgers.isEmpty());
            System.assertEquals(false, glAccountBalanceSettings.singleLedger);
            System.assertEquals(true, glAccountBalanceSettings.singleCurrency);

            GLAccountCurrentBalanceController.GLAccountCurrentBalanceResult balanceResult =
                GLAccountCurrentBalanceController.getCurrentBalance(testData.glAccounts.get(0).Id, glAccountBalanceSettings.ledgers[0].Id);

            System.assertEquals(testCR.Amount__c, balanceResult.balance);
            System.assertEquals(MultiCurrencyHandler.CORPORATE_CURRENCY, balanceResult.currencyIsoCode);
            System.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, balanceResult.isMultiCurrencyOrganization);

            balanceResult =
                GLAccountCurrentBalanceController.getCurrentBalance(testData.glAccounts.get(16).Id, glAccountBalanceSettings.ledgers[0].Id);

            System.assertEquals(testCR.Amount__c * (-1), balanceResult.balance);
            System.assertEquals(MultiCurrencyHandler.CORPORATE_CURRENCY, balanceResult.currencyIsoCode);
            System.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, balanceResult.isMultiCurrencyOrganization);
        }
    }

    @IsTest
    static void testGetCurrentBalanceWithMixedPeriodStatuses() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today());
            System.assertNotEquals(NULL, currentPeriod);
            System.assertNotEquals(NULL, currentPeriod.Id);

            Accounting_Period__c archivedPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -5);
            Accounting_Period__c archiveInProgressPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -4);
            Accounting_Period__c closedPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -3);
            Accounting_Period__c closeInProgressPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -2);
            Accounting_Period__c priorOpenPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -1);

            //create Cash Receipts for each prior period including current one to have Financial Cubes created
            List<Cash_Receipt__c> allCRs = new List<Cash_Receipt__c>();

            Cash_Receipt__c testCR1 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 100,
                Payment_Reference__c = '0000000991',
                Receipt_Date__c = archivedPeriod.Start_Date__c,
                Accounting_Period__c = archivedPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id
            );
            allCRs.add(testCR1);

            Cash_Receipt__c testCR2 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 200,
                Payment_Reference__c = '0000000992',
                Receipt_Date__c = archiveInProgressPeriod.Start_Date__c,
                Accounting_Period__c = archiveInProgressPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id
            );
            allCRs.add(testCR2);

            Cash_Receipt__c testCR3 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 300,
                Payment_Reference__c = '0000000993',
                Receipt_Date__c = closedPeriod.Start_Date__c,
                Accounting_Period__c = closedPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id
            );
            allCRs.add(testCR3);

            Cash_Receipt__c testCR4 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 400,
                Payment_Reference__c = '0000000994',
                Receipt_Date__c = closeInProgressPeriod.Start_Date__c,
                Accounting_Period__c = closeInProgressPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id
            );
            allCRs.add(testCR4);

            Cash_Receipt__c testCR5 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 500,
                Payment_Reference__c = '0000000995',
                Receipt_Date__c = priorOpenPeriod.Start_Date__c,
                Accounting_Period__c = priorOpenPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id
            );
            allCRs.add(testCR5);

            Cash_Receipt__c testCR6 = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 600,
                Payment_Reference__c = '0000000996',
                Receipt_Date__c = currentPeriod.Start_Date__c,
                Accounting_Period__c = currentPeriod.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(16).Id
            );
            allCRs.add(testCR6);

            insert allCRs;

            //set status for periods
            AccountingPeriodActions.isFirstRun = false;
            archivedPeriod.Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            archiveInProgressPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            closedPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            closeInProgressPeriod.Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;

            update new List<Accounting_Period__c>{archivedPeriod, archiveInProgressPeriod, closedPeriod, closeInProgressPeriod};
            AccountingPeriodActions.isFirstRun = true;
            AccountingPeriodHandler.reset();

            //manually carry over opening balance on related fin cubes
            //we need to do this only for period which are considered as 'closed'
            System.assertEquals(12, [SELECT count() FROM Financial_Cube__c LIMIT 100]);
            List<Financial_Cube__c> fCubesToUpdate = new List<Financial_Cube__c>();

            Financial_Cube__c archiveInProgressPeriodFinCubeDebit = [
                SELECT Id, Opening_Balance__c
                FROM Financial_Cube__c
                WHERE Accounting_Period__c = :archiveInProgressPeriod.Id
                AND GL_Account__c = :testData.glAccounts.get(0).Id
            ];
            archiveInProgressPeriodFinCubeDebit.Opening_Balance__c = testCR1.Amount__c;
            fCubesToUpdate.add(archiveInProgressPeriodFinCubeDebit);

            Financial_Cube__c archiveInProgressPeriodFinCubeCredit = [
                SELECT Id, Opening_Balance__c
                FROM Financial_Cube__c
                WHERE Accounting_Period__c = :archiveInProgressPeriod.Id
                AND GL_Account__c = :testData.glAccounts.get(16).Id
            ];
            archiveInProgressPeriodFinCubeCredit.Opening_Balance__c = testCR1.Amount__c * -1;
            fCubesToUpdate.add(archiveInProgressPeriodFinCubeCredit);

            Financial_Cube__c closedPeriodFinCubeDebit = [
                SELECT Id, Opening_Balance__c
                FROM Financial_Cube__c
                WHERE Accounting_Period__c = :closedPeriod.Id
                AND GL_Account__c = :testData.glAccounts.get(0).Id
            ];
            closedPeriodFinCubeDebit.Opening_Balance__c = testCR1.Amount__c + testCR2.Amount__c;
            fCubesToUpdate.add(closedPeriodFinCubeDebit);

            Financial_Cube__c closedPeriodFinCubeCredit = [
                SELECT Id, Opening_Balance__c
                FROM Financial_Cube__c
                WHERE Accounting_Period__c = :closedPeriod.Id
                AND GL_Account__c = :testData.glAccounts.get(16).Id
            ];
            closedPeriodFinCubeCredit.Opening_Balance__c = (testCR1.Amount__c + testCR2.Amount__c) * -1;
            fCubesToUpdate.add(closedPeriodFinCubeCredit);

            FinancialCubeActions.isPreventOverride = true;
            update fCubesToUpdate;
            FinancialCubeActions.isPreventOverride = false;

            Test.startTest();
            GLAccountCurrentBalanceController.GLAccountCurrentBalanceSettings glAccountBalanceSettings =
                GLAccountCurrentBalanceController.getSettings(testData.glAccounts.get(0).Id);
            System.assertEquals(true, glAccountBalanceSettings.isFeatureAvailable);
            System.assertNotEquals(true, glAccountBalanceSettings.ledgers.isEmpty());
            System.assertEquals(false, glAccountBalanceSettings.singleLedger);
            System.assertEquals(true, glAccountBalanceSettings.singleCurrency);

            GLAccountCurrentBalanceController.GLAccountCurrentBalanceResult balanceResult =
                GLAccountCurrentBalanceController.getCurrentBalance(testData.glAccounts.get(0).Id, glAccountBalanceSettings.ledgers[0].Id);

            System.assertEquals((testCR1.Amount__c + testCR2.Amount__c + testCR3.Amount__c + testCR4.Amount__c + testCR5.Amount__c + testCR6.Amount__c), balanceResult.balance);
            System.assertEquals(MultiCurrencyHandler.CORPORATE_CURRENCY, balanceResult.currencyIsoCode);
            System.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, balanceResult.isMultiCurrencyOrganization);

            balanceResult =
                GLAccountCurrentBalanceController.getCurrentBalance(testData.glAccounts.get(16).Id, glAccountBalanceSettings.ledgers[0].Id);

            //for P&L GL Account balance equal to current period if last closed period belongs to prior year
            if (closedPeriod.Start_Date__c.year() < currentPeriod.Start_Date__c.year()) {
                Decimal expectedBalance = 0;
                if (AccountingPeriodHandler.getInstance().getAccountingPeriodById(testCR6.Accounting_Period__c).Start_Date__c.year() == Date.today().year()) {
                    expectedBalance += testCR6.Amount__c;
                }
                if (AccountingPeriodHandler.getInstance().getAccountingPeriodById(testCR5.Accounting_Period__c).Start_Date__c.year() == Date.today().year()) {
                    expectedBalance += testCR5.Amount__c;
                }
                if (AccountingPeriodHandler.getInstance().getAccountingPeriodById(testCR4.Accounting_Period__c).Start_Date__c.year() == Date.today().year()) {
                    expectedBalance += testCR4.Amount__c;
                }
                System.assertEquals(expectedBalance * -1, balanceResult.balance);
            }
            else {
                System.assertEquals((testCR1.Amount__c + testCR2.Amount__c + testCR3.Amount__c + testCR4.Amount__c + testCR5.Amount__c + testCR6.Amount__c) * (-1), balanceResult.balance);
            }
            System.assertEquals(MultiCurrencyHandler.CORPORATE_CURRENCY, balanceResult.currencyIsoCode);
            System.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, balanceResult.isMultiCurrencyOrganization);
        }
    }

    @IsTest
    static void testGetCurrentBalanceForCashFlowCategory() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today());
            System.assertNotEquals(NULL, currentPeriod);
            System.assertNotEquals(NULL, currentPeriod.Id);

            Test.startTest();
            GLAccountCurrentBalanceController.GLAccountCurrentBalanceSettings glAccountBalanceSettings =
                GLAccountCurrentBalanceController.getSettings(testData.cashFlowCategories.get(0).Id);
            System.assertEquals(false, glAccountBalanceSettings.isFeatureAvailable);
        }
    }

    @IsTest
    static void testGetCurrentBalance_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(Date.today());
                System.assertNotEquals(NULL, currentPeriod);
                System.assertNotEquals(NULL, currentPeriod.Id);

                //create Ledger in foreign currency
                Ledger__c testLedger = [
                    SELECT  Id, Name, Type__c, Default_Bank_Account__c, Default_Billing_Format__c,
                            Billing_Outstanding_Statement_Format__c, Billing_Activity_Statement_Format__c
                    FROM Ledger__c
                    WHERE Type__c = 'Transactional'
                    LIMIT 1
                ];
                Ledger__c newLedger = testLedger.clone(false, true, false, false);
                newLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newLedger;
                newLedger = LedgerHandler.getInstanceWithoutSharing().getAllLedgersMap().get(newLedger.Id);

                //set default ledger (simulate Ledger Manager component behaviour)
                Ledger_Custom_Settings__c ledgerSettings = Ledger_Custom_Settings__c.getOrgDefaults();
                ledgerSettings.Ledger_Id__c = newLedger.Id;
                SFDCSecurityUtils.updateProxy(ledgerSettings);

                //create Cash Receipt in foreign currency to have Financial Cubes created
                Cash_Receipt__c testCR = new Cash_Receipt__c(
                    Account__c = testData.accounts.get(0).Id,
                    Amount__c = 500.00,
                    Payment_Reference__c = '0000000999',
                    Receipt_Date__c = currentPeriod.Start_Date__c,
                    Accounting_Period__c = currentPeriod.Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = testData.glAccounts.get(0).Id,
                    Credit_GL_Account__c = testData.glAccounts.get(16).Id,
                    Ledger__c = newLedger.Id
                );
                testCR.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testCR;

                Test.startTest();
                GLAccountCurrentBalanceController.GLAccountCurrentBalanceSettings glAccountBalanceSettings =
                    GLAccountCurrentBalanceController.getSettings(testData.glAccounts.get(0).Id);
                System.assertEquals(true, glAccountBalanceSettings.isFeatureAvailable);
                System.assertNotEquals(true, glAccountBalanceSettings.ledgers.isEmpty());
                System.assertEquals(false, glAccountBalanceSettings.singleLedger);
                System.assertEquals(false, glAccountBalanceSettings.singleCurrency);
                System.assertEquals(true, glAccountBalanceSettings.isMultiCurrencyOrganization);

                GLAccountCurrentBalanceController.GLAccountCurrentBalanceResult balanceResult =
                    GLAccountCurrentBalanceController.getCurrentBalance(testData.glAccounts.get(0).Id, newLedger.Id);

                System.assertEquals(testCR.Amount__c, balanceResult.balance.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals(LedgerHandler.getLedgerCurrency(newLedger.Id), balanceResult.currencyIsoCode);
                System.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, balanceResult.isMultiCurrencyOrganization);

                balanceResult =
                    GLAccountCurrentBalanceController.getCurrentBalance(testData.glAccounts.get(16).Id, newLedger.Id);

                System.assertEquals(testCR.Amount__c * (-1), balanceResult.balance.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals(LedgerHandler.getLedgerCurrency(newLedger.Id), balanceResult.currencyIsoCode);
                System.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, balanceResult.isMultiCurrencyOrganization);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

}