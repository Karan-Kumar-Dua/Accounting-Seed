@IsTest
private class PayableTest {

    @TestSetup
    static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testCreatePayableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Model
            PayableModel model = new PayableModel();
            //Create Payable
            Account_Payable__c testPayable = new Account_Payable__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payee_Reference__c =  '123123'               
            );
            model.payable = testPayable;
            //Create Payable Lines
            List<Account_Payable_Line__c> payableLines = new List<Account_Payable_Line__c>();
            Account_Payable_Line__c testPayableLine1 = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Unit_Cost__c = 1,
                Quantity__c = 100,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            );
            payableLines.add(testPayableLine1);

            Account_Payable_Line__c testPayableLine2 = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Unit_Cost__c = 2,
                Quantity__c = 50,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            );
            payableLines.add(testPayableLine2);
            model.payableLines = payableLines;

            Test.startTest();
            ServiceResult sr = Payable.create(model);
            List<Account_Payable__c> payables = [
                SELECT Id, (SELECT Id FROM Project_Account_Payable_Lines__r) FROM Account_Payable__c
            ];
            System.assertEquals(true, sr.isSuccess);
            System.assertNotEquals(true, payables.isEmpty());
            System.assertEquals(2, sr.results.size());
            System.assertEquals(payables[0].Project_Account_Payable_Lines__r[0].Id, sr.results[0].data);
            System.assertEquals(true, sr.results[0].isSuccess);
            System.assertEquals(payables[0].Project_Account_Payable_Lines__r[1].Id, sr.results[1].data);
            System.assertEquals(true, sr.results[1].isSuccess);
        }
    }

    @IsTest
    static void testCreatePayablesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Models
            List<PayableModel> models = new List<PayableModel>();
            PayableModel model1 = new PayableModel();
            PayableModel model2 = new PayableModel();
            //Create Payables
            Account_Payable__c testPayable1 = new Account_Payable__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payee_Reference__c =  '123123'               
            );            
            model1.payable = testPayable1;
            Account_Payable__c testPayable2 = new Account_Payable__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Due_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payee_Reference__c =  '123124'               
            );
            model2.payable = testPayable2;
            //Create Payable Lines
            List<Account_Payable_Line__c> payableLines1 = new List<Account_Payable_Line__c>();
            List<Account_Payable_Line__c> payableLines2 = new List<Account_Payable_Line__c>();
            Account_Payable_Line__c testPayableLine11 = new Account_Payable_Line__c(
                Account_Payable__c = testPayable1.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Unit_Cost__c = 2,
                Quantity__c = 50,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            );
            payableLines1.add(testPayableLine11);

            Account_Payable_Line__c testPayableLine12 = new Account_Payable_Line__c(
                Account_Payable__c = testPayable1.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Unit_Cost__c = 1,
                Quantity__c = 100,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            );
            payableLines1.add(testPayableLine12);
            model1.payableLines = payableLines1;

            Account_Payable_Line__c testPayableLine21 = new Account_Payable_Line__c(
                Account_Payable__c = testPayable2.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Unit_Cost__c = 2,
                Quantity__c = 50,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            );
            payableLines2.add(testPayableLine21);

            Account_Payable_Line__c testPayableLine22 = new Account_Payable_Line__c(
                Account_Payable__c = testPayable2.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Unit_Cost__c = 1,
                Quantity__c = 100,
                Expense_GL_Account__c = testData.glAccounts[10].Id
            );
            payableLines2.add(testPayableLine22);
            model2.payableLines = payableLines2;
            
            models.add(model1);
            models.add(model2);

            Test.startTest();
            ServiceResult sr = Payable.create(models);
            List<Account_Payable__c> payables = [
                SELECT Id, (SELECT Id FROM Project_Account_Payable_Lines__r) FROM Account_Payable__c
            ];
            System.assertEquals(true, sr.isSuccess);
            System.assertNotEquals(true, payables.isEmpty());
            System.assertEquals(2, sr.results.size());
            System.assertEquals(2, sr.results[0].results.size());
            System.assertEquals(2, sr.results[1].results.size());
            System.assertEquals(payables[0].Project_Account_Payable_Lines__r[0].Id, sr.results[0].results[0].data);
            System.assertEquals(true, sr.results[0].isSuccess);
            System.assertEquals(true, sr.results[0].results[0].isSuccess);
            System.assertEquals(true, sr.results[0].results[1].isSuccess);
            System.assertEquals(payables[0].Project_Account_Payable_Lines__r[1].Id, sr.results[0].results[1].data);
            System.assertEquals(payables[1].Project_Account_Payable_Lines__r[0].Id, sr.results[1].results[0].data);
            System.assertEquals(true, sr.results[0].isSuccess);
            System.assertEquals(true, sr.results[0].results[0].isSuccess);
            System.assertEquals(true, sr.results[0].results[1].isSuccess);
            System.assertEquals(payables[1].Project_Account_Payable_Lines__r[1].Id, sr.results[1].results[1].data);
        }
    }

    @IsTest
    static void testCreatePayableNoDataProvided() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Model
            PayableModel model = new PayableModel();
            Test.startTest();
            ServiceResult sr = Payable.create(model);
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(Payable.INVALID_RECORD_OR_ID, sr.errors.get(0).detail);
        }
    }

    @IsTest
    static void testCreatePayableNoModelProvided() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            //Create Model
            PayableModel model;
            Test.startTest();
            ServiceResult sr = Payable.create(model);
            System.assertEquals(false, sr.isSuccess);
            System.assertEquals(Payable.NO_INPUT_DATA, sr.errors.get(0).detail);
        }
    }

    @IsTest
    static void testPostPayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(1)) {
            Map<Id, Account_Payable__c> payables = new Map<Id, Account_Payable__c>([
                SELECT Id
                FROM Account_Payable__c
            ]);
            Test.startTest();
            List<ServiceResult> postResults = Payable.post(new List<Id>(payables.keySet()));
            System.assertEquals(true, postResults.get(0).isSuccess);
            for (Account_Payable__c payable : [SELECT Id, Status__c FROM Account_Payable__c]) {
                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, payable.Status__c);
            }
        }
    }

    @IsTest
    static void testPostPayablesAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users.get(1)) {
            Map<Id, Account_Payable__c> payables = new Map<Id, Account_Payable__c>([
                SELECT Id
                FROM Account_Payable__c
            ]);
            Test.startTest();
            List<ServiceResult> postResults = Payable.post(new List<Id>(payables.keySet()));
            System.assertEquals(false, postResults.get(0).isSuccess);            
        }
    }

    @IsTest
    static void testPostPayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult postResult = Payable.post(testData.payables.get(0).Id);
            System.assertEquals(true, postResult.isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [
                    SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id
                ].Status__c
            );
        }
    }

    @IsTest
    static void testPostPayableAlreadyPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult postResult2 = Payable.post(testData.payables.get(0).Id);
            System.assertEquals(false, postResult2.isSuccess);
        }
    }

    @IsTest
    static void testUnPostPayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users.get(1)) {
            Map<Id, Account_Payable__c> payables = new Map<Id, Account_Payable__c>([
                SELECT Id
                FROM Account_Payable__c
            ]);
            Test.startTest();
            List<ServiceResult> postResults = Payable.unpost(new List<Id>(payables.keySet()));
            System.assertEquals(true, postResults.get(0).isSuccess);
            for (Account_Payable__c payable : [SELECT Id, Status__c FROM Account_Payable__c]) {
                System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, payable.Status__c);
            }
        }        
    }

    @IsTest
    static void testUnPostPayablesNotPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(1)) {
            Map<Id, Account_Payable__c> payables = new Map<Id, Account_Payable__c>([
                SELECT Id
                FROM Account_Payable__c
            ]);
            Test.startTest();
            List<ServiceResult> postResults = Payable.unpost(new List<Id>(payables.keySet()));
            System.assertEquals(false, postResults.get(0).isSuccess);            
        }        
    }

    @IsTest
    static void testUnPostPayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult postResult = Payable.unpost(testData.payables.get(0).Id);
            System.assertEquals(true, postResult.isSuccess);
            System.assertEquals(
                AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED, [
                    SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id
                ].Status__c
            );
        }
    }

    @IsTest
    static void testUpPostPayableNotPostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ServiceResult postResult = Payable.unpost(testData.payables.get(0).Id);
            System.assertEquals(false, postResult.isSuccess);            
        }
    }

    @IsTest
    static void testRetrievePayable() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true);
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            PayableModel payableModel = Payable.retrieve(testData.payables.get(0).Id);

            Account_Payable__c existedPayable = [SELECT Id FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id];
            List<Account_Payable_Line__c> existedPayableLines = [SELECT Id, Account_Payable__c FROM Account_Payable_Line__c WHERE Account_Payable__c = :testData.payables.get(0).Id];

            System.assertEquals(existedPayable.Id, payableModel.payable.Id);
            System.assertEquals(existedPayableLines, payableModel.payableLines);
        }
    }

    @IsTest
    static void testRetrievePayableWrongId() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(true);
        Test.startTest();
        testData.createPayables(false);

        System.runAs(testData.users.get(1)) {
            PayableModel payableModel = Payable.retrieve(Id.valueOf('333xa000003DIlo'));

            System.assertEquals(NULL, payableModel.payable);
            System.assertEquals(NULL, payableModel.payableLines);

            payableModel = Payable.retrieve(testData.billings.get(0).Id);

            System.assertEquals(NULL, payableModel.payable);
            System.assertEquals(NULL, payableModel.payableLines);
        }
        Test.stopTest();
    }

    //------------------------------Filtering Tests-------------------------------------------------//
    @IsTest
    static void testRetrieveFiltered() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];
            
            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'All';
            
            List<String> fields = new List<String>{
                'Id', 
                'Name', 
                'Type__c', 
                'Status__c'
            };

            List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            system.assertEquals(4, payableModels.size());
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveFilteredMaxRows() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];
            
            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'All';          
            
            List<String> fields = new List<String>{
                'Id', 
                'Name', 
                'Type__c', 
                'Status__c'
            };
            
            List<PayableModel> payableModels = Payable.retrieve(filter, fields, 1);
            system.assertEquals(1, payableModels.size());
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveFilteredExistingAPDs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
        Test.startTest();
            testData.cashDisbursements[0].Amount__c = 150.00;
            update testData.cashDisbursements;

            testData.payables[0].Status__c = 'Approved';
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0], testData.payables[1]})) {
                System.assertEquals(true, result.isSuccess);
            }
            
            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Cash_Disbursement__c = testData.cashDisbursements[0].Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Paid_Amount__c = 100.00;            
            insert apd;

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'All';            

            List<String> fields = new List<String>{
                'Id', 
                'Name', 
                'Paid_Amount__c'
            };

            List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            system.assertEquals(4, payableModels.size());
            system.assertEquals(100.00, payableModels[0].payable.Paid_Amount__c);            
            Test.stopTest();

        }
    }

    @IsTest
    static void testRetrieveFilteredPaidPayables() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        createCurrentAccountingPeriod(testData);
        System.runAs(testData.users[1]) {
            Test.startTest();
            Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false,true);
            testCD.Amount__c = 145.00;
            insert testCD;

            testData.payables[0].Status__c = 'Approved';    
            update testData.payables;

            for (PostResult result : AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables[0]})) {
                System.assertEquals(true, result.isSuccess);
            }
            
            AP_Disbursement__c apd = new AP_Disbursement__c();
            apd.Cash_Disbursement__c = testCD.Id;
            apd.Account_Payable__c = testData.payables[0].Id;
            apd.Accounting_Period__c = testData.acctPeriods[1].Id;
            apd.Paid_Amount__c = 145.00;            
            insert apd;
            
            testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];
            
            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.includePaidPayables = true;

            List<String> fields = new List<String>{
                'Id', 
                'Name', 
                'Status__c'
            };
            
            List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            system.assertEquals(1, payableModels.size());
            system.assertEquals(testData.payables[0].Id, payableModels[0].payable.Id);            
            Test.stopTest();
        }
    }

    
    @IsTest
    static void testRetrieveFilteredOnlyPosted() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];
            
            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';

            List<String> fields = new List<String>{
                'Id', 
                'Name', 
                'Status__c'
            };
            
            List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            system.assertEquals(1, payableModels.size());
            system.assertEquals(testData.payables[0].Id, payableModels[0].payable.Id);            
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveFilteredOnlyApproved() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];
            
            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Approved';

            List<String> fields = new List<String>{
                'Id', 
                'Name', 
                'Status__c'
            };
            
            List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            system.assertEquals(1, payableModels.size());
            system.assertEquals(testData.payables[0].Id, payableModels[0].payable.Id);
            Test.stopTest();
        }
    }

    //------------------------------Filter Ranges-----------------------------------------------//
    @IsTest
    static void testRetrieveFilteredPayableNumber() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'All';
            filter.PayableNumber = 'Filter';            

            List<String> fields = new List<String>{
                'Id', 
                'Name', 
                'Status__c'
            };

            List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            system.assertEquals(1, payableModels.size());
            system.assertEquals(testData.payables[0].Id, payableModels[0].payable.Id);
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveFiltertePayeeReference() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'All';
            filter.PayeeReference = 'Reference';
            
            List<PayableModel> payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(1, payableModels.size());
            system.assertEquals(testData.payables[0].Id, payableModels[0].payable.Id);
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveFilteredIssueDate() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.issueDateStart = testData.acctPeriods[0].Start_Date__c;
            filter.issueDateEnd = testData.acctPeriods[0].End_Date__c;
            
            List<PayableModel> payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(1, payableModels.size());
            
            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.issueDateStart = testData.acctPeriods[1].Start_Date__c;
            filter.issueDateEnd = testData.acctPeriods[1].End_Date__c;

            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(1, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.issueDateEnd = testData.acctPeriods[1].End_Date__c;
            
            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(2, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.issueDateStart = testData.acctPeriods[0].Start_Date__c;
            
            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(2, payableModels.size());
            Test.stopTest();
        }
    }

    @IsTest
    static void testRetrieveFilteredDueDate() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.dueDateStart = testData.acctPeriods[0].Start_Date__c;
            filter.dueDateEnd = testData.acctPeriods[0].End_Date__c;
            
            List<PayableModel> payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(1, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.dueDateStart = testData.acctPeriods[1].Start_Date__c;
            filter.dueDateEnd = testData.acctPeriods[1].End_Date__c;
            
            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(1, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.dueDateStart = testData.acctPeriods[2].Start_Date__c;
            filter.dueDateEnd = testData.acctPeriods[2].End_Date__c;
            
            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(0, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.dueDateEnd = testData.acctPeriods[1].End_Date__c;
            
            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(2, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.dueDateStart = testData.acctPeriods[0].Start_Date__c;
            
            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(2, payableModels.size());
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetRetrieveFilteredPayableAmount() {
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

            Cash_Disbursement__c testCD = [SELECT Id, Payee_Id__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id LIMIT 1];

            PayableFilter filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.payableAmountStart = 2000.00;
            filter.payableAmountEnd = 4000.00;

            List<PayableModel> payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(2, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.payableAmountStart = 5000.00;
            filter.payableAmountEnd = 6000.00;

            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(0, payableModels.size());

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.payableAmountEnd = 4000.00;

            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(2, payableModels.size());            

            filter = new PayableFilter();
            filter.cashDisbursementId = testCD.Id;
            filter.payeeId = testCD.Payee_Id__c;
            filter.postingStatus = 'Posted';
            filter.payableAmountStart = 2000.00;
            
            payableModels = Payable.retrieve(filter, NULL);
            system.assertEquals(2, payableModels.size());            
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetRetrieveFilteredBadField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();            
        System.runAs(testData.users[1]) {
            Test.startTest();
        
            PayableFilter filter = new PayableFilter();
            filter.postingStatus = 'All';

            List<String> fields = new List<String>{
                'Bank_Id__c'
            };
            
            Payable.PayableException expectedEx;
            try {
                List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            } catch (Payable.PayableException ex) {
                expectedEx = ex;
            }
            system.assertNotEquals(NULL, expectedEx);
        }    
    }

    @IsTest
    static void testGetRetrieveFilteredNullField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();            
        System.runAs(testData.users[1]) {
            Test.startTest();
        
            PayableFilter filter = new PayableFilter();
            filter.postingStatus = 'All';

            List<String> fields = new List<String>{
                ''
            };
            
            Payable.PayableException expectedEx;
            try {
                List<PayableModel> payableModels = Payable.retrieve(filter, fields);
            } catch (Payable.PayableException ex) {
                expectedEx = ex;
            }
            system.assertNotEquals(NULL, expectedEx);
            system.assertEquals(true, expectedEx.getMessage().contains(Payable.INVALID_QUERY_FIELD));
        }    
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
}