@IsTest
public class PaymentLinkTest {

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true, true);
    }

    @IsTest
    public static void testGetUrlPositive() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            String maxLengthUsername = 'U79aBwa6KQuuwSf8niTpfvWy28VeCwnWkevJ97SHwUeSFANmZ5gNPaANA4nZrDEgwmK47TAdAqh9jtAQ';

            AccountingSettingsHandler.acctSeedSettings = NULL;
            PaymentLink.paymentLinkEnabled = NULL;
            testData.settings.Payment_Link_Username__c = maxLengthUsername;
            update testData.settings;

            External_Settings__mdt exSetting = [
                SELECT Value_1__c, Value_2__c
                FROM External_Settings__mdt
                WHERE DeveloperName = 'Payment_Link_Settings'
            ];
            Blob key = EncodingUtil.base64Decode(exSetting.Value_2__c);

            Test.startTest();

            Payment_Processor__c testProcessor =  new Payment_Processor__c(
                    Type__c = 'Stripe',
                    Active__c = true,
                    Connected_Account_Token__c = 'acct_8ux2oinmlksnuogwvr'
            );

            insert testProcessor;

            Billing__c testBilling = new Billing__c(
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'In Process',
                Payment_Processor__c = testProcessor.Id
            );

            insert testBilling;

            PaymentLink.PaymentLinkJSON js = new PaymentLink.PaymentLinkJSON(maxLengthUsername, testBilling.Id, UserInfo.getDefaultCurrency());

            String paymentLinkUrl = PaymentLink.getUrl(testBilling.Id);

            String result = paymentLinkUrl.removeStart(exSetting.Value_1__c + '/v2/payment/');
            Blob b64decrypted = EncodingUtil.base64Decode(EncodingUtil.urlDecode(result, 'UTF-8'));
            String finalResult = b64decrypted.toString();

            System.assertEquals(JSON.serialize(js), finalResult);
        }

    }

    @IsTest
    public static void testIsEnabledNegative() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            AccountingSettingsHandler.acctSeedSettings = NULL;
            testData.settings.Payment_Link_Username__c = NULL;
            update testData.settings;

            Billing__c testBilling = new Billing__c(
                Customer__c = testData.accounts[0].Id,
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Status__c = 'In Process'
            );

            insert testBilling;

            PaymentLink.PaymentLinkException exc;

            try {
                PaymentLink pl = new PaymentLink(testBilling.Id);
            }
            catch (PaymentLink.PaymentLinkException ex) {
                exc = ex;
            }
            update testBilling;
            System.assertEquals(PaymentLink.PAYMENT_LINK_NOT_ENABLED_ERROR_MESSAGE, exc.getMessage());
        }

    }

    @IsTest 
    private static void base64UrlEncodePlus() {
        Blob input = Blob.valueOf('6~hjk');
        String b64 = EncodingUtil.base64Encode(input);
        String b64url = PaymentLink.base64UrlEncode(input);

        System.assertEquals('AzZ+aGpr', b64);
        System.assertEquals('AzZ-aGpr', b64url);
    }

    @IsTest 
    private static void base64UrlEncodeSlash() {
        Blob input = Blob.valueOf('ABCD??ABC');
        String b64 = EncodingUtil.base64Encode(input);
        String b64url = PaymentLink.base64UrlEncode(input);

        System.assertEquals('QUJDRD8/QUJD', b64);
        System.assertEquals('QUJDRD8_QUJD', b64url);
    }

    @IsTest 
    private static void base64UrlEncodeEquals() {
        Blob input = Blob.valueOf('ABCD');
        String b64 = EncodingUtil.base64Encode(input);
        String b64url = PaymentLink.base64UrlEncode(input);

        System.assertEquals('QUJDRA==', b64);
        System.assertEquals('QUJDRA', b64url);
    }

    @IsTest
    public static void testPaymentLinkCardknox() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
			Test.startTest();
			testData.billings[0].Payment_Processor__c = testData.paymentProcessors[2].Id;
            testData.billings[0].Billing_Contact__c = testData.contacts[0].Id;
            testData.billings[0].Shipping_Contact__c = testData.contacts[0].Id;
            testData.billings[0].Billing_Comment__c = 'Test';
            testData.billings[0].PO_Number__c = '1234';
            update  testData.billings[0];

            //Update billing to get payment link.
			update  testData.billings[0];
            Billing__c testBilling = [SELECT Id, Payment_Site_URL__c, Billing_Contact__r.FirstName, Balance__c , Payment_Processor__c, Billing_Contact__r.LastName, Customer__c, Customer__r.Name, Customer__r.Phone, Billing_Contact__r.MobilePhone, Billing_Contact__r.Email, Billing_City__c, Billing_State__c, Billing_Street__c, Billing_PostalCode__c, Billing_Country__c, Shipping_Contact__r.FirstName, Shipping_Contact__r.LastName, Shipping_Contact__r.MobilePhone, Shipping_Contact__r.Email, Shipping_City__c, Shipping_State__c, Shipping_Street__c, Shipping_PostalCode__c, Shipping_Country__c, Total__c, Name, PO_Number__c, Billing_Comment__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            System.assert(testBilling.Payment_Site_URL__c != NULL);
            System.assert(testBilling.Payment_Site_URL__c.contains(testData.paymentProcessors[2].PaymentSite_URL__c + '?xInvoice=' + EncodingUtil.urlEncode(testBilling.Name, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillFirstName=' +  EncodingUtil.urlEncode(testBilling.Billing_Contact__r.FirstName, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillCompany=' + EncodingUtil.urlEncode(testBilling.Customer__r.Name, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillStreet=' + EncodingUtil.urlEncode(testBilling.Billing_Street__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillCity=' + EncodingUtil.urlEncode(testBilling.Billing_City__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillState=' + EncodingUtil.urlEncode(testBilling.Billing_State__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillZip=' + EncodingUtil.urlEncode(testBilling.Billing_PostalCode__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillCountry=' + EncodingUtil.urlEncode(testBilling.Billing_Country__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipFirstName=' + EncodingUtil.urlEncode(testBilling.Shipping_Contact__r.FirstName, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipLastName=' + EncodingUtil.urlEncode(testBilling.Shipping_Contact__r.LastName, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipCompany=' + EncodingUtil.urlEncode(testBilling.Customer__r.Name, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipStreet=' + EncodingUtil.urlEncode(testBilling.Shipping_Street__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipState=' + EncodingUtil.urlEncode(testBilling.Shipping_State__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipCity=' + EncodingUtil.urlEncode(testBilling.Shipping_City__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipZip=' + EncodingUtil.urlEncode(testBilling.Shipping_PostalCode__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipCountry=' + EncodingUtil.urlEncode(testBilling.Shipping_Country__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xCustom18=' + EncodingUtil.urlEncode(String.valueOf(testBilling.Balance__c), 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xPONum=' + EncodingUtil.urlEncode(testBilling.PO_Number__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xDescription=' + EncodingUtil.urlEncode(testBilling.Billing_Comment__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xCustom19=' + EncodingUtil.urlEncode(testBilling.Id, 'UTF-8')));
            Test.stopTest();
        }
    }
    @IsTest
    public static void testPaymentLinkCardknoxWithPartialPaymentUncheck() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createBillings()
            .createPaymentProcessors();

        System.runAs(testData.users[1]) {
            testData.paymentProcessors[2].Enable_PaymentSITE_Partial_Payment__c = false;
            update testData.paymentProcessors[2];
			Test.startTest();
			testData.billings[0].Payment_Processor__c = testData.paymentProcessors[2].Id;
            testData.billings[0].Billing_Contact__c = testData.contacts[0].Id;
            testData.billings[0].Shipping_Contact__c = testData.contacts[0].Id;
            testData.billings[0].Billing_Comment__c = 'Test';
            testData.billings[0].PO_Number__c = '1234';
            update  testData.billings[0];

            //Update billing to get payment link.
			update  testData.billings[0];
            Billing__c testBilling = [SELECT Id, Payment_Site_URL__c, Billing_Contact__r.FirstName, Balance__c , Payment_Processor__c, Billing_Contact__r.LastName, Customer__c, Customer__r.Name, Customer__r.Phone, Billing_Contact__r.MobilePhone, Billing_Contact__r.Email, Billing_City__c, Billing_State__c, Billing_Street__c, Billing_PostalCode__c, Billing_Country__c, Shipping_Contact__r.FirstName, Shipping_Contact__r.LastName, Shipping_Contact__r.MobilePhone, Shipping_Contact__r.Email, Shipping_City__c, Shipping_State__c, Shipping_Street__c, Shipping_PostalCode__c, Shipping_Country__c, Total__c, Name, PO_Number__c, Billing_Comment__c FROM Billing__c WHERE Id = :testData.billings[0].Id LIMIT 1];
            System.assert(testBilling.Payment_Site_URL__c != NULL);
            System.assert(testBilling.Payment_Site_URL__c.contains(testData.paymentProcessors[2].PaymentSite_URL__c + '?xInvoice=' + EncodingUtil.urlEncode(testBilling.Name, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillFirstName=' +  EncodingUtil.urlEncode(testBilling.Billing_Contact__r.FirstName, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillCompany=' + EncodingUtil.urlEncode(testBilling.Customer__r.Name, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillStreet=' + EncodingUtil.urlEncode(testBilling.Billing_Street__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillCity=' + EncodingUtil.urlEncode(testBilling.Billing_City__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillState=' + EncodingUtil.urlEncode(testBilling.Billing_State__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillZip=' + EncodingUtil.urlEncode(testBilling.Billing_PostalCode__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xBillCountry=' + EncodingUtil.urlEncode(testBilling.Billing_Country__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipFirstName=' + EncodingUtil.urlEncode(testBilling.Shipping_Contact__r.FirstName, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipLastName=' + EncodingUtil.urlEncode(testBilling.Shipping_Contact__r.LastName, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipCompany=' + EncodingUtil.urlEncode(testBilling.Customer__r.Name, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipStreet=' + EncodingUtil.urlEncode(testBilling.Shipping_Street__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipState=' + EncodingUtil.urlEncode(testBilling.Shipping_State__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipCity=' + EncodingUtil.urlEncode(testBilling.Shipping_City__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipZip=' + EncodingUtil.urlEncode(testBilling.Shipping_PostalCode__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xShipCountry=' + EncodingUtil.urlEncode(testBilling.Shipping_Country__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xAmount=' + EncodingUtil.urlEncode(String.valueOf(testBilling.Balance__c), 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xPONum=' + EncodingUtil.urlEncode(testBilling.PO_Number__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xDescription=' + EncodingUtil.urlEncode(testBilling.Billing_Comment__c, 'UTF-8')));
            System.assert(testBilling.Payment_Site_URL__c.contains('xCustom19=' + EncodingUtil.urlEncode(testBilling.Id, 'UTF-8')));
            Test.stopTest();
        }
    }

    @IsTest
    public static void testPaymentLinkCardknoxWithMC() {
        try{
            TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors().enableMultiCurrency();
            System.runAs(testData.users[1]) {
                Billing__c billing = new Billing__c(
                Customer__c = testData.accounts[0].Id,
                Status__c = 'Approved',
                Accounting_Period__c = testData.acctPeriods[0].Id,
                Payment_Processor__c = testData.paymentProcessors[0].Id,
                Ledger__c = testData.ledgers[0].Id    
                );
                billing.put('CurrencyIsoCode', 'EUR - Euro');

                INSERT billing;
                Billing__c testBilling = [SELECT Id, Payment_Site_URL__c FROM Billing__c WHERE Id = :billing.Id];
                System.assertEquals(testBilling.Payment_Site_URL__c, 'N/A');
            }
        }catch(exception e){}
    }
}