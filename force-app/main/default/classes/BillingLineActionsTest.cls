@IsTest
public class BillingLineActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testReparentingBetweenNotPostedBillings() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Billing__c sourceBilling = testData.billings[0];
            Billing__c targetBilling = testData.billings[1];

            System.assertEquals(2, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :sourceBilling.Id]);
            System.assertEquals(2, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :targetBilling.Id]);

            //reparenting between two not posted Billings
            Billing_Line__c theLine = testData.billingLines[0];
            theLine.Billing__c = targetBilling.Id;
            DmlException dmlEx;
            try {
                update theLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
            System.assertEquals(1, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :sourceBilling.Id]);
            System.assertEquals(3, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :targetBilling.Id]);
        }

    }

    @IsTest
    public static void testReparentingBetweenBillingsWhereSourceIsPostedAndTargetIsNot() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c sourceBilling = testData.billings[0];
            Billing__c targetBilling = testData.billings[1];

            System.assertEquals(2, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :sourceBilling.Id]);
            System.assertEquals(2, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :targetBilling.Id]);

            //reparenting between two Billings: Source Billing is Posted
            //unpost target Billing record
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Billing__c>{
                targetBilling
            });
            System.assertEquals(true, postResults[0].isSuccess);
            //try to reparent
            Billing_Line__c theLine = testData.billingLines[0];
            theLine.Billing__c = targetBilling.Id;
            DmlException dmlEx;
            try {
                update theLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(BillingLineActions.BILLING_LINE_REPARENTING_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }

    }

    @IsTest
    public static void testReparentingBetweenBillingsWhereSourceIsNotPostedAndTargetIsPosted() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings(true);

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c sourceBilling = testData.billings[0];
            Billing__c targetBilling = testData.billings[1];

            System.assertEquals(2, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :sourceBilling.Id]);
            System.assertEquals(2, [SELECT COUNT() FROM Billing_Line__c WHERE Billing__c = :targetBilling.Id]);

            //reparenting between two Billings: Target Billing is Posted
            //unpost source Billing record
            AbstractPostHandler postHandler = new BillingPostHandler();
            List<PostResult> postResults = postHandler.unpost(new List<Billing__c>{
                sourceBilling
            });
            System.assertEquals(true, postResults[0].isSuccess);
            //try to reparent
            Billing_Line__c theLine = testData.billingLines[0];
            theLine.Billing__c = targetBilling.Id;
            DmlException dmlEx;
            try {
                update theLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(BillingLineActions.BILLING_LINE_REPARENTING_ERROR, dmlEx.getDmlMessage(0));
            Test.stopTest();
        }

    }

    @IsTest
    public static void testRequireRevenueGLAccountInsertError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        List<GL_Account_Default__c> defaults = [
            SELECT Id
            FROM GL_Account_Default__c
            WHERE Ledger__c = :testData.ledgers[0].Id AND GL_Account_Specification__c = :GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT
        ];
        delete defaults;

        testData.createBillings();

        System.runAs(testData.users[1]) {
            Billing_Line__c billLine = testData.billingLines[0].clone(false, true);
            billLine.Product__c = null;
            billLine.Revenue_GL_Account__c = null;

            DmlException dmlEx;
            try {
                insert billLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testRequireRevenueGLAccountUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            delete testData.settings;
            AccountingSettingsHandler.acctSeedSettings = null;

            testData.billingLines[0].Product__c = null;
            testData.billingLines[0].Revenue_GL_Account__c = null;

            DmlException dmlEx;
            try {
                update testData.billingLines[0];
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    private static void testSetVATReportingFields() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createTaxGroups()
            .setAvaVATSelected();

        Test.startTest();

        testData.accounts.get(0).Default_Expense_GL_Account__c = testData.glAccounts.get(12).Id;
        update testData.accounts.get(0);

        List<Billing__c> billings = new List<Billing__c>();

        List<Billing_Line__c> billingLines = new List<Billing_Line__c>();

        billings.add(
            new Billing__c(
                Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Billing_Format__c = testData.billingFormats[0].Id,
                Due_Date2__c = System.today() + 30,
                Billing_Street__c = '999 Billing Street',
                Billing_City__c = 'BillingCity',
                Billing_State__c = 'CA',
                Billing_Country__c = 'US',
                Billing_PostalCode__c = '94104',
                Shipping_Street__c = '888 Shipping Street',
                Shipping_City__c = 'ShippingCity',
                Shipping_State__c = 'CA',
                Shipping_Country__c = 'US',
                Shipping_PostalCode__c = '90100'
            )
        );
        insert billings;

        billingLines.add(
            new Billing_Line__c(
                Billing__c = billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Tax_Group__c = testData.taxGroups[3].Id
            )
        );
        insert billingLines;

        Billing_Line__c bl = [SELECT Is_VAT_Related__c FROM Billing_Line__c WHERE Id = :billingLines.get(0).Id];
        System.assertEquals(true, bl.Is_VAT_Related__c);

        billingLines[0].Tax_Group__c = null;
        update billingLines[0];

        bl = [SELECT Is_VAT_Related__c FROM Billing_Line__c WHERE Id = :billingLines.get(0).Id];
        System.assertEquals(false, bl.Is_VAT_Related__c);

        billingLines[0].Tax_Group__c = testData.taxGroups[4].Id;
        update billingLines[0];

        bl = [SELECT Is_VAT_Related__c FROM Billing_Line__c WHERE Id = :billingLines.get(0).Id];
        System.assertEquals(true, bl.Is_VAT_Related__c);

        billingLines[0].Tax_Group__c = testData.taxGroups[0].Id;
        update billingLines[0];

        bl = [SELECT Is_VAT_Related__c FROM Billing_Line__c WHERE Id = :billingLines.get(0).Id];
        System.assertEquals(false, bl.Is_VAT_Related__c);

        Test.stopTest();
    }

    @IsTest
    public static void testDefaultRevenueGLAccountAndDefaultProductFieldsError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        List<GL_Account_Default__c> defaults = [
            SELECT Id
            FROM GL_Account_Default__c
            WHERE Ledger__c = :testData.ledgers[0].Id AND GL_Account_Specification__c = :GLAccountDefaultsHandler.REVENUE_GL_ACCOUNT
        ];
        delete defaults;

        testData.createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10
            );

            DmlException dmlEx;
            try {
                insert billingLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testDefaultRevenueGLAccountFromAccountingSettingsError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[2].Id
            );

            DmlException dmlEx;
            try {
                insert billingLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testDefaultRevenueGLAccountAndDefaultProductFieldsDefault() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables().createProducts().createBillings();
        testData.setInventoryValuationStandardCost();
        testData.setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.products[0];

            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Product__c = testData.products[0].Id,
                Hours_Units__c = 20,
                Rate__c = 10
            );


            DmlException dmlEx;
            try {
                insert billingLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(null, dmlEx);

            System.assertEquals(
                testData.products[0].Revenue_GL_Account__c,
                [SELECT Revenue_GL_Account__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Revenue_GL_Account__c
            );

            System.assertEquals(
                testData.products[0].Expense_GL_Account__c,
                [SELECT Expense_GL_Account__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Expense_GL_Account__c
            );

            System.assertEquals(
                testData.products[0].Inventory_GL_Account__c,
                [SELECT Inventory_GL_Account__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Inventory_GL_Account__c
            );

            System.assertEquals(
                testData.products[0].Unit_Cost__c,
                [SELECT Product_Unit_Cost__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Product_Unit_Cost__c
            );

            System.assertEquals(
                testData.products[0].GL_Account_Variable_1__c,
                [SELECT GL_Account_Variable_1__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.products[0].GL_Account_Variable_2__c,
                [SELECT GL_Account_Variable_2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.products[0].GL_Account_Variable_3__c,
                [SELECT GL_Account_Variable_3__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.products[0].GL_Account_Variable_4__c,
                [SELECT GL_Account_Variable_4__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    public static void testDefaultRevenueGLAccountAndDefaultProductFieldsNoDefaultOverride() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createAccountingVariables()
            .createBillings()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.products[0];

            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Product__c = testData.products[0].Id,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[12].Id,
                Expense_GL_Account__c = testData.glAccounts[7].Id,
                Inventory_GL_Account__c = testData.glAccounts[16].Id,
                Product_Unit_Cost__c = 23353,
                GL_Account_Variable_1__c = testData.accountingVariables1[1].Id,
                GL_Account_Variable_2__c = testData.accountingVariables2[1].Id,
                GL_Account_Variable_3__c = testData.accountingVariables3[1].Id,
                GL_Account_Variable_4__c = testData.accountingVariables4[1].Id
            );

            DmlException dmlEx;
            try {
                insert billingLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(null, dmlEx);

            System.assertNotEquals(
                testData.products[0].Revenue_GL_Account__c,
                [SELECT Revenue_GL_Account__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Revenue_GL_Account__c
            );

            System.assertNotEquals(
                testData.products[0].Expense_GL_Account__c,
                [SELECT Expense_GL_Account__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Expense_GL_Account__c
            );

            System.assertNotEquals(
                testData.products[0].Inventory_GL_Account__c,
                [SELECT Inventory_GL_Account__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Inventory_GL_Account__c
            );

            System.assertNotEquals(
                testData.products[0].Unit_Cost__c,
                [SELECT Product_Unit_Cost__c FROM Billing_Line__c WHERE Id = :billingLine.Id].Product_Unit_Cost__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_1__c,
                [SELECT GL_Account_Variable_1__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_1__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_2__c,
                [SELECT GL_Account_Variable_2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_2__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_3__c,
                [SELECT GL_Account_Variable_3__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_3__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_4__c,
                [SELECT GL_Account_Variable_4__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    public static void testPreventUpdateActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Accounting_Period__r.Status__c,
                    Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);

            BillingPostTransaction pbt = new BillingPostTransaction(cont);

            pbt.post();

            System.assertEquals(
                'Posted', [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c
            );

            DmlException dmlEx;
            // Test update no error since no fields changed.
            Billing_Line__c billingLine = [
                SELECT Id, Rate__c
                FROM Billing_Line__c
                WHERE Billing__c = :testData.billings[0].Id
                LIMIT 1
            ];

            try {
                update billingLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);

            // Test update error since attempted to change protected field on account payable.
            try {
                billingLine.Rate__c = 10000;
                update billingLine;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
        }

    }

    @IsTest
    public static void testPreventUpdateActionPostedUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            Billing_Line__c bl = testData.billingLines[0].clone(false, true);
            insert bl;

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();

            System.assertEquals(
                'Posted', [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c
            );

            DmlException dmlEx;

            try {
                bl.Project__c = testData.projects[0].Id;
                update bl;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
            Test.stopTest();
        }

    }

    @IsTest
    public static void testPreventUpdateActionPostedNoChangeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            Billing_Line__c bl = testData.billingLines[0].clone(false, true);
            bl.Rate__c = 6.78656565;
            insert bl;

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();

            System.assertEquals(
                'Posted', [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c
            );

            DmlException dmlEx;
            try {
                update bl;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testPreventUpdateActionPostedNoChangeSetScaleSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            Billing_Line__c bl = testData.billingLines[0].clone(false, true);
            bl.Rate__c = 6.78656565;
            bl.Hours_Units__c = 5.7891239;
            insert bl;

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ]);
            BillingPostTransaction pbt = new BillingPostTransaction(cont);
            pbt.post();

            System.assertEquals(
                'Posted', [
                    SELECT Accounting_Period__r.Status__c, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c
            );

            DmlException dmlEx;

            // Test update no error since no fields changed.
            bl = [SELECT Id, Rate__c, Hours_Units__c FROM Billing_Line__c WHERE Id = :bl.Id LIMIT 1];

            try {
                bl.Rate__c = 6.786566;
                update bl;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);

            bl = [SELECT Id, Rate__c, Hours_Units__c FROM Billing_Line__c WHERE Id = :bl.Id LIMIT 1];
            System.assertEquals(5.789124, bl.Hours_Units__c);
            try {
                bl.Hours_Units__c = 5.7891239;
                update bl;
            } catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(null, dmlEx);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testPreventDeleteLineActionPosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings;

            PostResult result = BillingPostService.postBillings(
                new List<Billing__c>{
                    testData.billings[0]
                }
            )[0];
            System.assertEquals(true, result.isSuccess);

            DmlException dmlEx;
            try {
                delete testData.billingLines;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testBillingLineNotNullPointerExceptionInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                DmlException dmlEx;

                Billing_Line__c bl = new Billing_Line__c();

                try {
                    insert bl;
                } catch (DmlException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.nullPointerException'));
            }
        } catch (Exception ex) {

        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            Billing_Line__c billLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Hours_Units__c = 20.989342348934,
                Rate__c = 10.236746723674344,
                List_Price__c = 23.423423545452423,
                Product_Unit_Cost__c = 3.4237468273582872853

            );
            insert billLine;

            Billing_Line__c newBillingLine = [
                SELECT Id,
                    Hours_Units__c,
                    Rate__c,
                    List_Price__c,
                    Product_Unit_Cost__c
                FROM Billing_Line__c
                WHERE Id = :billLine.Id
            ];

            System.assertEquals(20.989342, newBillingLine.Hours_Units__c);
            System.assertEquals(10.236747, newBillingLine.Rate__c);
            System.assertEquals(23.42, newBillingLine.List_Price__c);
            System.assertEquals(3.423747, newBillingLine.Product_Unit_Cost__c);
        }

    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {

            testData.billingLines[0].Hours_Units__c = 20.989342348934;
            testData.billingLines[0].Rate__c = 10.236746723674344;
            testData.billingLines[0].List_Price__c = 23.423423545452423;
            testData.billingLines[0].Product_Unit_Cost__c = 3.4237468273582872853;

            update testData.billingLines[0];

            Billing_Line__c newBillingLine = [
                SELECT Id,
                    Hours_Units__c,
                    Rate__c,
                    List_Price__c,
                    Product_Unit_Cost__c
                FROM Billing_Line__c
                WHERE Id = :testData.billingLines[0].Id
            ];

            System.assertEquals(20.989342, newBillingLine.Hours_Units__c);
            System.assertEquals(10.236747, newBillingLine.Rate__c);
            System.assertEquals(23.42, newBillingLine.List_Price__c);
            System.assertEquals(3.423747, newBillingLine.Product_Unit_Cost__c);
        }

    }

    @IsTest
    public static void testSetCurrencyFromParent() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createBillings();
            String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
            if (String.isBlank(newCurrency)) {
                return;
            }
            String testBillId = testData.billings[0].Id;
            String parentCurrency = (String) Database.query(
                'SELECT CurrencyIsoCode ' +
                'FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c ' +
                'WHERE Id = :testBillId'
            )[0].get('CurrencyIsoCode');

            System.assertNotEquals(newCurrency, parentCurrency);

            Billing_Line__c billLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Hours_Units__c = 20,
                Rate__c = 10
            );
            billLine.put('CurrencyIsoCode', newCurrency);

            insert billLine;

            String lineId = billLine.Id;
            String lineCurrencyInsert = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

            System.assertEquals(parentCurrency, lineCurrencyInsert);

            billLine.put('CurrencyIsoCode', newCurrency);

            update billLine;

            String lineCurrencyUpdate = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

            System.assertEquals(parentCurrency, lineCurrencyUpdate);
        } catch (Exception ex) {

        }

    }

    @IsTest
    public static void testClearFieldsWhenTaxGroupRemoved() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost();
        Test.startTest();
        testData.createBillings()
            .createTaxGroups();

        System.runAs(testData.users[1]) {
            Tax_Group__c taxGroup = testData.taxGroups[0];
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

            line = [SELECT Tax_Inclusive__c, Combined_Tax_Rate__c FROM Billing_Line__c WHERE Id = :line.Id LIMIT 1];
            Assert.areEqual(true, line.Tax_Inclusive__c);
            Assert.isNotNull(line.Combined_Tax_Rate__c);
            Assert.isTrue(line.Combined_Tax_Rate__c > 0);

            line.Tax_Group__c = null;
            update line;

            line = [SELECT Tax_Inclusive__c, Combined_Tax_Rate__c FROM Billing_Line__c WHERE Id = :line.Id LIMIT 1];
            Assert.areEqual(false, line.Tax_Inclusive__c);
            Assert.isNotNull(line.Combined_Tax_Rate__c);
            Assert.areEqual(0, line.Combined_Tax_Rate__c);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testPreventTaxGroup() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createTaxGroups();
        Test.startTest();
        testData.setLineLevelPost()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {

            testData.taxGroups[0].Tax_Inclusive__c = true;
            update testData.taxGroups[0];

            testData.billings[0].Ledger__c = testData.ledgers[0].Id;
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            Billing_Line__c bl = testData.billingLines[0].clone(false, true);
            bl.Rate__c = 6.78656565;
            bl.Hours_Units__c = 5.7891239;
            bl.Tax_Group__c = testData.taxGroups[0].Id;
            bl.Billing__c = testData.billings[0].Id;


            DmlException dmlEx;

            try {
                insert bl;
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(Label.ERR_PREVENT_AVATAX_MESSAGE, dmlEx.getDmlMessage(0));

        }

    }

    @IsTest
    public static void testPreventTaxGroupHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings();
        Test.startTest();
        testData.createTaxGroups()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {

            testData.taxGroups[0].Tax_Inclusive__c = true;
            update testData.taxGroups[0];

            testData.billings[0].Ledger__c = testData.ledgers[0].Id;
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            Billing_Line__c bl = testData.billingLines[0].clone(false, true);
            bl.Rate__c = 6.78656565;
            bl.Hours_Units__c = 5.7891239;
            bl.Tax_Group__c = testData.taxGroups[0].Id;
            bl.Billing__c = testData.billings[0].Id;

            System.assertEquals(null, bl.Id);

            insert bl;
            Test.stopTest();

            Billing_Line__c bl1 = [SELECT Id, Tax_Group__c FROM Billing_Line__c WHERE Id = :bl.Id LIMIT 1];
            System.assertEquals(null, bl1.Tax_Group__c);
        }

    }

}