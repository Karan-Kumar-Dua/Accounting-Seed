@IsTest
public class MassAddEditLineComponentCntrlTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testGetEntryName() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl1 = new MassAddEditLineComponentCntrl();
        elCtrl1.masterRecord = testData.payables[0];
        String resultName = elCtrl1.getEntryName();
        System.assertEquals(resultName, Label.COMMON_PAYABLE);

        MassAddEditLineComponentCntrl elCtrl2 = new MassAddEditLineComponentCntrl();
        elCtrl2.masterRecord = testData.billings[0];
        resultName = elCtrl2.getEntryName();
        System.assertEquals(resultName, Label.COMMON_BILLING);

        MassAddEditLineComponentCntrl elCtrl3 = new MassAddEditLineComponentCntrl();
        elCtrl3.masterRecord = testData.journalEntries[0];
        resultName = elCtrl3.getEntryName();
        System.assertEquals(resultName, Label.COMMON_JOURNAL_ENTRY);
    }

    @IsTest
    private static void testGetEntryAPIName() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl1 = new MassAddEditLineComponentCntrl();
        elCtrl1.masterRecord = testData.payables[0];
        String resultName = elCtrl1.getEntryAPIName();
        System.assertEquals(resultName, Schema.Account_Payable__c.SObjectType.getDescribe().getName());

        MassAddEditLineComponentCntrl elCtrl2 = new MassAddEditLineComponentCntrl();
        elCtrl2.masterRecord = testData.billings[0];
        resultName = elCtrl2.getEntryAPIName();
        System.assertEquals(resultName, Schema.Billing__c.SObjectType.getDescribe().getName());

        MassAddEditLineComponentCntrl elCtrl3 = new MassAddEditLineComponentCntrl();
        elCtrl3.masterRecord = testData.journalEntries[0];
        resultName = elCtrl3.getEntryAPIName();
        System.assertEquals(resultName, Schema.Journal_Entry__c.SObjectType.getDescribe().getName());
    }

    @IsTest
    static void testGetDetailFields() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl1 = new MassAddEditLineComponentCntrl();
        elCtrl1.masterRecord = testData.payables[0];
        List<Schema.FieldSetMember> result = SObjectType.Account_Payable_Line__c.FieldSets.MassAddEditRows.getFields();
        List<Schema.FieldSetMember> resultFields = elCtrl1.getDetailFields();
        System.assert(String.valueOf(result).equals(String.valueOf(resultFields)));

        MassAddEditLineComponentCntrl elCtrl2 = new MassAddEditLineComponentCntrl();
        elCtrl2.masterRecord = testData.billings[0];
        result = SObjectType.Billing_Line__c.FieldSets.MassAddEditRows.getFields();
        resultFields = elCtrl2.getDetailFields();
        System.assert(String.valueOf(result).equals(String.valueOf(resultFields)));

        MassAddEditLineComponentCntrl elCtrl3 = new MassAddEditLineComponentCntrl();
        elCtrl3.masterRecord = testData.journalEntries[0];
        result = SObjectType.Journal_Entry_Line__c.FieldSets.MassAddEditRows.getFields();
        resultFields = elCtrl3.getDetailFields();
        System.assert(String.valueOf(result).equals(String.valueOf(resultFields)));
    }

    @IsTest
    static void testGetMasterFields() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl1 = new MassAddEditLineComponentCntrl();
        elCtrl1.masterRecord = testData.payables[0];
        List<Schema.FieldSetMember> result = SObjectType.Account_Payable__c.FieldSets.MassAddEditRows.getFields();
        List<Schema.FieldSetMember> resultFields = elCtrl1.getMasterFields();
        System.assert(String.valueOf(result).equals(String.valueOf(resultFields)));

        MassAddEditLineComponentCntrl elCtrl2 = new MassAddEditLineComponentCntrl();
        elCtrl2.masterRecord = testData.billings[0];
        result = SObjectType.Billing__c.FieldSets.MassAddEditRows.getFields();
        resultFields = elCtrl2.getMasterFields();
        System.assert(String.valueOf(result).equals(String.valueOf(resultFields)));

        MassAddEditLineComponentCntrl elCtrl3 = new MassAddEditLineComponentCntrl();
        elCtrl3.masterRecord = testData.journalEntries[0];
        result = SObjectType.Journal_Entry__c.FieldSets.MassAddEditRows.getFields();
        resultFields = elCtrl3.getMasterFields();
        System.assert(String.valueOf(result).equals(String.valueOf(resultFields)));
    }

    @IsTest
    private static void testPutNewLine() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        String FS_PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

        MassAddEditLineComponentCntrl elCtrl1 = new MassAddEditLineComponentCntrl();
        elCtrl1.masterRecord = testData.payables[0];
        elCtrl1.initAllLines();
        elCtrl1.putNewLine();
        System.assertEquals(4, elCtrl1.allLines.size());
        System.assertEquals(
                (Date)elCtrl1.allLines[elCtrl1.allLines.size() - 1].rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Date__c'),
                (Date)elCtrl1.masterRecord.get(FS_PACKAGE_QUALIFIER + 'Date__c')
        );

        MassAddEditLineComponentCntrl elCtrl2 = new MassAddEditLineComponentCntrl();
        elCtrl2.masterRecord = testData.billings[0];
        elCtrl2.initAllLines();
        elCtrl2.putNewLine();
        System.assertEquals(3, elCtrl2.allLines.size());
        System.assertEquals(
                (Date)elCtrl2.allLines[elCtrl2.allLines.size() - 1].rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Date__c'),
                (Date)elCtrl2.masterRecord.get(FS_PACKAGE_QUALIFIER + 'Date__c')
        );

        MassAddEditLineComponentCntrl elCtrl3 = new MassAddEditLineComponentCntrl();
        elCtrl3.masterRecord = testData.journalEntries[0];
        elCtrl3.initAllLines();
        elCtrl3.putNewLine();
        System.assertEquals(3, elCtrl3.allLines.size());
        System.assertEquals(
                (Date)elCtrl3.allLines[elCtrl3.allLines.size() - 1].rowContentObj.get(FS_PACKAGE_QUALIFIER + 'Date__c'),
                (Date)elCtrl3.masterRecord.get(FS_PACKAGE_QUALIFIER + 'Journal_Date__c')
        );
    }

    @IsTest
    static void testUnitPriceStdCost() {
        if (AccountingSettingsHandler.isERPEnabled() & AccountingSettingsHandler.isInventoryValuationAverageCost()){
            TestDataSuite testData = TestDataSuite.getInstance()
                    .createAccountingVariables();

            Product2 prod = new Product2(
                    Name = 'Test Prod 1',
                    Inventory_GL_Account__c = testData.glAccounts[22].Id,
                    Expense_GL_Account__c = testData.glAccounts[6].Id,
                    Revenue_GL_Account__c = testData.glAccounts[11].Id,
                    Inventory_Type__c = 'Purchased',
                    Inventory_Product__c = true,
                    Unit_Cost__c = 100
            );
            insert prod;

            MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
            Set<Id> product = new Set<Id>{prod.Id};
            Map<String, SObject> productPrice = elCtrl.getPriceByProductIds(product);
            System.assertEquals(100, productPrice.values()[0].get('Unit_Price__c '));
        }
    }

    @IsTest
    static void testInitAllLinesNegative() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = new Account_Payable__c(
                                    Payee_Reference__c = '2345sdfghtwsrehfdhdfhdfh',
                                    Status__c = 'In Process',
                                    Payment_Status__c = 'Unpaid',
                                    Date__c = testData.acctPeriods[0].Start_Date__c,
                                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                                    Vendor__c = testData.accounts[0].Id,
                                    Discount_Amount__c = 20,
                                    Accounting_Period__c = testData.acctPeriods[0].Id
                               );
        elCtrl.initAllLines();
        System.assertEquals(elCtrl.allLines, new List<MassAddEditLineComponentCntrl.LineWrapper>());
    }

    @IsTest
    static void testDeleteLinePositive() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.billings[0];
        elCtrl.initAllLines();
        System.assertEquals(2, elCtrl.allLines.size());
        System.assertEquals(true, elCtrl.removedRows.isEmpty());
        elCtrl.indexOfRowToDelete = 0;
        elCtrl.deleteLine();
        System.assertNotEquals(true, elCtrl.removedRows.isEmpty());
    }

    @IsTest
    static void testSaveAndRefreshPositive() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.journalEntries[0];
        elCtrl.initAllLines();
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
            2,
            new Journal_Entry_Line__c(
                Journal_Entry__c = testData.journalEntries[0].Id,
                Project__c = testData.projects[0].Id,
                Project_Task__c = testData.projectTasks[0].Id,
                Credit__c = 100,
                GL_Account__c = testData.glAccounts[0].Id,
                Units__c = 10,
                Reference__c = 'the reference 1'
            ),
            elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndRefresh();
        System.assertNotEquals(true, elCtrl.isError);
        System.assertEquals(3, [SELECT Id FROM Journal_Entry_Line__c WHERE Journal_Entry__r.Id = :testData.journalEntries[0].Id].size());
    }

    @IsTest
    static void testSaveAndRefreshNegative() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.payables[0];
        elCtrl.allLines = new List<MassAddEditLineComponentCntrl.LineWrapper>();
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
            0,
            new Account_Payable_Line__c(
                Account_Payable__c = NULL,
                Amount__c = 550,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = NULL
            ),
            elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndRefresh();

        System.assertEquals(MassAddEditLineComponentCntrl.VALIDATION_ERROR, ApexPages.getMessages()[0].getDetail());
    }

    @IsTest
    static void testSaveAndCompletePositive() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.payables[0];
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
            0,
            new Account_Payable_Line__c(
                Account_Payable__c = elCtrl.masterRecord.Id,
                Amount__c = 550,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[25].Id
            ),
            elCtrl.wrappedDetailFields
        ));

        PageReference pageRef = elCtrl.saveAndComplete();

        System.assertEquals(false, elCtrl.isError);
        System.assertEquals(4, [SELECT count() FROM Account_Payable_Line__c WHERE Account_Payable__r.Id = :testData.payables[0].Id]);
        System.assertEquals('/' + testData.payables[0].Id, pageRef.getUrl());
    }

    @isTest static void testSaveAndCompleteNegative() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.payables[0];
        elCtrl.allLines = new List<MassAddEditLineComponentCntrl.LineWrapper>();
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
            0,
            new Account_Payable_Line__c(
                Account_Payable__c = NULL,
                Amount__c = 550,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = NULL
            ),
            elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndComplete();

        System.assertEquals(MassAddEditLineComponentCntrl.VALIDATION_ERROR, ApexPages.getMessages()[0].getDetail());
    }

    @isTest static void testSaveAndNewPositive() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.payables[0];
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
            0,
            new Account_Payable_Line__c(
                Account_Payable__c = elCtrl.masterRecord.Id,
                Amount__c = 550,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[25].Id
            ),
            elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndRefresh();
        PageReference pageRef = elCtrl.redirectToNew();

        System.assertEquals(false, elCtrl.isError);
        System.assertEquals(4, [SELECT count() FROM Account_Payable_Line__c WHERE Account_Payable__r.Id = :testData.payables[0].Id]);
        System.assertEquals('/' + elCtrl.masterRecord.getSObjectType().getDescribe().getKeyPrefix() + '/e?retURL=' + elCtrl.masterRecord.Id, pageRef.getUrl());
    }

    @isTest static void testSaveAndNewNegative() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.payables[0];
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
            0,
            new Account_Payable_Line__c(
                Account_Payable__c = elCtrl.masterRecord.Id,
                Amount__c = 550,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = NULL
            ),
            elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndRefresh();
        elCtrl.redirectToNew();

        System.assertEquals(MassAddEditLineComponentCntrl.VALIDATION_ERROR, ApexPages.getMessages()[0].getDetail());
    }

    @isTest static void testSaveAndPostPayable() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        testData.payables[0].Status__c = 'Approved';
        update testData.payables[0];
        elCtrl.masterRecord = testData.payables[0];
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
                0,
                new Account_Payable_Line__c(
                        Account_Payable__c = elCtrl.masterRecord.Id,
                        Amount__c = 550,
                        Date__c = testData.acctPeriods[0].Start_Date__c,
                        Expense_GL_Account__c = testData.glAccounts[25].Id
                ),
                elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndPost();

        System.assertEquals(false, elCtrl.isError);
        System.assertEquals('Posted', [SELECT Id, Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Status__c);
    }

    @IsTest
    static void testSaveAndPostJE() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();

        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        testData.journalEntries[0].Status__c = 'Approved';
        update testData.journalEntries[0];
        elCtrl.masterRecord = testData.journalEntries[0];
        elCtrl.initAllLines();
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
                1,
                new Journal_Entry_Line__c(
                        Journal_Entry__c = testData.journalEntries[0].Id,
                        Project__c = testData.projects[0].Id,
                        Project_Task__c = testData.projectTasks[0].Id,
                        Credit__c = 100,
                        GL_Account__c = testData.glAccounts[0].Id,
                        Units__c = 10,
                        Reference__c = 'the reference 1'
                ),
                elCtrl.wrappedDetailFields
        ));

        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
                2,
                new Journal_Entry_Line__c(
                        Journal_Entry__c = testData.journalEntries[0].Id,
                        Project__c = testData.projects[0].Id,
                        Project_Task__c = testData.projectTasks[0].Id,
                        Debit__c = 100,
                        GL_Account__c = testData.glAccounts[0].Id,
                        Units__c = 10,
                        Reference__c = 'the reference 1'
                ),
                elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndPost();
        System.assertEquals(false, elCtrl.isError);
        System.assertEquals('Posted', [SELECT Id, Status__c FROM Journal_Entry__c WHERE Id = :testData.journalEntries[0].Id].Status__c);
    }

    @isTest
    private static void testSaveAndPostBilling() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProjects();
        testData.createProjectTasks();
        testData.createJournalEntries();

        Test.startTest();
        testData.createPayables();
        testData.createBillings();
        testData.createProducts();

        MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
        elCtrl.masterRecord = testData.billings[0];
        elCtrl.initAllLines();
        elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
            1,
            new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Hours_Units__c = 20,
                Rate__c = 10,
                Revenue_GL_Account__c = testData.glAccounts[10].Id
            ),
            elCtrl.wrappedDetailFields
        ));

        elCtrl.saveAndPost();

        Test.stopTest();
        System.assertEquals(false, elCtrl.isError);
        System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
    }

    @IsTest
    private static void testUpdateBillingLineWithAvalaraTaxLineUpsert() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createProducts();

        Test.startTest();
        testData.createBillings();
        testData.createAccountingVariables();
        testData.enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            MassAddEditLineComponentCntrl elCtrl = new MassAddEditLineComponentCntrl();
            testData.billings[0].Ledger__c = testData.ledgers[0].Id;
            update testData.billings[0];
            elCtrl.masterRecord = testData.billings[0];
            elCtrl.initAllLines();
            elCtrl.allLines.clear();
            elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
                1,
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 20,
                    Rate__c = 10,
                    Revenue_GL_Account__c = testData.glAccounts[10].Id
                ),
                elCtrl.wrappedDetailFields
            ));
            elCtrl.allLines.add(new MassAddEditLineComponentCntrl.LineWrapper(
                1,
                new Billing_Line__c(
                    Billing__c = testData.billings[0].Id,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Hours_Units__c = 1,
                    Rate__c = 15,
                    Revenue_GL_Account__c = testData.glAccounts[28].Id,
                    GL_Account_Variable_1__c = testData.accountingVariables1[0].Id
                ),
                elCtrl.wrappedDetailFields
            ));

            AvaTaxService.TransactionModel avaTaxTransaction = new AvaTaxService.TransactionModel();
            avaTaxTransaction.avaTaxDate = Date.today();
            avaTaxTransaction.totalTax = 15;

            Boolean exceptionThrown = false;
            try {
                elCtrl.upsertSalesTaxLine(avaTaxTransaction, testData.billings[0]);
            }
            catch (Exception ex) {
                exceptionThrown = true;
            }

            System.assertNotEquals(true, exceptionThrown);
        }
    }

}