@IsTest
public class BillingActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPreventOverAppliedBillingsByBCR() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true)
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 500
            );

            DmlException dmlEx;
            try {
                insert testBCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    SObjectActions.OVER_APPLIED_ERROR,
                    new List<String> {Billing__c.getSObjectType().getDescribe().getLabel()}
                ),
                dmlEx.getDmlMessage(0));
        }
        Test.stopTest();
    }

    @IsTest
    public static void testPreventOverAppliedBillingsByBCRWithNegativeAdjustment() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true)
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[1].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 500,
                Adjustment_Amount__c = -40,
                Adjustment_GL_Account__c = testData.glAccounts.get(0).Id
            );

            DmlException dmlEx;
            try {
                insert testBCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    SObjectActions.OVER_APPLIED_ERROR,
                    new List<String> {Billing__c.getSObjectType().getDescribe().getLabel()}
                ),
                dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            testBCR.Adjustment_Amount__c = -50;

            try {
                insert testBCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            Test.stopTest();
            System.assertEquals(NULL, dmlEx);            
        }
    }

    @IsTest
    public static void testNotOverAppliedBillingsByBCRWithNegativeAdjustment() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true)
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[1].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 100,
                Adjustment_Amount__c = -650,
                Adjustment_GL_Account__c = testData.glAccounts.get(0).Id
            );

            DmlException dmlEx;
            try {
                insert testBCR;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            Billing__c bill = [SELECT Id, Balance__c FROM Billing__c WHERE Id = :testData.billings[0].Id];
            System.assertEquals(450 - 100 - (-650), bill.Balance__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPreventOverAppliedBillingsByBCM() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true)
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -500;

            DmlException dmlEx;
            try {
                insert bcm;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(true,
                dmlEx.getDmlMessage(0).contains(
                    String.format(
                SObjectActions.OVER_APPLIED_ERROR,
                new List<String> {Billing__c.getSObjectType().getDescribe().getLabel()}
            )));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testRequiredFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c bill = testData.billings[0].clone(false, true);
            bill.Date__c = Date.newInstance(1970, 3, 13);
            bill.Accounting_Period__c = NULL;

            DMLException dmlEx;
            try {
                insert bill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            //remove Billing format from Actual Ledger to prevent auto population on Billing
            LedgerActions.isPreventUpdateOverride = true;
            testData.ledgers[0].Default_Billing_Format__c = NULL;
            update testData.ledgers[0];
            LedgerActions.isPreventUpdateOverride = false;

            bill = testData.billings[0].clone(false, true);
            bill.Billing_Format__c = NULL;
            try {
                insert bill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(BillingActions.BILLING_FORMAT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testRequiredFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Accounting_Period__c = NULL;

            DMLException dmlEx;
            try {
                update testData.billings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            testData.billings[2].Billing_Format__c = NULL;
            try {
                update testData.billings[2];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(BillingActions.BILLING_FORMAT_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = NULL;
            Billing__c bill = testData.billings[0].clone(false, true);
            insert bill;
            bill.Ledger__c = NULL;

            try {
                update bill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testPreventUpdateActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DMLException dmlEx;
            // Test update no error since no fields changed.
            Billing__c bill = [
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ];

            try {
                update bill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            // Test update error since attempted to change protected field on billing.
            try {
                bill.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                update bill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sdv = new BillingFieldUpdateValidator();
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR,
                    new List<String>{
                        sdv.formatFieldStrings(sdv.lockedUpdateFieldsPosted),
                        AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                    }
                ),
                dmlEx.getDMLMessage(0)
            );

            dmlEx = NULL;
            // Test update error since attempted to add new billing line.
            try {
                Billing_Line__c billingLine = testData.billingLines[0].clone(false, true);
                insert billingLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_INSERT_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    public static void testBillingFormatSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.ledgers[2].Default_Billing_Format__c = testData.billingFormats[1].Id;
            update testData.ledgers[2];

            Billing__c bill = testData.billings[0].clone(false, true, false, false);
            bill.Ledger__c = testData.ledgers[2].Id;
            bill.Billing_Format__c = NULL;
            insert bill;

            System.assertEquals(
                testData.billingFormats[1].Id,
                [SELECT Billing_Format__c FROM Billing__c WHERE Id = :bill.Id].Billing_Format__c
            );
        }
    }

    @IsTest
    public static void testAssociateBillingTermsAndDueDateAndDiscountInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.accounts[0].Billing_Days_Due__c = 90;
            testData.accounts[0].Billing_Terms_Name__c = 'This is a test';
            testData.accounts[0].Billing_Discount_Percent__c = 10;
            testData.accounts[0].Billing_Discount_Days_Due__c = 30;
            update testData.accounts[0];

            // Create billing and check default billing due date
            Billing__c bill = testData.billings[0].clone(false, true, false, false);
            bill.Due_Date2__c = NULL;
            insert bill;

            System.assertEquals(bill.Date__c + 90, [SELECT Due_Date2__c FROM Billing__c WHERE Id = :bill.Id].Due_Date2__c);
            System.assertEquals(bill.Date__c + 30, [SELECT Discount_Due_Date__c FROM Billing__c WHERE Id = :bill.Id].Discount_Due_Date__c);

            testData.accounts[0].Billing_Days_Due__c = NULL;
            testData.accounts[0].Billing_Terms_Name__c = NULL;
            testData.accounts[0].Billing_Discount_Days_Due__c = NULL;
            update testData.accounts[0];


            // Create billing and check default billing due date
            bill = testData.billings[0].clone(false, true, false, false);
            bill.Due_Date2__c = NULL;
            insert bill;

            System.assertEquals(bill.Date__c, [SELECT Due_Date2__c FROM Billing__c WHERE Id = :bill.Id].Due_Date2__c);
            System.assertEquals(NULL, [SELECT Discount_Due_Date__c FROM Billing__c WHERE Id = :bill.Id].Discount_Due_Date__c);
        }

    }

    @IsTest
    public static void testAssociateBillingAddressAndBillingContactFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.accounts[0].BillingStreet = '9413 Eddy Line Lane';
            testData.accounts[0].BillingCity = 'Laurel';
            testData.accounts[0].BillingState = 'MD';
            testData.accounts[0].BillingPostalCode = '20723';
            testData.accounts[0].BillingCountry = 'USA';
            testData.accounts[0].Billing_Contact__c = testData.contacts[1].Id;
            update testData.accounts[0];

            // Create billing and check address fields
            Billing__c bill = testData.billings[1].clone(false, true, false, false);
            bill.Billing_Contact__c = NULL;
            insert bill;

            System.assertEquals(
                testData.accounts[0].Billing_Contact__c,
                [SELECT Billing_Contact__c FROM Billing__c WHERE Id = :bill.Id].Billing_Contact__c
            );
            System.assertEquals(
                testData.accounts[0].BillingStreet,
                [SELECT Billing_Street__c FROM Billing__c WHERE Id = :bill.Id].Billing_Street__c
            );
            System.assertEquals(
                testData.accounts[0].BillingCity,
                [SELECT Billing_City__c FROM Billing__c WHERE Id = :bill.Id].Billing_City__c
            );
            System.assertEquals(
                testData.accounts[0].BillingState,
                [SELECT Billing_State__c FROM Billing__c WHERE Id = :bill.Id].Billing_State__c
            );
            System.assertEquals(
                testData.accounts[0].BillingPostalCode,
                [SELECT Billing_PostalCode__c FROM Billing__c WHERE Id = :bill.Id].Billing_PostalCode__c
            );
            System.assertEquals(
                testData.accounts[0].BillingCountry,
                [SELECT Billing_Country__c FROM Billing__c WHERE Id = :bill.Id].Billing_Country__c
            );

            // Create billing and check address fields
            bill = testData.billings[1].clone(false, true, false, false);
            bill.Billing_Contact__c = NULL;
            bill.Billing_Street__c = '2744 Selma Lane';
            bill.Billing_City__c = 'Farmers Branch';
            bill.Billing_State__c = 'TX';
            bill.Billing_PostalCode__c = '75234';
            bill.Billing_Country__c = NULL;
            insert bill;

            System.assertEquals(
                bill.Billing_Street__c,
                [SELECT Billing_Street__c FROM Billing__c WHERE Id = :bill.Id].Billing_Street__c
            );
            System.assertEquals(
                bill.Billing_City__c,
                [SELECT Billing_City__c FROM Billing__c WHERE Id = :bill.Id].Billing_City__c
            );
            System.assertEquals(
                bill.Billing_State__c,
                [SELECT Billing_State__c FROM Billing__c WHERE Id = :bill.Id].Billing_State__c
            );
            System.assertEquals(
                bill.Billing_PostalCode__c,
                [SELECT Billing_PostalCode__c FROM Billing__c WHERE Id = :bill.Id].Billing_PostalCode__c
            );
            System.assertEquals(
                bill.Billing_Country__c,
                [SELECT Billing_Country__c FROM Billing__c WHERE Id = :bill.Id].Billing_Country__c
            );
        }

    }

    @IsTest
    public static void testAssociateShippingAddressAndShippingContactFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.accounts[0].ShippingStreet = '9413 Eddy Line Lane';
            testData.accounts[0].ShippingCity = 'Laurel';
            testData.accounts[0].ShippingState = 'MD';
            testData.accounts[0].ShippingPostalCode = '20723';
            testData.accounts[0].ShippingCountry = 'USA';
            testData.accounts[0].Shipping_Contact__c = testData.contacts[1].Id;
            update testData.accounts[0];

            // Create billing and check address fields
            Billing__c bill = testData.billings[1].clone(false, true, false, false);
            bill.Shipping_Contact__c = NULL;
            insert bill;

            System.assertEquals(
                testData.accounts[0].Shipping_Contact__c,
                [SELECT Shipping_Contact__c FROM Billing__c WHERE Id = :bill.Id].Shipping_Contact__c
            );
            System.assertEquals(
                testData.accounts[0].ShippingStreet,
                [SELECT Shipping_Street__c FROM Billing__c WHERE Id = :bill.Id].Shipping_Street__c
            );
            System.assertEquals(
                testData.accounts[0].ShippingCity,
                [SELECT Shipping_City__c FROM Billing__c WHERE Id = :bill.Id].Shipping_City__c
            );
            System.assertEquals(
                testData.accounts[0].ShippingState,
                [SELECT Shipping_State__c FROM Billing__c WHERE Id = :bill.Id].Shipping_State__c
            );
            System.assertEquals(
                testData.accounts[0].ShippingPostalCode,
                [SELECT Shipping_PostalCode__c FROM Billing__c WHERE Id = :bill.Id].Shipping_PostalCode__c
            );
            System.assertEquals(
                testData.accounts[0].ShippingCountry,
                [SELECT Shipping_Country__c FROM Billing__c WHERE Id = :bill.Id].Shipping_Country__c
            );

            // Create Shipping and check address fields
            bill = testData.billings[1].clone(false, true, false, false);
            bill.Shipping_Contact__c = NULL;
            bill.Shipping_Street__c = '2744 Selma Lane';
            bill.Shipping_City__c = 'Farmers Branch';
            bill.Shipping_State__c = 'TX';
            bill.Shipping_PostalCode__c = '75234';
            bill.Shipping_Country__c = NULL;
            insert bill;

            System.assertEquals(
                bill.Shipping_Street__c,
                [SELECT Shipping_Street__c FROM Billing__c WHERE Id = :bill.Id].Shipping_Street__c
            );
            System.assertEquals(
                bill.Shipping_City__c,
                [SELECT Shipping_City__c FROM Billing__c WHERE Id = :bill.Id].Shipping_City__c
            );
            System.assertEquals(
                bill.Shipping_State__c,
                [SELECT Shipping_State__c FROM Billing__c WHERE Id = :bill.Id].Shipping_State__c
            );
            System.assertEquals(
                bill.Shipping_PostalCode__c,
                [SELECT Shipping_PostalCode__c FROM Billing__c WHERE Id = :bill.Id].Shipping_PostalCode__c
            );
            System.assertEquals(
                bill.Shipping_Country__c,
                [SELECT Shipping_Country__c FROM Billing__c WHERE Id = :bill.Id].Shipping_Country__c
            );
        }

    }

    @IsTest
    public static void testPreventDeleteBillingCashReceipts() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Applied_Amount__c = 10;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            insert bcr;

            DMLException dmlEx;

            try {
                delete testData.billings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sdv = new BillingFieldUpdateValidator();
            System.assertEquals(SourceDocumentUpdateFieldValidator.DELETE_APPLIED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testBillingUnpostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            testData.billings[0].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.billings[0];

            DMLException dmlEx;
            try {
                delete testData.billings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testBillingPostedDeleteError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true);

        System.runAs(testData.users.get(1)) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            DMLException dmlEx;
            try {
                delete testData.billings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sdv = new BillingFieldUpdateValidator();
            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    public static  void testPreventInsertMaxLineCountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Billing_Line__c> lineList = new List<Billing_Line__c>();
            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT; i++) {
                lineList.add(testData.billingLines[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                BillingLineActions.isBypassGLAccountValidations = true;
                insert lineList;
                BillingLineActions.isBypassGLAccountValidations = false;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SObjectActions.MAX_LINE_ERROR, new List<String> {String.valueOf(SObjectActions.MAX_LINE_COUNT)}),
                dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testPreventInsertMaxLineCountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Billing_Line__c> lineList = new List<Billing_Line__c>();
            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT - 100; i++) {
                lineList.add(testData.billingLines[0].clone(false, true));
            }

            DMLException dmlEx;
            try {
                BillingLineActions.isBypassGLAccountValidations = true;
                insert lineList;
                BillingLineActions.isBypassGLAccountValidations = false;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
        }

    }

    @IsTest
    public static void testSetDefaultFieldsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String defaultValue = 'In Process';
            for (Schema.PicklistEntry pickListEntry : Billing__c.Status__c.getDescribe().getPicklistValues()) {
                if (pickListEntry.isDefaultValue() && pickListEntry.getValue() != 'Posted') {
                    defaultValue = pickListEntry.getValue();
                }
            }

            Billing__c bill = testData.billings[0].clone(false, true);

            bill.Status__c = 'Posted';
            bill.Closed_Accounting_Period__c = testData.acctPeriods[0].Id;
            bill.Credit_Memo_Applied_Amount__c = 2;
            insert bill;

            System.assertEquals(defaultValue, [SELECT Id, Status__c FROM Billing__c WHERE Id = :bill.Id].Status__c);
            System.assertEquals(NULL, [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :bill.Id].Closed_Accounting_Period__c);
            System.assertEquals(0, [SELECT Id, Credit_Memo_Applied_Amount__c FROM Billing__c WHERE Id = :bill.Id].Credit_Memo_Applied_Amount__c);
            System.assertEquals(testData.ledgerSettings.Ledger_Id__c, [SELECT Id, Ledger__c FROM Billing__c WHERE Id = :bill.Id].Ledger__c);

            bill = testData.billings[0].clone(false, true);

            bill.Status__c = NULL;
            bill.Closed_Accounting_Period__c = testData.acctPeriods[0].Id;
            bill.Credit_Memo_Applied_Amount__c = 2;
            insert bill;

            System.assertEquals(defaultValue, [SELECT Id, Status__c FROM Billing__c WHERE Id = :bill.Id].Status__c);
            System.assertEquals(NULL, [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :bill.Id].Closed_Accounting_Period__c);
            System.assertEquals(0, [SELECT Id, Credit_Memo_Applied_Amount__c FROM Billing__c WHERE Id = :bill.Id].Credit_Memo_Applied_Amount__c);
            System.assertEquals(testData.ledgerSettings.Ledger_Id__c, [SELECT Id, Ledger__c FROM Billing__c WHERE Id = :bill.Id].Ledger__c);

            bill = testData.billings[0].clone(false, true);

            bill.Status__c = defaultValue;
            bill.Closed_Accounting_Period__c = testData.acctPeriods[0].Id;
            bill.Credit_Memo_Applied_Amount__c = 2;
            insert bill;

            System.assertEquals(defaultValue, [SELECT Id, Status__c FROM Billing__c WHERE Id = :bill.Id].Status__c);
            System.assertEquals(NULL, [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :bill.Id].Closed_Accounting_Period__c);
            System.assertEquals(0, [SELECT Id, Credit_Memo_Applied_Amount__c FROM Billing__c WHERE Id = :bill.Id].Credit_Memo_Applied_Amount__c);
            System.assertEquals(testData.ledgerSettings.Ledger_Id__c, [SELECT Id, Ledger__c FROM Billing__c WHERE Id = :bill.Id].Ledger__c);

            bill = testData.billings[0].clone(false, true);

            bill.Status__c = 'Arbitrary';
            bill.Closed_Accounting_Period__c = testData.acctPeriods[0].Id;
            bill.Credit_Memo_Applied_Amount__c = 2;
            insert bill;

            System.assertEquals('Arbitrary', [SELECT Id, Status__c FROM Billing__c WHERE Id = :bill.Id].Status__c);
            System.assertEquals(NULL, [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id = :bill.Id].Closed_Accounting_Period__c);
            System.assertEquals(0, [SELECT Id, Credit_Memo_Applied_Amount__c FROM Billing__c WHERE Id = :bill.Id].Credit_Memo_Applied_Amount__c);
            System.assertEquals(testData.ledgerSettings.Ledger_Id__c, [SELECT Id, Ledger__c FROM Billing__c WHERE Id = :bill.Id].Ledger__c);
        }

    }

    @IsTest
    public static void testSetPreventUpdateStatusFieldPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            DMLException dmlEx = NULL;
            try {
                testData.billings[0].Status__c = 'Posted';
                update testData.billings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    @IsTest
    public static void testResolveAccountingPeriodBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> billings = new List<Billing__c>();
            billings.add(
                new Billing__c(
                    Billing_Cycle_Start_Date__c = System.today() - 3,
                    Billing_Cycle_End_Date__c = System.today(),
                    Date__c = Date.newinstance(1992, 1, 2),
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'In Process',
                    Billing_Format__c = testData.billingFormats[0].Id
                )
            );

            insert billings;

            List<Billing_Line__c> billingLines = new List<Billing_Line__c>();
            billingLines.add(
                new Billing_Line__c(
                    Billing__c = billings[0].Id,
                    Date__c = System.today(),
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[2].Id
                )
            );

            System.assertEquals(testData.acctPeriods[3].Id, [SELECT Accounting_Period__c FROM Billing__c WHERE Id = :billings[0].Id].Accounting_Period__c);
        }
    }

    @IsTest
    public static void testPreventUpdateLedgerAppliedBCRError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing_Cash_Receipt__c testBillingCashReceipt = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Applied_Amount__c = 200
            );

            insert testBillingCashReceipt;

            testData.billings[0].Ledger__c = testData.ledgers[2].Id;
            DmlException dmlEx;
            try {
                update testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sdv = new BillingFieldUpdateValidator();
            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_APPLIED_ERROR, new List<String>{sdv.formatFieldStrings(sdv.lockedUpdateFieldsApplied)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventUpdatePeriodAppliedBCRError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing_Cash_Receipt__c testBillingCashReceipt = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Applied_Amount__c = 200
            );

            insert testBillingCashReceipt;

            testData.billings[0].Accounting_Period__c = testData.acctPeriods[3].Id;
            DmlException dmlEx;
            try {
                update testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sdv = new BillingFieldUpdateValidator();
            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_APPLIED_ERROR, new List<String>{sdv.formatFieldStrings(sdv.lockedUpdateFieldsApplied)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testAccountPDFFormatTakesOverBillingPDFFormat() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //create Account record with populated PDF Format lookup field
            Account testAccount = new Account(
                Name = 'TestAccount',
                Billing_Format__c = testData.billingFormats[0].Id
            );

            insert testAccount;

            Billing__c testBilling = new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testAccount.Id,
                Status__c = 'In Process',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = NULL,
                Due_Date2__c = System.today() + 30
            );
            insert testBilling;

            testBilling = [SELECT Id, Billing_Format__c FROM Billing__c WHERE Id = :testBilling.Id LIMIT 1];

            System.assertEquals(testData.billingFormats[0].Id, testBilling.Billing_Format__c);
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeIfNullInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createBillings();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Billing__c testBilling = testData.billings[0].clone(false,true);
                testBilling.put('CurrencyIsoCode', NULL);

                insert testBilling;

                Id billId = testBilling.Id;
                testBilling = (Billing__c) Database.query('SELECT Id, CurrencyIsoCode FROM Billing__c WHERE Id = :billId');
                System.assertNotEquals(NULL, testBilling.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeIfNullUpdate_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createBillings();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Billing__c testBilling = testData.billings[0].clone(false,true);
                testBilling.put('CurrencyIsoCode', NULL);

                insert testBilling;

                testBilling.put('CurrencyIsoCode', NULL);
                update testBilling;
  
                Id billId = testBilling.Id;
                testBilling = (Billing__c) Database.query('SELECT Id, CurrencyIsoCode FROM Billing__c WHERE Id = :billId');
                System.assertNotEquals(NULL, testBilling.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testPreventUpdateCurrency_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createBillings();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Billing__c testBilling = testData.billings[0];
                testBilling.put('CurrencyIsoCode', newCurrencyIsoCode);

                DmlException dmlEx;
                try {
                    update testBilling;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }
                SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
                System.assertEquals(String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}), dmlEx.getDmlMessage(0));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testCreatePaymentLinkPositive() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AccountingSettingsHandler.acctSeedSettings = NULL;
            PaymentLink.paymentLinkEnabled = NULL;
            testData.settings.Payment_Link_Username__c = 'testUser';
            update testData.settings;

            Billing__c testBilling = new Billing__c(
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'In Process'
            );

            insert testBilling;

            testBilling = [SELECT Id, Payment_Link__c FROM Billing__c WHERE Id = :testBilling.Id LIMIT 1];

            System.assert(testBilling.Payment_Link__c == NULL);

            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreatePaymentLinkNegative() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AccountingSettingsHandler.acctSeedSettings = NULL;
            testData.settings.Payment_Link_Username__c = NULL;
            update testData.settings;

            Billing__c testBilling = new Billing__c(
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'In Process'
                );

            insert testBilling;
            update testBilling;

            testBilling = [SELECT Id, Payment_Link__c FROM Billing__c WHERE Id = :testBilling.Id LIMIT 1];

            System.assert(testBilling.Payment_Link__c == NULL);
        }

    }

    @IsTest
    public static void testPreventPaymentLinkNonUSD_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createBillings();

            System.runAs(testData.users[1]) {
                Billing__c testBilling = testData.billings[0].clone(false);
                testBilling.put('CurrencyIsoCode', 'EUR');
                insert testBilling;

                DmlException dmlEx;
                try {
                    update testBilling;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(NULL, [SELECT Id, Payment_Link__c FROM Billing__c WHERE Id = :testBilling.Id].Payment_Link__c);
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testUpdateLedgerField() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Billing__c bill = testData.billings[0].clone(false, true);
            bill.Date__c = Date.newInstance(1970, 3, 13);
            insert bill;

            System.assertEquals(testData.ledgers[0].Id, [SELECT Id, Ledger__c FROM Billing__c WHERE Id = :bill.Id].Ledger__c);

            DMLException dmlEx;
            Ledger_Custom_Settings__c ledgerSettings;
            try {
                ledgerSettings = new Ledger_Custom_Settings__c(Ledger_Id__c = testData.ledgers[0].Id);
                insert ledgerSettings;
                bill.Ledger__c = NULL;
                update bill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                Ledger_Custom_Settings__c.getOrgDefaults().Ledger_Id__c, [
                    SELECT Id, Ledger__c FROM Billing__c WHERE Id = :bill.Id
                ].Ledger__c
            );
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Billing__c bill = testData.billings[0].clone(false, true);
            bill.Currency_Conversion_Rate__c = 1.235343967;
            bill.Discount_Percent__c = 10.3499;

            insert bill;

            Billing__c newBilling = [
                SELECT  Id,
                        Currency_Conversion_Rate__c,
                        Discount_Percent__c
                FROM Billing__c
                WHERE Id = : bill.Id
            ];

            System.assertEquals(1.235344, newBilling.Currency_Conversion_Rate__c);
            System.assertEquals(10.35, newBilling.Discount_Percent__c);
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            Billing__c bill = testData.billings[0];
            bill.Currency_Conversion_Rate__c = 1.235343967;
            bill.Discount_Percent__c = 10.3499;

            update bill;

            Billing__c newBilling = [
                SELECT  Id,
                        Currency_Conversion_Rate__c,
                        Discount_Percent__c
                FROM Billing__c
                WHERE Id = :bill.Id
            ];

            System.assertEquals(1.235344, newBilling.Currency_Conversion_Rate__c);
            System.assertEquals(10.35, newBilling.Discount_Percent__c);
        }
    }

    @IsTest
    public static void testBillingNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;

            Billing__c bl = new Billing__c();

            try {
                insert bl;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testCalculateSalesTaxValueNativeFS() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost();
        Test.startTest();
        testData.createBillings()
            .createProducts();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = testData.billings[0];

            delete [SELECT Id FROM Billing_Line__c WHERE Billing__c = :testBilling.Id];
			Test.stopTest();
            Product2 taxRateProduct = testData.products[4];
            Product2 taxableProduct = testData.products[3];
            Account_Tax__c tax = new Account_Tax__c(
                Account__c = testBilling.Customer__c,
                Tax_Rate__c = taxRateProduct.Id,
                Tax_Type__c = 'Sales'
            );
            insert tax;

            Billing_Line__c taxableLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testBilling.Date__c,
                Hours_Units__c = 25,
                Rate__c = 10,
                Product__c = taxableProduct.Id
            );

            Billing_Line__c salesTaxLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testBilling.Date__c,
                Hours_Units__c = 1,
                Rate__c = 10,
                Product__c = taxRateProduct.Id
            );

            insert new List<Billing_Line__c>{taxableLine, salesTaxLine};
			
            System.assertEquals(10, [SELECT Id, Sales_Tax2__c FROM Billing__c WHERE Id = :testBilling.Id].Sales_Tax2__c.setScale(2, System.RoundingMode.HALF_UP));
            System.assertEquals(true, [SELECT Tax_Line__c FROM Billing_Line__c WHERE Id = :salesTaxLine.Id].Tax_Line__c);
        }
    }

    @IsTest
    public static void testCalculateSalesTaxValueAvalara() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createBillings()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Billing__c testBilling =[SELECT Id, Ledger__c, Date__c FROM Billing__c WHERE Id = :testData.billings[0].Id];
            delete [SELECT Id FROM Billing_Line__c WHERE Billing__c = :testBilling.Id];
            Product2 taxableProduct = testData.products[3];

            Billing_Line__c taxableLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testBilling.Date__c,
                Hours_Units__c = 25,
                Rate__c = 10,
                Product__c = taxableProduct.Id
            );

            Billing_Line__c salesTaxLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testBilling.Date__c,
                Hours_Units__c = 1,
                Rate__c = 10,
                Product__c = ((AbstractTaxService) new AvaTaxLineLevel()).getSalesTaxProduct(testBilling)
            );

            insert new List<Billing_Line__c>{taxableLine, salesTaxLine};

            System.assertEquals(10, [SELECT Id, Sales_Tax2__c FROM Billing__c WHERE Id = :testBilling.Id].Sales_Tax2__c.setScale(2, System.RoundingMode.HALF_UP));
            System.assertEquals(true, [SELECT Tax_Line__c FROM Billing_Line__c WHERE Id = :salesTaxLine.Id].Tax_Line__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCalculateSalesTaxValueAvalara_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .setLineLevelPost()
                .createProducts()
                .enableAvaTaxCalculation();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                AvaTax_License__c newLicense = new AvaTax_License__c();
                newLicense.Active_AvaTax_Endpoint__c = 'testEndpoint';
                newLicense.AvaTax_Account_ID__c = 'testId';
                newLicense.AvaTax_License_Key__c = 'testKey';
                insert newLicense;

                Tax_Settings__c actualSetting = new Tax_Settings__c();
                actualSetting.Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
                actualSetting.Origin_Address__c = testData.addressObjects[0].Id;
                actualSetting.Sales_Tax_GL_Account__c = testData.glAccounts[15].Id;
                actualSetting.AvaTax_License__c = newLicense.Id;
                actualSetting.Sales_Tax_Product__c = testData.products[5].Id;
                insert actualSetting;

                Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
                selectedLedger.Tax_Settings__c = actualSetting.Id;
                selectedLedger.Sales_Tax_Company_Code__c = 'testCode';
                update selectedLedger;

                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Product2 taxableProduct = testData.products[3];

                Billing__c testBilling = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = System.today(),
                    Currency_Conversion_Rate__c = 1.0,
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

                testBilling.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testBilling;

                Billing_Line__c taxableLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testBilling.Date__c,
                    Hours_Units__c = 25,
                    Rate__c = 10,
                    Product__c = taxableProduct.Id
                );
                taxableLine.put('CurrencyIsoCode', newCurrencyIsoCode);

                Billing_Line__c salesTaxLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testBilling.Date__c,
                    Hours_Units__c = 1,
                    Rate__c = 10,
                    Product__c = actualSetting.Sales_Tax_Product__c
                );
                salesTaxLine.put('CurrencyIsoCode', newCurrencyIsoCode);

                insert new List<Billing_Line__c>{taxableLine, salesTaxLine};
                
                System.assertEquals(10, [SELECT Id, Sales_Tax2__c FROM Billing__c WHERE Id = :testBilling.Id].Sales_Tax2__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals(true, [SELECT Tax_Line__c FROM Billing_Line__c WHERE Id = :salesTaxLine.Id].Tax_Line__c);
                Test.stopTest();
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCalculateSalesTaxValueNativeFS_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProducts();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Billing__c testBilling = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = System.today(),
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

                testBilling.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testBilling;

                Product2 taxRateProduct = testData.products[4];
                Product2 taxableProduct = testData.products[3];
                Account_Tax__c tax = new Account_Tax__c(
                    Account__c = testBilling.Customer__c,
                    Tax_Rate__c = taxRateProduct.Id,
                    Tax_Type__c = 'Sales'
                );
                insert tax;

                Billing_Line__c taxableLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testBilling.Date__c,
                    Hours_Units__c = 25,
                    Rate__c = 10,
                    Product__c = taxableProduct.Id
                );
                taxableLine.put('CurrencyIsoCode', newCurrencyIsoCode);

                Billing_Line__c salesTaxLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testBilling.Date__c,
                    Hours_Units__c = 1,
                    Rate__c = 10,
                    Product__c = taxRateProduct.Id,
                    Tax_Line__c = true
                );
                salesTaxLine.put('CurrencyIsoCode', newCurrencyIsoCode);

                insert new List<Billing_Line__c>{taxableLine, salesTaxLine};
                System.assertEquals(10, [SELECT Id, Sales_Tax2__c FROM Billing__c WHERE Id = :testBilling.Id].Sales_Tax2__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals(true, [SELECT Tax_Line__c FROM Billing_Line__c WHERE Id = :salesTaxLine.Id].Tax_Line__c);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
        }
    }

    @IsTest
    public static void testPreventUpdateLedgerIfAvalaraIsEnabled() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProducts()
                .enableAvaTaxCalculation();

            System.runAs(testData.users.get(1)) {
                
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Ledger__c foreignCurrencyLedger = new Ledger__c(
                    Name = 'foreignCurrencyLedger',
                    Type__c = 'Transactional',
                    Default_Bank_Account__c = testData.glAccounts[0].Id,
                    Default_Billing_Format__c = testData.billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
                    Tax_Settings__c = [SELECT Id FROM Tax_Settings__c WHERE Tax_Settings_Method__c = 'AvaTax' LIMIT 1].Id,
                    Sales_Tax_Company_Code__c = '100101'
                );
                foreignCurrencyLedger.put('CurrencyIsoCode', newCurrencyIsoCode);

                insert foreignCurrencyLedger;
                Product2 taxableProduct = testData.products[3];

                Billing__c testBilling = new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c+3,
                    Date__c = System.today(),
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

                testBilling.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testBilling;

                DmlException dmlException;
                try {
                    testBilling.Ledger__c = foreignCurrencyLedger.Id;
                    update testBilling;
                }
                catch (DmlException ex) {
                    dmlException = ex;
                }
                System.assertEquals(Label.LEDGER_UPDATE_IF_AVALARA_IS_ENABLED_ERROR, dmlException.getDmlMessage(0));

                dmlException = NULL;
                try {
                    testBilling.Ledger__c = NULL;
                    update testBilling;
                } catch (DmlException ex) {
                    dmlException = ex;
                }

                System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlException.getDmlMessage(0));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
        }  
    }

    @IsTest
    public static void testPaidDateUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true)
            .createCashReceipts();


        System.runAs(testData.users.get(1)) {
            //if it is NOT paid then this field should be blank.
            Billing__c billing = [Select Id, Paid_Date__c,Balance__c from Billing__c where Id = :testData.billings[0].Id];
            System.assertEquals(null,billing.Paid_Date__c);
            System.assertEquals(450,billing.Balance__c);

            Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 200,
                Applied_Date__c = testData.acctPeriods[1].Start_Date__c + 10
            );

            insert testBCR;

            //if it is partially paid, then this field should be blank.
            billing = [Select Id, Paid_Date__c,Balance__c from Billing__c where Id = :testData.billings[0].Id];
            System.assertEquals(null,billing.Paid_Date__c);
            System.assertEquals(250,billing.Balance__c);

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -250;
            bcm.Applied_Date__c = testData.acctPeriods[0].Start_Date__c + 5;
            insert bcm;

            //And if it is paid in full by a cash/credit application (Billing Balance = 0), then automatically populate the 
            //Paid Date field with the applied date value  later of all BCR and BCM applications
            billing = [Select Id, Paid_Date__c,Balance__c from Billing__c where Id = :testData.billings[0].Id];
            System.assertEquals(testData.acctPeriods[1].Start_Date__c + 10,billing.Paid_Date__c);
            System.assertEquals(0,billing.Balance__c);

            delete bcm;

            //And if a cash/credit application is unapplied (if a CR/CM was unapplied from the Billing after its Balance had reached 0.00), 
            //then clear this value.
            billing = [Select Id, Paid_Date__c,Balance__c from Billing__c where Id = :testData.billings[0].Id];
            System.assertEquals(null,billing.Paid_Date__c);
            System.assertEquals(250,billing.Balance__c);

            Test.stopTest();
        }
    }
    
    @isTest
    public static void testSetDefaultPaymentProcessor() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            testData.settings.Stripe_Connected_Account_Id__c = testData.paymentProcessors[0].Id;
            update testData.settings;

            Billing__c clonedBilling = testData.billings[0].clone();
            insert clonedBilling;
            System.assert([SELECT Id, Payment_Processor__c FROM Billing__c WHERE Id =: clonedBilling.Id].Payment_Processor__c == testData.paymentProcessors[0].Id);

            Billing__c clonedBilling2 = testData.billings[0].clone();
            clonedBilling2.Payment_Processor__c = testData.paymentProcessors[1].Id;
            insert clonedBilling2;
            System.assert([SELECT Id, Payment_Processor__c FROM Billing__c WHERE Id =: clonedBilling2.Id].Payment_Processor__c == testData.paymentProcessors[1].Id);
        }
    }

    @IsTest
    public static void testPaymentLinkCardknox() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
			testData.billings[0].Payment_Processor__c = testData.paymentProcessors[2].Id;
            update  testData.billings[0];

            Billing__c testBilling = [SELECT Id, Name, Payment_Site_URL__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            System.assert(testBilling.Payment_Site_URL__c != NULL);
            System.assert(testBilling.Payment_Site_URL__c.contains(testData.paymentProcessors[2].PaymentSite_URL__c + '?xInvoice=' + EncodingUtil.urlEncode(testBilling.Name, 'UTF-8')));

            Test.stopTest();
        }
    }
    @IsTest
    public static void testNoPaymentSiteUrlOnBilling() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            Test.startTest();
			testData.billings[0].Payment_Processor__c = testData.paymentProcessors[2].Id;
            update  testData.billings[0];

            Billing__c testBilling = [SELECT Id, Name, Payment_Site_URL__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            Assert.areNotEqual(null,testBilling.Payment_Site_URL__c);
            Assert.isTrue(testBilling.Payment_Site_URL__c.contains(testData.paymentProcessors[2].PaymentSite_URL__c + '?xInvoice=' + EncodingUtil.urlEncode(testBilling.Name, 'UTF-8')));

            testData.billings[0].Payment_Processor__c = null;
            update  testData.billings[0];

            Billing__c testBilling2 = [SELECT Id, Name, Payment_Site_URL__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            Assert.areEqual(null,testBilling2.Payment_Site_URL__c);

            Test.stopTest();
        }
    }

    @IsTest
    public static void testNoPaymentSiteUrlBalanceUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPaymentProcessors()    
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Payment_Processor__c processor = testData.paymentProcessors[2];
            processor.Enable_PaymentSITE_Partial_Payment__c = false;
            update processor;

            Billing__c billing = testData.billings[0];
            billing.Payment_Processor__c = processor.Id;
            update billing;

            Billing__c result = [SELECT Payment_Site_URL__c, Balance__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            Assert.isNotNull(result.Payment_Site_URL__c);
            Assert.isTrue(result.Payment_Site_URL__c.contains('&xAmount=' + result.Balance__c));

            // Balance__c = Total__c - Received_Amount__c - Cash_Application_Adjustment_Amount__c - Credit_Memo_Applied_Amount__c

            // test changing Total__c
            Billing_Line__c line = new Billing_Line__c(
                Billing__c = billing.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            insert line;

            result = [SELECT Payment_Site_URL__c, Balance__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            Assert.isNotNull(result.Payment_Site_URL__c);
            Assert.isTrue(result.Payment_Site_URL__c.contains('&xAmount=' + result.Balance__c));

            // test changing Received_Amount__c and Cash_Application_Adjustment_Amount__c
            Cash_Receipt__c cashReceipt = testData.cashReceipts[0];
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = billing.Id,
                Cash_Receipt__c = cashReceipt.Id,
                Applied_Amount__c = 10,
                Adjustment_Amount__c = 10,
                Adjustment_GL_Account__c = testData.glAccounts[21].Id
            );
            insert bcr;

            result = [SELECT Payment_Site_URL__c, Balance__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            Assert.isNotNull(result.Payment_Site_URL__c);
            Assert.isTrue(result.Payment_Site_URL__c.contains('&xAmount=' + result.Balance__c));   
            
            // test changing Credit_Memo_Applied_Amount__c to reduce balance
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c(
                Billing_Invoice__c = billing.Id,
                Billing_Credit_Memo__c = testData.billings[2].Id,
                Amount__c = 10,
                Accounting_Period__c = testData.acctPeriods[0].Id
            );
            insert bcm;

            result = [SELECT Payment_Site_URL__c, Balance__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            Assert.isNotNull(result.Payment_Site_URL__c);
            Assert.isTrue(result.Payment_Site_URL__c.contains('&xAmount=' + result.Balance__c)); 

            // test changing Credit_Memo_Applied_Amount__c to increase balance
            delete bcm;

            result = [SELECT Payment_Site_URL__c, Balance__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            Assert.isNotNull(result.Payment_Site_URL__c);
            Assert.isTrue(result.Payment_Site_URL__c.contains('&xAmount=' + result.Balance__c)); 

            Test.stopTest();
        }
    }
    @isTest
    public static void testSetDefaultPaymentProcessorOfAccountandLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            testData.settings.Stripe_Connected_Account_Id__c = testData.paymentProcessors[0].Id;
            update testData.settings;

            Account acc = testData.accounts[0];
            acc.Default_Payment_Processor__c = testData.paymentProcessors[1].Id;
            UPDATE acc;

            Ledger__c ledger = testData.ledgers[0];
            ledger.Default_Payment_Processor__c = testData.paymentProcessors[2].Id;
            UPDATE ledger;

            Billing__c clonedBilling = testData.billings[0].clone();
            clonedBilling.Customer__c = acc.Id;
            insert clonedBilling;
            System.assert([SELECT Id, Payment_Processor__c FROM Billing__c WHERE Id =: clonedBilling.Id].Payment_Processor__c == acc.Default_Payment_Processor__c);

            Billing__c clonedBilling2 = testData.billings[0].clone();
            clonedBilling2.Customer__c = testData.accounts[1].Id;
            clonedBilling2.Ledger__c = ledger.Id;

            insert clonedBilling2;
            System.assert([SELECT Id, Payment_Processor__c FROM Billing__c WHERE Id =: clonedBilling2.Id].Payment_Processor__c == ledger.Default_Payment_Processor__c);
        }
    }
}