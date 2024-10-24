@isTest
private class FastLinkHandlerTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testConstructorWithCreateParameters() {
        TestDataSuite testData = TestDataSuite.getInstance();
        

        System.runAs(testData.users[1]) {
            Test.startTest();
            PageReference pageRef = Page.FastLink;
            Test.setCurrentPage(pageRef);
            FastLinkHandler controller = new FastLinkHandler();
            Test.stopTest();
            FastLinkHandler.FastLinkConfigModel properties =
                (FastLinkHandler.FastLinkConfigModel) JSON.deserialize(
                                                                        controller.fastLinkProperties, 
                                                                        FastLinkHandler.FastLinkConfigModel.class);
            System.assertNotEquals('', properties.jwtToken);
            System.assertEquals(NULL, properties.params.providerAccountId); 
        }
    }

    @isTest
    private static void testConstructorWithEditParameters() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            PageReference pageRef = Page.FastLink;
            pageRef.getParameters().put('params', '11111');
            pageRef.getParameters().put('action', 'edit');
            Test.setCurrentPage(pageRef);
            FastLinkHandler controller = new FastLinkHandler();
            Test.stopTest();
            FastLinkHandler.FastLinkConfigModel properties =
                (FastLinkHandler.FastLinkConfigModel) JSON.deserialize(
                                                                        controller.fastLinkProperties, 
                                                                        FastLinkHandler.FastLinkConfigModel.class);
            System.assertNotEquals('', properties.jwtToken);
            System.assertEquals('11111', properties.params.providerAccountId); 
            System.assertEquals('edit', properties.params.flow);
        }
    }

    @isTest
    private static void testConstructorWithRefreshParameters() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            Test.startTest();
            PageReference pageRef = Page.FastLink;
            pageRef.getParameters().put('params', '11111');
            pageRef.getParameters().put('action', 'refresh');
            Test.setCurrentPage(pageRef);
            FastLinkHandler controller = new FastLinkHandler();
            Test.stopTest();
            FastLinkHandler.FastLinkConfigModel properties =
                (FastLinkHandler.FastLinkConfigModel) JSON.deserialize(
                                                                        controller.fastLinkProperties, 
                                                                        FastLinkHandler.FastLinkConfigModel.class);
            System.assertNotEquals('', properties.jwtToken);
            System.assertEquals('11111', properties.params.providerAccountId); 
            System.assertEquals('refresh', properties.params.flow);
        }
    }

}