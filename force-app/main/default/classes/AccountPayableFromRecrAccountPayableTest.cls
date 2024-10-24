@IsTest
private class AccountPayableFromRecrAccountPayableTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testCreateAccountPayableFromRecrAccountPayableIsInactiveError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Status__c = 'Inactive';
            update testData.recurringPayables.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringPayables.get(0));
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);

            Test.stopTest();

            System.assertEquals(true, ara.isInActiveError);
        }
    }

    @IsTest
    private static void testCreatePayableFromRecurringPayableWithContact() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createContacts();

            Recurring_Account_Payable__c recurringAccountPayable = new Recurring_Account_Payable__c(
                    Name = 'Test Recurring Payable 1',
                    Contact__c = [SELECT Id FROM Contact LIMIT 1].Id,
                    Next_Account_Payable_Date__c = Date.newInstance(1991, 12, 31),
                    Account_Payable_Frequency__c = 'Monthly',
                    Status__c = 'Active');
            insert recurringAccountPayable;

            System.runAs(testData.users.get(1)) {
                Test.startTest();
                testData.disableLDVMode();

                ApexPages.StandardController controller = new ApexPages.StandardController(recurringAccountPayable);
                AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);
                ara.createPayable();

                Test.stopTest();

            System.assert([
                    SELECT Id, Contact__c, Recurring_Account_Payable__c
                    FROM Account_Payable__c
                    WHERE Recurring_Account_Payable__c=:recurringAccountPayable.Id
            ]!=null);
        }
    }

    @IsTest
    private static void testCreatePayableFromRecurringPayableWithUser() {
        TestDataSuite testData = TestDataSuite.getInstance();

        Recurring_Account_Payable__c recurringAccountPayable = new Recurring_Account_Payable__c(
                Name = 'Test Recurring Payable 1',
                Employee__c = TestDataSuite.createTestUser().Id,
                Next_Account_Payable_Date__c = Date.newInstance(1991, 12, 31),
                Account_Payable_Frequency__c = 'Monthly',
                Status__c = 'Active');
        insert recurringAccountPayable;

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(recurringAccountPayable);
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);
            ara.createPayable();

            Test.stopTest();

            System.assert([
                    SELECT Id, Recurring_Account_Payable__c
                    FROM Account_Payable__c
                    WHERE Recurring_Account_Payable__c=:recurringAccountPayable.Id
            ]!=null);
        }
    }

    @IsTest
    private static void testCreateAccountPayableFromRecrAccountPayableMonthlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Account_Payable_Frequency__c= 'Monthly';
            update testData.recurringPayables.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringPayables.get(0));
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);
            ara.createPayable();

            Test.stopTest();

            Recurring_Account_Payable__c validatedTestRecurringAccountPayable = [
                SELECT Last_Account_Payable_Date__c, Next_Account_Payable_Date__c
                FROM Recurring_Account_Payable__c
                WHERE Id = :testData.recurringPayables.get(0).Id
            ];

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c,
                validatedTestRecurringAccountPayable.Last_Account_Payable_Date__c
            );

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c.addMonths(1),
                validatedTestRecurringAccountPayable.Next_Account_Payable_Date__c
            );
        }
    }

    @IsTest
    private static void testCreateAccountPayableFromRecrAccountPayableQuarterlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Account_Payable_Frequency__c= 'Quarterly';
            update testData.recurringPayables.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringPayables.get(0));
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);
            ara.createPayable();

            Test.stopTest();

            Recurring_Account_Payable__c validatedTestRecurringAccountPayable = [
                SELECT Last_Account_Payable_Date__c, Next_Account_Payable_Date__c
                FROM Recurring_Account_Payable__c
                WHERE Id = :testData.recurringPayables.get(0).Id
            ];

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c,
                validatedTestRecurringAccountPayable.Last_Account_Payable_Date__c
            );

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c.addMonths(3),
                validatedTestRecurringAccountPayable.Next_Account_Payable_Date__c
            );
        }
    }

    @IsTest
    private static void testCreatePayableFromRecurringPayableSemiAnnualSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Account_Payable_Frequency__c= 'Semi-annual';
            update testData.recurringPayables.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringPayables.get(0));
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);
            ara.createPayable();

            Test.stopTest();

            Recurring_Account_Payable__c validatedTestRecurringAccountPayable = [
                SELECT Last_Account_Payable_Date__c, Next_Account_Payable_Date__c
                FROM Recurring_Account_Payable__c
                WHERE Id = :testData.recurringPayables.get(0).Id
            ];

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c,
                validatedTestRecurringAccountPayable.Last_Account_Payable_Date__c
            );

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c.addMonths(6),
                validatedTestRecurringAccountPayable.Next_Account_Payable_Date__c
            );
        }
    }

    @IsTest
    private static void testCreateAccountPayableFromRecrAccountPayableAnnualSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Account_Payable_Frequency__c = 'Annual';
            update testData.recurringPayables.get(0);

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringPayables.get(0));
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);
            ara.createPayable();

            Test.stopTest();

            Recurring_Account_Payable__c validatedTestRecurringAccountPayable = [
                SELECT Last_Account_Payable_Date__c, Next_Account_Payable_Date__c
                FROM Recurring_Account_Payable__c
                WHERE Id = :testData.recurringPayables.get(0).Id
            ];

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c,
                validatedTestRecurringAccountPayable.Last_Account_Payable_Date__c
            );

            System.assertEquals(
                testData.recurringPayables.get(0).Next_Account_Payable_Date__c.addMonths(12),
                validatedTestRecurringAccountPayable.Next_Account_Payable_Date__c
            );
        }
    }

    @IsTest
    private static void testCreateAccountPayableFromRecrAccountPayableIsSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Status__c = 'Inactive';
            testData.recurringPayables.get(1).Status__c = 'Inactive';
            update testData.recurringPayables;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringPayables);
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(setController);

            Test.stopTest();

            System.assertEquals(true, ara.isNoSelectionError);
        }
    }

    @IsTest
    private static void testCreatePayablesFromRecurringPayablesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringPayables);
            setController.setSelected(setController.getRecords());

            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(setController);
            ara.createPayable();

            Test.stopTest();

            System.assertEquals(false, ara.isNoSelectionError);
        }
    }

    @IsTest
    private static void testCreatePayablesFromRecurringPayablesTestGetNextPayableDateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringPayables);
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(setController);

            Test.stopTest();

            System.assertEquals(
                29,
                ara.getNextSourceDate(Date.newInstance(2012, 1, 31), 1).day()
            );

            System.assertEquals(
                31,
                ara.getNextSourceDate(Date.newInstance(2012, 2, 28), 1).day()
            );

            System.assertEquals(
                31,
                ara.getNextSourceDate(Date.newInstance(2012, 6, 30), 1).day()
            );

            System.assertEquals(
                Date.newInstance(2012, 6, 15).addMonths(1).day(),
                ara.getNextSourceDate(Date.newInstance(2012, 6, 15), 1).day()
            );
        }
    }

    @IsTest
    private static void testCreatePayablesAndPostFromRecurringPayablesSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringPayables);
            setController.setSelected(setController.getRecords());

            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(setController);
            ara.createPayableAndPost();

            System.assertEquals(false, ara.isNoSelectionError);

            Test.stopTest();
            List<Account_Payable__c> accountPayables = [
                SELECT Id, Status__c
                FROM Account_Payable__c
                WHERE Recurring_Account_Payable__c IN :testData.recurringPayables
            ];

            for (Account_Payable__c payable : accountPayables) {
                System.assertEquals('Posted', payable.Status__c);

                System.assertEquals(
                    String.format(AbstractSourceFromRecurring.CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE, new List<String>{'payable records'}),
                    ApexPages.getMessages().get(0).getDetail()
                );
            }
        }
    }

    @IsTest
    private static void testCreateMultipleAccountPayableFromRecrAccountPayableMonthlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Account_Payable_Frequency__c = 'Monthly';
            update testData.recurringPayables.get(0);

            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(testData.recurringPayables);
            ara.createPayable();

            Test.stopTest();

            Set<Id> recAcctPayablesIdsToRetrieve = new Set<Id>{
                testData.recurringPayables[0].Id,
                testData.recurringPayables[1].Id
            };

            Map<Id, Recurring_Account_Payable__c> recAcctPayables = new Map<Id, Recurring_Account_Payable__c>([
                SELECT 
                    Id,
                    Last_Account_Payable_Date__c,
                    Next_Account_Payable_Date__c
                FROM Recurring_Account_Payable__c
                WHERE Id IN :recAcctPayablesIdsToRetrieve
            ]);

            System.assertEquals(
                Date.newInstance(1991, 12, 31),
                recAcctPayables.get(testData.recurringPayables[0].Id).Last_Account_Payable_Date__c
            );
            System.assertEquals(
                testData.recurringPayables[0].Next_Account_Payable_Date__c.addMonths(1),
                recAcctPayables.get(testData.recurringPayables[0].Id).Next_Account_Payable_Date__c
            );
            System.assertEquals(
                Date.newInstance(1992, 1, 31),
                recAcctPayables.get(testData.recurringPayables[1].Id).Last_Account_Payable_Date__c
            );
            System.assertEquals(
                testData.recurringPayables[1].Next_Account_Payable_Date__c.addMonths(1),
                recAcctPayables.get(testData.recurringPayables[1].Id).Next_Account_Payable_Date__c
            );

            Map<Id, Recurring_Account_Payable_Line__c> recAcctPayLines = new Map<Id, Recurring_Account_Payable_Line__c>([
                SELECT
                    Id,
                    Internal_Comment__c
                FROM Recurring_Account_Payable_Line__c]);

            List<Account_Payable_Line__c> acctPayLines = [
                SELECT 
                    Id, 
                    Internal_Comment__c,
                    Recurring_Account_Payable_Line__c
                FROM Account_Payable_Line__c
            ];

            //check that field map down to lower objects
            for (Account_Payable_Line__c aPayLine : acctPayLines) {
                System.assertEquals(
                    recAcctPayLines.get(aPayLine.Recurring_Account_Payable_Line__c).Internal_Comment__c,
                    aPayLine.Internal_Comment__c
                );
            }
        }
    }

    @IsTest
    private static void testCreateMultipleAccountPayableFromRecrAccountPayableWeeklySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Account_Payable_Frequency__c = 'Weekly';
            update testData.recurringPayables.get(0);

            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(testData.recurringPayables);
            ara.createPayable();

            Test.stopTest();

            System.assertEquals(
                Date.newInstance(1991, 12, 31), [
                    SELECT Last_Account_Payable_Date__c
                    FROM Recurring_Account_Payable__c
                    WHERE Id = :testData.recurringPayables[0].Id
                ].Last_Account_Payable_Date__c
            );
            System.assertEquals(
                testData.recurringPayables[0].Next_Account_Payable_Date__c.addDays(7), [
                    SELECT Next_Account_Payable_Date__c
                    FROM Recurring_Account_Payable__c
                    WHERE Id = :testData.recurringPayables[0].Id
                ].Next_Account_Payable_Date__c
            );
        }
    }

    @IsTest
    private static void testCreateMultipleAccountPayableFromRecrAccountPayableBiWeeklySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            testData.recurringPayables.get(0).Account_Payable_Frequency__c = 'Bi-weekly';
            update testData.recurringPayables.get(0);

            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(testData.recurringPayables);
            ara.createPayable();

            Test.stopTest();

            System.assertEquals(
                Date.newInstance(1991, 12, 31), [
                    SELECT Last_Account_Payable_Date__c
                    FROM Recurring_Account_Payable__c
                    WHERE Id = :testData.recurringPayables[0].Id
                ].Last_Account_Payable_Date__c
            );
            System.assertEquals(
                testData.recurringPayables[0].Next_Account_Payable_Date__c.addDays(14), [
                    SELECT Next_Account_Payable_Date__c
                    FROM Recurring_Account_Payable__c
                    WHERE Id = :testData.recurringPayables[0].Id
                ].Next_Account_Payable_Date__c
            );
        }
    }

    @IsTest
    private static void testCreateAccountPayableFromRecrAccountPayableIsDmlLimitError() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();
            List<Recurring_Account_Payable__c> rap = new List<Recurring_Account_Payable__c>();
            for (Integer i = 0; i < 2000; i++) {
                rap.add(testData.recurringPayables.get(0).clone());
            }
            insert rap;

            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(rap);
            System.assertEquals(true, ara.isDmlLimitError);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateAccountPayableFromRecrAccountPayablePlatformUserSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringAccountPayables()
            .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(0)) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User'];
            User testPlatformUser = new User(
                Alias = 'pltfUsr',
                Email = 'platformuser@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'platformUser.recbill@testorg.com'
            );
            insert testPlatformUser;

            TestDataSuite.assignAdminPermissionSet(testPlatformUser.Id);

            System.runAs(testPlatformUser) {

                Test.startTest();
                testData.disableLDVMode();

                testData.recurringPayables.get(0).Account_Payable_Frequency__c = 'Monthly';
                update testData.recurringPayables.get(0);

                AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(testData.recurringPayables);
                ara.createPayable();

                Test.stopTest();

                System.assertEquals(
                    Date.newInstance(1991, 12, 31), [
                        SELECT Last_Account_Payable_Date__c
                        FROM Recurring_Account_Payable__c
                        WHERE Id = :testData.recurringPayables[0].Id
                    ].Last_Account_Payable_Date__c
                );
                System.assertEquals(
                    testData.recurringPayables[0].Next_Account_Payable_Date__c.addMonths(1), [
                        SELECT Next_Account_Payable_Date__c
                        FROM Recurring_Account_Payable__c
                        WHERE Id = :testData.recurringPayables[0].Id
                    ].Next_Account_Payable_Date__c
                );
                System.assertEquals(
                    Date.newInstance(1992, 1, 31), [
                        SELECT Last_Account_Payable_Date__c
                        FROM Recurring_Account_Payable__c
                        WHERE Id = :testData.recurringPayables[1].Id
                    ].Last_Account_Payable_Date__c
                );
                System.assertEquals(
                    testData.recurringPayables[1].Next_Account_Payable_Date__c.addMonths(1), [
                        SELECT Next_Account_Payable_Date__c
                        FROM Recurring_Account_Payable__c
                        WHERE Id = :testData.recurringPayables[1].Id
                    ].Next_Account_Payable_Date__c
                );
            }
        }

    }

    @IsTest
    public static void testUpdateLinesDates() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringPayables.get(0));
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);

            Date testDate = Date.today().addDays(3);
            ara.payableList[0].obj.put(PACKAGE_QUALIFIER + 'Date__c', testDate);
            ara.updateLinesDates();

            System.assertEquals(testDate, (Date)ara.payableList[0].objLines[0].get(PACKAGE_QUALIFIER + 'Date__c'));
            Test.stopTest();
        }
    }

    @IsTest
    public static void test() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            testData.disableLDVMode();

            String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringPayables.get(0));
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(controller);

            Date testDate = Date.today().addDays(3);
            ara.payableList[0].obj.put(PACKAGE_QUALIFIER + 'Date__c', testDate);
            ara.updateLinesDates();

            System.assertEquals(testDate, (Date)ara.payableList[0].objLines[0].get(PACKAGE_QUALIFIER + 'Date__c'));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreatePayableLDOSingleLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            // this leaves the recurring payable with a single line.
            // it is expected that recurring payables with a single 
            // line are processed synchronously regardless of ldo being enabled.
            delete new List<Recurring_Account_Payable_Line__c>{
                testData.recurringPayableLines[1]
            };

            Recurring_Account_Payable__c selectedRecurringPayable = [SELECT Id, Last_Account_Payable_Date__c, Next_Account_Payable_Date__c, Total2__c FROM Recurring_Account_Payable__c WHERE Id = : testData.recurringPayables[0].Id];
            Recurring_Account_Payable_Line__c selectedRecurringPayableLine = testData.recurringPayableLines[0];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController ctrl = new ApexPages.StandardController(selectedRecurringPayable);
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(ctrl);
            ara.createPayable();

            // the recurring payable should have been updated
            Recurring_Account_Payable__c rPay = [SELECT Last_Account_Payable_Date__c, Next_Account_Payable_Date__c, Total2__c FROM Recurring_Account_Payable__c WHERE Id = :selectedRecurringPayable.Id];
            Assert.areEqual(selectedRecurringPayable.Next_Account_Payable_Date__c, rPay.Last_Account_Payable_Date__c);
            Assert.areEqual(selectedRecurringPayable.Next_Account_Payable_Date__c.addMonths(1), rPay.Next_Account_Payable_Date__c);
            
            // a payable should have been created
            List<Account_Payable__c> payables = [SELECT Total__c FROM Account_Payable__c WHERE Recurring_Account_Payable__c = :selectedRecurringPayable.Id ];
            Assert.areEqual(1, payables.size());
            Assert.areEqual(selectedRecurringPayable.Total2__c, payables[0].Total__c);
            
            // a payable line should have been created
            List<Account_Payable_Line__c> lines = [SELECT Recurring_Account_Payable_Line__c FROM Account_Payable_Line__c WHERE Account_Payable__c IN :payables];
            Assert.areEqual(1, lines.size());
            Assert.areEqual(selectedRecurringPayableLine.Id, lines[0].Recurring_Account_Payable_Line__c);

            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreatePayableLDOMultiLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable__c selectedRecurringPayable = [SELECT Id, Last_Account_Payable_Date__c, Next_Account_Payable_Date__c FROM Recurring_Account_Payable__c WHERE Id = : testData.recurringPayables[0].Id];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController ctrl = new ApexPages.StandardController(selectedRecurringPayable);
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(ctrl);
            ara.createPayable();

            // the recurring payable should not have been updated - it should be updated later in the async job
            Recurring_Account_Payable__c rPay = [SELECT Last_Account_Payable_Date__c, Next_Account_Payable_Date__c FROM Recurring_Account_Payable__c WHERE Id = :selectedRecurringPayable.Id];
            Assert.areEqual(selectedRecurringPayable.Last_Account_Payable_Date__c, rPay.Last_Account_Payable_Date__c);
            Assert.areEqual(selectedRecurringPayable.Next_Account_Payable_Date__c, rPay.Next_Account_Payable_Date__c);
            
            // a payable should not have been created - it should be created later in the async job
            Integer payables = [SELECT COUNT() FROM Account_Payable__c];
            Assert.areEqual(0, payables);
            
            // payable lines should not have been created - they should be created later in the async job
            Integer lines = [SELECT COUNT() FROM Account_Payable_Line__c];
            Assert.areEqual(0, lines);

            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreatePayableLDOMultiLineWithHeaderUpdates() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringAccountPayables()
                .createRecurringAccountPayableLines();

        System.runAs(testData.users.get(1)) {
            Recurring_Account_Payable__c selectedRecurringPayable = [SELECT Id, Last_Account_Payable_Date__c, Next_Account_Payable_Date__c FROM Recurring_Account_Payable__c WHERE Id = : testData.recurringPayables[0].Id];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController ctrl = new ApexPages.StandardController(selectedRecurringPayable);
            AccountPayableFromRecrAccountPayable ara = new AccountPayableFromRecrAccountPayable(ctrl);
            
            // edit header record to simulate UI update to Account_Payable__c.Date__c field
            Account_Payable__c obj = (Account_Payable__c) ara.objList[0].obj;
            obj.Date__c = obj.Date__c.addDays(1);

            ara.createPayable();

            // the recurring payable should not have been updated - it should be updated later in the async job
            Recurring_Account_Payable__c rPay = [SELECT Last_Account_Payable_Date__c, Next_Account_Payable_Date__c FROM Recurring_Account_Payable__c WHERE Id = :selectedRecurringPayable.Id];
            Assert.areEqual(selectedRecurringPayable.Last_Account_Payable_Date__c, rPay.Last_Account_Payable_Date__c);
            Assert.areEqual(selectedRecurringPayable.Next_Account_Payable_Date__c, rPay.Next_Account_Payable_Date__c);
            
            // a payable should have been created
            List<Account_Payable__c> payables = [SELECT Id, Total__c FROM Account_Payable__c];
            Assert.areEqual(1, payables.size());
            Assert.areEqual(0, payables[0].Total__c);
            
            // payable lines should not have been created - they should be created later in the async job
            Integer lines = [SELECT COUNT() FROM Account_Payable_Line__c];
            Assert.areEqual(0, lines);

            // transaction group should have been created to be picked up by the async job
            List<Transaction_Group__c> txnGroups = [SELECT Account_Payable__c, Recurring_Account_Payable__c FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroups.size());
            Assert.areEqual(payables[0].Id, txnGroups[0].Account_Payable__c);
            Assert.areEqual(selectedRecurringPayable.Id, txnGroups[0].Recurring_Account_Payable__c);

            Test.stopTest();
        }
    }

}