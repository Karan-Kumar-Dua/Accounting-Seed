@IsTest
public class FixedAssetActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }


    @IsTest
    public static void testRequiredFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createFixedAssets();

        System.runAs(testData.users[1]) {
            Fixed_Asset__c fixedAsset = testData.fixedAssets[0].clone(false, true);
            insert fixedAsset;
            fixedAsset.Ledger__c = NULL;
            DMLException dmlEx;
            try {
                update fixedAsset;
            }
            catch(DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));

        }
    }

    @IsTest
    public static void testSetDefaultFieldsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createFixedAssets();

        System.runAs(testData.users[1]) {

            Fixed_Asset__c fixedAsset = testData.fixedAssets[0].clone(false, true);
            insert fixedAsset;

            System.assertEquals(testData.ledgerSettings.Ledger_Id__c, [SELECT Id, Ledger__c FROM Fixed_Asset__c WHERE Id = :fixedAsset.Id].Ledger__c);

        }
    }

    @IsTest
    public static void testFixedAssetNoNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;

                Fixed_Asset__c fa = new Fixed_Asset__c();

                try {
                    insert fa;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        }
        catch (Exception ex) {

        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeToLedgerInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createFixedAssets();//will throw an exception in case of non-MC org
            
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Fixed_Asset__c fixedAsset = testData.fixedAssets[0].clone(false, true);
                fixedAsset.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert fixedAsset;

                Id ledgerId = [SELECT Id, Ledger__c FROM Fixed_Asset__c WHERE Id = :fixedAsset.Id].Ledger__c;

                Ledger__c ledger = Database.query('SELECT Id, CurrencyIsoCode FROM Ledger__c WHERE Id = :ledgerId');

                Id fixedAssetId = fixedAsset.Id;
                fixedAsset = Database.query('SELECT Id, CurrencyIsoCode FROM Fixed_Asset__c WHERE Id = :fixedAssetId');

                System.assertNotEquals(null, fixedAsset);
                System.assertNotEquals(null, fixedAsset.get('CurrencyIsoCode'));
                System.assertEquals(ledger.get('CurrencyIsoCode'), fixedAsset.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyIsoCodeToLedgerUpdate_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createFixedAssets(); //will throw an exception in case of non-MC org
            
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Fixed_Asset__c fixedAsset = testData.fixedAssets[0].clone(false, true);
                insert fixedAsset;
                
                fixedAsset.put('CurrencyIsoCode', newCurrencyIsoCode);
                Ledger__c ledger;

                Id ledgerId = testData.ledgers[0].Id;
                ledger = Database.query('SELECT Id, CurrencyIsoCode FROM Ledger__c WHERE Id = :ledgerId');

                Id fixedAssetId = fixedAsset.Id;
                fixedAsset = Database.query('SELECT Id, CurrencyIsoCode FROM Fixed_Asset__c WHERE Id = :fixedAssetId');

                System.assertNotEquals(null, fixedAsset);
                System.assertNotEquals(null, fixedAsset.get('CurrencyIsoCode'));
                System.assertEquals(ledger.get('CurrencyIsoCode'), fixedAsset.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }
}