@IsTest
private class ActivityStatementsManagerControllerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSaveStatementsAsPDFAttachmentNoRecordsSelected() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
                ActivityStatementsManagerController controller = new ActivityStatementsManagerController(setController);
            Test.stopTest();

            System.assertEquals(true, controller.isAltPayorIncluded);
            System.assertEquals(AbstractStatementManager.NO_RECORDS_SELECTED_ERROR, ApexPages.getMessages()[0].getSummary());
        }

    }

    @IsTest
    private static void testSaveStatementsAsPDFAttachmentPositive() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
            setController.setSelected(testData.accounts);
            ActivityStatementsManagerController controller = new ActivityStatementsManagerController(setController);
            //select Ledger for each of wrapped Customers
            for (ActivityStatementsManagerController.CustomerWrapper wrappedCustomer : controller.wrappedCustomers) {
                wrappedCustomer.selectedLedgerId = wrappedCustomer.availableLedgers[0].getValue();
            }

            controller.savePDFs();
            Test.stopTest();

            System.assertEquals(false, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testData.accounts[0].Id].isEmpty());
        }

    }
    
    @IsTest
    private static void testSaveAndEmailStatementsAsPDFNoRecordsSelected() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
            setController.setSelected(testData.accounts);
            ActivityStatementsManagerController controller = new ActivityStatementsManagerController(setController);

            Test.startTest();
            controller.emailPDFs();
            Test.stopTest();

            System.assertEquals(
                true,
                [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :TestData.accounts[0].Id].isEmpty()
            );
        }
    }

    @IsTest
    private static void testSaveAndEmailStatementsAsPDFPositive() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
                Contact testContact = testData.contacts[0];
                testContact.Email = 'test@mail.com';
                update testContact;

                Account customer = testData.accounts[0];
                customer.AcctSeed__Billing_Contact__c = testContact.Id;
                update customer;

                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
                setController.setSelected(testData.accounts);
                ActivityStatementsManagerController controller = new ActivityStatementsManagerController(setController);
                //select Ledger for each of wrapped Customers
                for (ActivityStatementsManagerController.CustomerWrapper wrappedCustomer : controller.wrappedCustomers) {
                    wrappedCustomer.selectedLedgerId = wrappedCustomer.availableLedgers[0].getValue();
                }

                controller.emailPDFs();
                String pageMessage = String.format(AbstractStatementManager.MAIL_SUCCESS_MESSAGE_FOR_ACCOUNTS, new List<String>{'Activity'});
                System.assertEquals(2, ApexPages.getMessages().size());
                System.assertEquals(pageMessage, ApexPages.getMessages()[1].getSummary());
            Test.stopTest();

            System.assertEquals(false, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :customer.Id].isEmpty());
            Account Acc = [
                SELECT Id, Last_Statement_Sent__c
                FROM Account
                WHERE Id = :customer.Id
            ];
            System.assertEquals(Date.today(), Acc.Last_Statement_Sent__c);
        }
    }
    @IsTest
    public static void testChangeLedgerInMultiCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency().createPaymentProcessors();
            
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                //create new Bank GL Account
                GL_Account__c newBankGlAccount = testData.glAccounts[0].clone(false, true, false, false);
                newBankGlAccount.Name = '1000-Cash-NEW';
                newBankGlAccount.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newBankGlAccount;
                //create Ledger in foreign currency
                Ledger__c newLedger = new Ledger__c(
                    Name = 'Actual-NEW',
                    Type__c = 'Transactional',
                    Default_Bank_Account__c = newBankGlAccount.Id,
                    Default_Billing_Format__c = testData.billingFormats[0].Id,
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                );
                newLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newLedger;

                Test.startTest();
                ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
                setController.setSelected(testData.accounts);
                ActivityStatementsManagerController controller = new ActivityStatementsManagerController(setController);
                
                Assert.areNotEqual(null,controller.wrappedCustomers);
                Assert.areEqual('USD', controller.wrappedCustomers[0].selectedCurrency);                
                controller.wrappedCustomers[0].selectedLedgerId = newLedger.Id;
                controller.changeLedger();
                Assert.areEqual('EUR', controller.wrappedCustomers[0].selectedCurrency);
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }
}