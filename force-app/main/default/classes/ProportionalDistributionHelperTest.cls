@IsTest
private class ProportionalDistributionHelperTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testHLPCalculateBalanceAllLinesWithSameKey() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createPayables(true);
            testData.createCashDisbursements(true);

            Account_Payable__c pay = testData.payables[0].clone();
            pay.Ledger__c = testData.ledgers[3].Id;
            pay.Payee_Reference__c = 'test ref';
            insert pay;

            List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
            Decimal total = 0;
            for (Account_Payable_Line__c line : testData.payableLines) {
                if (line.Account_Payable__c == testData.payables[0].Id) {
                    Account_Payable_Line__c newLine = line.clone();
                    newLine.Account_Payable__c = pay.Id;
                    total += newLine.Amount__c;
                    lines.add(newLine);
                }
            }

            insert lines;

            Cash_Disbursement__c cd = testData.cashDisbursements[0].clone();
            cd.Ledger__c = testData.ledgers[3].Id;
            cd.Debit_GL_Account__c = testData.glAccounts[5].Id;
            insert cd;


            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 10
            );
            insert apd;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {apd});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(pay.Id);

            System.assertEquals(1, calc.lines.size());
            System.assertEquals(1, calc.existedPay.size());
            System.assertEquals(total, calc.total);
            System.assertEquals(apd.Paid_Amount__c, calc.lines[0].total);

        }
    }

    @IsTest
    private static void testLLPCalculateBalanceAllLinesWithSameKey() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost().createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {

            Test.startTest();
            //Put some field into set of unlocked fields just to check it later
            TriggerObserver.getInstance().unlockField(Account.GL_Account_Variable_1__c);
            //create and post records
            testData.createPayables(true);
            testData.createCashDisbursements(true);

            Account_Payable__c pay = testData.payables[0].clone();
            pay.Ledger__c = testData.ledgers[3].Id;
            pay.Payee_Reference__c = 'test ref';
            insert pay;

            List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
            Decimal total = 0;
            for (Account_Payable_Line__c line : testData.payableLines) {
                if (line.Account_Payable__c == testData.payables[0].Id) {
                    Account_Payable_Line__c newLine = line.clone();
                    newLine.Account_Payable__c = pay.Id;
                    total += newLine.Amount__c;
                    lines.add(newLine);
                }
            }

            insert lines;

            Cash_Disbursement__c cd = testData.cashDisbursements[0].clone();
            cd.Ledger__c = testData.ledgers[3].Id;
            cd.Debit_GL_Account__c = testData.glAccounts[5].Id;
            insert cd;

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 10
            );
            insert apd;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {apd});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(pay.Id);

            Decimal linesTotal = 0;
            for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calc.lines) {
                linesTotal += line.total;
            }

            System.assertEquals(3, calc.lines.size());
            System.assertEquals(1, calc.existedPay.size());
            System.assertEquals(total, calc.total);
            System.assertEquals(apd.Paid_Amount__c, linesTotal);

        }
    }

    @IsTest
    private static void testHLPCalculateBalanceAllLinesWithDifferentKey() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createPayables(true);
            testData.createCashDisbursements(true);

            Account_Payable__c pay = testData.payables[0].clone();
            pay.Ledger__c = testData.ledgers[3].Id;
            pay.Payee_Reference__c = 'test ref';
            insert pay;

            List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
            Decimal total = 0;
            Integer count = 0;
            for (Account_Payable_Line__c line : testData.payableLines) {
                if (line.Account_Payable__c == testData.payables[0].Id) {
                    Account_Payable_Line__c newLine = line.clone();
                    newLine.Account_Payable__c = pay.Id;
                    if (count <= testData.accountingVariables1.size() - 1) {
                        newLine.GL_Account_Variable_1__c = testData.accountingVariables1[count].Id;
                    }
                    total += newLine.Amount__c;
                    lines.add(newLine);
                    count ++;
                }
            }

            insert lines;

            Cash_Disbursement__c cd = testData.cashDisbursements[0].clone();
            cd.Ledger__c = testData.ledgers[3].Id;
            cd.Debit_GL_Account__c = testData.glAccounts[5].Id;
            insert cd;

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 10
            );
            insert apd;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {apd});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(pay.Id);

            Account_Payable__c payForResult = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :pay.Id];
            List<Account_Payable_Line__c> linesForResult = [SELECT Id, Amount__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :pay.Id ORDER BY Amount__c ASC];

            List<Decimal> linesTotal = new List<Decimal>();
            for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calc.lines) {
                linesTotal.add(line.total);
            }
            linesTotal.sort();

            System.assertEquals(3, calc.lines.size());
            System.assertEquals(1, calc.existedPay.size());
            System.assertEquals(total, calc.total);
            System.assertEquals(linesForResult[0].Amount__c * apd.Paid_Amount__c / payForResult.Total__c, linesTotal[0]);
            System.assertEquals(linesForResult[1].Amount__c  * apd.Paid_Amount__c / payForResult.Total__c, linesTotal[1]);
            System.assertEquals(linesForResult[2].Amount__c  * apd.Paid_Amount__c / payForResult.Total__c, linesTotal[2]);

        }
    }

    @IsTest
    private static void testLLPCalculateBalanceAllLinesWithDifferentKey() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost().createCashDisbursementBatches().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createPayables(true);
            testData.createCashDisbursements(true);

            Account_Payable__c pay = testData.payables[0].clone();
            pay.Ledger__c = testData.ledgers[3].Id;
            pay.Payee_Reference__c = 'test ref';
            insert pay;

            List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
            Decimal total = 0;
            Integer count = 0;
            for (Account_Payable_Line__c line : testData.payableLines) {
                if (line.Account_Payable__c == testData.payables[0].Id) {
                    Account_Payable_Line__c newLine = line.clone();
                    newLine.Account_Payable__c = pay.Id;
                    if (count <= testData.accountingVariables1.size() - 1) {
                        newLine.GL_Account_Variable_1__c = testData.accountingVariables1[count].Id;
                    }
                    total += newLine.Amount__c;
                    lines.add(newLine);
                    count ++;
                }
            }

            insert lines;

            Cash_Disbursement__c cd = testData.cashDisbursements[0].clone();
            cd.Ledger__c = testData.ledgers[3].Id;
            cd.Debit_GL_Account__c = testData.glAccounts[5].Id;
            insert cd;

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 10
            );
            insert apd;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {apd});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(pay.Id);

            Account_Payable__c payForResult = [SELECT Id, Total__c FROM Account_Payable__c WHERE Id = :pay.Id];
            List<Account_Payable_Line__c> linesForResult = [SELECT Id, Amount__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :pay.Id ORDER BY Amount__c ASC];

            List<Decimal> linesTotal = new List<Decimal>();
            for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calc.lines) {
                linesTotal.add(line.total);
            }
            linesTotal.sort();

            System.assertEquals(3, calc.lines.size());
            System.assertEquals(1, calc.existedPay.size());
            System.assertEquals(total, calc.total);
            System.assertEquals(linesForResult[0].Amount__c * apd.Paid_Amount__c / payForResult.Total__c, linesTotal[0]);
            System.assertEquals(linesForResult[1].Amount__c  * apd.Paid_Amount__c / payForResult.Total__c, linesTotal[1]);
            System.assertEquals(linesForResult[2].Amount__c  * apd.Paid_Amount__c / payForResult.Total__c, linesTotal[2]);

        }
    }

    @IsTest
    private static void testHLPCalculateBalanceAllLinesWithSameKeyDoubleAPD() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createCashDisbursements(true);

            Account_Payable__c pay = testData.payables[0].clone();
            pay.Ledger__c = testData.ledgers[3].Id;
            pay.Payee_Reference__c = 'test ref';
            insert pay;

            List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
            Decimal total = 0;
            for (Account_Payable_Line__c line : testData.payableLines) {
                if (line.Account_Payable__c == testData.payables[0].Id) {
                    Account_Payable_Line__c newLine = line.clone();
                    newLine.Account_Payable__c = pay.Id;
                    total += newLine.Amount__c;
                    lines.add(newLine);
                }
            }

            insert lines;

            Cash_Disbursement__c cd = testData.cashDisbursements[0].clone();
            cd.Ledger__c = testData.ledgers[3].Id;
            cd.Debit_GL_Account__c = testData.glAccounts[5].Id;
            insert cd;

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 10
            );
            insert apd;

            AP_Disbursement__c apd2 = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 15
            );
            insert apd2;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {apd2});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(pay.Id);

            System.assertEquals(1, calc.lines.size());
            System.assertEquals(2, calc.existedPay.size());
            System.assertEquals(total, calc.total);
            System.assertEquals(apd.Paid_Amount__c + apd2.Paid_Amount__c, calc.lines[0].total);

        }
    }

    @IsTest
    private static void testHLPCalculateBalanceWithAppliedCreditMemo() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createCashDisbursements(true);

            Account_Payable__c cmPay = testData.payables[4].clone();
            cmPay.Ledger__c = testData.ledgers[3].Id;
            cmPay.Payee_Reference__c = 'test ref cm';
            insert cmPay;

            List<Account_Payable_Line__c> cmLines = new List<Account_Payable_Line__c>();
            Decimal cmTotal = 0;
            for (Account_Payable_Line__c cmLine : testData.payableLines) {
                if (cmLine.Account_Payable__c == testData.payables[4].Id) {
                    Account_Payable_Line__c newLine = cmLine.clone();
                    newLine.Account_Payable__c = cmPay.Id;
                    cmTotal += newLine.Amount__c;
                    cmLines.add(newLine);
                }
            }

            insert cmLines;

            Account_Payable__c pay = testData.payables[0].clone();
            pay.Ledger__c = testData.ledgers[3].Id;
            pay.Payee_Reference__c = 'test ref';
            insert pay;

            List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
            Decimal total = 0;
            for (Account_Payable_Line__c line : testData.payableLines) {
                if (line.Account_Payable__c == testData.payables[0].Id) {
                    Account_Payable_Line__c newLine = line.clone();
                    newLine.Account_Payable__c = pay.Id;
                    total += newLine.Amount__c;
                    lines.add(newLine);
                }
            }

            insert lines;

            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = pay.Id;
            acm.Account_Payable_Credit_Memo__c = cmPay.Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id;
            acm.Amount__c = -15;
            insert acm;

            Cash_Disbursement__c cd = testData.cashDisbursements[0].clone();
            cd.Ledger__c = testData.ledgers[3].Id;
            cd.Debit_GL_Account__c = testData.glAccounts[5].Id;
            insert cd;


            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 10,
                Accounting_Period__c = testData.acctPeriods[1].Id
            );
            insert apd;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {apd});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(pay.Id);

            List<Decimal> linesTotal = new List<Decimal>();
            for (ProportionalDistributionHelper.TransactionAmountCalculationLine line : calc.lines) {
                linesTotal.add(line.total);
            }
            linesTotal.sort();

            System.assertEquals(2, calc.lines.size());
            System.assertEquals(1, calc.existedPay.size());
            System.assertEquals(total + cmTotal, calc.total);

            System.assertEquals(cmTotal * apd.Paid_Amount__c / (total + cmTotal), linesTotal[0]);
            System.assertEquals(total * apd.Paid_Amount__c / (total + cmTotal), linesTotal[1]);

        }
    }

    @IsTest
    private static void testHLPCalculateBalanceAllLinesWithDiscount() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createPayables(true);
            testData.createCashDisbursements(true);

            Account_Payable__c pay = testData.payables[0].clone();
            pay.Ledger__c = testData.ledgers[3].Id;
            pay.Payee_Reference__c = 'test ref';
            insert pay;

            List<Account_Payable_Line__c> lines = new List<Account_Payable_Line__c>();
            Decimal total = 0;
            for (Account_Payable_Line__c line : testData.payableLines) {
                if (line.Account_Payable__c == testData.payables[0].Id) {
                    Account_Payable_Line__c newLine = line.clone();
                    newLine.Account_Payable__c = pay.Id;
                    total += newLine.Amount__c;
                    lines.add(newLine);
                }
            }

            insert lines;

            pay.Discount_Amount__c = 5;
            update pay;

            Cash_Disbursement__c cd = testData.cashDisbursements[0].clone();
            cd.Ledger__c = testData.ledgers[3].Id;
            cd.Debit_GL_Account__c = testData.glAccounts[5].Id;
            insert cd;

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = pay.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 160
            );
            insert apd;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {apd});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(pay.Id);

            System.assertEquals(1, calc.lines.size());
            System.assertEquals(1, calc.existedPay.size());
            System.assertEquals(total, calc.total);
            System.assertEquals(apd.Paid_Amount__c, calc.lines[0].total);

        }
    }

    @IsTest
    private static void testHLPCalculateBalanceAllLinesWithAdjustmentAmount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createBillings(true);
            testData.createCashReceipts();

            Billing__c bill = testData.billings[0].clone();
            bill.Ledger__c = testData.ledgers[3].Id;
            insert bill;

            List<Billing_Line__c> lines = new List<Billing_Line__c>();
            Decimal total = 0;
            for (Billing_Line__c line : testData.billingLines) {
                if (line.Billing__c == testData.billings[0].Id) {
                    Billing_Line__c newLine = line.clone();
                    newLine.Billing__c = bill.Id;
                    total += newLine.Rate__c * newLine.Hours_Units__c;
                    lines.add(newLine);
                }
            }

            insert lines;

            Cash_Receipt__c cr = testData.cashReceipts[0].clone();
            cr.Ledger__c = testData.ledgers[3].Id;
            cr.Credit_GL_Account__c = testData.glAccounts[6].Id;
            insert cr;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Billing__c = bill.Id,
                Cash_Receipt__c = cr.Id,
                Applied_Amount__c = 15,
                Adjustment_Amount__c = 5,
                Adjustment_GL_Account__c = testData.glAccounts.get(0).Id
            );
            insert bcr;

            ProportionalDistributionHelper pdh = new ProportionalDistributionHelper(new List<SObject> {bcr});
            ProportionalDistributionHelper.TransactionAmountCalculation calc = pdh.getTransactionAmountCalculationById(bill.Id);

            System.assertEquals(1, calc.lines.size());
            System.assertEquals(1, calc.existedPay.size());
            System.assertEquals(total, calc.total);
            System.assertEquals(bcr.Applied_Amount__c + bcr.Adjustment_Amount__c, calc.lines[0].total);

        }
    }
}