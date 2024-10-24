@IsTest
public class BankRecCalculatorHelperTest {
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetMultiCurrencyStatusSameCurrencies_nonMC() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        System.runAs(testData.users[1]) {
            Test.startTest();

            Bank_Reconciliation2__c brec = new Bank_Reconciliation2__c(
                End_Date__c = testData.acctPeriods[0].Start_Date__c+30,
                Bank_Account__c = testData.glAccounts[0].Id,
                Beginning_Balance__c = 20000,
                Ending_Balance__c = 20000,
                Cleared_Disbursements__c = 0,
                Cleared_Deposits__c = 0,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert brec;

            BankRecCalculatorHelper.BRECResponse result = BankRecCalculatorHelper.getMultiCurrencyStatus(brec.Id);
            System.assertEquals(result.isSuccess, true);
            System.assertEquals(result.currencyMismatch, false);
            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testGetMultiCurrencyStatusSameCurrencies_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            
            System.runAs(testData.users[1]) {
                Test.startTest();

                Bank_Reconciliation2__c brec = new Bank_Reconciliation2__c(
                    End_Date__c = testData.acctPeriods[0].Start_Date__c+30,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 20000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                );            
                insert brec;

                BankRecCalculatorHelper.BRECResponse result = BankRecCalculatorHelper.getMultiCurrencyStatus(brec.Id);
                System.assertEquals(result.isSuccess, true);
                System.assertEquals(result.currencyMismatch, false);
                Test.stopTest();
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testGetMultiCurrencyStatusError_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            
            System.runAs(testData.users[1]) {
                Test.startTest();

                //use a fake bank rec id to cause it to error
                BankRecCalculatorHelper.BRECResponse result = BankRecCalculatorHelper.getMultiCurrencyStatus('a0B3B000008V3NUUA0');
                System.assertEquals(result.isSuccess, false);            
                Test.stopTest();
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testGetMultiCurrencyStatusDifferentCurrencies_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            
            System.runAs(testData.users[1]) {
                Test.startTest();

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();

                Bank_Reconciliation2__c brec = new Bank_Reconciliation2__c(
                    End_Date__c = testData.acctPeriods[0].Start_Date__c+30,
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Beginning_Balance__c = 20000,
                    Ending_Balance__c = 20000,
                    Cleared_Disbursements__c = 0,
                    Cleared_Deposits__c = 0,
                    Type__c = BankReconciliation.BANK_TYPE
                );
                brec.put('CurrencyIsoCode', newCurrency);
                insert brec;

                BankRecCalculatorHelper.BRECResponse result = BankRecCalculatorHelper.getMultiCurrencyStatus(brec.Id);
                System.assertEquals(result.isSuccess, true);
                System.assertEquals(result.currencyMismatch, true);
                Test.stopTest();
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }
}