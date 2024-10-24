@IsTest
private class FAnalyticsTemplateHandlerTest {

    @IsTest
    static void testOnConfig() {
        WaveTemplate.WaveTemplateInfo template =
            WaveTemplate.Test.getWaveTemplateInfoForApexTesting(GlobalVariables.PACKAGE_QUALIFIER + 'Accounting_Seed_Financial_Analytics');

        FAnalyticsTemplateHandler templateHandler = new FAnalyticsTemplateHandler();
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_ENABLE_F_ANALYTICS, true);
        Test.startTest();
        //Test the onConfigurationRetrieval method in your Apex Modifier Class
        templateHandler.onConfigurationRetrieval(template);
        System.assertEquals(GlobalVariables.PACKAGE_QUALIFIER + 'Accounting_Seed_Financial_Analytics', template.getApiName());
    }

}