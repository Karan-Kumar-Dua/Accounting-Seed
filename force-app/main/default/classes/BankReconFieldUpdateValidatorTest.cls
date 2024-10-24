@IsTest
private class BankReconFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventDeleteActionAlternatePosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BankReconciliationFieldUpdateValidator();
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];

            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            update brec;
            BankReconciliation.setStatus(brec.Id, BankReconciliation.Status.COMPLETED);
            Test.getEventBus().deliver();

            DMLException dmlEx;
            try {
                delete testData.bankReconciliations[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.ALTERNATE_POSTED_DELETE_ERROR,
                    new List<String>{BankReconciliation.WORKING}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testValidateLockedFieldAlternatePosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BankReconciliationFieldUpdateValidator();
            Bank_Reconciliation2__c brec = [
                SELECT
                    Id,
                    Uncleared_Amount__c
                FROM
                    Bank_Reconciliation2__c
                WHERE
                    Id = :testData.bankReconciliations[0].Id
                LIMIT 1
            ];

            if (brec.Uncleared_Amount__c > 0) {
                brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
            } else if (brec.Uncleared_Amount__c < 0) {
                brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
            }
            update brec;
            BankReconciliation.setStatus(brec.Id, BankReconciliation.Status.COMPLETED);
            Test.getEventBus().deliver();

            DMLException dmlEx;
            try {
                testData.bankReconciliations[0].GL_Ending_Balance__c = 100010.00;
                update testData.bankReconciliations[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.ALTERNATE_POSTED_UPDATE_ERROR,
                    new List<String>{
                        sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted),
                        BankReconciliation.WORKING
                    }
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testValidatePreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            SourceDocumentUpdateFieldValidator sfu = new BankReconciliationFieldUpdateValidator();
            DMLException dmlEx;

            try {
                testData.bankReconciliations[0].End_Date__c = Date.Today();
                update testData.bankReconciliations[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}), 
                                dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testValidatePreventDeleteDelArcRoutine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            SourceDocumentUpdateFieldValidator sfu = new BankReconciliationFieldUpdateValidator();
            AccountingPeriodActions.isDelarcInProgress = true;
            DMLException dmlEx;

            try {
                delete testData.bankReconciliations[0];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(dmlEx == null);
        }
    }
}