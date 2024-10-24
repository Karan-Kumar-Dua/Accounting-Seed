@IsTest
public with sharing class AddressValidationHelperTest {
    
    public class AddressValidationProviderMock implements System.StubProvider {
        
        private AddressValidationProvider.ValidationResult output;

        public AddressValidationProviderMock(AddressValidationProvider.ValidationResult output) {
            this.output = output;
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {
            
            if (stubbedMethodName == 'validate') {
                return output;
            } else if (stubbedMethodName == 'precheck') {
                return output;
            }
            return null;     
        }
    }

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    private static void testValidateSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // build mock result
            AddressValidationProvider.ValidationResult mockResult = new AddressValidationProvider.ValidationResult();
            AddressValidationProvider.ValidationAddress mockAddress = new AddressValidationProvider.ValidationAddress();
            mockAddress.street = '20 W 34th St';
            mockAddress.city = 'New York';
            mockAddress.state = 'NY';
            mockAddress.postalCode = '10001';
            mockAddress.country = 'US';
            mockResult.address = mockAddress;

            // create mock provider
            AddressValidationProviderMock mockProvider = new AddressValidationProviderMock(mockResult);
            AddressValidationProvider provider = (AddressValidationProvider) Test.createStub(AvaTaxAddressValidator.class, mockProvider);

            // inject mock provider
            AddressValidationHelper.provider = provider;

            // run test
            Test.startTest();
            AddressValidationProvider.ValidationResult result = AddressValidationHelper.validate(
                '20 West 34th Street', 
                'New York', 
                'NY', 
                '10001', 
                'US',
                null,
                null
            );
            Test.stopTest();

            // validate
            System.assertNotEquals(null, result);
            System.assertNotEquals(null, result.address);
            System.assert(result.messages.isEmpty());
            System.assertEquals(mockAddress.street, result.address.street);
            System.assertEquals(mockAddress.city, result.address.city);
            System.assertEquals(mockAddress.state, result.address.state);
            System.assertEquals(mockAddress.postalCode, result.address.postalCode);
            System.assertEquals(mockAddress.country, result.address.country);
        }
    }

    @IsTest
    private static void testValidateError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // build mock result
            AddressValidationProvider.ValidationResult mockResult = new AddressValidationProvider.ValidationResult();
            AddressValidationProvider.ValidationMessage mockMessage = new AddressValidationProvider.ValidationMessage(
                AddressValidationProvider.Severity.ERROR,
                'An error occurred.'
            );
            mockResult.messages.add(mockMessage);

            // create mock provider
            AddressValidationProviderMock mockProvider = new AddressValidationProviderMock(mockResult);
            AddressValidationProvider provider = (AddressValidationProvider) Test.createStub(AvaTaxAddressValidator.class, mockProvider);

            // inject mock provider
            AddressValidationHelper.provider = provider;

            // run test
            Test.startTest();
            AddressValidationProvider.ValidationResult result = AddressValidationHelper.validate(
                '20 W 34th St', 
                'New York', 
                'NY', 
                '10001', 
                'US',
                null,
                null
            );
            Test.stopTest();

            // validate
            System.assertNotEquals(null, result);
            System.assertEquals(null, result.address);
            System.assertEquals(1, result.messages.size());
            System.assertEquals(mockMessage.message, result.messages[0].message);
            System.assertEquals(mockMessage.severity, result.messages[0].severity);
        }
    }

    @IsTest
    private static void testPrecheckSuccess() {
        TestDataSuite testData = TestDataSuite.getInstance();

        // run in user context to avoid permission issues
        System.runAs(testData.users.get(1)) {
            // build mock result
            AddressValidationProvider.ValidationResult mockResult = new AddressValidationProvider.ValidationResult();
            AddressValidationProvider.ValidationAddress mockAddress = new AddressValidationProvider.ValidationAddress();
            mockAddress.street = '20 W 34th St';
            mockAddress.city = 'New York';
            mockAddress.state = 'NY';
            mockAddress.postalCode = '10001';
            mockAddress.country = 'US';
            mockResult.address = mockAddress;

            // create mock provider
            AddressValidationProviderMock mockProvider = new AddressValidationProviderMock(mockResult);
            AddressValidationProvider provider = (AddressValidationProvider) Test.createStub(AvaTaxAddressValidator.class, mockProvider);

            // inject mock provider
            AddressValidationHelper.provider = provider;

            // run test
            Test.startTest();
            AddressValidationProvider.ValidationResult result = AddressValidationHelper.precheck(
                '20 West 34th Street', 
                'New York', 
                'NY', 
                '10001', 
                'US'
            );
            Test.stopTest();

            // validate
            System.assertNotEquals(null, result);
            System.assertNotEquals(null, result.address);
            System.assert(result.messages.isEmpty());
            System.assertEquals(mockAddress.street, result.address.street);
            System.assertEquals(mockAddress.city, result.address.city);
            System.assertEquals(mockAddress.state, result.address.state);
            System.assertEquals(mockAddress.postalCode, result.address.postalCode);
            System.assertEquals(mockAddress.country, result.address.country);
        }
    }

    @IsTest
    private static void testPrecheckError() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            // build mock result
            AddressValidationProvider.ValidationResult mockResult = new AddressValidationProvider.ValidationResult();
            AddressValidationProvider.ValidationMessage mockMessage = new AddressValidationProvider.ValidationMessage(
                AddressValidationProvider.Severity.ERROR,
                'An error occurred.'
            );
            mockResult.messages.add(mockMessage);

            // create mock provider
            AddressValidationProviderMock mockProvider = new AddressValidationProviderMock(mockResult);
            AddressValidationProvider provider = (AddressValidationProvider) Test.createStub(AvaTaxAddressValidator.class, mockProvider);

            // inject mock provider
            AddressValidationHelper.provider = provider;

            // run test
            Test.startTest();
            AddressValidationProvider.ValidationResult result = AddressValidationHelper.precheck(
                '20 W 34th St', 
                'New York', 
                'NY', 
                '10001', 
                'US'
            );
            Test.stopTest();

            // validate
            System.assertNotEquals(null, result);
            System.assertEquals(null, result.address);
            System.assertEquals(1, result.messages.size());
            System.assertEquals(mockMessage.message, result.messages[0].message);
            System.assertEquals(mockMessage.severity, result.messages[0].severity);
        }
    }

}