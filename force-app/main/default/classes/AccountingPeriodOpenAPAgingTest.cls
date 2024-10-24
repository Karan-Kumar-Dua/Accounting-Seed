@isTest
private class AccountingPeriodOpenAPAgingTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    // Test if the closed period is before the accounting period and no aging history record exits that the closed period is set to null
    @isTest
    private static void testAccountingPeriodOpenAPAgingClosedPeriodBeforePeriodSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createPayables()
            .createCashDisbursementBatches()
            .createCashDisbursements();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            testData.payables[0].Discount_Amount__c = 20;
            update testData.payables[0];

            List<AP_Aging_History__c> aahList = new List<AP_Aging_History__c>();

            for (Accounting_Period__c acctPeriod : testData.acctPeriods) {
                aahList.add(
                    new AP_Aging_History__c(
                        Accounting_Period__c = acctPeriod.Id,
                        Account_Payable__c = testData.payables.get(0).Id,
                        Amount__c = 2
                    )
                );
            }

            insert aahList;

            Cash_Disbursement__c testCashDisbursement = testData.cashDisbursements[5];
            testCashDisbursement.Status__c = 'Approved';
            testCashDisbursement.Amount__c = 200;
            update testCashDisbursement;

            AbstractPostHandler cdPostHandler = new CashDisbursementPostHandler();
            List<PostResult> cdPostResults = cdPostHandler.post(new List<Cash_Disbursement__c>{testCashDisbursement});

            System.assertEquals(
                true,
                cdPostResults.get(0).isSuccess
            );

            Accounting_Period__c period = testData.acctPeriods.get(3);

            AP_Disbursement__c newAPD = new AP_Disbursement__c(
                Account_Payable__c = testData.payables.get(0).Id,
                Cash_Disbursement__c = testCashDisbursement.Id,
                Paid_Amount__c = 145,
                Accounting_Period__c = period.Id
            );
            insert newAPD;

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Closed_Accounting_Period__c
            );

            AccountingPeriodOpenAPAging apb = new AccountingPeriodOpenAPAging(
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods.get(0)},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            Database.executeBatch(apb);

            Test.stopTest();

            System.assertEquals(
                period.Id,
                [SELECT Id, Closed_Accounting_Period__c FROM Account_Payable__c WHERE Id = :testData.payables.get(0).Id].Closed_Accounting_Period__c
            );
        }
    }

    @isTest
    private static void testAccountingPeriodOpenAPAgingSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            Test.startTest();

            List<AP_Aging_History__c> aahList = new List<AP_Aging_History__c>();

            for (Accounting_Period__c acctPeriod : testData.acctPeriods) {
                aahList.add(
                    new AP_Aging_History__c(
                        Accounting_Period__c = acctPeriod.Id,
                        Account_Payable__c = testData.payables.get(4).Id,
                        Amount__c = 2
                    )
                );
            }

            insert aahList;

            testData.payables.get(4).Closed_Accounting_Period__c = testData.acctPeriods.get(4).Id;
            update testData.payables.get(4);

            System.assertEquals(
                1,
                [SELECT count() FROM AP_Aging_History__c WHERE Accounting_Period__c = :testData.acctPeriods.get(4).Id]
            );

            AccountingPeriodOpenAPAging apb = new AccountingPeriodOpenAPAging(
                new AccountingPeriodOpenCloseOptions(
                    new List<Accounting_Period__c>{testData.acctPeriods.get(4)},
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.OPENING
                )
            );
            Database.executeBatch(apb);

            Test.stopTest();

            System.assertEquals(
                0,
                [SELECT COUNT() FROM AP_Aging_History__c WHERE Accounting_Period__c = :testData.acctPeriods.get(4).Id]
            );
        }
    }

    @isTest
    private static void testdeleteAPAgingOnSoftOpenSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        List < AP_Aging_History__c > aphList = new List < AP_Aging_History__c > ();
        List < Accounting_Period__c > newPeriods = new List < Accounting_Period__c > {
            testData.acctPeriods.get(0),
            testData.acctPeriods.get(1)
        };

        System.runAs(testData.users.get(1)) {
            for (Accounting_Period__c acctPeriod: newPeriods) {
                aphList.add(
                    new AP_Aging_History__c(
                        Accounting_Period__c = acctPeriod.Id,
                        Account_Payable__c = testData.payables.get(0).Id,
                        Amount__c = 2
                    )
                );
            }
            insert aphList;
            System.assertEquals(TRUE, [SELECT ID FROM AP_Aging_History__c WHERE Accounting_Period__c != null]?.size() > 0);
            System.assertEquals(TRUE, aphList[0].Accounting_Period__c == newPeriods.get(0).Id);
            System.assertEquals(TRUE, aphList[1].Accounting_Period__c == newPeriods.get(1).Id);
            System.assertEquals(TRUE, aphList[0].Account_Payable__c == testData.payables.get(0).Id);
            System.assertEquals(TRUE, aphList[1].Account_Payable__c == testData.payables.get(0).Id);


            Test.startTest();
            AccountingPeriodOpenAPAging apAging = new AccountingPeriodOpenAPAging(
                new AccountingPeriodOpenCloseOptions(
                    newPeriods,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.SOFT_OPEN
                )
            );
            Database.executeBatch(apAging);
            Test.stopTest();

            System.assertEquals(TRUE, [SELECT ID FROM AP_Aging_History__c]?.size() == 0);
        }
    }

    /*  The idea to have this test method is only to pass the coverage. 
        No assertions can be applied over here since it's referencing ERP fields.
    */
    @isTest
    private static void testCreateInventoryCreationOnHardClose() {
        TestDataSuite testData = TestDataSuite.getInstance();
        
        List < Accounting_Period__c > updatedPeriods = new List < Accounting_Period__c >();

        System.runAs(testData.users.get(1)) {
            for (Accounting_Period__c acctPeriod: new List<Accounting_Period__c>{testData.acctPeriods.get(0)}) {
                acctPeriod.Status__c = AccountingPeriodActions.CLOSED_STATUS;
                updatedPeriods.add(acctPeriod);
            }
            
            Test.startTest(); 
        
                    AccountingPeriodOpenCloseOptions periodInfoContainer =
                new AccountingPeriodOpenCloseOptions(
                    updatedPeriods,
                    0,
                    AccountingPeriodOpenCloseUtils.PeriodUpdateContext.CLOSING // context is soft open becoz AR_close is unchecked and status is open
                );

                AccountingPeriodOpenAPAging acountingPeriodCloseAPAging = new AccountingPeriodOpenAPAging(periodInfoContainer);
                Database.executeBatch(acountingPeriodCloseAPAging,1);  
            
            Test.stopTest();

            //assert the batch completed which will make a call to ERP.  There are tests in ERP for the actual creation of Inventory Histories
            List<AsyncApexJob> completedJobs = [SELECT ID, Status, MethodName, ApexClass.Name 
                                                FROM AsyncApexJob 
                                                WHERE ApexClass.Name = 'AccountingPeriodOpenAPAging' 
                                                AND Status = 'Completed' ];

            System.assertEquals(1, completedJobs.size());
        }
    }
}