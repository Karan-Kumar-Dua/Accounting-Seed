import TAX_SETTINGS from '@salesforce/schema/Tax_Settings__c';
import ORIGIN_ADDRESS from '@salesforce/schema/Tax_Settings__c.Origin_Address__c';

export default class TaxSettings {
    static objectApiName = TAX_SETTINGS.objectApiName;

    static originAddress = ORIGIN_ADDRESS;

    originAddress = ORIGIN_ADDRESS.fieldApiName;

}