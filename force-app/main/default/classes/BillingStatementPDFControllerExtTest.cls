@IsTest
public class BillingStatementPDFControllerExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBillingStatementOutstandingPDF() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            PageReference pageRef = Page.BillingOutstandingStatementPDF;
            pageRef.getParameters().put('id', testData.billings[0].Customer__c);
            pageRef.getParameters().put('formatId', testData.billingFormats[2].Id);
            pageRef.getParameters().put('reportType', 'outstanding');
            pageRef.getParameters().put('ledgerId', testData.ledgers[0].Id);
            Test.setCurrentPage(pageRef);

            testData.billings[3].Date__c = Date.newInstance(1992, 2, 10);

            for (Billing__c bill : testData.billings) {
                bill.Customer__c = testData.billings[0].Customer__c;
                bill.Status__c = 'Approved';
            }
            update testData.billings;

            System.assertNotEquals(
                0,
            [   SELECT count()
            FROM Billing_Line__c
            WHERE Billing__c IN :testData.billings
            AND Billing__r.Status__c = 'Approved'
            AND Billing__r.Accounting_Period__r.Status__c = :AccountingPeriodActions.OPEN_STATUS
            ]
            );

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.billings);
            setController.setSelected(setController.getRecords());
            BillingPostTransaction bpt = new BillingPostTransaction(setController);
            bpt.post();
            BillingStatementPDFControllerExt bPdf = new BillingStatementPDFControllerExt(new ApexPages.StandardController(testData.billings[0]));
            // select all outstanding
            System.assertEquals(
                4,
            [   SELECT count()
            FROM Billing__c
            WHERE Id IN :testData.billings
            AND Status__c = 'Posted'
            AND Balance__c != 0
            AND Customer__c = :testData.billings[0].Customer__c
            AND Ledger__c = :testData.ledgers[0].Id
            ]
            );
            // select outstanding until today
            bPdf.todayDate = Date.newInstance(1992, 2, 8);

            System.assertEquals(4, bPdf.getBillingStatementWrapper().size());
        }

    }

    @IsTest
    public static void testBillingStatementActivityPDF() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            PageReference pageRef = Page.BillingOutstandingStatementPDF;
            pageRef.getParameters().put('id', testData.billings[0].Customer__c);
            pageRef.getParameters().put('formatId', testData.billingFormats[2].Id);
            pageRef.getParameters().put('reportType', 'activity');
            pageRef.getParameters().put(
                'startDate',
                String.valueOf(testData.acctPeriods[0].Start_Date__c.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.day()), 1)
            );
            pageRef.getParameters().put(
                'endDate',
                String.valueOf(testData.acctPeriods[1].End_Date__c.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.day()), 1));

            Test.setCurrentPage(pageRef);
            pageRef.getParameters().put('ledgerId', testData.ledgers[0].Id);

            for (Billing__c bill : testData.billings) {
                bill.Customer__c = testData.billings[0].Customer__c;
                bill.Status__c = 'Approved';
            }
            update testData.billings;
            System.assertNotEquals(
                0, [
                SELECT count()
                FROM Billing_Line__c
                WHERE (Billing__c IN :testData.billings AND Billing__r.Status__c = 'Approved' AND Billing__r.Accounting_Period__r.Status__c = :AccountingPeriodActions.OPEN_STATUS)
            ]);

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.billings);
            setController.setSelected(setController.getRecords());
            BillingPostTransaction bpt = new BillingPostTransaction(setController);
            bpt.post();

            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
            for (Cash_Receipt__c cr : testData.cashReceipts) {
                Cash_Receipt__c cloneCr = cr.clone(false,true);
                cloneCr.Account__c = testData.billings[0].Customer__c;
                cashReceipts.add(cloneCr);
            }
            insert cashReceipts;

            BillingStatementPDFControllerExt bPdf = new BillingStatementPDFControllerExt(
                new ApexPages.StandardController(testData.billings[0])
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Billing__c
                    WHERE (
                        Id IN :testData.billings
                        AND Status__c = 'Posted'
                        AND Balance__c > 0
                        AND Customer__c = :testData.billings[0].Customer__c
                        AND Ledger__c = :testData.ledgers[0].Id
                    )
                ]
            );

            System.assertEquals(11, bPdf.getBillingStatementWrapper().size());
        }
    }

    @IsTest
    public static void testBillingStatementActivityPDFWithAlternatePayors() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account mainAccount = testData.accounts[0];
            Account alternateAccount = testData.accounts[1];
            List<Billing__c> billList = new List<Billing__c>();
            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            //Create test invoice
            billList.add(new Billing__c(
                Customer__c = mainAccount.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c
            ));

            billList.add(new Billing__c(
                Customer__c = alternateAccount.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c + 10
            ));
            insert billList;

            billLineList.add(new Billing_Line__c(
                Billing__c = billList[0].Id,
                Hours_Units__c = 1,
                Rate__c = 1000,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            ));

            billLineList.add(new Billing_Line__c(
                Billing__c = billList[1].Id,
                Hours_Units__c = 1,
                Rate__c = -500,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            ));
            insert billLineList;

            //Create test Cash Receipt for Alternate Payor
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = alternateAccount.Id,
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c + 15,
                Payment_Reference__c = 'test ref xxx',
                Amount__c = 200
            );
            insert testCR;

            //Apply Credit Memo
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = billList[0].Id,
                Billing_Credit_Memo__c = billList[1].Id,
                Amount__c = -500,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcm;

            //Apply Cash Receipt
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing__c = billList[0].Id,
                Cash_Receipt__c = testCR.Id,
                Applied_Amount__c = 200
            );
            insert bcr;

            //post Invoice and Credit Memo
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(billList);
            System.assertEquals(true, postResults[0].isSuccess);

            Test.stopTest();

            PageReference pageRef = Page.BillingOutstandingStatementPDF;
            pageRef.getParameters().put('id', billList[0].Customer__c);
            pageRef.getParameters().put('formatId', testData.billingFormats[2].Id);
            pageRef.getParameters().put('reportType', 'activity');
            pageRef.getParameters().put(
                'startDate',
                String.valueOf(testData.acctPeriods[0].Start_Date__c.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.day()), 1)
            );
            pageRef.getParameters().put(
                'endDate',
                String.valueOf(testData.acctPeriods[1].End_Date__c.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.day()), 1));

            Test.setCurrentPage(pageRef);
            pageRef.getParameters().put('ledgerId', testData.ledgers[0].Id);
            pageRef.getParameters().put('includeAltPayor', 'true');

            BillingStatementPDFControllerExt bPdf = new BillingStatementPDFControllerExt(
                new ApexPages.StandardController(mainAccount)
            );

            List<BillingStatementPDFControllerExt.BillingStatementWrapper> rows = bPdf.getBillingStatementWrapper();

            //Expected
            // 1 row for Selected Payor Invoice
            // 1 row for Applied Alternate Payor Credit Memo
            // 1 row for Applied Alternate Payor Cash Receipt
            System.assertEquals(3, rows.size());
            System.assertEquals(true, bPdf.showFootnote);
            
            String testInvoiceName = [SELECT Name FROM Billing__c WHERE Id = :billList[0].Id].Name;
            String testCreditMemoName = [SELECT Name FROM Billing__c WHERE Id = :billList[1].Id].Name;

            for (BillingStatementPDFControllerExt.BillingStatementWrapper row : rows) {
                if (row.statementSource == 'billing') {
                    System.assertEquals(row.reference, testInvoiceName);
                }
                else if (row.statementSource == 'billing-credit-memo') {
                    System.assertEquals(row.reference, testCreditMemoName);
                }
                else if (row.statementSource == 'billing-cash-receipt') {
                    System.assertEquals(testCR.Payment_Reference__c, row.reference);
                }
                else {
                    System.assert(false, 'the row does not belong to any of available sources');
                }
            }
        }
    }

    @IsTest
    public static void testBillingStatementActivityPDFWithAlternatePayorsDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account mainAccount = testData.accounts[0];
            Account alternateAccount = testData.accounts[1];

            //Create test invoice
            List<Billing__c> billList = new List<Billing__c>();
            List<Billing_Line__c> billLineList = new List<Billing_Line__c>();

            //Create test invoice
            billList.add(new Billing__c(
                Customer__c = mainAccount.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c
            ));

            billList.add(new Billing__c(
                Customer__c = alternateAccount.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c + 10
            ));
            insert billList;

            billLineList.add(new Billing_Line__c(
                Billing__c = billList[0].Id,
                Hours_Units__c = 1,
                Rate__c = 1000,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            ));

            billLineList.add(new Billing_Line__c(
                Billing__c = billList[1].Id,
                Hours_Units__c = 1,
                Rate__c = -500,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            ));
            insert billLineList;

            //Create test Cash Receipt for Alternate Payor
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = alternateAccount.Id,
                Receipt_Date__c = testData.acctPeriods[0].Start_Date__c + 15,
                Payment_Reference__c = 'test ref xxx',
                Amount__c = 200
            );
            insert testCR;

            //Apply Credit Memo
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = billList[0].Id,
                Billing_Credit_Memo__c = billList[1].Id,
                Amount__c = -500,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert bcm;

            //Apply Cash Receipt
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing__c = billList[0].Id,
                Cash_Receipt__c = testCR.Id,
                Applied_Amount__c = 200
            );
            insert bcr;

            //post Invoice and Credit Memo
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(billList);
            System.assertEquals(true, postResults[0].isSuccess);
            
            Test.stopTest();
            PageReference pageRef = Page.BillingOutstandingStatementPDF;
            pageRef.getParameters().put('id', billList[0].Customer__c);
            pageRef.getParameters().put('formatId', testData.billingFormats[2].Id);
            pageRef.getParameters().put('reportType', 'activity');
            pageRef.getParameters().put(
                'startDate',
                String.valueOf(testData.acctPeriods[0].Start_Date__c.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.day()), 1)
            );
            pageRef.getParameters().put(
                'endDate',
                String.valueOf(testData.acctPeriods[1].End_Date__c.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.day()), 1));

            Test.setCurrentPage(pageRef);
            pageRef.getParameters().put('ledgerId', testData.ledgers[0].Id);
            pageRef.getParameters().put('includeAltPayor', 'false');

            BillingStatementPDFControllerExt bPdf = new BillingStatementPDFControllerExt(
                new ApexPages.StandardController(mainAccount)
            );

            List<BillingStatementPDFControllerExt.BillingStatementWrapper> rows = bPdf.getBillingStatementWrapper();

            //Expected
            // 1 row for Selected Payor Invoice
            // No rows for Applied Alternate Payor Credit Memo
            // No rows for Applied Alternate Payor Cash Receipt
            System.assertEquals(1, rows.size());
            System.assertEquals(false, bPdf.showFootnote);

            String invName = [SELECT Name FROM Billing__c WHERE Id = :billList[0].Id].Name;
            for (BillingStatementPDFControllerExt.BillingStatementWrapper row : rows) {
                System.assertEquals(row.reference, invName);
            }
        }
    }

    @IsTest
    public static void testBillingStatementActivityPDF_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBillings()
                .createCashReceipts();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                List<Billing__c> billList = testData.billings;
                Billing__c newCurrencyBill = new Billing__c(
                    Customer__c = testData.billings[0].Customer__c,
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30
                );

                newCurrencyBill.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newCurrencyBill;

                Billing_Line__c newCurrencyLine = new Billing_Line__c(
                    Billing__c = newCurrencyBill.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                );
                insert newCurrencyLine;

                billList.add(newCurrencyBill);

                PageReference pageRef = Page.BillingOutstandingStatementPDF;
                pageRef.getParameters().put('id', testData.billings[0].Customer__c);
                pageRef.getParameters().put('formatId', testData.billingFormats[2].Id);
                pageRef.getParameters().put('reportType', 'activity');
                pageRef.getParameters().put('startDate', String.valueOf(testData.acctPeriods[0].Start_Date__c.year()) + '-' + FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.month()),1) + '-' + FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[0].Start_Date__c.day()),1));
                pageRef.getParameters().put('endDate', String.valueOf(testData.acctPeriods[1].End_Date__c.year()) + '-' + FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.month()),1) + '-' + FinancialSuiteUtils.leftPad(String.valueOf(testData.acctPeriods[1].End_Date__c.day()),1));
                Test.setCurrentPage(pageRef);
                pageRef.getParameters().put('ledgerId', testData.ledgers[0].Id);
                pageRef.getParameters().put('currencyIsoCode', newCurrencyIsoCode);

                for (Billing__c bill : billList) {
                    bill.Customer__c = testData.billings[0].Customer__c;
                    bill.Status__c = 'Approved';
                }
                update billList;
                System.assertNotEquals(0,[Select count() From Billing_Line__c where (Billing__c IN :billList and Billing__r.Status__c = 'Approved' and Billing__r.Accounting_Period__r.Status__c = :AccountingPeriodActions.OPEN_STATUS)]);
                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(billList);
                setController.setSelected(setController.getRecords());
                BillingPostTransaction bpt = new BillingPostTransaction(setController);
                bpt.post();

                List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>();
                for (Cash_Receipt__c cr : testData.cashReceipts) {
                    Cash_Receipt__c cloneCr = cr.clone(false,true);
                    cloneCr.Account__c = testData.billings[0].Customer__c;
                    cashReceipts.add(cloneCr);
                }
                insert cashReceipts;

                BillingStatementPDFControllerExt bPdf = new BillingStatementPDFControllerExt(
                    new ApexPages.StandardController(newCurrencyBill)
                );
                System.assertEquals(
                    3, [
                    SELECT count()
                    FROM Billing__c
                    WHERE (
                        Id IN :testData.billings
                        AND Status__c = 'Posted'
                        AND Balance__c > 0
                        AND Customer__c = :testData.billings[0].Customer__c
                        AND Ledger__c = :testData.ledgers[0].Id
                    )
                ]
                );

                System.assertEquals(1, bPdf.getBillingStatementWrapper().size());
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void activityStmtExcludesRefundActivity(){
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            // clone CR
            Cash_Receipt__c cr = testData.cashReceipts[0].clone(false, true, false, false);

            // add to account with clean billing activity
            cr.Account__c = testData.accounts[1].Id;

            insert cr;

            // refund CR
            CreditsAndRefundsOptions opts = new CreditsAndRefundsOptions(cr.Id);
            opts.refundDate = cr.Receipt_Date__c;
            ServiceResult res = CreditsAndRefunds.createRefundForCashReceipt(opts);
            System.assert(res.isSuccess);
            Test.stopTest();

            // check reported activity excludes CR
            PageReference pageRef = Page.BillingOutstandingStatementPDF;
            pageRef.getParameters().put('id', cr.Account__c);
            pageRef.getParameters().put('formatId', testData.billingFormats[2].Id);
            pageRef.getParameters().put('reportType', 'activity');
            Date startDate = cr.Receipt_Date__c.addDays(-5);
            pageRef.getParameters().put(
                'startDate',
                String.valueOf(startDate.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(startDate.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(startDate.day()), 1)
            );
            Date endDate = cr.Receipt_Date__c.addDays(5);
            pageRef.getParameters().put(
                'endDate',
                String.valueOf(endDate.year()) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(endDate.month()), 1) +
                    '-' +
                    FinancialSuiteUtils.leftPad(String.valueOf(endDate.day()), 1));

            Test.setCurrentPage(pageRef);
            pageRef.getParameters().put('ledgerId', testData.ledgers[0].Id);


            BillingStatementPDFControllerExt ctrl = new BillingStatementPDFControllerExt(
                new ApexPages.StandardController(new Account(Id=cr.Account__c))
            );

            List<BillingStatementPDFControllerExt.BillingStatementWrapper> activities = ctrl.getBillingStatementWrapper();

            System.assertNotEquals(0, activities.size());

            Set<Id> activitySourceIds = new Set<Id>();
            for(BillingStatementPDFControllerExt.BillingStatementWrapper activity : activities){
                if(activity.receipt != null){
                    activitySourceIds.add(activity.receipt.Id);
                }
            }

            System.assert(activitySourceIds.contains(cr.Id));
            System.assert(activitySourceIds.contains(res.data));
        }
    }
}