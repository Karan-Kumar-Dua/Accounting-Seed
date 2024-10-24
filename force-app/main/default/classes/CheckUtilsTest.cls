@IsTest
public with sharing class CheckUtilsTest {
    
    @IsTest
    private static void testToWordsNull() {
        String out = CheckUtils.toWords(null);
        System.assertEquals(null, out);
    }

    @IsTest
    private static void testToWordsZero() {
        String out = CheckUtils.toWords(0);
        System.assertEquals(Label.INF_WORDS_ZERO, out);
    }

    @IsTest
    private static void testToWordsNegNum() {
        String out = CheckUtils.toWords(-14.12);
        System.assertEquals(' ' + Label.INF_FOURTEEN_AND_12 + Label.INF_WORDS_DENOMINATOR, out);
    }

    @IsTest
    private static void testToWordsPosNum() {
        String out = CheckUtils.toWords(14.12);
        System.assertEquals(' ' + Label.INF_FOURTEEN_AND_12 + Label.INF_WORDS_DENOMINATOR, out);
    }

    @IsTest
    private static void testToWordsFractional() {
        String out = CheckUtils.toWords(0.03);
        System.assertEquals('03' + Label.INF_WORDS_DENOMINATOR, out);
    }

    @IsTest
    private static void testToWordsSmall() {
        String out = CheckUtils.toWords(1.48);
        System.assertEquals(' ' + Label.COMMON_ONE + ' ' + Label.COMMON_AND + ' 48' + Label.INF_WORDS_DENOMINATOR, out);
    }

    @IsTest
    private static void testToWordsLarge() {
        String out = CheckUtils.toWords(2742894.93);
        System.assertEquals(' ' + Label.INF_WORD_FORMAT_OF_A_NUMBER + Label.INF_WORDS_DENOMINATOR, out);
    }

    @IsTest
    private static void testGetNextCheckNumber() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createCashDisbursementBatches();
        System.runAs(testData.users.get(1)) {
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = 1000,
                Source__c = 'Payable',
                Bank_Account__c = testData.glAccounts[0].Id,
                Debit_GL_Account__c = testData.glAccounts[4].Id,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Reference__c = 'the reference 0',
                Check_Number__c = 1
            );
            insert testCD;

            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = -400,
                Payment_Reference__c = '0000000432',
                Receipt_Date__c = testData.acctPeriods.get(1).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Payment_Type__c = 'Check',
                Check_Number__c = 2
            );
            insert testCR;

            Test.startTest();

            Decimal nextCheckNmb = CheckUtils.getNextCheckNumber(testData.glAccounts.get(0).Id);
            System.assertEquals(3, nextCheckNmb);
        }
    }

    @IsTest
    private static void testGetNextCheckNumberforCR() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createCashDisbursementBatches();
        System.runAs(testData.users.get(1)) {
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = 1000,
                Source__c = 'Payable',
                Bank_Account__c = testData.glAccounts[0].Id,
                Debit_GL_Account__c = testData.glAccounts[4].Id,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Reference__c = 'the reference 0',
                Check_Number__c = 1
            );
            insert testCD;
            List<Cash_Receipt__c> testCRs = new List<Cash_Receipt__c>();
            Test.startTest();
            for(Integer i = 1; i<= 150; i++){
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = -400,
                Payment_Reference__c = '0000000432',
                Receipt_Date__c = testData.acctPeriods.get(1).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Payment_Type__c = 'Check',
                Check_Number__c = i
            );
                testCRs.add(testCR);
            }
            insert testCRs;
            Test.stopTest();

            
            Decimal nextCheckNmb = CheckUtils.getNextCheckNumber(testData.glAccounts.get(0).Id);
            System.assertEquals(151, nextCheckNmb);
        }
    }
    
    @IsTest
    private static void testGetNextCheckNumberforCD() {
        TestDataSuite testData = TestDataSuite.getInstance(true).createCashDisbursementBatches();
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<Cash_Disbursement__c> testCDs = new List<Cash_Disbursement__c>();
            for(Integer i = 1; i<= 200; i++){
            Cash_Disbursement__c testCD = new Cash_Disbursement__c(
                Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
                Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
                Type__c = 'Check',
                Amount__c = 1000,
                Source__c = 'Payable',
                Bank_Account__c = testData.glAccounts[0].Id,
                Debit_GL_Account__c = testData.glAccounts[4].Id,
                Vendor__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Reference__c = 'the reference 0',
                Check_Number__c = i
            );
                testCDs.add(testCD);
            }
            insert testCDs;
            
            
            Cash_Receipt__c testCR = new Cash_Receipt__c(
                Account__c = testData.accounts.get(0).Id,
                Amount__c = -400,
                Payment_Reference__c = '0000000432',
                Receipt_Date__c = testData.acctPeriods.get(1).Start_Date__c,
                Accounting_Period__c = testData.acctPeriods.get(1).Id,
                Purpose__c = 'Customer Receipt',
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Credit_GL_Account__c = testData.glAccounts.get(1).Id,
                Payment_Type__c = 'Check',
                Check_Number__c = 2
            );
                
            insert testCR;
            Test.stopTest();

            
            Decimal nextCheckNmb = CheckUtils.getNextCheckNumber(testData.glAccounts.get(0).Id);
            System.assertEquals(201, nextCheckNmb);
        }
    }

}