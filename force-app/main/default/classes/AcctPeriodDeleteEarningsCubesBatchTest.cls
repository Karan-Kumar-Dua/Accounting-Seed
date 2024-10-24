@IsTest
private class AcctPeriodDeleteEarningsCubesBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testBatchInClosingContext() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAcctPeriod1 = testData.acctPeriods[0];
            Accounting_Period__c testAcctPeriod2 = testData.acctPeriods[1];

            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAcctPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING
                );

            AccountingPeriodDeleteEarningsCubesBatch batchInstance = new AccountingPeriodDeleteEarningsCubesBatch(
                periodDataContainer, new Set<Id>{testAcctPeriod1.Id}, new Set<Id>{testAcctPeriod2.Id}
            );

            Test.startTest();
            Id jobId = Database.executeBatch(batchInstance);
            Test.stopTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM AsyncApexJob WHERE Id = :jobId AND Status = 'Completed']
            );
        }
    }

    @IsTest
    private static void testBatchInOpeningContext() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users.get(1)) {
            Accounting_Period__c testAcctPeriod1 = testData.acctPeriods[0];
            Accounting_Period__c testAcctPeriod2 = testData.acctPeriods[1];

            AccountingPeriodOpenCloseOptions periodDataContainer =
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testAcctPeriod1},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                );

            AccountingPeriodDeleteEarningsCubesBatch batchInstance = new AccountingPeriodDeleteEarningsCubesBatch(
                periodDataContainer, new Set<Id>{testAcctPeriod1.Id}, new Set<Id>{testAcctPeriod2.Id}
            );

            Test.startTest();
            Database.executeBatch(batchInstance);
            Test.stopTest();

            Integer combinedTotal = DomainUtils.getCountCurrentAndRetainedEarnings(
                new Set<Id>{testAcctPeriod1.Id}, new Set<Id>{testAcctPeriod2.Id}
            );
            System.assertEquals(0, combinedTotal);
        }
    }

}