@IsTest
public class SObjectActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    //=============================================================================
    //===== Group of test methods related to the Multi Currency functionality =====
    //=============================================================================

    @IsTest
    public static void testPreventUpdateCurrencyConversionRateIfPostedForPreExistedPostedRecords() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createCashReceipts();
            System.runAs(testData.users.get(1)) {
                testData.cashReceipts[0].Currency_Conversion_Rate__c = NULL;

                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Currency_Conversion_Rate__c,
                        Cash_Receipt__c.Status__c
                    }
                );
                update testData.cashReceipts[0];

                testData.cashReceipts[0].Payment_Reference__c = 'newRef';
                DmlException dmlEx;
                try {
                    update testData.cashReceipts[0];
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                System.assertEquals(NULL, dmlEx);
                System.assertEquals(1, [SELECT Currency_Conversion_Rate__c FROM Cash_Receipt__c WHERE Id = :testData.cashReceipts[0].Id LIMIT 1].Currency_Conversion_Rate__c);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testPreventUpdateCurrencyConversionRateIfPostedForRegularRecords() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Cash_Receipt__c testCR = new Cash_Receipt__c(
                    Account__c = testData.accounts[0].Id,
                    Amount__c = 1000,
                    Payment_Reference__c = 'oldRef',
                    Status__c = 'In Process',
                    Receipt_Date__c = testData.acctPeriods[1].Start_Date__c,
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Purpose__c = 'Customer Receipt',
                    Bank_Account__c = testData.glAccounts[0].Id,
                    Credit_GL_Account__c = testData.glAccounts[1].Id
                );

                testCR.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert testCR;

                testCR = [SELECT Id, Currency_Conversion_Rate__c FROM Cash_Receipt__c WHERE Id = :testCR.Id];
                testCR.Currency_Conversion_Rate__c = 1.2;
                DmlException dmlEx;
                try {
                    update testCR;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }

                SourceDocumentUpdateFieldValidator sfu = new CashReceiptFieldUpdateValidator();
                System.assertEquals(
                    String.format(SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR, new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0]}),
                    dmlEx.getDMLMessage(0)
                );
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyByLedger() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createScheduledRevenueExpense();

            System.runAs(testData.users.get(1)) {
                String theNewCurrencyIsoCode = getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                String ledgerCurrency = (String) LedgerHandler.getInstanceWithoutSharing().getLedgerById(testData.ledgers[0].Id).get('CurrencyIsoCode');

                List<Scheduled_Revenue_Expense__c> scheduledRevenueExpenses = new List<Scheduled_Revenue_Expense__c>();
                //Check before insert trigger behaviour

                for (Scheduled_Revenue_Expense__c sre : (List<Scheduled_Revenue_Expense__c>) Database.query('SELECT Id, CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c LIMIT 10')) {
                    System.assertEquals(ledgerCurrency, (String) sre.get('CurrencyIsoCode'));
                    sre.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                    scheduledRevenueExpenses.add(sre);
                }

                //Check before update trigger behavior
                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Schema.SObjectType.Scheduled_Revenue_Expense__c.fields.getMap().get('CurrencyIsoCode'),
                        Scheduled_Revenue_Expense__c.Status__c,
                        Scheduled_Revenue_Expense__c.Amount__c
                    }
                );
                update scheduledRevenueExpenses;

                for (Scheduled_Revenue_Expense__c sre : (List<Scheduled_Revenue_Expense__c>) Database.query('SELECT Id, CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Scheduled_Revenue_Expense__c LIMIT 10')) {
                    System.assertEquals(ledgerCurrency, (String) sre.get('CurrencyIsoCode'));
                }
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    public static void testValidateAndSetCurrencyConversionRateOnInsert() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                //insert new record
                Account_Payable__c newAcctPayable = new Account_Payable__c(
                    Payee_Reference__c = 'testRef',
                    Status__c = 'In Process',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[1].End_Date__c,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = testData.acctPeriods[1].Id
                );
                insert newAcctPayable;

                //Expected: Currency Conversion Rate should be set by trigger logic
                System.assertNotEquals(NULL, [SELECT Currency_Conversion_Rate__c FROM Account_Payable__c WHERE Id = :newAcctPayable.Id LIMIT 1].Currency_Conversion_Rate__c);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    public static void testValidateAndSetCurrencyConversionRateOnUpdate() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                String theNewCurrencyIsoCode = getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                //insert new record
                Account_Payable__c newAcctPayable = new Account_Payable__c(
                    Payee_Reference__c = 'testRef',
                    Status__c = 'In Process',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[1].End_Date__c,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = testData.acctPeriods[1].Id
                );

                newAcctPayable.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert newAcctPayable;

                //Expected: Currency Conversion Rate should be set by trigger logic
                System.assertNotEquals(NULL, [SELECT Currency_Conversion_Rate__c FROM Account_Payable__c WHERE Id = :newAcctPayable.Id LIMIT 1].Currency_Conversion_Rate__c);

                //Now let's test wrong CCR value(negative) during record update
                newAcctPayable.Currency_Conversion_Rate__c = -2;

                DmlException dmlEx;
                try {
                    update newAcctPayable;
                }
                catch (DmlException ex) {
                    dmlEx = ex;
                }
                System.assertEquals(SObjectActions.CURRENCY_CONVERSION_RATE_RANGE_ERROR, dmlEx.getDmlMessage(0));
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    public static void testSetISOCodeFromParent() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables();

            System.runAs(testData.users.get(1)) {

                Account_Payable_Line__c newLineWithNonMasterCurrency = new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = 666,
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Expense_GL_Account__c = testData.glAccounts[16].Id
                );

                String theNewCurrencyIsoCode = getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }
                //set different Currency for the record
                newLineWithNonMasterCurrency.put('CurrencyIsoCode', theNewCurrencyIsoCode);

                insert newLineWithNonMasterCurrency;
                //EXPECTED: this new line must have same currency iso code as its master record
                String testAcctPayableId = testData.payables[0].Id;
                String testAcctLineId = newLineWithNonMasterCurrency.Id;
                String masterCurrCode = String.valueOf(Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable__c WHERE Id = :testAcctPayableId')[0].get('CurrencyIsoCode'));
                String lineCurrCode = String.valueOf(Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable_Line__c WHERE Id = :testAcctLineId')[0].get('CurrencyIsoCode'));
                System.assertEquals(masterCurrCode, lineCurrCode);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetISOCodeFromParentLedger() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency() //will throw an exception in case of non-MC org
                .createPayables();

            System.runAs(testData.users.get(1)) {

                String theNewCurrencyIsoCode = getTheNewCurrencyIsoCode();

                //If there is no another currency except current - there is nothing to test
                if (String.isBlank(theNewCurrencyIsoCode)) {
                    return;
                }

                Account_Payable__c ap = new Account_Payable__c(
                    Payee_Reference__c = '2345sdfghtws',
                    Status__c = 'Approved',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[0].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[0].End_Date__c,
                    Vendor__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = testData.ledgers[0].Id
                );
                ap.put('CurrencyIsoCode', theNewCurrencyIsoCode);
                insert ap;

                AP_Aging_History__c aph = new AP_Aging_History__c(
                    Amount__c = 100,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Account_Payable__c = ap.Id
                );
                insert aph;

                String testAPHId = aph.Id;
                String aphCurrCode = String.valueOf(Database.query('SELECT CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'AP_Aging_History__c WHERE Id = :testAPHId')[0].get('CurrencyIsoCode'));

                System.assertEquals(LedgerHandler.getLedgerCurrency(testData.ledgers[0].Id), aphCurrCode);
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    public static void testSetCurrencyConversionRateBySourceDocumentAndLedger() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                String ledgerId = testData.ledgers[0].Id;

                Map<String, Decimal> ccrMap = getCurrencyConversionRateMap();
                Map<Id, Ledger__c> testLedgers = new Map<Id, Ledger__c>(getLedgersInForeignCurrency());
                List<String> existingCurrency = new List<String>();

                Ledger__c baseLedger = Database.query('SELECT Id, CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c WHERE Id = :ledgerId');
                testLedgers.put(baseLedger.Id, baseLedger);

                for (Ledger__c ledger : testLedgers.values()) {
                    existingCurrency.add((String) ledger.get('CurrencyIsoCode'));
                }

                List<Billing__c> billings = new List<Billing__c>();
                for (Ledger__c ledger : testLedgers.values()) {
                    for (String currencyCode : existingCurrency) {
                        if (currencyCode != (String) ledger.get('CurrencyIsoCode')) {
                            Billing__c bill = new Billing__c(
                                    Date__c = System.today(),
                                    Customer__c = testData.accounts[0].Id,
                                    Accounting_Period__c = testData.acctPeriods[0].Id,
                                    Ledger__c = ledger.Id
                                );
                            bill.put('CurrencyIsoCode', currencyCode);
                            billings.add(bill);
                        }
                    }

                }

                insert billings;

                billings = Database.query('SELECT Id, CurrencyIsoCode, Currency_Conversion_Rate__c, ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c WHERE Id IN :billings');
                for (Billing__c bill : billings) {
                    Decimal expectedResult = (ccrMap.get((String) bill.get('CurrencyIsoCode'))/ccrMap.get((String) testLedgers.get(bill.Ledger__c).get('CurrencyIsoCode'))).setScale(6, System.RoundingMode.HALF_UP);
                    System.assertEquals(expectedResult, bill.Currency_Conversion_Rate__c);
                }

                for (Billing__c bill : billings) {
                    bill.Currency_Conversion_Rate__c = 10;
                }

                update billings;

                billings = Database.query('SELECT Id, CurrencyIsoCode, Currency_Conversion_Rate__c, ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c WHERE Id IN :billings');
                for (Billing__c bill : billings) {
                    System.assertEquals(10, bill.Currency_Conversion_Rate__c);
                }

                String secondLedgerId = testData.ledgers[2].Id;
                Ledger__c secondLedger = Database.query('SELECT Id, CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c WHERE Id = :secondLedgerId');
                testLedgers.put(secondLedger.Id, secondLedger);

                for (Billing__c bill : billings) {
                    if (bill.Ledger__c != testData.ledgers[0].Id) {
                        bill.Ledger__c = testData.ledgers[0].Id;
                    }
                    else {
                        bill.Ledger__c = testData.ledgers[2].Id;
                    }
                }

                update billings;

                billings = Database.query('SELECT Id, CurrencyIsoCode, Currency_Conversion_Rate__c, ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c WHERE Id IN :billings');
                for (Billing__c bill : billings) {
                    Decimal expectedResult = (ccrMap.get((String) bill.get('CurrencyIsoCode'))/ccrMap.get((String) testLedgers.get(bill.Ledger__c).get('CurrencyIsoCode'))).setScale(6, System.RoundingMode.HALF_UP);
                    System.assertEquals(expectedResult, bill.Currency_Conversion_Rate__c);
                }
            }
        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    @IsTest
    public static void testSetCCRForDifferentSourcePerTransaction() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency(); //will throw an exception in case of non-MC org

            System.runAs(testData.users.get(1)) {

                String ledgerId = testData.ledgers[0].Id;

                Map<String, Decimal> ccrMap = getCurrencyConversionRateMap();
                if (ccrMap.isEmpty()) {
                    return;
                }
                Map<Id, Ledger__c> testLedgers = new Map<Id, Ledger__c>(getLedgersInForeignCurrency());
                List<String> existingCurrency = new List<String>();

                Ledger__c baseLedger = Database.query('SELECT Id, CurrencyIsoCode FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c WHERE Id = :ledgerId');
                testLedgers.put(baseLedger.Id, baseLedger);

                for (Ledger__c ledger : testLedgers.values()) {
                    existingCurrency.add((String) ledger.get('CurrencyIsoCode'));
                }
                Billing__c bill = new Billing__c(
                    Date__c = System.today(),
                    Customer__c = testData.accounts[0].Id,
                    Accounting_Period__c = testData.acctPeriods[0].Id,
                    Ledger__c = testLedgers.values()[0].Id
                );
                bill.put('CurrencyIsoCode', existingCurrency[0]);

                insert bill;

                String billId = bill.Id;
                Billing__c newBill = Database.query('SELECT Id, CurrencyIsoCode, Currency_Conversion_Rate__c, ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c WHERE Id = :billId LIMIT 1');
                Decimal expectedResult = (ccrMap.get(existingCurrency[0])/ccrMap.get((String) testLedgers.get(testLedgers.values()[0].Id).get('CurrencyIsoCode'))).setScale(6, System.RoundingMode.HALF_UP);
                System.assertEquals(expectedResult, newBill.Currency_Conversion_Rate__c);

                if (existingCurrency.size() >= 2 && testLedgers.values().size() >= 2) {
                    Account_Payable__c ap = new Account_Payable__c(
                        Vendor__c = testData.accounts[0].Id,
                        Accounting_Period__c = testData.acctPeriods[0].Id,
                        Date__c = System.today(),
                        Payee_Reference__c = 'testReference',
                        Ledger__c = testLedgers.values()[0].Id
                    );
                    ap.put('CurrencyIsoCode', existingCurrency[1]);
                    insert ap;
                    String apId = ap.Id;
                    Account_Payable__c newAp = Database.query('SELECT Id, CurrencyIsoCode, Currency_Conversion_Rate__c, ' + GlobalVariables.PACKAGE_QUALIFIER + 'Ledger__c FROM ' + GlobalVariables.PACKAGE_QUALIFIER + 'Account_Payable__c WHERE Id = :apId LIMIT 1');
                    Decimal expectedResult2 = (ccrMap.get(existingCurrency[1])/ccrMap.get((String) testLedgers.get(testLedgers.values()[0].Id).get('CurrencyIsoCode'))).setScale(6, System.RoundingMode.HALF_UP);
                    System.assertEquals(expectedResult2, newAp.Currency_Conversion_Rate__c);
                }
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }

    }

    //this method returns Currency ISO Code wich is not equal to the current User's currency
    public static String getTheNewCurrencyIsoCode() {
        String result;
        List<SObject> allCurrencies = Database.query('SELECT Id, IsoCode FROM CurrencyType LIMIT 2');
        for (SObject eachCurrency : allCurrencies) {
            if (eachCurrency.get('IsoCode') != UserInfo.getDefaultCurrency()) {
                result = (String) eachCurrency.get('IsoCode');
                break;
            }
        }
        return result;
    }

    public static List<Ledger__c> getLedgersInForeignCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance();
        List<Ledger__c> result = new List<Ledger__c>();
        List<SObject> allCurrencies = Database.query('SELECT Id, IsoCode FROM CurrencyType');
        for (SObject eachCurrency : allCurrencies) {
            if (eachCurrency.get('IsoCode') != UserInfo.getDefaultCurrency()) {
                Ledger__c ledger = new Ledger__c(
                        Name = 'Actual',
                        Type__c = 'Transactional',
                        Default_Bank_Account__c = testData.glAccounts[0].Id,
                        Default_Billing_Format__c = testData.billingFormats[0].Id,
                        Billing_Outstanding_Statement_Format__c = testData.billingFormats[2].Id,
                        Billing_Activity_Statement_Format__c = testData.billingFormats[3].Id
                    );
                ledger.put('CurrencyIsoCode', (String) eachCurrency.get('IsoCode'));
                result.add(ledger);
            }
            if (result.size() >= 2) {
                break;
            }
        }

        insert result;

        return result;
    }

    public static Map<String, Decimal> getCurrencyConversionRateMap() {
        Map<String, Decimal> result = new Map<String, Decimal>();
        List<SObject> allCurrencies = Database.query(
            'SELECT IsoCode, StartDate, NextStartDate, ConversionRate FROM DatedConversionRate WHERE (StartDate <= ' + String.valueOf(System.today()) + ' AND NextStartDate >= ' + String.valueOf(System.today()) + ')'
        );
        for (SObject eachCurrency : allCurrencies) {
            result.put((String) eachCurrency.get('IsoCode'), (Decimal) eachCurrency.get('ConversionRate'));
        }

        return result;
    }

    //=============================================================================
    //=============================================================================

    @IsTest
    public static void testUpdateLedgerWithAssociatedRecords() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Deposit__c testBankDeposit = new Bank_Deposit__c(
                Deposit_Date__c = testData.acctPeriods[1].Start_Date__c,
                Bank_Account__c = testData.glAccounts[0].Id,
                Deposit_Reference__c = 'the reference 1'
            );
            insert testBankDeposit;

            testData.cashReceipts[0].Bank_Deposit__c = testBankDeposit.Id;

            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];

            testBankDeposit.Ledger__c = testData.ledgers[2].Id;

            DmlException dmlEx;
            try {
                TriggerObserver.getInstance().unlockField(Bank_Deposit__c.Ledger__c);
                update testBankDeposit;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(
                String.format(
                    SObjectActions.FIELD_CHANGE_WITH_ASSOCIATED_RECORD_ERROR_MAP.get(Bank_Deposit__c.getSObjectType()),
                    new List<String> {'Ledger'}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

    @IsTest
    public static void associateWithCashFlowCategory() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createCashDisbursementBatches()
            .createCashDisbursements()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.createCashFlowCategories(true);

            List<Cash_Receipt__c> insertCRList = new List<Cash_Receipt__c>();
            Integer totalNumberOfCashReceipts = 0;
            for (Cash_Receipt__c cr : testData.cashReceipts) {
                insertCRList.add(cr.clone());
                totalNumberOfCashReceipts += 1;
            }

            insert insertCRList;

            List<Cash_Receipt__c> cashReceiptsAssociatedWithCFC = [
                SELECT Id
                FROM Cash_Receipt__c
                WHERE Cash_Flow_Category__c != NULL
            ];

            System.assertEquals(totalNumberOfCashReceipts, cashReceiptsAssociatedWithCFC.size());

            List<Cash_Disbursement__c> insertCDList = new List<Cash_Disbursement__c>();
            Integer totalNumberOfCashDisbursements = 0;
            for (Cash_Disbursement__c cd : testData.cashDisbursements) {
                insertCDList.add(cd.clone());
                totalNumberOfCashDisbursements += 1;
            }

            insert insertCDList;

            List<Cash_Disbursement__c> cashDisbursementsAssociatedWithCFC = [
                SELECT Id
                FROM Cash_Disbursement__c
                WHERE Cash_Flow_Category__c != NULL
            ];

            System.assertEquals(totalNumberOfCashDisbursements, cashDisbursementsAssociatedWithCFC.size());

            List<Journal_Entry_Line__c> insertJELList = new List<Journal_Entry_Line__c>();
            Integer totalNumberOfJournalEntryLines = 0;
            for (Journal_Entry_Line__c jel : testData.journalEntryLines) {
                insertJELList.add(jel.clone());
                totalNumberOfJournalEntryLines += 1;
            }

            insert insertJELList;

            List<Journal_Entry_Line__c> jeLinesAssociatedWithCFC = [
                SELECT Id
                FROM Journal_Entry_Line__c
                WHERE Cash_Flow_Category__c != NULL
            ];

            System.assertEquals(totalNumberOfJournalEntryLines, jeLinesAssociatedWithCFC.size());

            Test.stopTest();
        }
    }

    @IsTest
    public static void testPreventInsertLineAction() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries(true);

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            DmlException dmlException;

            //try to create and add new line for the posted record
            Journal_Entry_Line__c testJournalEntryLine = testData.journalEntryLines[0].clone(false, true, false, false);

            try {
                insert testJournalEntryLine;
            }
            catch (DmlException ex) {
                dmlException = ex;
            }

            System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_INSERT_ERROR, dmlException.getDMLMessage(0));
        }
    }

    @IsTest
    public static void testPreventSameTimeApplyOnDepositAndReconciliation() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankDeposits()
            .createBankReconciliations()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
            TriggerObserver.getInstance().unlockFields(
                new Set<SObjectField>{
                    Cash_Receipt__c.Bank_Deposit__c,
                    Cash_Receipt__c.Status__c
                }
            );
            update testData.cashReceipts[0];
            testData.cashReceipts[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

            DmlException dmlEx;
            try {
                TriggerObserver.getInstance().unlockFields(
                    new Set<SObjectField>{
                        Cash_Receipt__c.Bank_Reconciliation__c,
                        Cash_Receipt__c.Status__c
                    }
                );
                update testData.cashReceipts[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.APPLY_DEPOSIT_ERROR, dmlEx.getDmlMessage(0));

            testData.cashReceipts[0].Bank_Deposit__c = NULL;
            testData.cashReceipts[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
            update testData.cashReceipts[0];
            testData.cashReceipts[0].Bank_Deposit__c = testData.bankDeposits[0].Id;

            DmlException dmlEx2;
            try {
                update testData.cashReceipts[0];
            }
            catch (DmlException ex) {
                dmlEx2 = ex;
            }

            System.assertEquals(SObjectActions.APPLY_RECONCILIATION_ERROR, dmlEx2.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testPopulateLedgerField() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
        //insert new record
            Account_Payable__c newAcctPayable = new Account_Payable__c(
                    Payee_Reference__c = 'testRef',
                    Status__c = 'In Process',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[1].End_Date__c,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = testData.acctPeriods[1].Id
            );
            insert newAcctPayable;

            System.assertEquals(testData.ledgers[0].Id, [SELECT Ledger__c FROM Account_Payable__c WHERE Id = :newAcctPayable.Id LIMIT 1].Ledger__c);
        }

    }

    @IsTest
    public static void testValidateLedgerType() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //insert new record
            Account_Payable__c newAcctPayable = new Account_Payable__c(
                    Payee_Reference__c = 'testRef',
                    Status__c = 'In Process',
                    Payment_Status__c = 'Unpaid',
                    Date__c = testData.acctPeriods[1].Start_Date__c,
                    Due_Date__c = testData.acctPeriods[1].End_Date__c,
                    Employee__c = UserInfo.getUserId(),
                    Accounting_Period__c = testData.acctPeriods[1].Id,
                    Ledger__c = testData.ledgers[1].Id
            );

            DmlException dmlEx;
            try {
                insert newAcctPayable;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(0));
        }

    }

    @IsTest
    public static void testValidateLedgerTypeForRecurringJEs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            Ledger__c testConsLedger = [SELECT Id FROM Ledger__c WHERE Name = 'Consolidation ledger1'];
            Ledger__c testElimLedger = [SELECT Id FROM Ledger__c WHERE Consolidation_Ledger_ID__c = :testConsLedger.Id];

            Recurring_Journal_Entry__c testRJE = new Recurring_Journal_Entry__c(
                Name = 'Test Journal Entry 1',
                Next_Journal_Entry_Date__c = Date.newInstance(1991, 12, 31),
                Journal_Entry_Frequency__c = 'Monthly',
                Status__c = 'Active',
                Ledger__c = testConsLedger.Id
            );

            DmlException dmlEx;
            try {
                insert testRJE;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            //Consolidation Ledger is not allowed
            System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = null;
            try {
                testRJE.Ledger__c = testElimLedger.Id;
                insert testRJE;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            //Elimination Ledger is allowed for JE & RJE records
            System.assertEquals(null, dmlEx);
        }

    }

    @IsTest
    public static void testValidateLedgerTypeForTimeCardsOnUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createConsolidationLedgers();

        System.runAs(testData.users.get(1)) {
            Ledger__c testConsLedger = [SELECT Id FROM Ledger__c WHERE Name = 'Consolidation ledger1'];
            Ledger__c testElimLedger = [SELECT Id FROM Ledger__c WHERE Consolidation_Ledger_ID__c = :testConsLedger.Id];

            Time_Card__c testTC = testData.timeCards[0];

            DmlException dmlEx;
            try {
                testTC.Ledger__c = testConsLedger.Id;
                update testTC;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(0));

            dmlEx = null;
            try {
                testTC.Ledger__c = testElimLedger.Id;
                update testTC;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testNormalizeNumericAndCurrencyFields() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {

            Billing_Line__c billLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Hours_Units__c = 20.989342348934,
                Rate__c = 10.236746723674344,
                List_Price__c = 23.423423545452423,
                Product_Unit_Cost__c = 3.4237468273582872853

            );
            insert billLine;

            Billing_Line__c newBillingLine = [
                SELECT Id,
                    Hours_Units__c,
                    Rate__c,
                    List_Price__c,
                    Product_Unit_Cost__c
                FROM Billing_Line__c
                WHERE Id = : billLine.Id];

            System.assertEquals(20.989342, newBillingLine.Hours_Units__c);
            System.assertEquals(10.236747, newBillingLine.Rate__c);
            System.assertEquals(23.42, newBillingLine.List_Price__c);
            System.assertEquals(3.423747, newBillingLine.Product_Unit_Cost__c);
        }

    }

    @IsTest
    public static void testPreventUpdateLedgerIfAssociatedAE() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createBillings();

        System.runAs(testData.users.get(1)) {

            Scheduled_Revenue_Expense__c sre = new Scheduled_Revenue_Expense__c(
                Name = 'Test SRE',
                Amount__c = 400,
                Credit_GL_Account__c = testData.glAccounts[11].Id,
                Debit_GL_Account__c = testData.glAccounts[16].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'Scheduled',
                Billing__c = testData.billings[0].Id
            );
            insert sre;

            DmlException dmlException;
            try {
                testData.billings[0].Ledger__c = testData.ledgers[2].Id;
                update testData.billings[0];
            }
            catch (DmlException ex) {
                dmlException = ex;
            }

            System.assertEquals(SObjectActions.LEDGER_UPDATE_IF_AE_ASSOCIATED_ERROR, dmlException.getDmlMessage(0));
        }
    }

    //======================================================================================
    //======== TEST GLAVs TRANSFER ====================================================
    //======================================================================================

    //INSERT PAYABLE LINE TESTING ==================================================
    @IsTest
    public static void testPayableLineAndGLAVsFromProduct() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProducts()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Product2 testProduct = testData.products[0];
            testProduct.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testProduct.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testProduct.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testProduct.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;

            update testProduct;

            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();
            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Product__c = testProduct.Id,
                    Expense_GL_Account__c = testData.glAccounts[12].Id
                )
            );

            insert accountPayableLines;

            System.assertEquals(
                testProduct.GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testProduct.GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testProduct.GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testProduct.GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_4__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPayableLineAndGLAVsSetByUser() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProducts()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.products[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.products[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.products[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.products[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.products[0];

            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();
            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Product__c = testData.products[0].Id,
                    Expense_GL_Account__c = testData.glAccounts[12].Id,
                    GL_Account_Variable_1__c = testData.accountingVariables1[1].Id,
                    GL_Account_Variable_2__c = testData.accountingVariables2[1].Id,
                    GL_Account_Variable_3__c = testData.accountingVariables3[1].Id,
                    GL_Account_Variable_4__c = testData.accountingVariables4[1].Id
                )
            );

            insert accountPayableLines;

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_1__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_2__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_3__c
            );

            System.assertNotEquals(
                testData.products[0].GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_4__c
            );
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPayableLineAndGLAVsFromAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProducts()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.accounts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.accounts[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.accounts[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.accounts[0];

            List<Account_Payable_Line__c> accountPayableLines = new List<Account_Payable_Line__c>();
            accountPayableLines.add(
                new Account_Payable_Line__c(
                    Account_Payable__c = testData.payables[0].Id,
                    Amount__c = 45,
                    Date__c = System.today(),
                    Product__c = testData.products[0].Id,
                    Expense_GL_Account__c = testData.glAccounts[12].Id
                )
            );

            insert accountPayableLines;

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Account_Payable_Line__c
                    WHERE Id = :accountPayableLines[0].Id].GL_Account_Variable_4__c
            );
            Test.stopTest();
        }
    }

    //INSERT BILLING LINE
    @IsTest
    public static void testBillingLineAndGLAVsFromAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProducts()
            .createBillings()
            .setInventoryValuationStandardCost()
            .setERPEnabled();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.accounts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.accounts[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.accounts[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.accounts[0];

            Billing_Line__c billingLine = new Billing_Line__c(
                Billing__c = testData.billings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Product__c = testData.products[0].Id,
                Hours_Units__c = 20,
                Rate__c = 10
            );


            DMLException dmlEx;
            try {
                insert billingLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_1__c,
                [SELECT GL_Account_Variable_1__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_2__c,
                [SELECT GL_Account_Variable_2__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_3__c,
                [SELECT GL_Account_Variable_3__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_4__c,
                [SELECT GL_Account_Variable_4__c FROM Billing_Line__c WHERE Id = :billingLine.Id].GL_Account_Variable_4__c
            );
            Test.stopTest();
        }

    }

    //INSERT RECURRING PAYABLE LINE
    @IsTest
    public static void testRecurringPayableLineAndGLAVsFromProduct() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProducts()
            .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            Product2 testProduct = testData.products[0];
            testProduct.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testProduct.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testProduct.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testProduct.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;

            update testProduct;

            List<Recurring_Account_Payable_Line__c> recPayableLines = new List<Recurring_Account_Payable_Line__c>();
            recPayableLines.add(
                new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                    Amount2__c = 45,
                    Quantity__c = 1,
                    Date__c = System.today(),
                    Product__c = testProduct.Id,
                    Expense_GL_Account__c = testData.glAccounts[11].Id
                )
            );

            insert recPayableLines;

            System.assertEquals(
                testProduct.GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testProduct.GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testProduct.GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id
                ].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testProduct.GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id
                ].GL_Account_Variable_4__c
            );
        }
    }

    @IsTest
    public static void testRecurringPayableLineAndGLAVsFromAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProducts()
            .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            testData.accounts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.accounts[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.accounts[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.accounts[0];

            Product2 testProduct = testData.products[0];
            testProduct.GL_Account_Variable_1__c = testData.accountingVariables1[1].Id;
            testProduct.GL_Account_Variable_2__c = testData.accountingVariables2[1].Id;
            testProduct.GL_Account_Variable_3__c = testData.accountingVariables3[1].Id;
            testProduct.GL_Account_Variable_4__c = testData.accountingVariables4[1].Id;

            update testProduct;

            List<Recurring_Account_Payable_Line__c> recPayableLines = new List<Recurring_Account_Payable_Line__c>();
            recPayableLines.add(
                new Recurring_Account_Payable_Line__c(
                    Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                    Amount2__c = 45,
                    Quantity__c = 1,
                    Product__c = testProduct.Id,
                    Date__c = System.today(),
                    Expense_GL_Account__c = testData.glAccounts[11].Id
                )
            );

            insert recPayableLines;

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Recurring_Account_Payable_Line__c
                    WHERE Id = :recPayableLines[0].Id].GL_Account_Variable_4__c
            );
        }
    }

    //INSERT RECURRING BILLING LINE
    @IsTest
    public static void testRecurringBillingLineAndGLAVsFromAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProducts()
            .createRecurringBilling();

        System.runAs(testData.users.get(1)) {
            testData.accounts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.accounts[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.accounts[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.accounts[0];

            Recurring_Billing_Line__c recBillingLine = new Recurring_Billing_Line__c(
                Recurring_Billing__c = testData.recurringBillings[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Product__c = testData.products[0].Id,
                Revenue_GL_Account__c = testData.glAccounts[10].Id,
                Quantity__c = 20,
                Rate__c = 10
            );


            DMLException dmlEx;
            try {
                insert recBillingLine;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_1__c, [
                    SELECT GL_Account_Variable_1__c
                    FROM Recurring_Billing_Line__c
                    WHERE Id = :recBillingLine.Id
                ].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_2__c, [
                    SELECT GL_Account_Variable_2__c
                    FROM Recurring_Billing_Line__c
                    WHERE Id = :recBillingLine.Id
                ].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_3__c, [
                    SELECT GL_Account_Variable_3__c
                    FROM Recurring_Billing_Line__c
                    WHERE Id = :recBillingLine.Id
                ].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_4__c, [
                    SELECT GL_Account_Variable_4__c
                    FROM Recurring_Billing_Line__c
                    WHERE Id = :recBillingLine.Id
                ].GL_Account_Variable_4__c
            );
        }

    }

    //INSERT PROJECT TASK
    @IsTest
    public static void testProjectTaskAndGLAVsFromAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects();

        System.runAs(testData.users.get(1)) {

            testData.accounts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
            testData.accounts[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            testData.accounts[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.accounts[0];

            Project_Task__c projectTask = new Project_Task__c(
                Name = 'Test Project Task',
                Project__c = testData.projects.get(0).Id,
                Status__c = 'Active'
            );

            DMLException dmlEx;
            try {
                insert projectTask;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_1__c,
                [SELECT GL_Account_Variable_1__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_1__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_2__c,
                [SELECT GL_Account_Variable_2__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_3__c,
                [SELECT GL_Account_Variable_3__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_3__c
            );

            System.assertEquals(
                testData.accounts[0].GL_Account_Variable_4__c,
                [SELECT GL_Account_Variable_4__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_4__c
            );
        }

    }

    @IsTest
    public static void testProjectTaskAndGLAVsWithoutAccount() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createAccountingVariables()
            .createProjects();

        System.runAs(testData.users.get(1)) {

            Project__c project =  new Project__c(
                Name = 'Test Project New',
                Status__c = 'Active'
            );

            insert project;

            Project_Task__c projectTask = new Project_Task__c(
                Name = 'Test Project Task',
                Project__c = project.Id,
                Status__c = 'Active',
                GL_Account_Variable_3__c = testData.accountingVariables3[0].Id
            );

            DMLException dmlEx;
            try {
                insert projectTask;
            }
            catch (DMLException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);

            System.assertEquals(
                NULL,
                [SELECT GL_Account_Variable_1__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_1__c
            );

            System.assertEquals(
                NULL,
                [SELECT GL_Account_Variable_2__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_2__c
            );

            System.assertEquals(
                testData.accountingVariables3[0].Id,
                [SELECT GL_Account_Variable_3__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_3__c
            );

            System.assertEquals(
                NULL,
                [SELECT GL_Account_Variable_4__c FROM Project_Task__c WHERE Id = :projectTask.Id].GL_Account_Variable_4__c
            );
        }

    }
    //======================================================================================
    //======================================================================================

    @IsTest
    public static void testDeleteSourceRecordUpdateBTStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            testData.bankTransactions[0].Status__c = BankTransactionsHelper.BT_MATCHED_STATUS;
            testData.cashDisbursements[0].Bank_Transaction__c = testData.bankTransactions[0].Id;

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Transaction__c);
            update testData.cashDisbursements[0];
            TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Bank_Transaction__c);

            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            update testData.bankTransactions[0];
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;

            System.assertEquals(
                BankTransactionsHelper.BT_MATCHED_STATUS,
                [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testData.bankTransactions[0].Id].Status__c
            );

            delete testData.cashDisbursements[0];

            System.assertEquals(
                BankTransactionsHelper.BT_UNMATCHED_STATUS,
                [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testData.bankTransactions[0].Id].Status__c
            );
        }
    }

    @IsTest
    public static void testAmountUpdateSourceRecordUpdateBTStatus() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankTransactions()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Transaction__c testBT = testData.bankTransactions[0];
            Cash_Disbursement__c testCD = testData.cashDisbursements[6];

            testBT.Status__c = BankTransactionsHelper.BT_MATCHED_STATUS;
            testCD.Bank_Transaction__c = testData.bankTransactions[0].Id;
            testCD.Cleared_Date__c = System.today();

            TriggerObserver.getInstance().unlockField(Cash_Disbursement__c.Bank_Transaction__c);
            update testCD;
            TriggerObserver.purgeUnlockedFields(Cash_Disbursement__c.Bank_Transaction__c);

            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            update testBT;
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;

            testBT = [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testBT.Id];
            System.assertEquals(BankTransactionsHelper.BT_MATCHED_STATUS, testBT.Status__c);

            testCD = [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id];
            testCD.Amount__c = 300;
            update testCD;

            Test.stopTest();

            Cash_Disbursement__c cd = [
                SELECT Cleared_Date__c, Bank_Transaction__c
                FROM Cash_Disbursement__c
                WHERE Id = :testData.cashDisbursements[6].Id
            ];

            System.assertEquals(
                BankTransactionsHelper.BT_UNMATCHED_STATUS,
                [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testBT.Id].Status__c
            );
            System.assertEquals(NULL, cd.Cleared_Date__c);
            System.assertEquals(NULL, cd.Bank_Transaction__c);
        }
    }

    @IsTest
    public static void testHandleBtForceMatchForCRs() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .disableAutoPostSourceDocuments()
            .createCashReceipts()
            .createBankTransactions();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Transaction__c testBT = testData.bankTransactions[0];
            Cash_Receipt__c testCR = testData.cashReceipts[0];

            //Enable Force Match feature
            Accounting_Settings__c settings = AccountingSettingsHandler.getAccountingSettings();
            settings.Financial_Suite_Key__c = GlobalVariables.FORCE_MATCH_PERMISSION_KEY;
            update settings;
            //Force Match BT and CR
            testCR.Bank_Transaction__c = testBT.Id;
            update testCR;
            //Check Status of the Bank Transaction record
            testBT = [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testBT.Id];
            System.assertEquals(BankTransactionsHelper.BT_MATCHED_STATUS, testBT.Status__c);
            //Force Unmatch BT and CR
            testCR.Bank_Transaction__c = NULL;
            update testCR;
            //Check Status of the Bank Transaction record
            testBT = [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testBT.Id];
            System.assertEquals(BankTransactionsHelper.BT_UNMATCHED_STATUS, testBT.Status__c);
            //Force Match BT and CR and then change matching to another BT
            testCR.Bank_Transaction__c = testBT.Id;
            update testCR;
            testCR.Bank_Transaction__c = testData.bankTransactions[1].Id;
            update testCR;
            //Check Status of the Bank Transaction record
            testBT = [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testBT.Id];
            Bank_Transaction__c newBT = [SELECT Id, Status__c FROM Bank_Transaction__c WHERE Id = :testData.bankTransactions[1].Id];
            System.assertEquals(BankTransactionsHelper.BT_UNMATCHED_STATUS, testBT.Status__c);
            System.assertEquals(BankTransactionsHelper.BT_MATCHED_STATUS, newBT.Status__c);
        }
    }

    @IsTest
    public static void testSetAppliedDateOutsideAcctPeriodBCM() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        Date today = Date.today();

        System.runAs(testData.users.get(1)) {
            Billing_Credit_Memo__c testBillingCreditMemo = new Billing_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Billing_Invoice__c = testData.billings[1].Id,
                Billing_Credit_Memo__c = testData.billings[2].Id,
                Amount__c = -5,
                Applied_Date__c = today
            );

            DmlException dmlEx;
            try {
                insert testBillingCreditMemo;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testSetAppliedDateOutsideAcctPeriodAPCM() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();
        Date today = Date.today();

        System.runAs(testData.users.get(1)) {
            AP_Credit_Memo__c testAPCM = new AP_Credit_Memo__c(
                Accounting_Period__c = testData.acctPeriods[1].Id,
                Account_Payable_Invoice__c = testData.payables[0].Id,
                Account_Payable_Credit_Memo__c = testData.payables[4].Id,
                Amount__c = -5,
                Applied_Date__c = today
            );

            DmlException dmlEx;
            try {
                insert testAPCM;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(SObjectActions.APPLIED_DATE_OUTSIDE_ACCOUNTING_PERIOD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForPayableInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            // clone new payable records
            List<Account_Payable__c> payables = new List<Account_Payable__c>{
                testData.payables[0].clone(false, true, false, false),
                testData.payables[1].clone(false, true, false, false),
                testData.payables[2].clone(false, true, false, false),
                testData.payables[3].clone(false, true, false, false)
            };

            // set payee ref
            for (Integer i=0; i<payables.size(); i++) {
                payables[i].Payee_Reference__c = 'test-payable-' + i;
            }

            // set ledger
            payables[0].Ledger__c = testData.ledgers[6].Id;
            payables[1].Ledger__c = testData.ledgers[7].Id;
            payables[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            payables[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert payables;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(payables.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForPayableUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createPayables();

        System.runAs(testData.users.get(1)) {
            // get payable records
            List<Account_Payable__c> payables = new List<Account_Payable__c>{
                testData.payables[0],
                testData.payables[1],
                testData.payables[2],
                testData.payables[3]
            };

            // set ledger
            payables[0].Ledger__c = testData.ledgers[6].Id;
            payables[1].Ledger__c = testData.ledgers[7].Id;
            payables[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            payables[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update payables;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(payables.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForBankDepositInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            // clone new bank deposit records
            List<Bank_Deposit__c> bankDeposits = new List<Bank_Deposit__c>{
                testData.bankDeposits[0].clone(false, true, false, false),
                testData.bankDeposits[0].clone(false, true, false, false),
                testData.bankDeposits[0].clone(false, true, false, false),
                testData.bankDeposits[0].clone(false, true, false, false)
            };

            // set ledger
            bankDeposits[0].Ledger__c = testData.ledgers[6].Id;
            bankDeposits[1].Ledger__c = testData.ledgers[7].Id;
            bankDeposits[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            bankDeposits[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert bankDeposits;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(bankDeposits.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForBankDepositUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            // clone new bank deposit records
            List<Bank_Deposit__c> bankDeposits = new List<Bank_Deposit__c>{
                testData.bankDeposits[0].clone(false, true, false, false),
                testData.bankDeposits[0].clone(false, true, false, false),
                testData.bankDeposits[0].clone(false, true, false, false),
                testData.bankDeposits[0].clone(false, true, false, false)
            };

            insert bankDeposits;

            // set ledger
            bankDeposits[0].Ledger__c = testData.ledgers[6].Id;
            bankDeposits[1].Ledger__c = testData.ledgers[7].Id;
            bankDeposits[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            bankDeposits[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update bankDeposits;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(bankDeposits.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForBankReconciliationsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            // clone new bank reconciliation records
            List<Bank_Reconciliation2__c> bankReconciliations = new List<Bank_Reconciliation2__c>{
                testData.bankReconciliations[0].clone(false, true, false, false),
                testData.bankReconciliations[0].clone(false, true, false, false),
                testData.bankReconciliations[0].clone(false, true, false, false),
                testData.bankReconciliations[0].clone(false, true, false, false)
            };

            // set ledger
            bankReconciliations[0].Ledger__c = testData.ledgers[6].Id;
            bankReconciliations[1].Ledger__c = testData.ledgers[7].Id;
            bankReconciliations[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            bankReconciliations[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert bankReconciliations;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(bankReconciliations.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForBillingsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Test.startTest();
        testData.createConsolidationLedgers()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            // clone new billing records
            List<Billing__c> billings = new List<Billing__c>{
                testData.billings[0].clone(false, true, false, false),
                testData.billings[0].clone(false, true, false, false),
                testData.billings[0].clone(false, true, false, false),
                testData.billings[0].clone(false, true, false, false)
            };

            // set ledger
            billings[0].Ledger__c = testData.ledgers[6].Id;
            billings[1].Ledger__c = testData.ledgers[7].Id;
            billings[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            billings[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert billings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(billings.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForBillingsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createBillings();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            // clone new billing records
            List<Billing__c> billings = new List<Billing__c>{
                testData.billings[0].clone(false, true, false, false),
                testData.billings[0].clone(false, true, false, false),
                testData.billings[0].clone(false, true, false, false),
                testData.billings[0].clone(false, true, false, false)
            };

            insert billings;

            // set ledger
            billings[0].Ledger__c = testData.ledgers[6].Id;
            billings[1].Ledger__c = testData.ledgers[7].Id;
            billings[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            billings[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update billings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            Test.stopTest();

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(billings.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForCashDisbursementsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();

        Ledger__c ledgerET = [
                SELECT Id
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1
        ];
        Ledger__c ledgerEB = [
                SELECT Id
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1
        ];

        List<GL_Account_Default__c> defaults = new List<GL_Account_Default__c>{
                new GL_Account_Default__c(Ledger__c = testData.ledgers[6].Id, GL_Account__c = testData.glAccounts[4].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT),
                new GL_Account_Default__c(Ledger__c = testData.ledgers[7].Id, GL_Account__c = testData.glAccounts[4].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT),
                new GL_Account_Default__c(Ledger__c = ledgerET.Id, GL_Account__c = testData.glAccounts[4].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT),
                new GL_Account_Default__c(Ledger__c = ledgerEB.Id, GL_Account__c = testData.glAccounts[4].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
        };
        insert defaults;

        testData
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            // clone cash disbursement records
            List<Cash_Disbursement__c> cashDisbursements = new List<Cash_Disbursement__c>{
                testData.cashDisbursements[0].clone(false, true, false, false),
                testData.cashDisbursements[0].clone(false, true, false, false),
                testData.cashDisbursements[0].clone(false, true, false, false),
                testData.cashDisbursements[0].clone(false, true, false, false)
            };

            // set ledger
            cashDisbursements[0].Ledger__c = testData.ledgers[6].Id;
            cashDisbursements[1].Ledger__c = testData.ledgers[7].Id;
            cashDisbursements[2].Ledger__c = ledgerET.Id;
            cashDisbursements[3].Ledger__c = ledgerEB.Id;

            // test insert
            DmlException dmlEx;
            try {
                insert cashDisbursements;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(cashDisbursements.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForCashDisbursementsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            // clone cash disbursement records
            List<Cash_Disbursement__c> cashDisbursements = new List<Cash_Disbursement__c>{
                testData.cashDisbursements[4].clone(false, true, false, false),
                testData.cashDisbursements[4].clone(false, true, false, false),
                testData.cashDisbursements[4].clone(false, true, false, false),
                testData.cashDisbursements[4].clone(false, true, false, false)
            };

            insert cashDisbursements;

            // set ledger
            cashDisbursements[0].Ledger__c = testData.ledgers[6].Id;
            cashDisbursements[1].Ledger__c = testData.ledgers[7].Id;
            cashDisbursements[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            cashDisbursements[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update cashDisbursements;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(cashDisbursements.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForCashReceiptsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers();
        Ledger__c ledgerET = [
                SELECT Id
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1
        ];
        Ledger__c ledgerEB = [
                SELECT Id
                FROM Ledger__c
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1
        ];

        List<GL_Account_Default__c> defaults = new List<GL_Account_Default__c>{
                new GL_Account_Default__c(Ledger__c = testData.ledgers[6].Id, GL_Account__c = testData.glAccounts[1].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT),
                new GL_Account_Default__c(Ledger__c = testData.ledgers[7].Id, GL_Account__c = testData.glAccounts[1].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT),
                new GL_Account_Default__c(Ledger__c = ledgerET.Id, GL_Account__c = testData.glAccounts[1].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT),
                new GL_Account_Default__c(Ledger__c = ledgerEB.Id, GL_Account__c = testData.glAccounts[1].Id, GL_Account_Specification__c = GLAccountDefaultsHandler.UNAPPLIED_CASH_GL_ACCOUNT)
        };
        insert defaults;
        testData.createCashReceipts();

        System.runAs(testData.users.get(1)) {
            // clone new cash reciepts
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>{
                testData.cashReceipts[0].clone(false, true, false, false),
                testData.cashReceipts[0].clone(false, true, false, false),
                testData.cashReceipts[0].clone(false, true, false, false),
                testData.cashReceipts[0].clone(false, true, false, false)
            };

            // set ledger
            cashReceipts[0].Ledger__c = testData.ledgers[6].Id;
            cashReceipts[1].Ledger__c = testData.ledgers[7].Id;
            cashReceipts[2].Ledger__c = ledgerET.Id;
            cashReceipts[3].Ledger__c = ledgerEB.Id;

            // test insert
            DmlException dmlEx;
            try {
                insert cashReceipts;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(cashReceipts.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForCashReceiptsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            // clone new cash reciepts
            List<Cash_Receipt__c> cashReceipts = new List<Cash_Receipt__c>{
                testData.cashReceipts[0].clone(false, true, false, false),
                testData.cashReceipts[0].clone(false, true, false, false),
                testData.cashReceipts[0].clone(false, true, false, false),
                testData.cashReceipts[0].clone(false, true, false, false)
            };

            insert cashReceipts;

            // set ledger
            cashReceipts[0].Ledger__c = testData.ledgers[6].Id;
            cashReceipts[1].Ledger__c = testData.ledgers[7].Id;
            cashReceipts[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            cashReceipts[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update cashReceipts;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(cashReceipts.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForExpenseReportsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createExpenseReports();

        System.runAs(testData.users.get(1)) {
            // clone new expense report records
            List<Expense_Report__c> expenseReports = new List<Expense_Report__c>{
                testData.expenseReports[0].clone(false, true, false, false),
                testData.expenseReports[0].clone(false, true, false, false),
                testData.expenseReports[0].clone(false, true, false, false),
                testData.expenseReports[0].clone(false, true, false, false)
            };

            // set ledger
            expenseReports[0].Ledger__c = testData.ledgers[6].Id;
            expenseReports[1].Ledger__c = testData.ledgers[7].Id;
            expenseReports[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            expenseReports[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert expenseReports;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(expenseReports.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForExpenseReportsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createExpenseReports();

        System.runAs(testData.users.get(1)) {
            // clone new expense report records
            List<Expense_Report__c> expenseReports = new List<Expense_Report__c>{
                testData.expenseReports[0].clone(false, true, false, false),
                testData.expenseReports[0].clone(false, true, false, false),
                testData.expenseReports[0].clone(false, true, false, false),
                testData.expenseReports[0].clone(false, true, false, false)
            };

            insert expenseReports;

            // set ledger
            expenseReports[0].Ledger__c = testData.ledgers[6].Id;
            expenseReports[1].Ledger__c = testData.ledgers[7].Id;
            expenseReports[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            expenseReports[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update expenseReports;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(expenseReports.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForFixedAssetsInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createFixedAssets();

        System.runAs(testData.users.get(1)) {
            // clone new fixed assets
            List<Fixed_Asset__c> fixedAssets = new List<Fixed_Asset__c>{
                testData.fixedAssets[0].clone(false, true, false, false),
                testData.fixedAssets[0].clone(false, true, false, false),
                testData.fixedAssets[0].clone(false, true, false, false),
                testData.fixedAssets[0].clone(false, true, false, false)
            };

            // set ledger
            fixedAssets[0].Ledger__c = testData.ledgers[6].Id;
            fixedAssets[1].Ledger__c = testData.ledgers[7].Id;
            fixedAssets[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            fixedAssets[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert fixedAssets;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(fixedAssets.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForFixedAssetsUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createFixedAssets();

        System.runAs(testData.users.get(1)) {
            // clone new fixed assets
            List<Fixed_Asset__c> fixedAssets = new List<Fixed_Asset__c>{
                testData.fixedAssets[0].clone(false, true, false, false),
                testData.fixedAssets[0].clone(false, true, false, false),
                testData.fixedAssets[0].clone(false, true, false, false),
                testData.fixedAssets[0].clone(false, true, false, false)
            };

            insert fixedAssets;

            // set ledger
            fixedAssets[0].Ledger__c = testData.ledgers[6].Id;
            fixedAssets[1].Ledger__c = testData.ledgers[7].Id;
            fixedAssets[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            fixedAssets[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update fixedAssets;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(fixedAssets.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForRecurringPayableInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            // clone new recurring payables
            List<Recurring_Account_Payable__c> recurringPayables = new List<Recurring_Account_Payable__c>{
                testData.recurringPayables[0].clone(false, true, false, false),
                testData.recurringPayables[0].clone(false, true, false, false),
                testData.recurringPayables[0].clone(false, true, false, false),
                testData.recurringPayables[0].clone(false, true, false, false)
            };

            // set ledgers
            recurringPayables[0].Ledger__c = testData.ledgers[6].Id;
            recurringPayables[1].Ledger__c = testData.ledgers[7].Id;
            recurringPayables[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            recurringPayables[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert recurringPayables;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(recurringPayables.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForRecurringPayableUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
           // clone new recurring payables
           List<Recurring_Account_Payable__c> recurringPayables = new List<Recurring_Account_Payable__c>{
                testData.recurringPayables[0].clone(false, true, false, false),
                testData.recurringPayables[0].clone(false, true, false, false),
                testData.recurringPayables[0].clone(false, true, false, false),
                testData.recurringPayables[0].clone(false, true, false, false)
            };

            insert recurringPayables;

            // set ledgers
            recurringPayables[0].Ledger__c = testData.ledgers[6].Id;
            recurringPayables[1].Ledger__c = testData.ledgers[7].Id;
            recurringPayables[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            recurringPayables[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update recurringPayables;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(recurringPayables.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForRecurringBillingInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createRecurringBilling();

        System.runAs(testData.users.get(1)) {
            // clone new recurring billing records
            List<Recurring_Billing__c> recurringBillings = new List<Recurring_Billing__c>{
                testData.recurringBillings[0].clone(false, true, false, false),
                testData.recurringBillings[0].clone(false, true, false, false),
                testData.recurringBillings[0].clone(false, true, false, false),
                testData.recurringBillings[0].clone(false, true, false, false)
            };

            // set ledger
            recurringBillings[0].Ledger__c = testData.ledgers[6].Id;
            recurringBillings[1].Ledger__c = testData.ledgers[7].Id;
            recurringBillings[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            recurringBillings[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;


            // test insert
            DmlException dmlEx;
            try {
                insert recurringBillings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(recurringBillings.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForRecurringBillingUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createRecurringBilling();

        System.runAs(testData.users.get(1)) {
            // clone new recurring billing records
            List<Recurring_Billing__c> recurringBillings = new List<Recurring_Billing__c>{
                testData.recurringBillings[0].clone(false, true, false, false),
                testData.recurringBillings[0].clone(false, true, false, false),
                testData.recurringBillings[0].clone(false, true, false, false),
                testData.recurringBillings[0].clone(false, true, false, false)
            };

            insert recurringBillings;

            // set ledger
            recurringBillings[0].Ledger__c = testData.ledgers[6].Id;
            recurringBillings[1].Ledger__c = testData.ledgers[7].Id;
            recurringBillings[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            recurringBillings[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;


            // test insert
            DmlException dmlEx;
            try {
                update recurringBillings;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(recurringBillings.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForScheduledRevenueExpenseInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createScheduledRevenueExpense();
         
        System.runAs(testData.users.get(1)) {
            // clone new scheduled revenue exp records
            List<Scheduled_Revenue_Expense__c> scheduledRevenues = new List<Scheduled_Revenue_Expense__c> {
                testData.scheduledRevenues[0].clone(false, true, false, false),
                testData.scheduledRevenues[0].clone(false, true, false, false),
                testData.scheduledRevenues[0].clone(false, true, false, false),
                testData.scheduledRevenues[0].clone(false, true, false, false)
            };

            // set ledgers
            scheduledRevenues[0].Ledger__c = testData.ledgers[6].Id;
            scheduledRevenues[1].Ledger__c = testData.ledgers[7].Id;
            scheduledRevenues[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            scheduledRevenues[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert scheduledRevenues;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(scheduledRevenues.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForScheduledRevenueExpenseUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createScheduledRevenueExpense();

        System.runAs(testData.users.get(1)) {
            // clone new scheduled revenue exp records
            List<Scheduled_Revenue_Expense__c> scheduledRevenues = new List<Scheduled_Revenue_Expense__c> {
                testData.scheduledRevenues[0].clone(false, true, false, false),
                testData.scheduledRevenues[0].clone(false, true, false, false),
                testData.scheduledRevenues[0].clone(false, true, false, false),
                testData.scheduledRevenues[0].clone(false, true, false, false)
            };

            insert scheduledRevenues;

            // set ledgers
            scheduledRevenues[0].Ledger__c = testData.ledgers[6].Id;
            scheduledRevenues[1].Ledger__c = testData.ledgers[7].Id;
            scheduledRevenues[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
                scheduledRevenues[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                update scheduledRevenues;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify errors
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(scheduledRevenues.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForTimeCardInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users.get(1)) {
            List<Time_Card_Period__c> timeCardPeriods = new List<Time_Card_Period__c>{
                new Time_Card_Period__c(
                    Name = '1991-12',
                    Start_Date__c = Date.newInstance(1991, 12, 1),
                    End_Date__c = Date.newInstance(1991, 12, 7),
                    Status__c = 'Open'
                ),
                new Time_Card_Period__c(
                    Name = '1992-01',
                    Start_Date__c = Date.newInstance(1992, 1, 1),
                    End_Date__c = Date.newInstance(1992, 1, 7),
                    Status__c = 'Open'
                ),
                new Time_Card_Period__c(
                    Name = '1992-02',
                    Start_Date__c = Date.newInstance(1992, 2, 1),
                    End_Date__c = Date.newInstance(1992, 2, 7),
                    Status__c = 'Open'
                ),
                new Time_Card_Period__c(
                    Name = '1992-03',
                    Start_Date__c = Date.newInstance(1992, 3, 1),
                    End_Date__c = Date.newInstance(1992, 3, 7),
                    Status__c = 'Open'
                )
            };

            insert timeCardPeriods;
            
            // clone time cards
            Time_Card__c timeCard0 = testData.timeCards[0].clone(false, true, false, false);
            Time_Card__c timeCard1 = testData.timeCards[0].clone(false, true, false, false);
            Time_Card__c timeCard2 = testData.timeCards[0].clone(false, true, false, false);
            Time_Card__c timeCard3 = testData.timeCards[0].clone(false, true, false, false);
            
            // set time card period
            timeCard0.Time_Card_Period__c = timeCardPeriods[0].Id;
            timeCard1.Time_Card_Period__c = timeCardPeriods[1].Id;
            timeCard2.Time_Card_Period__c = timeCardPeriods[2].Id;
            timeCard3.Time_Card_Period__c = timeCardPeriods[3].Id;

            // set ledger
            timeCard0.Ledger__c = testData.ledgers[5].Id;
            timeCard1.Ledger__c = testData.ledgers[4].Id;
            timeCard2.Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            timeCard3.Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            List<Time_Card__c> timeCards = new List<Time_Card__c>{
                timeCard0,
                timeCard1,
                timeCard2,
                timeCard3
            };

            // test insert
            DmlException dmlEx;
            try {
                insert timeCards;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify error
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(timeCards.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assert(dmlEx.getDmlMessage(i).contains(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForTimeCardUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users.get(1)) {
            List<Time_Card_Period__c> timeCardPeriods = new List<Time_Card_Period__c>{
                new Time_Card_Period__c(
                    Name = '1991-12',
                    Start_Date__c = Date.newInstance(1991, 12, 1),
                    End_Date__c = Date.newInstance(1991, 12, 7),
                    Status__c = 'Open'
                ),
                new Time_Card_Period__c(
                    Name = '1992-01',
                    Start_Date__c = Date.newInstance(1992, 1, 1),
                    End_Date__c = Date.newInstance(1992, 1, 7),
                    Status__c = 'Open'
                ),
                new Time_Card_Period__c(
                    Name = '1992-02',
                    Start_Date__c = Date.newInstance(1992, 2, 1),
                    End_Date__c = Date.newInstance(1992, 2, 7),
                    Status__c = 'Open'
                ),
                new Time_Card_Period__c(
                    Name = '1992-03',
                    Start_Date__c = Date.newInstance(1992, 3, 1),
                    End_Date__c = Date.newInstance(1992, 3, 7),
                    Status__c = 'Open'
                )
            };

            insert timeCardPeriods;

            // clone time cards
            Time_Card__c timeCard0 = testData.timeCards[0].clone(false, true, false, false);
            Time_Card__c timeCard1 = testData.timeCards[0].clone(false, true, false, false);
            Time_Card__c timeCard2 = testData.timeCards[0].clone(false, true, false, false);
            Time_Card__c timeCard3 = testData.timeCards[0].clone(false, true, false, false);
            
            // set time card period
            timeCard0.Time_Card_Period__c = timeCardPeriods[0].Id;
            timeCard1.Time_Card_Period__c = timeCardPeriods[1].Id;
            timeCard2.Time_Card_Period__c = timeCardPeriods[2].Id;
            timeCard3.Time_Card_Period__c = timeCardPeriods[3].Id;

            List<Time_Card__c> timeCards = new List<Time_Card__c>{
                timeCard0,
                timeCard1,
                timeCard2,
                timeCard3
            };

            insert timeCards;

            // set ledger
            timeCards[0].Ledger__c = testData.ledgers[6].Id;
            timeCards[1].Ledger__c = testData.ledgers[7].Id;
            timeCard2.Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            timeCard3.Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update timeCards;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify error
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(timeCards.size(), dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForJournalEntryInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            // clone new journal entry records
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>{
                testData.journalEntries[0].clone(false, true, false, false),
                testData.journalEntries[0].clone(false, true, false, false),
                testData.journalEntries[0].clone(false, true, false, false),
                testData.journalEntries[0].clone(false, true, false, false)
            };

            // set ledger
            journalEntries[0].Ledger__c = testData.ledgers[6].Id;
            journalEntries[1].Ledger__c = testData.ledgers[7].Id;
            journalEntries[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            journalEntries[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert journalEntries;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify error
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(3, dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForJournalEntryUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createProjects()
            .createProjectTasks()
            .createJournalEntries();

        System.runAs(testData.users.get(1)) {
            // clone new journal entry records
            List<Journal_Entry__c> journalEntries = new List<Journal_Entry__c>{
                testData.journalEntries[0].clone(false, true, false, false),
                testData.journalEntries[0].clone(false, true, false, false),
                testData.journalEntries[0].clone(false, true, false, false),
                testData.journalEntries[0].clone(false, true, false, false)
            };

            insert journalEntries;

            // set ledger
            journalEntries[0].Ledger__c = testData.ledgers[6].Id;
            journalEntries[1].Ledger__c = testData.ledgers[7].Id;
            journalEntries[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            journalEntries[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update journalEntries;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify error
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(3, dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForRecurringJournalEntryInsert() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createRecurringJournalEntry();

        System.runAs(testData.users.get(1)) {
            // clone new recurring journal entry records
            List<Recurring_Journal_Entry__c> recurringJournalEntries = new List<Recurring_Journal_Entry__c>{
                testData.recurringJournalEntries[0].clone(false, true, false, false),
                testData.recurringJournalEntries[0].clone(false, true, false, false),
                testData.recurringJournalEntries[0].clone(false, true, false, false),
                testData.recurringJournalEntries[0].clone(false, true, false, false)
            };

            // set ledger
            recurringJournalEntries[0].Ledger__c = testData.ledgers[6].Id;
            recurringJournalEntries[1].Ledger__c = testData.ledgers[7].Id;
            recurringJournalEntries[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
                recurringJournalEntries[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test insert
            DmlException dmlEx;
            try {
                insert recurringJournalEntries;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify error
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(3, dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

    @IsTest
    public static void testValidateLedgerTypeForRecurringJournalEntryUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createRecurringJournalEntry();

        System.runAs(testData.users.get(1)) {
            // clone new recurring journal entry records
            List<Recurring_Journal_Entry__c> recurringJournalEntries = new List<Recurring_Journal_Entry__c>{
                testData.recurringJournalEntries[0].clone(false, true, false, false),
                testData.recurringJournalEntries[0].clone(false, true, false, false),
                testData.recurringJournalEntries[0].clone(false, true, false, false),
                testData.recurringJournalEntries[0].clone(false, true, false, false)
            };

            insert recurringJournalEntries;

            // set ledger
            recurringJournalEntries[0].Ledger__c = testData.ledgers[6].Id;
            recurringJournalEntries[1].Ledger__c = testData.ledgers[7].Id;
            recurringJournalEntries[2].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_TRANSACTIONAL
                LIMIT 1].Id;
            recurringJournalEntries[3].Ledger__c = [
                SELECT Id 
                FROM Ledger__c 
                WHERE Type__c = :LedgerActions.LEDGER_TYPE_ELIMINATIONS_BUDGET
                LIMIT 1].Id;

            // test update
            DmlException dmlEx;
            try {
                update recurringJournalEntries;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            // verify error
            System.assertNotEquals(null, dmlEx);
            System.assertEquals(3, dmlEx.getNumDml());
            for (Integer i=0; i<dmlEx.getNumDml(); i++) {
                System.assertEquals(SObjectActions.LEDGER_TYPE_TRANSACTIONAL_AND_ELIMINATION_TRANSACTIONAL_ONLY_ERROR, dmlEx.getDmlMessage(i));
            }
        }
    }

}