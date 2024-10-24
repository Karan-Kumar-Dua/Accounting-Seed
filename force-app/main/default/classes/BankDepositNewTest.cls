@IsTest
public class BankDepositNewTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testBankDepositNewGetGLAccounts() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits();

        System.runAs(testData.users[1]) {
            BankDepositNew bdn = new BankDepositNew(new ApexPages.StandardController(testData.bankDeposits[0]));
            System.assertNotEquals(0, bdn.getGLAccounts().size());
        }
    }
    
    @IsTest
    public static void testSaveBankDepositNewError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits();

        System.runAs(testData.users[1]) {
            BankDepositNew bdn = new BankDepositNew(new ApexPages.StandardController(new Bank_Deposit__c()));
            bdn.bankDeposit.Ledger__c = NULL;
            bdn.bankDeposit.Bank_Account__c = NULL;
            System.assertEquals(NULL, bdn.saveBankDeposit());
            System.assertEquals(true, bdn.isLedgerError);
            System.assertEquals(true, bdn.isGLAccountError);
            System.assertEquals(false, bdn.isDateError);//populated in BankDepositNew constructor
        }
    }
    
    @IsTest
    public static void testSaveBankDepositNewSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDeposits();

        System.runAs(testData.users[1]) {
            Bank_Deposit__c bankDeposit = testData.bankDeposits[0].clone(false, true);
            BankDepositNew bdn = new BankDepositNew(new ApexPages.StandardController(bankDeposit));
            System.assertNotEquals(NULL, bdn.saveBankDeposit());
            System.assertEquals(1, [SELECT count() FROM Bank_Deposit__c WHERE Id = :bdn.bankDeposit.Id]);
        }
    }

    @IsTest
    public static void testSaveBankDepositNewSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createBankDeposits();

            System.runAs(testData.users[1]) {
                Test.startTest();
                Bank_Deposit__c bankDeposit = testData.bankDeposits[0].clone(false, true);

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrency)) {
                    return;
                }

                BankDepositNew bdn = new BankDepositNew(new ApexPages.StandardController(bankDeposit));
                bdn.bankDeposit.put('CurrencyIsoCode', newCurrency);
                System.assertNotEquals(NULL, bdn.saveBankDeposit());
                System.assertEquals(newCurrency,
                    Database.query('SELECT Id, CurrencyIsoCode FROM Bank_Deposit__c WHERE Id = \'' + bdn.bankDeposit.Id + '\'')[0].get('CurrencyIsoCode')
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }

    }

}