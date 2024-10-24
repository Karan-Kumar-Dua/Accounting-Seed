@IsTest
 with sharing class CashDisbursementApplyHelperTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static void createCurrentAccountingPeriod(TestDataSuite testData){
        testData.acctPeriods.add(new Accounting_Period__c(
            Name = '1992-05',
            Start_Date__c = Date.newInstance(1992, 5, 1),
            End_Date__c = Date.today(),
            Status__c = AccountingPeriodActions.OPEN_STATUS
        ));
        insert testData.acctPeriods[testData.acctPeriods.size()-1];
    }

//------------------------------Get Cash Disbursement Tests------------------------------------------//
    @IsTest
     static void testCashDisbursement() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            CashDisbursementApplyHelper.cashDisbursementWrapper wrapper = CashDisbursementApplyHelper.getCashDisbursement(testData.cashDisbursements[5].Id);
            
            system.assertNotEquals(Null, wrapper.cashDisbursement);
            system.assertEquals(testData.cashDisbursements[5].Amount__c, wrapper.cashDisbursement.Amount__c);
            system.assertEquals(MultiCurrencyHandler.isMultiCurrencyEnabled, wrapper.isMultiCurrencyEnabled);
            Test.stopTest();
        }
    }

    @IsTest
     static void testCashDisbursementFakeId() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        CashDisbursementApplyHelper.cashDisbursementWrapper wrapper;

        AuraHandledException expectedEx;

        System.runAs(testData.users[1]) {
            Test.startTest();
            try {
                wrapper = CashDisbursementApplyHelper.getCashDisbursement('abc123');
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }

        System.assertNotEquals(null, expectedEx);
    }
    
