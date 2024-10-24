@IsTest
private class APDisbursementFieldUpdateValidatorTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidatePreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new APDisbursementFieldUpdateValidator();
            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Cash_Disbursement__c = testData.cashDisbursements[0].Id;
            apd.Paid_Amount__c = 5;
            insert apd;

            DmlException dmlEx;
            try {
                apd.Paid_Amount__c = 200;
                update apd;
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

    @IsTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches();

        Test.startTest();
        testData.createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new APDisbursementFieldUpdateValidator();
            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apd.Paid_Amount__c = 5;
            insert apd;

            DmlException dmlEx;

            try {
                apd.Applied_Date__c = Date.today().addDays(3);
                update apd;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateWrappedFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDmlMessage(0));
        }
    }
}