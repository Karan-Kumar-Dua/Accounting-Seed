import EXCHANGE_RATE from '@salesforce/schema/Exchange_Rate__c';
import FROM_CURRENCY_CODE from '@salesforce/schema/Exchange_Rate__c.From_Currency_Code__c';

export default class ExchangeRate {
    static objectApiName = EXCHANGE_RATE.objectApiName;

    static fromCurrencyCode = FROM_CURRENCY_CODE;

    fromCurrencyCode = FROM_CURRENCY_CODE.fieldApiName
}