@IsTest
public class BillingPDFManagerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testSaveReallyLongAttachmentName() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
                // Account name is 254 characters
                Account longAcctName = new Account(Name = 'Character a 100% free online charactercharacterch count calculator thats simple to use. Sometimes users prefer simplicity over all of the detailed writing information Word Counter provides, and this is exactly what this tool offers. It displays character');
                Billing__c bill = testData.billings[0];
                Account customer = [SELECT Name, (SELECT Id FROM Billings__r WHERE Id = :bill.Id) FROM Account LIMIT 1];
                customer.Name = longAcctName.Name;
                update customer;

                BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(bill));
                bpm.saveAttach();
            Test.stopTest();
            
            System.assertEquals(
                    1,
                    [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :bill.Id]
                );
            
            //overall length should be the max of 255, the customer name gets truncated to fit
            System.assertEquals(255, [SELECT Id, Title FROM ContentVersion].Title.length());
        }
    }

    @IsTest
    public static void testSaveAttachmentSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testData.billings[0]));
            bpm.saveAttach();
            System.assertEquals(
                1,
                [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :testData.billings[0].Id]
            );
            System.assertEquals(
                true,
                bpm.getSortField().contains([
                    SELECT Id, Sort_Field__c FROM Billing_Format__c WHERE Id = :bpm.billing.Billing_Format__c
                ].Sort_Field__c)
            );
        }
    }

    @IsTest
    public static void testSendEmailNoSenderError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testData.billings[0]));
            System.assertEquals(false, bpm.showSendEmail);
        }
    }
    
    @IsTest
    public static void testSendEmailNoEmailError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();
            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testData.billings[0]));
            bpm.billing.Billing_Contact__c = testData.contacts[0].Id;
            bpm.setContact();

            System.assertEquals(AbstractStatementManager.NO_EMAIL_ERROR, ApexPages.getMessages()[0].getSummary());
        }
    }

    @IsTest
    public static void testSendEmailBillingContactSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.contacts[0].Email = 'test11234234@gmail.com';
            update testData.contacts[0];

            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testData.billings[0]));
            bpm.sendCCUser = false;
            bpm.billing.Billing_Contact__c = testData.contacts[0].Id;
            bpm.setContact();
            System.assertEquals(true, bpm.showSendEmail);
            bpm.saveAndEmail();

            System.assertEquals(true, ApexPages.getMessages()[0].getSummary().contains(AbstractStatementManager.EMAIL_SENT_SUCCESS));
        }
    }

    @IsTest
    public static void testSendEmailBillingContactSuccessWithBillingStatusCheck() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testData.contacts[0].Email = 'chun.chun.mail@gmail.com';
            update testData.contacts[0];

            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testBilling));
            bpm.sendCCUser = false;
            bpm.billing.Billing_Contact__c = testData.contacts[0].Id;
            bpm.setContact();
            System.assertEquals(true, bpm.showSendEmail);
            bpm.saveAndEmail();
            //Check results
            System.assertEquals(true, ApexPages.getMessages()[0].getSummary().contains(AbstractStatementManager.EMAIL_SENT_SUCCESS));

            Billing__c billForCheck = [SELECT Id, PDF_Email_Status__c FROM Billing__c WHERE Id = :testBilling.Id LIMIT 1];
            System.assertEquals(AbstractStatementManager.PDF_EMAIL_STATUS_SENT, billForCheck.PDF_Email_Status__c);
        }
    }

    @IsTest
    public static void testSetContactRemotePositive() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            Contact testContact = testData.contacts[0];
            testContact.Email = 'fake.mail@mail.com';
            update testContact;

            AbstractStatementManager.RemoteActionResult result = BillingPDFManager.setContactRemote(
                testBilling.Id,
                testContact.Id
            );

            System.assertEquals(true, result.isValidContact);
            System.assertEquals(false, (result.template == NULL));
        }
    }

    @IsTest
    public static void testSetContactRemoteNoContactEmail() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            Contact testContact = testData.contacts[0];
            AbstractStatementManager.RemoteActionResult result = BillingPDFManager.setContactRemote(
                testBilling.Id,
                testContact.Id
            );
            System.assertEquals(false, result.isValidContact);
            System.assertEquals(AbstractStatementManager.NO_EMAIL_ERROR, result.errorMessage);
        }
    }

    @IsTest
    public static void testPageLoadWithoutCCAddresses() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testData.contacts[0].Email = 'chun.chun.mail@gmail.com';
            update testData.contacts[0];

            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testBilling));
            bpm.billing.Billing_Contact__c = testData.contacts[0].Id;
            System.assertEquals(true, String.isBlank(bpm.ccAddresses));
        }
    }

    @IsTest
    public static void testPageLoadWithCCAddresses() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testData.contacts[0].Email = 'chun.chun.mail@gmail.com';
            update testData.contacts[0];

            AccountContactRole contactRole = new AccountContactRole(
                AccountId = testData.accounts[0].Id,
                ContactId = testData.contacts[0].Id,
                Role = 'Billing Contact'
            );

            insert contactRole;

            if (GlobalVariables.isContactsToMultipleAccountsEnabled) {
                SObject contactRelation = Schema.getGlobalDescribe().get('AccountContactRelation').newSObject();
                contactRelation.put('AccountId', testData.accounts[0].Id);
                contactRelation.put('ContactId', testData.contacts[2].Id);
                contactRelation.put('Roles', 'Billing Contact');
                insert contactRelation;
            }
            
            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testBilling));
            bpm.billing.Billing_Contact__c = testData.contacts[0].Id;

            System.assertEquals(false, String.isBlank(bpm.ccAddresses));
            System.assertEquals('chun.chun.mail@gmail.com', bpm.ccAddresses);
        }
    }

    @IsTest
    public static void testSetDefaultOWEAddress() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<OrgWideEmailAddress> specificOrgWideEmailAddress = [SELECT Id, Address FROM OrgWideEmailAddress];

            if (specificOrgWideEmailAddress.isEmpty()) {
                return;
            }

            testData.billingFormats[0].Org_Wide_Email_Address__c = specificOrgWideEmailAddress[0].Address;
            update testData.billingFormats[0];

            BillingPDFManager bpm = new BillingPDFManager(new ApexPages.StandardController(testData.billings[0]));

            System.assertEquals(specificOrgWideEmailAddress[0].Id, bpm.selectedOrgWideEmailAddress);
        }
    }

}