@IsTest
public class AccountingPeriodOpenCloseUtilsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
        //Set current transaction-per-period limit
        FeatureManagement.setPackageIntegerValue(FeatureManagementHandler.FP_ACCOUNTING_PERIOD_TRANSACTION_LIMIT, 50);
    }

    @IsTest
    private static void testOpenCloseRollBackAndNotify() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Accounting_Period__c> twoPeriods = new List<Accounting_Period__c>{testData.acctPeriods[0], testData.acctPeriods[1]};
            try {
                for (Accounting_Period__c period : twoPeriods) {
                    period.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                }
                AccountingPeriodActions.isFirstRun = false;
                update(twoPeriods);

                twoPeriods = [SELECT Id, Name, Status__c FROM Accounting_Period__c WHERE Id IN :twoPeriods];
                System.assertEquals(AccountingPeriodActions.CLOSED_STATUS, twoPeriods[0].Status__c);
                System.assertEquals(AccountingPeriodActions.CLOSED_STATUS, twoPeriods[1].Status__c);
                throw new AccountingPeriodHandler.AccountingPeriodException('Custom Exception');
            }
            catch (Exception ex) {
                Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers.get(0).Id);
                AccountingPeriodOpenCloseOptions periodInfoContainer =
                    new AccountingPeriodOpenCloseOptions(
                        twoPeriods,
                        0,
                        AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                    );

                Test.startTest();
                AccountingPeriodOpenCloseUtils.rollBackAndNotify(ex, periodInfoContainer);
                twoPeriods = [SELECT Id, Name, Status__c FROM Accounting_Period__c WHERE Id IN :twoPeriods];
                //first period status will not be rolled back because this is "currently processed" period
                System.assertEquals(AccountingPeriodActions.CLOSED_STATUS, twoPeriods[0].Status__c);
                System.assertEquals(AccountingPeriodActions.OPEN_STATUS, twoPeriods[1].Status__c);
            }
        }
    }

    @IsTest
    private static void testArchivingRollBackAndNotify() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[0];
            testAccountingPeriod.Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update(testAccountingPeriod);

            Test.startTest();
            AccountingPeriodOpenCloseUtils.updateAndNotify(
                testAccountingPeriod, AccountingPeriodActions.OPEN_STATUS, 'Subj', 'Body'
            );

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                [SELECT Id, Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );
        }
    }

    @IsTest
    private static void testCloseAccountingPeriodsWhenNextPeriodDoesNotExists() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            for (Accounting_Period__c period : testData.acctPeriods) {
                period.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }

            DmlException dmlEx;
            try {
                update testData.acctPeriods;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            String expectedErrorMessage = String.format(
                AccountingPeriodOpenCloseUtils.NEXT_PERIOD_DOES_NOT_EXISTS_ERROR_MESSAGE,
                new List<String>{
                    AccountingPeriodHandler.getInstance().getNextAccountingPeriod(
                        testData.acctPeriods.get(testData.acctPeriods.size() - 1)
                    ).Name,
                    testData.acctPeriods.get(testData.acctPeriods.size() - 1).Name
                }
            );
            System.assertEquals(expectedErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testCloseAccountingPeriodWhenNextPeriodDoesNotExists() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testPeriod = testData.acctPeriods.get(testData.acctPeriods.size() - 1);

            DmlException dmlEx;
            try {
                testPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            String expectedErrorMessage = String.format(
                AccountingPeriodOpenCloseUtils.NEXT_PERIOD_DOES_NOT_EXISTS_ERROR_MESSAGE,
                new List<String>{
                    AccountingPeriodHandler.getInstance().getNextAccountingPeriod(
                        testData.acctPeriods.get(testData.acctPeriods.size() - 1)
                    ).Name,
                    testData.acctPeriods.get(testData.acctPeriods.size() - 1).Name
                }
            );
            System.assertNotEquals(expectedErrorMessage, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    private static void testOpenAccountingPeriodSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            Test.startTest();

            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.CLOSE_INTERIM_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            Test.stopTest();
            //after batch chain end we expect final status
            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
            AccountingPeriodActions.isFirstRun = true;
            testAccountingPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.OPEN_INTERIM_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );
        }
    }

    @IsTest
    private static void testCloseAccountingJobInProgressError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Test.startTest();
                Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
                testAccountingPeriod1.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod1;
                Test.stopTest();

                AccountingPeriodActions.isFirstRun = true;
                Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);
                testAccountingPeriod2.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update testAccountingPeriod2;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodOpenCloseUtils.JOB_IN_PROGRESS_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testOpenAccountingJobInProgressError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Test.startTest();
                List<Accounting_Period__c> testPeriods = new List<Accounting_Period__c>();
                Accounting_Period__c testAccountingPeriod1 = testData.acctPeriods.get(0);
                testAccountingPeriod1.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                testPeriods.add(testAccountingPeriod1);

                Accounting_Period__c testAccountingPeriod2 = testData.acctPeriods.get(1);
                testAccountingPeriod2.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                testPeriods.add(testAccountingPeriod2);

                update testPeriods;

                Test.stopTest();
                Set<Id> testAccountingPeriodIds = new Set<Id>{testAccountingPeriod1.Id, testAccountingPeriod2.Id};
                Map<Id, Accounting_Period__c> validatedAccountingPeriodsMap = new Map<Id, Accounting_Period__c>([
                    SELECT Id, Status__c FROM Accounting_Period__c WHERE Id IN :testAccountingPeriodIds
                ]);
                System.assertEquals(
                    AccountingPeriodActions.CLOSED_STATUS,
                    validatedAccountingPeriodsMap.get(testAccountingPeriod1.Id).Status__c
                );
                System.assertEquals(
                    AccountingPeriodActions.CLOSED_STATUS,
                    validatedAccountingPeriodsMap.get(testAccountingPeriod2.Id).Status__c
                );

                AccountingPeriodActions.isFirstRun = true;
                testAccountingPeriod2.Status__c = AccountingPeriodActions.OPEN_STATUS;
                update testAccountingPeriod2;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodOpenCloseUtils.JOB_IN_PROGRESS_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testCloseAccountingPeriodNotContiguousError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();
            acctPeriods.add(
                new Accounting_Period__c(
                    Name = '1970-03',
                    Start_Date__c = Date.newInstance(1970, 3, 1),
                    End_Date__c = Date.newInstance(1991, 3, 31),
                    Status__c = AccountingPeriodActions.OPEN_STATUS
                )
            );

            insert acctPeriods;
            acctPeriods.addAll(testData.acctPeriods);
            try {
                for (Accounting_Period__c period : acctPeriods) {
                    period.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                }
                AccountingPeriodHandler.reset();
                update acctPeriods;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.NOT_CONTIGUOUS_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testCloseAccountingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.CLOSE_INTERIM_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            Test.stopTest();
            //after batch chain end we expect final status
            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );
        }

    }

    @IsTest
    private static void testSoftOpenOfStuckInCloseInProgressAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.CLOSE_INTERIM_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            testAccountingPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );
        }

    }

    @IsTest
    private static void testSoftOpenOfStuckInOpenInProgressAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods.get(0);
            testAccountingPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.CLOSE_INTERIM_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            Test.stopTest();

            System.assertEquals(
                AccountingPeriodActions.CLOSED_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            AccountingPeriodActions.isFirstRun = true;
            AccountingPeriodOpenCloseUtils.isPreventJobSearchSkip = false;
            testAccountingPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.OPEN_INTERIM_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );

            testAccountingPeriod.Status__c = AccountingPeriodActions.OPEN_STATUS;
            update testAccountingPeriod;

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                [SELECT Status__c FROM Accounting_Period__c WHERE Id = :testAccountingPeriod.Id].Status__c
            );
        }

    }

    @IsTest
    private static void testCloseAccountingPeriodsGenericException() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            AccountingPeriodOpenCloseUtils.closeAccountingPeriods(testData.acctPeriods, NULL);
            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS,
                AccountingPeriodHandler.getInstance().getAccountingPeriodById(testData.acctPeriods[0].Id).Status__c
            );
        }
    }

}