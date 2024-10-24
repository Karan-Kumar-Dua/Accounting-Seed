@IsTest
public class ALMRowTemplateHelperTest {

    private static final String HEADER_API_NAME = GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Journal_Entry__c';
    private static final String LINE_API_NAME = GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Journal_Entry_Line__c';

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testCreateRowCacheDisabled() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();

        System.runAs(testData.users[1]) {
            ALMRowCreateEvent event = new ALMRowCreateEvent();
            event.lines = [SELECT Id FROM Recurring_Journal_Entry_Line__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries.get(0).Id];
            event.headerId = testData.recurringJournalEntries.get(0).Id;
            event.linesObjectApiName = LINE_API_NAME;
            event.headerObjectApiName = HEADER_API_NAME;
            event.parentRelationshipApiName = HEADER_API_NAME;
            event.createRowsCount = 1;

            Test.startTest();
            List<SObject> response = ALMRowTemplateHelper.createRowCacheDisabled(JSON.serialize(event), '');
            Test.stopTest();

            Assert.areNotEqual(null, response);
            Assert.areEqual(1, response.size());
            Assert.areEqual(testData.recurringJournalEntries.get(0).Id, response[0].get(GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Journal_Entry__c'));
        }
    }

    @IsTest
    static void testCreateRowCacheDisabledWithInvalidTemplate() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();

        System.runAs(testData.users[1]) {
            ALMRowCreateEvent event = new ALMRowCreateEvent();
            event.lines = [SELECT Id FROM Recurring_Journal_Entry_Line__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries.get(0).Id];
            event.headerId = testData.recurringJournalEntries.get(0).Id;
            event.linesObjectApiName = LINE_API_NAME;
            event.headerObjectApiName = HEADER_API_NAME;
            event.parentRelationshipApiName = HEADER_API_NAME;
            event.createRowsCount = 1;

            Test.startTest();
            try {
                List<SObject> response = ALMRowTemplateHelper.createRow(JSON.serialize(event), 'ALMRowCreateEvent');
            } catch (Exception e) {
                Assert.areNotEqual(null, e);
                Assert.areEqual(false, String.isBlank(e.getMessage()));
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateRowCacheDisabledInvalidTemplateException() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();

        System.runAs(testData.users[1]) {
            ALMRowCreateEvent event = new ALMRowCreateEvent();
            event.lines = [SELECT Id FROM Recurring_Journal_Entry_Line__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries.get(0).Id];
            event.headerId = testData.recurringJournalEntries.get(0).Id;
            event.linesObjectApiName = LINE_API_NAME;
            event.headerObjectApiName = HEADER_API_NAME;
            event.parentRelationshipApiName = HEADER_API_NAME;
            event.createRowsCount = 1;

            Test.startTest();
            try {
                List<SObject> response = ALMRowTemplateHelper.createRowCacheDisabled(JSON.serialize(event), 'ALMRowCreateEvent');
            } catch (Exception e) {
                Assert.areNotEqual(null, e);
                Assert.areEqual(false, String.isBlank(e.getMessage()));
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateRowCacheEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();

        System.runAs(testData.users[1]) {
            ALMRowCreateEvent event = new ALMRowCreateEvent();
            event.lines = [SELECT Id FROM Recurring_Journal_Entry_Line__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries.get(0).Id];
            event.headerId = testData.recurringJournalEntries.get(0).Id;
            event.linesObjectApiName = LINE_API_NAME;
            event.headerObjectApiName = HEADER_API_NAME;
            event.parentRelationshipApiName = HEADER_API_NAME;
            event.createRowsCount = 1;

            Test.startTest();
            List<SObject> response = ALMRowTemplateHelper.createRowCacheEnabled(JSON.serialize(event), '');
            Test.stopTest();

            Assert.areNotEqual(null, response);
            Assert.areEqual(1, response.size());
            Assert.areEqual(testData.recurringJournalEntries.get(0).Id, response[0].get(GlobalVariables.PACKAGE_QUALIFIER + 'Recurring_Journal_Entry__c'));
        }
    }

    @IsTest
    static void testCreateRowCacheEnabledWithInvalidTemplate() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();

        System.runAs(testData.users[1]) {
            ALMRowCreateEvent event = new ALMRowCreateEvent();
            event.lines = [SELECT Id FROM Recurring_Journal_Entry_Line__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries.get(0).Id];
            event.headerId = testData.recurringJournalEntries.get(0).Id;
            event.linesObjectApiName = LINE_API_NAME;
            event.headerObjectApiName = HEADER_API_NAME;
            event.parentRelationshipApiName = HEADER_API_NAME;
            event.createRowsCount = 1;

            Test.startTest();
            try {
                List<SObject> response = ALMRowTemplateHelper.createRow(JSON.serialize(event), 'ALMRowCreateEvent');
            } catch (Exception e) {
                Assert.areNotEqual(null, e);
                Assert.areEqual(Label.ERR_INVALID_TEMPLATE, e.getMessage());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateRowCacheEnabledInvalidTemplateException() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringJournalEntry();

        System.runAs(testData.users[1]) {
            ALMRowCreateEvent event = new ALMRowCreateEvent();
            event.lines = [SELECT Id FROM Recurring_Journal_Entry_Line__c WHERE Recurring_Journal_Entry__c = :testData.recurringJournalEntries.get(0).Id];
            event.headerId = testData.recurringJournalEntries.get(0).Id;
            event.linesObjectApiName = LINE_API_NAME;
            event.headerObjectApiName = HEADER_API_NAME;
            event.parentRelationshipApiName = HEADER_API_NAME;
            event.createRowsCount = 1;

            Test.startTest();
            try {
                List<SObject> response = ALMRowTemplateHelper.createRowCacheEnabled(JSON.serialize(event), 'ALMRowCreateEvent');
            } catch (Exception e) {
                Assert.areNotEqual(null, e);
                Assert.areEqual(false, String.isBlank(e.getMessage()));
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreateRowsForPayables() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            ALMRowCreateEvent event = new ALMRowCreateEvent();
            event.lines = [SELECT Id FROM Account_Payable_Line__c WHERE Account_Payable__c = :testData.payables.get(0).Id];
            event.headerId = testData.payables.get(0).Id;
            event.linesObjectApiName = GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable_Line__c';
            event.headerObjectApiName = GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable__c';
            event.parentRelationshipApiName = event.headerObjectApiName;
            event.createRowsCount = 1;

            Test.startTest();
            List<SObject> response = ALMRowTemplateHelper.createRowCacheDisabled(JSON.serialize(event), '');
            Test.stopTest();

            Assert.areNotEqual(null, response);
            Assert.areEqual(1, response.size());
            Assert.areEqual(testData.payables.get(0).Id, response[0].get(GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable__c'));
        }
    }

    @IsTest
    static void testHasRowChangeTemplateTrue() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Boolean response = ALMRowTemplateHelper.hasRowChangeTemplate(SobjectType.Account_Payable__c.getName());
            Test.stopTest();

            Assert.areNotEqual(null, response);
            Assert.areEqual(true, response);
        }
    }

    @IsTest
    static void testHasRowChangeTemplateFalse() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Boolean response = ALMRowTemplateHelper.hasRowChangeTemplate(SobjectType.Billing__c.getName());
            Test.stopTest();

            Assert.areNotEqual(null, response);
            Assert.areEqual(false, response);
        }
    }

    @IsTest
    static void testUpdateALMRow() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            ALMRowChangeEvent event = new ALMRowChangeEvent();
            event.oldRow = testData.payableLines[0];
            event.updatedRow = testData.payableLines[0];
            event.headerObjectApiName = SobjectType.Account_Payable__c.getName();

            Test.startTest();
            SObject response = ALMRowTemplateHelper.updateALMRow(JSON.serialize(event), '');
            Test.stopTest();

            Assert.areNotEqual(null, response);
            Assert.areEqual(testData.payableLines[0].Ledger__c, response.get(GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c'));
            Assert.areEqual(testData.payableLines[0].Date__c, response.get(GlobalVariables.PACKAGE_QUALIFIER + 'Date__c'));
        }
    }

    @IsTest
    static void testUpdateALMRowWithNoImplementationForObject() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            ALMRowChangeEvent event = new ALMRowChangeEvent();
            event.oldRow = testData.payableLines[0];
            event.updatedRow = testData.payableLines[0];
            event.headerObjectApiName = SobjectType.Billing__c.getName();

            Exception ex;
            Test.startTest();
            try {
                SObject response = ALMRowTemplateHelper.updateALMRow(JSON.serialize(event), '');
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();
            Assert.areNotEqual(null, ex);
            Assert.areEqual(false, String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void testUpdatePayableLinesRowInventoryChecked() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createProducts();

        System.runAs(testData.users[1]) {
            testData.accounts.get(0).Default_Expense_GL_Account__c = testData.glAccounts.get(12).Id;
            update testData.accounts.get(0);

            ALMRowChangeEvent event = new ALMRowChangeEvent();
            event.oldRow = testData.payableLines[1];
            testData.payableLines[0].Product__c = testData.products[0].Id;
            event.updatedRow = testData.payableLines[0];
            event.headerObjectApiName = SobjectType.Account_Payable__c.getName();

            Test.startTest();
            SObject response = ALMRowTemplateHelper.updateALMRow(JSON.serialize(event), '');
            Test.stopTest();

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);

            Assert.areNotEqual(null, response);
            Assert.areEqual(defaultsBySpecDevNames.get(GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT)?.GL_Account__c, response.get(GlobalVariables.PACKAGE_QUALIFIER + 'Expense_GL_Account__c'));
        }
    }

    @IsTest
    static void testUpdatePayableLinesRowInventoryUnChecked() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables().createProducts();

        System.runAs(testData.users[1]) {
            ALMRowChangeEvent event = new ALMRowChangeEvent();
            event.oldRow = testData.payableLines[1];
            testData.payableLines[0].Product__c = testData.products[4].Id;
            event.updatedRow = testData.payableLines[0];
            event.headerObjectApiName = SObjectType.Account_Payable__c.getName();

            Test.startTest();
            SObject response = ALMRowTemplateHelper.updateALMRow(JSON.serialize(event), '');
            Test.stopTest();

            Assert.areNotEqual(null, response);
            Assert.areEqual(testData.products[4].Expense_GL_Account__c, response.get(GlobalVariables.PACKAGE_QUALIFIER + 'Expense_GL_Account__c'));
        }
    }

}