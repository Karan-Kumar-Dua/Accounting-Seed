@IsTest
private class BillingsPDFManagerTest {

    private static Billing__c getBillingById(Id billId) {
        return [
            SELECT  Id,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Proprietary_Billing_Number__c,
                    Billing_Contact__c,
                    Billing_Contact__r.FirstName,
                    Billing_Contact__r.LastName,
                    Billing_Contact__r.Email,
                    Billing_Format__c,
                    Billing_Format__r.Default_Email_Template__c,
                    Billing_Format__r.ReplyTo_Email__c,
                    Billing_Format__r.Visualforce_PDF_Page__c,
                    Billing_Format__r.Sort_Field__c,
                    Billing_Format__r.Org_Wide_Email_Address__c,
                    Date__c
            FROM Billing__c
            WHERE Id = :billId
            LIMIT 1
        ];
    }

    private static List<Billing__c> getBillingsByBillings(List<Billing__c> objs) {
        return [
            SELECT  Id,
                    Name,
                    Customer__c,
                    Customer__r.Name,
                    Proprietary_Billing_Number__c,
                    Billing_Contact__c,
                    Billing_Contact__r.FirstName,
                    Billing_Contact__r.LastName,
                    Billing_Contact__r.Email,
                    Billing_Format__c,
                    Billing_Format__r.Default_Email_Template__c,
                    Billing_Format__r.ReplyTo_Email__c,
                    Billing_Format__r.Visualforce_PDF_Page__c,
                    Billing_Format__r.Sort_Field__c,
                    Billing_Format__r.Org_Wide_Email_Address__c,
                    Date__c
            FROM Billing__c
            WHERE Id IN :objs
            LIMIT 10000
        ];
    }

    private static Account getAccount(Account act) {
        return [
            SELECT  Id,
                    Name,
                    Billing_Contact__c,
                    Billing_Contact__r.FirstName,
                    Billing_Contact__r.LastName,
                    Billing_Contact__r.Email,
                    Activity_Statement_Format__c,
                    Activity_Statement_Format__r.Visualforce_PDF_Page__c,
                    Outstanding_Statement_Format__c,
                    Outstanding_Statement_Format__r.Default_Email_Template__c,
                    Outstanding_Statement_Format__r.ReplyTo_Email__c,
                    Outstanding_Statement_Format__r.Visualforce_PDF_Page__c,
                    Outstanding_Statement_Format__r.Sort_Field__c,
                    Outstanding_Statement_Format__r.Org_Wide_Email_Address__c
            FROM Account
            WHERE Id = :act.Id
            LIMIT 1
        ];
    }

    private static Billing__c initializeBillingWithoutContact(TestDataSuite testData) {
        return getBillingById(testData.billings.get(0).Id);
    }

    private static Billing__c initializeBillingWithContact(TestDataSuite testData) {
        Billing__c bill = initializeBillingWithoutContact(testData);
        testData.contacts[0].Email = 'test@mail.com';
        bill.Billing_Contact__c = testData.contacts[0].Id;
        update testData.contacts[0];
        update bill;
        return getBillingById(bill.Id);
    }

