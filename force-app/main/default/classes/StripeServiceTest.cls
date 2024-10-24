@IsTest
public class StripeServiceTest {

    @TestSetup
    public static void setupTestData() {
        TestDataSuite testData = TestDataSuite.getInstance(true);
        testData.settings.Stripe_Connected_Account_Id__c = 'acct_12345678901234567890';
        update testData.settings;
    }

    public static final String CUSTOMER_URL = StripeService.CUSTOMER_URL;
    public static final String CHARGE_URL = StripeService.CHARGE_URL;
    public static final String TOKEN_URL = StripeService.TOKEN_URL;
    public static final String TOKEN_ID = 'tok_17hOeJGKbd1fBtzkqXtPDbbU';
    public static final String FINGERPRINT = 'fj30j20j3fsdfj87w37fh3fh0f30hf3';
    public static final Integer CARD_EXP_MONTH = 8;
    public static final Integer CARD_EXP_YEAR = 2017;

    private static testMethod void testGetCombinedSourceNameAsCard() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            StripeService.StripeSource stripeSource = new StripeService.StripeSource();
            stripeSource.name = 'testName';
            stripeSource.brand = 'VISA';
            stripeSource.last4 = '5555';
            stripeSource.stripeObject = 'card';
            System.assertEquals('testName' + ' ' + 'VISA' + ' ' + '5555', stripeSource.getCombinedSourceName());
            stripeSource.name = NULL;
            System.assertEquals('VISA' + ' ' + '5555', stripeSource.getCombinedSourceName());
            stripeSource.brand = NULL;
            System.assertEquals('5555', stripeSource.getCombinedSourceName());
            stripeSource.last4 = NULL;
            System.assertEquals('', stripeSource.getCombinedSourceName());
        }
    }

    private static testMethod void testGetCombinedSourceNameAsBankAccount() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            StripeService.StripeSource stripeSource = new StripeService.StripeSource();
            stripeSource.name = 'testName';
            stripeSource.bank_name = 'Bank Name';
            stripeSource.last4 = '5555';
            stripeSource.stripeObject = 'bank_account';
            System.assertEquals('testName' + ' ' + 'Bank Name' + ' ' + '5555', stripeSource.getCombinedSourceName());
            stripeSource.name = NULL;
            System.assertEquals('Bank Name' + ' ' + '5555', stripeSource.getCombinedSourceName());
            stripeSource.bank_name = NULL;
            System.assertEquals('5555', stripeSource.getCombinedSourceName());
            stripeSource.last4 = NULL;
            System.assertEquals('', stripeSource.getCombinedSourceName());
        }
    }

    //==========================================================================================================
    //============ Unit tests for StripeService.deleteStripeCard method ========================================
    //==========================================================================================================
    private static testMethod void testDeleteStripeCardSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            SingleRequestMock getDeleteStripeCardGeneratorSuccess = new SingleRequestMock(
                200,
                'Complete',
                getDeleteStripeCardResponseBody(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerator(getDeleteStripeCardGeneratorSuccess, CUSTOMER_URL + '/StripeCustomerId/sources/StripeCardId');
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeSource stripeCard = StripeService.deleteStripeSource('StripeCustomerId', 'StripeCardId');
            Test.stopTest();
            System.assertEquals('StripeCardId', stripeCard.id);
        }
    }

    private static testMethod void testDeleteStripeCardResponseError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            SingleRequestMock getDeleteStripeCardGeneratorResponseError = new SingleRequestMock(
                200,
                'Complete',
                getErrorResponse(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerator(getDeleteStripeCardGeneratorResponseError, CUSTOMER_URL + '/StripeCustomerId/sources/StripeCardId');
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeServiceException stripeEx;
            try {
                StripeService.StripeSource stripeCard = StripeService.deleteStripeSource('StripeCustomerId', 'StripeCardId');
            }
            catch (StripeService.StripeServiceException ex) {
                stripeEx = ex;
            }
            Test.stopTest();
            System.assertEquals('StripeErrorMessage', stripeEx.getMessage());
        }
    }
    //==========================================================================================================
    //============ Unit tests for StripeService.getDuplicatedStripeCardIfExists method =========================
    //==========================================================================================================
    private static testMethod void testGetDuplicatedStripeCardIfExists() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            String stripeCustomerId = 'StripeCustomerId_Success';
            String tokenJSON = PaymentMethodManagerTest.getStripeCardTokenJSON('Visa', '12', '2020', '4242');
            StripeService.StripeSourceToken token =
                    (StripeService.StripeSourceToken) JSON.deserialize(tokenJSON, StripeService.StripeSourceToken.class);
            token.id = TOKEN_ID;
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);
            // case #1, duplicate not found
            Test.startTest();
            StripeService.StripeSource card = StripeService.getDuplicatedStripeSourceIfExists(stripeCustomerId, token);
            System.assert(card == null);    // card hasn't duplicate (year doesn't match)
            // case #2, duplicate found
            stripeCustomerId = 'StripeCustomerId_Duplicate';
            card = StripeService.getDuplicatedStripeSourceIfExists(stripeCustomerId, token);
            System.assert(card != null);
            Test.stopTest();
        }
    }
    //==========================================================================================================
    //============ Unit tests for StripeService.updateStripeCard method ========================================
    //==========================================================================================================
    private static testMethod void testUpdateStripeCardSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeSource stripeCard = StripeService.updateStripeSource('StripeCustomerId_Success', 'StripeCardId', NULL, new Map<String, String>{'name' => 'Chloe Martin'});
            Test.stopTest();
            System.assertEquals('StripeCardId', stripeCard.id);
        }
    }

    private static testMethod void testUpdateStripeCardResponseError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeServiceException stripeEx;
            try {
                StripeService.StripeSource stripeCard = StripeService.updateStripeSource('StripeCustomerId_Response_Error', 'StripeCardId', NULL, new Map<String, String>{'name' => 'Chloe Martin'});
            }
            catch (StripeService.StripeServiceException ex) {
                stripeEx = ex;
            }
            Test.stopTest();
            System.assertEquals('StripeErrorMessage', stripeEx.getMessage());
        }
    }

    //==========================================================================================================
    //============ Unit tests for StripeService.createStripeCard method ========================================
    //==========================================================================================================
    private static testMethod void testCreateStripeCardSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            Map<String, String> creditCardInfo = new Map<String, String>{
                'name' => 'Visa',
                'number' => '12345678901234',
                'exp_month' => '12',
                'exp_year' => '2020',
                'cvc' => '333'
            };

            String tokenJSON = PaymentMethodManagerTest.getStripeCardTokenJSON('Visa', '12', '2020', '4242');
            StripeService.StripeSourceToken token =
                (StripeService.StripeSourceToken) JSON.deserialize(tokenJSON, StripeService.StripeSourceToken.class);

            StripeService.StripeSource stripeCard = StripeService.createStripeSource('StripeCustomerId_Success', token, FinancialSuiteUtils.getUUID());
            Test.stopTest();
            System.assertEquals('StripeCardId', stripeCard.id);
        }
    }

    private static testMethod void testCreateStripeCardResponseError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeServiceException stripeEx;
            try {
                String tokenJSON = PaymentMethodManagerTest.getStripeCardTokenJSON('Visa', '12', '2020', '4242');
                StripeService.StripeSourceToken token =
                    (StripeService.StripeSourceToken) JSON.deserialize(tokenJSON, StripeService.StripeSourceToken.class);
                StripeService.Stripesource stripeCard = StripeService.createStripeSource('StripeCustomerId_Response_Error', token, FinancialSuiteUtils.getUUID());
            }
            catch (StripeService.StripeServiceException ex) {
                stripeEx = ex;
            }
            Test.stopTest();
            System.assertEquals('StripeErrorMessage', stripeEx.getMessage());
        }
    }

    //==========================================================================================================
    //============ Unit tests for StripeService.updateStripeCustomer method ====================================
    //==========================================================================================================
    private static testMethod void testUpdateStripeCustomerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeCustomer stripeCustomer = StripeService.updateStripeCustomer('StripeCustomerId_Success', new Map<String, String>{'description' => 'updated user'});
            Test.stopTest();
            System.assertEquals('cus_9M8lj1ufREF2SR', stripeCustomer.id);
        }
    }

    private static testMethod void testUpdateStripeCustomerResponseError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeServiceException stripeEx;
            try {
                StripeService.StripeCustomer stripeCustomer = StripeService.updateStripeCustomer('StripeCustomerId_Response_Error', new Map<String, String>{'description' => 'updated user'});
            }
            catch (StripeService.StripeServiceException ex) {
                stripeEx = ex;
            }
            Test.stopTest();
            System.assertEquals('StripeErrorMessage', stripeEx.getMessage());
        }
    }

    //==========================================================================================================
    //============ Unit tests for StripeService.createStripeCardToken method ====================================
    //==========================================================================================================
    private static testMethod void testCreateStripeCardTokenSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Map<String, String> creditCardInfo = new Map<String, String>{
                    'name' => 'Visa',
                    'number' => '12345678901234',
                    'exp_month' => CARD_EXP_MONTH + '',
                    'exp_year' => CARD_EXP_YEAR + '',
                    'cvc' => '333'
            };

            Test.startTest();
            StripeService.StripeSourceToken token = StripeService.createStripeSourceToken(creditCardInfo);
            Test.stopTest();
            System.assert(token != null);
            System.assertEquals(CARD_EXP_MONTH, token.card.exp_month);
            System.assertEquals(CARD_EXP_YEAR, token.card.exp_year);
        }
    }
    private static testMethod void testCreateStripeCardTokenError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            SingleRequestMock getCreateStripeCardTokenError = new SingleRequestMock(
                    200,
                    'Complete',
                    getErrorResponse(),
                    new Map<String, String>{'Content-Type' => 'application/json'}
            );
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerator(getCreateStripeCardTokenError, TOKEN_URL);
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Map<String, String> creditCardInfo = new Map<String, String>{
                    'name' => 'Visa',
                    'number' => '12345678901234',
                    'exp_month' => CARD_EXP_MONTH + '',
                    'exp_year' => CARD_EXP_YEAR + '',
                    'cvc' => '333'
            };

            Test.startTest();
            try {
                StripeService.StripeSourceToken token = StripeService.createStripeSourceToken(creditCardInfo);
                System.assert(false);   // fail, exception must be occurred
            } catch (StripeService.StripeServiceException ex) {
                System.assert(ex != null);
            }
            Test.stopTest();
        }
    }
    //==========================================================================================================
    //============ Unit tests for StripeService.createStripeCustomer method ====================================
    //==========================================================================================================
    private static testMethod void testCreateStripeCustomerSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            Map<String, String> metadataMap = new Map<String, String>{'sf_id' => '123456789012345'};

            String tokenJSON = PaymentMethodManagerTest.getStripeCardTokenJSON('Visa', '12', '2020', '4242');
            StripeService.StripeSourceToken token =
                (StripeService.StripeSourceToken) JSON.deserialize(tokenJSON, StripeService.StripeSourceToken.class);

            StripeService.StripeCustomer stripeCustomer = StripeService.createStripeCustomer(token, metadataMap, FinancialSuiteUtils.getUUID());
            Test.stopTest();
            System.assertEquals('cus_9M8lj1ufREF2SR', stripeCustomer.id);
        }
    }

    //==========================================================================================================
    //============ Unit tests for StripeService.createCharge method ============================================
    //==========================================================================================================
    private static testMethod void testCreateChargeSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeCharge stripeCharge = StripeService.createCharge(
                'StripeCustomerId_Success',
                'Card_Id',
                500.00,
                'USD',
                'Custom_Description',
                FinancialSuiteUtils.getUUID()
            );
            Test.stopTest();
            System.assertEquals('ch_193QTxGKbd1fBtzkpIMfgZS1', stripeCharge.id);
            System.assertEquals(500, stripeCharge.amount);
            System.assertEquals('Custom_Description', stripeCharge.description);
            System.assertEquals('succeeded', stripeCharge.status);
        }
    }

    private static testMethod void testCreateChargeResponseError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            SingleRequestMock getChargeGeneratorResponseError = new SingleRequestMock(
                200,
                'Complete',
                getErrorResponse(),
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerator(getChargeGeneratorResponseError, CHARGE_URL);
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeServiceException stripeEx;
            try {
                StripeService.StripeCharge stripeCharge = StripeService.createCharge(
                    'StripeCustomerId_Success',
                    'Card_Id',
                    500.00,
                    'USD',
                    'Custom_Description',
                    FinancialSuiteUtils.getUUID()
                );
            }
            catch (StripeService.StripeServiceException ex) {
                stripeEx = ex;
            }

            System.assertEquals('StripeErrorMessage', stripeEx.getMessage());
        }
    }
    //==========================================================================================================
    //============ Unit tests for StripeService.getListAllCustomerCards method =================================
    //==========================================================================================================
    private static testMethod void testGetListAllCustomerCardsSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            List<StripeService.StripeSource> cards = StripeService.getListAllCustomerCards('StripeCustomerId_Success');
            Test.stopTest();
            System.assertEquals(1, cards.size());
            System.assertEquals('card_1949TyGKbd1fBtzklrzAHIIv', cards[0].id);
        }
    }

    private static testMethod void testGetListAllCustomerCardsNoResult() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            List<StripeService.StripeSource> cards = StripeService.getListAllCustomerCards('StripeCustomerId_No_Cards');

            System.assertEquals(true, cards.isEmpty());
        }
    }

    private static testMethod void testGetListAllCustomerCardsError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            HttpCalloutMock multiCalloutMockInstance = createResponseGenerators();
            Test.setMock(HttpCalloutMock.class, multiCalloutMockInstance);

            Test.startTest();
            StripeService.StripeServiceException stripeEx;
            try {
                List<StripeService.StripeSource> cards = StripeService.getListAllCustomerCards('StripeCustomerId_Response_Error');
            }
            catch(StripeService.StripeServiceException ex) {
                stripeEx = ex;
            }
            Test.stopTest();
            System.assertEquals('StripeErrorMessage', stripeEx.getMessage());
        }
    }

    @IsTest
    private static void testCreateChargeIdempotencyError() {
        TestDataSuite testData = TestDataSuite.getInstance().createPaymentProcessors();

        System.runAs(testData.users[1]) {
            String requestLogUrl = 'https://dashboard.stripe.com/test/logs/req_5aqv4vAvnVGu4d?t=1677266245';
            HttpCalloutMock mockResp = new SingleRequestMock(
                400,
                'Bad Request',
                '{' +
                    '"error": {' +
                        '"message": "Keys for idempotent requests can only be used with the same parameters they were first used with. Try using a key other than \'2\' if you meant to execute a different request.",' +
                        '"request_log_url": "'+ requestLogUrl +'",' +
                        '"type": "idempotency_error"' +
                    '}' +
                '}',
                new Map<String, String>{'Content-Type' => 'application/json'}
            );
            Test.setMock(HttpCalloutMock.class, mockResp);

            Test.startTest();
            StripeService.StripeServiceException stripeEx;
            try {
                StripeService.createCharge(
                    'customer_id',
                    'payment_method_id',
                    500.00,
                    'currency_code',
                    'description',
                    'idempotency_key',
                    testData.paymentProcessors[0]);
            }
            catch(StripeService.StripeServiceException ex) {
                stripeEx = ex;
            }
            Test.stopTest();
            
            Assert.isNotNull(stripeEx);
            Assert.areEqual(Label.ERR_PAYMENTS_DUPLICATE_FOUND + ' ' + requestLogUrl, stripeEx.getMessage());
        }
    }

    //==========================================================================================================
    //================================ Create Multi-Response Generator =========================================
    //==========================================================================================================
    public static HttpCalloutMock createResponseGenerators() {
        //======
        SingleRequestMock getListAllCustomerCardsGeneratorSuccess = new SingleRequestMock(
            200,
            'Complete',
            getListAllCustomerCardsResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock getListAllCustomerCardsGeneratorForCheckDuplicate = new SingleRequestMock(
                200,
                'Complete',
                getListAllCustomerCardsResponseBodyForCheckDuplicate(),
                new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock getListAllCustomerCardsGeneratorNoCards = new SingleRequestMock(
            200,
            'Complete',
            getListAllCustomerCardsResponseBodyEmpty(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock getListAllCustomerCardsGeneratorResponseError = new SingleRequestMock(
            200,
            'Complete',
            getErrorResponse(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock getChargeGeneratorSuccess = new SingleRequestMock(
            200,
            'Complete',
            getChargeResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock createStripeCustomerGeneratorSuccess = new SingleRequestMock(
            200,
            'Complete',
            getCreateStripeCustomerResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock createStripeCardTokenGenerator = new SingleRequestMock(
            200,
            'Complete',
            getCreateStripeTokenResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock updateStripeCustomerGeneratorSuccess = new SingleRequestMock(
            200,
            'Complete',
            getCreateStripeCustomerResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock updateStripeCustomerGeneratorResponseError = new SingleRequestMock(
            200,
            'Complete',
            getErrorResponse(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock createStripeCardGeneratorSuccess = new SingleRequestMock(
            200,
            'Complete',
            getCreateStripeCardResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock createStripeCardGeneratorResponseError = new SingleRequestMock(
            200,
            'Complete',
            getErrorResponse(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock updateStripeCardGeneratorSuccess = new SingleRequestMock(
            200,
            'Complete',
            getCreateStripeCardResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock updateStripeCardGeneratorResponseError = new SingleRequestMock(
            200,
            'Complete',
            getErrorResponse(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======
        SingleRequestMock getDuplicatedStripeCardIfExists = new SingleRequestMock(
            200,
            'Complete',
            getCreateStripeTokenResponseBody(),
            new Map<String, String>{'Content-Type' => 'application/json'}
        );
        //======

        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Success/sources?object=card&limit=' + StripeService.RECEIVE_STRIPE_SOURCES_LIMIT, getListAllCustomerCardsGeneratorSuccess);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Duplicate/sources?object=card&limit=' + StripeService.RECEIVE_STRIPE_SOURCES_LIMIT, getListAllCustomerCardsGeneratorForCheckDuplicate);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_No_Cards/sources?object=card&limit=' + StripeService.RECEIVE_STRIPE_SOURCES_LIMIT, getListAllCustomerCardsGeneratorNoCards);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Response_Error/sources?object=card&limit=' + StripeService.RECEIVE_STRIPE_SOURCES_LIMIT, getListAllCustomerCardsGeneratorResponseError);
        endpoint2TestResp.put(CHARGE_URL, getChargeGeneratorSuccess);
        endpoint2TestResp.put(CUSTOMER_URL, createStripeCustomerGeneratorSuccess);
        endpoint2TestResp.put(TOKEN_URL, createStripeCardTokenGenerator);
        endpoint2TestResp.put(TOKEN_URL + '/' + TOKEN_ID, getDuplicatedStripeCardIfExists);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Success', updateStripeCustomerGeneratorSuccess);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Response_Error', updateStripeCustomerGeneratorResponseError);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Success/sources', createStripeCardGeneratorSuccess);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Response_Error/sources', createStripeCardGeneratorResponseError);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Success/sources/StripeCardId', updateStripeCardGeneratorSuccess);
        endpoint2TestResp.put(CUSTOMER_URL + '/StripeCustomerId_Response_Error/sources/StripeCardId', updateStripeCardGeneratorResponseError);

        HttpCalloutMock multiCalloutMockInstance = new MultiRequestMock(endpoint2TestResp);

        return multiCalloutMockInstance;
    }
    //For special cases
    private static HttpCalloutMock createResponseGenerator(SingleRequestMock singleRequestMock, String endpoint) {
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(endpoint, singleRequestMock);
        HttpCalloutMock multiCalloutMockInstance = new MultiRequestMock(endpoint2TestResp);
        return multiCalloutMockInstance;
    }

    //==========================================================================================================
    //================================ JSON Response Bodies ====================================================
    //==========================================================================================================
    private static String getDeleteStripeCardResponseBody() {
        String result =
            '{' +
                '"deleted": true,' +
                '"id": "StripeCardId"' +
            '}';

        return result;
    }

    private static String getCreateStripeCardResponseBody() {
        String result =
            '{' +
                '"id": "StripeCardId",' +
                '"object": "card",' +
                '"brand": "Discover",' +
                '"country": "US",' +
                '"customer": "cus_9M8lj1ufREF2SR",' +
                '"cvc_check": "pass",' +
                '"dynamic_last4": null,' +
                '"exp_month": 8,' +
                '"exp_year": 2019,' +
                '"funding": "credit",' +
                '"last4": "1117",' +
                '"metadata": {' +
                '},' +
                '"name": "Test",' +
                '"tokenization_method": null' +
            '}';
        return result;
    }

    private static String getCreateStripeCustomerResponseBody() {
        String result =
            '{' +
                '"id": "cus_9M8lj1ufREF2SR",' +
                '"object": "customer",' +
                '"account_balance": 0,' +
                '"created": 1476193171,' +
                '"currency": "usd",' +
                '"default_source": "card_193QTfGKbd1fBtzkOvmzCTXw"' +
            '}';
        return result;
    }

    private static String getCreateStripeTokenResponseBody() {
        String result =
            '{' +
                '"id": "' + TOKEN_ID + '",' +
                '"object": "token",' +
                '"card": {' +
                    '"id": "card_17hOeJGKbd1fBtzklnY1AKUz",' +
                    '"object": "card",' +
                    '"brand": "Visa",' +
                    '"country": "US",' +
                    '"cvc_check": null,' +
                    '"dynamic_last4": null,' +
                    '"exp_month": ' + CARD_EXP_MONTH + ',' +
                    '"exp_year": ' + CARD_EXP_YEAR + ',' +
                    '"fingerprint": "' + FINGERPRINT + '",' +
                    '"funding": "credit",' +
                    '"last4": "4242",' +
                    '"metadata": {' +
                    '},' +
                    '"name": null,' +
                    '"tokenization_method": null' +
                '},' +
                '"client_ip": null,' +
                '"created": 1456166591,' +
                '"livemode": false,' +
                '"type": "card",' +
                '"used": false' +
            '}';
        return result;
    }

    public static String getChargeResponseBody() {
        String result =
            '{' +
                '"id": "ch_193QTxGKbd1fBtzkpIMfgZS1",' +
                '"object": "charge",' +
                '"amount": 500,' +
                '"amount_refunded": 0,' +
                '"application": null,' +
                '"application_fee": null,' +
                '"balance_transaction": "txn_184tFGGKbd1fBtzkTKgYQy24",' +
                '"captured": true,' +
                '"created": 1476193189,' +
                '"currency": "usd",' +
                '"customer": "cus_9M8lj1ufREF2SR",' +
                '"description": "Custom_Description",' +
                '"destination": null,' +
                '"dispute": null,' +
                '"failure_code": null,' +
                '"failure_message": null,' +
                '"fraud_details": {' +
                '},' +
                '"invoice": null,' +
                '"livemode": false,' +
                '"metadata": {' +
                '},' +
                '"order": null,' +
                '"outcome": {' +
                    '"network_status": "approved_by_network",' +
                    '"reason": null,' +
                    '"risk_level": "normal",' +
                    '"seller_message": "Payment complete.",' +
                    '"type": "authorized"' +
                '},' +
                '"paid": true,' +
                '"receipt_email": null,' +
                '"receipt_number": null,' +
                '"refunded": false,' +
                '"refunds": {' +
                    '"object": "list",' +
                    '"data": [' +
                    '],' +
                    '"has_more": false,' +
                    '"total_count": 0,' +
                    '"url": "/v1/charges/ch_193QTxGKbd1fBtzkpIMfgZS1/refunds"' +
                '},' +
                '"review": null,' +
                '"shipping": null,' +
                '"source": {' +
                    '"id": "card_193QTfGKbd1fBtzkOvmzCTXw",' +
                    '"object": "card",' +
                    '"address_city": null,' +
                    '"address_country": null,' +
                    '"address_line1": null,' +
                    '"address_line1_check": null,' +
                    '"address_line2": null,' +
                    '"address_state": null,' +
                    '"address_zip": null,' +
                    '"address_zip_check": null,' +
                    '"brand": "Visa",' +
                    '"country": "AT",' +
                    '"customer": "cus_9M8lj1ufREF2SR",' +
                    '"cvc_check": "pass",' +
                    '"dynamic_last4": null,' +
                    '"exp_month": 9,' +
                    '"exp_year": 2019,' +
                    '"funding": "credit",' +
                    '"last4": "0008",' +
                    '"metadata": {' +
                    '},' +
                    '"name": "Test Name",' +
                    '"tokenization_method": null' +
                '},' +
                '"source_transfer": null,' +
                '"statement_descriptor": null,' +
                '"status": "succeeded"' +
            '}';

        return result;
    }

    private static String getListAllCustomerCardsResponseBody() {
        String result =
            '{' +
                '"object": "list",' +
                '"url": "/v1/customers/cus_9M8lj1ufREF2SR/sources",' +
                '"has_more": false,' +
                '"data": [' +
                '{' +
                '"id": "card_1949TyGKbd1fBtzklrzAHIIv",' +
                '"object": "card",' +
                '"address_city": null,' +
                '"address_country": null,' +
                '"address_line1": null,' +
                '"address_line1_check": null,' +
                '"address_line2": null,' +
                '"address_state": null,' +
                '"address_zip": null,' +
                '"address_zip_check": null,' +
                '"brand": "Discover",' +
                '"country": "US",' +
                '"customer": "cus_9M8lj1ufREF2SR",' +
                '"cvc_check": "pass",' +
                '"dynamic_last4": null,' +
                '"exp_month": 8,' +
                '"exp_year": 2019,' +
                '"fingerprint": "' + FINGERPRINT + '",' +
                '"funding": "credit",' +
                '"last4": "1117",' +
                '"metadata": {' +
                '},' +
                '"name": "Test",' +
                '"tokenization_method": null' +
                '}' +
                ']' +
                '}';

        return result;
    }

    private static String getListAllCustomerCardsResponseBodyForCheckDuplicate() {
        String result =
                '{' +
                        '"object": "list",' +
                        '"url": "/v1/customers/cus_9M8lj1ufREF2SR/sources",' +
                        '"has_more": false,' +
                        '"data": [' +
                        '{' +
                        '"id": "card_1949TyGKbd1fBtzklrzAHIIv",' +
                        '"object": "card",' +
                        '"address_city": null,' +
                        '"address_country": null,' +
                        '"address_line1": null,' +
                        '"address_line1_check": null,' +
                        '"address_line2": null,' +
                        '"address_state": null,' +
                        '"address_zip": null,' +
                        '"address_zip_check": null,' +
                        '"brand": "Discover",' +
                        '"country": "US",' +
                        '"customer": "cus_9M8lj1ufREF2SR",' +
                        '"cvc_check": "pass",' +
                        '"dynamic_last4": null,' +
                        '"exp_month": ' + CARD_EXP_MONTH + ',' +
                        '"exp_year": ' + CARD_EXP_YEAR + ',' +
                        '"fingerprint": "' + FINGERPRINT + '",' +
                        '"funding": "credit",' +
                        '"last4": "1117",' +
                        '"metadata": {' +
                        '},' +
                        '"name": "Test",' +
                        '"tokenization_method": null' +
                        '}' +
                        ']' +
                        '}';

        return result;
    }

    private static String getListAllCustomerCardsResponseBodyEmpty() {
        String result =
            '{' +
                '"object": "list",' +
                '"url": "/v1/customers/cus_9M8lj1ufREF2SR/sources",' +
                '"has_more": false,' +
                '"data": [' +
                ']' +
            '}';

        return result;
    }

    public static String getErrorResponse() {
        return
            '{' +
                '"error": {' +
                    '"code": "some_code",' +
                    '"param": "some_param",' +
                    '"message": "StripeErrorMessage",' +
                    '"type": "some_type"' +
                '}' +
            '}';
    }

}