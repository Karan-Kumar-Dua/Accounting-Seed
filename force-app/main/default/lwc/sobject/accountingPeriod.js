import ACCOUNTING_PERIOD from '@salesforce/schema/Accounting_Period__c';
import ID from '@salesforce/schema/Accounting_Period__c.Id';
import END_DATE from '@salesforce/schema/Accounting_Period__c.End_Date__c';
import STATUS from '@salesforce/schema/Accounting_Period__c.Status__c';
import NAME_FIELD from '@salesforce/schema/Accounting_Period__c.Name';
import LAST_MODIFIED_DATE from '@salesforce/schema/Accounting_Period__c.LastModifiedDate';

export default class AccountingPeriod {
    static objectApiName = ACCOUNTING_PERIOD.objectApiName;

    static end_date = END_DATE;
    static status = STATUS;
    static name_field = NAME_FIELD;
    static last_modified_date = LAST_MODIFIED_DATE;
    static id_field = ID;

    end_date = END_DATE.fieldApiName;
    status = STATUS.fieldApiName;
    name_field = NAME_FIELD.fieldApiName;
    last_modified_date = LAST_MODIFIED_DATE.fieldApiName;
}