global with sharing class GLAccountDefault {
    global GL_Account_Default__c glAccountDefault;
    global GL_Account__c glAccount;
    global GL_Account_Specification__mdt glAccountSpecification;
    global Ledger__c ledger;

    global Errors errors;

    global class Errors {
        global List<Map<String, String>> items;

        global Errors() {
            this.items = new List<Map<String, String>>();
        }

        global Errors add(String message) {
            this.items.add(new Map<String, String>{'message' => message, 'code' => ApexPages.Severity.ERROR.name()});
            return this;
        }

        global Errors add(String message, String code) {
            this.items.add(new Map<String, String>{'message' => message, 'code' => code});
            return this;
        }

        global Boolean isEmpty() {
            return this.items.isEmpty();
        }
    }
}