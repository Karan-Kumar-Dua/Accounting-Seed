@IsTest
private class BillingMergeTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testMergeWithDifferentLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling1 = testData.billings[0];
            Billing__c testBilling2 = testData.billings[1];

            testBilling2.Ledger__c = testData.ledgers[2].Id;//another Transactional ledger
            update testBilling2;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Billing__c>{
                    testBilling1, testBilling2
                }
            );
            setController.setSelected(setController.getRecords());

            BillingMerge bm = new BillingMerge(setController);
            System.assertEquals(true, bm.isValidationError);
            System.assertEquals(BillingMerge.MULTI_LEDGER_ERROR, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testMergeCreditMemoAndInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Billing__c testCreditMemo = testData.billings[2];
            Billing__c testInvoice = testData.billings[0];
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Billing__c>{
                    testCreditMemo, testInvoice
                }
            );
            setController.setSelected(setController.getRecords());

            BillingMerge bm = new BillingMerge(setController);
            System.assertEquals(true, bm.isValidationError);
            System.assertEquals(BillingMerge.MIXED_TYPE_ERROR, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testBillingMerge() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling1 = testData.billings[0];
            Integer lineQuantityToAssert = [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :testBilling1.Id];
            Billing__c testBilling2 = testData.billings[1];
            lineQuantityToAssert += [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :testBilling2.Id];
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Billing__c>{
                    testBilling1, testBilling2
                }
            );
            setController.setSelected(setController.getRecords());

            BillingMerge bm = new BillingMerge(setController);
            bm.billingMergeWrapperList[0].bill.Accounting_Period__c = testData.acctPeriods[0].Id;
            bm.billingMergeWrapperList[0].bill.Billing_Format__c = testData.billingFormats[0].Id;
            bm.mergeBillings();

            System.assertEquals(0, [SELECT COUNT() FROM Billing__c WHERE Id = :testData.billings[0].Id]);
            System.assertEquals(0, [SELECT COUNT() FROM Billing__c WHERE Id = :testData.billings[1].Id]);

            System.assertEquals(
                lineQuantityToAssert,
                [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :bm.billingMergeWrapperList[0].bill.Id]
            );
            Test.stopTest();
        }

    }

    @IsTest
    private static void testValidateCurrencies() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBillings();

            System.runAs(testData.users.get(1)) {

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrency)) {
                    return;
                }

                testData.billings[0].put('CurrencyIsoCode', newCurrency);

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Schema.SObjectType.Billing__c.fields.getMap().get('CurrencyIsoCode')
                    }
                );
                update testData.billings[0];
                TriggerObserver.reset();

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.billings);
                setController.setSelected(setController.getRecords());

                BillingMerge bm = new BillingMerge(setController);

                System.assertEquals(BillingMerge.MULTI_CURRENCY_ERROR, ApexPages.getMessages()[0].getDetail());
            }
        } catch (Exception ex) {

        }
    }

    @IsTest
    private static void testInitBillingWrapper() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {

            Billing__c testBilling1 = testData.billings[2];
            testBilling1.Customer__c = testData.accounts[1].Id;
            Billing__c testBilling2 = testData.billings[3];
            testBilling2.Customer__c = testData.accounts[1].Id;

            List<Billing__c> testBillings = new List<Billing__c>{
                testBilling1, testBilling2
            };

            update testBillings;

            testBillings.add(testData.billings[0]);//Billing with other Customer than the rest

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testBillings);
            setController.setSelected(setController.getRecords());

            BillingMerge bm = new BillingMerge(setController);

            System.assertEquals(2, bm.billingMergeWrapperList.size());
            System.assertEquals(2, bm.billingMergeWrapperList[0].billLines.size());
            System.assertEquals(2, bm.billingMergeWrapperList[1].billLines.size());
        }
    }

    @IsTest
    private static void testMergeWithAERecord() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Scheduled_Revenue_Expense__c re = new Scheduled_Revenue_Expense__c(
                Name = 'Test Rev 1',
                Amount__c = 400,
                Billing__c = testData.billings[0].Id,
                Credit_GL_Account__c = testData.glAccounts[6].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Scheduled'
            );
            insert re;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Billing__c>{
                    testData.billings[0]
                }
            );
            setController.setSelected(setController.getRecords());

            BillingMerge bm = new BillingMerge(setController);
            System.assertEquals(true, bm.isValidationError);
            System.assertEquals(BillingMerge.AE_EXIST_ERROR, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    private static void testMergeWithCloseARAccountingPeriodSoftClose() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Date newDate = Date.newInstance(1991, 10, 16);

            Accounting_Period__c testAccPeriod = [
                SELECT Id, Name, Close_AR__c
                FROM Accounting_Period__c
                WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS AND Start_Date__c < :newDate AND End_Date__c > :newDate
            ];

            testAccPeriod.Close_AR__c = true;
            update testAccPeriod;

            Billing__c testBilling1 = testData.billings[0];
            Billing__c testBilling2 = testData.billings[1];
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(
                new List<Billing__c>{
                    testBilling1, testBilling2
                }
            );
            setController.setSelected(setController.getRecords());

            BillingMerge bm = new BillingMerge(setController);
            bm.billingMergeWrapperList[0].bill.Accounting_Period__c = testAccPeriod.Id;
            bm.mergeBillings();

            System.assertEquals(0, [SELECT COUNT() FROM Billing__c WHERE Id = :testData.billings[0].Id]);
            System.assertEquals(0, [SELECT COUNT() FROM Billing__c WHERE Id = :testData.billings[1].Id]);
            Test.stopTest();

        }
    }
}