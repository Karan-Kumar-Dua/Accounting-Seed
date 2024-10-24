@IsTest
private class FinancialReportResultValueActionsTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSetCurrencyByParentLedger() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createReportDefinitions();

            System.runAs(testData.users.get(1)) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                //Create Ledger with foreign currency
                Ledger__c newLedger = new Ledger__c(
                    Name = 'Actual 3',
                    Type__c = 'Transactional',
                    Default_Bank_Account__c = testData.glAccounts[0].Id,
                    Default_Billing_Format__c = testData.billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                );
                newLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newLedger;

                //Create Financial Report Result
                Financial_Report_Result__c result = new Financial_Report_Result__c(
                    Status__c = 'Completed',
                    Ledger__c = newLedger.Id
                );
                result.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert result;

                //Create new Financial Report Result Values
                List<Financial_Report_Result_Value__c> values = new List<Financial_Report_Result_Value__c>();
                values.add(new Financial_Report_Result_Value__c(
                    Financial_Report_Result__c = result.Id
                ));
                values.add(new Financial_Report_Result_Value__c(
                    Financial_Report_Result__c = result.Id
                ));
                insert values;

                System.assertEquals(values.size(), [SELECT Id FROM Financial_Report_Result_Value__c].size());
                System.assertEquals(
                    newCurrencyIsoCode,
                    Database.query('SELECT Id, CurrencyIsoCode FROM Financial_Report_Result_Value__c').get(0).get('CurrencyIsoCode')
                );
                System.assertEquals(
                    newCurrencyIsoCode,
                    Database.query('SELECT Id, CurrencyIsoCode FROM Financial_Report_Result_Value__c').get(1).get('CurrencyIsoCode')
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }
}