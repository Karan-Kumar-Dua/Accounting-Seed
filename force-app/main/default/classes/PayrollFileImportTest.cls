@IsTest
private class PayrollFileImportTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testGetTransactionalLedger() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Map<String, String> ledgers = PayrollFileImport.getTransactionalLedger();

            System.assertEquals(5, ledgers.values().size());
        }
    }

    @isTest
    private static void testGetGlavsLabels() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Map<String, String> glavs = PayrollFileImport.getGlavsLabels();

            System.assertEquals(4, glavs.values().size());
        }
    }

    @isTest
    private static void testSaveRecordsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                '50,000.02',
                testData.accountingVariables1[0].Name
            );

            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');
            Id resultJEId = [SELECT Id FROM Journal_Entry__c WHERE Name = 'testJE' LIMIT 1].Id;
            System.assertEquals(true, result[0].created);
            System.assertEquals(1, [SELECT count() FROM ContentVersion WHERE Title = 'testFile']);
            System.assertEquals(1, [SELECT count() FROM Journal_Entry__c WHERE Name = 'testJE']);
            System.assertEquals(2, [SELECT count() FROM Journal_Entry_Line__c WHERE Journal_Entry__c = :resultJEId]);
        }
    }

    @isTest
    private static void testGLAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                'wrongName',
                '10/20/1991',
                '5',
                '',
                '',
                '5',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.GL_ACCOUNT_NOT_FOUND,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testGLVariableError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '5',
                '',
                '',
                '5',
                'wrongGLAV'
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.GLAV_NOT_FOUND,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testExistedJEError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                testData.journalEntries[0].Name,
                testData.glAccounts[0].Name,
                '10/20/1991',
                '5',
                '',
                '',
                '5',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                testData.journalEntries[0].Id,
                PayrollFileImport.StatusCode.RECORD_EXISTS,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testRequiredJEFieldsError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                '',
                '',
                '10/20/1991',
                '5',
                '',
                '',
                '5',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.REQUIRED_FIELD_ERROR,
                'Journal Entry,GL Account'
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testBothDebitCreditError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '5',
                '6',
                '6',
                '5',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.WRONG_DEBIT_CREDIT,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testBalanceDebitCreditError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '5',
                '',
                '',
                '4',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.BALANCE_ERROR,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testEmptyDebitCreditError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '',
                '',
                '',
                '',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.EMPTY_DEBIT_CREDIT,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testNegativeDebitCreditError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '-5',
                '',
                '',
                '-5',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.NEGATIVE_DEBIT_CREDIT,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testWrongDateFormatError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10.02.2001',
                '5',
                '',
                '',
                '5',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.WRONG_DATE_FORMAT,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testNonNumericDebitCreditError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        System.runAs(testData.users.get(1)) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '$5',
                '',
                '',
                '$5',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.NON_NUMERIC,
                ''
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());

        }
    }

    @isTest
    private static void testSaveRecordsSuccessMC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createAccountingVariables();

            System.runAs(testData.users.get(1)) {
                String fileBody = getFileBody(
                    'testJE',
                    testData.glAccounts[0].Name,
                    '10/20/1991',
                    '50,000.02',
                    '',
                    '',
                    '50,000.02',
                    testData.accountingVariables1[0].Name
                );

                List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');
                Journal_Entry__c resultJE = Database.query('SELECT Id, Ledger__c, CurrencyIsoCode FROM Journal_Entry__c WHERE Name = \'testJE\' LIMIT 1');
                String ledgerId = resultJE.Ledger__c;
                Ledger__c ledger = Database.query('SELECT Id, CurrencyIsoCode FROM Ledger__c WHERE Id = :ledgerId LIMIT 1');
                System.assertEquals(true, result[0].created);
                System.assertEquals(1, [SELECT count() FROM ContentVersion WHERE Title = 'testFile']);
                System.assertEquals(1, [SELECT count() FROM Journal_Entry__c WHERE Name = 'testJE']);
                System.assertEquals(2, [SELECT count() FROM Journal_Entry_Line__c WHERE Journal_Entry__c = :resultJE.Id]);
                System.assertEquals(ledger.get('CurrencyIsoCode'), resultJE.get('CurrencyIsoCode'));
            }
        }
        catch (Exception ex) {

        }
    }

    @isTest
    private static void testNonCRUDAndFLSGLAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        User testUser = TestDataSuite.createTestUser();
        testUser.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        update testUser;
        System.runAs(testUser) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                '50,000.02',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.CRUD_FLS_ERROR,
                'GL Account'
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assert(result[0].inspector.getCumulativeMessage().contains(expectedResult.getMessage()));

        }
    }

    @isTest
    private static void testNonCRUDAndFLSAccountingVariable() {
        TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables();

        User testUser = TestDataSuite.createTestUser();
        testUser.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        update testUser;
        System.runAs(testUser) {
            String fileBody = getFileBody(
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                '50,000.02',
                testData.accountingVariables1[0].Name
            );
            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.CRUD_FLS_ERROR,
                'GL Account Variable'
            );
            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(fileBody, 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assert(result[0].inspector.getCumulativeMessage().contains(expectedResult.getMessage()));

        }
    }

    @isTest
    private static void testSaveRecordsWithAdditionalFieldsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {

            List<PayrollFileImport.PayrollImportLineWrapper> resultList = new List<PayrollFileImport.PayrollImportLineWrapper>();
            PayrollFileImport.PayrollImportLineWrapper pfiDebit = new PayrollFileImport.PayrollImportLineWrapper (
                1,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiDebit.accountName = testData.accounts[0].Name;
            pfiDebit.projectName = testData.projects[0].Name;
            pfiDebit.projectTaskName = testData.projectTasks[0].Name;
            resultList.add(pfiDebit);

            PayrollFileImport.PayrollImportLineWrapper pfiCredit = new PayrollFileImport.PayrollImportLineWrapper (
                2,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '',
                '50,000.02',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiCredit.accountName = testData.accounts[0].Name;
            pfiCredit.projectName = testData.projects[0].Name;
            pfiCredit.projectTaskName = testData.projectTasks[0].Name;
            resultList.add(pfiCredit);

            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(JSON.serialize(resultList), 'testBody', 'testFile');
            Id resultJEId = [SELECT Id FROM Journal_Entry__c WHERE Name = 'testJE' LIMIT 1].Id;
            System.assertEquals(true, result[0].created);
            System.assertEquals(1, [SELECT count() FROM ContentVersion WHERE Title = 'testFile']);
            System.assertEquals(1, [SELECT count() FROM Journal_Entry__c WHERE Name = 'testJE']);
            System.assertEquals(2, [SELECT count() FROM Journal_Entry_Line__c WHERE Journal_Entry__c = :resultJEId]);

            List<Journal_Entry_Line__c> lines = [SELECT Id, Account__c, Project__c, Project_Task__c FROM Journal_Entry_Line__c WHERE Journal_Entry__c = :resultJEId];

            for (Journal_Entry_Line__c line : lines) {
                System.assertEquals(testData.accounts[0].Id, line.Account__c);
                System.assertEquals(testData.projects[0].Id, line.Project__c);
                System.assertEquals(testData.projectTasks[0].Id, line.Project_Task__c);
            }
        }
    }

    @isTest
    private static void testNoAccountValueError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {

            List<PayrollFileImport.PayrollImportLineWrapper> resultList = new List<PayrollFileImport.PayrollImportLineWrapper>();
            PayrollFileImport.PayrollImportLineWrapper pfiDebit = new PayrollFileImport.PayrollImportLineWrapper (
                1,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiDebit.accountName = 'test account name';
            pfiDebit.projectName = testData.projects[0].Name;
            pfiDebit.projectTaskName = testData.projectTasks[0].Name;
            resultList.add(pfiDebit);

            PayrollFileImport.PayrollImportLineWrapper pfiCredit = new PayrollFileImport.PayrollImportLineWrapper (
                2,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '',
                '50,000.02',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiCredit.accountName = testData.accounts[0].Name;
            pfiCredit.projectName = testData.projects[0].Name;
            pfiCredit.projectTaskName = testData.projectTasks[0].Name;
            resultList.add(pfiCredit);

            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.ACCOUNT_NOT_FOUND,
                ''
            );

            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(JSON.serialize(resultList), 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());
        }
    }

    @isTest
    private static void testNoProjectValueError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {

            List<PayrollFileImport.PayrollImportLineWrapper> resultList = new List<PayrollFileImport.PayrollImportLineWrapper>();
            PayrollFileImport.PayrollImportLineWrapper pfiDebit = new PayrollFileImport.PayrollImportLineWrapper (
                1,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiDebit.accountName = testData.accounts[0].Name;
            pfiDebit.projectName =  'test project name';
            pfiDebit.projectTaskName = testData.projectTasks[0].Name;
            resultList.add(pfiDebit);

            PayrollFileImport.PayrollImportLineWrapper pfiCredit = new PayrollFileImport.PayrollImportLineWrapper (
                2,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '',
                '50,000.02',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiCredit.accountName = testData.accounts[0].Name;
            pfiCredit.projectName = testData.projects[0].Name;
            pfiCredit.projectTaskName = testData.projectTasks[0].Name;
            resultList.add(pfiCredit);

            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.PROJECT_NOT_FOUND,
                ''
            );

            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(JSON.serialize(resultList), 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());
        }
    }

    @isTest
    private static void testNoProjectTaskValueError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {

            List<PayrollFileImport.PayrollImportLineWrapper> resultList = new List<PayrollFileImport.PayrollImportLineWrapper>();
            PayrollFileImport.PayrollImportLineWrapper pfiDebit = new PayrollFileImport.PayrollImportLineWrapper (
                1,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiDebit.accountName = testData.accounts[0].Name;
            pfiDebit.projectName = testData.projects[0].Name;
            pfiDebit.projectTaskName = 'test project task name';
            resultList.add(pfiDebit);

            PayrollFileImport.PayrollImportLineWrapper pfiCredit = new PayrollFileImport.PayrollImportLineWrapper (
                2,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '',
                '50,000.02',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiCredit.accountName = testData.accounts[0].Name;
            pfiCredit.projectName = testData.projects[0].Name;
            pfiCredit.projectTaskName = testData.projectTasks[0].Name;
            resultList.add(pfiCredit);

            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.PROJECT_TASK_NOT_FOUND,
                ''
            );

            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(JSON.serialize(resultList), 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());
        }
    }

    @isTest
    private static void testProjectTaskRequiredError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects()
            .createProjectTasks();

        System.runAs(testData.users.get(1)) {

            List<PayrollFileImport.PayrollImportLineWrapper> resultList = new List<PayrollFileImport.PayrollImportLineWrapper>();
            PayrollFileImport.PayrollImportLineWrapper pfiDebit = new PayrollFileImport.PayrollImportLineWrapper (
                1,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '50,000.02',
                '',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiDebit.accountName = testData.accounts[0].Name;
            pfiDebit.projectName = testData.projects[0].Name;
            pfiDebit.projectTaskName = '';
            resultList.add(pfiDebit);

            PayrollFileImport.PayrollImportLineWrapper pfiCredit = new PayrollFileImport.PayrollImportLineWrapper (
                2,
                'testJE',
                testData.glAccounts[0].Name,
                '10/20/1991',
                '',
                '50,000.02',
                '',
                testData.accountingVariables1[0].Name,
                '', '', ''
            );
            pfiCredit.accountName = testData.accounts[0].Name;
            pfiCredit.projectName = testData.projects[0].Name;
            pfiCredit.projectTaskName = '';
            resultList.add(pfiCredit);

            PayrollFileImport.PayrollFileImportProcessResult expectedResult = new PayrollFileImport.PayrollFileImportProcessResult(
                false,
                '',
                PayrollFileImport.StatusCode.PROJECT_TASK_REQUIRED,
                ''
            );

            List<PayrollFileImport.PayrollImportLineWrapper> result = PayrollFileImport.saveRecords(JSON.serialize(resultList), 'testBody', 'testFile');

            System.assertEquals(false, result[0].created);
            System.assertEquals(expectedResult.getMessage(), result[0].inspector.getCumulativeMessage());
        }
    }

    private static String getFileBody(String recordName,
                                        String glAccountName,
                                        String stringTransDate,
                                        String debitAmount1,
                                        String creditAmount1,
                                        String debitAmount2,
                                        String creditAmount2,
                                        String glVariable1Name
    ) {
        List<PayrollFileImport.PayrollImportLineWrapper> resultList = new List<PayrollFileImport.PayrollImportLineWrapper>();
        PayrollFileImport.PayrollImportLineWrapper pfiDebit = new PayrollFileImport.PayrollImportLineWrapper (
            1,
            recordName,
            glAccountName,
            stringTransDate,
            debitAmount1,
            creditAmount1,
            '',
            glVariable1Name,
            '', '', ''
        );
        resultList.add(pfiDebit);
        PayrollFileImport.PayrollImportLineWrapper pfiCredit = new PayrollFileImport.PayrollImportLineWrapper (
            2,
            recordName,
            glAccountName,
            stringTransDate,
            debitAmount2,
            creditAmount2,
            '',
            glVariable1Name,
            '', '', ''
        );
        resultList.add(pfiCredit);
        return JSON.serialize(resultList);
    }

}