@IsTest
public class BankMappingProviderTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testInitMappingState() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account_Mapping__c testMappingEntry = new GL_Account_Mapping__c(
                External_Id__c = 'EXT_ID',
                GL_Account__c = testData.glAccounts[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );

            insert testMappingEntry;

            System.assertEquals(testData.glAccounts[0].Id, BankMappingProvider.bankGLAccounts[0].Id);
            System.assertEquals(testData.glAccounts[0].Id, BankMappingProvider.mappingStateMap.get('EXT_ID').glAccountId);
            System.assertEquals(testData.ledgers[0].Id, BankMappingProvider.mappingStateMap.get('EXT_ID').ledgerId);
        }

    }

    @IsTest
    public static void testRefreshMappingState() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            GL_Account_Mapping__c testMappingEntry = new GL_Account_Mapping__c(
                External_Id__c = 'EXT_ID',
                GL_Account__c = testData.glAccounts[0].Id,
                Ledger__c = testData.ledgers[0].Id
            );

            insert testMappingEntry;

            Test.startTest();
            BankMappingProvider.refreshMappingState();
            System.assertEquals(testData.glAccounts[0].Id, BankMappingProvider.bankGLAccounts[0].Id);
            System.assertEquals(testData.glAccounts[0].Id, BankMappingProvider.mappingStateMap.get('EXT_ID').glAccountId);
            System.assertEquals(testData.ledgers[0].Id, BankMappingProvider.mappingStateMap.get('EXT_ID').ledgerId);
        }

    }

}