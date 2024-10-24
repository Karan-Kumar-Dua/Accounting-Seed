import ACCOUNT from '@salesforce/schema/Account';
import B_STREET from '@salesforce/schema/Account.BillingStreet';
import B_CITY from '@salesforce/schema/Account.BillingCity';
import B_STATE from '@salesforce/schema/Account.BillingState';
import B_POSTAL_CODE from '@salesforce/schema/Account.BillingPostalCode';
import B_COUNTRY from '@salesforce/schema/Account.BillingCountry';
import S_STREET from '@salesforce/schema/Account.ShippingStreet';
import S_CITY from '@salesforce/schema/Account.ShippingCity';
import S_STATE from '@salesforce/schema/Account.ShippingState';
import S_POSTAL_CODE from '@salesforce/schema/Account.ShippingPostalCode';
import S_COUNTRY from '@salesforce/schema/Account.ShippingCountry';

export default class Account {
    static objectApiName = ACCOUNT.objectApiName;

    static bStreet = B_STREET;
    static bCity = B_CITY;
    static bState = B_STATE;
    static bPostalCode = B_POSTAL_CODE;
    static bCountry = B_COUNTRY;
    static sStreet = S_STREET;
    static sCity = S_CITY;
    static sState = S_STATE;
    static sPostalCode = S_POSTAL_CODE;
    static sCountry = S_COUNTRY;

    bStreet = B_STREET.fieldApiName;
    bCity = B_CITY.fieldApiName;
    bState = B_STATE.fieldApiName;
    bPostalCode = B_POSTAL_CODE.fieldApiName;
    bCountry = B_COUNTRY.fieldApiName;
    sStreet = S_STREET.fieldApiName;
    sCity = S_CITY.fieldApiName;
    sState = S_STATE.fieldApiName;
    sPostalCode = S_POSTAL_CODE.fieldApiName;
    sCountry = S_COUNTRY.fieldApiName;
}