@IsTest
public class BillingFromTimeCardTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testTimeCardNoSelection() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards();

        System.runAs(testData.users[1]) {
            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);
            System.assertEquals(BillingFromTimeCard.NO_SELECTION_ERROR_MESSAGE, ApexPages.getMessages()[0].getDetail());
        }
    }

    @IsTest
    public static void testHandleDmlAndSecurityErrorOnBillingCreation() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        ApexPages.StandardSetController setController;
        BillingFromTimeCard bftc;

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            update testData.timeCards;

            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
                tcl.Billed__c = false;
                tcl.Overtime__c = true;
            }

            update testData.timeCardLines;

            setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());

            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);
            tcp.post();

            for (Time_Card__c tc : [SELECT Id, Status__c FROM Time_Card__c WHERE Id IN :testData.timeCards]) {
                System.assertEquals('Posted', tc.Status__c);
            }

            bftc = new BillingFromTimeCard(setController);
            bftc.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bftc.bill.Accounting_Period__c = testData.acctPeriods[0].Id;
            bftc.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bftc.bill.Billing_Cycle_Start_Date__c = bftc.bill.Date__c;
            bftc.bill.Billing_Cycle_End_Date__c = bftc.bill.Date__c + 30;

            Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(testData.ledgers[0].Id);
            for (BillingFromTimeCard.TimeCardWrapper item : bftc.timeCardWrapperList) {
                for (BillingFromTimeCard.TimeCardLineWrapper line : item.timeCardLineList) {
                    line.glAccountBillLine.Revenue_GL_Account__c = defaultsBySpecDevNames?.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c;
                }
            }

            DmlException dmlEx;
            try {
                bftc.createBillings();
            } catch (DmlException ex) {
                dmlEx = ex;
            }

            System.assertEquals(NULL, dmlEx);//Dml Exception will be handled by page controller
            System.assertEquals(GLAccountValidator.cumulativeErrorMessage, ApexPages.getMessages()[1].getSummary());

            for (BillingFromTimeCard.TimeCardWrapper item : bftc.timeCardWrapperList) {
                for (BillingFromTimeCard.TimeCardLineWrapper line : item.timeCardLineList) {
                    line.glAccountBillLine.Revenue_GL_Account__c = testData.glAccounts[5].Id;
                }
            }

            //change profile of the Admin user from System Administrator to Standard User
            Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
            User user = [SELECT Id, ProfileId FROM User WHERE Id = : testData.users[0].Id];
            user.ProfileId = profile.Id;
            update user;
        }

        //try to execute controller's method under Standard User (without necessary permissions)
        System.runAs(testData.users[0]) {
            SFDCSecurityUtils.SecurityException securityException;
            try {
                bftc.createBillings();
            } catch (SFDCSecurityUtils.SecurityException ex) {
                securityException = ex;
            }

            System.assertEquals(NULL, securityException);
            System.assertEquals(String.format(
                SFDCSecurityUtils.CRUD_ERROR,
                new List<String>{
                    'Create',
                    'Billing'
                }
            ), ApexPages.getMessages()[2].getSummary());
        }
    }
    
    @IsTest
    public static void testGetBillingRates() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            //Set CreatedDate field for all Billing Rates created by TestDataSuite.initialize() method
            //It is possible after SF Spring 16 release
            Integer daysBeforeToday = testData.billingRates.size();
            for (Billing_Rates__c testBr : testData.billingRates) {
                Test.setCreatedDate(testBr.Id, Datetime.now().addDays(-1 * daysBeforeToday));
                daysBeforeToday--;
            }

            Test.startTest();

            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            update testData.timeCards;

            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
            }
            //TestDataSuite.timeCardLines
            update testData.timeCardLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);
            tcp.post();

            for (Time_Card__c tc : [SELECT Id, Status__c FROM Time_Card__c WHERE Id IN :testData.timeCards]) {
                System.assertEquals('Posted', tc.Status__c);
            }

            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);

            System.assertEquals(
                true,
                bftc.billingRates.containsKey(String.valueOf(testData.timeCardLines[0].Project_Task__c) +
                    String.valueOf(UserInfo.getUserId()))
            );

            setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            bftc = new BillingFromTimeCard(setController);

            System.assertEquals(
                true,
                bftc.billingRates.containsKey(String.valueOf(testData.timeCardLines[0].Project__c) +
                    String.valueOf(UserInfo.getUserId()))
            );
            //billingRates[5] is the most recent billing rate in this case
            System.assertEquals(
                testData.billingRates[5].Amount__c,
                bftc.billingRates.get(
                    String.valueOf(testData.timeCardLines[0].Project__c) + String.valueOf(UserInfo.getUserId())
                ).Amount__c
            );
        }

    }

    @IsTest
    public static void testGetBillingRatesForOvertime() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            //Set CreatedDate field for all Billing Rates created by TestDataSuite.initialize() method
            //It is possible after SF Spring 16 release
            for (Billing_Rates__c testBr : testData.billingRates) {
                Test.setCreatedDate(testBr.Id, Datetime.now().addDays(-5));//all Billing Rates are in the past
            }
            //Move Billing Rate record with non-empty Overtime_Labor_Billing_Rate__c field to most recent
            Billing_Rates__c testBR = testData.billingRates[6];
            Test.setCreatedDate(testBR.Id, Datetime.now());

            Test.startTest();

            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            update testData.timeCards;

            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
                tcl.Overtime__c = true;
            }

            update testData.timeCardLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);
            tcp.post();

            for (Time_Card__c tc : [SELECT Id, Status__c FROM Time_Card__c WHERE Id IN :testData.timeCards]) {
                System.assertEquals('Posted', tc.Status__c);
            }

            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);

            System.assertEquals(
                true,
                bftc.billingRates.containsKey(
                    String.valueOf(testData.timeCardLines[0].Project_Task__c) + String.valueOf(UserInfo.getUserId())
                )
            );

            setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            bftc = new BillingFromTimeCard(setController);

            System.assertEquals(
                true,
                bftc.billingRates.containsKey(
                    String.valueOf(testData.timeCardLines[0].Project_Task__c) + String.valueOf(UserInfo.getUserId())
                )
            );

            System.assertEquals(
                testBR.Overtime_Labor_Billing_Rate__c,
                bftc.billingRates.get(
                    String.valueOf(testData.timeCardLines[1].Project_Task__c) + String.valueOf(UserInfo.getUserId())
                ).Overtime_Labor_Billing_Rate__c
            );
        }

    }

    @IsTest
    public static void testCreateBillingsFromOvertime() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            //Set CreatedDate field for all Billing Rates created by TestDataSuite.initialize() method
            //It is possible after SF Spring 16 release
            for (Billing_Rates__c testBr : testData.billingRates) {
                Test.setCreatedDate(testBr.Id, Datetime.now().addDays(-5));//all Billing Rates are in the past
            }
            //Move Billing Rate record with non-empty Overtime_Labor_Billing_Rate__c field to most recent
            Billing_Rates__c testBR = testData.billingRates[6];
            Test.setCreatedDate(testBR.Id, Datetime.now());

            Test.startTest();

            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            update testData.timeCards;

            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
                tcl.Billed__c = false;
                tcl.Overtime__c = true;
            }
            update testData.timeCardLines;

            //Check existed Billings
            Map<Id, Billing__c> existedBillingsMap = new Map<Id, Billing__c>([SELECT Id FROM Billing__c LIMIT 100]);

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);
            tcp.post();

            for (Time_Card__c tc : [SELECT Id, Status__c FROM Time_Card__c WHERE Id IN :testData.timeCards]) {
                System.assertEquals('Posted', tc.Status__c);
            }

            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);

            Decimal amountWithoutOvertime = 0;
            //need to summarize total Time Card Lines Amount not taken Overtime flag into consideration
            for (Time_Card__c tc : [SELECT Total_Hours__c FROM Time_Card__c LIMIT 100]) {
                amountWithoutOvertime += tc.Total_Hours__c * testData.billingRates[6].Amount__c;
            }
            //and then compare that value with real total for Time Card Lines which were marked with Overtime flag
            for (BillingFromTimeCard.TimeCardWrapper tcWrapper : bftc.timeCardWrapperList) {
                //expected: value calculated above must be less than real Overtimed value
                System.assertEquals(true, tcWrapper.getAmount() > amountWithoutOvertime);
            }

            bftc.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bftc.bill.Accounting_Period__c = testData.acctPeriods[0].Id;
            bftc.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bftc.bill.Billing_Cycle_Start_Date__c = bftc.bill.Date__c;
            bftc.bill.Billing_Cycle_End_Date__c = bftc.bill.Date__c + 30;
            bftc.createBillings();

            System.assertEquals(true, bftc.isSuccess);

            for (Time_Card_Line__c tcl : [SELECT Id,
                                                 Billed__c,
                                                 (SELECT Id, Billing_Line__c FROM Time_Card_Days__r)
                                          FROM Time_Card_Line__c
                                          WHERE Id IN :testData.timeCardLines
            ]) {

                System.assertEquals(true, tcl.Billed__c);

                for (Time_Card_Day__c tcd : tcl.Time_Card_Days__r) {
                    System.assertNotEquals(NULL, tcd.Billing_Line__c);
                }
            }

            List<Billing__c> newBillings = [
                SELECT  Id,
                        (SELECT Id, Rate__c FROM Project_Billing_Lines__r)
                FROM Billing__c
                WHERE Id NOT IN :existedBillingsMap.keySet() LIMIT 100
            ];
            System.assertEquals(false, newBillings.isEmpty());
            System.assertEquals(testBR.Overtime_Labor_Billing_Rate__c, newBillings[0].Project_Billing_Lines__r[0].Rate__c);
        }

    }

    @IsTest
    public static void testCreateBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            update testData.timeCards;

            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
                tcl.Billed__c = false;
                tcl.Overtime__c = true;
            }

            update testData.timeCardLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);
            tcp.post();

            for (Time_Card__c tc : [SELECT Id, Status__c FROM Time_Card__c WHERE Id IN :testData.timeCards]) {
                System.assertEquals('Posted', tc.Status__c);
            }

            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);
            bftc.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bftc.bill.Accounting_Period__c = testData.acctPeriods[0].Id;
            bftc.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bftc.bill.Billing_Cycle_Start_Date__c = bftc.bill.Date__c;
            bftc.bill.Billing_Cycle_End_Date__c = bftc.bill.Date__c + 30;
            bftc.createBillings();

            System.assertEquals(true, bftc.isSuccess);

            for (Time_Card_Line__c tcl : [SELECT Id,
                                                 Billed__c,
                                                (SELECT Id, Billing_Line__c
                                                    FROM Time_Card_Days__r)
                                          FROM Time_Card_Line__c
                                          WHERE Id IN :testData.timeCardLines
            ]) {

                System.assertEquals(true, tcl.Billed__c);

                for (Time_Card_Day__c tcd : tcl.Time_Card_Days__r) {
                    System.assertNotEquals(NULL, tcd.Billing_Line__c);
                }
            }
        }

    }

    @IsTest
    public static void testCreateBillingsAndPost() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            update testData.timeCards;

            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
                tcl.Billed__c = false;
                tcl.Overtime__c = true;
            }

            update testData.timeCardLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);
            tcp.post();

            for (Time_Card__c tc : [SELECT Id, Status__c FROM Time_Card__c WHERE Id IN :testData.timeCards]) {
                System.assertEquals('Posted', tc.Status__c);
            }

            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);
            bftc.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bftc.bill.Accounting_Period__c = testData.acctPeriods[0].Id;
            bftc.bill.Billing_Format__c = testData.billingFormats[0].Id;
            bftc.bill.Billing_Cycle_Start_Date__c = bftc.bill.Date__c;
            bftc.bill.Billing_Cycle_End_Date__c = bftc.bill.Date__c + 30;
            bftc.createBillingAndPost();

            System.assertEquals(true, bftc.isSuccess);

            for (Time_Card_Line__c tcl : [
                    SELECT  Id,
                            Billed__c,
                            (SELECT Id,
                                   Billing_Line__c,
                                   Billing_Line__r.Billing__r.Status__c
                                FROM Time_Card_Days__r)
                    FROM Time_Card_Line__c
                    WHERE Id IN :testData.timeCardLines
            ]
            ) {
                System.assertEquals(true, tcl.Billed__c);
                for (Time_Card_Day__c tcd : tcl.Time_Card_Days__r) {
                    System.assertEquals('Posted', tcd.Billing_Line__r.Billing__r.Status__c);
                }
            }
        }

    }

    @IsTest
    public static void testCreateBillingsDifferentLedgers() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        System.runAs(testData.users[1]) {
            Test.startTest();
            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            testData.timeCards[0].Ledger__c = testData.ledgers[0].Id;
            testData.timeCards[1].Ledger__c = testData.ledgers[2].Id;
            update testData.timeCards;

            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
                tcl.Billed__c = false;
                tcl.Overtime__c = true;
            }

            update testData.timeCardLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());
            TimeCardPostTransaction tcp = new TimeCardPostTransaction(setController);
            tcp.post();

            for (Time_Card__c tc : [SELECT Id, Status__c FROM Time_Card__c WHERE Id IN :testData.timeCards]) {
                System.assertEquals('Posted', tc.Status__c);
            }

            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);
            bftc.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bftc.bill.Accounting_Period__c = testData.acctPeriods[0].Id;
            bftc.bill.Billing_Cycle_Start_Date__c = bftc.bill.Date__c;
            bftc.bill.Billing_Cycle_End_Date__c = bftc.bill.Date__c + 30;
            bftc.createBillings();

            System.assertEquals(true, bftc.isSuccess);
            System.assertEquals(2, bftc.timeCardWrapperList.size());
            Test.stopTest();
        }
    }

    @IsTest
    public static void testCreateSoftARCloseBillings() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createProjects()
            .createProjectTasks()
            .createTimeCards()
            .createBillingRates();

        System.runAs(testData.users[1]) {

            List<Accounting_Period__c> acctPeriods = [Select id, Close_AR__c, Start_Date__c From Accounting_Period__c 
                                                    WHERE Start_Date__c =: Date.newInstance(1991, 10, 1)];
            acctPeriods[0].Close_AR__c = true;
            UPDATE acctPeriods[0]; 

            for (Time_Card__c tc : testData.timeCards) {
                tc.Status__c = 'Approved';
            }
            for (Time_Card_Line__c tcl : testData.timeCardLines) {
                tcl.Billable__c = true;
                tcl.Billed__c = false;
                tcl.Overtime__c = true;
            }

            update testData.timeCardLines;

            ApexPages.StandardSetController setController = new ApexPages.StandardSetController(testData.timeCards);
            setController.setSelected(setController.getRecords());

            BillingFromTimeCard bftc = new BillingFromTimeCard(setController);
            bftc.bill.Date__c = testData.acctPeriods[0].Start_Date__c.addDays(3);
            bftc.bill.Billing_Cycle_Start_Date__c = bftc.bill.Date__c;
            bftc.bill.Billing_Cycle_End_Date__c = bftc.bill.Date__c + 30;
            bftc.createBillingAndPost();

            System.assertEquals(FALSE, bftc.isSuccess);
            System.assertEquals(NULL, bftc.bill.Accounting_Period__c);
        }
    }

}