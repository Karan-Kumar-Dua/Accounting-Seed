@IsTest
private class BankAccountHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testUploadSignature() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();
        System.runAs(testData.users[1]) {
            BankAccountHelper.BankAccountSignatureWrapper bankAccSignDetails = new BankAccountHelper.BankAccountSignatureWrapper();
            bankAccSignDetails.signature_file_name = 'Testing';
            bankAccSignDetails.base64_of_signature_file = 'Testing';
            bankAccSignDetails.record_id = testData.bankAccounts[0].Id;
            bankAccSignDetails.external_id = 'Test-1';
            BankAccountHelper.uploadSignature(JSON.serialize(bankAccSignDetails));

            Bank_Account__c ba = [SELECT Id, Signature_Block__c FROM Bank_Account__c WHERE Id = :testData.bankAccounts[0].Id];
            Assert.areEqual('Test-1',ba.Signature_Block__c);
        }
    }

    @IsTest
    static void testUploadSignatureError() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, True);
        TestDataSuite testData = TestDataSuite.getInstance().createBankAccounts();
        System.runAs(testData.users[1]) {
            BankAccountHelper.BankAccountSignatureWrapper bankAccSignDetails = new BankAccountHelper.BankAccountSignatureWrapper();
            bankAccSignDetails.signature_file_name = 'Testing';
            bankAccSignDetails.base64_of_signature_file = 'Testing';
            bankAccSignDetails.external_id = 'Test-1';

            try {
                BankAccountHelper.uploadSignature(JSON.serialize(bankAccSignDetails));
            }
            catch(Exception e) {
                Assert.areEqual('There is an error linking a signature to your Bank Account.',e.getMessage());
            }
        }
    }
}