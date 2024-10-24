@IsTest
public with sharing class PurgeDataHelperTest {
    
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static List<AsyncApexJob> retrieveAsyncApexJobs(List<String> apexClassNames) {
        List<ApexClass> apexClasses = [
            SELECT Id
            FROM ApexClass
            WHERE Name IN :apexClassNames
        ];

        Set<Id> apexClassIds = new Map<Id, ApexClass>(apexClasses).keySet();
        
        return [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE ApexClassID IN :apexClassIds
        ];
    }

    @IsTest
    private static void testPurgeAPAgingHistory() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id period = testData.acctPeriods[0].Id;
            String actualMsg = PurgeDataHelper.purgeAPAgingHistory(period);

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeAPAgingHistoryBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_BATCH_RUNNING_SUCCESS, new String[]{ 
                AP_Aging_History__c.getsObjectType().getDescribe().getLabel(),
                UserInfo.getUserEmail()
            });
            System.assertEquals(expectedMsg, actualMsg);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPurgeAPAgingHistoryMissingInput() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Exception expectedEx;
            try {
                PurgeDataHelper.purgeAPAgingHistory(null);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_PERIOD });
            System.assertEquals(expectedMsg, expectedEx.getMessage());

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeAPAgingHistoryBatch' });
            System.assert(asyncApexJobs.isEmpty());
            System.assertEquals(0, asyncApexJobs.size());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPurgeAPAgingHistoryLimitOneJob() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id period = testData.acctPeriods[0].Id;
            PurgeDataHelper.purgeAPAgingHistory(period);

            Exception expectedEx;
            try {
                PurgeDataHelper.purgeAPAgingHistory(period);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeAPAgingHistoryBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(PurgeDataHelper.MESSAGE_JOB_IS_RUNNING, expectedEx.getMessage());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testBillingAgingHistory() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id period = testData.acctPeriods[0].Id;
            String actualMsg = PurgeDataHelper.purgeBillingAgingHistory(period);

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeBillingAgingHistoryBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_BATCH_RUNNING_SUCCESS, new String[]{ 
                Billing_Aging_History__c.getsObjectType().getDescribe().getLabel(),
                UserInfo.getUserEmail()
            });
            System.assertEquals(expectedMsg, actualMsg);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testBillingAgingHistoryLimitOneJob() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id period = testData.acctPeriods[0].Id;
            PurgeDataHelper.purgeBillingAgingHistory(period);

            Exception expectedEx;
            try {
                PurgeDataHelper.purgeBillingAgingHistory(period);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeBillingAgingHistoryBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(PurgeDataHelper.MESSAGE_JOB_IS_RUNNING, expectedEx.getMessage());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testBillingAgingHistoryMissingInput() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Exception expectedEx;
            try {
                PurgeDataHelper.purgeBillingAgingHistory(null);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_PERIOD });
            System.assertEquals(expectedMsg, expectedEx.getMessage());

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeBillingAgingHistoryBatch' });
            System.assert(asyncApexJobs.isEmpty());
            System.assertEquals(0, asyncApexJobs.size());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testFinancialReportResults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String actualMsg = PurgeDataHelper.purgeFinancialReportResults();

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeFinancialReportResultBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_BATCH_RUNNING_SUCCESS, new String[]{ 
                Financial_Report_Result__c.getsObjectType().getDescribe().getLabel(),
                UserInfo.getUserEmail()
            });
            System.assertEquals(expectedMsg, actualMsg);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testFinancialReportResultsLimitOneJob() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            PurgeDataHelper.purgeFinancialReportResults();

            Exception expectedEx;
            try {
                PurgeDataHelper.purgeFinancialReportResults();
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeFinancialReportResultBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(PurgeDataHelper.MESSAGE_JOB_IS_RUNNING, expectedEx.getMessage());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testZeroBalanceFinancialCubes() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String actualMsg = PurgeDataHelper.purgeZeroBalanceFinancialCubes();

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeZeroBalanceFinancialCubesBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_BATCH_RUNNING_SUCCESS, new String[]{ 
                Financial_Cube__c.getsObjectType().getDescribe().getLabel(),
                UserInfo.getUserEmail()
            });
            System.assertEquals(expectedMsg, actualMsg);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testZeroBalanceFinancialCubesLimitOneJob() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            PurgeDataHelper.purgeZeroBalanceFinancialCubes();

            Exception expectedEx;
            try {
                PurgeDataHelper.purgeZeroBalanceFinancialCubes();
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeZeroBalanceFinancialCubesBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(PurgeDataHelper.MESSAGE_JOB_IS_RUNNING, expectedEx.getMessage());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testAutomatedJobResults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Date before = testData.acctPeriods[0].End_Date__c;
            String actualMsg = PurgeDataHelper.purgeAutomatedJobResults(before);

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeAutomatedJodResultsBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_BATCH_RUNNING_SUCCESS, new String[]{ 
                Automated_Job_Results__c.getsObjectType().getDescribe().getLabel(),
                UserInfo.getUserEmail()
            });
            System.assertEquals(expectedMsg, actualMsg);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testAutomatedJobResultsMissingInput() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Exception expectedEx;
            try {
                PurgeDataHelper.purgeAutomatedJobResults(null);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_BEFORE });
            System.assertEquals(expectedMsg, expectedEx.getMessage());

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeAutomatedJodResultsBatch' });
            System.assert(asyncApexJobs.isEmpty());
            System.assertEquals(0, asyncApexJobs.size());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testAutomatedJobResultsLimitOneJob() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Date before = testData.acctPeriods[0].End_Date__c;
            PurgeDataHelper.purgeAutomatedJobResults(before);

            Exception expectedEx;
            try {
                PurgeDataHelper.purgeAutomatedJobResults(before);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeAutomatedJodResultsBatch' });
            System.assertNotEquals(null, asyncApexJobs);
            System.assert(!asyncApexJobs.isEmpty());
            System.assertEquals(1, asyncApexJobs.size());

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(PurgeDataHelper.MESSAGE_JOB_IS_RUNNING, expectedEx.getMessage());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testInventoryBalanceHistory() {
        // if ERP is really installed, not just faked
        if (AccountingSettingsHandler.isERPEnabled()) {
            TestDataSuite testData = TestDataSuite.getInstance().setERPEnabled();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                Date before = testData.acctPeriods[0].End_Date__c;
                String actualMsg = PurgeDataHelper.purgeInventoryBalanceHistory(before);

                List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeInventoryBalanceHistoryBatch' });
                System.assertNotEquals(null, asyncApexJobs);
                System.assert(!asyncApexJobs.isEmpty());
                System.assertEquals(1, asyncApexJobs.size());

                String expectedMsg = String.format(PurgeDataHelper.MESSAGE_BATCH_RUNNING_SUCCESS, new String[]{ 
                    Schema.getGlobalDescribe().get(PurgeDataHelper.INVENTORY_BALANCE_HISTORY_SOBJECT_NAME.toLowerCase()).getDescribe().getLabel(),
                    UserInfo.getUserEmail()
                });
                System.assertEquals(expectedMsg, actualMsg);

                Test.stopTest();
            }   
        }
    }

    @IsTest
    private static void testInventoryBalanceHistoryMissingInput() {
        TestDataSuite testData = TestDataSuite.getInstance().setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Exception expectedEx;
            try {
                PurgeDataHelper.purgeInventoryBalanceHistory(null);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            System.assertNotEquals(null, expectedEx);
            String expectedMsg = String.format(PurgeDataHelper.MESSAGE_REQUIRED_INPUT, new String[]{ Label.COMMON_BEFORE });
            System.assertEquals(expectedMsg, expectedEx.getMessage());

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeInventoryBalanceHistoryBatch' });
            System.assert(asyncApexJobs.isEmpty());
            System.assertEquals(0, asyncApexJobs.size());
            Test.stopTest();
        }
    }

    @IsTest
    private static void testInventoryBalanceHistoryERPNotInstalled() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Exception expectedEx;
            try {
                Date before = testData.acctPeriods[0].End_Date__c;
                PurgeDataHelper.purgeInventoryBalanceHistory(before);
            }
            catch (PurgeDataHelper.PurgeDataHelperException ex) {
                expectedEx = ex;
            }

            List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeInventoryBalanceHistoryBatch' });
            System.assert(asyncApexJobs.isEmpty());

            System.assertNotEquals(null, expectedEx);
            System.assertEquals(PurgeDataHelper.MESSAGE_ERP_REQUIRED, expectedEx.getMessage());

            Test.stopTest();
        }
    }

    @IsTest
    private static void testInventoryBalanceHistoryLimitOneJob() {
        // if ERP is really installed, not just faked
        if (AccountingSettingsHandler.isERPEnabled()) {
            TestDataSuite testData = TestDataSuite.getInstance().setERPEnabled();

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                Date before = testData.acctPeriods[0].End_Date__c;
                PurgeDataHelper.purgeInventoryBalanceHistory(before);

                Exception expectedEx;
                try {
                    PurgeDataHelper.purgeInventoryBalanceHistory(before);
                }
                catch (PurgeDataHelper.PurgeDataHelperException ex) {
                    expectedEx = ex;
                }

                List<AsyncApexJob> asyncApexJobs = retrieveAsyncApexJobs(new String[]{ 'PurgeInventoryBalanceHistoryBatch' });
                System.assertNotEquals(null, asyncApexJobs);
                System.assert(!asyncApexJobs.isEmpty());
                System.assertEquals(1, asyncApexJobs.size());

                System.assertNotEquals(null, expectedEx);
                System.assertEquals(PurgeDataHelper.MESSAGE_JOB_IS_RUNNING, expectedEx.getMessage());
                Test.stopTest();
            }
        }
    }

}