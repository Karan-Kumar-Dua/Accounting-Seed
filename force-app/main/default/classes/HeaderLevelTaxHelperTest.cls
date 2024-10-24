@IsTest
private class HeaderLevelTaxHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSetTaxAmountIfNoTaxGroupAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Amount__c = 45,
                Date__c = System.today(),
                Expense_GL_Account__c = testData.glAccounts.get(12).Id
            );
            insert testPayableLine;

            System.assertEquals(
                0,
                [SELECT Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :testPayableLine.Id].Tax_Amount__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSetTaxGroupFromProductAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable_Line__c accountPayableLines = new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 45,
                    Date__c = System.today(),
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                    Product__c = testData.products[7].Id
                );

            insert accountPayableLines;

            System.assertEquals(
                testData.taxGroups.get(1).Id,
                [SELECT Tax_Group__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.Id].Tax_Group__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSetTaxAmountByTaxGroupAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
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

    @IsTest
    private static void testSetTaxAmountByAmountFieldAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Amount__c = 50,
                Date__c = System.today(),
                Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                Product__c = testData.products[7].Id
            );

            DmlException dmlEx;
            try {
                insert testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(PayableLineActions.MATH_DOSNT_WORK, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testUpdateTaxAmountByAmountFieldAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Unit_Cost__c = 50,
                Date__c = System.today(),
                Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                Product__c = testData.products[7].Id
            );
            insert testPayableLine;

            //re-query the line
            testPayableLine = [SELECT Id, Unit_Cost__c, Amount__c, Tax_Group__c, Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :testPayableLine.Id];

            System.assertEquals(testData.taxGroups.get(1).Id, testPayableLine.Tax_Group__c);
            System.assertEquals(testPayableLine.Unit_Cost__c * testData.taxRates[1].Tax_Rate__c / 100, testPayableLine.Tax_Amount__c);

            DmlException dmlEx;
            try {
                testPayableLine.Amount__c = 150;
                update testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(PayableLineActions.TOTAL_FIELD_POPULATED_UPDATE_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testUpdateTaxAmountByTaxGroupFieldAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
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

            testPayableLine.Tax_Group__c = testData.taxGroups.get(1).Id;
            update testPayableLine;

            System.assertEquals(
                testPayableLine.Unit_Cost__c * testData.taxRates[1].Tax_Rate__c / 100,
                [SELECT Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :testPayableLine.Id].Tax_Amount__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetTaxGroupBySobjectAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();
            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 50,
                    Date__c = System.today(),
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                    Product__c = testData.products[7].Id
                )
            );

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 45,
                    Date__c = System.today(),
                    Product__c = testData.products[8].Id,
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Unit_Cost__c = 30,
                    Date__c = System.today(),
                    Product__c = testData.products[7].Id,
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );

            insert accountPayableLines;

            System.assertEquals(2, TaxGroupHandler.getTaxGroupsBySObject(accountPayableLines).size());
            System.assert(TaxGroupHandler.getTaxGroupsBySObject(accountPayableLines).containsKey(testData.taxGroups.get(2).Id));
            System.assert(TaxGroupHandler.getTaxGroupsBySObject(accountPayableLines).containsKey(testData.taxGroups.get(1).Id));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPayableLineValidateTaxGroupTypeOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c testPayable = new Account_Payable__c(
                Payee_Reference__c = 'test-ref-1',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Vendor__c = testData.accounts[0].Id
            );
            insert testPayable;

            DmlException dmlEx;
            try {
                Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                    Account_Payable__c = testPayable.Id,
                    Unit_Cost__c = 100,
                    Expense_GL_Account__c = testData.glAccounts[16].Id,
                    Tax_Amount__c = 10,
                    Tax_Group__c = testData.taxGroups[0].Id
                );
                insert testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(HeaderLevelTaxHelper.NOT_PURCHASE_TAX_GROUP_ERROR, new List<String> {Label.COMMON_PAYABLE_LINE}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testPayableLineValidateTaxGroupTypeOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Account_Payable__c testPayable = new Account_Payable__c(
                Payee_Reference__c = 'test-ref-1',
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Vendor__c = testData.accounts[0].Id
            );
            insert testPayable;

            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testPayable.Id,
                Amount__c = 100,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                testPayableLine.Tax_Group__c = testData.taxGroups[0].Id;
                update testPayableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(HeaderLevelTaxHelper.NOT_PURCHASE_TAX_GROUP_ERROR, new List<String> {Label.COMMON_PAYABLE_LINE}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testSetTaxAmountIfNoTaxGroupBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10
            );
            insert billingLine;

            System.assertEquals(
                0,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSetTaxAmountIfTaxGroupPopulatedButAvalaraIsEnabledBL() {
        Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
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
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSetTaxGroupFromProductBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Product__c = testData.products[6].Id
            );

            insert billingLine;

            System.assertEquals(
                testData.taxGroups.get(0).Id,
                [SELECT Tax_Group__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Group__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testCleanTaxGroupPopulatedFromProductBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Product__c = testData.products[6].Id
            );

            insert billingLine;

            System.assertEquals(
                testData.taxGroups.get(0).Id,
                [SELECT Tax_Group__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Group__c
            );

            billingLine.Tax_Group__c = NULL;
            update billingLine;

            billingLine = [SELECT Id, Tax_Group__c, Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id LIMIT 1];

            System.assertEquals(NULL, billingLine.Tax_Group__c);
            System.assertEquals(0, billingLine.Tax_Amount2__c);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSetTaxAmountByTaxGroupBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Product__c = testData.products[6].Id
            );
            insert testBillingLine;

            testBillingLine = [SELECT Id, Hours_Units__c, Rate__c, Tax_Group__c, Tax_Amount2__c FROM Billing_Line__c WHERE Id = :testBillingLine.Id];

            System.assertEquals(testData.taxGroups.get(0).Id, testBillingLine.Tax_Group__c);
            System.assertEquals(
                testBillingLine.Hours_Units__c * testBillingLine.Rate__c * testData.taxRates[0].Tax_Rate__c / 100,
                testBillingLine.Tax_Amount2__c
            );

            testBillingLine.Tax_Amount2__c = 23;
            update testBillingLine;

            System.assertEquals(
                testBillingLine.Hours_Units__c * testBillingLine.Rate__c * testData.taxRates[0].Tax_Rate__c / 100,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :testBillingLine.Id].Tax_Amount2__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testUpdateTaxAmountByRateFieldBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Product__c = testData.products[6].Id
            );

            insert billingLine;

            System.assertEquals(
                testData.taxGroups.get(0).Id,
                [SELECT Tax_Group__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Group__c
            );

            System.assertEquals(
                20,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );

            billingLine.Rate__c = 5;

            update billingLine;

            System.assertEquals(
                10,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testUpdateTaxAmountByHoursUnitFieldBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Product__c = testData.products[6].Id
            );

            insert billingLine;

            System.assertEquals(
                testData.taxGroups.get(0).Id,
                [SELECT Tax_Group__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Group__c
            );

            System.assertEquals(
                20,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );

            billingLine.Hours_Units__c = 30;

            update billingLine;

            System.assertEquals(
                30,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testUpdateTaxAmountByTaxGroupFieldBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Product__c = testData.products[6].Id
            );

            insert billingLine;

            System.assertEquals(
                testData.taxGroups.get(0).Id,
                [SELECT Tax_Group__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Group__c
            );

            System.assertEquals(
                20,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );

            billingLine.Tax_Group__c = testData.taxGroups.get(2).Id;

            update billingLine;

            System.assertEquals(
                6,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testGetTaxGroupBySobjectBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users[1]) {
            List<Billing_Line__c> billingLines = new List<Billing_Line__c>();
            billingLines.add(
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Product__c = testData.products[6].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Product__c = testData.products[8].Id
                )
            );

            billingLines.add(
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Product__c = testData.products[8].Id
                )
            );

            insert billingLines;

            System.assertEquals(2, TaxGroupHandler.getTaxGroupsBySObject(billingLines).size());
            System.assert(TaxGroupHandler.getTaxGroupsBySObject(billingLines).containsKey(testData.taxGroups.get(0).Id));
            System.assert(TaxGroupHandler.getTaxGroupsBySObject(billingLines).containsKey(testData.taxGroups.get(2).Id));
            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxAmountScaleAndRoundingBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20.254444,
                Rate__c = 10.000000,
                Product__c = testData.products[6].Id
            );

            
            insert billingLine;
            System.assertEquals(
                20.25,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );

            billingLine.Hours_Units__c = 20.255555;
            billingLine.Rate__c = 10.001111;
            update billingLine;
            System.assertEquals(
                20.26,
                [SELECT Tax_Amount2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Tax_Amount2__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxAmountScaleAndRoundingAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
        .createTaxGroups()
        .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account_Payable_Line__c testPayableLine = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Unit_Cost__c = 10,
                Quantity__c = 20.254444,
                Date__c = System.today(),
                Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                Product__c = testData.products[7].Id
            );
            insert testPayableLine;           
            System.assertEquals(
                10.13,
                [SELECT Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :testPayableLine.Id].Tax_Amount__c
            );

            testPayableLine.Unit_Cost__c = 10.055555;
            testPayableLine.Quantity__c = 20.255555;
            update testPayableLine;
            System.assertEquals(
                10.18,
                [SELECT Tax_Amount__c FROM Account_Payable_Line__c WHERE Id = :testPayableLine.Id].Tax_Amount__c
            );
            Test.stopTest();
        }
    }



    @IsTest
    public static void testBillingLineValidateTaxGroupTypeOnInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = new Billing__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id
            );
            insert testBilling;

            DmlException dmlEx;
            try {
                Billing_Line__c testBillingLine = new Billing_Line__c(
                    Billing__c = testBilling.Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Rate__c = 100,
                    Tax_Amount2__c = 10,
                    Tax_Group__c = testData.taxGroups[1].Id
                );
                insert testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {Label.COMMON_BILLING_LINE}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testBillingLineValidateTaxGroupTypeOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Billing__c testBilling = new Billing__c(
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id
            );
            insert testBilling;

            Billing_Line__c testBillingLine = new Billing_Line__c(
                Billing__c = testBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 1,
                Rate__c = 100
            );

            Test.startTest();
            DmlException dmlEx;
            try {
                insert testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                testBillingLine.Tax_Group__c = testData.taxGroups[1].Id;
                update testBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(
                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {Label.COMMON_BILLING_LINE}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testRecurringBillingLineCalcTaxBasedOnTaxGroupPopulatedDirectly() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            //Create Recurring Billing
            Recurring_Billing__c testRecurringBilling = new Recurring_Billing__c(
                Name = 'Test RB',
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Monthly',
                Next_Billing_Date__c = testData.acctPeriods[0].Start_Date__c.addMonths(1)
            );
            insert testRecurringBilling;

            //Create Recurring Billing Line
            Recurring_Billing_Line__c testRecurringBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecurringBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Quantity__c = 1,
                Rate__c = 100,
                Tax_Group__c = testData.taxGroups[0].Id,
                Revenue_GL_Account__c = testData.glAccounts[11].Id
            );
            insert testRecurringBillingLine;

            Recurring_Billing_Line__c checkedRecurringBillingLine = [
                SELECT Id, Quantity__c, Rate__c, Tax_Amount__c
                FROM Recurring_Billing_Line__c
                WHERE Id = :testRecurringBillingLine.Id
            ];

            System.assertEquals(
                testRecurringBillingLine.Quantity__c * testRecurringBillingLine.Rate__c * testData.taxRates[0].Tax_Rate__c / 100,
                checkedRecurringBillingLine.Tax_Amount__c
            );
        }
    }

    @IsTest
    private static void testRecurringBillingLineCalcTaxBasedOnTaxGroupPopulatedFromProduct() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            //Create Recurring Billing
            Recurring_Billing__c testRecurringBilling = new Recurring_Billing__c(
                Name = 'Test RB',
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Monthly',
                Next_Billing_Date__c = testData.acctPeriods[0].Start_Date__c.addMonths(1)
            );
            insert testRecurringBilling;

            //Create Recurring Billing Line
            Recurring_Billing_Line__c testRecurringBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecurringBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Quantity__c = 1,
                Rate__c = 100,
                Product__c = testData.products[6].Id,
                Revenue_GL_Account__c = testData.glAccounts[11].Id
            );
            insert testRecurringBillingLine;

            Recurring_Billing_Line__c checkedRecurringBillingLine = [
                SELECT Id, Quantity__c, Rate__c, Tax_Amount__c, Tax_Group__c
                FROM Recurring_Billing_Line__c
                WHERE Id = :testRecurringBillingLine.Id
            ];

            System.assertEquals(testData.taxGroups[0].Id, checkedRecurringBillingLine.Tax_Group__c);

            System.assertEquals(
                testRecurringBillingLine.Quantity__c * testRecurringBillingLine.Rate__c * testData.taxRates[0].Tax_Rate__c / 100,
                checkedRecurringBillingLine.Tax_Amount__c
            );
        }
    }

    @IsTest
    private static void testRecurringBillingLineNoTaxGroupFromProductDuringUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            //Create Recurring Billing
            Recurring_Billing__c testRecurringBilling = new Recurring_Billing__c(
                Name = 'Test RB',
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Monthly',
                Next_Billing_Date__c = testData.acctPeriods[0].Start_Date__c.addMonths(1)
            );
            insert testRecurringBilling;

            //Create Recurring Billing Line
            Recurring_Billing_Line__c testRecurringBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecurringBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Quantity__c = 1,
                Rate__c = 100,
                Revenue_GL_Account__c = testData.glAccounts[11].Id
            );
            insert testRecurringBillingLine;

            Recurring_Billing_Line__c checkedRecurringBillingLine = [
                SELECT Id, Quantity__c, Rate__c, Tax_Amount__c, Tax_Group__c
                FROM Recurring_Billing_Line__c
                WHERE Id = :testRecurringBillingLine.Id
            ];

            System.assertEquals(NULL, checkedRecurringBillingLine.Tax_Group__c);

            //populate Product with Tax Group
            checkedRecurringBillingLine.Product__c = testData.products[6].Id;
            update checkedRecurringBillingLine;

            checkedRecurringBillingLine = [
                SELECT Id, Quantity__c, Rate__c, Tax_Amount__c, Tax_Group__c
                FROM Recurring_Billing_Line__c
                WHERE Id = :testRecurringBillingLine.Id
            ];
            //since it is update - Tax Group will not be inherited from linked Product
            System.assertEquals(NULL, checkedRecurringBillingLine.Tax_Group__c);
        }
    }

    @IsTest
    private static void testRecurringBillingLineValidateTaxGroupType() {
        TestDataSuite testData = TestDataSuite.getInstance().createTaxGroups();

        System.runAs(testData.users.get(1)) {
            //Create Recurring Billing
            Recurring_Billing__c testRecurringBilling = new Recurring_Billing__c(
                Name = 'Test RB',
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Monthly',
                Next_Billing_Date__c = testData.acctPeriods[0].Start_Date__c.addMonths(1)
            );
            insert testRecurringBilling;

            //Create Recurring Billing Line
            Recurring_Billing_Line__c testRecurringBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecurringBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Quantity__c = 1,
                Rate__c = 100,
                Tax_Group__c = testData.taxGroups[1].Id,
                Revenue_GL_Account__c = testData.glAccounts[11].Id
            );

            DmlException dmlEx;
            try {
                insert testRecurringBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(HeaderLevelTaxHelper.NOT_SALES_TAX_GROUP_ERROR, new List<String> {Label.COMMON_RECURRING_BILLING_LINE}),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    private static void testRecurringBillingLineValidateTaxGroupHasTaxRate() {
        TestDataSuite testData = TestDataSuite.getInstance().setHeaderLevelPost();

        System.runAs(testData.users.get(1)) {
            //Create Tax Group
            Tax_Group__c testTaxGroup = new Tax_Group__c(
                Name = 'TG',
                Tax_Type__c = 'Sales'
            );
            insert testTaxGroup;

            //Create Recurring Billing
            Recurring_Billing__c testRecurringBilling = new Recurring_Billing__c(
                Name = 'Test RB',
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Monthly',
                Next_Billing_Date__c = testData.acctPeriods[0].Start_Date__c.addMonths(1)
            );
            insert testRecurringBilling;

            //Create Recurring Billing Line
            Recurring_Billing_Line__c testRecurringBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testRecurringBilling.Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Quantity__c = 1,
                Rate__c = 100,
                Tax_Group__c = testTaxGroup.Id,
                Revenue_GL_Account__c = testData.glAccounts[11].Id
            );

            DmlException dmlEx;
            try {
                insert testRecurringBillingLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(HeaderLevelTaxHelper.TAX_GROUP_WITHOUT_TAX_RATE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testSetTaxGroupFieldOnBillingLineWithAvaTaxInsertAndUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Tax_Group__c taxGroup = new Tax_Group__c(
                Name = 'SalesTaxGroup',
                Tax_Type__c = 'Sales'
            );
            insert taxGroup;

            Billing_Line__c newBillingLine = testData.billingLines[0].clone();
            newBillingLine.Tax_Group__c = taxGroup.Id;
            insert newBillingLine;
            System.assertEquals(NULL, [SELECT Id, Tax_Group__c FROM Billing_Line__c WHERE Id = : newBillingLine.Id].Tax_Group__c);

            newBillingLine.Tax_Group__c = taxGroup.Id;
            update newBillingLine;
            System.assertEquals(NULL, [SELECT Id, Tax_Group__c FROM Billing_Line__c WHERE Id = : newBillingLine.Id].Tax_Group__c);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testSetTaxGroupFieldOnRecurringBillingLineWithAvaTaxInsertAndUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {

            Tax_Group__c taxGroup = new Tax_Group__c(
                Name = 'SalesTaxGroup',
                Tax_Type__c = 'Sales'
            );
            insert taxGroup;

            Recurring_Billing_Line__c newRecBillingLine = testData.recurringBillingLines[0].clone();
            newRecBillingLine.Tax_Group__c = taxGroup.Id;
            insert newRecBillingLine;
            System.assertEquals(NULL, [SELECT Id, Tax_Group__c FROM Recurring_Billing_Line__c WHERE Id = : newRecBillingLine.Id].Tax_Group__c);

            newRecBillingLine.Tax_Group__c = taxGroup.Id;
            update newRecBillingLine;
            System.assertEquals(NULL, [SELECT Id, Tax_Group__c FROM Recurring_Billing_Line__c WHERE Id = : newRecBillingLine.Id].Tax_Group__c);
        }

    }

    @IsTest
    private static void testTaxInclusiveAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Tax_Group__c taxGroup = [SELECT Id, Combined_Tax_Rate__c FROM Tax_Group__c WHERE Id = :testData.taxGroups[1].Id LIMIT 1];
            taxGroup.Tax_Inclusive__c = true;
            update taxGroup;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Unit_Cost__c = 100,
                Date__c = System.today(),
                Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                Tax_Group__c = taxGroup.Id
            );
            insert line;

            //re-query the line
            line = [
                SELECT Id, Unit_Cost__c, Tax_Group__c, Tax_Amount__c, Sub_Total__c, Amount__c, Combined_Tax_Rate__c, Tax_Inclusive__c 
                FROM Account_Payable_Line__c 
                WHERE Id = :line.Id
                LIMIT 1
            ];

            Assert.areEqual(taxGroup.Id, line.Tax_Group__c);
            Assert.areEqual(taxGroup.Combined_Tax_Rate__c, line.Combined_Tax_Rate__c);
            Assert.areEqual(true, line.Tax_Inclusive__c);
            Assert.areEqual(100, line.Unit_Cost__c);
            Assert.areEqual(line.Unit_Cost__c, line.Amount__c);
            Assert.areEqual(line.Amount__c - (line.Amount__c / (1 + (line.Combined_Tax_Rate__c/100))).setScale(2, RoundingMode.HALF_UP), line.Tax_Amount__c);
            Assert.areEqual(line.Amount__c - line.Tax_Amount__c, line.Sub_Total__c);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxInclusiveChangeAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Tax_Group__c taxGroupInclusive = [SELECT Id, Combined_Tax_Rate__c, Tax_Inclusive__c FROM Tax_Group__c WHERE Id = :testData.taxGroups[1].Id LIMIT 1];
            taxGroupInclusive.Tax_Inclusive__c = true;
            update taxGroupInclusive;

            Account_Payable_Line__c line = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Unit_Cost__c = 100,
                Date__c = System.today(),
                Expense_GL_Account__c = testData.glAccounts.get(12).Id,
                Tax_Group__c = taxGroupInclusive.Id
            );
            insert line;

            //re-query the line
            line = [
                SELECT Combined_Tax_Rate__c, Tax_Inclusive__c 
                FROM Account_Payable_Line__c 
                WHERE Id = :line.Id
                LIMIT 1
            ];

            Assert.areEqual(taxGroupInclusive.Tax_Inclusive__c, line.Tax_Inclusive__c);
            Assert.areEqual(taxGroupInclusive.Combined_Tax_Rate__c, line.Combined_Tax_Rate__c);

            Tax_Group__c taxGroupExclusive = [SELECT Id, Combined_Tax_Rate__c, Tax_Inclusive__c FROM Tax_Group__c WHERE Id = :testData.taxGroups[2].Id LIMIT 1];
            Assert.areEqual(false, taxGroupExclusive.Tax_Inclusive__c);
            line.Tax_Group__c = taxGroupExclusive.Id;
            update line;

            line = [
                SELECT Combined_Tax_Rate__c, Tax_Inclusive__c 
                FROM Account_Payable_Line__c 
                WHERE Id = :line.Id
                LIMIT 1
            ];

            Assert.areEqual(taxGroupExclusive.Tax_Inclusive__c, line.Tax_Inclusive__c);
            Assert.areEqual(taxGroupExclusive.Combined_Tax_Rate__c, line.Combined_Tax_Rate__c);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxInclusiveBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Tax_Group__c taxGroup = [SELECT Id, Combined_Tax_Rate__c FROM Tax_Group__c WHERE Id = :testData.taxGroups[0].Id LIMIT 1];
            taxGroup.Tax_Inclusive__c = true;
            update taxGroup;

            Billing_Line__c line = new Billing_Line__c(
                Billing__c = testData.billings.get(0).Id,
                Hours_Units__c = 5,
                Rate__c = 20,
                Date__c = System.today(),
                Tax_Group__c = taxGroup.Id
            );
            insert line;

            //re-query the line
            line = [
                SELECT Id, Rate__c, Hours_Units__c, Tax_Group__c, Tax_Amount2__c, Sub_Total__c, Total__c, Combined_Tax_Rate__c, Tax_Inclusive__c 
                FROM Billing_Line__c 
                WHERE Id = :line.Id
                LIMIT 1
            ];

            Assert.areEqual(taxGroup.Id, line.Tax_Group__c);
            Assert.areEqual(taxGroup.Combined_Tax_Rate__c, line.Combined_Tax_Rate__c);
            Assert.isTrue(line.Tax_Inclusive__c);
            Assert.areEqual(100, line.Total__c);
            Assert.areEqual((line.Hours_Units__c * line.Rate__c).setScale(2, RoundingMode.HALF_UP), line.Total__c);
            Assert.areEqual(line.Total__c - (line.Total__c / (1 + (line.Combined_Tax_Rate__c/100))).setScale(2, RoundingMode.HALF_UP), line.Tax_Amount2__c);
            Assert.areEqual(line.Total__c - line.Tax_Amount2__c, line.Sub_Total__c);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testTaxInclusiveChangeBL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createTaxGroups()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Tax_Group__c taxGroupInclusive = [SELECT Id, Combined_Tax_Rate__c, Tax_Inclusive__c FROM Tax_Group__c WHERE Id = :testData.taxGroups[0].Id LIMIT 1];
            taxGroupInclusive.Tax_Inclusive__c = true;
            update taxGroupInclusive;

            Billing_Line__c line = new Billing_Line__c(
                Billing__c = testData.billings.get(0).Id,
                Hours_Units__c = 5,
                Rate__c = 20,
                Date__c = System.today(),
                Tax_Group__c = taxGroupInclusive.Id
            );
            insert line;

            //re-query the line
            line = [
                SELECT Combined_Tax_Rate__c, Tax_Inclusive__c 
                FROM Billing_Line__c 
                WHERE Id = :line.Id
                LIMIT 1
            ];

            Assert.areEqual(taxGroupInclusive.Tax_Inclusive__c, line.Tax_Inclusive__c);
            Assert.areEqual(taxGroupInclusive.Combined_Tax_Rate__c, line.Combined_Tax_Rate__c);

            Tax_Group__c taxGroupExclusive = [SELECT Id, Combined_Tax_Rate__c, Tax_Inclusive__c FROM Tax_Group__c WHERE Id = :testData.taxGroups[2].Id LIMIT 1];
            Assert.isFalse(taxGroupExclusive.Tax_Inclusive__c);
            line.Tax_Group__c = taxGroupExclusive.Id;
            update line;

            line = [
                SELECT Combined_Tax_Rate__c, Tax_Inclusive__c 
                FROM Billing_Line__c 
                WHERE Id = :line.Id
                LIMIT 1
            ];

            Assert.areEqual(taxGroupExclusive.Tax_Inclusive__c, line.Tax_Inclusive__c);
            Assert.areEqual(taxGroupExclusive.Combined_Tax_Rate__c, line.Combined_Tax_Rate__c);

            Test.stopTest();
        }
    }

}