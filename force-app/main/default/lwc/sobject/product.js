import PRODUCT from '@salesforce/schema/Product2';

import TAX_RATE from '@salesforce/schema/Product2.Tax_Rate__c';

export default class Product {
    static objectApiName = PRODUCT.objectApiName;

    static taxRate = TAX_RATE;

    taxRate = TAX_RATE.fieldApiName;
}