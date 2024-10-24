@IsTest
private class BillingLineFieldUpdateValidatorTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidatePreventInsertActionApplied() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            Billing_Line__c newBillingLine = testData.billingLines[0].clone();
            newBillingLine.Billing__c = testData.billings[0].Id;

            DmlException dmlEx;
            try {
                insert newBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SourceDocumentUpdateFieldValidator.INSERT_APPLIED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testValidatePreventInsertActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            Billing_Line__c newBillingLine = testData.billingLines[0].clone();
            newBillingLine.Billing__c = testData.billings[0].Id;

            DmlException dmlEx;
            try {
                insert newBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_INSERT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();

            DmlException dmlEx;
            try {
                delete testData.billingLines[0];
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
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            DmlException dmlEx;
            try {
                delete testData.billingLines[0];
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
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            DmlException dmlEx;
            try {
                testData.billingLines[0].Hours_Units__c = 40;
                update testData.billingLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_APPLIED_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsApplied)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();

            DmlException dmlEx;
            try {
                testData.billingLines[0].Rate__c = 33;
                update testData.billingLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateLockedCustomField() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Billing__c.Locked_In_AvaTax__c});
            testData.billings[0].Locked_In_AvaTax__c = true;
            update testData.billings[0];
            TriggerObserver.reset();

            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();

            DmlException dmlEx;
            try {
                testData.billingLines[0].Rate__c = 33;
                update testData.billingLines[0];
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
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();

            AccountingPeriodActions.isDelarcInProgress = true;
            DmlException dmlEx;
            try {
                delete testData.billingLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }
}