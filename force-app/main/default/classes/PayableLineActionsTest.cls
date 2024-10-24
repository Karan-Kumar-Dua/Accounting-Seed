@IsTest
private class PayableLineActionsTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    // ==================APL Test=================================

    @isTest
    private static void testRequireAmountOrUnitCostInsertAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            Account_Payable_Line__c pl = testData.payableLines.get(0).clone();
            pl.Amount__c = NULL;
            pl.Unit_Cost__c = NULL;
            insert pl;
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        Test.stopTest();

        System.assertEquals(
            SObjectActions.REQUIRED_FIELD_ERROR,
            dmlEx.getDmlMessage(0)
        );
    }

    @isTest
    private static void testRequireAmountOrUnitCostUpdateAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            testData.payableLines.get(0).Amount__c = NULL;
            testData.payableLines.get(0).Unit_Cost__c = NULL;
            update testData.payableLines.get(0);
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        Test.stopTest();

        System.assertEquals(
            SObjectActions.REQUIRED_FIELD_ERROR,
            dmlEx.getDmlMessage(0)
        );
    }

    @isTest
    private static void testBothPopulatedAmountOrUnitCostInsertAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            Account_Payable_Line__c pl = new Account_Payable_Line__c(
                Account_Payable__c = testData.payables[0].Id,
                Date__c = testData.acctPeriods[0].Start_Date__c,
                Expense_GL_Account__c = testData.glAccounts[16].Id
            );
            pl.Amount__c = 33;
            pl.Unit_Cost__c = 44;
            insert pl;
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(
            PayableLineActions.MATH_DOSNT_WORK,
            dmlEx.getDmlMessage(0)
        );
    }

    @isTest
    private static void testBothPopulatedAmountOrUnitCostInsertCloneAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            Account_Payable_Line__c pl = testData.payableLines.get(0).clone();
            pl.Amount__c = 33;
            pl.Unit_Cost__c = 44;
            insert pl;
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        Test.stopTest();

        System.assertEquals(NULL, dmlEx);
    }

    @isTest
    private static void testQuantityPopulatedForPostedPayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables();

        testData.payables[0].Status__c = 'Posted';
        Account_Payable_Line__c pl = new Account_Payable_Line__c();
        pl.Account_Payable__c = testData.payables[0].Id;
        pl.Unit_Cost__c = 1;
        pl.Quantity__c = null;
        Map<Id, Account_Payable_Line__c> aplMap = new Map<Id, Account_Payable_Line__c>();
        aplMap.put(pl.Id,pl);

        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Account_Payable_Line__c>(), aplMap);
        System.assertEquals(null, pl.Quantity__c);
    }

    @isTest
    private static void testQuantityPopulatedForUnpostedPayable() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createPayables()
                .createGLAccountExpenses();

        Account_Payable_Line__c pl = new Account_Payable_Line__c();
        pl.Account_Payable__c = testData.payables[0].Id;
        pl.Unit_Cost__c = 1;
        pl.Quantity__c = null;
        pl.Expense_GL_Account__c = testData.glAccountsExpense[0].id;
        insert pl;

        System.assertEquals(1, [SELECT Id, Quantity__c FROM Account_Payable_Line__c WHERE Id =: pl.Id].Quantity__c);

    }


    @isTest
    private static void testBothPopulatedAmountOrUnitCostUpdateAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            testData.payableLines.get(0).Amount__c = 20;
            testData.payableLines.get(0).Unit_Cost__c = 10;
            update testData.payableLines.get(0);
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        Test.stopTest();

        System.assertEquals(
            PayableLineActions.MATH_DOSNT_WORK,
            dmlEx.getDmlMessage(0)
        );
    }

    @isTest
    private static void testSetAmountByUnitCostInsertAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c pl;
        DMLException dmlEx;
        try {
            pl = testData.payableLines.get(0).clone();
            pl.Amount__c = NULL;
            pl.Unit_Cost__c = 30;
            insert pl;
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(30, [SELECT Id, Amount__c FROM Account_Payable_Line__c WHERE Id = : pl.Id].Amount__c);
        System.assertEquals(1, [SELECT Id,Quantity__c FROM Account_Payable_Line__c WHERE Id = : pl.Id].Quantity__c);
    }

    @isTest
    private static void testSetAmountByUnitCostUpdateAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            testData.payableLines.get(0).Amount__c = NULL;
            testData.payableLines.get(0).Unit_Cost__c = 20;
            testData.payableLines.get(0).Quantity__c = 2;
            update testData.payableLines.get(0);
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(40, [SELECT Id, Amount__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Amount__c);
        System.assertEquals(2, [SELECT Id, Quantity__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Quantity__c);
    }

    @isTest
    private static void testSetAmountByUnitCostAndZeroQuantityInsertAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c pl;
        DMLException dmlEx;
        try {
            pl = testData.payableLines.get(0).clone();
            pl.Amount__c = NULL;
            pl.Unit_Cost__c = 30;
            pl.Quantity__c = 0;
            insert pl;
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(0, [SELECT Id, Amount__c FROM Account_Payable_Line__c WHERE Id = : pl.Id].Amount__c);
        System.assertEquals(0, [SELECT Id,Quantity__c FROM Account_Payable_Line__c WHERE Id = : pl.Id].Quantity__c);
    }

    @isTest
    private static void testSetAmountByUnitCostAndZeroQuantityUpdateAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            testData.payableLines.get(0).Amount__c = NULL;
            testData.payableLines.get(0).Unit_Cost__c = 20;
            testData.payableLines.get(0).Quantity__c = 0;
            update testData.payableLines.get(0);
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(0, [SELECT Id, Amount__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Amount__c);
        System.assertEquals(0, [SELECT Id, Quantity__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Quantity__c);
    }

    @isTest
    private static void testSetUnitCostByAmountInsertAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c pl;
        DMLException dmlEx;
        try {
            pl = testData.payableLines.get(0).clone();
            pl.Amount__c = 20;
            pl.Unit_Cost__c = NULL;
            insert pl;
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(20, [SELECT Id, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = : pl.Id].Unit_Cost__c);
        System.assertEquals(1, [SELECT Id,Quantity__c FROM Account_Payable_Line__c WHERE Id = : pl.Id].Quantity__c);
    }

    @isTest
    private static void testSetUnitCostByAmountUpdateAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            testData.payableLines.get(0).Amount__c = 40;
            testData.payableLines.get(0).Unit_Cost__c = NULL;
            testData.payableLines.get(0).Quantity__c = 2;
            update testData.payableLines.get(0);
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(20, [SELECT Id, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Unit_Cost__c);
        System.assertEquals(2, [SELECT Id, Quantity__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Quantity__c);
    }

    @isTest
    private static void testSetUnitCostByAmountUpdateUnitCostNotNullAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            testData.payableLines.get(0).Amount__c = 40;
            testData.payableLines.get(0).Quantity__c = 2;
            update testData.payableLines.get(0);
        } catch (DMLException ex) {
            dmlEx = ex;
        }

        System.assertEquals(20, [SELECT Id, Unit_Cost__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Unit_Cost__c);
        System.assertEquals(2, [SELECT Id, Quantity__c FROM Account_Payable_Line__c WHERE Id = : testData.payableLines.get(0).Id].Quantity__c);
    }

    @isTest
    private static void testAmountNotNullAndQuantity0ErrorInsertAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c pl;
        DMLException dmlEx;
        try {
            pl = testData.payableLines.get(0).clone();
            pl.Amount__c = 30;
            pl.Unit_Cost__c = NULL;
            pl.Quantity__c = 0;
            insert pl;
        } catch (DMLException ex) {
            dmlEx = ex;
        }
        System.assertEquals(PayableLineActions.TOTAL_FIELD_QUANTITY_0_ERROR, dmlEx.getDmlMessage(0));
    }

    @isTest
    private static void testAmountNotNullUnitCostNullAndQuantity0ErrorUpdateAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();

        DMLException dmlEx;
        try {
            testData.payableLines.get(0).Amount__c = 30;
            testData.payableLines.get(0).Unit_Cost__c = NULL;
            testData.payableLines.get(0).Quantity__c = 0;
            update testData.payableLines.get(0);
        } catch (DMLException ex) {
            dmlEx = ex;
        }
        System.assertEquals(PayableLineActions.TOTAL_FIELD_QUANTITY_0_ERROR, dmlEx.getDmlMessage(0));
    }

    @isTest
    private static void testLegacyUpdateAmountEmptyQuantityHLPAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c legacyAPLOld = testData.payableLines.get(0).clone(true, true);
        legacyAPLOld.Quantity__c = NULL;
        legacyAPLOld.Unit_Cost__c = NULL;
        Account_Payable_Line__c legacyAPLNew = testData.payableLines.get(0).clone(true, true);
        System.assertEquals(45, legacyAPLNew.Amount__c);
        legacyAPLNew.Quantity__c = NULL;
        legacyAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyAPLOld.Id => legacyAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Account_Payable_Line__c> {legacyAPLNew}, legacyMap);

        System.assertEquals(200, legacyAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyAPLNew.Amount__c);
        System.assertEquals(1, legacyAPLNew.Quantity__c);
    }

    @isTest
    private static void testLegacyUpdateAmountEmptyQuantityLLPAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c legacyAPLOld = testData.payableLines.get(0).clone(true, true);
        legacyAPLOld.Quantity__c = NULL;
        legacyAPLOld.Unit_Cost__c = NULL;
        Account_Payable_Line__c legacyAPLNew = testData.payableLines.get(0).clone(true, true);
        System.assertEquals(45, legacyAPLNew.Amount__c);
        legacyAPLNew.Quantity__c = NULL;
        legacyAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyAPLOld.Id => legacyAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Account_Payable_Line__c> {legacyAPLNew}, legacyMap);

        System.assertEquals(200, legacyAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyAPLNew.Amount__c);
        System.assertEquals(1, legacyAPLNew.Quantity__c);
    }

    @isTest
    private static void testLegacyUpdateAmountNonEmptyQuantityHLPAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c legacyAPLOld = testData.payableLines.get(0).clone(true, true);
        legacyAPLOld.Quantity__c = 1;
        legacyAPLOld.Unit_Cost__c = NULL;
        Account_Payable_Line__c legacyAPLNew = testData.payableLines.get(0).clone(true, true);
        System.assertEquals(45, legacyAPLNew.Amount__c);
        legacyAPLNew.Quantity__c = 1;
        legacyAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyAPLOld.Id => legacyAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Account_Payable_Line__c> {legacyAPLNew}, legacyMap);

        System.assertEquals(200, legacyAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyAPLNew.Amount__c);
        System.assertEquals(1, legacyAPLNew.Quantity__c);
    }

    @isTest
    private static void testLegacyUpdateAmountNonEmptyQuantityLLPAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().setLineLevelPost()
            .createPayables();

        Test.startTest();
        Account_Payable_Line__c legacyAPLOld = testData.payableLines.get(0).clone(true, true);
        legacyAPLOld.Quantity__c = 1;
        legacyAPLOld.Unit_Cost__c = NULL;
        Account_Payable_Line__c legacyAPLNew = testData.payableLines.get(0).clone(true, true);
        System.assertEquals(45, legacyAPLNew.Amount__c);
        legacyAPLNew.Quantity__c = 1;
        legacyAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyAPLOld.Id => legacyAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Account_Payable_Line__c> {legacyAPLNew}, legacyMap);

        System.assertEquals(200, legacyAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyAPLNew.Amount__c);
        System.assertEquals(1, legacyAPLNew.Quantity__c);
    }
    //======================RAPL Tests================================

    @IsTest
    public static void testRequiredAmountOrUnitCostInsertRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id
            );

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testRequiredAmountOrUnitCostUpdateRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = NULL;
            testData.recurringPayableLines[0].Unit_Cost__c = NULL;

            DmlException dmlEx;
            try {
                update testData.recurringPayableLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testBothPopulatedAmountOrUnitCostInsertRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Amount2__c = 23,
                Unit_Cost__c = 13
            );

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(PayableLineActions.MATH_DOSNT_WORK, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testBothPopulatedAmountOrUnitCostInsertCloneRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = testData.recurringPayableLines[0].clone();

            payableLine.Amount2__c = 22;
            payableLine.Unit_Cost__c = 33;

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(NULL, dmlEx);
        }
    }

    @IsTest
    public static void testBothPopulatedAmountOrUnitCostUpdateRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = 22;
            testData.recurringPayableLines[0].Unit_Cost__c = 33;

            DmlException dmlEx;
            try {
                update testData.recurringPayableLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(PayableLineActions.MATH_DOSNT_WORK, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testSetAmountByUnitCostInsertRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Unit_Cost__c = 20
            );

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(20, [SELECT Id, Amount2__c FROM Recurring_Account_Payable_Line__c WHERE Id = : payableLine.Id].Amount2__c);
            System.assertEquals(1, [SELECT Id, Quantity__c FROM Recurring_Account_Payable_Line__c WHERE Id = : payableLine.Id].Quantity__c);
        }
    }

    @IsTest
    public static void testSetAmountByUnitCostUpdateRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = NULL;
            testData.recurringPayableLines[0].Unit_Cost__c = 20;
            testData.recurringPayableLines[0].Quantity__c = 2;

            DmlException dmlEx;
            try {
                update testData.recurringPayableLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(40, [SELECT Id, Amount2__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Amount2__c);
            System.assertEquals(2, [SELECT Id, Quantity__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Quantity__c);
        }
    }

    @IsTest
    public static void testSetAmountByUnitCostAndZeroQuantityInsertRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Quantity__c = 0,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Unit_Cost__c = 20
            );

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(0, [SELECT Id, Amount2__c FROM Recurring_Account_Payable_Line__c WHERE Id = : payableLine.Id].Amount2__c);
            System.assertEquals(0, [SELECT Id, Quantity__c FROM Recurring_Account_Payable_Line__c WHERE Id = : payableLine.Id].Quantity__c);
        }
    }

    @IsTest
    public static void testSetAmountByUnitCostAndZeroQuantityUpdateRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = NULL;
            testData.recurringPayableLines[0].Unit_Cost__c = 20;
            testData.recurringPayableLines[0].Quantity__c = 0;

            DmlException dmlEx;
            try {
                update testData.recurringPayableLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(0, [SELECT Id, Amount2__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Amount2__c);
            System.assertEquals(0, [SELECT Id, Quantity__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Quantity__c);
        }
    }

    @IsTest
    public static void testSetUnitCostByAmountUpdateUnitCostNotNullRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = 40;
            testData.recurringPayableLines[0].Quantity__c = 2;

            DmlException dmlEx;
            try {
                update testData.recurringPayableLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(20, [SELECT Id, Unit_Cost__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Unit_Cost__c);
            System.assertEquals(2, [SELECT Id, Quantity__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Quantity__c);
        }
    }

    @IsTest
    public static void testSetUnitCostByAmountInsertRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Quantity__c = 1,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Amount2__c = 20
            );

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(20, [SELECT Id, Unit_Cost__c FROM Recurring_Account_Payable_Line__c WHERE Id = : payableLine.Id].Unit_Cost__c);
            System.assertEquals(1, [SELECT Id, Quantity__c FROM Recurring_Account_Payable_Line__c WHERE Id = : payableLine.Id].Quantity__c);
        }
    }

    @IsTest
    public static void testSetUnitCostByAmountUpdateRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = 40;
            testData.recurringPayableLines[0].Unit_Cost__c = NULL;
            testData.recurringPayableLines[0].Quantity__c = 2;

            DmlException dmlEx;
            try {
                update testData.recurringPayableLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(20, [SELECT Id, Unit_Cost__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Unit_Cost__c);
            System.assertEquals(2, [SELECT Id, Quantity__c FROM Recurring_Account_Payable_Line__c WHERE Id = : testData.recurringPayableLines[0].Id].Quantity__c);
        }
    }

    @IsTest
    public static void testAmountNotNullUnitCostNullAndQuantity0ErrorInsertRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables();
        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable_Line__c payableLine = new Recurring_Account_Payable_Line__c(
                Recurring_Account_Payable__c = testData.recurringPayables[0].Id,
                Quantity__c = 0,
                Expense_GL_Account__c = testData.glAccounts.get(11).Id,
                Amount2__c = 20
            );

            DmlException dmlEx;
            try {
                insert payableLine;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(PayableLineActions.TOTAL_FIELD_QUANTITY_0_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    public static void testAmountNotNullUnitCostNullAndQuantity0ErrorUpdateRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();
        System.runAs(testData.users.get(1)) {

            testData.recurringPayableLines[0].Amount2__c = 40;
            testData.recurringPayableLines[0].Unit_Cost__c = NULL;
            testData.recurringPayableLines[0].Quantity__c = 0;

            DmlException dmlEx;
            try {
                update testData.recurringPayableLines[0];
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }
            System.assertEquals(PayableLineActions.TOTAL_FIELD_QUANTITY_0_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @isTest
    private static void testLegacyUpdateAmountEmptyQuantityHLPRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        Test.startTest();
        Recurring_Account_Payable_Line__c legacyRAPLOld = testData.recurringPayableLines.get(0).clone(true, true);
        legacyRAPLOld.Quantity__c = NULL;
        legacyRAPLOld.Unit_Cost__c = NULL;
        Recurring_Account_Payable_Line__c legacyRAPLNew = testData.recurringPayableLines.get(0).clone(true, true);
        System.assertEquals(3446, legacyRAPLNew.Amount2__c);
        legacyRAPLNew.Quantity__c = NULL;
        legacyRAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyRAPLOld.Id => legacyRAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Recurring_Account_Payable_Line__c> {legacyRAPLNew}, legacyMap);

        System.assertEquals(200, legacyRAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyRAPLNew.Amount2__c);
        System.assertEquals(1, legacyRAPLNew.Quantity__c);
    }

    @isTest
    private static void testLegacyUpdateAmountEmptyQuantityLLPRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        Test.startTest();
        Recurring_Account_Payable_Line__c legacyRAPLOld = testData.recurringPayableLines.get(0).clone(true, true);
        legacyRAPLOld.Quantity__c = NULL;
        legacyRAPLOld.Unit_Cost__c = NULL;
        Recurring_Account_Payable_Line__c legacyRAPLNew = testData.recurringPayableLines.get(0).clone(true, true);
        System.assertEquals(3446, legacyRAPLNew.Amount2__c);
        legacyRAPLNew.Quantity__c = NULL;
        legacyRAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyRAPLOld.Id => legacyRAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Recurring_Account_Payable_Line__c> {legacyRAPLNew}, legacyMap);

        System.assertEquals(200, legacyRAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyRAPLNew.Amount2__c);
        System.assertEquals(1, legacyRAPLNew.Quantity__c);
    }

    @isTest
    private static void testLegacyUpdateAmountNonEmptyQuantityHLPRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        Test.startTest();
        Recurring_Account_Payable_Line__c legacyRAPLOld = testData.recurringPayableLines.get(0).clone(true, true);
        legacyRAPLOld.Quantity__c = 1;
        legacyRAPLOld.Unit_Cost__c = NULL;
        Recurring_Account_Payable_Line__c legacyRAPLNew = testData.recurringPayableLines.get(0).clone(true, true);
        System.assertEquals(3446, legacyRAPLNew.Amount2__c);
        legacyRAPLNew.Quantity__c = 1;
        legacyRAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyRAPLOld.Id => legacyRAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Recurring_Account_Payable_Line__c> {legacyRAPLNew}, legacyMap);

        System.assertEquals(200, legacyRAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyRAPLNew.Amount2__c);
        System.assertEquals(1, legacyRAPLNew.Quantity__c);
    }

    @isTest
    private static void testLegacyUpdateAmountNonEmptyQuantityLLPRAPL() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        Test.startTest();
        Recurring_Account_Payable_Line__c legacyRAPLOld = testData.recurringPayableLines.get(0).clone(true, true);
        legacyRAPLOld.Quantity__c = 1;
        legacyRAPLOld.Unit_Cost__c = NULL;
        Recurring_Account_Payable_Line__c legacyRAPLNew = testData.recurringPayableLines.get(0).clone(true, true);
        System.assertEquals(3446, legacyRAPLNew.Amount2__c);
        legacyRAPLNew.Quantity__c = 1;
        legacyRAPLNew.Unit_Cost__c = 200;

        Map<Id, SObject> legacyMap = new Map<Id, SObject> {legacyRAPLOld.Id => legacyRAPLOld};
        PayableLineActions.validateAndSetAmountAndUnitCostFields(new List<Recurring_Account_Payable_Line__c> {legacyRAPLNew}, legacyMap);

        System.assertEquals(200, legacyRAPLNew.Unit_Cost__c);
        System.assertEquals(200, legacyRAPLNew.Amount2__c);
        System.assertEquals(1, legacyRAPLNew.Quantity__c);
    }
}