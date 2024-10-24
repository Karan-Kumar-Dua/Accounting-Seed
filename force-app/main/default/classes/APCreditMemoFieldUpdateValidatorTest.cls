@IsTest
private class APCreditMemoFieldUpdateValidatorTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testValidatePreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            DMLException dmlEx;
            try {
                acm.Amount__c = 200;
                update acm;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            SourceDocumentUpdateFieldValidator sfu = new APCreditMemoFieldUpdateValidator();
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateWrappedFields)}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testBypassPreventUpdateActionForLegacyRecordWithEmptyAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Accounting_Period__c = testData.acctPeriods[2].Id;
            acm.Amount__c = -10;
            insert acm;

            DMLException dmlEx;
            try {
                //Clear Applied Date field to simulate legacy (pre-kermit) record
                acm.Applied_Date__c = NULL;
                //Prevent auto-population of Applied Date by the trigger
                Accounting_Period__c period = AccountingPeriodHandler.getInstance().getAccountingPeriodById(acm.Accounting_Period__c);
                period.Start_Date__c = NULL;//This will be carried over to Applied Date on APCM record
                //Unlock the field to bypass update validation
                TriggerObserver.getInstance().unlockField(AP_Credit_Memo__c.Applied_Date__c);
                update acm;
                TriggerObserver.purgeUnlockedFields(AP_Credit_Memo__c.Applied_Date__c);
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            System.assertEquals(NULL, [SELECT Applied_Date__c FROM AP_Credit_Memo__c WHERE Id = :acm.Id].Applied_Date__c);

            try {
                //Reset AccountingPeriodHandler instance to re-query all Accounting Periods
                AccountingPeriodHandler.reset();
                //Auto populate the Applied Date field. No validation error is expected because previous value is NULL.
                update acm;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            //Check Applied Date field is set to Accounting Period's Start Date value
            System.assertEquals(
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(acm.Accounting_Period__c).Start_Date__c,
                [SELECT Applied_Date__c FROM AP_Credit_Memo__c WHERE Id = :acm.Id].Applied_Date__c
            );
        }
    }

}