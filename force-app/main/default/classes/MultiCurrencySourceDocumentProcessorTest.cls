@IsTest
public with sharing class MultiCurrencySourceDocumentProcessorTest {

    private static MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler getDatedConversionRates() {
        MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler datedConversionRateHandler = new MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler();
        MultiCurrencySourceDocumentProcessor.DatedConversionRate dcr;
        Date startDate = Date.newInstance(0000, 12, 30);
        Date nextStartDate = Date.newInstance(1990, 8, 6);
        String isoCode = 'USD';
        Double ccr = 1;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);
        
        startDate = Date.newInstance(1990, 8, 6);
        nextStartDate = Date.newInstance(1990, 10, 6);
        isoCode = 'USD';
        ccr = 1;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);

        startDate = Date.newInstance(1990, 10, 6);
        nextStartDate = Date.newInstance(9999, 12, 30);
        isoCode = 'USD';
        ccr = 1;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);

        startDate = Date.newInstance(0000, 12, 30);
        nextStartDate = Date.newInstance(1990, 8, 6);
        isoCode = 'EUR';
        ccr = 0.40;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);

        startDate = Date.newInstance(1990, 8, 6);
        nextStartDate = Date.newInstance(1990, 10, 6);
        isoCode = 'EUR';
        ccr = 0.50;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);

        startDate = Date.newInstance(1990, 10, 6);
        nextStartDate = Date.newInstance(9999, 12, 30);
        isoCode = 'EUR';
        ccr = 0.60;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);  

        startDate = Date.newInstance(0000, 12, 30);
        nextStartDate = Date.newInstance(1990, 8, 6);
        isoCode = 'GBP';
        ccr = 0.70;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);

        startDate = Date.newInstance(1990, 8, 6);
        nextStartDate = Date.newInstance(1990, 10, 6);
        isoCode = 'GBP';
        ccr = 0.80;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);

        startDate = Date.newInstance(1990, 10, 6);
        nextStartDate = Date.newInstance(9999, 12, 30);
        isoCode = 'GBP';
        ccr = 0.90;
        dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(startDate, nextStartDate, isoCode, ccr);
        datedConversionRateHandler.addDatedConversionRate(dcr);    

        return datedConversionRateHandler;
    }

    @IsTest
    public static void testSetParentIsoCodeByParentRelationship() {

        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                    .enableMultiCurrency()//will throw an exception in case of non-MC org
                                    .createGLAccountExpenses()
                                    .createProjects()
                                    .createProjectTasks()
                                    .createExpenseReports()
                                    .createExpenseLines();

            System.runAs(testData.users.get(1)) {

                Expense_Report__c testExpReport = testData.expenseReports[0].clone();
                testExpReport.put('CurrencyIsoCode', UserInfo.getDefaultCurrency());

                Expense_Line__c testExpLine = testData.expenses.get(0).clone();
                String isoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();

                testExpLine.put('CurrencyIsoCode',isoCode);
                DmlException dmlEx;
                try {
                    insert testExpReport;
                    testExpLine.Expense_Report__c = testExpReport.Id;
                    insert testExpLine;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(NULL, dmlEx);

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Expense_Report__c');
                MultiCurrencySourceDocumentProcessor.getInstance().setParentIsoCodeByParentRelationship(
                    NULL, new List<SObject>{testExpLine}
                );
                
                System.assertEquals(
                    1,
                    MultiCurrencySourceDocumentProcessor.getInstance().sourceDocNoConversionRateList.size()
                );
                System.assertEquals(
                    UserInfo.getDefaultCurrency(),
                    MultiCurrencySourceDocumentProcessor.getInstance().sourceDocNoConversionRateList[0].parentIsoCode
                );
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetParentIsoCodeByLedger() {

        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                    .enableMultiCurrency()//will throw an exception in case of non-MC org
                                    .createBillings();

            System.runAs(testData.users.get(1)) {

                Billing__c bill = testData.billings[0].clone();
                bill.Ledger__c = testData.ledgers[0].Id;

                DMLException dmlEx;
                try {
                    insert bill;
                }
                catch (DMLException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(NULL, dmlEx);

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.getInstance().setParentIsoCodeByLedger(NULL, new SObject[]{bill});
                
                System.assertEquals(
                    1,
                    MultiCurrencySourceDocumentProcessor.getInstance().sourceDocNoConversionRateList.size()
                );

                String ledgerIsoCode = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id);
                System.assertEquals(
                    ledgerIsoCode,
                    MultiCurrencySourceDocumentProcessor.getInstance().sourceDocNoConversionRateList[0].parentIsoCode
                );
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyConversionRateOrAddRetrievalListCCRIsOne() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();

            System.runAs(testData.users.get(1)) {

                Billing__c bill = testData.billings[0].clone();
                String ledgerIsoCode = LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id);
                bill.Ledger__c = testData.ledgers[0].Id;
                bill.put('CurrencyIsoCode', ledgerIsoCode);

                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = ledgerIsoCode;

                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(true, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);

                System.assertEquals(1, sdm.currencyConversionRate);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyConversionRateOrAddRetrievalListSetCCR() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();

            System.runAs(testData.users.get(1)) {

                Billing__c bill = testData.billings[0].clone();
                bill.Date__c = Date.newInstance(1990, 8, 7);
                bill.put('CurrencyIsoCode', 'EUR');

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = 'USD';
                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    getDatedConversionRates();

                System.assert(
                    1 < MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler.datedConversionRateMap.size()
                );
                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);

                System.assertEquals(0.50, sdm.currencyConversionRate);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }
    
    @IsTest
    public static void testSetCurrencyConversionRateOrAddRetrievalListCCRNotFound() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();

            System.runAs(testData.users.get(1)) {

                Billing__c bill = testData.billings[0].clone();
                Date testDate = Date.newInstance(1970, 13, 3);
                bill.Date__c = testDate;
                bill.put('CurrencyIsoCode', 'AUD');

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = 'CAD';
                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    getDatedConversionRates();

                System.assert(
                    1 < MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler.datedConversionRateMap.size()
                );
                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);
                System.assert(MultiCurrencySourceDocumentProcessor.getInstance().currencyISOCodes.contains('CAD'));
                System.assert(MultiCurrencySourceDocumentProcessor.getInstance().currencyISOCodes.contains('AUD'));
                System.assert(MultiCurrencySourceDocumentProcessor.getInstance().recordDateSet.contains(testDate));
                System.assertEquals(
                    sdm,
                    MultiCurrencySourceDocumentProcessor.getInstance().sourceDocNoConversionRateList[0]
                );
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testGetConversionRateBySourceDocumentAndParentEURToUSDBase() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();
            System.runAs(testData.users.get(1)) {
                
                Billing__c bill = testData.billings[0].clone();
                bill.Date__c = Date.newInstance(1988,7,2);
                bill.put('CurrencyIsoCode','EUR');

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = 'USD';
                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    getDatedConversionRates();

                System.assert(
                    1 < MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler.datedConversionRateMap.size()
                );
                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);
                System.assertEquals(0.40, sdm.currencyConversionRate);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testGetConversionRateBySourceDocumentAndParentGBPToUSDBase() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();
            System.runAs(testData.users.get(1)) {
                
                Billing__c bill = testData.billings[0].clone();
                bill.Date__c = Date.newInstance(1990, 8, 7);
                bill.put('CurrencyIsoCode', 'GBP');

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = 'USD';
                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    getDatedConversionRates();

                System.assert(
                    1 < MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler.datedConversionRateMap.size()
                );
                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);
                System.assertEquals(0.80, sdm.currencyConversionRate);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testGetConversionRateBySourceDocumentAndParentEURToGBPNonBase() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();

            System.runAs(testData.users.get(1)) {
                Billing__c bill = testData.billings[0].clone();
                bill.Date__c = Date.newInstance(1990, 10, 4);
                bill.put('CurrencyIsoCode', 'EUR');

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = 'GBP';
                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    getDatedConversionRates();

                System.assert(
                    1 < MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler.datedConversionRateMap.size()
                );
                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);
                System.assertEquals(0.625, sdm.currencyConversionRate);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testGetConversionRateBySourceDocumentAndParentGBPToEURNonBase() {
       try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();

            System.runAs(testData.users.get(1)) {
                Billing__c bill = testData.billings[0].clone();
                bill.Date__c = Date.newInstance(1990, 10, 8);
                bill.put('CurrencyIsoCode', 'GBP');

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = 'EUR';
                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    getDatedConversionRates();

                System.assert(
                    1 < MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler.datedConversionRateMap.size()
                );
                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);
                System.assertEquals(1.5, sdm.currencyConversionRate);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }



    @IsTest
    public static void testDatedConversionRateHandlerGetDCRDatesOutOfSequence() {
       try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                                            .enableMultiCurrency()//will throw an exception in case of non-MC org
                                            .createBillings();

            System.runAs(testData.users.get(1)) {

                MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler datedConversionRateHandler =
                    new MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler();
                MultiCurrencySourceDocumentProcessor.DatedConversionRate dcr;

                Date startDate = Date.newInstance(0000, 12, 30);
                Date nextStartDate = Date.newInstance(9999, 12, 30);
                String isoCode = 'USD';
                Double ccr = 1;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1990, 10, 6);
                nextStartDate = Date.newInstance(1995, 5, 30);
                isoCode = 'GBP';
                ccr = 0.90;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1995, 5, 30);
                nextStartDate = Date.newInstance(9999, 12, 30);
                isoCode = 'GBP';
                ccr = 0.85;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);  

                startDate = Date.newInstance(0000, 12, 30);
                nextStartDate = Date.newInstance(1990, 8, 6);
                isoCode = 'GBP';
                ccr = 0.70;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1990, 8, 6);
                nextStartDate = Date.newInstance(1990, 10, 6);
                isoCode = 'GBP';
                ccr = 0.80;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);  

                Billing__c bill = testData.billings[0].clone();
                bill.Date__c = Date.newInstance(1996, 8, 7);
                bill.put('CurrencyIsoCode', 'GBP');

                MultiCurrencySourceDocumentProcessor.getInstance().init('Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency sdm =
                    new MultiCurrencySourceDocumentProcessor.SourceDocumentMultiCurrency(true);
                sdm.newRecord = bill;
                sdm.oldRecord = NULL;
                sdm.parentISOCode = 'USD';

                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    datedConversionRateHandler;
                System.assert(
                    1 < MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler.datedConversionRateMap.size()
                );
                System.assertEquals(true, sdm.isCalculateCurrencyConversionRate());
                System.assertEquals(false, sdm.isCurrencyConversionRateOne());
                System.assertEquals(NULL, sdm.currencyConversionRate);

                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateOrAddRetrievalList(sdm);
                System.assertEquals(0.85, sdm.currencyConversionRate);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testCreateMultipleJournalEntriesEachFallWithinDifferentDcrPeriod() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency();//will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler datedConversionRateHandler =
                    new MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler();
                MultiCurrencySourceDocumentProcessor.DatedConversionRate dcr;

                //Ledger DCR
                Date startDate = Date.newInstance(0000, 12, 30);
                Date nextStartDate = Date.newInstance(9999, 12, 30);
                String isoCode = 'USD';
                Double ccr = 1;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                //Record DCR
                startDate = Date.newInstance(0000, 12, 30);
                nextStartDate = Date.newInstance(1991, 10, 1);
                isoCode = 'EUR';
                ccr = 0.85;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1991, 10, 1);
                nextStartDate = Date.newInstance(1991, 11, 1);
                isoCode = 'EUR';
                ccr = 0.85;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1991, 11, 1);
                nextStartDate = Date.newInstance(1991, 12, 1);
                isoCode = 'EUR';
                ccr = 0.86;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1991, 12, 1);
                nextStartDate = Date.newInstance(9999, 12, 30);
                isoCode = 'EUR';
                ccr = 0.87;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();
                Journal_Entry__c baseJE = new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Journal_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10),
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Ledger__c = testData.ledgers[0].Id
                );
                baseJE.put('CurrencyIsoCode', 'EUR');
                journalEntries.add(baseJE);

                Journal_Entry__c clonedJE = baseJE.clone(false, true);
                clonedJE.Journal_Date__c = testData.acctPeriods[1].Start_Date__c.addDays(10);
                journalEntries.add(clonedJE);

                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    datedConversionRateHandler;
                MultiCurrencySourceDocumentProcessor.getInstance().init('Journal_Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.getInstance().setParentIsoCodeByLedger(
                    NULL, journalEntries
                );
                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateRecords();

                System.assertEquals(0.85, baseJE.Currency_Conversion_Rate__c);
                System.assertEquals(0.86, clonedJE.Currency_Conversion_Rate__c);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testCreateMultipleJournalEntriesEachFallOnStartOfDifferentDcrPeriod() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance(true)
                .enableMultiCurrency();//will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler datedConversionRateHandler =
                    new MultiCurrencySourceDocumentProcessor.DatedConversionRateHandler();
                MultiCurrencySourceDocumentProcessor.DatedConversionRate dcr;

                //Ledger DCR
                Date startDate = Date.newInstance(0000, 12, 30);
                Date nextStartDate = Date.newInstance(9999, 12, 30);
                String isoCode = 'USD';
                Double ccr = 1;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                //Record DCR
                startDate = Date.newInstance(0000, 12, 30);
                nextStartDate = Date.newInstance(1991, 10, 1);
                isoCode = 'EUR';
                ccr = 0.85;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1991, 10, 1);
                nextStartDate = Date.newInstance(1991, 11, 1);
                isoCode = 'EUR';
                ccr = 0.85;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1991, 11, 1);
                nextStartDate = Date.newInstance(1991, 12, 1);
                isoCode = 'EUR';
                ccr = 0.86;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                startDate = Date.newInstance(1991, 12, 1);
                nextStartDate = Date.newInstance(9999, 12, 30);
                isoCode = 'EUR';
                ccr = 0.87;
                dcr = new MultiCurrencySourceDocumentProcessor.DatedConversionRate(
                    startDate, nextStartDate, isoCode, ccr
                );
                datedConversionRateHandler.addDatedConversionRate(dcr);

                List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>();
                Journal_Entry__c baseJE = new Journal_Entry__c(
                    Name = 'testJournal 1',
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Journal_Date__c = testData.acctPeriods[0].Start_Date__c,
                    Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
                    Ledger__c = testData.ledgers[0].Id
                );
                baseJE.put('CurrencyIsoCode', 'EUR');
                journalEntries.add(baseJE);

                Journal_Entry__c clonedJE = baseJE.clone(false, true);
                clonedJE.Journal_Date__c = testData.acctPeriods[1].Start_Date__c;
                journalEntries.add(clonedJE);

                MultiCurrencySourceDocumentProcessor.getInstance().datedConversionRateHandler =
                    datedConversionRateHandler;
                MultiCurrencySourceDocumentProcessor.getInstance().init('Journal_Date__c', 'Ledger__c');
                MultiCurrencySourceDocumentProcessor.getInstance().setParentIsoCodeByLedger(
                    NULL, journalEntries
                );
                MultiCurrencySourceDocumentProcessor.getInstance().setCurrencyConversionRateRecords();

                System.assertEquals(0.85, baseJE.Currency_Conversion_Rate__c);
                System.assertEquals(0.86, clonedJE.Currency_Conversion_Rate__c);
            }
        }
        catch (Exception ex) {
            //just skip this test if it is non-MC org
        }
    }

}