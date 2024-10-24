@IsTest
private class RecurringBillingSchedulableBatchTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateBatchBillingFromRecurringBillingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling().createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
            update testData.recurringBillings[0];

            if (DomainUtils.getCronTriggerByJobName(new Set<String> {'Recurring Billing Job'}).size() != 0) {
                return;
            }

            RecurringBillingSchedulableBatch.startRecurringBillingSchedulableBatch(NULL, 'Recurring Billing Job');
            Test.stopTest();
            System.assertEquals(
                Date.newinstance(1991, 12, 31), [
                    SELECT Last_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Last_Billing_Date__c
            );
            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c.addMonths(1), [
                    SELECT Next_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Next_Billing_Date__c
            );
            System.assertEquals(
                Date.newinstance(1992, 01, 31), [
                    SELECT Last_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[1].Id
                ].Last_Billing_Date__c
            );
            System.assertEquals(
                testData.recurringBillings[1].Next_Billing_Date__c.addMonths(1), [
                    SELECT Next_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[1].Id
                ].Next_Billing_Date__c
            );
            System.assertEquals(
                2, [
                SELECT count()
                FROM Billing__c
                WHERE Recurring_Billing__c IN :testData.recurringBillings
            ]
            );
            System.assertEquals(
                4, [
                SELECT count()
                FROM Billing_Line__c
                WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
            ]
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Billing', ajr.Schedule_Job_Type__c);
            System.assertEquals(2, ajr.Processed__c);
            System.assertEquals(2, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    public static void testCreateBatchBillingNextDateMoreToday() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling().createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            for (Recurring_Billing__c rBill : testData.recurringBillings) {
                rBill.Next_Billing_Date__c = System.today().addDays(2);
            }
            update testData.recurringBillings;

            RecurringBillingSchedulableBatch.startRecurringBillingSchedulableBatch(NULL, 'Recurring Billing Job');
            Test.stopTest();
            System.assertEquals(
                0, [
                SELECT count()
                FROM Billing__c
                WHERE Recurring_Billing__c IN :testData.recurringBillings
            ]
            );
            System.assertEquals(
                0, [
                SELECT count()
                FROM Billing_Line__c
                WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
            ]
            );

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Billing', ajr.Schedule_Job_Type__c);
            System.assertEquals(0, ajr.Processed__c);
            System.assertEquals(0, ajr.Succeeded__c);
            System.assertEquals(0, ajr.Failed__c);
        }
    }

    @IsTest
    public static void testCreateBatchExcludeScheduledJob() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling().createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();

            for (Recurring_Billing__c rBill : testData.recurringBillings) {
                rBill.Exclude_From_Automation__c = true;
            }
            update testData.recurringBillings;

            RecurringBillingSchedulableBatch.startRecurringBillingSchedulableBatch(NULL, 'Recurring Billing Job');
            Test.stopTest();
            System.assertEquals(
                0, [
                SELECT count()
                FROM Billing__c
                WHERE Recurring_Billing__c IN :testData.recurringBillings
            ]
            );
            System.assertEquals(
                0, [
                SELECT count()
                FROM Billing_Line__c
                WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
            ]
            );
        }
    }

    @IsTest
    public static void testCreateBatchSchedulerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling().createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
            update testData.recurringBillings[0];

            RecurringBillingSchedulableBatch.startRecurringBillingSchedulableBatch(NULL, 'Recurring Billing Job');

            Test.stopTest();

            AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE ApexClass.Name = 'RecurringBillingSchedulableBatch' AND JobType = 'BatchApex'];
            System.assertNotEquals(NULL, job);

        }
    }

    @IsTest
    public static void testCreateBatchSchedulerPartialSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling().createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            //set Bank GL Account on Recurring Billing Line to prevent Billing Line creation
            Recurring_Billing_Line__c badLine = testData.recurringBillingLines[0].clone(false, true, false, false);
            badLine.Revenue_GL_Account__c = testData.glAccounts[0].Id;
            RecurringBillingLineActions.bypassGLAccountValidation = true;
            insert badLine;
            RecurringBillingLineActions.bypassGLAccountValidation = false;

            RecurringBillingSchedulableBatch.startRecurringBillingSchedulableBatch(NULL, 'Recurring Billing Job');

            Test.stopTest();

            AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE ApexClass.Name = 'RecurringBillingSchedulableBatch' AND JobType = 'BatchApex'];
            System.assertNotEquals(NULL, job);

            System.assertEquals(0, [SELECT count() FROM Billing__c WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id]);
            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Recurring_Billing__c = :testData.recurringBillings[1].Id]);

            Automated_Job_Results__c ajr = [SELECT Id, Schedule_Job_Type__c, Succeeded__c, Processed__c, Failed__c FROM Automated_Job_Results__c];

            System.assertEquals('Recurring Billing', ajr.Schedule_Job_Type__c);
            System.assertEquals(2, ajr.Processed__c);
            System.assertEquals(1, ajr.Succeeded__c);
            System.assertEquals(1, ajr.Failed__c);
        }
    }

}