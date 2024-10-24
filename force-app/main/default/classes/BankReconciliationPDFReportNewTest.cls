@IsTest
private class BankReconciliationPDFReportNewTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBankReconciliationPDFReport() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
                testData.bankDeposits[0].Deposit_Date__c = Date.today();
                update testData.bankDeposits[0];
                Bank_Reconciliation2__c brec = [
                    SELECT
                        Id,
                        Uncleared_Amount__c
                    FROM
                        Bank_Reconciliation2__c
                    WHERE
                        Id = :testData.bankReconciliations[0].Id
                    LIMIT 1
                ];

                if (brec.Uncleared_Amount__c > 0) {
                    brec.Cleared_Deposits__c = brec.Uncleared_Amount__c;
                } else if (brec.Uncleared_Amount__c < 0) {
                    brec.Cleared_Disbursements__c = brec.Uncleared_Amount__c;
                }

                update brec;
                BankReconciliation.complete(brec.Id);

            Test.stopTest();

            ApexPages.currentPage().getParameters().put('id', testData.bankReconciliations[0].Id);
            BankReconciliationPDFReportNew brr = new BankReconciliationPDFReportNew();

            System.assertEquals(FinancialSuiteUtils.getDecimalLocaleFormatString(30000, 2), brr.getClearedDepositsString());
            System.assertEquals(FinancialSuiteUtils.getDecimalLocaleFormatString(0, 2), brr.getClearedDisbursementsString());
        }

    }
}