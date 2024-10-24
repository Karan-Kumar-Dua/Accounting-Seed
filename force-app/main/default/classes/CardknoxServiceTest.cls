@IsTest
public with sharing class CardknoxServiceTest {
    public class MockTransactionResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', 'xkey');
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"CustomerId" : "c11844844","Amount":"1","GatewayRefNum":"1234","GatewayStatus":"S"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockGetTransactionResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', 'xkey');
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"TransactionId" : "c11844844","GatewayRefNum":"1234","GatewayStatus":"S"}');
            res.setStatusCode(200);
            return res;
        }
    }
    public class MockGatewayResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Authorization', 'xkey');
            res.setHeader('X-Recurring-Api-Version', '2.0');
            res.setBody('{"xCommand" : "cc:sale","xToken":"1234","xAmount":"2.0","xRefNum":"1234","xStatus":"Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }
    @IsTest
    public static void testGetTransaction() {
        Test.setMock(HttpCalloutMock.class, new MockGetTransactionResponse());
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users.get(1)) {
            Payment_Processor__c pp = [SELECT Id, External_Key__c FROM Payment_Processor__c Where Type__c = 'Cardknox' Limit 1];

            Test.startTest();
            CardknoxService.PaymentTransaction pgt = CardknoxService.getTransaction('c11844844',pp);
            Test.stopTest();

            System.assertEquals('1234',pgt.GatewayRefNum);
            System.assertEquals('S',pgt.GatewayStatus);
        }
    }

    @IsTest
    static void testDateConversionLongForm() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // test same day AM
            CardknoxService.DateTimeParser est = new CardknoxService.LongFormDateTimeParser('2/28/2023 11:55:24 AM'); // 28 Feb 2023 11:55:24 EST
            Datetime utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 16, 55, 24), utc);
            Assert.areEqual('2023-02-28 11:55:24', CardknoxService.toEST(utc));


             // test same day PM
             est = new CardknoxService.LongFormDateTimeParser('2/28/2023 1:55:24 PM'); // 28 Feb 2023 13:55:24 EST
             utc = CardknoxService.toUTC(est);
             Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 18, 55, 24), utc);
             Assert.areEqual('2023-02-28 13:55:24', CardknoxService.toEST(utc));

            // test noon
            est = new CardknoxService.LongFormDateTimeParser('2/28/2023 12:55:24 PM'); // 28 Feb 2023 12:55:24 EST
            utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 17, 55, 24), utc);
            Assert.areEqual('2023-02-28 12:55:24', CardknoxService.toEST(utc));

            // test midnight
            est = new CardknoxService.LongFormDateTimeParser('2/28/2023 12:55:24 AM'); // 28 Feb 2023 00:55:24 EST
            utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 5, 55, 24), utc);
            Assert.areEqual('2023-02-28 00:55:24', CardknoxService.toEST(utc));

            // test next/previous day and year
            est = new CardknoxService.LongFormDateTimeParser('12/31/2022 10:15:07 PM'); // 31 Dec 2022 22:15:07 EST
            utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 1, 1, 3, 15, 7), utc);
            Assert.areEqual('2022-12-31 22:15:07', CardknoxService.toEST(utc));
        }
    }

    @IsTest
    static void testDateConversionShortForm() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // test same day AM
            CardknoxService.DateTimeParser est = new CardknoxService.ShortFormDateTimeParser('2/28/2023 11:55 AM'); // 28 Feb 2023 11:55 EST
            Datetime utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 16, 55, 0), utc);
            Assert.areEqual('2023-02-28 11:55:00', CardknoxService.toEST(utc));


             // test same day PM
             est = new CardknoxService.ShortFormDateTimeParser('2/28/2023 1:55 PM'); // 28 Feb 2023 13:55 EST
             utc = CardknoxService.toUTC(est);
             Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 18, 55, 0), utc);
             Assert.areEqual('2023-02-28 13:55:00', CardknoxService.toEST(utc));

            // test noon
            est = new CardknoxService.ShortFormDateTimeParser('2/28/2023 12:55 PM'); // 28 Feb 2023 12:55 EST
            utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 17, 55, 0), utc);
            Assert.areEqual('2023-02-28 12:55:00', CardknoxService.toEST(utc));

            // test midnight
            est = new CardknoxService.ShortFormDateTimeParser('2/28/2023 12:55 AM'); // 28 Feb 2023 00:55 EST
            utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 2, 28, 5, 55, 0), utc);
            Assert.areEqual('2023-02-28 00:55:00', CardknoxService.toEST(utc));

            // test next/previous day and year
            est = new CardknoxService.ShortFormDateTimeParser('12/31/2022 10:15 PM'); // 31 Dec 2022 22:15 EST
            utc = CardknoxService.toUTC(est);
            Assert.areEqual(Datetime.newInstanceGmt(2023, 1, 1, 3, 15, 0), utc);
            Assert.areEqual('2022-12-31 22:15:00', CardknoxService.toEST(utc));
        }
    }

    @IsTest
    static void testDefaultReportingCurrency() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String str = '{"xCurrency": ""}';
            CardknoxService.ReportData data = (CardknoxService.ReportData) JSON.deserialize(str, CardknoxService.ReportData.class);
            Assert.areEqual(MultiCurrencyHandler.CORPORATE_CURRENCY, data.xCurrency);

            str = '{}';
            data = (CardknoxService.ReportData) JSON.deserialize(str, CardknoxService.ReportData.class);
            Assert.areEqual(MultiCurrencyHandler.CORPORATE_CURRENCY, data.xCurrency);

            str = '{"xCurrency": "INR"}';
            data = (CardknoxService.ReportData) JSON.deserialize(str, CardknoxService.ReportData.class);
            Assert.areEqual('INR', data.xCurrency);
        }
    }

}