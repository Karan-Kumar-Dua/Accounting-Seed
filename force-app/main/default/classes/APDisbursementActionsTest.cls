@IsTest
public class APDisbursementActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    public testMethod static void testHandleDeletion() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                Paid_Amount__c = 10
            );
            insert testApDisbursement;

            List<Transaction__c> apdTransactions = [SELECT Id FROM Transaction__c WHERE AP_Disbursement__c = :testApDisbursement.Id];
            System.assertEquals(true, apdTransactions.isEmpty());

            DmlException dmlEx;
            try {
                delete testApDisbursement;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(APDisbursementActions.DELETION_ERROR, dmlEx.getDMLMessage(0));
        }

    }

    public testMethod static void testSetAccountingPeriodFromAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            AP_Disbursement__c apDisbursement = new AP_Disbursement__c();
            apDisbursement.Account_Payable__c = testData.payables[0].Id;
            apDisbursement.Cash_Disbursement__c = testData.cashDisbursements[0].Id;
            apDisbursement.Accounting_Period__c = NULL;
            apDisbursement.Applied_Date__c = testData.acctPeriods[2].Start_Date__c.addDays(3);
            apDisbursement.Paid_Amount__c = 1;
            insert apDisbursement;
            System.assertNotEquals(NULL, [SELECT Id, Accounting_Period__c FROM AP_Disbursement__c WHERE Id = :apDisbursement.Id]);
            System.assertEquals(
                testData.acctPeriods[2].Id,
                [SELECT Id, Accounting_Period__c FROM AP_Disbursement__c WHERE Id = :apDisbursement.Id].Accounting_Period__c
            );
        }

    }

    public testMethod static void testSetAccountingPeriodNoAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            AP_Disbursement__c apDisbursement = new AP_Disbursement__c();
            apDisbursement.Account_Payable__c = testData.payables[0].Id;
            apDisbursement.Cash_Disbursement__c = testData.cashDisbursements[0].Id;
            apDisbursement.Accounting_Period__c = NULL;
            apDisbursement.Applied_Date__c = NULL;
            apDisbursement.Paid_Amount__c = 1;
            insert apDisbursement;
            System.assertNotEquals(NULL, [SELECT Id, Accounting_Period__c FROM AP_Disbursement__c WHERE Id = :apDisbursement.Id]);
            System.assertEquals(
                testData.cashDisbursements[0].Accounting_Period__c,
                [SELECT Id, Accounting_Period__c FROM AP_Disbursement__c WHERE Id = :apDisbursement.Id].Accounting_Period__c
            );
        }
    }

    public testMethod static void testAPDUpdateAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            AP_Disbursement__c apDisbursement = new AP_Disbursement__c();
            apDisbursement.Account_Payable__c = testData.payables[0].Id;
            apDisbursement.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apDisbursement.Accounting_Period__c = testData.acctPeriods[1].Id;
            apDisbursement.Applied_Date__c = NULL;
            apDisbursement.Paid_Amount__c = 1;
            insert apDisbursement;

            List<AP_Disbursement__c> apdsBeforeUpdate = [SELECT Id, Applied_Date__c FROM AP_Disbursement__c WHERE Id = :apDisbursement.Id];
            System.assertEquals(testData.acctPeriods[1].Start_Date__c, apdsBeforeUpdate[0].Applied_Date__c);

            apDisbursement.Applied_Date__c = testData.acctPeriods[1].End_Date__c.addDays(40);

            DMLException dmlEx;
            try {
                update apDisbursement;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new APDisbursementFieldUpdateValidator();
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

    public testMethod static void testSetAppliedDateOutsideAcctPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();
        Date today = Date.today();

        System.runAs(testData.users[1]) {
            AP_Disbursement__c apDisbursement = new AP_Disbursement__c();
            apDisbursement.Account_Payable__c = testData.payables[0].Id;
            apDisbursement.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apDisbursement.Accounting_Period__c = testData.acctPeriods[1].Id;
            apDisbursement.Applied_Date__c = today;
            apDisbursement.Paid_Amount__c = 1;

            DMLException dmlEx;
            try {
                insert apDisbursement;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(String.format(APDisbursementActions.AUTO_POST_FAILED_ERROR, new List<String>{APDisbursementActions.APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR}), dmlEx.getDmlMessage(0));
        }
    }

    public testMethod static void testPreventUpdateAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;

            try {
                testData.apDisbursements[4].Accounting_Period__c = testData.acctPeriods[1].Id;
                update testData.apDisbursements[4];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new APDisbursementFieldUpdateValidator();
            String expectedMessage = String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)});
            System.assertEquals(expectedMessage, dmlEx.getDMLMessage(0));
        }
        Test.stopTest();
    }

    @IsTest
    public static void testDeleteWithTransactionsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            //Create new AP Disbursement with posting
            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[5].Id,
                Paid_Amount__c = 1
            );
            insert testApDisbursement;
            //Make sure transactions for the new AP Disbursement record were created
            List<Transaction__c> apdTransactions = [SELECT Id FROM Transaction__c WHERE AP_Disbursement__c = :testApDisbursement.Id];
            System.assertEquals(2, apdTransactions.size());

            //Delete the AP Disbursements with all related Transactions
            delete testApDisbursement;
            Integer transactionLeft = [SELECT count() FROM Transaction__c WHERE Id IN :apdTransactions];
            System.assertEquals(0, transactionLeft);
        }

    }

    public testMethod static void testTransactionCreationError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                Paid_Amount__c = 10
            );

            insert extraAPD;//without posting bc Debit GL Account == AP Control GL Account

            System.assertEquals(true, [SELECT Id FROM Transaction__c WHERE AP_Disbursement__c = :extraAPD.Id].isEmpty());
        }
    }

    @IsTest
    public static void testAPDisbursementNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;

            AP_Disbursement__c apd = new AP_Disbursement__c();

            try {
                insert apd;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            AP_Disbursement__c apd = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                Paid_Amount__c = 1.989342348934
            );

            insert apd;

            AP_Disbursement__c newApd = [
                SELECT Id,
                    Paid_Amount__c
                FROM AP_Disbursement__c
                WHERE Id = : apd.Id];

            System.assertEquals(1.99, newApd.Paid_Amount__c);
        }

    }

    @IsTest
    public static void testPreventCreateSameCurrency_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org
            Test.startTest();
            testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements(false);

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c testPayable = testData.payables.get(0);
                Cash_Disbursement__c testCD = testData.cashDisbursements.get(0);

                //create APD record
                AP_Disbursement__c newAPD = new AP_Disbursement__c(
                    Account_Payable__c = testPayable.Id,
                    Cash_Disbursement__c = testCD.Id,
                    Paid_Amount__c = 10
                );
                newAPD.put('CurrencyIsoCode', theNewCurrencyIsoCode);

                DmlException dmlEx;
                try {
                    insert newAPD;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }
                //APD currency will be populated in before insert trigger so no errors expected
                System.assertEquals(NULL, dmlEx);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }
    
    @IsTest
    public static void testPreventCreateSamePayeeVendor() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements.get(0).Id,
                Paid_Amount__c = 10
            );

            DmlException dmlEx;
            try {
                insert extraAPD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            //same vendor - no errors expected
            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testPreventCreateSamePayeeContact() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables.get(1).Id,
                Cash_Disbursement__c = testData.cashDisbursements.get(1).Id,
                Paid_Amount__c = 10
            );

            DmlException dmlEx;
            try {
                insert extraAPD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            //same contact - no errors expected
            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testPreventCreateSamePayeeEmployee() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            AP_Disbursement__c extraAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables.get(2).Id,
                Cash_Disbursement__c = testData.cashDisbursements.get(2).Id,
                Paid_Amount__c = 10
            );

            DmlException dmlEx;
            try {
                insert extraAPD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            //same User - no errors expected
            System.assertEquals(NULL, dmlEx);
        }
    }

    public testMethod static void testPreventUpdateActionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;

            try {
                testData.apDisbursements[4].Paid_Amount__c = 20;
                update testData.apDisbursements[4];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            SourceDocumentUpdateFieldValidator sfu = new APDisbursementFieldUpdateValidator();
            String expectedMessage = String.format(SourceDocumentUpdateFieldValidator.UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)});
            System.assertEquals(expectedMessage, dmlEx.getDmlMessage(0));
        }
        Test.stopTest();
    }

    public testMethod static void testPreventUpdateActionIfPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        System.runAs(testData.users[1]) {
            DMLException dmlEx;
            try {
                testData.apDisbursements[3].Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                update testData.apDisbursements[3];
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
            //Posting Status will be set to "Posted" because this APD record has existed transactions
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
                [SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testData.apDisbursements[3].Id].Status__c
            );
        }
        Test.stopTest();
    }

    public testMethod static void testTriggerObserverLockedFieldUpdateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        List<AP_Disbursement__c> apDisbursements = testData.apDisbursements;

        System.runAs(testData.users[1]) {
            TriggerObserver.SObjectFieldUpdateObserverException fieldUpdateEx;

            try {
                TriggerObserver.getInstance().watch(apDisbursements);
                TriggerObserver.getInstance().unlockField(AP_Disbursement__c.Status__c);
                apDisbursements[0].Status__c = 'Approved';
                TriggerObserver.reset();
                TriggerObserver.getInstance().validateObservedContent(apDisbursements);
            } catch (TriggerObserver.SObjectFieldUpdateObserverException ex) {
                fieldUpdateEx = ex;
            }

            System.assertEquals(null, fieldUpdateEx);
        }
        Test.stopTest();
    }

    @IsTest
    public static void testTriggerObserverLockedFieldUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements().createApDisbursements();

        System.runAs(testData.users[1]) {
            List<AP_Disbursement__c> apDisbursements = [SELECT Id, Status__c FROM AP_Disbursement__c];
            
            TriggerObserver.SObjectFieldUpdateObserverException fieldUpdateEx;

            try {
                TriggerObserver.getInstance().watch(apDisbursements);
                apDisbursements[4].Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
                TriggerObserver.getInstance().validateObservedContent(apDisbursements);
            } catch (TriggerObserver.SObjectFieldUpdateObserverException ex) {
                fieldUpdateEx = ex;
            }

            System.assertNotEquals(NULL, fieldUpdateEx);
        }
        Test.stopTest();
    }

    @IsTest
    private static void testUpdateLegacyAPDAndSetPostingStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {
            //Turn off auto posting of APDs
            testData.disableAutoPostSourceDocuments();
            //create new APD record (will not be auto posted on creation)
            AP_Disbursement__c testAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testData.cashDisbursements[0].Id,
                Paid_Amount__c = 10
            );
            insert testAPD;
            //make sure that Posting Status is equal to "Approved" after APD creation
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
                ].Status__c
            );

            Transaction__c trans = new Transaction__c(
                AP_Disbursement__c = testAPD.Id,
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Date__c = testData.acctPeriods[1].Start_Date__c,
                Ledger__c = testData.ledgers[0].Id,
                GL_Account__c = testData.glAccounts[0].Id,
                Amount__c = testAPD.Paid_Amount__c
            );
            TransactionActions.createTransactions(new List<Transaction__c>{trans});

            testAPD.Status__c = NULL;
            update testAPD;
            //Make sure that APD has been posted successfully
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM AP_Disbursement__c WHERE Id = :testAPD.Id
                ].Status__c
            );
            //make sure existed Transaction is still in place -> means only the Posting Status of the record has been changed
            List<Transaction__c> transactions = DomainUtils.getTransactionsByApd(new List<AP_Disbursement__c>{testAPD});
            System.assertNotEquals(true, transactions.isEmpty());
            System.assertEquals(trans.Id, transactions[0].Id);
            Test.stopTest();
        }
    }

    public testMethod static void testSoftAPClosePost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {

            Cash_Disbursement__c cds = testData.cashDisbursements[0];
            cds.Debit_GL_Account__c = testData.glAccounts[0].Id;
            update cds;

            Accounting_Period__c actPeriod = [Select id, Close_AP__c from Accounting_Period__c WHERE Start_Date__c =: Date.newInstance(1991, 11, 1)];
            actPeriod.Close_AP__c = true;
            UPDATE actPeriod;

            Assert.isTrue(actPeriod.Close_AP__c);

            //create new APD record will be blocked becuase of soft closed period
            AP_Disbursement__c testAPD = new AP_Disbursement__c();
            testAPD.Accounting_Period__c = actPeriod.Id;
            testAPD.Account_Payable__c = testData.payables[0].Id;
            testAPD.Cash_Disbursement__c = cds.Id;
            testAPD.Paid_Amount__c = 10;
            
            DMLException dmlEx;
            
            try {
                insert testAPD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            Test.stopTest();
        }
    }
    public testMethod static void testPreventInsertWhenCDIsPostedWithSourcePayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(true)
            .createCashDisbursementBatches();
        Test.startTest();
        testData.createCashDisbursements();

        System.runAs(testData.users[1]) {

            testData.cashDisbursements[0].Accounting_Period__c = testData.acctPeriods[4].Id;
            update testData.cashDisbursements[0];

            AbstractPostHandler postHandler = new CashDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{testData.cashDisbursements[0]});
            System.assertEquals(true, postResults[0].isSuccess);

            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Cash_Disbursement__c
                    WHERE Id = :testData.cashDisbursements[0].Id
                ].Status__c
            );

            Accounting_Period__c actPeriod = [Select id, Close_AP__c from Accounting_Period__c WHERE Start_Date__c =: Date.newInstance(1991, 11, 1)];

            //create new APD record will be blocked becuase of soft closed period
            AP_Disbursement__c testAPD = new AP_Disbursement__c();
            testAPD.Accounting_Period__c = actPeriod.Id;
            testAPD.Account_Payable__c = testData.payables[0].Id;
            testAPD.Cash_Disbursement__c = testData.cashDisbursements[0].Id;
            testAPD.Paid_Amount__c = 10;
            
            DMLException dmlEx;
            
            try {
                insert testAPD;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            Assert.AreNotEqual(NULL, dmlEx);
            Assert.areEqual(true,dmlEx.getMessage().contains(Label.ERR_WHEN_PAYABLE_IS_APPLIED_TO_POSTED_CD));            
            Test.stopTest();
        }
    }
}