@IsTest
public with sharing class AvaTaxAddressValidatorTest {
    
    private static AddressValidationProvider.ValidationAddress getTestAddress() {
        AddressValidationProvider.ValidationAddress addr = new AddressValidationProvider.ValidationAddress();
        addr.street = '20 W 34th St';
        addr.city = 'New York';
        addr.state = 'NY';
        addr.postalCode = '10001';
        addr.country = 'US';
        return addr;
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidateMissingFields() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            AvaTaxAddressValidator validator = new AvaTaxAddressValidator();

            String missingInfo = Label.WRN_ENTER_ADDRESS_INFORMATION;

            // missing street
            AddressValidationProvider.ValidationAddress addr = getTestAddress();
            addr.street = null;
            AddressValidationProvider.ValidationResult result = validator.validate(addr);
            System.assertEquals(null, result.address);
            System.assertEquals(1, result.messages.size());
            System.assertEquals(AddressValidationProvider.Severity.ERROR.name(), result.messages[0].severity);
            System.assertEquals(missingInfo, result.messages[0].message);

            // missing city
            addr = getTestAddress();
            addr.city = null;
            result = validator.validate(addr);
            System.assertEquals(null, result.address);
            System.assertEquals(1, result.messages.size());
            System.assertEquals(AddressValidationProvider.Severity.ERROR.name(), result.messages[0].severity);
            System.assertEquals(missingInfo, result.messages[0].message);

            // missing state
            addr = getTestAddress();
            addr.state = null;
            result = validator.validate(addr);
            System.assertEquals(null, result.address);
            System.assertEquals(1, result.messages.size());
            System.assertEquals(AddressValidationProvider.Severity.ERROR.name(), result.messages[0].severity);
            System.assertEquals(missingInfo, result.messages[0].message);
        }
    }

    @IsTest
    private static void testValidateCountry() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            AddressValidationProvider.ValidationAddress addr = getTestAddress();
            addr.state = 'Gisborne';
            addr.country = 'NZ';

            AvaTaxAddressValidator validator = new AvaTaxAddressValidator();
            AddressValidationProvider.ValidationResult result = validator.validate(addr);

            // validate
            System.assertEquals(null, result.address);
            System.assertEquals(1, result.messages.size());
            System.assertEquals(AddressValidationProvider.Severity.ERROR.name(), result.messages[0].severity);
            System.assertEquals(Label.ERR_AVALARA_ADDRESS_VALIDATOR_SALES_TAX_CALC_NOT_SUPPORTED, result.messages[0].message);
        }
    }

    @IsTest
    private static void testValidateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            Test.startTest();
            // build mock response
            AvaTaxService.AddressResolutionModel mockResponse = new AvaTaxService.AddressResolutionModel();
            mockResponse.validatedAddresses = new List<AvaTaxService.AddressInfo>{ 
                new AvaTaxService.AddressInfo('street', 'city', 'state', 'country', 'postalCode')
            };

            Test.setMock(HttpCalloutMock.class, new SingleRequestMock(
                200,
                'Complete',
                JSON.serialize(mockResponse),
                new Map<String, String>{'Content-Type' => 'application/json'}
            ));

            // get validation address
            AddressValidationProvider.ValidationAddress addr = getTestAddress();

            // run test
            AvaTaxAddressValidator validator = new AvaTaxAddressValidator();
            AddressValidationProvider.ValidationResult result = validator.validate(addr);

            // validate
            System.assertNotEquals(null, result.address);
            System.assertEquals(mockResponse.validatedAddresses[0].line1, result.address.street);
            System.assertEquals(mockResponse.validatedAddresses[0].city, result.address.city);
            System.assertEquals(mockResponse.validatedAddresses[0].region, result.address.state);
            System.assertEquals(mockResponse.validatedAddresses[0].postalCode, result.address.postalCode);
            System.assertEquals(mockResponse.validatedAddresses[0].country, result.address.country);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testPrecheckCountry() {
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            // unsupported contry code
            AddressValidationProvider.ValidationAddress addr = getTestAddress();
            addr.state = 'Gisborne';
            addr.country = 'NZ';

            // run the prechecks
            AvaTaxAddressValidator validator = new AvaTaxAddressValidator();
            AddressValidationProvider.ValidationResult result = validator.precheck(addr);

            // validate
            System.assertEquals(1, result.messages.size());
            System.assertEquals(AddressValidationProvider.Severity.ERROR.name(), result.messages[0].severity);
            System.assertEquals(System.Label.ERR_AVATAX_COUNTRY_CODE_RESTRICTED, result.messages[0].message);
        }
    }

    @IsTest
    private static void testPrecheckCountryIsBlank() {
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            // blank Country code
            AddressValidationProvider.ValidationAddress addr = getTestAddress();
            addr.state = 'Gisborne';
            addr.country = null;

            // run the prechecks
            AvaTaxAddressValidator validator = new AvaTaxAddressValidator();
            AddressValidationProvider.ValidationResult result = validator.precheck(addr);

            // validate
            System.assertEquals(0, result.messages.size());
        }
    }

    @IsTest
    private static void testPrecheckAvalaraNotEnabled() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // valid address input
            AddressValidationProvider.ValidationAddress addr = getTestAddress();

            // run the prechecks
            AvaTaxAddressValidator validator = new AvaTaxAddressValidator();
            AddressValidationProvider.ValidationResult result = validator.precheck(addr);

            // validate
            System.assertEquals(0, result.messages.size());
        }
    }

    @IsTest
    private static void testPrecheckSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance().enableAvaTaxCalculation();

        System.runAs(testData.users.get(1)) {
            // valid address input
            AddressValidationProvider.ValidationAddress addr = getTestAddress();

            // run the prechecks
            AvaTaxAddressValidator validator = new AvaTaxAddressValidator();
            AddressValidationProvider.ValidationResult result = validator.precheck(addr);

            // validate
            System.assertEquals(0, result.messages.size());
            System.assertNotEquals(null, result.address);
            System.assertEquals(addr.street, result.address.street);
            System.assertEquals(addr.city, result.address.city);
            System.assertEquals(addr.state, result.address.state);
            System.assertEquals(addr.postalCode, result.address.postalCode);
            System.assertEquals(addr.country, result.address.country);
        }
    }

}