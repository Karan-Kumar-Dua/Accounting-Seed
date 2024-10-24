@isTest
private class PurgeBatchesTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest 
    private static void PurgeAPAgingHistoryBatchWithoutDataTest() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true).createAPAgingHistories();
        
        System.runAs(testData.users.get(0)){
            Test.startTest();
            List<AP_Aging_History__c> historiesFromDB = [SELECT Id FROM AP_Aging_History__c];
            System.assertEquals(testData.apAgingHistories.size(), historiesFromDB.size());

            PurgeAPAgingHistoryBatch purgeBatch = new PurgeAPAgingHistoryBatch(null);
            Database.executeBatch(purgeBatch);
            Test.stopTest();

            historiesFromDB = [SELECT Id FROM AP_Aging_History__c];
            System.assertEquals(testData.apAgingHistories.size(), historiesFromDB.size());
        }
    }
    
    @isTest 
    private static void PurgeAPAgingHistoryBatchWithDataTest() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables(true).createAPAgingHistories();

        System.runAs(testData.users.get(0)) {
            //Close Accounting Periods
            //TODO: change that approach for closing after merging with dallas branch
            List<Accounting_Period__c> closedPeriods = new List<Accounting_Period__c>();
            closedPeriods.add(testData.acctPeriods[0]);
            closedPeriods.add(testData.acctPeriods[1]);
            closedPeriods.add(testData.acctPeriods[2]);

            AccountingPeriodActions.isFirstRun = false;
            for (Accounting_Period__c ap : closedPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update ap;
            }
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();
            List<AP_Aging_History__c> historiesFromDB = [SELECT Id FROM AP_Aging_History__c];
            System.assertEquals(testData.apAgingHistories.size(), historiesFromDB.size());
            AccountingPeriodHandler.reset();
            PurgeAPAgingHistoryBatch purgeBatch = new PurgeAPAgingHistoryBatch(testData.acctPeriods[2].Id);
            Database.executeBatch(purgeBatch);
            Test.stopTest();

            historiesFromDB = [SELECT Id FROM AP_Aging_History__c];
            System.assertEquals(1, historiesFromDB.size());
        }
    }
    
    @isTest 
    private static void PurgeBillingAgingHistoryBatchWithoutDataTest() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true).createBillingAgingHistories();
        System.runAs(testData.users.get(0)) {
            Test.startTest();
            List<Billing_Aging_History__c> historiesFromDB = [SELECT Id FROM Billing_Aging_History__c];
            System.assertEquals(testData.billingAgingHistories.size(), historiesFromDB.size());

            PurgeBillingAgingHistoryBatch purgeBatch = new PurgeBillingAgingHistoryBatch(null);
            Database.executeBatch(purgeBatch);
            Test.stopTest();

            historiesFromDB = [SELECT Id FROM Billing_Aging_History__c];
            System.assertEquals(testData.billingAgingHistories.size(), historiesFromDB.size());
        }
    }
    
    @isTest 
    private static void PurgeBillingAgingHistoryBatchWithDataTest() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true).createBillingAgingHistories();

        System.runAs(testData.users.get(0)) {
            //Close Accounting Periods
            //TODO: change that approach for closing after merging with dallas branch
            List<Accounting_Period__c> closedPeriods = new List<Accounting_Period__c>();
            closedPeriods.add(testData.acctPeriods[0]);
            closedPeriods.add(testData.acctPeriods[1]);
            closedPeriods.add(testData.acctPeriods[2]);

            AccountingPeriodActions.isFirstRun = false;
            for (Accounting_Period__c ap : closedPeriods) {
                ap.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                update ap;
            }
            AccountingPeriodActions.isFirstRun = true;

            Test.startTest();
            List<Billing_Aging_History__c> historiesFromDB = [SELECT Id FROM Billing_Aging_History__c];
            System.assertEquals(testData.billingAgingHistories.size(), historiesFromDB.size());
            AccountingPeriodHandler.reset();
            PurgeBillingAgingHistoryBatch purgeBatch = new PurgeBillingAgingHistoryBatch(testData.acctPeriods[2].Id);
            Database.executeBatch(purgeBatch);
            Test.stopTest();

            historiesFromDB = [SELECT Id FROM Billing_Aging_History__c];
            System.assertEquals(1, historiesFromDB.size());
        }
    }
    
    @isTest 
    private static void PurgeFinancialReportResultBatchTest() {
        TestDataSuite testData = TestDataSuite.getInstance().createFinancialReportResults();

        System.runAs(testData.users.get(0)) {
            Test.startTest();
            List<Financial_Report_Result__c> resultsFromDB = [SELECT Id FROM Financial_Report_Result__c];
            System.assertEquals(testData.financialReportResults.size(), resultsFromDB.size());

            PurgeFinancialReportResultBatch purgeBatch = new PurgeFinancialReportResultBatch();
            Database.executeBatch(purgeBatch);
            Test.stopTest();

            resultsFromDB = [SELECT Id FROM Financial_Report_Result__c];
            System.assertEquals(0, resultsFromDB.size());
        }
    }
    
    @isTest
    private static void PurgeInventoryBalanceHistoryBatchNegativeTest() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(0)) {
            if (!AccountingSettingsHandler.isERPEnabled()) {
                Test.startTest();
                PurgeInventoryBalanceHistoryBatch purgeBatch = new PurgeInventoryBalanceHistoryBatch(Date.today());
                try {
                    purgeBatch.start(null);
                } catch (Exception e) {
                    System.assertEquals(e.getTypeName(), 'System.QueryException');
                }
                Test.stopTest();
            }
        }
    }
    @isTest
   private static void PurgeAutomatedJobResultTest() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(0)) {
            //this one will not get deleted because the created date is equal to the retention date
            AutomatedJobResultsHandler.setJobType('Recurring Journal Entry Job');
            AutomatedJobResultsHandler.saveAutomatedJobResults();
            List<Automated_Job_Results__c> resultsAJR = [SELECT Id, CreatedDate FROM Automated_Job_Results__c];
            System.assertEquals(1, resultsAJR.size());
            Test.startTest();
            PurgeAutomatedJodResultsBatch purgeBatch = new PurgeAutomatedJodResultsBatch(resultsAJR[0].CreatedDate.date());
            Database.executeBatch(purgeBatch);
            Test.stopTest();

            resultsAJR = [SELECT Id FROM Automated_Job_Results__c];
            System.assertEquals(1, resultsAJR.size());
        }
    }

   @isTest
   private static void PurgeAutomatedJobResultRetentionDateTest() {
       TestDataSuite testData = TestDataSuite.getInstance();
       System.runAs(testData.users.get(0)) {
           //this one will get deleted because the created date is less than the retention date
           AutomatedJobResultsHandler.setJobType('Recurring Journal Entry Job');
           AutomatedJobResultsHandler.saveAutomatedJobResults();
           List<Automated_Job_Results__c> resultsAJR = [SELECT Id FROM Automated_Job_Results__c];
           System.assertEquals(1, resultsAJR.size());
           Test.setCreatedDate(resultsAJR[0].id, System.today() - 1);

           Test.startTest();
           PurgeAutomatedJodResultsBatch purgeBatch = new PurgeAutomatedJodResultsBatch(System.today());
           Database.executeBatch(purgeBatch);
           Test.stopTest();

           resultsAJR = [SELECT Id FROM Automated_Job_Results__c];
           System.assertEquals(0, resultsAJR.size());
       }
   }
}