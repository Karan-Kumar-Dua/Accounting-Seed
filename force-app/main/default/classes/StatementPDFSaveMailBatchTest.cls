@IsTest
public class StatementPDFSaveMailBatchTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static Billing__c getBillingById(Id billId) {
        return [
            SELECT  Id,
                    Name,
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

    private static Billing__c initializeBillingWithoutContact() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        return getBillingById(testData.billings[0].Id);
    }

    private static Billing__c initializeBillingWithContact() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Billing__c bill = initializeBillingWithoutContact();
        testData.contacts[0].Email = 'test@mail.com';
        bill.Billing_Contact__c = testData.contacts[0].Id;
        update testData.contacts[0];
        update bill;
        return getBillingById(bill.Id);
    }

    private static List<Billing__c> initializeBillingsWithContact(Integer countBills) {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.contacts[0].Email = 'test@mail.com';
        update testData.contacts[0];
        List<Billing__c> bills = new List<Billing__c>();
        for (Integer i = 0; i < countBills; i++) {
            bills.add(
                new Billing__c(
                    Billing_Cycle_Start_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Billing_Cycle_End_Date__c = testData.acctPeriods[0].End_Date__c + 3 + i,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Customer__c = testData.accounts[0].Id,
                    Status__c = 'In Process',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Billing_Contact__c = testData.contacts[0].Id,
                    Billing_Format__c = testData.billingFormats[0].Id,
                    Due_Date2__c = System.today() + 30 + i
                )
            );
        }
        insert bills;
        return bills;
    }

    @IsTest
    private static void testBillingsPDFSaveMailBatchSavePDFs() {
        List<Billing__c> bills = new List<Billing__c>{initializeBillingWithoutContact()};
        List<Id> selectedIds = new List<Id>();
        for (Billing__c bill : bills) {
            selectedIds.add(bill.Id);
        }

        Test.startTest();
        StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
            selectedIds,
            false,
            URL.getOrgDomainUrl().toExternalForm(),
            AbstractStatementManager.StatementBase.BILLING
        );

        Database.executeBatch(pdfBatch);
        Test.stopTest();

        List<ContentDocumentLink> files = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :selectedIds];
        System.assertEquals(1, files.size());
    }

    @IsTest
    private static void testBillingsPDFSaveMailBatchEmailPDFs() {
        List<Billing__c> bills = new List<Billing__c>{initializeBillingWithContact()};
        List<Id> selectedIds = new List<Id>();
        for (Billing__c bill : bills) {
            selectedIds.add(bill.Id);
        }

        Test.startTest();
        StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
            selectedIds,
            true,
            URL.getOrgDomainUrl().toExternalForm(),
            AbstractStatementManager.StatementBase.BILLING
        );

        Database.executeBatch(pdfBatch);
        Test.stopTest();

        List<ContentDocumentLink> files = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :selectedIds];
        System.assertEquals(1, files.size());
    }

    @IsTest
    private static void testBillingsPDFSaveMailBatchEmailPDFsWithErrors() {
        List<Billing__c> bills = new List<Billing__c>{initializeBillingWithoutContact()};
        List<Id> selectedIds = new List<Id>();
        for (Billing__c bill : bills) {
            selectedIds.add(bill.Id);
        }

        Test.startTest();
        StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
            selectedIds,
            true,
            URL.getOrgDomainUrl().toExternalForm(),
            AbstractStatementManager.StatementBase.BILLING
        );

        Database.executeBatch(pdfBatch);
        Test.stopTest();

        List<ContentDocumentLink> files = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :selectedIds];
        System.assertEquals(0, files.size());
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId IN :selectedIds];
        System.assertEquals(bills.size(), tasks.size());
    }

    @IsTest
    private static void testAccountPDFSaveMailBatchEmailPDFsWithErrors() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Billing_Format__c testCustomerStatementFormat = new Billing_Format__c(
            Name = 'Customer Statement',
            Visualforce_PDF_Page__c = 'BillingOutstandingStatementPDF',
            Default_Email_Template__c = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1].DeveloperName,
            ReplyTo_Email__c = 'test.mail.address@gmail.com',
            Type__c = 'Customer Statement'
        );
        insert testCustomerStatementFormat;

        testData.ledgers[0].Billing_Outstanding_Statement_Format__c = testCustomerStatementFormat.Id;
        testData.ledgers[0].Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id;
        update testData.ledgers[0];

        Map<Id, Id> accountIdToLedgerId = new Map<Id, Id>();
        Map<Id, String> accountIdToCurrencyIsoCode = new Map<Id, String>();

        List<Id> selectedIds = new List<Id>();
        for (Account account : testData.accounts) {
            accountIdToLedgerId.put(account.Id, testData.ledgers[0].Id);
            accountIdToCurrencyIsoCode.put(account.Id, 'usd');
            account.Outstanding_Statement_Format__c = testCustomerStatementFormat.Id;
            selectedIds.add(account.Id);
        }

        update testData.accounts;

        Test.startTest();
        StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
            selectedIds,
            accountIdToLedgerId,
            accountIdToCurrencyIsoCode,
            true,
            URL.getOrgDomainUrl().toExternalForm(),
            AbstractStatementManager.StatementBase.CUSTOMER,
            AbstractStatementManager.statementType.OUTSTANDING
        );

        Database.executeBatch(pdfBatch);
        Test.stopTest();

        List<ContentDocumentLink> files = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :selectedIds];
        System.assertEquals(0, files.size());
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId IN :selectedIds];
        System.assertEquals(testData.accounts.size(), tasks.size());
    }

    @IsTest
    private static void testBillingsPDFSaveMailBatchLimits() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {

            List<Billing__c> bills = initializeBillingsWithContact(AbstractStatementManager.BATCH_CHUNK_SIZE);
            List<Id> selectedIds = new List<Id>();
            for (Billing__c bill : bills) {
                selectedIds.add(bill.Id);
            }

            Test.startTest();
            System.assert(AbstractStatementManager.BATCH_CHUNK_SIZE > 0);
            StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
                selectedIds,
                true,
                URL.getOrgDomainUrl().toExternalForm(),
                AbstractStatementManager.StatementBase.BILLING
            );
            Database.executeBatch(pdfBatch, AbstractStatementManager.BATCH_CHUNK_SIZE);
            Test.stopTest();

            List<ContentDocumentLink> files = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN :selectedIds];
            System.assertEquals(AbstractStatementManager.BATCH_CHUNK_SIZE, files.size());
        }
    }

    @IsTest
    private static void testBillingsPDFSaveMailBatchEmailSubject() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Billing__c> bills = new List<Billing__c>{initializeBillingWithContact()};
            List<Id> selectedIds = new List<Id>();
            for (Billing__c bill : bills) {
                selectedIds.add(bill.Id);
            }

            Test.startTest();
            StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
                selectedIds,
                true,
                URL.getOrgDomainUrl().toExternalForm(),
                AbstractStatementManager.StatementBase.BILLING
            );

            System.assertEquals(String.format(AbstractStatementManager.REPORT_SUBJECT, new List<String> {'billings'}), pdfBatch.getSubject());
        }
    }

    @IsTest
    private static void testCustomerPDFSaveMailBatchEmailSubject() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            List<Id> selectedIds = new List<Id>();
            for (Account account : testData.accounts) {
                selectedIds.add(account.Id);
            }

            Test.startTest();
            StatementPDFSaveMailBatch pdfBatch = new StatementPDFSaveMailBatch(
                selectedIds,
                true,
                URL.getOrgDomainUrl().toExternalForm(),
                AbstractStatementManager.StatementBase.CUSTOMER
            );

            System.assertEquals(String.format(AbstractStatementManager.REPORT_SUBJECT, new List<String> {'statements'}), pdfBatch.getSubject());
        }
    }

}