@IsTest
public class BillingStatementManagerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testSaveAttachmentSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingStatementManager bsm = new BillingStatementManager(
                new ApexPages.StandardController(testData.accounts[0])
            );
            bsm.saveAttach();
            System.assertEquals(1, [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :testData.accounts[0].Id]);
        }
    }

    @IsTest
    private static void testOutstandingStmtNotOnAccountMailSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account act = testData.accounts.get(2);
            testData.contacts[0].Email = 'test@mail.com';
            act.Billing_Contact__c = testData.contacts[0].Id;
            act.Outstanding_Statement_Format__c = NULL;
            act.Activity_Statement_Format__c = NULL;
            update testData.contacts[0];
            update act;

            BillingStatementManager bsm = new BillingStatementManager(
                    new ApexPages.StandardController(act)
            );
            bsm.saveAndEmail();
            System.assertEquals(1, [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :act.Id]);
        }
    }

    @IsTest
    public static void testSendEmailNoSenderError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingStatementManager bsm = new BillingStatementManager(
                new ApexPages.StandardController(testData.accounts[0])
            );

            System.assertEquals(true, bsm.getDisableOutstandingEmail());
            System.assertEquals(true, bsm.getDisableActivityEmail());
        }
    }

    @IsTest
    public static void testOutstandingSendEmailNoEmailTemplateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingStatementManager bsm = new BillingStatementManager(
                new ApexPages.StandardController(testData.accounts[0])
            );
            bsm.selectedTab = 'outstanding';
            bsm.outstandingAccount.Billing_Contact__c = testData.contacts[0].Id;
            bsm.setOutstandingContact();

            System.assert(true, bsm.getDisableOutstandingEmail());
            System.assertEquals(AbstractStatementManager.NO_EMAIL_ERROR, ApexPages.getMessages()[0].getSummary());
        }
    }
  
    @IsTest
    public static void testActivitySendEmailNoEmailTemplateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingStatementManager bsm = new BillingStatementManager(
                new ApexPages.StandardController(testData.accounts[0])
            );
            bsm.selectedTab = 'activity';
            bsm.activityAccount.Billing_Contact__c = testData.contacts[0].Id;
            bsm.setActivityContact();

            System.assert(true, bsm.getDisableActivityEmail());
            System.assertEquals(AbstractStatementManager.NO_EMAIL_ERROR, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testOutstandingSendEmailBillingContactSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.contacts[0].Email = 'test11234234@gmail.com';
            update testData.contacts[0];

            BillingStatementManager bsm = new BillingStatementManager(
                new ApexPages.StandardController(testData.accounts[0])
            );
            bsm.selectedTab = 'outstanding';
            bsm.outstandingCCUser = true;
            bsm.outstandingAccount.Billing_Contact__c = testData.contacts[0].Id;
            bsm.setOutstandingContact();
            bsm.saveAndEmail();

            System.assertEquals(false, bsm.getDisableOutstandingEmail());
            System.assertEquals(true, ApexPages.getMessages()[0].getSummary().contains(AbstractStatementManager.EMAIL_SENT_SUCCESS));
        }
    }

    @IsTest
    public static void testActivitySendEmailBillingContactSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.contacts[0].Email = 'test11234234@gmail.com';
            update testData.contacts[0];

            BillingStatementManager bsm = new BillingStatementManager(
                new ApexPages.StandardController(testData.accounts[0])
            );
            bsm.selectedTab = 'activity';
            bsm.activityCCUser = true;
            bsm.activityAccount.Billing_Contact__c = testData.contacts[0].Id;
            bsm.setActivityContact();
            bsm.saveAndEmail();
            System.assertEquals(false, bsm.getDisableActivityEmail());
            System.assertEquals(true, ApexPages.getMessages()[0].getSummary().contains(AbstractStatementManager.EMAIL_SENT_SUCCESS));
        }
    }

    @IsTest
    public static void testOutstandingSendEmailBillingContactSuccessWithCustomFormat() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.contacts[0].Email = 'test11234234@gmail.com';
            update testData.contacts[0];

            Billing_Format__c testCustomerStatementFormat = new Billing_Format__c(
                Name = 'Customer Statement',
                Visualforce_PDF_Page__c = 'BillingOutstandingStatementPDF',
                Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName,
                ReplyTo_Email__c = 'test.mail.address@gmail.com',
                Type__c = 'Customer Statement'
            );
            insert testCustomerStatementFormat;

            Account testAccount = testData.accounts[0];
            testAccount.Outstanding_Statement_Format__c = testCustomerStatementFormat.Id;
            update testAccount;

            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            bsm.selectedTab = 'outstanding';
            bsm.outstandingCCUser = true;
            bsm.outstandingAccount.Billing_Contact__c = testData.contacts[0].Id;
            bsm.setOutstandingContact();
            bsm.saveAndEmail();

            System.assertEquals(false, bsm.getDisableOutstandingEmail());
            System.assertEquals(true, ApexPages.getMessages()[0].getSummary().contains(AbstractStatementManager.EMAIL_SENT_SUCCESS));
        }
    }

    @IsTest
    public static void testChangeStatement() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            List<Billing_Format__c> statements = new List<Billing_Format__c>();

            Billing_Format__c testCustomerOutstandingStatementFormat = new Billing_Format__c(
                Name = 'Outstanding Statement Modern',
                Visualforce_PDF_Page__c = 'BillingOutstandingStmtModernPDF',
                Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName,
                ReplyTo_Email__c = 'test.mail.address2@gmail.com',
                Type__c = 'Outstanding Statement'
            );
            statements.add(testCustomerOutstandingStatementFormat);

            Billing_Format__c testCustomerActivityStatementFormat = new Billing_Format__c(
                Name = 'Activity Statement Modern',
                Visualforce_PDF_Page__c = 'BillingActivityStmtModernPDF',
                Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName,
                ReplyTo_Email__c = 'test.mail.address3@gmail.com',
                Type__c = 'Activity Statement'
            );
            statements.add(testCustomerActivityStatementFormat);

            insert statements;

            Test.startTest();
            Account testAccount = testData.accounts[0];
            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            System.assertNotEquals(testCustomerOutstandingStatementFormat.Id, bsm.outstandingPdfFormat.Id);
            System.assertNotEquals(testCustomerActivityStatementFormat.Id, bsm.activityPdfFormat.Id);

            bsm.selectedTab = 'outstanding';
            bsm.outstandingCCUser = true;
            List<System.SelectOption> ledgerSelectOptions = bsm.getAllLedgers();
            System.assertEquals(4, ledgerSelectOptions.size());

            bsm.proxyOutstandingPdfFormat.Outstanding_Statement_Format__c = testCustomerOutstandingStatementFormat.Id;
            bsm.proxyActivityPdfFormat.Activity_Statement_Format__c = testCustomerActivityStatementFormat.Id;

            bsm.changeOutstandingPDFFormat();
            bsm.changeActivityPDFFormat();
            System.assertEquals(testCustomerOutstandingStatementFormat.Id, bsm.outstandingPdfFormat.Id);
            System.assertEquals(testCustomerActivityStatementFormat.Id, bsm.activityPdfFormat.Id);

        }
    }

    @IsTest
    public static void testSetContactRemotePositive() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Contact testContact = testData.contacts[0];
            testContact.Email = 'test11234234@gmail.com';
            update testContact;

            Account testAccount = testData.accounts[0];
            testAccount.Billing_Contact__c = testData.contacts[0].Id;
            update testAccount;

            AbstractStatementManager.RemoteActionResult outstandingResult = BillingStatementManager.setContactRemote(
                testAccount.Id, testContact.Id, 'outstanding', LedgerHandler.getLedgerId()
            );

            System.assertEquals(true, outstandingResult.isValidContact);
            System.assertEquals(false, (outstandingResult.template == NULL));

            AbstractStatementManager.RemoteActionResult activityResult = BillingStatementManager.setContactRemote(
                testAccount.Id, testContact.Id, 'activity', LedgerHandler.getLedgerId()
            );

            System.assertEquals(true, activityResult.isValidContact);
            System.assertEquals(false, (activityResult.template == NULL));
        }
    }

    @IsTest
    public static void testSetContactRemoteNoPdfFormat() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();

            Contact testContact = testData.contacts[0];
            testContact.Email = 'test11234234@gmail.com';
            update testContact;

            Account testAccount = testData.accounts[0];
            testAccount.Billing_Contact__c = testData.contacts[0].Id;
            update testAccount;

            AbstractStatementManager.RemoteActionResult outstandingResult = BillingStatementManager.setContactRemote(
                testAccount.Id, testContact.Id, 'outstanding', testData.ledgers[1].Id
            );

            System.assertEquals(false, outstandingResult.isValidContact);
            System.assertEquals(BillingStatementManager.NO_OUTSTANDING_PDF_FORMAT_DEFINED_ERROR, outstandingResult.errorMessage);

            AbstractStatementManager.RemoteActionResult activityResult = BillingStatementManager.setContactRemote(
                testAccount.Id, testContact.Id, 'activity', testData.ledgers[1].Id
            );

            System.assertEquals(false, activityResult.isValidContact);
            System.assertEquals(BillingStatementManager.NO_ACTIVITY_PDF_FORMAT_DEFINED_ERROR, activityResult.errorMessage);
        }
    }

    @IsTest
    public static void testSetContactRemoteNoContactEmail() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Contact testContact = testData.contacts[0];
            Account testAccount = testData.accounts[0];
            testAccount.Billing_Contact__c = testData.contacts[0].Id;
            update testAccount;

            AbstractStatementManager.RemoteActionResult outstandingResult = BillingStatementManager.setContactRemote(
                testAccount.Id, testContact.Id, 'outstanding', LedgerHandler.getLedgerId()
            );

            System.assertEquals(false, outstandingResult.isValidContact);
            System.assertEquals(AbstractStatementManager.NO_EMAIL_ERROR, outstandingResult.errorMessage);

            AbstractStatementManager.RemoteActionResult activityResult = BillingStatementManager.setContactRemote(
                testAccount.Id, testContact.Id, 'activity', LedgerHandler.getLedgerId()
            );

            System.assertEquals(false, activityResult.isValidContact);
            System.assertEquals(AbstractStatementManager.NO_EMAIL_ERROR, activityResult.errorMessage);
        }
    }

    @IsTest
    public static void testChangeCurrency() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();
                Account testAccount = testData.accounts[0];
                BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
                bsm.selectedTab = 'outstanding';
                bsm.outstandingCCUser = true;
                List<System.SelectOption> currencySelectOptions = bsm.availableCurrencies;
                System.assertEquals(MultiCurrencyHandler.getAllCurrenciesSelectOptions(), currencySelectOptions);

                String accountId = testData.accounts[0].Id;
                String accountCurrency = (String) Database.query('SELECT CurrencyIsoCode FROM Account WHERE Id = :accountId')[0].get('CurrencyIsoCode');

                System.assertEquals(accountCurrency, bsm.outstandingBill.get('CurrencyIsoCode'));
                System.assertEquals(accountCurrency, bsm.activityBill.get('CurrencyIsoCode'));

                bsm.outstandingBill.put('CurrencyIsoCode', currencySelectOptions[1].getValue());
                bsm.activityBill.put('CurrencyIsoCode', currencySelectOptions[1].getValue());

                bsm.changeOutstandingCurrencyIsoCode();
                System.assertEquals(currencySelectOptions[1].getValue(), bsm.outstandingBill.get('CurrencyIsoCode'));

                bsm.changeActivityCurrencyIsoCode();
                System.assertEquals(currencySelectOptions[1].getValue(), bsm.activityBill.get('CurrencyIsoCode'));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testChangeOutstandingLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Account testAccount = testData.accounts[0];
            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            bsm.selectedTab = 'outstanding';
            bsm.outstandingCCUser = true;

            System.assertEquals(testData.ledgers[0].Id, bsm.outstandingBill.Ledger__c);

            bsm.outstandingBill.Ledger__c = testData.ledgers[2].Id;
            bsm.changeOutstandingLedger();

            System.assertEquals(testData.ledgers[2].Id, bsm.outstandingStatementManager.ledgerId);

        }
    }

    @IsTest
    public static void testChangeActivityLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Account testAccount = testData.accounts[0];
            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            bsm.selectedTab = 'activity';
            bsm.outstandingCCUser = true;

            System.assertEquals(testData.ledgers[0].Id, bsm.activityBill.Ledger__c);

            bsm.activityBill.Ledger__c = testData.ledgers[2].Id;
            bsm.changeActivityLedger();

            System.assertEquals(testData.ledgers[2].Id, bsm.activityStatementManager.ledgerId);

        }
    }

    @IsTest
    public static void testSetActivityDefaultOWEAddress() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<OrgWideEmailAddress> specificOrgWideEmailAddress = [SELECT Id, Address FROM OrgWideEmailAddress];

            if (specificOrgWideEmailAddress.isEmpty()) {
                return;
            }

            Billing_Format__c testCustomerStatementFormat = new Billing_Format__c(
                Name = 'Customer Statement',
                Visualforce_PDF_Page__c = 'BillingActivityStatementPDF',
                Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName,
                ReplyTo_Email__c = 'test.mail.address@test.com',
                Type__c = 'Activity Statement',
                Org_Wide_Email_Address__c = specificOrgWideEmailAddress[0].Address
            );
            insert testCustomerStatementFormat;

            Account testAccount = testData.accounts[0];
            testAccount.Activity_Statement_Format__c = testCustomerStatementFormat.Id;
            update testAccount;

            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            bsm.selectedTab = 'activity';

            System.assertEquals(specificOrgWideEmailAddress[0].Id, bsm.activitySelectedOrgWideEmailAddress);
        }
    }

    @IsTest
    public static void testUpdateActivityDefaultOWEAddress() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<OrgWideEmailAddress> specificOrgWideEmailAddress = [SELECT Id, Address FROM OrgWideEmailAddress];

            if (specificOrgWideEmailAddress.isEmpty()) {
                return;
            }

            Billing_Format__c testCustomerStatementFormat = new Billing_Format__c(
                Name = 'Customer Statement',
                Visualforce_PDF_Page__c = 'BillingActivityStatementPDF',
                Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName,
                ReplyTo_Email__c = 'test.mail.address@test.com',
                Type__c = 'Activity Statement',
                Org_Wide_Email_Address__c = specificOrgWideEmailAddress[0].Address
            );
            insert testCustomerStatementFormat;

            Account testAccount = testData.accounts[0];

            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            bsm.selectedTab = 'activity';

            System.assertNotEquals(specificOrgWideEmailAddress[0].Id, bsm.activitySelectedOrgWideEmailAddress);
            bsm.proxyActivityPdfFormat.Activity_Statement_Format__c = testCustomerStatementFormat.Id;
            bsm.changeActivityPDFFormat();

            System.assertEquals(specificOrgWideEmailAddress[0].Id, bsm.activitySelectedOrgWideEmailAddress);
        }
    }

    @IsTest
    public static void testSetOutstandingDefaultOWEAddress() {
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

            Account testAccount = testData.accounts[0];
            testAccount.Outstanding_Statement_Format__c = testCustomerStatementFormat.Id;
            update testAccount;

            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            bsm.selectedTab = 'outstanding';

            System.assertEquals(specificOrgWideEmailAddress[0].Id, bsm.outstandingSelectedOrgWideEmailAddress);
        }
    }

    @IsTest
    public static void testUpdateOutstandingDefaultOWEAddress() {
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

            Account testAccount = testData.accounts[0];

            BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
            bsm.selectedTab = 'outstanding';

            System.assertNotEquals(specificOrgWideEmailAddress[0].Id, bsm.outstandingSelectedOrgWideEmailAddress);
            bsm.proxyOutstandingPdfFormat.Outstanding_Statement_Format__c = testCustomerStatementFormat.Id;
            bsm.changeOutstandingPDFFormat();

            System.assertEquals(specificOrgWideEmailAddress[0].Id, bsm.outstandingSelectedOrgWideEmailAddress);
        }
    }

    @IsTest
    private static void testSaveAndEmail_PersonAccount() {
        if (TestDataSuite.isPersonAccountsEnabled()) {
            TestDataSuite testData = TestDataSuite.getInstance().createPersonAccounts();

            System.runAs(testData.users[1]) {
                Contact billingContact = testData.contacts[0];
                billingContact.Email = 'test@mail.com';
                update billingContact;

                Account acct = testData.personAccounts[0];
                acct.Billing_Contact__c = billingContact.Id;
                acct.Outstanding_Statement_Format__c = testData.billingFormats[2].Id;
                acct.Activity_Statement_Format__c = testData.billingFormats[3].Id;
                update acct;

                Test.startTest();
                BillingStatementManager bsm = new BillingStatementManager(
                        new ApexPages.StandardController(acct)
                );
                bsm.saveAndEmail();
                Test.stopTest();

                System.assert(!ApexPages.hasMessages(ApexPages.SEVERITY.ERROR));
            }
        }
    }
    @IsTest
    public static void testChangeOutstandingLedgerInMultiCurrency() {
        try{
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Account testAccount = testData.accounts[0];
                BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
                bsm.selectedTab = 'outstanding';
                bsm.outstandingCCUser = true;

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
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[3].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                );
                newLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newLedger;

                System.assertEquals(testData.ledgers[0].Id, bsm.outstandingBill.Ledger__c);

                bsm.outstandingBill.Ledger__c = newLedger.Id;
                bsm.changeOutstandingLedger();

                System.assertEquals(newLedger.Id, bsm.outstandingStatementManager.ledgerId);
                System.assertEquals(newLedger.get('CurrencyIsoCode'), bsm.outstandingStatementManager.currencyIsoCode);
                System.assertEquals(testData.billingFormats[3].Id,(Id) bsm.outstandingBill.get(GlobalVariables.PACKAGE_QUALIFIER+'Outstanding_Statement_Format__c'));
                
            }
        }catch(Exception e){

        }
    }
    @IsTest
    public static void testChangeActivityLedgerInMultiCurrency() {
        try{
            TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }
                Account testAccount = testData.accounts[0];
                BillingStatementManager bsm = new BillingStatementManager(new ApexPages.StandardController(testAccount));
                bsm.selectedTab = 'outstanding';
                bsm.outstandingCCUser = true;

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
                    Billing_Outstanding_Statement_Format__c = testData.billingFormats[3].Id,
                    Billing_Activity_Statement_Format__c = testData.billingFormats[2].Id
                );
                newLedger.put('CurrencyIsoCode', newCurrencyIsoCode);
                insert newLedger;

                System.assertEquals(testData.ledgers[0].Id, bsm.activityBill.Ledger__c);

                bsm.activityBill.Ledger__c = newLedger.Id;
                bsm.changeActivityLedger();

                System.assertEquals(newLedger.Id, bsm.activityStatementManager.ledgerId);
                System.assertEquals(newLedger.get('CurrencyIsoCode'), bsm.activityStatementManager.currencyIsoCode);
                System.assertEquals(testData.billingFormats[2].Id, (Id)bsm.activityBill.get(GlobalVariables.PACKAGE_QUALIFIER+'Activity_Statement_Format__c'));
                
            }
        }catch(Exception e){

        }
    }
}