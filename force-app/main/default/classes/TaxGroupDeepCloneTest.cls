@IsTest
private class TaxGroupDeepCloneTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testTaxGroupClone() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Tax_Group__c sourceTaxGroup = testData.taxGroups[0];

            Test.startTest();
            Id clonedTaxGroup = TaxGroupDeepClone.deepClone(sourceTaxGroup.Id, 'Cloned TG');
            List<Tax_Group__c> clonedTGs = [
                SELECT Id, Name, (SELECT Id FROM Tax_Rates__r)
                FROM Tax_Group__c
                WHERE Name = 'Cloned TG'
            ];
            System.assertNotEquals(true, clonedTGs.isEmpty());
            System.assertNotEquals(true, clonedTGs[0].Tax_Rates__r.isEmpty());
        }

    }

}