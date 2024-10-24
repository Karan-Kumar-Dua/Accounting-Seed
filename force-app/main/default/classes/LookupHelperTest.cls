@IsTest
private class LookupHelperTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    private static String getSearchOptionsJosn(
            String searchTerm, 
            String searchGroup, 
            String searchObject, 
            String searchDisplayField, 
            Integer searchLimit) {

        return JSON.serialize(new Map<String,Object>{
            'searchTerm'         => searchTerm,
            'searchGroup'        => searchGroup,
            'searchObject'       => searchObject,
            'searchDisplayField' => searchDisplayField,
            'searchLimit'        => searchLimit
        });
    }

    private static String getFilterJson(String field, String op, Object val, string type) {
        return JSON.serialize(new Map<String,Object>{
            'field' => field,
            'op'    => op,
            'val'   => val,
            'type'  => type
        });
    }

    @IsTest static void search_nullOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Exception expectedEx;
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search(null, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }
        System.assertNotEquals(null, expectedEx);
    }

    @IsTest static void search_blankOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Exception expectedEx;
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search('', null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }
        System.assertNotEquals(null, expectedEx);
    }

    @IsTest static void search_emptyOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Exception expectedEx;
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search('{}', null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }
        System.assertNotEquals(null, expectedEx);
    }

    @IsTest static void search_invalidOptions() {
        TestDataSuite testData = TestDataSuite.getInstance();
        Exception expectedEx;
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search('{"fake":5}', null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
        }
        System.assertNotEquals(null, expectedEx);
    }

    @IsTest static void search_optsMissingSearchObject() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            String opts = getSearchOptionsJosn('term', 'NAME', null, 'Name', 5);

            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }
    @IsTest static void search_optsInvalidSearchObject() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            String opts = getSearchOptionsJosn('term', 'NAME', 'Not_Real_Obj__c', 'Name', 5);

            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest static void search_optsMissingSearchTerm() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            String opts = getSearchOptionsJosn(null, 'NAME', 'Account', 'Name', 5);

            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, null);
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest static void search_nullFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String opts = getSearchOptionsJosn('test', 'NAME', 'Account', 'Name', 5);

            Test.startTest();
            List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, null);
            Test.stopTest();
            System.assertEquals(0, response.size());
        }
    }

    @IsTest static void search_blankFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String opts = getSearchOptionsJosn('test', 'NAME', 'Account', 'Name', 5);

            Test.startTest();
            List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, '');
            Test.stopTest();
            System.assertEquals(0, response.size());
        }
    }

    @IsTest static void search_emptyFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String opts = getSearchOptionsJosn('test', 'NAME', 'Account', 'Name', 5);

            Test.startTest();
            List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, '{}');
            Test.stopTest();
            System.assertEquals(0, response.size());
        }
    }

    @IsTest static void search_invalidFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Exception expectedEx;
            String opts = getSearchOptionsJosn('test', 'NAME', 'Account', 'Name', 5);

            Test.startTest();
            try {
                List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, '{"x":5}');
            } catch (AuraHandledException ex) {
                expectedEx = ex;
            }
            Test.stopTest();
            System.assertNotEquals(null, expectedEx);
        }
    }

    @IsTest static void search_searchLimit() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Integer searchLimit = 2;
            String opts = getSearchOptionsJosn('Accou', 'NAME', 'Account', 'Name', searchLimit);

            Id [] fixedSearchResults= new Id[3];
            fixedSearchResults[0] = testData.accounts.get(0).Id;    // Name: Test Account
            fixedSearchResults[1] = testData.accounts.get(1).Id;    // Name: Acme Account
            fixedSearchResults[2] = testData.accounts.get(2).Id;    // Name: Accounting Seed
            Test.setFixedSearchResults(fixedSearchResults);

            Test.startTest();
            List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, null);
            Test.stopTest();

            System.assertEquals(searchLimit, response.size());
        }
    }

    @IsTest static void search_filtered() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String opts = getSearchOptionsJosn('Doe', 'NAME', 'Contact', 'FirstName', 5);
            String filter = getFilterJson('FirstName', '=', 'John', 'string');

            Id [] fixedSearchResults= new Id[3];
            fixedSearchResults[0] = testData.contacts.get(0).Id;    // Name: John Doe
            fixedSearchResults[1] = testData.contacts.get(1).Id;    // Name: Jane Doe
            fixedSearchResults[2] = testData.contacts.get(2).Id;    // Name: Mike Black
            Test.setFixedSearchResults(fixedSearchResults);

            Test.startTest();
            List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, filter);
            Test.stopTest();

            System.assertEquals(1, response.size());
            System.assertEquals('Contact', response.get(0).getLabel());
            System.assertEquals(false, String.isBlank(response.get(0).getIcon()));
            Contact obj = (Contact) response.get(0).getObj();
            System.assertEquals('John', obj.FirstName);
        }
    }

    @IsTest static void search_customIcon() {
        TestDataSuite testData = TestDataSuite.getInstance();
        String opts = getSearchOptionsJosn('1991', 'ALL', GlobalVariables.PACKAGE_QUALIFIER + 'Accounting_Period__c', 'Name', 5);

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = testData.acctPeriods.get(0).Id;
        Test.setFixedSearchResults(fixedSearchResults);
        
        System.runAs(testData.users.get(1)) {
            Test.startTest();
            List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, null);
            Test.stopTest();

            System.assertEquals(false, String.isBlank(response.get(0).getIcon()));
        }
    }

    @IsTest static void search_dateFilter() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Date today = Date.today();
            Account testAccount0 = testData.accounts.get(0);
            Account testAccount1 = testData.accounts.get(1);
            testAccount0.Last_Statement_Sent__c = today.addDays(-10);
            testAccount1.Last_Statement_Sent__c = today;
            List<Account> testAccounts = new List<Account>{ testAccount0, testAccount1 };
            update testAccounts;

            String opts = getSearchOptionsJosn('Accou', 'ALL', 'Account', 'Name', 5);
            String filter = getFilterJson(GlobalVariables.PACKAGE_QUALIFIER + 'Last_Statement_Sent__c', '>', today.addDays(-5), 'date');

            Id [] fixedSearchResults= new Id[2];
            fixedSearchResults[0] = testAccount0.Id;
            fixedSearchResults[1] = testAccount1.Id;
            Test.setFixedSearchResults(fixedSearchResults);
            Test.startTest();
            List<LookupHelper.LookupSearchResult> response = LookupHelper.search(opts, filter);
            Test.stopTest();

            System.assertEquals(1, response.size());
            Account obj = (Account) response.get(0).getObj();
            System.assertEquals('Acme Account', obj.Name);
        }
    }

    @IsTest static void testGetSObjectValue() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users.get(1)) {
            LookupHelper.LookupSearchResult response = LookupHelper.getSObjectValue(GlobalVariables.PACKAGE_QUALIFIER + 'Billing__c', testData.billings[0].Id);

            Billing__c bill = [SELECT Name FROM Billing__c WHERE Id = :testData.billings[0].Id];
            System.assertEquals('Billing', response.getLabel());
            System.assertEquals(false, String.isBlank(response.getIcon()));
            System.assertEquals(bill.Name, response.getObj().get('Name'));
        }
    }

}