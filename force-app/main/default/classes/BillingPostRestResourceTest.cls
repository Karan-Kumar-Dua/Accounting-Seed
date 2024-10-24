@isTest
public class BillingPostRestResourceTest {

    @testSetup
    public static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    public static void testDoBillingsPostCreatePostedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostCreate();
            System.assertEquals(true, result.isSuccess);

            result = BillingPostRestResource.doBillingsPostCreate();
            System.assertEquals(false, result.isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_POSTED.name(), result.errors[0].statusCode);
        }

    }

    @isTest
    public static void testDoBillingsPostCreateNotApprovedError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();
        Billing__c billing = testData.billings[0];
        billing.Status__c = 'In Process';
        update billing;

        System.runAs(testData.users[1]) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + billing.Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            RestResult result = BillingPostRestResource.doBillingsPostCreate();
            Test.stopTest();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(PostResult.StatusCode.STATUS_NOT_APPROVED.name(), result.errors[0].statusCode);
        }

    }

    @isTest
    public static void testDoBillingsPostCreateNoControlAccountError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            delete [SELECT Id FROM GL_Account_Default__c WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT];
            GLAccountDefaultsHandler.instance = null;

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostCreate();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_CONTROL_AR_ACCOUNT_DEFINED.name(), result.errors[0].statusCode);
        }

    }

    @isTest
    public static void testDoBillingsPostCreateInvalidBilllingIdError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI =
                'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id + 'xxxxxx';
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            String errorMessage;
            try {
                RestResult result = BillingPostRestResource.doBillingsPostCreate();
            }
            catch (Exception ex) {
                errorMessage = ex.getMessage();
            }

            System.assertEquals(errorMessage, 'Record ID is invalid: ' + testData.billings[0].Id + 'xxxxxx');
        }

    }

    @isTest
    public static void testDoBillingsPostCreateNoBillingLinesError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            delete testData.billingLines;

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testBilling.Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostCreate();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(PostResult.StatusCode.NO_LINES.name(), result.errors[0].statusCode);
        }

    }

    @isTest
    public static void testDoBillingsPostClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostCreate();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD.name(), result.errors[0].statusCode);
        }

    }

    @isTest
    public static void testDoBillingsPostSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostCreate();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals(0, result.errors.size());
        }

    }

    @isTest
    public static void testDoBillingsPostDeleteBilllingIdError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Billing__c testBilling = testData.billings[0];
            testBilling.Status__c = 'Approved';
            update testBilling;

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testBilling.Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostCreate();
            System.assertEquals(true, result.isSuccess);
            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testBilling.Id].Status__c);

            req = new RestRequest();
            res = new RestResponse();

            req.requestURI =
                'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testBilling.Id + 'xxxxxx';
            req.httpMethod = 'DELETE';
            RestContext.request = req;
            RestContext.response = res;

            String errorMessage;
            try {
                result = BillingPostRestResource.doBillingsPostDelete();
            }
            catch (Exception ex) {
                errorMessage = ex.getMessage();
            }

            System.assertEquals(errorMessage, 'Record ID is invalid: ' + testBilling.Id + 'xxxxxx');
        }

    }

    @isTest
    public static void testDoBillingsPostDeleteUnpostedSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'DELETE';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostDelete();

            System.assertEquals(false, result.isSuccess);
            System.assertEquals(PostResult.StatusCode.ALREADY_UNPOSTED.name(), result.errors[0].statusCode);
        }

    }

    @isTest
    public static void testDoBillingsPostDeleteClosedAccountingPeriodError() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostCreate();
            System.assertEquals(true, result.isSuccess);

            AccountingPeriodActions.isFirstRun = false;
            testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
            update testData.acctPeriods[0];
            Test.stopTest();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'DELETE';
            RestContext.request = req;
            RestContext.response = res;

            result = BillingPostRestResource.doBillingsPostDelete();
            System.assertEquals(false, result.isSuccess);
            System.assertEquals(PostResult.StatusCode.CLOSED_ACCOUNTING_PERIOD.name(), result.errors[0].statusCode);
        }

    }

    @isTest
    public static void testDoBillingsPostDeleteBillingCashReceipt() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings().createCashReceipts();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;
            BillingPostRestResource.doBillingsPostCreate();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'DELETE';
            RestContext.request = req;
            RestContext.response = res;

            Billing_Cash_Receipt__c bcr = new Billing_Cash_Receipt__c();
            bcr.Billing__c = testData.billings[0].Id;
            bcr.Cash_Receipt__c = testData.cashReceipts[0].Id;
            bcr.Accounting_Period__c = testData.acctPeriods[1].Id;
            bcr.Applied_Amount__c = 2;
            insert bcr;

            RestResult result = BillingPostRestResource.doBillingsPostDelete();
            System.assertEquals(true, result.isSuccess);
        }

    }

    @isTest
    public static void testDoBillingsPostDeleteInvoiceCreditMemos() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            testData.billings[3].Status__c = 'Approved';
            update testData.billings[3];

            System.assertEquals(
                'Approved', [
                    SELECT Id, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c
            );

            System.assertEquals(
                'Approved', [
                    SELECT Id, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[3].Id
                ].Status__c
            );

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS, [
                    SELECT Id, Accounting_Period__r.Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Accounting_Period__r.Status__c
            );

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS, [
                    SELECT Id, Accounting_Period__r.Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[3].Id
                ].Accounting_Period__r.Status__c
            );

            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[0].Id]);
            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[3].Id]);

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            BillingPostRestResource.doBillingsPostCreate();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[3].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;
            BillingPostRestResource.doBillingsPostCreate();

            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[3].Id].Status__c);

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;

            insert bcm;

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'DELETE';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostDelete();

            System.assertEquals(true, result.isSuccess);
        }

    }

    @isTest
    public static void testDoBillingsPostDeleteCreditMemoCreditMemos() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            testData.billings[3].Status__c = 'Approved';
            update testData.billings[3];

            System.assertEquals(
                'Approved', [
                    SELECT Id, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Status__c
            );

            System.assertEquals(
                'Approved', [
                    SELECT Id, Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[3].Id
                ].Status__c
            );

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS, [
                    SELECT Id, Accounting_Period__r.Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[0].Id
                ].Accounting_Period__r.Status__c
            );

            System.assertEquals(
                AccountingPeriodActions.OPEN_STATUS, [
                    SELECT Id, Accounting_Period__r.Status__c
                    FROM Billing__c
                    WHERE Id = :testData.billings[3].Id
                ].Accounting_Period__r.Status__c
            );

            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[0].Id]);
            System.assertNotEquals(0, [SELECT count() FROM Billing_Line__c WHERE Billing__c = :testData.billings[3].Id]);

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            BillingPostRestResource.doBillingsPostCreate();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[3].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;

            BillingPostRestResource.doBillingsPostCreate();

            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);
            System.assertEquals('Posted', [SELECT Id, Status__c FROM Billing__c WHERE Id = :testData.billings[3].Id].Status__c);

            Billing_Credit_Memo__c bcm = new Billing_Credit_Memo__c();
            bcm.Billing_Invoice__c = testData.billings[0].Id;
            bcm.Billing_Credit_Memo__c = testData.billings[3].Id;
            bcm.Accounting_Period__c = testData.acctPeriods[0].Id;
            bcm.Amount__c = -10;
            insert bcm;

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[3].Id;
            req.httpMethod = 'DELETE';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostDelete();

            System.assertEquals(true, result.isSuccess);
        }

    }

    @isTest
    public static void testDoBillingsPostDeleteSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().createBillings();

        System.runAs(testData.users[1]) {
            Test.startTest();
            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'PUT';
            RestContext.request = req;
            RestContext.response = res;
            BillingPostRestResource.doBillingsPostCreate();

            req.requestURI = 'https://na9.salesforce.com/services/apexrest/v1.0/billing/post/' + testData.billings[0].Id;
            req.httpMethod = 'DELETE';
            RestContext.request = req;
            RestContext.response = res;

            RestResult result = BillingPostRestResource.doBillingsPostDelete();

            System.assertEquals(true, result.isSuccess);
            System.assertEquals(0, result.errors.size());
        }

    }
}