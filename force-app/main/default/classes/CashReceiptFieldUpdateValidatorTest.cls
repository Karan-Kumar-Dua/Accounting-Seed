@IsTest
private class CashReceiptFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidateLockedFieldPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();

            DMLException dmlEx;

            try {
                testData.cashReceipts[0].Receipt_Date__c = System.today();
                update testData.cashReceipts[0];
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
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();

            DMLException dmlEx;

            try {
                delete testData.cashReceipts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @isTest
    private static void testValidateLockedFieldStatusField() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ]);
            CashReceiptPost pbt = new CashReceiptPost(cont);
            pbt.unpost();
            System.assertEquals(
                'Approved',
                [SELECT Accounting_Period__r.Status__c, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Status__c
            );

            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();

            DMLException dmlEx;

            Cash_Receipt__c cr = [SELECT Id, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];

            try {
                cr.Status__c = 'Posted';
                update cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidateLockedField() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts().createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Cash_Receipt__c
                WHERE Id = :testData.cashReceipts[0].Id
            ]);
            CashReceiptPost pbt = new CashReceiptPost(cont);
            pbt.unpost();
            System.assertEquals(
                'Approved',
                [SELECT Accounting_Period__r.Status__c, Status__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Status__c
            );
            
            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();

            DMLException dmlEx;

            Cash_Receipt__c cr = [SELECT Id, Bank_Reconciliation__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];

            try {
                cr.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
                update cr;
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
            .createCashReceipts()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();

            Cash_Receipt__c cr = [SELECT Id, Bank_Transaction__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1];

            DMLException dmlEx;
            try {
                cr.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                dmlEx.getDmlMessage(0)
            );

            //Enable Force Match Feature to allow update of the Bank Transaction field on CR record
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Financial_Suite_Key__c = GlobalVariables.FORCE_MATCH_PERMISSION_KEY;
            update settings;

            dmlEx = NULL;
            try {
                cr.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update cr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            //No DML error expected since we bypass Bank Transaction field's validation via FORCE_MATCH_PERMISSION_KEY
            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                testData.bankTransactions[0].Id,
                [SELECT Bank_Transaction__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id].Bank_Transaction__c
            );
        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().disableAutoPostSourceDocuments().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                delete testData.cashReceipts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }

    @isTest
    private static void testValidatePreventUpdateDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                update testData.cashReceipts[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(dmlEx == null);
        }

    }

}