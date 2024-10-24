@IsTest
public class TaxDispatcherExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }


    @IsTest
    public static void testDispatcherWhenAvalaraTaxCalculationDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users.get(1)) {
            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            Billing__c testBilling = testData.billings[0];

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpportunity);
            TaxDispatcherExt controller = new TaxDispatcherExt(stdController);
            PageReference pr = controller.redirectTo();
            System.assertEquals(pr.getUrl(), TaxDispatcherExt.FS_OPPORTUNITY_SALES_TAX_PAGE.getURL());

            stdController = new ApexPages.StandardController(testBilling);
            controller = new TaxDispatcherExt(stdController);
            pr = controller.redirectTo();
            System.assertEquals(pr.getUrl(), TaxDispatcherExt.FS_BILLING_SALES_TAX_PAGE.getURL());
        }
    }

    @IsTest
    public static void testDispatcherWhenAvalaraTaxCalculationEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation().createBillings();
        System.runAs(testData.users.get(1)) {
            Opportunity testOpportunity = new Opportunity(
                Name = 'TestOpp',
                AccountId = testData.accounts[0].Id,
                CloseDate = Date.today(),
                StageName = 'Closed Won'
            );
            insert testOpportunity;

            Billing__c testBilling = testData.billings[0];
            testBilling.Ledger__c = testData.ledgers[0].Id;
            update testBilling;

            Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(testOpportunity);
            TaxDispatcherExt controller = new TaxDispatcherExt(stdController);
            PageReference pr = controller.redirectTo();
            System.assertEquals(pr.getUrl(), TaxDispatcherExt.AVALARA_OPPORTUNITY_SALES_TAX_PAGE.getURL());

            stdController = new ApexPages.StandardController(testBilling);
            controller = new TaxDispatcherExt(stdController);
            pr = controller.redirectTo();
            System.assertEquals(pr.getUrl(), TaxDispatcherExt.AVALARA_BILLING_SALES_TAX_PAGE.getURL());
        }
    }

}