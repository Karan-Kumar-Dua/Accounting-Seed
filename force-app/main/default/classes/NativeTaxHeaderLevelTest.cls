@IsTest
private class NativeTaxHeaderLevelTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSetTaxAmountByTaxGroupAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
                Tax_Settings__c actualSetting = new Tax_Settings__c();
                actualSetting.Tax_Settings_Method__c = TaxSettingsActions.NATIVE_TAX_METHOD;
                insert actualSetting;

                Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
                selectedLedger.Tax_Settings__c = actualSetting.Id;
                update selectedLedger;

                Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 50,
                    Date__c = System.today(),
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                    Product__c = testData.products[7].Id
                );
                insert testPayableLine;

                //re-query the line
                testPayableLine = [SELECT Id, Unit_Cost__c, Tax_Group__c, Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :testPayableLine.Id];

                System.assertEquals(testData.taxGroups.get(1).Id, testPayableLine.Tax_Group__c);
                System.assertEquals(testPayableLine.Unit_Cost__c * testData.taxRates[1].Tax_Rate__c / 100, testPayableLine.Tax_Amount__c);

                testPayableLine.Tax_Amount__c = 23;//this will initiate Tax Amount recalculation
                update testPayableLine;
                //expected: despite of directly set Tax Amount value - it will be recalculated by trigger based on Tax Group
                System.assertEquals(
                    testPayableLine.Unit_Cost__c * testData.taxRates[1].Tax_Rate__c / 100,
                    [SELECT Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :testPayableLine.Id].Tax_Amount__c
                );
            Test.stopTest();
        }
    }
}