@IsTest
private class RecurringPayableSchedulableBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateBatchPayableFromRecurringPayableSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.recurringPayables[0].Account_Payable_Frequency__c = 'Monthly';
            update testData.recurringPayables[0];

            if (DomainUtils.getCronTriggerByJobName(new Set<String> {'Recurring Payable Job'}).size() != 0) {
                return;
            }

            RecurringPayableSchedulableBatch.startRecurringPayableSchedulableBatch(NULL, 'Recurring Payable Job');
            Test.stopTest();
            System.assertEquals(
                Date.newinstance(1991, 12, 31), [
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
                2, [
                SELECT count()
                FROM Account_Payable__c
                WHERE Recurring_Account_Payable__c IN :testData.recurringPayables
            ]
            );
            System.assertEquals(
                4, [
                SELECT count()
                FROM Account_Payable_Line__c
                WHERE Recurring_Account_Payable_Line__c IN :testData.recurringPayableLines
            ]
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Payable', ajr.Schedule_Job_Type__c);
            System.assertEquals(2, ajr.Processed__c);
            System.assertEquals(2, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    public static void testCreateBatchPayableNextDateMoreToday() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            for (Recurring_Account_Payable__c rPay : testData.recurringPayables) {
                rPay.Next_Account_Payable_Date__c = System.today().addDays(2);
            }
            update testData.recurringPayables;

            RecurringPayableSchedulableBatch.startRecurringPayableSchedulableBatch(NULL, 'Recurring Payable Job');
            Test.stopTest();
            System.assertEquals(
                0, [
                SELECT count()
                FROM Account_Payable__c
                WHERE Recurring_Account_Payable__c IN :testData.recurringPayables
            ]
            );
            System.assertEquals(
                0, [
                SELECT count()
                FROM Account_Payable_Line__c
                WHERE Recurring_Account_Payable_Line__c IN :testData.recurringPayableLines
            ]
            );
        }
    }

    @IsTest
    public static void testCreateBatchExcludeScheduledJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            for (Recurring_Account_Payable__c rPay : testData.recurringPayables) {
                rPay.Exclude_From_Automation__c = true;
            }
            update testData.recurringPayables;

            RecurringPayableSchedulableBatch.startRecurringPayableSchedulableBatch(NULL, 'Recurring Payable Job');
            Test.stopTest();
            System.assertEquals(
                0, [
                SELECT count()
                FROM Account_Payable__c
                WHERE Recurring_Account_Payable__c IN :testData.recurringPayables
            ]
            );
            System.assertEquals(
                0, [
                SELECT count()
                FROM Account_Payable_Line__c
                WHERE Recurring_Account_Payable_Line__c IN :testData.recurringPayableLines
            ]
            );
        }
    }

    @IsTest
    public static void testCreateBatchSchedulerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            testData.recurringPayables[0].Account_Payable_Frequency__c = 'Monthly';
            update testData.recurringPayables[0];

            RecurringPayableSchedulableBatch.startRecurringPayableSchedulableBatch(NULL, 'Recurring Payable Job');

            Test.stopTest();

            AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE ApexClass.Name = 'RecurringPayableSchedulableBatch' AND JobType = 'BatchApex'];
            System.assertNotEquals(NULL, job);

        }
    }

    @IsTest
    public static void testCreateBatchSchedulerPartialSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringAccountPayables().createRecurringAccountPayableLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            //set Bank GL Account on Recurring Payable Line to prevent Payable Line creation
            Recurring_Account_Payable_Line__c badLine = testData.recurringPayableLines[0].clone(false, true, false, false);
            badLine.Expense_GL_Account__c = testData.glAccounts[0].Id;
            RecurringAccountPayableLineActions.bypassGLAccountValidation = true;
            insert badLine;
            RecurringAccountPayableLineActions.bypassGLAccountValidation = false;

            RecurringPayableSchedulableBatch.startRecurringPayableSchedulableBatch(NULL, 'Recurring Payable Job');

            Test.stopTest();

            AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE ApexClass.Name = 'RecurringPayableSchedulableBatch' AND JobType = 'BatchApex'];
            System.assertNotEquals(NULL, job);

            System.assertEquals(0, [SELECT count() FROM Account_Payable__c WHERE Recurring_Account_Payable__c = :testData.recurringPayables[0].Id]);
            System.assertEquals(1, [SELECT count() FROM Account_Payable__c WHERE Recurring_Account_Payable__c = :testData.recurringPayables[1].Id]);

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Payable', ajr.Schedule_Job_Type__c);
            System.assertEquals(2, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(1, ajr.Failed__c);
        }
    }

}