@IsTest
private class AvaTaxHeaderLevelTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSetTaxAmountIfTaxGroupPopulatedButAvalaraIsEnabledBL() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createTaxGroups();
        Test.startTest();
        testData.createBillings(false);
        testData.enableAvaTaxCalculation();
        testData.createAddressObjects();

        System.runAs(testData.users[1]) {
            AvaTax_License__c newLicense = new AvaTax_License__c();
            newLicense.Active_AvaTax_Endpoint__c = 'testEndpoint';
            newLicense.AvaTax_Account_ID__c = 'testId';
            newLicense.AvaTax_License_Key__c = 'testKey';
            insert newLicense;

            Tax_Settings__c actualSetting = new Tax_Settings__c();
            actualSetting.Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
            actualSetting.Origin_Address__c = testData.addressObjects[0].Id;
            actualSetting.Sales_Tax_GL_Account__c = testData.glAccounts[15].Id;
            actualSetting.AvaTax_License__c = newLicense.Id;
            insert actualSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = actualSetting.Id;
            selectedLedger.Sales_Tax_Company_Code__c = 'testCode';
            update selectedLedger;

            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Tax_Group__c = testData.taxGroups[0].Id
            );
            insert billingLine;

            //since we are in Avalara Mode - Tax Group field will be cleared
            System.assertEquals(
                0,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );
        }
    }

    @IsTest
    private static void testSetTaxAmountIfTaxGroupPopulatedButAvalaraIsEnabledPayable() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createTaxGroups();
        Test.startTest();
        testData.createPayables(false);
        testData.enableAvaTaxCalculation();
        testData.createAddressObjects();

        System.runAs(testData.users[1]) {
            AvaTax_License__c newLicense = new AvaTax_License__c();
            newLicense.Active_AvaTax_Endpoint__c = 'testEndpoint';
            newLicense.AvaTax_Account_ID__c = 'testId';
            newLicense.AvaTax_License_Key__c = 'testKey';
            insert newLicense;

            Tax_Settings__c actualSetting = new Tax_Settings__c();
            actualSetting.Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
            actualSetting.Origin_Address__c = testData.addressObjects[0].Id;
            actualSetting.Sales_Tax_GL_Account__c = testData.glAccounts[15].Id;
            actualSetting.AvaTax_License__c = newLicense.Id;
            insert actualSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = actualSetting.Id;
            selectedLedger.Sales_Tax_Company_Code__c = 'testCode';
            update selectedLedger;

            Account_Payable_Line__c payableLine = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Unit_Cost__c = 50,
                Tax_Group__c = testData.taxGroups[1].Id,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            insert payableLine;
            Test.stopTest();

            //skip Avalara Mode for Payables - Tax Group and Tax Amount field will be populated
            System.assertEquals(
                2.5,
                [SELECT Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :payableLine.Id].Tax_Amount__c
            );
        }
    }

    @IsTest
    private static void testSetTaxAmountIfTaxGroupPopulatedButAvalaraIsEnabledRecPayable() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createTaxGroups();
        Test.startTest();
        testData.createRecurringAccountPayables();
        testData.enableAvaTaxCalculation();
        testData.createAddressObjects();

        System.runAs(testData.users[1]) {
            AvaTax_License__c newLicense = new AvaTax_License__c();
            newLicense.Active_AvaTax_Endpoint__c = 'testEndpoint';
            newLicense.AvaTax_Account_ID__c = 'testId';
            newLicense.AvaTax_License_Key__c = 'testKey';
            insert newLicense;

            Tax_Settings__c actualSetting = new Tax_Settings__c();
            actualSetting.Tax_Settings_Method__c = TaxSettingsActions.AVA_TAX_METHOD;
            actualSetting.Origin_Address__c = testData.addressObjects[0].Id;
            actualSetting.Sales_Tax_GL_Account__c = testData.glAccounts[15].Id;
            actualSetting.AvaTax_License__c = newLicense.Id;
            insert actualSetting;

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);
            selectedLedger.Tax_Settings__c = actualSetting.Id;
            selectedLedger.Sales_Tax_Company_Code__c = 'testCode';
            update selectedLedger;

            testData.recurringPayables[0].Ledger__c = selectedLedger.Id;
            update testData.recurringPayables[0];

            Recurring_Account_Payable_Line__c recPayLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c= testData.recurringPayables.get(0).Id,
                Quantity__c = 1,
                Unit_Cost__c = 50,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Internal_Comment__c = 'test comment 1',
                Tax_Group__c = testData.taxGroups[1].Id
            );
            insert recPayLine;

            //skip Avalara Mode for Rec Payables - Tax Group and Tax Amount field will be populated
            System.assertEquals(
                2.5,
                [SELECT Tax_Amount__c FROM Recurring_Account_Payable_Line__c WHERE Id = :recPayLine.Id].Tax_Amount__c
            );
            System.assertEquals(
                testData.taxGroups[1].Id,
                [SELECT Tax_Group__c FROM Recurring_Account_Payable_Line__c WHERE Id = :recPayLine.Id].Tax_Group__c
            );
        }
    }
}