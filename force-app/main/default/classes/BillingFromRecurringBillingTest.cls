@IsTest
public class BillingFromRecurringBillingTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingIsInactiveError() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();

        System.runAs(testData.users[1]) {
            testData.recurringBillings[0].Status__c = 'Inactive';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            System.assertEquals(true, brb.isInActiveError);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingStandardUserSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users.get(0)) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
            User testStandardUser = new User(
                Alias = 'stdUsr',
                Email = 'standarduser@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'standardUser.recbill@testorg.com'
            );
            insert testStandardUser;

            TestDataSuite.assignAdminPermissionSet(testStandardUser.Id);

            System.runAs(testStandardUser) {

                testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
                testData.recurringBillings[0].Opportunity__c = NULL;
                update testData.recurringBillings[0];

                Test.startTest();
                testData.disableLDVMode();
                ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
                BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

                brb.createBilling();

                List<Recurring_Billing__c> recBilling = [
                    SELECT 
                        Id,
                        Last_Billing_Date__c,
                        Next_Billing_Date__c,
                        Billing_Contact__c,
                        PO_Number__c,
                        Comment__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ];

                System.assertEquals( 1, recBilling.size());

                System.assertEquals(
                    testData.recurringBillings[0].Next_Billing_Date__c,
                    recBilling[0].Last_Billing_Date__c
                );
                System.assertEquals(
                    testData.recurringBillings[0].Next_Billing_Date__c.addMonths(1),
                    recBilling[0].Next_Billing_Date__c
                );
                
                List<Billing__c> relatedBilling = [
                    SELECT 
                        Id,
                        Billing_Contact__c,
                        PO_Number__c,
                        Billing_Comment__c
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ];
                System.assertEquals(1, relatedBilling.size());
                System.assertEquals(recBilling[0].Billing_Contact__c, relatedBilling[0].Billing_Contact__c);
                System.assertEquals(recBilling[0].PO_Number__c, relatedBilling[0].PO_Number__c);
                System.assertEquals(recBilling[0].Comment__c, relatedBilling[0].Billing_Comment__c);

                System.assertEquals(
                    2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
                );
                Test.stopTest();
            }
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWeeklySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Weekly';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c, [
                    SELECT Last_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Last_Billing_Date__c
            );
            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c.addDays(7), [
                    SELECT Next_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Next_Billing_Date__c
            );
            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingBiWeeklySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Bi-weekly';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c, [
                    SELECT Last_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Last_Billing_Date__c
            );
            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c.addDays(14), [
                    SELECT Next_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Next_Billing_Date__c
            );
            System.assertEquals(
                1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingMonthlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c, [
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
                1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
            System.assertEquals(
                2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingQuarterlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Quarterly';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c, [
                    SELECT Last_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Last_Billing_Date__c
            );

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c.addMonths(3), [
                    SELECT Next_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Next_Billing_Date__c
            );
            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id]);
            System.assertEquals(2, [SELECT count() FROM Billing_Line__c WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines]);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingSemiAnnualSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Semi-annual';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c, [
                    SELECT Last_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Last_Billing_Date__c
            );

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c.addMonths(6), [
                    SELECT Next_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Next_Billing_Date__c
            );
            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id]);
            System.assertEquals(2, [SELECT count() FROM Billing_Line__c WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines]);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingAnnualSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Annual';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c, [
                    SELECT Last_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Last_Billing_Date__c
            );
            System.assertEquals(
                testData.recurringBillings[0].Next_Billing_Date__c.addMonths(12), [
                    SELECT Next_Billing_Date__c
                    FROM Recurring_Billing__c
                    WHERE Id = :testData.recurringBillings[0].Id
                ].Next_Billing_Date__c
            );
            System.assertEquals(1, [SELECT count() FROM Billing__c WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id]);
            System.assertEquals(2, [SELECT count() FROM Billing_Line__c WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines]);
            Test.stopTest();
        }

    }
        
    @IsTest
    public static void testCreateBillingFromRecurringBillingIsSelectionError() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();

        System.runAs(testData.users[1]) {
            testData.recurringBillings[0].Status__c = 'Inactive';
            testData.recurringBillings[1].Status__c = 'Inactive';
            update testData.recurringBillings;

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            System.assertEquals(true, brb.isNoSelectionError);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingsFromRecurringBillingsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            brb.createBilling();

            System.assertEquals(
                String.format(AbstractSourceFromRecurring.CREATE_SUCCESS_MESSAGE, new List<String>{SObjectType.Billing__c.getLabelPlural().toLowerCase()}),
                ApexPages.getMessages().get(0).getDetail()
            );

            System.assertEquals(2, [SELECT count() FROM Billing__c WHERE Recurring_Billing__c IN :testData.recurringBillings]);
            System.assertEquals(4, [SELECT count() FROM Billing_Line__c WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines]);

            for (Billing__c bill : [SELECT Id, Opportunity__c
                                    FROM Billing__c
                                    WHERE Recurring_Billing__c IN :testData.recurringBillings
            ]) {

                System.assertEquals(testData.opportunities[0].Id, bill.Opportunity__c);
            }
            Test.stopTest();
        }

    }
    
    @IsTest
    public static void testCreateBillingsFromRecurringBillingsTestGetNextBillingDateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.disableLDVMode();
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            System.assertEquals(29, brb.getNextSourceDate(Date.newInstance(2012, 1, 31), 1).day());
            System.assertEquals(31, brb.getNextSourceDate(Date.newInstance(2012, 2, 28), 1).day());
            System.assertEquals(31, brb.getNextSourceDate(Date.newInstance(2012, 6, 30), 1).day());
            System.assertEquals(Date.newInstance(2012, 6, 15).addMonths(1).day(),brb.getNextSourceDate(Date.newInstance(2012, 6, 15), 1).day());
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateAndPostBillingsFromRecurringBillingsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Test.startTest();
            testData.disableLDVMode();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            brb.createBillingAndPost();

            System.assertEquals(2, [SELECT count() FROM Billing__c WHERE Recurring_Billing__c IN :testData.recurringBillings]);
            System.assertEquals(4, [SELECT count() FROM Billing_Line__c WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines]);
            Test.stopTest();
            for (Billing__c bill : [SELECT Id, Status__c, Opportunity__c FROM Billing__c WHERE Recurring_Billing__c IN :testData.recurringBillings]) {
                System.assertEquals(testData.opportunities[0].Id, bill.Opportunity__c);
                System.assertEquals('Posted', bill.Status__c);
                System.assertEquals(
                    String.format(AbstractSourceFromRecurring.CREATE_AND_ASYNC_POST_JOB_STARTED_SUCCESS_MESSAGE, new List<String>{'billings'}),
                    ApexPages.getMessages().get(0).getDetail()
                );
            }
        }
    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxLineOnInitialPageLoadLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .enableAvaTaxCalculation()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Recurring_Billing__c testRecBill = testData.recurringBillings[0];
            Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
            testRecBillLine.Product__c = testData.products[3].Id;
            update testRecBillLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            System.assertEquals(2 + 1, brb.billList.get(0).objLines.size());
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxLineOnInitialPageLoadHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enableAvaTaxCalculation()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines()
            .createProducts();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Recurring_Billing__c testRecBill = testData.recurringBillings[0];
            Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
            testRecBillLine.Product__c = testData.products[3].Id;
            update testRecBillLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            System.assertEquals(2, brb.billList.get(0).objLines.size());
            System.assertEquals(
                testRecBillLine.Rate__c * testRecBillLine.Quantity__c * brb.billList.get(0).getCurrencyConversionRate() / 10,
                brb.billList.get(0).objLines.get(0).get(Billing_Line__c.Tax_Amount2__c)
            );
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxOnCreateLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Recurring_Billing__c testRecBill = testData.recurringBillings[0];
            Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
            testRecBillLine.Product__c = testData.products[3].Id;
            update testRecBillLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            System.assertEquals(2 + 1, brb.billList.get(0).objLines.size());

            brb.createBilling();

            System.assertNotEquals(
                true, [
                    SELECT Id, Rate__c
                    FROM Billing_Line__c
                    WHERE Product__c = :AvaTaxHelper.getSalesTaxProductId(testRecBill)
                ].isEmpty()
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxOnCreateHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Recurring_Billing__c testRecBill = testData.recurringBillings[0];
            Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
            testRecBillLine.Product__c = testData.products[3].Id;
            update testRecBillLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            brb.createBilling();

            Billing_Line__c checkedBLine = [
                SELECT Id, Tax_Amount2__c
                FROM Billing_Line__c
                WHERE Recurring_Billing_Line__c = :testRecBillLine.Id
            ];

            System.assertEquals(
                testRecBillLine.Rate__c * testRecBillLine.Quantity__c * brb.billList.get(0).getCurrencyConversionRate() / 10,
                checkedBLine.Tax_Amount2__c
            );
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxOnCreateAndPostLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .enableAvaTaxCalculation()
            .setLineLevelPost()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Recurring_Billing__c testRecBill = testData.recurringBillings[0];
            Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
            testRecBillLine.Product__c = testData.products[3].Id;
            update testRecBillLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();
            List<Recurring_Billing__c> recBills = [SELECT Id, Ledger__c FROM Recurring_Billing__c WHERE Id IN :testData.recurringBillings];
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(recBills);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            brb.createBillingAndPost();

            Test.stopTest();

            List<Billing_Line__c> salesTaxLines = [
                SELECT Id, Rate__c, Billing__r.Status__c
                FROM Billing_Line__c
                WHERE Product__c IN :AvaTaxHelper.getSalesTaxProductIds(recBills)
            ];

            System.assertNotEquals(true, salesTaxLines.isEmpty());
            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, salesTaxLines[0].Billing__r.Status__c);
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxOnCreateAndPostHLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines()
            .createProducts()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            Recurring_Billing__c testRecBill = testData.recurringBillings[0];
            Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
            testRecBillLine.Product__c = testData.products[3].Id;
            update testRecBillLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.recurringBillings);
            setController.setSelected(setController.getRecords());
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(setController);

            brb.createBillingAndPost();

            Test.stopTest();

            Billing_Line__c checkedBLine = [
                SELECT Id, Tax_Amount2__c, Billing__r.Status__c
                FROM Billing_Line__c
                WHERE Recurring_Billing_Line__c = :testRecBillLine.Id
            ];

            System.assertEquals(AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED, checkedBLine.Billing__r.Status__c);

            System.assertEquals(
                testRecBillLine.Rate__c * testRecBillLine.Quantity__c * brb.billList.get(0).getCurrencyConversionRate() / 10,
                checkedBLine.Tax_Amount2__c
            );
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxLineOnInitialPageLoadLLP_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .setLineLevelPost()
                .enableMultiCurrency()
                .createOpportunities()
                .createRecurringBilling()
                .createRecurringBillingLines()
                .enableAvaTaxCalculation();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                testData.opportunities[0].StageName = 'Closed Won';
                update testData.opportunities[0];

                RecurringBillingActions.isPreventUpdateOverride = true;
                Recurring_Billing__c testRecBill = testData.recurringBillings[0];
                testRecBill.put('CurrencyIsoCode', newCurrencyIsoCode);
                update testRecBill;
                RecurringBillingActions.isPreventUpdateOverride = false;

                Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
                testRecBillLine.Product__c = testData.products[3].Id;
                update testRecBillLine;

                SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

                Test.startTest();

                ApexPages.StandardController stdController = new ApexPages.StandardController(testData.recurringBillings[0]);
                BillingFromRecurringBilling brb = new BillingFromRecurringBilling(stdController);

                System.assertEquals(2 + 1, brb.billList.get(0).objLines.size());
                System.assertEquals(
                    testRecBillLine.Rate__c * testRecBillLine.Quantity__c * brb.billList.get(0).getCurrencyConversionRate() / 10,
                    brb.billList.get(0).objLines.get(2).get('Rate__c')
                );
                Test.stopTest();
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraTaxCalcOnInitialPageLoadHLP_MC() {
        try {
            TestDataSuite testData = TestDataSuite.getInstance()
                .enableMultiCurrency()
                .createOpportunities()
                .createRecurringBilling()
                .createRecurringBillingLines()
                .createProducts()
                .enableAvaTaxCalculation();

            System.runAs(testData.users[1]) {
                String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
                if (String.isBlank(newCurrencyIsoCode)) {
                    return;
                }

                testData.opportunities[0].StageName = 'Closed Won';
                update testData.opportunities[0];

                RecurringBillingActions.isPreventUpdateOverride = true;
                Recurring_Billing__c testRecBill = testData.recurringBillings[0];
                testRecBill.put('CurrencyIsoCode', newCurrencyIsoCode);
                update testRecBill;
                RecurringBillingActions.isPreventUpdateOverride = false;

                Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
                testRecBillLine.Product__c = testData.products[3].Id;
                update testRecBillLine;

                SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                    200,
                    'Complete',
                    testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                    new Map<String, String>{'Content-Type' => 'application/json'}
                );

                Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

                Test.startTest();

                ApexPages.StandardController stdController = new ApexPages.StandardController(testData.recurringBillings[0]);
                BillingFromRecurringBilling brb = new BillingFromRecurringBilling(stdController);

                System.assertEquals(2, brb.billList.get(0).objLines.size());
                System.assertEquals(
                    testRecBillLine.Rate__c * testRecBillLine.Quantity__c * brb.billList.get(0).getCurrencyConversionRate() / 10,
                    brb.billList.get(0).objLines.get(0).get(Billing_Line__c.Tax_Amount2__c)
                );
            }
        }
        catch (TestDataSuite.TestDataSuiteException ex) {

        }
    }

    @IsTest
    public static void testCreateMultipleBillingFromRecurringBillingMonthlySuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            testData.opportunities[0].StageName = 'Closed Won';
            update testData.opportunities[0];

            testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(testData.recurringBillings);
            brb.createBilling();

            System.assertEquals(
                Date.newInstance(1991, 12, 31), [
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
                Date.newInstance(1992, 1, 31), [
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
                1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
            );
            System.assertEquals(
                4, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
            );
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingIsDmlLimitError() {
        TestDataSuite testData = TestDataSuite.getInstance().createRecurringBilling();

        System.runAs(testData.users[1]) {
            List<Recurring_Billing__c> rbl = new List<Recurring_Billing__c>();
            for (Integer i = 0; i < 2000; i++) {
                rbl.add(testData.recurringBillings[0].clone());
            }

            insert rbl;

            Test.startTest();
            testData.disableLDVMode();

            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(rbl);

            System.assertEquals(true, brb.isDmlLimitError);
            Test.stopTest();
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingPlatformUserSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

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

                testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
                testData.recurringBillings[0].Opportunity__c = NULL;
                update testData.recurringBillings[0];

                Test.startTest();
                testData.disableLDVMode();

                ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
                BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

                brb.createBilling();

                System.assertEquals(
                    testData.recurringBillings[0].Next_Billing_Date__c, [
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
                    1, [
                    SELECT count()
                    FROM Billing__c
                    WHERE Recurring_Billing__c = :testData.recurringBillings[0].Id
                ]
                );
                System.assertEquals(
                    2, [
                    SELECT count()
                    FROM Billing_Line__c
                    WHERE Recurring_Billing_Line__c IN :testData.recurringBillingLines
                ]
                );
                Test.stopTest();
            }
        }

    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingWithAvalaraSalesTaxLineSetTotalLLP() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .setLineLevelPost()
            .createOpportunities()
            .createRecurringBilling()
            .createRecurringBillingLines()
            .enableAvaTaxCalculation();

        System.runAs(testData.users[1]) {

            Recurring_Billing__c testRecBill = testData.recurringBillings[0];

            Recurring_Billing_Line__c testRecBillLine = testData.recurringBillingLines[0];
            testRecBillLine.Product__c = testData.products[3].Id;
            update testRecBillLine;

            SingleRequestMock xPostCreateOrAdjustTransactionRequestMock = new SingleRequestMock(
                200,
                'Complete',
                testData.getCreateAvaTaxTransactionResponseBody(testRecBill, new List<Recurring_Billing_Line__c>{testRecBillLine}, 10),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );

            Test.setMock(HttpCalloutMock.class, xPostCreateOrAdjustTransactionRequestMock);

            Test.startTest();

            ApexPages.StandardController stdController = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(stdController);

            System.assertEquals(14619.2, brb.billList.get(0).total);
            Test.stopTest();
        }
    }

    @IsTest
    public static void testUpdateLinesDates() {
        TestDataSuite testData = TestDataSuite.getInstance()
                .createRecurringBilling()
                .createRecurringBillingLines();

        System.runAs(testData.users.get(1)) {
            testData.recurringBillings[0].Billing_Frequency__c = 'Monthly';
            testData.recurringBillings[0].Opportunity__c = NULL;
            update testData.recurringBillings[0];

            Test.startTest();
            testData.disableLDVMode();

            String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
            ApexPages.StandardController controller = new ApexPages.StandardController(testData.recurringBillings[0]);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            Date testDate = Date.today().addDays(3);
            brb.billList[0].obj.put(PACKAGE_QUALIFIER + 'Date__c', testDate);
            brb.updateLinesDates();

            System.assertEquals(testDate, (Date)brb.billList[0].objLines[0].get(PACKAGE_QUALIFIER + 'Date__c'));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingLDOSingleLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            // this leaves the recurring billing with a single line.
            // it is expected that recurring billings with a single 
            // line are processed synchronously regardless of ldo being enabled.
            delete new List<Recurring_Billing_Line__c>{
                testData.recurringBillingLines[1]
            };

            Recurring_Billing__c selectedRecurringBilling = [SELECT Id, Last_Billing_Date__c, Next_Billing_Date__c, Total__c FROM Recurring_Billing__c WHERE Id = : testData.recurringBillings[0].Id];
            Recurring_Billing_Line__c selectedRecurringBillingLine = testData.recurringBillingLines[0];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(selectedRecurringBilling);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            // the recurring billing should have been updated
            Recurring_Billing__c rBill = [SELECT Last_Billing_Date__c, Next_Billing_Date__c, Total__c FROM Recurring_Billing__c WHERE Id = :selectedRecurringBilling.Id];
            Assert.areEqual(selectedRecurringBilling.Next_Billing_Date__c, rBill.Last_Billing_Date__c);
            Assert.areEqual(selectedRecurringBilling.Next_Billing_Date__c.addMonths(1), rBill.Next_Billing_Date__c);
            
            // a billing should have been created
            List<Billing__c> bills = [SELECT Total__c FROM Billing__c WHERE Recurring_Billing__c = :selectedRecurringBilling.Id ];
            Assert.areEqual(1, bills.size());
            Assert.areEqual(selectedRecurringBilling.Total__c, bills[0].Total__c);
            
            // a billing line should have been created
            List<Billing_Line__c> lines = [SELECT Recurring_Billing_Line__c FROM Billing_Line__c WHERE Billing__c IN :bills];
            Assert.areEqual(1, lines.size());
            Assert.areEqual(selectedRecurringBillingLine.Id, lines[0].Recurring_Billing_Line__c);

            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingLDOMultiLine() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Recurring_Billing__c selectedRecurringBilling = [SELECT Id, Last_Billing_Date__c, Next_Billing_Date__c FROM Recurring_Billing__c WHERE Id = : testData.recurringBillings[0].Id];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(selectedRecurringBilling);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);

            brb.createBilling();

            // the recurring billing should not have been updated - it should be updated later in the async job
            Recurring_Billing__c rBill = [SELECT Last_Billing_Date__c, Next_Billing_Date__c FROM Recurring_Billing__c WHERE Id = :selectedRecurringBilling.Id];
            Assert.areEqual(selectedRecurringBilling.Last_Billing_Date__c, rBill.Last_Billing_Date__c);
            Assert.areEqual(selectedRecurringBilling.Next_Billing_Date__c, rBill.Next_Billing_Date__c);
            
            // a billing should not have been created - it should be created later in the async job
            Integer bills = [SELECT COUNT() FROM Billing__c];
            Assert.areEqual(0, bills);
            
            // billing lines should not have been created - they should be created later in the async job
            Integer lines = [SELECT COUNT() FROM Billing_Line__c];
            Assert.areEqual(0, lines);

            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateBillingFromRecurringBillingLDOMultiLineWithHeaderUpdate() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createRecurringBilling()
            .createRecurringBillingLines();

        System.runAs(testData.users[1]) {
            Recurring_Billing__c selectedRecurringBilling = [SELECT Id, Last_Billing_Date__c, Next_Billing_Date__c, Total__c FROM Recurring_Billing__c WHERE Id = : testData.recurringBillings[0].Id];

            Test.startTest();
            testData.enableLDVMode();

            ApexPages.StandardController controller = new ApexPages.StandardController(selectedRecurringBilling);
            BillingFromRecurringBilling brb = new BillingFromRecurringBilling(controller);
            
            // edit header record to simulate UI update to Billing__c.Date__c field
            Billing__c obj = (Billing__c) brb.objList[0].obj;
            obj.Date__c = obj.Date__c.addDays(1);

            brb.createBilling();

            // the recurring billing should not have been updated - it should be updated later in the async job
            Recurring_Billing__c rBill = [SELECT Last_Billing_Date__c, Next_Billing_Date__c FROM Recurring_Billing__c WHERE Id = :selectedRecurringBilling.Id];
            Assert.areEqual(selectedRecurringBilling.Last_Billing_Date__c, rBill.Last_Billing_Date__c);
            Assert.areEqual(selectedRecurringBilling.Next_Billing_Date__c, rBill.Next_Billing_Date__c);
            
            // a billing should have been created
            List<Billing__c> bills = [SELECT Id, Total__c FROM Billing__c];
            Assert.areEqual(1, bills.size());
            Assert.areEqual(0, bills[0].Total__c);
            
            // billing lines should not have been created - they should be created later in the async job
            Integer lines = [SELECT COUNT() FROM Billing_Line__c];
            Assert.areEqual(0, lines);

            // transaction group should have been created to be picked up by async job
            List<Transaction_Group__c> txnGroups = [SELECT Billing__c, Recurring_Billing__c FROM Transaction_Group__c];
            Assert.areEqual(1, txnGroups.size());
            Assert.areEqual(bills[0].Id, txnGroups[0].Billing__c);
            Assert.areEqual(selectedRecurringBilling.Id, txnGroups[0].Recurring_Billing__c);

            Test.stopTest();
        }
    }

}