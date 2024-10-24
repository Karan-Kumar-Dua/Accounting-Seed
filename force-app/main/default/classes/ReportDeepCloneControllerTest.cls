@IsTest
private class ReportDeepCloneControllerTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testNoReportNameError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.reportDefs.get(0));
            ReportDeepCloneController repClone = new ReportDeepCloneController(controller);

            //No new report name
            repClone.deepClone();
            System.assertEquals(ReportDeepCloneController.NO_REPORT_NAME_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    private static void testCloneReportNoRowsAndColsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.reportDefs.get(0));
            ReportDeepCloneController repClone = new ReportDeepCloneController(controller);

            repClone.newReportName = 'New Report For Testing';
            repClone.newReportDescription = 'Blah';
            repClone.cloneCols = false;
            repClone.cloneRows = false;
            repClone.deepClone();

            System.assertEquals(
                1,
                [SELECT count() FROM Financial_Report_Definition__c WHERE Id = :repClone.newReportDef.Id]
            );
            System.assertEquals(
                0,
                [SELECT count() FROM Financial_Report_Column__c WHERE Financial_Report_Definition__c = :repClone.newReportDef.Id]
            );
            System.assertEquals(
                0,
                [SELECT count() FROM Financial_Report_Row__c WHERE Financial_Report_Definition__c = :repClone.newReportDef.Id]
            );
        }
    }

    @IsTest
    private static void testCloneReportSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportColumns()
            .createReportRows();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.reportDefs.get(0));
            ReportDeepCloneController repClone = new ReportDeepCloneController(controller);

            repClone.newReportName = 'New Report For Testing';
            repClone.newReportDescription = 'Blah';

            repClone.deepClone();

            System.assertEquals(
                1,
                [SELECT count() FROM Financial_Report_Definition__c WHERE Id = :repClone.newReportDef.Id]
            );
            System.assertEquals(
                6,
                [SELECT count() FROM Financial_Report_Column__c WHERE Financial_Report_Definition__c = :repClone.newReportDef.Id]
            );
            System.assertEquals(
                9,
                [SELECT count() FROM Financial_Report_Row__c WHERE Financial_Report_Definition__c = :repClone.newReportDef.Id]
            );
        }
    }

}