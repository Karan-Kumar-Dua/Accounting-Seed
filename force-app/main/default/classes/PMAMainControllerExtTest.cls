@IsTest
private class PMAMainControllerExtTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testRedirectToStripeSettings() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            PageReference pageRef = Page.PMAMain;
            Test.setCurrentPage(pageRef);

            PMAMainControllerExt ctrl = new PMAMainControllerExt();
            PageReference page = ctrl.redirectToStripeSettings();
            System.assert(page.getRedirect());
            System.assertEquals('/lightning/n/' + GlobalVariables.PACKAGE_QUALIFIER + 'Stripe_Settings', page.getUrl());
        }
    }

    @IsTest
    private static void testRedirectToStripeSettingsFalse() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            PageReference pageRef = Page.PMAMain;
            Test.setCurrentPage(pageRef);
            ApexPages.currentPage().getParameters().put('redirect', 'false');

            PMAMainControllerExt ctrl = new PMAMainControllerExt();
            PageReference page = ctrl.redirectToStripeSettings();
            System.assertEquals(null, page);
        }
    }

}