//------------------------------Filtering Tests-------------------------------------------------//

    @IsTest
     static void testGetApplicablePayablesSoftClose() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            

            testData.acctPeriods[1].Close_AP__c = TRUE;
            testData.acctPeriods[testData.acctPeriods.size()-1].Close_AP__c = TRUE;
            Update testData.acctPeriods;

            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                Assert.areEqual(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;
            
            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'All',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            Assert.areEqual(3, payables.size());
            Test.stopTest();
        }
    }

    @IsTest
     static void testGetApplicablePayables() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            
            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;
            
            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'All',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(3, payables.size());
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetApplicablePayablesWithoutCurrentPeriod() {
       TestDataSuite testData = TestDataSuite.getInstance()
           .createPayables()
           .createCashDisbursementBatches()
           .createCashDisbursements();
     
       System.runAs(testData.users[1]) {
           Test.startTest();
           
           testData.payables[0].Status__c = 'Approved';
           testData.payables[1].Status__c = 'Approved';
           update testData.payables;

           for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
               System.assertEquals(true, result.isSuccess);
           }

           Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

           Integer maxResults = 10;
           
           List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
               testCD.Id,
               maxResults,
               testCD.Payee_Id__c,
               'All',
               NULL,
               NULL,
               NULL,
               NULL,
               NULL,
               NULL,
               NULL,
               NULL,
               false
           );
           system.assertEquals(3, payables.size());
           Test.stopTest();
       }
   }

    @IsTest
     static void testGetApplicablePayablesLimitResults() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            
            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 1;            

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'All',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());
            Test.stopTest();
        }
    }

    @IsTest
     static void testGetApplicablePayablesExistingAPDs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
        Test.startTest();
            testData.cashDisbursements[5].Amount__c = 150.00;
            update testData.cashDisbursements;

            testData.payables[0].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            
            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Paid_Amount__c = 100.00;            
            insert apd;

            Integer maxResults = 10;

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'All',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(3, payables.size());
            system.assertEquals(100.00, payables[0].appliedAmount);
            system.assertEquals(testData.acctPeriods[1].Start_Date__c, payables[0].appliedDate);
            Test.stopTest();

        }
    }

    
    @IsTest
     static void testGetApplicablePayablesOnlyPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            Integer maxResults = 10;

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());
            system.assertEquals(testData.payables[0].Id, payables[0].payableId);            
            Test.stopTest();
        }
    }

    @IsTest
     static void testGetApplicablePayablesOnlyApproved() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            for (integer i = 2; i < testData.payables.size(); i++) {
                testData.payables[i].Status__c = 'In Process';
            }
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Approved',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());
            system.assertEquals(testData.payables[0].Id, payables[0].payableId);
            Test.stopTest();
        }
    }

    //------------------------------Filter Ranges-----------------------------------------------//
    @IsTest
     static void testGetApplicablePayablesPayableNumber() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            testData.payables[0].Proprietary_Payable_Number__c = 'Test Payable 0 Filter';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'All',
                'Filter',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());
            system.assertEquals(testData.payables[0].Id, payables[0].payableId);
            Test.stopTest();
        }
    }

    @IsTest
     static void testGetApplicablePayablesPayeeReference() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[1].Status__c = 'Approved';
            testData.payables[0].Payee_Reference__c = 'Test Payee Reference';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'All',
                NULL,
                'Reference',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());
            system.assertEquals(testData.payables[0].Id, payables[0].payableId);
            Test.stopTest();
        }
    }

    @IsTest
     static void testGetApplicablePayablesIssueDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[5].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[5]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                testData.acctPeriods[0].Start_Date__c,
                testData.acctPeriods[0].End_Date__c,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                testData.acctPeriods[1].Start_Date__c,
                testData.acctPeriods[1].End_Date__c,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                testData.acctPeriods[1].End_Date__c,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(2, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                testData.acctPeriods[0].Start_Date__c,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(2, payables.size());
            Test.stopTest();
        }
    }

    @IsTest
     static void testGetApplicablePayablesDueDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[5].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[5]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                testData.acctPeriods[0].Start_Date__c,
                testData.acctPeriods[0].End_Date__c,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                testData.acctPeriods[1].Start_Date__c,
                testData.acctPeriods[1].End_Date__c,
                NULL,
                NULL,
                false
            );
            system.assertEquals(1, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                testData.acctPeriods[2].Start_Date__c,
                testData.acctPeriods[2].End_Date__c,
                NULL,
                NULL,
                false
            );
            system.assertEquals(0, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                testData.acctPeriods[1].End_Date__c,
                NULL,
                NULL,
                false
            );
            system.assertEquals(2, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                testData.acctPeriods[0].Start_Date__c,
                NULL,
                NULL,
                NULL,
                false
            );
            system.assertEquals(2, payables.size());
            Test.stopTest();
        }
    }

    @IsTest
     static void testGetApplicablePayablePayableAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[5].Status__c = 'Approved';
            update testData.payables;

            //set the payable amounts to 2000 and 4000 respectively
            testData.payableLines[0].Amount__c = 750;
            testData.payableLines[1].Amount__c = 250;
            testData.payableLines[2].Amount__c = 1000;            
            testData.payableLines[12].Amount__c = 4000;
            update testData.payableLines;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[5]})) {
                System.assertEquals(true, result.isSuccess);
            }

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];

            Integer maxResults = 10;

            List<CashDisbursementApplyHelper.PayableWrapper> payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                2000.00,
                4000.00,
                false
            );
            system.assertEquals(2, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                5000.00,
                6000.00,
                false
            );
            system.assertEquals(0, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                4000.00,
                false
            );
            system.assertEquals(2, payables.size());

            payables = CashDisbursementApplyHelper.getApplicablePayables(
                testCD.Id,
                maxResults,
                testCD.Payee_Id__c,
                'Posted',
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
                2000.00,
                NULL,
                false
            );
            system.assertEquals(2, payables.size());
            Test.stopTest();
        }
    }

