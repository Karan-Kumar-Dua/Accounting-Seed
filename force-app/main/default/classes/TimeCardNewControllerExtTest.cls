@IsTest
public class TimeCardNewControllerExtTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testTimeCardNewControllerExtPeriodAndEmployeeError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // Call the method being tested
            ApexPages.StandardController controller = new ApexPages.StandardController(new Time_Card__c());
            TimeCardNewControllerExt tdc = new TimeCardNewControllerExt(controller);
            tdc.timeCard.Employee__c = NULL;
            tdc.timeCard.Ledger__c = NULL;
            tdc.saveback();

            System.assertEquals(true, tdc.isPeriodError);
            System.assertEquals(true, tdc.isEmployeeError);
            System.assertEquals(true, tdc.isLedgerError);
        }

    }

    @isTest
    public static void testTimeCardNewControllerExtTimeCardPeriodList() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            // Call the method being tested
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.timeCards[0]);
            TimeCardNewControllerExt tdc = new TimeCardNewControllerExt(controller);

            for (SelectOption so : tdc.getTimeCardPeriods()) {
                System.assertNotEquals(testData.timeCards[0].Time_Card_Period__c, so.getValue());
            }
        }

    }

    @isTest
    public static void testTimeCardNewControllerExtInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createProjects().createProjectTasks().createTimeCards();

        System.runAs(testData.users.get(1)) {
            delete testData.timeCards;
            Test.startTest();

            ApexPages.StandardController controller = new ApexPages.StandardController(new Time_Card__c());
            TimeCardNewControllerExt tdc = new TimeCardNewControllerExt(controller);

            System.assertNotEquals(true, tdc.getTimeCardPeriods().isEmpty());

            tdc.timeCard.Time_Card_Period__c = tdc.getTimeCardPeriods()[1].getValue();
            tdc.saveback();

            List<Time_Card__c> newTimeCards = [SELECT Id, Status__c FROM Time_Card__c WHERE Id = :tdc.timeCard.Id];
            System.assertNotEquals(true, newTimeCards.isEmpty());
            String postingStatus = FinancialSuiteUtils.getDefaultPostingStatus(Time_Card__c.Status__c);
            System.assertEquals(postingStatus, newTimeCards.get(0).Status__c);
        }
    }

    @isTest
    public static void testGetAllLedgerPositive() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(new Time_Card__c());
            TimeCardNewControllerExt controller = new TimeCardNewControllerExt(stdController);
            System.assertNotEquals(true, controller.getTimeCardPeriods().isEmpty());

            List<SelectOption> opts = controller.allLedgersSelectOptions;
            System.assertEquals(4, opts.size());//number of Transactional Ledgers
        }
    }

    @isTest
    public static void testGetAllLedgerNegative() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            delete testData.ledgers[2];//remove one of Transactional Ledgers

            ApexPages.StandardController stdController = new ApexPages.StandardController(new Time_Card__c());
            TimeCardNewControllerExt controller = new TimeCardNewControllerExt(stdController);
            System.assertNotEquals(true, controller.getTimeCardPeriods().isEmpty());

            List<SelectOption> opts = controller.allLedgersSelectOptions;
            System.assertEquals(3, opts.size());//number of Transactional Ledgers
        }
    }

}