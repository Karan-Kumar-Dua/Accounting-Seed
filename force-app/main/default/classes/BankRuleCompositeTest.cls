@IsTest
private class BankRuleCompositeTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testIsTheBankRuleApplicablePositive() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankTransactions()
            .createBankRules();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Transaction__c testBT =
                DomainUtils.getBankTransactionsById(new Set<Id>{testData.bankTransactions.get(0).Id}).get(0);
            testBT.Amount__c = testData.bankRuleConditions[0].Amount__c;
            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            update testBT;
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;

            Boolean isApplicableRuleFound = false;
            for (Bank_Rule__c br : DomainUtils.getBankRulesComposed('Cash_In', true)) {
                BankRuleComposite bankRuleComp = new BankRuleComposite(br);
                if (bankRuleComp.isApplicableFor(testBT)) {
                    isApplicableRuleFound = true;
                }
            }
            System.assertEquals(true, isApplicableRuleFound);
        }
    }

    @IsTest
    private static void testIsTheBankRuleApplicableNegative() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBankTransactions()
            .createBankRules();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Transaction__c testBT =
                DomainUtils.getBankTransactionsById(new Set<Id>{testData.bankTransactions.get(0).Id}).get(0);

            Boolean isApplicableRuleFound = false;
            for (Bank_Rule__c br : DomainUtils.getBankRulesComposed('Cash_In', true)) {
                BankRuleComposite bankRuleComp = new BankRuleComposite(br);
                if (bankRuleComp.isApplicableFor(testBT)) {
                    isApplicableRuleFound = true;
                }
            }
            System.assertEquals(false, isApplicableRuleFound);
        }
    }

    @IsTest
    private static void testTakeActionsFromApplicableBankRule() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createCashReceipts()
            .createBankTransactions()
            .createBankRules();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            Bank_Transaction__c testBT =
                DomainUtils.getBankTransactionsById(new Set<Id>{testData.bankTransactions.get(0).Id}).get(0);
            testBT.Amount__c = testData.bankRuleConditions[0].Amount__c;
            BankTransactionActions.isDmlRestrictionBypassEnabled = true;
            update testBT;
            BankTransactionActions.isDmlRestrictionBypassEnabled = false;

            Cash_Receipt__c testCashReceipt = testData.cashReceipts.get(0);

            Boolean isApplicableRuleFound = false;
            BankRuleComposite bankRuleComp;
            for (Bank_Rule__c br : DomainUtils.getBankRulesComposed('Cash_In', true)) {
                bankRuleComp = new BankRuleComposite(br);
                if (bankRuleComp.isApplicableFor(testBT)) {
                    isApplicableRuleFound = true;
                    bankRuleComp.takeActions(testCashReceipt, false);
                }
            }
            System.assertEquals(true, isApplicableRuleFound);
            System.assertEquals(testCashReceipt.Description__c, 'test test test');
        }
    }

    @IsTest
    private static void testCompareFieldValues() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            BankRuleComposite bankRuleComp = new BankRuleComposite(NULL, NULL, NULL, NULL);
            Boolean result = bankRuleComp.compareFieldValues('test', 'Contains', 'testtest', DisplayType.STRING);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues('test', 'Does_Not_Contain', 'xxx', DisplayType.STRING);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues('test', 'Does_Not_Equal', 'xxx', DisplayType.STRING);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues(10, 'Does_Not_Equal', 20, DisplayType.CURRENCY);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues(10, 'Equals', 10, DisplayType.CURRENCY);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues('test', 'Equals', 'test', DisplayType.STRING);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues('test', 'Equals', 'test', DisplayType.PICKLIST);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues(10, 'Greater_Than', 20, DisplayType.CURRENCY);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues(NULL, 'Is_Blank', NULL, DisplayType.STRING);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues(100, 'Less_Than', 10, DisplayType.CURRENCY);
            System.assertEquals(true, result);
            result = bankRuleComp.compareFieldValues('test', 'Starts_With', 'test string', DisplayType.STRING);
            System.assertEquals(true, result);
        }
    }

}