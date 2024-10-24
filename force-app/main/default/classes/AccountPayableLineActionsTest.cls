@IsTest
private class AccountPayableLineActionsTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testAssociateDefaultExpenseGLAccountNoDefaultGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();
        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Default_Expense_GL_Account__c = testData.glAccounts.get(17).Id;
            update testData.accounts.get(0);

            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );

            insert accountPayableLines;

            Test.stopTest();

            System.assertEquals(
                testData.glAccounts.get(12).Id,
                [SELECT Expense_GL_Account__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id].Expense_GL_Account__c
            );
        }
    }

    @IsTest
    private static void testAssociateDefaultExpenseGLAccountDefaultGLAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Default_Expense_GL_Account__c = testData.glAccounts.get(12).Id;
            update testData.accounts.get(0);

            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today()
                )
            );

            insert accountPayableLines;

            Test.stopTest();

            System.assertEquals(
                testData.accounts.get(0).Default_Expense_GL_Account__c,
                [SELECT Expense_GL_Account__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id].Expense_GL_Account__c
            );
        }
    }

    @IsTest
    private static void testSetVATReportingFields() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createTaxGroups()
            .setAvaVATSelected();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.accounts.get(0).Default_Expense_GL_Account__c = testData.glAccounts.get(12).Id;
            update testData.accounts.get(0);

            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();

            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();

            accountPayables.add(
                new Account_Payable__c(
                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                    Vendor__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = testData.ledgers[0].Id
                )
            );

            insert accountPayables;

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = accountPayables.get(0).Id,
                    Unit_Cost__c = 45,
                    Date__c = System.today(),
                    Tax_Group__c = testData.taxGroups[3].Id
                )
            );

            insert accountPayableLines;

            Account_Payable_Line__c apl = [SELECT Is_VAT_Related__c, Reverse_Charge__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id];
            System.assertEquals(true, apl.Is_VAT_Related__c);
            System.assertEquals(true, apl.Reverse_Charge__c);

            accountPayableLines[0].Tax_Group__c = NULL;
            update accountPayableLines[0];

            apl = [SELECT Is_VAT_Related__c, Reverse_Charge__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id];
            System.assertEquals(false, apl.Is_VAT_Related__c);
            System.assertEquals(false, apl.Reverse_Charge__c);

            accountPayableLines[0].Tax_Group__c = testData.taxGroups[4].Id;
            update accountPayableLines[0];

            apl = [SELECT Is_VAT_Related__c, Reverse_Charge__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id];
            System.assertEquals(true, apl.Is_VAT_Related__c);
            System.assertEquals(false, apl.Reverse_Charge__c);

            accountPayableLines[0].Tax_Group__c = testData.taxGroups[1].Id;
            update accountPayableLines[0];

            apl = [SELECT Is_VAT_Related__c, Reverse_Charge__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id];
            System.assertEquals(false, apl.Is_VAT_Related__c);
            System.assertEquals(false, apl.Reverse_Charge__c);

            Test.stopTest();
        }
    }

    @IsTest
    private static void testAssociateDefaultExpenseGLAccountStandardCost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createProducts()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Product__c = testData.products.get(0).Id,
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );

            insert accountPayableLines;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c,
                [SELECT Expense_GL_Account__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id].Expense_GL_Account__c
            );
        }
    }

    @isTest
    private static void testAssociateDefaultExpenseGLAccountStandardCostProductCostingDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .createProducts()
            .setInventoryValuationStandardCost()
            .setERPEnabled()
            .disableProductCosting();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Product__c = testData.products.get(0).Id,
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );
            insert accountPayableLines;

            System.assertEquals(
                testData.glAccounts.get(12).Id,
                [SELECT Expense_GL_Account__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id].Expense_GL_Account__c
            );
        }

    }

    @IsTest
    private static void testAssociateDefaultExpenseGLAccountNonInventoryProduct() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables(false)
            .setInventoryValuationStandardCost()
            .disableProductCosting();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            //Create non-inventory Product
            Product2 testProduct = new Product2(Name = 'non inv prod');
            insert testProduct;
            //Add Default Expense GL Account to the Vendor
            testData.accounts[0].Default_Expense_GL_Account__c = testData.glAccounts[17].Id;
            update testData.accounts[0];
            //Add Payable Line with non-inventory Product
            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();
            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Product__c = testProduct.Id,
                    Expense_GL_Account__c = NULL
                )
            );
            insert accountPayableLines;
            //Expected: Expense_GL_Account__c field is populated from Vendor's Default_Expense_GL_Account__c field
            System.assertEquals(
                testData.accounts[0].Default_Expense_GL_Account__c,
                [SELECT Expense_GL_Account__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id].Expense_GL_Account__c
            );
        }

    }

    @isTest
    private static void testAssociateDefaultExpenseGLAccountAverageCost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createProducts()
            .setInventoryValuationAverageCost()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Product__c = testData.products.get(0).Id,
                    Expense_GL_Account__c = testData.glAccounts.get(12).Id
                )
            );

            insert accountPayableLines;
            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            System.assertEquals(
                defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c,
                [SELECT Expense_GL_Account__c FROM Account_Payable_Line__c WHERE Id = :accountPayableLines.get(0).Id].Expense_GL_Account__c
            );
        }
    }

    @isTest
    private static void testPreventUpdateActionPostedUpdateError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createProjects();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            Account_Payable_Line__c apl = testData.payableLines.get(0).clone(false, true);
            apl.Account_Payable__c = testData.payables.get(0).Id;
            insert apl;

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);

            AccountPayablePostTransaction pt = new AccountPayablePostTransaction(controller);
            pt.post();

            System.assertEquals(
                'Posted',
                [SELECT Accounting_Period__r.Status__c, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            DMLException dmlEx;
            try {
                apl.Project__c = testData.projects.get(0).Id;
                update apl;
            } catch(DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
                dmlEx.getDmlType(0)
            );
        }
    }

    @isTest
    private static void testPreventUpdateActionPostedNoChangeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            Account_Payable_Line__c apl = testData.payableLines.get(0).clone(false, true);
            apl.Account_Payable__c = testData.payables.get(0).Id;
            apl.Amount__c = 6.78656565;
            insert apl;

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);

            AccountPayablePostTransaction pt = new AccountPayablePostTransaction(controller);
            pt.post();

            System.assertEquals(
                'Posted',
                [SELECT Accounting_Period__r.Status__c, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            DMLException dmlEx;
            try {
                update apl;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                null,
                dmlEx
            );
        }
    }

    @isTest
    private static void testPreventUpdateActionPostedNoChangeSetScaleSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            Account_Payable_Line__c apl = testData.payableLines.get(0).clone(false, true);
            apl.Account_Payable__c = testData.payables.get(0).Id;
            apl.Amount__c = 6.78656565;
            insert apl;

            ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller([
                SELECT  Accounting_Period__r.Status__c,
                        Status__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables.get(0).Id
            ]);

            AccountPayablePostTransaction pt = new AccountPayablePostTransaction(controller);
            pt.post();

            System.assertEquals(
                'Posted',
                [SELECT Accounting_Period__r.Status__c, Status__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Status__c
            );

            DMLException dmlEx;
            try {
                apl.Amount__c = 6.79;
                update apl;
            } catch(DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                null,
                dmlEx
            );
        }
    }
    
    @isTest
    private static void testRequireExpenseGLAccountInsert() {
        String fieldName = Account_Payable_Line__c.Expense_GL_Account__c.getDescribe().getLabel();
        String message = SObjectActions.REQUIRED_FIELD_ERROR;
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();

            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables.get(0).Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Expense_GL_Account__c = null
                )
            );

            Test.startTest();

            DMLException dmlEx;
            try {
                insert accountPayableLines;
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            System.assertEquals(
                message,
                dmlEx.getDmlMessage(0)
            );
        }
    }
    
    @isTest
    private static void testRequireExpenseGLAccountUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            DMLException dmlEx;
            try {
                testData.payableLines.get(0).Expense_GL_Account__c = null;
                update testData.payableLines.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            Test.stopTest();

            Map<String, Schema.SObjectField> fields = Schema.SObjectType.Account_Payable_Line__c.fields.getMap();

            System.assertEquals(
                SObjectActions.REQUIRED_FIELD_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @isTest
    private static void testPreventDeleteLinePosted() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables.get(0).Status__c = 'Approved';
            update testData.payables.get(0);

            PostResult result = AccountPayablePostService.postAccountPayables(new List<Account_Payable__c>{testData.payables.get(0)}).get(0);

            System.assertEquals(
                true,
                result.isSuccess
            );

            DMLException dmlEx = null;
            try {
                delete testData.payableLines.get(0);
            } catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR,
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {

            Account_Payable_Line__c payableLine = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables[0].Id,
                Amount__c = 20.989342348934,
                Quantity__c = 10.236746723674344,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );

            insert payableLine;

            Account_Payable_Line__c newPayableLine = [
                SELECT Id,
                    Amount__c,
                    Quantity__c
                FROM Account_Payable_Line__c
                WHERE Id = : payableLine.Id];

            System.assertEquals(20.99, newPayableLine.Amount__c);
            System.assertEquals(10.236747, newPayableLine.Quantity__c);
        }

    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        System.runAs(testData.users.get(1)) {

            testData.payableLines[0].Amount__c = 20.989342348934;
            testData.payableLines[0].Quantity__c = 10.236746723674344;
            testData.payableLines[0].Unit_Cost__c = NULL;

            update testData.payableLines[0];

            Account_Payable_Line__c newPayableLine = [
                SELECT Id,
                    Amount__c,
                    Quantity__c
                FROM Account_Payable_Line__c
                WHERE Id = : testData.payableLines[0].Id];

            System.assertEquals(20.99, newPayableLine.Amount__c);
            System.assertEquals(10.236747, newPayableLine.Quantity__c);
        }

    }

    @IsTest
    public static void testAccountPayableLineNoNullPointerExceptionInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            DMLException dmlEx;
            try {
                Account_Payable_Line__c payLine = new Account_Payable_Line__c();
                insert payLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }
            System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
        }
    }

    @IsTest
    public static void testAccountPayableLineNoNullPointerExceptionInsert_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency();

            System.runAs(testData.users.get(1)) {
                Account_Payable_Line__c payLine = new Account_Payable_Line__c();
                DmlException dmlEx;
                try {
                    insert payLine;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }
                System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyFromParent() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createPayables(false);

            System.runAs(testData.users.get(1)) {
                Test.startTest();

                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }
                String testPayableId = testData.payables[0].Id;
                String parentCurrency = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable__c WHERE Id = :testPayableId')[0].get('CurrencyIsoCode');
                System.assertNotEquals(newCurrency, parentCurrency);

                Account_Payable_Line__c payableLine = new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = 20,
                    Quantity__c = 10,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                );
                payableLine.put('CurrencyIsoCode', newCurrency);

                insert payableLine;

                String lineId = payableLine.Id;
                String lineCurrencyInsert = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

                System.assertEquals(parentCurrency, lineCurrencyInsert);

                payableLine.put('CurrencyIsoCode', newCurrency);

                update payableLine;

                String lineCurrencyUpdate = (String) Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable_Line__c WHERE Id = :lineId')[0].get('CurrencyIsoCode');

                System.assertEquals(parentCurrency, lineCurrencyUpdate);

                Test.stopTest();
            }

        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testClearFieldsWhenTaxGroupRemoved() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setHeaderLevelPost()
            .createPayables(false);

        Test.startTest();
        testData.createTaxGroups();

        System.runAs(testData.users.get(1)) {
            Tax_Group__c taxGroup = testData.taxGroups[1];
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

            line = [SELECT Tax_Inclusive__c, Combined_Tax_Rate__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];
            Assert.areEqual(true, line.Tax_Inclusive__c);
            Assert.isNotNull(line.Combined_Tax_Rate__c);
            Assert.isTrue(line.Combined_Tax_Rate__c > 0);

            line.Tax_Group__c = null;
            update line;

            line = [SELECT Tax_Inclusive__c, Combined_Tax_Rate__c FROM Account_Payable_Line__c WHERE Id = :line.Id LIMIT 1];
            Assert.areEqual(false, line.Tax_Inclusive__c);
            Assert.isNotNull(line.Combined_Tax_Rate__c);
            Assert.areEqual(0, line.Combined_Tax_Rate__c);
        }
    }

}