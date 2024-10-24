@isTest
private class AccountingPeriodOpenBillingAgingTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    // Test if the closed period is before the accounting period and no aging history record exits that the closed period is set to null
    @isTest
    private static void testAccountingPeriodOpenBillingAgingClosedPeriodBeforePeriodSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createCashReceipts();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            Accounting_Period__c period = testData.acctPeriods.get(3);
            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c(
                Billing__c = testData.billings.get(0).Id,
                Cash_Receipt__c = testData.cashReceipts.get(1).Id,
                Applied_Amount__c = 450,
                Accounting_Period__c = period.Id
            );
            insert bcr;

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id =: testData.billings.get(0).Id].Closed_Accounting_Period__c
            );

            AccountingPeriodOpenBillingAging apb = new AccountingPeriodOpenBillingAging(
                new AccountingPeriodOpenCloseOptions(
                    new List < Accounting_Period__c > {
                        testData.acctPeriods.get(1)
                    },
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            Database.executeBatch(apb);

            Test.stopTest();

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Billing__c WHERE Id =: testData.billings.get(0).Id].Closed_Accounting_Period__c
            );
        }
    }

    @isTest
    private static void testAccountingPeriodOpenBillingAgingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createBillingAgingHistories();

        System.runAs(testData.users.get(1)) {
            delete testData.billingAgingHistories;

            List < Billing_Aging_History__c > bahList = new List < Billing_Aging_History__c > ();

            for (Accounting_Period__c acctPeriod: testData.acctPeriods) {
                bahList.add(
                    new Billing_Aging_History__c(
                        Accounting_Period__c = acctPeriod.Id,
                        Billing__c = testData.billings.get(0).Id,
                        Amount__c = 2
                    )
                );
            }

            insert bahList;

            testData.billings.get(0).Closed_Accounting_Period__c = testData.acctPeriods.get(4).Id;
            update testData.billings.get(0);

            Test.startTest();

            System.assertEquals(
                1,
                [SELECT COUNT() FROM Billing_Aging_History__c WHERE Accounting_Period__c =: testData.acctPeriods.get(4).Id]
            );

            AccountingPeriodOpenBillingAging apb = new AccountingPeriodOpenBillingAging(
                new AccountingPeriodOpenCloseOptions(
                    new List < Accounting_Period__c > {
                        testData.acctPeriods.get(4)
                    },
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            Database.executeBatch(apb);

            Test.stopTest();

            System.assertEquals(
                0,
                [SELECT COUNT() FROM Billing_Aging_History__c WHERE Accounting_Period__c =: testData.acctPeriods.get(4).Id]
            );
        }
    }

    @isTest
    private static void testdeleteARAgingOnSoftOpenSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        List < Billing_Aging_History__c > bahList = new List < Billing_Aging_History__c > ();
        List < Accounting_Period__c > newPeriods = new List < Accounting_Period__c > {
            testData.acctPeriods.get(0),
            testData.acctPeriods.get(1)
        };

        System.runAs(testData.users.get(1)) {
            for (Accounting_Period__c acctPeriod: newPeriods) {
                bahList.add(
                    new Billing_Aging_History__c(
                        Accounting_Period__c = acctPeriod.Id,
                        Billing__c = testData.billings.get(0).Id,
                        Amount__c = 2
                    )
                );
            }
            insert bahList;
            System.assertEquals(TRUE, [SELECT ID FROM Billing_Aging_History__c WHERE Accounting_Period__c != null]?.size() > 0);
            System.assertEquals(TRUE, bahList[0].Accounting_Period__c == newPeriods.get(0).Id);
            System.assertEquals(TRUE, bahList[1].Accounting_Period__c == newPeriods.get(1).Id);

            Test.startTest();
            AccountingPeriodOpenBillingAging apb = new AccountingPeriodOpenBillingAging(
                new AccountingPeriodOpenCloseOptions(
                    newPeriods,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_OPEN
                )
            );
            Database.executeBatch(apb);
            Test.stopTest();

            System.assertEquals(TRUE, [SELECT ID FROM Billing_Aging_History__c]?.size() == 0);
        }
    }

}