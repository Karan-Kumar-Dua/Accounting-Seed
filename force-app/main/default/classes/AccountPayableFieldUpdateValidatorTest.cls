@IsTest
private class AccountPayableFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.payables[0];
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
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            DMLException dmlEx;

            try {
                delete testData.payables[0];
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
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            DMLException dmlEx;

            try {
                testData.payables[0].Accounting_Period__c = NULL;
                update testData.payables[0];
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
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.payables[0].Accounting_Period__c = NULL;
                update testData.payables[0];
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
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();

            DMLException dmlEx;

            Account_Payable__c pay = [SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id LIMIT 1];

            try {
                pay.Status__c = 'Posted';
                update pay;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidateLockedField() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPayables();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();

                DMLException dmlEx;

                Account_Payable__c pay = [SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id LIMIT 1];

                try {
                    pay.put('CurrencyIsoCode', newCurrencyIsoCode);
                    update pay;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(
                    String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                    dmlEx.getDmlMessage(0));
            }
        }
        catch (Exception ex) {

        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();

            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                delete testData.payables[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }

    @isTest
    private static void testValidatePreventUpdateDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();

            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                update testData.payables[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }
}