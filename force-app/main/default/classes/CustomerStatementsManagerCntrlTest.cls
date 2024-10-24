@isTest
private class CustomerStatementsManagerCntrlTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testSaveStatementsAsPDFAttachmentNegative() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
            CustomerStatementsManagerController controller = new CustomerStatementsManagerController(setController);

            Test.stopTest();

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
            CustomerStatementsManagerController controller = new CustomerStatementsManagerController(setController);

            System.assertEquals(CustomerStatementsManagerController.NO_SENDER_EMAIL_ERROR, ApexPages.getMessages()[0].getSummary());

            //select Ledger for each of wrapped Customers
            for (CustomerStatementsManagerController.CustomerWrapper wrappedCustomer : controller.wrappedCustomers) {
                wrappedCustomer.selectedLedgerId = wrappedCustomer.availableLedgers[0].getValue();
            }

            controller.savePDFs();
            Test.stopTest();

            System.assertEquals(false, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testData.accounts[0].Id].isEmpty());
        }

    }
    
    @IsTest
    private static void testSaveAndEmailStatementsAsPDFNegative() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
            setController.setSelected(testData.accounts);
            CustomerStatementsManagerController controller = new CustomerStatementsManagerController(setController);

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
            customer.Billing_Contact__c = testContact.Id;
            update customer;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.accounts);
            setController.setSelected(testData.accounts);
            CustomerStatementsManagerController controller = new CustomerStatementsManagerController(setController);
            //select Ledger for each of wrapped Customers
            for (CustomerStatementsManagerController.CustomerWrapper wrappedCustomer : controller.wrappedCustomers) {
                wrappedCustomer.selectedLedgerId = wrappedCustomer.availableLedgers[0].getValue();
            }

            controller.emailPDFs();
            Test.stopTest();

            System.assertEquals(false, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :customer.Id].isEmpty());
            System.assertEquals('No', [SELECT Id, Statement_Needed__c FROM Account WHERE Id = :testData.accounts[0].Id].Statement_Needed__c);
            System.assertEquals(System.today(), [SELECT Id, Last_Statement_Sent__c FROM Account WHERE Id = :testData.accounts[0].Id].Last_Statement_Sent__c);
        }

    }

    @IsTest
    public static void testSetDefaultOWEAddressAccounts() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<OrgWideEmailAddress> specificOrgWideEmailAddress = [SELECT Id, Address FROM OrgWideEmailAddress];

            if (specificOrgWideEmailAddress.isEmpty()) {
                return;
            }

            Billing_Format__c testCustomerStatementFormat = new Billing_Format__c(
                Name = 'Customer Statement',
                Visualforce_PDF_Page__c = 'BillingOutstandingStatementPDF',
                Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName,
                ReplyTo_Email__c = 'test.mail.address@test.com',
                Type__c = 'Outstanding Statement',
                Org_Wide_Email_Address__c = specificOrgWideEmailAddress[0].Address
            );
            insert testCustomerStatementFormat;
            Map<Id, Id> accountIdToLedgerId = new Map<Id, Id>();
            for (Account testAccount : testData.accounts) {
                testAccount.Outstanding_Statement_Format__c = testCustomerStatementFormat.Id;
                accountIdToLedgerId.put(testAccount.Id, testData.ledgers[0].Id);
            }
            update testData.accounts;

            List<Account> accountList = Database.query('SELECT Id, Name, ' +
                'Billing_Contact__c, ' +
                'Billing_Contact__r.FirstName, ' +
                'Billing_Contact__r.LastName, ' +
                'Billing_Contact__r.Email, ' +
                'Outstanding_Statement_Format__c, ' +
                'Outstanding_Statement_Format__r.Visualforce_PDF_Page__c, ' +
                'Outstanding_Statement_Format__r.ReplyTo_Email__c, ' +
                'Outstanding_Statement_Format__r.Default_Email_Template__c, ' +
                'Outstanding_Statement_Format__r.Org_Wide_Email_Address__c, ' +
                'Activity_Statement_Format__c ' +
                'FROM Account');

            AbstractStatementManager.StatementSet statementHandler = new AbstractStatementManager.StatementSet(
                (List<Account>) accountList,
                accountIdToLedgerId,
                new Map<Id, String>(),
                AbstractStatementManager.StatementType.OUTSTANDING,
                NULL,
                NULL
            );

            for (AbstractStatementManager.Statement st : statementHandler.statements) {
                System.assertEquals(specificOrgWideEmailAddress[0].Id, st.owa.Id);
            }
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
                CustomerStatementsManagerController controller = new CustomerStatementsManagerController(setController);
                
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