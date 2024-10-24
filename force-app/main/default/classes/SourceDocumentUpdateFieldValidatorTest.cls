@IsTest
private class SourceDocumentUpdateFieldValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventInsertActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            Billing_Line__c newBillingLine = testData.billingLines[0].clone();
            newBillingLine.Billing__c = testData.billings[0].Id;

            DMLException dmlEx;

            try {
                insert newBillingLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_INSERT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
            testData.createBillings(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.billingLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidatePreventInsertActionApplied() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            Billing_Line__c newBillingLine = testData.billingLines[0].clone();
            newBillingLine.Billing__c = testData.billings[0].Id;

            DMLException dmlEx;

            try {
                insert newBillingLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.INSERT_APPLIED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidatePreventDeleteActionApplied() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            DMLException dmlEx;

            try {
                delete testData.billingLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.DELETE_APPLIED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedFieldApplied() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            DMLException dmlEx;

            try {
                testData.billings[0].Accounting_Period__c = NULL;
                update testData.billings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_APPLIED_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsApplied)}),
                dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.billings[0].Accounting_Period__c = NULL;
                update testData.billings[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidateLockedFieldStatusField() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();

            DMLException dmlEx;

            Billing__c bill = [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];

            try {
                bill.Status__c = 'Posted';
                update bill;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testSetValidationRules() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            sfu.sObjectType = Billing__c.getSObjectType();
            sfu.setValidationRules();

            System.assert(sfu.lockedUpdateFieldsPostedWrapper != NULL);
            System.assert(sfu.lockedUpdateFieldsAppliedWrapper != NULL);
            System.assert(sfu.lockedUpdateStatusFieldWrapper != NULL);
            System.assert(sfu.lockedDeletePosted);
            System.assert(sfu.lockedDeleteApplied);
        }
    }

    @isTest
    private static void testSetJunctionSObjectIds() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Map<Id, SObject> newObjectMap = new Map<Id, SObject>(testData.billings);

            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();
            sfu.setJunctionSObjectIds(NULL, newObjectMap);

            System.assertEquals(new Map<Id, SObject>(testData.billings).keySet(), sfu.junctionSObjectIds);

        }

    }

    @isTest
    private static void testSetJunctionSObjectIdsOverride() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true);

        System.runAs(testData.users.get(1)) {
            Map<Id, SObject> newObjectMap = new Map<Id, SObject>(testData.billingLines);

            SourceDocumentUpdateFieldValidator sfu = new BillingLineFieldUpdateValidator();
            sfu.setJunctionSObjectIds(NULL, newObjectMap);

            System.assertEquals(new Map<Id, SObject>(testData.billings).keySet(), sfu.junctionSObjectIds);

        }

    }

    @isTest
    private static void testGetLockedFields() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Map<Id, SObject> newObjectMap = new Map<Id, SObject>(testData.billingLines);
            TriggerObserver.getInstance().unlockFields(new Set<SObjectField>{Billing__c.Status__c, Billing__c.Locked_In_AvaTax__c});
            SourceDocumentUpdateFieldValidator sfu = new BillingFieldUpdateValidator();

            sfu.lockedUpdateFieldsPosted = new Set<SObjectField> {
                Billing__c.Status__c,
                Billing__c.Customer__c
            };

            sfu.lockedUpdateFieldsApplied = new Set<SObjectField> {
                Billing__c.Accounting_Period__c,
                Billing__c.Customer__c
            };

            sfu.lockedUpdateFieldsCustomSet = new Set<SObjectField> {
                Billing__c.Customer__c, Billing__c.Accounting_Period__c
            };

            sfu.getLockedFields();

            Set<SObjectField> result = new Set<SObjectField> {Billing__c.Customer__c, Billing__c.Accounting_Period__c};

            System.assertEquals(result, sfu.nonUpdateableFields);

        }

    }
}