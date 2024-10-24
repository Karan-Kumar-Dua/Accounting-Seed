@IsTest
public class PrintchecksComponentTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testPrintchecksComponentCashDisbursement() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            PrintchecksComponent pcc = new PrintchecksComponent();
            pcc.setCashDisbursementId(testData.cashDisbursements[0].Id);

            System.assertEquals(1, pcc.cashDisbursementWrapperList.size());
        }

    } 

    @IsTest          
    public static void testPrintchecksComponentCashDisbursementBatch() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            PrintchecksComponent pcc = new PrintchecksComponent();
            pcc.setCashDisbursementBatchId(testData.cashDisbursementBatch[0].Id);

            System.assertEquals(3, pcc.cashDisbursementWrapperList.size());
        }

    } 

    @IsTest    
    public static void testPrintchecksComponentGetMethods() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            PrintchecksComponent pcc = new PrintchecksComponent();
            System.assertEquals(PrintchecksComponent.DATE_TOP_POSITION, pcc.getDateTopOffset());
            System.assertEquals(PrintchecksComponent.DATE_RIGHT_POSITION, pcc.getDateRightOffset());

            System.assertEquals(PrintchecksComponent.AMOUNT_TOP_POSITION, pcc.getAmountTopOffset());
            System.assertEquals(PrintchecksComponent.AMOUNT_RIGHT_POSITION, pcc.getAmountRightOffset());

            System.assertEquals(PrintchecksComponent.AMOUNT_WORDS_TOP_POSITION, pcc.getAmountWordsTopOffset());
            System.assertEquals(PrintchecksComponent.AMOUNT_WORDS_LEFT_POSITION, pcc.getAmountWordsLeftOffset());

            System.assertEquals(PrintchecksComponent.PAYEE_TOP_POSITION, pcc.getPayeeTopOffset());
            System.assertEquals(PrintchecksComponent.PAYEE_LEFT_POSITION, pcc.getPayeeLeftOffset());

            System.assertEquals(PrintchecksComponent.PAYEE_ADDRESS_TOP_POSITION, pcc.getPayeeAddressTopOffset());
            System.assertEquals(PrintchecksComponent.PAYEE_ADDRESS_LEFT_POSITION, pcc.getPayeeAddressLeftOffset());

            System.assertEquals(PrintchecksComponent.MEMO_TOP_POSITION, pcc.getMemoTopOffset());
            System.assertEquals(PrintchecksComponent.MEMO_LEFT_POSITION, pcc.getMemoLeftOffset());
        }

    }

}