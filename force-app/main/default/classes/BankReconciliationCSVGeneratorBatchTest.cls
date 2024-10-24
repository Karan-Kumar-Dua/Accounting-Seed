@IsTest
private class BankReconciliationCSVGeneratorBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testGenerateRecordString() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;
            List<SObject> bw = BankReconciliation.retrieve(bankRec.Id, true, true).items;

            BankReconciliationCSVGeneratorBatch generator = new BankReconciliationCSVGeneratorBatch(bankRec.Id);
            generator.execute(null, bw);

            List<String> result = generator.body.split('\n');

            System.assertEquals(generator.header, result[0]);
            System.assertEquals(bw.size(), result.size()-1);
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetDataByObjectType() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createCashReceipts()
            .createBankDeposits()
            .createProjects()
            .createProjectTasks();
        Test.startTest();
        testData.createJournalEntries(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            String isoCode = UserInfo.getDefaultCurrency();
            Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
            bankRec.End_Date__c = System.today().addDays(30);
            insert bankRec;

            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'Cash Receipt',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Date__c = Date.newInstance(1991, 8, 1),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            insert ubrecLine;
            UnclearedBankReconciliationLineActions.isPreventInsertOverride = false;

            BankReconciliationCSVGeneratorBatch generator = new BankReconciliationCSVGeneratorBatch(bankRec.Id);
            String date1 = Date.newInstance(1991, 10, 1).format();
            String date2 = Date.newInstance(1991, 11, 1).format();
            String date3 = Date.newInstance(1991, 8, 1).format();

            String cdExpected = date1 + ',,' + isoCode + ',' + generator.getFormattedAmountVal(0) + ',,Payment,the reference 0,,';
            String cdResult = generator.getDataByObjectType(testData.cashDisbursements[0]);
            System.assertEquals(cdExpected, cdResult);

            String crExpected = date2 + ',,' + isoCode + ',' + generator.getFormattedAmountVal(400) + ',,Deposit,0000000432,,';
            String crResult = generator.getDataByObjectType(testData.cashReceipts[0]);
            System.assertEquals(crExpected, crResult);

            String bdExpected = date2 + ',,' + isoCode + ',,,Deposit,the reference 1,,';
            String bdResult = generator.getDataByObjectType(testData.bankDeposits[0]);
            System.assertEquals(bdExpected, bdResult);

            String jelExpected = ',,' + isoCode + ',,,Payment,the reference 1,,the description 1';
            String jelResult = generator.getDataByObjectType(testData.journalEntryLines[0]);
            System.assertEquals(jelExpected, jelResult);

            String ublExpected = date3 + ',,' + isoCode + ',' + generator.getFormattedAmountVal(100) + ',,Deposit,,,';
            String ublResult = generator.getDataByObjectType(ubrecLine);
            System.assertEquals(ublExpected, ublResult);
        }
    }
    

    @IsTest
    static void testShowTableHeaderWithoutLedgerAmount_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashReceipts()
                .createBankReconciliations();

            System.runAs(testData.users.get(1)) {
                String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrency)) {
                    return;
                }

                Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
                bankRec.put('CurrencyIsoCode', newCurrency);
                insert bankRec;

                Test.startTest();
                BankReconciliationCSVGeneratorBatch generator = new BankReconciliationCSVGeneratorBatch(bankRec.Id);

                String expected = Label.BANK_REC_CSV_HEADER;
                System.assertEquals(expected, generator.header);

            }

        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    static void testShowTableHeaderWithLedgerAmount_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createCashReceipts()
                .createBankReconciliations();

            System.runAs(testData.users.get(1)) {
                Bank_Reconciliation2__c bankRec = testData.bankReconciliations[0].clone();
                bankRec.End_Date__c = System.today().addDays(30);
                insert bankRec;

                Test.startTest();
                BankReconciliationCSVGeneratorBatch generator = new BankReconciliationCSVGeneratorBatch(bankRec.Id);

                String expected = Label.BANK_REC_CSV_HEADER;
                System.assertEquals(expected, generator.header);

            }

        } catch (TestDataSuite.TestDataSuiteException ex) {
            //just skip this test if it is non-MC org
        }
    }

    @IsTest
    static void testGetCashDisbursementData() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashDisbursementBatches()
            .createCashDisbursements(true)
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            BankReconciliationCSVGeneratorBatch generator = new BankReconciliationCSVGeneratorBatch(testData.bankReconciliations[0].Id);
            Cash_Disbursement__c cd = testData.cashDisbursements[0];
            
            // reference and check number
            cd.Check_Number__c = 123;
            cd.Reference__c = 'reference';
            String line = generator.getCashDisbursementData(cd);  
            System.assertEquals(cd.Check_Number__c + ' - ' + cd.Reference__c, line.replaceAll(',', ', ').split(',')[6].trim());

            // check number
            cd.Check_Number__c = 123;
            cd.Reference__c = null;
            line = generator.getCashDisbursementData(cd);  
            System.assertEquals(String.valueOf(cd.Check_Number__c), line.replaceAll(',', ', ').split(',')[6].trim());

            // reference
            cd.Check_Number__c = null;
            cd.Reference__c = 'reference';
            line = generator.getCashDisbursementData(cd);  
            System.assertEquals(cd.Reference__c, line.replaceAll(',', ', ').split(',')[6].trim());

            // none
            cd.Check_Number__c = null;
            cd.Reference__c = null;
            line = generator.getCashDisbursementData(cd);    
            System.assertEquals('', line.replaceAll(',', ', ').split(',')[6].trim());
        }
    }

    @IsTest
    static void testGetCashReceiptData() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankReconciliations();

        System.runAs(testData.users.get(1)) {
            BankReconciliationCSVGeneratorBatch generator = new BankReconciliationCSVGeneratorBatch(testData.bankReconciliations[0].Id);
            Cash_Receipt__c cr = testData.cashReceipts[0];
            
            // reference and check number
            cr.Check_Number__c = 123;
            cr.Payment_Reference__c = 'reference';
            String line = generator.getCashReceiptData(cr);  
            System.assertEquals(cr.Check_Number__c + ' - ' + cr.Payment_Reference__c, line.replaceAll(',', ', ').split(',')[6].trim());

            // reference
            cr.Check_Number__c = null;
            cr.Payment_Reference__c = 'reference';
            line = generator.getCashReceiptData(cr);  
            System.assertEquals(cr.Payment_Reference__c, line.replaceAll(',', ', ').split(',')[6].trim());
        }
    }
}