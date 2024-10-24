@IsTest
public class BillingCashReceiptActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBillingCashReceiptNoControlAccount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                )
            );

            DMLException dmlEx;

            try {
                insert billingCashReceipts;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BillingCashReceiptPostHandler.NO_CONTROL_ACCOUNT_MESSAGE, ApexPages.getMessages()[0].getDetail());
            System.assertEquals(
                String.format(BillingCashReceiptActions.AUTO_POST_FAILED_ERROR, new List<String>{BillingCashReceiptPostHandler.NO_CONTROL_ACCOUNT_MESSAGE}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testBillingCashReceiptPreventUpdateAction() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_Amount__c = 2,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id
                )
            );

            insert billingCashReceipts;
            billingCashReceipts[0].Applied_Amount__c = 13;
            billingCashReceipts[0].Adjustment_Amount__c = 1;
            billingCashReceipts[0].Accounting_Period__c = testData.acctPeriods[1].Id;
            billingCashReceipts[0].Adjustment_GL_Account__c = testData.glAccounts[3].Id;

            DMLException dmlEx;
            try {
                BillingCashReceiptActions.isFirstRun = true;
                update billingCashReceipts;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }      

    @IsTest
    public static void testBillingCashReceiptUpdateAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_Amount__c = 2,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id
                )
            );
            insert billingCashReceipts;

            List<Billing_Cash_Receipt__c> bcrsBeforeUpdate = [SELECT Id, Applied_Date__c FROM Billing_Cash_Receipt__c WHERE Id = :billingCashReceipts[0].Id];
            System.assertEquals(testData.acctPeriods[1].Start_Date__c, bcrsBeforeUpdate[0].Applied_Date__c);
                       
            billingCashReceipts[0].Applied_Date__c = testData.acctPeriods[1].End_Date__c.addDays(40);
            
            DMLException dmlEx;
            try {
                update billingCashReceipts;                
            }
            catch (DMLException ex) {
                dmlEx = ex;                
            }            
            SourceDocumentUpdateFieldValidator sfu = new BillingCashReceiptFieldUpdateValidator();
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR,
                    new List<String>{
                        sfu.formatFieldStrings(sfu.lockedUpdateWrappedFieldsPosted),
                        AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED
                    }
                ),
                dmlEx.getDmlMessage(0)); 
        }

    }

    @IsTest
    public static void testSetAppliedDateOutsideAcctPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();
        Date today = Date.today();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_Amount__c = 2,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id,
                    Applied_Date__c = today
                )
            );
            
            DMLException dmlEx;
            try {
                insert billingCashReceipts;
            }
            catch (DMLException ex) {
                dmlEx = ex;                
            }            
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(String.format(BillingCashReceiptActions.AUTO_POST_FAILED_ERROR, new List<String>{BillingCashReceiptActions.APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR}), dmlEx.getDmlMessage(0));            
        }

    }   

    @IsTest
    public static void testBillingCashReceiptRequireAdjustmentGLAccountAndAmount() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_Amount__c = 2
                )
            );

            DMLException dmlEx;

            try {
                insert billingCashReceipts;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(BillingCashReceiptActions.ADJUSTMENT_ERROR, ApexPages.getMessages()[0].getDetail());
            System.assertEquals(BillingCashReceiptActions.ADJUSTMENT_ERROR, dmlEx.getDmlMessage(0));

            billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12,
                    Adjustment_GL_Account__c = testData.glAccounts[16].Id
                )
            );

            try {
                insert billingCashReceipts;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(BillingCashReceiptActions.ADJUSTMENT_ERROR, ApexPages.getMessages()[0].getDetail());
            System.assertEquals(BillingCashReceiptActions.ADJUSTMENT_ERROR, dmlEx.getDmlMessage(0));
        }
    }
    
    @IsTest    
    public static void testBillingCashReceiptPostedInsertClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {

            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update new List<Accounting_Period__c>{testData.acctPeriods[0], testData.acctPeriods[1]};
            Test.stopTest();

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[1].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[1].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;

            DMLException dmlEx;
            try {
                insert bcr;
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_FILTER_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }
    
    @IsTest    
    public static void testBillingCashReceiptPostedInsertArchivedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            AccountingPeriodService.setStatus(
                new List<Accounting_Period__c>{
                    testData.acctPeriods[0]
                },
                'Archived',
                EncodingUtil.base64Encode(
                    Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
                )
            );
            update testData.acctPeriods[0];

            System.assertEquals(
                'Archived',
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods[0].Id].Status__c
            );
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[0].Id;

            DMLException dmlEx;
            try {
                insert bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_FILTER_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }
    }

    @IsTest    
    public static void testBillingCashReceiptPostedDeleteClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true).createCashReceipts();

        System.runAs(testData.users[1]) {

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[2].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[0].Id;
            insert bcr;

            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();

            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods[0].Id].Status__c
            );

            DMLException dmlEx;
            try {
                delete bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BillingCashReceiptActions.ACCOUNTING_PERIOD_CLOSED_ERROR, dmlEx.getDMLMessage(0));
        }
    }

    @IsTest    
    public static void testBillingCashReceiptPostedDeleteArchivedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings(true).createCashReceipts();

        System.runAs(testData.users[1]) {

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[2].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[0].Id;
            insert bcr;

            AccountingPeriodService.setStatus(
                new List<Accounting_Period__c>{
                    testData.acctPeriods[0]
                },
                'Archived',
                EncodingUtil.base64Encode(
                    Crypto.generateDigest('SHA-512', Blob.valueOf(GlobalVariables.UNIVERSAL_AUTH_KEY))
                )
            );
            update testData.acctPeriods[0];

            System.assertEquals(
                'Archived',
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods[0].Id].Status__c
            );

            Test.stopTest();

            DMLException dmlEx;
            try {
                delete bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(BillingCashReceiptActions.ACCOUNTING_PERIOD_CLOSED_ERROR, dmlEx.getDMLMessage(0));
        }
    }

    @IsTest    
    public static void testBillingCashReceiptPostedDeleteOpenAccountingPeriodSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[2].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[0].Id;
            insert bcr;

            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :bcr.Id]);

            DMLException dmlEx;
            try {
                delete bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(true, [SELECT Id FROM Billing_Cash_Receipt__c WHERE Id = :bcr.Id].isEmpty());
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :bcr.Id]);
            System.assertEquals(NULL, dmlEx);

            try {
                undelete bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(System.StatusCode.UNDELETE_FAILED, dmlEx.getDmlType(0));
        }
    }
    
    @IsTest    
    public static void testBillingCashReceiptInsertOpenAccountingPeriodSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testData.acctPeriods[4].Id].Status__c
            );

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            insert bcr;

            System.assertEquals(2, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :bcr.Id]);
        }
    }

    @IsTest
    public static void testBillingCashReceiptNoBillingId() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = NULL,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Applied_Amount__c = 12
                )
            );

            DMLException dmlEx;

            try {
                insert billingCashReceipts;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            String billingFieldApiName = Billing_Cash_Receipt__c.Billing__c.getDescribe().Name;
            System.assertEquals('Required fields are missing: [' + billingFieldApiName + ']', dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testBillingCashReceiptNoCRId() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {

            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = NULL,
                    Billing__c = testData.billings[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Applied_Amount__c = 12
                )
            );

            DMLException dmlEx;

            try {
                insert billingCashReceipts;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            String cashReceiptFieldApiName = Billing_Cash_Receipt__c.Cash_Receipt__c.getDescribe().Name;
            System.assertEquals('Required fields are missing: [' + cashReceiptFieldApiName + ']', dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testBillingCashReceiptNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
                insert bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testBillingCashReceiptNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();
            Test.startTest();
            testData.createBillings(true).createCashReceipts();

            System.runAs(testData.users[1]) {
                DMLException dmlEx;

                Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();

                try {
                    insert bcr;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            Billing_Cash_Receipt__c billingCashReceipts = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[2].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Adjustment_GL_Account__c = testData.glAccounts[0].Id,
                Applied_Amount__c = 20.989342348934,
                Adjustment_Amount__c = 10.236746723674344
            );

            insert billingCashReceipts;

            Billing_Cash_Receipt__c newBillingCashReceipts = [
                SELECT  Id,
                        Applied_Amount__c,
                        Adjustment_Amount__c
                FROM Billing_Cash_Receipt__c
                WHERE Id = : billingCashReceipts.Id];

            System.assertEquals(20.99, newBillingCashReceipts.Applied_Amount__c);
            System.assertEquals(10.24, newBillingCashReceipts.Adjustment_Amount__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPreventCreateSameCurrency_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org
            Test.startTest();
            testData.createBillings(true).createCashReceipts();

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Billing__c testBilling = testData.billings.get(0);
                Cash_Receipt__c testCR = testData.cashReceipts.get(0);

                //create new BCR record
                Billing_Cash_Receipt__c testBCR = new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testCR.Id,
                    Billing__c = testBilling.Id,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Applied_Amount__c = 12
                );
                testCR.put('CurrencyIsoCode', theNewCurrencyIsoCode);

                DmlException dmlEx;
                try {
                    insert testBCR;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                //BCR currency will be populated in before insert trigger so no errors expected
                System.assertEquals(NULL, dmlEx);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testTriggerObserverLockedFieldUpdateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Applied_Amount__c = 12
                )
            );
            insert billingCashReceipts;
            
            TriggerObserver.SObjectFieldUpdateObserverException fieldUpdateEx;

            try {
                TriggerObserver.getInstance().watch(billingCashReceipts);
                TriggerObserver.getInstance().unlockField(Billing_Cash_Receipt__c.Status__c);
                billingCashReceipts[0].Status__c = 'Approved';
                TriggerObserver.reset();
                TriggerObserver.getInstance().validateObservedContent(billingCashReceipts);
            } catch (TriggerObserver.SObjectFieldUpdateObserverException ex) {
                fieldUpdateEx = ex;
            }

            System.assertEquals(null, fieldUpdateEx);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testTriggerObserverLockedFieldUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Applied_Amount__c = 12
                )
            );
            insert billingCashReceipts;
            
            TriggerObserver.SObjectFieldUpdateObserverException fieldUpdateEx;

            try {
                TriggerObserver.getInstance().watch(billingCashReceipts);
                billingCashReceipts[0].Status__c = 'Approved';
                TriggerObserver.getInstance().validateObservedContent(billingCashReceipts);
            } catch (TriggerObserver.SObjectFieldUpdateObserverException ex) {
                fieldUpdateEx = ex;
            }

            System.assertNotEquals(null, fieldUpdateEx);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPostOnInsertSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Applied_Amount__c = 12
                )
            );

            DmlException dmlEx;
            try {
                insert billingCashReceipts;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Status__c FROM Billing_Cash_Receipt__c WHERE Id = :billingCashReceipts[0].Id].Status__c
            );

        }
    }

    @IsTest
    public static void testSetAccountingPeriodFromAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Applied_Amount__c = 12,
                    Applied_Date__c = testData.acctPeriods[2].Start_Date__c.addDays(3)
                )
            );

            DmlException dmlEx;
            try {
                insert billingCashReceipts;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            List<Billing_Cash_Receipt__c> bcrs =
                [SELECT Applied_Date__c, Accounting_Period__c FROM Billing_Cash_Receipt__c WHERE Id = :billingCashReceipts[0].Id];
            System.assertEquals(testData.acctPeriods[2].Id, bcrs[0].Accounting_Period__c);

        }
    }

    @IsTest
    public static void testSetAccountingPeriodFromCreatedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Applied_Amount__c = 12
                )
            );

            DmlException dmlEx;
            try {
                insert billingCashReceipts;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            List<Billing_Cash_Receipt__c> bcrs =
                [SELECT Applied_Date__c, Accounting_Period__c FROM Billing_Cash_Receipt__c WHERE Id = :billingCashReceipts[0].Id];
            System.assertEquals(testData.acctPeriods[testData.acctPeriods.size()/2].Id, bcrs[0].Accounting_Period__c);

        }
    }

    @IsTest
    public static void testUpdateLegacyBCRAndSetPostingStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users.get(1)) {
            testData.disableAutoPostSourceDocuments();

            Billing_Cash_Receipt__c testBillingCR = new Billing_Cash_Receipt__c(
                Cash_Receipt__c = testData.cashReceipts[0].Id,
                Billing__c = testData.billings[0].Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Applied_Amount__c = 12
            );
            insert testBillingCR;

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Billing_Cash_Receipt__c WHERE Id = :testBillingCR.Id
                ].Status__c
            );

            Transaction__c trans = new Transaction__c(
                Billing_Cash_Receipt__c = testBillingCR.Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Date__c = testData.acctPeriods[1].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                GL_Account__c = testData.glAccounts[0].Id,
                Amount__c = testBillingCR.Applied_Amount__c
            );
            TransactionActions.createTransactions(new List<Transaction__c>{trans});

            
            testBillingCR.Status__c = NULL;
            update testBillingCR;
            //check Posting Status -> must be "Posted"
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Billing_Cash_Receipt__c WHERE Id = :testBillingCR.Id
                ].Status__c
            );
            //make sure existed Transaction is still in place -> means only the Posting Status of the record has been changed
            List<Transaction__c> transactions = DomainUtils.getTransactionsByBcr(new List<Billing_Cash_Receipt__c>{testBillingCR});
            System.assertNotEquals(true, transactions.isEmpty());
            System.assertEquals(trans.Id, transactions[0].Id);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testRefundBCRInsertSuccessNoPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {
            List<Billing_Cash_Receipt__c> billingCashReceipts = new List<Billing_Cash_Receipt__c>();
            billingCashReceipts.add(
                new Billing_Cash_Receipt__c(
                    Cash_Receipt__c = testData.cashReceipts[0].Id,
                    Billing__c = testData.billings[0].Id,
                    Applied_Amount__c = 12, 
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND
                )
            );

            DmlException dmlEx;
            try {
                insert billingCashReceipts;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);
            List<Id> BCRIds = new List<Id>();
            for(Billing_Cash_Receipt__c BCR : billingCashReceipts){
                BCRIds.add(BCR.Id);
            }

            System.assertEquals(0, [SELECT Id FROM Transaction__c WHERE Billing_Cash_Receipt__r.Id IN :BCRIds].size());
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND,
                [SELECT Status__c FROM Billing_Cash_Receipt__c WHERE Id = :billingCashReceipts[0].Id].Status__c
            );

        }
    }

    @IsTest    
    public static void testRefundBCRDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);
        Test.startTest();
        testData.createCashReceipts();

        System.runAs(testData.users[1]) {

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[2].Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcr.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_BCR_REFUND;
            insert bcr;

            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :bcr.Id]);

            DMLException dmlEx;
            try {
                delete bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(true, [SELECT Id FROM Billing_Cash_Receipt__c WHERE Id = :bcr.Id].isEmpty());
            System.assertEquals(0, [SELECT count() FROM Transaction__c WHERE Billing_Cash_Receipt__c = :bcr.Id]);
            System.assertEquals(NULL, dmlEx);

            try {
                undelete bcr;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(System.StatusCode.UNDELETE_FAILED, dmlEx.getDmlType(0));
        }
    }
    @IsTest
    public static void testDMLErrorWhenForwardAccountingPeriodBCR() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts();
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            Date today = System.today();

            Tax_Settings__c taxSetting = new Tax_Settings__c();
            taxSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
            taxSetting.Sales_Tax_GL_Account__c = testData.glAccounts[28].Id;
            taxSetting.Sales_Tax_Product__c = testData.products[5].Id;
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Shipment';
            taxSetting.Tax_Rounding_Threshold__c = '0.02';
            insert taxSetting;
            Ledger__c ledger = new Ledger__c(
                Name = 'Actual 3',
                Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_CASH,
                Type__c = 'Transactional',
                Default_Bank_Account__c = testData.glAccounts[0].Id,
                Default_Billing_Format__c = testData.billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            );

            INSERT ledger;

            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(1);
            testAccountingPeriod1.Start_Date__c = Date.newInstance(today.year(),today.addMonths(-1).month(),1);
            testAccountingPeriod1.End_Date__c = Date.newInstance(today.year(),today.addMonths(-1).month(),28);

            UPDATE testAccountingPeriod1;

            Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(0);
            testAccountingPeriod2.Start_Date__c = Date.newInstance(today.year(),today.month(),1);
            testAccountingPeriod2.End_Date__c = Date.newInstance(today.year(),today.month(),28);

            UPDATE testAccountingPeriod2;

            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 400,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c =testAccountingPeriod2.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Ledger__c = ledger.Id
            );
            insert testCR;

            Billing__c bill = new Billing__c();
            bill.Proprietary_Billing_Number__c = 'i';
            bill.Customer__c = testData.accounts[0].Id;
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Ledger__c =ledger.Id;

            INSERT bill;

            Billing_Line__c objBillingLine = new Billing_Line__c();
            objBillingLine.Billing__c = bill.Id;
            objBillingLine.Rate__c = 500;
            objBillingLine.Hours_Units__c = 1;

            insert objBillingLine;
           
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = bill.Id;
            bcr.Cash_Receipt__c = testCR.Id;
            bcr.Applied_Amount__c = 100;
            bcr.Accounting_Period__c = testAccountingPeriod2.Id;
           
            INSERT bcr;

            Billing_Cash_Receipt__c bcr1 = new Billing_Cash_Receipt__c();
            bcr1.Billing__c = bill.Id;
            bcr1.Cash_Receipt__c = testCR.Id;
            bcr1.Applied_Amount__c = 100;
            bcr1.Accounting_Period__c = testAccountingPeriod1.Id;
            
            Exception exp;
            try {
                insert bcr1;
            }
            catch (Exception ex) {
                exp = ex;      
            }  

            Assert.areNotEqual(NULL, exp);
            Assert.areEqual(true, exp.getMessage().contains(BillingCashReceiptActions.BCR_IN_FUTURE_ERROR));
            test.stopTest();                     
        }
    }
    @IsTest
    public static void testDMLErrorWhenForwardAccountingPeriodBCM() {
        TestDataSuite testData = TestDataSuite.getInstance().createProducts().createBillings(true);
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            Date today = System.today();

            Tax_Settings__c taxSetting = new Tax_Settings__c();
            taxSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
            taxSetting.Sales_Tax_GL_Account__c = testData.glAccounts[28].Id;
            taxSetting.Sales_Tax_Product__c = testData.products[5].Id;
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Shipment';
            taxSetting.Tax_Rounding_Threshold__c = '0.02';
            insert taxSetting;

            Ledger__c ledger = new Ledger__c(
                Name = 'Actual 3',
                Accounting_Method__c = LedgerActions.ACCOUNTING_METHOD_CASH,
                Type__c = 'Transactional',
                Default_Bank_Account__c = testData.glAccounts[0].Id,
                Default_Billing_Format__c = testData.billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
                Tax_Settings__c = taxSetting.Id
            );

            INSERT ledger;

            Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(1);
            testAccountingPeriod1.Start_Date__c = Date.newInstance(today.year(),today.addMonths(-1).month(),1);
            testAccountingPeriod1.End_Date__c = Date.newInstance(today.year(),today.addMonths(-1).month(),28);

            UPDATE testAccountingPeriod1;

            Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(0);
            testAccountingPeriod2.Start_Date__c = Date.newInstance(today.year(),today.month(),1);
            testAccountingPeriod2.End_Date__c = Date.newInstance(today.year(),today.month(),28);

            UPDATE testAccountingPeriod2;

            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = 400,
                Payment_Reference__c = '0000000432',
                Status__c = 'Approved',
                Receipt_Date__c = testData.acctPeriods.get(0).Start_Date__c,
                Accounting_Period__c =testAccountingPeriod2.Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Ledger__c = ledger.Id
            );
            insert testCR;

            Billing__c bill = new Billing__c();
            bill.Proprietary_Billing_Number__c = 'i';
            bill.Customer__c = testData.accounts[0].Id;
            bill.Accounting_Period__c = testAccountingPeriod2.Id;
            bill.Ledger__c =ledger.Id;

            INSERT bill;

            Billing_Line__c objBillingLine = new Billing_Line__c();
            objBillingLine.Billing__c = bill.Id;
            objBillingLine.Rate__c = 500;
            objBillingLine.Hours_Units__c = 1;

            insert objBillingLine;

            Billing__c bill1 = new Billing__c();
            bill1.Proprietary_Billing_Number__c = 'i';
            bill1.Customer__c = testData.accounts[0].Id;
            bill1.Accounting_Period__c = testAccountingPeriod2.Id;
            bill1.Ledger__c =ledger.Id;

            INSERT bill1;

            Billing_Line__c objBillingLine1 = new Billing_Line__c();
            objBillingLine1.Billing__c = bill1.Id;
            objBillingLine1.Rate__c = 500;
            objBillingLine1.Hours_Units__c = -1;

            insert objBillingLine1;

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = bill.Id;
            bcm.Billing_Credit_Memo__c = bill1.Id;
            bcm.Accounting_Period__c =testAccountingPeriod2.Id;
            bcm.Amount__c = -250;
            bcm.Applied_Date__c = testAccountingPeriod2.Start_Date__c + 5;
            insert bcm;


            Billing_Cash_Receipt__c bcr1 = new Billing_Cash_Receipt__c();
            bcr1.Billing__c = bill.Id;
            bcr1.Cash_Receipt__c = testCR.Id;
            bcr1.Applied_Amount__c = 100;
            bcr1.Accounting_Period__c = testAccountingPeriod1.Id;
            
            Exception exp;
            try {
                insert bcr1;
            }
            catch (Exception ex) {
                exp = ex;      
            }  

            Assert.areNotEqual(NULL, exp);
            Assert.areEqual(true, exp.getMessage().contains(BillingCashReceiptActions.BCR_IN_FUTURE_ERROR));
            test.stopTest();                     
        }
    }
}