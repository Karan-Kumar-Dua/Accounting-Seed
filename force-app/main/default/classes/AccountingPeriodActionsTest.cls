@IsTest
private class AccountingPeriodActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testChangeStatusFormArchiveInProgressToOpen() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = 'Archive In Progress';
            AccountingPeriodActions.isPreventUpdateOverride = true;
            update testAccountingPeriod;
            AccountingPeriodActions.isPreventUpdateOverride = false;

            DmlException dmlEx;

            try {
                testAccountingPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.STATUS_CHANGED_FROM_ARCHIVE_IN_PROGRESS_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testChangeStatusFormArchiveInProgressToClosed() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = 'Archive In Progress';
            AccountingPeriodActions.isPreventUpdateOverride = true;
            update testAccountingPeriod;
            AccountingPeriodActions.isPreventUpdateOverride = false;

            DmlException dmlEx;

            try {
                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.STATUS_CHANGED_FROM_ARCHIVE_IN_PROGRESS_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testCheckAllPeriodsHaveSameStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testAccountingPeriod;
            AccountingPeriodActions.isFirstRun = true;

            DmlException dmlEx;

            try {
                update testData.acctPeriods;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.OPEN_AND_CLOSE_IN_ONE_STEP_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testCloseAllExceptLastOne() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Accounting_Period__c> initialAccountingPeriods = testData.acctPeriods;

            Test.startTest();
            for (Accounting_Period__c period : initialAccountingPeriods) {
                period.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }

            List<Database.SaveResult> results = Database.update(initialAccountingPeriods, false);
            Test.stopTest();

            String errorMessage = String.format(Label.ERR_ACCOUNTING_PERIOD_NEXT_PERIOD_DOES_NOT_EXISTS, new List<Object>{AccountingPeriodHandler.getInstance().getNextAccountingPeriod(initialAccountingPeriods.get(6)).Name, testData.acctPeriods.get(6).Name});

            Database.SaveResult badResult;

            for (Database.SaveResult result : results) {
                if (!result.isSuccess()) {
                    badResult = result;
                }
            }

            System.assertNotEquals(null, badResult);
            System.assertEquals(errorMessage, badResult.getErrors().get(0).getMessage());

            Map<Id, Accounting_Period__c> initialAccountingPeriodsMap = new Map<Id, Accounting_Period__c>(initialAccountingPeriods);

            Map<Id, Accounting_Period__c> validatedAccountingPeriodsMap = new Map<Id, Accounting_Period__c>([
                SELECT Id, Status__c FROM Accounting_Period__c WHERE Id IN :initialAccountingPeriodsMap.keySet()
            ]);

            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                validatedAccountingPeriodsMap.get(testData.acctPeriods.get(0).Id).Status__c
            );
            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                validatedAccountingPeriodsMap.get(testData.acctPeriods.get(1).Id).Status__c
            );
            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                validatedAccountingPeriodsMap.get(testData.acctPeriods.get(2).Id).Status__c
            );
            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                validatedAccountingPeriodsMap.get(testData.acctPeriods.get(3).Id).Status__c
            );
            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                validatedAccountingPeriodsMap.get(testData.acctPeriods.get(4).Id).Status__c
            );
            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                validatedAccountingPeriodsMap.get(testData.acctPeriods.get(5).Id).Status__c
            );
            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                validatedAccountingPeriodsMap.get(testData.acctPeriods.get(6).Id).Status__c
            );
        }

    }
    
    @IsTest
    private static void testAddPeriodStartDateInRange() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = Date.newInstance(1991, 10, 8);
            testAccountingPeriod.End_Date__c = Date.newInstance(1991, 10, 31);

            DmlException dmlEx;

            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.DATE_RANGE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testAddPeriodEndDateInRange() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c period = new Accounting_Period__c();
            period.Name = '1995-03';
            period.Start_Date__c = Date.newInstance(1995, 3, 1);
            period.End_Date__c = Date.newInstance(1995, 3, 31);
            insert period;

            Accounting_Period__c newPeriod = new Accounting_Period__c();
            newPeriod.Name = '1995-02';
            newPeriod.Start_Date__c = Date.newInstance(1995, 3, 1);
            newPeriod.End_Date__c = Date.newInstance(1995, 3, 31);

            DmlException dmlEx;

            try {
                AccountingPeriodHandler.reset();
                insert newPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.DATE_RANGE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testBothStartAndEndDateInRange() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
            testAccountingPeriod.Start_Date__c = Date.newInstance(1991, 11, 31);
            testAccountingPeriod.End_Date__c = Date.newInstance(1991, 12, 28);

            DmlException dmlEx;

            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.DATE_RANGE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testPreventBulkUpdateAccountingPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            //We can not bulk update more than 12 accounting periods
            //5 are already existed
            //need to create another 8
            Id lastExistedPeriodId = testData.acctPeriods.get(6).Id;
            List<Accounting_Period__c> newPeriods = new List<Accounting_Period__c>();
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            for (Integer i = 1; i <= 8; i++) {
                Accounting_Period__c newPeriod = acctPeriodHandler.getFakePeriodFromOffset(lastExistedPeriodId, i);
                newPeriods.add(newPeriod);
            }
            insert newPeriods;

            AccountingPeriodHandler.reset();
            List<Accounting_Period__c> allExistedAcctPeriods = AccountingPeriodHandler.getInstance().getAllAccountingPeriods();
            System.assertEquals(15, allExistedAcctPeriods.size());

            try {
                update allExistedAcctPeriods;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.BULK_UPDATE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testPreventStatusClosedIfPastOpenPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;

            try {
                Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.PAST_OPEN_ACCOUNTING_PERIOD_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testPreventStatusOpenIfFutureClosedPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;

            try {
                AccountingPeriodActions.isFirstRun = false;
                Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
                testAccountingPeriod1.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod1;

                Test.startTest();
                Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);
                testAccountingPeriod2.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                update testAccountingPeriod2;
                Test.stopTest();

                AccountingPeriodActions.isFirstRun = true;
                testAccountingPeriod1.Status__c = AccountingPeriodActions.OPEN_STATUS;
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                update testAccountingPeriod1;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.BEFORE_CLOSED_OR_ARCHIVED_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testNameFormatInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // Test insert new accounting period and generate error
            Accounting_Period__c period = new Accounting_Period__c();
            period.Name = '1970-906';
            period.Start_Date__c = Date.newInstance(1970,1,1);
            period.End_Date__c = Date.newInstance(1970,1,31);
            DmlException dmlEx;
            try {
                insert period;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.NAME_FORMAT_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testNameFormatUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // Test update existing accounting period and generate error
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Name = '0970-12';

            DmlException dmlEx;
            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.NAME_FORMAT_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testNameDuplicationInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // Test insert new accounting period and generate error
            Accounting_Period__c periodInDB = new Accounting_Period__c();
            periodInDB.Name = '1970-10';
            periodInDB.Start_Date__c = Date.newInstance(1970, 10, 1);
            periodInDB.End_Date__c = Date.newInstance(1970, 10, 30);

            insert periodInDB;

            Test.startTest();

            List<Accounting_Period__c> periodsForSave = new List<Accounting_Period__c>();

            Accounting_Period__c newPeriod_1 = new Accounting_Period__c();
            newPeriod_1.Name = '1970-09';
            newPeriod_1.Start_Date__c = Date.newInstance(1970, 07, 1);
            newPeriod_1.End_Date__c = Date.newInstance(1970, 07, 30);
            periodsForSave.add(newPeriod_1);

            Accounting_Period__c newPeriod_2 = new Accounting_Period__c();
            newPeriod_2.Name = '1970-09';
            newPeriod_2.Start_Date__c = Date.newInstance(1970, 09, 1);
            newPeriod_2.End_Date__c = Date.newInstance(1970, 09, 30);
            periodsForSave.add(newPeriod_2);

            Accounting_Period__c newPeriod_3 = new Accounting_Period__c();
            newPeriod_3.Name = '1970-10';
            newPeriod_3.Start_Date__c = Date.newInstance(1970, 08, 1);
            newPeriod_3.End_Date__c = Date.newInstance(1970, 08, 30);
            periodsForSave.add(newPeriod_3);

            DmlException dmlEx;
            try {
                insert periodsForSave;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(AccountingPeriodActions.NAME_DUPLICATION_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testNameDuplicationUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Accounting_Period__c> periodsForSave = new List<Accounting_Period__c>();

            Accounting_Period__c periodInDB_1 = new Accounting_Period__c();
            periodInDB_1.Name = '1970-10';
            periodInDB_1.Start_Date__c = Date.newInstance(1970, 10, 1);
            periodInDB_1.End_Date__c = Date.newInstance(1970, 10, 30);
            periodsForSave.add(periodInDB_1);

            Accounting_Period__c periodInDB_2 = new Accounting_Period__c();
            periodInDB_2.Name = '1970-11';
            periodInDB_2.Start_Date__c = Date.newInstance(1970, 11, 1);
            periodInDB_2.End_Date__c = Date.newInstance(1970, 11, 30);
            periodsForSave.add(periodInDB_2);

            insert periodsForSave;

            Test.startTest();

            Accounting_Period__c periodForUpdate = [
                SELECT Id, Name
                FROM Accounting_Period__c
                WHERE Name = :periodInDB_1.Name LIMIT 1
            ];
            periodForUpdate.Name = '1970-11';

            DmlException dmlEx;
            try {
                AccountingPeriodHandler.reset();
                update periodForUpdate;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(AccountingPeriodActions.NAME_DUPLICATION_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testStartDateGreaterThanEndDateInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // Test insert new accounting period and generate error
            Accounting_Period__c period = new Accounting_Period__c();
            period.Name = '1970-03';
            period.Start_Date__c = Date.newInstance(1970,1,31);
            period.End_Date__c = Date.newInstance(1970,1,1);

            DmlException dmlEx;
            try {
                insert period;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.START_DATE_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testStartDateGreaterThanEndDateUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // Test update existing accounting period and generate error
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Start_Date__c = Date.newInstance(1970,1,31);
            testAccountingPeriod.End_Date__c = Date.newInstance(1970,1,1);

            DmlException dmlEx;
            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.START_DATE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testSetStatusFieldDefaultOpen() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c period = new Accounting_Period__c();
            period.Name = '1970-01';
            period.Start_Date__c = Date.newInstance(1970,1,1);
            period.End_Date__c = Date.newInstance(1970,1,31);
            period.Status__c = AccountingPeriodActions.CLOSED_STATUS;

            insert period;

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :period.Id].Status__c
            );
        }

    }

    @IsTest
    private static void testCheckValidStatusUpdateNonNull() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = 'Crazy Value';

            DmlException dmlEx;
            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.STATUS_VALUE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testCheckValidStatusUpdateNull() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = null;

            DmlException dmlEx;
            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.STATUS_VALUE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testSetStatusArchiveError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = 'Archived';

            DmlException dmlEx;
            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.STATUS_ARCHIVE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testSetStatusUnArchiveError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = 'Archived';

            AccountingPeriodActions.isPreventUpdateOverride = true;
            update testAccountingPeriod;
            AccountingPeriodActions.isPreventUpdateOverride = false;

            testAccountingPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            DmlException dmlEx;
            try {
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.STATUS_UNARCHIVE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testResetAccountingPeriodHandler() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            List<Accounting_Period__c> periods = acctPeriodHandler.getAllAccountingPeriods();
            System.assertEquals(7, periods.size());

            Accounting_Period__c newPeriod = new Accounting_Period__c(
                    Name = '1992-05',
                    Start_Date__c = Date.newinstance(1992, 5, 1),
                    End_Date__c = Date.newinstance(1992, 5, 30),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            insert newPeriod;

            AccountingPeriodHandler acctPeriodHandlerNew = AccountingPeriodHandler.getInstance();
            List<Accounting_Period__c> newPeriods = acctPeriodHandlerNew.getAllAccountingPeriods();
            System.assertEquals(8, newPeriods.size());
        }
    }

    @IsTest
    public static void testAccountingPeriodNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            try {
                Accounting_Period__c ap = new Accounting_Period__c();
                insert ap;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testAccountingPeriodNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DmlException dmlEx;
                try {
                    Accounting_Period__c ap = new Accounting_Period__c();
                    insert ap;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testPreventDeleteIfPayblesExist() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {

            Accounting_Period__c testPeriod = new Accounting_Period__c(
                Name = '1992-05',
                Start_Date__c = Date.newInstance(1992, 5, 1),
                End_Date__c = Date.newInstance(1992, 5, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            insert testPeriod;

            Account_Payable__c newItem = testData.payables[0].clone(false);
            newItem.Accounting_Period__c = testPeriod.Id;
            newItem.Payee_Reference__c = 'test ref';

            insert newItem;

            System.assertEquals(1, [SELECT Id FROM Account_Payable__c WHERE Accounting_Period__c = :testPeriod.Id].size());

            DmlException dmlEx;
            try {
                delete testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventDeleteIfBillingsExist() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testPeriod = new Accounting_Period__c(
                Name = '1992-05',
                Start_Date__c = Date.newInstance(1992, 5, 1),
                End_Date__c = Date.newInstance(1992, 5, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            insert testPeriod;

            Billing__c newItem = testData.billings[0].clone(false);
            newItem.Accounting_Period__c = testPeriod.Id;

            insert newItem;

            System.assertEquals(1, [SELECT Id FROM Billing__c WHERE Accounting_Period__c = :testPeriod.Id].size());

            DmlException dmlEx;
            try {
                delete testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventDeleteIfCashReceiptsExist() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testPeriod = new Accounting_Period__c(
                Name = '1992-05',
                Start_Date__c = Date.newInstance(1992, 5, 1),
                End_Date__c = Date.newInstance(1992, 5, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            insert testPeriod;

            Cash_Receipt__c newItem = testData.cashReceipts[0].clone(false);
            newItem.Accounting_Period__c = testPeriod.Id;

            insert newItem;

            System.assertEquals(1, [SELECT Id FROM Cash_Receipt__c WHERE Accounting_Period__c = :testPeriod.Id].size());

            DmlException dmlEx;
            try {
                delete testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventDeleteIfCashDisbursementsExist() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testPeriod = new Accounting_Period__c(
                Name = '1992-05',
                Start_Date__c = Date.newInstance(1992, 5, 1),
                End_Date__c = Date.newInstance(1992, 5, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            insert testPeriod;

            Cash_Disbursement__c newItem = testData.cashDisbursements[0].clone(false);
            newItem.Accounting_Period__c = testPeriod.Id;

            insert newItem;

            System.assertEquals(1, [SELECT Id FROM Cash_Disbursement__c WHERE Accounting_Period__c = :testPeriod.Id].size());

            DmlException dmlEx;
            try {
                delete testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventDeleteIfJournalEntriesExist() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testPeriod = new Accounting_Period__c(
                Name = '1992-05',
                Start_Date__c = Date.newInstance(1992, 5, 1),
                End_Date__c = Date.newInstance(1992, 5, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );

            insert testPeriod;

            Journal_Entry__c newItem = testData.journalEntries[0].clone(false);
            newItem.Accounting_Period__c = testPeriod.Id;

            insert newItem;

            System.assertEquals(1, [SELECT Id FROM Journal_Entry__c WHERE Accounting_Period__c = :testPeriod.Id].size());

            DmlException dmlEx;
            try {
                delete testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventDeleteIfAPDisbursementsExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createCashDisbursementBatches()
            .createCashDisbursements(false);

        Test.startTest();
        testData.createApDisbursements();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testPeriod = new Accounting_Period__c(
                Name = '1992-05',
                Start_Date__c = Date.newInstance(1992, 5, 1),
                End_Date__c = Date.newInstance(1992, 5, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert testPeriod;

            AP_Disbursement__c newItem = testData.apDisbursements[4].clone(false);
            newItem.Paid_Amount__c = 0.01;
            newItem.Accounting_Period__c = testPeriod.Id;
            insert newItem;

            System.assertEquals(1, [SELECT Id FROM AP_Disbursement__c WHERE Accounting_Period__c = :testPeriod.Id].size());

            DmlException dmlEx;
            try {
                delete testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testPreventDeleteIfBCRsExist() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings(false)
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c testPeriod = new Accounting_Period__c(
                Name = '1992-05',
                Start_Date__c = Date.newInstance(1992, 5, 1),
                End_Date__c = Date.newInstance(1992, 5, 30),
                Status__c = AccountingPeriodActions.OPEN_STATUS
            );
            insert testPeriod;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Accounting_Period__c = testPeriod.Id;
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Applied_Amount__c = 1;
            insert bcr;

            System.assertEquals(1, [SELECT Id FROM Billing_Cash_Receipt__c WHERE Accounting_Period__c = :testPeriod.Id].size());

            DmlException dmlEx;
            try {
                delete testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventOpenClosedOrArchivedPeriodIfConsolidation() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            DmlException dmlEx;
            Database.executeBatch(
                new ConsolidationRoutineBatch(new LedgerHierarchyModel(testData.ledgerHierarchies[2]), testData.acctPeriods.get(1).Id, true)
            );
            try {
                Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(1);
                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.CONSOLIDATION_IN_PROGRESS_ERROR, dmlEx.getDmlMessage(0));
        }

    }
    
    @IsTest
    private static void testPreventOpenAPOpenARIfStatusClosed() {
        
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
        //no mixed close and soft operations are allowed so 2 updates are used as setup.
        testAccountingPeriod.Close_AP__c = true;
        testAccountingPeriod.Close_AR__c = true;
        update testAccountingPeriod;
        Test.startTest();
                testAccountingPeriod.Status__c = 'Closed';
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                update testAccountingPeriod;
        Test.stopTest();
        System.runAs(testData.users.get(1)) {

            DmlException dmlEx;
            try {
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                testAccountingPeriod.Close_AP__c = false;
                testAccountingPeriod.Close_AR__c = false;
                update testAccountingPeriod;
                Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
                testAccountingPeriod1.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                testAccountingPeriod1.Close_AP__c = false;
                testAccountingPeriod1.Close_AR__c = false;
                update testAccountingPeriod1;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.CLOSE_AP_AR_INVENTORY_ERROR + ' Close AP, Close AR.', dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    private static void testPreventOpenARIfStatusClosed() {
        
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
        //no mixed close and soft operations are allowed so 2 updates are used as setup.
        testAccountingPeriod.Close_AR__c = true;
        update testAccountingPeriod;
        Test.startTest();
                testAccountingPeriod.Status__c = 'Closed';
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                update testAccountingPeriod;
        Test.stopTest();

        System.runAs(testData.users.get(1)) {

            DmlException dmlEx;
            try {
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                testAccountingPeriod.Close_AR__c = false;
                update testAccountingPeriod;
                Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
                testAccountingPeriod1.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                testAccountingPeriod1.Close_AR__c = false;
                update testAccountingPeriod1;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.CLOSE_AP_AR_INVENTORY_ERROR + ' Close AR.', dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    private static void testPreventOpenAPIfStatusClosed() {
        
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
        //no mixed close and soft operations are allowed so 2 updates are used as setup.
        testAccountingPeriod.Close_AP__c = true;
        update testAccountingPeriod;
        //This is a job that needs to be run in a block so that the close process will finish.
        //The actual test is below it.
        Test.startTest();
                testAccountingPeriod.Status__c = 'Closed';
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                update testAccountingPeriod;
        Test.stopTest();

        System.runAs(testData.users.get(1)) {

            DmlException dmlEx;
            try {
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                testAccountingPeriod.Close_AP__c = false;
                update testAccountingPeriod;
                Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
                testAccountingPeriod1.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                testAccountingPeriod1.Close_AP__c = false;
                testAccountingPeriod1.Close_AR__c = false;
                update testAccountingPeriod1;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            catch (Exception ex) {
                System.assert(false, 'Wrong Error: ' + ex.getMessage());
            }
            System.assertNotEquals(NULL, dmlEx, 'Error Failed to be thrown.');
            System.assertEquals(AccountingPeriodActions.CLOSE_AP_AR_INVENTORY_ERROR + ' Close AP.', dmlEx.getDmlMessage(0));

        }
    }

    private static void testdeleteAPAgingOnSoftOpen() {
        TestDataSuite testData = TestDataSuite.getInstance();

        List < Accounting_Period__c > newPeriods = new List < Accounting_Period__c >();
        List < Accounting_Period__c > updatedPeriods = new List < Accounting_Period__c >();

        System.assertEquals(FALSE,testData.acctPeriods.get(0).close_AP__c);
        System.assertEquals(AccountingPeriodActions.OPEN_STATUS,testData.acctPeriods.get(1).Status__c);
        System.assertEquals(FALSE,testData.acctPeriods.get(1).close_AP__c);

        System.runAs(testData.users.get(1)) {
            for (Accounting_Period__c acctPeriod: new List<Accounting_Period__c>{testData.acctPeriods.get(0),testData.acctPeriods.get(1)}) {
                acctPeriod.close_AP__c = true;
                newPeriods.add(acctPeriod);
            }       
            update newPeriods;

            System.assertEquals(TRUE, newPeriods.get(0).close_AP__c);
            System.assertEquals(TRUE, newPeriods.get(1).close_AP__c);
            AccountingPeriodHandler.reset();
            AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;

            for (Accounting_Period__c acctPeriod: newPeriods) {
                acctPeriod.close_AP__c = false;
                updatedPeriods.add(acctPeriod);
            }       
            update updatedPeriods;

            System.assertEquals(FALSE, newPeriods.get(0).close_AP__c);
            System.assertEquals(FALSE, newPeriods.get(1).close_AP__c); 
            System.assertEquals(TRUE, [Select id, close_AP__c, Status__c from Accounting_Period__c Where
                                   close_AP__c = false AND Status__c = :AccountingPeriodActions.OPEN_STATUS]?.size() > 0); 

        }  
    }

    @IsTest
    private static void testdeleteARAgingOnSoftOpen() {
        TestDataSuite testData = TestDataSuite.getInstance();

        List < Accounting_Period__c > newPeriods = new List < Accounting_Period__c >();
        List < Accounting_Period__c > updatedPeriods = new List < Accounting_Period__c >();

        System.assertEquals(FALSE,testData.acctPeriods.get(0).close_AR__c);
        System.assertEquals(AccountingPeriodActions.OPEN_STATUS,testData.acctPeriods.get(1).Status__c);
        System.assertEquals(FALSE,testData.acctPeriods.get(1).close_AR__c);

        System.runAs(testData.users.get(1)) {
            for (Accounting_Period__c acctPeriod: new List<Accounting_Period__c>{testData.acctPeriods.get(0),testData.acctPeriods.get(1)}) {
                acctPeriod.close_AR__c = true;
                newPeriods.add(acctPeriod);
            }       
            update newPeriods;

        System.assertEquals(TRUE, newPeriods.get(0).close_AR__c);
        System.assertEquals(TRUE, newPeriods.get(1).close_AR__c);

            AccountingPeriodHandler.reset();
            AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;

            for (Accounting_Period__c acctPeriod: newPeriods) {
                acctPeriod.close_AR__c = false;
                updatedPeriods.add(acctPeriod);
            }       
            update updatedPeriods;

        System.assertEquals(FALSE, newPeriods.get(0).close_AR__c);
        System.assertEquals(FALSE, newPeriods.get(1).close_AR__c); 
        System.assertEquals(TRUE, [Select id, close_AR__c, Status__c from Accounting_Period__c Where
                                   close_AR__c = false AND Status__c = :AccountingPeriodActions.OPEN_STATUS]?.size() > 0); 

        }  
    }

    @IsTest
    private static void closeAndSoftClose() {
        DmlException dmlEx;
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testCloseAccountingPeriod = testData.acctPeriods.get(0);
            Accounting_Period__c testSoftCloseAccountingPeriod = testData.acctPeriods.get(1);

            try {
                testCloseAccountingPeriod.Status__c = 'Closed';
                testSoftCloseAccountingPeriod.Close_AP__c = true;
                List<Accounting_Period__c> periodsToUpdate = new List<Accounting_Period__c>();
                periodsToUpdate.add(testSoftCloseAccountingPeriod);
                periodsToUpdate.add(testCloseAccountingPeriod);
                update periodsToUpdate;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            catch (Exception ex) {
		        System.assert(false, 'Wrong Error: ' + ex.getMessage());
            }


            System.assertNotEquals(NULL, dmlEx, 'DML error was not thrown');
            System.assertEquals(AccountingPeriodActions.MIXED_OPEN_CLOSE_WITH_SOFT_OPEN_CLOSE, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testPreventOpenARIfStatusCloseInProgress() {
        
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
        Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(1);
        testAccountingPeriod.Close_AR__c = true;
        testAccountingPeriod1.Close_AR__c = true;
        List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();
        acctPeriods.add(testAccountingPeriod);
        acctPeriods.add(testAccountingPeriod1);
        update acctPeriods;
        System.Test.stopTest();
        AccountingPeriodHandler.reset();
        AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
        testAccountingPeriod.Status__c = 'Closed';
        update testAccountingPeriod;

        //simulate another user tying to soft close something while the close is in progress
        System.runAs(testData.users.get(1)) {
            AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = true;

            DmlException dmlEx;
            try {
                testAccountingPeriod1 = testData.acctPeriods.get(1);
                testAccountingPeriod1.Close_AR__c = false;
                update testAccountingPeriod1;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.ERR_OPEN_CLOSE_OPERATION_IN_PROGRESS, dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    private static void testPreventOpenARIfStatusSoftOpInProgress() {
        
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();
        Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
        Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(1);
        testAccountingPeriod.Close_AR__c = true;
        testAccountingPeriod1.Close_AR__c = true;
        acctPeriods.add(testAccountingPeriod);
        acctPeriods.add(testAccountingPeriod1);
        update acctPeriods;

        //simulate another user tying to soft close something while the close is in progress
        System.runAs(testData.users.get(1)) {

            DmlException dmlEx;
            try {
                testAccountingPeriod1 = testData.acctPeriods.get(1);
                testAccountingPeriod1.Close_AR__c = false;
                update testAccountingPeriod1;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
        Test.stopTest();
            System.assertEquals(AccountingPeriodActions.ERR_OPEN_CLOSE_OPERATION_IN_PROGRESS, dmlEx.getDmlMessage(0));

        }
   }

    @IsTest
    private static void testPreventCloseARIfStatusSoftOpInProgress() {
        
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
        testAccountingPeriod.Close_AR__c = true;
        update testAccountingPeriod;
        Test.stopTest();
        AccountingPeriodHandler.reset();
        AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
        testAccountingPeriod.Close_AR__c = false;
        update testAccountingPeriod;

        //simulate another user tying to soft close something while the close is in progress
        System.runAs(testData.users.get(1)) {
            AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = true;

            DmlException dmlEx;
            try {
                Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(1);
                testAccountingPeriod1.Close_AR__c = true;
                update testAccountingPeriod1;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(AccountingPeriodActions.ERR_OPEN_CLOSE_OPERATION_IN_PROGRESS, dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    private static void testPreventOpenAPIfStatusArchived() {
        
        TestDataSuite testData = TestDataSuite.getInstance();
        Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);

        Test.startTest();
                testAccountingPeriod.Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
                AccountingPeriodActions.isPreventUpdateOverride = true;
                update testAccountingPeriod;
                AccountingPeriodActions.isPreventUpdateOverride = true;
        Test.stopTest();

        System.runAs(testData.users.get(1)) {

            DmlException dmlEx;
            try {
                AccountingPeriodHandler.reset();
                AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
                testAccountingPeriod.Close_AP__c = true;
                update testAccountingPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            catch (Exception ex) {
                Assert.areEqual(false, 'Wrong Error: ' + ex.getMessage());
            }
            Assert.areEqual(AccountingPeriodActions.CLOSE_AP_AR_INVENTORY_ERROR + ' Close AP.', dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testPreventClosedOrArchivedPeriodIfLDOInProgress() {
        TestDataSuite testData = TestDataSuite.getInstance().enableLDVMode().createBillings(false);

        System.runAs(testData.users.get(1)) {
            testData.billings[0].Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTING_IN_PROGRESS;
            TriggerObserver.getInstance().unlockField(Billing__c.Status__c);
            update testData.billings[0];
            TriggerObserver.purgeUnlockedFields(Billing__c.Status__c);

            DmlException dmlEx;
            try {
                Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
                testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(Label.ERR_LDO_JOB_IN_PROGRESS, dmlEx.getDmlMessage(0));
        }

    }

}