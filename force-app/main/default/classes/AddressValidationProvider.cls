/**
 * Provides a common interface for address validation services.
 */
public with sharing abstract class AddressValidationProvider {
    
    /**
     * Validates the provided address.
     */
    public abstract ValidationResult validate(ValidationAddress address);

    public abstract ValidationResult precheck(ValidationAddress address);

    /**
     * The result of validating an address.
     */
    public with sharing class ValidationResult {
        /**
         * The validated address
         */
        @AuraEnabled
        public ValidationAddress address;
        /**
         * Errors or other messages from the validation provider.
         */
        @AuraEnabled
        public List<ValidationMessage> messages;

        public ValidationResult() {
            this.messages = new List<ValidationMessage>();
        }
    }

    /**
     * An address.
     */
    public with sharing class ValidationAddress {
        @AuraEnabled
        public String street;
        @AuraEnabled
        public String city;
        @AuraEnabled
        public String state;
        @AuraEnabled
        public String postalCode;
        @AuraEnabled
        public String country;
    }

    /**
     * A message fron the validation provider.
     */
    public with sharing class ValidationMessage {
        /**
         * The message.
         */
        @AuraEnabled
        public String message;
        /**
         * Severity of the message.
         */
        @AuraEnabled
        public String severity;

        @AuraEnabled
        public String errorLevel;

        public ValidationMessage(Severity severity,String message) {
            this.severity = severity.name();
            this.message = message;
        }

        public ValidationMessage errorLevel(ErrorLevel errorLevel) {
            this.errorLevel = errorLevel.name();
            return this;
        }
    }

    public enum Severity {
        CONFIRM,
        INFO,
        WARN,
        ERROR,
        FATAL
    }

    public enum ErrorLevel {
        SECTION,
        PAGE
    }
}