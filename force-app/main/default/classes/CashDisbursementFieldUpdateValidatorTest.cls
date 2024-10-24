@IsTest
private class CashDisbursementFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.cashDisbursements[0].Disbursement_Date__c = System.today();
                update testData.cashDisbursements[0];
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
    private static void testPreventUpdateCheckNumberPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();

            DMLException dmlEx;
            try {
                testData.cashDisbursements[0].Check_Number__c = 1;
                update testData.cashDisbursements[0];
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
    private static void testPreventUpdateDescriptionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();

            DMLException dmlEx;
            try {
                testData.cashDisbursements[0].Description__c = 'some description';
                update testData.cashDisbursements[0];
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
    private static void testValidatePreventDeleteActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.cashDisbursements[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedFieldStatusField() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();

            DMLException dmlEx;

            Cash_Disbursement__c cd = [SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            try {
                cd.Status__c = 'Posted';
                update cd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidateLockedField() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();

            DMLException dmlEx;

            Cash_Disbursement__c cd = [SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            try {
                cd.Void_Date__c = System.today();
                update cd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testValidateLockedFieldDependingOfFeatureManagement() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();

            Cash_Disbursement__c cd = [SELECT Id, Bank_Transaction__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            DMLException dmlEx;
            try {
                cd.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update cd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                dmlEx.getDmlMessage(0)
            );

            //Enable Force Match Feature to allow update of the Bank Transaction field on CD record
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Financial_Suite_Key__c = GlobalVariables.FORCE_MATCH_PERMISSION_KEY;
            update settings;

            dmlEx = NULL;
            try {
                cd.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update cd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            //No DML error expected since we bypass Bank Transaction field's validation via FORCE_MATCH_PERMISSION_KEY
            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                testData.bankTransactions[0].Id,
                [SELECT Bank_Transaction__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id].Bank_Transaction__c
            );
        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements(false);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                delete testData.cashDisbursements[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }
    }

    @isTest
    private static void testValidatePreventUpdateDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                update testData.cashDisbursements[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }
    }

}