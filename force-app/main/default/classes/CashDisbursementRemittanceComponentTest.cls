@isTest
public class CashDisbursementRemittanceComponentTest {

    public static testMethod void testNullCashDisbursement() {
        CashDisbursementRemittanceComponent cmp = new CashDisbursementRemittanceComponent();
        
        Test.startTest();
            System.assertNotEquals(NULL, cmp.cCashDisbursement);
        Test.stopTest();
    }
}