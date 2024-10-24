@IsTest
public class BillingCreditMemoActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testUpdateBillings() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -2;
            insert bcm;

            // Validate updated on insert
            System.assertEquals(
                2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Credit_Memo_Applied_Amount__c
            );

            System.assertEquals(
                -2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[2].Id
                ].Credit_Memo_Applied_Amount__c
            );

            bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -1;
            insert bcm;

            System.assertEquals(
                3, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Credit_Memo_Applied_Amount__c
            );

            System.assertEquals(
                -3, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[2].Id
                ].Credit_Memo_Applied_Amount__c
            );

            delete bcm;

            // Validate updated on delete
            System.assertEquals(
                2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Credit_Memo_Applied_Amount__c
            );

            System.assertEquals(
                -2, [
                    SELECT Id, Credit_Memo_Applied_Amount__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[2].Id
                ].Credit_Memo_Applied_Amount__c
            );
        }

    }

    @isTest
    public static void testPreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -2;
            insert bcm;

            DMLException dmlEx;
            try {
                bcm.Amount__c = -3;
                update bcm;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new BillingCreditMemoFieldUpdateValidator();
            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateWrappedFields)}),
                dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testBillingCreditMemoNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
                insert bcm;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testBillingCreditMemoNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users[1]) {
                Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
                DMLException dmlEx;
                try {
                    insert bcm;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }

    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[2].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -20.989342348934;
            insert bcm;

            Billing_Credit_Memo__c newBcm = [
                SELECT  Id,
                        Amount__c
                FROM Billing_Credit_Memo__c
                WHERE Id = : bcm.Id];

            System.assertEquals(-20.99, newBcm.Amount__c);
        }

    }

    @IsTest
    public static void testPreventOverAppliedBilling() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Billing_Credit_Memo__c testBillingCreditMemo = new Billing_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Invoice__c = testData.billings[0].Id,
                Billing_Credit_Memo__c = testData.billings[3].Id,
                Amount__c = -300
            );

            DmlException dmlEx;
            try {
                insert testBillingCreditMemo;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(String.format(
                SObjectActions.OVER_APPLIED_ERROR,
                new List<String> {Billing__c.getSObjectType().getDescribe().getLabel()}
            ), dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testSetAppliedDateIfBlank() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            Billing_Credit_Memo__c testBillingCreditMemo = new Billing_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Billing_Invoice__c = testData.billings[1].Id,
                Billing_Credit_Memo__c = testData.billings[2].Id,
                Amount__c = -5
            );

            insert testBillingCreditMemo;

            Billing_Credit_Memo__c bcm = [SELECT Applied_Date__c FROM Billing_Credit_Memo__c WHERE Id = :testBillingCreditMemo.Id];
            System.assertEquals(bcm.Applied_Date__c, testData.acctPeriods[1].Start_Date__c);
        }
    }

    @IsTest
    public static void testUpdateAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        
        System.runAs(testData.users.get(1)) {
            Billing_Credit_Memo__c testBillingCreditMemo = new Billing_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Billing_Invoice__c = testData.billings[1].Id,
                Billing_Credit_Memo__c = testData.billings[2].Id,
                Amount__c = -5
            );
            insert testBillingCreditMemo;
            testBillingCreditMemo.Applied_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(2);

            DmlException dmlEx;
            try {
                update testBillingCreditMemo;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            SourceDocumentUpdateFieldValidator sfu = new BillingCreditMemoFieldUpdateValidator();
            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateWrappedFields)}),
                dmlEx.getDmlMessage(0));            
        }
    }

    @IsTest
    public static void testLDOIsInProgress() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            testData.billings[1].Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS;

            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            SFDCSecurityUtils.updateCheckCRUDAndFLS(testData.billings[1], new List<String>{
                'Status__c'
            });
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            Billing_Credit_Memo__c testBillingCreditMemo = new Billing_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Billing_Invoice__c = testData.billings[1].Id,
                Billing_Credit_Memo__c = testData.billings[2].Id,
                Amount__c = -5
            );

            DmlException dmlEx;
            try {
                insert testBillingCreditMemo;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(Label.ERR_CM_APPLY_IF_BILLING_IN_PROGRESS, dmlEx.getDmlMessage(0));
        }
    }

}