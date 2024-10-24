@IsTest
public class APCreditMemoActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testUpdateAccountPayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id;
            acm.Amount__c = -2;
            insert acm;

            // Validate updated on insert
            System.assertEquals(
                2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[0].Id
                ].Credit_Memo_Applied_Amount__c
            );

            System.assertEquals(
                -2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[4].Id
                ].Credit_Memo_Applied_Amount__c
            );

            acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id;
            acm.Amount__c = -1;
            insert acm;

            System.assertEquals(
                3, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[0].Id
                ].Credit_Memo_Applied_Amount__c
            );

            System.assertEquals(
                -3, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[4].Id
                ].Credit_Memo_Applied_Amount__c
            );

            delete acm;

            // Validate updated on delete
            System.assertEquals(
                2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[0].Id
                ].Credit_Memo_Applied_Amount__c
            );

            System.assertEquals(
                -2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Account_Payable__c
                    WHERE Id = :testData.payables[4].Id
                ].Credit_Memo_Applied_Amount__c
            );
        }
    }

    @IsTest
    public static void testAppliedDatePopulated() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id; // Name = '1991-11',
            acm.Amount__c = -2;
            insert acm;

            AP_Credit_Memo__c apCreditMemo = [SELECT ID, Applied_Date__c FROM AP_Credit_Memo__c WHERE Id =: acm.Id];

            // Validate applied date populated
            System.assertEquals(Datetime.newInstance(1991,11,01).date() , apCreditMemo.Applied_Date__c);
        }
    }


    @IsTest
    public static void testPreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id;
            acm.Amount__c = -2;
            insert acm;

            DmlException dmlEx;
            try {
                acm.Amount__c = 3;
                update acm;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new APCreditMemoFieldUpdateValidator();
            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateWrappedFields)}),
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @IsTest
    public static void testAPCreditMemoNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            AP_Credit_Memo__c apc = new AP_Credit_Memo__c();
            DmlException dmlEx;
            try {
                insert apc;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users[1]) {
            Test.startTest();
            AP_Credit_Memo__c acm = new AP_Credit_Memo__c();
            acm.Account_Payable_Invoice__c = testData.payables[0].Id;
            acm.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            acm.Accounting_Period__c = testData.acctPeriods[1].Id;
            acm.Amount__c = -20.989342348934;
            insert acm;

            AP_Credit_Memo__c newAcm = [
                SELECT  Id,
                        Amount__c
                FROM AP_Credit_Memo__c
                WHERE Id = :acm.Id
            ];

            System.assertEquals(-20.99, newAcm.Amount__c);
        }

    }

    @IsTest
    public static void testPreventOverAppliedPayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Account_Payable_Invoice__c = testData.payables[0].Id,
                Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                Amount__c = -60
            );

            DmlException dmlEx;
            try {
                insert testApCreditMemo;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(
                SObjectActions.OVER_APPLIED_ERROR,
                new List<String> {Account_Payable__c.getSObjectType().getDescribe().getLabel()}
            ), dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testLDOIsInProgress() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(false);

        System.runAs(testData.users.get(1)) {
            testData.payables[0].Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS;

            TriggerObserver.getInstance().unlockField(Account_Payable__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(testData.payables[0], new List<String>{
                'Status__c'
            });
            TriggerObserver.purgeUnlockedFields(Account_Payable__c.Status__c);

            AP_Credit_Memo__c testApCreditMemo = new AP_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Account_Payable_Invoice__c = testData.payables[0].Id,
                Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                Amount__c = -2
            );

            DmlException dmlEx;
            try {
                insert testApCreditMemo;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(Label.ERR_CM_APPLY_IF_PAYABLE_IN_PROGRESS, dmlEx.getDmlMessage(0));
        }
    }

}