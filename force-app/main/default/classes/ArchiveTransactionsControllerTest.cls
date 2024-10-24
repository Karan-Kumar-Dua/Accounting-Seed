@IsTest
public class ArchiveTransactionsControllerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testInitialPageLoadNotValidPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c testPeriod = testData.acctPeriods[0];
            ApexPages.StandardController controller = new ApexPages.StandardController(testPeriod);
            ArchiveTransactionsController.testableTodayDate = testData.acctPeriods[4].Start_Date__c.addDays(10);
            ArchiveTransactionsController archiveCntrl = new ArchiveTransactionsController(controller);

            System.assertEquals(true, archiveCntrl.isError);

            //build expected error message
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            String periodOffset = String.valueOf(ArchiveTransactionsController.MOST_RECENT_VALID_PERIOD_OFFSET * -1);
            String validAccountingPeriod = acctPeriodHandler.getAccountingPeriodByOffset(
                acctPeriodHandler.getAccountingPeriodByDate(ArchiveTransactionsController.testableTodayDate).Id,
                ArchiveTransactionsController.MOST_RECENT_VALID_PERIOD_OFFSET
            ).Name;
            //check actual error message
            System.assertEquals(
                String.format(ArchiveTransactionsController.NOT_VALID_PERIOD_ERROR, new List<String>{periodOffset, validAccountingPeriod}),
                ApexPages.getMessages()[0].getSummary()
            );
        }
    }

    @IsTest
    public static void testInitialPageLoadNotValidPriorPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Date acctDate = Date.newInstance(
                testData.acctPeriods[0].Start_Date__c.year(),
                testData.acctPeriods[0].Start_Date__c.month()-18,
                1
            );

            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();

            for (Integer i = 0; i < 18; i++) {

                acctPeriods.add(
                    new Accounting_Period__c(
                        Name = String.valueOf(acctDate.year()) + '-' + (acctDate.month() > 9 ? String.valueOf(acctDate.month()) : '0' + String.valueOf(acctDate.month())),
                        Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                        End_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), Date.daysInMonth(acctDate.year(),acctDate.month())),
                        Status__c = AccountingPeriodActions.OPEN_STATUS
                    )
                );

                if (acctDate.month() == 12) {
                    acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
                }
                else {
                    acctDate = acctDate.addMonths(1);
                }
            }
            insert acctPeriods;

            acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[2].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[3].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[4].Status__c = AccountingPeriodActions.CLOSED_STATUS;

            List<Accounting_Period__c> closedAcctPeriods = new List<Accounting_Period__c>{
                acctPeriods[0], acctPeriods[1], acctPeriods[2], acctPeriods[3], acctPeriods[4]
            };
            update closedAcctPeriods;

            Test.stopTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(acctPeriods[1]);
            ArchiveTransactionsController.testableTodayDate = testData.acctPeriods[4].Start_Date__c.addDays(10);
            ArchiveTransactionsController archiveCntrl = new ArchiveTransactionsController(controller);

            System.assertEquals(true, archiveCntrl.isError);
            System.assertEquals(ArchiveTransactionsController.PRIOR_PERIOD_NOT_ARCHIVED_ERROR, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testInitialPageLoadSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Date acctDate = Date.newInstance(
                testData.acctPeriods[0].Start_Date__c.year(),
                testData.acctPeriods[0].Start_Date__c.month()-18,
                1
            );

            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();

            for (Integer i = 0; i < 18; i++) {

                acctPeriods.add(
                    new Accounting_Period__c(
                        Name = String.valueOf(acctDate.year()) + '-' + (acctDate.month() > 9 ? String.valueOf(acctDate.month()) : '0' + String.valueOf(acctDate.month())),
                        Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                        End_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), Date.daysInMonth(acctDate.year(),acctDate.month())),
                        Status__c = AccountingPeriodActions.OPEN_STATUS
                    )
                );

                if (acctDate.month() == 12) {
                    acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
                }
                else {
                    acctDate = acctDate.addMonths(1);
                }
            }
            insert acctPeriods;

            acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[2].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[3].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[4].Status__c = AccountingPeriodActions.CLOSED_STATUS;

            List<Accounting_Period__c> closedAcctPeriods = new List<Accounting_Period__c>{
                acctPeriods[0], acctPeriods[1], acctPeriods[2], acctPeriods[3], acctPeriods[4]
            };
            update closedAcctPeriods;

            Test.stopTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(acctPeriods[0]);
            ArchiveTransactionsController.testableTodayDate = testData.acctPeriods[4].Start_Date__c.addDays(10);
            ArchiveTransactionsController archiveCntrl = new ArchiveTransactionsController(controller);

            System.assertEquals(false, archiveCntrl.isError);
        }
    }

    @IsTest
    public static void testInitialPageLoadNotValidConsolidationJob() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Date acctDate = Date.newInstance(
                testData.acctPeriods[0].Start_Date__c.year(),
                testData.acctPeriods[0].Start_Date__c.month()-18,
                1
            );

            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();

            for (Integer i = 0; i < 18; i++) {

                acctPeriods.add(
                    new Accounting_Period__c(
                        Name = String.valueOf(acctDate.year()) + '-' + (acctDate.month() > 9 ? String.valueOf(acctDate.month()) : '0' + String.valueOf(acctDate.month())),
                        Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                        End_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), Date.daysInMonth(acctDate.year(),acctDate.month())),
                        Status__c = AccountingPeriodActions.OPEN_STATUS
                    )
                );

                if (acctDate.month() == 12) {
                    acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
                }
                else {
                    acctDate = acctDate.addMonths(1);
                }
            }
            insert acctPeriods;

            acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[2].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[3].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[4].Status__c = AccountingPeriodActions.CLOSED_STATUS;

            List<Accounting_Period__c> closedAcctPeriods = new List<Accounting_Period__c>{
                acctPeriods[0], acctPeriods[1], acctPeriods[2], acctPeriods[3], acctPeriods[4]
            };
            update closedAcctPeriods;

            Test.stopTest();
            Database.executeBatch(
                new ConsolidationRoutineBatch(new LedgerHierarchyModel(testData.ledgerHierarchies[2]), testData.acctPeriods.get(1).Id, true)
            );
            ApexPages.StandardController controller = new ApexPages.StandardController(acctPeriods[0]);
            ArchiveTransactionsController.testableTodayDate = testData.acctPeriods[4].Start_Date__c.addDays(10);
            ArchiveTransactionsController archiveCntrl = new ArchiveTransactionsController(controller);

            System.assertEquals(true, archiveCntrl.isError);

            System.assertEquals(
                AccountingPeriodActions.CONSOLIDATION_IN_PROGRESS_ERROR,
                ApexPages.getMessages()[0].getSummary()
            );
        }
    }

    @IsTest
    public static void testInitialPageLoadNotValidConsolidationJobAfterRun() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Date acctDate = Date.newInstance(
                testData.acctPeriods[0].Start_Date__c.year(),
                testData.acctPeriods[0].Start_Date__c.month()-18,
                1
            );

            List<Accounting_Period__c> acctPeriods = new List<Accounting_Period__c>();

            for (Integer i = 0; i < 18; i++) {

                acctPeriods.add(
                    new Accounting_Period__c(
                        Name = String.valueOf(acctDate.year()) + '-' + (acctDate.month() > 9 ? String.valueOf(acctDate.month()) : '0' + String.valueOf(acctDate.month())),
                        Start_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), 1),
                        End_Date__c = Date.newInstance(acctDate.year(), acctDate.month(), Date.daysInMonth(acctDate.year(),acctDate.month())),
                        Status__c = AccountingPeriodActions.OPEN_STATUS
                    )
                );

                if (acctDate.month() == 12) {
                    acctDate = Date.newInstance(acctDate.year() + 1, 1, 1);
                }
                else {
                    acctDate = acctDate.addMonths(1);
                }
            }
            insert acctPeriods;

            acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[1].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[2].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[3].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            acctPeriods[4].Status__c = AccountingPeriodActions.CLOSED_STATUS;

            List<Accounting_Period__c> closedAcctPeriods = new List<Accounting_Period__c>{
                acctPeriods[0], acctPeriods[1], acctPeriods[2], acctPeriods[3], acctPeriods[4]
            };
            update closedAcctPeriods;

            Test.stopTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(acctPeriods[0]);
            ArchiveTransactionsController.testableTodayDate = testData.acctPeriods[4].Start_Date__c.addDays(10);
            ArchiveTransactionsController archiveCntrl = new ArchiveTransactionsController(controller);

            System.assertEquals(false, archiveCntrl.isError);
            Database.executeBatch(
                new ConsolidationRoutineBatch(new LedgerHierarchyModel(testData.ledgerHierarchies[2]), testData.acctPeriods.get(1).Id, true)
            );

            ArchiveTransactionsController.ArchiveResult result = archiveCntrl.archive(testData.acctPeriods.get(1).Id);

            System.assertEquals(
                AccountingPeriodActions.CONSOLIDATION_IN_PROGRESS_ERROR,
                result.message
            );
        }
    }

}