@isTest
private class AccountingPeriodCloseBatchProcessorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }


    //================================================================================
    // Test the the revenue and expense cubes are carried over correctly in the following circumstances:
    //  1. When the opening balance is 0 and the transaction amount is non 0
    //  2. When the opening balance is non 0 and the transaction amount is non 0
    //  3. When the next month is the last month of a fiscal year.
    //================================================================================ 
    @isTest 
    private static void testCalculateNextPeriodFinancialCubesRevenueANDExpense() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            // Set up data we will create billings in the current accounting period
            // and in the next accounting period.
            List<Billing__c> billings = new List<Billing__c>();

            Billing__c bill = testData.billings.get(0).clone(false);
            bill.Status__c = 'Approved';
            billings.add(bill);

            Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);

            bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Status__c = 'Approved';
            billings.add(bill);

            insert billings;

            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            Billing_Line__c billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = billings.get(0).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = billings.get(0).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = billings.get(1).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = billings.get(1).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            insert billLineList;

            BillingPostService.postBillings(billings);

            System.assertEquals(
                6,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            // Test 0 opening balance cube created in next period correctly
            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            List<Financial_Cube__c> fCubes = [
                SELECT  Id,
                        Accounting_Period__c,
                        GL_Account__c,
                        GL_Account__r.Type__c,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c,
                        Opening_Balance__c,
                        Amount__c,
                        Key_Group__c,
                        Cube_Type__c,
                        Transaction_Amount__c,
                        Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod1.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ];

            // Test 0 opening balance cube created in next period correctly
            AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            Decimal currentPeriodAmount = [
                SELECT Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                    AND Accounting_Period__c = :testAccountingPeriod1.Id
                    AND Cube_Type__c = 'Period'
            ].Transaction_Amount__c;

            Decimal nextPeriodOpeningBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            System.assertEquals(currentPeriodAmount,nextPeriodOpeningBalance);

            fCubes = [
                SELECT  Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ];

            bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Status__c = 'Approved';
            insert bill;

            billLineList = new List<Billing_Line__c>();

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            BillingPostService.postBillings(new List<Billing__c>{bill});

            // Test non 0 opening balance cube created in next period correctly
            periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod2},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            Decimal currentPeriodTAmount = [
                SELECT Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                    AND Cube_Type__c = 'Period'
            ].Transaction_Amount__c;

            Decimal currentPeriodOBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            Accounting_Period__c testAccountingPeriod3 = testData.acctPeriods.get(2);

            nextPeriodOpeningBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                    AND Accounting_Period__c = :testAccountingPeriod3.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            System.assertEquals(
                currentPeriodTAmount + currentPeriodOBalance,
                nextPeriodOpeningBalance
            );

            // Test revenue financial cube opening balance is set to 0 for new year
            periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod3},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            Test.stopTest();

            Accounting_Period__c testAccountingPeriod4 = testData.acctPeriods.get(3);

            nextPeriodOpeningBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            System.assertEquals(
                0,
                nextPeriodOpeningBalance
            );
        }
    }
    
    //================================================================================ 
    //  Test the the balance sheet cubes are carried over correctly in the following circumstances:
    //  1. When the opening balance is 0 and the transaction amount is non 0
    //  2. When the opening balance is non 0 and the transaction amount is non 0
    //  3. When the next month is the last month of a fiscal year.
    //================================================================================    
    @isTest 
    private static void testCalculateNextPeriodFinancialCubesBalanceSheet() {   
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            List<Billing__c> billings = new List<Billing__c>();

            Billing__c bill = testData.billings.get(0).clone(false);
            bill.Status__c = 'Approved';
            billings.add(bill);

            Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);

            bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Status__c = 'Approved';
            billings.add(bill);
            insert billings;

            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            Billing_Line__c billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = billings.get(0).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = billings.get(0).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = billings.get(1).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = billings.get(1).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            insert billLineList;

            BillingPostService.postBillings(billings);

            System.assertEquals(
                6,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            // Test 0 opening balance cube created in next period correctly
            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            List<Financial_Cube__c> fCubes = [
                SELECT  Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod1.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ];

            // Test 0 opening balance cube created in next period correctly
            AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            Decimal currentPeriodAmount = [
                SELECT Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod1.Id
                    AND Cube_Type__c = 'Period'
            ].Transaction_Amount__c;

            Decimal nextPeriodOpeningBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            System.assertEquals(
                currentPeriodAmount,
                nextPeriodOpeningBalance
            );

            fCubes = [
                SELECT Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                ORDER BY GL_Account_Variable_1__c,GL_Account_Variable_2__c,GL_Account_Variable_3__c,GL_Account_Variable_4__c
            ];

            bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Status__c = 'Approved';
            insert bill;

            billLineList = new List<Billing_Line__c>();

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            BillingPostService.postBillings(new List<Billing__c>{bill});

            // Test 0 opening balance cube created in next period correctly
            periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod2},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            Decimal currentPeriodTAmount = [
                SELECT Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                    AND Cube_Type__c = 'Period'
            ].Transaction_Amount__c;

            Decimal currentPeriodOBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            Accounting_Period__c testAccountingPeriod3 = testData.acctPeriods.get(2);

            nextPeriodOpeningBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod3.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            System.assertEquals(
                currentPeriodTAmount + currentPeriodOBalance,
                nextPeriodOpeningBalance
            );

            // Test balance sheet financial cube opening balance is carried over to new year
            periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod3},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            Test.stopTest();

            currentPeriodTAmount = [
                SELECT Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod3.Id
                    AND Cube_Type__c = 'Period'
            ].Transaction_Amount__c;

            currentPeriodOBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod3.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            Accounting_Period__c testAccountingPeriod4 = testData.acctPeriods.get(3);

            nextPeriodOpeningBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(2).Id
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                    AND Cube_Type__c = 'Period'
            ].Opening_Balance__c;

            System.assertEquals(
                currentPeriodTAmount + currentPeriodOBalance,
                nextPeriodOpeningBalance
            );
        }
    }
    
    //================================================================================
    //  Validate that if a financial cube has a 0 opening balance and a 0 transaction amount
    //  that a financial cube is not created for this financial cube in the next accounting period
    //================================================================================
    @isTest 
    private static void testCalculateNextPeriodFinancialCubesNextPeriodCubeNotCreatedZeroBalanceANDAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings();

        System.runAs(testData.users.get(1)) {

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);

            Test.startTest();
            Billing__c bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod1.Id;
            bill.Status__c = 'Approved';
            insert bill;

            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            Billing_Line__c billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            insert billLineList;

            BillingPostService.postBillings(new List<Billing__c>{bill});
            BillingPostService.unpostBillings(new List<Billing__c>{bill});

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            Financial_Cube__c validatedTestFinancialCube = [
                    SELECT Opening_Balance__c, Transaction_Amount__c
                    FROM Financial_Cube__c
                    WHERE Accounting_Period__c = :testAccountingPeriod1.Id
                        AND GL_Account__c = :testData.glAccounts.get(10).Id
                        AND Cube_Type__c = 'Period'
                    LIMIT 1
            ];

            System.assertEquals(
                0,
                validatedTestFinancialCube.Opening_Balance__c
            );

            System.assertEquals(
                0,
                validatedTestFinancialCube.Transaction_Amount__c
            );

            // Test 0 opening balance cube created in next period correctly
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            List<Financial_Cube__c> fCubes = [
                SELECT  Id,
                        Accounting_Period__c,
                        GL_Account__c,
                        GL_Account__r.Type__c,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c,
                        Opening_Balance__c,
                        Amount__c,
                        Key_Group__c,
                        Cube_Type__c,
                        Transaction_Amount__c,
                        Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod1.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ];

            AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            // Test next period cube did not get created.
            Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);
            System.assertEquals(
                0,
                [
                    SELECT COUNT()
                    FROM Financial_Cube__c
                    WHERE Accounting_Period__c = :testAccountingPeriod2.Id
                        AND GL_Account__c = :testData.glAccounts.get(10).Id
                        AND Cube_Type__c = 'Period'
                ]
            );
            Test.stopTest();
        }
    }
    
    //================================================================================
    //  Validate that the opening balance and amount values are correctly transcribed
    //  to the the next accounting period which is a non beginning fiscal year period.
    //================================================================================ 
    @isTest 
    private static void testCalculateCurrentYearEarningsPeriodSameYear() {   
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            Billing__c bill = testData.billings.get(0).clone(false);
            bill.Status__c = 'Approved';
            insert bill;

            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            Billing_Line__c billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            insert billLineList;

            BillingPostService.postBillings(new List<Billing__c>{bill});
            Account_Payable__c ap = testData.payables.get(0).clone(false);
            ap.Status__c = 'Approved';
            ap.Payee_Reference__c = 'haifohsdofisfsdfsdfsddsf';
            insert ap;

            List<Account_Payable_Line__c> apLineList = new List<Account_Payable_Line__c>();

            Account_Payable_Line__c apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(16).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 4000;
            apLineList.add(apLine);

            apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(17).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 7000;
            apLineList.add(apLine);

            insert apLineList;

            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{ap});

            System.assertEquals(
                6,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            // Test 0 opening balance cube created in next period correctly
            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            List<Financial_Cube__c> fCubes = [
                SELECT Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod1.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ];

            // Test current year earnings financial cube has opening balance and amount set correctly
            AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();
            
            AccountingPeriodCloseBatchProcessor.FinancialCubesCurrentYearEarningsProcessor fce = new AccountingPeriodCloseBatchProcessor.FinancialCubesCurrentYearEarningsProcessor(periodDataContainer,fCubes);
            fce.calculateCurrentYearEarnings();

            Financial_Cube__c validatedTestFinancialCube = [
                    SELECT Opening_Balance__c, Amount__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(9).Id
                        AND Accounting_Period__c = :testAccountingPeriod1.Id
                        AND Cube_Type__c = 'Current Year Earnings'
                    LIMIT 1
            ];

            System.assertEquals(
                0,
                validatedTestFinancialCube.Opening_Balance__c
            );

            System.assertEquals(
                7000,
                validatedTestFinancialCube.Amount__c
            );

            Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);

            bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Status__c = 'Approved';
            insert bill;

            billLineList = new List<Billing_Line__c>();

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 2000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            insert billLineList;

            BillingPostService.postBillings(new List<Billing__c>{bill});

            ap = testData.payables.get(0).clone(false);
            ap.Accounting_Period__c = testAccountingPeriod2.Id;
            ap.Status__c = 'Approved';
            ap.Payee_Reference__c = 'haifohsdofisfdsf';
            insert ap;

            apLineList = new List<Account_Payable_Line__c>();

            apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(16).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 2000;
            apLineList.add(apLine);

            apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(17).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 9000;
            apLineList.add(apLine);

            insert apLineList;

            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{ap});

            periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod2},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            fCubes = [
                SELECT Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod2.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ];

            // Test current year earnings financial cube has opening balance and amount set correctly
            fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer,fCubes);
            fcp.calculateNextPeriodFinancialCubes();
            
            fce = new AccountingPeriodCloseBatchProcessor.FinancialCubesCurrentYearEarningsProcessor(periodDataContainer,fCubes);
            fce.calculateCurrentYearEarnings();

            Financial_Cube__c validatedTestFinancialCube2 = [
                    SELECT Opening_Balance__c, Amount__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(9).Id
                        AND Accounting_Period__c = :testAccountingPeriod2.Id
                        AND Cube_Type__c = 'Current Year Earnings'
                    LIMIT 1
            ];

            System.assertEquals(
                7000,
                validatedTestFinancialCube2.Opening_Balance__c
            );

            System.assertEquals(
                6000,
                validatedTestFinancialCube2.Amount__c
            );
        }
    }

    //================================================================================
    //  Validate that the opening balance and amount values are correctly transcribed
    //  to the the next accounting period which is a beginning fiscal year period.
    //================================================================================ 
    @isTest 
    private static void testCalculateCurrentYearEarningsNewYear() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            Accounting_Period__c testAccountingPeriod3 = testData.acctPeriods.get(2);

            Billing__c bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod3.Id;
            bill.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            insert bill;

            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            Billing_Line__c billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);
            insert billLineList;

            BillingPostService.postBillings(new List<Billing__c>{bill});

            Account_Payable__c ap = testData.payables.get(0).clone(false);
            ap.Accounting_Period__c = testAccountingPeriod3.Id;
            ap.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            ap.Payee_Reference__c = 'haifohsdofisfsdfsdfsddsf';
            insert ap;

            List<Account_Payable_Line__c> apLineList = new List<Account_Payable_Line__c>();

            Account_Payable_Line__c apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(16).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 4000;
            apLineList.add(apLine);

            apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(17).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 7000;
            apLineList.add(apLine);
            insert apLineList;

            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{ap});

            System.assertEquals(
                6,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            // Test 0 opening balance cube created in next period correctly
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod3},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            List<Financial_Cube__c> fCubes = [
                SELECT  Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod3.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ];

            // Test current year earnings financial cube has opening balance and amount set correctly
            AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor fcp =
                new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer, fCubes);
            fcp.calculateNextPeriodFinancialCubes();
            
            AccountingPeriodCloseBatchProcessor.FinancialCubesCurrentYearEarningsProcessor fce =
                new AccountingPeriodCloseBatchProcessor.FinancialCubesCurrentYearEarningsProcessor(periodDataContainer, fCubes);
            fce.calculateCurrentYearEarnings();

            Financial_Cube__c validatedTestFinancialCube = [
                SELECT Opening_Balance__c, Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(9).Id
                AND Accounting_Period__c = :testAccountingPeriod3.Id
                AND Cube_Type__c = 'Current Year Earnings'
                LIMIT 1
            ];

            System.assertEquals(
                0,
                validatedTestFinancialCube.Opening_Balance__c
            );

            System.assertEquals(
                7000,
                validatedTestFinancialCube.Amount__c
            );

            Accounting_Period__c testAccountingPeriod4 = testData.acctPeriods.get(3);

            bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod4.Id;
            bill.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            insert bill;

            billLineList = new List<Billing_Line__c>();

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 2000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = bill.Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);
            insert billLineList;

            BillingPostService.postBillings(new List<Billing__c>{bill});

            ap = testData.payables.get(0).clone(false);
            ap.Accounting_Period__c = testAccountingPeriod4.Id;
            ap.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
            ap.Payee_Reference__c = 'haifohsdofisfdsf';
            insert ap;

            apLineList = new List<Account_Payable_Line__c>();

            apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(16).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 2000;
            apLineList.add(apLine);

            apLine = testData.payableLines.get(0).clone(false);
            apLine.Expense_GL_Account__c = testData.glAccounts.get(17).Id;
            apLine.Account_Payable__c = ap.Id;
            apLine.Amount__c = 9000;
            apLineList.add(apLine);
            insert apLineList;

            AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{ap});

            periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod4},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );
            fCubes = [
                SELECT  Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Period'
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c,GL_Account_Variable_4__c
            ];

            // Test current year earnings financial cube has opening balance set to 0
            fcp = new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer, fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            fce = new AccountingPeriodCloseBatchProcessor.FinancialCubesCurrentYearEarningsProcessor(periodDataContainer, fCubes);
            fce.calculateCurrentYearEarnings();

            Financial_Cube__c validatedTestFinancialCube2 = [
                SELECT Opening_Balance__c, Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(9).Id
                AND Accounting_Period__c = :testAccountingPeriod4.Id
                AND Cube_Type__c = 'Current Year Earnings'
                LIMIT 1
            ];

            System.assertEquals(
                0,
                validatedTestFinancialCube2.Opening_Balance__c
            );

            System.assertEquals(
                6000,
                validatedTestFinancialCube2.Amount__c
            );
            Test.stopTest();
        }
    } 

    //================================================================================
    //  Validate that the opening balance and amount values are correctly transcribed
    //  to the the next accounting period for the retained earning
    //  which is a non year end accounting period
    //================================================================================ 
    @IsTest
    private static void testCalculateRetainedEarningsNonYearEnd() {

        TestDataSuite testData = TestDataSuite.getInstance()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(0, [SELECT COUNT() FROM Financial_Cube__c]);

            Test.startTest();
            Accounting_Period__c testAccountingPeriod3 = testData.acctPeriods.get(0);

            // Setup current year earnings for data
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(8).Id;
            fCube.Opening_Balance__c = 100;
            fCube.Amount__c = 0;
            fCube.Cube_Type__c = 'Retained Earnings';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(8).Id;
            fCube.Opening_Balance__c = 200;
            fCube.Amount__c = 0;
            fCube.Cube_Type__c = 'Retained Earnings';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Financial_Cube__c WHERE Cube_Type__c IN ('Retained Earnings')]
            );
            
            // Test retained earnings is carried over correctly in next accounting period which is non year end accounting period
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod3},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            Map<String, Financial_Cube__c> reCubeMap = new Map<String, Financial_Cube__c>();

            for (Financial_Cube__c fCube1 : [
                SELECT Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                AND Cube_Type__c = 'Retained Earnings'
                AND Accounting_Period__c = :testAccountingPeriod3.Id
                ORDER BY GL_Account_Variable_1__c,GL_Account_Variable_2__c,GL_Account_Variable_3__c,GL_Account_Variable_4__c
            ]) {
                reCubeMap.put(fCube1.Key_Group__c, fCube1);
            }

            AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor fcr = new AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor(periodDataContainer, reCubeMap);
            fcr.calculateRetainedEarningsForNewFiscalYear();
            fcr.calculateRetainedEarningsNextPeriod();

            Accounting_Period__c testAccountingPeriod4 = testData.acctPeriods.get(1);
            System.assertEquals(
                2, [
                    SELECT COUNT()
                    FROM Financial_Cube__c
                    WHERE Cube_Type__c = 'Retained Earnings'
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                ]
            );

            System.assertEquals(
                100, [
                    SELECT Opening_Balance__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(8).Id
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                    AND Cube_Type__c = 'Retained Earnings'
                    AND GL_Account_Variable_1__c = null
                ].Opening_Balance__c
            );

            System.assertEquals(
                200, [
                    SELECT Opening_Balance__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(8).Id
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                    AND Cube_Type__c = 'Retained Earnings'
                    AND GL_Account_Variable_1__c = :testData.accountingVariables1.get(0).Id
                ].Opening_Balance__c
            );
        }
    }

    //================================================================================
    //  Validate that the opening balance and amount values are correctly transcribed
    //  to the the next accounting period for the retained earning
    //  which is a year end accounting period
    //================================================================================ 
    @isTest 
    private static void testCalculateRetainedEarningsPeriodYearEndRetainedEarningsExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;
            System.assertEquals(0, [SELECT COUNT() FROM Financial_Cube__c]);

            Test.startTest();
            Accounting_Period__c testAccountingPeriod3 = testData.acctPeriods.get(2);

            // Setup current year earnings for data
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(9).Id;
            fCube.Opening_Balance__c = 100;
            fCube.Amount__c = 100;
            fCube.Cube_Type__c = 'Current Year Earnings';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(9).Id;
            fCube.Opening_Balance__c = 200;
            fCube.Amount__c = 150;
            fCube.Cube_Type__c = 'Current Year Earnings';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            fCubeList.add(fCube);

            Accounting_Period__c testAccountingPeriod4 = testData.acctPeriods.get(3);

            System.assertEquals('1991-12', testAccountingPeriod3.Name);
            
            // Setup retained earnings for data
            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(8).Id;
            fCube.Opening_Balance__c = 100;
            fCube.Amount__c = 0;
            fCube.Cube_Type__c = 'Retained Earnings';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(8).Id;
            fCube.Opening_Balance__c = 200;
            fCube.Amount__c = 0;
            fCube.Cube_Type__c = 'Retained Earnings';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            fCubeList.add(fCube);
            
            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                4,
                [SELECT COUNT() FROM Financial_Cube__c WHERE Cube_Type__c IN ('Current Year Earnings', 'Retained Earnings')]
            );

            Map<String, Financial_Cube__c> cyCubeMap = new Map<String, Financial_Cube__c>();

            for (Financial_Cube__c fCube1 : [
                SELECT Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                AND Cube_Type__c = 'Current Year Earnings'
                AND Accounting_Period__c = :testAccountingPeriod3.Id
                ORDER BY GL_Account_Variable_1__c, GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c
            ]) {
                cyCubeMap.put(fCube1.Key_Group__c, fCube1);
            }

            Map<String, Financial_Cube__c> reCubeMap = new Map<String, Financial_Cube__c>();

            for (Financial_Cube__c fCube1 : [
                SELECT Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                AND Cube_Type__c = 'Retained Earnings'
                AND Accounting_Period__c = :testAccountingPeriod3.Id
                ORDER BY GL_Account_Variable_1__c,GL_Account_Variable_2__c,GL_Account_Variable_3__c,GL_Account_Variable_4__c
            ]) {
                reCubeMap.put(fCube1.Key_Group__c, fCube1);
            }

            // Test 0 opening balance cube created in next period correctly
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod3},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor fcr =
                new AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor(periodDataContainer, cyCubeMap);

            fcr.calculateRetainedEarningsForNewFiscalYear();

            System.assertEquals(
                2, [
                    SELECT COUNT()
                    FROM Financial_Cube__c
                    WHERE Cube_Type__c = 'Retained Earnings'
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                ]
            );

            fcr = new AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor(periodDataContainer, reCubeMap);
            fcr.calculateRetainedEarningsNextPeriod();

            System.assertEquals(
                2, [
                    SELECT COUNT()
                    FROM Financial_Cube__c
                    WHERE Cube_Type__c = 'Retained Earnings'
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                ]
            );

            System.assertEquals(
                300, [
                    SELECT Opening_Balance__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(8).Id
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                    AND Cube_Type__c = 'Retained Earnings'
                    AND GL_Account_Variable_1__c = NULL
                ].Opening_Balance__c
            );

            System.assertEquals(
                550, [
                    SELECT Opening_Balance__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(8).Id
                    AND Accounting_Period__c = :testAccountingPeriod4.Id
                    AND Cube_Type__c = 'Retained Earnings'
                    AND GL_Account_Variable_1__c = :testData.accountingVariables1.get(0).Id
                ].Opening_Balance__c
            );
           
        }
    }
    
    //================================================================================
    //  Validate that the opening balance and amount values are correctly transcribed
    //  to the the next accounting period for the retained earning
    //  which is a year end accounting period
    //================================================================================   
    @isTest 
    private static void testCalculateRetainedEarningsPeriodYearEndNoRetainedEarningsExist() {   
        TestDataSuite testData = TestDataSuite.getInstance()
                .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            Test.startTest();

            Accounting_Period__c testAccountingPeriod3 = testData.acctPeriods.get(2);

            // Setup current year earnings for data
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(10).Id;
            fCube.Opening_Balance__c = 100;
            fCube.Amount__c = 100;
            fCube.Cube_Type__c = 'Current Year Earnings';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers.get(0).Id;
            fCube.Accounting_Period__c = testAccountingPeriod3.Id;
            fCube.GL_Account__c = testData.glAccounts.get(10).Id;
            fCube.Opening_Balance__c = 200;
            fCube.Amount__c = 150;
            fCube.Cube_Type__c = 'Current Year Earnings';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1.get(0).Id;
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(2,[SELECT COUNT() FROM Financial_Cube__c WHERE Cube_Type__c = 'Current Year Earnings']);

            // Test 0 opening balance cube created in next period correctly
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod3},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );
            
            Map<String,Financial_Cube__c> fCubeMap = new Map<String,Financial_Cube__c>();

            for (Financial_Cube__c fCube1 : [
                SELECT Id, Accounting_Period__c, GL_Account__c, GL_Account__r.Type__c, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Opening_Balance__c, Amount__c, Key_Group__c, Cube_Type__c,
                        Transaction_Amount__c, Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = 'Transactional'
                    AND Cube_Type__c = 'Current Year Earnings'
                    AND Accounting_Period__c = :testAccountingPeriod3.Id
                ORDER BY GL_Account_Variable_1__c,GL_Account_Variable_2__c,GL_Account_Variable_3__c,GL_Account_Variable_4__c
            ]) {
                fCubeMap.put(fCube1.Key_Group__c, fCube1);
            }

            AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor fcr = new AccountingPeriodCloseBatchProcessor.FinancialCubesRetainedEarningsProcessor(periodDataContainer, fCubeMap);
            fcr.calculateRetainedEarningsForNewFiscalYear();
            fcr.calculateRetainedEarningsNextPeriod();

            System.assertEquals(
                2,
                [SELECT COUNT() FROM Financial_Cube__c WHERE Cube_Type__c = 'Retained Earnings']
            );

            Accounting_Period__c testAccountingPeriod4 = testData.acctPeriods.get(3);

            System.assertEquals(
                200,
                [
                    SELECT Opening_Balance__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(8).Id
                        AND Accounting_Period__c = :testAccountingPeriod4.Id
                        AND Cube_Type__c = 'Retained Earnings'
                        AND GL_Account_Variable_1__c = null
                ].Opening_Balance__c
            );

            System.assertEquals(
                350,
                [
                    SELECT Opening_Balance__c
                    FROM Financial_Cube__c
                    WHERE GL_Account__c = :testData.glAccounts.get(8).Id
                        AND Accounting_Period__c = :testAccountingPeriod4.Id
                        AND Cube_Type__c = 'Retained Earnings'
                        AND GL_Account_Variable_1__c = :testData.accountingVariables1.get(0).Id
                ].Opening_Balance__c
            );
        }
    } 
    
    //================================================================================
    //  Validate the batch job excutes to completion
    //================================================================================   
    @isTest 
    private static void testAccountingPeriodCloseBatchProcessorSuccess() {   
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            // Set up data we will create billings in the current accounting period
            // and in the next accounting period.
            List<Billing__c> billings = new List<Billing__c>();

            Billing__c bill = testData.billings.get(0).clone(false);
            bill.Status__c = 'Approved';
            billings.add(bill);

            Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);

            bill = testData.billings.get(0).clone(false);
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Status__c = 'Approved';
            billings.add(bill);

            insert billings;

            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            Billing_Line__c billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = billings.get(0).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = billings.get(0).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(10).Id;
            billLine.Billing__c = billings.get(1).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 1000;
            billLineList.add(billLine);

            billLine = testData.billingLines.get(0).clone(false);
            billLine.Revenue_GL_Account__c = testData.glAccounts.get(11).Id;
            billLine.Billing__c = billings.get(1).Id;
            billLine.Hours_Units__c = 1;
            billLine.Rate__c = 3000;
            billLineList.add(billLine);

            insert billLineList;

            BillingPostService.postBillings(billings);

            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);

            System.assertEquals(
                3,
                [SELECT COUNT() FROM Financial_Cube__c WHERE Accounting_Period__c = :testAccountingPeriod1.Id]
            );

            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            AccountingPeriodCloseBatchProcessor apc = new AccountingPeriodCloseBatchProcessor(periodDataContainer);
            Id jobId = Database.executeBatch(apc);

            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM AsyncApexJob WHERE Id = :jobId AND Status = 'Completed']
            );
        }
    }

    @isTest
    private static void testAPCloseBatchProcessorWithCFSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashFlowCategories(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            System.assertEquals(0, [SELECT COUNT() FROM Financial_Cube__c]);

            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 400,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Cash_Flow_Category__c = testData.cashFlowCategories.get(2).Id
            );

            insert testCR;

            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods.get(0)},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            AccountingPeriodCloseBatchProcessor apc = new AccountingPeriodCloseBatchProcessor(periodDataContainer);
            Id jobId = Database.executeBatch(apc);

            Test.stopTest();

            System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE Id = :jobId AND Status = 'Completed']);
            System.assertEquals(1, [SELECT COUNT() FROM Financial_Cube__c WHERE Cube_Type__c = 'Cash Flow' AND Accounting_Period__c = :testData.acctPeriods.get(0).Id]);
            System.assertEquals(1, [SELECT COUNT() FROM Financial_Cube__c WHERE Cube_Type__c = 'Cash Flow' AND Accounting_Period__c = :testData.acctPeriods.get(1).Id]);
            System.assertEquals(0, [SELECT COUNT() FROM Financial_Cube__c WHERE GL_Account__c = : testData.cashFlowCategories.get(0).Id AND Accounting_Period__c = :testData.acctPeriods.get(1).Id AND Cube_Type__c = 'Period']);

        }
    }

    //Eliminations-Transactional tests
    @isTest
    private static void testCalculateNextPeriodFinancialCubesElimination() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            List<Ledger__c> eliminationLedgers = [
                SELECT Id
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
            ];
            System.assertEquals(false, eliminationLedgers.isEmpty());
            Ledger__c eliminationLedger = eliminationLedgers.get(0);

            Test.startTest();

            FinancialCubeActions.isPreventOverride = true;
            delete [SELECT Id FROM Financial_Cube__c];
            FinancialCubeActions.isPreventOverride = false;

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Financial_Cube__c]
            );

            //Create Journal Entry
            Journal_Entry__c testJE = new Journal_Entry__c(
                Name = 'testJournal-el',
                Accounting_Period__c = testData.acctPeriods.get(0).Id,
                Journal_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                Ledger__c = eliminationLedger.Id
            );
            insert testJE;

            List<Journal_Entry_Line__c> lines = new List<Journal_Entry_Line__c>();
            //Create JE Lines
            Journal_Entry_Line__c debitLine = new Journal_Entry_Line__c(
                Journal_Entry__c = testJE.Id,
                Debit__c = 100,
                GL_Account__c = testData.glAccounts[10].Id,
                Units__c = 10,
                Reference__c = 'the reference 1'
            );
            lines.add(debitLine);

            Journal_Entry_Line__c creditLine = new Journal_Entry_Line__c(
                Journal_Entry__c = testJE.Id,
                Credit__c = 100,
                GL_Account__c = testData.glAccounts[11].Id,
                Units__c = 10,
                Reference__c = 'the reference 2'
            );
            lines.add(creditLine);
            insert lines;

            //Post Journal Entries
            AbstractPostHandler postHandler = new JournalEntryPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Journal_Entry__c>{testJE});
            System.assertEquals(true, postResults[0].isSuccess);
            System.assertEquals(2, [SELECT COUNT() FROM Financial_Cube__c]);

            // Test 0 opening balance cube created in next period correctly
            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAccountingPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            List<Financial_Cube__c> fCubes = [
                SELECT
                    Id,
                    Accounting_Period__c,
                    GL_Account__c,
                    GL_Account__r.Type__c,
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c,
                    Opening_Balance__c,
                    Amount__c,
                    Key_Group__c,
                    Cube_Type__c,
                    Transaction_Amount__c,
                    Ledger__c
                FROM Financial_Cube__c
                WHERE Ledger_Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_PERIOD
                AND Accounting_Period__c = :testAccountingPeriod1.Id
                ORDER BY
                    GL_Account_Variable_1__c,
                    GL_Account_Variable_2__c,
                    GL_Account_Variable_3__c,
                    GL_Account_Variable_4__c
            ];

            // Test 0 opening balance cube created in next period correctly
            AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor fcp =
                new AccountingPeriodCloseBatchProcessor.FinancialCubesPeriodProcessor(periodDataContainer, fCubes);
            fcp.calculateNextPeriodFinancialCubes();

            Decimal currentPeriodAmount = [
                SELECT Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                AND Accounting_Period__c = :testAccountingPeriod1.Id
                AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_PERIOD
            ].Transaction_Amount__c;

            Decimal nextPeriodOpeningBalance = [
                SELECT Opening_Balance__c
                FROM Financial_Cube__c
                WHERE GL_Account__c = :testData.glAccounts.get(10).Id
                AND Accounting_Period__c = :testData.acctPeriods[1].Id
                AND Cube_Type__c = :FinancialCubeActions.FINANCIAL_CUBE_PERIOD
            ].Opening_Balance__c;

            System.assertEquals(currentPeriodAmount, nextPeriodOpeningBalance);
        }
    }

 }