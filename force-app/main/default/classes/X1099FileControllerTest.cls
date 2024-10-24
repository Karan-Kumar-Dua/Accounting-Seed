@IsTest
public class X1099FileControllerTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateFileLedgerNotFound() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();
        PageReference testPage = Page.X1099File;
        Test.setCurrentPage(testPage);

        Test.startTest();
        ApexPages.StandardSetController standardSetController = new ApexPages.StandardSetController(testData.cashDisbursements);
        X1099FileController controller = new X1099FileController(standardSetController);
        controller.selectedYear = '2020';
        controller.selectedLedger = NULL;
        PageReference pr = controller.create1099File();

        System.assertEquals(X1099FileController.EMPTY_LEDGER, ApexPages.getMessages()[0].getSummary());
    }

    @IsTest
    public static void testCreateFileSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        testData.accounts[0].X1099_Vendor__c = true;
        update testData.accounts[0];

        testData.contacts[0].X1099_Vendor__c = true;
        update testData.contacts[0];

        PageReference testPage = Page.X1099File;
        Test.setCurrentPage(testPage);

        Test.startTest();
        ApexPages.StandardSetController standardSetController = new ApexPages.StandardSetController(testData.cashDisbursements);
        X1099FileController controller = new X1099FileController(standardSetController);
        controller.selectedYear = '2020';
        controller.selectedLedger = testData.ledgers[0].Id;
        controller.selectedFormType =  [Select Id from Form_Type__mdt WHERE Effective_Year__c <= 2020 limit 1].Id;
        controller.getApplicableFormTypes();
        System.assertEquals(2, controller.availableFormTypes.size());
        System.assertNotEquals(NUll, controller.selectedFormType);
        PageReference pr = controller.create1099File();
        Test.stopTest();

        System.assertEquals(NULL, pr);
    }

    @IsTest
    public static void testCreateFileSuccessMultipleFormTypes() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        testData.accounts[0].X1099_Vendor__c = true;
        update testData.accounts[0];

        testData.contacts[0].X1099_Vendor__c = true;
        update testData.contacts[0];

        PageReference testPage = Page.X1099File;
        Test.setCurrentPage(testPage);

        Test.startTest();
        ApexPages.StandardSetController standardSetController = new ApexPages.StandardSetController(testData.cashDisbursements);
        X1099FileController controller = new X1099FileController(standardSetController);
        controller.selectedYear = '2020';
        controller.selectedLedger = testData.ledgers[0].Id;
        controller.selectedFormType =  [Select Id from Form_Type__mdt WHERE Effective_Year__c >= 2020 limit 1].Id;
        controller.getApplicableFormTypes();
        system.assertEquals(2, controller.availableFormTypes.size());
        system.assertNotEquals(NUll, controller.selectedFormType);
        PageReference pr = controller.create1099File();
        Test.stopTest();

        System.assertEquals(NULL, pr);
    }

}