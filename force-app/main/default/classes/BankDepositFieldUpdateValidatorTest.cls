@IsTest
private class BankDepositFieldUpdateValidatorTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidateLockedField() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankTransactions();

        System.runAs(testData.users.get(1)) {
            //Create Bank Deposit linked with BT
            Bank_Deposit__c testBD = new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[1].Start_Date__c,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'BD REF',
                Bank_Transaction__c = testData.bankTransactions[0].Id
            );

            SObjectActions.isPreventNonCloneableFieldsCleaning = true;
            insert testBD;
            SObjectActions.isPreventNonCloneableFieldsCleaning = false;

            DmlException dmlEx;
            try {
                testBD.Bank_Transaction__c = testData.bankTransactions[1].Id;
                update testBD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);

            SourceDocumentUpdateFieldValidator sfu = new BankDepositFieldUpdateValidator();

            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testValidateLockedFieldDependingOfFeatureManagement() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            SourceDocumentUpdateFieldValidator sfu = new BankDepositFieldUpdateValidator();

            Bank_Deposit__c bd = [SELECT Id, Bank_Transaction__c FROM Bank_Deposit__c WHERE Id = :testData.bankDeposits[0].Id LIMIT 1];

            DMLException dmlEx;
            try {
                bd.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update bd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                dmlEx.getDmlMessage(0)
            );

            //Enable Force Match Feature to allow update of the Bank Transaction field on BD record
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Financial_Suite_Key__c = GlobalVariables.FORCE_MATCH_PERMISSION_KEY;
            update settings;

            dmlEx = NULL;
            try {
                bd.Bank_Transaction__c = testData.bankTransactions[0].Id;
                update bd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            //No DML error expected since we bypass Bank Transaction field's validation via FORCE_MATCH_PERMISSION_KEY
            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                testData.bankTransactions[0].Id,
                [SELECT Bank_Transaction__c FROM Bank_Deposit__c WHERE Id = :testData.bankDeposits[0].Id].Bank_Transaction__c
            );
        }
    }

}