import ADDRESS from '@salesforce/schema/Address__c';
import STREET from '@salesforce/schema/Address__c.Street__c';
import CITY from '@salesforce/schema/Address__c.City__c';
import STATE from '@salesforce/schema/Address__c.State_Province__c';
import POSTAL_CODE from '@salesforce/schema/Address__c.Postal_Code__c';
import COUNTRY_CODE from '@salesforce/schema/Address__c.Country_Code__c';

export default class Address {
    static objectApiName = ADDRESS.objectApiName;

    static street = STREET;
    static city = CITY;
    static state = STATE;
    static postalCode = POSTAL_CODE;
    static countryCode = COUNTRY_CODE;

    street = STREET.fieldApiName;
    city = CITY.fieldApiName;
    state = STATE.fieldApiName;
    postalCode = POSTAL_CODE.fieldApiName;
    countryCode = COUNTRY_CODE.fieldApiName;
}