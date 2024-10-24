@IsTest
private class LedgerInquiryInXlsFormatControllerTest {

    @TestSetup
    private static void testDataSetup() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        AccountingPeriodHandler.reset();

        System.runAs(testData.users.get(1)) {
            //Create source documents
            testData.createBillings();

            Test.startTest();
            AccountingPeriodActions.isFirstRun = false;
            for (Accounting_Period__c ap : testData.acctPeriods) {
                ap.Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            }
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            System.assertEquals(7, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.ARCHIVED_STATUS]);

            Date acctDate = Date.newInstance(System.today().year(), System.today().month() - 3, 1);
            List<Accounting_Period__c> newPeriods = new List<Accounting_Period__c>();

            for (Integer i = 0; i < 8; i++) {
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

            System.assertEquals(8, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS LIMIT 100]);

            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());

            List<Accounting_Period__c> closedPeriods = new List<Accounting_Period__c>{
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -3),
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -2),
                AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(currentPeriod, -1)
            };

            AccountingPeriodActions.isFirstRun = false;
            for (Accounting_Period__c ap : closedPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }
            update closedPeriods;
            AccountingPeriodActions.isFirstRun = true;

            System.assertEquals(3, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.CLOSED_STATUS LIMIT 100]);
            System.assertEquals(5, [SELECT count() FROM Accounting_Period__c WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS LIMIT 100]);
        }
    }


    @IsTest
    private static void testExportAsXlsFile() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = currentPeriod.Start_Date__c,
                Billing_Cycle_End_Date__c = currentPeriod.End_Date__c + 3,
                Date__c = currentPeriod.Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = currentPeriod.End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempBilling;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = currentPeriod.Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert tempBillingLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c> {tempBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            //Prepare data as it comes from a client side
            String base64Options = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(options)));
            PageReference pageRef = Page.LedgerInquiryInXlsFormat;
            pageRef.getParameters().put('options', base64Options);
            Test.setCurrentPage(pageRef);

            LedgerInquiryInXlsFormatController controller = new LedgerInquiryInXlsFormatController();
            System.assertEquals(false, controller.theReport.lines.isEmpty());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testExportAsXlsFileNoData() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            //Prepare data as it comes from a client side
            String base64Options = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(options)));
            PageReference pageRef = Page.LedgerInquiryInXlsFormat;
            pageRef.getParameters().put('options', base64Options);
            Test.setCurrentPage(pageRef);

            Test.startTest();
            LedgerInquiryInXlsFormatController controller = new LedgerInquiryInXlsFormatController();
            System.assertEquals(true, controller.theReport.lines.isEmpty());
        }
    }

    @IsTest
    private static void testExportAsXlsFileAggregateBy() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c currentPeriod = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(System.today());
            Billing__c tempBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = currentPeriod.Start_Date__c,
                Billing_Cycle_End_Date__c = currentPeriod.End_Date__c + 3,
                Date__c = currentPeriod.Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = currentPeriod.Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = currentPeriod.End_Date__c + 30,
                Ledger__c = testData.ledgers[0].Id
            );
            insert tempBilling;

            Billing_Line__c tempBillingLine = new Billing_Line__c(
                Billing__c = tempBilling.Id,
                Date__c = currentPeriod.Start_Date__c.addDays(10),
                Hours_Units__c = 1,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert tempBillingLine;

            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Billing__c> {tempBilling});
            System.assertEquals(true, postResults[0].isSuccess);

            LedgerInquiryFinancialReportOptions options = new LedgerInquiryFinancialReportOptions();
            options.aggregatedBy = 'source';
            //Prepare data as it comes from a client side
            String base64Options = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(options)));
            PageReference pageRef = Page.LedgerInquiryInXlsFormat;
            pageRef.getParameters().put('options', base64Options);
            Test.setCurrentPage(pageRef);

            LedgerInquiryInXlsFormatController controller = new LedgerInquiryInXlsFormatController();
            System.assertEquals(false, controller.theReport.lines.isEmpty());
            Test.stopTest();
        }
    }

}