    private static Account initializeAccountWithContact(TestDataSuite testData) {
        Account act = getAccount(testData.accounts.get(2));
        testData.contacts[0].Email = 'test@mail.com';
        act.Billing_Contact__c = testData.contacts[0].Id;
        act.Outstanding_Statement_Format__c = testData.billingFormats[2].id;
        act.Activity_Statement_Format__c = testData.billingFormats[3].Id;
        update testData.contacts[0];
        update act;
        act = getAccount(testData.accounts.get(2));
        return act;
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

   @IsTest
    private static void testGetStatementName() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c bill = initializeBillingWithoutContact(testData);
            AbstractStatementManager.StatementSet stSet = new AbstractStatementManager.StatementSet(
                new List<SObject>{bill}, AbstractStatementManager.StatementType.BILLING, NULL
            );

            String expectedResult = [
                SELECT Id, Customer__r.Name
                FROM Billing__c
                WHERE Id = :bill.Id
            ].Customer__r.Name +
                AbstractStatementManager.BILLING_STATEMENT_PDF_NAME_PREFIX +
                bill.Name +
                AbstractStatementManager.getLocaleDateTimeFormatted() +
                AbstractStatementManager.PDF_EXTENSION;

            String pdfName = stSet.statements[0].getStatementPDFName(AbstractStatementManager.StatementType.BILLING);
            System.assertEquals(expectedResult, pdfName);
        }

    }

    @IsTest
    private static void testGetPDF() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c bill = initializeBillingWithoutContact(testData);
            AbstractStatementManager.StatementSet stSet = new AbstractStatementManager.StatementSet(
                new List<SObject>{bill}, AbstractStatementManager.StatementType.BILLING, NULL
            );

            String pdfResult = stSet.statements[0].getPDF().toString();
            System.assertEquals('test' , pdfResult);
        }

    }

    @IsTest
    private static void testGetSortField() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c bill = initializeBillingWithoutContact(testData);
            AbstractStatementManager.StatementSet stSet = new AbstractStatementManager.StatementSet(
                new List<SObject>{bill}, AbstractStatementManager.StatementType.BILLING, NULL
            );

            String expectedResult = bill.Billing_Format__r.Sort_Field__c != NULL ? (bill.Billing_Format__r.Sort_Field__c) : '';
            System.assertEquals(expectedResult , stSet.statements[0].getSortField());
        }

    }

    @IsTest
    private static void testGetFile() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c bill = initializeBillingWithoutContact(testData);
            AbstractStatementManager.StatementSet stSet = new AbstractStatementManager.StatementSet(
                new List<SObject>{bill}, AbstractStatementManager.StatementType.BILLING, NULL
            );

            ContentVersion sfFile = stSet.statements[0].getFile(stSet.statements[0].getPDF());
            Map<Id, ContentVersion> fileMap = new Map<Id, ContentVersion>();
            fileMap.put(stSet.statements[0].source.Id, sfFile);
            stSet.saveFiles(fileMap);

            System.assertEquals(1, [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :bill.Id]);
        }

    }

    @IsTest
    private static void testGetMailSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c bill = initializeBillingWithContact(testData);
            AbstractStatementManager.StatementSet stSet = new AbstractStatementManager.StatementSet(
                new List<SObject>{bill}, AbstractStatementManager.StatementType.BILLING, NULL
            );

            Messaging.SingleEmailMessage mail = stSet.statements[0].getEmail(stSet.statements[0].getPDF());
            System.assertNotEquals(NULL, mail);
            System.assertEquals((Id) stSet.statements[0].emailTemplate, mail.getTemplateId());
            System.assertEquals(testData.contacts[0].Id, mail.getTargetObjectId());
        }

    }

    @IsTest
    private static void testOutstandingStmtMailSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Account act = initializeAccountWithContact(testData);
            AbstractStatementManager.StatementSet stSet = new AbstractStatementManager.StatementSet(
                    new List<SObject>{act}, AbstractStatementManager.StatementType.OUTSTANDING, NULL
            );

            Messaging.SingleEmailMessage mail = stSet.statements[0].getEmail(stSet.statements[0].getPDF());
            System.assertNotEquals(NULL, mail);
            System.assertEquals((Id) stSet.statements[0].emailTemplate, mail.getTemplateId());
            System.assertEquals(testData.contacts[0].Id, mail.getTargetObjectId());

        }

    }


    @IsTest
    private static void testBillingsPDFManagerGetUrlsByBillId() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> bills = getBillingsByBillings(testData.billings);
            AbstractStatementManager.StatementSet stSet = new AbstractStatementManager.StatementSet(
                bills, AbstractStatementManager.StatementType.BILLING, NULL
            );

            System.assertEquals(bills.size(), stSet.sourceToUrl.size());

            System.assertEquals(
                FinancialSuiteUtils.getFullVFPageUrl(bills[0].Billing_Format__r.Visualforce_PDF_Page__c, NULL),
                stSet.sourceToUrl.get(bills[0].Id)
            );
        }

    }

    @IsTest
    private static void testBillingsPDFManagerEmailPDFs() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> bills = new List<Billing__c> { initializeBillingWithContact(testData) };
            ApexPages.StandardSetController setCon = new ApexPages.StandardSetController(bills);
            setCon.setSelected(bills);
            BillingsPDFManager con = new BillingsPDFManager(setCon);
            con.emailPDFs();
            String prepareMessage = AbstractStatementManager.MAIL_SUCCESS_MESSAGE_FOR_BILLINGS;
            prepareMessage = prepareMessage.replace('{0}', String.valueOf(1));
            prepareMessage = prepareMessage.replace('{1}', String.valueOf(1));
            System.assertEquals(1, ApexPages.getMessages().size());
            System.assertEquals(prepareMessage, ApexPages.getMessages()[0].getSummary());
            Test.stopTest();
            Billing__c bill = [
                SELECT Id, PDF_Email_Status__c
                FROM Billing__c
                WHERE Id = :con.bills.get(0).Id
                LIMIT 1
            ];
            System.assertEquals(AbstractStatementManager.PDF_EMAIL_STATUS_SENT, bill.PDF_Email_Status__c);
        }

    }

    @IsTest
    private static void testBillingsPDFManagerNoSelected() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Billing__c> bills = new List<Billing__c>();
            ApexPages.StandardSetController setCon = new ApexPages.StandardSetController(bills);
            setCon.setSelected(bills);
            BillingsPDFManager con = new BillingsPDFManager(setCon);

            System.assertEquals(true, con.isNoSelectedBills);
            System.assertEquals(1, ApexPages.getMessages().size());
            System.assertEquals(
                AbstractStatementManager.NO_RECORDS_SELECTED_ERROR,
                ApexPages.getMessages()[0].getSummary()
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testSetDefaultOWEAddressBillings() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<OrgWideEmailAddress> specificOrgWideEmailAddress = [SELECT Id, Address FROM OrgWideEmailAddress];

            if (specificOrgWideEmailAddress.isEmpty()) {
                return;
            }

            testData.billingFormats[0].Org_Wide_Email_Address__c = specificOrgWideEmailAddress[0].Address;
            update testData.billingFormats[0];

            List<Billing__c> bills = new List<Billing__c> {initializeBillingWithContact(testData)};
            for (Billing__c bill : bills) {
                bill.Billing_Format__c = testData.billingFormats[0].Id;
            }

            update bills;

            AbstractStatementManager.StatementSet statementHandler = new AbstractStatementManager.StatementSet(
                (List<Billing__c>) bills,
                AbstractStatementManager.StatementType.BILLING,
                NULL
            );

            for (AbstractStatementManager.Statement st : statementHandler.statements) {
                System.assertEquals(specificOrgWideEmailAddress[0].Id, st.owa.Id);
            }
        }
    }

    @IsTest
    public static void testGetFullVFPageUrlInVFContext() {
        TestDataSuite.salesforceUrl = 'https://drive-platform-9749-dev-ed--AcctSeed.visualforce.com';
        String pageAPIName = 'BillingProductIrisPdfHLP'; // has namespace AcctSeed
        String pageURL = FinancialSuiteUtils.getFullVFPageUrl(pageAPIName, TestDataSuite.salesforceUrl);
        System.assertEquals(
            TestDataSuite.salesforceUrl + '/apex/BillingProductIrisPdfHLP',
            pageURL
        );
    }

    @IsTest
    public static void testGetFullVFPageUrlInSystemContext() {
        String pageAPIName = 'BillingProductIrisPdfHLP'; // has namespace AcctSeed
        String pageURL = FinancialSuiteUtils.getFullVFPageUrl(pageAPIName, TestDataSuite.salesforceUrl);
        System.assertEquals(
            TestDataSuite.salesforceUrl + '/apex/BillingProductIrisPdfHLP',
            pageURL
        );
    }

    @IsTest
    public static void testGetFullVFPageUrlInVFContextAndCustomPage() {
        String qualifier = GlobalVariables.PACKAGE_QUALIFIER.replaceAll('_', '');
        TestDataSuite.salesforceUrl = 'https://drive-platform-9749-dev-ed--' + qualifier + '.visualforce.com';
        String pageAPIName = 'NonExistedPageApiName'; // no namespace
        String pageURL = FinancialSuiteUtils.getFullVFPageUrl(pageAPIName, TestDataSuite.salesforceUrl);
        System.assertEquals(
            TestDataSuite.salesforceUrl.toLowerCase().replace(qualifier.toLowerCase(), 'c') + '/apex/NonExistedPageApiName',
            pageURL
        );
    }

}