@IsTest
private class BillingPostBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testBatchPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users[1]) {
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Status__c FROM Billing__c
                ][0].Status__c
            );
            Test.startTest();
            //Run batch job to post Billings with "Approved" Posting Status
            BillingPostBatch batchInstance = new BillingPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Billings'}),
                null
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Status__c FROM Billing__c
                ][0].Status__c
            );
            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(5, ajr.Processed__c);
            System.assertEquals(5, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    private static void testBatchPostFailure() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users[1]) {
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, testData.billings[0].Status__c);

            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();
            //Run batch job to post Billings with "Approved" Posting Status
            BillingPostBatch batchInstance = new BillingPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Billings'}),
                null
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();
            //Make sure that Billing has not been posted successfully and related task has been created
            List<Task> tasks = [SELECT Id, Description, Status FROM Task WHERE WhatId = :testData.billings[0].Id];
            System.assertNotEquals(true, tasks.isEmpty());
            System.assertEquals(AbstractPostHandler.ACCOUNTING_PERIOD_CLOSED_ERROR_MESSAGE, tasks[0].Description);
            for(Task t : tasks){
                System.AssertEquals('Completed', t.Status);
            }

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c, Notes__c FROM Automated_Job_Results__c];

            System.assertEquals('Scheduled Post', ajr.Schedule_Job_Type__c);
            System.assertEquals(5, ajr.Processed__c);
            System.assertEquals(0, ajr.Succeeded__c);
            System.assertEquals(5, ajr.Failed__c);
        }
    }

    @IsTest
    private static void testBatchPostAndCalculateAvalaraTaxesHLP() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            testData.setHeaderLevelPost();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100'
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //re-query billing line to have all necessary fields populated
            testBillingLine = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            //Run batch job to post Billings with "Approved" Posting Status
            BillingPostBatch batchInstance = new BillingPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Billings'}),
                null
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();

            Billing_Line__c checkedBLine = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, checkedBLine.Billing__r.Status__c);
            System.assertEquals(
                checkedBLine.Hours_Units__c * checkedBLine.Rate__c / 10,
                checkedBLine.Tax_Amount2__c
            );
        }
    }

    @IsTest
    private static void testBatchPostAndCalculateAvalaraTaxesLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost();

        System.runAs(testData.users.get(1)) {
            //Enable Avalara Tax Calculation
            testData.enableAvaTaxCalculation();
            //create taxable product
            Product2 testProduct = new Product2(
                Name = 'Jewelry',
                Expense_GL_Account__c = testData.glAccounts[12].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Accounting_Type__c = 'Taxable Product'
            );
            insert testProduct;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100',
                Ledger__c = testData.ledgers[0].Id
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Product__c = testProduct.Id,
                Rate__c = 1000,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert testBillingLine;

            //re-query billing line to have all necessary fields populated
            testBillingLine = [
                SELECT Id, Name, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Id = :testBillingLine.Id
            ];

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testBilling, new List<Billing_Line__c>{testBillingLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            //Run batch job to post Billings with "Approved" Posting Status
            BillingPostBatch batchInstance = new BillingPostBatch(
                new SourceRecordPostBatchChainController(new List<String>{'Billings'}),
                null
            );
            Database.executeBatch(batchInstance);
            Test.stopTest();

            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Billing__r.Status__c, Hours_Units__c, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testBilling.Id
                AND Product__c = :AvaTaxHelper.getSalesTaxProductId(testBilling)
            ];

            System.assertNotEquals(true, salesTaxLines.isEmpty(), 'sales tax line has not been created');
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, salesTaxLines[0].Billing__r.Status__c);
            System.assertEquals(
                testBillingLine.Hours_Units__c * testBillingLine.Rate__c / 10,
                salesTaxLines[0].Rate__c
            );
        }
    }

}