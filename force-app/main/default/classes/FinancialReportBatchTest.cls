@IsTest
private class FinancialReportBatchTest {

    @TestSetup
    private static void createTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.archiveOldAccountingPeriods();
            testData.createAccountingPeriodSetBasedOnCurrentDate();
            testData.closePreviousAccountingPeriodsBasedOnCurrentDate();
        }
    }

    @IsTest
    private static void testBatchExecution() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportRows()
            .createReportColumns();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            // Create Financial Cubes
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = 'Period';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 200;
            fCube.Cube_Type__c = 'Period';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;

            // Setup FinancialReportOptions
            CustomFinancialReportOptions reportOptions = new CustomFinancialReportOptions(testData.reportDefs[0].Id);
            reportOptions.glAccounts = DomainUtils.getAllGlAccounts();
            reportOptions.ledgerIds = new List<Id>{testData.ledgers[0].Id};

            // Setup FinancialReportWrapper for test data
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.reportDefinition = testData.reportDefs[0];
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;

            FinancialReportBatch processor = new FinancialReportBatch(frw, reportOptions);

            Id batchProcessId = Database.executeBatch(processor);

            Test.stopTest();

            System.assertEquals(
                'Completed',
                [SELECT Id, Status, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE Id = :batchProcessId].Status
            );

            System.assertEquals(
                0,
                [SELECT Id, Status, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE Id = :batchProcessId].NumberOfErrors
            );
        }
    }

    @IsTest
    private static void testPublishedStartAndEndEvents() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createGlReportingGroups()
            .createGlReportingGroupLines()
            .createReportDefinitions()
            .createReportRows()
            .createReportColumns();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            // Create Financial Cubes
            List<Financial_Cube__c> fCubeList = new List<Financial_Cube__c>();
            Financial_Cube__c fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 100;
            fCube.Cube_Type__c = 'Period';
            fCubeList.add(fCube);

            fCube = new Financial_Cube__c();
            fCube.Ledger__c = testData.ledgers[0].Id;
            fCube.Accounting_Period__c = testData.acctPeriods[0].Id;
            fCube.GL_Account__c = testData.glAccounts[10].Id;
            fCube.Opening_Balance__c = 200;
            fCube.Cube_Type__c = 'Period';
            fCube.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            fCubeList.add(fCube);

            FinancialCubeActions.isPreventOverride = true;
            insert fCubeList;

            // Setup FinancialReportOptions
            CustomFinancialReportOptions reportOptions = new CustomFinancialReportOptions(testData.reportDefs[0].Id);
            reportOptions.glAccounts = DomainUtils.getAllGlAccounts();
            reportOptions.ledgerIds = new List<Id>{testData.ledgers[0].Id};

            // Setup FinancialReportWrapper for test data
            FinancialReportWrapper frw = new FinancialReportWrapper();
            frw.reportDefinition = testData.reportDefs[0];
            frw.colList = testData.reportCols;
            frw.rowList = testData.reportRows;

            FinancialReportBatch processor = new FinancialReportBatch(frw, reportOptions);

            Id batchProcessId = Database.executeBatch(processor);

            Test.stopTest();

            List<SObject> events = EventBusTestUtils.getPublishedEvents();
            String startEventName = EventRegistry.RegisteredEvent.FINANCIAL_REPORTER_GENERATE_START.name();
            String endEventName = EventRegistry.RegisteredEvent.FINANCIAL_REPORTER_GENERATE_END.name();
            System.assertEquals(2, events.size());
            System.assert(events[0].get('Type__c') == startEventName || events[1].get('Type__c') == startEventName);
            System.assert(events[0].get('Type__c') == endEventName || events[1].get('Type__c') == endEventName);
            System.assertEquals(events[0].get('Request_Id__c'), processor.reportStubId);
            System.assertEquals(events[1].get('Request_Id__c'), processor.reportStubId);
        }
    }

}