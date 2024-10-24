@IsTest
public class FinancialReportResultDeleteTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testDeleteFinancialReportResultsNoSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            FinancialReportResultDelete frd = new FinancialReportResultDelete(
                new ApexPages.StandardSetController(new List<Financial_Report_Result__c>())
            );
            System.assertEquals(
                FinancialReportResultDelete.NO_SELECTION_ERROR_MESSAGE,
                ApexPages.getMessages()[0].getDetail()
            );
        }

    }

    @IsTest
    public static void testDeleteFinancialReportResultsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createReportDefinitions();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Financial_Report_Result__c firstFrr = new Financial_Report_Result__c();
            firstFrr.Financial_Report_Definition__c = testData.reportDefs[0].Id;
            firstFrr.Accounting_Period__c = testData.acctPeriods[0].Id;
            firstFrr.Run_Started__c = System.now()-10;
            firstFrr.Run_Finished__c = System.now();
            firstFrr.Status__c = 'Complete';
            insert firstFrr;

            List<Financial_Report_Result__c> reportResults = new List<Financial_Report_Result__c>();
            for (Integer i = 0; i <= 17; i++) {
                Financial_Report_Result__c frr = new Financial_Report_Result__c();
                frr.Financial_Report_Definition__c = testData.reportDefs[0].Id;
                frr.Accounting_Period__c = testData.acctPeriods[0].Id;
                frr.Run_Started__c = System.now() - i;
                frr.Run_Finished__c = System.now();
                frr.Status__c = 'Complete';
                reportResults.add(frr);
            }

            insert reportResults;

            reportResults.add(firstFrr);
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(reportResults);

            for (Integer i = 0; i <= 16; i++) {
                setController.setSelected(new Financial_Report_Result__c[]{reportResults[i]});
            }

            FinancialReportResultDelete frd = new FinancialReportResultDelete(setController);
            System.assertEquals(true, frd.isValidationPassed);

            PageReference pr = frd.deleteRecords();

            System.assertEquals(1, [SELECT count() FROM Financial_Report_Result__c WHERE Id = :firstFrr.Id]);
            System.assertEquals(FinancialReportResultDelete.OPERATION_SUCCESS_MESSAGE, ApexPages.getMessages()[1].getDetail());
            System.assertEquals(false, frd.isValidationPassed);//check Delete button is hidden
        }

    }

}