@isTest
private class AccountPayableActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPreventOverAppliedPayablesByAPD() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = new Account_Payable__c(
                Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfhhfsoinuy',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );
            insert testPayable;

            Account_Payable_Line__c testPL = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 5,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert testPL;

            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> results = postHandler.post(new List<Account_Payable__c>{testPayable});
            System.assertEquals(true, results.get(0).isSuccess);

            AP_Disbursement__c testAPD = new AP_Disbursement__c(
                Account_Payable__c = testPayable.Id,
                Cash_Disbursement__c = testData.cashDisbursements[7].Id,
                Paid_Amount__c = 8
            );

            DmlException dmlEx;
            try {
                insert testAPD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(
                String.format(
                    SObjectActions.OVER_APPLIED_ERROR,
                    new List<String> {Account_Payable__c.getSObjectType().getDescribe().getLabel()}
                ), dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPreventOverAppliedPayablesByPCM() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements(true);

        System.runAs(testData.users.get(1)) {
            AP_Credit_Memo__c creditMemo = new AP_Credit_Memo__c();
            creditMemo.Account_Payable_Invoice__c = testData.payables[0].Id;
            creditMemo.Account_Payable_Credit_Memo__c = testData.payables[4].Id;
            creditMemo.Accounting_Period__c = testData.acctPeriods[1].Id;
            creditMemo.Amount__c = -200;

            DmlException dmlEx;
            try {
                insert creditMemo;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(true, dmlEx.getDmlMessage(0).contains(String.format(
                SObjectActions.OVER_APPLIED_ERROR,
                new List<String> {Account_Payable__c.getSObjectType().getDescribe().getLabel()}
            )));
            Test.stopTest();
        }
    }

    @isTest
    private static void testRequireFieldsInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c ap = new Account_Payable__c(
                Date__c = Date.newInstance(1970, 3, 13),
                Due_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Accounting_Period__c = null,
                Payee_Reference__c = '23sdgdgdfhjsytusj45',
                Vendor__c = testData.accounts.get(0).Id,
                Ledger__c = testData.ledgers.get(0).Id
            );

            DMLException dmlEx;
            try {
                insert ap;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testRequireFieldsUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payables.get(4).Accounting_Period__c = NULL;

            DMLException dmlEx;
            try {
                update testData.payables.get(4);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );

            dmlEx = null;
            testData.payables.get(1).Due_Date__c = null;

            try {
                update testData.payables.get(1);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventUpdateCustomerPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            testData.payables[0].Vendor__c = testData.accounts[1].Id;
            DmlException dmlEx;
            try {
                update testData.payables[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();
            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @IsTest
    public static void testPreventUpdatePeriodPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users.get(1)) {

            testData.payables[0].Accounting_Period__c = testData.acctPeriods[3].Id;
            DmlException dmlEx;
            try {
                update testData.payables[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();
            System.assertEquals(
                String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventUpdateActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            // Test update no error since no fields changed.
            Account_Payable__c acctPayable = [
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ];

            DMLException dmlEx;
            try {
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            // Test update error since attempted to change protected field on account payable.
            try {
                acctPayable.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}
                ),
                dmlEx.getDMLMessage(0)
            );

            dmlEx = NULL;
            // Test update error since attempted to add new account payable line.
            try {
                Account_Payable_Line__c acctPayableLine = testData.payableLines.get(0).clone(false, true);
                insert acctPayableLine;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_INSERT_ERROR, dmlEx.getDMLMessage(0));
            Test.stopTest();
        }

    }


    @isTest
    private static void testAssociateAccountPayableTermsFromVendor() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Account_Payable_Terms__c = 30;
            update testData.accounts.get(0);

            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
            accountPayables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Vendor__c = testData.accounts.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                )
            );
            insert accountPayables;

            Date testDueDate = testData.acctPeriods.get(0).Start_Date__c + 30;
            System.assertEquals(
                testDueDate,
                [SELECT Due_Date__c FROM Account_Payable__c WHERE Id = :accountPayables.get(0).Id].Due_Date__c
            );
        }
    }

    @isTest
    private static void testAssociateContactPayableTermsFromContact() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.contacts.get(0).Payable_Days_Due__c = 30;
            update testData.contacts.get(0);

            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
            accountPayables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Contact__c = testData.contacts.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                )
            );
            insert accountPayables;

            Date testDueDate = testData.acctPeriods.get(0).Start_Date__c + 30;
            System.assertEquals(
                testDueDate,
                [SELECT Due_Date__c FROM Account_Payable__c WHERE Id = :accountPayables.get(0).Id].Due_Date__c
            );
        }
    }

    @isTest
    private static void testAssociateEmployeeUserPayableTermsFromContact() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(0)) {
            Test.startTest();

            testData.users.get(1).Payable_Days_Due__c = 30;
            update testData.users.get(1);

            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
            accountPayables.add(
                new Account_Payable__c(
                    Payee_Reference__c = 'employee',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Employee__c = testData.users.get(1).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                )
            );
            insert accountPayables;
            Test.stopTest();
            Date testDueDate = testData.acctPeriods.get(0).Start_Date__c + 30;
            System.assertEquals(
                testDueDate,
                [SELECT Due_Date__c FROM Account_Payable__c WHERE Id = :accountPayables.get(0).Id].Due_Date__c
            );
        }
    }

    @isTest
    private static void testAssociateAccountPayableTermsFromVendorSetDate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Account_Payable_Terms__c = 30;
            update testData.accounts.get(0);

            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
            accountPayables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345',
                    Date__c = null,
                    Vendor__c = testData.accounts.get(0).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                )
            );
            insert accountPayables;

            Date testDueDate = System.today();
            System.assertEquals(
                testDueDate,
                [SELECT Date__c FROM Account_Payable__c WHERE Id = :accountPayables.get(0).Id].Date__c
            );
        }
    }

    @isTest
    private static void testAssociateAccountPayableTermsFromVendorSetDefaultDueDateField() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Account_Payable_Terms__c = 30;
            update testData.accounts.get(0);

            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
            accountPayables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345',
                    Date__c = testData.acctPeriods.get(0).Start_Date__c,
                    Vendor__c = testData.accounts.get(1).Id,
                    Accounting_Period__c = testData.acctPeriods.get(0).Id
                )
            );
            insert accountPayables;

            Test.stopTest();

            System.assertEquals(
                testData.acctPeriods.get(0).Start_Date__c,
                [SELECT Due_Date__c FROM Account_Payable__c WHERE Id = :accountPayables.get(0).Id].Due_Date__c
            );
        }
    }

    @isTest
    private static void testPreventDeleteAPDisbursements() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();

        Test.startTest();
        testData.createCashDisbursements();
        testData.createApDisbursements();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                delete testData.payables.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
        Test.stopTest();
    }
    
    @isTest
    private static void testPreventDuplicatePayeeReferenceVendor() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c acctPayable = testData.payables.get(0).clone(false, true);

            Test.startTest();
            // Test Duplicate insert
            DMLException dmlEx;
            try {
                insert acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            // Test Duplicate same batch
            List<Account_Payable__c> acctPayables = new List<Account_Payable__c>();

            acctPayables.add(testData.payables.get(0).clone(false, true));
            acctPayables.get(0).Payee_Reference__c = 'UPPERCASE_REF';

            acctPayables.add(testData.payables.get(0).clone(false, true));
            acctPayables.get(1).Payee_Reference__c = 'lowercase_ref';

            try {
                insert acctPayables;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceContact() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c acctPayable = testData.payables.get(1).clone(false, true);

            Test.startTest();

            DMLException dmlEx;
            try {
                insert acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            // Test Duplicate same batch
            List<Account_Payable__c> acctPayables = new List<Account_Payable__c>();

            acctPayables.add(testData.payables.get(1).clone(false, true));
            acctPayables.get(0).Payee_Reference__c = 'UPPERCASE_REF';

            acctPayables.add(testData.payables.get(1).clone(false, true));
            acctPayables.get(1).Payee_Reference__c = 'lowercase_ref';

            try {
                insert acctPayables;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceEmployee() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c acctPayable = testData.payables.get(2).clone(false, true);

            Test.startTest();

            DMLException dmlEx;
            try {
                insert acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            // Test Duplicate same batch
            List<Account_Payable__c> acctPayables = new List<Account_Payable__c>();

            acctPayables.add(testData.payables.get(2).clone(false, true));
            acctPayables.get(0).Payee_Reference__c = 'UPPERCASE_REF';

            acctPayables.add(testData.payables.get(2).clone(false, true));
            acctPayables.get(1).Payee_Reference__c = 'lowercase_ref';

            try {
                insert acctPayables;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceVendorAndContactSameBatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c acctPayable1 = testData.payables.get(0).clone(false, true);
            Account_Payable__c acctPayable2 = testData.payables.get(1).clone(false, true);
            List<Account_Payable__c> acctPayables = new List<Account_Payable__c>{acctPayable1,acctPayable2};

            Test.startTest();

            DMLException dmlEx;
            try {
                insert acctPayables;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(1)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceVendorAndEmployeeSameBatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c acctPayable1 = testData.payables.get(0).clone(false, true);
            Account_Payable__c acctPayable2 = testData.payables.get(2).clone(false, true);
            List<Account_Payable__c> acctPayables = new List<Account_Payable__c>{acctPayable1,acctPayable2};

            Test.startTest();

            DMLException dmlEx;
            try {
                insert acctPayables;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(1)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceContactAndEmployeeSameBatch() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c acctPayable1 = testData.payables.get(1).clone(false, true);
            Account_Payable__c acctPayable2 = testData.payables.get(2).clone(false, true);
            List<Account_Payable__c> acctPayables = new List<Account_Payable__c>{acctPayable1,acctPayable2};

            Test.startTest();

            DMLException dmlEx;
            try {
                insert acctPayables;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(1)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceChangeVendor() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            // Test Duplicate update
            Account_Payable__c acctPayable = testData.payables.get(0).clone(false, true);
            acctPayable.Vendor__c = testData.accounts.get(1).Id;
            insert acctPayable;

            DMLException dmlEx;
            try {
                acctPayable.Vendor__c = testData.payables.get(0).Vendor__c;
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceChangeContact() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            // Test Duplicate update
            Account_Payable__c acctPayable = testData.payables.get(1).clone(false, true);
            acctPayable.Contact__c = testData.contacts.get(1).Id;
            insert acctPayable;

            DMLException dmlEx;
            try {
                acctPayable.Contact__c = testData.payables.get(1).Contact__c;
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceChangeEmployee() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            // Test Duplicate update
            Account_Payable__c acctPayable = testData.payables.get(2).clone(false, true);
            acctPayable.Employee__c = TestDataSuite.createTestUser().Id;
            insert acctPayable;

            DMLException dmlEx;
            try {
                acctPayable.Employee__c = testData.payables.get(2).Employee__c;
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceChangePayeeVendorToContact() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            // Test Duplicate update
            Account_Payable__c acctPayable = testData.payables.get(1).clone(false, true);
            acctPayable.Vendor__c = testData.accounts.get(1).Id;
            acctPayable.Contact__c = null;
            insert acctPayable;

            DMLException dmlEx;
            try {
                // Should throw exception as we are creating duplicate payable with same payee reference
                acctPayable.Vendor__c = null;
                acctPayable.Contact__c = testData.payables.get(1).Contact__c;
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceChangePayeeContactToVendor() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            // Test Duplicate update
            Account_Payable__c acctPayable = testData.payables.get(0).clone(false, true);
            acctPayable.Vendor__c = null;
            acctPayable.Contact__c = testData.contacts.get(1).Id;
            insert acctPayable;

            DMLException dmlEx;
            try {
                acctPayable.Vendor__c = testData.payables.get(0).Vendor__c;
                acctPayable.Contact__c = null;
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDuplicatePayeeReferenceChangePayeeEmployeeToVendor() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            // Test Duplicate update
            Account_Payable__c acctPayable = testData.payables.get(0).clone(false, true);
            acctPayable.Vendor__c = null;
            acctPayable.Employee__c = TestDataSuite.createTestUser().Id;
            insert acctPayable;

            DMLException dmlEx;
            try {
                acctPayable.Vendor__c = testData.payables.get(0).Vendor__c;
                acctPayable.Employee__c = null;
                update acctPayable;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.DUPLICATE_PAYEE_REFERENCE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testAccountPayablePostedDeleteError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);

        System.runAs(testData.users.get(1)) {
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Accounting_Period__r.Status__c, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(4).Id].Status__c
            );

            Test.startTest();

            DMLException dmlEx;
            try {
                delete testData.payables.get(4);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR,
                dmlEx.getDMLMessage(0)
            );
        }
    }

    @isTest
    private static void testAccountPayableUnpostedDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);

        System.runAs(testData.users.get(1)) {
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Accounting_Period__r.Status__c, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(4).Id].Status__c
            );

            Test.startTest();

            //Unpost Payables
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.unpost(testData.payables);
            System.assertEquals(true, postResults.get(0).isSuccess);
            delete testData.payables.get(4);
            System.assertEquals(
                0, [
                    SELECT COUNT() FROM Transaction__c WHERE Account_Payable_Line__r.Account_Payable__c = :testData.payables.get(4).Id
                ]
            );
            undelete testData.payables.get(4);

            Test.stopTest();

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(4).Id].Status__c
            );
        }
    }

    @isTest
    private static void testPreventInsertMaxLineCountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createPayables();

        System.runAs(testData.users.get(1)) {
            List<Account_Payable_Line__c> lineList = new List<Account_Payable_Line__c>();

            SObjectActions.MAX_LINE_COUNT = 3;

            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT; i++) {
                lineList.add(testData.payableLines.get(0).clone(false, true));
            }

            Test.startTest();
            DMLException dmlEx;
            try {
                AccountPayableLineActions.isBypassGLAccountValidations = true;
                insert lineList;
                AccountPayableLineActions.isBypassGLAccountValidations = false;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            Test.stopTest();

            System.assertEquals(
                String.format(SObjectActions.MAX_LINE_ERROR, new List<String> {String.valueOf(SObjectActions.MAX_LINE_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventInsertMaxLineCountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {            
            List<Account_Payable_Line__c> lineList = new List<Account_Payable_Line__c>();

            SObjectActions.MAX_LINE_COUNT = 3;

            for (Integer i = 0; i < SObjectActions.MAX_LINE_COUNT - 1; i++) {
                lineList.add(testData.payableLines.get(0).clone(false, true));
            }

            delete testData.payableLines;

            Test.startTest();

            DMLException dmlEx;
            try {
                AccountPayableLineActions.isBypassGLAccountValidations = true;
                insert lineList;
                AccountPayableLineActions.isBypassGLAccountValidations = false;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                null,
                dmlEx
            );
        }
    }

    @isTest
    private static void testPreventInsertLDVMaxLineCountError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .enableLDVMode();

        System.runAs(testData.users.get(1)) {
            List<Account_Payable_Line__c> lineList = new List<Account_Payable_Line__c>();

            SObjectActions.LDV_MAX_LINE_COUNT = 5;

            for (Integer i = 0; i < SObjectActions.LDV_MAX_LINE_COUNT; i++) {
                lineList.add(testData.payableLines.get(0).clone(false, true));
            }

            Test.startTest();
            DMLException dmlEx;
            try {
                AccountPayableLineActions.isBypassGLAccountValidations = true;
                insert lineList;
                AccountPayableLineActions.isBypassGLAccountValidations = false;
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            Test.stopTest();

            System.assertEquals(
                String.format(SObjectActions.MAX_LINE_ERROR, new List<String> {String.valueOf(SObjectActions.LDV_MAX_LINE_COUNT)}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventInsertLDVMaxLineCountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .enableLDVMode();

        System.runAs(testData.users.get(1)) {
            List<Account_Payable_Line__c> lineList = new List<Account_Payable_Line__c>();

            SObjectActions.LDV_MAX_LINE_COUNT = 5;

            for (Integer i = 0; i < SObjectActions.LDV_MAX_LINE_COUNT - 1; i++) {
                lineList.add(testData.payableLines.get(0).clone(false, true));
            }

            delete testData.payableLines;

            Test.startTest();

            DMLException dmlEx;
            try {
                AccountPayableLineActions.isBypassGLAccountValidations = true;
                insert lineList;
                AccountPayableLineActions.isBypassGLAccountValidations = false;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                null,
                dmlEx
            );
        }
    }

    @isTest
    private static void testRequiredVendorContactEmployeeInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c newAp = testData.payables.get(0).clone(false, true);
            newAp.Vendor__c = null;
            newAp.Contact__c = null;
            newAp.Employee__c = null;

            Test.startTest();

            // Test insert error
            DMLException dmlEx;
            try {
                insert newAp;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.REQUIRED_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testRequiredVendorContactEmployeeUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payables.get(4).Vendor__c = null;

            Test.startTest();

            DMLException dmlEx;
            try {
                update testData.payables.get(4);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.REQUIRED_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }

    }

    @isTest
    private static void testMultiplePayeeVendorContactEmployeeInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c newAp = testData.payables.get(0).clone(false, true);
            newAp.Vendor__c = testData.accounts.get(0).Id;
            newAp.Contact__c = testData.contacts.get(0).Id;
            newAp.Employee__c = null;
            newAp.Payee_Reference__c = 'agsahewte463464wtaewgsdgsdgsdgsdsgdq346436';

            Test.startTest();

            // Test insert error
            DMLException dmlEx;
            try {
                insert newAp;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.MULTIPLE_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            newAp = testData.payables.get(0).clone(false, true);
            newAp.Vendor__c = testData.accounts.get(0).Id;
            newAp.Contact__c = null;
            newAp.Employee__c = testData.users.get(0).Id;
            newAp.Payee_Reference__c = 'agsahewte46op]yuopiuwtaewgsdgsdgsdgsdsgdq346436';

            // Test insert error
            dmlEx = null;
            try {
                insert newAp;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.MULTIPLE_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            newAp = testData.payables.get(0).clone(false, true);
            newAp.Vendor__c = null;
            newAp.Contact__c = testData.contacts.get(0).Id;
            newAp.Employee__c = testData.users.get(0).Id;
            newAp.Payee_Reference__c = 'agsahewte463464wtaewgsasdfsefgdsddgsdgsdsgdq346436';

            // Test insert error
            dmlEx = null;
            try {
                insert newAp;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.MULTIPLE_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testMultiplePayeeVendorContactEmployeeUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payables.get(0).Vendor__c = testData.accounts.get(0).Id;
            testData.payables.get(0).Contact__c = testData.contacts.get(0).Id;
            testData.payables.get(0).Employee__c = null;

            Test.startTest();

            // Test update error
            DMLException dmlEx;
            try {
                update testData.payables.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.MULTIPLE_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            testData.payables.get(0).Vendor__c = testData.accounts.get(0).Id;
            testData.payables.get(0).Contact__c = null;
            testData.payables.get(0).Employee__c = testData.users.get(0).Id;

            // Test update error
            dmlEx = null;
            try {
                update testData.payables.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                AccountPayableActions.MULTIPLE_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );

            testData.payables.get(0).Vendor__c = null;
            testData.payables.get(0).Contact__c = testData.contacts.get(0).Id;
            testData.payables.get(0).Employee__c = testData.users.get(0).Id;

            // Test update error
            dmlEx = null;
            try {
                update testData.payables.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.MULTIPLE_PAYEEE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testSetPaymentStatusPartialPayInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c ap = testData.payables.get(0).clone(false, true);
            ap.Payee_Reference__c = 'agdsgdshgewtejo09i4r504-3i5ewfopkewf[pds]';
            insert ap;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            Account_Payable_Line__c apLine = new Account_Payable_Line__c(
                Account_Payable__c = ap.Id,
                Amount__c = 56,
                Quantity__c = 2,
                Expense_GL_Account__c = testData.glAccounts.get(12).Id
            );
            insert apLine;

            Cash_Disbursement__c cd = testData.cashDisbursements.get(0).clone(false, true);
            insert cd;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            //Post Payable
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{ap});
            System.assertEquals(true, postResults[0].isSuccess);

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = ap.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 1
            );
            insert apd;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_PARTIALLY_PAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            AbstractPostHandler apdPostHandler = new APDisbursementPostHandler();
            List<PostResult> apdPostResults = apdPostHandler.unpost(new List<AP_Disbursement__c>{apd});

            TriggerObserver.bypassDeleteApDisbursement = true;
            delete apd;
            TriggerObserver.bypassDeleteApDisbursement = false;

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );
        }
    }

    @isTest
    private static void testSetPaymentStatusFullPayInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c ap = testData.payables.get(0).clone(false, true);
            ap.Payee_Reference__c = 'agdsgdshgewtejo09i4r504-3i5ewfopkewf[pds]';
            ap.Discount_Amount__c = 0;
            insert ap;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            Account_Payable_Line__c apLine = new Account_Payable_Line__c(
                Account_Payable__c = ap.Id,
                Amount__c = 56,
                Expense_GL_Account__c = testData.glAccounts.get(12).Id
            );
            insert apLine;

            Cash_Disbursement__c cd = testData.cashDisbursements.get(0).clone(false, true);
            cd.Amount__c = 56;
            insert cd;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            //Post Payable
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{ap});
            System.assertEquals(true, postResults[0].isSuccess);

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = ap.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = 56
            );
            insert apd;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_PAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            AbstractPostHandler apdPostHandler = new APDisbursementPostHandler();
            List<PostResult> apdPostResults = apdPostHandler.unpost(new List<AP_Disbursement__c>{apd});

            TriggerObserver.bypassDeleteApDisbursement = true;
            delete apd;
            TriggerObserver.bypassDeleteApDisbursement = false;

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );
        }
    }

    @isTest
    private static void testSetPaymentStatusPartialPayCreditMemo() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            List<Account_Payable__c> apList = new List<Account_Payable__c>();
            List<Account_Payable_Line__c> apLineList = new List<Account_Payable_Line__c>();

            Account_Payable__c ap = testData.payables.get(0).clone(false, true);
            ap.Payee_Reference__c = 'agdsgdshgewtejo09i4r504-3i5ewfopkewf[pds]';
            ap.Discount_Amount__c = 0;
            apList.add(ap);

            ap = testData.payables.get(0).clone(false, true);
            ap.Payee_Reference__c = 'agdsgdshgewtejo09i4r504-3i5ewfopkewf[pdssdfbdsfndfnfdnfd]';
            ap.Discount_Amount__c = 0;
            apList.add(ap);

            Test.startTest();

            insert apList;

            Map<Id, Account_Payable__c> accountPayableMap = new Map<Id, Account_Payable__c>(apList);

            Map<Id, Account_Payable__c> validatedAccountPayableMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id IN :accountPayableMap.keySet()
            ]);

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(0).Id).Payment_Status__c
            );

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(1).Id).Payment_Status__c
            );

            Account_Payable_Line__c apLine = new Account_Payable_Line__c(
                Account_Payable__c = apList.get(0).Id,
                Amount__c = -56,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(12).Id
            );
            apLineList.add(apLine);

            apLine = new Account_Payable_Line__c(
                Account_Payable__c = apList.get(1).Id,
                Amount__c = 56,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(12).Id
            );
            apLineList.add(apLine);
            insert apLineList;

            AP_Credit_Memo__c apm = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = apList.get(1).Id,
                Account_Payable_Credit_Memo__c = apList.get(0).Id,
                Amount__c = -40
            );
            apm.Accounting_Period__c = testData.acctPeriods.get(0).Id;
            insert apm;

            validatedAccountPayableMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id IN :accountPayableMap.keySet()
            ]);

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_PARTIALLY_PAID,
                validatedAccountPayableMap.get(apList.get(0).Id).Payment_Status__c
            );

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_PARTIALLY_PAID,
                validatedAccountPayableMap.get(apList.get(1).Id).Payment_Status__c
            );
            delete apm;

            Test.stopTest();

            validatedAccountPayableMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id IN :accountPayableMap.keySet()
            ]);

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(0).Id).Payment_Status__c
            );

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(1).Id).Payment_Status__c
            );
        }
    }

    @isTest
    private static void testSetPaymentStatusFullPayCreditMemo() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            List<Account_Payable__c> apList = new List<Account_Payable__c>();
            List<Account_Payable_Line__c> apLineList = new List<Account_Payable_Line__c>();

            Account_Payable__c ap = testData.payables.get(0).clone(false, true);
            ap.Payee_Reference__c = 'agdsgdshgewtejo09i4r504-3i5ewfopkewf[pds]';
            ap.Discount_Amount__c = 0;
            apList.add(ap);

            ap = testData.payables.get(0).clone(false, true);
            ap.Payee_Reference__c = 'agdsgdshgewtejo09i4r504-3i5ewfopkewf[pdssdfbdsfndfnfdnfd]';
            ap.Discount_Amount__c = 0;
            apList.add(ap);

            Test.startTest();

            insert apList;

            Map<Id, Account_Payable__c> accountPayableMap = new Map<Id, Account_Payable__c>(apList);

            Map<Id, Account_Payable__c> validatedAccountPayableMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id IN :accountPayableMap.keySet()
            ]);

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(0).Id).Payment_Status__c
            );

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(1).Id).Payment_Status__c
            );

            Account_Payable_Line__c apLine = new Account_Payable_Line__c(
                Account_Payable__c = apList.get(0).Id,
                Amount__c = -56,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(12).Id
            );
            apLineList.add(apLine);

            apLine = new Account_Payable_Line__c(
                Account_Payable__c = apList.get(1).Id,
                Amount__c = 56,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(12).Id
            );
            apLineList.add(apLine);
            insert apLineList;

            AP_Credit_Memo__c apm = new AP_Credit_Memo__c(
                Account_Payable_Invoice__c = apList.get(1).Id,
                Account_Payable_Credit_Memo__c = apList.get(0).Id,
                Amount__c = -56,
                Accounting_Period__c = testData.acctPeriods.get(0).Id
            );
            insert apm;

            validatedAccountPayableMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id IN :accountPayableMap.keySet()
            ]);

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_PAID,
                validatedAccountPayableMap.get(apList.get(0).Id).Payment_Status__c
            );

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_PAID,
                validatedAccountPayableMap.get(apList.get(1).Id).Payment_Status__c
            );

            delete apm;

            Test.stopTest();

            validatedAccountPayableMap = new Map<Id, Account_Payable__c>([
                SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id IN :accountPayableMap.keySet()
            ]);

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(0).Id).Payment_Status__c
            );

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                validatedAccountPayableMap.get(apList.get(1).Id).Payment_Status__c
            );
        }
    }

    @isTest
    private static void testSetPaymentStatusFullPayScaleGreaterThanTwoInvoice() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Account_Payable__c ap = testData.payables.get(0).clone(false, true);
            ap.Payee_Reference__c = 'agdsgdshgewtejo09i4r504-3i5ewfopkewf[pds]';
            insert ap;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            Account_Payable_Line__c apLine = new Account_Payable_Line__c(
                Account_Payable__c = ap.Id,
                Amount__c = 56.34767896,
                Quantity__c = 2
            );
            apLine.Expense_GL_Account__c = testData.glAccounts.get(12).Id;
            insert apLine;

            Cash_Disbursement__c cd = testData.cashDisbursements.get(0).clone(false, true);
            cd.Amount__c = 56;
            insert cd;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            //Post Payable
            AbstractPostHandler postHandler = new AccountPayablePostHandler();
            List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{ap});
            System.assertEquals(true, postResults[0].isSuccess);

            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = ap.Id,
                Cash_Disbursement__c = cd.Id,
                Paid_Amount__c = [SELECT Net_Amount__c FROM Account_Payable__c WHERE Id = :ap.Id].Net_Amount__c - 0.001
            );
            insert apd;

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_PAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );

            AbstractPostHandler apdPostHandler = new APDisbursementPostHandler();
            List<PostResult> apdPostResults = apdPostHandler.unpost(new List<AP_Disbursement__c>{apd});

            TriggerObserver.bypassDeleteApDisbursement = true;
            delete apd;
            TriggerObserver.bypassDeleteApDisbursement = false;

            Test.stopTest();

            System.assertEquals(
                AccountPayableActions.PAYMENT_STATUS_UNPAID,
                [SELECT Id, Payment_Status__c FROM Account_Payable__c WHERE Id = :ap.Id].Payment_Status__c
            );
        }
    }

    @isTest
    private static void testSetDefaultFieldsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            String defaultValue = 'In Process';
            for (Schema.PicklistEntry pickListEntry : Account_Payable__c.Status__c.getDescribe().getPicklistValues()) {
                if (pickListEntry.isDefaultValue() && pickListEntry.getValue() != AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED) {
                    defaultValue = pickListEntry.getValue();
                }
            }

            Test.startTest();

            // Test status posted
            Account_Payable__c ap = testData.payables.get(0).clone(false, true);

            ap.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED;
            ap.Payment_Status__c = AccountPayableActions.PAYMENT_STATUS_PAID;
            ap.Payee_Reference__c = 'agaeswgji0a[gjsd[infsafsdfosdijfsdofjdsofjdsqvwerewofjdsf]]';
            ap.Closed_Accounting_Period__c = testData.acctPeriods.get(0).Id;
            ap.Credit_Memo_Applied_Amount__c = 2;
            insert ap;

            Account_Payable__c accountPayablePostedStatus = [
                SELECT Id, Status__c, Payment_Status__c, Closed_Accounting_Period__c, Credit_Memo_Applied_Amount__c
                FROM Account_Payable__c
                WHERE Id = :ap.Id
                LIMIT 1
            ];

            System.assertEquals(defaultValue, accountPayablePostedStatus.Status__c);

            System.assertEquals(AccountPayableActions.PAYMENT_STATUS_UNPAID, accountPayablePostedStatus.Payment_Status__c);

            System.assertEquals(null, accountPayablePostedStatus.Closed_Accounting_Period__c);

            System.assertEquals(0, accountPayablePostedStatus.Credit_Memo_Applied_Amount__c);

            // Test status null
            ap = testData.payables.get(0).clone(false, true);
            ap.Status__c = null;
            ap.Payment_Status__c = AccountPayableActions.PAYMENT_STATUS_PAID;
            ap.Payee_Reference__c = 'agaeswgji0a[gjsd[infsafsdfosdijfsdofjdsofjdsofjdsasdfasdfesf]]gasgsdg';
            ap.Closed_Accounting_Period__c = testData.acctPeriods.get(0).Id;
            ap.Credit_Memo_Applied_Amount__c = 2;
            insert ap;

            Account_Payable__c accountPayableNullStatus = [
                SELECT Id, Status__c, Payment_Status__c, Closed_Accounting_Period__c, Credit_Memo_Applied_Amount__c
                FROM Account_Payable__c
                WHERE Id = :ap.Id
                LIMIT 1
            ];

            System.assertEquals(defaultValue, accountPayableNullStatus.Status__c);
            System.assertEquals(AccountPayableActions.PAYMENT_STATUS_UNPAID, accountPayableNullStatus.Payment_Status__c);
            System.assertEquals(null, accountPayableNullStatus.Closed_Accounting_Period__c);
            System.assertEquals(0, accountPayableNullStatus.Credit_Memo_Applied_Amount__c);

            // Test status defaultvalue
            ap = testData.payables.get(0).clone(false, true);
            ap.Status__c = defaultValue;
            ap.Payment_Status__c = AccountPayableActions.PAYMENT_STATUS_PAID;
            ap.Payee_Reference__c = 'agaeswgji0a[gjsd[infsafsdfosdijfsdofjdsosgsdgdsgfjdsofjdsf]s223qvewr]';
            ap.Closed_Accounting_Period__c = testData.acctPeriods.get(0).Id;
            ap.Credit_Memo_Applied_Amount__c = 2;
            insert ap;

            Account_Payable__c accountPayableDefaultStatus = [
                SELECT Id, Status__c, Payment_Status__c, Closed_Accounting_Period__c, Credit_Memo_Applied_Amount__c
                FROM Account_Payable__c
                WHERE Id = :ap.Id
                LIMIT 1
            ];

            System.assertEquals(defaultValue, accountPayableDefaultStatus.Status__c);
            System.assertEquals(AccountPayableActions.PAYMENT_STATUS_UNPAID, accountPayableDefaultStatus.Payment_Status__c);
            System.assertEquals(null, accountPayableDefaultStatus.Closed_Accounting_Period__c);
            System.assertEquals(0, accountPayableDefaultStatus.Credit_Memo_Applied_Amount__c);

            // Test status arbitrary value
            ap = testData.payables.get(0).clone(false, true);
            ap.Status__c = 'Arbitrary';
            ap.Payment_Status__c = AccountPayableActions.PAYMENT_STATUS_PAID;
            ap.Payee_Reference__c = 'agaeswgji0a[gjsd[infsafsdfosdijfsdofjdsSAGSDGSDofjdsofjdsf]s223qvewr]';
            ap.Closed_Accounting_Period__c = testData.acctPeriods.get(0).Id;
            ap.Credit_Memo_Applied_Amount__c = 2;
            insert ap;

            Test.stopTest();

            Account_Payable__c accountPayableArbitraryStatus = [
                SELECT Id, Status__c, Payment_Status__c, Closed_Accounting_Period__c, Credit_Memo_Applied_Amount__c
                FROM Account_Payable__c
                WHERE Id = :ap.Id
                LIMIT 1
            ];

            System.assertEquals('Arbitrary', accountPayableArbitraryStatus.Status__c);
            System.assertEquals(AccountPayableActions.PAYMENT_STATUS_UNPAID, accountPayableArbitraryStatus.Payment_Status__c);
            System.assertEquals(null, accountPayableArbitraryStatus.Closed_Accounting_Period__c);
            System.assertEquals(0, accountPayableArbitraryStatus.Credit_Memo_Applied_Amount__c);
        }
    }

    @isTest
    private static void testResolveAccountingPeriodAccountPayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
            accountPayables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345',
                    Date__c = Date.newinstance(1992, 1, 2),
                    Due_Date__c =  System.today(),
                    Vendor__c = testData.accounts.get(0).Id
                )
            );
            insert accountPayables;

            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();
            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = accountPayables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Expense_GL_Account__c = testData.glAccounts.get(16).Id
                )
            );
            insert accountPayableLines;
            Test.stopTest();

            System.assertEquals(
                testData.acctPeriods.get(3).Id,
                [SELECT Accounting_Period__c FROM Account_Payable__c WHERE Id = :accountPayables.get(0).Id].Accounting_Period__c
            );
        }
    }

    @isTest
    private static void testPreventDeleteLineAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DMLException dmlEx = null;
            try {
                delete testData.payableLines.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }
            Test.stopTest();

            System.assertEquals(
                SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventUpdateCurrencyIfPosted_MC() {
        try {
            //will throw an exception in case of non-MC org
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();

                Test.startTest();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c testAP = new Account_Payable__c(
                    Payee_Reference__c = '2345',
                    Date__c = Date.newInstance(1992, 1, 2),
                    Due_Date__c =  System.today(),
                    Vendor__c = testData.accounts.get(0).Id
                );
                insert testAP;

                List<Account_Payable_Line__c> testLines = new List<Account_Payable_Line__c>{
                    new Account_Payable_Line__c(
                        Account_Payable__c = testAP.Id,
                        Amount__c = 45,
                        Date__c = testData.acctPeriods.get(0).Start_Date__c,
                        Expense_GL_Account__c = testData.glAccounts.get(16).Id
                    )
                };
                insert testLines;

                AbstractPostHandler postHandler = new AccountPayablePostHandler();
                List<PostResult> postResults = postHandler.post(new List<Account_Payable__c>{testAP});
                System.assertEquals(true, postResults.get(0).isSuccess);

                Account_Payable__c postedAP = [SELECT Id FROM Account_Payable__c WHERE Id = :testAP.Id LIMIT 1];
                postedAP.put('CurrencyIsoCode', newCurrencyIsoCode);

                DmlException dmlEx;
                try {
                    update postedAP;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }

                Test.stopTest();

                SourceDocumentUpdateFieldValidator sfu = new AccountPayableFieldUpdateValidator();
                System.assertEquals(
                    String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}),
                    dmlEx.getDMLMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {

            Account_Payable__c payable =  testData.payables[0].clone(false,true);
            payable.Currency_Conversion_Rate__c = 1.235343967;
            payable.Discount_Amount__c = 0.004;
            payable.Payee_Reference__c = testData.payables[0].Payee_Reference__c + 'w6yhgerhre';
            insert payable;

            Account_Payable__c newPayable = [
                SELECT
                    Id,
                    Currency_Conversion_Rate__c,
                    Discount_Amount__c
                FROM Account_Payable__c
                WHERE Id = :payable.Id
            ];

            System.assertEquals(1.235344,newPayable.Currency_Conversion_Rate__c);
            System.assertEquals(0.00,newPayable.Discount_Amount__c);
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {

            Account_Payable__c payable = testData.payables[0];
            payable.Currency_Conversion_Rate__c = 1.235343967;
            payable.Discount_Amount__c = 10.3499;
            payable.Payee_Reference__c = testData.payables[0].Payee_Reference__c + 'w6yhgerhre';
            update payable;

            Account_Payable__c newPayable = [
                SELECT
                    Id,
                    Currency_Conversion_Rate__c,
                    Discount_Amount__c
                FROM Account_Payable__c
                WHERE Id = :payable.Id
            ];

            System.assertEquals(1.235344,newPayable.Currency_Conversion_Rate__c);
            System.assertEquals(10.35,newPayable.Discount_Amount__c);
        }
    }

    @IsTest
    public static void testAccountPayableNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            Account_Payable__c pay = new Account_Payable__c();
            try {
                insert pay;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testCalculateUseTaxValueNativeFS() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createPayables()
            .createProducts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Account_Payable__c testPayable = testData.payables[0];
            delete [SELECT Id FROM Account_Payable_Line__c WHERE Account_Payable__c = :testPayable.Id];

            Product2 taxRateProduct = testData.products[4];
            Product2 taxableProduct = testData.products[3];
            Account_Tax__c tax = new Account_Tax__c(
                Account__c = testPayable.Vendor__c,
                Tax_Rate__c = taxRateProduct.Id,
                Tax_Type__c = 'Purchase'
            );
            insert tax;

            Account_Payable_Line__c taxableLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 45,
                Date__c = testPayable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id,
                Product__c = taxableProduct.Id
            );

            Account_Payable_Line__c useTaxLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 10,
                Date__c = testPayable.Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id,
                Product__c = taxRateProduct.Id
            );

            insert new List<Account_Payable_Line__c>{taxableLine, useTaxLine};

            System.assertEquals(10, [SELECT Id, Purchase_Tax2__c FROM Account_Payable__c WHERE Id = :testPayable.Id].Purchase_Tax2__c);
            System.assertEquals(true, [SELECT Tax_Line__c FROM Account_Payable_Line__c WHERE Id = :useTaxLine.Id].Tax_Line__c);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCalculateSalesTaxValueNativeFS_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createProducts()
                .setLineLevelPost();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c testPayable = new Account_Payable__c(
                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                    Date__c = Date.today(),
                    Due_Date__c = Date.today().addDays(30),
                    Vendor__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = testData.ledgers[0].Id
                );
                testPayable.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert testPayable;

                Product2 taxRateProduct = testData.products[4];
                Product2 taxableProduct = testData.products[3];
                Account_Tax__c tax = new Account_Tax__c(
                    Account__c = testPayable.Vendor__c,
                    Tax_Rate__c = taxRateProduct.Id,
                    Tax_Type__c = 'Purchase'
                );
                insert tax;

                Account_Payable_Line__c taxableLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayable.Id,
                    Amount__c = 45,
                    Date__c = testPayable.Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Product__c = taxableProduct.Id
                );
                taxableLine.put('CurrencyIsoCode', newCurrencyIsoCode);

                Account_Payable_Line__c useTaxLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayable.Id,
                    Amount__c = 10,
                    Date__c = testPayable.Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Product__c = taxRateProduct.Id
                );
                useTaxLine.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert new List<Account_Payable_Line__c>{taxableLine, useTaxLine};

                System.assertEquals(10, [SELECT Id, Purchase_Tax2__c FROM Account_Payable__c WHERE Id = :testPayable.Id].Purchase_Tax2__c.setScale(2, System.RoundingMode.HALF_UP));
                System.assertEquals(true, [SELECT Tax_Line__c FROM Account_Payable_Line__c WHERE Id = :useTaxLine.Id].Tax_Line__c);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeIfNullInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createPayables();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c ap = testData.payables[0].clone(false,true);
                ap.Payee_Reference__c = 'test';
                ap.put('CurrencyIsoCode', null);

                insert ap;
                Id apId = ap.Id;

                ap = Database.query('SELECT Id, CurrencyIsoCode FROM Account_Payable__c WHERE Id = :apId');
                System.assertNotEquals(null, ap);
                System.assertNotEquals(null, ap.get('CurrencyIsoCode'));
                System.assertEquals(UserInfo.getDefaultCurrency(), ap.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeIfNullUpdate_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()//will throw an exception in case of non-MC org
                .createPayables();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c ap = testData.payables[0].clone(false,true);
                ap.Payee_Reference__c = 'test';

                insert ap;
                Id apId = ap.Id;

                ap.put('CurrencyIsoCode', null);
                update ap;

                ap = Database.query('SELECT Id, CurrencyIsoCode FROM Account_Payable__c WHERE Id = :apId');
                System.assertNotEquals(null, ap);
                System.assertNotEquals(null, ap.get('CurrencyIsoCode'));
                System.assertEquals(UserInfo.getDefaultCurrency(), ap.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest 
    public static void testZeroBalanceClosedAPFieldNull(){
            TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createCashDisbursementBatches()
                .createCashDisbursements();
                
                
         
            System.runAs(testData.users[1]) {
                Test.startTest();
                testData.payables[0].Status__c = 'Approved';
                testData.payables[0].Discount_Amount__c = 0;
                update testData.payables;
    
                testData.payableLines[0].Amount__c = 4;
                testData.payableLines[1].Amount__c = 3;
                testData.payableLines[2].Amount__c = 3;                        
                update testData.payableLines;
    
                testData.cashDisbursements[0].Amount__c = 10.00;
                update testData.cashDisbursements[0];
    
                for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                    System.assertEquals(true, result.isSuccess);
                }

                testData.createApDisbursements();

                system.assertNotEquals(null, [SELECT Closed_Accounting_Period__c 
                                                FROM Account_Payable__c 
                                                WHERE Id = :testData.payables[0].Id].Closed_Accounting_Period__c);

                delete testData.cashDisbursementBatch[0];

                system.assertEquals(null, [SELECT Closed_Accounting_Period__c 
                FROM Account_Payable__c 
                WHERE Id = :testData.payables[0].Id].Closed_Accounting_Period__c);
            }   
    
    }

    @IsTest 
    public static void testRequiredPayeeRefOnStatusDraftError() {

        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

            System.runAs(testData.users[1]) {
                Account_Payable__c ap = testData.payables[0];
                ap.Payee_Reference__c = null;
                update ap;
            }
        }
        catch (DMLException ex) {
            Assert.isNotNull(ex);
            Assert.areEqual(ex.getDMLMessage(0), Label.COMMON_ERR_COMPLETE_THIS_FIELD);
        }

    }

    @IsTest 
    public static void testRequiredPayeeRefOnStatusDraft() {

        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users[1]) {
            Account_Payable__c ap = testData.payables[0];
            ap.Payee_Reference__c = 'Test';
            update ap;

            Account_Payable__c payable = [Select Id, Payee_Reference__c From Account_Payable__c Where Id=:ap.Id];
            
            Assert.areEqual(payable.Payee_Reference__c, ap.Payee_Reference__c);
        }

    }

    @IsTest 
    public static void testPayableFieldRestrictOnPaymentFeatureDisable(){
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
                
        System.runAs(testData.users[1]) {
            Test.startTest();
                
            try {
                FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, false);
                Account_Payable__c payable = testData.payables[0].clone(false, true);
                payable.AS_Pay_Type__c = 'ACH';
                insert payable;
            }
            catch(DMLException ex) {
                Assert.isNotNull(ex);
                Assert.isTrue(ex.getMessage().contains(String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<string>{getPayableRestrictFields()})));
            }

            Test.stopTest();
        }
    }

    @IsTest 
    public static void testPayableFieldRestrictOnPaymentFeatureEnable(){
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        string payeeRef = '1234567890';
                
        System.runAs(testData.users[1]) {
            Test.startTest();
                
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
            Account_Payable__c payable = testData.payables[0].clone(false, true);
            payable.AS_Pay_Type__c = 'ACH';
            payable.Payee_Reference__c = payeeRef;
            insert payable;

            Test.stopTest();

            Assert.isNotNull([SELECT Id FROM Account_Payable__c WHERE Payee_Reference__c =: payeeRef]);
    
        }
    }

    @IsTest 
    public static void testUpdatePayableFieldRestrictOnPaymentFeatureDisable(){
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
                
        System.runAs(testData.users[1]) {
            Test.startTest();
                
            try {
                testData.payables[0].AS_Pay_Type__c = 'ACH';
                Update testData.payables[0];
            }
            catch(DMLException ex) {
                Assert.isNotNull(ex);
                Assert.areEqual(ex.getDMLMessage(0), String.format(Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED, new List<string>{getPayableRestrictFields()}));
            }

            Test.stopTest();
        }
    }

    @IsTest 
    public static void testUpdatePayableFieldRestrictOnPaymentFeatureEnable()
    {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        string payeeRef = '1234567890';

        System.runAs(testData.users[1]) {
            Test.startTest();
                
            FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);    
            testData.payables[0].AS_Pay_Type__c = 'ACH';
            testData.payables[0].Payee_Reference__c = payeeRef;
            Update testData.payables[0];
            
            Test.stopTest();

            Assert.isNotNull([SELECT Id FROM Account_Payable__c WHERE Payee_Reference__c =: payeeRef]);
        }

    }

    private static String getPayableRestrictFields() {
        APAutomationControl service = new APAutomationControl();
        return Service.getFieldLabels(Service.getFieldGrants().get(Account_Payable__c.SObjectType));
    }

    @IsTest
    private static void testUpdateStatusToInProcess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = AccountPayableActions.STATUS_DRAFT;
            update testData.payables[0];
            Test.stopTest();

            Assert.isNotNull([SELECT Id FROM Account_Payable__c WHERE Id = :testData.payables[0].Id AND Status__c = 'In Process']);
        }
    }
    
    @IsTest
    public static void testpreventUpdatingOnHoldstatus()
    {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users[1]) {
            Test.startTest();
            try{
                Account_Payable__c acctPayable = testData.payables.get(0).clone(false, true);
                acctPayable.On_Hold__c = true;
                Insert acctPayable;
            }catch(Exception ex){
                System.assert(ex.getMessage().contains(Label.PAYABLE_CANT_BE_HOLD_IF_BALANCE_ZERO_ERROR),Label.PAYABLE_CANT_BE_HOLD_IF_BALANCE_ZERO_ERROR);
            }

            try{
                Account_Payable__c acctPayable = testData.payables.get(1).clone(false, true);
                acctPayable.Payee_Reference__c = '2345';
				Insert acctPayable;

                acctPayable.On_Hold__c = true;
				Update acctPayable;

            }catch(Exception ex){
                System.assert(ex.getMessage().contains(Label.PAYABLE_CANT_BE_HOLD_IF_BALANCE_ZERO_ERROR),Label.PAYABLE_CANT_BE_HOLD_IF_BALANCE_ZERO_ERROR);
            }

            Test.stopTest();

        }

    }
}