@IsTest
private class InventoryTransactionHandlerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetInvCostTransactionsIncludeKitChildProductsInventoryTypeKit() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createBillings()
            .createProductParts()
            .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            List<Transaction__c> transList = InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList);
            System.assertEquals(0, transList.size());

            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();
            its.ledgerId = testData.ledgers[0].Id;
            its.productId = testData.products[2].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.sourceId = testData.billingLines[0].Id;
            its.inventoryType = 'Kit';
            its.quantity = 40.0;
            its.unitCost = 100.0;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            itsList.add(its);
            System.assertEquals(4, InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList).size());
        }
    }

    @IsTest
    private static void testGetInvCostTransactionsIncludeKitChildProductsInventoryTypeNotKit() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createBillings()
            .createProductParts()
            .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            List<Transaction__c> transList = InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList);
            System.assertEquals(0, transList.size());

            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();
            its.ledgerId = testData.ledgers[0].Id;
            its.productId = testData.products[2].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.sourceId = testData.billingLines[0].Id;
            its.inventoryType = 'Manufactured';
            its.quantity = 40.0;
            its.unitCost = 100.0;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            itsList.add(its);
            System.assertEquals(2, InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList).size());
        }
    }

    @IsTest
    private static void testGetInvCostTransactionsIncludeKitChildProductsAndUnitCostNull () {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createBillings()
            .createProductParts()
            .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            List<Transaction__c> transList = InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList);
            System.assertEquals(0, transList.size());

            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();
            its.ledgerId = testData.ledgers[0].Id;
            its.productId = testData.products[2].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.sourceId = testData.billingLines[0].Id;
            its.inventoryType = 'Kit';
            its.quantity = 40.0;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            itsList.add(its);
            System.assertEquals(4, InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList).size());
        }
    }

    @IsTest
    private static void testCreateInvCostTransactionsExcludeKitChildProducts() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createAccountingVariables()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();

            its.ledgerId = testData.ledgers[0].Id;
            its.sourceId = testData.billingLines[0].Id;
            its.productId = testData.products[2].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.inventoryType = 'Kit';
            its.quantity = 40.0;
            its.unitCost = 100.0;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            its.glVariable1 = testData.accountingVariables1[0].Id;
            itsList.add(its);
            InventoryTransactionHandler.createInvCostTransactionsExcludeKitChildProducts(itsList);

            System.assertEquals(2, [SELECT COUNT() FROM Transaction__c]);
        }
    }

    @IsTest
    private static void testCreateInvCostTransactionsExcludeKitChildProductsIfProductNull() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createAccountingVariables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {
            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();
            its.ledgerId = testData.ledgers[0].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.inventoryType = 'Kit';
            its.quantity = 40.0;
            its.sourceId = testData.billingLines[0].Id;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            its.glVariable1 = testData.accountingVariables1[0].Id;
            itsList.add(its);

            InventoryTransactionHandler.createInvCostTransactionsExcludeKitChildProducts(itsList);
            System.assertEquals(0, [SELECT COUNT() FROM Transaction__c]);
        }
    }

    @IsTest
    private static void testInvCostTransactionsExcludeKitChildProductsRounding() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createBillings()
            .createProductParts()
            .createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();

            its.ledgerId = testData.ledgers[0].Id;
            its.productId = testData.products[2].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.sourceId = testData.billingLines[0].Id;
            its.inventoryType = 'Kit';
            its.unitcost = 50.00999;
            its.quantity = 40.00999;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            itsList.add(its);

            InventoryTransactionHandler.createInvCostTransactionsExcludeKitChildProducts(itsList);
            System.assertEquals(2, [SELECT COUNT() FROM Transaction__c]);

            for(Transaction__c inventoryTrans :[SELECT id, Amount__c FROM Transaction__c]){
                System.assertEquals(2000.90, Math.abs(inventoryTrans.Amount__c));
            }
        }
    }

    @IsTest
    private static void testInvCostTransactionsIncludeKitChildProductsRounding() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setInventoryValuationStandardCost()
            .createProducts()
            .createProjects()
            .createProjectTasks()
            .createGLAccountExpenses()
            .createBillings()
            .createProductParts();

        Test.startTest();
        testData.createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            List<Product_Part__c> productParts = new List<Product_Part__c>([
                SELECT Id, Quantity__c FROM Product_Part__c WHERE Product__c = :testData.products[2].Id
            ]);

            for (Product_Part__c productPart : productParts) {
                productPart.Quantity__c = 2.00;
            }
            update productParts;

            List<InventoryTransactionHandler.InventoryTransactionSource> itsList = new List<InventoryTransactionHandler.InventoryTransactionSource>();
            List<Transaction__c> transList = InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList);
            System.assertEquals(0, transList.size());

            InventoryTransactionHandler.InventoryTransactionSource its =  new InventoryTransactionHandler.InventoryTransactionSource();
            its.ledgerId = testData.ledgers[0].Id;
            its.productId = testData.products[2].Id;
            its.projectId = testData.projects[0].Id;
            its.projectTaskId = testData.projectTasks[0].Id;
            its.accountId = testData.accounts[0].Id;
            its.accountingPeriodId = testData.acctPeriods[0].Id;
            its.sourceDate = Date.today();
            its.debitGLAccountId = testData.glAccountsExpense[0].Id;
            its.creditGLAccountId = testData.glAccounts[0].Id;
            its.sourceId = testData.billingLines[0].Id;
            its.inventoryType = 'Kit';
            its.quantity = 40.00999;
            its.itemSourceType = InventoryTransactionHandler.SourceType.BILLING_LINE;
            itsList.add(its);

            TransactionActions.createTransactions(InventoryTransactionHandler.getInvCostTransactionsIncludeKitChildProducts(itsList));
            System.assertEquals(4, [SELECT COUNT() FROM Transaction__c]);
            System.assertEquals(8002, [SELECT Id, Amount__c FROM Transaction__c WHERE Product__c = :testData.products[0].Id AND Amount__c > 0].Amount__c);
        }
    }

}