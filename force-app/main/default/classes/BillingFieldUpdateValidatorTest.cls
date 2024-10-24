@IsTest
private class BillingFieldUpdateValidatorTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();

            DmlException dmlEx;
            try {
                delete testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testValidatePreventDeleteActionApplied() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            DmlException dmlEx;
            try {
                delete testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SourceDocumentUpdateFieldValidator.DELETE_APPLIED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testValidateLockedFieldApplied() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            DmlException dmlEx;
            try {
                testData.billings[0].Accounting_Period__c = NULL;
                update testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_APPLIED_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsApplied)}),
                dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();

            DmlException dmlEx;
            try {
                testData.billings[0].Accounting_Period__c = NULL;
                update testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateLockedFieldStatusField() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            Billing__c bill = [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];

            DmlException dmlEx;
            try {
                bill.Status__c = 'Posted';
                update bill;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateLockedField() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createBillings();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
                Billing__c bill = [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
                DmlException dmlEx;
                try {
                    bill.put('CurrencyIsoCode', newCurrencyIsoCode);
                    update bill;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                    dmlEx.getDmlMessage(0)
                );
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    private static void testValidateLockedCustomField() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            Billing__c bill = [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Billing__c.Locked_In_AvaTax__c});
            bill.Locked_In_AvaTax__c = true;
            update bill;
            TriggerObserver.reset();

            DmlException dmlEx;
            try {
                bill.Accounting_Period__c = testData.acctPeriods[1].Id;
                update bill;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(Label.ERR_UPDATE_AVATAX_LOCKED, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsCustomSet)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

     @IsTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(false);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;

            DmlException dmlEx;
            try {
                delete testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }
    }

    @IsTest
    private static void testValidatePreventUpdateDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;

            DmlException dmlEx;
            try {
                update testData.billings[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assert(dmlEx == null);
        }

    }
}