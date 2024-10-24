@IsTest
private class NavToCreateControllerTest {
    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest static void testInitPositive() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createGLAccountExpenses()
                .createPayables();

        System.runAs(testData.users.get(1)) {
            List<Account> accounts = new List<Account>{new Account(
                    Id = testData.accounts.get(0).Id,
                    Default_Expense_GL_Account__c = testData.glAccountsExpense.get(0).Id
            )};
            update accounts;
            List<Account_Payable__c> accountPayables = new List<Account_Payable__c>{new Account_Payable__c(
                    Id = testData.payables.get(0).Id,
                    Vendor__c = accounts[0].Id
            )};
            update accountPayables;
            System.currentPageReference().getParameters().put('Id', testData.payables.get(0).Id);
            NavToCreateController cnt = new NavToCreateController(new ApexPages.StandardSetController(testData.payableLines));
            System.assert(!cnt.isError);
            System.assert(cnt.redirectUrl.contains(testData.payables.get(0).Id));
            System.assert(cnt.redirectUrl.contains(Account_Payable__c.getSObjectType().getDescribe().name));
            System.assert(cnt.redirectUrl.contains(Account_Payable_Line__c.getSObjectType().getDescribe().name));
        }
    }

    @isTest static void testInitPositive2() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createBillings();

        System.runAs(testData.users.get(1)) {
            System.currentPageReference().getParameters().put('Id', testData.billings.get(0).Id);
            NavToCreateController cnt = new NavToCreateController(new ApexPages.StandardSetController(testData.billingLines));
            System.assert(!cnt.isError);
            System.assert(cnt.redirectUrl.contains(testData.billings.get(0).Id));
            System.assert(cnt.redirectUrl.contains(Billing__c.getSObjectType().getDescribe().name));
            System.assert(cnt.redirectUrl.contains(Billing_Line__c.getSObjectType().getDescribe().name));
        }
    }

    @isTest static void testInitPositive3() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createProjects()
                .createProjectTasks()
                .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            System.currentPageReference().getParameters().put('Id', testData.journalEntries.get(0).Id);
            NavToCreateController cnt = new NavToCreateController(new ApexPages.StandardSetController(testData.journalEntryLines));
            System.assert(!cnt.isError);
            System.assert(cnt.redirectUrl.contains(testData.journalEntries.get(0).Id));
            System.assert(cnt.redirectUrl.contains(Journal_Entry__c.getSObjectType().getDescribe().name));
            System.assert(cnt.redirectUrl.contains(Journal_Entry_Line__c.getSObjectType().getDescribe().name));
        }
    }

    @isTest static void testInitPositive4() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            System.currentPageReference().getParameters().put('Id', testData.recurringPayables.get(0).Id);
            NavToCreateController cnt = new NavToCreateController(new ApexPages.StandardSetController(testData.recurringPayableLines));
            System.assert(!cnt.isError);
            System.assert(cnt.redirectUrl.contains(testData.recurringPayables.get(0).Id));
            System.assert(cnt.redirectUrl.contains(Recurring_Account_Payable__c.getSObjectType().getDescribe().name));
            System.assert(cnt.redirectUrl.contains(Recurring_Account_Payable_Line__c.getSObjectType().getDescribe().name));
        }
    }

    @isTest static void testInitPositive5() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringBilling()
                .createRecurringBillingLines();

        System.runAs(testData.users.get(1)) {
            System.currentPageReference().getParameters().put('Id', testData.recurringBillings.get(0).Id);
            NavToCreateController cnt = new NavToCreateController(new ApexPages.StandardSetController(testData.recurringBillingLines));
            System.assert(!cnt.isError);
            System.assert(cnt.redirectUrl.contains(testData.recurringBillings.get(0).Id));
            System.assert(cnt.redirectUrl.contains(Recurring_Billing__c.getSObjectType().getDescribe().name));
            System.assert(cnt.redirectUrl.contains(Recurring_Billing_Line__c.getSObjectType().getDescribe().name));
        }
    }

    @isTest static void testInitNegativeId() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            NavToCreateController cnt = new NavToCreateController(new ApexPages.StandardSetController(testData.payableLines));
            System.assertEquals(true, cnt.isError);
        }

    }

    @isTest static void testInitNegativeMasterRecord() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            System.currentPageReference().getParameters().put('Id', testData.payables[0].Id);
            AbstractPostHandler apdPostHandler = new APDisbursementPostHandler();
            delete testData.payables[0];
            NavToCreateController cnt = new NavToCreateController(new ApexPages.StandardSetController(testData.payableLines));

            System.assertEquals(true, cnt.isError);
        }

    }
}