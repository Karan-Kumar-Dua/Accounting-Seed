@IsTest
private class AccountPayableLineFieldUpdateValidTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventInsertActionApplied() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableLineFieldUpdateValidator();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            Account_Payable_Line__c newPayLine = testData.payableLines[0].clone();
            newPayLine.Account_Payable__c = testData.payables[0].Id;

            DMLException dmlEx;

            try {
                insert newPayLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.INSERT_APPLIED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidatePreventInsertActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableLineFieldUpdateValidator();
            Account_Payable_Line__c newPayLine = testData.payableLines[0].clone();
            newPayLine.Account_Payable__c = testData.payables[0].Id;

            DMLException dmlEx;

            try {
                insert newPayLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_INSERT_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableLineFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.payableLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidatePreventDeleteActionApplied() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableLineFieldUpdateValidator();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            DMLException dmlEx;

            try {
                delete testData.payableLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.DELETE_APPLIED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedFieldApplied() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableLineFieldUpdateValidator();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            DMLException dmlEx;

            try {
                testData.payableLines[0].Amount__c = 40;
                update testData.payableLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_APPLIED_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsApplied), testData.payableLines[0].Parent_Status__c}),
                dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        Test.startTest();
        testData.createTaxGroups();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableLineFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.payableLines[0].Tax_Group__c = testData.taxGroups[1].Id;
                update testData.payableLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableLineFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;

            DMLException dmlEx;

            try {
                delete testData.payableLines[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }
}