//------------------------------Save Tests--------------------------------//

    @IsTest
     static void testSave() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[0].Discount_Amount__c = 0;
            update testData.payables;

            //set the payable amount to 400
            testData.payableLines[0].Amount__c = 50;
            testData.payableLines[1].Amount__c = 100;
            testData.payableLines[2].Amount__c = 250;                        
            update testData.payableLines;

            testData.cashDisbursements[5].Amount__c = 400.00;
            update testData.cashDisbursements[5];

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());
            system.assertEquals(testData.cashDisbursements[5].Id, response.cashDisbursement.Id);
            Test.stopTest();

            List<AP_Disbursement__c> disbursements = [SELECT Id, Paid_Amount__c, Applied_Date__c, Account_Payable__c FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :response.cashDisbursement.Id];
            List<Account_Payable__c> payable = [SELECT Id, Paid_Amount__c, Balance_Minus_Discount__c FROM Account_Payable__c WHERE Id = :disbursements[0].Account_Payable__c];
            system.assertEquals(1, disbursements.size());
            system.assertEquals(100.00, disbursements[0].Paid_Amount__c);
            system.assertEquals(testData.acctPeriods[1].Start_Date__c, disbursements[0].Applied_Date__c);
            
            system.assertEquals(100.00, payable[0].Paid_Amount__c);
            system.assertEquals(300.00, payable[0].Balance_Minus_Discount__c);

            system.assertEquals(300.00, response.cashDisbursement.Balance__c);
            system.assertEquals(100.00, response.cashDisbursement.Applied_Amount__c);
        }
    }

    @IsTest
     static void testSaveCashDisbursementModified() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate.addDays(2), items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals('cash_disbursement_modified', response.errors[0]);
            Test.stopTest();
        }
    }

    @IsTest
     static void testSaveBadAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }
            
            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = system.today().addYears(20);
            item.appliedAmount = 10;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(CashDisbursement.MISSING_ACCOUNTING_PERIOD, response.errors[0]);
            Test.stopTest();            
        }
    }

    @IsTest
     static void testSaveMissingAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            
            item.appliedAmount = 10;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(true, response.errors[0].contains(CashDisbursement.MISSING_ACCOUNTING_PERIOD));
            Test.stopTest();            
        }
    }

    @IsTest
     static void testSaveTooEarlyAppliedDatePayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[0].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[0].Start_Date__c;
            item.appliedAmount = 10;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[6].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[6].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(CashDisbursement.ACCOUNTING_PERIOD_BEFORE_PAYABLE_ACCOUNTING_PERIOD, response.errors[0]);
            Test.stopTest();            
        }
    }

    @IsTest
     static void testSaveTooEarlyAppliedDateCashDisbursement() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';            
            update testData.payables[0];

            testData.cashDisbursements[5].Accounting_Period__c = testData.acctPeriods[1].Id;
            update testData.cashDisbursements[5];

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[0].Start_Date__c;
            item.appliedAmount = 10;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(CashDisbursement.ACCOUNTING_PERIOD_BEFORE_CASH_DISBURSEMENT_ACCOUNTING_PERIOD, response.errors[0]);
            Test.stopTest();            
        }
    }

    @IsTest
     static void testSaveBadAppliedAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = -100;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(CashDisbursement.APPLIED_AMOUNT_LESS_THAN_ZERO, response.errors[0]);
            Test.stopTest();            
        }
    }

    @IsTest
     static void testSaveUpdateExistingAPDAppliedAmount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[0].Discount_Amount__c = 0;
            update testData.payables;

            //set the payable amount to 400
            testData.payableLines[0].Amount__c = 50;
            testData.payableLines[1].Amount__c = 100;
            testData.payableLines[2].Amount__c = 250;                        
            update testData.payableLines;

            testData.cashDisbursements[5].Amount__c = 400.00;
            update testData.cashDisbursements[5];

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Paid_Amount__c = 150.00;
            insert apd;

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 100;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());
            
            Test.stopTest();        
            List<AP_Disbursement__c> disbursements = [SELECT Id, Paid_Amount__c, Applied_Date__c, Account_Payable__c FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :response.cashDisbursement.Id];
            List<Account_Payable__c> payable = [SELECT Id, Paid_Amount__c, Balance_Minus_Discount__c FROM Account_Payable__c WHERE Id = :disbursements[0].Account_Payable__c];
            system.assertEquals(1, disbursements.size());
            system.assertEquals(100.00, disbursements[0].Paid_Amount__c);
            system.assertEquals(testData.acctPeriods[1].Start_Date__c, disbursements[0].Applied_Date__c);
                        
            system.assertEquals(100.00, payable[0].Paid_Amount__c);
            system.assertEquals(300.00, payable[0].Balance_Minus_Discount__c);

            system.assertEquals(300.00, response.cashDisbursement.Balance__c);
            system.assertEquals(100.00, response.cashDisbursement.Applied_Amount__c);
        }
    }

    @IsTest
     static void testSaveTooMuchApplied() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[0].Discount_Amount__c = 0;
            update testData.payables;

            //set the payable amount to 400
            testData.payableLines[0].Amount__c = 50;
            testData.payableLines[1].Amount__c = 100;
            testData.payableLines[2].Amount__c = 250;                        
            update testData.payableLines;

            testData.cashDisbursements[5].Amount__c = 400.00;
            update testData.cashDisbursements[5];

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Paid_Amount__c = 150.00;
            insert apd;

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[1].Start_Date__c;
            item.appliedAmount = 500;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(false, response.isSuccess);
            system.assertEquals(1, response.errors.size());
            system.assertEquals(true, response.errors[0].contains(CashDisbursement.CASH_DISBURSEMENT_BALANCE_LESS_THAN_ZERO));
            system.assertEquals(true, response.errors[0].contains(CashDisbursement.PAYABLE_BALANCE_LESS_THAN_ZERO));            
            Test.stopTest();                    
        }
    }

    @IsTest
     static void testSaveChangeAppliedDate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.payables[0].Status__c = 'Approved';
            testData.payables[0].Discount_Amount__c = 0;
            update testData.payables;

            //set the payable amount to 400
            testData.payableLines[0].Amount__c = 50;
            testData.payableLines[1].Amount__c = 100;
            testData.payableLines[2].Amount__c = 250;                        
            update testData.payableLines;

            testData.cashDisbursements[5].Amount__c = 400.00;
            update testData.cashDisbursements[5];

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }

            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Cash_Disbursement__c = testData.cashDisbursements[5].Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Paid_Amount__c = 150.00;
            insert apd;

            List<String> items = new List<String>();
            CashDisbursementApplyHelper.SaveItem item = new CashDisbursementApplyHelper.SaveItem();
            item.payableId = testData.payables[0].Id;
            item.payableNumber = testData.payables[0].Name;
            item.appliedDate = testData.acctPeriods[2].Start_Date__c;
            item.appliedAmount = 150;
            items.add(JSON.serialize(item));

            Cash_Disbursement__c disbursement = [SELECT Id, LastModifiedDate FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[5].Id LIMIT 1];
            
            CashDisbursementApplyHelper.SaveResponse response = CashDisbursementApplyHelper.save(testData.cashDisbursements[5].Id, disbursement.LastModifiedDate, items);
            system.assertEquals(true, response.isSuccess);
            system.assertEquals(0, response.errors.size());            
            
            Test.stopTest();        
            List<AP_Disbursement__c> disbursements = [SELECT Id, Applied_Date__c, Accounting_Period__c FROM AP_Disbursement__c WHERE Cash_Disbursement__c = :response.cashDisbursement.Id];
            
            system.assertEquals(1, disbursements.size());
            system.assertEquals(testData.acctPeriods[2].Start_Date__c, disbursements[0].Applied_Date__c);
            system.assertEquals(testData.acctPeriods[2].Id, disbursements[0].Accounting_Period__c);            
        }
    }
}