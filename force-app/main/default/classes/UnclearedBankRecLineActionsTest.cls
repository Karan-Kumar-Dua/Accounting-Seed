@IsTest
private class UnclearedBankRecLineActionsTest {

    @TestSetup
    private static void testDataSetup() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testPreventInsert() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'Cash Receipt',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                insert ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.INSERT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventInsertBankDisb() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDisbursements();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'Bank Disbursement',
                Bank_Disbursement__c = testData.bankDisbursements.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.PAYMENT_TYPE
            );

            DmlException dmlEx;
            try {
                insert ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.INSERT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventDelete() {
        TestDataSuite testData = TestDataSuite.getInstance().createCashReceipts();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'Cash Receipt',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                delete ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventDeleteBankDisb() {
        TestDataSuite testData = TestDataSuite.getInstance().createBankDisbursements();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'Bank Disbursement',
                Bank_Disbursement__c = testData.bankDisbursements.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.PAYMENT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                delete ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.DELETE_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testNoSourceDocPopulated() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'some text',
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.ONE_SOURCE_DOCUMENT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testMoreThanOneSourceDocPopulated() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'some text',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Bank_Deposit__c = testData.bankDeposits.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.ONE_SOURCE_DOCUMENT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'some text',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
            //Update without bypass
            try {
                ubrecLine.Amount__c = ubrecLine.Amount__c + 100;
                update ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            SourceDocumentUpdateFieldValidator sfu = new UnclearedBankRecLineFieldUpdateValidator();
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}
                ),
                dmlEx.getDmlMessage(0)
            );

            //Update with bypass
            dmlEx = NULL;
            try {
                ubrecLine.Amount__c = ubrecLine.Amount__c + 100;
                TriggerObserver.getInstance().unlockField(Uncleared_Bank_Reconciliation_Line__c.Amount__c);
                update ubrecLine;
                TriggerObserver.purgeUnlockedFields(Uncleared_Bank_Reconciliation_Line__c.Amount__c);
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    static void testMoreThanOneSourceDocPopulatedAfterUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'some text',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                ubrecLine.Bank_Deposit__c = testData.bankDeposits.get(0).Id;
                TriggerObserver.getInstance().unlockField(Uncleared_Bank_Reconciliation_Line__c.Bank_Deposit__c);
                update ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.ONE_SOURCE_DOCUMENT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testNoSourceDocPopulatedAfterUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'some text',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);

            try {
                ubrecLine.Cash_Receipt__c = NULL;
                TriggerObserver.getInstance().unlockField(Uncleared_Bank_Reconciliation_Line__c.Cash_Receipt__c);
                update ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            System.assertEquals(UnclearedBankReconciliationLineActions.ONE_SOURCE_DOCUMENT_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testPreventUpdateSourceDocumentField() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankDeposits();

        System.runAs(testData.users.get(1)) {
            //Create Bank Reconciliation record
            Bank_Reconciliation2__c bankRec = new Bank_Reconciliation2__c(
                Bank_Account__c = testData.glAccounts.get(0).Id,
                Beginning_Balance__c = 0,
                Ending_Balance__c = 1000,
                End_Date__c = testData.acctPeriods.get(0).End_Date__c,
                Type__c = BankReconciliation.BANK_TYPE
            );
            insert bankRec;
            //Create Uncleared Bank Reconciliation Line record
            Uncleared_Bank_Reconciliation_Line__c ubrecLine = new Uncleared_Bank_Reconciliation_Line__c(
                Bank_Reconciliation__c = bankRec.Id,
                Amount__c = 100,
                Related_Source_Document__c = 'some text',
                Cash_Receipt__c = testData.cashReceipts.get(0).Id,
                Date__c = Date.today(),
                Type__c = BankReconciliation.DEPOSIT_TYPE
            );

            DmlException dmlEx;
            try {
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
                insert ubrecLine;
                UnclearedBankReconciliationLineActions.isPreventInsertOverride = true;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
            //Update without bypass
            try {
                ubrecLine.Related_Source_Document__c = 'new some text';
                update ubrecLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertNotEquals(NULL, dmlEx);
            SourceDocumentUpdateFieldValidator sfu = new UnclearedBankRecLineFieldUpdateValidator();
            System.assertEquals(
                String.format(
                    SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
                    new List<String>{sfu.formatFieldStrings(sfu.lockedUpdateFields)}
                ),
                dmlEx.getDmlMessage(0)
            );
        }
    }

}