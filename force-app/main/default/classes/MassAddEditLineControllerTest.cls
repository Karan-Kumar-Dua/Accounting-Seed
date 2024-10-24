@isTest
private class MassAddEditLineControllerTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    
    @isTest static void testInitPositive() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            System.currentPageReference().getParameters().put('Id', testData.payables.get(0).Id);
            MassAddEditLineController cnt = new MassAddEditLineController(new ApexPages.StandardSetController(testData.payableLines));
            System.assertEquals(cnt.masterRecord.Id, testData.payables.get(0).Id);
        }

    }

    @isTest static void testInitNegativeId() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            MassAddEditLineController cnt = new MassAddEditLineController(new ApexPages.StandardSetController(testData.payableLines));
            System.assertEquals(true, cnt.isError);
        }

    }

    @isTest static void testInitNegativeStatus() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            testData.payables[4].Status__c = 'Approved';
            testData.payables[4].Accounting_Period__c = testData.acctPeriods[4].Id;
            update testData.payables[4];

            ApexPages.StandardController cont = new ApexPages.StandardController([
                SELECT Accounting_Period__r.Status__c, Status__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables[4].Id
            ]);
            AccountPayablePostTransaction pbt = new AccountPayablePostTransaction(cont);
            pbt.post();

            System.currentPageReference().getParameters().put('Id', testData.payables[4].Id);
            MassAddEditLineController cnt = new MassAddEditLineController(new ApexPages.StandardSetController(testData.payableLines));
            System.assertEquals(true, cnt.isRecordPosted);
        }

    }

    @isTest static void testInitNegativeMasterRecord() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users.get(1)) {
            System.currentPageReference().getParameters().put('Id', testData.payables[0].Id);
            AbstractPostHandler apdPostHandler = new APDisbursementPostHandler();
            delete testData.payables[0];
            MassAddEditLineController cnt = new MassAddEditLineController(new ApexPages.StandardSetController(testData.payableLines));

            System.assertEquals(true, cnt.isError);
        }

    }
}