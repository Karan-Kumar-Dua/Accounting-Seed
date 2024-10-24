import PAYABLE from '@salesforce/schema/Account_Payable__c';
import NAME_FIELD from '@salesforce/schema/Account_Payable__c.Name';
import PROPRIETARY_PAYABLE_NUMBER from '@salesforce/schema/Account_Payable__c.Proprietary_Payable_Number__c';
import DATE from '@salesforce/schema/Account_Payable__c.Date__c';
import TOTAL from '@salesforce/schema/Account_Payable__c.Total__c';
import VENDOR from '@salesforce/schema/Account_Payable__c.Vendor__c';
import VENDOR_R_NAME from '@salesforce/schema/Account_Payable__c.Vendor__r.Name';
import CONTACT from '@salesforce/schema/Account_Payable__c.Contact__c';
import CONTACT_R_NAME from '@salesforce/schema/Account_Payable__c.Contact__r.Name';
import EMPLOYEE from '@salesforce/schema/Account_Payable__c.Employee__c';
import EMPLOYEE_R_NAME from '@salesforce/schema/Account_Payable__c.Employee__r.Name';
import LEDGER from '@salesforce/schema/Account_Payable__c.Ledger__c';
import LEDGER_R_NAME from '@salesforce/schema/Account_Payable__c.Ledger__r.Name';
import LEDGER_R_ACCT_METHOD from '@salesforce/schema/Account_Payable__c.Ledger__r.Accounting_Method__c';
import LEDGER_AMOUNT from '@salesforce/schema/Account_Payable__c.Ledger_Amount__c';
import SUB_TOTAL from '@salesforce/schema/Account_Payable__c.Sub_Total__c';

export default class Payable {
    static objectApiName = PAYABLE.objectApiName;

    static name_field = NAME_FIELD;
    static proprietary_payable_number = PROPRIETARY_PAYABLE_NUMBER;
    static date = DATE;
    static vendor = VENDOR;
    static total = TOTAL;
    static vendor_r_name = VENDOR_R_NAME;
    static contact = CONTACT;
    static contact_r_name = CONTACT_R_NAME;
    static employee = EMPLOYEE;
    static employee_r_name = EMPLOYEE_R_NAME;
    static ledger = LEDGER;
    static ledger_r_name = LEDGER_R_NAME;
    static ledger_r_acct_method = LEDGER_R_ACCT_METHOD;
    static ledger_amount = LEDGER_AMOUNT;
    static sub_total = SUB_TOTAL;

    name_field = NAME_FIELD.fieldApiName;
    proprietary_payable_number = PROPRIETARY_PAYABLE_NUMBER.fieldApiName;
    date = DATE.fieldApiName;
    vendor = VENDOR.fieldApiName;
    total = TOTAL.fieldApiName;
    vendor_r_name = VENDOR_R_NAME.fieldApiName;
    contact = CONTACT.fieldApiName;
    contact_r_name = CONTACT_R_NAME;
    employee = EMPLOYEE.fieldApiName;
    employee_r_name = EMPLOYEE_R_NAME;
    ledger = LEDGER.fieldApiName;
    ledger_r_name = LEDGER_R_NAME.fieldApiName;
    ledger_r_acct_method = LEDGER_R_ACCT_METHOD.fieldApiName;
    ledger_amount = LEDGER_AMOUNT.fieldApiName;
    sub_total = SUB_TOTAL.fieldApiName;
}