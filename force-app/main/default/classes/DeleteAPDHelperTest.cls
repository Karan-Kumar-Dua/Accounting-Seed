@IsTest
private class DeleteAPDHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testDeletePayablePaidAPDAndCDSuccess() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();
        System.runAs(testData.users[1]) {
            Id cdId = testData.cashDisbursements[0].Id;
            //Check total AP Disbursement Records
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());

            DeleteAPDHelper.startDeleteAPDJob(cdId);
            Test.stopTest();

            System.assertEquals(0, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :cdId].size());
            System.assertEquals(0, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());
        }
    }

    @IsTest
    private static void testDeletePayableVoidAPDSuccess() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements(true);
        MasterRecordMatchingRulesValidator.isVoidCashDisbursementContext = true;
        testData.createApDisbursements();

        System.runAs(testData.users[1]) {
            Id cdId = testData.cashDisbursements[0].Id;
            //Void the CD
            ApexPages.StandardController controller = new ApexPages.StandardController([
                SELECT
                    Id,
                    Status__c,
                    Disbursement_Date__c,
                    Payment_Status__c,
                    Accounting_Period__r.Status__c,
                    Type__c,
                    Bank_Account__c,
                    Amount__c,
                    Vendor__c
                FROM Cash_Disbursement__c
                WHERE Id = :cdId
            ]);

            CashDisbursementVoid cdv = new CashDisbursementVoid(controller);
            cdv.cashDisbursementVoid.Void_Description__c = 'Void Reason';
            cdv.cashDisbursementVoid.Disbursement_Date__c = cdv.cashDisbursement.Disbursement_Date__c;
            cdv.voidCashDisbursement();
            System.assertEquals(
                'Void',
                [SELECT Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :cdId].Payment_Status__c
            );

            //Check total AP Disbursement Records
            System.assertEquals(2, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());

            DeleteAPDHelper.startDeleteAPDJob(cdId);
            Test.stopTest();

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :cdId].size());
            System.assertEquals(0, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());
        }
    }

    @IsTest
    private static void testDeletePayableManualAPDSuccess() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();
        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Debit_GL_Account__c = testData.glAccounts[4].Id;
            testCD.Source__c = 'Manual';
            insert testCD;

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = 1
            );
            insert testApDisbursement;

            AbstractPostHandler postHandler = new APDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<AP_Disbursement__c>{testApDisbursement});

            //Check total AP Disbursement Records
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :testCD.Id].size());

            DeleteAPDHelper.startDeleteAPDJob(testCD.Id);
            Test.stopTest();

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :testCD.Id].size());
            System.assertEquals(0, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :testCD.Id].size());
        }
    }

    @IsTest
    private static void testDeletePayablePaidAPDAndCDClosedPeriodError() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();
        System.runAs(testData.users[1]) {
            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            Id cdId = testData.cashDisbursements[0].Id;
            //Check total AP Disbursement Records
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());

            try {
                DeleteAPDHelper.startDeleteAPDJob(cdId);
            }
            catch (AuraHandledException ex) {
                System.assert(ex.getMessage().contains(Label.ERR_CD_ASSOCIATED_IN_CLOSED_PERIOD));
            }

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :cdId].size());
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :cdId].size());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testDeletePayableManualAPDClosedPeriodError() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();
        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Debit_GL_Account__c = testData.glAccounts[4].Id;
            testCD.Source__c = 'Manual';
            insert testCD;

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = 1,
                Accounting_Period__c = testData.acctPeriods.get(1).Id
            );
            insert testApDisbursement;

            AbstractPostHandler postHandler = new APDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<AP_Disbursement__c>{testApDisbursement});

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            //Check total AP Disbursement Records
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :testCD.Id].size());

            try {
                DeleteAPDHelper.startDeleteAPDJob(testCD.Id);
            }
            catch (AuraHandledException ex) {
                System.assert(ex.getMessage().contains(Label.ERR_APD_CD_ASSOCIATED_IN_CLOSED_PERIOD));
            }

            Test.stopTest();

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :testCD.Id].size());
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :testCD.Id].size());
        }
    }

    @IsTest
    private static void testDeletePayableManualAPDError() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createApDisbursements();
        System.runAs(testData.users[1]) {
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
            testCD.Debit_GL_Account__c = testData.glAccounts[4].Id;
            testCD.Source__c = 'Manual';
            insert testCD;

            AP_Disbursement__c testApDisbursement = new AP_Disbursement__c(
                Account_Payable__c = testData.payables[0].Id,
                Cash_Disbursement__c = testCD.Id,
                Paid_Amount__c = 1
            );
            insert testApDisbursement;

            AbstractPostHandler postHandler = new APDisbursementPostHandler();
            List<PostResult> postResults = postHandler.post(new List<AP_Disbursement__c>{testApDisbursement});

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods.get(0).Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods.get(0);

            //Check total AP Disbursement Records
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :testCD.Id].size());

            try {
                DeleteAPDHelper.startDeleteAPDJob(testCD.Id);
            }
            catch (AuraHandledException ex) {
                System.assert(ex.getMessage().contains(Label.ERR_APD_CD_ASSOCIATED_IN_CLOSED_PERIOD));
            }

            Test.stopTest();

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Id = :testCD.Id].size());
            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :testCD.Id].size());
        }
    }
}