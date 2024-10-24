import LEDGER from '@salesforce/schema/Ledger__c';
import NAME_FIELD from '@salesforce/schema/Ledger__c.Name';
import TYPE1 from '@salesforce/schema/Ledger__c.Type__c';
import TAX_SETTING from '@salesforce/schema/Ledger__c.Tax_Settings__c';
import ACCT_METHOD from '@salesforce/schema/Ledger__c.Accounting_Method__c';
import TAX_SETTING_R_TAX_METHOD from '@salesforce/schema/Ledger__c.Tax_Settings__r.Tax_Settings_Method__c';
import PAYMENT_NOTIFICATION_FIELD from '@salesforce/schema/Ledger__c.Payment_Notifications_Email__c';
import PAYMENT_SERVICES_ENROLLMENT_STATUS_FIELD from '@salesforce/schema/Ledger__c.Payment_Services_Enrollment_Status__c';

export default class Ledger {
    static objectApiName = LEDGER.objectApiName;
    static ledgerObject = LEDGER;

    static nameField = NAME_FIELD;
    static type1 = TYPE1;
    static taxSetting = TAX_SETTING;
    static taxSettingTaxMethod = TAX_SETTING_R_TAX_METHOD;
    static nameField = NAME_FIELD;
    static paymentNotificationField = PAYMENT_NOTIFICATION_FIELD;
    static PaymentServicesEnrollmentStatus = PAYMENT_SERVICES_ENROLLMENT_STATUS_FIELD;
    static acctMethod = ACCT_METHOD;

    nameField = NAME_FIELD.fieldApiName;
    type1 = TYPE1.fieldApiName;
    taxSetting = TAX_SETTING.fieldApiName;
    taxSettingTaxMethod = TAX_SETTING_R_TAX_METHOD.fieldApiName;
    nameField = NAME_FIELD.fieldApiName;
    paymentNotificationField = PAYMENT_NOTIFICATION_FIELD.fieldApiName;
    PaymentServicesEnrollmentStatus = PAYMENT_SERVICES_ENROLLMENT_STATUS_FIELD.fieldApiName;
    acctMethod = ACCT_METHOD.fieldApiName;
}