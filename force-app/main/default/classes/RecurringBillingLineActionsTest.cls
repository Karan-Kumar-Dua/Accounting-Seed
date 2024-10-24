@IsTest
public class RecurringBillingLineActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testRevenueGLAccountIsRequiredOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();
        System.runAs(testData.users.get(1)) {
            Recurring_Billing_Line__c recurringBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testData.recurringBillings[0].Id,
                Quantity__c = 2,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[11].Id
            );

            DmlException dmlEx;
            try {
                insert recurringBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULl, dmlEx);

            recurringBillingLine.Revenue_GL_Account__c = NULL;

            try {
                update recurringBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();

        System.runAs(testData.users.get(1)) {

            Recurring_Billing_Line__c billLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testData.recurringBillings[0].Id,
                Rate__c = 20.989342348934,
                Quantity__c = 10.236746723674344,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );

            insert billLine;

            Recurring_Billing_Line__c newBillingLine = [
                SELECT Id,
                    Rate__c,
                    Quantity__c
                FROM Recurring_Billing_Line__c
                WHERE Id = : billLine.Id];

            System.assertEquals(20.989342, newBillingLine.Rate__c);
            System.assertEquals(10.236747, newBillingLine.Quantity__c);
        }

    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling().createRecurringBillingLines();

        System.runAs(testData.users.get(1)) {

            testData.recurringBillingLines[0].Rate__c = 20.989342348934;
            testData.recurringBillingLines[0].Quantity__c = 10.236746723674344;

            update testData.recurringBillingLines[0];

            Recurring_Billing_Line__c newBillingLine = [
                SELECT Id,
                    Rate__c,
                    Quantity__c
                FROM Recurring_Billing_Line__c
                WHERE Id = : testData.recurringBillingLines[0].Id];

            System.assertEquals(20.989342, newBillingLine.Rate__c);
            System.assertEquals(10.236747, newBillingLine.Quantity__c);
        }

    }

    @isTest
    public static void testSetCurrencyFromParent() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createRecurringBilling();

            String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
            if (String.isBlank(newCurrency)) {
                return;
            }
            String testRBId = testData.recurringBillings[0].Id;
            String parentCurrency = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Billing__c WHERE Id = :testRBId')[0].get('CurrencyIsoCode');
            System.assertNotEquals(newCurrency, parentCurrency);

            Recurring_Billing_Line__c rbLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testData.recurringBillings[0].Id,
                Rate__c = 20,
                Quantity__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            );
            rbLine.put('CurrencyIsoCode', newCurrency);

            insert rbLine;

            String lineId = rbLine.Id;
            String lineCurrencyInsert = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Billing_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

            System.assertEquals(parentCurrency, lineCurrencyInsert);

            rbLine.put('CurrencyIsoCode', newCurrency);

            update rbLine;

            String lineCurrencyUpdate = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Billing_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

            System.assertEquals(parentCurrency, lineCurrencyUpdate);
        } catch (TestDataSuite.TestDataSuiteException ex) {
        //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testRecurringBillingLineNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                DMLException dmlEx;
                try {
                    Recurring_Billing_Line__c rbl = new Recurring_Billing_Line__c();
                    insert rbl;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testRecurringBillingLineNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Recurring_Billing_Line__c rbl = new Recurring_Billing_Line__c();
                insert rbl;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testPreventTaxGroup() {       
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .enableAvaTaxCalculation();
		System.runAs(testData.users[1]) {
        Test.startTest();
        Recurring_Billing__c billing = new Recurring_Billing__c(
                Name = 'Test Recurring Billing 1',
                Customer__c = testData.accounts[0].Id,
                Next_Billing_Date__c = Date.newInstance(1991, 12, 31),
                Opportunity__c = testData.opportunities[0].Id,
                Billing_Frequency__c = 'Monthly',
                Status__c = 'Active',
                Billing_Contact__c = testData.contacts[0].Id,
                PO_Number__c = '111111',
                Comment__c = 'test comment 1',
                Ledger__c = testData.ledgers[0].Id
            );
        insert billing;
       
        Recurring_Billing_Line__c bl = new Recurring_Billing_Line__c();
        
                bl.Quantity__c = 2;
                bl.Rate__c = 3446;
                bl.Revenue_GL_Account__c = testData.glAccounts[11].Id;
            
        bl.Tax_Inclusive__c = true;
        bl.Tax_Group__c = testData.taxGroups[0].Id;
        bl.Recurring_Billing__c = billing.Id;
        DMLException dmlEx;

        try {
            insert bl;
            
                bl.Tax_Group__c = testData.taxGroups[0].Id;
            update bl;
        }
        catch (DMLException ex) {
            dmlEx = ex;
        }

        Test.stopTest();
        Assert.isNull(dmlEx);
        }
    }

    @IsTest
    public static void testClearFieldsWhenTaxGroupRemoved() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createRecurringBilling()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Tax_Group__c taxGroup = testData.taxGroups[0];
            taxGroup.Tax_Inclusive__c = true;
            update taxGroup;

            Recurring_Billing_Line__c line = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testData.recurringBillings.get(0).Id,
                Quantity__c = 2,
                Rate__c = 3446,
                Revenue_GL_Account__c = testData.glAccounts[11].Id,
                Tax_Group__c = taxGroup.Id
            );
            insert line;

            line = [SELECT  Tax_Inclusive__c, Combined_Tax_Rate__c FROM Recurring_Billing_Line__c WHERE Id = :line.Id LIMIT 1];
            Assert.areEqual(true, line.Tax_Inclusive__c);
            Assert.isNotNull(line.Combined_Tax_Rate__c);
            Assert.isTrue(line.Combined_Tax_Rate__c > 0);

            line.Tax_Group__c = null;
            update line;

            line = [SELECT  Tax_Inclusive__c, Combined_Tax_Rate__c FROM Recurring_Billing_Line__c WHERE Id = :line.Id LIMIT 1];
            Assert.areEqual(false, line.Tax_Inclusive__c);
            Assert.isNotNull(line.Combined_Tax_Rate__c);
            Assert.areEqual(0, line.Combined_Tax_Rate__c);
            Test.stopTest();
        }

    }

}