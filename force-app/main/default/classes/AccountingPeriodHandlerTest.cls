@IsTest
public class AccountingPeriodHandlerTest {

    public static List<SObjectType> arSubLedgerTypes = new List<SObjectType>(AccountingPeriod.arSubLedgerTypes);
    public static List<SObjectType> apSubLedgerTypes = new List<SObjectType>(AccountingPeriod.apSubLedgerTypes);

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testIsConsideredOpen() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[0]));
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[1]));
        }
    }

    @IsTest
    static void testIsConsideredOpenWithPeriodId() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[0].Id));
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[1].Id));
        }
    }

    @IsTest
    static void testIsConsideredOpenForAP() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[0].Id,apSubLedgerTypes[0]));
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[1].Id,apSubLedgerTypes[0]));
        }
    }

    @IsTest
    static void testIsConsideredOpenForAR() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[0].Id,arSubLedgerTypes[0]));
            System.assertEquals(false, acctPeriodHandler.isConsideredOpen(testData.acctPeriods[1].Id,arSubLedgerTypes[0]));
        }
    }

    @IsTest
    static void testIsConsideredClosed() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.ARCHIVE_IN_PROGRESS_STATUS;
            testData.acctPeriods[2].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            testData.acctPeriods[3].Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[0]));
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[1]));
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[2]));
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[3]));
        }
    }

    @IsTest
    static void testIsConsideredClosedWithPeriodId() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[0].Id));
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[1].Id));
        }
    }

    @IsTest
    static void testIsConsideredClosedForAR() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[0].Id,arSubLedgerTypes[0]));
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[1].Id,arSubLedgerTypes[0]));
        }
    }

    @IsTest
    static void testIsConsideredClosedForAP() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            testData.acctPeriods[1].Status__c = AccountingPeriodActions.OPEN_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[0].Id,apSubLedgerTypes[0]));
            System.assertEquals(true, acctPeriodHandler.isConsideredClosed(testData.acctPeriods[1].Id,apSubLedgerTypes[0]));
        }
    }

    @IsTest
    static void testGetMostRecentAccountingPeriodFromCollection() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            Accounting_Period__c mostRecentAccountingPeriod =
                acctPeriodHandler.getMostRecentAccountingPeriodFromCollection(testData.acctPeriods);

            System.assertNotEquals(NULL, mostRecentAccountingPeriod);
            System.assertEquals(
                mostRecentAccountingPeriod.Id, [
                    SELECT Id FROM Accounting_Period__c ORDER BY End_Date__c DESC LIMIT 1
                ].Id
            );
        }
    }

    @IsTest
    static void testGetMostEarlierAccountingPeriodFromCollection() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            Accounting_Period__c mostEarlierAccountingPeriod =
                acctPeriodHandler.getMostEarlierAccountingPeriodFromCollection(testData.acctPeriods);

            System.assertNotEquals(NULL, mostEarlierAccountingPeriod);
            System.assertEquals(
                mostEarlierAccountingPeriod.Id, [
                    SELECT Id FROM Accounting_Period__c ORDER BY Start_Date__c ASC LIMIT 1
                ].Id
            );
        }
    }

    @IsTest
    static void testGetAccountingPeriodsByName() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c existedPeriod = [
                SELECT Id, Name, End_Date__c, Start_Date__c
                FROM Accounting_Period__c ORDER BY End_Date__c DESC LIMIT 1
            ];
            Accounting_Period__c newAccountingPeriod = new Accounting_Period__c(
                Name = existedPeriod.Name,
                Start_Date__c = existedPeriod.End_Date__c.addDays(1),
                End_Date__c = existedPeriod.End_Date__c.addDays(28)
            );

            DmlException dmlEx;
            try {
                insert newAccountingPeriod;
            }
            catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(AccountingPeriodActions.NAME_DUPLICATION_ERROR, dmlEx.getDmlMessage(0));
        }
    }

    @IsTest
    static void testGetPreviousAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[2];
            Test.startTest();
            Accounting_Period__c previousAccountingPeriod = AccountingPeriodHandler.getInstance().getPreviousAccountingPeriod(testAccountingPeriod.Name);
            System.assertEquals(testData.acctPeriods[1].Name, previousAccountingPeriod.Name);
        }

    }

    @IsTest
    static void testGetNextAccountingPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[2];
            Test.startTest();
            Accounting_Period__c nextAccountingPeriod = AccountingPeriodHandler.getInstance().getNextAccountingPeriod(testAccountingPeriod.Name);
            System.assertEquals(testData.acctPeriods[3].Name, nextAccountingPeriod.Name);
        }

    }

    @IsTest
    static void testGetAccountingPeriodByOffset() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[2];
            Test.startTest();
            Accounting_Period__c leftAP = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(testAccountingPeriod.Name, -2);
            Accounting_Period__c rightAP = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(testAccountingPeriod.Name, 2);
            System.assertEquals(testData.acctPeriods[0].Name, leftAP.Name);
            System.assertEquals(testData.acctPeriods[4].Name, rightAP.Name);
        }
    }

    @IsTest
    static void testGetAccountingPeriodByOffsetOutsideTheExistedRange() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Accounting_Period__c testAccountingPeriod = testData.acctPeriods[2];
            Test.startTest();
            Accounting_Period__c leftAP = AccountingPeriodHandler.getInstance().getAccountingPeriodByOffset(testAccountingPeriod.Name, -3);
            //Such AP is not in DB but fake AP expected here
            System.assertEquals('1991-09', leftAP.Name);
        }
    }

    @IsTest
    static void testGetAccountingPeriodsInRange() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Integer apsInRange = AccountingPeriodHandler.getInstance().countAccountingPeriodsInRange(
                testData.acctPeriods[0].Id,
                testData.acctPeriods[4].Id
            );
            System.assertEquals(5, apsInRange);
        }
    }

    @IsTest
    static void testGetAccountingPeriodByDate() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //Get By Start Date
            Date startDate = Date.newInstance(1991, 12, 1);
            Accounting_Period__c ap1 = AccountingPeriodHandler.getInstance().getAccountingPeriodByStartDate(startDate);
            System.assertEquals(testData.acctPeriods[2].Id, ap1.Id);
            //Get by End Date
            Date endDate = Date.newInstance(1992, 1, 31);
            Accounting_Period__c ap2 = AccountingPeriodHandler.getInstance().getAccountingPeriodByEndDate(endDate);
            System.assertEquals(testData.acctPeriods[3].Id, ap2.Id);
            //Get by any Date
            Date currentDate = Date.newInstance(1992, 2, 15);//in the middle of AP[4]
            Accounting_Period__c ap3 = AccountingPeriodHandler.getInstance().getAccountingPeriodByDate(currentDate);
            System.assertEquals(testData.acctPeriods[4].Id, ap3.Id);
        }

    }

    @IsTest
    static void testFilterByName() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> testRecords = new List<Accounting_Period__c>();
            testRecords.add(testData.acctPeriods[2]);
            testRecords.add(testData.acctPeriods[1]);
            Set<String> exNames = new Set<String>();
            exNames.add((testRecords.get(1).Name));
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().filterByName(testRecords, exNames);
            System.assertEquals(testRecords.get(0).Id, result.get(0).Id);
        }
    }

    @IsTest
    static void testGetAccountingPeriodById() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Id testAccId = testData.acctPeriods[0].Id;
            Accounting_Period__c result = AccountingPeriodHandler.getInstance().getAccountingPeriodById(testAccId);
            System.assertEquals(testData.acctPeriods[0].Name, result.Name);
        }
    }

    @IsTest
    static void testSecondGetMostRecentAccountingPeriodFromCollection() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> testRecords = new List<Accounting_Period__c>();
            testRecords.add(testData.acctPeriods[0]);
            testRecords.add(testData.acctPeriods[1]);
            testRecords.add(testData.acctPeriods[2]);
            Accounting_Period__c result = AccountingPeriodHandler.getInstance().getMostRecentAccountingPeriodFromCollection(testRecords);
            System.assertEquals(testRecords.get(2).Name, result.Name);
        }
    }

    @IsTest
    static void testSecondGetMostEarlierAccountingPeriodFromCollection() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> testRecords = new List<Accounting_Period__c>();
            testRecords.add(testData.acctPeriods[0]);
            testRecords.add(testData.acctPeriods[1]);
            testRecords.add(testData.acctPeriods[2]);
            Accounting_Period__c result = AccountingPeriodHandler.getInstance().getMostEarlierAccountingPeriodFromCollection(testRecords);
            System.assertEquals(testRecords.get(0).Name, result.Name);
        }
    }

    @IsTest
    static void testGetAllAccountingPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Set<String> exNames = new Set<String>();
            exNames.add(testData.acctPeriods[0].Status__c);
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getAllAccountingPeriods(exNames);
            System.assertEquals(testData.acctPeriods.size(), result.size());
        }


    }

    @IsTest
    static void testGetAccountingPeriodsByYears() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> recordsWith1991Year = new List<Accounting_Period__c>();
            for (Accounting_Period__c item : testData.acctPeriods) {
                String res = item.Name.left(4);
                if (res == '1991') {
                    recordsWith1991Year.add(item);
                }
            }
            Set<Integer> years = new Set<Integer>();
            years.add(1991);
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getAccountingPeriodsByYears(years);
            System.assertEquals(recordsWith1991Year.size(), result.size());
        }


    }

    @IsTest
    static void testGetAccountingPeriodByDateAndStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Date newDate = Date.newInstance(1991, 10, 16);
            String status = AccountingPeriodActions.OPEN_STATUS;
            Accounting_Period__c testAccPeriod = [
                    SELECT Name
                    FROM Accounting_Period__c
                    WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS AND Start_Date__c < :newDate AND End_Date__c > :newDate
            ];
            Accounting_Period__c result = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(newDate, status);
            System.assertEquals(testAccPeriod.Name, result.Name);
        }
    }

    @IsTest
    static void testGetAccountingPeriodByDateAndSetOfStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Date newDate = Date.newInstance(1991, 10, 16);
            String status = AccountingPeriodActions.OPEN_STATUS;
            Accounting_Period__c testAccPeriod = [
                    SELECT Name
                    FROM Accounting_Period__c
                    WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS AND Start_Date__c < :newDate AND End_Date__c > :newDate
            ];

            Set<String> setOfStatus = new Set<String>{status};

            Accounting_Period__c result = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(newDate,setOfStatus );
            System.assertEquals(testAccPeriod.Name, result.Name);
        }


    }

    @IsTest
    static void testGetAccountingPeriodByDateAndStatusOpenAP() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Date newDate = Date.newInstance(1991, 10, 16);
            String status = AccountingPeriodActions.OPEN_STATUS;
            Accounting_Period__c testAccPeriod = [
                    SELECT Name
                    FROM Accounting_Period__c
                    WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS AND Start_Date__c < :newDate AND End_Date__c > :newDate
            ];

            Set<String> setOfStatus = new Set<String>{status};

            Accounting_Period__c result = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(newDate,setOfStatus, apSubLedgerTypes[0]);
            System.assertEquals(testAccPeriod.Name, result.Name);
        }
    }

    @IsTest
    static void testGetAccountingPeriodByDateAndStatusOpenAR() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Date newDate = Date.newInstance(1991, 10, 16);
            String status = AccountingPeriodActions.OPEN_STATUS;
            Accounting_Period__c testAccPeriod = [
                    SELECT Name
                    FROM Accounting_Period__c
                    WHERE Status__c = :AccountingPeriodActions.OPEN_STATUS AND Start_Date__c < :newDate AND End_Date__c > :newDate
            ];

            Set<String> setOfStatus = new Set<String>{status};

            Accounting_Period__c result = AccountingPeriodHandler.getInstance().getAccountingPeriodByDateAndStatus(newDate,setOfStatus, arSubLedgerTypes[0]);
            System.assertEquals(testAccPeriod.Name, result.Name);
        }
    }

    @IsTest
    static void testGetPriorAccountingPeriodsForThisYear() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c testAccRecord = testData.acctPeriods[0];
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getPriorAccountingPeriodsForThisYear(testAccRecord, true);
            System.assertEquals(testAccRecord.Name, result.get(0).Name);
        }


    }

    @IsTest
    static void testGetPreviousAccountingPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c prevAccRecord = testData.acctPeriods[0];
            Date newDate = Date.newInstance(1991, 11, 16);
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getPreviousAccountingPeriods(newDate);
            System.assertEquals(prevAccRecord.Name, result.get(0).Name);
        }


    }

    @IsTest
    static void testSecondGetPreviousAccountingPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c prevAccRecord = testData.acctPeriods[0];
            Date newDate = Date.newInstance(1991, 11, 16);
            Set<String> validStatuses = new Set<String>();
            validStatuses.add(AccountingPeriodActions.OPEN_STATUS);
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getPreviousAccountingPeriods(newDate, validStatuses);
            System.assertEquals(prevAccRecord.Name, result.get(0).Name);
        }


    }

    @IsTest
    static void testGetNextAccountingPeriods() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c currentAccPeriod = testData.acctPeriods[1];
            Set<String> validStatuses = new Set<String>();
            validStatuses.add(AccountingPeriodActions.OPEN_STATUS);
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getNextAccountingPeriods(currentAccPeriod, validStatuses);
            Accounting_Period__c nextAccPeriod = testData.acctPeriods[2];
            System.assertEquals(nextAccPeriod.Name, result.get(0).Name);
        }


    }

    @IsTest
    static void testGetAccountingPeriodsFromRange() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> recordsInRange = new List<Accounting_Period__c>();
            recordsInRange.add(testData.acctPeriods[0]);
            recordsInRange.add(testData.acctPeriods[1]);
            String starPeriodName = testData.acctPeriods[0].Name;
            Integer numberOfPeriods = 2;
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getAccountingPeriodsFromRange(starPeriodName, numberOfPeriods);
            System.assertEquals(recordsInRange.get(1).Name, result.get(1).Name);
        }
    }

    @IsTest
    static void testGetAccountingPeriodsByDateRangeAndStatus() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Date startDate = Date.newInstance(1991, 10, 16);
            Date endDate = Date.newInstance(1991, 12, 27);
            String status = AccountingPeriodActions.OPEN_STATUS;
            List<Accounting_Period__c> result = AccountingPeriodHandler.getInstance().getAccountingPeriodsByDateRangeAndStatus(startDate, endDate, status);
            List<Accounting_Period__c> testAccRecords = new List<Accounting_Period__c>();
            testAccRecords.add(testData.acctPeriods[0]);
            testAccRecords.add(testData.acctPeriods[1]);
            testAccRecords.add(testData.acctPeriods[2]);
            System.assertEquals(testAccRecords.size(), result.size());
        }
    }

    @IsTest
    static void testIsPastOpenPeriodExists() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c currentAccPeriod = testData.acctPeriods[1];
            Boolean result = AccountingPeriodHandler.getInstance().isPastOpenOrInProgressPeriodExists(currentAccPeriod);
            System.assertEquals(true, result);
        }
    }

    @IsTest
    static void testIsFutureClosedPeriodExists() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c currentAccPeriod = testData.acctPeriods[1];
            Boolean result = AccountingPeriodHandler.getInstance().isFutureClosedPeriodExists(currentAccPeriod);
            System.assertEquals(false, result);
        }
    }

    @IsTest
    static void testToString() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            Accounting_Period__c currentAccPeriod = testData.acctPeriods[0];
            String result = AccountingPeriodHandler.getInstance().toString(currentAccPeriod);
            System.assertEquals((String) currentAccPeriod.Name, result);
        }
    }

    @IsTest
    static void testSecondToString() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> testAccRecords = new List<Accounting_Period__c>();
            testAccRecords.add(testData.acctPeriods[0]);
            testAccRecords.add(testData.acctPeriods[1]);
            testAccRecords.add(testData.acctPeriods[2]);
            List<String> results = AccountingPeriodHandler.getInstance().toString(testAccRecords);
            System.assertEquals((String) testAccRecords.get(1).Name, results.get(1));
        }
    }

    @IsTest
    static void testAreAccPeriodsExisting() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            List<Accounting_Period__c> testAccRecords = new List<Accounting_Period__c>();
            testAccRecords.add(testData.acctPeriods[0]);
            testAccRecords.add(testData.acctPeriods[1]);
            testAccRecords.add(testData.acctPeriods[2]);
            Date startDate = Date.newInstance(1991, 10, 16);
            Date endDate = Date.newInstance(1991, 11, 27);
            Boolean result = AccountingPeriodHandler.areAccPeriodsExisting(startDate, endDate, testAccRecords);
            System.assertEquals(true, result);
        }
    }

    @IsTest
    static void testGetFirstOpenedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();
            System.assertEquals(
                    testData.acctPeriods[1].Name, AccountingPeriodHandler.getInstance().getFirstOpenedPeriod().Name
            );
        }
    }

    @IsTest
    static void testGetFirstOpenedPeriodWhenFirstClosedIsArchived() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.ARCHIVED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods[0];
            AccountingPeriodActions.isFirstRun = true;
            Test.stopTest();
            System.assertEquals(
                    testData.acctPeriods[1].Name, AccountingPeriodHandler.getInstance().getFirstOpenedPeriod().Name
            );
        }
    }
    
    @IsTest
    static void testGetFirstPeriodWithStatusOpen() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();
            System.assertEquals(
                    testData.acctPeriods[1].Name, AccountingPeriodHandler.getInstance().getFirstPeriodWithStatusOpen().Name
            );
        }
    }

    @IsTest
    static void testGetFirstPeriodWithStatusOpenAllClosed() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users[1]) {

            AccountingPeriodActions.isFirstRun = false;
            for(Accounting_Period__c aP : testData.acctPeriods){
                aP.Status__c = AccountingPeriodActions.CLOSED_STATUS;
            }

            update testData.acctPeriods;

            Test.startTest();
            System.assertEquals(
                    testData.acctPeriods[0].Name, AccountingPeriodHandler.getInstance().getFirstPeriodWithStatusOpen().Name
            );
            Test.stopTest();
           
        }
    }

    @IsTest
    static void testIsConsideredOpenForReporting() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSE_INTERIM_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(true, acctPeriodHandler.IsConsideredOpenForReporting(testData.acctPeriods[0].Id));
            System.assertEquals(true, acctPeriodHandler.IsConsideredOpenForReporting(testData.acctPeriods[1].Id));
        }
    }

    @IsTest
    static void testIsConsideredOpenForReportingClosedPeriod() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            AccountingPeriodActions.isFirstRun = false;
            update testData.acctPeriods;
            AccountingPeriodActions.isFirstRun = true;

            AccountingPeriodHandler acctPeriodHandler = AccountingPeriodHandler.getInstance();
            System.assertEquals(false, acctPeriodHandler.IsConsideredOpenForReporting(testData.acctPeriods[0].Id));

        }
    }
}