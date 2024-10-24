@IsTest
public with sharing class FinancialSuiteUtilsTest {
    
    @TestSetup
    private static void setupTestData(){
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testGetNextRecurringDateWeekly() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date initialDate = Date.newInstance(2022, 1, 1);
            Date expectedDate = Date.newInstance(2022, 1, 8);
            Date result = FinancialSuiteUtils.getNextRecurringDate(initialDate, 'Weekly');
            Assert.areEqual(expectedDate, result);
        }
    }

    @IsTest
    public static void testGetNextRecurringDateBiWeekly() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date initialDate = Date.newInstance(2022, 1, 1);
            Date expectedDate = Date.newInstance(2022, 1, 15);
            Date result = FinancialSuiteUtils.getNextRecurringDate(initialDate, 'Bi-Weekly');
            Assert.areEqual(expectedDate, result);
        }
    }

    @IsTest
    public static void testGetNextRecurringDateMonthly() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date initialDate = Date.newInstance(2022, 1, 1);
            Date expectedDate = Date.newInstance(2022, 2, 1);
            Date result = FinancialSuiteUtils.getNextRecurringDate(initialDate, 'Monthly');
            Assert.areEqual(expectedDate, result);
        }
    }

    @IsTest
    public static void testGetNextRecurringDateQuarterly() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date initialDate = Date.newInstance(2022, 1, 1);
            Date expectedDate = Date.newInstance(2022, 4, 1);
            Date result = FinancialSuiteUtils.getNextRecurringDate(initialDate, 'Quarterly');
            Assert.areEqual(expectedDate, result);
        }
    }

    @IsTest
    public static void testGetNextRecurringDateSemiAnually() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date initialDate = Date.newInstance(2022, 1, 1);
            Date expectedDate = Date.newInstance(2022, 7, 1);
            Date result = FinancialSuiteUtils.getNextRecurringDate(initialDate, 'Semi-Annual');
            Assert.areEqual(expectedDate, result);
        }
    }

    @IsTest
    public static void testGetNextRecurringDateAnually() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date initialDate = Date.newInstance(2022, 1, 1);
            Date expectedDate = Date.newInstance(2023, 1, 1);
            Date result = FinancialSuiteUtils.getNextRecurringDate(initialDate, 'annual');
            Assert.areEqual(expectedDate, result);
        }
    }

    @IsTest
    public static void testGetNextRecurringDateDefault() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Date initialDate = Date.newInstance(2022, 1, 1);
            Date expectedDate = Date.newInstance(2022, 2, 1);
            Date result = FinancialSuiteUtils.getNextRecurringDate(initialDate, 'nonexistentfrequency');
            Assert.areEqual(expectedDate, result);
        }
    }

    @IsTest
    public static void testPunctuate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            String input;
            
            input = 'This is a test';          
            Assert.areEqual(input + '.', FinancialSuiteUtils.punctuate(input));

            input = 'This is a test 123';          
            Assert.areEqual(input + '.', FinancialSuiteUtils.punctuate(input));
            
            input = 'This is a test '; // the space indicates this is part of a larger sentence.
            Assert.areEqual(input, FinancialSuiteUtils.punctuate(input));

            input = 'This is a (test)';          
            Assert.areEqual(input + '.', FinancialSuiteUtils.punctuate(input));

            input = 'This is a <test>';          
            Assert.areEqual(input + '.', FinancialSuiteUtils.punctuate(input));

            input = 'This is a \'test\'';          
            Assert.areEqual(input + '.', FinancialSuiteUtils.punctuate(input));

            input = 'This is a "test"';          
            Assert.areEqual(input + '.', FinancialSuiteUtils.punctuate(input));

            input = 'This is a test.';
            Assert.areEqual(input, FinancialSuiteUtils.punctuate(input));

            input = 'This is a test?';
            Assert.areEqual(input, FinancialSuiteUtils.punctuate(input));

            input = 'This is a test -';
            Assert.areEqual(input, FinancialSuiteUtils.punctuate(input));

            input = 'This is a test ,';
            Assert.areEqual(input, FinancialSuiteUtils.punctuate(input));

            input = 'This is a test ;';
            Assert.areEqual(input, FinancialSuiteUtils.punctuate(input));
        }
    }
    
}