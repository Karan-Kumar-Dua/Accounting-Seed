/**
 * Provides address valitation services using the AvaTax service.
 */
public with sharing class AvaTaxAddressValidator extends AddressValidationProvider {

    private TaxService.AvaTaxLicense avaTaxLicense;

    public AvaTaxAddressValidator avaTaxLicense(AvaTax_License__c avaTaxLicense) {
        this.avaTaxLicense = new TaxService.AvaTaxLicense(avaTaxLicense);
        return this;
    }
    
    public override AddressValidationProvider.ValidationResult validate(AddressValidationProvider.ValidationAddress address) {
        try {
            // convert address formats
            AvaTaxService.AddressInfo addressInfo = new AvaTaxService.AddressInfo(
                address.street, 
                address.city, 
                address.state, 
                address.country, 
                address.postalCode
            );

            // domain obj to hold transformed AvaTax response
            ValidationResult response = new ValidationResult();

            // basic validation checks
            AvaTaxService.AddressPreliminaryCheckResult checkResult = addressInfo.preliminaryCheck();
            if (!checkResult.isValid) {
                response.messages.add(new ValidationMessage(Severity.ERROR, checkResult.message));
                return response; 
            }

            // call AvaTax address resolution service
            AvaTaxService.AddressResolutionModel validationResult = avaTaxLicense != null ?
                new AvaTaxService(
                        avaTaxLicense.avaTaxAccountId,
                        avaTaxLicense.avaTaxLicenseKey,
                        avaTaxLicense.activeAvaTaxEndpoint == AvaTaxService.PRODUCTION_ACTIVE_AVATAX_ENDPOINT).resolveAddressInst(addressInfo) :
                AvaTaxService.resolveAddress(addressInfo);

            // transform the validated address into return obj
            if (validationResult.validatedAddresses != null 
                    && !validationResult.validatedAddresses.isEmpty()) {
                AvaTaxService.AddressInfo validatedAddress = validationResult.validatedAddresses[0];
                ValidationAddress addr = new ValidationAddress();
                addr.street = validatedAddress.line1;
                addr.city = validatedAddress.city;
                addr.state = validatedAddress.region;
                addr.postalCode = validatedAddress.postalCode;
                addr.country = validatedAddress.country;
                response.address = addr;
            }
            // transform the validation messages into return obj
            if (validationResult.messages != null
                    && !validationResult.messages.isEmpty()) {
                ValidationMessage message = new ValidationMessage(Severity.ERROR, validationResult.messages[0].details);
                response.messages = new List<ValidationMessage>{ message };
            } 
            return response;
        } 
        catch (Exception e) {
            ValidationResult response = new ValidationResult();
            response.messages = new List<ValidationMessage>{ 
                new ValidationMessage(Severity.FATAL, e.getMessage())
            };
            return response;
        }
    }

    public override AddressValidationProvider.ValidationResult precheck(AddressValidationProvider.ValidationAddress address) {
        try {
            ValidationResult response = new ValidationResult();
            response.address = address;
            if (String.isNotBlank(address.country) && address.country != 'US') {
                response.messages = new List<ValidationMessage>{new ValidationMessage(severity.ERROR, System.Label.ERR_AVATAX_COUNTRY_CODE_RESTRICTED).errorLevel(ErrorLevel.SECTION)};
            }
            return response;
        }
        catch (Exception e) {
            ValidationResult response = new ValidationResult();
            response.messages = new List<ValidationMessage>{ 
                new ValidationMessage(Severity.FATAL, e.getMessage())
            };
            return response;
        }
    }
}