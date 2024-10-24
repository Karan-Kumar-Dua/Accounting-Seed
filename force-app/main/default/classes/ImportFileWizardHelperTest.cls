@IsTest
private class ImportFileWizardHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testParseFileSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String ofxTransactions = getOfxTransactions(10);
            String fileContent = getFileContent(ofxTransactions, false, UserInfo.getDefaultCurrency());
            Id contentDocumentId = createTestFile(fileContent);
            System.assertNotEquals(NULL, contentDocumentId);

            ImportFileWizardHelper.ImportFileDTO dto = ImportFileWizardHelper.parseFile(contentDocumentId);
            System.assertEquals(ImportFileWizardHelper.FILE_VERIFICATION_SUCCESS_MESSAGE, dto.message);
            List<BDCTransaction> transactionModels =
                (List<BDCTransaction>) JSON.deserialize(dto.serializedTransactionModels, List<BDCTransaction>.class);
            System.assertEquals(10, transactionModels.size());
        }
    }

    @IsTest
    private static void testParseFileNoTransactionData() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String ofxTransactions = getOfxTransactions(0);
            String fileContent = getFileContent(ofxTransactions, false, UserInfo.getDefaultCurrency());
            Id contentDocumentId = createTestFile(fileContent);
            System.assertNotEquals(NULL, contentDocumentId);

            ImportFileWizardHelper.ImportFileDTO dto = ImportFileWizardHelper.parseFile(contentDocumentId);
            System.assertEquals(ImportFileWizardHelper.FILE_VERIFICATION_NO_TRANSACTION_DATA_ERROR_MESSAGE, dto.message);
        }
    }

    @IsTest
    private static void testParseFileTransactionDataOverLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String ofxTransactions = getOfxTransactions(550);
            String fileContent = getFileContent(ofxTransactions, false, UserInfo.getDefaultCurrency());
            Id contentDocumentId = createTestFile(fileContent);
            System.assertNotEquals(NULL, contentDocumentId);

            ImportFileWizardHelper.ImportFileDTO dto = ImportFileWizardHelper.parseFile(contentDocumentId);
            System.assertEquals(ImportFileWizardHelper.MAX_TRANS_COUNT_ERROR_MESSAGE, dto.message);
        }
    }

    @IsTest
    private static void testParseFileNotValidFile() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Id contentDocumentId = createTestFile('Not valid OFX file content');
            System.assertNotEquals(NULL, contentDocumentId);

            ImportFileWizardHelper.ImportFileDTO dto = ImportFileWizardHelper.parseFile(contentDocumentId);
            System.assertEquals(OFXFileParser.FILE_FORMAT_ERROR, dto.message);
        }
    }

    @IsTest
    private static void testImportBankTransactionSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String ofxTransactions = getOfxTransactions(10);
            String fileContent = getFileContent(ofxTransactions, false, UserInfo.getDefaultCurrency());
            Id contentDocumentId = createTestFile(fileContent);
            System.assertNotEquals(NULL, contentDocumentId);

            ImportFileWizardHelper.ImportFileDTO dto = ImportFileWizardHelper.parseFile(contentDocumentId);
            System.assertEquals(ImportFileWizardHelper.FILE_VERIFICATION_SUCCESS_MESSAGE, dto.message);
            List<BDCTransaction> transactionModels =
                (List<BDCTransaction>) JSON.deserialize(dto.serializedTransactionModels, List<BDCTransaction>.class);
            System.assertEquals(10, transactionModels.size());

            ImportFileWizardHelper.importBankTransactions(JSON.serialize(dto), testData.glAccounts.get(0).Id, testData.ledgers.get(0).Id);

            System.assertEquals(10, [SELECT count() FROM Bank_Transaction__c]);
        }
    }

    @IsTest
    private static void testImportBankTransactionCreditCardAccountSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            String ofxTransactions = getOfxTransactions(10);
            String fileContent = getFileContent(ofxTransactions, true, UserInfo.getDefaultCurrency());
            Id contentDocumentId = createTestFile(fileContent);
            System.assertNotEquals(NULL, contentDocumentId);

            ImportFileWizardHelper.ImportFileDTO dto = ImportFileWizardHelper.parseFile(contentDocumentId);
            System.assertEquals(ImportFileWizardHelper.FILE_VERIFICATION_SUCCESS_MESSAGE, dto.message);
            List<BDCTransaction> transactionModels =
                (List<BDCTransaction>) JSON.deserialize(dto.serializedTransactionModels, List<BDCTransaction>.class);
            System.assertEquals(10, transactionModels.size());

            ImportFileWizardHelper.importBankTransactions(JSON.serialize(dto), testData.glAccounts.get(0).Id, testData.ledgers.get(0).Id);

            System.assertEquals(10, [SELECT count() FROM Bank_Transaction__c]);

            GL_Account_Mapping__c glam = [SELECT Id, Financial_Institution__c, Financial_Institution_Id__c FROM GL_Account_Mapping__c LIMIT 1];
            System.assertEquals('C1', glam.Financial_Institution__c);
            System.assertEquals('1001', glam.Financial_Institution_Id__c);
        }
    }

    @IsTest
    private static void testImportBankTransactionSuccess_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .setCashInDefaultSourceRecordType('Cash Receipt')
                .setCashOutDefaultSourceRecordType('Cash Disbursement');

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Test.startTest();
                String ofxTransactions = getOfxTransactions(1);
                String fileContent = getFileContent(ofxTransactions, false, theNewCurrencyIsoCode);
                Id contentDocumentId = createTestFile(fileContent);
                System.assertNotEquals(NULL, contentDocumentId);

                ImportFileWizardHelper.ImportFileDTO dto = ImportFileWizardHelper.parseFile(contentDocumentId);
                System.assertEquals(ImportFileWizardHelper.FILE_VERIFICATION_SUCCESS_MESSAGE, dto.message);
                List<BDCTransaction> transactionModels =
                    (List<BDCTransaction>) JSON.deserialize(dto.serializedTransactionModels, List<BDCTransaction>.class);
                System.assertEquals(1, transactionModels.size());

                ImportFileWizardHelper.importBankTransactions(JSON.serialize(dto), testData.glAccounts.get(0).Id, testData.ledgers.get(0).Id);

                List<GL_Account_Mapping__c> glams = Database.query('SELECT Id, CurrencyIsoCode FROM GL_Account_Mapping__c');
                System.assertNotEquals(true, glams.isEmpty());
                System.assertEquals(theNewCurrencyIsoCode, (String) glams[0].get('CurrencyIsoCode'));

                List<Bank_Transaction__c> bts = Database.query('SELECT Id, CurrencyIsoCode FROM Bank_Transaction__c');
                System.assertEquals(1, bts.size());
                System.assertEquals(theNewCurrencyIsoCode, (String) bts[0].get('CurrencyIsoCode'));
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    private static void testGetGLAMDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            GL_Account_Mapping__c glam = ImportFileWizardHelper.getGLAMDefaults();
            Test.stopTest();

            Id expected = LedgerHandler.getLedgerIdWithSharing();
            System.assertEquals(expected, glam.Ledger__c);
        }
    }

    @IsTest
    private static void testGetGLAMDefaultsMultiLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Ledger__c defaultLedger = new Ledger__c(
                Name = 'Default',
                Type__c = 'Transactional',
                Default_Bank_Account__c = testData.glAccounts[0].Id,
                Default_Billing_Format__c = testData.billingFormats[0].Id,
                Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id,
                Default_Purchase_Order_Format__c = testData.billingFormats[4].Id,
                Default_Packing_Slip_Format__c = testData.billingFormats[5].Id                
            );
            insert defaultLedger;

            LedgerService.setTestOrgDefaultLedger(defaultLedger.Id);

            Test.startTest();
            GL_Account_Mapping__c glam = ImportFileWizardHelper.getGLAMDefaults();
            Test.stopTest();

            System.assertEquals(defaultLedger.Id, glam.Ledger__c);
        }
    }

    private static Id createTestFile(String fileContent) {
        ContentVersion contV = new ContentVersion(
            Title = 'Test OFX File',
            PathOnClient = 'testOfx.ofx',
            VersionData = Blob.valueOf(fileContent),
            IsMajorVersion = true
        );
        insert contV;

        contV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contV.Id];
        return contV.ContentDocumentId;
    }

    private static String getFileContent(String ofxTransactions, Boolean isCreditCard, String currencyIsoCode) {
        String acctFrom = '';
        if (isCreditCard) {
            acctFrom =
                '<CCACCTFROM>\n' +
                    '<ACCTID>1234\n' +
                '</CCACCTFROM>';
        }
        else {
            acctFrom =
                '<BANKACCTFROM>\n' +
                    '<BANKID>073456789\n' +
                    '<ACCTID>XXXXXXXXXXXX7613\n' +
                    '<ACCTTYPE>CREDITLINE\n' +
                '</BANKACCTFROM>';
        }
        String result =
            'OFXHEADER:100\n' +
            'DATA:OFXSGML\n' +
            'VERSION:102\n' +
            'SECURITY:NONE\n' +
            'ENCODING:USASCII\n' +
            'CHARSET:1252\n' +
            'COMPRESSION:NONE\n' +
            'OLDFILEUID:NONE\n' +
            'NEWFILEUID:NONE\n' +
            '<OFX>\n' +
                '<SIGNONMSGSRSV1>\n' +
                '<SONRS>\n' +
                '<STATUS>\n' +
                '<CODE>0\n' +
                '<SEVERITY>INFO\n' +
                '</STATUS>\n' +
                '<DTSERVER>20200723022432\n' +
                '<LANGUAGE>ENG\n' +
                '<FI>\n' +
                    '<ORG>C1</ORG>\n' +
                    '<FID>1001</FID>\n' +
                '</FI>\n' +
                '</SONRS>\n' +
                '</SIGNONMSGSRSV1>\n' +
                '<BANKMSGSRSV1>\n' +
                '<STMTTRNRS>\n' +
                '<TRNUID>0\n' +
                '<STATUS>\n' +
                '<CODE>0\n' +
                '<SEVERITY>INFO\n' +
                '</STATUS>\n' +
                '<STMTRS>\n' +
                '<CURDEF>' + currencyIsoCode + '\n' +
                acctFrom + '\n' +
                '<BANKTRANLIST>\n' +
                '<DTSTART>20200101000000\n' +
                '<DTEND>20200719235959\n' +
                ofxTransactions +
                '</BANKTRANLIST>\n' +
                '<LEDGERBAL>\n' +
                '<BALAMT>-868.87\n' +
                '<DTASOF>20200723022432\n' +
                '</LEDGERBAL>\n' +
                '</STMTRS>\n' +
                '</STMTTRNRS>\n' +
                '</BANKMSGSRSV1>\n' +
                '</OFX>';
        return result;
    }

    private static String getOfxTransactions(Integer nmbOfTransactions) {
        String result = '';
        for (Integer i = 0; i < nmbOfTransactions; i++) {
            Date baseDate = Date.today();
            result += getOfxTransaction(10 + i, '123456' + i, 'DEBIT', 'Test Transaction Name #' + i, baseDate.addDays(i));
        }
        return result;
    }

    private static String getOfxTransaction(Decimal amount, String transactionId, String type, String name, Date trDate) {
        return
            '<STMTTRN>\n' +
                '<TRNTYPE>' + type + '\n' +
                '<DTPOSTED>' + formatDateForOfx(trDate) + '\n' +
                '<TRNAMT>' + String.valueOf(amount) + '\n' +
                '<FITID>' + transactionId + '\n' +
                '<NAME>' + name + '\n' +
            '</STMTTRN>\n';
    }

    private static String formatDateForOfx(Date trDate) {
        return trDate.year()
            + FinancialSuiteUtils.leftPad(String.valueOf(trDate.month()), ((trDate.month() > 9) ? 0 : 1))
            + FinancialSuiteUtils.leftPad(String.valueOf(trDate.day()), ((trDate.day() > 9) ? 0 : 1));
    }

}